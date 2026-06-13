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

// MARK: - Reusable timeline draw (shared by Preview + Paywall trial timeline)

/// One node on a vertical timeline. `halo` adds the soft outer ring (present
/// anchor); `solid` fills the dot blue (the live "today" node on the paywall;
/// Preview's anchor keeps a hollow dot, so it sets halo without solid).
struct OnbV2TimelineNode: Identifiable {
    let id: String
    let dayLabel: String
    let title: String
    let body: String
    var halo: Bool = false
    var solid: Bool = false
}

/// A vertical timeline whose spine grows top->bottom as a height mask and whose
/// nodes scale-in one after another (70ms apart). Preview and the paywall trial
/// timeline shared this exact spine+nodes shape, so it lives in one place.
///
/// Reduce Motion: the spine is full height and every node is present instantly
/// (a single crossfade owned by the parent), with no mask growth or scale pop.
struct OnbV2TimelineDraw: View {
    let nodes: [OnbV2TimelineNode]
    /// Flipped true by the parent once its reveal beat for the timeline lands.
    let draw: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Spine sits behind the nodes; the ZStack sizes itself to the node
            // column, so the gradient stretches to exactly the list height.
            spine
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { idx, node in
                    row(node)
                        .scaleEffect(draw ? 1 : (reduceMotion ? 1 : 0.7), anchor: .leading)
                        .opacity(draw ? 1 : 0)
                        .animation(nodeAnimation(idx), value: draw)
                }
            }
        }
    }

    private func nodeAnimation(_ idx: Int) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.15) }
        // Nodes pop in 70ms apart, after the spine has begun to grow.
        return .spring(response: 0.4, dampingFraction: 0.7).delay(0.25 + Double(idx) * 0.07)
    }

    private var spine: some View {
        LinearGradient(
            colors: [OnbV2.blue, OnbV2.blue.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 2)
        .clipShape(RoundedRectangle(cornerRadius: 1))
        // Vertical scale from the top draws the line downward with no measured
        // height (GeometryReader-free, so it never fights the ZStack's sizing).
        .scaleEffect(x: 1, y: (draw || reduceMotion) ? 1 : 0, anchor: .top)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .easeOut(duration: 0.6), value: draw)
        .padding(.leading, 7)
    }

    private func row(_ node: OnbV2TimelineNode) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                if node.halo {
                    Circle()
                        .stroke(OnbV2.blue.opacity(0.2), lineWidth: 4)
                        .frame(width: 24, height: 24)
                }
                Circle()
                    .fill(node.solid ? OnbV2.blue : OnbV2.bg)
                    .frame(width: 16, height: 16)
                Circle()
                    .stroke(OnbV2.blue, lineWidth: 2)
                    .frame(width: 16, height: 16)
            }
            .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(node.dayLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(OnbV2.blue)
                    .textCase(.uppercase)
                Text(node.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(OnbV2.fg)
                    .fixedSize(horizontal: false, vertical: true)
                Text(node.body)
                    .font(.system(size: 13.5))
                    .foregroundStyle(OnbV2.fg3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, -2)
        }
    }
}

// MARK: - Screen 14: Preview

struct OnbV2Screen14Preview: View {
    // Threaded from the router so the first-week preview can personalise to the
    // user's goals and real snapshot. Consumed by the paywall workstream.
    let profile: OnboardingV2Profile
    let snapshot: OnboardingHealthSnapshot
    let onBack: () -> Void
    let onContinue: () -> Void

    // One trigger flips the whole header/CTA stagger; the timeline draws after.
    @State private var appeared = false
    @State private var drawTimeline = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 15, total: OnbV2Flow.total, onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s14Eyebrow)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(OnbV2.blue)
                            .onbV2StaggerIn(index: 0, appeared: appeared)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s14Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .fixedSize(horizontal: false, vertical: true)
                            .onbV2StaggerIn(index: 1, appeared: appeared)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s14Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                            .onbV2StaggerIn(index: 2, appeared: appeared)

                        Spacer().frame(height: 22)

                        OnbV2TimelineDraw(nodes: timelineNodes, draw: drawTimeline)
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                OnbV2PrimaryCTA(Copy.OnboardingV2.s14CTA) {
                    ctaTapped.toggle()
                    onContinue()
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
                .onbV2StaggerIn(index: 4, appeared: appeared)
                .sensoryFeedback(.impact(weight: .light), trigger: ctaTapped)
            }
        }
        .task {
            appeared = true
            // Let the header stagger seat, then draw the timeline spine + nodes.
            try? await Task.sleep(for: .milliseconds(220))
            drawTimeline = true
        }
    }

    @State private var ctaTapped = false

    private var timelineNodes: [OnbV2TimelineNode] {
        Array(Copy.OnboardingV2.previewDays.enumerated()).map { idx, day in
            OnbV2TimelineNode(
                id: "preview_\(day.day)",
                dayLabel: Copy.Onboarding.dayLabel(day.day),
                title: day.title,
                body: day.body,
                halo: idx == 0   // anchor day keeps the soft ring, hollow dot
            )
        }
    }
}

// MARK: - Screen 15: Sign in with Apple

struct OnbV2Screen15SignIn: View {
    let onBack: () -> Void
    let onSignedIn: () -> Void

    @State private var isAuthing = false
    @State private var errorMessage: String?
    @State private var appeared = false
    @State private var pressed = false
    // Outcome trigger: flips only once the Apple sign-in actually succeeds.
    @State private var signedInOk = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnbV2ScreenContainer(ambient: .mix, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 16, total: OnbV2Flow.total, onBack: onBack)

                VStack(spacing: 0) {
                    Spacer()

                    OnbV2HeartHero(size: 180)
                        .onbV2StaggerIn(index: 0, appeared: appeared)

                    Spacer().frame(height: 28)

                    Text(Copy.OnboardingV2.s15Title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnbV2.fg)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .onbV2StaggerIn(index: 1, appeared: appeared)

                    Spacer().frame(height: 14)

                    Text(Copy.OnboardingV2.s15Lede)
                        .font(.system(size: 16))
                        .foregroundStyle(OnbV2.fg2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                        .fixedSize(horizontal: false, vertical: true)
                        .onbV2StaggerIn(index: 2, appeared: appeared)

                    Spacer()
                }
                .padding(.horizontal, OnbV2.bodyPadH)

                VStack(spacing: 12) {
                    Button(action: signIn) {
                        HStack(spacing: 8) {
                            if isAuthing {
                                // Inline progress so the press has a visible
                                // "working" state while Apple's sheet resolves.
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.black)
                            } else {
                                Image(systemName: "applelogo")
                                    .foregroundStyle(.black)
                                Text(Copy.OnboardingV2.s15CTA)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                        )
                        .scaleEffect(pressed && !reduceMotion ? 0.985 : 1)
                        .opacity(isAuthing ? 0.6 : (pressed ? 0.9 : 1))
                        .animation(.easeOut(duration: 0.12), value: pressed)
                    }
                    .buttonStyle(.plain)
                    .disabled(isAuthing)
                    .onLongPressGesture(minimumDuration: 0, pressing: { pressed = $0 }, perform: {})
                    .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, now in now }
                    .sensoryFeedback(.success, trigger: signedInOk)

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
                .onbV2StaggerIn(index: 3, appeared: appeared)
            }
        }
        .task { appeared = true }
    }

    private func signIn() {
        Task { @MainActor in
            isAuthing = true
            defer { isAuthing = false }
            do {
                let result = try await AppleAuthService.shared.signIn()
                // Apple returns fullName only on the FIRST sign-in for a given
                // Apple ID. Capture it now so the home greeting can show
                // "Good morning, {name}".
                if let given = result.fullName?.givenName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !given.isEmpty {
                    UserProfileStore.shared.saveDisplayName(given)
                }
                signedInOk.toggle()   // outcome haptic: success only, never on request
                onSignedIn()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Screen 16: Paywall (real StoreKit prices)

struct OnbV2Screen16Paywall: View {
    // Threaded from the router so the watch list and trial timeline can be
    // built from the user's real goals, symptoms, and verdict. Consumed by the
    // paywall workstream; nil verdict means the user did not reach a rich
    // instant verdict (sparse or denied branch).
    let profile: OnboardingV2Profile
    let snapshot: OnboardingHealthSnapshot
    let verdict: PredictionVerdict?
    let onBack: () -> Void
    let onPurchased: () -> Void

    @State private var selectedIsAnnual = true

    // Reveal clocks the screen owns: the watch-list check cascade ticks one row
    // at a time (each tick = one .selection), the trial timeline draws after,
    // and the plan cards fade in last.
    @State private var revealedChecks = 0
    @State private var drawTimeline = false
    @State private var plansAppeared = false
    // Outcome trigger: only flips when StoreKit actually grants access.
    @State private var purchased = false

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                return Copy.OnboardingV2.s16AnnualSub(perMonth: perMonth, trialDays: "\(trialDays)")
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

        let rows = watchRows
        return OnbV2ScreenContainer(ambient: .mix, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: OnbV2Flow.total, total: OnbV2Flow.total, onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s16Eyebrow)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1.6)
                            .foregroundStyle(OnbV2.blue)
                            .onbV2StaggerIn(index: 0, appeared: revealedChecks > 0)

                        Spacer().frame(height: 8)

                        Text(Copy.OnboardingV2.s16Title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .onbV2StaggerIn(index: 1, appeared: revealedChecks > 0)

                        Spacer().frame(height: 18)

                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                OnbV2WatchRow(
                                    icon: row.icon,
                                    color: row.color,
                                    label: row.label,
                                    sub: row.sub,
                                    showDivider: idx > 0 && rowShown(idx - 1)
                                )
                                // Each row + its check lands one tick at a time,
                                // springing in 80ms apart for the cascade feel.
                                .opacity(rowShown(idx) ? 1 : 0)
                                .scaleEffect(rowShown(idx) ? 1 : (reduceMotion ? 1 : 0.96), anchor: .leading)
                                .animation(rowReveal, value: revealedChecks)
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
                        // One .selection tick per check as the cascade advances.
                        .sensoryFeedback(.selection, trigger: revealedChecks) { old, new in
                            new > old && new <= rows.count
                        }

                        Spacer().frame(height: 18)

                        if productsLoaded {
                            trialTimeline(trialDays: trialDays)
                            Spacer().frame(height: 18)
                        }

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
                            .opacity(plansAppeared ? 1 : 0)
                            .offset(y: plansAppeared || reduceMotion ? 0 : 8)
                            .animation(reduceMotion ? .easeOut(duration: 0.15) : OnbV2.entryEase, value: plansAppeared)
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
                                        Text(Copy.Buttons.retry)
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
                        purchaseTapped.toggle()   // .impact(.medium): purchase intent
                        Task { @MainActor in
                            await SubscriptionManager.shared.purchase(product)
                            if FeatureGate.hasFullAccess {
                                purchased.toggle()   // outcome: access actually granted
                                onPurchased()
                            }
                        }
                    }
                    .sensoryFeedback(.impact(weight: .medium), trigger: purchaseTapped)
                    .sensoryFeedback(.success, trigger: purchased)

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
        .task { await runRevealCascade(rowCount: rows.count) }
    }

    @State private var purchaseTapped = false

    /// True once the cascade has reached row `idx` (0-based). The header reveals
    /// at the same first beat so nothing pops before the list starts.
    private func rowShown(_ idx: Int) -> Bool { revealedChecks > idx }

    private var rowReveal: Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .spring(response: 0.45, dampingFraction: 0.72)
    }

    /// Drives the watch-list check cascade (one row per 80ms tick, each tick a
    /// .selection), then draws the trial timeline, then fades the plan cards in.
    /// Cancel-safe `.task`, so swapping screens stops it cleanly.
    /// Reduce Motion: reveal everything at once on a single crossfade.
    @MainActor
    private func runRevealCascade(rowCount: Int) async {
        if reduceMotion {
            revealedChecks = rowCount
            drawTimeline = true
            plansAppeared = true
            return
        }
        for _ in 0..<rowCount {
            revealedChecks += 1
            try? await Task.sleep(for: .milliseconds(80))
            if Task.isCancelled { return }
        }
        // Let the last check settle before the timeline draws and plans land.
        try? await Task.sleep(for: .milliseconds(120))
        if Task.isCancelled { return }
        drawTimeline = true
        try? await Task.sleep(for: .milliseconds(200))
        if Task.isCancelled { return }
        plansAppeared = true
    }

    // MARK: - Watch list (built from the user's real answers + the read)

    /// The watch list is personal: one row per the user's own goals and
    /// symptoms (their words, their icons), the single concrete weekday dip the
    /// read already found, and a closing weekly-cadence row. No hardcoded
    /// metrics, no invented "Sunday dip".
    private var watchRows: [Copy.OnboardingV2.WatchListRow] {
        var rows: [Copy.OnboardingV2.WatchListRow] = []

        // Goals first: each carries its own icon and accent from the goal copy.
        for goal in profile.goals {
            guard let copy = Copy.OnboardingV2.goalCopy[goal] else { continue }
            rows.append(.init(
                id: "goal_\(goal.rawValue)",
                icon: copy.icon,
                color: copy.accent,
                label: copy.title,
                sub: Copy.OnboardingV2.watchRowGoalSub
            ))
        }

        // Then symptoms the user flagged ("Nothing major" is not a watch item).
        for symptom in profile.symptoms where symptom != .none {
            guard let copy = Copy.OnboardingV2.symptomCopy[symptom] else { continue }
            rows.append(.init(
                id: "symptom_\(symptom.rawValue)",
                icon: copy.icon,
                color: OnbV2.teal,
                label: copy.label,
                sub: Copy.OnboardingV2.watchRowGoalSub
            ))
        }

        // The one concrete pattern from the read: prefer the verdict's weekday
        // (the confirmed driver), else the snapshot's worst HRV weekday.
        let patternWeekday = verdict?.weekday ?? snapshot.hrvWorstWeekday
        if let name = OnbHealthFormat.weekdayName(patternWeekday) {
            rows.append(.init(
                id: "weekday",
                icon: "calendar",
                color: OnbV2.amber,
                label: Copy.OnboardingV2.watchWeekdayLabel(weekday: name),
                sub: Copy.OnboardingV2.watchWeekdaySub
            ))
        }

        // Closing row: the weekly cadence the subscription buys.
        rows.append(.init(
            id: "weekly",
            icon: "sparkles",
            color: OnbV2.blue,
            label: Copy.OnboardingV2.watchWeeklyLabel,
            sub: Copy.OnboardingV2.watchWeeklySub
        ))

        return rows
    }

    // MARK: - Trial timeline (today -> reminder -> renewal)

    /// Three-node timeline derived from the live StoreKit intro-offer length.
    /// `trialDays` is 0 when StoreKit has not surfaced an intro offer; the
    /// reminder and renewal nodes then fall back to a neutral 7-day shape so
    /// the graphic never shows day 0 or a negative reminder.
    private func trialTimeline(trialDays: Int) -> some View {
        let total = trialDays > 0 ? trialDays : 7
        // Reminder lands two days before renewal, but never before day 1.
        let remindDay = max(1, total - 2)
        let nodes: [OnbV2TimelineNode] = [
            OnbV2TimelineNode(
                id: "today",
                dayLabel: Copy.OnboardingV2.s16TimelineDay(0),
                title: Copy.OnboardingV2.s16TimelineToday,
                body: Copy.OnboardingV2.s16TimelineTodaySub,
                halo: true, solid: true   // the live "today" anchor
            ),
            OnbV2TimelineNode(
                id: "remind",
                dayLabel: Copy.OnboardingV2.s16TimelineDay(remindDay),
                title: Copy.OnboardingV2.s16TimelineRemind,
                body: Copy.OnboardingV2.s16TimelineRemindSub
            ),
            OnbV2TimelineNode(
                id: "renew",
                dayLabel: Copy.OnboardingV2.s16TimelineDay(total),
                title: Copy.OnboardingV2.s16TimelineRenew,
                body: Copy.OnboardingV2.s16TimelineRenewSub
            )
        ]
        return OnbV2TimelineDraw(nodes: nodes, draw: drawTimeline)
    }
}

// MARK: - Done

struct OnbV2ScreenDone: View {
    let onDone: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnbV2ScreenContainer(ambient: .mix, staggerOwnsEntry: true) {
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
                // Badge keeps its celebratory pop as the first beat; the spring
                // collapses to a plain fade under Reduce Motion.
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.6))
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.5, dampingFraction: 0.7), value: appeared)

                Spacer().frame(height: 26)

                Text(Copy.OnboardingV2.sDoneTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(OnbV2.fg)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .onbV2StaggerIn(index: 1, appeared: appeared)

                Spacer().frame(height: 12)

                Text(Copy.OnboardingV2.sDoneLede)
                    .font(.system(size: 16))
                    .foregroundStyle(OnbV2.fg2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .fixedSize(horizontal: false, vertical: true)
                    .onbV2StaggerIn(index: 2, appeared: appeared)

                Spacer()

                OnbV2PrimaryCTA(Copy.OnboardingV2.sDoneCTA, action: onDone)
                    .padding(.bottom, 20)
                    .onbV2StaggerIn(index: 3, appeared: appeared)
            }
            .padding(.horizontal, OnbV2.bodyPadH)
            // Completion outcome: the only success beat that lands on arrival.
            .sensoryFeedback(.success, trigger: appeared)
        }
        .onAppear { appeared = true }
    }
}
