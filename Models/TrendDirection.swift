import Foundation
import SwiftUI

/// Direction of a metric trend over time
enum TrendDirection: String, Codable {
    case improving
    case stable
    case declining

    var displayName: String {
        switch self {
        case .improving: return "Improving"
        case .stable: return "Stable"
        case .declining: return "Declining"
        }
    }

    var systemImageName: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .secondary
        case .declining: return .red
        }
    }

    var symbol: String {
        switch self {
        case .improving: return "↑"
        case .stable: return "→"
        case .declining: return "↓"
        }
    }
}
