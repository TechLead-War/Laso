import SwiftUI

/// Compact greeting header. Shows the time-of-day kicker, the date row, and an
/// ellipsis menu for the score guide. No streak, no prescription — Home keeps
/// the recovery card as the single content hero.
struct CoachGreetingView: View {
    var onTapScoreInfo: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top) {
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

            Spacer()

            if onTapScoreInfo != nil {
                Button {
                    onTapScoreInfo?()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(DS.Typography.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Score guide")
                .accessibilityHint("Opens score breakdown")
            }
        }
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

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var weekdayString: String { Self.weekdayFormatter.string(from: Date()) }
    private var dayMonthString: String { Self.dayMonthFormatter.string(from: Date()) }
    private var timeString: String { Self.timeFormatter.string(from: Date()) }

    // MARK: - Context-Aware Greeting

    private var timeOfDay: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
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
        CoachGreetingView(onTapScoreInfo: {})
        Divider()
        CoachGreetingView()
    }
}
