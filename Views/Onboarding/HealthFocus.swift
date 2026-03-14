import SwiftUI

// MARK: - HealthFocus

enum HealthFocus: String, Codable, Identifiable, Hashable, CaseIterable {
    case sleep
    case fitness
    case heartHealth
    case weightBody
    case recovery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sleep: "Sleep"
        case .fitness: "Fitness"
        case .heartHealth: "Heart Health"
        case .weightBody: "Weight & Body"
        case .recovery: "Recovery"
        }
    }

    var systemImageName: String {
        switch self {
        case .sleep: "bed.double.fill"
        case .fitness: "figure.run"
        case .heartHealth: "heart.fill"
        case .weightBody: "scalemass.fill"
        case .recovery: "bolt.heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .sleep: .indigo
        case .fitness: .green
        case .heartHealth: .red
        case .weightBody: .orange
        case .recovery: .purple
        }
    }

    /// Maps this focus to one or more HealthCategory values for insight filtering
    var healthCategories: Set<HealthCategory> {
        switch self {
        case .sleep: [.sleep]
        case .fitness: [.activity]
        case .heartHealth: [.heart]
        case .weightBody: [.body]
        case .recovery: [.heart, .respiratory]
        }
    }

    /// All HealthCategory values covered by a set of focuses
    static func categories(for focuses: Set<HealthFocus>) -> Set<HealthCategory> {
        var result = Set<HealthCategory>()
        for focus in focuses {
            result.formUnion(focus.healthCategories)
        }
        return result
    }
}
