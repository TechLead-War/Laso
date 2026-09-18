import Foundation

/// Single source of truth for the user-facing score bands used across
/// Home, Explore, the score guide, and category rows. Before this lived
/// in code, every section had its own inline thresholds (40/55/70/85 in
/// some files, 40/60/80 in the score guide, <60 / <75 in Needs Attention)
/// — which let a single score render with contradictory labels. Always
/// route UI labelling and colour through `HealthScore.Band` so the bands
/// stay aligned everywhere.
enum HealthScoreBand: Int, CaseIterable {
    case critical       // < 40
    case needsAttention // 40..<55
    case fair           // 55..<70
    case good           // 70..<85
    case excellent      // 85...100

    /// True for bands the UI should call out to the user.
    var requiresAttention: Bool {
        switch self {
        case .critical, .needsAttention, .fair: return true
        case .good, .excellent: return false
        }
    }

    static func from(score: Int) -> HealthScoreBand {
        switch score {
        case 85...: return .excellent
        case 70...: return .good
        case 55...: return .fair
        case 40...: return .needsAttention
        default: return .critical
        }
    }
}

/// Health score (0-100) for a category or overall
struct HealthScore: Identifiable {
    let id = UUID()
    let category: HealthCategory?  // nil for overall score
    let score: Int
    let breakdown: [ScoreComponent]
    let generatedAt: Date

    var grade: String {
        Self.grade(for: score)
    }

    /// Standard 5-band grade ladder (A/B/C/D/F).
    static func grade(for score: Int) -> String {
        switch score {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }

    /// Widget-friendly grade ladder that promotes 90+ to "A+" (used by the
    /// readiness widget snapshot where the top band is the visual reward).
    static func gradeWithPlus(for score: Int) -> String {
        switch score {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        default: return "D"
        }
    }

    init(category: HealthCategory? = nil, score: Int, breakdown: [ScoreComponent] = [], generatedAt: Date = Date()) {
        self.category = category
        self.score = max(0, min(100, score))
        self.breakdown = breakdown
        self.generatedAt = generatedAt
    }
}

/// A component contributing to the health score
struct ScoreComponent: Identifiable {
    let id = UUID()
    let metric: HealthMetric
    let points: Int  // positive = bonus, negative = deduction
    let reason: String
}
