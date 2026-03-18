import SwiftUI

enum WidgetStyle {
    static func readinessColor(score: Int) -> Color {
        switch score {
        case ..<50:
            return .red
        case 50..<76:
            return .yellow
        default:
            return .green
        }
    }

    static func severityColor(_ rawValue: Int) -> Color {
        switch rawValue {
        case 4...:
            return .red
        case 3:
            return .orange
        case 2:
            return .yellow
        default:
            return .blue
        }
    }

    static func debtColor(_ trend: String) -> Color {
        switch trend {
        case "worsening":
            return .red
        case "improving":
            return .green
        default:
            return .blue
        }
    }

    static func timeString(from date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}
