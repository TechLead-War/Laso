import ActivityKit
import Foundation

enum TodayScoreTint: String, Codable, Hashable, Sendable {
    case excellent
    case good
    case fair
    case poor

    static func from(score: Int) -> TodayScoreTint {
        if score >= 85 {
            return .excellent
        } else if score >= 70 {
            return .good
        } else if score >= 50 {
            return .fair
        } else {
            return .poor
        }
    }

    var label: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Needs work"
        }
    }

    var symbolName: String {
        switch self {
        case .excellent:
            return "flame.fill"
        case .good:
            return "bolt.fill"
        case .fair:
            return "leaf.fill"
        case .poor:
            return "moon.zzz.fill"
        }
    }
}

struct TodayScoreActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var overallScore: Int
        var scoreTint: TodayScoreTint
        var weakestPillar: String
        var weakestPillarScore: Int?
        var steps: Int
        var stepsGoal: Int
        var hrvMs: Int?
        var restingHR: Int?
        var lastUpdated: Date

        var stepsProgress: Double {
            guard stepsGoal > 0 else { return 0 }
            return min(1.0, Double(steps) / Double(stepsGoal))
        }
    }

    var userName: String?
}
