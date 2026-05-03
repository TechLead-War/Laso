import SwiftUI
import StoreKit

private extension Product.SubscriptionPeriod {
    var daysApprox: Int {
        switch unit {
        case .day:   return value
        case .week:  return value * 7
        case .month: return value * 30
        case .year:  return value * 365
        @unknown default: return value
        }
    }
}

// MARK: - Screen 14: Preview

struct OnbV2Screen14Preview: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 14, total: 16, onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s14Eyebrow)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(OnbV2.blue)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s14Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s14Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer().frame(height: 22)

                        timeline
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                OnbV2PrimaryCTA(Copy.OnboardingV2.s14CTA, action: onContinue)
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.bottom, 20)
            }
        }
    }

    private var timeline: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [OnbV2.blue, OnbV2.blue.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 2)
            .clipShape(RoundedRectangle(cornerRadius: 1))
            .padding(.leading, 7)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(Copy.OnboardingV2.previewDays.enumerated()), id: \.offset) { idx, day in
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            if idx == 0 {
                                Circle()
                                    .stroke(OnbV2.blue.opacity(0.2), lineWidth: 4)
                                    .frame(width: 24, height: 24)
                            }
                            Circle()
                                .fill(OnbV2.bg)
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(OnbV2.blue, lineWidth: 2)
                                .frame(width: 16, height: 16)
                        }
                        .frame(width: 16, height: 16)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("DAY \(day.day)")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.7)
                                .foregroundStyle(OnbV2.blue)
                                .textCase(.uppercase)
                            Text(day.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(OnbV2.fg)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(day.body)
                                .font(.system(size: 13.5))
                                .foregroundStyle(OnbV2.fg3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, -2)
                    }
                }
            }
        }
    }
}

// MARK: - Screen 15: Sign in with Apple

struct OnbV2Screen15SignIn: View {
    let onBack: () -> Void
    let onSignedIn: () -> Void

    @State private var isAuthing = false
    @State private var errorMessage: String?

    var body: some View {
        OnbV2ScreenContainer(ambient: .mix) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 15, total: 16, onBack: onBack)

                VStack(spacing: 0) {
                    Spacer()

                    OnbV2HeartHero(size: 180)

                    Spacer().frame(height: 28)

                    Text(Copy.OnboardingV2.s15Title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnbV2.fg)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 14)

                    Text(Copy.OnboardingV2.s15Lede)
                        .font(.system(size: 16))
                        .foregroundStyle(OnbV2.fg2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(.horizontal, OnbV2.bodyPadH)

                VStack(spacing: 12) {
                    Button {
                        Task { @MainActor in
                            isAuthing = true
                            defer { isAuthing = false }
                            do {
                                let result = try await AppleAuthService.shared.signIn()
                                // Apple returns fullName only on the FIRST sign-in
                                // for a given Apple ID. Capture it now so the home
                                // greeting can show "Good morning, {name}".
                                if let given = result.fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !given.isEmpty {
                                    UserProfileStore.shared.saveDisplayName(given)
                                }
                                onSignedIn()
                            } catch {
                                self.errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "applelogo")
                                .foregroundStyle(.black)
                            Text(Copy.OnboardingV2.s15CTA)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthing)
                    .opacity(isAuthing ? 0.6 : 1)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(OnbV2.rose)
                            .multilineTextAlignment(.center)
                    }

                    Text(Copy.OnboardingV2.s15Footnote)
                        .font(.system(size: 11.5))
                        .foregroundStyle(OnbV2.fg4)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Screen 16: Paywall (real StoreKit prices)

struct OnbV2Screen16Paywall: View {
    let onBack: () -> Void
    let onPurchased: () -> Void

    @State private var selectedIsAnnual = true

    @Environment(\.openURL) private var openURL
    private let manager = SubscriptionManager.shared

    var body: some View {
        let yearly = manager.yearlyProduct
        let monthly = manager.monthlyProduct
        let productsLoaded = (yearly != nil || monthly != nil)

        let annualPriceText: String = {
            if let p = yearly { return "\(p.displayPrice)/yr" }
            return ""
        }()

        let monthlyPriceText: String = {
            if let p = monthly { return "\(p.displayPrice)/mo" }
            return ""
        }()

        let savingsBadge: String? = {
            guard let y = yearly, let m = monthly, m.price > 0 else { return nil }
            let yearlyMonthly = (y.price as Decimal) / 12
            let pct = ((m.price - yearlyMonthly) / m.price) * 100
            let pctInt = Int(truncating: pct as NSDecimalNumber)
            guard pctInt > 0 else { return nil }
            return String(format: "Save %d%%", pctInt)
        }()

        let trialDays: Int = yearly?.subscription?.introductoryOffer?.period.daysApprox ?? 0

        let perMonthApprox: String? = {
            guard let y = yearly else { return nil }
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale.current
            formatter.currencyCode = y.priceFormatStyle.currencyCode
            let perMonth = NSDecimalNumber(decimal: (y.price as Decimal) / 12)
            return formatter.string(from: perMonth)
        }()

        let annualSub: String = {
            guard let perMonth = perMonthApprox else { return "" }
            if trialDays > 0 {
                return String(format: Copy.OnboardingV2.s16AnnualSubFmt, perMonth, "\(trialDays)")
            }
            return "That's about \(perMonth) per month"
        }()

        let ctaTitle: String = {
            guard productsLoaded else { return Copy.OnboardingV2.s16NoProducts }
            let p = selectedIsAnnual ? yearly : monthly
            if let intro = p?.subscription?.introductoryOffer, intro.period.value > 0 {
                let days = intro.period.daysApprox
                if days > 0 { return "Start \(days) day free trial" }
                return Copy.OnboardingV2.s16CTA
            }
            return Copy.OnboardingV2.s16CTAFallback
        }()

        return OnbV2ScreenContainer(ambient: .mix) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 16, total: 16, onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s16Eyebrow)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(OnbV2.blue)

                        Spacer().frame(height: 8)

                        Text(Copy.OnboardingV2.s16Title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer().frame(height: 18)

                        VStack(spacing: 0) {
                            ForEach(Array(Copy.OnboardingV2.watchListRows.enumerated()), id: \.offset) { idx, row in
                                OnbV2WatchRow(
                                    icon: row.icon,
                                    color: row.color,
                                    label: row.label,
                                    sub: row.sub,
                                    showDivider: idx > 0
                                )
                            }
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(OnbV2.bg2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(OnbV2.line, lineWidth: 1)
                        )

                        Spacer().frame(height: 18)

                        if productsLoaded {
                            VStack(spacing: 10) {
                                OnbV2PlanCard(
                                    title: Copy.OnboardingV2.s16AnnualTitle,
                                    priceText: annualPriceText,
                                    sublabel: annualSub,
                                    badge: savingsBadge,
                                    isSelected: selectedIsAnnual
                                ) {
                                    selectedIsAnnual = true
                                }

                                OnbV2PlanCard(
                                    title: Copy.OnboardingV2.s16MonthlyTitle,
                                    priceText: monthlyPriceText,
                                    sublabel: Copy.OnboardingV2.s16MonthlySub,
                                    badge: nil,
                                    isSelected: !selectedIsAnnual
                                ) {
                                    selectedIsAnnual = false
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                if let err = manager.errorMessage {
                                    Text(err)
                                        .font(.system(size: 13))
                                        .foregroundStyle(OnbV2.rose)
                                        .multilineTextAlignment(.center)
                                    Button {
                                        Task { @MainActor in await SubscriptionManager.shared.loadProducts() }
                                    } label: {
                                        Text("Retry")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(OnbV2.blue)
                                    }
                                } else {
                                    HStack(spacing: 10) {
                                        ProgressView().controlSize(.small).tint(OnbV2.fg3)
                                        Text(Copy.OnboardingV2.s16NoProducts)
                                            .font(.system(size: 13))
                                            .foregroundStyle(OnbV2.fg3)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 28)
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }

                VStack(spacing: 12) {
                    OnbV2PrimaryCTA(
                        ctaTitle,
                        isEnabled: !manager.isPurchasing && productsLoaded
                    ) {
                        guard let product = selectedIsAnnual ? yearly : monthly else { return }
                        Task { @MainActor in
                            await SubscriptionManager.shared.purchase(product)
                            if FeatureGate.hasFullAccess { onPurchased() }
                        }
                    }

                    HStack(spacing: 14) {
                        Button {
                            Task { @MainActor in
                                await SubscriptionManager.shared.restorePurchases()
                                if FeatureGate.hasFullAccess { onPurchased() }
                            }
                        } label: {
                            Text(Copy.OnboardingV2.s16Restore)
                                .font(.system(size: 12))
                                .foregroundStyle(OnbV2.fg4)
                        }

                        Button {
                            if let url = URL(string: "https://laso.ai/terms") {
                                openURL(url)
                            }
                        } label: {
                            Text(Copy.OnboardingV2.s16Terms)
                                .font(.system(size: 12))
                                .foregroundStyle(OnbV2.fg4)
                        }

                        Button {
                            if let url = URL(string: "https://laso.ai/privacy") {
                                openURL(url)
                            }
                        } label: {
                            Text(Copy.OnboardingV2.s16Privacy)
                                .font(.system(size: 12))
                                .foregroundStyle(OnbV2.fg4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
        .task {
            if SubscriptionManager.shared.products.isEmpty {
                await SubscriptionManager.shared.loadProducts()
            }
        }
    }
}

// MARK: - Done

struct OnbV2ScreenDone: View {
    let onDone: () -> Void

    @State private var appeared = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .mix) {
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [OnbV2.green, OnbV2.green.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 84, height: 84)
                        .shadow(color: OnbV2.green.opacity(0.4), radius: 14, x: 0, y: 6)

                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .font(.system(size: 36, weight: .bold))
                }
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)

                Spacer().frame(height: 26)

                Text(Copy.OnboardingV2.sDoneTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(OnbV2.fg)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 12)

                Text(Copy.OnboardingV2.sDoneLede)
                    .font(.system(size: 16))
                    .foregroundStyle(OnbV2.fg2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                OnbV2PrimaryCTA(Copy.OnboardingV2.sDoneCTA, action: onDone)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, OnbV2.bodyPadH)
        }
        .onAppear { appeared = true }
    }
}
