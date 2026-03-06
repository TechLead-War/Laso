import SwiftUI

/// Greeting header with score, yesterday delta, streak badge, and settings button
struct CoachGreetingView: View {
    let showSettings: Binding<Bool>
    var streakDays: Int = 0
    var scoreChangeFromYesterday: Int? = nil
    var currentScore: Int? = nil
    var onTapScoreInfo: (() -> Void)? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Time-based greeting
                Text(greeting)
                    .font(.title2.weight(.bold))

                // Date subtitle with optional streak badge
                HStack(spacing: 6) {
                    Text(dateString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        case 17..<22: return "Good Evening"
        default: return "Good Night"
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
    CoachGreetingView(
        showSettings: .constant(false),
        streakDays: 14,
        scoreChangeFromYesterday: 3,
        currentScore: 72
    )
}
