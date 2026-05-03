import Foundation
import StoreKit
import Observation
import UIKit

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
        case trial(daysRemaining: Int)
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

    var trialText: String? {
        guard case .trial(let days) = status else { return nil }
        return days == 1 ? "1 day left in trial" : "\(days) days left in trial"
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
                await refreshStatus()
                await syncSubscriptionToFirestore(transaction)
                trackPurchase(product: product, isTrialConversion: wasTrialBefore)

            case .userCancelled:
                AppAnalytics.shared.trackPurchaseFailed(productID: product.id, errorType: "user_cancelled")

            case .pending:
                errorMessage = "Purchase is pending approval."

            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
            AppAnalytics.shared.trackPurchaseFailed(productID: product.id, errorType: "purchase_error")
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshStatus()
            await syncCurrentEntitlementToFirestore()
        } catch {
            errorMessage = "Could not restore purchases. Please try again."
        }
    }

    // MARK: - Status Check

    func refreshStatus() async {
        // 1. Check for an active subscription entitlement.
        //    StoreKit reports the introductory free-trial period as an active
        //    entitlement, so a user inside their 7-day Apple trial lands here
        //    with status = .subscribed (expirationDate = trial end).
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if SubscriptionConfig.allProductIDs.contains(transaction.productID) {
                if let expiration = transaction.expirationDate, expiration > Date() {
                    status = .subscribed(expirationDate: expiration)
                    // Record that we were subscribed. used for grace period tracking
                    defaults.set(Date(), forKey: Key.lastSubscribedDate)
                    clearGraceState()
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

    private func startOrContinueGrace() -> Int {
        if let existing = defaults.object(forKey: Key.graceStartDate) as? Date {
            return Date.cal.dateComponents([.day], from: existing, to: Date()).day ?? 0
        }
        // First time entering grace. record the start
        defaults.set(Date(), forKey: Key.graceStartDate)
        AppAnalytics.shared.trackBillingGraceStarted(daysSinceInstall: SessionTracker.shared.daysSinceInstall)
        return 0
    }

    private func clearGraceState() {
        if let graceStart = defaults.object(forKey: Key.graceStartDate) as? Date {
            let wasActive = isBillingGrace
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
        let previousStatus = status
        await refreshStatus()
        await syncCurrentEntitlementToFirestore()
        AppAnalytics.shared.updateSubscriptionProperties(status: status)
        if case .subscribed = previousStatus, case .subscribed(let expirationDate) = status {
            AppAnalytics.shared.trackSubscriptionRenewed(newExpirationDate: expirationDate)
        }
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

    private func trackPurchase(product: Product, isTrialConversion: Bool) {
        let period: String = switch product.subscription?.subscriptionPeriod.unit {
        case .month: "monthly"
        case .year: "yearly"
        case .week: "weekly"
        default: "unknown"
        }
        AppAnalytics.shared.trackSubscriptionPurchased(
            productID: product.id,
            price: product.displayPrice,
            isTrialConversion: isTrialConversion,
            revenueAmount: NSDecimalNumber(decimal: product.price).doubleValue,
            currency: product.priceFormatStyle.currencyCode,
            subscriptionPeriod: period
        )
        AppAnalytics.shared.updateSubscriptionProperties(status: status)
    }

    // MARK: - Error

    enum SubscriptionError: Error {
        case failedVerification
    }
}
