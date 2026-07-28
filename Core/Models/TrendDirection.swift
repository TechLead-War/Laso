import Foundation
import SwiftUI

/// Direction of a metric trend over time
enum TrendDirection: String, Codable {
    case improving
    case stable
    case declining

    var displayName: String {
        switch self {
        case .improving: return "Getting better"
        case .stable: return "Steady"
        case .declining: return "Dropping"
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
        case .improving: return AppColour.success
        case .stable: return AppColour.textSecondary
        case .declining: return AppColour.danger
        }
    }

    var symbol: String {
        switch self {
        case .improving: return "↑"
        case .stable: return "→"
        case .declining: return "↓"
        }
    }

    // Arrow points in the direction the numeric value moved, independent of
    // sentiment. Color/label still come from `TrendDirection` (sentiment).
    static func arrowImageName(forChange change: Double) -> String {
        if change > 0 { return "arrow.up.right" }
        if change < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    static func arrowSymbol(forChange change: Double) -> String {
        if change > 0 { return "↑" }
        if change < 0 { return "↓" }
        return "→"
    }
}
