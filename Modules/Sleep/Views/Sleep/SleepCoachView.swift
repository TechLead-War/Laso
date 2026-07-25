import SwiftUI

/// Full Sleep Coach detail view showing tonight's sleep recommendation,
/// sleep debt tracking, 14-day history, consistency score, and tips.
struct SleepCoachView: View {
    let baseHoursNeeded: Double
    let bedtime: Date?
    let wakeTime: Date?
    let debtHours: Double
    let dailyHistory: [DayEntry]
    let consistencyScore: Int
    /// Pull-to-refresh hook wired by the route destination
    /// to `dashboardViewModel.refresh()`. Defaults to a no-op so existing
    /// previews and unit consumers continue to compile unchanged.
    var onRefresh: (() async -> Void)? = nil

    @State private var showAllTips = false
    @State private var expandedDayId: UUID? = nil

    /// A single day's sleep record for the 14-day history chart.
    struct DayEntry: Identifiable {
        let id = UUID()
        let date: Date
        let actual: Double   // hours slept (asleep stages summed)
        let needed: Double   // hours needed
        let bedtime: Date?
        let wakeTime: Date?
        /// Per-stage breakdown — populated when HealthKit stage data is available.
        let coreHours: Double?
        let deepHours: Double?
        let remHours: Double?
        let awakeHours: Double?
        /// Total nap minutes recorded on this calendar day (sleep that didn't
        /// qualify as the overnight session). Surfaced as a small "+ Xm nap"
        /// badge on the history row so users can see naps that are silently
        /// counted toward sleep balance.
        let napMinutes: Int?

        init(
            date: Date,
            actual: Double,
            needed: Double,
            bedtime: Date? = nil,
            wakeTime: Date? = nil,
            coreHours: Double? = nil,
            deepHours: Double? = nil,
            remHours: Double? = nil,
            awakeHours: Double? = nil,
            napMinutes: Int? = nil
        ) {
            self.date = date
            self.actual = actual
            self.needed = needed
            self.bedtime = bedtime
            self.wakeTime = wakeTime
            self.coreHours = coreHours
            self.deepHours = deepHours
            self.remHours = remHours
            self.awakeHours = awakeHours
            self.napMinutes = napMinutes
        }

        /// Total bed-to-wake span in hours when both timestamps are present.
        /// Falls back to `actual` (sum of asleep stages) when boundaries are missing.
        var bedToWakeHours: Double {
            if let bedtime, let wakeTime {
                return max(0, wakeTime.timeIntervalSince(bedtime) / 3600.0)
            }
            return actual
        }

        /// Whether per-stage data is available for the expanded breakdown view.
        var hasStageBreakdown: Bool {
            coreHours != nil || deepHours != nil || remHours != nil || awakeHours != nil
        }
    }

    @State private var performanceLevel: PerformanceLevel = .peak

    enum PerformanceLevel: String, CaseIterable, Identifiable {
        case peak = "Peak"
        case perform = "Perform"
        case getBy = "Get By"

        var id: String { rawValue }

        /// Adjustment to the base sleep need (in hours).
        var adjustment: Double {
            switch self {
            case .peak: return 0.75
            case .perform: return 0
            case .getBy: return -0.75
            }
        }
    }

    private var adjustedNeed: Double {
        max(4, baseHoursNeeded + performanceLevel.adjustment)
    }

    /// Bedtime shifted by the performance-level adjustment so
    /// that bedtime + adjustedNeed ≈ wakeTime.
    private var adjustedBedtime: Date? {
        bedtime?.addingTimeInterval(-performanceLevel.adjustment * 3600)
    }

    private var formattedBedtime: String {
        adjustedBedtime?.formatted(date: .omitted, time: .shortened) ?? "--:--"
    }

    private var formattedWakeTime: String {
        wakeTime?.formatted(date: .omitted, time: .shortened) ?? "--:--"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                heroSection
                performancePicker
                scheduleSection
                debtSection
                historySection
                consistencySection
                tipsSection
            }
            .padding(.bottom, DS.space6)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .refreshable {
            await onRefresh?()
        }
        .navigationTitle(Copy.SleepCoach.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.sleepCoach)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.sleepCoach)
        }
    }

    // MARK: - 1. Hero Section

    private var heroSection: some View {
        VStack(spacing: DS.space4) {
            ZStack {
                Circle()
                    .stroke(AppColour.categorySleep.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: min(1, adjustedNeed / 12))
                    .stroke(AppColour.categorySleep, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Image(systemName: "moon.fill")
                        .font(DS.Typography.title2)
                        .foregroundStyle(AppColour.categorySleep)
                    Text(formatDuration(adjustedNeed))
                        .font(DS.Typography.displayS)
                    Text(Copy.SleepCoach.tonight)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                }
            }

            Text(Copy.SleepCoach.recommendedSleep(level: performanceLevel.rawValue.lowercased()))
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.space5)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal)
    }

    // MARK: - 2. Performance Level Picker

    private var performancePicker: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(icon: "slider.horizontal.3", title: Copy.SleepCoach.performanceLevel)

            Picker(Copy.SleepCoach.performanceLabel, selection: $performanceLevel) {
                ForEach(PerformanceLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }

    // MARK: - 3. Schedule Section

    private var scheduleSection: some View {
        HStack(spacing: DS.itemSpacing) {
            scheduleItem(
                icon: "moon.zzz.fill",
                label: Copy.SleepCoach.bedtime,
                value: formattedBedtime,
                color: AppColour.categorySleep
            )

            scheduleItem(
                icon: "sunrise.fill",
                label: Copy.SleepCoach.wakeUp,
                value: formattedWakeTime,
                color: .orange
            )
        }
        .padding(.horizontal)
    }

    private func scheduleItem(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: DS.space2) {
            Image(systemName: icon)
                .font(DS.Typography.title2)
                .foregroundStyle(color)

            Text(label)
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(AppColour.textSecondary)
                .textCase(.uppercase)

            Text(value)
                .font(DS.Typography.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.space4)
        .cardStyle()
    }

    // MARK: - 4. Sleep Debt Section

    private var debtSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(icon: "exclamationmark.triangle.fill", title: Copy.SleepCoach.sleepDebt)

            VStack(spacing: DS.itemSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: DS.space1) {
                        Text(Copy.SleepCoach.currentDebt)
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(AppColour.textSecondary)
                            .textCase(.uppercase)

                        Text(formatDuration(debtHours))
                            .font(DS.Typography.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(debtHours > 0 ? AnyShapeStyle(AppColour.textPrimary) : AnyShapeStyle(AppColour.success))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: DS.space1) {
                        debtLevelBadge

                        if debtHours > 0 {
                            Text(Copy.SleepCoach.daysToPayOff(daysToPayOff))
                                .font(DS.Typography.caption)
                                .foregroundStyle(AppColour.textSecondary)
                        }
                    }
                }

                // Debt level bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColour.borderLow)
                            .frame(height: 6)

                        Capsule()
                            .fill(debtColor.gradient)
                            .frame(width: geo.size.width * debtFraction, height: 6)
                    }
                }
                .frame(height: 6)

                // Trend indicator
                HStack(spacing: DS.space1) {
                    Image(systemName: debtTrendIcon)
                        .font(DS.Typography.caption2.weight(.bold))
                    Text(debtTrendLabel)
                        .font(DS.Typography.caption)
                }
                .foregroundStyle(debtTrendColor)
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    // MARK: - 5. 14-Day Sleep History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(icon: "chart.bar.fill", title: Copy.SleepCoach.fourteenDayHistory)

            if dailyHistory.isEmpty {
                Text(Copy.Common.notEnoughData)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.space5)
                    .cardStyle()
                    .padding(.horizontal)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(dailyHistory.suffix(14).reversed())) { day in
                        historyRow(day)
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
            }
        }
    }

    /// Tappable row — collapsed shows day/bedtime/bar/wake/total. Expanded
    /// reveals the per-stage breakdown (Deep / REM / Core / Awake).
    @ViewBuilder
    private func historyRow(_ day: DayEntry) -> some View {
        let isExpanded = expandedDayId == day.id

        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expandedDayId = isExpanded ? nil : day.id
                }
            } label: {
                historyBar(day, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.SleepCoach.sleepInBedLabel(dayLabel(day.date), formatDuration(day.bedToWakeHours)))
            .accessibilityHint(isExpanded ? "Tap to collapse stage breakdown" : "Tap to show stage breakdown")

            if let napMinutes = day.napMinutes, napMinutes > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption2)
                        .foregroundStyle(AppColour.textTertiary)
                    Text(Copy.SleepCoach.mNapText(napMinutes))
                        .font(DS.Typography.caption2.monospacedDigit())
                        .foregroundStyle(AppColour.textSecondary)
                    Spacer()
                }
                .padding(.leading, 80)
                .accessibilityLabel(Copy.SleepCoach.daytimeNapMinutesCountedInLabel(napMinutes))
            }

            if isExpanded {
                stageBreakdown(day)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func historyBar(_ day: DayEntry, isExpanded: Bool) -> some View {
        HStack(spacing: DS.space2) {
            Text(dayLabel(day.date))
                .font(DS.Typography.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppColour.textSecondary)
                .frame(width: 28, alignment: .leading)

            Text(day.bedtime.map(Self.timeFormatter.string(from:)) ?? "—")
                .font(DS.Typography.caption2.monospacedDigit())
                .foregroundStyle(day.bedtime == nil ? AppColour.textTertiary : AppColour.textSecondary)
                .frame(width: 42, alignment: .trailing)

            sleepBar(day)
                .frame(height: 18)

            Text(day.wakeTime.map(Self.timeFormatter.string(from:)) ?? "—")
                .font(DS.Typography.caption2.monospacedDigit())
                .foregroundStyle(day.wakeTime == nil ? AppColour.textTertiary : AppColour.textSecondary)
                .frame(width: 42, alignment: .leading)

            Text(formatDuration(day.bedToWakeHours))
                .font(DS.Typography.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(day.actual >= day.needed ? AnyShapeStyle(AppColour.textPrimary) : AnyShapeStyle(AppColour.warning))
                .frame(width: 46, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppColour.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 10)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// Per-stage breakdown shown when a row is expanded. Falls back to a hint
    /// when HealthKit didn't return any stage data for that night.
    @ViewBuilder
    private func stageBreakdown(_ day: DayEntry) -> some View {
        if day.hasStageBreakdown {
            VStack(spacing: 6) {
                stageRow(label: Copy.SleepCoach.stageDeep,  hours: day.deepHours,  total: day.bedToWakeHours, color: AppColour.categorySleep)
                stageRow(label: Copy.SleepCoach.stageRem,   hours: day.remHours,   total: day.bedToWakeHours, color: AppColour.categoryStress)
                stageRow(label: Copy.SleepCoach.stageCore,  hours: day.coreHours,  total: day.bedToWakeHours, color: AppColour.scoreOptimal)
                stageRow(label: Copy.SleepCoach.stageAwake, hours: day.awakeHours, total: day.bedToWakeHours, color: AppColour.warning)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        } else {
            Text(Copy.SleepCoach.stageDataUnavailable)
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
        }
    }

    private func stageRow(label: String, hours: Double?, total: Double, color: Color) -> some View {
        let value = hours ?? 0
        let frac = total > 0 ? max(0, min(1, value / total)) : 0
        return HStack(spacing: DS.space2) {
            Text(label)
                .font(DS.Typography.caption2.weight(.medium))
                .foregroundStyle(AppColour.textSecondary)
                .frame(width: 44, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: max(2, geo.size.width * frac))
                }
            }
            .frame(height: 6)

            Text(formatDuration(value))
                .font(DS.Typography.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppColour.textPrimary)
                .frame(width: 56, alignment: .trailing)
        }
    }

    private func sleepBar(_ day: DayEntry) -> some View {
        GeometryReader { geo in
            let maxHours: Double = 12
            let neededFrac = max(0, min(1, day.needed / maxHours))
            let actualFrac = max(0, min(1, day.actual / maxHours))
            let goalMet = day.actual >= day.needed
            let accent: Color = goalMet ? AppColour.categorySleep : AppColour.warning

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColour.borderLow)
                    .frame(width: geo.size.width, height: 4)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.55),
                                accent,
                                accent.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(2, geo.size.width * actualFrac), height: 8)
                    .shadow(color: accent.opacity(goalMet ? 0.55 : 0.35),
                            radius: goalMet ? 5 : 3, x: 0, y: 1)

                Rectangle()
                    .fill(AppColour.textTertiary.opacity(0.5))
                    .frame(width: 1.5, height: 12)
                    .offset(x: max(0, geo.size.width * neededFrac - 0.75))
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        formatter.amSymbol = "a"
        formatter.pmSymbol = "p"
        return formatter
    }()

    // MARK: - 6. Consistency Score

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(icon: "target", title: Copy.SleepCoach.consistency)

            HStack(spacing: DS.space5) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(AppColour.borderLow, lineWidth: 6)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: Double(consistencyScore) / 100.0)
                        .stroke(consistencyColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    Text(Copy.SleepCoach.xText(consistencyScore))
                        .font(DS.Typography.title3.weight(.bold).monospacedDigit())
                }

                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(consistencyLabel)
                        .font(DS.Typography.subheadlineSemibold)

                    Text(consistencyDescription)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    // MARK: - 7. Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(icon: "lightbulb.fill", title: debtHours > 2 ? Copy.SleepCoach.payingOffDebtTitle : Copy.SleepCoach.sleepTips)

            let visibleTips = showAllTips ? currentTips : Array(currentTips.prefix(2))

            VStack(spacing: 0) {
                ForEach(Array(visibleTips.enumerated()), id: \.offset) { index, tip in
                    tipRow(tip)
                    if index < visibleTips.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }

                if !showAllTips && currentTips.count > 2 {
                    Divider().padding(.leading, 44)
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { showAllTips = true }
                    } label: {
                        Text(Copy.SleepCoach.showMoreTips(currentTips.count - 2))
                            .font(DS.Typography.subheadlineMedium)
                            .foregroundStyle(AppColour.info)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.space3)
                    }
                    .buttonStyle(.dsPress)
                }
            }
            .padding(.vertical, DS.space2)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private func tipRow(_ tip: SleepTip) -> some View {
        HStack(spacing: DS.itemSpacing) {
            Image(systemName: tip.icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(tip.color)
                .frame(width: 32, height: 32)
                .background(tip.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .font(DS.Typography.subheadlineMedium)
                Text(tip.detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, DS.space2)
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: DS.space2) {
            Image(systemName: icon)
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(AppColour.categorySleep)
            Text(title)
                .font(DS.Typography.headline)
        }
        .padding(.horizontal)
    }

    // MARK: - Tips Data

    private struct SleepTip: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    private var currentTips: [SleepTip] {
        if debtHours > 2 {
            return [
                SleepTip(icon: "plus.circle.fill", color: AppColour.categorySleep,
                         title: Copy.SleepCoach.tipAddSleepTitle,
                         detail: Copy.SleepCoach.tipAddSleepDetail),
                SleepTip(icon: "calendar.badge.clock", color: .orange,
                         title: Copy.SleepCoach.tipBePatientTitle,
                         detail: Copy.SleepCoach.tipBePatientDetail(days: daysToPayOff)),
                SleepTip(icon: "cup.and.saucer.fill", color: .brown,
                         title: Copy.SleepCoach.tipCutCaffeineTitle,
                         detail: Copy.SleepCoach.tipCutCaffeineDetail),
                SleepTip(icon: "iphone.slash", color: .red,
                         title: Copy.SleepCoach.tipScreenCurfewTitle,
                         detail: Copy.SleepCoach.tipScreenCurfewDetail)
            ]
        } else {
            return [
                SleepTip(icon: "clock.fill", color: AppColour.categorySleep,
                         title: Copy.SleepCoach.tipConsistentScheduleTitle,
                         detail: Copy.SleepCoach.tipConsistentScheduleDetail),
                SleepTip(icon: "thermometer.snowflake", color: .cyan,
                         title: Copy.SleepCoach.tipCoolBedroomTitle,
                         detail: Copy.SleepCoach.tipCoolBedroomDetail),
                SleepTip(icon: "sun.max.fill", color: .orange,
                         title: Copy.SleepCoach.tipMorningSunlightTitle,
                         detail: Copy.SleepCoach.tipMorningSunlightDetail),
                SleepTip(icon: "figure.walk", color: .green,
                         title: Copy.SleepCoach.tipExerciseTimingTitle,
                         detail: Copy.SleepCoach.tipExerciseTimingDetail)
            ]
        }
    }

    // MARK: - Computed Properties

    private var debtColor: Color {
        if debtHours <= 1 { return AppColour.success }
        if debtHours <= 4 { return AppColour.warning }
        return AppColour.danger
    }

    private var debtFraction: Double {
        min(1.0, debtHours / 10.0)
    }

    private var debtLevelBadge: some View {
        let (text, color) = debtLevelInfo
        return Text(text)
            .font(DS.Typography.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(color.opacity(DS.badgeBg), in: Capsule())
    }

    private var debtLevelInfo: (String, Color) {
        if debtHours <= 0.5 { return (Copy.SleepCoach.debtClear, AppColour.success) }
        if debtHours <= 2 { return (Copy.SleepCoach.debtLow, AppColour.info) }
        if debtHours <= 5 { return (Copy.SleepCoach.debtModerate, AppColour.warning) }
        return (Copy.SleepCoach.debtHigh, AppColour.danger)
    }

    private var daysToPayOff: Int {
        guard debtHours > 0 else { return 0 }
        // Assume recovering ~45 min extra per night
        return max(1, Int(ceil(debtHours / 0.75)))
    }

    private var debtTrendIcon: String {
        let recent = dailyHistory.suffix(3)
        guard recent.count >= 2 else { return "arrow.right" }
        let avgDelta = recent.map { $0.actual - $0.needed }.reduce(0, +) / Double(recent.count)
        if avgDelta > 0.25 { return "arrow.down.right" }
        if avgDelta < -0.25 { return "arrow.up.right" }
        return "arrow.right"
    }

    private var debtTrendLabel: String {
        let recent = dailyHistory.suffix(3)
        guard recent.count >= 2 else { return Copy.SleepCoach.tracking }
        let avgDelta = recent.map { $0.actual - $0.needed }.reduce(0, +) / Double(recent.count)
        if avgDelta > 0.25 { return Copy.SleepCoach.payingOff }
        if avgDelta < -0.25 { return Copy.SleepCoach.accumulating }
        return Copy.SleepCoach.stable
    }

    private var debtTrendColor: Color {
        let recent = dailyHistory.suffix(3)
        guard recent.count >= 2 else { return AppColour.textSecondary }
        let avgDelta = recent.map { $0.actual - $0.needed }.reduce(0, +) / Double(recent.count)
        if avgDelta > 0.25 { return AppColour.success }
        if avgDelta < -0.25 { return AppColour.warning }
        return AppColour.textSecondary
    }

    private var consistencyColor: Color {
        if consistencyScore >= 80 { return AppColour.success }
        if consistencyScore >= 60 { return AppColour.info }
        if consistencyScore >= 40 { return AppColour.warning }
        return AppColour.danger
    }

    private var consistencyLabel: String {
        if consistencyScore >= 80 { return Copy.SleepCoach.excellent }
        if consistencyScore >= 60 { return Copy.SleepCoach.good }
        if consistencyScore >= 40 { return Copy.SleepCoach.needsWork }
        return Copy.SleepCoach.irregular
    }

    private var consistencyDescription: String {
        if consistencyScore >= 80 {
            return Copy.SleepCoach.consistencyExcellent
        }
        if consistencyScore >= 60 {
            return Copy.SleepCoach.consistencyGood
        }
        if consistencyScore >= 40 {
            return Copy.SleepCoach.consistencyNeedsWork
        }
        return Copy.SleepCoach.consistencyIrregular
    }

    // MARK: - Formatting Helpers

    private func formatDuration(_ hours: Double) -> String {
        let clamped = max(0, hours)
        let h = Int(clamped)
        let m = max(0, Int((clamped - Double(h)) * 60))
        if h == 0 { return "\(m)m" }
        return "\(h)h \(String(format: "%02d", m))m"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter
    }()

    private func dayLabel(_ date: Date) -> String {
        String(Self.dayFormatter.string(from: date).prefix(3))
    }
}
