import SwiftUI
import HealthKit

/// Screen 3: Connect Apple Health.
/// Single primer, no checkbox theatre. Same underlying 20 HealthKit types requested, clean surface.
struct OnboardingConnectHealthStep: View {
    let healthKitManager: HealthKitManager
    let age: Int?
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "heart.text.square")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.red)
                .frame(width: 88, height: 88)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                .padding(.bottom, 28)

            VStack(spacing: 10) {
                Text(Copy.Onboarding.connectTitle)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space6)

                Text(Copy.Onboarding.connectSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)

                if let note = Copy.Onboarding.personalizedConnectNote(age: age) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.space7)
                        .padding(.top, DS.space1)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Copy.Onboarding.connectPrivacyNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, DS.space6)

            Spacer()

            if healthKitManager.isHealthKitAvailable {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Allow Laso to read",
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
                            PostHogManager.shared.capture(event: "healthkit_authorized", properties: [
                                "healthkit_available": true
                            ])
                        }
                        onContinue()
                    }
                } label: {
                    Text(Copy.Onboarding.connectAllow)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline)
                .padding(.horizontal, DS.space6)
                .padding(.bottom, DS.space8)
                .accessibilityIdentifier("onboarding.connectHealthButton")
            } else {
                VStack(spacing: 12) {
                    Text(Copy.Onboarding.connectUnavailable)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Continue Without Apple Health",
                            type: .onboardingContinueAnyway,
                            screen: .onboarding,
                            metadata: [
                                "step_name": "connect_health",
                                "healthkit_available": 0
                            ]
                        )
                        onContinue()
                    } label: {
                        Text(Copy.Onboarding.connectContinueAnyway)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.headline)
                    .padding(.horizontal, DS.space6)
                    .accessibilityIdentifier("onboarding.connectHealthContinueAnyway")
                }
                .padding(.bottom, DS.space8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
