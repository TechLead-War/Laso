import SwiftUI
import StoreKit

/// Full-screen paywall shown after the 7-day trial expires.
/// Displays localized pricing from StoreKit (currency adapts per country).
struct PaywallView: View {
    let subscriptionManager: SubscriptionManager

    @State private var selectedProduct: Product?
    @State private var isRestoring = false
    @State private var paywallOpenDate = Date()

    private var yearly: Product? { subscriptionManager.yearlyProduct }
    private var monthly: Product? { subscriptionManager.monthlyProduct }
    private var callToActionTitle: String {
        guard let product = selectedProduct else { return "Subscribe" }
        return product.subscription?.introductoryOffer != nil ? "Start Free Trial" : "Subscribe Now"
    }

    /// Monthly cost if paying yearly, for "save X%" label.
    private var yearlySavingsPercent: Int? {
        guard let y = yearly, let m = monthly else { return nil }
        let yearlyMonthly = (y.price as Decimal) / 12
        let monthlyPrice = m.price as Decimal
        guard monthlyPrice > 0 else { return nil }
        let savings = ((monthlyPrice - yearlyMonthly) / monthlyPrice) * 100
        return Int(truncating: savings as NSDecimalNumber)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    features
                    pricing
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 24)
            }

            footer
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            selectedProduct = yearly ?? monthly
            paywallOpenDate = Date()
            AppAnalytics.shared.trackPaywallViewed(source: "trial_expired")
        }
        .onChange(of: subscriptionManager.products) { _, _ in
            if selectedProduct == nil {
                selectedProduct = yearly ?? monthly
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Image("LaunchIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("Unlock Laso")
                .font(.largeTitle.weight(.bold))

            Text("Your personal health intelligence,\npowered by your Apple Watch data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var features: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(icon: "waveform.path.ecg", text: "Live vitals & 58+ health metrics")
            featureRow(icon: "brain.head.profile", text: "Personalized insights & root cause analysis")
            featureRow(icon: "chart.line.uptrend.xyaxis", text: "Trends, correlations & weekly reports")
            featureRow(icon: "bell.badge.fill", text: "Smart alerts with custom thresholds")
            featureRow(icon: "lock.shield.fill", text: "Health data stays on-device; anonymous usage analytics and optional feedback improve Laso")
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(.tint)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Pricing

    private var pricing: some View {
        VStack(spacing: 12) {
            if let yearly {
                pricingOption(
                    product: yearly,
                    label: "Yearly",
                    detail: yearlyDetail(yearly),
                    badge: savingsBadge
                )
            }

            if let monthly {
                pricingOption(
                    product: monthly,
                    label: "Monthly",
                    detail: monthly.displayPrice + "/month",
                    badge: nil
                )
            }

            if subscriptionManager.products.isEmpty {
                ProgressView("Loading prices...")
                    .padding()
            }
        }
    }

    private func yearlyDetail(_ product: Product) -> String {
        product.displayPrice + "/year"
    }

    private var savingsBadge: String? {
        guard let pct = yearlySavingsPercent, pct > 0 else { return nil }
        return "Save \(pct)%"
    }

    private func pricingOption(
        product: Product,
        label: String,
        detail: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedProduct?.id == product.id

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProduct = product
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(.headline)

                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.green, in: Capsule())
                        }
                    }

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                guard let product = selectedProduct else { return }
                AppAnalytics.shared.trackPaywallCTATapped(
                    productID: product.id,
                    price: product.displayPrice
                )
                Task { await subscriptionManager.purchase(product) }
            } label: {
                Group {
                    if subscriptionManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(callToActionTitle)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedProduct == nil || subscriptionManager.isPurchasing)

            Button {
                isRestoring = true
                Task {
                    let previousStatus = subscriptionManager.status
                    await subscriptionManager.restorePurchases()
                    let restored = subscriptionManager.hasAccess && !{
                        if case .trial = previousStatus { return true }
                        if case .subscribed = previousStatus { return true }
                        return false
                    }()
                    AppAnalytics.shared.trackRestoreAttempted(success: restored)
                    isRestoring = false
                }
            } label: {
                if isRestoring {
                    ProgressView()
                } else {
                    Text("Restore Purchases")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if subscriptionManager.products.isEmpty {
                Button {
                    Task { await subscriptionManager.loadProducts() }
                } label: {
                    Text("Retry loading plans")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://lasohealth.com/terms")!)
                Text("\u{00B7}")
                    .foregroundStyle(.quaternary)
                Link("Privacy Policy", destination: URL(string: "https://lasohealth.com/privacy")!)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}
