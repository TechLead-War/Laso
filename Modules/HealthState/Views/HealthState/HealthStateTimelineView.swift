import SwiftUI

/// Visualizes the HealthStateClassifier output. calendar view with color-coded states,
/// transition patterns, and distribution.
struct HealthStateTimelineView: View {
    let viewModel: HealthStateTimelineViewModel
    @State private var selectedMonth = Date()


    // Section trackers
    @State private var currentStateTracker = SectionTracker(section: .healthStateCurrent, tab: .healthStateTimeline)
    @State private var calendarTracker = SectionTracker(section: .healthStateCalendar, tab: .healthStateTimeline)
    @State private var distributionTracker = SectionTracker(section: .healthStateDistribution, tab: .healthStateTimeline)
    @State private var transitionsTracker = SectionTracker(section: .healthStateTransitions, tab: .healthStateTimeline)
    @State private var guideTracker = SectionTracker(section: .healthStateGuide, tab: .healthStateTimeline)

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                if viewModel.states.isEmpty {
                    // Day-1 cold start: classifier has not yet produced any
                    // states. Render a single explanatory card instead of four
                    // individually-empty sections.
                    emptyState
                        .padding(.horizontal)
                } else {
                    // 1. Current state hero
                    if let current = viewModel.currentState {
                        currentStateHero(current)
                            .padding(.horizontal)
                            .onAppear { currentStateTracker.appeared() }
                            .onDisappear { currentStateTracker.disappeared() }
                    }

                    // 2. Calendar grid
                    calendarSection
                        .padding(.horizontal)
                        .onAppear { calendarTracker.appeared() }
                        .onDisappear { calendarTracker.disappeared() }

                    // 3. State distribution
                    distributionBar
                        .padding(.horizontal)
                        .onAppear { distributionTracker.appeared() }
                        .onDisappear { distributionTracker.disappeared() }

                    // 4. Transition patterns
                    if !viewModel.commonTransitions.isEmpty {
                        transitionSection
                            .padding(.horizontal)
                            .onAppear { transitionsTracker.appeared() }
                            .onDisappear { transitionsTracker.disappeared() }
                    }

                    // 5. State descriptions
                    stateDescriptions
                        .padding(.horizontal)
                        .onAppear { guideTracker.appeared() }
                        .onDisappear { guideTracker.disappeared() }
                }
            }
            .padding(.vertical)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .accessibilityIdentifier("screen.healthStateTimeline")
        .navigationTitle("Health States")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.healthStateTimeline, metadata: [
                "states_count": viewModel.states.count,
                "history_days": viewModel.stateHistory.count
            ])
            if let current = viewModel.currentState {
                AppAnalytics.shared.trackHealthStateTimelineViewed(
                    currentState: current.label,
                    daysInState: current.daysInState,
                    totalStates: viewModel.states.count
                )
            }
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.healthStateTimeline)
        }
    }

    // MARK: - 1. Current State Hero

    private func currentStateHero(_ state: HealthState) -> some View {
        let color = viewModel.color(for: state.label)

        return VStack(spacing: DS.itemSpacing) {
            HStack(spacing: DS.space4) {
                Circle()
                    .fill(color)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: iconFor(state.label))
                            .font(DS.Typography.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: DS.space1) {
                    Text(state.label)
                        .font(DS.Typography.title3.weight(.bold))

                    Text("\(state.daysInState) day\(state.daysInState == 1 ? "" : "s") in this state")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: 0) {
                Text(viewModel.description(for: state.label))
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            // Transition prediction
            if let nextState = state.transitionProbabilities.max(by: { $0.value < $1.value }),
               nextState.key != state.label,
               let avgDays = viewModel.averageTransitionTime(from: state.label, to: nextState.key) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(color)
                    Text("You typically move to \(nextState.key) in ~\(String(format: "%.0f", avgDays)) days")
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                    Spacer()
                }
                .padding(DS.cardPadding)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }

            // Characteristics
            let notable = state.characteristics.filter { $0.level != .normal }
            if !notable.isEmpty {
                HStack(spacing: DS.space2) {
                    ForEach(Array(notable.prefix(4).enumerated()), id: \.offset) { _, char in
                        HStack(spacing: DS.space1) {
                            Image(systemName: char.level == .high ? "arrow.up" : "arrow.down")
                                .font(DS.Typography.caption2.weight(.bold))
                                .foregroundStyle(char.level == .high ? AppColour.success : AppColour.danger)
                            Text(char.metric.displayName)
                                .font(DS.Typography.caption2)
                                .foregroundStyle(AppColour.textSecondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(DS.space4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
    }

    // MARK: - 2. Calendar Grid

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            // Month navigation
            HStack {
                Button {
                    selectedMonth = Date.cal.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    AppAnalytics.shared.trackBlockTap(
                        title: "Previous Month",
                        type: .healthStatePrevMonth,
                        screen: .healthStateTimeline,
                        metadata: [
                            "direction": "previous",
                            "month": monthYearString(selectedMonth)
                        ]
                    )
                    calendarTracker.tapped(target: "previous_month")
                } label: {
                    Image(systemName: "chevron.left")
                        .font(DS.Typography.captionSemibold)
                }

                Spacer()

                Text(monthYearString(selectedMonth))
                    .font(DS.Typography.subheadlineSemibold)

                Spacer()

                Button {
                    let next = Date.cal.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    if next <= Date() {
                        selectedMonth = next
                        AppAnalytics.shared.trackBlockTap(
                            title: "Next Month",
                            type: .healthStateNextMonth,
                            screen: .healthStateTimeline,
                            metadata: [
                                "direction": "next",
                                "month": monthYearString(selectedMonth)
                            ]
                        )
                        calendarTracker.tapped(target: "next_month")
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.captionSemibold)
                }
                .disabled(Date.cal.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            }

            // Day-of-week header
            let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(DS.Typography.caption2Medium)
                        .foregroundStyle(AppColour.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar days
            let weeks = viewModel.calendarDays(for: selectedMonth)
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(week) { day in
                        calendarCell(day)
                    }
                }
            }

            // Legend
            HStack(spacing: DS.itemSpacing) {
                ForEach(viewModel.uniqueStateLabels.prefix(5), id: \.self) { label in
                    HStack(spacing: DS.space1) {
                        Circle()
                            .fill(viewModel.color(for: label))
                            .frame(width: 8, height: 8)
                        Text(label)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(.top, DS.space1)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func calendarCell(_ day: HealthStateTimelineViewModel.CalendarDay) -> some View {
        Group {
            if let label = day.stateLabel {
                Text("\(day.dayNumber)")
                    .font(DS.Typography.caption2.weight(.medium).monospacedDigit())
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background(viewModel.color(for: label).opacity(0.7), in: RoundedRectangle(cornerRadius: DS.Radius.xs))
                    .foregroundStyle(.white)
            } else if day.dayNumber > 0 {
                Text("\(day.dayNumber)")
                    .font(DS.Typography.caption2.monospacedDigit())
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .foregroundStyle(AppColour.textTertiary)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
        }
    }

    // MARK: - 3. State Distribution

    private var distributionBar: some View {
        let distribution = viewModel.stateDistribution(for: selectedMonth)
        let total = max(1, distribution.values.reduce(0, +))

        return VStack(alignment: .leading, spacing: DS.space2) {
            Text(Copy.HealthStateTimeline.distributionHeader)
                .font(DS.Typography.subheadlineSemibold)

            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(distribution.sorted(by: { $0.value > $1.value }), id: \.key) { label, count in
                        let fraction = CGFloat(count) / CGFloat(total)
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(viewModel.color(for: label))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
            }
            .frame(height: 16)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))

            HStack(spacing: DS.itemSpacing) {
                ForEach(distribution.sorted(by: { $0.value > $1.value }), id: \.key) { label, count in
                    let pct = Int(Double(count) / Double(total) * 100)
                    Text("\(label): \(pct)%")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(AppColour.textSecondary)
                }
                Spacer()
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 4. Transitions

    private var transitionSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.HealthStateTimeline.commonTransitionsHeader)
                .font(DS.Typography.subheadlineSemibold)

            ForEach(Array(viewModel.commonTransitions.prefix(5).enumerated()), id: \.offset) { _, transition in
                HStack(spacing: DS.space2) {
                    Circle()
                        .fill(viewModel.color(for: transition.from))
                        .frame(width: 10, height: 10)
                    Text(transition.from)
                        .font(DS.Typography.captionMedium)

                    Image(systemName: "arrow.right")
                        .font(DS.Typography.caption2)
                        .foregroundStyle(AppColour.textTertiary)

                    Circle()
                        .fill(viewModel.color(for: transition.to))
                        .frame(width: 10, height: 10)
                    Text(transition.to)
                        .font(DS.Typography.captionMedium)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(transition.probability * 100))%")
                            .font(DS.Typography.caption.weight(.bold).monospacedDigit())
                        if let avg = transition.avgDays {
                            Text("~\(String(format: "%.1f", avg))d")
                                .font(DS.Typography.caption2)
                                .foregroundStyle(AppColour.textSecondary)
                        }
                    }
                }
                .padding(.vertical, DS.space1)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 5. State Descriptions

    private var stateDescriptions: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.HealthStateTimeline.stateGuideHeader)
                .font(DS.Typography.subheadlineSemibold)

            ForEach(viewModel.states, id: \.label) { state in
                let color = viewModel.color(for: state.label)

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: DS.space1) {
                        ForEach(Array(state.characteristics.prefix(5).enumerated()), id: \.offset) { _, char in
                            HStack(spacing: DS.space2) {
                                Image(systemName: char.metric.systemImageName)
                                    .font(DS.Typography.caption2)
                                    .foregroundStyle(char.metric.category.color)
                                Text("\(char.metric.displayName): \(char.level.rawValue)")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(AppColour.textSecondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, DS.space1)
                } label: {
                    VStack(alignment: .leading, spacing: DS.space1) {
                        HStack(spacing: DS.space2) {
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)
                            Text(state.label)
                                .font(DS.Typography.subheadlineMedium)
                        }
                        Text(viewModel.description(for: state.label))
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - Empty State

    /// Day-1 cold-start placeholder shown until the classifier produces its
    /// first health state. Single centered card so the screen has weight while
    /// data is still being learned.
    private var emptyState: some View {
        VStack(spacing: DS.itemSpacing) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(DS.Typography.heroIcon)
                .foregroundStyle(.secondary)

            Text(Copy.HealthStateTimeline.emptyTitle)
                .font(DS.Typography.headline)
                .multilineTextAlignment(.center)

            Text(Copy.HealthStateTimeline.emptyBody)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.space7)
        .padding(.top, DS.space5)
    }

    // MARK: - Helpers

    private func iconFor(_ label: String) -> String {
        switch label {
        case "Recovery": return "heart.fill"
        case "Peak Performance": return "bolt.fill"
        case "Stressed": return "flame.fill"
        case "Under-Slept": return "moon.fill"
        case "Active": return "figure.run"
        case "Fatigued": return "battery.25percent"
        case "Resting": return "leaf.fill"
        case "Recovering": return "arrow.up.heart.fill"
        case "Strained": return "exclamationmark.triangle.fill"
        case "Low Energy": return "battery.0percent"
        case "Restful": return "moon.zzz.fill"
        case "Balanced": return "circle.dashed"
        default: return "circle.fill"
        }
    }

    private func monthYearString(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}
