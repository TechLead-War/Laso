import SwiftUI

struct TodayWorkoutCard: View {
    let plan: WorkoutPlan
    let recoveryBand: WorkoutRecoveryBand
    let cyclePhase: CyclePhaseModifier?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: plan.zone.icon)
                        .font(DS.Typography.title3)
                        .foregroundStyle(plan.zone.tint)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(plan.zone.tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(Copy.Strain.todaysWorkout)
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(plan.title)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)

                        Text(plan.summary)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 8) {
                    workoutChip(icon: "bolt.heart.fill", text: plan.zone.rawValue, tint: plan.zone.tint)
                    workoutChip(icon: "clock", text: Copy.Strain.minutesShort(plan.targetDuration), tint: .secondary)
                    if let cyclePhase {
                        workoutChip(icon: "drop.fill", text: cyclePhase.displayName, tint: .pink)
                    }
                }

                HStack(spacing: 10) {
                    Text(recoveryBand.label)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(recoveryBand.tint)
                    Text(Copy.Strain.tapToViewWorkout)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: plan.zone.tint)
        }
        .buttonStyle(.dsPress)
    }

    private func workoutChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(DS.Typography.caption2Semibold)
            Text(text)
                .font(DS.Typography.captionMedium)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(DS.badgeBg), in: Capsule())
    }
}

struct WorkoutPlanSheet: View {
    let plan: WorkoutPlan
    let recoveryBand: WorkoutRecoveryBand
    let cyclePhase: CyclePhaseModifier?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                summaryCard

                if let note = plan.cyclePhaseNote {
                    infoCard(
                        title: Copy.Strain.cycleAdjustmentTitle,
                        detail: note,
                        icon: "drop.circle.fill",
                        tint: .pink
                    )
                } else if let cyclePhase {
                    infoCard(
                        title: Copy.Strain.cyclePhaseTitle,
                        detail: Copy.Strain.cyclePhaseDetail(cyclePhase.displayName),
                        icon: "drop.circle.fill",
                        tint: .pink
                    )
                }

                blockCard(title: Copy.Strain.warmUpTitle, block: plan.warmup, tint: AppColour.warning)

                ForEach(Array(plan.mainBlocks.enumerated()), id: \.offset) { index, block in
                    blockCard(title: Copy.Strain.mainBlockTitle(index + 1), block: block, tint: plan.zone.tint)
                }

                blockCard(title: Copy.Strain.cooldownTitle, block: plan.cooldown, tint: AppColour.info)
            }
            .padding(.horizontal)
            .padding(.vertical, DS.space5)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .navigationTitle(Copy.Strain.todaysWorkout)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(Copy.Strain.done) {
                    dismiss()
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: plan.zone.icon)
                    .font(DS.Typography.title2)
                    .foregroundStyle(plan.zone.tint)
                    .frame(width: 48, height: 48)
                    .background(plan.zone.tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.lg))

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(DS.Typography.title3)
                    Text(plan.summary)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                metricPill(value: recoveryBand.label, label: Copy.Strain.recoveryLabel, tint: recoveryBand.tint)
                metricPill(value: "\(plan.targetDuration)m", label: Copy.Strain.durationLabel, tint: plan.zone.tint)
                metricPill(value: "\(plan.estimatedCalories)", label: Copy.Strain.caloriesLabel, tint: AppColour.warning)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: plan.zone.tint)
    }

    private func infoCard(title: String, detail: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(DS.Typography.title3)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.md))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DS.Typography.subheadlineSemibold)
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: tint)
    }

    private func blockCard(title: String, block: WorkoutBlock, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(block.name)
                        .font(DS.Typography.headline)
                }

                Spacer()

                Text("\(block.duration) min")
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(DS.badgeBg), in: Capsule())
            }

            if let heartRateTarget = block.heartRateTarget {
                Text(Copy.Strain.workoutHeartRateTarget(label: heartRateTarget.label, minBPM: heartRateTarget.minBPM, maxBPM: heartRateTarget.maxBPM))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(block.exercises) { exercise in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: exercise.icon)
                            .font(DS.Typography.body)
                            .foregroundStyle(tint)
                            .frame(width: 26)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                                .font(DS.Typography.subheadlineSemibold)
                            Text(exercise.instruction)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: tint)
    }

    private func metricPill(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(tint)
            Text(label)
                .font(DS.Typography.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.space3)
        .padding(.vertical, DS.space2)
        .background(tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

private extension TrainingZone {
    var tint: Color {
        switch self {
        case .restoring:
            return AppColour.danger
        case .maintaining:
            return AppColour.warning
        case .building:
            return AppColour.success
        case .overreaching:
            return AppColour.info
        }
    }
}

private extension WorkoutRecoveryBand {
    var label: String {
        switch self {
        case .red:
            return Copy.Strain.redRecovery
        case .yellow:
            return Copy.Strain.yellowRecovery
        case .green:
            return Copy.Strain.greenRecovery
        }
    }

    var tint: Color {
        switch self {
        case .red:
            return AppColour.danger
        case .yellow:
            return AppColour.warning
        case .green:
            return AppColour.success
        }
    }
}

#Preview("Workout Card") {
    TodayWorkoutCard(
        plan: WorkoutProgrammer.generatePlan(recoveryBand: .green),
        recoveryBand: .green,
        cyclePhase: .luteal,
        action: {}
    )
    .padding()
    .background(AppColour.surfaceBase)
}
