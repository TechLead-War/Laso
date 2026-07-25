import SwiftUI

enum WidgetStyle {
    /// Single source of truth for score-band tinting across every Live Activity
    /// surface. Bands match `TodayScoreTint.from(score:)` so the ring, hero
    /// number, and accent icon always agree on the same colour for a given score.
    static func scoreBandColor(score: Int) -> Color {
        switch TodayScoreTint.from(score: score) {
        case .excellent: return AppColour.scoreOptimal
        case .good:      return AppColour.scoreGood
        case .fair:      return AppColour.scoreFair
        case .poor:      return AppColour.scorePoor
        }
    }

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

    static func timeString(from date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    /// A guaranteed-forward range for `Text(timerInterval:)` / `ProgressView(timerInterval:)`.
    /// Swift's `...` traps when `start > end`, which happens routinely once a target
    /// (bedtime, session end) passes before the next push lands — that trap crashes the
    /// widget extension. Clamp the upper bound just above the start so the range is never
    /// empty or reversed; a passed target then reads as 0:00 instead of crashing.
    static func timerRange(from start: Date = Date(), to end: Date) -> ClosedRange<Date> {
        start...max(end, start.addingTimeInterval(1))
    }
}
