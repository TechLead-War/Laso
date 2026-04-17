import SwiftUI

/// Overlay shown when a free user tries to access a pro-only feature.
/// Shows a teaser with feature description and upgrade prompt.
struct ProFeatureOverlay: View {
    let feature: String
    let icon: String
    let description: String

    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(feature)
                        .font(.title2.weight(.bold))
                    Text("PRO")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(.tint, in: Capsule())
                        .foregroundStyle(.white)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Upgrade to Pro",
                    type: .proUpgradeButton,
                    screen: .proOverlay,
                    metadata: ["feature_name": feature]
                )
                AppAnalytics.shared.trackPremiumFeatureAttempted(feature: feature, screen: .proOverlay)
                AppAnalytics.shared.trackProFeatureFunnel(feature: feature, step: "upgrade_tapped")
                // PostHog: Track upgrade intent (high-value conversion signal)
                PostHogManager.shared.capture(event: "pro_overlay_upgrade_tapped", properties: [
                    "feature_name": feature,
                ])
                showPaywall = true
            } label: {
                Text("Upgrade to Pro")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Spacer()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .accessibilityIdentifier("screen.proFeatureOverlay")
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: SubscriptionManager.shared)
        }
        .onAppear {
            AppAnalytics.shared.trackProFeatureFunnel(feature: feature, step: "overlay_shown")
            AppAnalytics.shared.trackFeatureOpen(.proOverlay, metadata: [
                "feature": feature
            ])
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.proOverlay, metadata: [
                "feature": feature
            ])
        }
    }
}
