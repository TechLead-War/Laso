import SwiftUI
import SwiftData

/// Fast multi-behavior journal sheet. log 5-10 behaviors in under 30 seconds.
/// Presents 55 behaviors organized by group with filter pills and compact input rows.
struct ExpandedJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Which behaviors the user has actively set, keyed by behavior with the logged value.
    @State private var loggedBehaviors: [JournalBehavior: Double] = [:]

    /// Currently selected group filter (nil = show all groups)
    @State private var selectedGroup: JournalBehaviorGroup?

    /// Confirmation overlay state
    @State private var showConfirmation = false
    @State private var savedCount = 0

    /// Haptic trigger for toggle changes
    @State private var toggleTrigger = false


    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        groupFilterBar
                            .padding(.top, DS.space2)
                            .padding(.bottom, DS.itemSpacing)

                        behaviorList
                            .padding(.bottom, hasModifications ? 80 : 16)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(AppColour.surfaceBase.ignoresSafeArea())

                if hasModifications {
                    saveBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: hasModifications)
            .navigationTitle(Copy.Journal.dailyCheckInTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.Buttons.cancel) { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: toggleTrigger)
            .overlay {
                if showConfirmation {
                    confirmationOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .onAppear {
                AppAnalytics.shared.trackFeatureOpen(.expandedJournal)
            }
            .onDisappear {
                AppAnalytics.shared.trackFeatureClose(.expandedJournal)
            }
            .task(id: showConfirmation) {
                guard showConfirmation else { return }
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
    }

    // MARK: - Computed

    private var hasModifications: Bool {
        !loggedBehaviors.isEmpty
    }

    private var displayedGroups: [JournalBehaviorGroup] {
        if let group = selectedGroup {
            return [group]
        }
        return JournalBehaviorGroup.allCases
    }

    // MARK: - Group Filter Bar

    private var groupFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" pill
                filterPill(label: "All", icon: "square.grid.2x2.fill", color: .primary, isSelected: selectedGroup == nil) {
                    selectedGroup = nil
                }

                ForEach(JournalBehaviorGroup.allCases) { group in
                    filterPill(label: group.displayName, icon: group.icon, color: group.color, isSelected: selectedGroup == group) {
                        selectedGroup = selectedGroup == group ? nil : group
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func filterPill(label: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.space1) {
                Image(systemName: icon)
                    .font(DS.Typography.caption2Semibold)
                Text(label)
                    .font(DS.Typography.subheadlineMedium)
            }
            .padding(.horizontal, DS.space3)
            .padding(.vertical, DS.space2)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.dsPress)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Behavior List

    private var behaviorList: some View {
        LazyVStack(spacing: DS.sectionSpacing, pinnedViews: .sectionHeaders) {
            ForEach(displayedGroups) { group in
                Section {
                    VStack(spacing: 0) {
                        let behaviors = JournalBehavior.behaviors(in: group)
                        ForEach(Array(behaviors.enumerated()), id: \.element.id) { index, behavior in
                            behaviorRow(behavior, group: group)

                            if index < behaviors.count - 1 {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .padding(.vertical, DS.space1)
                    .cardStyle()
                    .padding(.horizontal)
                } header: {
                    sectionHeader(group)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ group: JournalBehaviorGroup) -> some View {
        HStack(spacing: DS.space2) {
            Image(systemName: group.icon)
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(group.color)
                .frame(width: 24, height: 24)
                .background(group.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.xs))

            Text(group.displayName)
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(AppColour.textPrimary)

            Spacer()

            let count = groupLoggedCount(group)
            if count > 0 {
                Text(Copy.Journal.xText(count))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(group.color)
                    .padding(.horizontal, DS.badgeH)
                    .padding(.vertical, DS.badgeV)
                    .background(group.color.opacity(DS.badgeBg), in: Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DS.space2)
        .background(.bar)
    }

    private func groupLoggedCount(_ group: JournalBehaviorGroup) -> Int {
        JournalBehavior.behaviors(in: group).filter { loggedBehaviors[$0] != nil }.count
    }

    // MARK: - Behavior Row

    private func behaviorRow(_ behavior: JournalBehavior, group: JournalBehaviorGroup) -> some View {
        let isLogged = loggedBehaviors[behavior] != nil

        return HStack(spacing: DS.space3) {
            // Icon
            Image(systemName: behavior.icon)
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(isLogged ? group.color : AppColour.textSecondary)
                .frame(width: 28)

            // Label
            Text(behavior.displayName)
                .font(isLogged ? DS.Typography.subheadlineSemibold : DS.Typography.subheadline)
                .foregroundStyle(isLogged ? AppColour.textPrimary : AppColour.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 4)

            // Input control
            inputControl(for: behavior, group: group)
        }
        .frame(height: 44)
        .padding(.horizontal, DS.cardPadding)
        .contentShape(Rectangle())
    }

    // MARK: - Input Controls

    @ViewBuilder
    private func inputControl(for behavior: JournalBehavior, group: JournalBehaviorGroup) -> some View {
        switch behavior.inputType {
        case .yesNo:
            yesNoControl(for: behavior, color: group.color)
        case .quantity(let unit, _, let step):
            quantityControl(for: behavior, unit: unit, step: step, color: group.color)
        case .rating(let maxValue):
            ratingControl(for: behavior, maxValue: maxValue, color: group.color)
        }
    }

    // MARK: Yes/No Toggle

    private func yesNoControl(for behavior: JournalBehavior, color: Color) -> some View {
        let isOn = loggedBehaviors[behavior] == 1

        return Toggle(isOn: Binding(
            get: { isOn },
            set: { newValue in
                if newValue {
                    loggedBehaviors[behavior] = 1
                } else {
                    loggedBehaviors.removeValue(forKey: behavior)
                }
                toggleTrigger.toggle()
            }
        )) {
            EmptyView()
        }
        .toggleStyle(.switch)
        .tint(color)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel(behavior.displayName)
        .accessibilityHint(Copy.Journal.toggleToLogOrUnlogHint(behavior.displayName))
    }

    // MARK: Quantity Stepper

    private func quantityControl(for behavior: JournalBehavior, unit: String, step: Double, color: Color) -> some View {
        let currentValue = loggedBehaviors[behavior]
        let displayValue = currentValue ?? 0

        return HStack(spacing: 6) {
            // Minus button
            Button {
                let newValue = displayValue - step
                if newValue <= 0 {
                    loggedBehaviors.removeValue(forKey: behavior)
                } else {
                    loggedBehaviors[behavior] = newValue
                }
                toggleTrigger.toggle()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(DS.Typography.body)
                    .foregroundStyle(currentValue != nil ? color : AppColour.textTertiary)
            }
            .disabled(currentValue == nil)
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.Journal.decreaseLabel(behavior.displayName))
            .accessibilityHint(Copy.Journal.decreasesTheLoggedAmountByHint(formattedQuantity(step, step: step), unit))

            // Value display
            Text(formattedQuantity(displayValue, step: step))
                .font(DS.Typography.subheadlineSemibold.monospacedDigit())
                .foregroundStyle(currentValue != nil ? AppColour.textPrimary : AppColour.textTertiary)
                .frame(minWidth: 24, alignment: .center)
                .contentTransition(.numericText())

            // Unit label
            Text(unit)
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: 48, alignment: .leading)

            // Plus button
            Button {
                let current = currentValue ?? 0
                loggedBehaviors[behavior] = current + step
                toggleTrigger.toggle()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(DS.Typography.body)
                    .foregroundStyle(color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.Journal.increaseLabel(behavior.displayName))
            .accessibilityHint(Copy.Journal.increasesTheLoggedAmountByHint(formattedQuantity(step, step: step), unit))
        }
    }

    // MARK: Rating Control

    private func ratingControl(for behavior: JournalBehavior, maxValue: Int, color: Color) -> some View {
        let currentValue = loggedBehaviors[behavior]
        let displayMax = min(maxValue, 5)  // show at most 5 tappable circles
        let scaleFactor = maxValue > 5 ? Double(maxValue) / Double(displayMax) : 1.0

        return HStack(spacing: 4) {
            ForEach(1...displayMax, id: \.self) { index in
                let scaledValue = Double(index) * scaleFactor
                let isFilled = currentValue != nil && currentValue! >= scaledValue

                Button {
                    if currentValue == scaledValue {
                        loggedBehaviors.removeValue(forKey: behavior)
                    } else {
                        loggedBehaviors[behavior] = scaledValue
                    }
                    toggleTrigger.toggle()
                } label: {
                    Image(systemName: isFilled ? "circle.fill" : "circle")
                        .font(DS.Typography.caption)
                        .foregroundStyle(isFilled ? color : AppColour.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Copy.Journal.ratingOfLabel(behavior.displayName, index, displayMax))
                .accessibilityHint(Copy.Journal.selectsRatingOutOfHint(index, displayMax))
                .accessibilityAddTraits(isFilled ? .isSelected : [])
            }

            if let value = currentValue {
                Text(formattedRating(value, maxValue: maxValue))
                    .font(DS.Typography.caption2Semibold.monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        Button {
            saveBehaviors()
        } label: {
            HStack(spacing: DS.space2) {
                Image(systemName: "checkmark.circle.fill")
                Text(Copy.Journal.logCount(loggedBehaviors.count))
                    .font(DS.Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.space4)
            .background(AppColour.primary, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .padding(.horizontal)
        }
        .buttonStyle(.dsPress)
        .accessibilityLabel(Copy.Journal.loggedCount(loggedBehaviors.count))
        .accessibilityHint(Copy.Journal.savesTheSelectedBehaviorsAndDismissesHint)
        .padding(.bottom, DS.space2)
        .background(
            LinearGradient(
                colors: [AppColour.surfaceBase.opacity(0), AppColour.surfaceBase],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        VStack(spacing: DS.itemSpacing) {
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.heroIcon)
                .foregroundStyle(AppColour.success)
            Text(Copy.Journal.loggedCount(savedCount))
                .font(DS.Typography.title3)
        }
        .padding(DS.space7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
    }

    // MARK: - Save Logic

    private func saveBehaviors() {
        let store = JournalStore(modelContext: modelContext)
        let today = Date.cal.startOfDay(for: Date())
        var count = 0

        for (behavior, value) in loggedBehaviors {
            if let legacyCategory = behavior.legacyCategory {
                // Save via legacy path so existing correlation analysis picks it up.
                // JournalStore.save uses JournalCategory.rawValue as the key.
                store.save(category: legacyCategory, value: value, date: today)
            } else {
                // New expanded behavior. save with behavior rawValue as category key
                let entry = StoredJournalEntry(
                    date: today,
                    categoryRawValue: behavior.rawValue,
                    value: value
                )
                modelContext.insert(entry)
            }
            count += 1
        }
        try? modelContext.save()

        savedCount = count
        withAnimation(.spring(duration: 0.4)) {
            showConfirmation = true
        }
    }

    // MARK: - Formatting Helpers

    private func formattedQuantity(_ value: Double, step: Double) -> String {
        if step >= 1 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func formattedRating(_ value: Double, maxValue: Int) -> String {
        "\(Int(value))/\(maxValue)"
    }
}
