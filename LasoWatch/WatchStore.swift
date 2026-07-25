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

    /// Wrist writes sent but not yet reflected in a payload from the phone. The
    /// phone re-sends after applying a command, and that re-send is the
    /// acknowledgement, so no separate ack message is needed.
    private(set) var pendingCommands: Set<UUID> = []

    private let bridge = WatchConnectivityBridge()
    private let defaults = UserDefaults(suiteName: WatchBridge.watchAppGroup)

    init() {
        payload = loadCached()
        bridge.onPayload = { [weak self] payload in
            Task { @MainActor in self?.receive(payload) }
        }
        bridge.onReachabilityChange = { [weak self] reachable in
            Task { @MainActor in self?.hasCompanion = self?.hasCompanion == true || reachable }
        }
        bridge.activate()
    }

    // MARK: - Receive

    private func receive(_ payload: WatchPayload) {
        // A payload can arrive out of order when a queued complication transfer
        // lands after a newer application context. Never move backwards in time.
        if let current = self.payload, current.updatedAt > payload.updatedAt { return }

        self.payload = payload
        hasCompanion = true
        pendingCommands.removeAll()
        cache(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Send

    /// Queues a wrist write. Uses guaranteed delivery rather than a live message so
    /// a tap made with the phone asleep or out of range still lands.
    func send(_ command: WatchCommand) {
        pendingCommands.insert(command.id)
        bridge.send(command)
    }

    func markActionDone() {
        guard let dayKey = payload?.dayKey else { return }
        send(.markActionDone(id: UUID(), dayKey: dayKey))
    }

    func submitCheckIn(sleepQuality: Int, energyLevel: Int, soreness: Int) {
        guard let dayKey = payload?.dayKey else { return }
        send(.checkIn(
            id: UUID(),
            dayKey: dayKey,
            sleepQuality: sleepQuality,
            energyLevel: energyLevel,
            soreness: soreness
        ))
    }

    func logQuickTag(_ tag: WatchQuickTag) {
        guard let dayKey = payload?.dayKey else { return }
        send(.journalTag(id: UUID(), dayKey: dayKey, category: tag.rawValue, value: tag.value))
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

    private func deliver(_ dictionary: [String: Any]) {
        guard let data = dictionary[WatchBridge.payloadKey] as? Data,
              let payload = try? JSONDecoder().decode(WatchPayload.self, from: data) else { return }
        onPayload?(payload)
    }
}
