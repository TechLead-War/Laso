import SwiftUI
import StoreKit

/// Full-screen paywall shown after the 7-day trial expires.
/// Displays localized pricing from StoreKit (currency adapts per country).
struct PaywallView: View {
    let subscriptionManager: SubscriptionManager

    @State private var selectedProduct: Product?
    @State private var isRestoring = false
    @State private var paywallOpenDate = Date()

    // Section trackers
    @State private var headerTracker = SectionTracker(section: .paywallHeader, tab: .paywall)
    @State private var featuresTracker = SectionTracker(section: .paywallFeatures, tab: .paywall)
    @State private var pricingTracker = SectionTracker(section: .paywallPricing, tab: .paywall)
    @State private var footerTracker = SectionTracker(section: .paywallFooter, tab: .paywall)

    private var yearly: Product? { subscriptionManager.yearlyProduct }
    private var monthly: Product? { subscriptionManager.monthlyProduct }
    private var callToActionTitle: String {
        guard let product = selectedProduct else { return Copy.Buttons.subscribe }
        return product.subscription?.introductoryOffer != nil ? Copy.Paywall.startFreeTrial : Copy.Paywall.subscribeNow
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
                        .onAppear { headerTracker.appeared() }
                        .onDisappear { headerTracker.disappeared() }
                    features
                        .onAppear { featuresTracker.appeared() }
                        .onDisappear { featuresTracker.disappeared() }
                    pricing
                        .onAppear { pricingTracker.appeared() }
                        .onDisappear { pricingTracker.disappeared() }
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 24)
            }

            footer
                .onAppear { footerTracker.appeared() }
                .onDisappear { footerTracker.disappeared() }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            selectedProduct = yearly ?? monthly
            paywallOpenDate = Date()
            AppAnalytics.shared.trackFeatureOpen(.paywall, metadata: [
                "source": "trial_expired",
                "products_available": subscriptionManager.products.count
            ])
            AppAnalytics.shared.trackPaywallViewed(source: "trial_expired")
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.paywall)
            let duration = Int(Date().timeIntervalSince(paywallOpenDate))
            if !subscriptionManager.hasAccess {
                AppAnalytics.shared.trackPaywallDismissed(
                    timeOnPaywallSec: duration,
                    source: "trial_expired"
                )
            }
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

            Text(Copy.Paywall.unlockTitle)
                .font(.largeTitle.weight(.bold))

            Text(Copy.Paywall.unlockSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var features: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(icon: "waveform.path.ecg", text: Copy.Paywall.featureLiveVitals)
            featureRow(icon: "brain.head.profile", text: Copy.Paywall.featureInsights)
            featureRow(icon: "chart.line.uptrend.xyaxis", text: Copy.Paywall.featureTrends)
            featureRow(icon: "bell.badge.fill", text: Copy.Paywall.featureAlerts)
            featureRow(icon: "lock.shield.fill", text: Copy.Paywall.featurePrivacy)
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
                    label: Copy.Paywall.yearly,
                    detail: yearlyDetail(yearly),
                    badge: savingsBadge
                )
            }

            if let monthly {
                pricingOption(
                    product: monthly,
                    label: Copy.Paywall.monthly,
                    detail: Copy.Paywall.perMonth(monthly.displayPrice),
                    badge: nil
                )
            }

            if subscriptionManager.products.isEmpty {
                ProgressView(Copy.Settings.loadingPrices)
                    .padding()
            }
        }
    }

    private func yearlyDetail(_ product: Product) -> String {
        Copy.Paywall.perYear(product.displayPrice)
    }

    private var savingsBadge: String? {
        guard let pct = yearlySavingsPercent, pct > 0 else { return nil }
        return Copy.Paywall.savePercent(pct)
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
            let type: BlockType = label == "Yearly" ? .paywallPlanYearly : .paywallPlanMonthly
            AppAnalytics.shared.trackBlockTap(
                title: label,
                type: type,
                screen: .paywall,
                metadata: [
                    "product_id": product.id,
                    "price": product.displayPrice,
                    "billing_period": label.lowercased()
                ]
            )
            pricingTracker.tapped(target: label.lowercased())
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
                AppAnalytics.shared.trackBlockTap(
                    title: "Subscribe",
                    type: .paywallSubscribe,
                    screen: .paywall,
                    metadata: [
                        "product_id": product.id,
                        "price": product.displayPrice,
                        "cta_title": callToActionTitle
                    ]
                )
                footerTracker.tapped(target: "subscribe")
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
                AppAnalytics.shared.trackBlockTap(
                    title: "Restore Purchases",
                    type: .paywallRestore,
                    screen: .paywall,
                    metadata: [
                        "source": "paywall_footer"
                    ]
                )
                footerTracker.tapped(target: "restore_purchases")
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
                    Text(Copy.Buttons.restorePurchases)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if subscriptionManager.products.isEmpty {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Retry loading plans",
                        type: .paywallRetryPlans,
                        screen: .paywall,
                        metadata: [
                            "source": "paywall_footer"
                        ]
                    )
                    footerTracker.tapped(target: "retry_loading_plans")
                    Task { await subscriptionManager.loadProducts() }
                } label: {
                    Text(Copy.Settings.retryLoadingPlans)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                Link(Copy.Privacy.termsOfUse, destination: URL(string: AppSecrets.URLs.termsOfUse)!)
                Text("\u{00B7}")
                    .foregroundStyle(.quaternary)
                Link(Copy.Privacy.privacyPolicy, destination: URL(string: AppSecrets.URLs.privacyPolicy)!)
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
