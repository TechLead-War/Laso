import SwiftUI
import StoreKit

/// Full-screen paywall presented when users hit a gated feature
struct PaywallView: View {
    let trigger: Feature
    let featureGate: FeatureGate
    let subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PlanType = .yearly
    @State private var isPurchasing = false

    enum PlanType { case monthly, yearly }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero
                    heroSection

                    // Feature list
                    featureListSection

                    // Plan selector
                    planSelector

                    // Purchase button
                    purchaseButton

                    // Restore + terms
                    footerLinks
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.subheadline.weight(.medium))
                }
            }
            .task {
                await subscriptionManager.loadProducts()
                AnalyticsManager.shared.track(.paywallViewed(trigger: trigger.rawValue))
            }
        }
    }

    // MARK: - Hero

    private var isTrialBucket: Bool {
        ABTestManager.shared.bucket == .trial
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image("1024")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(isTrialBucket ? "Continue with Laso Pro" : "Unlock Laso Pro")
                .font(.title.weight(.bold))

            Text(isTrialBucket
                 ? "Your trial has ended. Subscribe to keep tracking your health with all features unlocked."
                 : "Get the full picture of your health with predictive risk analysis, all 48+ metrics, and personalized focus areas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top)
    }

    // MARK: - Feature List

    private var featureListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(featureGate.proFeatures) { feature in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.displayName)
                            .font(.subheadline.weight(.medium))
                        Text(feature.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal)

                if feature != featureGate.proFeatures.last {
                    Divider().padding(.leading, 48)
                }
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        VStack(spacing: 10) {
            planCard(
                type: .yearly,
                label: "Yearly",
                price: yearlyPrice,
                subtitle: savingsText,
                badge: "Best Value"
            )

            planCard(
                type: .monthly,
                label: "Monthly",
                price: monthlyPrice,
                subtitle: nil,
                badge: nil
            )
        }
    }

    private func planCard(type: PlanType, label: String, price: String, subtitle: String?, badge: String?) -> some View {
        Button {
            selectedPlan = type
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.green, in: Capsule())
                        }
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Text(price)
                    .font(.subheadline.weight(.bold).monospacedDigit())

                Image(systemName: selectedPlan == type ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedPlan == type ? .blue : .secondary)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selectedPlan == type ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Purchase Button

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchase() }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        if isTrialBucket {
                            Text("Subscribe Now")
                        } else {
                            let trialDays = FeatureConfig.pricing[.pro]?.trialDays ?? 0
                            if trialDays > 0 {
                                Text("Start \(trialDays)-Day Free Trial")
                            } else {
                                Text("Subscribe Now")
                            }
                        }
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(isPurchasing)

            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        VStack(spacing: 8) {
            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restore()
                    if subscriptionManager.activeTier >= .pro {
                        featureGate.currentTier = subscriptionManager.activeTier
                        dismiss()
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private var monthlyPrice: String {
        if let product = subscriptionManager.monthlyProduct(for: .pro) {
            return "\(product.displayPrice)/mo"
        }
        return "\(FeatureConfig.pricing[.pro]?.monthlyDisplayPrice ?? "$5.99")/mo"
    }

    private var yearlyPrice: String {
        if let product = subscriptionManager.yearlyProduct(for: .pro) {
            return "\(product.displayPrice)/yr"
        }
        return "\(FeatureConfig.pricing[.pro]?.yearlyDisplayPrice ?? "$39.99")/yr"
    }

    private var savingsText: String? {
        guard let monthlyProduct = subscriptionManager.monthlyProduct(for: .pro),
              let yearlyProduct = subscriptionManager.yearlyProduct(for: .pro) else {
            return "Save 44%"
        }
        let annualFromMonthly = monthlyProduct.price * 12
        let savings = ((annualFromMonthly - yearlyProduct.price) / annualFromMonthly * 100)
        return "Save \(NSDecimalNumber(decimal: savings).intValue)%"
    }

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        let product: Product?
        switch selectedPlan {
        case .yearly:
            product = subscriptionManager.yearlyProduct(for: .pro)
        case .monthly:
            product = subscriptionManager.monthlyProduct(for: .pro)
        }

        guard let product else { return }

        let success = await subscriptionManager.purchase(product)
        if success {
            featureGate.currentTier = subscriptionManager.activeTier
            dismiss()
        }
    }
}
