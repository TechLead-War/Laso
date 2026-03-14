import SwiftUI

/// Visualizes the HealthStateClassifier output — calendar view with color-coded states,
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
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
        let rgb = viewModel.color(for: state.label)
        let color = Color(red: rgb.r, green: rgb.g, blue: rgb.b)

        return VStack(spacing: 10) {
            HStack(spacing: 16) {
                Circle()
                    .fill(color)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: iconFor(state.label))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.label)
                        .font(.title3.weight(.bold))

                    Text("\(state.daysInState) day\(state.daysInState == 1 ? "" : "s") in this state")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Transition prediction
            if let nextState = state.transitionProbabilities.max(by: { $0.value < $1.value }),
               nextState.key != state.label,
               let avgDays = viewModel.averageTransitionTime(from: state.label, to: nextState.key) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(color)
                    Text("You typically move to \(nextState.key) in ~\(String(format: "%.0f", avgDays)) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(DS.cardPadding)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.iconRadius))
            }

            // Characteristics
            let notable = state.characteristics.filter { $0.level != .normal }
            if !notable.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(notable.prefix(4).enumerated()), id: \.offset) { _, char in
                        HStack(spacing: 3) {
                            Image(systemName: char.level == .high ? "arrow.up" : "arrow.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(char.level == .high ? .green : .red)
                            Text(char.metric.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - 2. Calendar Grid

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Month navigation
            HStack {
                Button {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
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
                        .font(.caption.weight(.semibold))
                }

                Spacer()

                Text(monthYearString(selectedMonth))
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
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
                        .font(.caption.weight(.semibold))
                }
                .disabled(Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month))
            }

            // Day-of-week header
            let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
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
            HStack(spacing: 12) {
                ForEach(viewModel.uniqueStateLabels.prefix(5), id: \.self) { label in
                    let rgb = viewModel.color(for: label)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                            .frame(width: 8, height: 8)
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func calendarCell(_ day: HealthStateTimelineViewModel.CalendarDay) -> some View {
        Group {
            if let label = day.stateLabel {
                let rgb = viewModel.color(for: label)
                Text("\(day.dayNumber)")
                    .font(.caption2.weight(.medium).monospacedDigit())
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .background(Color(red: rgb.r, green: rgb.g, blue: rgb.b).opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.white)
            } else if day.dayNumber > 0 {
                Text("\(day.dayNumber)")
                    .font(.caption2.monospacedDigit())
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .foregroundStyle(.tertiary)
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

        return VStack(alignment: .leading, spacing: 8) {
            Text("Distribution")
                .font(.subheadline.weight(.semibold))

            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(distribution.sorted(by: { $0.value > $1.value }), id: \.key) { label, count in
                        let rgb = viewModel.color(for: label)
                        let fraction = CGFloat(count) / CGFloat(total)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: rgb.r, green: rgb.g, blue: rgb.b))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
            }
            .frame(height: 16)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 12) {
                ForEach(distribution.sorted(by: { $0.value > $1.value }), id: \.key) { label, count in
                    let pct = Int(Double(count) / Double(total) * 100)
                    Text("\(label): \(pct)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 4. Transitions

    private var transitionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Common Transitions")
                .font(.subheadline.weight(.semibold))

            ForEach(Array(viewModel.commonTransitions.prefix(5).enumerated()), id: \.offset) { _, transition in
                HStack(spacing: 8) {
                    let fromRgb = viewModel.color(for: transition.from)
                    let toRgb = viewModel.color(for: transition.to)

                    Circle()
                        .fill(Color(red: fromRgb.r, green: fromRgb.g, blue: fromRgb.b))
                        .frame(width: 10, height: 10)
                    Text(transition.from)
                        .font(.caption.weight(.medium))

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Circle()
                        .fill(Color(red: toRgb.r, green: toRgb.g, blue: toRgb.b))
                        .frame(width: 10, height: 10)
                    Text(transition.to)
                        .font(.caption.weight(.medium))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(transition.probability * 100))%")
                            .font(.caption.weight(.bold).monospacedDigit())
                        if let avg = transition.avgDays {
                            Text("~\(String(format: "%.1f", avg))d")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 5. State Descriptions

    private var stateDescriptions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("State Guide")
                .font(.subheadline.weight(.semibold))

            ForEach(viewModel.states, id: \.label) { state in
                let rgb = viewModel.color(for: state.label)
                let color = Color(red: rgb.r, green: rgb.g, blue: rgb.b)

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(state.characteristics.prefix(5).enumerated()), id: \.offset) { _, char in
                            HStack(spacing: 6) {
                                Image(systemName: char.metric.systemImageName)
                                    .font(.caption2)
                                    .foregroundStyle(char.metric.category.color)
                                Text("\(char.metric.displayName): \(char.level.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                        Text(state.label)
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
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
        default: return "circle.fill"
        }
    }

    private func monthYearString(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}
