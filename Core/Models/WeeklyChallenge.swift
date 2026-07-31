import Foundation

/// Computed weekly review. assembled from existing analysis, not persisted
struct WeeklyReview {
    let currentScore: Int
    let previousScore: Int?
    let scoreTrend: TrendDirection
    /// The few shown on screen. `winCount` / `alertCount` hold how many there
    /// actually were, so the stat row does not report the display cap as a total.
    let wins: [DashboardViewModel.MetricChange]
    let watchOuts: [DashboardViewModel.MetricChange]
    let winCount: Int
    let alertCount: Int
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
    let currentDailyStepTarget: Int
    let nextDailyStepTarget: Int
    let adherence: CoachAdherenceStatus
    let currentAverageDailySteps: Int
    let coachingMessage: String

    var weeklyDelta: Int { nextDailyStepTarget - currentDailyStepTarget }
}
