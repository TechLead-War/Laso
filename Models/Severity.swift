import Foundation
import SwiftUI

/// Severity level for health insights and anomalies
enum Severity: String, Codable, Comparable {
    case info
    case warning
    case critical

    var displayName: String {
        switch self {
        case .info: return "Tip"
        case .warning: return "Check this"
        case .critical: return "Needs attention"
        }
    }

    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var systemImageName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }

    static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
