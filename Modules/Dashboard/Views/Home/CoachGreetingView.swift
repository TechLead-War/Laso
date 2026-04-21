import SwiftUI

/// Context-aware greeting header that combines time of day with recovery state
/// to deliver a data-driven one-line observation alongside date and streak badge.
struct CoachGreetingView: View {
    var streakDays: Int = 0
    var scoreChangeFromYesterday: Int? = nil
    var currentScore: Int? = nil
    var recoveryState: DashboardViewModel.RecoveryState? = nil
    var onTapScoreInfo: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top meta row. compact uppercase greeting + date on left, overflow on right
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(compactGreetingLine)
                        .font(.system(size: 13).weight(.semibold))
                        .tracking(1.8)
                        .foregroundStyle(.secondary)

                    Text(compactDateLine)
                        .font(.system(size: 13).weight(.regular))
                        .tracking(1.8)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if onTapScoreInfo != nil {
                    Button {
                        onTapScoreInfo?()
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16).weight(.semibold))
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

            // Hero line. recovery-aware body observation (the real headline)
            if let prescription = recoveryPrescription {
                Text(prescription)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(contextGreeting)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Streak badge (only when relevant)
            if streakDays > 1 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13.2))
                    Text(Copy.Home.Greeting.streakBadge(streakDays))
                        .font(.system(size: 13.2).weight(.bold).monospacedDigit())
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, DS.space2)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, DS.screenPadding)
        .padding(.top, 2)
        .overlay(alignment: .top) {
            streakMilestoneOverlay
        }
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

    // MARK: - Streak Milestone

    @ViewBuilder
    private var streakMilestoneOverlay: some View {
        if let milestone = SessionTracker.shared.checkStreakMilestone() {
            Text(Copy.Home.Greeting.streakMilestone(milestone))
                .font(.system(size: 14.4).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, DS.space3)
                .padding(.vertical, 6)
                .background(.orange.gradient, in: Capsule())
                .transition(.move(edge: .top).combined(with: .opacity))
                .offset(y: -32)
        }
    }

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

    /// Data-driven subtitle based on recovery state and time of day.
    /// Returns nil when no recovery data is available (falls back to date-only).
    private var recoveryPrescription: String? {
        guard let state = recoveryState else { return nil }

        switch (timeOfDay, state) {
        case (.morning, .green):  return Copy.Home.Greeting.morningGreen
        case (.morning, .yellow): return Copy.Home.Greeting.morningYellow
        case (.morning, .red):    return Copy.Home.Greeting.morningRed
        case (.afternoon, .green):  return Copy.Home.Greeting.afternoonGreen
        case (.afternoon, .yellow): return Copy.Home.Greeting.afternoonYellow
        case (.afternoon, .red):    return Copy.Home.Greeting.afternoonRed
        case (.evening, .green):  return Copy.Home.Greeting.eveningGreen
        case (.evening, .yellow): return Copy.Home.Greeting.eveningYellow
        case (.evening, .red):    return Copy.Home.Greeting.eveningRed
        case (.night, .green):  return Copy.Home.Greeting.nightGreen
        case (.night, .yellow): return Copy.Home.Greeting.nightYellow
        case (.night, .red):    return Copy.Home.Greeting.nightRed
        }
    }

}

#Preview {
    VStack(spacing: 20) {
        CoachGreetingView(
            streakDays: 14,
            scoreChangeFromYesterday: 3,
            currentScore: 82,
            recoveryState: .green
        )

        Divider()

        CoachGreetingView(
            streakDays: 5,
            scoreChangeFromYesterday: -2,
            currentScore: 55,
            recoveryState: .yellow
        )

        Divider()

        CoachGreetingView(
            streakDays: 0,
            scoreChangeFromYesterday: -8,
            currentScore: 35,
            recoveryState: .red
        )
    }
}
