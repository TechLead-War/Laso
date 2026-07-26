import SwiftUI

/// Three-tab navigation model for the custom bottom bar
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case live
    case explore
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Today"
        case .live: return "Live"
        case .explore: return "Biology"
        case .settings: return "Settings"
        }
    }

    var systemImageName: String {
        switch self {
        case .home: return "heart.text.clipboard"
        case .live: return "waveform.path.ecg"
        case .explore: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        }
    }
}
