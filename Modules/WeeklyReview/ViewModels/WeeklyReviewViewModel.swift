import Foundation
import Observation

@MainActor @Observable
final class WeeklyReviewViewModel {
    private let dashboardViewModel: DashboardViewModel
    private let persistence = PersistenceManager()
    private let calendar = Date.cal

    private static let minimumDailyStepTarget = 4000
    private static let maximumDailyStepTarget = 15000
    private static let weeklyStepIncrement = 500

    var review: WeeklyReview?
    var isLoading = false
    /// Timestamp of the most recent successful `load()`.
    /// Drives a small "Updated …" caption at the top of the screen.
    private(set) var lastUpdated: Date?

    init(dashboardViewModel: DashboardViewModel) {
        self.dashboardViewModel = dashboardViewModel
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        // Don't show a review if there's no real scored data
        guard !dashboardViewModel.analysisEngine.categoryScores.isEmpty else {
            review = nil
            return
        }

        let score = dashboardViewModel.scores.overallScore.score
        let previousScore = persistence.loadPreviousWeekScore()

        let scoreTrend: TrendDirection
        if let prev = previousScore {
            if score > prev + 2 { scoreTrend = .improving }
            else if score < prev - 2 { scoreTrend = .declining }
            else { scoreTrend = .stable }
        } else {
            scoreTrend = .stable
        }

        let summary = dashboardViewModel.focusFilteredPeriodSummary(for: .sevenDays)
        let wins = Array(summary.topImproved.prefix(3))
        let watchOuts = Array(summary.topDeclined.prefix(2))
        let coachPlan = buildProgressiveCoachPlan()

        review = WeeklyReview(
            currentScore: score,
            previousScore: previousScore,
            scoreTrend: scoreTrend,
            wins: wins,
            watchOuts: watchOuts,
            coachPlan: coachPlan
        )
        lastUpdated = Date()
    }

    // MARK: - Computed Helpers

    var scoreDelta: Int? {
        guard let review, let prev = review.previousScore else { return nil }
        return review.currentScore - prev
    }

    var winsCount: Int {
        review?.wins.count ?? 0
    }

    // MARK: - Progressive Coach

    private func buildProgressiveCoachPlan() -> ProgressiveCoachPlan? {
        guard let stepSeries = dashboardViewModel.healthKitManager.timeSeries[.steps] else { return nil }

        let weekStart = startOfWeek(for: Date())
        let today = Date()
        let elapsedDays = max(1, daysBetween(weekStart, today) + 1)

        var state = persistence.loadProgressiveCoachState() ?? ProgressiveCoachState(
            weekStart: weekStart,
            dailyStepTarget: Self.minimumDailyStepTarget,
            lastAdherence: .plateauing
        )

        if state.weekStart > weekStart {
            state = ProgressiveCoachState(
                weekStart: weekStart,
                dailyStepTarget: state.dailyStepTarget,
                lastAdherence: state.lastAdherence
            )
        }

        // Catch up if app hasn't been opened for one or more weeks.
        while state.weekStart < weekStart {
            let closedWeekStart = state.weekStart
            let closedWeekEnd = calendar.date(byAdding: .day, value: 6, to: closedWeekStart) ?? closedWeekStart
            let weeklyAverage = averageDailySteps(
                series: stepSeries,
                from: closedWeekStart,
                to: closedWeekEnd,
                expectedDays: 7
            )
            let adherence = adherenceStatus(
                averageDailySteps: weeklyAverage,
                dailyTarget: state.dailyStepTarget,
                elapsedDays: 7,
                isCurrentWeek: false
            )

            state = ProgressiveCoachState(
                weekStart: calendar.date(byAdding: .day, value: 7, to: closedWeekStart) ?? weekStart,
                dailyStepTarget: adjustedDailyTarget(
                    from: state.dailyStepTarget,
                    adherence: adherence
                ),
                lastAdherence: adherence
            )
        }

        let currentAverage = averageDailySteps(
            series: stepSeries,
            from: weekStart,
            to: today,
            expectedDays: elapsedDays
        )
        let currentAdherence = adherenceStatus(
            averageDailySteps: currentAverage,
            dailyTarget: state.dailyStepTarget,
            elapsedDays: elapsedDays,
            isCurrentWeek: true
        )
        let nextDailyTarget = adjustedDailyTarget(from: state.dailyStepTarget, adherence: currentAdherence)

        let message = coachingMessage(
            adherence: currentAdherence,
            currentTarget: state.dailyStepTarget,
            nextTarget: nextDailyTarget
        )

        // Persist current-week anchor and target so next week can adapt from this baseline.
        persistence.saveProgressiveCoachState(state)

        return ProgressiveCoachPlan(
            currentDailyStepTarget: state.dailyStepTarget,
            nextDailyStepTarget: nextDailyTarget,
            adherence: currentAdherence,
            currentAverageDailySteps: Int(currentAverage.rounded()),
            coachingMessage: message
        )
    }

    private func startOfWeek(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }

    private func averageDailySteps(
        series: MetricTimeSeries,
        from start: Date,
        to end: Date,
        expectedDays: Int
    ) -> Double {
        let samples = series.samples(from: start, to: end)
        guard expectedDays > 0 else { return 0 }

        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.date)
        }
        let totalSteps = grouped.values
            .map { daySamples in daySamples.map(\.value).reduce(0, +) }
            .reduce(0, +)

        return totalSteps / Double(expectedDays)
    }

    private func adherenceStatus(
        averageDailySteps: Double,
        dailyTarget: Int,
        elapsedDays: Int,
        isCurrentWeek: Bool
    ) -> CoachAdherenceStatus {
        guard dailyTarget > 0 else { return .plateauing }
        let ratio = averageDailySteps / Double(dailyTarget)

        if ratio >= 1.0 {
            return .keepingUp
        }
        if ratio >= 0.75 {
            return .plateauing
        }
        // During the first 2 days, avoid overreacting to low early-week volume.
        if isCurrentWeek && elapsedDays <= 2 {
            return .plateauing
        }
        return .struggling
    }

    private func adjustedDailyTarget(from currentTarget: Int, adherence: CoachAdherenceStatus) -> Int {
        let adjusted: Int
        switch adherence {
        case .keepingUp:
            adjusted = currentTarget + Self.weeklyStepIncrement
        case .plateauing:
            adjusted = currentTarget
        case .struggling:
            adjusted = currentTarget - Self.weeklyStepIncrement
        }

        return min(
            Self.maximumDailyStepTarget,
            max(Self.minimumDailyStepTarget, adjusted)
        )
    }

    private func coachingMessage(
        adherence: CoachAdherenceStatus,
        currentTarget: Int,
        nextTarget: Int
    ) -> String {
        switch adherence {
        case .keepingUp:
            return Copy.Reports.WeeklyReview.keepingUp(currentTarget: formatSteps(currentTarget), nextTarget: formatSteps(nextTarget))
        case .plateauing:
            return Copy.Reports.WeeklyReview.plateauing(currentTarget: formatSteps(currentTarget))
        case .struggling:
            return Copy.Reports.WeeklyReview.struggling(currentTarget: formatSteps(currentTarget), nextTarget: formatSteps(nextTarget))
        }
    }

    private func formatSteps(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}
