import SwiftUI

struct OnboardingCycleOptInStep: View {
    let onEnable: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(Copy.Labels.appName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.pink)
                .frame(width: 88, height: 88)
                .background(Color.pink.opacity(0.12), in: Circle())
                .padding(.bottom, 28)

            VStack(spacing: 10) {
                Text(Copy.Onboarding.enableCycleTracking)
                    .font(.title2.weight(.bold))

                Text(Copy.Onboarding.cycleOptInDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Enable Cycle Tracking",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "cycle_opt_in",
                        "enabled": 1
                    ]
                )
                onEnable()
            } label: {
                Text(Copy.Buttons.enable)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("onboarding.cycleEnable")

            Button(Copy.Buttons.notNow) {
                AppAnalytics.shared.trackBlockTap(
                    title: "Cycle Tracking Not Now",
                    type: .onboardingContinueAnyway,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "cycle_opt_in",
                        "enabled": 0
                    ]
                )
                onSkip()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
            .padding(.bottom, 48)
            .accessibilityIdentifier("onboarding.cycleSkip")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
