import SwiftUI

// MARK: - Plan Goal

enum PlanGoalOption: String, CaseIterable, Identifiable, Codable {
    case sleepDeeper = "Sleep Deeper"
    case boostFitness = "Boost Fitness"
    case feelBetter = "Feel Better"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sleepDeeper: return "moon.fill"
        case .boostFitness: return "figure.run"
        case .feelBetter: return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .sleepDeeper: return .indigo
        case .boostFitness: return .green
        case .feelBetter: return .purple
        }
    }

    var description: String {
        switch self {
        case .sleepDeeper:
            return "Optimize sleep duration and quality with tailored daily targets and rest day scheduling."
        case .boostFitness:
            return "Progressive strain targets to build cardiovascular fitness while managing recovery."
        case .feelBetter:
            return "Balance activity and recovery to improve HRV, reduce stress, and feel your best."
        }
    }
}

// MARK: - Daily Target

struct PlanDayTarget: Identifiable {
    let id = UUID()
    let date: Date
    let targetStrainLow: Double
    let targetStrainHigh: Double
    let targetSleepHours: Double
    let isRestDay: Bool
    let completion: DayCompletion

    enum DayCompletion {
        case met
        case partial
        case missed
        case pending
    }
}

// MARK: - Weekly Plan

struct WeeklyPlanData: Identifiable {
    let id = UUID()
    let goal: PlanGoalOption
    let weekStartDate: Date
    let dailyTargets: [PlanDayTarget]
    let adherencePercent: Double
    let todayFocusMessage: String
    let daysCompleted: Int
}

// MARK: - Weekly Plan View

struct WeeklyPlanView: View {
    let activePlan: WeeklyPlanData?
    let onSelectGoal: (PlanGoalOption) -> Void
    let onSetNextWeekGoal: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            if let plan = activePlan {
                if isWeekComplete(plan) {
                    weekSummaryContent(plan)
                } else {
                    activePlanContent(plan)
                }
            } else {
                goalSelectorContent
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Weekly Plan")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.weeklyPlan)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.weeklyPlan)
        }
    }

    // MARK: - Goal Selector (No Active Plan)

    private var goalSelectorContent: some View {
        VStack(spacing: DS.sectionSpacing) {
            // Header prompt
            VStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)

                Text("Choose Your Focus")
                    .font(.title2.weight(.bold))

                Text("Pick a goal for this week. Your plan adapts daily targets to match.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 12)

            // Plan cards
            VStack(spacing: DS.itemSpacing) {
                ForEach(PlanGoalOption.allCases) { goal in
                    goalCard(goal)
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 24)
        }
        .padding(.vertical, 16)
    }

    private func goalCard(_ goal: PlanGoalOption) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(goal.color, in: RoundedRectangle(cornerRadius: DS.iconRadius))

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.rawValue)
                        .font(.headline)

                    Text(goal.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Button {
                onSelectGoal(goal)
            } label: {
                Text("Start This Plan")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(goal.color, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: goal.color)
    }

    // MARK: - Active Plan View

    private func activePlanContent(_ plan: WeeklyPlanData) -> some View {
        VStack(spacing: DS.sectionSpacing) {
            // Header
            planHeader(plan)

            // Adherence ring
            adherenceRing(plan)

            // 7-day grid
            dayGrid(plan)

            // Today's focus
            todayFocusCard(plan)

            // Progress bar
            progressSection(plan)

            Spacer(minLength: 24)
        }
        .padding(.vertical, 16)
    }

    private func planHeader(_ plan: WeeklyPlanData) -> some View {
        HStack(spacing: 12) {
            Image(systemName: plan.goal.icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(plan.goal.color, in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.goal.rawValue)
                    .font(.title3.weight(.bold))

                Text("Week of \(weekOfLabel(plan.weekStartDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    private func adherenceRing(_ plan: WeeklyPlanData) -> some View {
        ZStack {
            Circle()
                .stroke(plan.goal.color.opacity(0.15), lineWidth: 10)
                .frame(width: 100, height: 100)

            Circle()
                .trim(from: 0, to: plan.adherencePercent / 100.0)
                .stroke(plan.goal.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(Int(plan.adherencePercent))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("Adherence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - 7-Day Grid

    private func dayGrid(_ plan: WeeklyPlanData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "calendar", title: "This Week")

            HStack(spacing: 6) {
                ForEach(plan.dailyTargets) { target in
                    dayCell(target, plan: plan)
                }
            }
            .padding(.horizontal)
        }
    }

    private func dayCell(_ target: PlanDayTarget, plan: WeeklyPlanData) -> some View {
        let isToday = calendar.isDateInToday(target.date)
        let isFuture = target.date > Date.now && !isToday
        let dayAbbrev = dayAbbreviation(target.date)

        return VStack(spacing: 6) {
            // Day label
            Text(dayAbbrev)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? AnyShapeStyle(plan.goal.color) : (isFuture ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary)))

            // Completion / rest indicator
            ZStack {
                Circle()
                    .fill(cellBackgroundColor(target, isFuture: isFuture, planColor: plan.goal.color))
                    .frame(width: 36, height: 36)

                if target.isRestDay {
                    Text("R")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isFuture ? AnyShapeStyle(.tertiary) : AnyShapeStyle(plan.goal.color))
                } else {
                    completionIcon(target.completion, isFuture: isFuture)
                }
            }
            .overlay {
                if isToday {
                    Circle()
                        .strokeBorder(plan.goal.color, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
            }

            // Strain range
            if !target.isRestDay {
                Text("\(Int(target.targetStrainLow))-\(Int(target.targetStrainHigh))")
                    .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(isFuture ? .tertiary : .secondary)
            } else {
                Text("Rest")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isFuture ? .tertiary : .secondary)
            }

            // Sleep target
            Text("\(String(format: "%.0f", target.targetSleepHours))h")
                .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(isFuture ? .quaternary : .tertiary)
        }
        .frame(maxWidth: .infinity)
        .opacity(isFuture ? 0.6 : 1.0)
    }

    private func cellBackgroundColor(_ target: PlanDayTarget, isFuture: Bool, planColor: Color) -> Color {
        if isFuture {
            return Color(.systemGray5)
        }

        switch target.completion {
        case .met:
            return .green.opacity(DS.badgeBg)
        case .partial:
            return .yellow.opacity(DS.badgeBg)
        case .missed:
            return .red.opacity(DS.badgeBg)
        case .pending:
            return planColor.opacity(DS.tintBg)
        }
    }

    @ViewBuilder
    private func completionIcon(_ completion: PlanDayTarget.DayCompletion, isFuture: Bool) -> some View {
        switch completion {
        case .met:
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.green)
        case .partial:
            Image(systemName: "minus")
                .font(.caption.weight(.bold))
                .foregroundStyle(.yellow)
        case .missed:
            Image(systemName: "xmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(.red)
        case .pending:
            if isFuture {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 6, height: 6)
            } else {
                Image(systemName: "circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Today's Focus

    private func todayFocusCard(_ plan: WeeklyPlanData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "scope", title: "Today's Focus")

            HStack(spacing: 12) {
                Image(systemName: todayIsRestDay(plan) ? "bed.double.fill" : "bolt.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(plan.goal.color, in: Circle())

                Text(plan.todayFocusMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(tint: plan.goal.color)
            .padding(.horizontal)
        }
    }

    // MARK: - Progress

    private func progressSection(_ plan: WeeklyPlanData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "chart.bar.fill", title: "Progress")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(plan.daysCompleted) of 7 days completed")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text("\(Int(Double(plan.daysCompleted) / 7.0 * 100))%")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(plan.goal.color)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        Capsule()
                            .fill(plan.goal.color.gradient)
                            .frame(width: max(geo.size.width * CGFloat(plan.daysCompleted) / 7.0, 8), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    // MARK: - Week Summary (End of Week)

    private func weekSummaryContent(_ plan: WeeklyPlanData) -> some View {
        VStack(spacing: DS.sectionSpacing) {
            // Plan header
            planHeader(plan)

            // Large adherence score
            VStack(spacing: 8) {
                Text("\(Int(plan.adherencePercent))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(adherenceColor(plan.adherencePercent))

                Text("Adherence Score")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            // Met / missed breakdown
            metMissedBreakdown(plan)

            // CTA
            Button {
                onSetNextWeekGoal()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.body)
                    Text("Set Next Week's Goal")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(plan.goal.color, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            Spacer(minLength: 24)
        }
        .padding(.vertical, 16)
    }

    private func metMissedBreakdown(_ plan: WeeklyPlanData) -> some View {
        let met = plan.dailyTargets.filter { $0.completion == .met }.count
        let partial = plan.dailyTargets.filter { $0.completion == .partial }.count
        let missed = plan.dailyTargets.filter { $0.completion == .missed }.count

        return HStack(spacing: 0) {
            breakdownColumn(label: "Met", value: "\(met)", color: .green)

            Rectangle()
                .fill(.quaternary)
                .frame(width: 1, height: DS.dividerHeight)

            breakdownColumn(label: "Partial", value: "\(partial)", color: .yellow)

            Rectangle()
                .fill(.quaternary)
                .frame(width: 1, height: DS.dividerHeight)

            breakdownColumn(label: "Missed", value: "\(missed)", color: .red)
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
    }

    private func breakdownColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal)
    }

    private func weekOfLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func dayAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(3))
    }

    private func isWeekComplete(_ plan: WeeklyPlanData) -> Bool {
        plan.daysCompleted >= 7
    }

    private func todayIsRestDay(_ plan: WeeklyPlanData) -> Bool {
        plan.dailyTargets.first { calendar.isDateInToday($0.date) }?.isRestDay ?? false
    }

    private func adherenceColor(_ percent: Double) -> Color {
        if percent >= 80 { return .green }
        if percent >= 50 { return .yellow }
        return .red
    }
}

// MARK: - Preview

#Preview("Goal Selector") {
    NavigationStack {
        WeeklyPlanView(
            activePlan: nil,
            onSelectGoal: { _ in },
            onSetNextWeekGoal: { }
        )
    }
}

#Preview("Active Plan") {
    let cal = Calendar.current
    let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now))!

    let targets = (0..<7).map { offset -> PlanDayTarget in
        let date = cal.date(byAdding: .day, value: offset, to: monday)!
        let isRest = offset == 3 || offset == 6
        let completion: PlanDayTarget.DayCompletion = {
            if cal.isDateInToday(date) { return .pending }
            if date > .now { return .pending }
            if isRest { return .met }
            return [.met, .partial, .missed][offset % 3]
        }()

        return PlanDayTarget(
            date: date,
            targetStrainLow: isRest ? 0 : 10,
            targetStrainHigh: isRest ? 5 : 16,
            targetSleepHours: isRest ? 8.5 : 7.5,
            isRestDay: isRest,
            completion: completion
        )
    }

    NavigationStack {
        WeeklyPlanView(
            activePlan: WeeklyPlanData(
                goal: .boostFitness,
                weekStartDate: monday,
                dailyTargets: targets,
                adherencePercent: 72,
                todayFocusMessage: "Push for 14+ strain today to stay on track for your fitness goal.",
                daysCompleted: 4
            ),
            onSelectGoal: { _ in },
            onSetNextWeekGoal: { }
        )
    }
}

#Preview("Week Summary") {
    let cal = Calendar.current
    let monday = cal.date(byAdding: .day, value: -7, to: .now)!

    let targets = (0..<7).map { offset -> PlanDayTarget in
        let date = cal.date(byAdding: .day, value: offset, to: monday)!
        let isRest = offset == 3 || offset == 6
        let completion: PlanDayTarget.DayCompletion = {
            if isRest { return .met }
            return [.met, .met, .partial, .missed, .met][offset % 5]
        }()

        return PlanDayTarget(
            date: date,
            targetStrainLow: isRest ? 0 : 8,
            targetStrainHigh: isRest ? 5 : 14,
            targetSleepHours: 8,
            isRestDay: isRest,
            completion: completion
        )
    }

    NavigationStack {
        WeeklyPlanView(
            activePlan: WeeklyPlanData(
                goal: .sleepDeeper,
                weekStartDate: monday,
                dailyTargets: targets,
                adherencePercent: 71,
                todayFocusMessage: "Rest and recover tonight.",
                daysCompleted: 7
            ),
            onSelectGoal: { _ in },
            onSetNextWeekGoal: { }
        )
    }
}
