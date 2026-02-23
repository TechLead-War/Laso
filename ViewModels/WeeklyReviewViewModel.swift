import Foundation
import Observation

@Observable
final class WeeklyReviewViewModel {
    private let dashboardViewModel: DashboardViewModel
    private let persistence = PersistenceManager()

    var review: WeeklyReview?
    var isLoading = false

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

        let score = dashboardViewModel.overallScore.score
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

        review = WeeklyReview(
            currentScore: score,
            previousScore: previousScore,
            scoreTrend: scoreTrend,
            wins: wins,
            watchOuts: watchOuts
        )
    }

    // MARK: - Computed Helpers

    var scoreDelta: Int? {
        guard let review, let prev = review.previousScore else { return nil }
        return review.currentScore - prev
    }

    var winsCount: Int {
        review?.wins.count ?? 0
    }
}
