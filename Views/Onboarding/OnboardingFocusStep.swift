import SwiftUI

struct OnboardingFocusCalibrationStep: View {
    let isActive: Bool
    @Binding var selectedFocuses: Set<HealthFocus>
    let healthKitManager: HealthKitManager
    let runCalibration: () async -> String?
    let onComplete: () -> Void

    @State private var hasStartedCalibration = false

    var body: some View {
        Group {
            if hasStartedCalibration {
                OnboardingCalibrationStep(
                    isActive: isActive,
                    healthKitManager: healthKitManager,
                    runCalibration: runCalibration,
                    onComplete: onComplete
                )
            } else {
                OnboardingFocusSelectionStep(selectedFocuses: $selectedFocuses) {
                    hasStartedCalibration = true
                }
            }
        }
    }
}

// MARK: - Focus Selection

struct OnboardingFocusSelectionStep: View {
    @Binding var selectedFocuses: Set<HealthFocus>
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("LaunchIcon")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                Text(Copy.Onboarding.whatMatters)
                    .font(.title2.weight(.bold))

                Text(Copy.Onboarding.focusSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)

            FlowLayout(spacing: 10) {
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
                                "step_name": "focus_calibration",
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
                        Label(focus.displayName, systemImage: focus.systemImageName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                isSelected ? focus.color.opacity(0.2) : Color.secondary.opacity(0.06),
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? focus.color : .secondary)
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? focus.color : .clear, lineWidth: 2)
                            )
                    }
                    .sensoryFeedback(.selection, trigger: isSelected)
                }
            }
            .padding(.horizontal)

            Spacer()
            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Continue",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "focus_calibration",
                        "selected_focuses_count": selectedFocuses.count
                    ]
                )
                onContinue()
            } label: {
                Text(Copy.Buttons.continueButton)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
