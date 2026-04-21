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
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(plan.zone.tint)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(plan.zone.tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Workout")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(plan.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 8) {
                    workoutChip(icon: "bolt.heart.fill", text: plan.zone.rawValue, tint: plan.zone.tint)
                    workoutChip(icon: "clock", text: "\(plan.targetDuration) min", tint: .secondary)
                    if let cyclePhase {
                        workoutChip(icon: "drop.fill", text: cyclePhase.displayName, tint: .pink)
                    }
                }

                HStack(spacing: 10) {
                    Text(recoveryBand.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(recoveryBand.tint)
                    Text("Tap to view warm-up, blocks, and cooldown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: plan.zone.tint)
        }
        .buttonStyle(.plain)
    }

    private func workoutChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(text)
                .font(.caption.weight(.medium))
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
                        title: "Cycle Adjustment",
                        detail: note,
                        icon: "drop.circle.fill",
                        tint: .pink
                    )
                } else if let cyclePhase {
                    infoCard(
                        title: "Cycle Phase",
                        detail: "Current phase: \(cyclePhase.displayName). Training stays aligned to your recovery capacity today.",
                        icon: "drop.circle.fill",
                        tint: .pink
                    )
                }

                blockCard(title: "Warm-Up", block: plan.warmup, tint: .orange)

                ForEach(Array(plan.mainBlocks.enumerated()), id: \.offset) { index, block in
                    blockCard(title: "Main Block \(index + 1)", block: block, tint: plan.zone.tint)
                }

                blockCard(title: "Cooldown", block: plan.cooldown, tint: .blue)
            }
            .padding(.horizontal)
            .padding(.vertical, DS.space5)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Today's Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: plan.zone.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(plan.zone.tint)
                    .frame(width: 48, height: 48)
                    .background(plan.zone.tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.title3.weight(.bold))
                    Text(plan.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                metricPill(value: recoveryBand.label, label: "Recovery", tint: recoveryBand.tint)
                metricPill(value: "\(plan.targetDuration)m", label: "Duration", tint: plan.zone.tint)
                metricPill(value: "\(plan.estimatedCalories)", label: "Cal", tint: .orange)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: plan.zone.tint)
    }

    private func infoCard(title: String, detail: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(block.name)
                        .font(.headline)
                }

                Spacer()

                Text("\(block.duration) min")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(DS.badgeBg), in: Capsule())
            }

            if let heartRateTarget = block.heartRateTarget {
                Text("Target: \(heartRateTarget.label) • \(heartRateTarget.minBPM)-\(heartRateTarget.maxBPM) bpm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(block.exercises) { exercise in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: exercise.icon)
                            .font(.body)
                            .foregroundStyle(tint)
                            .frame(width: 26)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                                .font(.subheadline.weight(.semibold))
                            Text(exercise.instruction)
                                .font(.caption)
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
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.space3)
        .padding(.vertical, DS.space2)
        .background(tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 12))
    }
}

private extension TrainingZone {
    var tint: Color {
        switch self {
        case .restoring:
            return .red
        case .maintaining:
            return .yellow
        case .building:
            return .green
        case .overreaching:
            return .blue
        }
    }
}

private extension WorkoutRecoveryBand {
    var label: String {
        switch self {
        case .red:
            return "Red recovery"
        case .yellow:
            return "Yellow recovery"
        case .green:
            return "Green recovery"
        }
    }

    var tint: Color {
        switch self {
        case .red:
            return .red
        case .yellow:
            return .yellow
        case .green:
            return .green
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
    .background(Color(.systemGroupedBackground))
}
