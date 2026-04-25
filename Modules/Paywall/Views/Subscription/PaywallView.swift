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

    /// Whether the selected product offers a free trial via its introductory offer.
    private var selectedProductHasTrial: Bool {
        selectedProduct?.subscription?.introductoryOffer != nil
    }

    /// Display price string for the after-trial disclosure text.
    private var afterTrialPriceText: String? {
        guard let product = selectedProduct else { return nil }
        return product.displayPrice
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
                VStack(spacing: DS.sectionSpacing) {
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
                .padding(.horizontal, DS.space6)
                .padding(.top, DS.space8)
                .padding(.bottom, DS.space6)
            }

            footer
                .onAppear { footerTracker.appeared() }
                .onDisappear { footerTracker.disappeared() }
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .accessibilityIdentifier("screen.paywall")
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
        VStack(spacing: DS.space3) {
            Image("LaunchIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous))

            Text(Copy.Paywall.unlockTitle)
                .font(DS.Typography.largeTitle)

            Text(Copy.Paywall.unlockSubtitle)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var features: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            featureRow(icon: "waveform.path.ecg", text: Copy.Paywall.featureLiveVitals)
            featureRow(icon: "brain.head.profile", text: Copy.Paywall.featureInsights)
            featureRow(icon: "chart.line.uptrend.xyaxis", text: Copy.Paywall.featureTrends)
            featureRow(icon: "bell.badge.fill", text: Copy.Paywall.featureAlerts)
            featureRow(icon: "lock.shield.fill", text: Copy.Paywall.featurePrivacy)
        }
        .padding(DS.space5)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: DS.itemSpacing) {
            Image(systemName: icon)
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(.tint)
                .frame(width: 28)

            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textPrimary)
        }
    }

    // MARK: - Pricing

    private var pricing: some View {
        VStack(spacing: DS.itemSpacing) {
            if let yearly {
                pricingOption(
                    product: yearly,
                    label: Copy.Paywall.yearly,
                    detail: yearlyDetail(yearly),
                    badge: savingsBadge
                )
                .accessibilityIdentifier("paywall.annualPlan")
            }

            if let monthly {
                pricingOption(
                    product: monthly,
                    label: Copy.Paywall.monthly,
                    detail: Copy.Paywall.perMonth(monthly.displayPrice),
                    badge: nil
                )
                .accessibilityIdentifier("paywall.monthlyPlan")
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
                VStack(alignment: .leading, spacing: DS.space1) {
                    HStack(spacing: DS.space2) {
                        Text(label)
                            .font(DS.Typography.headline)

                        if let badge {
                            Text(badge)
                                .font(DS.Typography.captionSemibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.space2)
                                .padding(.vertical, DS.space1)
                                .background(AppColour.success, in: Capsule())
                        }
                    }

                    Text(detail)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : AppColour.textSecondary)
            }
            .padding(DS.space4)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(AppColour.surfaceRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .buttonStyle(.dsPress)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: DS.itemSpacing) {
            if let error = subscriptionManager.errorMessage {
                Text(error)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.danger)
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
                if subscriptionManager.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(callToActionTitle)
                }
            }
            .buttonStyle(.dsPrimary)
            .disabled(selectedProduct == nil || subscriptionManager.isPurchasing)
            .accessibilityIdentifier("paywall.startTrialButton")

            // Trial duration and auto-renewal disclosure
            if selectedProductHasTrial {
                Text(Copy.Paywall.trialDuration(SubscriptionConfig.trialDays))
                    .font(DS.Typography.subheadlineMedium)
                    .foregroundStyle(AppColour.textPrimary)

                if let price = afterTrialPriceText {
                    Text(Copy.Paywall.afterTrial(price))
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

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
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                }
            }
            .buttonStyle(.dsTertiary)
            .accessibilityIdentifier("paywall.restoreButton")

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
                        .font(DS.Typography.subheadlineMedium)
                }
                .buttonStyle(.dsTertiary)
            }

            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase.")
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space6)

            HStack(spacing: DS.space4) {
                if let termsURL = URL(string: AppSecrets.URLs.termsOfUse) {
                    Link(Copy.Privacy.termsOfUse, destination: termsURL)
                }
                Text("\u{00B7}")
                    .foregroundStyle(AppColour.textQuaternary)
                if let privacyURL = URL(string: AppSecrets.URLs.privacyPolicy) {
                    Link(Copy.Privacy.privacyPolicy, destination: privacyURL)
                }
            }
            .font(DS.Typography.caption2)
            .foregroundStyle(AppColour.textTertiary)
        }
        .padding(.horizontal, DS.space6)
        .padding(.top, DS.space3)
        .padding(.bottom, DS.space2)
        .background(.ultraThinMaterial)
    }
}
