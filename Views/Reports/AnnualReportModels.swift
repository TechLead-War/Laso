import SwiftUI

// MARK: - Data Models

struct AnnualStats {
    let totalActiveDays: Int
    let totalExerciseHours: Double
    let totalDistanceKm: Double
    let averageDailySteps: Int
    let averageSleepHours: Double
    let sleepOver7HoursPercent: Double
}

struct AnnualCategoryScore: Identifiable {
    var id: String { category.rawValue }
    let category: HealthCategory
    let averageScore: Int
    let trend: TrendDirection
}

struct AnnualDiscovery: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let category: HealthCategory
    let month: Int
}

struct AnnualRecord: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
}
