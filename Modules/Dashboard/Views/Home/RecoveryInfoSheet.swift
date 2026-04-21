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
                            .font(.system(size: 24).weight(.semibold))

                        Text(Copy.Home.RecoveryInfo.description)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.space5)
                    }
                    .padding(.top, DS.space2)

                    // MARK: - Score Levels
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.RecoveryInfo.scoreLevels)
                            .font(.system(size: 20.4, weight: .semibold))
                            .padding(.horizontal, DS.screenPadding)

                        VStack(spacing: 0) {
                            scoreLevelRow(
                                range: Copy.Home.RecoveryInfo.fullyRecoveredRange,
                                label: Copy.Home.RecoveryInfo.fullyRecoveredLabel,
                                color: .green,
                                description: Copy.Home.RecoveryInfo.fullyRecoveredDescription
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: Copy.Home.RecoveryInfo.moderateRange,
                                label: Copy.Home.RecoveryInfo.moderateLabel,
                                color: .yellow,
                                description: Copy.Home.RecoveryInfo.moderateDescription
                            )
                            Divider().padding(.leading, 52)
                            scoreLevelRow(
                                range: Copy.Home.RecoveryInfo.lowRange,
                                label: Copy.Home.RecoveryInfo.lowLabel,
                                color: .red,
                                description: Copy.Home.RecoveryInfo.lowDescription
                            )
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, DS.screenPadding)
                    }

                    // MARK: - How it's calculated
                    VStack(alignment: .leading, spacing: 10) {
                        Text(Copy.Home.RecoveryInfo.howItsCalculated)
                            .font(.system(size: 20.4, weight: .semibold))
                            .padding(.horizontal, DS.screenPadding)

                        Text(Copy.Home.RecoveryInfo.howItsCalculatedBody)
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DS.screenPadding)

                        VStack(spacing: 0) {
                            factorRow(
                                icon: "waveform.path.ecg",
                                color: .purple,
                                name: Copy.Home.RecoveryInfo.hrvName,
                                weight: Copy.Home.RecoveryInfo.hrvWeight,
                                detail: Copy.Home.RecoveryInfo.hrvDetail
                            )
                            Divider().padding(.leading, 52)
                            factorRow(
                                icon: "heart.fill",
                                color: .red,
                                name: Copy.Home.RecoveryInfo.restingHRName,
                                weight: Copy.Home.RecoveryInfo.restingHRWeight,
                                detail: Copy.Home.RecoveryInfo.restingHRDetail
                            )
                            Divider().padding(.leading, 52)
                            factorRow(
                                icon: "bed.double.fill",
                                color: .indigo,
                                name: Copy.Home.RecoveryInfo.sleepDurationName,
                                weight: Copy.Home.RecoveryInfo.sleepDurationWeight,
                                detail: Copy.Home.RecoveryInfo.sleepDurationDetail
                            )
                            Divider().padding(.leading, 52)
                            factorRow(
                                icon: "moon.stars.fill",
                                color: .blue,
                                name: Copy.Home.RecoveryInfo.sleepQualityName,
                                weight: Copy.Home.RecoveryInfo.sleepQualityWeight,
                                detail: Copy.Home.RecoveryInfo.sleepQualityDetail
                            )
                            Divider().padding(.leading, 52)
                            factorRow(
                                icon: "figure.run",
                                color: .green,
                                name: Copy.Home.RecoveryInfo.workoutRecoveryName,
                                weight: Copy.Home.RecoveryInfo.workoutRecoveryWeight,
                                detail: Copy.Home.RecoveryInfo.workoutRecoveryDetail
                            )
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, DS.screenPadding)
                    }

                    // MARK: - Device requirement
                    Text(Copy.Home.RecoveryInfo.wearRequirement(deviceName: DeviceMessaging.optionalDeviceName))
                        .font(.system(size: 14.4))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.screenPadding)

                    // MARK: - When does it update?
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 19.2))
                                .foregroundStyle(.blue)
                            Text(Copy.Home.RecoveryInfo.whenItUpdatesTitle)
                                .font(.system(size: 18).weight(.medium))
                        }

                        Text(Copy.Home.RecoveryInfo.whenItUpdatesBody)
                            .font(.system(size: 14.4))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, DS.screenPadding)
                    .padding(.bottom, DS.space4)

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
                        .font(.system(size: 18).weight(.medium))
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

    // MARK: - Factor Row

    private func factorRow(icon: String, color: Color, name: String, weight: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19.2))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 18).weight(.medium))
                    Text(weight)
                        .font(.system(size: 13.2))
                        .foregroundStyle(.tertiary)
                }
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
