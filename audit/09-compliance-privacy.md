# 09 — Compliance, Privacy, and App Review Pre-Launch Audit

Scope: pre-launch compliance review of the Laso iOS app (`com.lasohealth.fit`, iOS 17+, on TestFlight) against:
- Apple App Review Guidelines (focus on hard blockers).
- GDPR (EU launch).
- India DPDP Act 2023 (India launch).
- Brazil LGPD (if/when launched in BR).
- CCPA (California users).
- PIPEDA (Canada users).

This audit was done READ-ONLY against the repo at `/Users/primetrace/Desktop/RnD/HealthPulse` on 2026-04-25. Every finding cites a file and line. No runtime test. Nothing was changed.

---

## TL;DR — Apple App Review hard-block table

| # | Guideline | Required | Present today | Verdict |
|---|-----------|----------|---------------|---------|
| 1 | 5.1.1(v) — In-app account / data deletion, free, no ticket | Server-side records (Firestore `user_profiles`, `subscriptions`, `referrals`, `feedback`) must be deletable in-app | Settings has only "Delete All My Data" which clears LOCAL state and exits — never calls Firestore deletion. Auth user (`Auth.auth().currentUser`) is also never deleted | **REJECTION risk** |
| 2 | 5.1.1(i) — Privacy Policy + ToS reachable BEFORE account/profile creation | Must be linkable on the first profile-capture screen | `ProfileCaptureView.swift` collects age + gender → writes Firestore profile doc with NO Privacy Policy or Terms link in the onboarding flow | **REJECTION risk** |
| 3 | App Privacy Manifest (`PrivacyInfo.xcprivacy`) | Declare every collected data type | Declares only `NSPrivacyCollectedDataTypeHealthData`. Missing: `OtherUserContent` (journal notes), `SensitiveInfo` (cycle), `UserID` (Firebase UID + deviceId), `DeviceID` (PostHog distinct_id, IDFV via FirebaseAnalytics), `CrashData` (PostHog crash handler), `PerformanceData`, `OtherDiagnosticData`, `EmailAddress` (feedback `contact_email`), `OtherDataTypes` (referral codes, subscription status) | **REJECTION risk** |
| 4 | `NSPrivacyTracking` truthful | If false, no tracking SDK may persist linked identifiers across apps | `NSPrivacyTracking=false` (`PrivacyInfo.xcprivacy:6`), but `FirebaseAnalytics` is linked (`project.yml:28`) with no `setAnalyticsCollectionEnabled(false)` and no `FIREBASE_ANALYTICS_COLLECTION_ENABLED=NO` in Info.plist. Auto-collects IDFV / app_instance_id by default | **REJECTION + enforcement risk** |
| 5 | `NSHealthUpdateUsageDescription` truthful | String must reflect actual writes | String says "future features like logging workouts and health entries" but `HealthKitManager.swift:1150–1188` already writes `bodyMass`, `dietaryWater`, `mindfulSession`. IntentDataProvider also saves a HKQuantitySample (`Core/Intents/IntentDataProvider.swift:158–165`) | **Likely metadata reject** |
| 6 | 1.4.1 / 5.1.1(ix) — No diagnostic / medical claims | Pattern language only | Risk module strings are pattern/trend language ("Heart Health Pattern", "Stress & Recovery", "informational only" disclaimer). Brain Health calls itself "Cognitive Wellness" (not "dementia screening"). Disclaimer present in Settings, Onboarding, RiskDetail | **PASS (with caveat)** |
| 7 | 3.1.2 — Subscription disclosures | Price, period, free trial terms, auto-renewal, cancel-via-Settings, ToS+PP links on paywall | All present (`PaywallView.swift:295–375`). Apple's standard auto-renew disclaimer included verbatim | **PASS** |
| 8 | ATT (App Tracking Transparency) | Required if any SDK tracks across apps | App does not call `requestTrackingAuthorization`. With FirebaseAnalytics auto-collecting IDFV without ATT, technically OK only if `NSPrivacyTracking=false` is true — finding (4) above breaks this | **Risk depends on (4)** |
| 9 | Account-creation requirement (5.1.1) | Apps that create accounts must offer account creation in-app | App auto-creates an anonymous Firebase Auth UID at first launch (`AppLaunchCoordinator.swift:27–33`) without asking the user, AND writes a server-side `user_profiles/{deviceId}` document in onboarding (`UserProfileStore.swift:186–198`). Apple now treats this as account creation for which 5.1.1(v) deletion applies | **REJECTION risk (links into #1)** |

**Verdict: Three to four hard blockers. Cannot ship to App Store as-is.**

---

## Multi-jurisdiction compliance table

Legend: ✓ present, ✗ missing, ⚠ partial, n/a not applicable.

| Control | GDPR (EU) | DPDP (India) | LGPD (Brazil) | CCPA (CA) | PIPEDA (CA) |
|---------|-----------|---------------|---------------|-----------|--------------|
| Privacy Policy URL public + in-app | ✓ Settings + Paywall | ✓ | ✓ | ✓ | ✓ |
| Privacy Policy presented BEFORE data collection in onboarding | ✗ | ✗ | ✗ | ✗ | ✗ |
| Explicit consent capture (record + version + timestamp) | ✗ | ✗ | ✗ | n/a | ✗ |
| Article 9 explicit consent for health/special-category data | ✗ | ✗ (similar Sec 9) | ✗ | n/a | ✗ |
| Right to access / data export | ⚠ "Generate Web Report" exists for paid tier only — gates a fundamental right behind a paywall | ⚠ | ⚠ | ⚠ | ⚠ |
| Right to portability (machine-readable) | ✗ Web Report is HTML, not JSON/CSV | ✗ | ✗ | n/a | n/a |
| Right to erasure / data deletion incl. server-side | ✗ Settings deletes local only; Firestore docs persist | ✗ | ✗ | ⚠ | ✗ |
| Withdraw consent as easily as given | ✗ No consent toggle. Only nuclear "Delete All My Data" | ✗ | ✗ | n/a | ✗ |
| Children — age gate appropriate to jurisdiction | ⚠ Min age 13 (US COPPA floor); EU GDPR-K is 16 (most states), DPDP is 18 with parental consent | ✗ DPDP requires parental consent for under-18 | ⚠ LGPD is 18 with parental | ⚠ COPPA 13 OK | ⚠ |
| Data retention policy (server-side) | ✗ Local SwiftData has retention; Firestore docs grow forever | ✗ | ✗ | n/a | ⚠ |
| Records of Processing Activity (RoPA) doc | ✗ none in `Docs/` | n/a | ✗ | n/a | ✗ |
| Sub-processor list disclosed | unverified (depends on PP page content; not in repo) | unverified | unverified | unverified | unverified |
| Encryption at rest (local) | ✓ FileProtection.completeUntilFirstUserAuthentication + EncryptedStore AES-GCM | ✓ | ✓ | n/a | ✓ |
| Encryption in transit | ✓ Firebase + PostHog HTTPS only by default; ATS not relaxed | ✓ | ✓ | n/a | ✓ |
| "Do Not Sell or Share" link | n/a | n/a | n/a | ⚠ defensible since no sale, but link recommended in PP | n/a |
| Localized privacy policy | unverified | unverified | ✗ Brazil requires PT-BR | n/a | ⚠ FR for QC |
| Marketing email opt-in | n/a app does not send | n/a | n/a | n/a | n/a |
| Push notification scope clear | ⚠ Settings has bucket toggles but no upfront purpose copy split (motivational vs medical reminder) | ⚠ | ⚠ | n/a | ⚠ |

---

## Data type: declared vs actually collected

The single source of truth Apple checks on submission. Each unmatched row is an App Store reject.

| Data Type (Apple taxonomy) | Declared in `PrivacyInfo.xcprivacy`? | Actually collected? | Evidence |
|----------------------------|--------------------------------------|---------------------|---------|
| Health & Fitness — Health | ✓ Linked=false, Tracking=false, Purpose=AppFunctionality | ✓ | HealthKit reads in `HealthKitManager.swift:119–149`, Firestore `subscriptions` does NOT contain HK data (good) |
| Health & Fitness — Fitness | ✗ | ✓ workouts, exercise minutes, steps | `HealthKitManager.swift:128–133` |
| Sensitive Info — health/cycle | ✗ | ✓ menstrualFlow read from HK | `HealthKitManager.swift:146`, `454`, `567` |
| User Content — Other (journal notes free text) | ✗ | ✓ stored on-device | `JournalStore.swift:101–119`, entry view `JournalEntryView.swift:237` |
| User Content — Audio (Siri intents) | ✗ | ⚠ Siri requests via `NSSiriUsageDescription` but no audio is stored. Not collected → OK |  |
| Identifiers — User ID | ✗ | ✓ Firebase Auth UID, deviceId (`identifierForVendor`) | `AppLaunchCoordinator.swift:27`, `UserProfileStore.swift:81–83`, `ReferralManager.swift:32` |
| Identifiers — Device ID | ✗ | ✓ IDFV via FirebaseAnalytics auto-collect, PostHog `distinct_id`, app_instance_id | `project.yml:28` (FirebaseAnalytics linked, never disabled), `PostHogManager.swift:21–43` |
| Contact Info — Email | ✗ | ✓ optional, in feedback `contact_email` field, written to Firestore | `FeedbackPromptManager.swift:135–140` |
| Contact Info — Name | ✗ | ⚠ schema exists in `UserProfile` but onboarding passes `name: ""` (`OnboardingView.swift:166`). NOT actually collected today, but the field is on the data model and EncryptedStore key exists (`UserProfileStore.swift:106–112`) — risk of silent enable. |  |
| Contact Info — Date of Birth | ✗ | ⚠ collected as `age` (Int) in onboarding, converted to `dateOfBirth` and saved to encrypted local store; only `ageBracket` written to Firestore. Local DOB is sensitive → declarable | `OnboardingView.swift:158–163`, `UserProfileStore.swift:114–118` |
| Demographics — Gender | ✗ | ✓ written to Firestore | `UserProfileStore.swift:175` |
| Other User Content — Demographic / health focuses | ✗ | ✓ | `UserProfileStore.swift:177` |
| Diagnostics — Crash Data | ✗ | ✓ PostHog uncaught exception + signal handler captures stack traces | `PostHogManager.swift:126–166` |
| Diagnostics — Performance Data | ✗ | ✓ `trackSyncPerformance`, `trackMLAnalysisPerformance` | `AppAnalytics.swift:1755`, `1765` |
| Diagnostics — Other Diagnostic Data | ✗ | ✓ device model (`UIDevice.current.model`), iOS version, locale, bundle id, app version sent with every feedback | `FeedbackPromptManager.swift:128–133` |
| Usage Data — Product Interaction | ✗ | ✓ extensive screen tracking, feature open/close, block taps, paywall events, etc. | `AppAnalytics.swift` (all of it) |
| Purchases — Purchase History | ✗ | ✓ `subscriptions/{deviceId}` documents in Firestore with productId, originalTransactionId, purchaseDate, expirationDate | `SubscriptionManager.swift:467–486` |
| Identifiers — referralCode (linked to deviceId) | ✗ | ✓ Firestore `referrals` collection | `ReferralManager.swift:181–195` |
| Audio Data — voice recording | n/a | n/a | Siri integration is intent-only, no audio stored |
| Location | n/a | n/a | No location permission requested (good) |

**Net:** the manifest declares 1 of ≥ 12 collected data types. Every undeclared row is an audit-trail violation under Apple Privacy Nutrition Label policy and a Privacy Manifest non-compliance starting iOS 17+.

---

## Findings

### F1. No in-app account / server-side data deletion. Apple 5.1.1(v) hard block. GDPR Art. 17 violation. DPDP Sec 12 violation.

- **Severity:** Critical (launch blocker)
- **Issue:** "Delete All My Data" in Settings only deletes the **device-local** state (Keychain + SwiftData + UserDefaults). It does NOT delete the Firestore documents the app has been writing for this user, and it does NOT delete the anonymous Firebase Auth user. After tapping it, server-side records remain forever.
- **What persists server-side after "deletion":**
  - `user_profiles/{deviceId}` with gender, ageBracket, healthFocuses, deviceId, region, appVersion, firebaseUid, referralCode, redeemedReferralCode, referralFreeUntil — `UserProfileStore.swift:186–198`.
  - `subscriptions/{deviceId}` with productId, originalTransactionId, purchaseDate, expirationDate, environment, lastVerified, deviceId — `SubscriptionManager.swift:477–486`.
  - `referrals/*` documents with referrerDeviceId + referredDeviceId for any referral involving this user — `ReferralManager.swift:181–187`.
  - `feedback/*` documents with category, free-text feedback, optional `contact_email`, deviceId-equivalent metadata — `FeedbackPromptManager.swift:139–142`.
  - The anonymous `FirebaseAuth` user (`Auth.auth().currentUser`) is never `.delete()`'d.
- **Why this is fatal:**
  - Apple 5.1.1(v) requires deletion of "the user's account and any associated personal data" in-app, "without requiring contacting Customer Service". Apple's reviewer test: tap delete → all backend records gone. Today they would still see the Firestore doc the next launch on the same device.
  - GDPR Art. 17 (right to erasure): you have no mechanism to comply.
  - India DPDP Sec. 12 (right to erasure of personal data) and Sec. 8 (data fiduciary obligations) — same.
  - Although Firebase Anonymous Auth is "anonymous", Apple has tightened its review: any server-side user-bound document = account.
- **Fix:**
  1. Add a "Delete account and all my data" button in Settings (separate from "Delete on-device data only").
  2. On tap: call a Cloud Function `deleteAccountAndAllData(deviceId, firebaseUid)` that, server-side, deletes:
     - `user_profiles/{deviceId}`
     - `subscriptions/{deviceId}`
     - all `referrals/*` where referrerDeviceId == deviceId or referredDeviceId == deviceId
     - all `feedback/*` from this deviceId / firebaseUid
  3. Then on-device: call `Auth.auth().currentUser?.delete()`, clear local stores (existing `performDataDeletion()` flow), exit app.
  4. Update copy: rename "Delete All My Data" → "Delete Account and All Data". Today's wording ("from this device") implies local-only, so the user does not even know server data exists.
- **Confidence:** 96/100 — verified end-to-end in source. The 4 missing points: (a) no Cloud Function source visible, but absence of any client `.delete()` of these collections rules out client-side server deletion; (b) PP page text not inspected (could promise deletion in spirit but the app does not do it); (c) Firestore security rules not in repo, so theoretically a rule could allow client deletion but no client code attempts it; (d) admin-panel folder not opened, but it would not be the user-facing path Apple checks.

### F2. PrivacyInfo.xcprivacy declares 1 of ≥ 12 collected data types. iOS 17+ Privacy Manifest violation.

- **Severity:** Critical (launch blocker for iOS 17+ App Store submission since May 2024)
- **Issue:** `PrivacyInfo.xcprivacy:9–23` declares only `NSPrivacyCollectedDataTypeHealthData`. The app collects at least 11 more declarable categories (see "Data type" table above).
- **Why this is fatal:** Since 1 May 2024, Apple validates the privacy manifest at upload time. A missing data type = automatic build rejection during processing OR manual rejection on App Privacy review. Even if it slips through, the App Store Connect Privacy Questionnaire (legal binding statement) will conflict with the manifest, exposing the team to App Store enforcement actions and FTC misrepresentation claims.
- **Fix:** Add entries for at least:
  - `NSPrivacyCollectedDataTypeOtherUserContent` (journal free-text notes) — Linked=true, Tracking=false, Purpose=AppFunctionality.
  - `NSPrivacyCollectedDataTypeUserID` (Firebase UID + deviceId) — Linked=true, Tracking=false, Purpose=AppFunctionality + Analytics.
  - `NSPrivacyCollectedDataTypeDeviceID` (IDFV via Firebase, distinct_id via PostHog) — Linked=false, Tracking=false (only true if (4) below is fixed), Purpose=Analytics.
  - `NSPrivacyCollectedDataTypeEmailAddress` (feedback `contact_email`) — Linked=true, Tracking=false, Purpose=AppFunctionality + CustomerSupport.
  - `NSPrivacyCollectedDataTypeOtherDiagnosticData` (device model, iOS version, locale, app version) — Linked=true, Tracking=false, Purpose=Analytics.
  - `NSPrivacyCollectedDataTypeCrashData` (PostHog crash handler) — Linked=true, Tracking=false, Purpose=AppFunctionality.
  - `NSPrivacyCollectedDataTypePerformanceData` — Linked=true, Tracking=false, Purpose=Analytics.
  - `NSPrivacyCollectedDataTypeProductInteraction` (every event in `AppAnalytics.swift`) — Linked=true, Tracking=false, Purpose=Analytics + ProductPersonalization.
  - `NSPrivacyCollectedDataTypePurchaseHistory` (StoreKit transactions in Firestore) — Linked=true, Tracking=false, Purpose=AppFunctionality.
  - `NSPrivacyCollectedDataTypeSensitiveInfo` (cycle/menstrual data when read into the app from HK) — Linked=true, Tracking=false, Purpose=AppFunctionality.
  - `NSPrivacyCollectedDataTypeOtherUserContent` for healthFocuses / gender / ageBracket if not preferring the Demographics bucket.
- **Confidence:** 95/100 — manifest text and source code both directly verified; only uncertainty is the precise Apple bucket for each (e.g. Demographics vs OtherUserContent for healthFocuses), which Apple itself sometimes leaves ambiguous.

### F3. `NSPrivacyTracking=false` is contradicted by FirebaseAnalytics being linked without explicit disable. Apple submission risk + FTC.

- **Severity:** Critical (correctness + regulatory)
- **Issue:** `PrivacyInfo.xcprivacy:5–6` says `NSPrivacyTracking=false`. `project.yml:28` declares `FirebaseAnalytics` as a product dependency. There is no `setAnalyticsCollectionEnabled(false)` call, no `FIREBASE_ANALYTICS_COLLECTION_ENABLED=NO` in `Info.plist`, no `FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED=YES`. By default, FirebaseAnalytics auto-collects IDFV, app_instance_id, screen views, in-app purchase events, app launches, session duration → those are persistent identifiers linked across the SDK's data graph (and Google AdServices, since the SDK is integrated with the same Google Marketing Platform).
- **Apple's definition of tracking:** "linking data collected from your app about a particular end user or device, with third-party data collected from other apps or websites for targeted advertising or advertising measurement purposes, **OR sharing data collected from your app about a particular end-user or device with data brokers**." FirebaseAnalytics by default sends to Google, which is treated as a data broker / ad measurement partner. Therefore `NSPrivacyTracking=false` is materially false unless Analytics is explicitly disabled.
- **Evidence of no disable:**
  - `grep -rinE "setAnalyticsCollectionEnabled|FIREBASE_ANALYTICS_COLLECTION_ENABLED|FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift" --include="*.plist" --include="*.yml"` → only `project.yml:28` matches (the dependency declaration), no flags.
  - No `import FirebaseAnalytics` anywhere in `Core/`, `App/`, `Modules/` → analytics is linked but never used in code, which is the worst combination: it auto-collects but nobody is responsible for tuning it.
- **Fix (pick one):**
  1. **Recommended.** Remove `FirebaseAnalytics` from `project.yml:28` — the app does not call into it. This eliminates the question entirely.
  2. Or set in `Info.plist`: `FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED = YES` to fully disable at startup, document it in the PP, keep the manifest claim defensible.
  3. Do not pick "leave it on and ATT-prompt the user" — would force a tracking permission popup the product doesn't need.
- **Confidence:** 94/100 — link, build artifacts, and absence of any disable flag all verified by grep. 6 points withheld because (a) Firebase auto-collection behavior on iOS without IDFA can vary by SDK version, and (b) there could be a linker dead-strip eliminating the analytics binary if no symbol is referenced — that is unverified at runtime, and even so it is brittle against any future symbol reference.

### F4. `NSHealthUpdateUsageDescription` describes "future features" but app already writes HealthKit samples today.

- **Severity:** Medium (likely metadata reject from Apple's sample-record review)
- **Issue:** The string says: "Laso requests write access to Apple Health to allow future features like logging workouts and health entries directly from the app." But the app already writes:
  - body mass — `HealthKitManager.swift:1150–1160`.
  - dietary water — `HealthKitManager.swift:1163–1174`.
  - mindful sessions — `HealthKitManager.swift:1177–1188`.
  - And via Siri intent: a `HKQuantitySample` write — `Core/Intents/IntentDataProvider.swift:158–165`.
- **Why Apple cares:** App Review reads usage strings literally and will reject if the user-facing reason understates actual access. They also flag "future features" as vague.
- **Fix:** Replace with concrete, present-tense reasons: e.g. "Laso writes water intake, weight, and mindful minutes to Apple Health when you log them, so all your health data stays in one place."
- **Confidence:** 96/100 — write paths verified.

### F5. Privacy Policy and Terms of Use are not surfaced in the onboarding flow before profile data is written to Firestore.

- **Severity:** High (Apple 5.1.1(i) + GDPR Art. 7/13 + DPDP Sec. 6)
- **Issue:** `OnboardingView.swift:172` calls `UserProfileStore.shared.save(profile)` which writes to Firestore. Before that point in the flow, the user has been through:
  - Pulse (Screen 1) → no PP / ToS link.
  - ProfileCapture (Screen 2) → collects age + gender → no PP / ToS link, no checkbox for "I accept".
  - ConnectHealth (Screen 3) → only HK system prompt, no PP link.
  - Priority (Screen 4) → focus selection, no PP link.
  - Mirror (Screen 5) → no PP link.
  - Promise (Screen 6) → has a "Full disclaimer" button (medical), no PP / ToS link, no consent toggle.
- **Why this fails:**
  - Apple 5.1.1(i): "Apps that collect or transmit user data must publish a privacy policy and link to it before the data is collected." Today the link is reachable only after onboarding completes (Settings → About → Privacy Policy).
  - GDPR Art. 7(1): controller must be able to demonstrate consent. The user never affirmatively accepts anything.
  - GDPR Art. 13: information must be provided at the time data is collected, not after.
  - DPDP Sec. 6(1): notice + consent must be obtained before processing.
- **Evidence:**
  - `grep -rinE "privacyPolicy|termsOfUse" /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Onboarding --include="*.swift"` returns 0 results.
  - PP/ToS links exist only at `SettingsView.swift:387–409` and `PaywallView.swift:367–375`.
- **Fix:**
  - On the ProfileCaptureView (Screen 2) footer: "By tapping Continue, you accept our [Terms] and [Privacy Policy]." Make them tappable Links to `AppSecrets.URLs.privacyPolicy` / `termsOfUse`. Block the Continue button until the user has at least had a chance to read them (links visible).
  - Persist a consent record in Firestore: `consents/{deviceId}` with `{ acceptedAt: TS, ppVersion: "v1.0", tosVersion: "v1.0", appVersion, locale, region }` — needed for GDPR Art. 7(1) demonstrability.
- **Confidence:** 95/100.

### F6. No mechanism for the user to "withdraw consent" without nuking their entire data.

- **Severity:** High (GDPR Art. 7(3))
- **Issue:** GDPR requires withdrawal to be as easy as giving consent. Today the only way to "withdraw" is the destructive "Delete All My Data" button (which itself is incomplete — see F1). A user who simply wants to stop analytics collection has no toggle.
- **Fix:** Settings → Privacy section with toggles:
  - "Share anonymous usage data (helps us improve Laso)" — gates PostHog `capture()` calls.
  - "Allow performance/crash reporting" — gates the crash handler in `PostHogManager.swift:126–166`.
  - "Allow cloud backup of computed scores" — already implicitly off by default (`CloudBackupManager.swift:60`).
  - The current flow already uses CloudBackup as opt-in (good). Replicate that pattern for analytics.
- **Confidence:** 92/100 — GDPR text + lack of toggles in Settings verified.

### F7. Right of access / data portability is partially gated behind the paywall and the format is not machine-readable.

- **Severity:** Medium-High (GDPR Art. 15, 20; DPDP Sec. 11; LGPD Art. 18)
- **Issue:** `SettingsView.swift:282–323` gates "Generate Web Report" behind `FeatureGate.canAccess(.exportReport)`. Free users see only `proBadge`. Even paid users get an HTML web report (not JSON/CSV).
- **Why this matters:** GDPR Art. 12(5) requires the right of access and portability to be provided "free of charge". You cannot paywall it. Art. 20 (portability) requires "structured, commonly used and machine-readable format" — HTML does not qualify.
- **Fix:** A free "Export My Data" button in Settings that produces a single ZIP containing:
  - `profile.json` (gender, ageBracket, healthFocuses, region, deviceId, firebaseUid, createdAt, updatedAt)
  - `journal_entries.json` (date, category, value, notes)
  - `daily_samples.json` (date, metric, value)
  - `analysis_snapshots.json`
  - `subscriptions.json`
  - `consent_log.json` (once F5 is built)
  - `README.txt` describing each file.
- **Confidence:** 91/100 — feature gate verified at the line cited.

### F8. Cycle / menstrual data has no separate explicit opt-in screen. GDPR Art. 9 special category data violation risk.

- **Severity:** High (EU launch)
- **Issue:** Cycle data is read from HealthKit if the user grants HK permissions in onboarding (`HealthKitManager.swift:146`). The HK system prompt covers HK access but not "your cycle data may be processed by Laso for cycle phase analysis". Article 9 of GDPR requires explicit, granular consent for special-category data (health, including reproductive health). The single HK system prompt does not satisfy Art. 9 because it is Apple's prompt for the OS, not Laso's processing.
- **Fix:** Before showing cycle phase UI for the first time (`Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift`), present a one-time sheet: "We use cycle data from Apple Health only on this device to give you phase-specific recovery insights. No cycle data is sent to our servers. Allow?" — with Allow / Don't allow buttons. Persist the choice. Skip the entire `CycleTracking` module if declined.
- **Note:** This is a closer-than-it-looks call because Laso does NOT actually transmit cycle data to its servers (only HealthFocuses/gender go to Firestore, never raw flow data). But the law is concerned with **processing**, which includes on-device analysis. Explicit opt-in is the safe path.
- **Confidence:** 88/100 — confirmed that `UserProfileStore.save` does not include flow data in the Firestore payload (`UserProfileStore.swift:174–184`); confirmed cycle data is read from HK locally; what's not verified is whether the team's PP page already covers this with an explicit clause (out-of-repo).

### F9. Age gate too low for EU + India + Brazil simultaneously. Children's data risk.

- **Severity:** High (DPDP Sec. 9, GDPR-K, LGPD Art. 14)
- **Issue:** `ProfileCaptureView.swift:16` accepts age 13–120. Without parental consent, this is non-compliant for:
  - **GDPR-K**: 16 in most EU member states (NL, DE, FR, IT, ES, IE among others); 13–16 floor varies. Ireland, where Apple's EU entity is based, sets it at 16.
  - **DPDP**: Sec. 9 — anyone under 18 in India requires verifiable parental consent. There is no parental consent mechanism in code.
  - **LGPD**: Art. 14 — under 18 requires guardian consent.
- **Fix options:**
  - Easiest: raise minimum age to 18 globally. Lose the 13–17 cohort (small).
  - Better: keep min at 13 but on age 13–17, branch to a "Get a parent's permission" flow with email-confirmation pattern. Heavy lift.
  - Phased: launch with min age 18 in IN, EU, BR; min age 13 in US/CA only. Implement region-aware gate using `Locale.current.region`.
- **Confidence:** 92/100 — code-side age range verified; jurisdictional thresholds well-established.

### F10. Paywall claim "Your health data stays on your phone" is materially misleading.

- **Severity:** High (FTC misrepresentation, GDPR Art. 13 transparency, App Review marketing-claim scrutiny)
- **Issue:** `PaywallView.swift:126` shows feature row `Copy.Paywall.featurePrivacy` = "Your health data stays on your phone" (`Copy+Paywall.swift:17`). But the app:
  - Writes `gender`, `ageBracket`, `healthFocuses` to Firestore (`UserProfileStore.swift:174–184`) — those are health-adjacent.
  - Sends ~hundred event types via PostHog including HRV bands, sleep duration buckets, score values, journal-entry-created with `has_notes` flag, etc. (entire `AppAnalytics.swift`). These ARE health data even when bucketed.
  - Writes computed analysis snapshots, ML state, subscription history to CloudKit (when CloudBackup is enabled — `CloudBackupManager.swift`, `BackupPayload.swift`). Encrypted, but still off-device.
  - Backs up encryption keys to iCloud Keychain (`EncryptedStore.swift:81`) — `synchronizable: true`. Good for UX but does mean the key (not data) leaves the device.
- **Why this matters:** The claim is FTC-actionable ("deceptive trade practice"). It can also be challenged by users in EU under GDPR Art. 13/14 transparency. Apple has rejected apps for similar paywall claims that contradict their actual data flow.
- **Fix:** Change the paywall row copy to truthful language, e.g. "Your raw Apple Health readings stay on your phone. Anonymous app usage helps us improve Laso." Or simply "Built privacy-first" with a link to the PP.
- **Confidence:** 94/100 — Firestore writes, PostHog events, CloudKit backup paths all verified by file:line. Whether the Privacy Policy page reconciles this language with the paywall is unverified.

### F11. PostHog session replay is on by default. Risk of journal text leak.

- **Severity:** Medium-High
- **Issue:** `PostHogManager.swift:29` enables session replay. Lines 34–36 set `maskAllTextInputs = true`, `maskAllImages = true`, `maskAllSandboxedViews = true`. That covers most surfaces, but:
  - `maskAllTextInputs` masks UIKit `UITextField` / `UITextView`. SwiftUI's `TextField(...)` ultimately bridges to `UITextField`, so the *input* is masked. However, the journal entry view also writes `notes` back into the SwiftUI view tree as visible text (`JournalEntryView.swift:237` shows the bound state, then on save, the journal sheet may render the saved text in lists). The render-side `Text(...)` views in journal lists have NOT been audited for `.postHogMask()`.
  - The `.postHogMask()` modifier IS applied liberally on dashboard cards (29 hits in the grep) but appears 0 times in `Modules/Journal/`.
- **Risk:** A user types a sensitive journal note ("doctor said I have diabetes"). The text input is masked at type-time; once saved and re-rendered as a SwiftUI `Text(entry.notes ?? "")`, it is captured in the next session replay snapshot.
- **Fix:** Add `.postHogMask()` to every `Text` view in `Modules/Journal/` that renders user-entered free text. Better: add a project-wide lint rule.
- **Confidence:** 82/100 — confirmed 0 mask usages in `Modules/Journal/`; have not opened every Journal subview to confirm whether notes are rendered back. The 18-point gap is the unread render path.

### F12. FeedbackPromptManager sends `device_model`, `ios_version`, `bundle_id`, plus optional `contact_email` to Firestore in plaintext.

- **Severity:** Medium
- **Issue:** `FeedbackPromptManager.swift:122–142` writes a full `feedback/*` Firestore document. Combined with `deviceId`-equivalent metadata (the `bundle_id` field is constant; the `locale` + `device_model` + `app_version` plus `timestamp` are a low-entropy fingerprint that may, at scale, be re-identifiable). The `contact_email` (when present) is plaintext PII.
- **Risk:** GDPR Art. 32 (security of processing) — minimum is pseudonymization; emails should at least live in a separate access-controlled collection / be hashed where possible. App Privacy Manifest lacks the `EmailAddress` declaration (see F2).
- **Fix:** (a) split feedback collection into `feedback/{id}` (free-text + anonymous metadata) + `feedback_contacts/{id}` (email only, restricted IAM); (b) declare `EmailAddress` in privacy manifest; (c) document the email field in PP.
- **Confidence:** 90/100.

### F13. No data retention policy on server-side Firestore documents.

- **Severity:** Medium (GDPR Art. 5(1)(e))
- **Issue:** `Core/Data/DataRetentionManager.swift` prunes local SwiftData rows. Nothing prunes:
  - Firestore `user_profiles` documents of users who deleted the app and never returned.
  - Firestore `feedback/*` records (kept forever).
  - Firestore `subscriptions/*` after expiration + retention window.
  - `referrals/*` — if the law requires deletion of referrals after the program ends, this is unhandled.
- **Fix:** A scheduled Cloud Function that runs daily and prunes:
  - `user_profiles` where `updatedAt < now-3y` AND no active subscription.
  - `feedback` after 2 years.
  - `subscriptions` 1 year after final expirationDate.
- **Confidence:** 88/100 — local retention verified; absence of any Cloud Functions in repo verified.

### F14. No localized Privacy Policy / ToS for Brazil (LGPD).

- **Severity:** Medium (only matters if BR launch)
- **Issue:** `AppSecrets.URLs.privacyPolicy = "https://lasohealth.fit/privacy"` is a single English URL. LGPD Art. 6(VI) requires transparency in Portuguese for Brazilian users.
- **Fix:** Either pre-launch in BR or make the page content-language-aware (server-side via Accept-Language).
- **Confidence:** 80/100 — URL literal verified, page content not opened.

### F15. CCPA "Do Not Sell or Share My Personal Information" link recommended but absent.

- **Severity:** Low-Medium (CCPA / CPRA)
- **Issue:** Even though Laso does not sell data, CPRA best practice is to provide a "Do Not Sell or Share My Personal Information" link on the homepage and in the app for California residents. App Review has been known to flag this for health apps.
- **Fix:** Add a dedicated link in the in-app PP page; not a hard launch blocker.
- **Confidence:** 72/100 — CCPA optional-but-recommended for non-sellers; whether App Review will flag is variable.

### F16. iCloud Keychain–synced encryption key (`syncKey`) widens the trust boundary.

- **Severity:** Low (note for documentation, not a fix)
- **Issue:** `EncryptedStore.swift:81` stores the sync key with `kSecAttrAccessibleAfterFirstUnlock` and `synchronizable: true`. This means the key syncs to iCloud Keychain. CloudKit-encrypted backups use this key. End-to-end the data is fine (Apple's E2E iCloud Keychain), but for the PP, this should be disclosed: "If you enable cloud backup, encrypted backups travel through iCloud and the encryption key is synchronized via your iCloud Keychain."
- **Fix:** Document in PP. No code change needed.
- **Confidence:** 90/100.

### F17. Firebase Auth is created automatically without user awareness or chance to opt out.

- **Severity:** Medium (transparency)
- **Issue:** `AppLaunchCoordinator.swift:27–33` creates an anonymous Firebase Auth user on first launch silently. The user has not yet seen a Privacy Policy. While the UID is anonymous, GDPR Art. 13 still requires informing the user that their device just got a UID and the controller is now processing it.
- **Fix:** Defer the `Auth.auth().signInAnonymously` call until after the user has seen onboarding Screen 1 and the bottom of Screen 2 has the "By continuing, you accept our [Terms] and [Privacy Policy]" footer (see F5).
- **Confidence:** 90/100.

### F18. No DPA / RoPA / sub-processor list in repo `Docs/`.

- **Severity:** Low-Medium (internal ops, not user-facing)
- **Issue:** `Docs/` has only `device-compatibility-drp-2026-04-07.md`, `todo.md`, `posthog-setup-report.md`. No GDPR Article 30 Records of Processing Activities, no Data Processing Agreement template, no signed sub-processor list (Firebase, PostHog).
- **Fix:** Author and check in:
  - `Docs/RoPA.md` listing each processing activity, lawful basis, retention, recipient, transfer mechanism.
  - `Docs/sub-processors.md` listing Firebase (Google LLC, US-based, SCCs in place via Firebase DPA), PostHog (PostHog Inc, EU-hosted via `eu.i.posthog.com` — `AppSecrets.swift:70`), Apple StoreKit (US, sub-processor for billing).
  - `Docs/DPA.md` — note that PostHog and Firebase DPAs are linked in PP (with URLs).
- **Confidence:** 88/100 — `ls` confirmed.

### F19. No consent log / version capture.

- **Severity:** Medium (GDPR Art. 7(1))
- **Issue:** When the user (eventually, after F5 is fixed) accepts the PP and ToS, no record is kept of which version they accepted. GDPR requires being able to demonstrate, on a per-user basis, what version of the policy they consented to.
- **Fix:** Once F5 lands, write `consents/{deviceId}/{timestamp}` Firestore docs with `{ ppVersion, tosVersion, appVersion, locale, acceptedAt }`. Bump `ppVersion` whenever the policy changes; show users a re-consent sheet on next launch.
- **Confidence:** 92/100.

### F20. Push notification consent does not split "engagement" from "alerts".

- **Severity:** Low-Medium
- **Issue:** `NotificationManager.swift:52` requests `[.alert, .sound, .badge]` once. The system prompt does not differentiate "Daily summary / motivational / re-engagement" from "Critical health alerts". GDPR's transparency expects the user to know what notifications will be sent.
- **Fix:** The Settings page already has per-bucket toggles (`Copy+Settings.swift`, `NotificationsSettingsView.swift`). The fix is purely UX: explain the categories on the pre-permission "soft prompt" sheet (currently absent — system prompt fires raw).
- **Confidence:** 80/100.

### F21. No HIPAA-implying language found. Pass.

- **Severity:** n/a (positive finding)
- **Note:** Reviewed Copy+Paywall, Copy+Settings, Copy+Onboarding, Copy+BrainHealth, Copy+CycleTracking, Copy+SleepCoach, Insights/Copy+Analysis. No "HIPAA-protected", "medical-grade", "FDA-cleared" claims. Disclaimers present in onboarding, settings, risk detail. Brain Health correctly uses "Cognitive Wellness" not "dementia screening". Risk module uses "Pattern" / "Trend" language not "diagnosis". This is the right posture.
- **Confidence:** 95/100.

### F22. Risk module language is just barely on the safe side.

- **Severity:** Low (caution flag)
- **Issue:** `HealthRiskDetailView.swift:92` accessibility label literally says "risk level X out of 100". `HealthRisk.swift:174` enumerates `RiskFactorStatus.critical`. While the surrounding disclaimer (`Copy+Analysis.swift:200`) clarifies these are not diagnoses, in App Review's Health-app pattern-matching this combination ("critical risk level" + a numeric score) can read as a clinical claim.
- **Fix (defensive):** Soften to "Pattern level X / 100" or "Watch level X / 100" if Apple flags. Keep current language as the default; have soft-language alternative ready for resubmission.
- **Confidence:** 75/100 — Apple's threshold for "diagnostic claim" in App Review is fuzzy; the existing disclaimer text mitigates significantly.

### F23. ATT not requested. Acceptable only if F3 is fixed.

- **Severity:** Conditional
- **Issue:** No `ATTrackingManager.requestTrackingAuthorization` in code. This is the correct posture **iff** `NSPrivacyTracking=false` is true — i.e. iff F3 is fixed by disabling FirebaseAnalytics. Until then, the absence of ATT plus auto-collected IDFV via Firebase = ATT violation.
- **Fix:** Resolves automatically once F3 is fixed.
- **Confidence:** 88/100.

### F24. WebExport (`Modules/WebExport`) — out of scope confirmation.

- **Severity:** n/a (verified)
- **Note:** Searched for `WKWebView` or cookie persistence; none in `Modules/WebExport` source. The "web report" is a generated HTML file shared via `UIActivityViewController` (`SettingsView.swift:147`). No third-party web tracking is loaded inside the app.
- **Confidence:** 90/100.

---

## Summary scorecard

| Severity | Count | Where |
|----------|-------|-------|
| Critical (App Store hard block) | 3 | F1, F2, F3 |
| High (legal exposure / regulator complaint) | 6 | F5, F6, F7, F8, F9, F10 |
| Medium | 7 | F4, F11, F12, F13, F14, F17, F19 |
| Low / advisory | 6 | F15, F16, F18, F20, F22, F23 |
| Pass / informational | 2 | F21, F24 |

### Top Now (do not submit to App Store without these)
1. **F1** — implement true server-side account/data deletion via Cloud Function + `Auth.delete()`.
2. **F2** — expand `PrivacyInfo.xcprivacy` to declare every collected data type.
3. **F3** — remove `FirebaseAnalytics` from `project.yml` (or set the disable flag in `Info.plist`).
4. **F4** — rewrite `NSHealthUpdateUsageDescription` to reflect actual writes.
5. **F5** — add Privacy Policy + Terms link + acceptance gate to onboarding screen 2 footer.

### Top This Week (before EU + IN + BR launch)
6. **F6** — add per-feature consent toggles in Settings (analytics, crash, cloud backup).
7. **F7** — free, machine-readable "Export My Data" JSON ZIP in Settings.
8. **F8** — explicit opt-in sheet for cycle/menstrual data processing.
9. **F9** — region-aware age gate (≥18 in IN/EU/BR, ≥13 in US/CA only).
10. **F10** — fix the paywall "stays on your phone" claim.
11. **F11** — `.postHogMask()` audit on `Modules/Journal/` rendered text views.
12. **F19** — write a `consents/` collection logging accepted PP/ToS versions per user.

### Top Pre-Scale
13. **F12** — split feedback emails into restricted-access subcollection.
14. **F13** — Cloud Function for Firestore retention pruning.
15. **F18** — author RoPA + sub-processor list in `Docs/`.
16. **F14** — localize PP for BR (only when BR launch is imminent).

---

## Key file references (absolute paths)

- `/Users/primetrace/Desktop/RnD/HealthPulse/PrivacyInfo.xcprivacy`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Info.plist`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Laso.entitlements`
- `/Users/primetrace/Desktop/RnD/HealthPulse/project.yml`
- `/Users/primetrace/Desktop/RnD/HealthPulse/App/AppLaunchCoordinator.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/UserProfileStore.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/HealthKitManager.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/HealthDataContainerFactory.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/JournalStore.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Data/CloudBackupManager.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/PostHogManager.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/AppAnalytics.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Tracking/FeedbackPromptManager.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Subscriptions/SubscriptionManager.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Security/EncryptedStore.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Onboarding/Views/Onboarding/OnboardingView.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Onboarding/Views/Onboarding/ProfileCaptureView.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Onboarding/Views/Onboarding/OnboardingPromiseStep.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Settings/Views/SettingsView.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Paywall/Views/Subscription/PaywallView.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Paywall/Copy+Paywall.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Referral/Services/ReferralManager.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Modules/Risk/Views/Risk/HealthRiskDetailView.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Models/HealthRisk.swift`
- `/Users/primetrace/Desktop/RnD/HealthPulse/Core/Intents/IntentDataProvider.swift`

---

**Confidence: 90/100** — Three things are dragging the score down: (a) the actual content of `https://lasohealth.fit/privacy` and `/terms` was not fetched, so PP-vs-code cross-checks for F10/F12/F14/F16/F19 are inferential; (b) Firestore security rules are not in the repo, so server-side enforcement of ownership / deletion / retention is unverifiable end-to-end; (c) no runtime test was performed (the audit mandate is read-only) so the FirebaseAnalytics auto-collection behavior at startup, the journal-text PostHog session-replay leak hypothesis, and the actual Apple-Store metadata reviewer's threshold for the Risk module language are not empirically confirmed.
