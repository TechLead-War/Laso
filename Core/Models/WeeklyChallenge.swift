import Foundation

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
