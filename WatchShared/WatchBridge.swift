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

    /// Message dictionary key carrying an encoded `WatchCommandResult`.
    static let resultKey = "laso.watch.result"

    /// App Group shared by the watch app and the watch complication. The iPhone's
    /// group is a separate container that watchOS cannot reach, so it can never be
    /// used as the phone-to-watch transport.
    static let watchAppGroup = "group.com.lasohealth.fit.watch"

    /// Latest payload, written by the watch app and read by the complication.
    static let cachedPayloadKey = "laso.watch.cachedPayload"

    /// Latest word the watch app computed, read by the complication so the face and the
    /// app can never show different verdicts.
    static let cachedVerdictKey = "laso.watch.cachedVerdict"

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

    /// Shape of the payload this build sends.
    ///
    /// 1 — score, grade, day type and the daily action.
    /// 2 — adds the baselines and ceilings `WatchVerdict` needs, so the wrist can pick
    ///     its own word instead of only rendering a number.
    ///
    /// Every schema 2 field is optional, so a watch on an older build decodes what it
    /// understands and ignores the rest rather than failing the whole payload and going
    /// blank.
    static let schemaVersion = 2

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

    // MARK: - Schema 2
    //
    // Every field below is optional so a phone running a newer build can talk to a
    // watch the user has not updated yet: the old watch decodes what it knows and
    // ignores the rest, instead of failing the whole payload and going blank.
    //
    // These are the values `WatchVerdict` needs and the wrist cannot measure, because
    // each one needs 30 to 90 days of history against watchOS's roughly seven day
    // HealthKit window.

    /// Payload shape. Nil means a phone build from before schema 2.
    let schemaVersion: Int?

    /// The phone's multi-day body-stress read. Drives the `rest` rung, which must never
    /// fire off a single night.
    let bodyStressElevated: Bool?

    /// This wearer's own resting heart rate baseline. Without it a resting rate is just
    /// a number; with it the wrist can say "3 above your normal" all day with no
    /// further messages.
    let restingHeartRateBaseline: Double?

    /// Bottom of this wearer's usual HRV range, not the mean. A value under the floor is
    /// what "suppressed" means for them.
    let hrvBaselineFloor: Double?

    /// Hours since the last high-strain day, so a suppressed HRV can be explained rather
    /// than merely reported.
    let hoursSinceHardDay: Double?

    /// Minutes of movement that are wise today, from the strain coach. The wrist never
    /// derives this: it depends on load history the watch cannot see.
    let exerciseCeilingMinutes: Int?

    /// Tonight's bedtime target, from sleep need plus accumulated debt.
    let bedtimeTarget: Date?

    /// Nights of history behind the values above. Below
    /// `WatchVerdictThresholds.baselineNightsRequired` the wrist names the cold start
    /// instead of making claims.
    let nightsOfHistory: Int?

    init(
        dayKey: String,
        readinessScore: Int,
        readinessGrade: String,
        dayType: String,
        actionHeadline: String?,
        actionDetail: String?,
        actionIcon: String?,
        actionDone: Bool,
        checkInAvailable: Bool,
        updatedAt: Date,
        schemaVersion: Int? = WatchBridge.schemaVersion,
        bodyStressElevated: Bool? = nil,
        restingHeartRateBaseline: Double? = nil,
        hrvBaselineFloor: Double? = nil,
        hoursSinceHardDay: Double? = nil,
        exerciseCeilingMinutes: Int? = nil,
        bedtimeTarget: Date? = nil,
        nightsOfHistory: Int? = nil
    ) {
        self.dayKey = dayKey
        self.readinessScore = readinessScore
        self.readinessGrade = readinessGrade
        self.dayType = dayType
        self.actionHeadline = actionHeadline
        self.actionDetail = actionDetail
        self.actionIcon = actionIcon
        self.actionDone = actionDone
        self.checkInAvailable = checkInAvailable
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
        self.bodyStressElevated = bodyStressElevated
        self.restingHeartRateBaseline = restingHeartRateBaseline
        self.hrvBaselineFloor = hrvBaselineFloor
        self.hoursSinceHardDay = hoursSinceHardDay
        self.exerciseCeilingMinutes = exerciseCeilingMinutes
        self.bedtimeTarget = bedtimeTarget
        self.nightsOfHistory = nightsOfHistory
    }

    var version: Int { schemaVersion ?? 1 }

    /// Age of this payload in minutes, which the `train` rung gates on and every screen
    /// shows. Freshness is stated in this design, never hidden.
    func ageMinutes(now: Date = Date()) -> Double {
        max(0, now.timeIntervalSince(updatedAt) / 60)
    }

    /// True when the payload is too old, or describes a day that has since passed,
    /// to be presented as today's truth.
    func isStale(now: Date = Date()) -> Bool {
        if dayKey != WatchBridge.dayKey(for: now) { return true }
        return now.timeIntervalSince(updatedAt) > WatchBridge.stalePayloadInterval
    }
}

// MARK: - Watch to Phone

/// A user write made on the wrist. Every case carries an id so the phone can drop
/// redeliveries, and the moment the tap happened so the phone can store the write on
/// the day it belongs to.
///
/// The instant travels, not a day key. A day key would have to be copied out of the
/// last payload the phone sent, and on any morning before the phone has synced that
/// key still names yesterday, so every write made that morning would be filed on the
/// wrong day or thrown away. The phone still turns the instant into a day with its
/// own calendar, so the two devices never disagree about where a day starts.
enum WatchCommand: Codable, Equatable {
    case markActionDone(id: UUID, createdAt: Date)
    case checkIn(id: UUID, createdAt: Date, sleepQuality: Int, energyLevel: Int, soreness: Int)
    case journalTag(id: UUID, createdAt: Date, category: String, value: Double)

    var id: UUID {
        switch self {
        case let .markActionDone(id, _): return id
        case let .checkIn(id, _, _, _, _): return id
        case let .journalTag(id, _, _, _): return id
        }
    }

    var createdAt: Date {
        switch self {
        case let .markActionDone(_, createdAt): return createdAt
        case let .checkIn(_, createdAt, _, _, _): return createdAt
        case let .journalTag(_, createdAt, _, _): return createdAt
        }
    }
}

/// What the phone did with one wrist write.
///
/// Sent as its own queued transfer rather than folded into the payload: an outcome is
/// a one time fact about one command, while the application context only ever holds
/// the newest state, so a burst of wrist taps would lose every outcome but the last.
struct WatchCommandResult: Codable, Equatable {
    let commandId: UUID

    /// Why the phone refused the write. Nil when it was stored.
    let rejection: WatchCommandRejection?
}

/// Why a wrist write was not stored. The wrist says so instead of quietly showing the
/// write as saved, which is what it used to do.
enum WatchCommandRejection: String, Codable, CaseIterable {

    /// The tap happened on an earlier day and that write only makes sense for today.
    case earlierDay

    /// The phone could not store it, so nothing was written.
    case notStored

    /// The write never reached the phone.
    case notDelivered
}

// MARK: - Watch Payload Cache

/// The last payload the watch app stored, read back by the complication.
///
/// The complication extension has no connectivity session of its own, so this
/// shared App Group file is the only thing it can render from.
/// The word the watch app last computed, so the complication renders exactly what the
/// app would.
///
/// The complication extension links no HealthKit, so it cannot run the ladder itself: it
/// has no live heart rate and no exercise minutes. Rather than give the extension a
/// second health permission and let it reach a different rung from the same payload, the
/// app caches its answer here and the face renders it. One computation, one answer, no
/// way for the two surfaces to disagree.
struct CachedWatchVerdict: Codable, Equatable {
    let word: WatchWord
    let reason: String
    let headroomMinutes: Int?
    let band: WatchBand?
    let computedAt: Date

    /// The day this word described. Without it the face kept yesterday's word and
    /// yesterday's headroom after midnight while the app had already moved on.
    let dayKey: String?

    /// The ceiling the headroom was measured against, carried here rather than read back
    /// out of the payload cache. The two caches are written at independent moments, so
    /// pairing a headroom from one computation with a ceiling from another produced a
    /// gauge that could read backwards.
    let ceilingMinutes: Int?

    /// True once this word describes a different day. It is not aged out by the clock:
    /// only `train` is freshness-gated in this design, and blanking the face an hour
    /// after the app last ran is exactly the "-- on the watch face" failure the redesign
    /// set out to remove.
    func isForAnotherDay(now: Date = Date()) -> Bool {
        guard let dayKey else { return false }
        return dayKey != WatchBridge.dayKey(for: now)
    }

    /// How long ago the word was computed, so a surface can show its age instead of
    /// hiding it.
    func ageMinutes(now: Date = Date()) -> Double {
        max(0, now.timeIntervalSince(computedAt) / 60)
    }

    /// Fraction of today's ceiling already spent, or nil when no ceiling is known.
    var spentFraction: Double? {
        guard let ceilingMinutes, ceilingMinutes > 0, let headroomMinutes else { return nil }
        return min(1, max(0, Double(ceilingMinutes - headroomMinutes) / Double(ceilingMinutes)))
    }
}

enum WatchVerdictCache {

    static func load(
        defaults: UserDefaults? = UserDefaults(suiteName: WatchBridge.watchAppGroup)
    ) -> CachedWatchVerdict? {
        guard let data = defaults?.data(forKey: WatchBridge.cachedVerdictKey) else { return nil }
        return try? JSONDecoder().decode(CachedWatchVerdict.self, from: data)
    }

    static func save(_ verdict: CachedWatchVerdict, defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(verdict) else { return }
        defaults?.set(data, forKey: WatchBridge.cachedVerdictKey)
    }
}

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
