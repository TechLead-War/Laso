import SwiftUI

/// Screen 4: Priority.
/// Large tap cards mapped one to one to HealthFocus cases. Multi select, drives downstream
/// insight filtering in DashboardViewModel. No confirmation sub screen, no calibration here.
/// Mirror Moment lives in OnboardingMirrorMomentStep.
struct OnboardingFocusSelectionStep: View {
    @Binding var selectedFocuses: Set<HealthFocus>
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DS.itemSpacing) {
                Text(Copy.Onboarding.priorityTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space6)

                Text(Copy.Onboarding.prioritySubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
            }
            .padding(.bottom, DS.space6)

            VStack(spacing: DS.itemSpacing) {
                ForEach(HealthFocus.allCases) { focus in
                    let isSelected = selectedFocuses.contains(focus)
                    Button {
                        if isSelected {
                            selectedFocuses.remove(focus)
                        } else {
                            selectedFocuses.insert(focus)
                        }
                        AppAnalytics.shared.trackBlockTap(
                            title: focus.displayName,
                            type: .onboardingFocusChip,
                            screen: .onboarding,
                            metadata: [
                                "step_name": "priority",
                                "focus_id": focus.rawValue,
                                "is_selected": selectedFocuses.contains(focus) ? 1 : 0,
                                "selected_count": selectedFocuses.count
                            ]
                        )
                        AppAnalytics.shared.trackSettingChanged(
                            name: "onboarding_focus_\(focus.rawValue)",
                            value: !isSelected
                        )
                    } label: {
                        priorityCard(focus: focus, isSelected: isSelected)
                    }
                    .buttonStyle(.dsPress)
                    .sensoryFeedback(.selection, trigger: isSelected)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(focus.displayName)
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                    .accessibilityHint(Copy.Onboarding.togglesAsAFocusAreaHint(focus.displayName))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, DS.space5)

            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Priority Continue",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "priority",
                        "selected_focuses_count": selectedFocuses.count
                    ]
                )
                onContinue()
            } label: {
                Text(Copy.Onboarding.priorityContinue)
            }
            .buttonStyle(.dsPrimary)
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space8)
            .disabled(selectedFocuses.isEmpty)
            .opacity(selectedFocuses.isEmpty ? 0.55 : 1.0)
            .accessibilityIdentifier("onboarding.prioritySelectionContinue")
            .accessibilityHint(Copy.Onboarding.savesYourSelectedFocusAreasAndHint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func priorityCard(focus: HealthFocus, isSelected: Bool) -> some View {
        HStack(spacing: DS.space4) {
            Image(systemName: focus.systemImageName)
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(isSelected ? focus.color : AppColour.textSecondary)
                .frame(width: 40, height: 40)
                .background(
                    (isSelected ? focus.color.opacity(DS.badgeBg) : AppColour.borderLow.opacity(0.5)),
                    in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                )

            VStack(alignment: .leading, spacing: DS.space1) {
                Text(focus.displayName)
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(AppColour.textPrimary)
                Text(Copy.Onboarding.priorityCardSubtitle(for: focus))
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(DS.Typography.title3)
                .foregroundStyle(isSelected ? focus.color : AppColour.borderMedium)
        }
        .padding(DS.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(isSelected ? focus.color.opacity(DS.tintBg * 2) : AppColour.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(isSelected ? focus.color.opacity(0.6) : AppColour.borderLow, lineWidth: 1.5)
        )
    }
}
