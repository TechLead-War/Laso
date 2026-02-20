import SwiftUI

/// Full-page view shown in place of locked detail screens (metric detail, risk detail).
/// Displays a lock icon, feature title/description, and an "Unlock with Pro" button that presents PaywallView.
struct ProLockedView: View {
    let icon: String
    let title: String
    let description: String
    let trigger: Feature
    let featureGate: FeatureGate
    let subscriptionManager: SubscriptionManager

    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Lock icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 88, height: 88)

                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }

            // Feature icon + title
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.title3.weight(.bold))

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Unlock button
            Button {
                AnalyticsManager.shared.track(.featureGated(feature: trigger.rawValue))
                showPaywall = true
            } label: {
                Label("Unlock with Pro", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal, 40)

            Spacer()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                trigger: trigger,
                featureGate: featureGate,
                subscriptionManager: subscriptionManager
            )
        }
    }

    // MARK: - Convenience Initializers

    /// Locked view for a pro-only metric detail
    static func metricLocked(
        metric: HealthMetric,
        featureGate: FeatureGate,
        subscriptionManager: SubscriptionManager
    ) -> ProLockedView {
        ProLockedView(
            icon: metric.systemImageName,
            title: metric.displayName,
            description: "Upgrade to Pro to view detailed trends, statistics, and insights for \(metric.displayName).",
            trigger: .allMetrics,
            featureGate: featureGate,
            subscriptionManager: subscriptionManager
        )
    }

    /// Locked view for a pro-only risk detail
    static func riskLocked(
        riskType: HealthRiskType,
        featureGate: FeatureGate,
        subscriptionManager: SubscriptionManager
    ) -> ProLockedView {
        ProLockedView(
            icon: riskType.systemImageName,
            title: riskType.displayName,
            description: "Upgrade to Pro to view risk factors, contributing metrics, and personalized recommendations.",
            trigger: .riskPredictions,
            featureGate: featureGate,
            subscriptionManager: subscriptionManager
        )
    }
}

#Preview {
    NavigationStack {
        ProLockedView.metricLocked(
            metric: .heartRateVariability,
            featureGate: FeatureGate(),
            subscriptionManager: SubscriptionManager()
        )
        .navigationTitle("Heart Rate Variability")
    }
}
