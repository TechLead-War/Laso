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
        case .under: return AppColour.info
        case .optimal: return AppColour.success
        case .overreaching: return AppColour.danger
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
    // The caller rebuilds this array inside a @ViewBuilder on every parent
    // re-render, so a fresh UUID here would re-fire the selection haptic and
    // restart the bar animations. One point per calendar day, no collision.
    var id: Date { date }
    let date: Date
    let strain: Double
    let level: StrainLevel

    /// A strain of exactly zero means nothing was recorded that day. The score
    /// rises above zero for any calories, steps, distance, or active minutes,
    /// so a day the device was actually worn never lands on a flat zero.
    var hasRecordedData: Bool { strain > 0 }
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
    /// Longer daily history behind the trend card, oldest first.
    let trendPoints: [TrendSparkPoint]

    private let maxStrain: Double = 21.0

    @State private var animatedProgress: Double = 0
    @State private var showLearnMore = false
    @State private var selectedHistoryDate: Date?
    /// Latches once the drag is claimed as a scrub, so a curving finger keeps
    /// scrubbing instead of handing the touch back to the page scroll.
    @State private var isScrubbing = false

    /// Matches `MetricChartView`: below this the touch belongs to the page scroll.
    private static let scrubMinimumDrag: CGFloat = 8

    private var selectedHistoryPoint: DailyStrainPoint? {
        guard let selectedHistoryDate, !weekHistory.isEmpty else { return nil }
        return weekHistory.min(by: { lhs, rhs in
            abs(lhs.date.timeIntervalSince(selectedHistoryDate)) < abs(rhs.date.timeIntervalSince(selectedHistoryDate))
        })
    }

    private var progress: Double {
        min(strainValue / maxStrain, 1.0)
    }

    /// True only when we actually have signal: any HR-zone minutes today, OR
    /// today's strain is meaningfully above zero, OR the week's history has at
    /// least one non-zero day. Pure zero across all three means no workout/HK
    /// data flowed in — show an empty state instead of "0.0 / 21 Light day".
    private var hasData: Bool {
        if strainValue > 0 { return true }
        if zoneMinutes.values.contains(where: { $0 > 0 }) { return true }
        if weekHistory.contains(where: { $0.strain > 0 }) { return true }
        return false
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
                if hasData {
                    heroSection
                    if !weekHistory.isEmpty {
                        historySection
                    }
                    if trendPoints.count >= TrendSparkCard.minimumPoints {
                        trendsSection
                            .padding(.horizontal)
                    }
                    snapshotSection
                } else {
                    emptyStateSection
                }
                learnMoreSection
                disclaimerNote
            }
            .padding(.bottom, DS.space6)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
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
                .font(DS.Typography.captionMedium)
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
                    .stroke(AppColour.scoreGood.opacity(0.5), style: StrokeStyle(lineWidth: 10, lineCap: .round))
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

                    Text(Copy.Strain.scaleSuffix)
                        .font(DS.Typography.subheadlineSemibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(strainLevel.displayName)
                        .font(DS.Typography.footnoteMedium)
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
            .font(DS.Typography.captionSemibold)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)

            // Context line. what today means + what to do. Full width, no truncation.
            Text(strainContext)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.space2)
        }
        .padding(DS.space6)
        .frame(maxWidth: .infinity)
        .background(strainGradient, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .strokeBorder(strainLevel.color.opacity(DS.strokeAlpha * 2), lineWidth: 1)
        )
        .shadow(color: strainLevel.color.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal)
    }

    /// Honest empty state shown when no workout/HR-zone data is available
    /// today and there's no week history to fall back on. Replaces the
    /// previous "0.0 / 21 Light day for your body" silent fallback.
    private var emptyStateSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.top, DS.space3)

            Text(Copy.Strain.noWorkoutData)
                .font(DS.Typography.title3.weight(.semibold))

            Text(Copy.Strain.logWorkoutHint)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.space4)
                .padding(.bottom, DS.space4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.space4)
        .cardStyle()
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
                        if point.hasRecordedData {
                            BarMark(
                                x: .value("Day", point.date, unit: .day),
                                y: .value("Strain", point.strain)
                            )
                            .foregroundStyle(point.level.color.gradient)
                            .cornerRadius(4)
                            // Per-bar VoiceOver readout for the 7-day strain history.
                            .accessibilityLabel(Text(point.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())))
                            .accessibilityValue(Text(Copy.Strain.strainValueAndLevel(String(format: "%.1f", point.strain), point.level.displayName)))
                        } else {
                            // Full height shaded column so a day with no data reads as a
                            // gap, not as a real zero effort day.
                            BarMark(
                                x: .value("Day", point.date, unit: .day),
                                yStart: .value("Strain", 0.0),
                                yEnd: .value("Strain", maxStrain)
                            )
                            .foregroundStyle(.secondary.opacity(0.12))
                            .cornerRadius(4)
                            .accessibilityLabel(Text(point.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())))
                            .accessibilityValue(Text(Copy.Strain.noDataDay))
                        }
                    }

                    RuleMark(y: .value("Target Low", targetStrainRange.lowerBound))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    RuleMark(y: .value("Target High", targetStrainRange.upperBound))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    if let selected = selectedHistoryPoint {
                        RuleMark(x: .value("Selected Day", selected.date, unit: .day))
                            .foregroundStyle(selected.hasRecordedData ? selected.level.color.opacity(0.35) : Color.secondary.opacity(0.35))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))

                        if selected.hasRecordedData {
                            PointMark(
                                x: .value("Selected Day", selected.date, unit: .day),
                                y: .value("Strain", selected.strain)
                            )
                            .foregroundStyle(.white)
                            .symbolSize(60)

                            PointMark(
                                x: .value("Selected Day", selected.date, unit: .day),
                                y: .value("Strain", selected.strain)
                            )
                            .foregroundStyle(selected.level.color)
                            .symbolSize(24)
                        }
                    }
                }
                .chartXSelection(value: $selectedHistoryDate)
                .chartYScale(domain: 0...21)
                // Chart-level VoiceOver summary for the strain history.
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(Copy.Strain.strainOverTheLastDaysText(weekHistory.count)))
                .accessibilityValue(Text(strainChartAccessibilityValue))
                .chartYAxis {
                    AxisMarks(values: [0, 7, 14, 21]) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Copy.Strain.xText(Int(v))).font(DS.Typography.caption2)
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
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: Self.scrubMinimumDrag)
                                    .onChanged { value in
                                        // The chart fills the width of a scrolling page, so it
                                        // only takes over once the finger is clearly moving
                                        // sideways. Once scrubbing it keeps the touch, however
                                        // the finger drifts.
                                        guard isScrubbing || abs(value.translation.width) > abs(value.translation.height) else { return }
                                        isScrubbing = true
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let origin = geometry[plotFrame].origin
                                        let x = value.location.x - origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            selectedHistoryDate = date
                                        }
                                    }
                                    .onEnded { _ in isScrubbing = false }
                            )
                            .onTapGesture { location in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let origin = geometry[plotFrame].origin
                                let x = location.x - origin.x
                                if let date: Date = proxy.value(atX: x) {
                                    if let current = selectedHistoryDate,
                                       Date.cal.isDate(current, inSameDayAs: date) {
                                        selectedHistoryDate = nil
                                    } else {
                                        selectedHistoryDate = date
                                    }
                                }
                            }
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let selected = selectedHistoryPoint {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if selected.hasRecordedData {
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(String(format: "%.1f", selected.strain))
                                        .font(.callout.weight(.bold).monospacedDigit())
                                        .foregroundStyle(selected.level.color)
                                    Text(Copy.Strain.scaleSuffix)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                                Text(selected.level.displayName)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(selected.level.color)
                            } else {
                                Text(Copy.Strain.noDataDay)
                                    .font(.callout.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        .padding(DS.space1)
                    }
                }
                .sensoryFeedback(.selection, trigger: selectedHistoryPoint?.id)

                if !recordedDays.isEmpty {
                    let avgStrain = averageStrain
                    HStack(spacing: 6) {
                        Text(Copy.Strain.averageOfDaysWithData(recordedDays.count))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Text(String(format: "%.1f", avgStrain))
                                .font(DS.Typography.captionSemibold.monospacedDigit())
                            Text(Copy.Strain.scaleSuffix)
                                .font(DS.Typography.caption2Medium.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(StrainLevel(strain: avgStrain).displayName)
                            .font(DS.Typography.caption2Semibold)
                            .foregroundStyle(StrainLevel(strain: avgStrain).color)
                            .padding(.horizontal, DS.badgeH)
                            .padding(.vertical, DS.badgeV)
                            .background(StrainLevel(strain: avgStrain).color.opacity(DS.badgeBg), in: Capsule())
                    }
                }

                if recordedDays.count < weekHistory.count {
                    Text(Copy.Strain.missingDaysNote)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    // MARK: - Trends

    private var trendsSection: some View {
        TrendSection {
            TrendSparkCard(
                icon: "figure.run",
                title: Copy.Strain.title,
                value: String(format: "%.1f", strainValue),
                points: trendPoints,
                band: PersonalBand.make(from: trendPoints.map(\.value)),
                tint: strainLevel.color
            )
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
                    iconColor: AppColour.categorySleep,
                    title: trainingZone,
                    subtitle: guidanceText,
                    subtitleLines: 3
                )
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }

    /// Days that actually recorded activity. Days with no data are excluded from
    /// every average so an unworn watch does not read as an easy day.
    private var recordedDays: [DailyStrainPoint] {
        weekHistory.filter(\.hasRecordedData)
    }

    private var averageStrain: Double {
        guard !recordedDays.isEmpty else { return 0 }
        return recordedDays.map(\.strain).reduce(0, +) / Double(recordedDays.count)
    }

    private var strainChartAccessibilityValue: String {
        guard !recordedDays.isEmpty else { return Copy.Strain.noHistoryAvailable }
        let latest = recordedDays.last?.strain ?? 0
        return Copy.Strain.latestStrainAndAverage(
            String(format: "%.1f", latest),
            String(format: "%.1f", averageStrain),
            recordedDays.count
        )
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
        targetStrainRange.contains(strainValue) ? AppColour.success : AppColour.warning
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
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(.white)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(iconColor.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(DS.Typography.caption)
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
                        .font(DS.Typography.subheadlineSemibold)
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(.gray.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Strain.learnMore)
                            .font(DS.Typography.subheadlineSemibold)
                        Text(Copy.Strain.learnMoreHint)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
            .onChange(of: showLearnMore) { _, isOpen in
                guard isOpen else { return }
                AppAnalytics.shared.trackExplanationViewed(type: "strain_methodology", screen: .strainDetail)
            }
        }
    }

    private var zoneBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.Strain.heartRateZones)
                .font(DS.Typography.subheadlineSemibold)
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
            Text(Copy.Strain.zoneShort(zone))
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(TrainingZoneColor.color(for: zone), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(zoneName(zone))
                        .font(DS.Typography.subheadlineMedium)
                    Spacer()
                    Text(formatMinutes(minutes))
                        .font(DS.Typography.subheadlineSemibold.monospacedDigit())
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
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                ForEach(StrainLevel.allCases, id: \.rawValue) { level in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level.color)
                            .frame(height: 4)
                        Text(level.displayName)
                            .font(DS.Typography.caption2Medium)
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
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)

            Text(Copy.Strain.strainDisclaimer)
                .font(DS.Typography.caption2)
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
                DailyStrainPoint(date: Date.cal.date(byAdding: .day, value: -6, to: .now)!, strain: 8.5, level: .moderate),
                DailyStrainPoint(date: Date.cal.date(byAdding: .day, value: -5, to: .now)!, strain: 12.3, level: .moderate),
                DailyStrainPoint(date: Date.cal.date(byAdding: .day, value: -4, to: .now)!, strain: 15.8, level: .high),
                // Zero strain day: previews the shaded no data column and confirms
                // it is left out of the average.
                DailyStrainPoint(date: Date.cal.date(byAdding: .day, value: -3, to: .now)!, strain: 0, level: .low),
                DailyStrainPoint(date: Date.cal.date(byAdding: .day, value: -2, to: .now)!, strain: 11.0, level: .moderate),
                DailyStrainPoint(date: Date.cal.date(byAdding: .day, value: -1, to: .now)!, strain: 18.9, level: .overreaching),
                DailyStrainPoint(date: .now, strain: 14.2, level: .high)
            ],
            strainBalance: .optimal,
            trendPoints: (0..<30).reversed().map { offset in
                TrendSparkPoint(
                    date: Date.cal.date(byAdding: .day, value: -offset, to: .now)!,
                    value: 10 + Double((offset * 3) % 9)
                )
            }
        )
    }
}
