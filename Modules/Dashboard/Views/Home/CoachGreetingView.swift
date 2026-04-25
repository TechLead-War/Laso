import SwiftUI

/// Compact greeting header. Time-of-day kicker + date row only. No streak,
/// no prescription, no overflow menu — the recovery card is Home's single
/// content hero, and the score guide opens from tapping the card itself.
struct CoachGreetingView: View {
    /// Pass 12 BE perf: cached current calendar. `timeOfDay` is read on every
    /// Home render via the greeting line; per-render alloc is wasteful.
    private static let cal: Calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(compactGreetingLine)
                .font(DS.Typography.captionSemibold)
                .tracking(0.8)
                .foregroundStyle(AppColour.textTertiary)

            Text(compactDateLine)
                .font(DS.Typography.caption)
                .tracking(0.8)
                .foregroundStyle(AppColour.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.screenPadding)
        .padding(.top, 2)
    }

    // MARK: - Compact Header Lines

    private var compactGreetingLine: String {
        "\(contextGreeting.uppercased()) · \(weekdayString.uppercased())"
    }

    private var compactDateLine: String {
        "\(dayMonthString.uppercased()) · \(timeString)"
    }

    // Pass 8 Y: locale-aware. `.dateTime` resolves ordering / separators
    // and the time formatter respects 24h vs 12h based on `Locale.current`.
    // Weekday + day + month names are localized (e.g. "lundi" / "lunes").
    private var weekdayString: String { Date().formatted(.dateTime.weekday(.wide)) }
    private var dayMonthString: String { Date().formatted(.dateTime.day().month(.wide)) }
    private var timeString: String { Date().formatted(.dateTime.hour().minute()) }

    // MARK: - Context-Aware Greeting

    private var timeOfDay: TimeOfDay {
        let hour = Self.cal.component(.hour, from: Date())
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }

    private enum TimeOfDay {
        case morning, afternoon, evening, night
    }

    private var contextGreeting: String {
        switch timeOfDay {
        case .morning: return Copy.Home.Greeting.goodMorning
        case .afternoon: return Copy.Home.Greeting.goodAfternoon
        case .evening: return Copy.Home.Greeting.goodEvening
        case .night: return Copy.Home.Greeting.goodNight
        }
    }

}

#Preview {
    VStack(spacing: 20) {
        CoachGreetingView()
        Divider()
        CoachGreetingView()
    }
}
