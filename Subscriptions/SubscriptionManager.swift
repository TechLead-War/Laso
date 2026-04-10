import Foundation
import StoreKit
import Observation
import Security
import CryptoKit
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
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

    private enum Key {
        static let installDate = AppKeys.Lifecycle.installDate
        static let graceStartDate = AppKeys.Billing.graceStartDate
        static let lastSubscribedDate = AppKeys.Billing.lastSubscribedDate
        static let keychainInstallDate = "com.lasohealth.install_date"
        static let keychainInstallHash = "com.lasohealth.install_date_hash"
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
        // 1. Check for an active subscription entitlement
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
            // Grace period exhausted. fall through to trial/expired
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

        // 4. Cross-reference with Firestore if device is online.
        //    If Firestore has an active subscription record, maintain subscribed state
        //    as a lightweight anti-spoofing layer.
        if let firestoreStatus = await fetchFirestoreSubscriptionStatus() {
            status = firestoreStatus
            return
        }

        // 5. No subscription and no grace. check trial
        resolveTrialStatus()
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
            return Calendar.current.dateComponents([.day], from: existing, to: Date()).day ?? 0
        }
        // First time entering grace. record the start
        defaults.set(Date(), forKey: Key.graceStartDate)
        AppAnalytics.shared.trackBillingGraceStarted(daysSinceInstall: SessionTracker.shared.daysSinceInstall)
        return 0
    }

    private func clearGraceState() {
        if let graceStart = defaults.object(forKey: Key.graceStartDate) as? Date {
            let wasActive = isBillingGrace
            let daysInGrace = Calendar.current.dateComponents([.day], from: graceStart, to: Date()).day ?? 0
            defaults.removeObject(forKey: Key.graceStartDate)
            if wasActive {
                AppAnalytics.shared.trackBillingGraceResolved(daysInGrace: daysInGrace)
            }
        }
    }

    private func resolveTrialStatus() {
        let installDate = persistentInstallDate()
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

    // MARK: - Persistent Install Date (Keychain-backed)

    /// Returns the original install date, persisted in Keychain to survive app reinstalls.
    /// On first launch: stores the current date in both Keychain and UserDefaults.
    /// On reinstall: recovers the original date from Keychain even if UserDefaults was wiped.
    private func persistentInstallDate() -> Date {
        // 1. Try Keychain first (survives app deletion)
        if let keychainDate = loadInstallDateFromKeychain() {
            // Validate integrity using device-bound hash
            if verifyInstallDateIntegrity(keychainDate) {
                // Backfill UserDefaults if it was wiped (reinstall scenario)
                if defaults.object(forKey: Key.installDate) == nil {
                    defaults.set(keychainDate, forKey: Key.installDate)
                }
                return keychainDate
            }
            // Hash mismatch -- Keychain date may have been tampered with.
            // Fall through to treat as new install (conservative approach).
        }

        // 2. Check UserDefaults (normal case on existing installs before this migration)
        if let defaultsDate = defaults.object(forKey: Key.installDate) as? Date {
            // Migrate existing install date to Keychain
            saveInstallDateToKeychain(defaultsDate)
            saveInstallDateHash(for: defaultsDate)
            return defaultsDate
        }

        // 3. Truly new install -- record the date everywhere
        let now = Date()
        defaults.set(now, forKey: Key.installDate)
        saveInstallDateToKeychain(now)
        saveInstallDateHash(for: now)
        return now
    }

    // MARK: - Keychain Helpers

    private func loadInstallDateFromKeychain() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Key.keychainInstallDate,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let timestamp = String(data: data, encoding: .utf8),
              let interval = TimeInterval(timestamp) else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    private func saveInstallDateToKeychain(_ date: Date) {
        let timestamp = String(date.timeIntervalSince1970)
        guard let data = timestamp.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Key.keychainInstallDate,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: Key.keychainInstallDate
            ]
            status = SecItemUpdate(
                searchQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
        }
    }

    // MARK: - Integrity Hash (device-bound)

    /// Creates a SHA256 hash of the install date combined with the device's identifierForVendor.
    /// This makes it impractical to forge a Keychain entry with a manipulated date.
    private func installDateHash(for date: Date) -> String {
        let timestamp = String(date.timeIntervalSince1970)
        let vendorID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
        let payload = "\(timestamp):\(vendorID):com.lasohealth.trial"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func saveInstallDateHash(for date: Date) {
        let hash = installDateHash(for: date)
        guard let data = hash.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Key.keychainInstallHash,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: Key.keychainInstallHash
            ]
            status = SecItemUpdate(
                searchQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
        }
    }

    private func verifyInstallDateIntegrity(_ date: Date) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Key.keychainInstallHash,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let storedHash = String(data: data, encoding: .utf8) else {
            // No hash stored yet (pre-migration installs) -- treat as valid
            // and store the hash now for future verification
            saveInstallDateHash(for: date)
            return true
        }
        return storedHash == installDateHash(for: date)
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
        guard !deviceId.isEmpty else { return }

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
                .document(deviceId)
                .setData(data, merge: true)
        } catch {
            // Firestore write failed silently. local entitlement remains the source of truth.
        }
        #endif
    }

    /// Sync the current active entitlement (if any) to Firestore.
    /// Called after restore or transaction updates where we don't have the raw Transaction object.
    private func syncCurrentEntitlementToFirestore() async {
        guard !deviceId.isEmpty else { return }

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
                .document(deviceId)
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
        guard !deviceId.isEmpty else { return nil }

        #if canImport(FirebaseFirestore)
        do {
            let doc = try await Firestore.firestore()
                .collection(firestoreCollection)
                .document(deviceId)
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
