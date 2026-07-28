import Foundation
import SwiftUI

/// Top-level health categories grouping related metrics
enum HealthCategory: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }

    case heart
    case sleep
    case activity
    case body
    case respiratory
    case mindfulness
    case mobility
    case nutrition
    case hearing

    var displayName: String {
        switch self {
        case .heart: return "Heart & Cardio"
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .body: return "Body & Vitals"
        case .respiratory: return "Respiratory"
        case .mindfulness: return "Mindfulness"
        case .mobility: return "Mobility"
        case .nutrition: return "Nutrition"
        case .hearing: return "Hearing"
        }
    }

    var systemImageName: String {
        switch self {
        case .heart: return "heart.fill"
        case .sleep: return "bed.double.fill"
        case .activity: return "figure.run"
        case .body: return "figure.stand"
        case .respiratory: return "lungs.fill"
        case .mindfulness: return "brain.head.profile"
        case .mobility: return "figure.walk.motion"
        case .nutrition: return "fork.knife"
        case .hearing: return "ear.fill"
        }
    }

    var color: Color {
        switch self {
        case .heart: return AppColour.categoryHeart
        case .sleep: return AppColour.categorySleep
        case .activity: return AppColour.categoryActivity
        case .body: return AppColour.primary
        case .respiratory: return AppColour.accent
        case .mindfulness: return AppColour.categoryStress
        case .mobility: return AppColour.success
        case .nutrition: return AppColour.warning
        case .hearing: return AppColour.stateDefault
        }
    }

    var shortName: String {
        switch self {
        case .heart: return "Heart"
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .body: return "Body"
        case .respiratory: return "Lungs"
        case .mindfulness: return "Mind"
        case .mobility: return "Mobility"
        case .nutrition: return "Nutrition"
        case .hearing: return "Hearing"
        }
    }

    var metrics: [HealthMetric] {
        HealthMetric.allCases.filter { $0.category == self }
    }
}
