import SwiftUI

/// Tutorial sheet explaining the Health Score to users.
struct ScoreGuideSheet: View {
    let score: Int
    let weakestCategoryName: String?
    let appStateStore: AppStateStore

    @Environment(\.dismiss) private var dismiss
    @State private var contentTracker = SectionTracker(section: .scoreGuideContent, tab: .scoreGuide)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // MARK: - Hero
                    VStack(spacing: 16) {
                        HealthScoreRing(score: score, label: Copy.Home.ScoreGuide.healthScore, size: 120, lineWidth: 12)

                        Text(Copy.Home.ScoreGuide.title)
                            .font(.system(size: 24).weight(.semibold))

                        Text(Copy.Home.ScoreGuide.description)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.space6)
                    }
                    .padding(.top, DS.space2)

                    // MARK: - What does it mean?
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.ScoreGuide.whatDoesItMean)
                            .font(.system(size: 20.4, weight: .semibold))

                        Text(Copy.Home.ScoreGuide.whatDoesItMeanBody(score: score, weakestCategory: weakestCategoryName))
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, DS.screenPadding + DS.space5)
                    .padding(.trailing, DS.screenPadding)

                    // MARK: - Score Levels
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.ScoreGuide.scoreLevels)
                            .font(.system(size: 20.4, weight: .semibold))
                            .padding(.leading, DS.screenPadding + DS.space5)
                            .padding(.trailing, DS.screenPadding)

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
                        .padding(.horizontal, DS.screenPadding)
                    }

                    // MARK: - How it's calculated
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.ScoreGuide.howItsCalculated)
                            .font(.system(size: 20.4, weight: .semibold))
                            .padding(.leading, DS.screenPadding + DS.space5)
                            .padding(.trailing, DS.screenPadding)

                        Text(Copy.Home.ScoreGuide.howItsCalculatedBody)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .padding(.leading, DS.screenPadding + DS.space5)
                            .padding(.trailing, DS.screenPadding)

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
                        .padding(.horizontal, DS.screenPadding)
                    }

                    // MARK: - When does it update?
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.ScoreGuide.whenItUpdatesTitle)
                            .font(.system(size: 20.4, weight: .semibold))
                            .padding(.leading, DS.screenPadding + DS.space5)
                            .padding(.trailing, DS.screenPadding)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 19.2))
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)

                                Text(Copy.Home.ScoreGuide.whenItUpdatesBody)
                                    .font(.system(size: 18))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, DS.screenPadding)
                    }

                    // MARK: - Baseline callout
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill.checkmark")
                            .font(.system(size: 24))
                            .foregroundStyle(.purple)

                        Text(Copy.Home.ScoreGuide.baselineCallout)
                            .font(.system(size: 18))
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.purple.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, DS.screenPadding)

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
                        appStateStore.markScoreGuideSeen()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.system(size: 18).weight(.medium))
                    .padding(.bottom, DS.space6)

                    Text(Copy.Analysis.RiskDetail.disclaimer)
                        .font(.system(size: 13.2))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, DS.screenPadding)
                        .padding(.top, DS.space6)
                        .padding(.bottom, DS.space4)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("screen.scoreGuide")
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
                        appStateStore.markScoreGuideSeen()
                        dismiss()
                    }
                    .font(.system(size: 18))
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
                        .font(.system(size: 18).weight(.semibold))
                    Text(label)
                        .font(.system(size: 14.4).weight(.medium))
                        .foregroundStyle(color)
                }
                Text(description)
                    .font(.system(size: 14.4))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, DS.space5)
        .padding(.vertical, DS.space3)
    }

    // MARK: - Category Row

    private func categoryRow(icon: String, color: Color, name: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19.2))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 18).weight(.medium))
                Text(detail)
                    .font(.system(size: 14.4))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, DS.space5)
        .padding(.vertical, DS.space3)
    }
}
