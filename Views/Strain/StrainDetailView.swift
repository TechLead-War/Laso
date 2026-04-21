import SwiftUI
import Charts

// MARK: - Strain Balance

enum StrainBalance {
    case under
    case optimal
    case overreaching

    var displayName: String {
        switch self {
        case .under: return Copy.Strain.underTraining
        case .optimal: return Copy.Strain.optimal
        case .overreaching: return Copy.Strain.overreaching
        }
    }

    var color: Color {
        switch self {
        case .under: return .blue
        case .optimal: return .green
        case .overreaching: return .red
        }
    }

    var icon: String {
        switch self {
        case .under: return "arrow.down.circle.fill"
        case .optimal: return "checkmark.circle.fill"
        case .overreaching: return "exclamationmark.triangle.fill"
        }
    }

    var description: String {
        switch self {
        case .under: return Copy.Strain.underTrainingDescription
        case .optimal: return Copy.Strain.optimalDescription
        case .overreaching: return Copy.Strain.overreachingDescription
        }
    }
}

// MARK: - Daily Strain Point

struct DailyStrainPoint: Identifiable {
    let id = UUID()
    let date: Date
    let strain: Double
    let level: StrainLevel
}

// MARK: - Strain Detail View

/// Simplified Strain detail. Hero ring and 7-day chart tell the story; today's snapshot
/// compresses target, balance, and coach tip into three scannable lines. Full HR zone
/// breakdown and coach detail live behind one Learn More disclosure.
struct StrainDetailView: View {
    let strainValue: Double
    let strainLevel: StrainLevel
    let zoneMinutes: [Int: Double]
    let targetStrainRange: ClosedRange<Double>
    let trainingZone: String
    let guidanceText: String
    let weekHistory: [DailyStrainPoint]
    let strainBalance: StrainBalance
    let workoutRecoveryBand: WorkoutRecoveryBand
    let cyclePhase: CyclePhaseModifier?

    private let maxStrain: Double = 21.0

    @State private var animatedProgress: Double = 0
    @State private var showLearnMore = false

    private var progress: Double {
        min(strainValue / maxStrain, 1.0)
    }

    private var strainContext: String {
        switch strainLevel {
        case .low:          return Copy.Strain.contextLow
        case .light:        return Copy.Strain.contextLight
        case .moderate:     return Copy.Strain.contextModerate
        case .high:         return Copy.Strain.contextHigh
        case .overreaching: return Copy.Strain.contextPeak
        case .allOut:       return Copy.Strain.contextAllOut
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                heroSection
                if !weekHistory.isEmpty {
                    historySection
                }
                snapshotSection
                learnMoreSection
                disclaimerNote
            }
            .padding(.bottom, DS.space6)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(Copy.Strain.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.strainDetail)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.strainDetail)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            // Static explainer. teaches the user what this screen is about
            Text(Copy.Strain.heroExplainer)
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            ZStack {
                Circle()
                    .stroke(strainLevel.color.opacity(0.2), lineWidth: 10)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: targetStrainRange.lowerBound / maxStrain,
                          to: targetStrainRange.upperBound / maxStrain)
                    .stroke(Color.green.opacity(0.5), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(strainLevel.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: animatedProgress)

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", strainValue))
                        .font(DS.Typography.displayM)
                        .foregroundStyle(strainLevel.color)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .postHogMask()

                    Text(strainLevel.displayName)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(strainLevel.color)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(width: 130)
            }
            .onAppear { animatedProgress = progress }
            .onChange(of: strainValue) { animatedProgress = progress }

            Text(Copy.Strain.targetZoneLabel(
                String(format: "%.1f", targetStrainRange.lowerBound),
                String(format: "%.1f", targetStrainRange.upperBound)
            ))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)

            // Context line. what today means + what to do. Full width, no truncation.
            Text(strainContext)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.space2)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(strainGradient, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(strainLevel.color.opacity(DS.strokeAlpha * 2), lineWidth: 1)
        )
        .shadow(color: strainLevel.color.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal)
    }

    private var strainGradient: LinearGradient {
        LinearGradient(
            colors: [strainLevel.color.opacity(0.28), strainLevel.color.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - History Chart

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(icon: "calendar", title: Copy.Strain.sevenDayHistory)

            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(weekHistory) { point in
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Strain", point.strain)
                        )
                        .foregroundStyle(point.level.color.gradient)
                        .cornerRadius(4)
                    }

                    RuleMark(y: .value("Target Low", targetStrainRange.lowerBound))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    RuleMark(y: .value("Target High", targetStrainRange.upperBound))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartYScale(domain: 0...21)
                .chartYAxis {
                    AxisMarks(values: [0, 7, 14, 21]) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))").font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        AxisGridLine()
                    }
                }
                .frame(height: 170)

                let avgStrain = weekHistory.map(\.strain).reduce(0, +) / max(Double(weekHistory.count), 1)
                HStack(spacing: 6) {
                    Text(Copy.Strain.sevenDayAverage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 2) {
                        Text(String(format: "%.1f", avgStrain))
                            .font(.caption.weight(.bold).monospacedDigit())
                        Text(Copy.Strain.scaleSuffix)
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(StrainLevel(strain: avgStrain).displayName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(StrainLevel(strain: avgStrain).color)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(StrainLevel(strain: avgStrain).color.opacity(DS.badgeBg), in: Capsule())
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    // MARK: - Today's Snapshot (3 compact lines)

    private var snapshotSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(icon: "sparkles", title: Copy.Strain.todaySnapshot)

            VStack(spacing: 0) {
                snapshotRow(
                    icon: targetIcon,
                    iconColor: targetColor,
                    title: targetStatusTitle,
                    subtitle: Copy.Strain.targetRange(
                        String(format: "%.1f", targetStrainRange.lowerBound),
                        String(format: "%.1f", targetStrainRange.upperBound)
                    )
                )

                Divider().padding(.leading, 58)

                snapshotRow(
                    icon: strainBalance.icon,
                    iconColor: strainBalance.color,
                    title: strainBalance.displayName,
                    subtitle: strainBalance.description
                )

                Divider().padding(.leading, 58)

                snapshotRow(
                    icon: "text.bubble.fill",
                    iconColor: .indigo,
                    title: trainingZone,
                    subtitle: guidanceText,
                    subtitleLines: 3
                )
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private var targetStatusTitle: String {
        if targetStrainRange.contains(strainValue) {
            return Copy.Strain.inTarget
        }
        return strainValue < targetStrainRange.lowerBound ? Copy.Strain.belowTarget : Copy.Strain.aboveTarget
    }

    private var targetIcon: String {
        if targetStrainRange.contains(strainValue) { return "checkmark.circle.fill" }
        return strainValue < targetStrainRange.lowerBound ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }

    private var targetColor: Color {
        targetStrainRange.contains(strainValue) ? .green : .orange
    }

    private func snapshotRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        subtitleLines: Int = 2
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(iconColor.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(subtitleLines)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, DS.space3)
    }

    // MARK: - Learn More (HR Zones + Detail)

    private var learnMoreSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(isExpanded: $showLearnMore) {
                VStack(alignment: .leading, spacing: 18) {
                    zoneBreakdown
                    scaleLegend
                }
                .padding(.top, 10)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(.gray.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Strain.learnMore)
                            .font(.subheadline.weight(.semibold))
                        Text(Copy.Strain.learnMoreHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private var zoneBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Strain.heartRateZones)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(1...5, id: \.self) { zone in
                    zoneRow(zone: zone)
                }
            }
        }
    }

    private func zoneRow(zone: Int) -> some View {
        let minutes = zoneMinutes[zone] ?? 0
        let totalMinutes = max((1...5).compactMap({ zoneMinutes[$0] }).reduce(0, +), 1)
        let fraction = minutes / totalMinutes

        return HStack(spacing: 10) {
            Text("Z\(zone)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(TrainingZoneColor.color(for: zone), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(zoneName(zone))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(formatMinutes(minutes))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(TrainingZoneColor.color(for: zone))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(TrainingZoneColor.color(for: zone).opacity(0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(TrainingZoneColor.color(for: zone))
                            .frame(width: max(geo.size.width * CGFloat(fraction), 4), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private var scaleLegend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Copy.Strain.strainScaleLegend)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(StrainLevel.allCases, id: \.rawValue) { level in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level.color)
                            .frame(height: 4)
                        Text(level.displayName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimerNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(Copy.Strain.strainDisclaimer)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func zoneName(_ zone: Int) -> String {
        switch zone {
        case 1: return Copy.Strain.activeRecovery
        case 2: return Copy.Strain.fatBurn
        case 3: return Copy.Strain.aerobic
        case 4: return Copy.Strain.threshold
        case 5: return Copy.Strain.anaerobic
        default: return Copy.Strain.zoneDefault(zone)
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        if h > 0 {
            return "\(h)h \(String(format: "%02d", m))m"
        }
        return "\(m)m"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StrainDetailView(
            strainValue: 14.2,
            strainLevel: .high,
            zoneMinutes: [1: 45, 2: 30, 3: 22, 4: 15, 5: 8],
            targetStrainRange: 10.0...16.0,
            trainingZone: "Zone 2 to 3 (Aerobic Base)",
            guidanceText: "Your recovery supports moderate to high strain today. Focus on sustained aerobic work for cardiovascular benefit without overreaching.",
            weekHistory: [
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -6, to: .now)!, strain: 8.5, level: .moderate),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -5, to: .now)!, strain: 12.3, level: .moderate),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -4, to: .now)!, strain: 15.8, level: .high),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -3, to: .now)!, strain: 5.2, level: .low),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!, strain: 11.0, level: .moderate),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!, strain: 18.9, level: .overreaching),
                DailyStrainPoint(date: .now, strain: 14.2, level: .high)
            ],
            strainBalance: .optimal,
            workoutRecoveryBand: .green,
            cyclePhase: .follicular
        )
    }
}
