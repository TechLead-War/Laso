import Foundation
import StoreKit
import Observation
import UIKit
import FacebookCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@MainActor
@Observable
final class SubscriptionManager {

    static let shared = SubscriptionManager()

    // MARK: - Published State

    private(set) var status: Status = .unknown
    private(set) var products: [Product] = []
    private(set) var errorMessage: String?
    private(set) var isPurchasing = false

    // MARK: - Status

    enum Status: Equatable {
        case unknown
        case trial(expiration: Date)
        case subscribed(expirationDate: Date)
        case billingGrace(daysSinceExpiry: Int)
        case expired
    }

    var hasAccess: Bool {
        switch status {
        case .trial, .subscribed, .billingGrace: return true
        case .unknown, .expired: return false
        }
    }

    var shouldEnforcePaywall: Bool {
        if case .expired = status { return true }
        return false
    }

    var isBillingGrace: Bool {
        if case .billingGrace = status { return true }
        return false
    }

    var billingGraceDays: Int? {
        if case .billingGrace(let days) = status { return days }
        return nil
    }

    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionConfig.yearlyProductID }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionConfig.monthlyProductID }
    }

    static let billingGraceDays = 30

    // MARK: - Private

    @ObservationIgnored private var transactionListener: Task<Void, Error>?
    private let defaults = UserDefaults.standard
    private let firestoreCollection = "subscriptions"

    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString
            ?? defaults.string(forKey: AppKeys.Profile.deviceId)
            ?? ""
    }

    /// Firestore document key for this user's subscription mirror.
    /// Keyed by Firebase Auth UID so post-Apple-Sign-In the subscription is
    /// portable across devices on the same Apple ID. Falls back to deviceId only
    /// when Auth has not yet established a session (rare cold-launch race).
    private var firestoreDocumentKey: String {
        #if canImport(FirebaseAuth)
        if let uid = Auth.auth().currentUser?.uid, !uid.isEmpty {
            return uid
        }
        #endif
        return deviceId
    }

    private enum Key {
        static let graceStartDate = AppKeys.Billing.graceStartDate
        static let lastSubscribedDate = AppKeys.Billing.lastSubscribedDate
        /// One-shot per cancellation for subscription_cancel_detected, separate
        /// from cancelledSaveArmed so the churn signal is recorded even when the
        /// save push cannot be scheduled (e.g. notifications denied). Cleared
        /// when auto-renew turns back on so a later re-cancel fires again.
        static let cancelDetectedTracked = "laso.billing.cancel_detected_tracked"
    }

    // MARK: - Init

    private init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        let listener = transactionListener
        listener?.cancel()
    }

    func configure() async {
        // Drain any pending StoreKit transactions before checking entitlements.
        // The Task.detached `listenForTransactions()` started in init() may not
        // have begun consuming Transaction.updates yet on a cold launch; an
        // unfinished purchase from a previous app session could otherwise be
        // missed by refreshStatus(), leaving a paid user incorrectly expired.
        await processUnfinishedTransactions()
        await loadProducts()
        await refreshStatus()
        AppAnalytics.shared.updateSubscriptionProperties(status: status)
    }

    /// Finishes any unfinished StoreKit transactions queued for this app.
    /// Apple stores unfinished transactions across launches; calling
    /// `transaction.finish()` here closes the StoreKit handshake so the
    /// transaction listener does not need to handle them later.
    private func processUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            await transaction.finish()
        }
    }

    /// Forces a status used only when capturing App Store screenshots in UI test
    /// mode. The guard ensures the bypass cannot be invoked outside that mode.
    func setStatusForUITestMode(_ status: Status) {
        guard UITestMode.isEnabled else { return }
        self.status = status
    }

    // MARK: - Products

    @MainActor
    func loadProducts() async {
        let ids = SubscriptionConfig.allProductIDs
        NSLog("[StoreKit] requesting products for IDs: %@", "\(ids)")
        do {
            let loaded = try await Self.withTimeout(seconds: 8) {
                try await Product.products(for: ids)
            }
            NSLog("[StoreKit] got %d products: %@", loaded.count, "\(loaded.map { $0.id })")
            products = loaded.sorted { $0.price > $1.price } // yearly first
            errorMessage = nil
        } catch is TimeoutError {
            NSLog("[StoreKit] timeout")
            errorMessage = "Loading prices took too long. Check your connection and tap Retry."
        } catch {
            NSLog("[StoreKit] error: %@", "\(error)")
            errorMessage = "Could not load subscription options. Check your connection."
        }
    }

    private struct TimeoutError: Error {}

    /// Runs `operation` and throws `TimeoutError` if it does not complete within
    /// `seconds`. Apple's `Product.products(for:)` has no built-in timeout and
    /// can hang indefinitely on degraded networks; this guard prevents a stuck
    /// "Loading prices..." spinner on the paywall.
    private static func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            guard let first = try await group.next() else { throw TimeoutError() }
            group.cancelAll()
            return first
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        // Re-entrancy guard: protects against rapid double-taps that race past
        // the disabled-button check (Task is scheduled async from the main actor;
        // the second tap can land before isPurchasing flips to true here).
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                let wasTrialBefore = { if case .trial = self.status { return true }; return false }()
                // This charge is reported by purchase_completed. Advance the
                // renewal baseline to the purchased period's end BEFORE
                // refreshStatus so its trackSubscriptionRenewed call self-dedupes;
                // otherwise an already-entitled user changing plans fires
                // subscription_renewed + purchase_completed for one charge and
                // renewal_count increments twice.
                if let expiration = transaction.expirationDate {
                    AppAnalytics.shared.advanceRenewalBaseline(to: expiration)
                }
                await refreshStatus()
                await syncSubscriptionToFirestore(transaction)
                trackPurchase(product: product, isTrialConversion: wasTrialBefore, transactionID: transaction.id)
                armTrialNotifications()

                // A paid activation that did not pass through a free trial:
                // confirm it with a welcome push and mark the cohort. A trial
                // conversion (wasTrialBefore) is excluded; it has its own drip.
                if !wasTrialBefore, case .subscribed = status {
                    AppAnalytics.shared.trackNonTrialActivation(
                        productID: product.id,
                        billingPeriod: Self.billingPeriod(for: product)
                    )
                    TrialScheduler.scheduleNonTrialWelcome()
                }

            case .userCancelled:
                AppAnalytics.shared.trackPurchaseFailed(productID: product.id, reason: .userCancelled)

            case .pending:
                errorMessage = "Purchase is pending approval."

            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
            AppAnalytics.shared.trackPurchaseFailed(productID: product.id, reason: .verification)
        }
    }

    /// After a successful purchase, retire any pending trial or win-back nudges
    /// (a paying user should never see them) and, when the new entitlement is a
    /// trial-bearing subscription, arm the trial-lifecycle drip off the live
    /// expiration date. Called only from the purchase success branch.
    private func armTrialNotifications() {
        TrialScheduler.cancelAllAndRearmWinback()
        // Schedule off whichever active entitlement we hold: a free trial now
        // reports as .trial, a direct purchase as .subscribed. Both carry the
        // period-end date the lifecycle drip is anchored to.
        let entitlementEnd: Date
        switch status {
        case .trial(let expiration): entitlementEnd = expiration
        case .subscribed(let expiration): entitlementEnd = expiration
        default: return
        }
        TrialScheduler.scheduleTrialLifecycle(trialEnd: entitlementEnd)
    }

    // MARK: - Restore

    func restorePurchases() async {
        // Clear any prior error first so a later success does not leave a stale error
        // in the paywall footer, and so each failure is a distinct nil->message change
        // (PaywallView tracks restore failures via .onChange of errorMessage; a repeated
        // identical message would otherwise not re-fire onChange and go untracked).
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshStatus()
            await syncCurrentEntitlementToFirestore()
            // Re-stamp the persisted status like configure() and
            // handleTransactionUpdate() do: the renewal/conversion detector
            // keys off lastKnownStatus, so a restore that leaves it stale
            // (e.g. "expired" from earlier in the launch) silently swallows
            // the first post-restore renewal or trial conversion.
            AppAnalytics.shared.updateSubscriptionProperties(status: status)
        } catch {
            errorMessage = "Could not restore purchases. Please try again."
        }
    }

    // MARK: - Status Check

    func refreshStatus() async {
        // The free-year Remote Config flag can flip on AFTER the win-back was
        // armed; retire the now-nonsense push the same way the purchase and
        // referral-unlock paths do. Guarded on the armed flag so a normal
        // refresh pays one defaults read.
        if FeatureGate.freeYearActive, defaults.bool(forKey: AppKeys.Billing.winbackArmed) {
            TrialScheduler.cancelAllAndRearmWinback()
        }

        // 1. Check for an active subscription entitlement.
        //    StoreKit reports the introductory free-trial period as an active
        //    entitlement, so a user inside their 7-day Apple trial lands here
        //    with status = .subscribed (expirationDate = trial end).
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if SubscriptionConfig.allProductIDs.contains(transaction.productID) {
                if let expiration = transaction.expirationDate, expiration > Date() {
                    // Apple reports the introductory free-trial period as an active
                    // entitlement. Distinguish it so the trial-lifecycle analytics
                    // (trial_started / trial_day_check / trial->paid conversion) and
                    // the trial countdown can fire; a paid period stays .subscribed.
                    // Capture grace state before reassigning status so the
                    // billing_grace_resolved event fires on recovery.
                    let wasInGrace = isBillingGrace
                    status = isInFreeTrial(transaction)
                        ? .trial(expiration: expiration)
                        : .subscribed(expirationDate: expiration)
                    // Renewal detection must run on this refresh path: real
                    // renewals land while the app is closed and their
                    // transactions are drained by processUnfinishedTransactions()
                    // before the Transaction.updates listener can observe them.
                    // Self-deduping via the stored expiration baseline.
                    AppAnalytics.shared.trackSubscriptionRenewed(newExpirationDate: expiration)
                    // Record that we were subscribed. used for grace period tracking
                    defaults.set(Date(), forKey: Key.lastSubscribedDate)
                    clearGraceState(wasActive: wasInGrace)
                    await armCancelledSaveIfNeeded(productID: transaction.productID, expiration: expiration)
                    return
                }
            }
        }

        // 2. No active entitlement. check if Apple is retrying the payment
        if await isInBillingRetry() {
            let graceDays = startOrContinueGrace()
            if graceDays <= Self.billingGraceDays {
                status = .billingGrace(daysSinceExpiry: graceDays)
                return
            }
            // Grace period exhausted. fall through to expired
            clearGraceState()
        }

        // 3. Check our own extended grace (Apple stopped retrying but < 30 days since grace started)
        if let graceStart = defaults.object(forKey: Key.graceStartDate) as? Date {
            let daysSinceGrace = Date.cal.dateComponents([.day], from: graceStart, to: Date()).day ?? 0
            if daysSinceGrace <= Self.billingGraceDays {
                status = .billingGrace(daysSinceExpiry: daysSinceGrace)
                return
            }
            // Grace exhausted
            clearGraceState()
        }

        // 4. Cross-reference with Firestore if device is online.
        //    If Firestore has an active subscription record, maintain subscribed state
        //    as a lightweight anti-spoofing layer.
        if let firestoreStatus = await fetchFirestoreSubscriptionStatus() {
            status = firestoreStatus
            return
        }

        // 5. No StoreKit entitlement and no grace -> not entitled.
        //    Trial is purchase-driven (Apple's introductory offer), not
        //    install-date-driven, so without a StoreKit transaction there is
        //    no trial. Onboarding now requires the user to start the trial
        //    via autopay before reaching this state.
        status = .expired
        armWinbackIfNeeded()
    }

    /// Arm the single trial-expired win-back (Journey 3) the first time status
    /// lands on expired. One-shot via `winbackArmed` so refreshStatus, which
    /// runs on many launches, does not keep resetting the delay. The flag is
    /// cleared on the next purchase, so a re-subscribe-then-lapse re-arms it.
    private func armWinbackIfNeeded() {
        // During free year everything is already free, and referral credit
        // also keeps the app unlocked, so a "trial expired" win-back push
        // would be nonsense in either state; skip arming entirely.
        guard !FeatureGate.freeYearActive, !ReferralManager.shared.hasReferralAccess else { return }
        guard !defaults.bool(forKey: AppKeys.Billing.winbackArmed) else { return }
        // Await the real authorization state (StoreKit can resolve before the
        // launch-time auth cache warms) and arm the one-shot flag only after
        // the schedule passed every gate, so a suppressed attempt retries on
        // the next status refresh instead of being lost forever.
        Task {
            guard await NotificationManager.shared.isCurrentlyAuthorized() else { return }
            // Re-check after the await: a purchase can complete (or another
            // refresh can arm the flag) while the authorization query was in
            // flight — an active subscriber must never get the winback push.
            guard case .expired = status,
                  !defaults.bool(forKey: AppKeys.Billing.winbackArmed) else { return }
            // A few hours after expiry, not the instant it lapses, so it reads as a
            // gentle return invite rather than a paywall slam.
            if TrialScheduler.scheduleWinback(focus: trackedFocusLabel(), delay: 6 * 60 * 60) {
                defaults.set(true, forKey: AppKeys.Billing.winbackArmed)
            }
        }
    }

    /// The user's own focus to name in the win-back. Prefers their onboarding
    /// prediction phrase (their exact words); falls back to the first stored
    /// health-focus label; nil when neither exists so the generic copy is used.
    private func trackedFocusLabel() -> String? {
        if let phrase = OnboardingPredictionStore.loadPrediction()?.userPhrase, !phrase.isEmpty {
            return phrase
        }
        return PersistenceManager().loadHealthFocuses().first?.displayName
    }

    /// Whether `transaction` is currently inside its introductory FREE-TRIAL
    /// period, as opposed to a paid period or a paid introductory price. Apple
    /// reports a free trial as an active entitlement, so this is the only way to
    /// tell a trialing user apart from a paying one. iOS 17.2 exposes the applied
    /// offer on the transaction directly; on 17.0-17.1 we read the (now-deprecated)
    /// offerType and confirm it against the product's offer payment mode. When the
    /// trial state cannot be confirmed we return false, i.e. treat it as paid, so
    /// access is never under-granted.
    private func isInFreeTrial(_ transaction: StoreKit.Transaction) -> Bool {
        if #available(iOS 17.2, *) {
            return transaction.offer?.paymentMode == .freeTrial
        }
        guard transaction.offerType == .introductory,
              let product = products.first(where: { $0.id == transaction.productID }),
              product.subscription?.introductoryOffer?.paymentMode == .freeTrial else {
            return false
        }
        return true
    }

    private func isInBillingRetry() async -> Bool {
        for productID in SubscriptionConfig.allProductIDs {
            guard let product = products.first(where: { $0.id == productID }),
                  let subscription = product.subscription else { continue }

            do {
                let statuses = try await subscription.status
                for status in statuses {
                    switch status.state {
                    case .inBillingRetryPeriod, .inGracePeriod:
                        return true
                    default:
                        continue
                    }
                }
            } catch {
                continue
            }
        }
        return false
    }

    /// Detect a still-active paid subscription whose auto-renew has been turned
    /// off (cancelled but not yet lapsed) and arm one save push before it ends.
    /// One-shot via `cancelledSaveArmed`; cleared (and the push cancelled) when
    /// auto-renew is turned back on. Trials are skipped: a trial that will not
    /// renew is the trial-expiry win-back's job, not the paid-save's.
    private func armCancelledSaveIfNeeded(productID: String, expiration: Date) async {
        guard case .subscribed = status else { return }
        guard let willRenew = await autoRenewIsOn(for: productID) else { return }

        if willRenew {
            // Renewal is on (or back on): retire any armed save push and re-arm
            // cancel detection so a later re-cancel is recorded again.
            if defaults.bool(forKey: AppKeys.Billing.cancelledSaveArmed) {
                defaults.set(false, forKey: AppKeys.Billing.cancelledSaveArmed)
                TrialScheduler.cancelCancelledSave()
            }
            defaults.set(false, forKey: Key.cancelDetectedTracked)
            return
        }

        // Auto-renew is off and access is still live: record the churn signal
        // BEFORE any push gating — the analytics observation must not depend on
        // notification permission or on the save push clearing its gates.
        // Migration: on older builds the event fired inside the save-push arming
        // branch, so cancelledSaveArmed=true means it was already emitted for
        // this cancellation; seed the new one-shot so updating mid-cancellation
        // does not re-fire it. Remove once no installs predate this build.
        if defaults.bool(forKey: AppKeys.Billing.cancelledSaveArmed) {
            defaults.set(true, forKey: Key.cancelDetectedTracked)
        }
        if !defaults.bool(forKey: Key.cancelDetectedTracked) {
            defaults.set(true, forKey: Key.cancelDetectedTracked)
            let daysLeft = max(0, Date.cal.dateComponents([.day], from: Date(), to: expiration).day ?? 0)
            AppAnalytics.shared.trackSubscriptionCancelDetected(daysUntilExpiry: daysLeft)
        }

        // Arm the save push once. Await the real authorization state (StoreKit
        // can resolve before the launch-time auth cache warms) and burn the
        // one-shot flag only after the schedule passed every gate, so a
        // suppressed attempt retries on the next status refresh instead of
        // being lost forever.
        guard !defaults.bool(forKey: AppKeys.Billing.cancelledSaveArmed) else { return }
        guard await NotificationManager.shared.isCurrentlyAuthorized() else { return }
        if TrialScheduler.scheduleCancelledSave(focus: trackedFocusLabel(), expiration: expiration) {
            defaults.set(true, forKey: AppKeys.Billing.cancelledSaveArmed)
        }
    }

    /// Whether the active subscription for `productID` is set to auto-renew.
    /// Returns nil when StoreKit does not surface renewal info (offline or no
    /// subscription), so callers no-op rather than guess.
    private func autoRenewIsOn(for productID: String) async -> Bool? {
        guard let product = products.first(where: { $0.id == productID }),
              let subscription = product.subscription else { return nil }
        do {
            let statuses = try await subscription.status
            // Prefer the renewal info that matches this exact product.
            for status in statuses {
                if case .verified(let renewalInfo) = status.renewalInfo,
                   renewalInfo.currentProductID == productID {
                    return renewalInfo.willAutoRenew
                }
            }
            // Fall back to the first verified renewal info in the group.
            for status in statuses {
                if case .verified(let renewalInfo) = status.renewalInfo {
                    return renewalInfo.willAutoRenew
                }
            }
            return nil
        } catch {
            return nil
        }
    }

    private func startOrContinueGrace() -> Int {
        if let existing = defaults.object(forKey: Key.graceStartDate) as? Date {
            return Date.cal.dateComponents([.day], from: existing, to: Date()).day ?? 0
        }
        // First time entering grace. record the start
        defaults.set(Date(), forKey: Key.graceStartDate)
        AppAnalytics.shared.trackBillingGraceStarted(daysSinceInstall: SessionTracker.shared.daysSinceInstall)
        return 0
    }

    private func clearGraceState(wasActive: Bool? = nil) {
        if let graceStart = defaults.object(forKey: Key.graceStartDate) as? Date {
            // Recovery callers reassign `status` away from .billingGrace before
            // calling this, so isBillingGrace would already read false. They pass
            // the pre-reassignment value explicitly; other callers pass nil and
            // fall back to the current status.
            let wasActive = wasActive ?? isBillingGrace
            let daysInGrace = Date.cal.dateComponents([.day], from: graceStart, to: Date()).day ?? 0
            defaults.removeObject(forKey: Key.graceStartDate)
            if wasActive {
                AppAnalytics.shared.trackBillingGraceResolved(daysInGrace: daysInGrace)
            }
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.handleTransactionUpdate()
            }
        }
    }

    private func handleTransactionUpdate() async {
        // Renewal/conversion detection happens inside refreshStatus, keyed off
        // the persisted status — the in-memory `status` is still .unknown when
        // a transaction lands during cold launch, so it cannot be trusted here.
        await refreshStatus()
        await syncCurrentEntitlementToFirestore()
        AppAnalytics.shared.updateSubscriptionProperties(status: status)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Firestore Subscription Verification

    /// Sync a specific StoreKit transaction to Firestore as a server-side record.
    /// Called after a successful purchase to create an authoritative subscription document.
    private func syncSubscriptionToFirestore(_ transaction: StoreKit.Transaction) async {
        guard !firestoreDocumentKey.isEmpty else { return }

        let environmentString: String
        if #available(iOS 16.0, *) {
            environmentString = transaction.environment == .production ? "production" : "sandbox"
        } else {
            environmentString = "unknown"
        }

        let data: [String: Any] = [
            "productId": transaction.productID,
            "originalTransactionId": String(transaction.originalID),
            "purchaseDate": transaction.purchaseDate.timeIntervalSince1970,
            "expirationDate": transaction.expirationDate?.timeIntervalSince1970 ?? 0,
            "environment": environmentString,
            "lastVerified": Date().timeIntervalSince1970,
            "deviceId": deviceId
        ]

        #if canImport(FirebaseFirestore)
        do {
            try await Firestore.firestore()
                .collection(firestoreCollection)
                .document(firestoreDocumentKey)
                .setData(data, merge: true)
        } catch {
            // Firestore write failed silently. local entitlement remains the source of truth.
        }
        #endif
    }

    /// Sync the current active entitlement (if any) to Firestore.
    /// Called after restore or transaction updates where we don't have the raw Transaction object.
    private func syncCurrentEntitlementToFirestore() async {
        guard !firestoreDocumentKey.isEmpty else { return }

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if SubscriptionConfig.allProductIDs.contains(transaction.productID),
               let expiration = transaction.expirationDate, expiration > Date() {
                await syncSubscriptionToFirestore(transaction)
                return
            }
        }

        // No active entitlement -- mark as expired in Firestore so the record stays current
        #if canImport(FirebaseFirestore)
        do {
            try await Firestore.firestore()
                .collection(firestoreCollection)
                .document(firestoreDocumentKey)
                .setData([
                    "expirationDate": 0,
                    "lastVerified": Date().timeIntervalSince1970,
                    "deviceId": deviceId
                ], merge: true)
        } catch {}
        #endif
    }

    /// Fetch subscription status from Firestore as a cross-reference.
    /// Returns a valid `Status` if Firestore has an active, non-expired subscription record.
    /// Returns `nil` if offline, no record exists, or the record is expired.
    private func fetchFirestoreSubscriptionStatus() async -> Status? {
        guard !firestoreDocumentKey.isEmpty else { return nil }

        #if canImport(FirebaseFirestore)
        do {
            let doc = try await Firestore.firestore()
                .collection(firestoreCollection)
                .document(firestoreDocumentKey)
                .getDocument()

            guard let data = doc.data(),
                  let expirationTimestamp = data["expirationDate"] as? TimeInterval,
                  expirationTimestamp > 0 else {
                return nil
            }

            let expirationDate = Date(timeIntervalSince1970: expirationTimestamp)
            guard expirationDate > Date() else { return nil }

            // Firestore says subscription is still active
            return .subscribed(expirationDate: expirationDate)
        } catch {
            // Offline or Firestore error. fall back to local-only resolution.
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - Analytics

    /// Billing-period label for analytics, derived from the product's
    /// subscription period unit. Shared by purchase tracking and the
    /// non-trial activation event so the mapping lives in one place.
    private static func billingPeriod(for product: Product) -> String {
        switch product.subscription?.subscriptionPeriod.unit {
        case .month: return "monthly"
        case .year: return "yearly"
        case .week: return "weekly"
        default: return "unknown"
        }
    }

    private func trackPurchase(product: Product, isTrialConversion: Bool, transactionID: UInt64) {
        let period = Self.billingPeriod(for: product)
        // status was refreshed just before this call; .trial means the purchase
        // opened Apple's $0 introductory trial, not a paid activation.
        let isFreeTrialStart = { if case .trial = self.status { return true }; return false }()
        AppAnalytics.shared.trackPurchaseCompleted(
            productID: product.id,
            billingPeriod: period,
            grossRevenue: NSDecimalNumber(decimal: product.price).doubleValue,
            currency: product.priceFormatStyle.currencyCode,
            isTrialConversion: isTrialConversion,
            isFreeTrialStart: isFreeTrialStart,
            transactionIDHash: AppAnalytics.sha256Hash16(String(transactionID))
        )
        AppAnalytics.shared.updateSubscriptionProperties(status: status)

        // Meta ad optimization: send the standard StartTrial / Subscribe event
        // so campaigns optimizing for subscription activation have a signal to
        // bid on. A first purchase that opens a free trial reports as .trial; a
        // direct or converted paid period reports as .subscribed.
        let fbEvent: AppEvents.Name = { if case .trial = status { return .startTrial }; return .subscribe }()
        AppEvents.shared.logEvent(
            fbEvent,
            valueToSum: NSDecimalNumber(decimal: product.price).doubleValue,
            parameters: [.currency: product.priceFormatStyle.currencyCode]
        )
    }

    // MARK: - Error

    enum SubscriptionError: Error {
        case failedVerification
    }
}
