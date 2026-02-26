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
        case expired
    }

    /// Whether the user can access the app right now.
    var hasAccess: Bool {
        switch status {
        case .trial, .subscribed: return true
        case .unknown, .expired: return false
        }
    }

    /// Formatted trial text for UI (e.g., "5 days left").
    var trialText: String? {
        guard case .trial(let days) = status else { return nil }
        return days == 1 ? "1 day left in trial" : "\(days) days left in trial"
    }

    /// Yearly product (primary offering).
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionConfig.yearlyProductID }
    }

    /// Monthly product (anchor for comparison).
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionConfig.monthlyProductID }
    }

    // MARK: - Private

    private var transactionListener: Task<Void, Error>?
    private let defaults = UserDefaults.standard

    private enum Key {
        static let installDate = "laso.install_date"
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
    }

    // MARK: - Products

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: SubscriptionConfig.allProductIDs)
            products = loaded.sorted { $0.price > $1.price } // yearly first
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
                await refreshStatus()
                trackPurchase(product: product)

            case .userCancelled:
                break

            case .pending:
                errorMessage = "Purchase is pending approval."

            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed. Please try again."
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
        // Check for an active subscription entitlement first
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }

            if SubscriptionConfig.allProductIDs.contains(transaction.productID) {
                if let expiration = transaction.expirationDate, expiration > Date() {
                    status = .subscribed(expirationDate: expiration)
                    return
                }
            }
        }

        // No active subscription — check trial
        resolveTrialStatus()
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
                await self?.refreshStatus()
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

    private func trackPurchase(product: Product) {
        let region = Locale.current.region?.identifier ?? "unknown"
        let tier = SubscriptionConfig.currentTier.rawValue
        AppAnalytics.shared.trackAction("subscription_purchased", metadata: [
            "product_id": product.id,
            "price": product.displayPrice,
            "region": region,
            "price_tier": tier,
        ])
    }

    // MARK: - Error

    enum SubscriptionError: Error {
        case failedVerification
    }
}
