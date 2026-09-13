import SwiftUI

/// The three places a person goes plus Settings: today's direction, the body
/// signals behind it, and whether what they did is working.
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case body
    case progress
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return Copy.DailyBrief.tabToday
        case .body: return Copy.DailyBrief.tabBody
        case .progress: return Copy.DailyBrief.tabProgress
        case .settings: return Copy.Settings.settings
        }
    }

    var systemImageName: String {
        switch self {
        case .home: return "sun.max"
        case .body: return "waveform.path.ecg"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }

    /// The analytics screen this tab reports as. One mapping, so tab-switch
    /// tracking and the root-level screenshot handler cannot disagree.
    var feature: AppFeature {
        switch self {
        case .home: return .home
        case .body: return .body
        case .progress: return .progress
        case .settings: return .settings
        }
    }

    var blockType: BlockType {
        switch self {
        case .home: return .tabHome
        case .body: return .tabBody
        case .progress: return .tabProgress
        case .settings: return .tabSettings
        }
    }
}
