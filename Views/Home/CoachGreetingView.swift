import SwiftUI

/// Context-aware greeting header that combines time of day with recovery state
/// to deliver a data-driven one-line observation alongside date and streak badge.
struct CoachGreetingView: View {
    let showSettings: Binding<Bool>
    var streakDays: Int = 0
    var scoreChangeFromYesterday: Int? = nil
    var currentScore: Int? = nil
    var recoveryState: DashboardViewModel.RecoveryState? = nil
    var onTapScoreInfo: (() -> Void)? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Context-aware greeting
                Text(contextGreeting)
                    .font(.title2.weight(.bold))

                // Recovery-aware observation
                if let prescription = recoveryPrescription {
                    Text(prescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Date + streak badge
                HStack(spacing: 6) {
                    Text(dateString)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if streakDays > 1 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                            Text(Copy.Home.Greeting.streakBadge(streakDays))
                                .font(.caption.weight(.bold).monospacedDigit())
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.top, 1)
            }

            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Settings",
                    type: .settingsGear,
                    screen: .home,
                    metadata: [
                        "destination": "settings_sheet"
                    ]
                )
                showSettings.wrappedValue = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.primary.opacity(0.06), lineWidth: 0.5))
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("home.settingsButton")
        }
        .padding(.horizontal)
        .overlay(alignment: .top) {
            streakMilestoneOverlay
        }
    }

    // MARK: - Streak Milestone

    @ViewBuilder
    private var streakMilestoneOverlay: some View {
        if let milestone = SessionTracker.shared.checkStreakMilestone() {
            Text(Copy.Home.Greeting.streakMilestone(milestone))
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private var dateString: String {
        Self.dateFormatter.string(from: Date())
    }
}

#Preview {
    VStack(spacing: 20) {
        CoachGreetingView(
            showSettings: .constant(false),
            streakDays: 14,
            scoreChangeFromYesterday: 3,
            currentScore: 82,
            recoveryState: .green
        )

        Divider()

        CoachGreetingView(
            showSettings: .constant(false),
            streakDays: 5,
            scoreChangeFromYesterday: -2,
            currentScore: 55,
            recoveryState: .yellow
        )

        Divider()

        CoachGreetingView(
            showSettings: .constant(false),
            streakDays: 0,
            scoreChangeFromYesterday: -8,
            currentScore: 35,
            recoveryState: .red
        )
    }
}
