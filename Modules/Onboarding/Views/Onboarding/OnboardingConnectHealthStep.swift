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
                .font(DS.Typography.largeIcon)
                .foregroundStyle(AppColour.danger)
                .frame(width: 88, height: 88)
                .background(AppColour.danger.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.xl))
                .padding(.bottom, DS.space7)

            VStack(spacing: DS.itemSpacing) {
                Text(Copy.Onboarding.connectTitle)
                    .font(DS.Typography.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space6)

                Text(Copy.Onboarding.connectSubtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)

                if let note = Copy.Onboarding.personalizedConnectNote(age: age) {
                    Text(note)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.space7)
                        .padding(.top, DS.space1)
                }
            }

            HStack(spacing: DS.space2) {
                Image(systemName: "lock.shield")
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textSecondary)
                Text(Copy.Onboarding.connectPrivacyNote)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textSecondary)
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
                            AnalyticsBackend.provider.capture(event: "healthkit_authorized", properties: [
                                "healthkit_available": 1
                            ])
                        }
                        onContinue()
                    }
                } label: {
                    Text(Copy.Onboarding.connectAllow)
                }
                .buttonStyle(.dsPrimary)
                .padding(.horizontal, DS.space6)
                .padding(.bottom, DS.space8)
                .accessibilityIdentifier("onboarding.connectHealthButton")
            } else {
                VStack(spacing: DS.itemSpacing) {
                    Text(Copy.Onboarding.connectUnavailable)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)

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
                    }
                    .buttonStyle(.dsPrimary)
                    .padding(.horizontal, DS.space6)
                    .accessibilityIdentifier("onboarding.connectHealthContinueAnyway")
                }
                .padding(.bottom, DS.space8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
