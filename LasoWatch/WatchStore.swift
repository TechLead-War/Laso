import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// The watch half of the phone link.
///
/// Holds the last payload the phone sent and caches it in the App Group the
/// complication also reads. Nothing here computes a score: watchOS cannot see the
/// phone's 60 day baselines, its remote kill switch, or the smoothing state the
/// readiness scorer keeps in phone memory.
@Observable
@MainActor
final class WatchStore {

    private(set) var payload: WatchPayload?

    /// Wrist writes sent but not yet answered by the phone, kept whole so an answer
    /// can be matched back to what the user did.
    ///
    /// Only the phone's answer clears one. An arriving payload used to clear them all,
    /// which showed every write as saved even when the phone had thrown it away.
    private(set) var pendingCommands: [UUID: (command: WatchCommand, sentAt: Date)] = [:]

    /// How long a wrist write may sit unanswered before the button unlocks again.
    ///
    /// Without this an answer that never arrives disabled the button until the app was
    /// relaunched, because the list only lives in memory. The write itself is still
    /// queued by WatchConnectivity and may yet land, so this only re-enables the
    /// control; it never claims the write failed.
    private static let pendingWriteTimeout: TimeInterval = 60

    /// True while a write is still within its answer window, which is the only time the
    /// action button should be locked.
    var hasPendingWrite: Bool {
        pendingCommands.values.contains { Date().timeIntervalSince($0.sentAt) < Self.pendingWriteTimeout }
    }

    /// Why the last wrist write did not land, or nil when the last one landed.
    private(set) var rejection: WatchCommandRejection?

    /// When the phone last confirmed a mark done sent from this wrist. It has to
    /// stand on its own: the phone sends no payload until it has a real score for the
    /// day, so an early morning tap gets no fresh payload to tick the button.
    private var markedDoneAt: Date?

    private let bridge = WatchConnectivityBridge()
    private let defaults = UserDefaults(suiteName: WatchBridge.watchAppGroup)

    init() {
        payload = loadCached()
        bridge.onPayload = { [weak self] payload in
            Task { @MainActor in self?.receive(payload) }
        }
        bridge.onResult = { [weak self] result in
            Task { @MainActor in self?.settle(result) }
        }
        bridge.onSendFailure = { [weak self] commandId in
            Task { @MainActor in self?.settle(WatchCommandResult(commandId: commandId, rejection: .notDelivered)) }
        }
        bridge.activate()
    }

    /// Whether today's action is ticked, from the phone's payload for today or from
    /// the phone's answer to a mark done sent from this wrist.
    var isActionDoneToday: Bool {
        if let markedDoneAt, Date.cal.isDateInToday(markedDoneAt) { return true }
        guard let payload, payload.dayKey == WatchBridge.dayKey(for: Date()) else { return false }
        return payload.actionDone
    }

    /// Assembles the ladder's input from the two sources.
    ///
    /// Measured values come from `health` and are present on any worn watch. Everything
    /// needing 30 to 90 days of history comes from the payload and stays nil when the
    /// phone has never synced, which makes the phone-dependent rungs skip rather than
    /// guess. A watch that has never met its phone still reaches rung 7 and shows a word.
    func verdictInput(health: WatchHealthStore, now: Date = Date()) -> WatchVerdictInput {
        // Two different lifetimes, so two different rules.
        //
        // `today` holds anything that describes this specific day: the score, the
        // ceiling, tonight's bedtime. None of it survives midnight.
        //
        // `slow` holds the 30 to 90 day baselines, which are still the wearer's baselines
        // at 06:00 the next morning. Dropping those at midnight left the wrist unable to
        // say "3 above your normal" until the phone next pushed, which is exactly the
        // dependency this design removes.
        let today = payload.flatMap { $0.dayKey == WatchBridge.dayKey(for: now) ? $0 : nil }
        let slow = payload

        return WatchVerdictInput(
            restingHeartRate: health.restingHeartRate,
            heartRate: health.heartRate,
            heartRateAgeMinutes: health.heartRateSampledAt.map { now.timeIntervalSince($0) / 60 },
            heartRateVariability: health.heartRateVariability,
            stepsLastTenMinutes: health.stepsLastTenMinutes,
            exerciseMinutesLastTenMinutes: health.exerciseMinutesLastTenMinutes,
            exerciseMinutesToday: health.exerciseMinutesToday,
            // Unknown means "no claim to make", not "brand new". The cold-start copy only
            // makes sense once the phone has told us how many nights it actually has.
            nightsOfHistory: slow?.nightsOfHistory ?? WatchVerdictThresholds.baselineNightsRequired,
            readinessScore: today.flatMap { $0.readinessScore > 0 ? $0.readinessScore : nil },
            payloadAgeMinutes: today?.ageMinutes(now: now),
            bodyStressElevated: today?.bodyStressElevated,
            restingHeartRateBaseline: slow?.restingHeartRateBaseline,
            hrvBaselineFloor: slow?.hrvBaselineFloor,
            hoursSinceHardDay: today?.hoursSinceHardDay,
            exerciseCeilingMinutes: today?.exerciseCeilingMinutes,
            minutesToBedtime: today?.bedtimeTarget.map { $0.timeIntervalSince(now) / 60 },
            isHealthAccessDenied: health.isAuthorized == false || health.hasNoReadableData == true
        )
    }

    // MARK: - Receive

    private func receive(_ payload: WatchPayload) {
        // A payload can arrive out of order when a queued complication transfer
        // lands after a newer application context. Never move backwards in time.
        if let current = self.payload, current.updatedAt > payload.updatedAt { return }

        self.payload = payload
        cache(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Records what the phone did with one wrist write.
    private func settle(_ result: WatchCommandResult) {
        guard let pending = pendingCommands.removeValue(forKey: result.commandId) else { return }
        rejection = result.rejection
        guard result.rejection == nil else {
            // A refused write must never look like a stored one.
            WatchHaptics.failure()
            return
        }
        guard case .markActionDone = pending.command else { return }
        markedDoneAt = Date()
    }

    // MARK: - Send

    /// Queues a wrist write. Uses guaranteed delivery rather than a live message so
    /// a tap made with the phone asleep or out of range still lands.
    func send(_ command: WatchCommand) {
        pendingCommands[command.id] = (command, Date())
        rejection = nil
        bridge.send(command)
    }

    func markActionDone() {
        send(.markActionDone(id: UUID(), createdAt: Date()))
    }

    func submitCheckIn(sleepQuality: Int, energyLevel: Int, soreness: Int) {
        send(.checkIn(
            id: UUID(),
            createdAt: Date(),
            sleepQuality: sleepQuality,
            energyLevel: energyLevel,
            soreness: soreness
        ))
    }

    func logQuickTag(_ tag: WatchQuickTag) {
        send(.journalTag(id: UUID(), createdAt: Date(), category: tag.rawValue, value: tag.value))
    }

    // MARK: - Cache

    private func cache(_ payload: WatchPayload) {
        WatchPayloadCache.save(payload, defaults: defaults)
    }

    /// Hands the app's answer to the complication and redraws the face.
    ///
    /// Nil means health access is off, which is the one state with no word. The last
    /// cached word is left in place: overwriting it would blank the face on a permission
    /// change the wearer can undo in Settings.
    func cache(verdict: WatchVerdict?, now: Date = Date()) {
        guard let verdict else { return }
        let entry = CachedWatchVerdict(
            word: verdict.word,
            reason: verdict.reason,
            headroomMinutes: verdict.headroomMinutes,
            band: verdict.band,
            computedAt: now,
            dayKey: WatchBridge.dayKey(for: now),
            ceilingMinutes: payload?.exerciseCeilingMinutes
        )
        // Reloading the face costs from a budget of roughly four an hour, so it is only
        // spent when the rendered content actually changed.
        guard entry.word != lastCachedVerdict?.word
                || entry.headroomMinutes != lastCachedVerdict?.headroomMinutes
                || entry.dayKey != lastCachedVerdict?.dayKey else { return }
        lastCachedVerdict = entry
        WatchVerdictCache.save(entry, defaults: defaults)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// What the face is currently showing, so an unchanged word does not spend a reload.
    private var lastCachedVerdict: CachedWatchVerdict?

    private func loadCached() -> WatchPayload? {
        WatchPayloadCache.load(defaults: defaults)
    }
}

// MARK: - Connectivity

/// Session delegate kept separate from `WatchStore` because `WCSessionDelegate`
/// callbacks arrive off the main actor and the store is main actor bound.
private final class WatchConnectivityBridge: NSObject, WCSessionDelegate {

    var onPayload: ((WatchPayload) -> Void)?
    var onResult: ((WatchCommandResult) -> Void)?
    var onSendFailure: ((UUID) -> Void)?
    var onReachabilityChange: ((Bool) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func send(_ command: WatchCommand) {
        guard WCSession.isSupported(),
              let data = try? JSONEncoder().encode(command) else { return }
        WCSession.default.transferUserInfo([WatchBridge.commandKey: data])
    }

    // MARK: WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard error == nil, activationState == .activated else { return }
        onReachabilityChange?(session.isCompanionAppInstalled)
        deliver(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        deliver(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        deliver(userInfo)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        onReachabilityChange?(session.isReachable)
    }

    /// A queued write could not be handed to the phone. Say so rather than leaving the
    /// button disabled on a write that is never coming back.
    func session(
        _ session: WCSession,
        didFinish userInfoTransfer: WCSessionUserInfoTransfer,
        error: Error?
    ) {
        guard error != nil,
              let data = userInfoTransfer.userInfo[WatchBridge.commandKey] as? Data,
              let command = try? JSONDecoder().decode(WatchCommand.self, from: data) else { return }
        onSendFailure?(command.id)
    }

    private func deliver(_ dictionary: [String: Any]) {
        if let data = dictionary[WatchBridge.payloadKey] as? Data,
           let payload = try? JSONDecoder().decode(WatchPayload.self, from: data) {
            onPayload?(payload)
        }
        if let data = dictionary[WatchBridge.resultKey] as? Data,
           let result = try? JSONDecoder().decode(WatchCommandResult.self, from: data) {
            onResult?(result)
        }
    }
}
