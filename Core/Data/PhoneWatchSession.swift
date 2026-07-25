import Foundation
import Observation
import WatchConnectivity

/// What the phone currently knows about the paired watch.
///
/// Read by the Home card that teaches people to add the complication, which must
/// disappear the moment they actually add it.
@Observable
@MainActor
final class WatchLinkState {

    private(set) var isPaired = false
    private(set) var isWatchAppInstalled = false
    private(set) var isComplicationEnabled = false

    fileprivate func update(from session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        isComplicationEnabled = session.isComplicationEnabled
    }
}

/// The iPhone half of the phone-to-watch link.
///
/// Sending: the newest state goes out as application context, which coalesces so a
/// burst of refreshes costs one delivery and the watch always sees the latest value.
/// When the readiness number itself changes we additionally spend one complication
/// transfer, which is the only thing that wakes the watch to redraw the face. That
/// budget is finite per day, so it is never spent on an unchanged score.
///
/// Receiving: wrist writes arrive as queued user info. They are guaranteed to be
/// delivered even if the phone was asleep when the tap happened, which is why the
/// wrist never uses `sendMessage`.
/// `WCSessionDelegate` is adopted on the class itself, not in an extension: most of
/// its methods are optional Objective-C requirements, and an extension witness does
/// not reliably get the `@objc` entry point the framework looks up, so incoming
/// wrist writes would silently never arrive.
final class PhoneWatchSession: NSObject, WCSessionDelegate {

    static let shared = PhoneWatchSession()

    /// Set once at startup so a wrist journal write reaches the same SwiftData
    /// store the app itself reads.
    @MainActor private weak var healthDataStore: HealthDataStore?

    /// The last score, grade and day type the phone computed. Kept so a payload can
    /// be rebuilt after a wrist write without waiting for the next analysis run.
    @MainActor private var lastCoreState: CoreState?

    /// The readiness number in the last complication transfer, so an unchanged score
    /// never spends from the daily budget.
    @MainActor private var lastComplicationScore: Int?

    @MainActor private let ledger = AppliedCommandLedger()

    /// Live view of the paired watch, for UI that has to react to it.
    @MainActor let linkState = WatchLinkState()

    private struct CoreState {
        let readinessScore: Int
        let grade: String
        let dayType: String
    }

    private override init() {
        super.init()
    }

    // MARK: - Lifecycle

    /// Activates the session. Safe to call more than once; activation is idempotent.
    @MainActor
    func activate(healthDataStore: HealthDataStore?) {
        self.healthDataStore = healthDataStore

        guard WCSession.isSupported() else { return }
        WatchQuickTag.validateAgainstJournalCategories()

        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    // MARK: - Send

    /// Pushes the current state to the watch. Called after every analysis refresh
    /// and after every wrist write is applied.
    @MainActor
    func push(readinessScore: Int, grade: String, dayType: String) {
        lastCoreState = CoreState(readinessScore: readinessScore, grade: grade, dayType: dayType)
        send(buildPayload(core: lastCoreState))
    }

    /// Re-sends using the last known score. Used after a wrist write changes an
    /// availability flag but not the score itself.
    @MainActor
    private func resend() {
        send(buildPayload(core: lastCoreState))
    }

    /// Wipes what the wrist is showing after the user deletes their account.
    ///
    /// The watch keeps its own copy of the last payload, one container further out
    /// than the local wipe reaches, so it has to be overwritten rather than deleted.
    @MainActor
    func clearForAccountWipe() {
        DailyActionStore.clear()
        lastCoreState = nil
        lastComplicationScore = nil
        send(buildPayload(core: nil))
    }

    @MainActor
    private func buildPayload(core: CoreState?) -> WatchPayload {
        let action = DailyActionStore.today()
        return WatchPayload(
            dayKey: WatchBridge.dayKey(for: Date()),
            readinessScore: core?.readinessScore ?? 0,
            readinessGrade: core?.grade ?? "",
            dayType: core?.dayType ?? "",
            actionHeadline: action?.title,
            actionDetail: action?.subtitle,
            actionIcon: action?.icon,
            actionDone: DailyActionCompletion.isDoneToday,
            checkInAvailable: MorningCheckInManager.shouldShowCheckIn(),
            updatedAt: Date()
        )
    }

    @MainActor
    private func send(_ payload: WatchPayload) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired,
              session.isWatchAppInstalled else { return }

        guard let data = try? JSONEncoder().encode(payload) else {
            AnalyticsBackend.provider.captureError(
                "Failed to encode watch payload", context: "phone_watch_session_encode")
            return
        }
        let context: [String: Any] = [WatchBridge.payloadKey: data]

        do {
            try session.updateApplicationContext(context)
        } catch {
            AnalyticsBackend.provider.captureError(error, context: "phone_watch_session_context")
        }

        // Only a complication transfer redraws the watch face while the watch app is
        // not in front. Spend one only when the number the face shows has changed,
        // and fall back to the application context above when the budget is gone.
        guard payload.readinessScore != lastComplicationScore,
              session.remainingComplicationUserInfoTransfers > 0 else { return }
        lastComplicationScore = payload.readinessScore
        session.transferCurrentComplicationUserInfo(context)
    }

    // MARK: - Apply wrist writes

    @MainActor
    private func apply(_ command: WatchCommand) {
        // A command queued before midnight must not land on the next day's record.
        guard command.dayKey == WatchBridge.dayKey(for: Date()) else { return }

        // WatchConnectivity redelivers queued transfers, and the journal writer
        // always inserts, so an unclaimed redelivery would double count.
        guard ledger.claim(command.id) else { return }

        switch command {
        case .markActionDone:
            let action = DailyActionStore.today()
            DailyActionCompletion.markDone(
                actionTitle: action?.title ?? "",
                actionIcon: action?.icon ?? "checkmark",
                score: lastCoreState?.readinessScore ?? 0,
                source: "watch_mark_done"
            )

        case let .checkIn(_, _, sleepQuality, energyLevel, soreness):
            MorningCheckInManager.record(
                MorningCheckIn(
                    date: Date(),
                    sleepQuality: sleepQuality,
                    energyLevel: energyLevel,
                    soreness: soreness
                )
            )

        case let .journalTag(_, _, category, value):
            guard let journalCategory = JournalCategory(rawValue: category) else {
                AnalyticsBackend.provider.captureError(
                    "Unknown journal category from watch: \(category)",
                    context: "phone_watch_session_journal")
                return
            }
            guard let context = healthDataStore?.modelContext else {
                AnalyticsBackend.provider.captureError(
                    "No model context for watch journal write",
                    context: "phone_watch_session_journal")
                return
            }
            JournalStore(modelContext: context).save(category: journalCategory, value: value)
        }

        // The wrist just changed an availability flag, so tell it what is true now.
        resend()
    }

    // MARK: - WCSessionDelegate

    @objc func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            AnalyticsBackend.provider.captureError(error, context: "phone_watch_session_activate")
            return
        }
        guard activationState == .activated else { return }
        Task { @MainActor in
            self.linkState.update(from: session)
            self.resend()
        }
    }

    /// Required on iOS. The session goes inactive when the user switches watches.
    @objc func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Required on iOS. Reactivate so the newly paired watch gets a session.
    @objc func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    /// A watch was paired, unpaired, the watch app was installed or removed, or a
    /// complication was added to or taken off the face.
    @objc func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.linkState.update(from: session)
            self.resend()
        }
    }

    @objc func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchBridge.commandKey] as? Data,
              let command = try? JSONDecoder().decode(WatchCommand.self, from: data) else {
            AnalyticsBackend.provider.captureError(
                "Undecodable command from watch", context: "phone_watch_session_receive")
            return
        }
        Task { @MainActor in self.apply(command) }
    }

    /// A queued transfer finished. Only surfaces failures; success needs no action
    /// because the phone re-sends its state after applying the command.
    @objc func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        guard let error else { return }
        AnalyticsBackend.provider.captureError(error, context: "phone_watch_session_transfer")
    }
}

// MARK: - Quick tag self-check

private extension WatchQuickTag {

    /// The wrist sends raw category strings and the phone maps them back to a
    /// `JournalCategory`. A typo would store a row the daily summary silently skips,
    /// so the mapping is checked once at session start rather than at first tap.
    static func validateAgainstJournalCategories() {
        let unknown = all.filter { JournalCategory(rawValue: $0.rawValue) == nil }
        guard !unknown.isEmpty else { return }
        let names = unknown.map(\.rawValue).joined(separator: ", ")
        assertionFailure("Watch quick tags do not match JournalCategory: \(names)")
        AnalyticsBackend.provider.captureError(
            "Watch quick tags do not match JournalCategory: \(names)",
            context: "watch_quick_tag_validation")
    }
}
