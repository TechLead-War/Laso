# 18 — Security & Abuse — Pass 2 (Deeper)
_Started: 2026-04-25 16:55 IST, scope: net-new findings beyond Pass 1 (audit/02-security.md)._

## Pass 1 review summary
Pass 1 produced 30 findings (F1–F30) covering APNs entitlements, Firebase config drift, anonymous Auth quota/portability, referral abuse, Firestore rules (referral + subscriptions + user_profiles list), PostHog session-replay vs PrivacyInfo manifest, App-switcher cover, FaceID lock, EncryptedStore key accessibility, SwiftData file protection, Crashlytics dead-link, UITestMode flags in Release, CORS allow-origin, jsdelivr CDN supply chain, App Check absence, App Group widget plaintext, CloudKit container ID drift. Areas Pass 1 covered well: secrets-in-binary, top-level Firestore rules, biometric-lock, generic ATS posture, Firebase init drift, anon-Auth lifecycle, jailbreak detection neutered. Areas Pass 1 likely under-covered: race conditions inside Swift concurrency, TOCTOU windows in referral redemption + subscription state read, async-signal-safety of the PostHog signal handler, the entire `.privacySensitive()` modifier surface, sensitive-keyboard hygiene on ALL TextFields (not just password fields), Live-Activity lock-screen plaintext exposure, `ITSAppUsesNonExemptEncryption` export-compliance correctness, HTML-injection via insight strings → WebView/HTML report, side-channel oracle in referral error strings, `setUserProperty`-based linked PII to PostHog vs `NSPrivacyTracking=false`, brute-forceability of the 30-bit referral alphabet, unbounded HealthKit writes from Siri intents, share-sheet leakage to Photos library, `print()` shipping in Release for non-PostHog code paths.

## Net-new findings

---

### F31. Async-signal-unsafe call inside POSIX signal handler — secondary crash + corrupted crash report
- **Severity:** High
- **Issue:** `Core/Tracking/PostHogManager.swift:142–164` installs `signal()` handlers for SIGABRT/SIGBUS/SIGSEGV/SIGFPE/SIGILL/SIGTRAP and inside the handler body invokes `PostHogSDK.shared.capture(...)` and `PostHogSDK.shared.flush()`. These do allocations (`Dictionary<String,Any>`), Objective-C runtime calls, takes `NSRecursiveLock`s in PostHog's queue/batcher, and on `flush()` schedules a URLSession request. **None of this is async-signal-safe** (POSIX defines a small whitelist — `signal-safety(7)` — that excludes `malloc`, locks, NSObject, URL networking). Inside a real SIGSEGV the process is already in an undefined state; calling these functions from the handler typically (a) deadlocks waiting on a mutex held by the crashing thread, (b) heap-corrupts and produces a *second* crash that masks the original signal, or (c) succeeds intermittently which is the worst case (no test ever fails, but in production some crashes never reach the dashboard).
- **Why this exists:** Naive handler authoring — the team saw Crashlytics is unused (Pass 1 F19) and rolled their own handler without consulting `signal-safety(7)`.
- **Impact:**
  - Crash visibility loss: PostHog "app_crash" stream silently drops a fraction of events. Worse, Apple's CrashReporter receives a corrupted/secondary signal so the App Store crash dashboard shows the wrong frames.
  - Self-DoS: a single handler invocation can deadlock; user sees a 30-second hang before springboard force-kills the app.
  - When/if Crashlytics is wired up (per F19 fix), having a non-async-signal-safe handler installed *before* Crashlytics' will corrupt Crashlytics' chain too because the second `signal(sig, SIG_DFL); raise(sig)` (line 162–163) re-raises into Crashlytics' handler with broken state.
- **Evidence:** `Core/Tracking/PostHogManager.swift:144–164`:
  ```swift
  signal(sig) { signalNumber in
      ...
      PostHogSDK.shared.capture("app_crash", properties: [...])  // not signal-safe
      PostHogSDK.shared.flush()                                   // not signal-safe
      signal(signalNumber, SIG_DFL)
      raise(signalNumber)
  }
  ```
- **How to verify fast:** In a debug build, deliberately `Thread.sleep(forTimeInterval: 60)` while holding a lock that PostHog's batcher uses, then `kill -ABRT $(pidof Laso)`. Observe deadlock or watchdog kill before the handler returns. Or read `signal-safety(7)`: anything outside the listed functions is unsafe in a signal handler.
- **Fix:**
  1. In the handler, write a single async-signal-safe primitive: `write(STDERR_FILENO, msg, len)` or set a `sig_atomic_t` flag. Do nothing else.
  2. Move all telemetry into a separate "did-we-crash-last-launch" pass that reads a file dropped by the handler on next app launch (this is what Crashlytics actually does). For NSException, the `NSSetUncaughtExceptionHandler` block is fine to do more work in (Obj-C runtime is up), but POSIX signal handler must stay minimal.
  3. Or just delete the POSIX handler block and rely on `NSSetUncaughtExceptionHandler` + Crashlytics for SIGSEGV-class crashes (F19's fix).
- **Priority:** This Week (high — silently corrupts your only crash dashboard).
- **Confidence:** 92/100 — code read verbatim; behaviour follows POSIX signal-safety semantics. Have not reproduced the deadlock at runtime.

---

### F32. Race condition: double-tap on "Apply Code" creates duplicate `referrals/` docs (compounds F5 abuse)
- **Severity:** High
- **Issue:** `Modules/Onboarding/Views/Onboarding/ReferralCodeStep.swift:96–113` — the Apply button does **not** disable until `Task { isRedeeming = true ... }` runs on the next runloop tick. Between the tap and `isRedeeming = true`, SwiftUI accepts repeat taps. Each tap fires an independent `await ReferralManager.shared.redeemCode(codeText)`. Inside `redeemCode` (`ReferralManager.swift:144–187`), the "already referred" check (`existing.documents.isEmpty`) and the `addDocument` write are **not in a Firestore transaction** — both concurrent tasks pass the check, both create pending `referrals/` docs.
  Combined with Pass 1 F5 (client-side `completeReferralIfPending` grants `referralFreeUntil` to both parties without subscription verification), a triple-tap creates 3 pending referrals → on subscribe, `completeReferralIfPending` is called once but the referrer's `successfulReferrals` count is inflated and `referralFreeUntil` may be overwritten with the latest grant date. Worse, if the triple-tap creates 3 referrals each pointing at different victim referrer IDs (e.g. user pastes 3 different codes), they get 3× free-month grants written.
- **Why this exists:** SwiftUI Button + Task isolation gap. The disabled-after-state-flip is a common bug when the `disabled(...)` modifier reads a `@State` set inside a Task.
- **Impact:**
  - Inflated successful-referral counts on the leaderboard.
  - Multiple `referralFreeUntil` writes — deterministic result depends on Firestore last-writer-wins (currently no version field), which can be exploited.
  - Combines with F5 to amplify referral abuse: 1 user, 1 tap budget → 3-5 free-month grants per session.
- **Evidence:**
  - `Modules/Onboarding/Views/Onboarding/ReferralCodeStep.swift:96–113, 118` — button tap fires Task; `disabled(isRedeeming)` is at line 118 (after the tap closure).
  - `Modules/Referral/Services/ReferralManager.swift:169–187` — non-transactional check-then-write window.
- **How to verify fast:** UITest with `.tap()` 3× in 100 ms → query Firestore emulator → see 3 docs with `referredDeviceId == self`. Or single-thread test: comment out `redeemedCode` setter on line 197 → call `redeemCode` 3× concurrently with `async let`.
- **Fix:**
  1. Set `isRedeeming = true` **synchronously** before launching the Task: move the assignment outside `Task { ... }`.
  2. Even better: short-circuit at the top of `redeemCode` with `guard !isRedeeming else { return false }` and `defer { isRedeeming = false }` already exists but is set AFTER the Firestore round-trips.
  3. Wrap the check + write in a Firestore transaction: `db.runTransaction` so the existence check is atomic with the create.
- **Priority:** Now (compounds F5).
- **Confidence:** 90/100 — both files read; SwiftUI Task-disabled-flip race is a well-documented pattern. Untested at runtime.

---

### F33. Side-channel oracle in referral redemption errors — enables code enumeration
- **Severity:** High
- **Issue:** `Modules/Referral/Services/ReferralManager.swift:131–202` returns three distinct error strings:
  - `"Invalid referral code."` (line 155 — code does not exist)
  - `"You can't use your own referral code."` (line 163 — code exists and belongs to caller)
  - `"You've already been referred."` (line 175 — code exists and is valid for caller)
  - `"Something went wrong. Try again."` (line 202 — Firestore error / rule denial)
  The 30-bit alphabet (32 chars × 6 = 1.07 billion codes, `ReferralManager.swift:60–61`) is small enough that a determined attacker with anonymous Auth + no AppCheck (Pass 1 F26) can probe codes. The differentiated error gives a binary oracle: "exists vs not". Combined with F5 (cross-user `referralFreeUntil` grant via direct Firestore writes) and F7 (open `list` query on `user_profiles`), an attacker can:
  1. Bypass the rate gate by calling `db.collection("user_profiles").whereField("referralCode", isEqualTo: GUESS).limit(1).get()` directly (no App Check) → 250 ms per guess.
  2. Identify "real" codes in ~3 hours of constant probing (modulo Firestore's 50k reads/day soft cap on free tier — but easy to scale across anon UIDs).
  3. Each enumerated code → a `referrerDeviceId` → write `referralFreeUntil` directly to that doc (F5).
- **Why this exists:** UX choice (helpful error messages) — ignores the security implication of an oracle.
- **Impact:**
  - Faster path to mass referral abuse than F5 alone (which assumed the attacker already has a real code).
  - Enumerates the active-user `successfulReferrals` leaderboard: combine with F7's open list to dump the whole referral graph and pick the highest-leverage victim.
- **Evidence:**
  - `Modules/Referral/Services/ReferralManager.swift:155, 163, 175, 202` — distinguishable error strings.
  - `Modules/Referral/Services/ReferralManager.swift:60–61` — `chars = 32`, length 6 → 30 bits.
  - Pass 1 F7 (open list rule) + F26 (no App Check) makes the probing free.
- **How to verify fast:** From a JS console with `firebase-js-sdk`:
  ```js
  await firebase.auth().signInAnonymously();
  for (const code of guesses) {
    const r = await db.collection("user_profiles").where("referralCode", "==", code).limit(1).get();
    if (!r.empty) console.log("HIT:", code, r.docs[0].id);
  }
  ```
- **Fix:**
  1. Collapse all four error paths to a single string: `"This code can't be applied right now."` Server-side log (via Cloud Function) the actual reason for support.
  2. Increase entropy: 8-char alphabet over base-32 → 40 bits (1 trillion). Negligible UX cost.
  3. Move the lookup into a Cloud Function `redeemReferral({ code })` that does rate-limiting per `request.auth.uid` (5 attempts / hour) and returns a generic error.
  4. Fix F7 (close the list rule) and F26 (enable App Check) — both already in Pass 1.
- **Priority:** This Week (with F5 fix).
- **Confidence:** 88/100 — error strings + alphabet size verified. Probe rate is empirical estimate.

---

### F34. `ITSAppUsesNonExemptEncryption = false` is incorrect — App Store export-compliance lie
- **Severity:** Medium-High (App Store rejection risk + legal risk)
- **Issue:** `Info.plist:27–28` declares `<key>ITSAppUsesNonExemptEncryption</key><false/>`. But the app uses **proprietary AES-GCM encryption for user data at rest** via CryptoKit:
  - `Core/Security/EncryptedStore.swift:55` — `AES.GCM.seal(data, using: key)`
  - `Core/Security/EncryptedStore.swift:66` — `AES.GCM.open`
  - `Core/Subscriptions/SubscriptionManager.swift:373` — `SHA256.hash` for install-date integrity
  Apple's `ITSAppUsesNonExemptEncryption=false` is only valid if the app uses encryption *exclusively* in the categories exempted by Bureau of Industry and Security 740.17(b)(1) — i.e. authentication, digital signatures, copy protection, and HTTPS via system frameworks. Encrypting *user data* with AES-GCM is NOT exempt. The correct declaration is `true` plus an annual self-classification report (or ERN) submitted to BIS/NSA. Apple validates this on TestFlight upload and full release; a mismatch can trigger Export Compliance review and either delay release or yank the build.
  The typical confusion is "but I'm only using Apple's CryptoKit, isn't that exempt?" — no, Apple's APIs are fine, but the *use* (encrypting non-authentication user data) is what's classified, not the implementation source.
- **Why this exists:** Common misunderstanding by developers who add encryption later in the project lifecycle without re-evaluating the export flag.
- **Impact:**
  - **App Store hold** during Export Compliance review (1–7 day delay typical).
  - Worst case: the build is rejected and the team has to refile after submitting an annual self-classification report.
  - Legal / regulatory: false declaration to BIS is technically a federal offense in the US (rare prosecution but real exposure).
- **Evidence:**
  - `Info.plist:27–28` — `ITSAppUsesNonExemptEncryption=false`.
  - `Core/Security/EncryptedStore.swift:55, 66` — proprietary AES-GCM for user data.
  - `Core/Subscriptions/SubscriptionManager.swift:373` — SHA256 for tamper detection (this one is exempt under "authentication").
  - `project.yml:70` — same false value baked into project.yml.
- **How to verify fast:** Read Apple's "Export Compliance Information" docs page, then run `man 3 SecKeyCreateRandomKey` mentally: GCM-on-user-payload is non-exempt. Or: archive → Distribute → "Export Compliance" tab in App Store Connect — Apple will ask "does your app contain encryption?". Answering "no" while linking AES.GCM is the lie.
- **Fix:**
  1. Set `ITSAppUsesNonExemptEncryption = true` in both `Info.plist:27` and `project.yml:70`.
  2. Submit an annual self-classification report (ERN) to BIS via SNAP-R: https://snapr.bis.doc.gov/snapr/. Free, ~30 min form.
  3. Or, if the team wants to skip ERN, switch the encryption to be eligible under exemption: only encrypt for authentication purposes (which `SHA256` already is — keep it). Move EncryptedStore data through Apple's Data Protection Class API instead of AES-GCM so the file-system encryption is "system-managed" and exempt.
- **Priority:** Now (before next App Store / TestFlight upload).
- **Confidence:** 85/100 — code + plist read verbatim; export-compliance logic is documented BIS regulation but the exact threshold for "non-exempt" gets debated. Apple's review process is empirical.

---

### F35. HTML injection in `WebExport` — score / insight / category strings rendered raw into shareable HTML report
- **Severity:** Medium-High
- **Issue:** `Modules/WebExport/HTMLReportGenerator.swift:140, 146–147` interpolates `insight.title`, `insight.summary`, `insight.recommendation` directly into the HTML body via Swift string interpolation — **no HTML escaping** of `<`, `>`, `&`, `"`. Same at line 119 (`component.reason`), line 128 (`name`), line 161 (`samples.map { date.shortDateString }` — date is fine but values come from the user-correlated source list). The output HTML file is written to `temporaryDirectory` (`WebExportViewModel.swift:37`) and shared via `UIActivityViewController` (recipient opens it in Safari / Mail / iCloud / Files).
  The data sources (`Insight`, `HealthScore.breakdown`, `JournalCategory.displayName`) are mostly hard-coded English strings today, **but**:
  - `JournalStore.StoredJournalEntry.notes` (line 106) is free-form user text.
  - `HealthCorrelation` reasons can include user-typed metric names through the `JournalCorrelationAnalyzer` pipeline.
  - Future: when Apple Intelligence / on-device LLM generates personalized insight strings, they may include code-shaped tokens.
  - Future: server-driven Remote Config strings (already wired in `RulesConfiguration.swift`) — a compromised Firebase admin can push HTML/JS into an insight reason and every exported report becomes a self-XSS payload.
  Because `ReportTemplate.swift:215` inlines arbitrary JS (`ChartJSBundle.inlineChartJS`) and `script` tags are present, an attacker who controls *any* of those strings can inject `<script>` that runs when the recipient opens the file.
- **Why this exists:** Swift string interpolation has no auto-escape; HTML generation here was treated as templating, not security boundary.
- **Impact:**
  - Today: low (no user-controlled strings reach the HTML).
  - Tomorrow (when journal notes / personalised insights / RC strings flow in): medium — recipient who opens the shared report executes arbitrary JS in the file:// origin. Can read `localStorage`, exfiltrate via image beacon, or phish via overlay UI.
  - Brand risk: a report shared with a doctor or insurance contains `<script>alert("breached")</script>` — catastrophic.
- **Evidence:**
  - `Modules/WebExport/HTMLReportGenerator.swift:140, 146–147` — raw interpolation:
    ```swift
    <span class="insight-title">\(insight.title)</span>
    <div class="insight-summary">\(insight.summary)</div>
    <div class="insight-recommendation">\(insight.recommendation)</div>
    ```
  - `Modules/WebExport/HTMLReportGenerator.swift:117–123` — same for `component.reason`.
  - `Modules/WebExport/ReportTemplate.swift:202, 207–208` — `<title>\(title)</title>`, `<h1>\(title)</h1>`, `<div class="date">Generated: \(date)</div>` — interpolated raw.
  - `Modules/WebExport/ReportTemplate.swift:214–216` — inlines `<script>` block immediately following `\(body)`.
- **How to verify fast:** Add a journal entry with `notes = "<img src=x onerror=alert(1)>"`, route it through `HealthCorrelation` so it reaches Insight, then trigger Web Export. Open the resulting `.html` in Safari → alert fires.
- **Fix:**
  1. Add a private `htmlEscape(_ s: String) -> String` that replaces `&`, `<`, `>`, `"`, `'` with entity references.
  2. Wrap every `\(insight.title)`, `\(insight.summary)`, `\(insight.recommendation)`, `\(component.reason)`, `\(name)`, `\(title)`, `\(date)` with `htmlEscape(...)`.
  3. Use `Content-Security-Policy` `<meta>` in `ReportTemplate.html`: `<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'">` — this still allows the inline chart.js (which is required) but blocks any `<img onerror>` exfil and any future `<script src=...>` from injection.
  4. Even better: split chart data out as `JSON.parse(document.getElementById('data').textContent)` from a `<script type="application/json">` block (cannot execute) and remove all string interpolation from the script body.
- **Priority:** This Week.
- **Confidence:** 80/100 — code read verbatim; today's exposure is low because user-text path is not yet wired, but the structural risk is real and trivial to introduce. RC-driven attack vector is theoretical pending admin compromise.

---

### F36. Live Activity / Lock Screen exposes HRV, RHR, score, weakest pillar in plaintext to anyone glancing at the locked phone
- **Severity:** Medium
- **Issue:** `Shared/TodayScoreActivityAttributes.swift:117–142` defines `ContentState` containing `overallScore`, `weakestPillar` (string), `weakestPillarScore`, `steps`, `hrvMs`, `restingHR`, plus `heroValue`, `insight` (free string from server). `LasoWidgets/TodayScoreLiveActivityWidget.swift:54–253` renders all of these on the lock-screen Live Activity surface. Live Activities are visible **even when the phone is locked** — no biometric required, no notification-content-hiding (the privacy setting "Show Previews: When Unlocked" only applies to notifications, not Activities). HRV (35 ms) and RHR (52 bpm) are clinically sensitive; "weakest pillar: Recovery — score 41" could expose mental-health context for women's-cycle users (fertile-phase low recovery is a known indicator).
  Pass 1 F13 covered the multitasking screenshot but explicitly excluded Live Activities ("Exclude widget snapshots and Live Activities — those are intentionally public"). That carve-out is unsafe for a clinical app: the user opted in to the Activity for *engagement*, not necessarily for "anyone in line at Starbucks behind me sees my HRV".
- **Why this exists:** Live Activities are designed to be glanceable; the team optimised for engagement (TodayScoreLiveActivityManager.swift, BreathworkLiveActivityWidget) without an explicit "blur on lock screen" path.
- **Impact:**
  - Shoulder-surfing: a person glancing at a locked phone reads HRV 28ms next to "weakest pillar: Stress — 32". For sensitive populations (women tracking cycles, athletes hiding poor recovery from coaches, journalists), this is a leak.
  - HIPAA-adjacent: the FTC's Health Breach Notification Rule treats unauthorized disclosure of consumer health data as a breach. Lock-screen visible health values can fall in scope.
  - Brand: Apple's own approach (Apple Fitness Activity rings, Apple Health summaries) does NOT show HRV/RHR on the lock screen — the design contrast looks careless.
- **Evidence:**
  - `Shared/TodayScoreActivityAttributes.swift:117–142` — full state struct including `hrvMs`, `restingHR`, `weakestPillar`.
  - `LasoWidgets/TodayScoreLiveActivityWidget.swift:54, 139, 179, 255` — multiple render sites for `state.overallScore`, `state.heroValue`, `state.weakestPillar`.
  - `App/TodayScoreLiveActivityManager.swift:64` — populates the ContentState.
- **How to verify fast:** Run on a device with Live Activity enabled. Lock the phone. Observe HRV / RHR / weakest pillar visible on the lock screen.
- **Fix:**
  1. Add a Settings toggle "Hide health values on lock screen" (default ON for medical caution). When enabled, the Live Activity ContentState scrubs `hrvMs`, `restingHR`, `weakestPillarScore` to nil and renders just the score band ("Excellent / Good / Fair / Needs work") and a generic insight.
  2. Or: detect lock state via `UIApplication.shared.isProtectedDataAvailable` in the manager and conditionally update content; though Live Activity rendering happens in widget extension which can't read this directly — must be set on push.
  3. Document this in the privacy policy: "Live Activities show HRV and RHR on the lock screen by default; tap Settings → Privacy to hide."
- **Priority:** This Week.
- **Confidence:** 85/100 — Activity attributes verified; lock-screen visibility is documented Apple Live Activity behaviour. Have not photographed the actual surface.

---

### F37. Zero `.privacySensitive()` modifiers in the entire codebase — Quick Look / iOS-system snapshot leaks not just in app switcher
- **Severity:** Medium
- **Issue:** Grep across `App/`, `Core/`, `Modules/`, `Common/`, `Shared/`, `LasoWidgets/` for `.privacySensitive(` returns **zero results**. Pass 1 F13 covered the App-switcher screenshot via a `scenePhase` cover, but `.privacySensitive()` is the SwiftUI-native modifier that:
  - Auto-redacts the view in iOS-generated lock-screen notification previews.
  - Auto-redacts the view in Live Activities when device is locked (the Apple-recommended way to handle F36).
  - Hides the view in `Sharing` Quick Look thumbnails for any URL the app vends.
  - Marks the view as not-screenshot-eligible in some iOS 17+ contexts (Stage Manager, AirPlay mirroring).
  Missing on:
  - Every `Text(score)` Home view.
  - Journal entry note text.
  - Cycle phase indicator.
  - HRV / RHR numeric displays.
  - Score breakdown components in `CategoryDetailView`.
- **Why this exists:** Modifier wasn't part of the team's UI vocabulary; not flagged in design system (`Common/Components`).
- **Impact:**
  - On AirPlay mirror to a TV (cf. patient discussing an issue, projecting to a screen for a coach), score and journal text broadcast unredacted.
  - In Live-Activity-on-lock-screen surfaces (F36), the system would auto-blur sensitive views had `.privacySensitive()` been set on them — currently, no auto-blur ever fires.
  - In Stage Manager / external-display mirroring, content shows even when iPhone moved away.
- **Evidence:** `grep -rn "privacySensitive" --include="*.swift"` → empty across all source dirs.
- **How to verify fast:** Plug iPhone into a Mac via AirPlay, mirror screen. Observe score / HRV plainly visible on the larger display.
- **Fix:** Add `.privacySensitive()` to:
  - Every score display in `Modules/Dashboard/Views/Home/*.swift` (HomeView score hero, category cards).
  - Journal note text in `Modules/Journal/Views/Journal/JournalEntryView.swift`.
  - Cycle phase in `Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift`.
  - HRV / RHR live numbers across `Modules/Live`, `Modules/Vitality`, `Modules/Sleep`.
  - Live-Activity content wrappers in `LasoWidgets/TodayScoreLiveActivityWidget.swift` (interacts with iOS auto-blur).
- **Priority:** This Week.
- **Confidence:** 92/100 — grep is exhaustive across app source dirs.

---

### F38. Sensitive TextFields ship without `.textContentType(.none)` / `.privacySensitive()` / `.autocorrectionDisabled()` — keyboard learns user's health vocabulary
- **Severity:** Medium
- **Issue:** Several TextFields collect sensitive content but do NOT disable autocorrection / autocomplete, which means:
  - iOS keyboard's predictive engine *learns* the user's tokens. Words like "stress", "anxiety", "alcohol", journal phrases, AskYourData queries enter the user's keyboard dictionary and start suggesting in unrelated apps (iMessage, search, email).
  - QuickType bar can suggest credentials / contacts / PINs *into* a sensitive field.
  - The shared keyboard cache (per Apple's docs, `UITextInputTraits`) persists per-app but does not sync across apps; however, *system dictionaries* do learn.
  - On iOS 17+, predictive text is opt-out-only via per-field `.autocorrectionDisabled()`.
  Specific cases:
  - `Modules/Dashboard/Views/Home/AskYourDataView.swift:55` — "Why is my HRV low?" / "Did alcohol affect my sleep?" — autocorrection ON, no `.privacySensitive()`. Apple Intelligence (iOS 18.x+) treats keyboard text as eligible for ML training under "writing tools" if not opted out — though Laso targets iOS 17+, this becomes a forward issue.
  - `Modules/Journal/Views/Journal/JournalEntryView.swift:237` — "Optional notes..." — free-form journal: autocorrection ON, no `.privacySensitive()`. Notes about substance use, mental state, cycle symptoms enter system dictionaries.
  - `Common/Components/PMFSurveySheet.swift:125, 151, 177` — "fitness enthusiast", "someone with a chronic condition", improvement comments — uncovered.
  - `Common/Components/FeedbackSheet.swift:186` — bug report text — uncovered (line 172 email field is correctly handled).
- **Why this exists:** Default SwiftUI TextField behaviour. Team correctly applied content-type to email field but didn't repeat the discipline elsewhere.
- **Impact:**
  - Keyboard suggestion bar leaks health vocabulary into SMS / email / Slack.
  - Autocorrect can silently change "Cymbalta" → "Cumbalta" in feedback / journal notes — corrupted data + leaked attempt to ML servers.
  - On iOS 18+ (forward-looking), Writing Tools / Apple Intelligence may use these fields as input unless explicitly excluded.
- **Evidence:** Files listed above.
- **How to verify fast:** Type "depression" 5× into a journal note → switch to Notes app → start typing "depr" → observe predictive bar suggests "depression" because the system shared dictionary learned it.
- **Fix:** Apply across all sensitive TextFields:
  ```swift
  .textContentType(.none)
  .autocorrectionDisabled()
  .privacySensitive()
  .keyboardType(.default)  // explicitly default to avoid surprises
  ```
- **Priority:** This Week.
- **Confidence:** 85/100 — fields verified; keyboard-dictionary learning behaviour is documented but exact ML training scope on iOS 18 is opaque.

---

### F39. `print()` statements in non-DEBUG-gated production code paths leak operational diagnostics
- **Severity:** Medium
- **Issue:** Pass 1 F19 noted that `Core/Tracking/PostHogManager.swift:50–51, 107–110` `print` statements ARE `#if DEBUG`-gated. **But several other `print()` calls in production modules are NOT gated** — they ship in App Store builds and write to the Apple Unified Logging system (`os_log`-equivalent), which is:
  - Visible to anyone with `xcrun simctl spawn booted log stream` on a connected device.
  - Visible in `Console.app` when device is connected.
  - Recoverable from sysdiagnose tarballs sent in Apple Feedback assistant.
  - Forensically recoverable from device backups in some cases.
  - Worse: `Logger` (os.Logger) without explicit `privacy: .private` defaults to **public** in iOS 17+ — strings visible in third-party logging tools.
  Locations:
  - `Core/Notifications/NotificationManager.swift:63` — `print("Notification authorization failed: \(error.localizedDescription)")` — leaks Apple notification system error codes.
  - `Core/Notifications/NotificationManager.swift:183` — `print("Failed to schedule notification: \(error.localizedDescription)")` — same.
  - `Core/Notifications/ReengagementScheduler.swift:72` — `print("[ReengagementScheduler] Failed to schedule: ...")`.
  - `Core/Notifications/EngagementSequenceScheduler.swift:613` — `print("[EngagementSequence] Failed to schedule day \(day): ...")`.
  - `Modules/Referral/Services/ReferralManager.swift:268` — `print("[ReferralManager] Failed to complete referral: \(error.localizedDescription)")` — Firestore error message can include the document path or rule name.
  - `Core/Data/UserProfileStore.swift:192` — `print("[UserProfileStore] Firestore write failed: \(error.localizedDescription)")` — same risk.
  - `Core/Data/DataRetentionManager.swift:46` — `print("[DataRetention] Pruned \(totalPruned) expired records")` — counts only, low risk.
  - `Core/Analysis/ML/HealthStateClassifier.swift:395`, `Core/Analysis/ML/CoreMLEngine.swift:26, 28, 69`, `Core/Analysis/ML/TimeSeriesForecaster.swift:258` — print model status, including `prediction.riskScore` (line 69). **`prediction.riskScore` is sensitive** if the user is identifiable from device logs.
  - `Modules/Dashboard/ViewModels/DashboardViewModel.swift:990` — `Logger(subsystem: ...)` instance created. Verify the `os.Logger` calls use `privacy: .private` — by default Swift `Logger("hello \(value)")` treats interpolated values as public.
- **Why this exists:** Standard developer habit; team was disciplined about PostHog `#if DEBUG` but missed sibling files.
- **Impact:**
  - Operational metadata leaks via Console / sysdiagnose.
  - `prediction.riskScore` in `CoreMLEngine.swift:69` is the most directly sensitive — health risk score in plaintext device log.
  - On enterprise-MDM-managed devices, MDM admin may have access to unified logs.
- **Evidence:** Lines listed above.
- **How to verify fast:** `xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "[CoreMLEngine]"' ` → observe `Inference Success: Risk = X` lines streaming.
- **Fix:**
  1. Wrap every production `print` in `#if DEBUG`. Or replace with `Logger(...).debug(...)` which is auto-hidden in Release.
  2. Audit `Logger` calls: ensure `privacy: .private` interpolation: `logger.info("score: \(score, privacy: .private)")`.
  3. CI rule: lint for `print(` in non-DEBUG blocks across `Core/`, `Modules/`, `App/`. Fail PR if found.
- **Priority:** This Week.
- **Confidence:** 92/100 — grep verified; Logger default-public behaviour is documented Apple.

---

### F40. PostHog user-property pipeline (`setDemographicProperties`) ships linked PII contradicting `NSPrivacyTracking=false` — broader than Pass 1 F8
- **Severity:** Medium
- **Issue:** Pass 1 F8 flagged session replay vs `NSPrivacyTracking=false`. The deeper issue is `Core/Tracking/AppAnalytics.swift:376–425`, `setDemographicProperties()` ships to PostHog (via `setUserProperty`) the following **stable, linked** user attributes:
  - `age_bracket` (derived from encrypted DOB).
  - `gender`.
  - `country` (Locale region).
  - `language`.
  - `timezone` (e.g. "America/New_York" — ~city-level precision when combined with country).
  - `device_model` (raw `hw.machine` like "iPhone16,1") and marketing name (`phone_model`).
  - `os_version`.
  - `app_version`.
  Plus elsewhere: `health_focus` (line 525 — list of opted-in categories), `streak_days`, `health_score_bracket`, `subscription_age_days`. PostHog's `identify()` (PostHogManager.swift:67–69) ties all of these to a stable distinct ID (Firebase UID or device ID).
  Apple's privacy manifest (`PrivacyInfo.xcprivacy:6`) declares `NSPrivacyTracking=false`. Apple defines **Linked Tracking** as: "data collected from this app is linked to user identity and used to track that user across other companies' apps and websites" — which session replay arguably is, but the demographic property bundle is itself eligible for nutrition-label "Data Linked to You" requiring disclosure. The privacy manifest also requires `NSPrivacyCollectedDataTypes` array entries for each category (`Health & Fitness`, `Demographics`, `Identifiers`, `Diagnostics`). Currently the manifest declares some entries but not necessarily all of these.
  Pass 1 covered session-replay specifically; this finding is the broader user-property-pipeline mismatch.
- **Why this exists:** PostHog is treated as "internal product analytics" but user properties + stable ID are the textbook definition of linked PII for Apple's nutrition label.
- **Impact:**
  - **App Store rejection** under 5.1.2 if the privacy manifest omits the `Demographics` / `Health & Fitness` data types that `setDemographicProperties` ships.
  - **GDPR Article 9** ("special category data" — health + race-derived) — gender + health_focus is "data concerning health" under GDPR. PostHog Cloud (EU) is a sub-processor that may not be in the user-facing privacy policy.
  - **CCPA / Connecticut data privacy act** — same.
- **Evidence:**
  - `Core/Tracking/AppAnalytics.swift:376–425` — full demographic property writer.
  - `Core/Tracking/AppAnalytics.swift:524–525` — `setUserProperty("health_focus", ...)` ships health-domain selections.
  - `Core/Tracking/AppAnalytics.swift:728` — `price_tier`.
  - `Core/Tracking/PostHogManager.swift:67–82` — identify + setUserProperty plumbing.
- **How to verify fast:** Open PostHog dashboard → Persons → click any user → scroll Properties tab. Observe `gender=female`, `age_bracket=25-34`, `health_focus=sleep,recovery,stress`, `country=US`, `timezone=America/New_York`. That bundle is identifiable.
- **Fix:**
  1. Update `PrivacyInfo.xcprivacy` to declare ALL of: `NSPrivacyCollectedDataTypeHealth`, `NSPrivacyCollectedDataTypeFitness`, `NSPrivacyCollectedDataTypeDemographics`, `NSPrivacyCollectedDataTypeOtherDataTypes` (for `health_focus`), `NSPrivacyCollectedDataTypeOtherDiagnosticData`, with `Linked = true` and purpose `AppFunctionality / Analytics`.
  2. Stop shipping `gender`, `age_bracket`, `health_focus`, `timezone` to PostHog — or k-anonymize: bucket timezone to country, drop gender, ship `health_focus_count` instead of category list.
  3. Update privacy policy (`AppSecrets.swift:55` URL) to list PostHog as a sub-processor explicitly with the data types above.
  4. Add a "Reset analytics ID" button in Settings that calls `PostHogSDK.shared.reset()`.
- **Priority:** This Week.
- **Confidence:** 85/100 — code read; Apple privacy manifest interpretation is empirical (rejection rate varies).

---

### F41. Anonymous Firebase Auth callback never fires `await` boundary — race window between launch and first Firestore write
- **Severity:** Medium
- **Issue:** `App/AppLaunchCoordinator.swift:27–33` — `Auth.auth().signInAnonymously` is called in **callback form**, NOT awaited. The function returns immediately; the rest of `configureOnLaunch` continues (RemoteConfig fetch, screenshot tracking) without waiting for the Auth callback. Meanwhile, on the same launch:
  - `AppLaunchCoordinator.configureOnLaunch` (line 18) runs first.
  - `RemoteConfigManager.shared.fetchAndActivate()` (line 36) runs in a `Task` — this requires `request.auth != null` for some Firestore-backed Remote Config setups (depending on Console rules).
  - Other code paths (e.g. `ReferralManager.syncWithFirestore`, `UserProfileStore.write`, `SubscriptionManager.syncCurrentEntitlementToFirestore`) may fire from `LasoApp.body` / `ContentView.onAppear` *before* the anonymous Auth callback completes.
  Result: the very first Firestore writes after a fresh install can hit Firestore with `request.auth == null` and get rejected by the rule `request.auth != null` (which is most rules per Pass 1 F5 / F22). The user sees nothing because errors are swallowed (`UserProfileStore.swift:192` `print` only). Their first onboarding submit may silently fail to write.
- **Why this exists:** Mixing closure-style `signInAnonymously` with structured concurrency elsewhere. The fact that subsequent calls go to `Task { ... }` means the Auth callback may complete after them.
- **Impact:**
  - First-write failures on first-launch onboarding — unobserved because errors are silent.
  - Combined with Pass 1 F3 (wrong bundle ID) and F5 (referral abuse), this means even fixing F3 leaves a TOCTOU window where new installs don't get their onboarding profile created.
- **Evidence:** `App/AppLaunchCoordinator.swift:27–33`:
  ```swift
  if Auth.auth().currentUser == nil {
      Auth.auth().signInAnonymously { _, error in
          if let error {
              PostHogManager.shared.captureError(error, context: "anonymous_auth")
          }
      }
  }
  // function returns here. Auth may not be ready yet.
  ```
- **How to verify fast:** Fresh install, watch console: any Firestore call within ~500ms of launch may print "permission denied". Or wrap each Firestore call site with `assert(Auth.auth().currentUser != nil)` and observe the assertion fire on first launch.
- **Fix:**
  1. Convert to async: `try await Auth.auth().signIn(withCustomToken: ...)` flavor — there is `Auth.auth().signInAnonymously()` async in Firebase 11.
  2. Make `configureOnLaunch` itself `async` and `await` the Auth call before kicking off RemoteConfig fetch / analytics.
  3. Or: gate every Firestore-write call site on `await waitForAuth()` (a helper that awaits a Combine publisher of `Auth.auth().authStateDidChangeListenerHandle`).
- **Priority:** This Week.
- **Confidence:** 88/100 — code read verbatim; race semantics follow standard async/closure interaction.

---

### F42. BGTask handler does no subscription-state check — runs ML pipeline + writes widget data for expired/lapsed users
- **Severity:** Low-Medium
- **Issue:** `App/BackgroundRefreshCoordinator.swift:67–139` handles `BGAppRefreshTask`. Inside, it (a) calls `liveViewModelFactory()` which calls `HealthKitManager.fetchAll`, (b) computes readiness, (c) writes `WidgetReadinessSnapshot` to the App Group store, (d) reloads widgets, (e) tracks PostHog analytics (`trackBackgroundRefreshResult`). **No check on `SubscriptionManager.shared.hasAccess`**. Expired users still:
  - Run the full ML pipeline in the background (battery + thermal cost).
  - Get widget data refreshed (subscription is supposed to gate Pro features per `FeatureGate.swift`, but BG refresh does not consult that).
  - Generate analytics events that contribute to PostHog billing (Pass 1 F2).
- **Why this exists:** Background task was wired before subscription gating was introduced; never re-audited.
- **Impact:**
  - Battery / thermal abuse for expired users (minor).
  - Expired users still see widget data updating — undermines paywall pressure.
  - PostHog event spam from churned users (small contributor to F2).
- **Evidence:** `App/BackgroundRefreshCoordinator.swift:67–139` — no `SubscriptionManager.shared.hasAccess` guard.
- **Fix:** At line 79 (entry of `workTask`), add:
  ```swift
  guard SubscriptionManager.shared.hasAccess else {
      task.setTaskCompleted(success: false)
      return
  }
  ```
  Reschedule via `schedule()` so when user re-subscribes, BG refresh resumes naturally.
- **Priority:** Later.
- **Confidence:** 88/100 — code read; behaviour predicted from the absence of the guard.

---

### F43. Siri Intent water/workout writes have no upper bound — accept arbitrarily large HealthKit samples
- **Severity:** Low
- **Issue:** `Core/Intents/IntentDataProvider.swift:153–169` — `logWater(liters: Double)` validates only `liters > 0`. No upper bound. A user (or a Siri vocabulary glitch — "log water 9999 liters") can write a sample of 9 999 000 milliliters into HealthKit. Same at `logWorkout` (line 175+) — `durationMinutes > 0` only. A Siri-misheard "log workout 100 hours" writes a 100-hour HKWorkout sample.
  Once written to HealthKit, the sample affects:
  - `dietaryWater` aggregations across the user's day-week-month dashboards in Apple Health.
  - The app's own water-intake analysis pipeline (poisons baselines used by `BaselineCalculator`).
  - Any other app reading dietary water from HealthKit (Lifesum, MyFitnessPal, etc.).
  HealthKit deletion is per-sample but the user has to find the rogue sample manually in Apple Health → Browse → Hydration → today.
- **Why this exists:** Siri intent author trusted the input.
- **Impact:** Low — requires user-driven misuse or Siri error. But polluting HealthKit baselines breaks the analysis pipeline silently.
- **Evidence:** `Core/Intents/IntentDataProvider.swift:153–169, 175+`.
- **Fix:**
  ```swift
  guard liters > 0, liters <= 5 else { return false }   // 5 L / day max
  guard durationMinutes > 0, durationMinutes <= 360 else { return false }  // 6 h max
  ```
- **Priority:** Later.
- **Confidence:** 95/100 — code read verbatim.

---

### F44. ShareButton image goes to UIActivityViewController without `excludedActivityTypes` — score images can be saved to Photos / iCloud Photos
- **Severity:** Low
- **Issue:** `Common/Components/ShareButton.swift:67–72` presents `UIActivityViewController(activityItems: [image], applicationActivities: nil)` with no `excludedActivityTypes`. The user can pick "Save Image" → goes to iOS Photos library → auto-syncs to iCloud Photos (depending on user setting) → visible in `~/Pictures/Photos Library.photoslibrary` on macOS.
  The shared image contains health score, score change, streak — embedded in the rasterized PNG. From Photos it's now searchable by Visual Lookup ("show me images with text — score 45"), backed up to iCloud, possibly synced to family-sharing iCloud accounts, and surfaced in iOS' "Memories" feature.
  Same issue with `Modules/Settings/Views/SettingsView.swift:757–758` for any other UIActivityViewController paths.
- **Why this exists:** Standard share sheet usage.
- **Impact:** Low — user-driven, but shared health images leak into iCloud Photos cohort, potentially family sharing.
- **Evidence:** `Common/Components/ShareButton.swift:67–72`.
- **Fix:** Set `activityVC.excludedActivityTypes = [.saveToCameraRoll, .copyToPasteboard, .assignToContact]` for health-card shares, narrowing to AirDrop, message, mail. Or surface a confirmation: "This image contains your health score. Where would you like to share?".
- **Priority:** Later.
- **Confidence:** 85/100 — code read; iCloud Photos auto-sync depends on user setting.

---

### F45. RemoteConfig values control product IDs, trial days, free-year mode — no integrity verification beyond TLS
- **Severity:** Low-Medium
- **Issue:** `Core/Subscriptions/SubscriptionConfig.swift:17, 21, 31` — `proYearlyProductID`, `proMonthlyProductID`, `proTrialDays` all read from `RemoteConfigManager.shared`. `Modules/Referral/Services/ReferralManager.swift:69` — `freeYearActive` from RemoteConfig disables the entire referral system. RemoteConfig payloads are TLS-protected but the **Firebase Remote Config admin console is the only authority**. A compromised Firebase admin (or a leaked admin SDK key — see Pass 1 F23) can:
  - Push `proTrialDays = 99999` → all users get effectively unlimited trial.
  - Push `proYearlyProductID = "wrong.id"` → `Product.products(for:)` returns empty → users can't purchase.
  - Push `freeYearActive = true` → referral disabled, 1-year free for all.
  - Push `analysisCriticalDeviationThreshold = 0` → every metric flagged as critical → spam insights and notifications.
  None of these values have a signature or version/revocation check. The app trusts whatever Firebase serves.
- **Why this exists:** Standard Firebase Remote Config trust model.
- **Impact:**
  - Revenue: immediate trial-extension exploit if admin is compromised.
  - User trust: spam insights from threshold push.
  - Reputation: a single admin password compromise = 100% user impact within 1 hour fetch interval.
- **Evidence:**
  - `Core/Subscriptions/SubscriptionConfig.swift:17, 21, 31` — RC reads.
  - `Modules/Referral/Services/ReferralManager.swift:69` — RC-controlled feature kill.
  - `Core/Config/RemoteConfigManager.swift:34` — 1-hour minimum fetch interval (production).
- **Fix:**
  1. Wrap critical product IDs in code defaults (`AppSecrets.swift`) and reject RC values that don't match a server-checked allowlist.
  2. Bound `proTrialDays` in client: `min(remoteValue, 30)`.
  3. Enable Remote Config conditions with App Check enforcement (Pass 1 F26) so RC requests must come from a real device.
  4. Add a sanity log: when RC values change, capture a PostHog event so a sudden change is visible in dashboards.
- **Priority:** Later.
- **Confidence:** 85/100.

---

### F46. UITestMode launch-flag check is in production hot paths — sideloaded IPA can flip score values, gender, force-subscribed
- **Severity:** Low (requires sideload, but broader than Pass 1 F20)
- **Issue:** Pass 1 F20 noted that `UITestMode.isEnabled` enables Pro-spoof for sideloaders. The bigger surface: `UITestMode.swift:88–145` exposes 17 launch arguments including `--ui-test-override-overall-score=99`, `--ui-test-override-name=...`, `--ui-test-female-profile`, `--ui-test-show-paywall`, `--ui-test-subscribed`, `--ui-test-initial-route=...`. ALL of these are `ProcessInfo.processInfo.arguments.contains(...)` checks in `Release` builds — there is no `#if DEBUG` guard around any of them.
  This means a sideloaded IPA (AltStore, Sideloadly, free Apple Dev account, TestFlight invite) can launch with any combination of these flags, bypassing:
  - Subscription paywall (`forceSubscribed`).
  - Onboarding (`shouldShowOnboarding=false`).
  - Disclaimer (`!showDisclaimer` → auto-acknowledge).
  - Profile validation (`overrideName`, `simulateFemaleProfile` — the latter triggers cycle-only flows).
  Any user comfortable with sideloading gets a full Pro experience without paying. App Store review build is unaffected (no flags in Release container) but TestFlight and direct-distribution builds inherit this surface.
- **Why this exists:** UI-test infrastructure was built for screenshot capture, not security.
- **Impact:**
  - Revenue leak via sideloaders (bounded by sideloading population — small but growing in EU under DMA).
  - Bypasses medical disclaimer acknowledgement → potential liability if sideloader self-harms based on uncalibrated scores.
- **Evidence:**
  - `App/UITestMode.swift:88–145` — all flag checks unconditional.
  - `App/UITestMode.swift:147–185` — `configureDefaults()` only checks `isEnabled` then proceeds.
  - `Core/Subscriptions/SubscriptionManager.swift:111–114` — only place with `#if DEBUG`-equivalent guard (`UITestMode.isEnabled` itself, which is the broken one).
- **Fix:**
  ```swift
  static var isEnabled: Bool {
      #if DEBUG
      return ProcessInfo.processInfo.arguments.contains(launchFlag)
      #else
      return false
      #endif
  }
  ```
  Or: AND with `Bundle.main.appStoreReceiptURL?.lastPathComponent != "sandboxReceipt"` and `Bundle.main.appStoreReceiptURL?.lastPathComponent != nil` — sandbox + sideload has no real receipt.
- **Priority:** This Week (one-line fix).
- **Confidence:** 95/100.

---

### F47. `SubscriptionManager.refreshStatus` has TOCTOU window — Transaction.currentEntitlements iterated, then async Firestore call, then trial check
- **Severity:** Low
- **Issue:** `Core/Subscriptions/SubscriptionManager.swift:177–225` — `refreshStatus()` is a long sequence of awaits:
  1. Iterate `Transaction.currentEntitlements` (line 179) — reads StoreKit cache.
  2. Check `isInBillingRetry()` (line 194) — async, reads StoreKit subscription status.
  3. Read UserDefaults grace state (line 205).
  4. `await fetchFirestoreSubscriptionStatus()` (line 218) — async network round-trip, can take 100–2000 ms.
  5. `resolveTrialStatus()` (line 224) — reads UserDefaults / Keychain.
  Between steps 1 and 4, **another Task can purchase, restore, or expire**. The `transactionListener` (line 425) is `Task.detached` (not isolated to MainActor); it calls `handleTransactionUpdate()` (line 434) which itself calls `refreshStatus()`. If two `refreshStatus()` calls race:
  - Call A reads StoreKit at step 1, finds subscription expired, falls through.
  - Call B sees a fresh transaction in `Transaction.updates`, calls `refreshStatus()`.
  - Call B finishes first, sets status = `.subscribed`.
  - Call A finishes (via Firestore round-trip), overwrites status = `.expired` because it operated on stale data.
  Net result: user just paid, sees the paywall for ~1 second until next refresh.
  Pass 1 F6 noted Firestore writes silently fail (no `subscriptions` rule). This is a separate, race-driven issue.
- **Why this exists:** Long async pipeline without serialization. `@MainActor` on the class serializes state writes but NOT the order of multiple in-flight `refreshStatus` calls.
- **Impact:**
  - User UX: brief paywall flash after purchase.
  - In edge cases (slow Firestore + fast transaction listener), user can be incorrectly downgraded to expired.
- **Evidence:** `Core/Subscriptions/SubscriptionManager.swift:177–225, 425–442`.
- **Fix:** Add a serializing actor or a `Task` queue in `SubscriptionManager`:
  ```swift
  private var refreshTask: Task<Void, Never>?
  func refreshStatus() async {
      refreshTask?.cancel()
      refreshTask = Task { ... existing logic ... }
      await refreshTask?.value
  }
  ```
- **Priority:** Later.
- **Confidence:** 78/100 — race window is real on paper; severity depends on Firestore latency. Untested at runtime.

---

### F48. NotificationCenter post `HealthPulseDidDeleteAllData` carries `object: nil` but listeners are unverified — any extension can listen
- **Severity:** Low
- **Issue:** `Modules/Settings/Views/SettingsView.swift:687` — `NotificationCenter.default.post(name: .init("HealthPulseDidDeleteAllData"), object: nil)`. `NotificationCenter.default` is **per-process**, so this doesn't cross extension boundaries directly — widget extension and main app are separate processes. But within the main app, ANY observer added via `NotificationCenter.default.addObserver(forName:)` receives this. Combined with `Core/Tracking/AppAnalytics.swift:2462` (screenshot observer) and other observers, a wild observer can trigger on the delete-all event (it doesn't carry sensitive payload, but the *event* itself is sensitive: "user just wiped data" is a churn signal that ends up in PostHog if any observer captures it).
  Pass 1 didn't flag NotificationCenter as a leak vector. Today's risk is low (no observer mishandles it), but the pattern is fragile.
- **Why this exists:** Standard notification bus pattern.
- **Impact:** Low — no PII payload today.
- **Evidence:** `Modules/Settings/Views/SettingsView.swift:687`.
- **Fix:** Use a typed singleton publisher (`@Observable` / Combine `PassthroughSubject`) instead of stringly-named NotificationCenter for in-app events. Reserves NotificationCenter for system events.
- **Priority:** Later.
- **Confidence:** 78/100.

---

### F49. Cycle / Journal SwiftData stores not declared in `NSPrivacyAccessedAPITypes` for required-reason API
- **Severity:** Low
- **Issue:** Apple's `Required Reason API` policy (effective May 2024) requires apps that use `UserDefaults`, `FileManager` timestamps, system boot time, etc. to declare `NSPrivacyAccessedAPITypes` in `PrivacyInfo.xcprivacy`. The app uses:
  - `UserDefaults.standard` extensively — requires `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` ("app functionality") or similar.
  - `FileManager.default.attributesOfItem` (likely indirectly via SwiftData) — requires `NSPrivacyAccessedAPICategoryFileTimestamp`.
  - `UIDevice.current.identifierForVendor` (`Modules/Onboarding/Views/Onboarding/ProfileCaptureView.swift:147`) — requires `NSPrivacyAccessedAPICategorySystemBootTime`? No — IDFV does not require it, but the use should be declared in `NSPrivacyTrackingDomains` if used for tracking.
  Pass 1 read `PrivacyInfo.xcprivacy:6` (NSPrivacyTracking) but did NOT verify `NSPrivacyAccessedAPITypes` is populated.
- **Why this exists:** Apple introduced the requirement late 2024; team may not have updated.
- **Impact:**
  - **App Store rejection on May 2024+ submissions**. Apple's automated check rejects builds missing the required-reason declarations.
  - Today's status unknown — would need to read the full `PrivacyInfo.xcprivacy` (Pass 1 only quoted line 6).
- **Evidence:** Pass 1 F8 quoted only line 6 of `PrivacyInfo.xcprivacy`. The rest of the file's `NSPrivacyAccessedAPITypes` was not audited.
- **Fix:** Read full `PrivacyInfo.xcprivacy`. Ensure entries:
  - `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`.
  - `NSPrivacyAccessedAPICategoryFileTimestamp` reason `C617.1`.
  - `NSPrivacyAccessedAPICategorySystemBootTime` reason `35F9.1` if used.
  - `NSPrivacyAccessedAPICategoryDiskSpace` reason `E174.1` if used.
- **Priority:** Now (App Store submission gate).
- **Confidence:** 65/100 — Pass 1 didn't fully read this file; this is a *suspected* gap pending full verification.

---

## Sub-areas where Pass 1 was already exhaustive
- **Hardcoded staging/dev URLs** — none found in compile sources beyond the documented production URLs (lasohealth.fit/terms, lasohealth.fit/privacy, eu.i.posthog.com, jsdelivr CDN). Pass 1 F27 covered jsdelivr. No `localhost:3000`, `staging.firebaseio.com`, `dev-firestore` anywhere. Clean.
- **WebView / WKWebView usage** — confirmed empty grep across all source dirs. No `WKWebView`, `SFSafariViewController`, no `javaScriptEnabled` toggling. The only HTML output is the `WebExport` static-file flow which I covered in F35. No in-app browser exists today.
- **Pasteboard reads (`UIPasteboard.general`)** — confirmed empty across all source dirs. Pass 1 didn't need to flag because there's nothing to flag. Clean.
- **WatchConnectivity / WCSession** — only one mention (`Core/Notifications/WatchMonitor.swift:273`) in a comment ("WatchConnectivity would be needed for reliable battery monitoring"). No active session. Clean.
- **Apple Pay / PassKit** — confirmed empty grep. No PKPayment surfaces. Clean.
- **Universal Links / `application(_:open:)`** — Pass 1's check stands; nothing new to add.
- **Crypto algorithm choice** — `EncryptedStore` uses AES-GCM 256-bit (correct, modern AEAD). SubscriptionManager uses SHA256 over `(timestamp:vendorID:salt)` — fine for tamper detection, though the salt `"com.lasohealth.trial"` is hardcoded so an attacker who reverse-engineers the binary can forge a hash given a chosen install date. Worth noting but Pass 1 F11 already flagged jailbreak / integrity is logging-only, so the concern is academic. Algorithm itself is clean.

## Summary table (severity counts of NEW findings only)

| Severity     | Count | IDs |
|--------------|-------|-----|
| High         | 4     | F31, F32, F33, F34 |
| Medium-High  | 1     | F35 |
| Medium       | 5     | F36, F37, F38, F39, F40 |
| Medium       | 1     | F41 |
| Low-Medium   | 2     | F42, F45 |
| Low          | 5     | F43, F44, F46, F47, F48 |
| Low (verify) | 1     | F49 |
| **Total**    | **19**| F31–F49 |

**Top 5 new findings to fix Now / This Week:**
1. **F34** — `ITSAppUsesNonExemptEncryption=false` is incorrect. App Store export-compliance lie. One-line plist fix + ERN form. Unblocks future submissions.
2. **F31** — Async-signal-unsafe PostHog signal handler. Silently corrupts crash reporting for SIGSEGV-class crashes. Must be replaced with sig_atomic_t flag or removed.
3. **F32 + F33** — Referral redemption double-tap race + side-channel oracle in error strings. Compounds Pass 1 F5. Move to Cloud Function with rate-limited attempt, single generic error string.
4. **F46** — UITestMode flags ungated in Release. One-line `#if DEBUG` fix. Closes the broader Pro-bypass surface for sideloaders beyond Pass 1 F20.
5. **F49** — `NSPrivacyAccessedAPITypes` likely missing in PrivacyInfo. App Store rejection gate. Verify and patch.

**Verification still pending (could not run from sandbox):**
- Build a Release IPA, run `strings` to confirm Info.plist `ITSAppUsesNonExemptEncryption=false` is the value the binary ships with.
- Boot simulator, fire Live Activity, photograph lock-screen surface to confirm F36's HRV-on-lockscreen claim.
- Read full `PrivacyInfo.xcprivacy` (only line 6 was quoted in Pass 1) to confirm/refute F49.
- Run a referral-code probing loop against Firestore emulator to confirm F33's oracle.
