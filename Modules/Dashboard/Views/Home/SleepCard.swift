import SwiftUI

/// Card showing last night's sleep duration, stage breakdown bar, and comparison to baseline
struct SleepCard: View {
    let liveVM: LiveViewModel
    let sleepBaseline: Double? // baseline hours from AnalysisEngine
    let sleepInsight: Insight? // top sleep performance insight, if any
    let onTap: () -> Void

    private var hours: Double { liveVM.sleep.lastNightSleepDuration / 3600 }

    var body: some View {
        if liveVM.sleep.hasSleepData {
            Button(action: onTap) {
                HStack(spacing: 0) {
                    // Left accent bar. indigo
                    RoundedRectangle(cornerRadius: DS.accentRadius)
                        .fill(.indigo)
                        .frame(width: 4)
                        .padding(.vertical, 6)

                    VStack(alignment: .leading, spacing: 10) {
                        // Header
                        HStack {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 20.4).weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: DS.iconSize, height: DS.iconSize)
                                .background(.indigo, in: Circle())

                            VStack(alignment: .leading, spacing: DS.space1) {
                                Text("Last Night's Sleep")
                                    .font(DS.Typography.calloutSemibold)
                                    .foregroundStyle(AppColour.textSecondary)
                                    .textCase(.uppercase)

                                HStack(spacing: 6) {
                                    Text(formatDuration(hours))
                                        .font(.system(size: 24).weight(.bold).monospacedDigit())
                                        .postHogMask()

                                    if let baseline = sleepBaseline, baseline > 0 {
                                        deltaLabel(current: hours, baseline: baseline)
                                    }
                                }
                            }

                            Spacer()

                            Text(liveVM.sleep.sleepQualityLabel)
                                .font(DS.Typography.calloutSemibold)
                                .foregroundStyle(qualityColor)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(qualityColor.opacity(DS.badgeBg), in: Capsule())

                            Image(systemName: "chevron.right")
                                .font(DS.Typography.footnoteMedium)
                                .foregroundStyle(AppColour.textTertiary)
                                .padding(.leading, DS.space1)
                        }

                        // Stage breakdown bar
                        if liveVM.sleep.hasSleepStageBreakdown {
                            stageBar
                        }

                        // Sleep impact insight
                        if let insight = sleepInsight {
                            Text(insight.summary)
                                .font(.system(size: 14.4))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        // B=MAP prompt. visible when sleep quality is poor (high motivation moment)
                        if liveVM.sleep.sleepQualityLabel == "Fair" || liveVM.sleep.sleepQualityLabel == "Poor" {
                            Text(Copy.Home.seeSleepTips)
                                .font(DS.Typography.footnoteMedium)
                                .foregroundStyle(AppColour.info)
                        }
                    }
                    .padding(.leading, DS.accentLeading)
                    .padding(.trailing, DS.accentTrailing)
                    .padding(.vertical, DS.accentVertical)
                }
                .cardStyle(tint: .indigo)
            }
            .buttonStyle(.dsPress)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Last night's sleep \(formatDuration(hours)), \(liveVM.sleep.sleepQualityLabel)")
            .accessibilityHint("View sleep details")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home.sleepCard")
        }
    }

    // MARK: - Stage Breakdown Bar

    private var stageBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let total = liveVM.sleep.lastNightDeepSleep + liveVM.sleep.lastNightREMSleep + liveVM.sleep.lastNightCoreSleep + liveVM.sleep.lastNightAwakeTime
                if total > 0 {
                    HStack(spacing: 1.5) {
                        stageSegment(duration: liveVM.sleep.lastNightDeepSleep, total: total, color: AppColour.categoryStress, width: geo.size.width)
                        stageSegment(duration: liveVM.sleep.lastNightREMSleep, total: total, color: AppColour.info, width: geo.size.width)
                        stageSegment(duration: liveVM.sleep.lastNightCoreSleep, total: total, color: AppColour.categorySleep, width: geo.size.width)
                        stageSegment(duration: liveVM.sleep.lastNightAwakeTime, total: total, color: AppColour.textTertiary, width: geo.size.width)
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            // Legend
            HStack(spacing: DS.space3) {
                stageLegend(label: "Deep", duration: liveVM.sleep.lastNightDeepSleep, color: AppColour.categoryStress)
                stageLegend(label: "REM", duration: liveVM.sleep.lastNightREMSleep, color: AppColour.info)
                stageLegend(label: "Core", duration: liveVM.sleep.lastNightCoreSleep, color: AppColour.categorySleep)
                stageLegend(label: "Awake", duration: liveVM.sleep.lastNightAwakeTime, color: AppColour.textTertiary)
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
        HStack(spacing: DS.space1) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(label) \(formatDuration(duration / 3600))")
                .font(DS.Typography.footnoteMedium)
                .foregroundStyle(AppColour.textSecondary)
                .postHogMask()
        }
    }

    // MARK: - Helpers

    private func deltaLabel(current: Double, baseline: Double) -> some View {
        let diff = current - baseline
        let percent = baseline > 0 ? (diff / baseline) * 100 : 0
        let arrow = diff >= 0 ? "+" : ""
        let labelColor: Color = diff >= 0 ? AppColour.success : AppColour.warning
        return Text("\(arrow)\(Int(percent))% vs avg")
            .font(DS.Typography.footnoteMedium)
            .foregroundStyle(labelColor)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(labelColor.opacity(DS.badgeBg), in: Capsule())
            .postHogMask()
    }

    private var qualityColor: Color {
        switch liveVM.sleep.sleepQualityLabel {
        case "Great": return AppColour.scoreOptimal
        case "Good": return AppColour.scoreGood
        case "Fair": return AppColour.warning
        default: return AppColour.danger
        }
    }

    private func formatDuration(_ hours: Double) -> String {
        let clamped = max(0, hours)
        let h = Int(clamped)
        let m = max(0, Int((clamped - Double(h)) * 60))
        if h == 0 { return "\(m)m" }
        return "\(h)h \(String(format: "%02d", m))m"
    }
}
