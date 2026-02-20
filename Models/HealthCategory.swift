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

    var displayName: String {
        switch self {
        case .heart: return "Heart & Cardio"
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .body: return "Body & Vitals"
        case .respiratory: return "Respiratory"
        case .mindfulness: return "Mindfulness"
        case .mobility: return "Mobility"
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
        }
    }

    var color: Color {
        switch self {
        case .heart: return .red
        case .sleep: return .indigo
        case .activity: return .green
        case .body: return .orange
        case .respiratory: return .teal
        case .mindfulness: return .cyan
        case .mobility: return .purple
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
        }
    }

    var metrics: [HealthMetric] {
        HealthMetric.allCases.filter { $0.category == self }
    }
}
