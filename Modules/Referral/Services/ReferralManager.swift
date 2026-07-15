import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

/// Client for the referral program. Codes are minted and rewards granted ONLY
/// by Cloud Functions (`getOrAssignReferralCode` / `redeemReferralCode`) —
/// firestore.rules blocks clients from writing `referralFreeUntil`, so the
/// server is the single trust point. Everything keys on the Firebase Auth UID,
/// which survives reinstalls once linked to Apple Sign-In. Local cache gives
/// instant access checks at launch.
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
    private(set) var isLoadingCode = false

    private let defaults = UserDefaults.standard

    /// Sent to the server as a second fraud key (blocks reinstall farming,
    /// where a new anonymous UID would otherwise allow a second redemption).
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString
            ?? defaults.string(forKey: AppKeys.Profile.deviceId)
            ?? ""
    }

    private var uid: String { Auth.auth().currentUser?.uid ?? "" }

    private init() {
        // Load cached values for instant access check
        referralCode = defaults.string(forKey: AppKeys.Referral.code)
        redeemedCode = defaults.string(forKey: AppKeys.Referral.redeemedCode)
        if let ts = defaults.object(forKey: AppKeys.Referral.freeUntil) as? Double, ts > 0 {
            referralFreeUntil = Date(timeIntervalSince1970: ts)
        }
    }

    /// The cache belongs to one Auth UID. When the UID changes mid-session
    /// (account deletion mints a new anonymous user; an Apple sign-in can land
    /// on a different existing account), stale values would leak the old
    /// account's code and credit — clear everything before any use.
    private func reconcileCacheOwner() {
        let currentUid = uid
        guard !currentUid.isEmpty else { return }
        let cachedOwner = defaults.string(forKey: AppKeys.Referral.ownerUid)
        if cachedOwner != currentUid {
            if cachedOwner != nil {
                referralCode = nil
                referralFreeUntil = nil
                redeemedCode = nil
                successfulReferrals = 0
                defaults.removeObject(forKey: AppKeys.Referral.code)
                defaults.removeObject(forKey: AppKeys.Referral.freeUntil)
                defaults.removeObject(forKey: AppKeys.Referral.redeemedCode)
            }
            defaults.set(currentUid, forKey: AppKeys.Referral.ownerUid)
        }
    }

    // MARK: - System Status

    /// Master kill switch for the whole program (Settings row, onboarding code
    /// step, share caption). Flipped from the admin panel via Remote Config.
    var isEnabled: Bool {
        RemoteConfigManager.shared.referralProgramEnabled
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

    // MARK: - Own Code

    /// Returns the user's invite code, asking the server to mint one on first
    /// call. The server generates transactionally, so two devices on the same
    /// account always converge on one code.
    @discardableResult
    func ensureReferralCode() async -> String? {
        reconcileCacheOwner()
        if let referralCode { return referralCode }
        guard isEnabled, !uid.isEmpty, !isLoadingCode else { return referralCode }
        isLoadingCode = true
        defer { isLoadingCode = false }

        do {
            let result = try await Functions.functions()
                .httpsCallable("getOrAssignReferralCode")
                .call()
            guard let payload = result.data as? [String: Any],
                  let code = payload["code"] as? String, !code.isEmpty else {
                return nil
            }
            referralCode = code
            defaults.set(code, forKey: AppKeys.Referral.code)
            return code
        } catch {
            AnalyticsBackend.provider.captureError(error, context: "referral_assign_code")
            return nil
        }
    }

    // MARK: - Sync with Firestore

    /// Refresh referral state from Firestore. Called at launch once auth exists.
    func syncWithFirestore() async {
        guard !uid.isEmpty else { return }
        reconcileCacheOwner()
        let db = Firestore.firestore()

        do {
            let doc = try await db.collection("user_profiles").document(uid).getDocument()
            if let data = doc.data() {
                if let code = data["referralCode"] as? String, !code.isEmpty {
                    referralCode = code
                    defaults.set(code, forKey: AppKeys.Referral.code)
                }
                if let ts = data["referralFreeUntil"] as? TimeInterval, ts > 0 {
                    referralFreeUntil = Date(timeIntervalSince1970: ts)
                    defaults.set(ts, forKey: AppKeys.Referral.freeUntil)
                }
                if let redeemed = data["redeemedReferralCode"] as? String, !redeemed.isEmpty {
                    redeemedCode = redeemed
                    defaults.set(redeemed, forKey: AppKeys.Referral.redeemedCode)
                }
            }
        } catch {
            // Offline / cold start: cached values remain valid.
            AnalyticsBackend.provider.captureError(error, context: "referral_sync_profile")
        }

        do {
            // All referral docs are created `completed` by the server, so a
            // plain referrer query is the successful-referral count.
            let snapshot = try await db.collection("referrals")
                .whereField("referrerUid", isEqualTo: uid)
                .getDocuments()
            successfulReferrals = snapshot.documents.count
        } catch {
            AnalyticsBackend.provider.captureError(error, context: "referral_sync_count")
        }
    }

    // MARK: - Redeem a Referral Code

    /// Validate and redeem a friend's code. All fraud checks and the reward
    /// grant for BOTH sides happen server-side in `redeemReferralCode`.
    func redeemCode(_ code: String) async -> Bool {
        reconcileCacheOwner()
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else {
            redeemError = Copy.Referral.errorEmptyCode
            return false
        }

        guard redeemedCode == nil else {
            redeemError = Copy.Referral.errorAlreadyRedeemed
            return false
        }

        isRedeeming = true
        redeemError = nil
        defer { isRedeeming = false }

        do {
            let result = try await Functions.functions()
                .httpsCallable("redeemReferralCode")
                .call(["code": trimmed, "deviceId": deviceId])

            guard let payload = result.data as? [String: Any],
                  let status = payload["status"] as? String else {
                redeemError = Copy.Referral.errorGeneric
                AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "bad_response")
                return false
            }

            switch status {
            case "ok":
                redeemedCode = trimmed
                defaults.set(trimmed, forKey: AppKeys.Referral.redeemedCode)
                if let ts = payload["freeUntil"] as? TimeInterval, ts > 0 {
                    referralFreeUntil = Date(timeIntervalSince1970: ts)
                    defaults.set(ts, forKey: AppKeys.Referral.freeUntil)
                }
                AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: true)
                AppAnalytics.shared.trackReferralCompleted(role: "referee")
                return true
            case "own_code":
                redeemError = Copy.Referral.errorOwnCode
                AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "own_code")
                return false
            case "already_referred":
                redeemError = Copy.Referral.errorAlreadyReferred
                AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "already_referred")
                return false
            default:
                redeemError = Copy.Referral.errorInvalidCode
                AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "invalid_code")
                return false
            }
        } catch {
            redeemError = Copy.Referral.errorGeneric
            AppAnalytics.shared.trackReferralCodeRedeemed(code: trimmed, success: false, failureReason: "network_error")
            return false
        }
    }
}
