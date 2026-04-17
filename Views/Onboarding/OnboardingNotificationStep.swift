import SwiftUI

struct OnboardingNotificationStep: View {
    let onContinue: () -> Void

    private let benefits = [
        (icon: "sun.horizon.fill", text: "Morning health briefing with your overnight recovery"),
        (icon: "exclamationmark.heart.fill", text: "Important alerts when something unusual happens"),
        (icon: "chart.bar.fill", text: "Weekly progress updates on your health trends")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(Copy.Labels.appName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.indigo)
                .frame(width: 88, height: 88)
                .background(Color.indigo.opacity(0.12), in: Circle())
                .padding(.bottom, 28)

            VStack(spacing: 10) {
                Text(Copy.Onboarding.enableNotifications)
                    .font(.title2.weight(.bold))

                Text(Copy.Onboarding.notificationDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)

            // Benefit list
            VStack(spacing: 0) {
                ForEach(benefits, id: \.text) { benefit in
                    HStack(spacing: 12) {
                        Image(systemName: benefit.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(.indigo)
                            .frame(width: 28)

                        Text(benefit.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }
            }

            Spacer()
            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Turn On Notifications",
                    type: .onboardingNotifications,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "notifications",
                        "action": "enable"
                    ]
                )
                Task {
                    if !UITestMode.isEnabled {
                        await NotificationManager.shared.requestAuthorization(source: "onboarding")
                        PostHogManager.shared.capture(event: "onboarding_notifications_authorized")
                    }
                    onContinue()
                }
            } label: {
                Text(Copy.Onboarding.enableNotificationsButton)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("onboarding.notificationsEnable")

            Button(Copy.Buttons.skipForNow) {
                AppAnalytics.shared.trackBlockTap(
                    title: "Skip Notifications",
                    type: .onboardingContinueAnyway,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "notifications",
                        "action": "skip"
                    ]
                )
                onContinue()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 12)
            .padding(.bottom, 48)
            .accessibilityIdentifier("onboarding.notificationsSkip")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
