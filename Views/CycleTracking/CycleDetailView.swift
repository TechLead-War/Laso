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
        case .menstrual:  return "Menstrual Phase"
        case .follicular: return "Follicular Phase"
        case .ovulatory:  return "Ovulatory Phase"
        case .luteal:     return "Luteal Phase"
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
        case .menstrual:
            return "Your body is shedding the uterine lining. Hormone levels are at their lowest, which can affect energy and mood."
        case .follicular:
            return "Estrogen rises steadily as follicles develop. Energy and mood typically improve as your body prepares for ovulation."
        case .ovulatory:
            return "An egg is released from the ovary. Estrogen peaks and testosterone briefly surges, often boosting energy and confidence."
        case .luteal:
            return "Progesterone rises to prepare the uterine lining. You may notice changes in appetite, sleep, and mood as the cycle nears its end."
        }
    }

    var energyImpact: String {
        switch self {
        case .menstrual:
            return "Energy tends to be lower. Light movement can help ease discomfort, but listen to your body and rest when needed."
        case .follicular:
            return "Rising estrogen boosts energy and endurance. A great time for challenging workouts and learning new skills."
        case .ovulatory:
            return "Peak energy and strength. You may hit personal records during this window as hormones support performance."
        case .luteal:
            return "Energy gradually declines, especially in the late luteal phase. Shift toward moderate, steady-state activities."
        }
    }

    var recoveryImpact: String {
        switch self {
        case .menstrual:
            return "Recovery may be slower due to inflammation. Prioritize sleep, hydration, and gentle movement like yoga or walking."
        case .follicular:
            return "Recovery is typically efficient. Your body responds well to training stimulus and adapts quickly."
        case .ovulatory:
            return "Good recovery capacity, but monitor intensity. The hormonal peak can mask fatigue signals."
        case .luteal:
            return "Recovery slows as progesterone rises. Allow extra rest between intense sessions and focus on sleep quality."
        }
    }

    var sleepImpact: String {
        switch self {
        case .menstrual:
            return "Sleep can be disrupted by cramps or discomfort. Melatonin production may be affected by low hormone levels."
        case .follicular:
            return "Sleep quality generally improves. Rising estrogen supports deeper, more restorative sleep cycles."
        case .ovulatory:
            return "Sleep is typically good, though some may experience a slight rise in body temperature affecting sleep onset."
        case .luteal:
            return "Progesterone raises core body temperature, which can reduce sleep quality. Keep the room cool and allow extra wind-down time."
        }
    }

    var nutritionTips: String {
        switch self {
        case .menstrual:
            return "Focus on iron-rich foods (leafy greens, red meat, lentils) and anti-inflammatory choices. Stay well hydrated."
        case .follicular:
            return "Support rising energy with complex carbs and lean protein. Fermented foods can support gut health during this phase."
        case .ovulatory:
            return "Lighter meals with plenty of fiber and antioxidants. Cruciferous vegetables help metabolize the estrogen peak."
        case .luteal:
            return "Increased caloric needs — add healthy fats and magnesium-rich foods. Dark chocolate and nuts can help with cravings."
        }
    }

    var exerciseRecommendation: String {
        switch self {
        case .menstrual:
            return "Gentle yoga, walking, light stretching, or swimming. Reduce intensity and focus on movement that feels good."
        case .follicular:
            return "High-intensity training, strength work, HIIT, and skill-based activities. Your body is primed for performance gains."
        case .ovulatory:
            return "Peak performance window — heavy lifts, sprint intervals, competitive sports. Push toward personal records."
        case .luteal:
            return "Moderate cardio, Pilates, strength maintenance. Taper intensity in the late luteal phase as energy declines."
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
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cycle Tracking")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Cycle Wheel

    private var cycleWheelSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Cycle wheel segments
                CycleWheelShape(cycleLength: cycleLength)
                    .frame(width: 220, height: 220)

                // Current position marker
                currentPositionMarker
                    .frame(width: 220, height: 220)

                // Center content
                VStack(spacing: 4) {
                    Image(systemName: currentPhase.icon)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(currentPhase.color)

                    Text("Day \(dayInCycle)")
                        .font(.title2.weight(.bold).monospacedDigit())

                    Text("of \(cycleLength)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)

            // Phase legend
            HStack(spacing: 16) {
                ForEach(CyclePhase.allCases) { phase in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(phase.color)
                            .frame(width: 8, height: 8)
                        Text(phase.rawValue.prefix(1).uppercased() + phase.rawValue.dropFirst())
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(phase == currentPhase ? .primary : .secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: currentPhase.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(currentPhase.color, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentPhase.displayName)
                        .font(.headline.weight(.bold))

                    Text("Day \(dayInPhase) of \(phaseDuration)")
                        .font(.subheadline.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if daysUntilPeriod > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(daysUntilPeriod)")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(currentPhase.color)
                        Text("days to\nperiod")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            Text(currentPhase.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: currentPhase.color)
        .padding(.horizontal)
    }

    // MARK: - Phase Impact Section

    private var phaseImpactSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("How This Phase Affects You")
                .font(.headline.weight(.bold))
                .padding(.horizontal)

            impactCard(
                icon: "bolt.fill",
                title: "Energy & Performance",
                description: currentPhase.energyImpact,
                color: .orange
            )

            impactCard(
                icon: "arrow.counterclockwise.circle.fill",
                title: "Recovery",
                description: currentPhase.recoveryImpact,
                color: .green
            )

            impactCard(
                icon: "moon.fill",
                title: "Sleep",
                description: currentPhase.sleepImpact,
                color: .indigo
            )

            impactCard(
                icon: "carrot.fill",
                title: "Nutrition Tips",
                description: currentPhase.nutritionTips,
                color: .teal
            )
        }
    }

    private func impactCard(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(color, in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(description)
                    .font(.caption)
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
            Text("Exercise Recommendation")
                .font(.headline.weight(.bold))
                .padding(.horizontal)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(currentPhase.color.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommended for \(currentPhase.displayName)")
                        .font(.subheadline.weight(.semibold))

                    Text(currentPhase.exerciseRecommendation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Intensity indicator
                    HStack(spacing: 4) {
                        Text("Intensity:")
                            .font(.caption2.weight(.medium))
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
            Text("Cycle History")
                .font(.headline.weight(.bold))
                .padding(.horizontal)

            if cycleHistory.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Not enough cycle data yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Average cycle length: \(avg) days")
                            .font(.caption.weight(.medium))
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
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(cycleLengthColor(entry.length), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.startDate, format: .dateTime.month(.wide).day().year())
                    .font(.subheadline.weight(.medium))

                Text("\(entry.length) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Length deviation from average
            deviationLabel(for: entry.length)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, DS.cardPadding)
    }

    @ViewBuilder
    private func deviationLabel(for length: Int) -> some View {
        if let avgLength = averageCycleLength {
            let diff = length - avgLength
            if diff != 0 {
                Text(diff > 0 ? "+\(diff)d" : "\(diff)d")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(abs(diff) <= 2 ? Color.secondary : Color.orange)
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
            return abs(length - avg) <= 2 ? .blue : .orange
        }
        return .blue
    }

    // MARK: - Next Period Section

    private var nextPeriodSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text("Next Period Estimate")
                .font(.headline.weight(.bold))
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
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text("days")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if let date = nextPeriodDate {
                        Text("Estimated Start")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.subheadline.weight(.bold))

                        Text("Based on your \(cycleLength)-day average cycle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("Estimated Start")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text("In about \(daysUntilPeriod) days")
                            .font(.subheadline.weight(.bold))
                    }
                }

                Spacer()
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: .red)
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
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
                CycleHistoryEntry(startDate: Calendar.current.date(byAdding: .day, value: -28, to: .now)!, length: 28),
                CycleHistoryEntry(startDate: Calendar.current.date(byAdding: .day, value: -56, to: .now)!, length: 27),
                CycleHistoryEntry(startDate: Calendar.current.date(byAdding: .day, value: -83, to: .now)!, length: 29),
                CycleHistoryEntry(startDate: Calendar.current.date(byAdding: .day, value: -112, to: .now)!, length: 28),
                CycleHistoryEntry(startDate: Calendar.current.date(byAdding: .day, value: -140, to: .now)!, length: 30),
            ],
            nextPeriodDate: Calendar.current.date(byAdding: .day, value: 20, to: .now)
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
            nextPeriodDate: Calendar.current.date(byAdding: .day, value: 25, to: .now)
        )
    }
}
