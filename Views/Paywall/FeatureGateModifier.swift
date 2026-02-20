import SwiftUI

/// ViewModifier that overlays a "Pro" lock on gated content and shows paywall on tap
struct FeatureGateModifier: ViewModifier {
    let feature: Feature
    let featureGate: FeatureGate
    let subscriptionManager: SubscriptionManager

    @State private var showPaywall = false

    var isLocked: Bool {
        !featureGate.isUnlocked(feature)
    }

    func body(content: Content) -> some View {
        if isLocked {
            content
                .overlay {
                    lockedOverlay
                }
                .onTapGesture {
                    AnalyticsManager.shared.track(.featureGated(feature: feature.rawValue))
                    showPaywall = true
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView(
                        trigger: feature,
                        featureGate: featureGate,
                        subscriptionManager: subscriptionManager
                    )
                }
        } else {
            content
        }
    }

    private var lockedOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)

            VStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Pro")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.blue.opacity(0.12), in: Capsule())
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Gate this view behind a feature flag — shows lock overlay if user doesn't have access
    func featureGated(
        _ feature: Feature,
        gate: FeatureGate,
        subscriptionManager: SubscriptionManager
    ) -> some View {
        modifier(FeatureGateModifier(
            feature: feature,
            featureGate: gate,
            subscriptionManager: subscriptionManager
        ))
    }
}
