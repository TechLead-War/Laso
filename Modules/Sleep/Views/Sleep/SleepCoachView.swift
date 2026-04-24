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

    @State private var showAllTips = false

    /// A single day's sleep record for the 14-day history chart.
    struct DayEntry: Identifiable {
        let id = UUID()
        let date: Date
        let actual: Double   // hours slept
        let needed: Double   // hours needed
        let bedtime: Date?
        let wakeTime: Date?

        init(date: Date, actual: Double, needed: Double, bedtime: Date? = nil, wakeTime: Date? = nil) {
            self.date = date
            self.actual = actual
            self.needed = needed
            self.bedtime = bedtime
            self.wakeTime = wakeTime
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
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.indigo.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: min(1, adjustedNeed / 12))
                    .stroke(.indigo, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Image(systemName: "moon.fill")
                        .font(.title2)
                        .foregroundStyle(.indigo)
                    Text(formatDuration(adjustedNeed))
                        .font(DS.Typography.displayS)
                    Text(Copy.SleepCoach.tonight)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(Copy.SleepCoach.recommendedSleep(level: performanceLevel.rawValue.lowercased()))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.space5)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    // MARK: - 2. Performance Level Picker

    private var performancePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        HStack(spacing: 12) {
            scheduleItem(
                icon: "moon.zzz.fill",
                label: Copy.SleepCoach.bedtime,
                value: formattedBedtime,
                color: .indigo
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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(label)
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.space4)
        .cardStyle()
    }

    // MARK: - 4. Sleep Debt Section

    private var debtSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "exclamationmark.triangle.fill", title: Copy.SleepCoach.sleepDebt)

            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Copy.SleepCoach.currentDebt)
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(formatDuration(debtHours))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(debtHours > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.green))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        debtLevelBadge

                        if debtHours > 0 {
                            Text(Copy.SleepCoach.daysToPayOff(daysToPayOff))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Debt level bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 6)

                        Capsule()
                            .fill(debtColor.gradient)
                            .frame(width: geo.size.width * debtFraction, height: 6)
                    }
                }
                .frame(height: 6)

                // Trend indicator
                HStack(spacing: 4) {
                    Image(systemName: debtTrendIcon)
                        .font(.caption2.weight(.bold))
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
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "chart.bar.fill", title: Copy.SleepCoach.fourteenDayHistory)

            if dailyHistory.isEmpty {
                Text(Copy.Common.notEnoughData)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DS.space5)
                    .cardStyle()
                    .padding(.horizontal)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(dailyHistory.suffix(14).reversed())) { day in
                        historyBar(day)
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
            }
        }
    }

    private func historyBar(_ day: DayEntry) -> some View {
        HStack(spacing: 6) {
            Text(dayLabel(day.date))
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)

            Text(day.bedtime.map(Self.timeFormatter.string(from:)) ?? "—")
                .font(.system(size: 10, weight: .regular).monospacedDigit())
                .foregroundStyle(day.bedtime == nil ? .tertiary : .secondary)
                .frame(width: 42, alignment: .trailing)

            GeometryReader { geo in
                let maxHours: Double = 12
                let neededWidth = geo.size.width * min(day.needed / maxHours, 1)
                let actualWidth = geo.size.width * min(day.actual / maxHours, 1)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(width: neededWidth, height: 14)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(day.actual >= day.needed ? AppColour.categorySleep : AppColour.warning)
                        .frame(width: actualWidth, height: 14)
                }
            }
            .frame(height: 14)

            Text(day.wakeTime.map(Self.timeFormatter.string(from:)) ?? "—")
                .font(.system(size: 10, weight: .regular).monospacedDigit())
                .foregroundStyle(day.wakeTime == nil ? .tertiary : .secondary)
                .frame(width: 42, alignment: .leading)

            Text(formatDuration(day.actual))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(day.actual >= day.needed ? AnyShapeStyle(.primary) : AnyShapeStyle(.orange))
                .frame(width: 46, alignment: .trailing)
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
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "target", title: Copy.SleepCoach.consistency)

            HStack(spacing: 20) {
                // Ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 6)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: Double(consistencyScore) / 100.0)
                        .stroke(consistencyColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    Text("\(consistencyScore)")
                        .font(.title3.weight(.bold).monospacedDigit())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(consistencyLabel)
                        .font(DS.Typography.subheadlineSemibold)

                    Text(consistencyDescription)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 10) {
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
                        Text("Show \(currentTips.count - 2) more tips")
                            .font(DS.Typography.subheadlineMedium)
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.space3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, DS.space2)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private func tipRow(_ tip: SleepTip) -> some View {
        HStack(spacing: 12) {
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
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 6)
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(.indigo)
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
                SleepTip(icon: "plus.circle.fill", color: .indigo,
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
                SleepTip(icon: "clock.fill", color: .indigo,
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
        if debtHours <= 1 { return .green }
        if debtHours <= 4 { return .orange }
        return .red
    }

    private var debtFraction: Double {
        min(1.0, debtHours / 10.0)
    }

    private var debtLevelBadge: some View {
        let (text, color) = debtLevelInfo
        return Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(color.opacity(DS.badgeBg), in: Capsule())
    }

    private var debtLevelInfo: (String, Color) {
        if debtHours <= 0.5 { return (Copy.SleepCoach.debtClear, .green) }
        if debtHours <= 2 { return (Copy.SleepCoach.debtLow, .blue) }
        if debtHours <= 5 { return (Copy.SleepCoach.debtModerate, .orange) }
        return (Copy.SleepCoach.debtHigh, .red)
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
        guard recent.count >= 2 else { return .secondary }
        let avgDelta = recent.map { $0.actual - $0.needed }.reduce(0, +) / Double(recent.count)
        if avgDelta > 0.25 { return .green }
        if avgDelta < -0.25 { return .orange }
        return .secondary
    }

    private var consistencyColor: Color {
        if consistencyScore >= 80 { return .green }
        if consistencyScore >= 60 { return .blue }
        if consistencyScore >= 40 { return .orange }
        return .red
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
