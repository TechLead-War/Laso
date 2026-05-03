import Foundation
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

/// Manages the referral system: code generation, redemption, reward tracking.
/// Referral state is cached locally and synced with Firestore.
@MainActor
@Observable
final class ReferralManager {

    static let shared = ReferralManager()

    // MARK: - State

    private(set) var referralCode: String?
    private(set) var referralFreeUntil: Date?
    private(set) var successfulReferrals: Int = 0
    private(set) var isRedeeming = false
    private(set) var redeemError: String?
    private(set) var redeemedCode: String?

    private let defaults = UserDefaults.standard

    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString
            ?? defaults.string(forKey: AppKeys.Profile.deviceId)
            ?? ""
    }

    /// Current Firebase Auth UID (anonymous). Empty string if not signed in.
    private var firebaseUid: String {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid ?? ""
        #else
        return ""
        #endif
    }

    private init() {
        // Load cached values for instant access check
        referralCode = defaults.string(forKey: AppKeys.Referral.code)
        redeemedCode = defaults.string(forKey: AppKeys.Referral.redeemedCode)
        if let ts = defaults.object(forKey: AppKeys.Referral.freeUntil) as? Double, ts > 0 {
            referralFreeUntil = Date(timeIntervalSince1970: ts)
        }
    }

    // MARK: - Code Generation

    /// Generate a unique referral code (format: HEALTH-XXXXXX).
    /// Uses chars that avoid 0/O/1/I ambiguity.
    nonisolated static func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let suffix = (0..<6).map { _ in chars.randomElement()! }
        return "HEALTH-\(String(suffix))"
    }

    // MARK: - System Status

    /// Whether the referral system is enabled (disabled during free year mode).
    var isEnabled: Bool {
        !RemoteConfigManager.shared.freeYearActive
    }

    /// Whether the user currently has free Pro access from referrals.
    var hasReferralAccess: Bool {
        guard let freeUntil = referralFreeUntil else { return false }
        return freeUntil > Date()
    }

    /// Days remaining on referral-based free Pro access.
    var referralDaysRemaining: Int? {
        guard let freeUntil = referralFreeUntil, freeUntil > Date() else { return nil }
        return Date.cal.dateComponents([.day], from: Date(), to: freeUntil).day
    }

    // MARK: - Sync with Firestore

    /// Sync referral state from Firestore. Call at app launch after auth.
    func syncWithFirestore() async {
        guard !deviceId.isEmpty else { return }

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()

        // Load profile referral fields
        do {
            let doc = try await db.collection("user_profiles").document(deviceId).getDocument()
            if let data = doc.data() {
                if let code = data["referralCode"] as? String {
                    referralCode = code
                    defaults.set(code, forKey: AppKeys.Referral.code)
                }
                if let ts = data["referralFreeUntil"] as? TimeInterval {
                    referralFreeUntil = Date(timeIntervalSince1970: ts)
                    defaults.set(ts, forKey: AppKeys.Referral.freeUntil)
                }
                if let redeemed = data["redeemedReferralCode"] as? String {
                    redeemedCode = redeemed
                    defaults.set(redeemed, forKey: AppKeys.Referral.redeemedCode)
                }
            }
        } catch {
            // Cached values will be used
        }

        // Count successful referrals
        do {
            let snapshot = try await db.collection("referrals")
                .whereField("referrerDeviceId", isEqualTo: deviceId)
                .whereField("status", isEqualTo: "completed")
                .getDocuments()
            successfulReferrals = snapshot.documents.count
        } catch {}
        #endif
    }

    // MARK: - Redeem a Referral Code

    /// Validate and redeem a referral code. Creates a pending referral in Firestore.
    func redeemCode(_ code: String) async -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            redeemError = "Please enter a referral code."
            return false
        }

        guard redeemedCode == nil else {
            redeemError = "You've already redeemed a referral code."
            return false
        }

        isRedeeming = true
        redeemError = nil
        defer { isRedeeming = false }

        #if canImport(FirebaseFirestore) && canImport(FirebaseFunctions)
        let db = Firestore.firestore()

        do {
            // Find referrer by code via Cloud Function. The `user_profiles`
            // collection is admin-only, so direct whereField queries are not
            // permitted for end users.
            let result = try await Functions.functions()
                .httpsCallable("lookupReferralCode")
                .call(["code": trimmed])

            guard let payload = result.data as? [String: Any],
                  let found = payload["found"] as? Bool, found,
                  let referrerOwnerUid = payload["ownerUid"] as? String,
                  !referrerOwnerUid.isEmpty else {
                redeemError = "Invalid referral code."
                AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "invalid_code")
                return false
            }

            // ownerUid is `firebaseUid || doc.id` from the server. The rest of
            // this flow expects the deviceId (which equals the user_profiles
            // document ID). When firebaseUid is set on the referrer's profile,
            // ownerUid returns firebaseUid — surfacing this as a data-model
            // follow-up rather than altering the smallest-change scope.
            let referrerDeviceId = referrerOwnerUid

            guard referrerDeviceId != deviceId else {
                redeemError = "You can't use your own referral code."
                AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "own_code")
                return false
            }

            // Ensure user hasn't already been referred
            let existing = try await db.collection("referrals")
                .whereField("referredDeviceId", isEqualTo: deviceId)
                .limit(to: 1)
                .getDocuments()

            guard existing.documents.isEmpty else {
                redeemError = "You've already been referred."
                AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "already_referred")
                return false
            }

            // Create pending referral
            try await db.collection("referrals").addDocument(data: [
                "referrerDeviceId": referrerDeviceId,
                "referredDeviceId": deviceId,
                "referralCode": trimmed,
                "status": "pending",
                "createdAt": Date().timeIntervalSince1970
            ])

            // Mark on own profile. Include firebaseUid + deviceId so that if
            // the profile doc does not yet exist, the create rule is satisfied.
            try await db.collection("user_profiles").document(deviceId).setData([
                "redeemedReferralCode": trimmed,
                "firebaseUid": firebaseUid,
                "deviceId": deviceId
            ], merge: true)

            redeemedCode = trimmed
            defaults.set(trimmed, forKey: AppKeys.Referral.redeemedCode)
            AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: true)
            return true
        } catch {
            redeemError = "Something went wrong. Try again."
            AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "firestore_error")
            return false
        }
        #else
        redeemError = "Referrals not available in this build."
        return false
        #endif
    }

    // MARK: - Complete Referral on Subscription

    /// Called when referred user subscribes. Completes the pending referral and grants both users 1 month free.
    func completeReferralIfPending() async {
        guard redeemedCode != nil else { return }

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()

        do {
            let snapshot = try await db.collection("referrals")
                .whereField("referredDeviceId", isEqualTo: deviceId)
                .whereField("status", isEqualTo: "pending")
                .limit(to: 1)
                .getDocuments()

            guard let referralDoc = snapshot.documents.first else { return }
            let referrerDeviceId = referralDoc.data()["referrerDeviceId"] as? String ?? ""

            // Mark completed
            try await referralDoc.reference.updateData([
                "status": "completed",
                "completedAt": Date().timeIntervalSince1970
            ])

            let oneMonth = Date.cal.date(byAdding: .month, value: 1, to: Date())!

            // Grant self (referred user) 1 month free. Include ownership fields
            // so merge-writes on a new doc still satisfy the create rule.
            try await db.collection("user_profiles").document(deviceId).setData([
                "referralFreeUntil": oneMonth.timeIntervalSince1970,
                "firebaseUid": firebaseUid,
                "deviceId": deviceId
            ], merge: true)
            referralFreeUntil = oneMonth
            defaults.set(oneMonth.timeIntervalSince1970, forKey: AppKeys.Referral.freeUntil)
            AppAnalytics.shared.trackReferralCompleted(role: "referee")

            // Grant referrer 1 month free (stacked on existing)
            let refDoc = try await db.collection("user_profiles").document(referrerDeviceId).getDocument()
            let baseDate: Date
            if let ts = refDoc.data()?["referralFreeUntil"] as? TimeInterval {
                let existing = Date(timeIntervalSince1970: ts)
                baseDate = existing > Date() ? existing : Date()
            } else {
                baseDate = Date()
            }
            let newFreeUntil = Date.cal.date(byAdding: .month, value: 1, to: baseDate)!
            try await db.collection("user_profiles").document(referrerDeviceId).setData([
                "referralFreeUntil": newFreeUntil.timeIntervalSince1970
            ], merge: true)

            // Note: successfulReferrals is NOT incremented here because this runs on the
            // referred user's device. The referrer's count is updated via syncWithFirestore(),
            // which queries Firestore for completed referrals where this device is the referrer.
        } catch {
            #if DEBUG
            print("[ReferralManager] Failed to complete referral: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    // MARK: - Share

    /// Pre-built share text for the referral code.
    var shareText: String {
        guard let code = referralCode else { return "" }
        return "Try Laso \u{2014} your health, understood. Use my referral code \(code) and we both get 1 month of Pro free!"
    }
}
