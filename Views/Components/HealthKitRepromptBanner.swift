import SwiftUI

/// In-app banner shown when the user authorized HealthKit but toggled off all
/// data categories, leaving the app with no usable health data.
/// Explains the issue and offers a one-tap path to the Health app settings.
struct HealthKitRepromptBanner: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "heart.text.clipboard")
                    .font(.title2)
                    .foregroundStyle(.pink)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Home.HealthKitReprompt.title)
                        .font(.subheadline.weight(.semibold))
                    Text(Copy.Home.HealthKitReprompt.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "HealthKit Reprompt Dismissed",
                        type: .smartAction,
                        screen: .home,
                        metadata: ["source": "healthkit_reprompt", "action": "not_now"]
                    )
                    isPresented = false
                } label: {
                    Text(Copy.Home.HealthKitReprompt.dismiss)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "HealthKit Reprompt Settings",
                        type: .smartAction,
                        screen: .home,
                        metadata: ["source": "healthkit_reprompt", "action": "open_settings"]
                    )
                    openHealthSettings()
                    isPresented = false
                } label: {
                    Text(Copy.Home.HealthKitReprompt.action)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.pink.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            HealthKitRepromptManager.recordRepromptShown()
            AppAnalytics.shared.trackFeatureOpen(.home, metadata: ["subscreen": "healthkit_reprompt_banner"])
        }
    }

    private func openHealthSettings() {
        // Open the main Settings app. iOS does not expose a direct deep link to
        // HealthKit per-app data sharing, so the system Settings URL is the best
        // path. The user can navigate to Health > Data Access & Devices from there.
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
