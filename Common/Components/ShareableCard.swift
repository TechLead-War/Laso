import SwiftUI

/// Card type for shareable content
enum ShareCardType {
    case score(score: Int, scoreChange: Int?, streakDays: Int)
    case insight(text: String, metric: String, category: String)
}

// MARK: - Score Card

/// A shareable card displaying the user's health score, weekly change, and streak
struct ShareableScoreCard: View {
    let score: Int
    let scoreChange: Int?
    let streakDays: Int

    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    private var gradientColors: [Color] {
        switch score {
        case 80...100: return [AppColour.shareScoreHighStart, AppColour.shareScoreHighEnd]
        case 60..<80: return [AppColour.shareScoreGoodStart, AppColour.shareScoreGoodEnd]
        case 40..<60: return [AppColour.shareScoreFairStart, AppColour.shareScoreFairEnd]
        default: return [AppColour.shareScorePoorStart, AppColour.shareScorePoorEnd]
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Top bar: App name
                HStack {
                    Text("Laso")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, DS.space6)
                .padding(.top, 28)

                Spacer()

                // Center: Score ring
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(scoreColor.opacity(0.08))
                        .frame(width: 200, height: 200)

                    // Background ring
                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 14)
                        .frame(width: 160, height: 160)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: Double(score) / 100.0)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 160, height: 160)

                    // Score number
                    VStack(spacing: 2) {
                        Text("\(score)")
                            .font(DS.Typography.displayXL)
                            .foregroundStyle(.white)
                        Text("Health Score")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer().frame(height: 24)

                // Badges row
                HStack(spacing: 12) {
                    if let change = scoreChange, change != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                            Text("\(change > 0 ? "+" : "")\(change) this week")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(change > 0 ? .green : .red)
                        .padding(.horizontal, DS.space3)
                        .padding(.vertical, 6)
                        .background((change > 0 ? Color.green : Color.red).opacity(0.15), in: Capsule())
                    }

                    if streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("\(streakDays)-day streak")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, DS.space3)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                    }
                }

                Spacer()

                // Bottom tagline
                Text("Track your health with Laso")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 390, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: Date())
    }
}

// MARK: - Insight Card

/// A shareable card displaying a health insight discovery
struct ShareableInsightCard: View {
    let insightText: String
    let metricName: String
    let category: String

    private var categoryColor: Color {
        // Map category string to HealthCategory color
        switch category.lowercased() {
        case "heart", "heart & cardio": return .red
        case "sleep": return .indigo
        case "activity": return .green
        case "body", "body & vitals": return .orange
        case "respiratory": return .teal
        case "mindfulness": return .cyan
        case "mobility": return .purple
        case "nutrition": return .brown
        default: return .blue
        }
    }

    private var categoryIcon: String {
        switch category.lowercased() {
        case "heart", "heart & cardio": return "heart.fill"
        case "sleep": return "bed.double.fill"
        case "activity": return "figure.run"
        case "body", "body & vitals": return "figure.stand"
        case "respiratory": return "lungs.fill"
        case "mindfulness": return "brain.head.profile"
        case "mobility": return "figure.walk.motion"
        case "nutrition": return "fork.knife"
        default: return "sparkles"
        }
    }

    private var gradientColors: [Color] {
        [categoryColor.opacity(0.25), AppColour.shareSecondaryBackground]
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Top bar: App name
                HStack {
                    Text("Laso")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, DS.space6)
                .padding(.top, 28)

                Spacer()

                // Insight icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(categoryColor)
                }

                Spacer().frame(height: 20)

                // Category badge
                Text(category)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(categoryColor)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(categoryColor.opacity(0.15), in: Capsule())

                Spacer().frame(height: 20)

                // Main insight text
                Text(insightText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, DS.space7)

                Spacer().frame(height: 12)

                // Metric label
                Text(metricName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                // Bottom tagline
                Text("Discover your health patterns with Laso")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 390, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: Date())
    }
}

// MARK: - Previews

#Preview("Score Card - High") {
    ShareableScoreCard(score: 85, scoreChange: 5, streakDays: 14)
        .padding()
        .background(.black)
}

#Preview("Score Card - Medium") {
    ShareableScoreCard(score: 62, scoreChange: -3, streakDays: 0)
        .padding()
        .background(.black)
}

#Preview("Insight Card") {
    ShareableInsightCard(
        insightText: "Your resting heart rate has been trending down over the past 2 weeks",
        metricName: "Resting Heart Rate",
        category: "Heart"
    )
    .padding()
    .background(.black)
}
