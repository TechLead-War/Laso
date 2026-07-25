import Foundation

/// Wire format shared by the iPhone app, the watch app and the watch complication.
///
/// The phone is the only authority: it computes every score, every label and every
/// availability flag, and the watch renders what it is handed. This file must stay
/// free of UIKit, WidgetKit, HealthKit and Firebase because the watch targets link
/// none of them.
enum WatchBridge {

    /// Message dictionary key carrying an encoded `WatchPayload`.
    static let payloadKey = "laso.watch.payload"

    /// Message dictionary key carrying an encoded `WatchCommand`.
    static let commandKey = "laso.watch.command"

    /// App Group shared by the watch app and the watch complication. The iPhone's
    /// group is a separate container that watchOS cannot reach, so it can never be
    /// used as the phone-to-watch transport.
    static let watchAppGroup = "group.com.lasohealth.fit.watch"

    /// Latest payload, written by the watch app and read by the complication.
    static let cachedPayloadKey = "laso.watch.cachedPayload"

    /// Command ids the phone has already applied. WatchConnectivity guarantees
    /// delivery but not exactly-once delivery, so without this a redelivered tap
    /// would be counted twice.
    static let appliedCommandIdsKey = "laso.watch.appliedCommandIds"

    /// Cap on remembered command ids.
    // ponytail: a flat list trimmed from the front. A redelivery that arrives after
    // 200 later commands would be applied twice, which needs more wrist taps in one
    // day than anyone makes. Key the ledger by day if that ever stops being true.
    static let appliedCommandIdsLimit = 200

    /// A payload older than this is shown as stale on the wrist rather than as
    /// today's truth. Matches the phone's own 30 minute readiness refresh.
    static let stalePayloadInterval: TimeInterval = 60 * 60

    /// Stable day identifier computed on the phone and carried in every message.
    /// Without it each device decides "today" from its own clock, which disagrees
    /// across midnight and after a timezone change.
    static func dayKey(for date: Date) -> String {
        let parts = Date.cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

// MARK: - Phone to Watch

/// Everything the wrist can show, computed on the phone.
struct WatchPayload: Codable, Equatable {

    /// The day this payload describes, as the phone's calendar sees it.
    let dayKey: String

    /// The same number the Home hero card shows, so the two screens never disagree.
    let readinessScore: Int
    let readinessGrade: String
    let dayType: String

    let actionHeadline: String?
    let actionDetail: String?
    let actionIcon: String?
    let actionDone: Bool

    /// Whether the phone would show the morning check-in right now. The watch must
    /// not decide this itself: the phone owns the time window, the completed flag
    /// and the dismissed flag.
    let checkInAvailable: Bool

    let updatedAt: Date

    /// True when the payload is too old, or describes a day that has since passed,
    /// to be presented as today's truth.
    func isStale(now: Date = Date()) -> Bool {
        if dayKey != WatchBridge.dayKey(for: now) { return true }
        return now.timeIntervalSince(updatedAt) > WatchBridge.stalePayloadInterval
    }
}

// MARK: - Watch to Phone

/// A user write made on the wrist. Every case carries an id so the phone can drop
/// redeliveries, and the phone's day key so a command queued before midnight is
/// never applied to the wrong day.
enum WatchCommand: Codable, Equatable {
    case markActionDone(id: UUID, dayKey: String)
    case checkIn(id: UUID, dayKey: String, sleepQuality: Int, energyLevel: Int, soreness: Int)
    case journalTag(id: UUID, dayKey: String, category: String, value: Double)

    var id: UUID {
        switch self {
        case let .markActionDone(id, _): return id
        case let .checkIn(id, _, _, _, _): return id
        case let .journalTag(id, _, _, _): return id
        }
    }

    var dayKey: String {
        switch self {
        case let .markActionDone(_, dayKey): return dayKey
        case let .checkIn(_, dayKey, _, _, _): return dayKey
        case let .journalTag(_, dayKey, _, _): return dayKey
        }
    }
}

// MARK: - Watch Payload Cache

/// The last payload the watch app stored, read back by the complication.
///
/// The complication extension has no connectivity session of its own, so this
/// shared App Group file is the only thing it can render from.
enum WatchPayloadCache {

    static func load(
        defaults: UserDefaults? = UserDefaults(suiteName: WatchBridge.watchAppGroup)
    ) -> WatchPayload? {
        guard let data = defaults?.data(forKey: WatchBridge.cachedPayloadKey) else { return nil }
        return try? JSONDecoder().decode(WatchPayload.self, from: data)
    }

    static func save(_ payload: WatchPayload, defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults?.set(data, forKey: WatchBridge.cachedPayloadKey)
    }
}

// MARK: - Applied Command Ledger

/// Remembers which wrist commands have already been applied on the phone.
///
/// WatchConnectivity redelivers a queued transfer after a failed hand-off, and the
/// journal writer always inserts a new row, so without this ledger one tap on the
/// wrist can be stored twice.
struct AppliedCommandLedger {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Records the id and reports whether this is the first time it was seen.
    /// Returns false when the command has already been applied.
    func claim(_ id: UUID) -> Bool {
        var ids = defaults.stringArray(forKey: WatchBridge.appliedCommandIdsKey) ?? []
        let key = id.uuidString
        guard !ids.contains(key) else { return false }
        ids.append(key)
        if ids.count > WatchBridge.appliedCommandIdsLimit {
            ids.removeFirst(ids.count - WatchBridge.appliedCommandIdsLimit)
        }
        defaults.set(ids, forKey: WatchBridge.appliedCommandIdsKey)
        return true
    }
}
