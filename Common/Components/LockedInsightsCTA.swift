import SwiftUI

/// Card shown below an insight list when free tier users have more insights
/// available than the `FeatureGate.insightLimit` cap allows. Tapping opens the paywall.
struct LockedInsightsCTA: View {
    let hiddenCount: Int

    @State private var showPaywall = false

    var body: some View {
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: "Unlock more insights",
                type: .proUpgradeButton,
                screen: .proOverlay,
                metadata: ["hidden_count": hiddenCount, "feature": "insights"]
            )
            AppAnalytics.shared.trackPremiumFeatureAttempted(feature: "all_insights", screen: .proOverlay)
            showPaywall = true
        } label: {
            HStack(spacing: DS.space3) {
                Image(systemName: "lock.fill")
                    .font(DS.Typography.body)
                    .foregroundStyle(.tint)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .background(Color.accentColor.opacity(DS.badgeBg), in: Circle())

                VStack(alignment: .leading, spacing: DS.space1) {
                    Text("\(hiddenCount) more insight\(hiddenCount == 1 ? "" : "s") with Pro")
                        .font(DS.Typography.subheadlineSemibold)
                        .foregroundStyle(AppColour.textPrimary)
                    Text(Copy.Common.unlockTheFullSetWithA)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
        .buttonStyle(.dsPress)
        .accessibilityLabel(Copy.Paywall.unlockMoreInsights(hiddenCount: hiddenCount))
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: SubscriptionManager.shared, source: "locked_insights")
        }
    }
}

#Preview {
    LockedInsightsCTA(hiddenCount: 5)
        .padding()
}
