import Foundation

/// Computed weekly review — assembled from existing analysis, not persisted
struct WeeklyReview {
    let currentScore: Int
    let previousScore: Int?
    let scoreTrend: TrendDirection
    let wins: [DashboardViewModel.MetricChange]
    let watchOuts: [DashboardViewModel.MetricChange]
}
