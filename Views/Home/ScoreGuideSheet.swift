import SwiftUI

/// One-time tutorial sheet explaining the Health Score to new users.
struct ScoreGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var contentTracker = SectionTracker(section: .scoreGuideContent, tab: .scoreGuide)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // MARK: - Hero
                    VStack(spacing: 16) {
                        HealthScoreRing(score: 76, label: "Health Score", size: 120, lineWidth: 12)

                        Text("This is your Health Score")
                            .font(.title3.weight(.semibold))

                        Text("A single number from 0 to 100 that reflects how your body is doing right now, based on your own data.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)

                    // MARK: - What does it mean?
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What does it mean?")
                            .font(.headline)

                        Text("Your score rises when your metrics are steady or improving compared to your personal baseline. It drops when something changes. This isn't a medical diagnosis — think of it as a daily check-in with your body.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // MARK: - Score Levels
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Score levels")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            scoreLevelRow(
                                range: "80–100",
                                label: "Excellent",
                                color: .green,
                                description: "Everything looks great — keep doing what you're doing."
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: "60–79",
                                label: "Good",
                                color: .yellow,
                                description: "Most things are on track with minor areas to watch."
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: "40–59",
                                label: "Fair",
                                color: .orange,
                                description: "A few metrics have shifted — worth paying attention."
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: "Below 40",
                                label: "Needs Attention",
                                color: .red,
                                description: "Several things are off from your norm — check your insights."
                            )
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // MARK: - How it's calculated
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How it's calculated")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            categoryRow(icon: "heart.fill", color: .red, name: "Heart & Cardio", detail: "Resting heart rate, HRV, and cardio fitness")
                            Divider().padding(.leading, 52)
                            categoryRow(icon: "bed.double.fill", color: .indigo, name: "Sleep", detail: "Duration, consistency, and sleep stages")
                            Divider().padding(.leading, 52)
                            categoryRow(icon: "figure.run", color: .green, name: "Activity", detail: "Steps, workouts, and energy burned")
                            Divider().padding(.leading, 52)
                            categoryRow(icon: "scalemass.fill", color: .orange, name: "Body & Vitals", detail: "Weight, body fat, blood oxygen, and more")
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // MARK: - Recovery / Readiness
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recovery & Readiness")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Readiness score (0–100) tells you how recovered your body is. It's calculated from two signals your Apple Watch measures while you sleep:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            recoveryFactorRow(
                                icon: "waveform.path.ecg",
                                color: .purple,
                                name: "Heart Rate Variability (HRV)",
                                detail: "Higher HRV means better recovery and lower stress."
                            )
                            Divider().padding(.leading, 40)
                            recoveryFactorRow(
                                icon: "heart.fill",
                                color: .red,
                                name: "Resting Heart Rate",
                                detail: "Lower resting HR means your heart is recovering well."
                            )
                        }
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        Text("Wear your Apple Watch overnight so we can update your readiness each morning.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }

                    // MARK: - Baseline callout
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill.checkmark")
                            .font(.title3)
                            .foregroundStyle(.purple)

                        Text("This score compares you to yourself — not world averages. As we learn your patterns, it becomes more accurate.")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.purple.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // MARK: - Got It
                    Button("Got It") {
                        AppAnalytics.shared.trackBlockTap(title: "Got It", type: .scoreGuideGotIt, screen: .scoreGuide)
                        contentTracker.tapped(target: "got_it")
                        UserDefaults.standard.set(true, forKey: AppKeys.App.hasSeenScoreGuide)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.subheadline.weight(.medium))
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        AppAnalytics.shared.trackBlockTap(title: "Close", type: .scoreGuideClose, screen: .scoreGuide)
                        contentTracker.tapped(target: "close")
                        UserDefaults.standard.set(true, forKey: AppKeys.App.hasSeenScoreGuide)
                        dismiss()
                    }
                    .font(.subheadline)
                }
            }
            .onAppear {
                AppAnalytics.shared.trackFeatureOpen(.scoreGuide)
                contentTracker.appeared()
            }
            .onDisappear {
                AppAnalytics.shared.trackFeatureClose(.scoreGuide)
                contentTracker.disappeared()
            }
        }
    }

    // MARK: - Score Level Row

    private func scoreLevelRow(range: String, label: String, color: Color, description: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(range)
                        .font(.subheadline.weight(.semibold))
                    Text(label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(color)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Recovery Factor Row

    private func recoveryFactorRow(icon: String, color: Color, name: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Category Row

    private func categoryRow(icon: String, color: Color, name: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
