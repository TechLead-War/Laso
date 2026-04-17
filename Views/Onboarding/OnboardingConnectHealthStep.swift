import SwiftUI
import HealthKit

struct OnboardingConnectHealthStep: View {
    let healthKitManager: HealthKitManager
    let age: Int?
    let onContinue: () -> Void

    private let permissions = [
        Copy.Onboarding.permissionHeartRate,
        Copy.Onboarding.permissionSteps,
        Copy.Onboarding.permissionSleepAnalysis,
        Copy.Onboarding.permissionHRV,
        Copy.Onboarding.permissionBloodOxygen,
        Copy.Onboarding.permissionWorkouts,
        Copy.Onboarding.permissionBodyMeasurements
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Apple Health icon
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.red)
                .frame(width: 70, height: 70)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 20)

            VStack(spacing: 10) {
                Text(Copy.Onboarding.connectAppleHealth)
                    .font(.title2.weight(.bold))

                Text(Copy.Onboarding.connectHealthDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if age != nil {
                    Text(Copy.Onboarding.personalizedConnectSubtitle(age: age))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 20)

            // Permission checklist
            VStack(spacing: 0) {
                ForEach(permissions, id: \.self) { permission in
                    HStack(spacing: 12) {
                        Image(systemName: "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)

                        Text(permission)
                            .font(.body.weight(.medium))

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }
            }
            .padding(.vertical, 8)

            Spacer()
            Spacer()

            if healthKitManager.isHealthKitAvailable {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Connect Apple Health",
                        type: .onboardingConnectHealth,
                        screen: .onboarding,
                        metadata: [
                            "step_name": "connect_health",
                            "healthkit_available": 1
                        ]
                    )
                    Task {
                        if !UITestMode.isEnabled {
                            await healthKitManager.requestAuthorization()
                            PostHogManager.shared.capture(event: "onboarding_connect_health_authorized", properties: [
                                "healthkit_available": true,
                            ])
                        }
                        onContinue()
                    }
                } label: {
                    Text(Copy.Onboarding.connectHealthData)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("onboarding.connectHealthButton")

                Button(Copy.Buttons.skipForNow) {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Skip for now",
                        type: .onboardingContinueAnyway,
                        screen: .onboarding,
                        metadata: [
                            "step_name": "connect_health",
                            "healthkit_available": 1,
                            "skipped": 1
                        ]
                    )
                    onContinue()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
                .padding(.bottom, 48)
                .accessibilityIdentifier("onboarding.connectHealthSkip")
            } else {
                VStack(spacing: 12) {
                    Text(Copy.Onboarding.healthKitUnavailable)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Continue Anyway",
                            type: .onboardingContinueAnyway,
                            screen: .onboarding,
                            metadata: [
                                "step_name": "connect_health",
                                "healthkit_available": 0
                            ]
                        )
                        onContinue()
                    } label: {
                        Text(Copy.Onboarding.continueAnyway)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("onboarding.connectHealthContinueAnyway")
                }
                .padding(.bottom, 48)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
