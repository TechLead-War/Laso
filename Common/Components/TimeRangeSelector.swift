import SwiftUI

/// Segmented picker for selecting time range (7d, 30d, 3m, 6m).
/// Free users only see buttons whose key is in `FeatureGate.allowedPeriods`;
/// disallowed options render with a lock and open `PaywallView` on tap.
struct TimeRangeSelector: View {
    @Binding var selectedDays: Int

    @State private var showPaywall = false

    private struct Option {
        let label: String
        let days: Int
        let key: String
    }

    private let options: [Option] = [
        Option(label: "7D",  days: 7,   key: "7d"),
        Option(label: "30D", days: 30,  key: "30d"),
        Option(label: "3M",  days: 90,  key: "3m"),
        Option(label: "6M",  days: 180, key: "6m")
    ]

    var body: some View {
        let allowed = Set(FeatureGate.allowedPeriods)

        HStack(spacing: 0) {
            ForEach(options, id: \.days) { option in
                let isAllowed = allowed.contains(option.key)
                let isSelected = selectedDays == option.days

                Button {
                    if isAllowed {
                        selectedDays = option.days
                    } else {
                        AppAnalytics.shared.trackPremiumFeatureAttempted(
                            feature: "time_range_\(option.key)",
                            screen: .proOverlay
                        )
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(option.label)
                            .font(DS.Typography.subheadlineSemibold)
                        if !isAllowed {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .semibold))
                        }
                    }
                    .foregroundStyle(
                        isSelected
                            ? Color.white
                            : (isAllowed ? AppColour.textPrimary : AppColour.textSecondary)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.accentColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isAllowed
                    ? "\(option.label) range"
                    : "\(option.label) range, locked, requires Pro")
            }
        }
        .padding(2)
        .background(AppColour.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: SubscriptionManager.shared)
        }
    }
}

#Preview {
    TimeRangeSelector(selectedDays: .constant(30))
        .padding()
}
