import Foundation
import SwiftUI

// MARK: - UserLevel

/// Progression level based on total days of app usage, inspired by WHOOP's tiered system.
enum UserLevel: Int, CaseIterable, Comparable {
    case newcomer = 0
    case explorer = 1
    case committed = 2
    case dedicated = 3
    case champion = 4
    case legend = 5

    static func < (lhs: UserLevel, rhs: UserLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .newcomer:  Copy.Achievements.newcomer
        case .explorer:  Copy.Achievements.explorer
        case .committed: Copy.Achievements.committed
        case .dedicated: Copy.Achievements.dedicated
        case .champion:  Copy.Achievements.champion
        case .legend:    Copy.Achievements.legend
        }
    }

    var color: Color {
        switch self {
        case .newcomer:  AppColour.achievementBronze
        case .explorer:  AppColour.achievementSilver
        case .committed: AppColour.achievementGold
        case .dedicated: AppColour.achievementPlatinum
        case .champion:  AppColour.achievementDiamond
        case .legend:    AppColour.achievementLegend
        }
    }

    var icon: String {
        switch self {
        case .newcomer:  "leaf.fill"
        case .explorer:  "binoculars.fill"
        case .committed: "flame.fill"
        case .dedicated: "star.fill"
        case .champion:  "diamond.fill"
        case .legend:    "crown.fill"
        }
    }

    var minDays: Int {
        switch self {
        case .newcomer:  0
        case .explorer:  7
        case .committed: 30
        case .dedicated: 90
        case .champion:  180
        case .legend:    365
        }
    }

    /// Days required to reach the next level, or nil if already at max.
    var nextLevelDays: Int? {
        guard let next = Self.allCases.first(where: { $0.rawValue == rawValue + 1 }) else { return nil }
        return next.minDays
    }

    var description: String {
        switch self {
        case .newcomer:  Copy.Achievements.newcomerDescription
        case .explorer:  Copy.Achievements.explorerDescription
        case .committed: Copy.Achievements.committedDescription
        case .dedicated: Copy.Achievements.dedicatedDescription
        case .champion:  Copy.Achievements.championDescription
        case .legend:    Copy.Achievements.legendDescription
        }
    }

    /// Determine level from total days tracked.
    static func from(days: Int) -> UserLevel {
        for level in Self.allCases.reversed() {
            if days >= level.minDays { return level }
        }
        return .newcomer
    }
}

// MARK: - AchievementCategory

enum AchievementCategory: String, CaseIterable {
    case streak
    case milestone
    case record
    case consistency
}

// MARK: - Achievement

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    var isUnlocked: Bool
    var unlockedDate: Date?
}

// MARK: - ActiveStreaks

struct ActiveStreaks {
    var activityStreak: Int = 0
    var sleepStreak: Int = 0
    var recoveryStreak: Int = 0
    var checkInStreak: Int = 0
    var masterStreak: Int = 0

    var longestActivityStreak: Int = 0
    var longestSleepStreak: Int = 0
    var longestRecoveryStreak: Int = 0
    var longestCheckInStreak: Int = 0
    var longestMasterStreak: Int = 0

    /// The single best active streak across all categories.
    var bestCurrent: Int {
        max(activityStreak, sleepStreak, recoveryStreak, checkInStreak, masterStreak)
    }
}

// MARK: - GamificationEngine

/// Computes user progression level, active streaks, and achievement unlocks
/// from on-device health data. Inspired by WHOOP's levels and streak system.
@Observable
final class GamificationEngine {

    // MARK: - Published State

    private(set) var currentLevel: UserLevel = .newcomer
    private(set) var streaks: ActiveStreaks = ActiveStreaks()
    private(set) var achievements: [Achievement] = []
    private(set) var totalDaysTracked: Int = 0

    /// Achievements unlocked within the last 7 days.
    var recentlyUnlocked: [Achievement] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return achievements.filter { $0.isUnlocked && ($0.unlockedDate ?? .distantPast) >= cutoff }
    }

    /// Progress toward the next level (0.0 – 1.0). Returns 1.0 if already at max level.
    var progressToNextLevel: Double {
        guard let nextDays = currentLevel.nextLevelDays else { return 1.0 }
        let currentMin = currentLevel.minDays
        let range = nextDays - currentMin
        guard range > 0 else { return 1.0 }
        return min(1.0, max(0.0, Double(totalDaysTracked - currentMin) / Double(range)))
    }

    // MARK: - Compute

    /// Main entry point: compute level, streaks, and achievements from health data.
    ///
    /// - Parameters:
    ///   - store: The on-device health data store.
    ///   - sessionDays: Total days the user has been using the app.
    ///   - scores: Daily overall health scores sorted chronologically.
    ///   - timeSeries: Optional in-memory time series to avoid redundant full-store reads.
    func compute(
        from store: HealthDataStore,
        sessionDays: Int,
        scores: [(date: Date, score: Int)],
        timeSeries: [HealthMetric: MetricTimeSeries]? = nil
    ) {
        totalDaysTracked = sessionDays
        currentLevel = UserLevel.from(days: sessionDays)

        let allTimeSeries: [HealthMetric: MetricTimeSeries]
        if let timeSeries {
            allTimeSeries = timeSeries
        } else {
            allTimeSeries = MainActor.assumeIsolated { store.loadAllTimeSeries() }
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build per-day lookups
        let stepsByDay = buildDayMap(from: allTimeSeries[.steps])
        let exerciseByDay = buildDayMap(from: allTimeSeries[.exerciseMinutes])
        let sleepByDay = buildDayMap(from: allTimeSeries[.sleepDuration])
        let scoresByDay = buildScoreDayMap(from: scores, calendar: calendar)

        // Compute streaks
        streaks = computeStreaks(
            stepsByDay: stepsByDay,
            exerciseByDay: exerciseByDay,
            sleepByDay: sleepByDay,
            scoresByDay: scoresByDay,
            today: today,
            calendar: calendar
        )

        // Capture previous state for change detection
        let previouslyUnlockedIds = Set(achievements.filter(\.isUnlocked).map(\.id))
        let previousLevel = currentLevel

        // Evaluate achievements
        achievements = evaluateAchievements(
            sessionDays: sessionDays,
            streaks: streaks,
            stepsByDay: stepsByDay,
            exerciseByDay: exerciseByDay,
            sleepByDay: sleepByDay,
            scoresByDay: scoresByDay,
            allTimeSeries: allTimeSeries,
            calendar: calendar,
            today: today
        )

        // Track newly unlocked achievements
        let newlyUnlocked = achievements.filter { $0.isUnlocked && !previouslyUnlockedIds.contains($0.id) }
        let didLevelUp = currentLevel > previousLevel && !previouslyUnlockedIds.isEmpty
        let newLevelName = currentLevel.displayName
        if !newlyUnlocked.isEmpty || didLevelUp {
            Task { @MainActor in
                for achievement in newlyUnlocked {
                    AppAnalytics.shared.trackAchievementUnlocked(
                        id: achievement.id,
                        title: achievement.title,
                        category: achievement.category.rawValue
                    )
                }
                if didLevelUp {
                    AppAnalytics.shared.trackLevelUp(
                        newLevel: newLevelName,
                        totalDaysTracked: sessionDays
                    )
                }
            }
        }
    }

    // MARK: - Day Map Builders

    /// Builds a dictionary mapping "yyyy-MM-dd" -> value for quick day lookups.
    private func buildDayMap(from series: MetricTimeSeries?) -> [String: Double] {
        guard let samples = series?.samples else { return [:] }
        let formatter = Self.dayFormatter
        var map: [String: Double] = [:]
        for sample in samples {
            map[formatter.string(from: sample.date)] = sample.value
        }
        return map
    }

    private func buildScoreDayMap(from scores: [(date: Date, score: Int)], calendar: Calendar) -> [String: Int] {
        let formatter = Self.dayFormatter
        var map: [String: Int] = [:]
        for entry in scores {
            map[formatter.string(from: entry.date)] = entry.score
        }
        return map
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Streak Computation

    private func computeStreaks(
        stepsByDay: [String: Double],
        exerciseByDay: [String: Double],
        sleepByDay: [String: Double],
        scoresByDay: [String: Int],
        today: Date,
        calendar: Calendar
    ) -> ActiveStreaks {
        var result = ActiveStreaks()
        let formatter = Self.dayFormatter

        // Walk backwards from today counting consecutive qualifying days
        var activityCurrent = 0
        var sleepCurrent = 0
        var recoveryCurrent = 0
        var masterCurrent = 0

        var activityLongest = 0
        var sleepLongest = 0
        var recoveryLongest = 0
        var masterLongest = 0

        // First pass: current streaks (walk back from today)
        for offset in 0..<3650 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let key = formatter.string(from: date)

            let meetsActivity = meetsActivityGoal(steps: stepsByDay[key], exercise: exerciseByDay[key])
            let meetsSleep = meetsSleepGoal(sleep: sleepByDay[key])
            let meetsRecovery = meetsRecoveryGoal(score: scoresByDay[key])

            if meetsActivity { activityCurrent += 1 } else if offset > 0 { break }
            if meetsSleep { sleepCurrent += 1 }
            if meetsRecovery { recoveryCurrent += 1 }

            // Master streak requires all three on the same day
            let meetsAll = meetsActivity && meetsSleep && meetsRecovery
            if meetsAll { masterCurrent += 1 }

            // Stop when none qualify (streak broken for all remaining)
            if !meetsActivity && !meetsSleep && !meetsRecovery && offset > 0 { break }
        }

        // For sleep/recovery/master, we need a proper backward walk that stops at first miss
        sleepCurrent = countConsecutiveStreak(from: today, calendar: calendar, formatter: formatter) { key in
            meetsSleepGoal(sleep: sleepByDay[key])
        }
        recoveryCurrent = countConsecutiveStreak(from: today, calendar: calendar, formatter: formatter) { key in
            meetsRecoveryGoal(score: scoresByDay[key])
        }
        activityCurrent = countConsecutiveStreak(from: today, calendar: calendar, formatter: formatter) { key in
            meetsActivityGoal(steps: stepsByDay[key], exercise: exerciseByDay[key])
        }
        masterCurrent = countConsecutiveStreak(from: today, calendar: calendar, formatter: formatter) { key in
            let a = meetsActivityGoal(steps: stepsByDay[key], exercise: exerciseByDay[key])
            let s = meetsSleepGoal(sleep: sleepByDay[key])
            let r = meetsRecoveryGoal(score: scoresByDay[key])
            return a && s && r
        }

        // Second pass: find longest historical streaks
        activityLongest = findLongestStreak(dayMap: stepsByDay, exerciseMap: exerciseByDay, calendar: calendar) { steps, exercise in
            meetsActivityGoal(steps: steps, exercise: exercise)
        }
        sleepLongest = findLongestStreak(singleMap: sleepByDay, calendar: calendar) { value in
            value != nil && value! >= 7.0
        }
        recoveryLongest = findLongestScoreStreak(scoresByDay: scoresByDay, calendar: calendar) { score in
            score != nil && score! > 75
        }
        masterLongest = findLongestMasterStreak(
            stepsByDay: stepsByDay,
            exerciseByDay: exerciseByDay,
            sleepByDay: sleepByDay,
            scoresByDay: scoresByDay,
            calendar: calendar
        )

        result.activityStreak = activityCurrent
        result.sleepStreak = sleepCurrent
        result.recoveryStreak = recoveryCurrent
        result.masterStreak = masterCurrent
        result.checkInStreak = sessionDaysCheckInStreak(scoresByDay: scoresByDay, today: today, calendar: calendar)

        result.longestActivityStreak = max(activityLongest, activityCurrent)
        result.longestSleepStreak = max(sleepLongest, sleepCurrent)
        result.longestRecoveryStreak = max(recoveryLongest, recoveryCurrent)
        result.longestCheckInStreak = max(result.checkInStreak, findLongestCheckInStreak(scoresByDay: scoresByDay, calendar: calendar))
        result.longestMasterStreak = max(masterLongest, masterCurrent)

        return result
    }

    // MARK: - Streak Helpers

    private func countConsecutiveStreak(
        from today: Date,
        calendar: Calendar,
        formatter: DateFormatter,
        qualifies: (String) -> Bool
    ) -> Int {
        var count = 0
        for offset in 0..<3650 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let key = formatter.string(from: date)
            if qualifies(key) {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    private func meetsActivityGoal(steps: Double?, exercise: Double?) -> Bool {
        let stepsOk = (steps ?? 0) >= 10_000
        let exerciseOk = (exercise ?? 0) >= 30
        return stepsOk || exerciseOk
    }

    private func meetsSleepGoal(sleep: Double?) -> Bool {
        (sleep ?? 0) >= 7.0
    }

    private func meetsRecoveryGoal(score: Int?) -> Bool {
        (score ?? 0) > 75
    }

    private func sessionDaysCheckInStreak(scoresByDay: [String: Int], today: Date, calendar: Calendar) -> Int {
        // Check-in streak: consecutive days with a score entry (proxy for app usage)
        let formatter = Self.dayFormatter
        return countConsecutiveStreak(from: today, calendar: calendar, formatter: formatter) { key in
            scoresByDay[key] != nil
        }
    }

    // MARK: - Longest Streak Finders

    private func findLongestStreak(
        dayMap: [String: Double],
        exerciseMap: [String: Double],
        calendar: Calendar,
        qualifies: (Double?, Double?) -> Bool
    ) -> Int {
        let allKeys = Set(dayMap.keys).union(exerciseMap.keys)
        guard !allKeys.isEmpty else { return 0 }

        let formatter = Self.dayFormatter
        let dates = allKeys.compactMap { formatter.date(from: $0) }.sorted()
        guard let first = dates.first, let last = dates.last else { return 0 }

        var longest = 0
        var current = 0
        var date = first
        while date <= last {
            let key = formatter.string(from: date)
            if qualifies(dayMap[key], exerciseMap[key]) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return longest
    }

    private func findLongestStreak(
        singleMap: [String: Double],
        calendar: Calendar,
        qualifies: (Double?) -> Bool
    ) -> Int {
        guard !singleMap.isEmpty else { return 0 }
        let formatter = Self.dayFormatter
        let dates = singleMap.keys.compactMap { formatter.date(from: $0) }.sorted()
        guard let first = dates.first, let last = dates.last else { return 0 }

        var longest = 0
        var current = 0
        var date = first
        while date <= last {
            let key = formatter.string(from: date)
            if qualifies(singleMap[key]) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return longest
    }

    private func findLongestScoreStreak(
        scoresByDay: [String: Int],
        calendar: Calendar,
        qualifies: (Int?) -> Bool
    ) -> Int {
        guard !scoresByDay.isEmpty else { return 0 }
        let formatter = Self.dayFormatter
        let dates = scoresByDay.keys.compactMap { formatter.date(from: $0) }.sorted()
        guard let first = dates.first, let last = dates.last else { return 0 }

        var longest = 0
        var current = 0
        var date = first
        while date <= last {
            let key = formatter.string(from: date)
            if qualifies(scoresByDay[key]) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return longest
    }

    private func findLongestCheckInStreak(scoresByDay: [String: Int], calendar: Calendar) -> Int {
        findLongestScoreStreak(scoresByDay: scoresByDay, calendar: calendar) { $0 != nil }
    }

    private func findLongestMasterStreak(
        stepsByDay: [String: Double],
        exerciseByDay: [String: Double],
        sleepByDay: [String: Double],
        scoresByDay: [String: Int],
        calendar: Calendar
    ) -> Int {
        let allKeys = Set(stepsByDay.keys)
            .union(exerciseByDay.keys)
            .union(sleepByDay.keys)
            .union(scoresByDay.keys)
        guard !allKeys.isEmpty else { return 0 }

        let formatter = Self.dayFormatter
        let dates = allKeys.compactMap { formatter.date(from: $0) }.sorted()
        guard let first = dates.first, let last = dates.last else { return 0 }

        var longest = 0
        var current = 0
        var date = first
        while date <= last {
            let key = formatter.string(from: date)
            let a = meetsActivityGoal(steps: stepsByDay[key], exercise: exerciseByDay[key])
            let s = meetsSleepGoal(sleep: sleepByDay[key])
            let r = meetsRecoveryGoal(score: scoresByDay[key])
            if a && s && r {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return longest
    }

    // MARK: - Achievements

    private func evaluateAchievements(
        sessionDays: Int,
        streaks: ActiveStreaks,
        stepsByDay: [String: Double],
        exerciseByDay: [String: Double],
        sleepByDay: [String: Double],
        scoresByDay: [String: Int],
        allTimeSeries: [HealthMetric: MetricTimeSeries],
        calendar: Calendar,
        today: Date
    ) -> [Achievement] {
        let now = Date()
        let definitions = Self.achievementDefinitions
        return definitions.map { def in
            let unlocked = def.condition(
                sessionDays, streaks, stepsByDay, exerciseByDay, sleepByDay, scoresByDay, allTimeSeries, calendar, today
            )
            return Achievement(
                id: def.id,
                title: def.title,
                description: def.description,
                icon: def.icon,
                category: def.category,
                isUnlocked: unlocked,
                unlockedDate: unlocked ? now : nil
            )
        }
    }

    // MARK: - Achievement Definitions

    private struct AchievementDef {
        let id: String
        let title: String
        let description: String
        let icon: String
        let category: AchievementCategory
        let condition: (
            _ sessionDays: Int,
            _ streaks: ActiveStreaks,
            _ stepsByDay: [String: Double],
            _ exerciseByDay: [String: Double],
            _ sleepByDay: [String: Double],
            _ scoresByDay: [String: Int],
            _ allTimeSeries: [HealthMetric: MetricTimeSeries],
            _ calendar: Calendar,
            _ today: Date
        ) -> Bool
    }

    private static let achievementDefinitions: [AchievementDef] = [

        // --- Milestone ---

        AchievementDef(
            id: "first_green_day",
            title: Copy.Achievements.firstGreenDayTitle,
            description: Copy.Achievements.firstGreenDayDescription,
            icon: "checkmark.circle.fill",
            category: .milestone
        ) { _, _, _, _, _, scoresByDay, _, _, _ in
            scoresByDay.values.contains { $0 > 75 }
        },

        AchievementDef(
            id: "first_week",
            title: Copy.Achievements.firstWeekTitle,
            description: Copy.Achievements.firstWeekDescription,
            icon: "calendar.badge.checkmark",
            category: .milestone
        ) { sessionDays, _, _, _, _, _, _, _, _ in
            sessionDays >= 7
        },

        AchievementDef(
            id: "data_scholar",
            title: Copy.Achievements.dataScholarTitle,
            description: Copy.Achievements.dataScholarDescription,
            icon: "books.vertical.fill",
            category: .milestone
        ) { sessionDays, _, _, _, _, _, _, _, _ in
            sessionDays >= 60
        },

        AchievementDef(
            id: "centurion",
            title: Copy.Achievements.centurionTitle,
            description: Copy.Achievements.centurionDescription,
            icon: "laurel.leading",
            category: .milestone
        ) { sessionDays, _, _, _, _, _, _, _, _ in
            sessionDays >= 100
        },

        AchievementDef(
            id: "half_year_hero",
            title: Copy.Achievements.halfYearHeroTitle,
            description: Copy.Achievements.halfYearHeroDescription,
            icon: "star.circle.fill",
            category: .milestone
        ) { sessionDays, _, _, _, _, _, _, _, _ in
            sessionDays >= 180
        },

        AchievementDef(
            id: "year_one",
            title: Copy.Achievements.yearOneTitle,
            description: Copy.Achievements.yearOneDescription,
            icon: "crown.fill",
            category: .milestone
        ) { sessionDays, _, _, _, _, _, _, _, _ in
            sessionDays >= 365
        },

        // --- Streak ---

        AchievementDef(
            id: "streak_7_activity",
            title: Copy.Achievements.weekWarriorTitle,
            description: Copy.Achievements.weekWarriorDescription,
            icon: "figure.run",
            category: .streak
        ) { _, streaks, _, _, _, _, _, _, _ in
            streaks.longestActivityStreak >= 7
        },

        AchievementDef(
            id: "streak_30_activity",
            title: Copy.Achievements.ironWillTitle,
            description: Copy.Achievements.ironWillDescription,
            icon: "bolt.shield.fill",
            category: .streak
        ) { _, streaks, _, _, _, _, _, _, _ in
            streaks.longestActivityStreak >= 30
        },

        AchievementDef(
            id: "streak_100_activity",
            title: Copy.Achievements.hundredDayHammerTitle,
            description: Copy.Achievements.hundredDayHammerDescription,
            icon: "flame.circle.fill",
            category: .streak
        ) { _, streaks, _, _, _, _, _, _, _ in
            streaks.longestActivityStreak >= 100
        },

        AchievementDef(
            id: "sleep_champion",
            title: Copy.Achievements.sleepChampionTitle,
            description: Copy.Achievements.sleepChampionDescription,
            icon: "moon.stars.fill",
            category: .streak
        ) { _, _, _, _, sleepByDay, _, _, _, _ in
            // Check for 7 consecutive 8+ hour nights (stricter than the 7h sleep streak)
            consecutiveDaysMeeting(dayMap: sleepByDay, threshold: 8.0, required: 7)
        },

        AchievementDef(
            id: "streak_30_sleep",
            title: Copy.Achievements.dreamMachineTitle,
            description: Copy.Achievements.dreamMachineDescription,
            icon: "bed.double.fill",
            category: .streak
        ) { _, streaks, _, _, _, _, _, _, _ in
            streaks.longestSleepStreak >= 30
        },

        AchievementDef(
            id: "streak_7_recovery",
            title: Copy.Achievements.recoveryProTitle,
            description: Copy.Achievements.recoveryProDescription,
            icon: "heart.circle.fill",
            category: .streak
        ) { _, streaks, _, _, _, _, _, _, _ in
            streaks.longestRecoveryStreak >= 7
        },

        AchievementDef(
            id: "streak_30_recovery",
            title: Copy.Achievements.zenMasterTitle,
            description: Copy.Achievements.zenMasterDescription,
            icon: "sparkles",
            category: .streak
        ) { _, streaks, _, _, _, _, _, _, _ in
            streaks.longestRecoveryStreak >= 30
        },

        AchievementDef(
            id: "perfect_week",
            title: Copy.Achievements.perfectWeekTitle,
            description: Copy.Achievements.perfectWeekDescription,
            icon: "checkmark.seal.fill",
            category: .streak
        ) { _, _, _, _, _, scoresByDay, _, calendar, today in
            // Check the most recent full calendar week
            hasFullGreenWeek(scoresByDay: scoresByDay, calendar: calendar, today: today)
        },

        AchievementDef(
            id: "streak_7_master",
            title: Copy.Achievements.tripleThreatTitle,
            description: Copy.Achievements.tripleThreatDescription,
            icon: "trophy.fill",
            category: .streak
        ) { _, streaks, _, _, _, _, _, _, _ in
            streaks.longestMasterStreak >= 7
        },

        AchievementDef(
            id: "streak_30_master",
            title: Copy.Achievements.absoluteLegendTitle,
            description: Copy.Achievements.absoluteLegendDescription,
            icon: "medal.fill",
            category: .streak
        ) { _, streaks, _, _, _, _, _, _, _ in
            streaks.longestMasterStreak >= 30
        },

        // --- Record ---

        AchievementDef(
            id: "marathon_month",
            title: Copy.Achievements.marathonMonthTitle,
            description: Copy.Achievements.marathonMonthDescription,
            icon: "figure.walk",
            category: .record
        ) { _, _, stepsByDay, _, _, _, _, calendar, today in
            hasMarathonMonth(stepsByDay: stepsByDay, calendar: calendar, today: today)
        },

        AchievementDef(
            id: "peak_performer",
            title: Copy.Achievements.peakPerformerTitle,
            description: Copy.Achievements.peakPerformerDescription,
            icon: "chart.line.uptrend.xyaxis",
            category: .record
        ) { _, _, _, _, _, scoresByDay, _, _, _ in
            scoresByDay.values.contains { $0 >= 95 }
        },

        AchievementDef(
            id: "step_king",
            title: Copy.Achievements.stepKingTitle,
            description: Copy.Achievements.stepKingDescription,
            icon: "shoeprints.fill",
            category: .record
        ) { _, _, stepsByDay, _, _, _, _, _, _ in
            stepsByDay.values.contains { $0 >= 20_000 }
        },

        // --- Consistency ---

        AchievementDef(
            id: "night_owl_reformed",
            title: Copy.Achievements.nightOwlReformedTitle,
            description: Copy.Achievements.nightOwlReformedDescription,
            icon: "sunrise.fill",
            category: .consistency
        ) { _, _, _, _, sleepByDay, _, _, _, _ in
            hasSleepImprovement(sleepByDay: sleepByDay)
        },

        AchievementDef(
            id: "steady_hand",
            title: Copy.Achievements.steadyHandTitle,
            description: Copy.Achievements.steadyHandDescription,
            icon: "waveform.path.ecg",
            category: .consistency
        ) { _, _, _, _, _, scoresByDay, _, _, _ in
            hasStableScoreRun(scoresByDay: scoresByDay, days: 14, maxSpread: 10)
        },

        AchievementDef(
            id: "checkin_14",
            title: Copy.Achievements.dailyDevoteeTitle,
            description: Copy.Achievements.dailyDevoteeDescription,
            icon: "app.badge.checkmark",
            category: .consistency
        ) { _, streaks, _, _, _, _, _, _, _ in
            streaks.longestCheckInStreak >= 14
        },
    ]

    // MARK: - Achievement Condition Helpers

    /// Check if there are `required` consecutive days in `dayMap` meeting `threshold`.
    private static func consecutiveDaysMeeting(dayMap: [String: Double], threshold: Double, required: Int) -> Bool {
        let formatter = dayFormatter
        let dates = dayMap.keys.compactMap { formatter.date(from: $0) }.sorted()
        guard dates.count >= required else { return false }

        var consecutive = 0
        var previousDate: Date?
        let calendar = Calendar.current

        for date in dates {
            let key = formatter.string(from: date)
            let value = dayMap[key] ?? 0

            if let prev = previousDate {
                let daysBetween = calendar.dateComponents([.day], from: prev, to: date).day ?? 0
                if daysBetween == 1 && value >= threshold {
                    consecutive += 1
                } else if value >= threshold {
                    consecutive = 1
                } else {
                    consecutive = 0
                }
            } else if value >= threshold {
                consecutive = 1
            }

            if consecutive >= required { return true }
            previousDate = date
        }
        return false
    }

    /// Check if any full calendar week (Mon-Sun) has all green scores (> 75).
    private static func hasFullGreenWeek(scoresByDay: [String: Int], calendar: Calendar, today: Date) -> Bool {
        let formatter = dayFormatter
        let scoreSet = Set(scoresByDay.filter { $0.value > 75 }.keys)

        // Check last 52 weeks
        for weekOffset in 0..<52 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today) else { continue }
            let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))
            guard let start = monday else { continue }

            var allGreen = true
            for dayOffset in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: start) else {
                    allGreen = false
                    break
                }
                if !scoreSet.contains(formatter.string(from: day)) {
                    allGreen = false
                    break
                }
            }
            if allGreen { return true }
        }
        return false
    }

    /// Check if any calendar month has total steps > 300K.
    private static func hasMarathonMonth(stepsByDay: [String: Double], calendar: Calendar, today: Date) -> Bool {
        let formatter = dayFormatter
        // Group steps by year-month
        var monthlyTotals: [String: Double] = [:]
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        monthFormatter.timeZone = TimeZone(identifier: "UTC")

        for (key, value) in stepsByDay {
            guard let date = formatter.date(from: key) else { continue }
            let monthKey = monthFormatter.string(from: date)
            monthlyTotals[monthKey, default: 0] += value
        }
        return monthlyTotals.values.contains { $0 >= 300_000 }
    }

    /// Detect sleep improvement: a 14-day window averaging 7+ after a prior 14-day window averaging < 6.5.
    private static func hasSleepImprovement(sleepByDay: [String: Double]) -> Bool {
        let formatter = dayFormatter
        let sorted = sleepByDay.keys.compactMap { key -> (Date, Double)? in
            guard let date = formatter.date(from: key), let val = sleepByDay[key] else { return nil }
            return (date, val)
        }.sorted { $0.0 < $1.0 }

        guard sorted.count >= 28 else { return false }

        // Sliding window of 14 days
        let windowSize = 14
        for i in windowSize..<sorted.count {
            let recentWindow = sorted[(i - windowSize)..<i]
            let recentAvg = recentWindow.map(\.1).reduce(0, +) / Double(windowSize)

            if recentAvg >= 7.0 && i >= windowSize * 2 {
                let priorWindow = sorted[(i - windowSize * 2)..<(i - windowSize)]
                let priorAvg = priorWindow.map(\.1).reduce(0, +) / Double(windowSize)
                if priorAvg < 6.5 { return true }
            }
        }
        return false
    }

    /// Check if scores stay within `maxSpread` points for `days` consecutive days.
    private static func hasStableScoreRun(scoresByDay: [String: Int], days: Int, maxSpread: Int) -> Bool {
        let formatter = dayFormatter
        let sorted = scoresByDay.keys.compactMap { key -> (Date, Int)? in
            guard let date = formatter.date(from: key), let val = scoresByDay[key] else { return nil }
            return (date, val)
        }.sorted { $0.0 < $1.0 }

        guard sorted.count >= days else { return false }

        let calendar = Calendar.current
        for startIdx in 0...(sorted.count - days) {
            let window = sorted[startIdx..<(startIdx + days)]
            let windowArray = Array(window)

            // Verify consecutive days
            var isConsecutive = true
            for j in 1..<windowArray.count {
                let gap = calendar.dateComponents([.day], from: windowArray[j - 1].0, to: windowArray[j].0).day ?? 0
                if gap != 1 {
                    isConsecutive = false
                    break
                }
            }
            guard isConsecutive else { continue }

            let scores = windowArray.map(\.1)
            let spread = (scores.max() ?? 0) - (scores.min() ?? 0)
            if spread <= maxSpread { return true }
        }
        return false
    }
}
