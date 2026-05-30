import SwiftUI
import SwiftData

/// Quick-log sheet for recording behavioral journal entries.
/// Presented as a sheet from the Home tab.
struct JournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedCategory: JournalCategory?
    @State private var value: Double = 0
    @State private var notes: String = ""
    @State private var showConfirmation = false

    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Category picker grid
                    categoryGrid

                    // Value input (shown after category selection)
                    if let category = selectedCategory {
                        valueInput(for: category)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        // Optional notes
                        notesField

                        // Save button
                        saveButton(for: category)
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.25), value: selectedCategory)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppColour.surfaceBase.ignoresSafeArea())
            .navigationTitle(Copy.Journal.logEntryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("screen.journalEntry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.Buttons.cancel) {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Cancel",
                            type: .journalEntryCancelled,
                            screen: .journalEntry,
                            metadata: ["had_category": selectedCategory != nil]
                        )
                        dismiss()
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedCategory)
            .overlay {
                if showConfirmation {
                    confirmationOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .onAppear {
                AppAnalytics.shared.trackFeatureOpen(.journalEntry)
            }
            .onDisappear {
                AppAnalytics.shared.trackFeatureClose(.journalEntry)
            }
            .task(id: showConfirmation) {
                guard showConfirmation else { return }
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Text(Copy.Journal.whatToLog)
                .font(DS.Typography.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(JournalCategory.allCases) { category in
                    categoryTile(category)
                }
            }
        }
    }

    private func categoryTile(_ category: JournalCategory) -> some View {
        Button {
            if selectedCategory == category {
                selectedCategory = nil
            } else {
                selectedCategory = category
                value = category.valueRange.lowerBound
                AppAnalytics.shared.trackBlockTap(
                    title: category.displayName,
                    type: .journalCategorySelected,
                    screen: .journalEntry,
                    metadata: ["category": category.rawValue]
                )
            }
        } label: {
            VStack(spacing: DS.space2) {
                Image(systemName: category.icon)
                    .font(DS.Typography.mediumIcon)
                    .foregroundStyle(selectedCategory == category ? .white : categoryColor(category))
                    .frame(width: DS.iconSize, height: DS.iconSize)

                Text(category.displayName)
                    .font(DS.Typography.captionMedium)
                    .foregroundStyle(selectedCategory == category ? .white : AppColour.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                selectedCategory == category
                    ? AnyShapeStyle(categoryColor(category))
                    : AnyShapeStyle(AppColour.surfaceRaised),
                in: RoundedRectangle(cornerRadius: DS.cardRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.cardRadius)
                    .strokeBorder(
                        selectedCategory == category
                            ? categoryColor(category).opacity(0.5)
                            : .primary.opacity(0.06),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.dsPress)
        .accessibilityLabel(category.displayName)
        .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
    }

    // MARK: - Value Input

    private func valueInput(for category: JournalCategory) -> some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            HStack {
                Text(Copy.Journal.amount)
                    .font(DS.Typography.headline)
                Spacer()
                Text(Copy.Journal.valueWithUnitText(formattedValue(value, for: category), category.unit))
                    .font(DS.Typography.title3.monospacedDigit())
                    .foregroundStyle(categoryColor(category))
                    .contentTransition(.numericText())
            }

            if category.usesStepper {
                stepperInput(for: category)
            } else {
                sliderInput(for: category)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func stepperInput(for category: JournalCategory) -> some View {
        HStack(spacing: DS.space4) {
            Button {
                let newValue = value - category.step
                if newValue >= category.valueRange.lowerBound {
                    value = newValue
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(DS.Typography.title2)
                    .foregroundStyle(value > category.valueRange.lowerBound ? categoryColor(category) : AppColour.textTertiary)
            }
            .disabled(value <= category.valueRange.lowerBound)
            .accessibilityLabel(Copy.Journal.decreaseLabel(category.displayName))
            .accessibilityHint(Copy.Journal.decreasesTheValueByHint(category.step, category.unit))

            Spacer()

            Text(formattedValue(value, for: category))
                .font(DS.Typography.displayL)
                .foregroundStyle(AppColour.textPrimary)
                .contentTransition(.numericText())

            Spacer()

            Button {
                let newValue = value + category.step
                if newValue <= category.valueRange.upperBound {
                    value = newValue
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(DS.Typography.title2)
                    .foregroundStyle(value < category.valueRange.upperBound ? categoryColor(category) : AppColour.textTertiary)
            }
            .disabled(value >= category.valueRange.upperBound)
            .accessibilityLabel(Copy.Journal.increaseLabel(category.displayName))
            .accessibilityHint(Copy.Journal.increasesTheValueByHint(category.step, category.unit))
        }
        .padding(.vertical, DS.space2)
        .sensoryFeedback(.increase, trigger: value)
    }

    private func sliderInput(for category: JournalCategory) -> some View {
        VStack(spacing: DS.space1) {
            Slider(
                value: $value,
                in: category.valueRange,
                step: category.step
            )
            .tint(categoryColor(category))
            .accessibilityLabel(Copy.Journal.amountLabel(category.displayName))
            .accessibilityValue(Copy.Journal.xValue(formattedValue(value, for: category), category.unit))
            .accessibilityHint(Copy.Journal.adjustTheAmountYouLoggedHint)

            HStack {
                Text(formattedValue(category.valueRange.lowerBound, for: category))
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textSecondary)
                Spacer()
                Text(formattedValue(category.valueRange.upperBound, for: category))
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textSecondary)
            }
        }
    }

    // MARK: - Notes Field

    private var notesField: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            Text(Copy.Journal.notes)
                .font(DS.Typography.headline)

            TextField("Optional notes...", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding(DS.cardPadding)
                .cardStyle()
        }
    }

    // MARK: - Save Button

    private func saveButton(for category: JournalCategory) -> some View {
        Button {
            let store = JournalStore(modelContext: modelContext)
            store.save(
                category: category,
                value: value,
                notes: notes.isEmpty ? nil : notes
            )
            AppAnalytics.shared.trackBlockTap(
                title: "Log \(category.displayName)",
                type: .journalEntrySaved,
                screen: .journalEntry,
                metadata: [
                    "category": category.rawValue,
                    "value": value,
                    "has_notes": !notes.isEmpty
                ]
            )
            withAnimation(.spring(duration: 0.4)) {
                showConfirmation = true
            }
        } label: {
            HStack(spacing: DS.space2) {
                Image(systemName: category.icon)
                Text(Copy.Journal.logEntry(displayName: category.displayName))
                    .font(DS.Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.space4)
            .background(categoryColor(category), in: RoundedRectangle(cornerRadius: DS.cardRadius))
        }
        .buttonStyle(.dsPress)
        .disabled(value == 0 && category != .stress && category != .mood)
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        VStack(spacing: DS.itemSpacing) {
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.heroIcon)
                .foregroundStyle(AppColour.success)
            Text(Copy.Journal.logged)
                .font(DS.Typography.title3)
        }
        .padding(DS.space7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
    }

    // MARK: - Helpers

    private func formattedValue(_ val: Double, for category: JournalCategory) -> String {
        if category.step >= 1 {
            return String(format: "%.0f", val)
        }
        return String(format: "%.1f", val)
    }

    private func categoryColor(_ category: JournalCategory) -> Color {
        switch category {
        case .caffeine: return .brown
        case .alcohol: return AppColour.categoryStress   // soft purple
        case .stress: return AppColour.danger
        case .supplements: return AppColour.success
        case .meditation: return AppColour.categorySleep // soft indigo
        case .screenTime: return AppColour.info
        case .mealTiming: return AppColour.warning
        case .water: return AppColour.accent
        case .mood: return AppColour.categoryActivity    // soft amber
        }
    }
}
