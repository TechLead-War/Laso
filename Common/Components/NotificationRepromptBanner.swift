import SwiftUI

/// In-app banner shown when the user denied notification permission 7+ days ago.
/// Explains the value and offers a one-tap path to Settings.
struct NotificationRepromptBanner: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Notifications.repromptTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(Copy.Notifications.repromptBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                Button {
                    AppAnalytics.shared.trackBlockTap(title: "Notification Reprompt Dismissed", type: .smartAction, screen: .home, metadata: ["source": "notification_reprompt", "action": "not_now"])
                    isPresented = false
                } label: {
                    Text(Copy.Notifications.repromptDismiss)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(Copy.Notifications.repromptDismiss)
                .accessibilityHint(Copy.Common.hidesThisBannerWithoutChangingNotificationHint)

                Button {
                    AppAnalytics.shared.trackBlockTap(title: "Notification Reprompt Settings", type: .smartAction, screen: .home, metadata: ["source": "notification_reprompt", "action": "open_settings"])
                    openNotificationSettings()
                    isPresented = false
                } label: {
                    Text(Copy.Notifications.repromptAction)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(Copy.Notifications.repromptAction)
                .accessibilityHint(Copy.Common.opensTheSystemSettingsAppToHint)
            }
        }
        .padding(DS.space4)
        .glassChrome(in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            NotificationRepromptManager.recordRepromptShown()
            AppAnalytics.shared.trackFeatureOpen(.home, metadata: ["subscreen": "notification_reprompt_banner"])
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
