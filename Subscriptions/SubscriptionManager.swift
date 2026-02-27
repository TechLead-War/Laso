import Foundation
import StoreKit
import Observation

/// Manages subscription state, purchases, and trial tracking via StoreKit 2.
/// The app is gated: 7-day trial → then paid-only.
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
        /// Apple is retrying the payment — user keeps full access silently
        case billingGrace(daysSinceExpiry: Int)
        case expired
    }

    /// Whether the user can access the app right now.
    var hasAccess: Bool {
        switch status {
        case .trial, .subscribed, .billingGrace: return true
        case .unknown, .expired: return false
        }
    }

    /// Paywall is enforced only after status is definitively expired.
    var shouldEnforcePaywall: Bool {
        if case .expired = status { return true }
        return false
    }

    /// True when we're in a silent billing retry grace period.
    var isBillingGrace: Bool {
        if case .billingGrace = status { return true }
        return false
    }

    /// Formatted trial text for UI (e.g., "5 days left").
    var trialText: String? {
        guard case .trial(let days) = status else { return nil }
        return days == 1 ? "1 day left in trial" : "\(days) days left in trial"
    }

    /// Days into the billing grace period, if applicable.
    var billingGraceDays: Int? {
        if case .billingGrace(let days) = status { return days }
        return nil
    }

    /// Yearly product (primary offering).
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionConfig.yearlyProductID }
    }

    /// Monthly product (anchor for comparison).
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionConfig.monthlyProductID }
    }

    /// Maximum days to silently grant access during billing retry (covers a salary cycle).
    static let billingGraceDays = 30

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?
    private let defaults = UserDefaults.standard

    private enum Key {
        static let installDate = AppKeys.Lifecycle.installDate
        static let graceStartDate = AppKeys.Billing.graceStartDate
        static let lastSubscribedDate = AppKeys.Billing.lastSubscribedDate
    }

    // MARK: - Init

    private init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    /// Call once at app launch to load products and check status.
    func configure() async {
        await loadProducts()
        await refreshStatus()
        AppAnalytics.shared.updateSubscriptionProperties(status: status)
    }

    // MARK: - Products

    @MainActor
    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: SubscriptionConfig.allProductIDs)
            products = loaded.sorted { $0.price > $1.price } // yearly first
            errorMessage = nil
        } catch {
            errorMessage = "Could not load subscription options. Check your connection."
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
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
        } catch {
            errorMessage = "Could not restore purchases. Please try again."
        }
    }

    // MARK: - Status Check

    func refreshStatus() async {
        // 1. Check for an active subscription entitlement
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if SubscriptionConfig.allProductIDs.contains(transaction.productID) {
                if let expiration = transaction.expirationDate, expiration > Date() {
                    status = .subscribed(expirationDate: expiration)
                    // Record that we were subscribed — used for grace period tracking
                    defaults.set(Date(), forKey: Key.lastSubscribedDate)
                    clearGraceState()
                    return
                }
            }
        }

        // 2. No active entitlement — check if Apple is retrying the payment
        if await isInBillingRetry() {
            let graceDays = startOrContinueGrace()
            if graceDays <= Self.billingGraceDays {
                status = .billingGrace(daysSinceExpiry: graceDays)
                return
            }
            // Grace period exhausted — fall through to trial/expired
            clearGraceState()
        }

        // 3. Check our own extended grace (Apple stopped retrying but < 30 days since grace started)
        if let graceStart = defaults.object(forKey: Key.graceStartDate) as? Date {
            let daysSinceGrace = Calendar.current.dateComponents([.day], from: graceStart, to: Date()).day ?? 0
            if daysSinceGrace <= Self.billingGraceDays {
                status = .billingGrace(daysSinceExpiry: daysSinceGrace)
                return
            }
            // Grace exhausted
            clearGraceState()
        }

        // 4. No subscription and no grace — check trial
        resolveTrialStatus()
    }

    /// Checks StoreKit 2 subscription status for billing retry or grace period states.
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

    /// Starts the grace period timer if not already started, returns days since grace began.
    private func startOrContinueGrace() -> Int {
        if let existing = defaults.object(forKey: Key.graceStartDate) as? Date {
            return Calendar.current.dateComponents([.day], from: existing, to: Date()).day ?? 0
        }
        // First time entering grace — record the start
        defaults.set(Date(), forKey: Key.graceStartDate)
        AppAnalytics.shared.trackAction("billing_grace_started")
        return 0
    }

    /// Clears grace period state when subscription is restored or grace expires.
    private func clearGraceState() {
        if defaults.object(forKey: Key.graceStartDate) != nil {
            let wasActive = isBillingGrace
            defaults.removeObject(forKey: Key.graceStartDate)
            if wasActive {
                AppAnalytics.shared.trackAction("billing_grace_resolved")
            }
        }
    }

    private func resolveTrialStatus() {
        let installDate = defaults.object(forKey: Key.installDate) as? Date ?? Date()
        let daysSinceInstall = Calendar.current.dateComponents(
            [.day], from: installDate, to: Date()
        ).day ?? 0

        if daysSinceInstall < SubscriptionConfig.trialDays {
            let remaining = SubscriptionConfig.trialDays - daysSinceInstall
            status = .trial(daysRemaining: remaining)
        } else {
            status = .expired
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                let previousStatus = self?.status
                await self?.refreshStatus()
                if let newStatus = self?.status {
                    AppAnalytics.shared.updateSubscriptionProperties(status: newStatus)
                }
                // Detect renewals: was subscribed before, still subscribed after
                if case .subscribed = previousStatus, case .subscribed = self?.status {
                    AppAnalytics.shared.trackSubscriptionRenewed()
                }
            }
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

    // MARK: - Analytics

    private func trackPurchase(product: Product, isTrialConversion: Bool) {
        AppAnalytics.shared.trackSubscriptionPurchased(
            productID: product.id,
            price: product.displayPrice,
            isTrialConversion: isTrialConversion
        )
        AppAnalytics.shared.updateSubscriptionProperties(status: status)
    }

    // MARK: - Error

    enum SubscriptionError: Error {
        case failedVerification
    }
}
