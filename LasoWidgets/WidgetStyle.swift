import SwiftUI

enum WidgetStyle {
    static func readinessColor(score: Int) -> Color {
        switch score {
        case ..<50:
            return AppColour.scorePoor
        case 50..<76:
            return AppColour.scoreFair
        default:
            return AppColour.scoreOptimal
        }
    }

    static func severityColor(_ rawValue: Int) -> Color {
        switch rawValue {
        case 4...:
            return AppColour.danger
        case 3:
            return AppColour.warning
        case 2:
            return AppColour.scoreFair
        default:
            return AppColour.info
        }
    }

    static func debtColor(_ trend: String) -> Color {
        switch trend {
        case "worsening":
            return AppColour.danger
        case "improving":
            return AppColour.success
        default:
            return AppColour.info
        }
    }

    static func timeString(from date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}
