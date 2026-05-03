import Foundation

/// Health score (0-100) for a category or overall
struct HealthScore: Identifiable {
    let id = UUID()
    let category: HealthCategory?  // nil for overall score
    let score: Int
    let maxScore: Int = 100
    let breakdown: [ScoreComponent]
    let generatedAt: Date

    var percentage: Double {
        Double(score) / Double(maxScore)
    }

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

    var label: String {
        category?.displayName ?? "Overall"
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
