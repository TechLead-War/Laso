import Foundation
import Observation
import StoreKit

/// Manages StoreKit 2 subscriptions, entitlement verification, and purchase flow
@Observable
final class SubscriptionManager {
    var products: [Product] = []
    var purchasedProductIds: Set<String> = []
    var isLoading = false
    var errorMessage: String?

    private var transactionListener: Task<Void, Error>?

    /// All product IDs from FeatureConfig
    private var allProductIds: Set<String> {
        var ids: Set<String> = []
        for (_, pricing) in FeatureConfig.pricing {
            ids.insert(pricing.monthlyProductId)
            ids.insert(pricing.yearlyProductId)
        }
        return ids
    }

    init() {
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    /// Fetch available products from App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: allProductIds)
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    /// Purchase a product
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIds.insert(transaction.productID)
                await transaction.finish()
                AnalyticsManager.shared.track(.subscriptionStarted(
                    tier: "pro",
                    plan: product.id.contains("yearly") ? "yearly" : "monthly",
                    price: product.displayPrice
                ))
                return true

            case .userCancelled:
                AnalyticsManager.shared.track(.subscriptionCancelled(tier: "pro"))
                return false

            case .pending:
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Restore

    /// Restore previous purchases
    func restore() async {
        isLoading = true
        defer { isLoading = false }

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedProductIds.insert(transaction.productID)
            }
        }
    }

    // MARK: - Entitlement Check

    /// Determine the user's current tier based on active subscriptions
    var activeTier: SubscriptionTier {
        // Check Pro tier product IDs
        if let proPricing = FeatureConfig.pricing[.pro] {
            if purchasedProductIds.contains(proPricing.monthlyProductId) ||
               purchasedProductIds.contains(proPricing.yearlyProductId) {
                return .pro
            }
        }
        // Add more tier checks here as tiers are added
        return .free
    }

    /// Monthly product for a tier
    func monthlyProduct(for tier: SubscriptionTier) -> Product? {
        guard let pricing = FeatureConfig.pricing[tier] else { return nil }
        return products.first { $0.id == pricing.monthlyProductId }
    }

    /// Yearly product for a tier
    func yearlyProduct(for tier: SubscriptionTier) -> Product? {
        guard let pricing = FeatureConfig.pricing[tier] else { return nil }
        return products.first { $0.id == pricing.yearlyProductId }
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await MainActor.run { [self] in
                        _ = self.purchasedProductIds.insert(transaction.productID)
                    }
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
