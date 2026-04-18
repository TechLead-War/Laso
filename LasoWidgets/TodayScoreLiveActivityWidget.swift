import ActivityKit
import SwiftUI
import WidgetKit

struct TodayScoreLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayScoreActivityAttributes.self) { context in
            TodayScoreLockScreenView(context: context)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TodayScoreBadge(
                        score: context.state.overallScore,
                        tint: tintColor(for: context.state.scoreTint),
                        symbolName: context.state.scoreTint.symbolName,
                        size: 52
                    )
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StepsRing(
                        steps: context.state.steps,
                        progress: context.state.stepsProgress,
                        tint: tintColor(for: context.state.scoreTint)
                    )
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        PillarChip(
                            pillar: context.state.weakestPillar,
                            score: context.state.weakestPillarScore,
                            tint: tintColor(for: context.state.scoreTint)
                        )
                        HStack(spacing: 8) {
                            if let hrv = context.state.hrvMs {
                                VitalChip(
                                    symbolName: "waveform.path.ecg",
                                    label: "HRV",
                                    value: "\(hrv) ms",
                                    tint: tintColor(for: context.state.scoreTint)
                                )
                            }
                            if let rhr = context.state.restingHR {
                                VitalChip(
                                    symbolName: "heart.fill",
                                    label: "RHR",
                                    value: "\(rhr) bpm",
                                    tint: tintColor(for: context.state.scoreTint)
                                )
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.scoreTint.symbolName)
                    .foregroundStyle(tintColor(for: context.state.scoreTint))
            } compactTrailing: {
                Text("\(context.state.overallScore)")
                    .font(.headline.weight(.bold).monospacedDigit())
                    .foregroundStyle(tintColor(for: context.state.scoreTint))
            } minimal: {
                ZStack {
                    Circle()
                        .fill(tintColor(for: context.state.scoreTint).opacity(0.22))
                    Circle()
                        .stroke(tintColor(for: context.state.scoreTint), lineWidth: 1.5)
                    Text("\(context.state.overallScore)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(tintColor(for: context.state.scoreTint))
                }
            }
        }
    }
}

// MARK: - Lock Screen

private struct TodayScoreLockScreenView: View {
    let context: ActivityViewContext<TodayScoreActivityAttributes>

    var body: some View {
        let tint = tintColor(for: context.state.scoreTint)

        HStack(alignment: .center, spacing: 12) {
            TodayScoreBadge(
                score: context.state.overallScore,
                tint: tint,
                symbolName: context.state.scoreTint.symbolName,
                size: 60
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(greetingText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                PillarChip(
                    pillar: context.state.weakestPillar,
                    score: context.state.weakestPillarScore,
                    tint: tint
                )

                StepsProgressBar(
                    steps: context.state.steps,
                    goal: context.state.stepsGoal,
                    progress: context.state.stepsProgress,
                    tint: tint
                )

                Text("Updated ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                + Text(context.state.lastUpdated, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                if let hrv = context.state.hrvMs {
                    VitalChip(
                        symbolName: "waveform.path.ecg",
                        label: "HRV",
                        value: "\(hrv) ms",
                        tint: tint
                    )
                }
                if let rhr = context.state.restingHR {
                    VitalChip(
                        symbolName: "heart.fill",
                        label: "RHR",
                        value: "\(rhr) bpm",
                        tint: tint
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var greetingText: String {
        if let name = context.attributes.userName, name.isEmpty == false {
            return "Today \u{00B7} \(name)"
        }
        return "Today"
    }
}

// MARK: - Score Badge

private struct TodayScoreBadge: View {
    let score: Int
    let tint: Color
    let symbolName: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))
            Circle()
                .stroke(tint, lineWidth: 3)
            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint)
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.2, weight: .semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Pillar Chip

private struct PillarChip: View {
    let pillar: String
    let score: Int?
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(tint)
            Text(labelText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule())
    }

    private var labelText: String {
        if let score {
            return "Weakest: \(pillar) \(score)"
        }
        return "Weakest: \(pillar)"
    }
}

// MARK: - Vital Chip

private struct VitalChip: View {
    let symbolName: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.caption2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Steps Progress Bar

private struct StepsProgressBar: View {
    let steps: Int
    let goal: Int
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text("\(steps)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("/ \(goal)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, min(1, progress)) * geo.size.width)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Steps Ring (Dynamic Island trailing)

private struct StepsRing: View {
    let steps: Int
    let progress: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\(steps)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.22), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "figure.walk")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: 22, height: 22)
        }
    }
}

// MARK: - Tint Mapping

private func tintColor(for tint: TodayScoreTint) -> Color {
    switch tint {
    case .excellent:
        return .green
    case .good:
        return .mint
    case .fair:
        return .orange
    case .poor:
        return .red
    }
}
