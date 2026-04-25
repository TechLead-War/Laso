import SwiftUI

/// Tutorial sheet explaining how Recovery & Readiness is calculated.
struct RecoveryInfoSheet: View {
    let score: Int

    @Environment(\.dismiss) private var dismiss
    @State private var contentTracker = SectionTracker(section: .recoveryInfoContent, tab: .recoveryInfo)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Hero
                    VStack(spacing: 16) {
                        HealthScoreRing(score: score, label: "Recovery", size: 120, lineWidth: 12)

                        Text(Copy.Home.RecoveryInfo.title)
                            .font(DS.Typography.title2)

                        Text(Copy.Home.RecoveryInfo.description)
                            .font(DS.Typography.body)
                            .foregroundStyle(AppColour.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.space5)
                    }
                    .padding(.top, DS.space2)

                    // MARK: - Score Levels
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.RecoveryInfo.scoreLevels)
                            .font(DS.Typography.title3)
                            .padding(.horizontal, DS.screenPadding)

                        VStack(spacing: 0) {
                            scoreLevelRow(
                                range: Copy.Home.RecoveryInfo.fullyRecoveredRange,
                                label: Copy.Home.RecoveryInfo.fullyRecoveredLabel,
                                color: AppColour.success,
                                description: Copy.Home.RecoveryInfo.fullyRecoveredDescription
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: Copy.Home.RecoveryInfo.moderateRange,
                                label: Copy.Home.RecoveryInfo.moderateLabel,
                                color: AppColour.warning,
                                description: Copy.Home.RecoveryInfo.moderateDescription
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: Copy.Home.RecoveryInfo.lowRange,
                                label: Copy.Home.RecoveryInfo.lowLabel,
                                color: AppColour.danger,
                                description: Copy.Home.RecoveryInfo.lowDescription
                            )
                        }
                        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .padding(.horizontal, DS.screenPadding)
                    }

                    // MARK: - How it's calculated
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.RecoveryInfo.howItsCalculated)
                            .font(DS.Typography.title3)
                            .padding(.horizontal, DS.screenPadding)

                        Text(Copy.Home.RecoveryInfo.howItsCalculatedBody)
                            .font(DS.Typography.body)
                            .foregroundStyle(AppColour.textSecondary)
                            .padding(.horizontal, DS.screenPadding)

                        VStack(spacing: 0) {
                            factorRow(
                                icon: "waveform.path.ecg",
                                color: AppColour.categoryStress,
                                name: Copy.Home.RecoveryInfo.hrvName,
                                weight: Copy.Home.RecoveryInfo.hrvWeight,
                                detail: Copy.Home.RecoveryInfo.hrvDetail
                            )
                            Divider().padding(.leading, 52)
                            factorRow(
                                icon: "heart.fill",
                                color: AppColour.categoryHeart,
                                name: Copy.Home.RecoveryInfo.restingHRName,
                                weight: Copy.Home.RecoveryInfo.restingHRWeight,
                                detail: Copy.Home.RecoveryInfo.restingHRDetail
                            )
                            Divider().padding(.leading, 52)
                            factorRow(
                                icon: "bed.double.fill",
                                color: AppColour.categorySleep,
                                name: Copy.Home.RecoveryInfo.sleepDurationName,
                                weight: Copy.Home.RecoveryInfo.sleepDurationWeight,
                                detail: Copy.Home.RecoveryInfo.sleepDurationDetail
                            )
                            Divider().padding(.leading, 52)
                            factorRow(
                                icon: "moon.stars.fill",
                                color: AppColour.info,
                                name: Copy.Home.RecoveryInfo.sleepQualityName,
                                weight: Copy.Home.RecoveryInfo.sleepQualityWeight,
                                detail: Copy.Home.RecoveryInfo.sleepQualityDetail
                            )
                            Divider().padding(.leading, 52)
                            factorRow(
                                icon: "figure.run",
                                color: AppColour.success,
                                name: Copy.Home.RecoveryInfo.workoutRecoveryName,
                                weight: Copy.Home.RecoveryInfo.workoutRecoveryWeight,
                                detail: Copy.Home.RecoveryInfo.workoutRecoveryDetail
                            )
                        }
                        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                        .padding(.horizontal, DS.screenPadding)
                    }

                    // MARK: - Device requirement
                    Text(Copy.Home.RecoveryInfo.wearRequirement(deviceName: DeviceMessaging.optionalDeviceName))
                        .font(.system(size: 14.4))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.screenPadding)

                    // MARK: - When does it update?
                    VStack(alignment: .leading, spacing: DS.space2) {
                        HStack(spacing: DS.space2) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(DS.Typography.bodySemibold)
                                .foregroundStyle(AppColour.info)
                            Text(Copy.Home.RecoveryInfo.whenItUpdatesTitle)
                                .font(DS.Typography.bodyMedium)
                        }

                        Text(Copy.Home.RecoveryInfo.whenItUpdatesBody)
                            .font(DS.Typography.callout)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                    .padding()
                    .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .padding(.horizontal, DS.screenPadding)
                    .padding(.bottom, DS.space4)

                    Text(Copy.Analysis.RiskDetail.disclaimer)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textSecondary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, DS.screenPadding)
                        .padding(.top, DS.space6)
                        .padding(.bottom, DS.space4)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("screen.recoveryInfo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.Buttons.done) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Done",
                            type: .recoveryInfoDone,
                            screen: .recoveryInfo,
                            metadata: [
                                "destination": "dismiss_recovery_info"
                            ]
                        )
                        contentTracker.tapped(target: "done")
                        dismiss()
                    }
                        .font(DS.Typography.bodyMedium)
                }
            }
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.recoveryInfo)
            contentTracker.appeared()
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.recoveryInfo)
            contentTracker.disappeared()
        }
    }

    // MARK: - Score Level Row

    private func scoreLevelRow(range: String, label: String, color: Color, description: String) -> some View {
        HStack(spacing: DS.space3) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DS.space1) {
                HStack(spacing: DS.space1) {
                    Text(range)
                        .font(DS.Typography.bodySemibold)
                    Text(label)
                        .font(DS.Typography.calloutSemibold)
                        .foregroundStyle(color)
                }
                Text(description)
                    .font(DS.Typography.callout)
                    .foregroundStyle(AppColour.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, DS.space5)
        .padding(.vertical, DS.space3)
    }

    // MARK: - Factor Row

    private func factorRow(icon: String, color: Color, name: String, weight: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: DS.space3) {
            Image(systemName: icon)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DS.space1) {
                HStack(spacing: DS.space1) {
                    Text(name)
                        .font(DS.Typography.bodyMedium)
                    Text(weight)
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textTertiary)
                }
                Text(detail)
                    .font(DS.Typography.callout)
                    .foregroundStyle(AppColour.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, DS.space5)
        .padding(.vertical, DS.space3)
    }
}
