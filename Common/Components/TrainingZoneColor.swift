import SwiftUI

enum TrainingZoneColor {
    static func color(for zone: Int) -> Color {
        switch zone {
        case 1: return AppColour.info
        case 2: return AppColour.success
        case 3: return AppColour.warning
        case 4: return AppColour.scoreFair
        case 5: return AppColour.danger
        default: return .gray
        }
    }
}
