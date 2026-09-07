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

            // No repeating pulse: this is the whole Live tab, Correlations and
            // Metric Detail for every free user, so an unbounded symbol effect
            // held the display link alive for as long as they sat on a screen
            // that is otherwise completely static.
            Image(systemName: icon)
                .font(DS.Typography.heroIcon)
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(feature)
                        .font(.title2.weight(.bold))
                    Text(Copy.Common.pro)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(.tint, in: Capsule())
                        .foregroundStyle(AppColour.textOnAccent)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space7)
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
                AppAnalytics.shared.trackProFeatureUpgradeTapped(feature: feature)
                showPaywall = true
            } label: {
                Text(Copy.Paywall.upgradeToPro)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(Copy.Paywall.upgradeToPro)
            .accessibilityHint(Copy.Common.opensTheSubscriptionPaywallToHint(feature))
            .padding(.horizontal, 40)

            Spacer()
        }
        .background(AppColour.surfaceSunken.ignoresSafeArea())
        .accessibilityIdentifier("screen.proFeatureOverlay")
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: SubscriptionManager.shared, source: "pro_feature_overlay")
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
