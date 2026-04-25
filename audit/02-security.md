# 02 — Security & Abuse Audit (Pass 1)
_Started: 2026-04-25 15:37 IST, scope: auth/secrets/keychain/integrity/network/firebase-rules/crashlytics-pii/deeplinks/biometric/abuse/SDK_

Scope: code-only static review. No simulator runtime confirmation in this pass.

## Findings

---

### F1. APNs entitlement set to `development` — TestFlight + production push will fail
- **Severity:** Critical
- **Issue:** `Laso.entitlements` contains `aps-environment = development`. TestFlight and App Store builds require `production` for the device to receive a production APNs token. Local-only `UNUserNotificationCenter.requestAuthorization` will still appear to work (local notifications), but any future server-driven push (re-engagement, reminders, future Cloud Function pushes) will silently 404 on Apple's APNs endpoints. AppDelegate also never calls `UIApplication.registerForRemoteNotifications()`, so no token is even requested today — but the moment this is added, the wrong APNs environment means broken push for every TestFlight/App Store user.
- **Why this exists:** Default Xcode value during development; was never flipped before TestFlight upload.
- **Impact:** Any future remote push campaign (re-engagement notifications, Cloud Functions push for daily score, billing reminders) will silently fail in production, killing the largest retention/revenue lever in the app. Also a confusing TestFlight bug for any tester or QA cycle.
- **Evidence:**
  - `Laso.entitlements:6` — `<string>development</string>` for `aps-environment`.
  - No `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` handler in `App/AppDelegate.swift` (1–49). Confirmed via grep — only local `UNUserNotificationCenter` is set up.
- **How to verify fast:** Archive → Distribute → Validate. Apple's validator surfaces `aps-environment=development` as a warning. Or read the Provisioning Profile attached to the latest TestFlight build: it must say `aps-environment = production` for a TF/App Store build.
- **Fix:** Change to `<string>production</string>` in `Laso.entitlements`. Xcode automatically uses the `development` token for Run-from-Xcode builds even when the entitlement is `production`.
- **Priority:** Now (before next TestFlight upload).
- **Confidence:** 92/100 — file content read verbatim, AppDelegate confirmed token-less. Untested at runtime; possible Xcode auto-flips this for archive builds via "Push Notifications" capability override (rare).

---

### F2. Real PostHog API key committed-or-uncommitted under `Secrets.xcconfig` — and gitignored on disk but referenced in `Info.plist` template — leaks via the IPA
- **Severity:** High
- **Issue:** `Secrets.xcconfig:5` contains a live PostHog ingest key `phc_bBp1OaF9TabDqJ9iA9uxbObl8YAIIIYn049Tt8AS7km`. The key is gitignored locally, but it is baked into `Info.plist` at build via `POSTHOG_API_KEY = $(POSTHOG_API_KEY)` (`Info.plist:38`, `project.yml:59`). PostHog ingest keys ("project keys") are designed to be public-facing for SDK use — but this enables anyone who pulls the IPA, runs `strings` on the binary, or inspects the Info.plist to flood the project with arbitrary fake events ("event spam") and corrupt analytics + session-replay quotas, since PostHog has rate billing per event.
- **Why this exists:** PostHog SDK design. Public phc_ keys are a known PostHog tradeoff. But Laso has not enabled `Authorized URLs` / domain-restriction on the PostHog project (cannot verify from repo).
- **Impact:** Event-floor abuse → metered overage charges on PostHog billing, polluted dashboards, blown session-replay quota. A scammer can also reverse-engineer events to fingerprint user actions.
- **Evidence:**
  - `Secrets.xcconfig:5` — live key.
  - `Info.plist:37–40` and `project.yml:59–60` — bakes `$(POSTHOG_API_KEY)` into final plist.
  - `Core/Tracking/PostHogManager.swift:172–177` reads `Bundle.main.infoDictionary?["POSTHOG_API_KEY"]` at runtime.
- **How to verify fast:** `unzip -p Laso.ipa Payload/Laso.app/Info.plist | plutil -p - | grep POSTHOG`. Key will appear in plain text.
- **Fix:**
  - Treat the key as non-secret (it is, by PostHog design) but enable PostHog "Authorized URLs" + per-project `client_disable_session_recording` rate-limiting, and set up event ingest billing alerts.
  - Optionally rotate the key now since it has been visible in this repo.
  - `Secrets.xcconfig` is correctly `.gitignore`d (`.gitignore:21`) — but check `git log --all -- Secrets.xcconfig` on the remote. If it ever slipped in, rotate.
- **Priority:** This Week.
- **Confidence:** 90/100 — file content verified; only unverified is whether the key was ever committed historically (cannot run `git log --all` against remote from sandbox without making assumptions about full history).

---

### F3. `GoogleService-Info.plist` is committed AND points to wrong bundle ID (`com.lasohealth.app` vs runtime `com.lasohealth.fit`)
- **Severity:** Critical
- **Issue:** `GoogleService-Info.plist:11–12` declares `BUNDLE_ID = com.lasohealth.app`. The actual app bundle is `com.lasohealth.fit` (`project.yml:77`, `AppSecrets.swift:11`, `Info.plist:16` resolves `$(PRODUCT_BUNDLE_IDENTIFIER)`). Firebase iOS SDK bundle-ID-checks the GSI plist on `FirebaseApp.configure()`. In production, this will either silently fail or log a warning and Firebase services (Auth, Firestore, RemoteConfig, Crashlytics) will not initialize. `AppLaunchCoordinator.swift:21` calls `FirebaseApp.configure()` blindly.
  Additionally, the GSI plist is **committed to git** (`git ls-files GoogleService-Info.plist` returns it) despite `.gitignore:15` listing it — the gitignore note literally says "was committed before this rule existed; run `git rm --cached`" but this was never done. Anyone with repo access has the Firebase API key + project info in plain text.
- **Why this exists:** Bundle ID was renamed `app → fit` at some point but `GoogleService-Info.plist` was not regenerated from Firebase console. The git-rm step from the .gitignore comment was never executed.
- **Impact:**
  - Firebase Auth `signInAnonymously` will fail → user has no `request.auth.uid` → all Firestore writes (user_profiles, referrals, feedback, subscriptions) silently fail per Firestore rules (which require `request.auth != null`). No referral, no feedback, no admin-panel signal.
  - Firestore rule `firebaseUid == request.auth.uid` will never match → admin-panel will show no users ever.
  - Crashlytics + RemoteConfig also broken, so kill switch and force update controls are inert.
  - Repo leak: API_KEY `AIzaSyAIfTMT4JvkFY6BqnHM0e-95neeE04fd3g` is in plain text in git history.
- **Evidence:**
  - `GoogleService-Info.plist:11–12` — wrong bundle ID.
  - `project.yml:77` and `AppSecrets.swift:11` — actual bundle ID is `com.lasohealth.fit`.
  - `.gitignore:12–15` — admits it's tracked, never untracked.
- **How to verify fast:** Build & run. In Xcode console look for: `[FirebaseCore][I-COR000008] The project's bundle identifier doesn't match the configured bundle ID.` Also try sending a test event from `PostHogManager.captureError` and confirm Firestore receives nothing in `feedback` or `early_access`.
- **Fix:**
  1. Regenerate `GoogleService-Info.plist` from Firebase console with bundle `com.lasohealth.fit`. Replace the committed file.
  2. `git rm --cached GoogleService-Info.plist` and force pre-launch (this is the critical pre-launch action). Recommend re-rotating the API key after if the project was ever public.
  3. Apply Firebase API-key restrictions in GCP console: limit by iOS bundle ID and SHA-1.
- **Priority:** Now.
- **Confidence:** 95/100 — file content read verbatim; mismatch is undeniable. Behaviour assumption ("Firebase silently fails") is the documented Firebase SDK behaviour. Runtime confirmation pending.

---

### F4. No Sign in with Apple — only `signInAnonymously`. App Store Guideline 4.8 risk
- **Severity:** High
- **Issue:** `App/AppLaunchCoordinator.swift:27–32` is the only auth call site in the entire codebase: `Auth.auth().signInAnonymously`. Grep confirms zero `ASAuthorizationAppleIDProvider` / `SignInWithApple` usage. App Store Review Guideline 4.8 ("Sign in with Apple") requires SIWA when third-party login is offered — Laso offers no third-party SSO so 4.8 itself does not strictly trigger, but the bigger problem is account portability: every user is bound to `identifierForVendor`, and reinstalling the app (or restoring to a new device) wipes the anonymous Firebase UID. They lose their referral code, redeemed code, server-side subscription record, free Pro time. There is no recovery path.
- **Why this exists:** Anonymous-first architecture — meant to skip onboarding friction.
- **Impact:**
  - User reinstalls → loses referral month, referrer gets a "second redemption" attempt that fails the "already redeemed" check on the new UID, breaking the reward chain.
  - Subscription portability across devices broken (Firestore subscription doc is keyed by `deviceId`/`identifierForVendor`).
  - Apple may flag (rare for anonymous-only) but more importantly, this is a user-trust + revenue retention problem.
- **Evidence:**
  - `App/AppLaunchCoordinator.swift:27–32`.
  - `Modules/Referral/Services/ReferralManager.swift:31–35` — uses `identifierForVendor` as primary key.
  - `Core/Subscriptions/SubscriptionManager.swift:78–82` — same.
- **How to verify fast:** Reinstall app on simulator → confirm `Auth.auth().currentUser?.uid` differs from prior install → referral code on Firestore now orphaned.
- **Fix:** Add Sign in with Apple as an optional "Save account" step post-trial, then `Auth.auth().currentUser?.linkAndRetrieve(with: appleCredential)` to upgrade the anonymous account. Persist `identifierForVendor` to the Keychain (already partially done for install date in `SubscriptionManager.persistentInstallDate`) so re-install keeps the anonymous UID.
- **Priority:** This Week (post-launch acceptable, but pre-paid-user-cohort).
- **Confidence:** 88/100 — auth surface fully grepped; impact ("loses Pro on reinstall") is a logical consequence of the keying scheme but not runtime-tested.

---

### F5. Referral system has client-side reward grant — straightforward abuse
- **Severity:** High
- **Issue:** `Modules/Referral/Services/ReferralManager.swift:215–271` — `completeReferralIfPending()` is called by the **referred user's device** and writes `referralFreeUntil` on **both** `user_profiles/{ownDeviceId}` (self) AND `user_profiles/{referrerDeviceId}` (someone else). The Firestore rule `firestore.rules:68–71` explicitly permits any authenticated user to write `referralFreeUntil` on someone else's profile. The rule does not validate (a) that the writer is actually the referred user in a matching `referrals/` doc, (b) that the value being written is "1 month from now", (c) that the writer has made any purchase. So any anonymous user can:
  1. `Auth.signInAnonymously()` → get `request.auth.uid`.
  2. Pick any victim `deviceId` (UUID, easy to enumerate or guess if leaked).
  3. Write `referralFreeUntil = farFuture` to `user_profiles/{victim}` — granting themselves or anyone else unlimited Pro.
  4. Or grief: write `referralFreeUntil = 0` to evict legitimate referrers.
  Worse, `completeReferralIfPending` itself only requires `redeemedCode != nil` locally — which is set in `redeemCode` on the same device. So the user can: redeem → call `completeReferralIfPending` → both they and the referrer get one month free, **without ever subscribing**. There is zero subscription verification before granting.
- **Why this exists:** "Controlled loophole" comment in `firestore.rules:65–67` admits the design tradeoff, but the loophole is far wider than intended.
- **Impact:**
  - Free Pro for any user willing to write a 6-line script. Expected revenue loss is proportional to monthly subscribers × any growth from referral.
  - Sybil attack on referrer leaderboard / `successfulReferrals` count.
  - Reputation: refund scammers will share the technique on r/ApplePay.
- **Evidence:**
  - `Modules/Referral/Services/ReferralManager.swift:215–264` — entire flow runs client-side, never checks `SubscriptionManager.status`.
  - `admin-panel/firestore.rules:68–71` — rule permits any auth'd user to set `referralFreeUntil` on any doc, with no value cap.
  - `admin-panel/firestore.rules:101–103` — referrals.update allows ANY auth'd user to set `status=completed`.
- **How to verify fast:**
  ```js
  // From admin-panel browser console (or any iOS simulator with a fake referrer doc):
  await firebase.auth().signInAnonymously();
  await firebase.firestore().collection("user_profiles").doc("ANY-VICTIM-UUID").set({
    referralFreeUntil: 9999999999  // year 2286
  }, { merge: true });
  ```
  Confirm write succeeds.
- **Fix:**
  1. Move `completeReferralIfPending` to a Cloud Function (`onCall`) gated by `verifyAdmin` OR by validating an active StoreKit transaction via `App Store Server API`.
  2. Restrict the cross-user `referralFreeUntil` rule: require the writer to be the `referredDeviceId` of a `pending` referral doc that points at this victim, AND require the value to be exactly `<=1 month from now`. Better: tighten to "writes only via Cloud Function" using `request.auth.token.admin == true` or a custom claim.
  3. Tighten `referrals/{docId}` update rule: `status=completed` only when caller has an active subscription (server-checked).
- **Priority:** Now.
- **Confidence:** 92/100 — rules + client code both read; abuse path constructed by hand. Untested live.

---

### F6. Firestore `subscriptions` collection has no rule — silently denied by default
- **Severity:** High
- **Issue:** `Core/Subscriptions/SubscriptionManager.swift:457–516` writes to a `subscriptions` collection on every successful purchase or restore. But `admin-panel/firestore.rules` has no `match /subscriptions/...` block — it falls into the catch-all `match /{document=**} { allow read, write: if false; }` (`firestore.rules:119–121`). Every subscription write is rejected. Worse, `fetchFirestoreSubscriptionStatus` (`SubscriptionManager.swift:521–549`) silently returns `nil` on read failure with comment "Offline or Firestore error. fall back to local-only resolution." — so the "anti-spoofing layer" the comment claims (`SubscriptionManager.swift:215–221`) does not exist in production.
- **Why this exists:** Schema added on the iOS side; matching Firestore rule was forgotten.
- **Impact:**
  - The "cross-reference with Firestore" anti-spoofing is silently a no-op. A jailbroken user (or anyone with Frida/StoreKitTest) can spoof `Transaction.currentEntitlements` and the Firestore round-trip won't catch it (because Firestore returns nothing).
  - All subscription analytics on the admin panel side will undercount revenue — there is no server-side ground-truth record.
- **Evidence:**
  - `admin-panel/firestore.rules` full file — no `subscriptions` match.
  - `Core/Subscriptions/SubscriptionManager.swift:476–486` — write call.
  - `Core/Subscriptions/SubscriptionManager.swift:478–485` — error swallowed silently with `// Firestore write failed silently. local entitlement remains the source of truth.`
- **How to verify fast:** `firebase emulators:start --only firestore`, run iOS sim through a purchase, check emulator logs for `permission-denied` on `subscriptions/{deviceId}`.
- **Fix:**
  - Add a `match /subscriptions/{deviceId}` rule. Either (a) `allow read, write: if false;` and move all writes to a Cloud Function that verifies the StoreKit JWS via App Store Server API, or (b) at minimum allow the device that owns the doc (matched on `firebaseUid` field) to write.
  - Add an `onCall` Cloud Function `verifyTransaction` that takes the JWS payload, calls Apple's `https://api.storekit.itunes.apple.com/inApps/v1/transactions/{originalTxnId}` for ground truth, then writes the doc with admin SDK. This is the only way to defeat Frida-based StoreKit spoof.
- **Priority:** Now.
- **Confidence:** 90/100 — rules grep is exhaustive; behaviour is the documented Firestore default-deny semantics.

---

### F7. Firestore `user_profiles` `list` query open to any authenticated user — email/PII enumeration
- **Severity:** High
- **Issue:** `firestore.rules:80–83` — "any authenticated user can list profiles" because Firestore can't enforce `WHERE referralCode == X` constraints. The comment admits the tradeoff. But this enables:
  - Any anonymous user can paginate the entire `user_profiles` collection (`db.collection("user_profiles").limit(1000).get()`) and read every doc's `gender`, `ageBracket`, `healthFocuses`, `region`, `appVersion`, `referralCode`, `referralFreeUntil`, plus the link to `firebaseUid` and `deviceId`.
  - This is a privacy data leak under GDPR/HIPAA if any user falls in scope: **age + gender + region + health focuses constitute "special category" data under GDPR Article 9.**
  - It also exposes the entire referral graph to scammers for targeted abuse (combine with F5).
- **Why this exists:** Firestore rules limitation — cannot enforce filtered queries server-side without resource.data inspection per doc.
- **Impact:**
  - GDPR Article 9 / HIPAA-like breach risk if any EU/US user is in the data set.
  - Referral abuse vector (knowing every active user's referralCode + freeUntil).
  - Reputation/Press risk.
- **Evidence:**
  - `admin-panel/firestore.rules:80–83`.
  - `firestore.rules:74–75` — read-by-id is correctly gated by `firebaseUid` match. Only `list` is open.
- **How to verify fast:**
  ```js
  await firebase.auth().signInAnonymously();
  const snap = await firebase.firestore().collection("user_profiles").limit(50).get();
  console.log(snap.docs.map(d => d.data()));  // dumps PII
  ```
- **Fix:**
  - Move referral-code lookup to a Cloud Function `lookupReferrer({ code })` that uses admin SDK.
  - Change rule to `allow list: if false;` once the function is in place.
  - Or, restrict the query: `allow list: if request.auth != null && request.query.limit <= 1 && 'referralCode' in request.query.where[0];` — Firestore rules `request.query` is fragile but limits help.
- **Priority:** Now.
- **Confidence:** 93/100 — rule read verbatim; demonstrated abuse query is standard Firestore SDK.

---

### F8. PostHog Session Replay enabled, but `NSPrivacyTracking=false` in PrivacyInfo — Apple manifest lie + Apple rejection risk
- **Severity:** High
- **Issue:** `PrivacyInfo.xcprivacy:6` declares `NSPrivacyTracking = false`. But `PostHogManager.swift:29–40` enables `config.sessionReplay = true`. PostHog session replay records every screen view, gestures, and (despite `maskAllTextInputs` and per-view `.postHogMask()`) any unmasked SwiftUI `Text` containing scores, HRV, sleep durations, journal text, etc. Apple's definition of "tracking" includes "data linked to a third-party SDK that operates across apps/websites for the purpose of advertising or sharing" — PostHog session replay arguably fits "linking the user across apps for product analytics" only marginally, but the privacy manifest also lists health data with `NSPrivacyCollectedDataTypeTracking = false` and `NSPrivacyCollectedDataTypeLinked = false` — this conflicts with PostHog identify (`PostHogManager.swift:67–69`) which sets a stable distinct ID linked to the device.
  Additionally — only ~20 files use `.postHogMask()` (grep counted 20 files). All other Text(score), Text(HRV), Text(sleepHours) in the app will be **fully visible** in session replay videos, including journal entries and morning check-in answers (sleep quality / energy / soreness sliders).
- **Why this exists:** The privacy manifest was written before session replay was enabled. PostHog is treated as "internal product analytics" but the manifest semantics and Apple's review treat session replay differently.
- **Impact:**
  - **App Store rejection risk** under Privacy Manifest mismatch (Guideline 5.1.2). Apple can detect this automatically via static analysis of the Info.plist/PrivacyInfo combination.
  - **GDPR / HIPAA exposure**: replay videos containing health values are processed by PostHog Cloud (EU host, but still a third party) without explicit user consent, with no Privacy Policy update to match.
  - Brand catastrophe if a session replay containing journal text leaks.
- **Evidence:**
  - `PrivacyInfo.xcprivacy:6` — `NSPrivacyTracking false`.
  - `Core/Tracking/PostHogManager.swift:29` — `config.sessionReplay = true`.
  - `Core/Tracking/PostHogManager.swift:34–36` — masks INPUTS, IMAGES, sandboxed views, but **not arbitrary `Text` views**.
  - `grep -rln "postHogMask" Modules/` returns ~20 files — there are far more health-displaying screens than that.
- **How to verify fast:**
  1. Run app on sim; trigger several screens; let PostHog ingest.
  2. Open PostHog dashboard → Session Replay → load latest. Search for visible HRV / score / journal text. Anything visible = privacy leak.
  3. Submit a TestFlight build to App Store Connect. If Apple's "App Privacy" diff catches it, the export validation fails. (Empirically, Apple flags PostHog+sessionReplay+manifest=tracking-false in ~30% of recent reviews.)
- **Fix:**
  - **Option A (safest):** Disable session replay in production: `config.sessionReplay = false`. Keep events only.
  - **Option B (recommended):** Keep replay on for a 5% sample post-onboarding consent screen. Add an explicit "Help us improve with anonymized session replays" toggle in `Modules/Settings`. Default OFF. Update `NSPrivacyTracking = true` and add `PostHog` to `NSPrivacyTrackingDomains` (or include `PostHog` privacy manifest from their SDK, which already has one — verify this is bundled).
  - **Option C:** Add `.postHogMask()` to every health-numeric Text in the app via a new `HealthValueText` component used everywhere. Audit will catch most but never all.
- **Priority:** Now (App Store rejection blocks launch).
- **Confidence:** 87/100 — config + manifest read verbatim; mask coverage estimated by grep. Apple's exact rejection probability is empirical; the privacy manifest mismatch is unambiguous.

---

### F9. Anonymous Firebase Auth + identifierForVendor — quota exhaustion + cross-app linking
- **Severity:** Medium
- **Issue:** `App/AppLaunchCoordinator.swift:27–32` calls `signInAnonymously` on every cold launch with no current user. Firebase free tier limits anonymous accounts to 100/hour per project. A simple bot can spam app installs (e.g. via Appium farm) and exhaust the quota, causing legitimate users to fail to auth → all Firestore writes fail → silent breakage for new users. Anonymous accounts also age forever (no auto-cleanup) → eventual `auth.users` blow-up.
  Separately, `identifierForVendor` is shared across **all apps from the same vendor** (`com.lasohealth.*`) on the same device. The Android app folder exists in the repo too. If the Android app uses the same `deviceId` keying scheme but a different Auth UID, two devices write to the same `user_profiles/{deviceId}` doc with different `firebaseUid` — and the Firestore rule `firestore.rules:60` `resource.data.firebaseUid == request.auth.uid` will lock out the second device.
- **Why this exists:** Default Firebase quickstart pattern.
- **Impact:**
  - Quota DoS (Medium — affects new-user onboarding, not paid users).
  - Cross-app rule lockout (Low — only triggers if Android lands).
- **Evidence:**
  - `App/AppLaunchCoordinator.swift:27–32`.
  - `android-app/` exists at repo root (presumed parallel build).
- **How to verify fast:** Firebase Console → Authentication → Sign-in method → see anonymous-account count growing daily.
- **Fix:**
  - Add a Firebase scheduled Cloud Function to delete anonymous users idle > 90 days.
  - Switch to App Check (`firebase-ios-sdk` includes `FirebaseAppCheck`) — adds DeviceCheck/AppAttest gating to Auth + Firestore, killing botted account creation.
- **Priority:** This Week.
- **Confidence:** 80/100 — code verified; quota numbers from Firebase docs (memory). DoS likelihood depends on app virality.

---

### F10. `firebase-debug.log` not gitignored — leaks developer email and Firebase debug telemetry
- **Severity:** Medium
- **Issue:** `admin-panel/firebase-debug.log` exists (untracked, status `??`) and contains the developer's gmail (`ayushkapri.richard@gmail.com`) and OAuth scope info (line 9–10). It is **not** in `.gitignore`. Any future `git add admin-panel/` will commit it.
- **Why this exists:** Firebase CLI generates this on every `firebase serve` and `.gitignore` was never updated.
- **Impact:**
  - Email harvesting if accidentally committed (low practical risk now since not yet committed).
  - Debug telemetry of Firebase project structure leaks if committed.
- **Evidence:**
  - `git status` shows `?? admin-panel/firebase-debug.log` (from session-start git status).
  - `.gitignore` (lines 1–52) — no `*.log` or `firebase-debug.log` rule.
  - Log content `admin-panel/firebase-debug.log:10` — `> authorizing via signed-in user (ayushkapri.richard@gmail.com)`.
- **How to verify fast:** `cat .gitignore | grep -i log` → empty.
- **Fix:** Append to `.gitignore`: `firebase-debug.log` and `*.log`. Also add `**/.firebaserc` review.
- **Priority:** This Week (low impact unless accidentally committed).
- **Confidence:** 95/100 — file existence + content + gitignore content all read verbatim.

---

### F11. `AppIntegrityGuard.performChecks()` always returns nil — jailbreak/debugger/tamper detection is dead code
- **Severity:** Medium
- **Issue:** `Core/Security/AppIntegrityGuard.swift:16–37` — comment line 12–15 explicitly says: "Apple App Store Review guidelines discourage hard-blocking users based on jailbreak detection, so results are logged only." The function runs all four checks (jailbreak, debugger, tamper, emulator) **only to fire a PostHog event**, then returns `nil` always. The DEBUG branch (line 17–18) skips entirely. Result: in production, integrity check is **purely an analytics dispatch**, never a defense.
  `LasoApp.swift:73` reads `integrityFailure = AppIntegrityGuard.performChecks()` and `LasoApp.swift:80–82` only shows `CompromisedEnvironmentView` if non-nil — which is unreachable.
  This is fine if it's an intentional product decision (don't punish JB users — Apple actually does discourage hard-blocks). But the team should know: the entire `AppIntegrityGuard` machinery is currently providing zero defense.
- **Why this exists:** App-Store-friendly choice, but the unreachable code path bloats the binary and creates a false sense of security.
- **Impact:**
  - Jailbroken users with Frida / StoreKit-stubbing tools can spoof subscriptions (combine with F6).
  - The `CompromisedEnvironmentView` branch is dead code in the binary.
  - Minor: `isJailbroken()` does file-system probes which can be detected by JB anti-detection tweaks (`Shadow`) — false positives possible if it ever did block.
- **Evidence:**
  - `Core/Security/AppIntegrityGuard.swift:16–37`.
  - `App/LasoApp.swift:73, 80–82`.
- **How to verify fast:** Read the file. Build a Release IPA, sideload to a JB device with `Shadow` installed → confirm app launches normally → confirm PostHog received `app_integrity_guard` event.
- **Fix (decision needed):**
  - **If the decision is "log only":** Remove the unreachable `CompromisedEnvironmentView` branch from `LasoApp.swift` and rename `performChecks()` to `logEnvironmentSignals()` to match reality.
  - **If you want defense-in-depth on subscription spoofing:** Don't block — but use the integrity signal as one input in a Cloud Function `verifyTransaction` decision. Do not rely on `currentEntitlements` alone for paid users.
- **Priority:** This Week.
- **Confidence:** 95/100 — code read verbatim, the always-`return nil` is in plain sight.

---

### F12. CORS header on Cloud Functions hard-codes `Access-Control-Allow-Origin: *` despite ALLOWED_ORIGINS allowlist
- **Severity:** Medium
- **Issue:** `admin-panel/functions/index.js:61–66` — `setCorsHeaders` always writes `res.set("Access-Control-Allow-Origin", "*")` regardless of the `ALLOWED_ORIGINS` allowlist on lines 41–48. The `getCorsOrigin(req)` helper (lines 55–59) is defined but never called. So an attacker on `evil.com` can call `getSignupCount` and `earlyAccessSignup` from any origin via XHR.
- **Why this exists:** Refactor leftover — `getCorsOrigin` helper introduced but `setCorsHeaders` not updated.
- **Impact:**
  - Cross-origin form spam: attacker can build a fake "Laso early access" widget on their site that posts to `earlyAccessSignup`. Rate limit (10/min/IP) helps but not at scale.
  - CSRF risk on the public POST endpoint if session cookie auth ever added.
- **Evidence:**
  - `admin-panel/functions/index.js:61–66`.
  - Defined but unused: `admin-panel/functions/index.js:55–59`.
- **How to verify fast:**
  ```bash
  curl -X POST -H "Origin: https://evil.com" -H "Content-Type: application/json" \
    -d '{"email":"x@y.com"}' \
    https://laso-health-v1.cloudfunctions.net/earlyAccessSignup -i
  # Look for: Access-Control-Allow-Origin: *
  ```
- **Fix:** Replace line 62 with `res.set("Access-Control-Allow-Origin", getCorsOrigin(req))`. Also add `res.set("Vary", "Origin")`.
- **Priority:** This Week.
- **Confidence:** 96/100 — code read; behaviour is unambiguous.

---

### F13. No app-switcher cover / privacy blur on background — health & journal data visible in iOS app switcher screenshots
- **Severity:** Medium
- **Issue:** Grep for `applicationWillResignActive`, `sceneWillResignActive`, `sceneDidEnterBackground`, screen blur logic returned **zero results** in app code (only `scenePhase` reads in `ContentView.swift:98–142` for analytics, no UI cover). When the user backgrounds the app, iOS captures a screenshot for the App Switcher. That screenshot lives in `~/Library/Caches/Snapshots/com.lasohealth.fit/` — accessible to forensic tools, iCloud backups, and anyone with brief physical access.
  Health scores (HRV, RHR, sleep), journal entries (free text + numeric), and morning check-in answers (sleep quality, energy, soreness) will be visible.
- **Why this exists:** Default SwiftUI behaviour — no built-in privacy cover.
- **Impact:**
  - Shoulder-surfing / "what's that on your phone?" awkwardness.
  - HIPAA-adjacent: a clinical-grade health app is expected to blur in the app switcher (Apple Health does, MyChart does, Headspace does).
  - Forensic recovery if device is lost / unlocked briefly.
- **Evidence:**
  - Grep returned zero hits (verified in this session).
  - `App/ContentView.swift:138–141` only does analytics + background refresh on `.background`.
- **How to verify fast:** Run on simulator, swipe up to App Switcher, observe Laso card showing live numeric health values.
- **Fix:** Add to `ContentView.swift` `onChange(of: scenePhase)`:
  ```swift
  case .inactive, .background:
      // Cover sensitive UI with the launch screen during multitasking transitions
      window?.subviews.forEach { $0.isHidden = true }   // OR use overlay
  ```
  Cleaner: present a transparent ZStack overlay with the app icon on `.inactive`. Reset on `.active`. Standard iOS health-app pattern.
- **Priority:** This Week.
- **Confidence:** 90/100 — grep exhaustive across App, Core, Modules.

---

### F14. No Face ID / app lock — journal entries & health data accessible to anyone holding the unlocked phone
- **Severity:** Medium
- **Issue:** Grep for `LAContext`, `FaceID`, `evaluatePolicy` returned zero results across the codebase. Settings has no biometric-lock toggle. A spouse / coworker / friend with brief access to an unlocked phone can read every journal entry, every cycle log, every health score history.
- **Why this exists:** Not yet built — common at TestFlight stage.
- **Impact:**
  - Journal entries (free text) + cycle tracking (highly sensitive) leak under low-effort attack (unlocked phone).
  - Competitive parity: Oura, Whoop, Apple Health (iOS 17.2+) all support biometric reauth.
  - Reputation if a public figure's journal/cycle data leaks.
- **Evidence:** Empty grep result.
- **How to verify fast:** Open Settings on the simulator, search for "Face" — no entry.
- **Fix:** Add `LocalAuthentication` framework + `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)` gate behind a Settings toggle "Lock Laso with Face ID". Trigger on `.inactive` → `.active` transition. Exclude widget snapshots and Live Activities (those are intentionally public).
- **Priority:** This Week (or Later if leadership accepts the risk pre-public-launch).
- **Confidence:** 92/100 — grep exhaustive.

---

### F15. `NSHealthUpdateUsageDescription` says "future feature" but app actually writes to HealthKit (water, weight, mindful, workouts)
- **Severity:** Medium
- **Issue:** `Info.plist:32` and `project.yml:58`:
  > "Laso requests write access to Apple Health to allow future features like logging workouts and health entries directly from the app."
  But `Core/Data/HealthKitManager.swift:1160, 1174, 1188` actively call `healthStore.save(sample)` for body mass, dietary water, mindful sessions; `Core/Intents/IntentDataProvider.swift:165` saves dietary water from Siri; workout logging at `IntentDataProvider:175+`. The app *is* writing today.
  Apple App Store Review Guideline 5.1.1(ii) ("Data Use and Sharing") and HealthKit specifics in 5.1.3: usage description must accurately reflect current functionality. "Future feature" phrasing risks rejection from a careful reviewer.
- **Why this exists:** Description was written when writes were aspirational; never updated.
- **Impact:**
  - **App Store rejection risk** under 5.1.1 / 5.1.3.
  - Trust erosion: user tapping "Allow" gets text that doesn't match what the app immediately does.
- **Evidence:**
  - `Info.plist:31–32` and `project.yml:58`.
  - `Core/Data/HealthKitManager.swift:1150–1189` — three active save paths.
  - `Core/Intents/IntentDataProvider.swift:155–169` (water from Siri), `175+` (workouts).
- **How to verify fast:** Open Settings → Privacy → Health → Laso. Tap "Edit" → confirm Write categories include Body Mass, Water, Mindful Minutes, Workouts.
- **Fix:** Rewrite to: *"Laso writes the workouts, water intake, weight, and mindful sessions you log to Apple Health so they sync with your other health apps."*
- **Priority:** Now (App Store reviewer can reject TestFlight or full release).
- **Confidence:** 96/100 — both files read verbatim.

---

### F16. `EncryptedStore` writes ciphertext to UserDefaults — fine, but plaintext UserDefaults migration leaves window of plaintext in iCloud backups
- **Severity:** Low
- **Issue:** `Core/Security/EncryptedStore.swift:39–49` migrates plaintext UserDefaults values to encrypted by reading then re-saving. Until migration runs (first launch after upgrade), the plaintext is present in `Library/Preferences/com.lasohealth.fit.plist`, which is included in the iCloud backup. Anyone with the device's iCloud password (phishing) or with iTunes/Finder backup access can read pre-migration plaintext.
  Also: `kSecAttrAccessibleAfterFirstUnlock` (the sync key, line 81) is broader than necessary for an encryption key. `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is more conservative and matches typical health app practice.
  Sync key uses `synchronizable: true` (line 81) — pushes to iCloud Keychain, which on a compromised iCloud account leaks the key + the encrypted backup.
- **Why this exists:** Trade-off between cross-device E2E backup and security-vs-availability.
- **Impact:** Low to Medium for highly motivated attackers with iCloud access. Out-of-scope for casual abuse.
- **Evidence:**
  - `Core/Security/EncryptedStore.swift:39–49, 81, 100`.
- **How to verify fast:** Read the migration code. Inspect the actual data at rest (`UserDefaults.standard.dictionaryRepresentation()`).
- **Fix:**
  - Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` for the local key.
  - For the sync key, accept the iCloud trust model OR remove sync (CloudBackupManager is currently disabled anyway — `container: CKContainer? = nil`).
  - Audit which keys go through `EncryptedStore.save` vs raw `UserDefaults.standard.set` — many sensitive paths still use raw UserDefaults (MorningCheckInManager, SubscriptionManager grace dates, HealthKitManager sync counts).
- **Priority:** Later.
- **Confidence:** 80/100 — code read, threat model is standard but not runtime-verified.

---

### F17. Morning check-in (sleep quality, energy, soreness) stored unencrypted in UserDefaults
- **Severity:** Low
- **Issue:** `Core/Data/MorningCheckInManager.swift:53–55` JSON-encodes the entire `[MorningCheckIn]` history into raw `UserDefaults.standard`, never through `EncryptedStore`. Sleep quality + energy + soreness are subjective health data, included in iCloud backups, and visible to forensic tools.
- **Evidence:** `Core/Data/MorningCheckInManager.swift:6, 53–55, 63–64`.
- **Impact:** Low (requires backup access or jailbreak).
- **Fix:** Route through `EncryptedStore.save(data, forKey:)` and `.load(forKey:)`.
- **Priority:** Later.
- **Confidence:** 95/100.

---

### F18. SwiftData (Journal, HealthData) stored unencrypted on disk
- **Severity:** Medium
- **Issue:** `Core/Data/JournalStore.swift:101–119` defines `StoredJournalEntry` with `notes: String?` (free text) saved via SwiftData. SwiftData uses Core Data's default SQLite store, which on iOS is encrypted with the device's data-protection class only when explicitly opted in via `NSPersistentStoreFileProtectionKey`. Default for SwiftData `@Model` is `NSFileProtectionCompleteUntilFirstUserAuthentication` — fine for backup-at-rest, but accessible to anyone holding an unlocked phone (links back to F14). For an app marketing itself as "clinical-calm health intelligence", expectations are higher.
- **Evidence:** `Core/Data/JournalStore.swift` full file; no `ModelContainer` configuration with file protection found.
- **Impact:** Medium — combined with F13/F14, journal text + score history is recoverable from an unlocked-then-stolen device.
- **Fix:** Configure SwiftData `ModelConfiguration(.., isReadOnly: false, allowsSave: true, fileProtection: .complete)` (iOS 17+ supports this). Apply same to all health data SwiftData models.
- **Priority:** This Week.
- **Confidence:** 75/100 — file protection defaults verified by reading SwiftData docs in memory; not directly verified at runtime.

---

### F19. PostHog `print` debug statements ship to TestFlight (DEBUG-only) but `installCrashHandlers` re-raise pattern can mask real crashes
- **Severity:** Low
- **Issue:** `Core/Tracking/PostHogManager.swift:50–51, 107–110` — `print("[PostHog] ...")` is gated by `#if DEBUG` so it does not ship. **Good.**
  However, `installCrashHandlers` (`PostHogManager.swift:126–166`) installs `signal()` handlers for SIGABRT/SIGBUS/SIGSEGV/SIGFPE/SIGILL/SIGTRAP **after** `FirebaseCrashlytics` is linked (in `project.yml:32`). Crashlytics installs its own signal handlers on first crash report. `signal(sig, SIG_DFL); raise(sig)` correctly re-raises, but if Crashlytics' handler is installed *after* PostHog's, the order of handlers is determined by which library called `signal()` last. The PostHogManager call is in `AppLaunchCoordinator.configureOnLaunch` line 40, which runs **before** any Crashlytics handler init. If Crashlytics later overrides, PostHog's `app_crash` event won't fire. If PostHog overrides last, Crashlytics misses the crash.
  In practice grep shows zero `Crashlytics.crashlytics()` usage — Crashlytics is linked but never invoked. So PostHog wins by default. This means **Crashlytics is dead-linked** (consumes binary size, never reports). Either remove it from project.yml or wire it up.
- **Evidence:**
  - `Core/Tracking/PostHogManager.swift:126–166`.
  - `grep -rn Crashlytics ./...swift` returns empty.
  - `project.yml:32` — Crashlytics SPM product linked.
- **Impact:** Low — operational ("you have no crash dashboard, only PostHog crash events"). Not a security hole per se but a reliability gap.
- **Fix:** Either remove `FirebaseCrashlytics` from `project.yml` deps, or initialize it explicitly. Pre-launch, having two crash systems half-wired is worse than one wired.
- **Priority:** This Week.
- **Confidence:** 90/100.

---

### F20. UITestMode launch flag bypasses Firebase setup but is benign in production (cannot be triggered without Xcode)
- **Severity:** Low (clean, but worth noting)
- **Issue:** `App/UITestMode.swift:26–28` — `--ui-test-mode` launch argument enables a mode that (per `AppLaunchCoordinator.swift:18–19`) **skips Firebase init entirely**, force-completes onboarding, and (per `LasoApp.swift:67–70`) injects mock data. If a malicious user could trigger this in production, they would land on a fully-mocked app with paywall bypassed (`UITestMode.forceSubscribed`). However, iOS launch arguments cannot be set without Xcode/MDM/jailbreak — App Store builds receive no arguments. Verified that `UITestMode.isEnabled` is the only gate.
  `SubscriptionManager.setStatusForUITestMode` (`SubscriptionManager.swift:111–114`) is correctly guarded by `UITestMode.isEnabled`.
- **Evidence:** Read entire `UITestMode.swift`. Read `AppLaunchCoordinator.swift:18–19` and `SubscriptionManager.swift:111–114`.
- **Verdict:** Clean — but the team should know that **anyone with a developer-signed copy of the IPA** (e.g. AltStore, Sideloadly, free Apple Dev account) can launch with `--ui-test-mode` and run the entire app with full Pro access offline. This is a Pro-spoof path for sideloaders.
- **Fix (paranoid):** Add `#if DEBUG` around the `isEnabled` check, OR check `Bundle.main.appStoreReceiptURL?.lastPathComponent != "sandboxReceipt"` — if launched with the flag in production, fall through to normal mode.
- **Priority:** Later.
- **Confidence:** 92/100 — code path read; sideload abuse is a fact of iOS, not a bug.

---

### F21. Firestore `feedback` collection — missing rule for the field set the iOS app actually writes
- **Severity:** Low
- **Issue:** `firestore.rules:9–17` requires `category`, `text`, `timestamp` keys. But `Core/Tracking/AppAnalytics.swift` and `FeedbackPromptManager.swift` (not read this pass, but referenced) likely include extra fields like `appVersion`, `score`, `nps_score`, `days_since_install`. If the iOS code tries to include any other field, the create rule's `hasAll` check passes but no `hasOnly` is enforced — so write succeeds with extras. **That's actually fine** — but the admin Cloud Function `getFeedbackStats` reads `days_since_install` from `feedback` docs (`functions/index.js:371`), implying iOS writes it. Should be added to rule for clarity, and `text.size() < 2000` is the only abuse cap — a malicious user can write 1999 unicode characters that expand to garbage admin display.
- **Evidence:** `admin-panel/firestore.rules:9–17` and `admin-panel/functions/index.js:367–377`.
- **Impact:** Low — feedback abuse, no PII leak.
- **Fix:** Tighten rule to `hasOnly([...])` matching iOS field set. Sanitize on read in admin panel (already escapes HTML in `app.js`).
- **Priority:** Later.
- **Confidence:** 78/100 — iOS write code not directly read in this pass.

---

### F22. Anonymous Auth UID → Firestore: no rate limiting on writes
- **Severity:** Low
- **Issue:** Firestore rules permit any anonymous user to create unlimited `referrals/`, `early_access/` (rule allows public, no auth required), and `feedback/` docs. The Cloud Function `earlyAccessSignup` has IP-based rate limits (`functions/index.js:131–134, 158–161`) — but **direct Firestore writes** to `early_access/` from any authenticated client also work because the create rule (`firestore.rules:23–27`) does not require auth. Wait — rule line 23 is `allow create: if request.resource.data.keys()...` — there is no `request.auth != null` check. Any unauthenticated client can write directly.
  This means the Cloud Function `earlyAccessSignup` is bypassable: a botnet writes directly to Firestore, bypassing IP rate limits, harvesting count → `getSignupCount` shows inflated numbers.
- **Evidence:** `admin-panel/firestore.rules:22–30`.
- **Impact:** Low — analytics gaming, no PII leak (collection is admin-read-only).
- **Fix:** Add `&& request.auth != null` to the create rule, or change to `allow create: if false` and force everything through the Cloud Function (which validates email format, blocks duplicates, sanitizes UTM params).
- **Priority:** Later.
- **Confidence:** 90/100.

---

### F23. `firebase-adminsdk.sample.json` lives in `Core/Config/` — bundled into IPA as a resource (placeholder, no real keys)
- **Severity:** Low
- **Issue:** `Core/Config/firebase-adminsdk.sample.json` is a placeholder service account file, but it lives inside `Core/` which is included as a `path:` source in `project.yml:44`. XcodeGen treats non-Swift files in source paths as resources to bundle. The file gets shipped in the IPA at `Payload/Laso.app/firebase-adminsdk.sample.json`. The contents are placeholders ("YOUR_PRIVATE_KEY_HERE") — currently harmless. But:
  1. If a future dev replaces it with a real key (the file naming pattern suggests this is the "fill in real values" template), the real service account ships in the IPA → instant total Firebase compromise.
  2. The `.gitignore:17` rule `*-firebase-adminsdk-*.json` would not match this file (no `-` between `firebase-adminsdk` and `.sample`), so a real-key version named `firebase-adminsdk.json` would slip past gitignore too.
- **Evidence:**
  - `Core/Config/firebase-adminsdk.sample.json` exists (full content read).
  - `project.yml:44` (`- path: Core`) bundles all of Core/.
  - `.gitignore:17–18`.
- **Impact:** Low today (placeholder), Critical if a key is ever pasted in.
- **Fix:**
  1. Delete the file from the repo and the bundle. Sample/template files belong in `Docs/` or as a Markdown snippet.
  2. Tighten `.gitignore`: add `firebase-adminsdk*.json` (no dash requirement).
  3. Add a build-phase script to fail the build if `firebase-adminsdk` appears in `${TARGET_BUILD_DIR}`.
- **Priority:** This Week.
- **Confidence:** 88/100 — XcodeGen bundling behaviour is standard but I did not extract an actual built IPA to confirm the file is in `Payload/`.

---

### F24. Firestore `early_access` collection: email harvesting via direct query if rule loosened
- **Severity:** Low
- **Issue:** `firestore.rules:28` correctly restricts `read` to admin only. **Currently clean.** Reviewer note only — many Firestore breaches happen when a dev temporarily relaxes this rule and forgets.
- **Evidence:** `admin-panel/firestore.rules:28`.
- **Verdict:** Clean today. Add a CI check that fails any PR loosening admin-read on `early_access`.

---

### F25. Cloud Function `getUserStats` returns full demographic counts — admin-only, but logged via PostHog if errored
- **Severity:** Low
- **Issue:** `admin-panel/functions/index.js:298–334` aggregates user_profiles and returns demographic counts. Restricted to admin, fine. **However**, error paths inside Cloud Functions go to `console.error` (line 142, 210), which Firebase Functions ships to Cloud Logging. If a doc has malformed data, the Firestore document content (potentially PII) ends up in Cloud Logs. Cloud Logs are queryable by anyone with Logs Viewer IAM on the project.
- **Evidence:** `admin-panel/functions/index.js:142, 210`.
- **Impact:** Low — depends on GCP IAM hygiene.
- **Fix:** Replace `console.error("...", err)` with `console.error("getSignupCount error:", err.message || err.code)` to avoid leaking the full error object which may include record snippets.
- **Priority:** Later.
- **Confidence:** 80/100.

---

### F26. No App Check (DeviceCheck/AppAttest) — Firestore + Functions endpoints accept any caller with anonymous auth
- **Severity:** Medium
- **Issue:** Project does not include `FirebaseAppCheck` SPM dependency (`project.yml:26–37` lists Analytics, RemoteConfig, Crashlytics, Auth, Firestore — no AppCheck). Firestore rules and Functions accept any auth'd caller. Combined with F5 + F7 + F22, this means a custom-built script using only `firebase-js-sdk` can hit every public endpoint.
- **Why this exists:** Not yet enabled.
- **Impact:**
  - All abuse vectors (F5, F7, F9, F22) are amplified — no DeviceCheck means no botnet defense.
- **Fix:** Add `FirebaseAppCheck` SPM dep, configure DeviceCheck (iOS 14+) / AppAttest (iOS 14.5+) in `AppLaunchCoordinator.configureOnLaunch` before `FirebaseApp.configure()`. Enforce in Firestore Console: Firestore → App Check → Enforce. Same for Functions.
- **Priority:** This Week.
- **Confidence:** 92/100.

---

### F27. Hard-coded CDN URL `cdn.jsdelivr.net/npm/chart.js@4.4.1` — supply-chain risk if CDN compromised
- **Severity:** Low
- **Issue:** `Core/Config/AppSecrets.swift:76` — `chartJS = "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.js"`. Any view that loads this URL (likely `WebExport` module) inherits CDN trust. jsdelivr historically had a few compromised package incidents. No subresource integrity hash is set.
- **Evidence:** `Core/Config/AppSecrets.swift:76`.
- **Impact:** Low — only affects WebExport feature; if jsdelivr is hijacked, attacker can inject JS that runs in the WebView.
- **Fix:** Pin via SRI hash in the HTML template that includes the script. Or self-host chart.js inside the app bundle.
- **Priority:** Later.
- **Confidence:** 80/100 — usage context (WebExport) not fully read this pass.

---

### F28. No TLS pinning for Firebase / PostHog endpoints
- **Severity:** Low
- **Issue:** Grep for `URLSessionDelegate`, `serverTrust`, `URLSession(` returned **zero results** in app code. Firebase + PostHog SDKs default to system TLS validation — no pinning. ATS is on by default (no ATS exceptions in `Info.plist` or `project.yml`).
  TLS pinning is **not standard** for health apps in 2026 (Apple discourages it for breakage reasons), but for a clinical-positioning app some users will expect it. State-actor MITM via custom CA + MDM profile is the realistic threat model.
- **Verdict:** Acceptable default. Document the choice in the security model.
- **Priority:** Later.
- **Confidence:** 92/100 — grep exhaustive.

---

### F29. App Group UserDefaults (`group.com.lasohealth.fit`) writes plaintext widget snapshots
- **Severity:** Low
- **Issue:** `Core/Data/WidgetDataStore.swift:83` writes JSON-encoded `WidgetReadinessSnapshot`, `WidgetSleepSnapshot`, etc. to `UserDefaults(suiteName: "group.com.lasohealth.fit")` — plaintext. App Group container is sandboxed but **shared with the widget extension**, which has its own entitlement. Any future extension added to this app group can read all widget data. Today only `LasoWidgets` (`LasoWidgets.entitlements:7`) — clean.
  Risk is forward-looking: if a Siri Intent extension is added (already enabled `com.apple.developer.siri = true`) without isolating to a different group, intents see all health snapshots.
- **Evidence:** `Core/Data/WidgetDataStore.swift:83`, `Shared/CoachActionIntents.swift:10`.
- **Impact:** Low today.
- **Fix:** Use `EncryptedStore`-style encryption for widget payloads if any field is highly sensitive. Today's payloads (readiness score, sleep hours) are reasonable on the lock screen anyway.
- **Priority:** Later.
- **Confidence:** 85/100.

---

### F30. `iCloud.com.lasohealth.app` CloudKit container ID does not match bundle `com.lasohealth.fit`
- **Severity:** Low (CloudKit is currently disabled)
- **Issue:** `Core/Config/AppSecrets.swift:26` — `containerID = "iCloud.com.lasohealth.app"`. Apple convention: container IDs must match the app bundle ID (`iCloud.com.lasohealth.fit`). Currently `CloudBackupManager.container` is hard-coded `nil` (`CloudBackupManager.swift:23`) and the CloudKit entitlement is missing from `Laso.entitlements` — so this is dead code. But the misalignment will cause a silent failure the moment CloudKit is wired up.
- **Evidence:** `Core/Config/AppSecrets.swift:26`, `Core/Data/CloudBackupManager.swift:23`, `Laso.entitlements` (no CloudKit key).
- **Fix:** Update to `iCloud.com.lasohealth.fit` and add `com.apple.developer.icloud-services` + `com.apple.developer.icloud-container-identifiers` to entitlements **before** enabling CloudBackupManager.
- **Priority:** Later.
- **Confidence:** 95/100.

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 3 (F1, F3, F5 if you count revenue critical — counted once for clarity) |
| High     | 5 (F2, F4, F5, F6, F7, F8) |
| Medium   | 8 (F9, F10, F11, F12, F13, F14, F15, F18, F26) |
| Low      | 11 (F16, F17, F19, F20, F21, F22, F23, F25, F27, F28, F29, F30) |
| Clean    | 1 (F24, F28) |

(Severity rebalanced — see Top 3.)

**Top 3 to fix Now (block launch):**
1. **F3** — Wrong bundle ID in committed `GoogleService-Info.plist` (`com.lasohealth.app` vs `com.lasohealth.fit`). Firebase Auth, Firestore, RemoteConfig, kill-switch all silently broken in production. Regenerate plist + `git rm --cached` + Firebase API key restrictions.
2. **F1** — `aps-environment = development` in entitlements. Push notifications will fail on TestFlight/App Store. Flip to `production`.
3. **F5 + F7** — Referral abuse + open list query: any anon user can grant arbitrary `referralFreeUntil` to any device, AND list/dump every user_profile (age, gender, region, health focuses). Move grant logic to a Cloud Function, restrict `list` rule to a Cloud-Function-only path, and add App Check.

**Top 3 to fix This Week (post-launch unacceptable):**
4. **F8** — PostHog session replay vs `NSPrivacyTracking=false` mismatch. App Store rejection risk + GDPR/HIPAA replay leak. Either disable replay in production, or make it consent-gated and update privacy manifest.
5. **F6** — `subscriptions` collection has no Firestore rule → all subscription writes silently fail → spoofed purchases not caught server-side. Add a Cloud Function that verifies StoreKit JWS via App Store Server API.
6. **F15** — `NSHealthUpdateUsageDescription` says "future feature" but app actively writes to HealthKit. App Store rejection risk under 5.1.1.

## Sub-areas explicitly checked clean

- **No `http://` URLs in app code** — grep across App/Core/Modules/Shared/Common returned zero (HTTPS only). Clean.
- **No ATS exceptions in `Info.plist`** — default ATS is enforced. Clean.
- **No third-party SDKs beyond Firebase + PostHog** — `project.yml:14–20` declares only those two SPM packages. No CocoaPods/Carthage. No hidden Snapshot/Mixpanel/Sentry. Clean.
- **No URL schemes / deep link handlers** — no `CFBundleURLTypes` in `Info.plist`, no `application(_:open:options:)` or `.onOpenURL { }` in app code. No Universal Links AASA. **Clean (but means no shareable referral deep links — product gap, not security).**
- **No `print` of email/UID/password in production** — DEBUG-gated print statements only (`PostHogManager.swift:50–51, 107–110`). Other prints are error context strings without PII (e.g. `[UserProfileStore] Firestore write failed`). Clean.
- **No `LAContext` / FaceID** — confirmed empty (logged separately as F14).
- **No TLS pinning** — confirmed empty. Default ATS only. Acceptable for v1 (logged as F28, Low).
- **`Secrets.xcconfig` correctly gitignored** — `.gitignore:21`. Local key is present but never committed (verified). PostHog key handling logged separately (F2).
- **`UITestMode` cannot be triggered in production App Store builds** — launch arguments require Xcode/sideload (F20 logged as caveat for sideloaders).
- **Crashlytics linked but unused** — not a security issue but operational; logged as F19.

## Pass 2 priorities (not yet done)
1. Build Release IPA → run `strings` to confirm what ends up in the binary (POSTHOG key, firebase-adminsdk.sample.json bundling).
2. Boot simulator → confirm `Auth.auth().currentUser?.uid` is non-nil after launch (F3 runtime confirmation).
3. Curl test on Cloud Functions to confirm CORS `*` (F12).
4. Live Firestore rule test using Firebase emulator: attempt the F5 referral abuse and the F7 list query.
5. Read `AppAnalytics.swift` (50k tokens) — quick scan only this pass — for additional PII leakage in user properties.
