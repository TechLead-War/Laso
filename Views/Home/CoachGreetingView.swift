import SwiftUI

/// Context-aware greeting header that combines time of day with recovery state
/// to deliver a prescriptive one-line message alongside date and streak badge.
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
                // Context-aware prescription greeting
                Text(contextGreeting)
                    .font(.title2.weight(.bold))

                // Recovery-aware subtitle
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
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                            Text("\(streakDays)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
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

    /// Prescriptive subtitle based on recovery state and time of day.
    /// Returns nil when no recovery data is available (falls back to date-only).
    private var recoveryPrescription: String? {
        guard let state = recoveryState else { return nil }

        switch (timeOfDay, state) {
        // Morning prescriptions
        case (.morning, .green):
            return "Your body recovered well. Today's a green day."
        case (.morning, .yellow):
            return "Moderate recovery. Take it steady today."
        case (.morning, .red):
            return "Your body needs rest. Go easy today."

        // Afternoon prescriptions
        case (.afternoon, .green):
            return "Recovery is strong. Great day to push hard."
        case (.afternoon, .yellow):
            return "Moderate recovery. Take it steady today."
        case (.afternoon, .red):
            return "Recovery is low. Prioritize rest this afternoon."

        // Evening prescriptions
        case (.evening, .green):
            return "Strong recovery today. Wind down and keep it going."
        case (.evening, .yellow):
            return "Moderate day. Prioritize sleep tonight."
        case (.evening, .red):
            return "Your body needs rest. Prioritize sleep tonight."

        // Late night
        case (.night, .green):
            return "Good recovery. Get some rest to keep it up."
        case (.night, .yellow):
            return "Get to bed soon for better recovery."
        case (.night, .red):
            return "Sleep is the best thing for you right now."
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
