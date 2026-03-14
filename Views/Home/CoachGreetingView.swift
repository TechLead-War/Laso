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
                            Text("\(streakDays)d streak")
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
                    .font(.title3)
                    .foregroundStyle(.secondary)
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
            Text("\(milestone)-day streak!")
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
        case .morning: return "Good Morning"
        case .afternoon: return "Good Afternoon"
        case .evening: return "Good Evening"
        case .night: return "Good Night"
        }
    }

    /// Data-driven subtitle based on recovery state and time of day.
    /// Returns nil when no recovery data is available (falls back to date-only).
    private var recoveryPrescription: String? {
        guard let state = recoveryState else { return nil }

        switch (timeOfDay, state) {
        // Morning
        case (.morning, .green):
            return "Your body bounced back well. Great day for a challenge."
        case (.morning, .yellow):
            return "Decent recovery overnight. Listen to your body today."
        case (.morning, .red):
            return "Recovery is catching up. A lighter day might work well."

        // Afternoon
        case (.afternoon, .green):
            return "Still riding high on solid recovery. Keep it going."
        case (.afternoon, .yellow):
            return "Holding steady this afternoon. Pacing yourself pays off."
        case (.afternoon, .red):
            return "Recovery is still building. Your body might appreciate a gentler afternoon."

        // Evening
        case (.evening, .green):
            return "Strong day all around. Wind down and keep the streak."
        case (.evening, .yellow):
            return "Not bad today. A good night\u{2019}s sleep will help."
        case (.evening, .red):
            return "Your body might benefit from a reset. Sleep could be your best recovery tool tonight."

        // Late night
        case (.night, .green):
            return "You\u{2019}re in good shape. Get some rest to stay there."
        case (.night, .yellow):
            return "Decent day. Sleep well and tomorrow\u{2019}s looking better."
        case (.night, .red):
            return "Recovery is still building. Sleep is your strongest ally right now."
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
