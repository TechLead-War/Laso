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

    /// True once the phone has ever been seen. Used to tell "no data yet" apart
    /// from "not paired", which need different instructions on the wrist.
    private(set) var hasCompanion = false

    /// Wrist writes sent but not yet answered by the phone, kept whole so an answer
    /// can be matched back to what the user did.
    ///
    /// Only the phone's answer clears one. An arriving payload used to clear them all,
    /// which showed every write as saved even when the phone had thrown it away.
    // ponytail: an answer that never arrives leaves its write pending until the app is
    // relaunched, since this list only lives in memory. Stamp the entries with a time
    // and expire them if that ever shows up in real use.
    private(set) var pendingCommands: [UUID: WatchCommand] = [:]

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
        bridge.onReachabilityChange = { [weak self] reachable in
            Task { @MainActor in self?.hasCompanion = self?.hasCompanion == true || reachable }
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

    // MARK: - Receive

    private func receive(_ payload: WatchPayload) {
        // A payload can arrive out of order when a queued complication transfer
        // lands after a newer application context. Never move backwards in time.
        if let current = self.payload, current.updatedAt > payload.updatedAt { return }

        self.payload = payload
        hasCompanion = true
        cache(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Records what the phone did with one wrist write.
    private func settle(_ result: WatchCommandResult) {
        guard let command = pendingCommands.removeValue(forKey: result.commandId) else { return }
        rejection = result.rejection
        guard result.rejection == nil, case .markActionDone = command else { return }
        markedDoneAt = Date()
    }

    // MARK: - Send

    /// Queues a wrist write. Uses guaranteed delivery rather than a live message so
    /// a tap made with the phone asleep or out of range still lands.
    func send(_ command: WatchCommand) {
        pendingCommands[command.id] = command
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
