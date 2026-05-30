import SwiftUI
import StoreKit

/// Full-screen paywall. Used both for trial-expired enforcement and as a
/// mandatory step inside onboarding (autopay setup with Apple introductory
/// free trial). When `onSubscribed` is non-nil, it fires the moment the
/// StoreKit entitlement flips to `.subscribed` so the parent can advance.
struct PaywallView: View {
    let subscriptionManager: SubscriptionManager
    let source: String
    let onSubscribed: (() -> Void)?

    init(
        subscriptionManager: SubscriptionManager,
        source: String = "trial_expired",
        onSubscribed: (() -> Void)? = nil
    ) {
        self.subscriptionManager = subscriptionManager
        self.source = source
        self.onSubscribed = onSubscribed
    }

    @State private var selectedProduct: Product?
    @State private var isRestoring = false
    @State private var paywallOpenDate = Date()
    /// Drives the in-app Safari sheet for Terms / Privacy. SwiftUI `Link`
    /// inside a `fullScreenCover` does not fire on iPad (App Review 2.1
    /// rejection on iPadOS 26), so we present SFSafariViewController instead.
    @State private var legalSheet: IdentifiedURL?
    /// Guards against `onSubscribed` firing more than once. Three independent
    /// observers (onAppear, status onChange, lastFetchTime onChange) can each
    /// detect "user now has full access" almost simultaneously after a purchase
    /// or a free-year flag flip; without this guard, finishOnboarding() would
    /// be invoked twice and corrupt analytics + navigation state.
    @State private var hasAdvanced = false

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
                "source": source,
                "products_available": subscriptionManager.products.count
            ])
            AppAnalytics.shared.trackPaywallViewed(source: source)
            // Onboarding-trial safety: if the user already has full access
            // (existing entitlement, billing grace, or remote-config free-year
            // bypass), advance immediately so we never force them to repurchase.
            advanceIfFullAccessGranted()
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.paywall)
            let duration = Int(Date().timeIntervalSince(paywallOpenDate))
            if !subscriptionManager.hasAccess {
                AppAnalytics.shared.trackPaywallDismissed(
                    timeOnPaywallSec: duration,
                    source: source
                )
            }
        }
        .onChange(of: subscriptionManager.products) { _, _ in
            if selectedProduct == nil {
                selectedProduct = yearly ?? monthly
            }
        }
        .onChange(of: subscriptionManager.status) { _, _ in
            advanceIfFullAccessGranted()
        }
        // Watch Remote Config fetches too: if free_year_active flips ON while
        // the user is sitting on this paywall (onboarding or otherwise), we
        // must auto-advance instead of forcing autopay setup they don't need.
        .onChange(of: RemoteConfigManager.shared.lastFetchTime) { _, _ in
            advanceIfFullAccessGranted()
        }
        // Surface paywall errors to PostHog the moment they appear (purchase
        // declined, restore failed, products fetch failed). Distinct from
        // `purchase_failed` (post-CTA) so we capture network/timeout cases too.
        .onChange(of: subscriptionManager.errorMessage) { _, newValue in
            guard let message = newValue, !message.isEmpty else { return }
            AppAnalytics.shared.trackPaywallError(
                errorType: classifyPaywallError(message),
                source: source,
                timeOnPaywallSec: Int(Date().timeIntervalSince(paywallOpenDate))
            )
        }
    }

    /// Map a free-form StoreKit error message to a stable `error_type` bucket
    /// so PostHog can group similar failures across iOS locales.
    private func classifyPaywallError(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("network") || lower.contains("internet") || lower.contains("connection") {
            return "network"
        }
        if lower.contains("cancel") {
            return "cancelled"
        }
        if lower.contains("declin") || lower.contains("payment") {
            return "payment_declined"
        }
        if lower.contains("not allowed") || lower.contains("permission") {
            return "not_permitted"
        }
        return "unknown"
    }

    /// Single entry point for "user has full access, advance the parent flow".
    /// Guards against re-entry so onAppear + status onChange + lastFetchTime
    /// onChange firing in quick succession can never call onSubscribed twice.
    private func advanceIfFullAccessGranted() {
        guard !hasAdvanced, FeatureGate.hasFullAccess else { return }
        hasAdvanced = true
        onSubscribed?()
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
            // Plan-selection funnel signal: distinct from CTA tap so we can see
            // how many users toggle yearly vs monthly before committing.
            AppAnalytics.shared.trackPaywallPlanSelected(
                productID: product.id,
                period: label.lowercased(),
                price: product.displayPrice
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Paywall.planLabel(label, detail))
        .accessibilityHint(Copy.Paywall.selectsTheSubscriptionPlanHint(label.lowercased()))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            .accessibilityLabel(callToActionTitle)
            .accessibilityHint(selectedProductHasTrial ? "Starts your free trial and subscribes after" : "Subscribes you to the selected plan")
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
                    if !restored {
                        AppAnalytics.shared.trackPaywallError(
                            errorType: "restore_failed",
                            source: source,
                            timeOnPaywallSec: Int(Date().timeIntervalSince(paywallOpenDate))
                        )
                    }
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
            .accessibilityLabel(Copy.Buttons.restorePurchases)
            .accessibilityHint(Copy.Paywall.restoresAnyPriorSubscriptionTiedToHint)
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

            Text(Copy.Paywall.appleAutoRenewDisclosure)
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space6)

            HStack(spacing: DS.space4) {
                if let termsURL = URL(string: AppSecrets.URLs.termsOfUse) {
                    Button(Copy.Privacy.termsOfUse) {
                        footerTracker.tapped(target: "terms_of_use")
                        legalSheet = IdentifiedURL(url: termsURL)
                    }
                    .accessibilityIdentifier("paywall.termsLink")
                }
                Text("\u{00B7}")
                    .foregroundStyle(AppColour.textQuaternary)
                if let privacyURL = URL(string: AppSecrets.URLs.privacyPolicy) {
                    Button(Copy.Privacy.privacyPolicy) {
                        footerTracker.tapped(target: "privacy_policy")
                        legalSheet = IdentifiedURL(url: privacyURL)
                    }
                    .accessibilityIdentifier("paywall.privacyLink")
                }
            }
            .font(DS.Typography.caption2)
            .foregroundStyle(AppColour.textTertiary)
        }
        .padding(.horizontal, DS.space6)
        .padding(.top, DS.space3)
        .padding(.bottom, DS.space2)
        .background(.ultraThinMaterial)
        .sheet(item: $legalSheet) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}
