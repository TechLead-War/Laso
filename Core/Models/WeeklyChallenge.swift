import Foundation

/// Computed weekly review. assembled from existing analysis, not persisted
struct WeeklyReview {
    let currentScore: Int
    let previousScore: Int?
    let scoreTrend: TrendDirection
    let wins: [DashboardViewModel.MetricChange]
    let watchOuts: [DashboardViewModel.MetricChange]
    let coachPlan: ProgressiveCoachPlan?
}

/// Adherence state used by the progressive weekly coach.
enum CoachAdherenceStatus: String, Codable {
    case keepingUp
    case plateauing
    case struggling

    var displayName: String {
        switch self {
        case .keepingUp: return "Keeping Up"
        case .plateauing: return "Plateauing"
        case .struggling: return "Struggling"
        }
    }
}

/// Persisted state so the coach can adjust week-to-week instead of resetting every launch.
struct ProgressiveCoachState: Codable {
    let weekStart: Date
    let dailyStepTarget: Int
    let lastAdherence: CoachAdherenceStatus
}

/// Week-specific adaptive coaching plan shown to the user.
struct ProgressiveCoachPlan {
    let weekStart: Date
    let weekEnd: Date
    let currentDailyStepTarget: Int
    let nextDailyStepTarget: Int
    let adherence: CoachAdherenceStatus
    let adherenceRatio: Double
    let currentAverageDailySteps: Int
    let coachingMessage: String

    var currentWeeklyStepTarget: Int { currentDailyStepTarget * 7 }
    var nextWeeklyStepTarget: Int { nextDailyStepTarget * 7 }
    var weeklyDelta: Int { nextDailyStepTarget - currentDailyStepTarget }
}
