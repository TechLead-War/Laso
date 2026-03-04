import SwiftUI

/// Card showing last night's sleep duration, stage breakdown bar, and comparison to baseline
struct SleepCard: View {
    let liveVM: LiveViewModel
    let sleepBaseline: Double? // baseline hours from AnalysisEngine
    let sleepInsight: Insight? // top sleep performance insight, if any

    private var hours: Double { liveVM.sleep.lastNightSleepDuration / 3600 }

    var body: some View {
        if liveVM.sleep.hasSleepData {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Left accent bar — indigo
                    RoundedRectangle(cornerRadius: DS.accentRadius)
                        .fill(.indigo)
                        .frame(width: 4)
                        .padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 10) {
                        // Header
                        HStack {
                            Image(systemName: "moon.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: DS.iconSize, height: DS.iconSize)
                                .background(.indigo, in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last Night's Sleep")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                HStack(spacing: 6) {
                                    Text(formatDuration(hours))
                                        .font(.title3.weight(.bold).monospacedDigit())

                                    if let baseline = sleepBaseline, baseline > 0 {
                                        deltaLabel(current: hours, baseline: baseline)
                                    }
                                }
                            }

                            Spacer()

                            Text(liveVM.sleep.sleepQualityLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(qualityColor)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(qualityColor.opacity(DS.badgeBg), in: Capsule())
                        }

                        // Stage breakdown bar
                        if liveVM.sleep.hasSleepStageBreakdown {
                            stageBar
                        }

                        // Sleep impact insight
                        if let insight = sleepInsight {
                            Text(insight.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.leading, DS.accentLeading)
                    .padding(.trailing, DS.accentTrailing)
                    .padding(.vertical, DS.accentVertical)
                }
                .cardStyle(tint: .indigo)
            }
        }
    }

    // MARK: - Stage Breakdown Bar

    private var stageBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let total = liveVM.sleep.lastNightDeepSleep + liveVM.sleep.lastNightREMSleep + liveVM.sleep.lastNightCoreSleep + liveVM.sleep.lastNightAwakeTime
                if total > 0 {
                    HStack(spacing: 1.5) {
                        stageSegment(duration: liveVM.sleep.lastNightDeepSleep, total: total, color: .purple, width: geo.size.width)
                        stageSegment(duration: liveVM.sleep.lastNightREMSleep, total: total, color: .blue, width: geo.size.width)
                        stageSegment(duration: liveVM.sleep.lastNightCoreSleep, total: total, color: .cyan, width: geo.size.width)
                        stageSegment(duration: liveVM.sleep.lastNightAwakeTime, total: total, color: Color(.systemGray4), width: geo.size.width)
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            // Legend
            HStack(spacing: 12) {
                stageLegend(label: "Deep", duration: liveVM.sleep.lastNightDeepSleep, color: .purple)
                stageLegend(label: "REM", duration: liveVM.sleep.lastNightREMSleep, color: .blue)
                stageLegend(label: "Core", duration: liveVM.sleep.lastNightCoreSleep, color: .cyan)
                stageLegend(label: "Awake", duration: liveVM.sleep.lastNightAwakeTime, color: Color(.systemGray4))
            }
        }
    }

    private func stageSegment(duration: TimeInterval, total: TimeInterval, color: Color, width: CGFloat) -> some View {
        let fraction = total > 0 ? duration / total : 0
        return RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: max(width * fraction - 1.5, 0), height: 8)
    }

    private func stageLegend(label: String, duration: TimeInterval, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) \(formatDuration(duration / 3600))")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func deltaLabel(current: Double, baseline: Double) -> some View {
        let diff = current - baseline
        let percent = baseline > 0 ? (diff / baseline) * 100 : 0
        let arrow = diff >= 0 ? "+" : ""
        return Text("\(arrow)\(Int(percent))% vs avg")
            .font(.caption2.weight(.medium))
            .foregroundStyle(diff >= 0 ? .green : .orange)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background((diff >= 0 ? Color.green : Color.orange).opacity(0.1), in: Capsule())
    }

    private var qualityColor: Color {
        switch liveVM.sleep.sleepQualityLabel {
        case "Great": return .green
        case "Good": return .blue
        case "Fair": return .orange
        default: return .red
        }
    }

    private func formatDuration(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if h == 0 { return "\(m)m" }
        return "\(h)h \(String(format: "%02d", m))m"
    }
}
