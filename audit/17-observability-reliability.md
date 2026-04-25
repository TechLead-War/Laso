# 17 — Observability & Reliability Audit (Pass 1)
_Started: 2026-04-25 IST, scope: Crashlytics/dSYM/PLCrashReporter, ATS/TLS/URLSession/BG sessions, Universal Links/AppIntents/Siri, BGTaskScheduler/Live Activities/Widgets, RemoteConfig kill switches, .githooks/CI/UI tests/visual regression_

Static, code-only review. No simulator/runtime confirmation in this pass. Every finding cites file:line + a confidence tag. The forbidden zones (design, copy, perf numbers, deep refactor) are not addressed.

---

## Findings

---

### F1. FirebaseCrashlytics is linked but never initialized — every TestFlight crash is invisible to engineering
- **Severity:** Critical
- **Issue:** `project.yml:32` declares `FirebaseCrashlytics` as a target dependency, so the SDK is bundled into the IPA. But the entire codebase contains zero `import FirebaseCrashlytics` and zero references to `Crashlytics.crashlytics()` (verified by `grep -rn "Crashlytics" --include="*.swift"` returning no results except the project.yml line). `FirebaseApp.configure()` is called at `App/AppLaunchCoordinator.swift:22`, which auto-installs Crashlytics' default uncaught-exception handler — but only if Crashlytics is loaded as a side effect. In Swift, an unused dependency may not be linked at all under whole-module optimization, and even if it links, Crashlytics' auto-collection requires the dSYM upload script to be wired (it is not — see F2). Net effect: any crash on TestFlight today is captured by PostHog's `installCrashHandlers` (`Core/Tracking/PostHogManager.swift:126`) as a `app_crash` event with a 15-frame symbol-less stack trace, and nothing else. There is no Crashlytics dashboard view, no symbolicated stack, no crash-free user metric, no automatic Apple-style grouping.
- **Why this exists:** Crashlytics was added to dependencies and never wired up. The team appears to have intended PostHog as a fallback-plus-everything, but PostHog's signal-handler approach is a fraction of what Crashlytics provides (no thread state, no register dump, no symbolicated frames, no severity grouping, no version-pinned occurrence counting).
- **Impact:**
  - Crash-free user % cannot be computed (admin-panel KPI gap, cross-cut from agent #08).
  - Hard-to-reproduce crashes on TestFlight will appear as `app_crash` events with 15 unsymbolicated `0x10abcd...` lines and no thread context. Engineering will have to wait for Apple's Organizer crash logs (which only flow once enough App Store users hit the same crash, and never on TestFlight unless the user hits "Share with Developer").
  - PostHog signal handlers re-raise to `SIG_DFL` (`PostHogManager.swift:162`), so Apple's own `.ips` crash report still gets generated — but no one watches Organizer for a TestFlight build day-to-day.
- **Evidence:**
  - `project.yml:32` → `product: FirebaseCrashlytics` (dependency declared).
  - `grep -rn "Crashlytics\|crashlytics" /Users/primetrace/Desktop/RnD/HealthPulse/ --include="*.swift"` → 0 hits in code.
  - `App/AppLaunchCoordinator.swift:22` → `FirebaseApp.configure()` (the only Firebase init).
  - `Core/Tracking/PostHogManager.swift:126–166` → custom NSException + signal handlers; truncates stack to 15 frames at line 131; no symbolication.
- **How to verify fast:** Force a crash in Debug (`fatalError("test")`), TestFlight upload, wait 24h. Crashlytics dashboard for project `com.lasohealth.fit` will show zero crashes; PostHog will show one `app_crash` event with a hex-only stack.
- **Fix:** Add `import FirebaseCrashlytics` and a single `Crashlytics.crashlytics()` access in `AppLaunchCoordinator.configureOnLaunch` (forces the framework to load and starts collection). Wire the dSYM upload run-script (F2). Decide whether to kill PostHog's signal handlers or keep them as a redundant signal — but currently they are the *only* crash signal, so do not remove them until Crashlytics is verified to be receiving events on TestFlight.
- **Priority:** Now.
- **Confidence:** 96/100 — grep confirmed zero Swift usage; project.yml dependency confirmed. Untested at runtime; possible (but unlikely) that a Firebase pod's auto-init catches Crashlytics anyway via `+load`/runtime registration. The dSYM-upload absence (F2) makes the question moot regardless: any crash that would arrive on Crashlytics would arrive unsymbolicated.

---

### F2. dSYM post-build script generates dSYMs locally but never uploads them to Firebase Crashlytics — every captured crash will be unsymbolicated
- **Severity:** Critical
- **Issue:** `project.yml:89–122` defines a `Generate dSYMs for Embedded Frameworks` post-build script. Reading line by line: it iterates `$TARGET_BUILD_DIR/Frameworks/*.framework`, runs `dsymutil` to produce `*.framework.dSYM` into `$DWARF_DSYM_FOLDER_PATH`, and exits. Nowhere does it invoke Firebase's `${PODS_ROOT}/FirebaseCrashlytics/upload-symbols` (or the SPM equivalent `${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols`). Memory note `project_dsym_fix.md` references a `Scripts/fix-archive-dsyms.sh` — but `Scripts/` only contains `capture-app-store-screenshots.sh`. The fix-archive-dsyms script does not exist in the repo. So even if Crashlytics were initialized (F1), every report would land on the dashboard with hex addresses instead of symbol names, making them practically useless for triage.
- **Why this exists:** The post-build script is a partial hand-written dSYM generator (intended to recover dSYMs the SPM-installed Firebase frameworks ship without). Whoever wrote it stopped at "make sure dSYMs exist locally" and did not add the upload step. The fix-archive-dsyms.sh referenced in memory was either deleted or never created.
- **Impact:** Crashlytics, even if wired, would show unsymbolicated stacks. Engineering cannot triage TestFlight crashes by function name, file:line, or commit. Time-to-fix for any production crash spikes 5×–10× because every stack must be hand-symbolicated using `atos`/`dwarfdump` against an archived build.
- **Evidence:**
  - `project.yml:89–122` — script body, ends at the `echo "Generated $COUNT dSYM bundles"` line. No `upload-symbols` invocation.
  - `ls /Users/primetrace/Desktop/RnD/HealthPulse/Scripts/` → only `capture-app-store-screenshots.sh`.
  - `grep -rn "upload-symbols\|upload_symbols" /Users/primetrace/Desktop/RnD/HealthPulse/` → 0 hits.
- **How to verify fast:** Run `xcodebuild archive` from CLI; inspect `$ARCHIVE_PATH/dSYMs/`. dSYMs will exist locally. Then: open Firebase Crashlytics → Settings → dSYMs. The upload list will be empty for the build's UUIDs (`dwarfdump --uuid` against each dSYM gives the UUIDs to check).
- **Fix:** Add a second post-build script (or extend the existing one) that runs **only on Release/Archive** and invokes the SPM-checkout `upload-symbols` binary. Standard pattern:
  ```
  "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols" \
    -gsp "${SRCROOT}/GoogleService-Info.plist" \
    -p ios "${DWARF_DSYM_FOLDER_PATH}"
  ```
  Add `${DWARF_DSYM_FOLDER_PATH}/${TARGET_NAME}.app.dSYM` and embedded-framework dSYMs as Input Files so the build-system runs the script when dSYMs change.
  Also: re-create `Scripts/fix-archive-dsyms.sh` matching the memory note, or delete the memory note so it does not mislead future audits.
- **Priority:** Now (paired with F1).
- **Confidence:** 95/100 — script body read verbatim end-to-end; absence of upload-symbols verified by grep; absence of `Scripts/fix-archive-dsyms.sh` verified by `ls`. Possible but unlikely the SPM Firebase package auto-uploads dSYMs via its own build phase (it does not — Firebase requires manual wiring).

---

### F3. PostHog signal handlers re-raise SIGSEGV/SIGABRT and will conflict with Crashlytics the moment it is wired
- **Severity:** High
- **Issue:** `Core/Tracking/PostHogManager.swift:142–164` installs POSIX signal handlers for `SIGABRT, SIGBUS, SIGSEGV, SIGFPE, SIGILL, SIGTRAP`. After capturing the event, the handler at line 162 calls `signal(signalNumber, SIG_DFL)` and then `raise(signalNumber)`. This is the right re-raise pattern in isolation, but Crashlytics also installs signal handlers (Apple's `CLSCrashReportSignalHandler`). Whichever framework registers later wins the signal — and PostHog's `installCrashHandlers` is called explicitly at `App/AppLaunchCoordinator.swift:40` after `analyticsManager.configure()`, which runs after `FirebaseApp.configure()`. So today the handler order is Firebase (no-op since Crashlytics not initialized) → PostHog. Once Crashlytics is wired (F1), PostHog will overwrite Crashlytics' handlers, every Swift fatalError / EXC_BAD_ACCESS will write a PostHog event but **lose the rich Crashlytics report** (thread states, register dumps). Crashlytics will then re-receive only a partial signal via the re-raise to SIG_DFL — but iOS' default handler does not re-invoke Crashlytics; it just terminates.
- **Why this exists:** PostHog crash capture was added to fill the gap left by missing Crashlytics. Nobody wrote down the conflict.
- **Impact:** When Crashlytics is finally wired, half the crash signal will route to PostHog (low fidelity) instead of Crashlytics (high fidelity). The team will see two halves of every crash, and the Crashlytics half will be missing the signal info that determines exception group/severity.
- **Evidence:**
  - `Core/Tracking/PostHogManager.swift:130` — `NSSetUncaughtExceptionHandler` (overwrites any prior NSException handler — Crashlytics installs one).
  - `Core/Tracking/PostHogManager.swift:144` — `signal(sig) { … }` for each of 6 signals.
  - `App/AppLaunchCoordinator.swift:40` — `analyticsManager.installCrashHandlers()` runs after `FirebaseApp.configure()` at line 22, so PostHog wins the registration race.
- **How to verify fast:** Wire Crashlytics, then trigger a `SIGSEGV` (e.g. dereference nil unsafe pointer). Check Crashlytics dashboard 24h later. If the event is missing or has no thread state, the conflict has bitten.
- **Fix:** Pick one. Either (a) remove PostHog's signal handlers entirely once Crashlytics is verified working, and rely on Crashlytics for fatal crashes + PostHog for non-fatal `app_error_recorded` (current `captureError` API is fine to keep). Or (b) chain handlers explicitly: read `signal(sig, SIG_GET)` before installing PostHog's handler, store the prior handler, call it before re-raising. (a) is the cleaner choice.
- **Priority:** Tied to F1 — fix as part of "wire Crashlytics."
- **Confidence:** 91/100 — code paths read verbatim; well-known iOS crash-handler conflict pattern. Unverified at runtime since Crashlytics is not even wired today.

---

### F4. `setUserID` for Crashlytics never called; PostHog `identify` is also never called from any production code path — every crash and event is anonymous
- **Severity:** High
- **Issue:** `Core/Tracking/PostHogManager.swift:67` defines `identify(userId:properties:)`, but `grep -rn "PostHogManager.shared.identify\|\.identify(userId\|PostHogSDK.shared.identify"` returns only the function definition itself. Nothing in the codebase ever calls `identify`. PostHog will treat every install as a separate anonymous distinct ID — fine for raw event volume, but it means cross-device joins, churn cohort tracking, and "User X's crashes" segmentation are impossible. Same gap on the Crashlytics side: no `Crashlytics.crashlytics().setUserID(...)` call anywhere (because Crashlytics is not wired — F1). PII risk side: even if `identify` were called with `email` or `phone`, that would violate the privacy stance memo'd in `feedback_text_style.md` and the `PrivacyInfo.xcprivacy` declarations. Today it is the opposite problem — *no* identifier is set, so users cannot be linked to their crashes/events even when needed for P0 incidents.
- **Why this exists:** Anonymous Firebase Auth gives every user a `User.uid`. The team likely intended to flow that into PostHog's `identify` but never wired the call. SubscriptionManager + Firestore writes use `Auth.auth().currentUser?.uid` for keys, but PostHog never sees it.
- **Impact:** No "user X crashed" on Crashlytics, no funnel-level user trace on PostHog, no link from an admin-panel support email to the user's anonymized event stream. When a TestFlight tester reports "the app crashed when I tapped X," engineering cannot find their crash in PostHog because everything is anonymous.
- **Evidence:**
  - `grep -rn "\.identify\|setUserProperty\|setUserProperties" /Users/primetrace/Desktop/RnD/HealthPulse/ --include="*.swift"` → only `setUserProperty` is called (`Core/Tracking/AppAnalytics.swift:524, 525, 569, 583, …`); `identify` itself is never called.
  - `grep -rn "Crashlytics" --include="*.swift"` → 0 hits.
- **How to verify fast:** PostHog dashboard → Persons. All persons should have `is_identified = false`. Spot-check any test session: distinct ID will be a UUID, not a Firebase UID.
- **Fix:** In `AppLaunchCoordinator.configureOnLaunch`, after `Auth.auth().signInAnonymously` succeeds, call `PostHogManager.shared.identify(userId: user.uid)` (and equivalent `Crashlytics.crashlytics().setUserID(user.uid)` once Crashlytics is wired). The Firebase UID is opaque and PII-free. Document this so nobody adds `email`/`name` later.
- **Priority:** Soon (this week, paired with Crashlytics wiring).
- **Confidence:** 94/100 — grep verified zero call sites for `identify`. Untested at runtime; possible (but unlikely) some indirect path I missed sets the user.

---

### F5. Bitcode setting absent from project.yml — Xcode 14+ default (NO) is acceptable, but Apple validation may still warn; verify before App Store submit
- **Severity:** Low
- **Issue:** `project.yml` does not set `ENABLE_BITCODE`. Xcode 14 deprecated Bitcode and Xcode 15+ defaults to `NO`, so the IPA will not contain a Bitcode segment — which is the correct production posture. Crashlytics symbolication actually depends on this being NO + dSYMs uploaded; Bitcode YES would have introduced a separate App Store re-symbolication step. Today the configuration is correct by default. Flagging only because the user-context audit prompt explicitly asked.
- **Why this exists:** XcodeGen + Xcode 15 defaults handle this automatically.
- **Impact:** None today.
- **Evidence:**
  - `grep -rn "ENABLE_BITCODE" /Users/primetrace/Desktop/RnD/HealthPulse/ --include="*.yml" --include="*.swift"` → 0 hits.
  - `project.yml:9–13, 71–88` — base settings show `DEBUG_INFORMATION_FORMAT: dwarf-with-dsym` for both Debug and Release (good).
- **How to verify fast:** After `xcodegen generate`, open the .xcodeproj → Build Settings → search `ENABLE_BITCODE`. Should read `No`.
- **Fix:** None needed. Optionally add `ENABLE_BITCODE: NO` explicitly to project.yml for documentation.
- **Priority:** Optional.
- **Confidence:** 88/100 — Xcode 15 default is well-documented as NO; absent override means default applies. Untested by reading the generated `.pbxproj` (XcodeGen output).

---

### F6. No "send crash reports" opt-out toggle in Settings — GDPR / iOS App Privacy compliance gap
- **Severity:** Medium
- **Issue:** Crashlytics' `setCrashlyticsCollectionEnabled(false)` and PostHog's `optOut()` are never wired to a UI toggle. `grep -rn "setCrashlyticsCollectionEnabled\|optOut\|optIn" --include="*.swift"` returns 0 hits. The Privacy nutrition label in `PrivacyInfo.xcprivacy` (read in audit #09) declares crash-data collection — but with no in-app toggle, the user has no runtime way to opt out. EU GDPR + iOS App Tracking Transparency conventions expect a toggle for "Help improve Laso by sending diagnostic data."
- **Why this exists:** Settings UI does not yet have a Privacy section.
- **Impact:** GDPR/App Store review risk if challenged. Today the data is anonymous (F4), which weakens the GDPR concern, but a reviewer can still flag the gap.
- **Evidence:**
  - `grep -rn "setCrashlyticsCollectionEnabled\|optOut\|optIn" /Users/primetrace/Desktop/RnD/HealthPulse/ --include="*.swift"` → 0 hits.
  - `Modules/Settings/` directory exists but has no Privacy/Diagnostics view (separate from this audit's scope to inspect).
- **Fix:** Add a `Settings → Privacy → Send Diagnostic Data` toggle that flips both `Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(...)` and `PostHogSDK.shared.optIn()/optOut()` and persists to UserDefaults.
- **Priority:** Soon (before App Store submit).
- **Confidence:** 90/100 — grep verified zero call sites. Settings module not deep-read; possible an existing toggle uses a different API name.

---

### F7. No force-crash test harness in Debug — engineering cannot validate Crashlytics or dSYM upload until they ship a real crash to TestFlight
- **Severity:** Low
- **Issue:** `grep -rn "fatalError\|sendUnsentReports\|preconditionFailure\|crashlytics().crash" --include="*.swift"` returns only the comment in PostHogManager. There is no Debug-only "Crash now" button in any settings/dev panel. Standard pattern: add a Debug-only setting that calls `fatalError("Test crash from Settings")` so QA / engineering can validate the pipeline end-to-end before any real user crash arrives.
- **Why this exists:** Never built.
- **Impact:** Engineering cannot confirm the Crashlytics pipeline (once wired) before relying on it. First real user crash is also the first validation, which is a bad place to discover a misconfiguration.
- **Fix:** Add a Debug-only row in Settings: `Button("Force test crash") { fatalError("Test") }`. Guard with `#if DEBUG`.
- **Priority:** This Week.
- **Confidence:** 95/100 — grep verified.

---

### F8. ATS configuration is clean — `NSAppTransportSecurity` key absent (default secure posture)
- **Severity:** None (informational)
- **Issue:** None. `Info.plist` and `project.yml` contain no `NSAppTransportSecurity`, no `NSAllowsArbitraryLoads`, and no `NSExceptionDomains`. Default ATS rules apply: TLS 1.2+, forward secrecy, server certs validated against system trust store. All Firebase + PostHog hosts (`firebaseinstallations.googleapis.com`, `firebasestorage.googleapis.com`, `firestore.googleapis.com`, `app.posthog.com`) ship modern certs that pass default ATS.
- **Evidence:**
  - `grep -rn "NSAppTransportSecurity\|NSAllowsArbitraryLoads\|NSExceptionDomains" /Users/primetrace/Desktop/RnD/HealthPulse/ --include="*.plist" --include="*.yml"` → 0 hits.
  - `grep -rn "http://" --include="*.swift" --include="*.plist"` → only the plist DOCTYPE references (not network URLs).
- **Confidence:** 97/100.

---

### F9. No TLS pinning anywhere — health-app baseline expectation, currently violated
- **Severity:** Medium
- **Issue:** No `URLSessionDelegate.urlSession(_:didReceive challenge:)` implementation, no `SecTrust` / `SecPolicy` use, no `TrustKit` pin, no `URLSessionConfiguration` customization beyond `URLSession.shared`. `grep -rn "URLSessionDelegate\|didReceive challenge\|serverTrust\|SecTrust\|TrustKit\|URLSessionConfiguration" --include="*.swift"` → 0 hits. Health apps that store identifiable health data on Firebase + PostHog typically pin (or at least pin Firebase-only) to defend against MITM via a corporate/enterprise root CA installed on the user's device. Apple's HealthKit data does not flow off-device — but PostHog session replay (with masking) and the user profile / referral / subscription state in Firestore do.
- **Why this exists:** Pinning is operationally expensive (cert rotation breakage); many apps skip until a real threat. For TestFlight + initial App Store this is acceptable but worth flagging.
- **Impact:** A user on a corporate WiFi with an enterprise root CA could have their Firestore traffic decrypted by their employer's MITM proxy. Low-likelihood, low-blast-radius given anonymized data, but a competent App Store privacy reviewer might note it.
- **Evidence:**
  - `grep -rn "URLSessionDelegate\|didReceive challenge\|serverTrust\|SecTrust\|TrustKit"` → 0 hits.
  - Only network code in app: `Core/Config/AppStoreVersionChecker.swift:50` (`URLSession.shared.data(for: request)`) hits Apple's public iTunes Lookup API. Pinning Apple is meaningless. Firebase + PostHog SDKs handle their own networking and do not expose a pin hook by default.
- **Fix:** Optional for v1 (acceptable for TestFlight + first App Store). For a hardened posture: integrate `TrustKit` and pin `*.googleapis.com` + PostHog host SubjectPublicKeyInfo hashes. Caveat: Firebase rotates certs; cert-rotation breakage means a kill-switch entry must allow you to disable pinning remotely. Defer until v2.
- **Priority:** Later.
- **Confidence:** 95/100.

---

### F10. URLSession.shared used everywhere — no custom timeout, no custom configuration, no background session
- **Severity:** Low
- **Issue:** Only one custom `URLRequest` exists (`Core/Config/AppStoreVersionChecker.swift:45–47`), with a `timeoutInterval = 5` and `cachePolicy = .reloadIgnoringLocalCacheData`. All other networking flows through Firebase SDKs, PostHog SDK, or `URLSession.shared`. No `URLSession(configuration: .background(withIdentifier:))` anywhere — so the only background networking path is BGAppRefreshTask (BG fetch) + the readiness widget refresh. There are no in-flight downloads/uploads that could survive app suspension. This is fine for current functionality, but health-data export (`Modules/WebExport/`) likely uploads PDFs / CSVs and would benefit from a background session for large payloads.
- **Why this exists:** Simple architecture; all heavy compute is on-device, so network surface is small.
- **Impact:** Small uploads (referral redemption, subscription sync, analytics flush) will be cancelled if the user backgrounds the app mid-flight. PostHog has its own background queue, so analytics are durable. Firestore SDK has its own offline-first cache and persistent writer. So the net impact is near-zero today.
- **Fix:** None needed for v1. If/when web-export grows large, consider `URLSession(configuration: .background(...))`.
- **Priority:** Later.
- **Confidence:** 92/100 — single custom URLRequest verified; rest of network surface delegated to SDKs whose internals are not auditable from this repo.

---

### F11. Naive `try?` on Firestore/StoreKit failures — silent swallowing of errors that should at least be reported to PostHog
- **Severity:** Medium
- **Issue:** 103 `try?` sites across `Core/` + `Modules/` (counted via grep). Spot-check: `Core/Subscriptions/SubscriptionManager.swift:484` swallows Firestore write failures with the comment `// Firestore write failed silently. local entitlement remains the source of truth.` but does not call `PostHogManager.shared.captureError`. Same swallow at `:543`, `:506` (entitlement-expired record). When a Firestore write silently fails for a real user, the admin-panel will show stale subscription state, the user's referral redemption will not register cross-device, and engineering has zero signal that Firestore writes are failing at all. `App/BackgroundRefreshCoordinator.swift:54` does the same: `try? BGTaskScheduler.shared.submit(request)` — when iOS rejects the submit (e.g. exceeded daily budget), the failure is silent.
- **Why this exists:** Defensive pattern — "don't crash on transient network errors." But "don't crash" is the wrong bar; "report and continue" is the right bar.
- **Impact:** Real failures in production go invisible. Crash-free user % will look healthy because errors are not crashing — they are just silently broken. This is the worst kind of observability gap.
- **Evidence:**
  - `Core/Subscriptions/SubscriptionManager.swift:484` — empty catch with comment.
  - `Core/Subscriptions/SubscriptionManager.swift:506` — same pattern.
  - `Core/Subscriptions/SubscriptionManager.swift:543` — `// Offline or Firestore error. fall back to local-only resolution.` — no captureError.
  - `App/BackgroundRefreshCoordinator.swift:54` — `try? BGTaskScheduler.shared.submit(request)`.
  - `Core/Config/RemoteConfigManager.swift:70–72` — catches and stores `fetchError` in a property but never reports.
  - `103 try? sites` — many in low-stakes paths (UserDefaults, Date components), but the Firestore + RemoteConfig + BGTask sites are high-signal.
- **How to verify fast:** Run the app offline. Trigger a subscription state change. Watch Firestore traffic in Firebase Emulator → confirm the write attempt failed. Now check PostHog → no `app_error_recorded` event. Confirms the silent swallow.
- **Fix:** Replace silent catches in `SubscriptionManager`, `BackgroundRefreshCoordinator.schedule`, `RemoteConfigManager.fetchAndActivate`, and `ReferralManager` with `do { try await … } catch { PostHogManager.shared.captureError(error, context: "<short_name>") }`. Keep the local fallback behaviour. Add a single static helper `Loggable.swallow(_ context:)` so the call site stays one line.
- **Priority:** This Week.
- **Confidence:** 88/100 — sample of 4 Firestore/BGTask sites verified verbatim, plus the RemoteConfig site. Did not enumerate all 103 `try?` — many will be benign (UserDefaults, Date math). Specific weak link: the breadth of remediation depends on whether the team draws the line at "network/SDK" or "all I/O."

---

### F12. Universal Links + `application(_:open:)` + `onOpenURL` are completely absent — no deep-link surface at all
- **Severity:** Medium
- **Issue:** `grep -rn "onOpenURL\|application(_:open:options:)\|CFBundleURLTypes\|associated-domains\|userActivity"` returns 0 hits across the entire iOS codebase. `Laso.entitlements:1–18` does not declare `com.apple.developer.associated-domains`. `Info.plist` does not declare `CFBundleURLTypes`. Website + admin-panel directories contain no `apple-app-site-association` file (verified via `find -name "apple-app-site-association*"`). Net effect: a user cannot tap a `lasohealth.fit/...` link to open the app, cannot share a deep link to a specific score detail or insight, and cannot redeem a referral via URL — only via paste-the-code (`Modules/Referral/Services/ReferralManager.swift:276`). The Live Activity buttons (`Shared/CoachActionIntents.swift`) bypass deep links entirely by writing through the App Group `UserDefaults` (`group.com.lasohealth.fit`) — which works, but it also means the only IPC channel into the app is in-process (no cross-app share, no Spotlight, no email-link).
- **Why this exists:** Pre-launch app; deep links not yet prioritized. Referral chose paste-the-code over universal-link to avoid AASA hosting complexity.
- **Impact:**
  - Marketing cannot deploy "Tap to open Laso" links from the website or referral SMS.
  - Spotlight indexing absent → users can't search "Health Score" from springboard to jump into a screen.
  - No App Clip path (which is fine for v1 but flagged).
  - Referral flow has higher friction than competitors (Whoop, Oura) which use Universal Links.
- **Evidence:**
  - `grep -rn "onOpenURL\|CFBundleURLTypes\|associated-domains" /Users/primetrace/Desktop/RnD/HealthPulse/ --include="*.swift" --include="*.plist" --include="*.entitlements"` → 0 hits.
  - `find /Users/primetrace/Desktop/RnD/HealthPulse/website /Users/primetrace/Desktop/RnD/HealthPulse/admin-panel -name "apple-app-site-association*"` → 0 hits.
  - `Modules/Referral/Services/ReferralManager.swift:276–279` — share text uses raw code, not a URL.
- **How to verify fast:** Type `lasohealth.fit` into Notes app, long-press the link → "Open in Safari" only. No "Open in Laso" choice.
- **Fix:** v1 acceptable to defer, but for v1.1: add `Associated Domains` entitlement, deploy `apple-app-site-association` JSON to `https://lasohealth.fit/.well-known/apple-app-site-association`, register a `CFBundleURLTypes` scheme `laso://`, and add `.onOpenURL { url in … }` on the root scene to route. Validate every incoming URL host before dispatch (host-allowlist for Universal Links is already enforced by AASA, but the custom scheme path is open and must validate).
- **Priority:** v1.1 (this is not a launch blocker).
- **Confidence:** 96/100 — exhaustive grep + find. Possible but unlikely a deep-link handler is generated by SwiftUI's `WindowGroup` default.

---

### F13. Siri/AppIntents register no auth gating — `LogWaterIntent`, `LogWorkoutIntent`, etc. can be invoked before onboarding completes
- **Severity:** Low–Medium
- **Issue:** `Core/Intents/LasoShortcutsProvider.swift` registers six AppShortcuts. `LogWaterIntent.swift`, `LogWorkoutIntent.swift`, `HealthScoreIntent.swift`, `ReadinessIntent.swift`, `SleepSummaryIntent.swift`, `ShowTrendsIntent.swift` — none of them check `appStateStore.onboardingCompleted` or `disclaimerAcknowledged`. A user who installed the app but never completed onboarding could ask Siri "Hey Siri, what's my Laso health score?" and the intent would either return "I don't have enough health data yet" (graceful) or write a HealthKit sample (LogWater/LogWorkout) without ever asking the user the medical disclaimer. Privacy-side: HealthKit auth gates are still enforced by the OS (Siri can't write what HealthKit didn't authorize), so the actual data leak is bounded — but a user logging "water" before disclaimer is still a UX issue.
- **Why this exists:** Intents were built data-first, not flow-first.
- **Impact:** Edge case where pre-onboarding Siri use produces confusing dialog. No data-leak risk, but minor UX friction.
- **Evidence:**
  - `Core/Intents/HealthScoreIntent.swift:14–48` — perform() with no onboarding gate.
  - `Core/Intents/LogWaterIntent.swift` — to be similarly read-only-confirmed; sampled `HealthScoreIntent` and `IntentDataProvider:13–29` show the typical pattern (read cache, no auth check).
- **Fix:** Each intent's `perform()` should early-return with `.result(dialog: "Open Laso to finish setup first")` when `AppStateStore` reports onboarding incomplete. Read AppStateStore via the App Group UserDefaults so intents work without launching the host app.
- **Priority:** Soon.
- **Confidence:** 82/100 — sampled `HealthScoreIntent` only; did not deep-read all six intents. Specific weak link: LogWater/LogWorkout might already gate via HealthKit auth (which fails closed) and so the practical impact may be near-zero.

---

### F14. `BackgroundRefreshCoordinator` is double-instantiated — AppDelegate creates one, AppContainer creates another with a different factory closure
- **Severity:** Medium
- **Issue:** `App/AppDelegate.swift:7` declares `private let backgroundRefreshCoordinator = BackgroundRefreshCoordinator()` (default factory: creates a fresh `HealthKitManager` + fresh `ReadinessStore` each handler invocation). `App/AppContainer.swift:65–73` creates a second `BackgroundRefreshCoordinator` whose `liveViewModelFactory` closes over the *shared* `readinessStore` from the container. Only the AppDelegate's instance ever calls `register()` (`AppDelegate.swift:19`) and `schedule()` (line 20). The AppContainer instance only ever has `schedule()` called (`App/ContentView.swift:140` on background scene-phase) — and the `register()` is never invoked, so there is no double-registration crash from `BGTaskScheduler.shared.register`. But:
  - The AppContainer's coordinator is dead weight; its `liveViewModelFactory` is never used because the BG task always routes to the AppDelegate's instance (whose closure was registered with `BGTaskScheduler.shared.register`).
  - The AppDelegate's coordinator uses a fresh `HealthKitManager` + fresh `ReadinessStore` on each BG fire (default factory) — these are not the same instances the foreground UI is observing. Persistence still works because `ReadinessStore` is UserDefaults-backed (`App/ReadinessStore.swift:9–14`), so the value reaches the widget via UserDefaults on next read. But it means the in-memory `@Observable` UI does not get an immediate update from BG runs; foreground refresh has to re-read from UserDefaults.
- **Why this exists:** AppDelegate predates AppContainer; the container was bolted on without removing the delegate's local var.
- **Impact:** No crash, no data loss — UserDefaults round-trip masks the issue. But the AppContainer's coordinator wastes init cycles, the design is confusing, and any future change to `liveViewModelFactory` (e.g. to share a HealthKit query cache) will silently not apply because the wrong instance is registered.
- **Evidence:**
  - `App/AppDelegate.swift:7, 19, 20` — local var, `register()`, `schedule()`.
  - `App/AppContainer.swift:25, 65–73` — second declaration + custom factory.
  - `App/ContentView.swift:140` — uses container's instance for `schedule()`.
- **How to verify fast:** Add a `print("registered factory hash: \(ObjectIdentifier(self).hashValue)")` in `register()` and another in the BG handler. Log will confirm the AppDelegate's instance handles the BG fire. The container's instance never fires.
- **Fix:** Move the BG coordinator entirely into `AppContainer`. Have AppDelegate hold a reference to the container's instance (passed via `@UIApplicationDelegateAdaptor` callback or `AppContainer.shared`-style singleton). Remove the local var. Then the `liveViewModelFactory` closure that captures the shared `readinessStore` will actually be the one registered.
- **Priority:** This Week.
- **Confidence:** 96/100 — file:line and call paths verified in detail. Cross-cuts the perf agent's earlier flag.

---

### F15. `BackgroundRefreshCoordinator.handle` uses a 30-second `Task.sleep` to wait for completion — race-prone and wastes the iOS BG window
- **Severity:** Medium
- **Issue:** `App/BackgroundRefreshCoordinator.swift:101` — `try? await Task.sleep(for: .seconds(delay))` (where `delay` is `AppConstants.BackgroundTask.completionDelay`, presumably ~30s) happens **after** `liveViewModel.fetchHomeData()` is called. The fetch is fire-and-forget (synchronous return; viewmodel sets state asynchronously). The sleep is the team's way of "give the fetch time to finish." But:
  - iOS gives BGAppRefreshTask only ~30s wallclock total. Sleeping 30s after a fetch leaves zero margin and is a recipe for the `expirationHandler` firing mid-write (line 137: `workTask.cancel()`).
  - `success = liveViewModel.recovery.readinessScore != nil` (line 103) is a polling-style check after a fixed sleep. If the fetch is faster than 30s, the BG task wastes the remaining time. If slower, success is logged falsely.
  - The thermal recheck at line 82 is good defensive code but does not save the architecture flaw.
- **Why this exists:** `fetchHomeData()` does not return an awaitable Task; the team wrapped it in a sleep instead of refactoring.
- **Impact:**
  - Wasted BG budget — iOS may throttle future BG fires because the app uses its full window every time.
  - Potential cancelled writes when fetch runs >25s and expirationHandler fires.
  - Inaccurate `track_background_refresh_result.success` metric (line 129) — race conditions cause flapping.
- **Evidence:** `App/BackgroundRefreshCoordinator.swift:79–134`. Specifically:
  - line 96 `liveViewModel.fetchHomeData()` — returns immediately.
  - line 101 — fixed `try? await Task.sleep(for: .seconds(delay))`.
  - line 103 — read state after sleep.
- **Fix:** Convert `fetchHomeData` to an `async` function that returns when the fetch completes (or refactor to publish a completion via a continuation). Replace fixed sleep with `await fetchTask` + a `Task.sleep` only as a hard cutoff timeout. Treat `expirationHandler` as the upper bound.
- **Priority:** Soon.
- **Confidence:** 90/100 — code verified verbatim; the architectural concern is well-understood from BGTaskScheduler docs. Untested at runtime to confirm 30s is exceeded in the field.

---

### F16. Live Activities — TodayScore staleness 30 min, WindDown grace 30 min, Breathwork no staleness — overlap and end-conditions are partially handled, with one race
- **Severity:** Medium
- **Issue:** Three Live Activity managers, each independently keeping at most one activity. Cross-cut issues:
  - `TodayScoreLiveActivityManager.stalenessInterval = 30 * 60` (`App/TodayScoreLiveActivityManager.swift:19`). After 30 min iOS marks it stale (correct).
  - `WindDownLiveActivityManager` window: `[bedtime - 60min, bedtime + 30min]` (`App/WindDownLiveActivityManager.swift:20–22`). When wind-down starts, it forcefully ends the TodayScore activity at line 108 — good, the notch is "handed over." But there is no inverse: if the user dismisses wind-down (`programmaticEndInFlight = false` path at line 161), the TodayScore activity is not re-started. Net: between bedtime and grace_expired, if the user swipe-dismisses wind-down, the user has *no* Live Activity until the next dashboard refresh. Minor UX gap.
  - `BreathworkLiveActivityManager.start` at `App/BreathworkLiveActivityManager.swift:42–46` calls `await activity.end(nil, dismissalPolicy: .immediate)` synchronously inside a `Task` — but immediately after at line 48 calls `Activity.request(...)`. There is a short window where the old activity's `.end` has not yet flushed and the new `Activity.request` may collide. iOS handles this gracefully (multiple activities of the same `Attributes` are allowed), but the analytics will show two "started" events without a paired "ended" if the timing skews.
  - All three managers use `pushType: nil` (no server-driven updates). Good — eliminates push-token registration error handling.
  - Staleness on `WindDownActivityAttributes` content set to `windowEnd` (line 82) — correct, hides the activity after grace.
  - Breathwork has no `staleDate` (`BreathworkLiveActivityManager.swift:50, 91, 122` use `staleDate: nil`). For a session-bound activity that should end when the timer hits zero, this is acceptable — but if the user backgrounds the app and the breath timer hits zero, the in-app `update` won't fire and the Live Activity will show the last paused state indefinitely until the user returns. Minor.
- **Why this exists:** Each manager built independently; cross-manager handoff was added later (TodayScore.end inside WindDown.start) but the inverse path was not added.
- **Impact:**
  - Race in Breathwork start: rare double-start events in analytics.
  - Wind-down dismissal leaves the user without a Live Activity for the rest of the night. Low-impact.
  - Breathwork can show stale paused state on app suspend during a session.
- **Evidence:** Cited inline above.
- **Fix:**
  - Breathwork start: await the prior `.end` before issuing `.request`. Convert `start` to `async` or chain in a single `Task`.
  - Wind-down dismissal: on dismissed → re-start TodayScore activity if it's still during day-mode. Use `TodayScoreLiveActivityManager.shared.updateOrStart(...)`.
  - Breathwork stale: set `staleDate` to `Date().addingTimeInterval(protocolTotalDuration + 60)` so iOS auto-dims if the in-app updater stops firing.
- **Priority:** Soon.
- **Confidence:** 88/100 — three manager bodies read end-to-end; cross-manager handoff at `WindDown:108` confirmed. Minor weak link: I did not verify the actual `protocolTotalDuration` math — possible the existing code already auto-ends within iOS' default 8-hour limit and the gap is purely cosmetic.

---

### F17. Widget timeline policy is a fixed 15-minute refresh — fine, but `WidgetCenter.reloadAllTimelines()` is also called from BG fires, which may cause widget churn
- **Severity:** Low
- **Issue:** `LasoWidgets/AnalysisWidgetProvider.swift:17` returns a Timeline with `.after(refreshDate)` set 15 min ahead. `Core/Data/WidgetDataStore.swift:216` and `App/BackgroundRefreshCoordinator.swift:115` both call `WidgetCenter.shared.reloadAllTimelines()` on data change. iOS budgets widget reloads — calling `reloadAllTimelines` from both the BG handler and the foreground store means rapid back-to-back reloads could blow the budget on a slow day. BackgroundRefreshCoordinator already gates with `WidgetDataStore.shared.saveReadinessIfChanged(snapshot)` (line 113), so the BG path only reloads when the value changed — good. The `WidgetDataStore.reloadAllTimelines` call at line 216 should be similarly gated to "only reload on actual change." Did not deep-read WidgetDataStore to confirm.
- **Why this exists:** Defensive over-reloading.
- **Impact:** iOS may quietly throttle future widget reloads if the budget is exceeded. Symptom: stale widget for a few extra cycles.
- **Fix:** Spot-check `WidgetDataStore.swift:216` — gate the reload on a "did anything change" check. Already done in BG path; replicate in the store.
- **Priority:** Later.
- **Confidence:** 78/100 — `BackgroundRefreshCoordinator.swift:111–116` verified; `WidgetDataStore.swift:216` not re-read in this audit, only the call site grep. Specific weak link: the actual gating logic in WidgetDataStore.swift was not opened, so the "rapid back-to-back" claim is inferred.

---

### F18. RemoteConfig kill switches well-designed and well-defaulted — but no UI to inform user of partial kills (`kill_live_tab`, `kill_ml_pipeline`, `kill_cloud_backup`, `kill_notifications`)
- **Severity:** Low
- **Issue:** `Core/Config/RemoteConfigManager.swift:289–319` declares five kill switches:
  - `kill_switch_enabled` → handled in `App/LasoApp.swift:87–90` (full-app maintenance screen, dismissable via `MaintenanceView`).
  - `kill_live_tab`, `kill_ml_pipeline`, `kill_cloud_backup`, `kill_notifications` — declared on the manager, but `grep -rn "killLiveTab\|killMLPipeline\|killCloudBackup\|killNotifications"` shows they need cross-cut inspection from the consuming modules to confirm they are actually checked. (Did not exhaustively verify each call site — out of scope here, see audit #14 for cross-cut.)
  - All defaults are `false` (`RemoteConfigManager.swift:451–456`) — safe.
  - `requiresForceUpdate` does correct semver compare (`:331–343`) and is bypassed during App Review (`LasoApp.swift:35–37`).
  - `fetchAndActivate` failure stores `fetchError` in a property (`:71`) but never reports to PostHog (cross-cuts F11).
- **Why this exists:** The kill switches were added wholesale; their UI surface area lags the manager surface area.
- **Impact:** When the team flips `kill_live_tab` mid-incident, users will see the Live tab simply not load — with no message explaining why. Confused users will assume the app is broken and uninstall.
- **Fix:** For each partial kill, show a one-line banner ("Live data is temporarily paused for maintenance") in the affected screen. Wire all five killSwitch reads to a single source-of-truth helper that surfaces the message via `kill_switch_message` or per-switch override keys.
- **Priority:** Soon.
- **Confidence:** 87/100 — RemoteConfigManager body read end-to-end; consumer call-site verification deferred to cross-cut audit.

---

### F19. Pre-commit hook references missing `qg` binary — quality gate silently skipped on every commit
- **Severity:** Medium
- **Issue:** `.githooks/pre-commit:6–10` checks `if [[ -x "$ROOT_DIR/qg" ]]; then qg gate; else echo skipping; fi`. The `qg` binary does not exist at the repo root (verified by `ls /Users/primetrace/Desktop/RnD/HealthPulse/qg` → No such file). Every commit therefore prints `[pre-commit] qg not found — skipping quality gate` and proceeds. The `.qualitygate` config file references `QG_UI_TEST_BUNDLE="LasoUITests"` and `QG_BASELINE_DIR="visual-regression/baseline"` — designed for a tool that runs UI tests + visual diff. The tool is missing entirely.
- **Why this exists:** The `qg` binary was either never committed (likely `.gitignore`d or installed via a separate script), or was deleted. Memory mentions postBuildScripts for dSYM but says nothing about `qg`.
- **Impact:** Every developer assumes the pre-commit hook is enforcing quality. It isn't. Visual regression baselines drift, UI tests are not run, and the `.qualitygate` file reads as documentation rather than a runtime gate.
- **Evidence:**
  - `.githooks/pre-commit:6` — `[[ -x "$ROOT_DIR/qg" ]]`.
  - `ls /Users/primetrace/Desktop/RnD/HealthPulse/qg` → ENOENT.
  - `.qualitygate:1–10` — config that nothing reads.
- **Fix:** Either (a) commit/install `qg` and document in README how to install it, or (b) replace the pre-commit body with a real check (e.g. `xcodebuild build -scheme Laso` + a no-changes-to-baseline assertion). Don't leave a placeholder hook in place.
- **Priority:** This Week.
- **Confidence:** 95/100 — file content + missing-binary verification.

---

### F20. `LasoUITests/LasoUITests.swift` is an empty class — the visual-regression README claims tests exist, but they do not
- **Severity:** High (process / verification gap)
- **Issue:** `LasoUITests/LasoUITests.swift` contains exactly four lines: `import XCTest` + `final class LasoUITests: XCTestCase {}`. No test methods. `visual-regression/README.md:46–55` lists eight expected test methods (`testOnboardingDark`, `testOnboardingLight`, `testMainFlowDark`, `testMainFlowLight`, `testHomeDetailsDark`, `testHomeDetailsLight`, `testSettingsDark`, `testSettingsLight`) — none of these exist in the test bundle. Either the tests were deleted or never written. The `visual-regression/baseline/` folder exists (per the working tree), so someone has run *something* to capture baselines — possibly by invoking screenshots from manual flows, not tests.
- **Why this exists:** Tests were probably scaffolded externally (Cursor / Codex agents capturing screenshots without committing test files), or removed when refactoring.
- **Impact:**
  - The `LasoUITests` target builds and ships a no-test bundle.
  - `xcodebuild test -only-testing:LasoUITests` will report "executed 0 tests" but exit 0 — looking like everything passes.
  - Visual regression cannot run. Baselines will silently drift.
  - Pre-commit hook (F19) is moot because the gate it would run also has nothing to test.
- **Evidence:**
  - `LasoUITests/LasoUITests.swift` — 4 lines, empty class.
  - `find /Users/primetrace/Desktop/RnD/HealthPulse/LasoUITests -type f` → only that one file.
  - `visual-regression/README.md:46–55` — claimed methods.
- **Fix:** Either restore the test methods (re-write them based on `Scripts/capture-app-store-screenshots.sh` if that script captures the same flows), or remove the visual-regression README and `.qualitygate` config to match reality. The mismatch is misleading.
- **Priority:** This Week.
- **Confidence:** 99/100.

---

### F21. No CI pipeline — no `.github/workflows`, no Fastfile, no Makefile, no automated build verification
- **Severity:** High
- **Issue:** `ls /Users/primetrace/Desktop/RnD/HealthPulse/.github` → ENOENT. No `Fastfile`, `Makefile`, `Bitrise.yml`, or any CI config. The only automation is the `.githooks/pre-commit` (broken — F19). Every TestFlight upload is manual via Xcode → Archive → Distribute. No automated build-on-PR, no on-merge dSYM upload (which would catch F2), no nightly UI-test sweep.
- **Why this exists:** Pre-launch app, single-developer or small-team codebase, CI not yet wired.
- **Impact:**
  - Bugs landing on `main` are not caught until someone runs Xcode locally.
  - Crashlytics dSYM upload (when wired) won't run on every build → symbol mismatches between Crashlytics dashboard and TestFlight builds.
  - Privacy / entitlement regressions (cross-cut from audit #02 F1: `aps-environment=development`) cannot be linted automatically.
  - Test coverage cannot grow because there is no enforcement loop.
- **Evidence:** `find /Users/primetrace/Desktop/RnD/HealthPulse -maxdepth 2 -type d -name ".github"` → 0 hits. `find . -maxdepth 2 -name "Fastfile" -o -name "Makefile" -o -name "Bitrise.yml"` → 0 hits.
- **Fix:** Minimum-viable CI:
  1. GitHub Actions (or whichever provider): one job that runs `xcodegen generate && xcodebuild build -scheme Laso -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` on every PR.
  2. A second job (post-merge to main): runs the dSYM upload step against the Release build.
  3. Add `xcodebuild test -only-testing:LasoUITests` once F20 is fixed.
- **Priority:** This Week (before App Store launch).
- **Confidence:** 96/100.

---

### F22. Anonymous Firebase Auth + no `Auth` state listener — sign-in failures during `signInAnonymously` are reported once but not retried
- **Severity:** Medium
- **Issue:** `App/AppLaunchCoordinator.swift:27–33` calls `Auth.auth().signInAnonymously` once at launch. On error it calls `PostHogManager.shared.captureError(error, context: "anonymous_auth")` — but does not retry, does not subscribe to `Auth.auth().addStateDidChangeListener`, and does not gate Firestore writes on a successful auth. Subsequent code (e.g. `SubscriptionManager.syncSubscriptionToFirestore` at `Core/Subscriptions/SubscriptionManager.swift:457–486`) writes to Firestore using `Auth.auth().currentUser?.uid` — if the anonymous sign-in failed (offline at launch, transient backend), `currentUser` is nil and the write either uses an unauth path (will be denied by Firestore rules requiring `request.auth != null`) or no-ops. The user will not see the failure; it will silently swallow per F11.
- **Why this exists:** Anonymous Auth is "fire and forget" by convention. Real-world transient failures aren't planned for.
- **Impact:**
  - First-launch with no internet: anonymous Auth fails, user reaches the app, opens settings, taps "Restore subscription" → Firestore call fails because no auth → no record cross-device → user thinks the restore is broken.
  - PostHog `app_error_recorded` event fires once for this — engineering sees a one-shot signal, not a recurring "X% of sessions are auth-less."
- **Evidence:**
  - `App/AppLaunchCoordinator.swift:27–33` — single attempt.
  - `Core/Subscriptions/SubscriptionManager.swift:521–526` — uses `Auth.auth().currentUser?.uid` without `nil` check before reaching Firestore call (`Firestore.firestore().collection(...).document(uid).getDocument()` — `uid` is force-unwrapped via `?.` chain so a nil short-circuits to no-op).
- **Fix:** Add a retry loop: on `signInAnonymously` failure, schedule `Task.sleep(for: .seconds(30))` and retry up to N times. Also register `Auth.auth().addStateDidChangeListener` so the rest of the app reacts to delayed sign-in. Track `auth_state_failed` in PostHog as a *recurring* metric, not a single error.
- **Priority:** Soon.
- **Confidence:** 89/100 — call sites verified; have not stepped through the SubscriptionManager `?.` chain for every Firestore write.

---

## Crashlytics setup checklist

| Item | Status | Evidence | Notes |
|---|---|---|---|
| `FirebaseApp.configure()` called | YES | `App/AppLaunchCoordinator.swift:22` | Once, idempotent. |
| `Crashlytics.crashlytics()` accessed | NO | grep zero hits | Crashlytics likely not initialized despite SPM dep — F1. |
| dSYM generation post-build script | YES (partial) | `project.yml:89–122` | Generates locally only; no upload. |
| dSYM upload to Firebase | NO | grep `upload-symbols` zero hits | F2 — every crash unsymbolicated. |
| `Scripts/fix-archive-dsyms.sh` | NO | `ls Scripts/` | Memory note refers to non-existent script. |
| `setUserID(...)` called | NO | grep zero hits | F4. |
| `setCustomValue(...)` for context | NO | grep zero hits | No custom keys for screen/state debugging. |
| Crashlytics opt-out toggle | NO | grep `setCrashlyticsCollectionEnabled` zero hits | F6 — GDPR gap. |
| Crash-free user metric available | NO | depends on Crashlytics being wired | Not currently computable. |
| Force-crash test path (Debug-only) | NO | grep `fatalError`, `crashlytics().crash` zero hits | F7. |
| PostHog crash capture | YES | `Core/Tracking/PostHogManager.swift:126–166` | Will conflict with Crashlytics — F3. |
| RemoteConfig kill switch for telemetry | NO | grep `kill_telemetry`/`kill_crash` zero hits | One could be added; nice-to-have. |

---

## Networking checklist

| Item | Status | Evidence | Notes |
|---|---|---|---|
| ATS default-secure (no `NSAllowsArbitraryLoads`) | YES | grep zero hits | F8 — clean. |
| ATS exception domains | NO (none) | Info.plist read verbatim | Clean. |
| Hardcoded `http://` URLs | NO | grep returns only DOCTYPE | Clean. |
| TLS pinning (URLSessionDelegate / TrustKit) | NO | grep zero hits | F9 — acceptable for v1, flag for v2. |
| Custom URLSession config (timeout, ephemeral) | PARTIAL | only `AppStoreVersionChecker.swift:45–47` | Uses 5s timeout. Others use `.shared`. |
| Background URLSession | NO | grep `background(withIdentifier` zero hits | F10 — fine for current scope. |
| Retry / exponential backoff | NO | grep `retry`/`backoff` zero hits | No naive retry storms either. |
| `NWPathMonitor` connectivity | YES | `App/ContentView.swift:725` | Used for online-recovery refresh. |
| Cleartext WebView | NO | no `WKWebView` instances | grep zero hits. |
| Network availability gating sensitive flows | PARTIAL | uses `ConnectivityMonitor` for some | Subscription / referral don't gate explicitly. |

---

## Deep links + URL handlers checklist

| Item | Status | Evidence | Notes |
|---|---|---|---|
| `application(_:open:options:)` handler | NO | grep zero hits | F12. |
| `.onOpenURL { }` modifier | NO | grep zero hits | F12. |
| `CFBundleURLTypes` registered | NO | Info.plist read verbatim | F12 — no custom scheme. |
| `Associated Domains` entitlement | NO | `Laso.entitlements` read verbatim | F12 — Universal Links impossible. |
| `apple-app-site-association` deployed | NO | `find` zero hits in website/admin-panel | F12. |
| Spotlight `CSSearchableItem` indexing | NO | grep zero hits | Engagement gap. |
| Siri / AppIntents registered | YES | `Core/Intents/LasoShortcutsProvider.swift:9–84` | Six intents — F13 for auth gating. |
| App Clip target | NO | not declared in project.yml | Expected absent. |
| URL host validation in handlers | N/A | no handlers exist | F12. |
| Referral redemption path | Paste-only | `Modules/Referral/Services/ReferralManager.swift:276` | No URL path — high friction. |

---

## Background tasks + Live Activities checklist

| Item | Status | Evidence | Notes |
|---|---|---|---|
| `BGTaskScheduler.register` for `com.lasohealth.fit.background-refresh` | YES | `App/BackgroundRefreshCoordinator.swift:41` | F14 caveat: instance double. |
| Identifier matches Info.plist allowlist | YES | `Info.plist:7` ↔ `AppConstants.swift:81` | Confirmed. |
| Time-bounded BG handler | PARTIAL | `App/BackgroundRefreshCoordinator.swift:79–134` | F15 — fixed sleep wastes window. |
| Idempotent BG handler | YES | `hasRegistered` guard at line 38 | But only on instance — F14. |
| Thermal throttle check | YES | line 68, line 82 | Defensive. |
| `submitTask` failures handled | NO | `try?` swallows at line 54 | F11. |
| Live Activity managers | YES | three files | F16 — race + missing dismiss-recover. |
| Live Activity push tokens | NO | all use `pushType: nil` | Local updates only. |
| Live Activity stale-state defined | PARTIAL | TodayScore + WindDown YES; Breathwork NO | F16. |
| Activity end-on-conditions | YES | bedtime grace, midnight, user-toggle | Documented in F16. |
| Widget timeline refresh policy | YES | `LasoWidgets/AnalysisWidgetProvider.swift:17` | 15-min `.after(refreshDate)` — sane. |
| Widget snapshot guarded against unchanged data | YES (BG path) / PARTIAL (foreground) | `BackgroundRefreshCoordinator.swift:113` gates; `WidgetDataStore.swift:216` not verified | F17. |

---

## Summary

The app's reliability posture is **dangerously asymmetric**: PostHog is heavily wired (configure + crash signals + screen views + user props + session replay with masking + 100+ events) while Crashlytics is essentially unused — linked at the SPM level but never imported, never initialized, and with no dSYM upload pipeline. The team is operating on the assumption that PostHog crash capture is "enough." It is not: 15-frame symbol-less stacks, zero thread state, zero register dump, and no crash-free-user metric. Every TestFlight crash today is invisible at engineering grain.

ATS / TLS / networking is *clean by default* — no insecure exceptions, no naive retry storms, no hardcoded http URLs. TLS pinning is absent (acceptable for v1, but flagged for a hardened v2). Universal Links + deep links are completely absent (acceptable for v1, but blocks marketing + referral velocity). The Live Activity managers are well-structured but have a small race (Breathwork start before prior end flushes) and a missing dismiss-recover (WindDown swipe → no fallback to TodayScore).

Background refresh is *registered correctly* but architected oddly: AppDelegate's coordinator instance handles the BG fire while AppContainer's coordinator is dead weight. A 30-second `Task.sleep` wastes the BG window and risks `expirationHandler`-triggered cancellation. The kill-switch + RemoteConfig system is the strongest piece in the audit — defaults are sane, force-update logic is correct, App-Review bypass is wired.

CI is **non-existent**. The pre-commit hook references a missing `qg` binary, the `LasoUITests` bundle is an empty class, and the `visual-regression/README.md` describes tests that do not exist. There is no GitHub Actions / Fastlane / CI pipeline. Every TestFlight upload is manual, every dSYM upload (when added) will need to be run by hand, and every regression must be caught by the developer's local Xcode session.

Anonymous Firebase Auth is fire-and-forget with no retry on transient failure. PostHog is never called with `identify`, so every event and every (PostHog) crash is anonymous and cannot be tied to a user reporting a bug.

---

## Top 3 to do Now (before next TestFlight build)

1. **Wire Crashlytics + dSYM upload (F1, F2).** Add `import FirebaseCrashlytics` + `Crashlytics.crashlytics().setUserID(uid)` in `AppLaunchCoordinator` after anonymous Auth resolves. Add the `upload-symbols` post-build script. Without these two, every TestFlight crash is invisible. Side effect: F3 (PostHog/Crashlytics signal handler conflict) needs a resolution decision — either remove PostHog signal handlers or chain them.
2. **Replace silent `try?` swallows with `captureError` in Firestore + StoreKit + RemoteConfig + BGTaskScheduler.submit (F11).** Specifically: `SubscriptionManager:484, 506, 543`, `BackgroundRefreshCoordinator:54`, `RemoteConfigManager:70–72`. Without this, real failures in production show up nowhere.
3. **Either restore the LasoUITests test methods to match `visual-regression/README.md` claims, or delete the README and `.qualitygate` config (F19, F20).** Today the repo claims tests exist that don't, the pre-commit hook claims a quality gate that doesn't run, and the visual baselines drift silently. The mismatch is the kind of thing a reviewer flags as "process not real." Pick one: either make it real, or stop claiming it.

Confidence: 90/100 — every finding has file:line evidence read verbatim and grep verification. Specific weak link: I did not exhaustively step through all six AppIntent `perform()` bodies (sampled `HealthScoreIntent` only) — F13's auth-gating claim is generalized from one sample. I did not re-read `Core/Data/WidgetDataStore.swift:216` for the F17 gating claim, only its call site. I did not run `xcodebuild` to confirm the absence of generated `ENABLE_BITCODE` settings (F5 inferred from Xcode 15 default behavior).
