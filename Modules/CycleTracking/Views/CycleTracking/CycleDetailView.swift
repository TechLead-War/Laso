import SwiftUI

// MARK: - Cycle Phase Definition

/// Represents each phase of the menstrual cycle with display metadata.
enum CyclePhase: String, CaseIterable, Identifiable {
    case menstrual
    case follicular
    case ovulatory
    case luteal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .menstrual:  return Copy.CycleTracking.menstrualPhase
        case .follicular: return Copy.CycleTracking.follicularPhase
        case .ovulatory:  return Copy.CycleTracking.ovulatoryPhase
        case .luteal:     return Copy.CycleTracking.lutealPhase
        }
    }

    var color: Color {
        switch self {
        case .menstrual:  return .red
        case .follicular: return .pink
        case .ovulatory:  return .orange
        case .luteal:     return .purple
        }
    }

    var icon: String {
        switch self {
        case .menstrual:  return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulatory:  return "sparkles"
        case .luteal:     return "moon.stars.fill"
        }
    }

    var description: String {
        switch self {
        case .menstrual:  return Copy.CycleTracking.menstrualDescription
        case .follicular: return Copy.CycleTracking.follicularDescription
        case .ovulatory:  return Copy.CycleTracking.ovulatoryDescription
        case .luteal:     return Copy.CycleTracking.lutealDescription
        }
    }

    var energyImpact: String {
        switch self {
        case .menstrual:  return Copy.CycleTracking.menstrualEnergy
        case .follicular: return Copy.CycleTracking.follicularEnergy
        case .ovulatory:  return Copy.CycleTracking.ovulatoryEnergy
        case .luteal:     return Copy.CycleTracking.lutealEnergy
        }
    }

    var recoveryImpact: String {
        switch self {
        case .menstrual:  return Copy.CycleTracking.menstrualRecovery
        case .follicular: return Copy.CycleTracking.follicularRecovery
        case .ovulatory:  return Copy.CycleTracking.ovulatoryRecovery
        case .luteal:     return Copy.CycleTracking.lutealRecovery
        }
    }

    var sleepImpact: String {
        switch self {
        case .menstrual:  return Copy.CycleTracking.menstrualSleep
        case .follicular: return Copy.CycleTracking.follicularSleep
        case .ovulatory:  return Copy.CycleTracking.ovulatorySleep
        case .luteal:     return Copy.CycleTracking.lutealSleep
        }
    }

    var nutritionTips: String {
        switch self {
        case .menstrual:  return Copy.CycleTracking.menstrualNutrition
        case .follicular: return Copy.CycleTracking.follicularNutrition
        case .ovulatory:  return Copy.CycleTracking.ovulatoryNutrition
        case .luteal:     return Copy.CycleTracking.lutealNutrition
        }
    }

    var exerciseRecommendation: String {
        switch self {
        case .menstrual:  return Copy.CycleTracking.menstrualExercise
        case .follicular: return Copy.CycleTracking.follicularExercise
        case .ovulatory:  return Copy.CycleTracking.ovulatoryExercise
        case .luteal:     return Copy.CycleTracking.lutealExercise
        }
    }

    /// Typical phase duration for a standard cycle, used for display.
    func typicalDays(cycleLength: Int) -> Int {
        switch self {
        case .menstrual:  return 5
        case .follicular:
            let ovStart = max(6, cycleLength - 15)
            return max(1, ovStart - 5)
        case .ovulatory:  return 3
        case .luteal:
            let ovEnd = min(cycleLength, max(8, cycleLength - 14) + 1)
            return max(1, cycleLength - ovEnd)
        }
    }
}

// MARK: - Cycle History Entry

/// Represents one historical menstrual cycle for the history section.
struct CycleHistoryEntry: Identifiable {
    let id = UUID()
    let startDate: Date
    let length: Int
}

// MARK: - Cycle Detail View

/// Full-screen detail view for menstrual cycle tracking.
/// Shows a circular cycle wheel, current phase info, phase impact cards,
/// exercise recommendations, cycle history, and next period estimate.
struct CycleDetailView: View {
    let currentPhase: CyclePhase
    let dayInCycle: Int
    let cycleLength: Int
    let daysUntilPeriod: Int
    let dayInPhase: Int
    let phaseDuration: Int
    let cycleHistory: [CycleHistoryEntry]
    let nextPeriodDate: Date?
    /// Freshness timestamp from the parent dashboard refresh.
    var lastUpdated: Date? = nil
    /// Pull-to-refresh hook wired by the route destination.
    var onRefresh: (() async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                // Hero: Circular cycle wheel
                cycleWheelSection

                // Current phase info card
                currentPhaseCard

                // Phase impact cards
                phaseImpactSection

                // Exercise recommendation
                exerciseSection

                // Cycle history
                cycleHistorySection

                // Next period estimate
                nextPeriodSection
            }
            .padding(.vertical)
        }
        .background(AppColour.surfaceBase)
        .refreshable {
            await onRefresh?()
        }
        .navigationTitle(Copy.CycleTracking.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.cycleDetail)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.cycleDetail)
        }
    }

    // MARK: - Cycle Wheel

    private var cycleWheelSection: some View {
        VStack(spacing: DS.itemSpacing) {
            ZStack {
                // Cycle wheel segments
                CycleWheelShape(cycleLength: cycleLength)
                    .frame(width: 220, height: 220)

                // Current position marker
                currentPositionMarker
                    .frame(width: 220, height: 220)

                // Center content
                VStack(spacing: DS.space1) {
                    Image(systemName: currentPhase.icon)
                        .font(DS.Typography.title)
                        .foregroundStyle(currentPhase.color)

                    Text(Copy.CycleTracking.dayOfCycle(dayInCycle))
                        .font(DS.Typography.title2)

                    Text(Copy.CycleTracking.ofTotal(cycleLength))
                        .font(DS.Typography.captionMedium)
                        .foregroundStyle(AppColour.textSecondary)
                }
            }
            .padding(.top, DS.space2)

            // Phase legend
            HStack(spacing: DS.space4) {
                ForEach(CyclePhase.allCases) { phase in
                    HStack(spacing: DS.space1) {
                        Circle()
                            .fill(phase.color)
                            .frame(width: 8, height: 8)
                        Text(phase.rawValue.prefix(1).uppercased() + phase.rawValue.dropFirst())
                            .font(DS.Typography.caption2Medium)
                            .foregroundStyle(phase == currentPhase ? AppColour.textPrimary : AppColour.textSecondary)
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
    }

    // MARK: - Current Position Marker

    private var currentPositionMarker: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius: CGFloat = 98 // Between inner and outer radius of the wheel
            let angle = Angle.degrees(Double(dayInCycle) / Double(cycleLength) * 360 - 90)
            let x = center.x + radius * cos(angle.radians)
            let y = center.y + radius * sin(angle.radians)

            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .shadow(color: currentPhase.color.opacity(0.5), radius: 4, y: 0)
                .overlay(
                    Circle()
                        .fill(currentPhase.color)
                        .frame(width: 8, height: 8)
                )
                .position(x: x, y: y)
        }
    }

    // MARK: - Current Phase Card

    private var currentPhaseCard: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            HStack(spacing: DS.itemSpacing) {
                Image(systemName: currentPhase.icon)
                    .font(DS.Typography.title3)
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(currentPhase.color, in: Circle())

                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(currentPhase.displayName)
                        .font(DS.Typography.headline)

                    Text(Copy.CycleTracking.dayOfPhase(dayInPhase, duration: phaseDuration))
                        .font(DS.Typography.subheadlineMedium)
                        .foregroundStyle(AppColour.textSecondary)
                }

                Spacer()

                if daysUntilPeriod > 0 {
                    VStack(alignment: .trailing, spacing: DS.space1) {
                        Text("\(daysUntilPeriod)")
                            .font(DS.Typography.displayS)
                            .foregroundStyle(currentPhase.color)
                        Text(Copy.CycleTracking.daysToPeriod)
                            .font(DS.Typography.caption2Medium)
                            .foregroundStyle(AppColour.textSecondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Text(currentPhase.description)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: currentPhase.color)
        .padding(.horizontal)
    }

    // MARK: - Phase Impact Section

    private var phaseImpactSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.CycleTracking.howThisPhaseAffectsYou)
                .font(DS.Typography.headline)
                .padding(.horizontal)

            impactCard(
                icon: "bolt.fill",
                title: Copy.CycleTracking.energyAndPerformance,
                description: currentPhase.energyImpact,
                color: .orange
            )

            impactCard(
                icon: "arrow.counterclockwise.circle.fill",
                title: Copy.CycleTracking.recovery,
                description: currentPhase.recoveryImpact,
                color: .green
            )

            impactCard(
                icon: "moon.fill",
                title: Copy.CycleTracking.sleep,
                description: currentPhase.sleepImpact,
                color: .indigo
            )

            impactCard(
                icon: "carrot.fill",
                title: Copy.CycleTracking.nutritionTips,
                description: currentPhase.nutritionTips,
                color: .teal
            )
        }
    }

    private func impactCard(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(.white)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(color, in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DS.Typography.subheadlineSemibold)

                Text(description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
    }

    // MARK: - Exercise Section

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.CycleTracking.exerciseRecommendation)
                .font(DS.Typography.headline)
                .padding(.horizontal)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.run")
                    .font(DS.Typography.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(currentPhase.color.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius))

                VStack(alignment: .leading, spacing: 6) {
                    Text(Copy.CycleTracking.recommendedFor(phase: currentPhase.displayName))
                        .font(DS.Typography.subheadlineSemibold)

                    Text(currentPhase.exerciseRecommendation)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Intensity indicator
                    HStack(spacing: 4) {
                        Text(Copy.CycleTracking.intensity)
                            .font(DS.Typography.caption2Medium)
                            .foregroundStyle(.tertiary)

                        ForEach(0..<4, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(level < intensityLevel ? currentPhase.color : currentPhase.color.opacity(0.2))
                                .frame(width: 18, height: 6)
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: currentPhase.color)
            .padding(.horizontal)
        }
    }

    private var intensityLevel: Int {
        switch currentPhase {
        case .menstrual:  return 1
        case .follicular: return 3
        case .ovulatory:  return 4
        case .luteal:     return 2
        }
    }

    // MARK: - Cycle History Section

    private var cycleHistorySection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.CycleTracking.cycleHistory)
                .font(DS.Typography.headline)
                .padding(.horizontal)

            if cycleHistory.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(DS.Typography.title2)
                            .foregroundStyle(.tertiary)
                        Text(Copy.CycleTracking.notEnoughCycleData)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, DS.space5)
                    Spacer()
                }
                .cardStyle()
                .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(cycleHistory.prefix(6)) { entry in
                        cycleHistoryRow(entry: entry)
                    }
                }
                .cardStyle()
                .padding(.horizontal)

                // Average cycle length
                if let avg = averageCycleLength {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        Text(Copy.CycleTracking.averageCycleLength(avg))
                            .font(DS.Typography.captionMedium)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private func cycleHistoryRow(entry: CycleHistoryEntry) -> some View {
        let isFirst = cycleHistory.first?.id == entry.id
        let entryIndex = cycleHistory.firstIndex(where: { $0.id == entry.id }) ?? 0

        if !isFirst {
            Divider()
                .padding(.leading, 40)
        }

        HStack(spacing: 12) {
            // Cycle number indicator
            Text("\(cycleHistory.count - entryIndex)")
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(cycleLengthColor(entry.length), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.startDate, format: .dateTime.month(.wide).day().year())
                    .font(DS.Typography.subheadlineMedium)

                Text(Copy.CycleTracking.daysCount(entry.length))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Length deviation from average
            deviationLabel(for: entry.length)
        }
        .padding(.vertical, DS.space2)
        .padding(.horizontal, DS.cardPadding)
    }

    @ViewBuilder
    private func deviationLabel(for length: Int) -> some View {
        if let avgLength = averageCycleLength {
            let diff = length - avgLength
            if diff != 0 {
                Text(diff > 0 ? "+\(diff)d" : "\(diff)d")
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(abs(diff) <= 2 ? AppColour.textSecondary : AppColour.warning)
            }
        }
    }

    private var averageCycleLength: Int? {
        guard !cycleHistory.isEmpty else { return nil }
        let total = cycleHistory.reduce(0) { $0 + $1.length }
        return total / cycleHistory.count
    }

    private func cycleLengthColor(_ length: Int) -> Color {
        if let avg = averageCycleLength {
            return abs(length - avg) <= 2 ? AppColour.info : AppColour.warning
        }
        return AppColour.info
    }

    // MARK: - Next Period Section

    private var nextPeriodSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.CycleTracking.nextPeriodEstimate)
                .font(DS.Typography.headline)
                .padding(.horizontal)

            HStack(spacing: 16) {
                // Countdown circle
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.15), lineWidth: 6)
                        .frame(width: 64, height: 64)

                    Circle()
                        .trim(from: 0, to: countdownProgress)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(daysUntilPeriod)")
                            .font(DS.Typography.displayS)
                        Text(Copy.CycleTracking.days)
                            .font(DS.Typography.caption2Medium)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let date = nextPeriodDate {
                        Text(Copy.CycleTracking.estimatedStart)
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(DS.Typography.subheadlineSemibold)

                        Text(Copy.CycleTracking.basedOnCycleLength(cycleLength))
                            .font(DS.Typography.caption2)
                            .foregroundStyle(AppColour.textTertiary)
                    } else {
                        Text(Copy.CycleTracking.estimatedStart)
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(AppColour.textSecondary)
                            .textCase(.uppercase)

                        Text(Copy.CycleTracking.inAboutDays(daysUntilPeriod))
                            .font(DS.Typography.subheadlineSemibold)
                    }
                }

                Spacer()
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: .red)
            .padding(.horizontal)
        }
        .padding(.bottom, DS.space2)
    }

    private var countdownProgress: Double {
        guard cycleLength > 0 else { return 0 }
        return 1.0 - (Double(daysUntilPeriod) / Double(cycleLength))
    }
}

// MARK: - Cycle Wheel Shape

/// Custom shape that draws 4 colored arc segments representing the menstrual cycle phases.
struct CycleWheelShape: View {
    let cycleLength: Int

    private let outerRadius: CGFloat = 110
    private let innerRadius: CGFloat = 72
    private let gapDegrees: Double = 2

    var body: some View {
        ZStack {
            ForEach(Array(segmentData.enumerated()), id: \.offset) { _, segment in
                CycleArcSegment(
                    startAngle: segment.start,
                    endAngle: segment.end,
                    outerRadius: outerRadius,
                    innerRadius: innerRadius
                )
                .fill(segment.color)
            }
        }
    }

    private var segmentData: [(start: Angle, end: Angle, color: Color)] {
        let menstrualDays = 5.0
        let ovulatoryDays = 3.0
        let ovulationCenter = max(8.0, Double(cycleLength) - 14.0)
        let follicularDays = max(1.0, ovulationCenter - 1.0 - menstrualDays)
        let lutealDays = max(1.0, Double(cycleLength) - menstrualDays - follicularDays - ovulatoryDays)

        let total = menstrualDays + follicularDays + ovulatoryDays + lutealDays
        let halfGap = gapDegrees / 2

        let menstrualAngle = (menstrualDays / total) * 360
        let follicularAngle = (follicularDays / total) * 360
        let ovulatoryAngle = (ovulatoryDays / total) * 360
        let lutealAngle = (lutealDays / total) * 360

        // Start at top (-90 degrees)
        let start0 = -90.0
        let end0 = start0 + menstrualAngle
        let end1 = end0 + follicularAngle
        let end2 = end1 + ovulatoryAngle
        let end3 = end2 + lutealAngle

        return [
            (Angle.degrees(start0 + halfGap), Angle.degrees(end0 - halfGap), CyclePhase.menstrual.color),
            (Angle.degrees(end0 + halfGap), Angle.degrees(end1 - halfGap), CyclePhase.follicular.color),
            (Angle.degrees(end1 + halfGap), Angle.degrees(end2 - halfGap), CyclePhase.ovulatory.color),
            (Angle.degrees(end2 + halfGap), Angle.degrees(end3 - halfGap), CyclePhase.luteal.color),
        ]
    }
}

/// An individual arc segment of the cycle wheel.
struct CycleArcSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let outerRadius: CGFloat
    let innerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()

        // Outer arc (clockwise)
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Inner arc (counter-clockwise back)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CycleDetailView(
            currentPhase: .follicular,
            dayInCycle: 8,
            cycleLength: 28,
            daysUntilPeriod: 20,
            dayInPhase: 3,
            phaseDuration: 8,
            cycleHistory: [
                CycleHistoryEntry(startDate: Date.cal.date(byAdding: .day, value: -28, to: .now)!, length: 28),
                CycleHistoryEntry(startDate: Date.cal.date(byAdding: .day, value: -56, to: .now)!, length: 27),
                CycleHistoryEntry(startDate: Date.cal.date(byAdding: .day, value: -83, to: .now)!, length: 29),
                CycleHistoryEntry(startDate: Date.cal.date(byAdding: .day, value: -112, to: .now)!, length: 28),
                CycleHistoryEntry(startDate: Date.cal.date(byAdding: .day, value: -140, to: .now)!, length: 30),
            ],
            nextPeriodDate: Date.cal.date(byAdding: .day, value: 20, to: .now)
        )
    }
}

#Preview("Menstrual Phase") {
    NavigationStack {
        CycleDetailView(
            currentPhase: .menstrual,
            dayInCycle: 3,
            cycleLength: 28,
            daysUntilPeriod: 25,
            dayInPhase: 3,
            phaseDuration: 5,
            cycleHistory: [],
            nextPeriodDate: Date.cal.date(byAdding: .day, value: 25, to: .now)
        )
    }
}
