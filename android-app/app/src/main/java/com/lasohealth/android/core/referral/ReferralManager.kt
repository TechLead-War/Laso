package com.lasohealth.android.core.referral

import android.content.Context
import android.content.SharedPreferences
import com.lasohealth.android.core.data.OnboardingPrefs
import com.google.firebase.FirebaseApp
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await

/**
 * Manages referral code generation, redemption, and free-access tracking.
 *
 * Referral codes use format HEALTH-XXXXXX where X is uppercase alphanumeric
 * excluding ambiguous characters (0, O, 1, I).
 *
 * All redemption and reward grants require Firestore validation — no local-only
 * access is ever granted. The flow mirrors the iOS implementation:
 *   1. redeemCode() validates the code against Firestore and creates a pending referral
 *   2. completeReferralIfPending() is called on subscription and grants both parties 1 month free
 *   3. syncWithFirestore() refreshes local state from the server at app launch
 */
class ReferralManager private constructor(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val onboardingPrefs = OnboardingPrefs(context)

    private val deviceId: String
        get() = onboardingPrefs.deviceId

    private val isFirestoreAvailable: Boolean
        get() = FirebaseApp.getApps(appContext).isNotEmpty()

    private val appContext: Context = context.applicationContext

    // ── Public properties ────────────────────────────────────────────────

    /** The user's own referral code (generated lazily on first access). */
    val referralCode: String
        get() {
            val stored = prefs.getString(KEY_CODE, null)
            if (!stored.isNullOrEmpty()) return stored
            val generated = generateCode()
            prefs.edit().putString(KEY_CODE, generated).apply()
            return generated
        }

    /** The code the user redeemed (empty string if none). */
    var redeemedCode: String
        get() = prefs.getString(KEY_REDEEMED_CODE, "") ?: ""
        private set(value) = prefs.edit().putString(KEY_REDEEMED_CODE, value).apply()

    /** Epoch millis until which the user has free Pro access via referral. 0 if none. */
    var referralFreeUntil: Long
        get() = prefs.getLong(KEY_FREE_UNTIL, 0L)
        private set(value) = prefs.edit().putLong(KEY_FREE_UNTIL, value).apply()

    /** Whether the user currently has free access through a referral. */
    val hasReferralAccess: Boolean
        get() = referralFreeUntil > System.currentTimeMillis()

    /** Feature flag — always enabled for now. */
    val isEnabled: Boolean
        get() = true

    /** Pre-built share text for the referral code. */
    val shareText: String
        get() = "Try Laso — the health app that actually makes sense of your data. " +
            "Use my code $referralCode to get free Pro access! " +
            "https://lasohealth.com/r/$referralCode"

    // ── Public methods ───────────────────────────────────────────────────

    /**
     * Generate a new referral code in the format HEALTH-XXXXXX.
     * Characters are uppercase alphanumeric excluding 0, O, 1, I to avoid ambiguity.
     */
    fun generateCode(): String {
        val chars = ALLOWED_CHARS
        val suffix = (1..CODE_LENGTH).map { chars.random() }.joinToString("")
        return "$CODE_PREFIX$suffix"
    }

    /**
     * Sealed class representing the outcome of a referral code redemption attempt.
     */
    sealed class RedeemResult {
        data object Success : RedeemResult()
        data class Error(val message: String) : RedeemResult()
    }

    /**
     * Attempt to redeem a referral code.
     *
     * Validates the code against Firestore — no Pro access is granted locally
     * without server confirmation. Creates a pending referral document on success.
     * Pro access is only granted later via [completeReferralIfPending].
     *
     * @return [RedeemResult] indicating success or an error with a user-facing message.
     */
    suspend fun redeemCode(code: String): RedeemResult {
        val trimmed = code.trim().uppercase()

        // Basic format validation
        if (!trimmed.startsWith(CODE_PREFIX)) {
            return RedeemResult.Error("Invalid referral code format.")
        }
        if (trimmed.length != CODE_PREFIX.length + CODE_LENGTH) {
            return RedeemResult.Error("Invalid referral code format.")
        }
        if (trimmed == referralCode) {
            return RedeemResult.Error("You can't use your own referral code.")
        }
        if (redeemedCode.isNotEmpty()) {
            return RedeemResult.Error("You've already redeemed a referral code.")
        }

        // Require Firestore for server-side validation
        if (!isFirestoreAvailable) {
            return RedeemResult.Error("Unable to validate code. Please check your connection and try again.")
        }

        if (deviceId.isEmpty()) {
            return RedeemResult.Error("Unable to validate code. Please try again later.")
        }

        return try {
            val db = FirebaseFirestore.getInstance()

            // Find referrer by code in user_profiles
            val referrerSnapshot = db.collection("user_profiles")
                .whereEqualTo("referralCode", trimmed)
                .limit(1)
                .get()
                .await()

            if (referrerSnapshot.isEmpty) {
                return RedeemResult.Error("Invalid referral code.")
            }

            val referrerDoc = referrerSnapshot.documents.first()
            val referrerDeviceId = referrerDoc.id

            if (referrerDeviceId == deviceId) {
                return RedeemResult.Error("You can't use your own referral code.")
            }

            // Ensure user hasn't already been referred
            val existingReferral = db.collection("referrals")
                .whereEqualTo("referredDeviceId", deviceId)
                .limit(1)
                .get()
                .await()

            if (!existingReferral.isEmpty) {
                return RedeemResult.Error("You've already been referred.")
            }

            // Create pending referral document
            db.collection("referrals").add(
                hashMapOf(
                    "referrerDeviceId" to referrerDeviceId,
                    "referredDeviceId" to deviceId,
                    "referralCode" to trimmed,
                    "status" to "pending",
                    "createdAt" to System.currentTimeMillis().toDouble() / 1000.0,
                )
            ).await()

            // Mark on own profile
            db.collection("user_profiles").document(deviceId).set(
                hashMapOf("redeemedReferralCode" to trimmed),
                com.google.firebase.firestore.SetOptions.merge(),
            ).await()

            // Only store locally after Firestore confirms
            redeemedCode = trimmed
            // NOTE: referralFreeUntil is NOT set here — Pro access is granted
            // only when completeReferralIfPending() runs after subscription.

            RedeemResult.Success
        } catch (e: Exception) {
            RedeemResult.Error("Something went wrong. Please check your connection and try again.")
        }
    }

    /**
     * Complete a pending referral if one exists.
     * Called when the referred user subscribes. Grants both users 1 month of free Pro
     * via Firestore — local state is only updated after server confirmation.
     */
    suspend fun completeReferralIfPending() {
        if (redeemedCode.isEmpty()) return
        if (!isFirestoreAvailable) return
        if (deviceId.isEmpty()) return

        try {
            val db = FirebaseFirestore.getInstance()

            val snapshot = db.collection("referrals")
                .whereEqualTo("referredDeviceId", deviceId)
                .whereEqualTo("status", "pending")
                .limit(1)
                .get()
                .await()

            val referralDoc = snapshot.documents.firstOrNull() ?: return
            val referrerDeviceId = referralDoc.getString("referrerDeviceId") ?: return

            // Mark completed on server
            referralDoc.reference.update(
                mapOf(
                    "status" to "completed",
                    "completedAt" to System.currentTimeMillis().toDouble() / 1000.0,
                )
            ).await()

            val oneMonthMs = REFERRAL_DURATION_MS
            val oneMonthFromNow = System.currentTimeMillis() + oneMonthMs
            val oneMonthEpochSec = oneMonthFromNow.toDouble() / 1000.0

            // Grant self (referred user) 1 month free
            db.collection("user_profiles").document(deviceId).set(
                hashMapOf("referralFreeUntil" to oneMonthEpochSec),
                com.google.firebase.firestore.SetOptions.merge(),
            ).await()
            referralFreeUntil = oneMonthFromNow

            // Grant referrer 1 month free (stacked on existing)
            val refDoc = db.collection("user_profiles").document(referrerDeviceId).get().await()
            val baseTimeMs: Long = if (refDoc.exists()) {
                val existingEpochSec = refDoc.getDouble("referralFreeUntil")
                if (existingEpochSec != null) {
                    val existingMs = (existingEpochSec * 1000.0).toLong()
                    if (existingMs > System.currentTimeMillis()) existingMs else System.currentTimeMillis()
                } else {
                    System.currentTimeMillis()
                }
            } else {
                System.currentTimeMillis()
            }

            val newFreeUntilMs = baseTimeMs + oneMonthMs
            val newFreeUntilSec = newFreeUntilMs.toDouble() / 1000.0
            db.collection("user_profiles").document(referrerDeviceId).set(
                hashMapOf("referralFreeUntil" to newFreeUntilSec),
                com.google.firebase.firestore.SetOptions.merge(),
            ).await()
        } catch (_: Exception) {
            // Will retry on next app launch / subscription event
        }
    }

    /**
     * Sync referral state from Firestore. Call at app startup after Firebase init.
     * Updates local cache with server-side values (referral code, free-until, redeemed code).
     */
    suspend fun syncWithFirestore() {
        if (!isFirestoreAvailable) return
        if (deviceId.isEmpty()) return

        try {
            val db = FirebaseFirestore.getInstance()

            // Load profile referral fields
            val doc = db.collection("user_profiles").document(deviceId).get().await()
            if (doc.exists()) {
                doc.getString("referralCode")?.let { code ->
                    prefs.edit().putString(KEY_CODE, code).apply()
                }
                doc.getDouble("referralFreeUntil")?.let { epochSec ->
                    val epochMs = (epochSec * 1000.0).toLong()
                    referralFreeUntil = epochMs
                }
                doc.getString("redeemedReferralCode")?.let { code ->
                    redeemedCode = code
                }
            }
        } catch (_: Exception) {
            // Cached values will be used
        }
    }

    companion object {
        private const val PREFS_NAME = "laso_referral"
        private const val KEY_CODE = "laso.referral.code"
        private const val KEY_REDEEMED_CODE = "laso.referral.redeemed_code"
        private const val KEY_FREE_UNTIL = "laso.referral.free_until"

        private const val CODE_PREFIX = "HEALTH-"
        private const val CODE_LENGTH = 6
        private const val ALLOWED_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

        /** 30 days in milliseconds. */
        private const val REFERRAL_DURATION_MS = 30L * 24 * 60 * 60 * 1000

        @Volatile
        private var instance: ReferralManager? = null

        fun getInstance(context: Context): ReferralManager {
            return instance ?: synchronized(this) {
                instance ?: ReferralManager(context.applicationContext).also { instance = it }
            }
        }
    }
}
