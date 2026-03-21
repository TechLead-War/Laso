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
                            .padding(.top, 8)
                            .padding(.bottom, DS.itemSpacing)

                        behaviorList
                            .padding(.bottom, hasModifications ? 80 : 16)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(Color(.systemGroupedBackground).ignoresSafeArea())

                if hasModifications {
                    saveBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: hasModifications)
            .navigationTitle("Daily Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
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
                    .padding(.vertical, 4)
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
        HStack(spacing: 8) {
            Image(systemName: group.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(group.color)
                .frame(width: 24, height: 24)
                .background(group.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 6))

            Text(group.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            let count = groupLoggedCount(group)
            if count > 0 {
                Text("\(count)")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(group.color)
                    .padding(.horizontal, DS.badgeH)
                    .padding(.vertical, DS.badgeV)
                    .background(group.color.opacity(DS.badgeBg), in: Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func groupLoggedCount(_ group: JournalBehaviorGroup) -> Int {
        JournalBehavior.behaviors(in: group).filter { loggedBehaviors[$0] != nil }.count
    }

    // MARK: - Behavior Row

    private func behaviorRow(_ behavior: JournalBehavior, group: JournalBehaviorGroup) -> some View {
        let isLogged = loggedBehaviors[behavior] != nil

        return HStack(spacing: 10) {
            // Icon
            Image(systemName: behavior.icon)
                .font(.body.weight(.medium))
                .foregroundStyle(isLogged ? group.color : .secondary)
                .frame(width: 28)

            // Label
            Text(behavior.displayName)
                .font(.subheadline.weight(isLogged ? .semibold : .regular))
                .foregroundStyle(isLogged ? .primary : .secondary)
                .lineLimit(1)

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
                    .font(.body)
                    .foregroundStyle(currentValue != nil ? color : Color(.tertiaryLabel))
            }
            .disabled(currentValue == nil)
            .buttonStyle(.plain)

            // Value display
            Text(formattedQuantity(displayValue, step: step))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(currentValue != nil ? .primary : .tertiary)
                .frame(minWidth: 24, alignment: .center)
                .contentTransition(.numericText())

            // Unit label
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 48, alignment: .leading)

            // Plus button
            Button {
                let current = currentValue ?? 0
                loggedBehaviors[behavior] = current + step
                toggleTrigger.toggle()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
                    .foregroundStyle(color)
            }
            .buttonStyle(.plain)
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
                        .font(.caption)
                        .foregroundStyle(isFilled ? color : Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }

            if let value = currentValue {
                Text(formattedRating(value, maxValue: maxValue))
                    .font(.caption2.weight(.semibold).monospacedDigit())
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
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Log \(loggedBehaviors.count) Behavior\(loggedBehaviors.count == 1 ? "" : "s")")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.blue, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Logged \(savedCount) behavior\(savedCount == 1 ? "" : "s")")
                .font(.title3.weight(.semibold))
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Save Logic

    private func saveBehaviors() {
        let store = JournalStore(modelContext: modelContext)
        let today = Calendar.current.startOfDay(for: Date())
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
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
