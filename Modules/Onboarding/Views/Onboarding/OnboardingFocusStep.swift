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

            VStack(spacing: 10) {
                Text(Copy.Onboarding.priorityTitle)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space6)

                Text(Copy.Onboarding.prioritySubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
            }
            .padding(.bottom, DS.space6)

            VStack(spacing: 10) {
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
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isSelected)
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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space8)
            .disabled(selectedFocuses.isEmpty)
            .opacity(selectedFocuses.isEmpty ? 0.55 : 1.0)
            .accessibilityIdentifier("onboarding.prioritySelectionContinue")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func priorityCard(focus: HealthFocus, isSelected: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: focus.systemImageName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? focus.color : .secondary)
                .frame(width: 40, height: 40)
                .background(
                    (isSelected ? focus.color.opacity(0.18) : Color.secondary.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(focus.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(Copy.Onboarding.priorityCardSubtitle(for: focus))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(isSelected ? focus.color : Color.secondary.opacity(0.35))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? focus.color.opacity(0.08) : Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? focus.color.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }
}
