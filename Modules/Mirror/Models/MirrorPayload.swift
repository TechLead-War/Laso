import Foundation

/// Everything a Daily Mirror template can draw, captured once at save time and
/// stored beside the photo.
///
/// The photo on disk is now the plain camera frame: the overlay is drawn at
/// view time from this payload. That is what makes a template a decision the
/// user can change later, and what lets a template written next year apply to
/// a photo taken today. Storing the values rather than re-reading them keeps a
/// past day honest, because "your last thirty days" on the seventh of August
/// must always mean the thirty days that ended that morning.
struct MirrorPayload: Codable, Equatable {

    // MARK: - The day itself

    var date: Date
    /// Capture streak this photo was taken on.
    var streak: Int
    var captureCount: Int
    /// Days between the first ever capture and this one, nil on the first day.
    var daysSinceFirst: Int?

    // MARK: - Readiness

    var score: Int?
    /// Morning lock confidence, 0 to 100.
    var scoreConfidence: Int?

    // MARK: - Last night

    var sleepHours: Double?
    var deepMinutes: Double?
    var remMinutes: Double?
    var debtHours: Double?

    // MARK: - Body

    var vitalityAge: Int?
    var chronologicalAge: Int?

    // MARK: - Effort

    var strain: Double?
    var restingHeartRate: Int?
    var hrv: Int?

    // MARK: - Sentences the app already writes

    /// Top intelligence headline, a complete English sentence.
    var sentence: String?
    /// The proof line: what the user did and what it moved.
    var actionLine: String?

    // MARK: - Series

    /// Up to thirty daily scores, oldest first, this photo's day last. Gaps are
    /// dropped rather than zeroed, so a missing day never draws as a crash to
    /// the floor.
    var scoreHistory: [Int]

    /// Sleep stages for the night before, as (stage, minutes) pairs, where the
    /// stage is 0 awake, 1 REM, 2 core, 3 deep. Empty when staging is not
    /// available, which is what makes The Night gate itself off.
    var sleepStages: [SleepStage]

    struct SleepStage: Codable, Equatable {
        var level: Int
        var minutes: Double
    }

    // MARK: - Derived

    var hasScore: Bool { score != nil }
    var hasSleep: Bool { sleepHours != nil }
    var hasStages: Bool { sleepStages.count >= 4 }
    var hasAges: Bool {
        guard let vitalityAge, let chronologicalAge else { return false }
        return vitalityAge > 0 && chronologicalAge > 0
    }
    var ageDelta: Int? {
        guard hasAges, let vitalityAge, let chronologicalAge else { return nil }
        return chronologicalAge - vitalityAge
    }
    /// Horizon needs enough of a run to read as terrain rather than as noise.
    var hasHistory: Bool { scoreHistory.count >= 10 }

    var averageScore: Int? {
        guard !scoreHistory.isEmpty else { return nil }
        return Int((Double(scoreHistory.reduce(0, +)) / Double(scoreHistory.count)).rounded())
    }

    static let empty = MirrorPayload(
        date: .now, streak: 0, captureCount: 0, daysSinceFirst: nil,
        score: nil, scoreConfidence: nil,
        sleepHours: nil, deepMinutes: nil, remMinutes: nil, debtHours: nil,
        vitalityAge: nil, chronologicalAge: nil,
        strain: nil, restingHeartRate: nil, hrv: nil,
        sentence: nil, actionLine: nil,
        scoreHistory: [], sleepStages: []
    )
}

// MARK: - Building

@MainActor
enum MirrorPayloadBuilder {

    /// Gathers the day from what is already in memory or on disk. Every source
    /// here is a synchronous read of a cached snapshot, so the capture screen
    /// never waits on HealthKit with a photo held on screen.
    ///
    /// - Parameter streak: the streak the caller intends to stamp, which on a
    ///   retake is today's existing streak rather than one more than it.
    static func build(streak: Int, on date: Date = .now) -> MirrorPayload {
        let store = MirrorPhotoStore.shared
        let widgets = WidgetDataStore.shared
        let readiness = ReadinessStore()

        let sleep = widgets.loadSleep()
        let vitality = VitalityScorer()

        var payload = MirrorPayload.empty
        payload.date = date
        payload.streak = streak
        payload.captureCount = store.photoCount + (store.hasPhoto(on: date) ? 0 : 1)
        payload.daysSinceFirst = store.allDays.first.map { $0.daysBetween(date) }

        payload.score = readiness.loadMorningLock(for: date) ?? readiness.loadCachedScore()
        payload.scoreConfidence = readiness.loadMorningLockConfidence(for: date)

        payload.sleepHours = sleep?.hoursSlept
        payload.deepMinutes = sleep?.deepMinutes
        payload.remMinutes = sleep?.remMinutes
        payload.debtHours = widgets.loadRecoveryDebt()?.debtHours

        if vitality.vitalityAge > 0 && vitality.chronologicalAge > 0 {
            payload.vitalityAge = vitality.vitalityAge
            payload.chronologicalAge = vitality.chronologicalAge
        }

        payload.sentence = widgets.loadIntelligence()?.headline
        // Only an upward move is worth writing onto a photo. A steady or falling
        // day still gets a sentence, it just comes from the intelligence card.
        if let result = DailyActionResultStore.resultToShow(), result.direction == .up {
            payload.actionLine = Copy.Mirror.actionProof(result.record.actionTitle, result.delta)
        }

        payload.scoreHistory = scoreHistory(endingOn: date, todayScore: payload.score)

        return payload
    }

    /// Daily scores ending on `date`. The archive's own stored scores are the
    /// source: they are already one per day, already on disk, and they need no
    /// model container, which the capture sheet has no way to reach.
    private static func scoreHistory(endingOn date: Date, todayScore: Int?) -> [Int] {
        let store = MirrorPhotoStore.shared
        var out: [Int] = []
        for offset in stride(from: 29, through: 1, by: -1) {
            let day = date.daysAgo(offset)
            if let score = store.meta(on: day)?.score { out.append(score) }
        }
        if let todayScore { out.append(todayScore) }
        return out
    }
}
