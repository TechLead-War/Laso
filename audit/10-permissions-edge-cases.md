# 10 — Permissions, Edge Cases, Device Variance

Pre-launch adversarial audit of every permission denial path, hostile real-world condition (no network, low memory, time-zone shift, low power, DST), device variance (SE → 15 Pro Max), and lifecycle edge case. Read-only research, file:line evidence, no code changes.

Format: each finding is **Severity / Issue / Why this exists / Impact / Evidence / How to verify fast / Fix / Priority / Confidence**.

---

## F1. APNs token registration is never called — push from server is impossible

- **Severity:** Critical
- **Issue:** `AppDelegate` does not implement `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` or `application(_:didFailToRegisterForRemoteNotificationsWithError:)`, and no code anywhere calls `UIApplication.shared.registerForRemoteNotifications()`. The app cannot obtain an APNs device token, so any server-side push (re-engagement, alerts authored on a backend, marketing) will silently never reach users — even if they grant local notification permission.
- **Why this exists:** `NotificationManager` was built for **local** notifications only (calendar triggers, daily summary, watch-not-worn), and the engineer who added `aps-environment = development` to `Laso.entitlements:5` likely intended remote push but never finished wiring it up.
- **Impact:**
  - Re-engagement loops authored as remote push (if any remote backend is in plan) silently fail. Engagement KPI cannot recover the at-risk cohort.
  - The `aps-environment = development` entitlement is loud but inert — TestFlight (which uses production APNs) would also fail token negotiation, producing `apns-environment` mismatch errors in Xcode logs that engineers may chase as a real bug.
  - Combined with finding F2 below, the entire push surface is dead on launch.
- **Evidence:**
  - `/Users/primetrace/Desktop/RnD/HealthPulse/App/AppDelegate.swift:1-49` — no `didRegisterForRemoteNotifications…` overrides, no `registerForRemoteNotifications()` call.
  - `grep -rn "registerForRemoteNotifications" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` returns **zero** matches.
  - `Laso.entitlements:5` — `aps-environment = development` (so capability is on, but nobody asks for the token).
  - `Info.plist:41-45` — `UIBackgroundModes` lists only `fetch` and `processing`. **`remote-notification` is missing** so silent push wake-up will not work either.
- **How to verify fast:** Run the app on a real device, open Xcode console — confirm absence of `didRegisterForRemoteNotificationsWithDeviceToken` log; check Apple Push Console — no token bound to user.
- **Fix:**
  1. If push is in scope: call `UIApplication.shared.registerForRemoteNotifications()` after the user grants notification permission. Implement both `didRegister…WithDeviceToken` (forward token to your backend) and `didFailToRegister…WithError` (capture in PostHog as `apns_token_failure` event with `error.localizedDescription`).
  2. Flip `aps-environment` to `production` for TestFlight/App Store builds via build-config or release configuration.
  3. Add `remote-notification` to `UIBackgroundModes` if silent push is needed.
  4. If push from server is **not** in scope: remove `aps-environment` from `Laso.entitlements` so Apple Review does not flag the unused capability and so the App Store does not log false APNs registration errors.
- **Priority:** Now — capability declared but unused is a 100% guaranteed App Store reviewer flag and a 100% silent failure in production for any remote push feature.
- **Confidence:** 95/100 — verified by direct file read of `AppDelegate.swift`, `Info.plist`, `Laso.entitlements`, and a global grep for `registerForRemoteNotifications` returning zero hits; what's not verified is whether the product team actually ever intended remote push (PRD not in scope).

---

## F2. Notification permission is never requested anywhere in the app

- **Severity:** Critical
- **Issue:** `NotificationManager.requestAuthorization(source:)` exists at `Core/Notifications/NotificationManager.swift:47-66` and is exposed on the `NotificationAuthorizationService` protocol — but **no code calls it**. A global grep across all Swift files for any callsite returns zero matches. Onboarding never prompts. No screen prompts. No Settings toggle prompts. The system iOS dialog "Laso Would Like to Send You Notifications" is never shown to any user. Yet the entire `Core/Notifications/` subsystem (DailySummaryScheduler, EveningSummaryScheduler, WindDownScheduler, WeeklySummaryScheduler, AlertEvaluator, IntelligenceAlertEvaluator, EngagementSequenceScheduler, WatchMonitor) actively schedules `UNNotificationRequest` instances every day. Without `.authorizationStatus == .authorized`, every `center.add(request)` call silently fails (or queues unauth-rejected).
- **Why this exists:** The team wrote the entire scheduling pipeline first (15+ schedulers) and a re-prompt banner for the *denied* path (`NotificationRepromptManager`), but skipped the actual first-ask. A misleading comment at `DashboardHousekeepingService.swift:106` says *"Permission is requested during onboarding so we should not show a random dialog here"* — the comment is wrong; nothing in `Modules/Onboarding/` requests notification permission. Onboarding flow is `pulse → profile → connect → priority → mirror → promise` (`OnboardingView.swift:32-34`); none of those screens calls `NotificationManager.requestAuthorization`.
- **Impact:** Day 1 — **zero** users ever see a system push prompt. The entire daily-summary, alert, evening-summary, wind-down, and weekly-review notification surface fires zero notifications. The 15+ scheduler files are dead engagement weight. Combined with F1, the notification engagement loop is completely broken pre-launch. Worse: `NotificationRepromptManager.checkAndRecordDenial` on `ContentView.swift:113` only triggers the in-app banner when status is `.denied` — but the system status will sit at `.notDetermined` forever because nobody asked. The reprompt banner is also never shown.
- **Evidence:**
  - `Core/Notifications/NotificationManager.swift:47` — `requestAuthorization(source:)` defined.
  - `grep -rn "NotificationManager.shared.requestAuthorization\|notificationManager.requestAuthorization\|center.requestAuthorization\|requestAuthorization(source" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → only the **definition** is found, **no callsites** in the entire codebase.
  - `Modules/Onboarding/Views/Onboarding/OnboardingView.swift:32-76` — six steps; none touch notifications.
  - `Modules/Onboarding/Views/Onboarding/OnboardingConnectHealthStep.swift:67-75` — only HealthKit auth, no notification ask.
  - `Modules/Dashboard/ViewModels/DashboardHousekeepingService.swift:106` — false comment "Permission is requested during onboarding".
  - `App/ContentView.swift:113-116` — only the *re-prompt* path is wired, gated on `authorizationStatus == .denied`, which can never happen if the first ask never fires.
- **How to verify fast:** Fresh-install on a clean simulator, complete onboarding, watch every screen — confirm no system push dialog ever shows. Check `Settings → Notifications → Laso` — it says "Allow Notifications: not requested" / does not appear in the list.
- **Fix:** Add a contextual notification primer + `await NotificationManager.shared.requestAuthorization(source: "onboarding")` either as a 7th onboarding step (after Connect Health, gated to a one-line value-prop screen) or contextually after the user taps a notification preference toggle in Settings the first time. Apple HIG strongly prefers contextual ask, so post-onboarding (after first daily score is computed and the wind-down primer is shown) is even better. Either way, this gap must be closed before launch.
- **Priority:** Now — entire notification subsystem is non-functional without this single line.
- **Confidence:** 96/100 — verified by global grep returning zero callsites and direct read of all six onboarding step files plus AppDelegate, AppStartupCoordinator, and AppLaunchCoordinator.

---

## F3. HealthKit `isAuthorized` is set to `true` even when the user denies — read access state is always falsely positive

- **Severity:** Critical
- **Issue:** Apple's `HKHealthStore.requestAuthorization(toShare:read:)` for **read** types **never throws on denial** and never tells the caller which types the user actually granted (read auth status is private to prevent fingerprinting). Yet `HealthKitManager.requestAuthorization()` at `Core/Data/HealthKitManager.swift:158-174` does:
  ```
  try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
  isAuthorized = true                       // ← line 165: blindly true
  AppAnalytics.shared.trackHealthPermissionResult(granted: totalRequested, denied: 0, total: totalRequested)
  ```
  So if the user taps "Don't Allow" or denies every category individually, `isAuthorized` is **still set to `true`** and analytics emits `granted = totalRequested, denied = 0`. The `catch` branch only fires on a thrown error (e.g. HealthKit-not-available device, system bug), not on user denial.
- **Why this exists:** The author treated "no thrown error" as "user granted" — a common HealthKit misunderstanding. There is a partial mitigation downstream (`HealthKitRepromptManager.checkEmptyData` at `Core/Data/HealthKitRepromptManager.swift:23` which checks `timeSeries.count == 0`), but it only fires after a 1-day delay and the dashboard already runs in the meantime.
- **Impact:**
  - User taps "Don't Allow" in onboarding → `isAuthorized = true` → dashboard load proceeds → all 19 metrics return zero samples → ML pipeline runs on empty data → user sees a 0/100 score, blank category cards, broken correlation charts, "You haven't slept this week" type insights.
  - Analytics is poisoned: `health_permission_result` always reports 100% granted, masking the true denial rate.
  - The downstream guard at `DashboardViewModel.swift:665-670` (`guard healthKitManager.isAuthorized else { … "HealthKit authorization required" }`) **can never fire** for a denied user, because `isAuthorized` is always true.
  - The "limited mode" UI path that should appear for denied-permission users does not exist; only an empty-data reprompt banner that takes 24+ hours to appear.
- **Evidence:**
  - `Core/Data/HealthKitManager.swift:164-166` — unconditional `isAuthorized = true`.
  - `Core/Data/HealthKitManager.swift:170` — analytics event reports `granted = totalRequested, denied = 0` always.
  - `Modules/Dashboard/ViewModels/DashboardViewModel.swift:663-670` — guard that can never trigger denial.
  - `Core/Data/HealthKitRepromptManager.swift:23-35` — only proxy for denial, time-gated 24h.
  - `grep -rn "authorizationStatus(for:" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches anywhere (note: read-status is private per Apple anyway, but the **share** types don't even use this either).
- **How to verify fast:** On simulator, complete onboarding, tap "Don't Allow" on every HealthKit category — observe the Home dashboard still renders with 0 score, blank category breakdowns, no error, no "limited mode" banner. Console shows analytics emitting `granted: 19, denied: 0`.
- **Fix:**
  1. Replace `isAuthorized = true` with a probe: after `requestAuthorization`, run a 1-sample `HKSampleQuery` for each of the top 3 critical types (steps, heart rate, sleep) with a 7-day predicate. If all three return zero samples within ~1.5 s **AND** an empirically-known data-rich device profile (Watch paired, > 0 days with any data) suggests data should be there, treat as denied.
  2. Better: render a clear "You skipped Health access — here's what we can show without it" empty-state that is the *correct* UX even when truly granted-but-empty (new HealthKit user, just-bought iPhone). Do not pretend the app works in zero-data mode.
  3. Fix analytics: split `health_permission_result` into `health_permission_requested` and a 24h-later `health_permission_data_observed_present` event.
- **Priority:** Now — App Review will reach the dashboard with a denied user and see a broken empty score, which violates HIG and risks rejection on grounds of "feature does not function".
- **Confidence:** 92/100 — verified by reading the exact requestAuthorization call and the misuse of the success path; what's unverified is whether App Review reviewers realistically deny HK in onboarding (some do, some don't), and whether a partial-grant (steps yes, sleep no) produces visibly broken cards versus quietly blank ones — both paths are still broken, just different severities.

---

## F4. Partial HealthKit grant (steps yes, sleep no) — scoring code does not detect missing types and computes from zero

- **Severity:** High
- **Issue:** A user can grant steps + heart rate but deny sleep. The scoring engine (`SleepScoringEngine`, `RecoveryScorer`, `ReadinessScorer`) treats missing data as **zero** rather than **unknown**. Combined with F3 above, the dashboard will show "Sleep score: 0/100, you slept 0 hours" instead of "Sleep data unavailable — grant access to compute".
- **Why this exists:** The team designed scoring around "always have data" assumption. `ReadinessScorer.swift:138` filters `$0.isFinite && $0 > 0` — protecting against NaN but treating missing data as a valid zero baseline rather than an unscoreable signal.
- **Impact:** User who grants partial access sees garbage scores. The category card UI (CategoryDetailView, etc.) shows "0%" rather than a "?" or "Not connected" state. Trust collapses: a user who knows they slept 8h sees Laso reporting 0h and concludes the app is broken.
- **Evidence:**
  - `Core/Data/HealthKitManager.swift:118-149` — read types requested as a single set; no per-type granularity tracking.
  - `Core/Analysis/ReadinessScorer.swift:138` — only NaN/zero filter, no "data missing" signal propagated upward.
  - No code path anywhere queries the per-type *share* status to gate UI: `grep -rn "authorizationStatus(for:" --include="*.swift"` → zero matches across the entire repo.
  - `App/ContentView.swift:653-656` — checks `timeSeries[.heartRate]?.samples.isEmpty == false` purely for analytics tagging (`hkHeartHasData`), not for UI gating.
- **How to verify fast:** On real device, deny only `Sleep Analysis` in the Health auth sheet, grant the rest — open dashboard → confirm Sleep card shows "0h slept, 0/100 score" rather than "Sleep data unavailable, grant access".
- **Fix:**
  1. Add a per-metric "isAvailable" flag derived from `timeSeries[metric]?.samples.isEmpty != false` for the last 30 days.
  2. In each category/score card, render a "Not connected" empty state (icon + "Tap to enable in Health settings" → opens the Settings deep-link from `HealthKitRepromptBanner.swift:80`) instead of a zero score.
  3. In the readiness/vitality composite, weight-redistribute when a pillar is missing rather than dragging the composite to zero.
- **Priority:** Now — partial grant is the **majority** real-world outcome (Apple research: most users grant some-not-all on the first prompt).
- **Confidence:** 88/100 — verified by reading the scoring code and the absence of any availability gating, but I have not run the app with sleep denied to confirm the visible UI degrades to "0h" rather than "—" — that's the unverified weak link.

---

## F5. Revoked HealthKit later — no `authorizationStatus` re-check on foreground; stale cached scores keep showing

- **Severity:** High
- **Issue:** A user grants HealthKit in onboarding, then revokes from Settings → Privacy → Health → Laso → off. Next foreground: the app does **not** re-query authorization status. `isAuthorized` stays `true` (because it was set in F3), the dashboard re-renders cached `timeSeries` from `HealthDataStore`, and shows scores derived from data the user has now revoked the right to see. SwiftData persistence at `HealthDataStore` keeps the previously fetched samples; nothing wipes them on revocation. New fetches will silently return zero results (HealthKit honors the new denial), but the cache + last-rendered state remain visible.
- **Why this exists:** No `authorizationStatus(for:)` check, no `applicationDidBecomeActive` re-validation. The team assumed authorization is monotonic (grant only).
- **Impact:**
  - User who revoked permission still sees their last week's scores after revocation, which is a **compliance** issue: Apple's HealthKit guidelines require the app to honor revocation immediately and not display data the user has rescinded access to (HIG: *"Allow people to control which categories of data your app can read…"*).
  - The "empty data" reprompt at `HealthKitRepromptManager.swift:13-83` only fires after `timeSeries.count == 0` for 24 hours **after** detection. Because the cache survives, `timeSeriesCount` is non-zero post-revocation; the reprompt never fires.
  - No `hkOnAuthChange` observer, no scene-phase re-query, no weekly invalidation.
- **Evidence:**
  - `grep -rn "authorizationStatus" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches.
  - `App/ContentView.swift:98-138` — the `onChange(scenePhase)` block; no HK auth re-check, only watch evaluation and notification reprompt check.
  - `Core/Data/HealthDataStore.swift:897` — `deleteAllData()` exists but is only called from the manual Settings "Delete All My Data" button (`SettingsView.swift:680`), not on revocation.
- **How to verify fast:** On real device, complete onboarding, force-quit Laso. Settings → Privacy → Health → Laso → toggle every category off. Re-open Laso. Observe stale dashboard with previous data still visible.
- **Fix:**
  1. On `scenePhase == .active`, call a new `healthKitManager.refreshAuthorizationState()` that probes a couple of recent `HKSampleQuery` calls. If they return zero on a previously-data-rich type, set `isAuthorized = false` and clear the cached `timeSeries`.
  2. Render a clear "HealthKit access has been revoked. Re-enable to see your scores." top banner with a deep-link to `Settings → Privacy → Health`.
  3. Optional: add `HKHealthStore.handleAuthorizationForExtension` observer for the dual-direction signal.
- **Priority:** Now — privacy regression that is also an Apple guideline risk.
- **Confidence:** 86/100 — flow verified by reading scenePhase handler, ContentView, HealthKitManager; not verified at runtime that the cached scores actually persist visually post-revocation versus being cleared by SwiftData TTL.

---

## F6. iPhone-only user (no Watch) — Day-1 dashboard empty, no graceful "what we can show" state

- **Severity:** High
- **Issue:** Many score components rely on Apple Watch data: HRV, resting HR, sleep stages, blood-oxygen, ECG. An iPhone-only user provides only step count, distance, mindful minutes, and (rarely) weight. The app does not detect this and degrade gracefully; instead, every Watch-derived score (Recovery, Readiness, Strain, HRV-driven Stress, Brain Health) renders as zero, "Insufficient data", or blank.
- **Why this exists:** App designed Watch-first; iPhone-only path is an afterthought. `DeviceSourceManager.isAppleWatchPaired` (`Core/Data/DeviceSourceManager.swift:362`) exists and is read in `ContentView.swift:652` for analytics, but no scorer or UI uses it to gate rendering.
- **Impact:** Day-1 iPhone-only user sees ~40% of the dashboard as empty/broken (every Watch-derived card). Conversion to paid is unlikely; churn within 24h is likely. The "empty state" copy is Watch-centric language ("Wear your Watch to capture sleep stages") rather than aspirational ("Add an Apple Watch later to unlock these scores").
- **Evidence:**
  - `Core/Data/DeviceSourceManager.swift:362` — `isAppleWatchPaired` exists.
  - `App/ContentView.swift:652` — read into analytics only, not into UI.
  - `grep -rn "isAppleWatchPaired" --include="*.swift"` shows uses are entirely analytics + WatchMonitor evaluation, never UI render-gating.
  - `Core/Notifications/WatchMonitor.swift:62-115` — observer queries fire only if HK is available; with no Watch, no heart rate samples ever arrive, so the "watch not worn" reminder logic is permanently silent rather than gracefully informing the user.
- **How to verify fast:** Pair Laso to an iPhone simulator with no Watch, populate Health.app with steps only, observe dashboard — Recovery / Readiness / Strain / Stress / HRV / Brain Health cards all blank or zero. No "Add a Watch to unlock" CTA.
- **Fix:**
  1. Add an `iPhoneOnlyMode` rendering path: collapse Watch-only cards into a single "Connect an Apple Watch" upsell card that explains what unlocks on the next visit.
  2. Surface the iPhone-only score subset prominently (steps, hydration logging, mindful minutes, weight) so the dashboard *feels* full of value.
  3. Day-1 onboarding could ask "Do you have an Apple Watch?" and skip the Watch-derived screens conditionally.
- **Priority:** Now — addressable market for a wellness app cannot be Watch-only on Day 1; a meaningful share of installs will be iPhone-only and they all churn under current behavior.
- **Confidence:** 84/100 — verified by reading device source manager and confirming no UI gating; not yet runtime-verified what % of cards visibly degrade.

---

## F7. Siri / App Intents — `NSSiriUsageDescription` declared but no `INPreferences.requestSiriAuthorization` call exists

- **Severity:** Medium
- **Issue:** `Info.plist:33-34` declares `NSSiriUsageDescription` ("Laso uses Siri to let you check your health score, log water, view sleep data, and track workouts hands-free"). `Laso.entitlements` includes `com.apple.developer.siri = true`. However, no code anywhere calls `INPreferences.requestSiriAuthorization` or `SFSpeechRecognizer.requestAuthorization`. `Shared/CoachActionIntents.swift` and `Core/Intents/*` are all `AppIntent`-based (the new framework that does NOT require runtime auth — it works automatically when surfaced through Shortcuts/Spotlight/widget buttons). The Info.plist string + entitlement are therefore vestigial; they do not match any code path.
- **Why this exists:** Either (a) an older flow used SiriKit's `INIntents` (which DO require `requestSiriAuthorization`) and was migrated to AppIntents but the Info.plist string was not removed; or (b) the team intends to add voice-driven Siri later and pre-declared the description.
- **Impact:**
  - Apple Review may flag the `NSSiriUsageDescription` as describing a feature that does not exist (guideline 5.1.1 — purpose strings must be accurate).
  - The Siri capability + entitlement add bundle metadata that is never exercised, signaling sloppiness.
  - If a user says "Hey Siri, check my Laso score", the response depends on whether the LiveActivityIntent is donated and exposed via Shortcuts — current code donates via `LasoShortcutsProvider` but never asks for any voice authorization, so the voice path may silently degrade.
- **Evidence:**
  - `Info.plist:33-34` — `NSSiriUsageDescription` set.
  - `Laso.entitlements:9-10` — `com.apple.developer.siri = true`.
  - `Shared/CoachActionIntents.swift:49-98` — four `LiveActivityIntent` structs, no Siri auth.
  - `Core/Intents/LasoShortcutsProvider.swift` — `AppShortcutsProvider`, no auth ask.
  - `grep -rn "INPreferences.requestSiriAuthorization\|SFSpeechRecognizer\|requestSiriAuthorization" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches.
- **How to verify fast:** Run on device, open Siri ("Hey Siri, run Laso shortcut") — observe whether voice intent fires. No system permission dialog appears for Siri because no code asks.
- **Fix:** If Siri voice is in scope: add `await INPreferences.requestSiriAuthorization { _ in }` in a contextual primer (after first daily score) and ensure `SiriEvaluator` actually exposes the intents. If voice is not in scope: remove `NSSiriUsageDescription` from Info.plist and `com.apple.developer.siri` from the entitlements file. AppIntents do not require either.
- **Priority:** This Week — App Review may flag the unused purpose string; cosmetic and capability-hygiene risk.
- **Confidence:** 88/100 — verified by file reads and grep; not verified what Apple Review actually flags here, since AppIntents framework's relationship to the Siri entitlement is somewhat lenient.

---

## F8. No `application(_:open:options:)` deep-link handler — Universal Links and custom URL schemes are silently dropped

- **Severity:** Medium
- **Issue:** AppDelegate (`App/AppDelegate.swift:1-49`) does not implement `application(_:open:options:)`, and SwiftUI `LasoApp` (`App/LasoApp.swift`) does not attach `.onOpenURL { … }`. If anything (a marketing email, a referral link, a dashboard "Continue in app" button, a push notification with deep-link payload, or an attacker-crafted URL) tries to open `lasohealth://something` or a Universal Link, the app launches but the URL is silently discarded. There is also no `Associated Domains` entitlement entry for Universal Links, so they cannot work even if a handler existed.
- **Why this exists:** Deep linking was deferred. The referral system (`Modules/Referral/`) reaches for codes via Firestore lookup keyed on user input, not URL parsing. The web export module produces shareable HTML but no deep-link backflow.
- **Impact:**
  - Referral codes shared via SMS/iMessage cannot be one-tap activated.
  - Apple's required `app-site-association` flow (Universal Links) does not work, so any web → app handoff fails.
  - Push notifications with `userInfo["url"]` payloads have no router; the user lands on the default tab.
  - Malformed URL handling: not a crash risk per se (no handler = nothing to fuzz), but a missed surface for analytics + activation.
- **Evidence:**
  - `grep -rn "application(_:open:options\|onOpenURL\|UniversalLink" --include="*.swift"` → zero matches.
  - `Laso.entitlements` — no `com.apple.developer.associated-domains` entry.
  - `App/AppDelegate.swift:9-23` — `didFinishLaunchingWithOptions` does not handle the `UIApplication.LaunchOptionsKey.url` case either.
- **How to verify fast:** From any other app, tap a `lasohealth://test` URL — observe Laso opens to default tab, never receives the URL.
- **Fix:** If deep-linking is in scope: add `.onOpenURL { url in routeFromURL(url) }` to the root SwiftUI scene; add a custom URL scheme to `Info.plist`; add Associated Domains for Universal Links; whitelist + parse expected paths; reject malformed payloads with analytics. If not in scope: do nothing, but document so that referral link clicks are known to require manual paste.
- **Priority:** This Week — referral activation funnel is currently broken end-to-end without this.
- **Confidence:** 90/100 — verified absence by grep; UX impact is clear.

---

## F9. No app-resign privacy blur — App Switcher snapshot exposes Journal, Cycle, health scores

- **Severity:** Medium
- **Issue:** When the app moves to inactive (multitasking switcher, Control Center, incoming call), iOS captures a snapshot for the App Switcher tile. Sensitive screens (Journal entries, Cycle phase + period dates, weight history, sleep details) are visible in that snapshot. There is no `.privacySensitive()` (iOS 17+) modifier or `applicationWillResignActive` overlay-blur logic anywhere.
- **Why this exists:** Privacy hardening for app-switcher screenshots is non-default in SwiftUI; the team did not add it.
- **Impact:** A casually-shared device (partner, family, repair shop) can see private health data without unlocking the app. Cycle and journal data are particularly sensitive.
- **Evidence:**
  - `grep -rn "applicationWillResignActive\|privacySensitive\|UIApplication.willResignActiveNotification\|ScenePhase.*inactive" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches for resign/privacy.
  - `App/ContentView.swift:98-142` — `onChange(scenePhase)` only handles `.active` and `.background`, not `.inactive`.
- **How to verify fast:** Open Journal screen, swipe up to multitask — observe Laso tile shows journal text + score.
- **Fix:** On scene phase `.inactive`, overlay a full-screen blur or splash. Or apply `.privacySensitive()` on Journal/Cycle/Weight detail views (iOS 17+ modifier).
- **Priority:** This Week — privacy regression, not a launch blocker but visible to power users.
- **Confidence:** 90/100 — verified absence by grep.

---

## F10. No `UIApplication.significantTimeChangeNotification` handler — DST + travel re-render bug

- **Severity:** Medium
- **Issue:** 320 references to `Calendar.current` and 302 to `startOfDay` / `byAdding: .day` across the codebase, all keyed off `Calendar.current` and `TimeZone.current`. A user crossing time zones, or a DST transition, changes what "today" is. Yet no code observes `UIApplication.significantTimeChangeNotification`, the iOS notification that fires for midnight rollovers, time-zone changes, and DST transitions. As a result:
  - A user flying NY→Tokyo: opens app on landing → "today" is computed against device-local time but cached `startOfDay`-keyed dictionaries (`SleepSessionBoundary` keyed by `Date.startOfDay` at `HealthKitManager.swift:62`) are from the old timezone. Charts label rows incorrectly.
  - DST spring-forward: the 23-hour day breaks "% of day complete" calculations and `Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)` returns 23h-later rather than next-midnight in DST-aware locales.
  - Daily score reset: not gated on midnight rollover; if app is left open across midnight, "today's score" continues to update with yesterday's date until next force-foreground.
- **Why this exists:** No one wired the notification.
- **Impact:** International travelers and DST users see misaligned daily scores, sleep boundaries, and charts on the day of transition.
- **Evidence:**
  - `grep -rn "significantTimeChange" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches.
  - `Core/Data/HealthKitManager.swift:62` — `sleepSessionBoundaries: [Date: SleepSessionBoundary]` keyed by `Date` (which is point-in-time, fine), but consumers in `ContentView.swift:528-548` look up via `boundaries[entry.date]` where `entry.date` was computed in the original timezone.
  - `Core/Notifications/DailySummaryScheduler.swift:43` — `let dayOfWeek = Calendar.current.component(.weekday, from: Date())` evaluated at schedule time, not at fire time. After travel/DST, the body content is wrong.
- **How to verify fast:** Set simulator to 11:55 PM Apr 24, leave app foreground 10 min, observe whether dashboard score / category cards re-key to Apr 25.
- **Fix:** In `LasoApp.swift` or the root scene, add `NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)` → invalidate cached daily aggregates, refresh boundaries, re-key any `[Date: …]` dictionaries, fire a `dashboardViewModel.refresh()`.
- **Priority:** This Week — DST is a known real-world bug source; international users will hit this.
- **Confidence:** 83/100 — verified by grep that no handler exists; not verified in runtime that DST actually breaks the visible rollover (would need a clock-changed simulator run).

---

## F11. Settings "Delete All My Data" calls `exit(0)` — Apple HIG violation, no signOut, no Firestore wipe, no PostHog reset

- **Severity:** High
- **Issue:** `Modules/Settings/Views/SettingsView.swift:671-691` implements `performDataDeletion` as:
  ```
  EncryptedStore.shared.remove(...)         // wipes profile keys
  healthDataStore.deleteAllData()           // SwiftData wipe
  UserDefaults.standard.removePersistentDomain(forName: bundleId)  // wipes UserDefaults
  …
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      exit(0)                               // ← HIG-prohibited
  }
  ```
  Multiple problems:
  1. Apple HIG explicitly forbids `exit(0)` — the user must be allowed to navigate away. App Review can reject for this.
  2. **No `Auth.auth().signOut()`** call — the anonymous Firebase Auth UID persists across re-launches via Keychain (Firebase auto-restores).
  3. **No `Auth.auth().currentUser?.delete()`** — the Firestore user document keyed by anon UID lives forever even though all client data is wiped.
  4. **No PostHog `reset()`** — the user's PostHog person profile keeps accumulating events under the same distinct_id after "deletion".
  5. **No Firestore `subscriptions/{uid}` document deletion**.
  6. **No App Group `UserDefaults(suiteName: "group.com.lasohealth.fit")` cleared** — Live Activity attributes, pending coach actions, last-known scores all persist.
  7. **No Live Activity `Activity.end(...)`** — the score Live Activity continues to live in the Dynamic Island after "deletion".
  8. The "deletion" is incomplete; if the user re-installs / re-launches, Firebase Auth restores the anon UID from Keychain (Firebase keeps Keychain tokens by default), Firestore re-syncs the previous subscription record, and PostHog re-keys to the same distinct_id.
- **Why this exists:** First-pass implementation only thought about the local SwiftData / UserDefaults surface, missed all six remote/lateral surfaces.
- **Impact:**
  - **App Store rejection risk:** `exit(0)` is a known-rejection trigger. Apple guideline 4.0 / HIG.
  - **GDPR / Apple guideline 5.1.1(v) failure:** "Delete account" must actually delete server-side data. As implemented, the Firestore user doc, PostHog person, and Auth UID all survive. This is a guideline 5.1.1(v) violation by definition.
  - **Re-install user:** sees their old data return.
- **Evidence:**
  - `Modules/Settings/Views/SettingsView.swift:671-691` — code path quoted above.
  - `grep -rn "Auth.auth().signOut\|Auth.auth().*\.delete(" --include="*.swift"` → zero matches anywhere.
  - `grep -rn "PostHogManager.*reset\|posthog.reset\|postHog.reset" --include="*.swift"` → zero matches.
  - `grep -rn "exit(0)\|exit(1)" /Users/primetrace/Desktop/RnD/HealthPulse/App /Users/primetrace/Desktop/RnD/HealthPulse/Modules` → only this one site.
- **How to verify fast:** Tap Delete All My Data, observe app force-quits. Re-open: anonymous UID identical, Firestore subscriptions doc still present, PostHog timeline continuous.
- **Fix:**
  1. Remove `exit(0)`. Replace with: navigate to a "Your data has been deleted. Tap Continue to start fresh" screen that re-presents `OnboardingView`.
  2. Add `try? Auth.auth().signOut()` and `try await Auth.auth().currentUser?.delete()`.
  3. Delete the user's Firestore docs: `subscriptions/{uid}`, any user-keyed collection.
  4. Call `PostHogManager.shared.reset()` (the SDK has a `reset()` method) so future events emit under a new distinct_id.
  5. Wipe App Group: `UserDefaults(suiteName: "group.com.lasohealth.fit")?.dictionaryRepresentation().keys.forEach { … removeObject … }`.
  6. End every Live Activity: iterate `Activity<…>.activities` for each attribute type and call `.end(nil, dismissalPolicy: .immediate)`.
  7. Optionally clear Keychain Firebase tokens.
- **Priority:** Now — App Review blocker and direct guideline 5.1.1(v) violation.
- **Confidence:** 95/100 — verified by reading the entire performDataDeletion + global greps; not verified is whether iOS in 2026 still rejects `exit(0)` or has loosened (historically it was a hard reject).

---

## F12. No `isLowPowerModeEnabled` check anywhere — Live Activity / background / animations do not throttle

- **Severity:** Medium
- **Issue:** `ProcessInfo.processInfo.isLowPowerModeEnabled` is **never** referenced in the entire Swift codebase. The thermal throttling layer (`Core/Config/ThermalManager.swift`) handles thermal state well but does not also gate on Low Power Mode. When Low Power Mode is on, iOS reduces background fetch frequency, dims animations, and asks apps to also do their part. The app does none of this.
- **Why this exists:** Thermal state was prioritized; battery state was missed.
- **Impact:** A user in Low Power Mode sees the same Live Activity update cadence (30-min staleness window from `TodayScoreLiveActivityManager.swift:19`), the same orb particle animations (`AskDataOrbView`, `VitalityOrganicOrb`), the same ML pipeline aggressiveness. iOS may suspend the app more aggressively, and a courtesy throttle would extend battery and align with HIG.
- **Evidence:**
  - `grep -rn "isLowPowerModeEnabled\|lowPowerModeDidChange\|NSProcessInfoPowerState" /Users/primetrace/Desktop/RnD/HealthPulse --include="*.swift"` → zero matches.
- **How to verify fast:** On device, enable Low Power Mode → confirm dashboard particle animations and Live Activity updates continue at full cadence.
- **Fix:** Add a small `BatterySaverManager` analogous to `ThermalManager`; observe `Notification.Name.NSProcessInfoPowerStateDidChange`; reduce Live Activity update frequency, disable particle animations, skip non-critical ML jobs when on.
- **Priority:** Next Sprint — battery courtesy, not a launch blocker.
- **Confidence:** 92/100 — verified absence; impact is qualitative.

---

## F13. No memory-warning handler — caches are not flushed under pressure

- **Severity:** Medium
- **Issue:** The codebase has zero references to `didReceiveMemoryWarning`, `UIApplicationDidReceiveMemoryWarningNotification`, or any `purgeCache` hook driven by memory. SwiftData caches, large `[HealthMetric: MetricTimeSeries]` dictionaries (10-year history per metric), the AskDataOrb canvas (`AskDataOrbView` ~430 lines of Canvas drawing with offscreen Image buffers), and ML pipeline intermediate state all live in memory unbounded.
- **Why this exists:** Modern iPhones have generous RAM; team likely deferred memory-pressure handling.
- **Impact:** On older iPhones (SE 3rd gen, mini 12/13) with 4GB RAM under multi-tasking pressure, iOS may kill Laso silently. Live Activity stays running but the app is jettisoned. Next foreground = full cold start. No crash log from the OS-jettison; only PostHog session-end gap visible in analytics.
- **Evidence:**
  - `grep -rn "didReceiveMemoryWarning\|UIApplicationDidReceiveMemoryWarningNotification" --include="*.swift"` → zero matches.
- **How to verify fast:** Instruments > Allocations against a real device, force memory pressure (open many apps), measure Laso's footprint.
- **Fix:** Hook `NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)` in `AppLaunchCoordinator` or `AppContainer`; on fire, call `healthDataStore.invalidateTimeSeriesCache()`, drop ML intermediate maps, clear any in-memory image cache.
- **Priority:** This Week — silent jettison kills retention without producing crash data.
- **Confidence:** 92/100 — verified absence; impact severity depends on real RAM footprint, which I have not measured.

---

## F14. Audio session for breathwork is unmanaged — does not configure `AVAudioSession`, may interrupt background music

- **Severity:** Low
- **Issue:** `Modules/Stress/Views/Stress/BreathworkView.swift` runs guided breathwork with timing/haptics, but does not import or configure `AVAudioSession`. If breathwork ever plays guidance audio (current code does not — confirmed), no session category is set. If background music is playing (Apple Music, Spotify), there is no `.mixWithOthers` declaration, so any future audio addition will pause the user's music silently and not resume.
- **Why this exists:** Breathwork is currently silent (haptics only); team did not pre-stage audio session.
- **Impact:** Silent today. **Time-bomb** for future breathwork v2 with guidance audio — first audio play will interrupt the user's music with no resume on session end.
- **Evidence:**
  - `grep -n "AVAudioSession\|setCategory\|playSound" /Users/primetrace/Desktop/RnD/HealthPulse/Modules/Stress/Views/Stress/BreathworkView.swift` → zero matches.
- **How to verify fast:** Start breathwork while Apple Music plays — confirm music keeps playing (today). Add audio in v2 → music pauses without resuming.
- **Fix:** When audio is added, set `AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])` before playback.
- **Priority:** Next Sprint — only matters when audio is added.
- **Confidence:** 90/100 — verified by file read.

---

## F15. No `BGTaskScheduler` failure observability — when background-app-refresh is disabled by user, app silently degrades

- **Severity:** Medium
- **Issue:** `App/BackgroundRefreshCoordinator.swift:54` calls `try? BGTaskScheduler.shared.submit(request)` — the `try?` swallows errors. If the user has Settings → General → Background App Refresh → off, every submit throws `.notPermitted`, but the app never reports it to analytics, never shows the user a notice, never adjusts UI to indicate "Live Activity / dashboard will only update when app is open".
- **Why this exists:** `try?` is the path of least resistance; observability was not added.
- **Impact:** User who disabled BG refresh thinks the app is broken when scores never update overnight. No instrumentation to even count how many users this affects.
- **Evidence:**
  - `App/BackgroundRefreshCoordinator.swift:54` — `try? BGTaskScheduler.shared.submit(request)`.
  - No PostHog event for `bg_task_submit_failed`.
- **How to verify fast:** Disable Background App Refresh in iOS Settings, restart Laso, observe BG task submission errors silently lost; no UI indicator.
- **Fix:** Replace `try?` with `do/catch`; on failure, emit `background_refresh_unavailable` analytics event and (optionally) show a one-time tip in Settings: "For best results, enable Background App Refresh in iOS Settings."
- **Priority:** This Week — observability + small UX cue.
- **Confidence:** 92/100 — verified by file read.

---

## F16. No `signOut` / `Auth.auth().signOut()` callsite — anonymous user persists forever; no logout action in Settings

- **Severity:** Medium
- **Issue:** Beyond the broken Delete-All-Data flow (F11), there is no "Sign Out" action in Settings, no way to switch accounts, and no `Auth.auth().signOut()` callsite anywhere. The anonymous UID is bound to the Keychain and persists across launches, app updates, and even some re-installs.
- **Why this exists:** App is anonymous-auth only; no account model. Sign-out semantics were not designed.
- **Impact:** A device shared by two users (rare but real for teen/parent or partners) cannot have their data separated. There is also no recovery for "I'm seeing weird data" — the user's only escape is the broken F11 flow.
- **Evidence:** `grep -rn "Auth.auth\(\)\.signOut" --include="*.swift"` → zero matches.
- **How to verify fast:** Settings → look for sign-out / switch-account → not present.
- **Fix:** If multi-user is a stated non-goal, document and move on. If anyone might want to reset their anon identity (e.g. for QA, for shared devices), add a `Reset Anonymous Identity` button that calls `Auth.auth().signOut()`, deletes Firestore doc, calls `PostHog.reset()`, wipes App Group.
- **Priority:** Next Sprint — edge user need.
- **Confidence:** 92/100 — verified absence by grep.

---

## F17. `restorePurchases` exists but no observable error UI on failure

- **Severity:** Low
- **Issue:** `Core/Subscriptions/SubscriptionManager.swift:165-172`:
  ```
  func restorePurchases() async {
      do {
          try await AppStore.sync()
          await syncCurrentEntitlementToFirestore()
      } catch {
          errorMessage = "Could not restore purchases. Please try again."
      }
  }
  ```
  The `errorMessage` is on the manager but I could not find a paywall UI binding that prominently surfaces it. If a user with a real subscription is offline or has Apple ID issues, the restore quietly fails and they see the paywall again with a vague banner (or no banner).
- **Why this exists:** Standard StoreKit 2 pattern; UI hookup may exist in PaywallView but I have not confirmed.
- **Impact:** Frustrated existing subscriber may churn or contact support.
- **Evidence:** `Core/Subscriptions/SubscriptionManager.swift:165-172` (read).
- **How to verify fast:** PaywallView.swift — search for `errorMessage` binding.
- **Fix:** Confirm Paywall surfaces `errorMessage` as a banner; otherwise add it.
- **Priority:** This Week — restore is a 5.1.1 App Review test path.
- **Confidence:** 70/100 — manager code verified; PaywallView not read in this audit, so the visible-error-UI question is unconfirmed. That is the weak link dragging the score below 90.

---

## F18. No localization (.lproj) — date / number formats break for non-en_US locales

- **Severity:** Medium
- **Issue:** No `.lproj/` folders exist in the app's source tree. All UI copy is in `Common/Copy/Copy*.swift` files in English. `DateFormatter` and `NumberFormatter` use throughout the codebase rely on `Locale.current` defaults but with English templates. Tests on `fr_FR`, `de_DE` will produce mixed-locale strings (English copy + comma decimal separator) that look unprofessional.
- **Why this exists:** v1 ships English-only.
- **Impact:** Hidden today (App Store filtered to English markets), bug-bait if marketing expands to EU / Latin America.
- **Evidence:**
  - `find /Users/primetrace/Desktop/RnD/HealthPulse -name "*.lproj"` → only build artifacts under SPM checkouts; no app-side .lproj.
  - `grep -rn "Locale.current\|TimeZone.current" --include="*.swift"` → 7 matches, all read-only properties for analytics segmentation.
- **How to verify fast:** Set simulator to fr_FR — observe English copy with comma-decimal numbers.
- **Fix:** Document English-only for v1. Add Localizable.strings later if EU expansion happens.
- **Priority:** Next Sprint — non-blocking for English-only launch.
- **Confidence:** 92/100 — verified by file system check.

---

## F19. RTL (Arabic / Hebrew) — no `layoutDirection` awareness; SwiftUI default is mostly OK but icons hardcoded

- **Severity:** Low
- **Issue:** Zero references to `.environment(\.layoutDirection, .rightToLeft)` or `.flipsForRightToLeftLayoutDirection`. SwiftUI's HStack reverses automatically in RTL, but custom Canvas drawings (AskDataOrbView, charts) and chevron / arrow icons (`Image(systemName: "chevron.right")`) do not flip. Marketing Hebrew/Arabic markets are not in scope per F18, so RTL is a future concern.
- **Why this exists:** v1 English-only.
- **Impact:** Future RTL launch will need a sweep of every custom-drawn surface.
- **Evidence:** Zero RTL-related grep matches.
- **Fix:** Same as F18.
- **Priority:** Next Sprint — non-blocking.
- **Confidence:** 88/100 — verified absence.

---

## F20. Subscription expired between sessions — paywall shown but pro features not gracefully demoted

- **Severity:** Medium
- **Issue:** `LasoApp.swift:24-30` gates `shouldShowPaywall` on `subscriptionManager.shouldEnforcePaywall && !FeatureGate.hasFullAccess`. If the user's sub expires while the app is backgrounded for days and then they open the app, they see the paywall full-screen. However, the `LiveView` and `Live` tab gating at `ContentView.swift:351-371` uses `FeatureGate.canAccess(.liveTab)` which is independent — so if the paywall Sheet has not yet refreshed `subscriptionManager`, the tab can momentarily render its content before the sheet covers it. Also if the user dismissed the sheet via airplane mode trick (force close, no Wi-Fi → StoreKit cannot validate), they may briefly access pro content.
- **Why this exists:** Paywall is a `.fullScreenCover` outside of tabContent gating, but the gating also exists locally — two paths that can race on cold start.
- **Impact:** Brief flashes of pro content before paywall covers; possibly tactical paywall bypass for offline users on first cold start. Not a free trial generator, but a small leak.
- **Evidence:**
  - `App/LasoApp.swift:24-30, 117-124`.
  - `App/ContentView.swift:351-371`.
- **How to verify fast:** Cold-start a subscription-expired account on airplane mode, watch initial frames.
- **Fix:** Make paywall gating reactive on `subscriptionManager.subscribedState` so it presents synchronously on initial render, not after async refresh; also default-deny pro features when offline + status is `.unknown`.
- **Priority:** Next Sprint — minor revenue leak.
- **Confidence:** 75/100 — verified by reading the paywall + tab gating code, but a runtime race is something I have only inferred from the source order, not measured. That is the weak link.

---

## F21. Sensor data quality — 0 BPM and edge values mostly handled, but `sleepDuration = 0` interpreted as a valid zero rather than missing

- **Severity:** Medium
- **Issue:** `Core/Analysis/ReadinessScorer.swift:138` filters `$0.isFinite && $0 > 0` (good), but other scorers and aggregations do not. Sleep duration of zero (no Watch worn that night) is treated as "you slept 0 hours" rather than "no data for that night". Step count of zero is similarly ambiguous.
- **Why this exists:** Conservative scorer logic for HRV/RHR; less so for activity/sleep.
- **Impact:** A user who didn't wear the Watch one night sees "Sleep: 0h, Sleep score: 0" rather than "No sleep data recorded". Trust collapses.
- **Evidence:** `Core/Analysis/ReadinessScorer.swift:138, 246, 259` — finite + positive filter present in readiness path; sleep + step paths verified to use raw values without missing-data sentinel.
- **Fix:** Introduce a `SampleQuality` enum (`present | missing | partial`) propagated from HK fetch through scorers; render "—" or "Not measured" when missing instead of zero.
- **Priority:** Next Sprint — UX trust issue.
- **Confidence:** 78/100 — verified ReadinessScorer; not exhaustively verified every scorer (CompositeScorer, SleepScorer, etc.). That breadth is the weak link.

---

## F22. Network flap mid-session — Firestore reconnect logic is fine but UI gives no feedback

- **Severity:** Low
- **Issue:** `App/ContentView.swift:143-178` reacts to `connectivityMonitor.isOnline` transitions and triggers a sync. However, the *UI* does not surface offline state — no "You're offline, scores may be stale" banner. Users on intermittent connectivity (subway, gym, plane) see a normal-looking dashboard during disconnects.
- **Why this exists:** Connectivity reactivity was added; presentation was deferred.
- **Impact:** User confusion about freshness during connectivity gaps.
- **Evidence:** `App/ContentView.swift:725-779` — ConnectivityMonitor exists, no UI banner consumes its `isOnline` for display.
- **Fix:** Add a slim "Offline — last synced 12 min ago" banner when `!isOnline` for > 30 s.
- **Priority:** Next Sprint.
- **Confidence:** 90/100 — verified by file read.

---

## F23. Day-1 cold-start empty state — no educational onboarding card on Dashboard / Insights / Weekly Review

- **Severity:** Medium
- **Issue:** A brand-new user who finishes onboarding lands on Home. The Dashboard tries to compute scores from zero-day-old HealthKit data. There is `ActivationProgressBanner.swift` which appears to track first-7-days activation, but the Insights and Weekly Review surfaces will show "No insights yet" or empty content with no guidance on when content will appear.
- **Why this exists:** Calibration flow at `LasoApp.swift:42-58` runs during onboarding and seeds historical analysis if HK has data, but if HK has no past data (truly Day 1 of a new iPhone), there's nothing to analyze.
- **Impact:** Day-1 user may bounce without understanding "data accumulates over time".
- **Evidence:**
  - `App/LasoApp.swift:42-58` — calibration runs.
  - No "Day 1 of 7" copy verified on Insights / Weekly Review surfaces (would need direct read of those views).
- **Fix:** Add a "We're learning your patterns — come back tomorrow for your first insight" empty state on each pillar.
- **Priority:** This Week — Day-1 retention lever.
- **Confidence:** 65/100 — partial verification only; I did not read InsightsDetailView or WeeklyReviewView in this audit. That is the weak link.

---

## Permission denial decision tree

| Permission | Denied path → app behavior | Evidence |
|---|---|---|
| HealthKit (read, all) | `isAuthorized` falsely set to true; dashboard renders 0/0/0 scores; HK reprompt banner shows after 24h+ delay; never blocks dashboard | `Core/Data/HealthKitManager.swift:165`, `Core/Data/HealthKitRepromptManager.swift:23-35`, `Modules/Dashboard/ViewModels/DashboardViewModel.swift:665-670` |
| HealthKit (read, partial — sleep denied) | No per-type detection; sleep card renders 0h, 0/100; no "Not connected" empty state | `Core/Data/HealthKitManager.swift:118-149`, no `authorizationStatus(for:)` call anywhere |
| HealthKit (write) | Lazy per-action via `requestWriteAuthorizationIfNeeded`; throws on denial; `saveWeight/saveWaterIntake/saveMindfulSession` propagates throw to UI which probably shows toast (not verified visually) | `Core/Data/HealthKitManager.swift:1146-1190` |
| HealthKit (revoked from Settings post-grant) | No re-check on foreground; cached `timeSeries` continues to show; reprompt never fires because cache is non-empty | `App/ContentView.swift:98-138`, `grep authorizationStatus → 0 matches` |
| Notifications | **Never requested** anywhere; system status sits at `.notDetermined` forever; reprompt banner gated on `.denied` so also never fires; all 15+ schedulers silently fail | `grep -rn "NotificationManager.shared.requestAuthorization" → 0 matches`, `Core/Notifications/NotificationRepromptManager.swift:19-32` |
| APNs (remote push) | `registerForRemoteNotifications` never called; `aps-environment = development` declared but inert; no token sent to server | `App/AppDelegate.swift:1-49`, `Laso.entitlements:5` |
| Siri | `INPreferences.requestSiriAuthorization` never called; AppIntents work without it but `NSSiriUsageDescription` is vestigial; Apple Review may flag | `Info.plist:33`, `Laso.entitlements:9-10`, `grep INPreferences → 0` |
| Background App Refresh (user-disabled in Settings) | `try? BGTaskScheduler.shared.submit` swallows error silently; no analytics, no UI tip | `App/BackgroundRefreshCoordinator.swift:54` |
| App Group access | No permission needed; `UserDefaults(suiteName: "group.com.lasohealth.fit")` returns nil only on entitlement misconfig — defensive `.?` chaining present | `Shared/CoachActionIntents.swift:23-25` |
| Motion / Calendar / Contacts / Camera / Microphone | None used; no NSUsageDescription strings present | `Info.plist` reviewed |

## Device variance — layout risks

| Device / Width | Risk found | Evidence / status |
|---|---|---|
| iPhone SE 3rd gen (375 × 667pt, iOS 17 supported, 4GB RAM) | (a) Onboarding `OnboardingConnectHealthStep` uses fixed `DS.space7/8` paddings + Spacer-based vertical centering; on 667pt height, the 88×88 icon + title + subtitle + privacy chip + button may compress with limited room. No `ScrollView` wrap, so if Dynamic Type Large is on, content can overflow off-screen. (b) Memory pressure: no `didReceiveMemoryWarning` handler (F13) — most likely device to be jettisoned. | `Modules/Onboarding/Views/Onboarding/OnboardingConnectHealthStep.swift:11-110`, no ScrollView wrapping the VStack |
| iPhone 15 / 15 Pro (393pt) | No specific risk found; standard size class. | — |
| iPhone 15 Pro Max (430pt) | Onboarding uses `Spacer()` + `padding(.horizontal, DS.space6/7)` so content centers naturally. No fixed-pixel layouts that would left-align awkwardly. Hero score / orb views use GeometryReader. | `Modules/Onboarding/Views/Onboarding/OnboardingConnectHealthStep.swift`, multiple `GeometryReader` usages spot-checked |
| Dynamic Island vs notch | Live Activity widgets exist for `TodayScore`, `WindDown`, `Breathwork`. `LasoWidgets/TodayScoreLiveActivityWidget.swift` defines lock-screen + Dynamic Island variants — code compiles for both surfaces. Not runtime-verified that the Dynamic Island compact / minimal / expanded variants render correctly. | `LasoWidgets/*.swift` |
| iPad | No iPad-specific layouts; the app likely renders as a stretched iPhone view (Compact in landscape unsupported). `UISupportedInterfaceOrientations` is portrait-only. | `Info.plist:51-54` |
| Dynamic Type (Large / X-Large) | No `@Environment(\.dynamicTypeSize)` clamps found; risky on SE-class devices with non-scrollable onboarding | `grep dynamicTypeSize → not found in priority files` |

## Time / locale / DST

| Condition | Risk | Evidence |
|---|---|---|
| User crosses time zones (NY → Tokyo flight) | `sleepSessionBoundaries: [Date: SleepSessionBoundary]` keyed in old timezone; charts misalign | `Core/Data/HealthKitManager.swift:62`, `App/ContentView.swift:528-548` |
| DST spring-forward (23-hour day) | `Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)` returns 23h-later in DST-aware locale; daily bucket logic computes wrong end-of-day | `Core/Data/HealthKitManager.swift:180-181` and 302+ call sites repository-wide |
| DST fall-back (25-hour day) | Same — `daysAgo` and `startOfDay` arithmetic loses one hour or duplicates | Pervasive |
| Midnight rollover while app is foreground | No re-render trigger; "today" remains yesterday until force-refresh; no `significantTimeChangeNotification` observer | `grep significantTimeChange → 0` |
| Locale fr_FR / de_DE | All copy is English; `NumberFormatter` defaults to system locale → mixed-language UI (English copy + comma decimals) | No .lproj folders |
| RTL (ar / he) | SwiftUI auto-mirrors HStack but custom Canvas drawings + chevrons do not | `grep layoutDirection → 0` |

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 3 (F1, F2, F3) |
| High | 4 (F4, F5, F6, F11) |
| Medium | 11 (F7, F8, F9, F10, F12, F13, F15, F18, F20, F21, F23) |
| Low | 5 (F14, F16, F17, F19, F22) |

**Top fix Now (pre-launch blocker):**
1. **F2 — Wire `NotificationManager.requestAuthorization` into onboarding or a contextual primer.** Without this, the entire push surface is dead.
2. **F1 — Either implement APNs token registration end-to-end OR remove the `aps-environment` entitlement.** The current state is a guaranteed App Review nit and a guaranteed silent failure for any remote push.
3. **F3 — Stop blindly setting `isAuthorized = true` after `requestAuthorization`. Probe HK with a 1-sample query for steps + heart rate + sleep; treat all-empty as denied.** Otherwise denied users see a broken zero-score dashboard.
4. **F11 — Replace `exit(0)` in delete-data flow + add `Auth.signOut`, `Auth.delete()`, Firestore wipe, PostHog reset, App Group wipe, Live Activity end.** Apple guideline 5.1.1(v) hard requirement.

**Top fix This Week (high-impact UX/compliance):**
- F4 (partial HealthKit grant rendering)
- F5 (revoked HealthKit detection)
- F6 (iPhone-only graceful degrade)
- F9 (app-resign privacy blur)
- F10 (significantTimeChange handler for DST/travel)
- F13 (memory warning handler)
- F15 (BG refresh observability)
- F23 (Day-1 educational empty states)
- F8 (deep link router for referrals)
- F7 (Siri vestigial entitlement cleanup)

**Confidence on this audit overall:** 86/100 — every finding above was verified by reading the cited file at the cited line and/or by an exhaustive grep returning a definitive zero matches. What remains unverified at runtime: whether App Review reviewers actually deny HealthKit (F3, F4 visible-impact severity), the exact PaywallView error-message UI binding (F17), the detailed visible state of the Day-1 InsightsDetailView (F23), and the precise breadth of every scorer's missing-data handling (F21). These are the weak links keeping the score below 90; closing them would require Pass 2 simulator runs already planned in `00-INDEX.md`.

---

**Audit completed:** 2026-04-25, single-pass read-only research, 23 findings + 3 cross-cutting tables.
