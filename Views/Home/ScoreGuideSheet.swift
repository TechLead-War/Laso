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
                        HealthScoreRing(score: 76, label: Copy.Home.ScoreGuide.healthScore, size: 120, lineWidth: 12)

                        Text(Copy.Home.ScoreGuide.title)
                            .font(.title3.weight(.semibold))

                        Text(Copy.Home.ScoreGuide.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 8)

                    // MARK: - What does it mean?
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.ScoreGuide.whatDoesItMean)
                            .font(.headline)

                        Text(Copy.Home.ScoreGuide.whatDoesItMeanBody)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // MARK: - Score Levels
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.ScoreGuide.scoreLevels)
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            scoreLevelRow(
                                range: Copy.Home.ScoreGuide.excellentRange,
                                label: Copy.Home.ScoreGuide.excellentLabel,
                                color: .green,
                                description: Copy.Home.ScoreGuide.excellentDescription
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: Copy.Home.ScoreGuide.goodRange,
                                label: Copy.Home.ScoreGuide.goodLabel,
                                color: .yellow,
                                description: Copy.Home.ScoreGuide.goodDescription
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: Copy.Home.ScoreGuide.fairRange,
                                label: Copy.Home.ScoreGuide.fairLabel,
                                color: .orange,
                                description: Copy.Home.ScoreGuide.fairDescription
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: Copy.Home.ScoreGuide.needsAttentionRange,
                                label: Copy.Home.ScoreGuide.needsAttentionLabel,
                                color: .red,
                                description: Copy.Home.ScoreGuide.needsAttentionDescription
                            )
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // MARK: - How it's calculated
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.ScoreGuide.howItsCalculated)
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 0) {
                            categoryRow(icon: "heart.fill", color: .red, name: Copy.Home.ScoreGuide.heartCardioName, detail: Copy.Home.ScoreGuide.heartCardioDetail)
                            Divider().padding(.leading, 52)
                            categoryRow(icon: "bed.double.fill", color: .indigo, name: Copy.Home.ScoreGuide.sleepName, detail: Copy.Home.ScoreGuide.sleepDetail)
                            Divider().padding(.leading, 52)
                            categoryRow(icon: "figure.run", color: .green, name: Copy.Home.ScoreGuide.activityName, detail: Copy.Home.ScoreGuide.activityDetail)
                            Divider().padding(.leading, 52)
                            categoryRow(icon: "scalemass.fill", color: .orange, name: Copy.Home.ScoreGuide.bodyVitalsName, detail: Copy.Home.ScoreGuide.bodyVitalsDetail)
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // MARK: - Recovery / Readiness
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.ScoreGuide.recoveryAndReadiness)
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(Copy.Home.ScoreGuide.readinessDescription(deviceName: DeviceMessaging.deviceName))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            recoveryFactorRow(
                                icon: "waveform.path.ecg",
                                color: .purple,
                                name: Copy.Home.ScoreGuide.hrvName,
                                detail: Copy.Home.ScoreGuide.hrvDetail
                            )
                            Divider().padding(.leading, 40)
                            recoveryFactorRow(
                                icon: "heart.fill",
                                color: .red,
                                name: Copy.Home.ScoreGuide.restingHRName,
                                detail: Copy.Home.ScoreGuide.restingHRDetail
                            )
                        }
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)

                        Text(DeviceMessaging.wearOvernightMessage)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }

                    // MARK: - Baseline callout
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill.checkmark")
                            .font(.title3)
                            .foregroundStyle(.purple)

                        Text(Copy.Home.ScoreGuide.baselineCallout)
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
                    Button(Copy.Home.ScoreGuide.gotIt) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Got It",
                            type: .scoreGuideGotIt,
                            screen: .scoreGuide,
                            metadata: [
                                "destination": "dismiss_score_guide"
                            ]
                        )
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
                    Button(Copy.Buttons.close) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Close",
                            type: .scoreGuideClose,
                            screen: .scoreGuide,
                            metadata: [
                                "destination": "dismiss_score_guide"
                            ]
                        )
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
