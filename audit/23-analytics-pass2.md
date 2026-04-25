# 23 — Analytics / PostHog Pass-2 Audit (NEW issues only)

App: Laso (com.lasohealth.fit), iOS 17+, PostHog SDK v3+, EU host.
Repo: /Users/primetrace/Desktop/RnD/HealthPulse
Scope: Issues NOT covered by `audit/07-analytics-posthog.md` (Pass 1). Same severity scale.
Method: full re-read of `Core/Tracking/{PostHogManager,AppAnalytics,SessionTracker,SectionTracker,FeedbackPromptManager,AppStoreReviewManager}.swift`, `App/{AppDelegate,AppLaunchCoordinator,ContentView}.swift`, `Common/Components/PMFSurveySheet.swift`, `Modules/Settings/Views/SettingsView.swift` (data-deletion path), `Core/Subscriptions/SubscriptionManager.swift`, `Core/Config/{RemoteConfigManager,FeatureGate}.swift`, `Core/Data/JournalStore.swift` plus targeted greps for `flush`, `optOut`, `identify`, `register`, `groups`, `getFeatureFlag`, lifecycle hooks, attribution, and free-text parameters.

---

## TL;DR — Pass 2 in one screen

Pass 1 caught the launch-blocker shape (key leak, session replay, no consent, no identify, no reset, referral-code PII). Pass 2 finds **eight further P0/P1 issues that are independent of the Pass 1 set** and most of them are NEW — they survive even after every Pass 1 fix is applied:

1. **PMF segment + benefit raw user free-text shipped to PostHog.** `trackPMFSegmentResponse(segment:)` and `trackPMFBenefitResponse(benefit:)` send the user's typed answer verbatim (truncated to 100 ch by the sanitizer). Pass 1's PII table claimed these were `text_length` only — that's true only for `improvement`. Health-app users will type chronic-condition descriptors here (e.g., "my hypertension", "my IBS"). **P0 PII.** (`AppAnalytics.swift:2985-2996`, `PMFSurveySheet.swift:132,158`)
2. **"Delete All Data" never resets PostHog.** The Settings → Delete All Data flow wipes UserDefaults + Encrypted Store + HealthDataStore and exits the process — but never calls `PostHogSDK.shared.reset()` and never invokes PostHog's GDPR-deletion HTTP endpoint. The user thinks their data is gone; the PostHog distinct_id and every event is preserved on PostHog cloud. **GDPR right-to-erasure violation candidate, P0.** (`SettingsView.swift:671-692`)
3. **Session boundary is broken.** `trackSessionStart()` is called on every `oldPhase != .active → .active` scenePhase transition (`ContentView.swift:98-101`). Every Control Center pull / lock-screen glance / banner dismiss spawns a new `session_id`, increments `totalSessions`, and re-fires `setDemographicProperties` + `updateJourneyProperties` (each emits a PostHog `$set`). DAU/WAU is inflated, session-duration analytics are inflated × 3-5, and `streak_rest_credit_granted` can fire repeatedly per day. **P1.** (`ContentView.swift:98-141`, `AppAnalytics.swift:673-744`)
4. **Sleep-onset and bedtime epoch timestamps are sent in clear.** `trackLiveActivitySleepOutcome` ships `bedtime_epoch` (Unix sec) and `sleep_onset_epoch` (Unix sec) without bucketing or truncation (`AppAnalytics.swift:2174-2183`). Combined with the `timezone` user property and PostHog's server-recorded IP, this is precise behavioural surveillance: the third party knows when the user falls asleep, to the second. Pass 1's PII table did not include this. **P0 PII.**
5. **`afib_count`, `clinical_stage`, `current_state` (HealthState), `chronotype`, `cycle_phase` shipped as raw clinical descriptors.** `trackECGAnalysisCompleted(afibCount:)`, `trackClinicalInsightGenerated(stage:trajectory:)`, `trackHealthStateTimelineViewed(currentState:)`, `trackCircadianAnalysisCompleted(chronotype:)`, `trackWorkoutPlanGenerated(cyclePhase:)` all bypass `metricParameterKeys` because their *keys* are not in the anonymizer set. AFib count > 0 + region + timezone + device-model is re-identifiable. **P0 PII.** (`AppAnalytics.swift:1670-1709, 1986-1989`)
6. **`trackInsightMarkedUnhelpful(reason:)` and `trackRecommendationSkipped(reason:)` accept free-text from a future TextField.** The strings are sanitized to 100 ch but not whitelisted. Today the call sites pass empty/enumerated reasons; a future UI that asks "why?" will silently leak. Same shape as the raw `error_message` problem in Pass 1's L3. **P1 latent.** (`AppAnalytics.swift:1915-1920, 1962-1967`)
7. **No PostHog flush hook on app lifecycle.** No `flush()` is called from any of: `applicationWillResignActive`, `applicationWillTerminate`, `scenePhase == .background`, `scenePhase == .inactive`, or the Settings-delete-all-data exit. The PostHog SDK's auto-flush will catch most events on its own schedule, but the `session_end` event fired in `.background` (line 139 of `ContentView.swift`) and the deletion flow (`exit(0)` at `SettingsView.swift:690`) can lose events to the in-memory queue. **P1.** (`AppDelegate.swift`, `ContentView.swift:138-141`, `SettingsView.swift:689-690`)
8. **`trackDeepLinkOpened` is fully orphan code.** It's defined (`AppAnalytics.swift:3066`), referenced in the schema comment (`:321`), and never invoked. There is no `onOpenURL`, no `onContinueUserActivity`, no `application(_:open:)` anywhere. Marketing attribution is therefore **0%** at launch. Pass 1 listed it in the inventory without flagging the orphan status. **P1 attribution gap.** (`AppAnalytics.swift:3066-3073`)

Plus: 12 more findings on event versioning, person-property staleness, type stability, build environment, batching defaults, cross-property collisions, `trackJournalEntryCreated` accepts an unused `value` parameter, `subscription_expired` overloads two distinct lifecycle moments, group analytics absent (subscription tier should be a PostHog group), `feature_flag_called` telemetry is impossible because PostHog flags are unused, and the `daily_active` event lacks a per-day idempotency guard at the client (relies on PostHog's distinct-day counting which still bills per event).

---

## A. Event versioning / schema migration

**A1 [P1] — No event-schema version is captured anywhere.** Grep for `event_v|schemaVersion|eventVersion|EVENT_VERSION` returns zero hits. There is no `tracker_version`, `schema_version`, or `_v` suffix on any event name. Consequence: when a property's meaning changes (e.g., `score_bracket` widens from 5 to 10 buckets, or `engagement_level` adds `super_user`), every dashboard built against the old shape silently mixes old and new. PostHog has no native schema migration, so the burden falls entirely on the producer. **Fix:** add a static `analyticsSchemaVersion = "2025.04.1"` and emit it as a super-property via `PostHogSDK.shared.register([:])`. Bump on every shape change. (verified absent across all of `Core/Tracking/`)

**A2 [P2] — Canonical-rewrite logic is unversioned.** `canonicalEventName(...)` (`AppAnalytics.swift:2722-2877`) is the most fragile piece of the analytics layer — a one-character rename of an `AppFeature` rawValue silently renames the event in PostHog. Add a regression suite (manual is fine — just print all canonical names at app startup in DEBUG and diff against a checked-in golden file). Pass 1 noted the two-name problem; this finding adds the migration angle.

---

## B. Feature flag mechanics

**B1 [P2] — UI does not block on Remote Config fetch.** `AppLaunchCoordinator.swift:35-37` runs `await remoteConfigManager.fetchAndActivate()` inside a detached `Task`. Until that completes (network round-trip, 200-2000ms typical), every `RemoteConfigManager.boolValue/intValue/stringValue` call returns the *defaults set* value (`RemoteConfigManager.swift:55-57, 30-37`). On first install (no cached config from a prior session), this means: the paywall, free-tier limits, and feature gates render with hardcoded defaults for the first ~1-2s of the user's life with the app — a flicker. Acceptable, but undocumented. **Fix:** either gate the splash on first-fetch-or-2s-timeout, or document the default-and-fetch behaviour. (verified by reading lines 24-39 of `RemoteConfigManager.swift` and lines 35-37 of `AppLaunchCoordinator.swift`)

**B2 [P1] — Default values shipped for every flag — but hidden from this audit.** `RemoteConfigManager.setDefaults(Self.defaults)` is called at init (`RemoteConfigManager.swift:37`). Without seeing the `defaults` static dictionary we can't verify each flag has a *safe* default. **You should manually verify** every key in the `defaults` dict has a value that does not catastrophically misroute users when Firebase is unreachable (e.g., a `paywall_enabled = true` default that locks free users out, or `pmf_survey_enabled = true` that spams day-1 users).

**B3 [P2] — Flag cache eviction across app upgrades.** Firebase RC's `minimumFetchInterval = 3600` (1 hr) means after an app upgrade, the cached values from the *prior* version persist for up to 1 hour. If a v2 launch ships with a renamed flag key, v2 users see the v1-cached default until the next fetch. **Fix:** call `remoteConfig.fetch(withExpirationDuration: 0)` once at first launch of a new app version (key the gate off `CFBundleVersion` change). (no such gate found — verified by grep `"appVersionDidChange|previousAppVersion|migrateFromVersion"` returning 0)

**B4 [P1] — PostHog feature flags are unused (Pass 1 noted) AND `FeatureGate.canAccess(...)` does not emit any analytics event.** Even if PostHog flags were added, you cannot run a behaviour-based experiment because the gate decision is invisible to PostHog. Today: a free user denied a feature → no event fires. PostHog cannot answer "what fraction of free users hit the gate this week". **Fix:** in `FeatureGate.canAccess`, on each call, fire `feature_gate_evaluated(feature, tier, allowed, source: "rc"|"posthog")`. (verified absent — grep `feature_flag_called|flag_evaluated` returns 0)

---

## C. Group analytics

**C1 [P2] — PostHog group analytics not used at all.** Grep `posthog\.group|setGroup|groupAnalytics|GroupProperty` returns 0 hits. PostHog's group analytics is the right model for `subscription_tier` (treat `pro|trial|free` as groups, not as person-properties), and would let you count "DAU among pro" without a pseudo-WHERE on every query. Today every cohort filter reads `user_tier = "pro"` from per-event enrichment — works but slower and more brittle. **Fix:** call `PostHogSDK.shared.group(type: "subscription", key: <userTier>)` on every status change. Same recommendation for `app_version` (treat as a group when running compatibility cohorts). Cost is zero; benefit is dashboard performance.

---

## D. Funnel definition

**D1 [P2] — There is no single source of truth for any funnel.** The schema reference comment (`AppAnalytics.swift:208-345`) lists conceptual funnels but the actual sequence is implicit in event order. A new analyst building "first-app-open → first-score" cannot know whether to use `Application Opened` (auto-capture) or `app_session_started` (canonical) as step 1, and whether `first_score_generated` or `health_analysis_completed` represents the conversion. **Fix:** ship a `FUNNELS.md` in the repo with PostHog-ready event sequences for the 4 launch funnels (onboarding, activation, paywall, retention). Out-of-scope to write here, but the absence is a finding.

**D2 [P3] — `subscription_expired` is overloaded.** `trackTrialExpired()` fires `subscription_expired` with `converted: 0` (`AppAnalytics.swift:1067-1077`); paid-sub natural expiry routes through `trackSubscriptionCancelled()` instead (`:1230-1232`). So PostHog's `subscription_expired` event is *actually* "trial expired without converting". Funnel-builders who interpret it literally as "any subscription expired" will overcount. Pass 1 listed this in the inventory; this finding is the funnel-impact angle. **Fix:** rename the trial-expiry event `trial_expired_unconverted` and reserve `subscription_expired` for paid-expiry only.

---

## E. Cohort sync

**E1 [P3] — No PostHog cohort consumed by the app.** PostHog cohorts are read-only on the SDK side (they affect feature-flag targeting, not in-app behaviour by themselves). Since PostHog flags are unused, cohorts cannot influence the app today. The cross-cut implication is that a "show survey to power users only" rollout requires either a PostHog feature-flag or a Firebase RC condition keyed on a property the app sets locally — today the PMFSurveyManager (`PMFSurveySheet.swift:232-273`) hardcodes `14 days + 10 sessions + 90-day cooldown`. Acceptable, but flag for future flexibility.

---

## F. Surveys

**F1 [P2] — PostHog Surveys explicitly disabled (`PostHogManager.swift:38: config.surveys = false`), but the in-app PMF survey logic is hand-rolled.** The hardcoded gating thresholds (`PMFSurveyManager.minDaysSinceInstall = 14`, `minSessions = 10`, `cooldownDays = 90`) cannot be tuned without an app update. PostHog Surveys would let product change criteria from the dashboard, but only if `config.surveys = true` and you accept the cohort-based targeting comes from PostHog. **Trade-off:** keeping `surveys = false` is the right call given the consent + privacy posture (Pass 1 B1/B3); just promote `minDaysSinceInstall/minSessions/cooldownDays` to Firebase Remote Config keys so product can flip without a release. (verified by reading `PMFSurveySheet.swift:242-249`)

---

## G. Heatmaps & session replay

**G1 [P1] — Session replay is the heatmap surrogate.** PostHog's screen heatmap feature is delivered *through* session replay recordings, post-hoc. Pass 1 already flagged session replay as P0 disable. But the cross-cut here: even if session replay is left enabled with consent, Laso has no per-screen heatmap dashboard plan, and no `tap_x_coord`/`tap_y_coord` capture in `block_tapped`, so the team cannot do "where on the score card do users tap most" analysis without enabling replay. Either commit to replay-with-consent (Pass 1 fix) or instrument coordinate-level taps for the highest-value screens. **Recommendation:** disable replay (Pass 1) and *do not* substitute coordinate capture — heatmaps are a nice-to-have, replay risk on a health app is a legal-to-have.

---

## H. Console error capture

**H1 [P2] — `os_log`, `Logger`, `print` calls are NOT captured to PostHog.** Greps over `Core/Tracking/` confirm no swizzle / interception of `os.Logger` or `OSLog`. Domain errors must explicitly call `AppAnalytics.recordNonFatal(...)` or `PostHogManager.captureError(...)`. The 11 `recordNonFatal` call sites Pass 1 enumerated cover roughly the critical paths but it's not exhaustive — every `catch { logger.error(...) }` block in the codebase is invisible to PostHog unless paired with a tracking call. **Fix:** add a wrapper `func logAndTrack(_ error: Error, context: String)` and migrate the codebase to it — too large to do retroactively, but mark the contract for new code in CLAUDE.md.

---

## I. A/B test variant

**I1 [P2] — No variant identifier exists, period.** No `experiment_id`, no `variant_id`, no `assigned_at` timestamp anywhere. When the team starts experimenting, they need: (a) variant assignment at first session, (b) variant persisted in encrypted storage so reinstalls preserve it, (c) variant shipped as super-property on every event. Today there is nothing to extend. Pass 1 noted "zero A/B tests today"; this finding is the *infrastructure-absence* angle. **Fix:** add a `ExperimentManager` wrapper now (deterministic hash of distinct_id → variant per experiment_id), and call `PostHogSDK.shared.register(["variant_<id>": "..."])` on assignment. Same hook then doubles for PostHog feature flags later.

---

## J. Test pollution & build environment

**J1 [P1] — `app_environment` super-property absent.** No event distinguishes Debug / TestFlight / Release / Beta / CI. Pass 1's U1 already flagged single-project pollution; this finding is the orthogonal one — even *with* a separate dev project, dashboards cannot filter "exclude TestFlight builds" because no flag is shipped. **Fix:** at `setUserProperties` time (or via `register`), include `app_environment ∈ {debug, testflight, appstore}` derived from `Bundle.main.appStoreReceiptURL?.lastPathComponent` (sandboxReceipt → debug/testflight) and `#if DEBUG`. (verified absent via grep)

**J2 [P2] — `UITestMode.isEnabled` short-circuits SDK setup, but onboarding's raw direct-PostHog calls (`OnboardingConnectHealthStep.swift:70`, `OnboardingMirrorMomentStep.swift:320,330`) check `isConfigured` only via the SDK guard inside `PostHogManager.capture` — they never branch on `UITestMode` themselves. If a future dev reaches into `PostHogSDK.shared.capture` directly bypassing the `PostHogManager` wrapper, UI test mode no longer protects them. Pass 1's E1 is about enrichment loss; this is the *test-mode-leak* angle.

---

## K. Sample rate, batching, retries, queue

**K1 [P1] — Zero PostHog batching configuration.** No `flushAt`, `flushInterval`, `maxQueueSize`, `maxBatchSize`, `requestTimeout`, `maxRetries` set anywhere (`PostHogManager.swift:21-43` is the entire config). PostHog iOS SDK defaults are: `flushAt = 20`, `flushInterval = 30s`, `maxQueueSize = 1000`. A health app that captures ~30-120 events per session (Pass 1 §18) means a normal session triggers 1-6 flushes — chatty. With `engagement_level = power_user`, the per-session count gets higher; cellular users pay for it. **Fix:** set `flushAt = 50`, `flushInterval = 60`, leave `maxQueueSize` at default. (verified by reading `PostHogManager.swift:21-43` line by line)

**K2 [P2] — No code-level rate limit.** PostHog has no client-side throttle. A bug that fires `block_tapped` in a tight loop (e.g., a `View.body` reads a binding that triggers a tap analytics call on every render) would shovel events at the SDK's queue and eventually drop them when `maxQueueSize=1000` is hit — silently. **Fix:** add a per-event-name token-bucket in `AppAnalytics.logEvent` (e.g., 30 events of the same name per minute, log-and-drop after). Even simpler: log `[event_name → last 60s count]` and `recordNonFatal("event_floods", context: name, ...)` on overflow.

**K3 [P3] — No offline-queue eviction policy is exposed.** PostHog SDK persists events to disk (default behaviour), evicting oldest on `maxQueueSize`. For a health app with HealthKit background delivery it's possible to accumulate hundreds of background-fired events while offline, and lose oldest on queue overflow on reconnect. Set `maxQueueSize` explicitly to make the contract visible. (verified by reading PostHogConfig usage)

---

## L. Lifecycle / sessions / flush

**L1 [P0] — `session_end` ships in `.background` but is not flushed.** `ContentView.swift:138-141` fires `trackSessionEnd()` on background, then schedules background-refresh — no `PostHogManager.shared.flush()` follows. iOS may suspend the process before the SDK's auto-flush timer fires, especially under low memory. The most important session event is the most likely to be lost. **Fix:** add `PostHogManager.shared.flush()` after `trackSessionEnd()` and protect with a `UIApplication.shared.beginBackgroundTask(...)` if it must complete. (verified at `ContentView.swift:138-141`)

**L2 [P1] — `applicationWillTerminate` not implemented.** `AppDelegate.swift` (45 lines, fully read) has no `applicationWillTerminate` method. iOS rarely calls this on user-force-quit but does call it on system-initiated termination. Without a flush there, the queue dies with the process. **Fix:** add `func applicationWillTerminate(_:)` that calls `PostHogManager.shared.flush()`. (verified by reading the entire AppDelegate.swift)

**L3 [P1] — Session boundary is broken: every scenePhase active-transition is a new session.** `ContentView.swift:98-101` does `if newPhase == .active && oldPhase != .active { startSessionAnalytics() }`. iOS goes inactive → active for: Control Center pull-down, lock-screen swipe, banner notification dismiss, system alert dismiss, AirPods pairing prompt, Apple Pay sheet. Each of these spawns a new `session_id`, increments `totalSessions` (`SessionTracker.swift:321`), increments daily streak inputs, re-fires `setDemographicProperties`, re-fires `setUserProperty` for ~10 keys, and emits a fresh `session_start` event. Real session count is inflated 2-5×; `app_session_ended` does not always pair with the matching start because background-then-active does not run an end first. **Fix:** add an idle-timeout (e.g., 30 min like PostHog's own definition): if `lastActiveDate` was less than 30 min ago, do not start a new session — just resume the existing one. (verified by reading `ContentView.swift:98-141` plus `SessionTracker.swift:132-150`)

**L4 [P1] — `daily_active` has no client-side per-day guard.** `trackDailyActiveUser()` fires from `startSessionAnalytics()` (`ContentView.swift:628`), which is called on every active-transition. With L3 above, a single power-user day can fire `daily_active` 10+ times. PostHog's distinct-day counting on the dashboard side will collapse to 1 DAU, but the *event count* is what bills. **Fix:** gate `trackDailyActiveUser` on a UserDefaults-stored "last DAU date" check — only fire if today is a new calendar day vs the stored value. (verified at `AppAnalytics.swift:1717-1723`)

**L5 [P2] — `applicationWillResignActive` not used.** Some events (PMF survey responses, notification permission grants, settings changes) are at risk of loss if the user kills the app within 30s of the action. A defensive `flush()` on `willResignActive` would close that gap with negligible cost.

---

## M. Marketing attribution / deep links

**M1 [P1] — `trackDeepLinkOpened` is orphan code.** Defined at `AppAnalytics.swift:3066` and never invoked. The app has no `onOpenURL`, no `application(_:open:options:)`, no `onContinueUserActivity` (verified by grep of `App/`, `Modules/`, `Common/`). Universal links and custom-scheme links would silently no-op for analytics. The `campaign` parameter is ready and unused. **Fix:** wire `onOpenURL` at `WindowGroup` level in `App/HealthPulseApp.swift` (or wherever the SwiftUI `App` lives) and call `trackDeepLinkOpened(url:source:campaign:)` with parsed `utm_*` query items. Strip identifying params before send (Pass 1's PII concern remains).

**M2 [P2] — No first-touch attribution captured.** PostHog supports `$initial_referrer` / `$initial_referring_domain` super-properties (auto-set on first event when the SDK is configured to autocapture). Apple does not expose Search Ads UTMs to clients without iAD/AdAttributionKit, but Branch / Adjust / AppsFlyer integrations can. None of those exist (verified by grep `appsflyer|adjust|branch.io|branchSDK|AppsFlyer|Adjust|BranchSDK|AdAttributionKit` returning 0). For a paid-launch budget, this means CAC-by-channel will be unattributable post-install. **Fix or accept:** if the launch is organic-only, document the constraint; if paid, integrate AdAttributionKit (Apple's first-party SKAdNetwork successor) or Branch before launch.

**M3 [P3] — No `$initial_*` properties verified.** Without an actual install on a device, we cannot confirm whether `captureApplicationLifecycleEvents = true` (`PostHogManager.swift:22`) is causing PostHog to emit `Application Installed` with the `$initial_referrer` set on first launch. Documented as low-confidence (need runtime check).

---

## N. Crash telemetry depth

**N1 [P1] — `app_crash` ships `signal_number` (Int) and `signal_name` (String) but no app_state context.** `PostHogManager.swift:155-159` captures `crash_type`, `signal_name`, `signal_number` only — no `current_screen`, no `last_event`, no `session_id`, no memory pressure, no thermal state. Pass 1's L1 covered the symbolication problem; this finding is the orthogonal *crash forensics* angle. The crash is logged but you can't tell what the user was doing. **Fix:** read `SessionTracker.shared.currentScreen`, last 5 event names from a `RingBuffer`, and `ProcessInfo.processInfo.thermalState` inside the signal handler — but be careful about async-signal-safety (only `signal-safe` operations are allowed; this rules out most Swift APIs and would need to pre-stage these strings in a static buffer updated on the main thread).

**N2 [P2] — Crash handler `flush()` after capture is best-effort.** `PostHogSDK.shared.flush()` is async — followed immediately by `signal(SIG_DFL); raise(...)` which kills the process synchronously. The flush almost certainly does not complete a network round-trip. Result: crash event sits in PostHog's local disk queue and is sent on next launch (acceptable, but documents a 1-session attribution lag). Pass 1 mentioned this in passing; flagging the lag as an explicit finding.

**N3 [P3] — `URLError` events are not auto-captured.** Network errors (timeouts, no-connection, server 5xx) are only logged when explicit `recordNonFatal` calls wrap them. Many `Task { try? await ... }` patterns in the codebase swallow `URLError` silently. **Fix:** add a `URLProtocol` interceptor in DEBUG only (production cost too high) to dump network error rates to the console.

---

## O. HealthKit permission timing

**O1 [P1] — No `time_to_answer` measurement on HK permission.** `trackHealthPermissionRequested(metrics:)` fires when the prompt is *about to* show; `trackHealthPermissionResult(granted:denied:total:)` fires after. Neither ships a duration. The two events share no `request_id`. So you cannot answer "median time users take to respond to the HK prompt" — a critical drop-off proxy. **Fix:** capture the timestamp at request time, attach `time_to_answer_sec` to the result event, plus a UUID `permission_request_id` on both. (`AppAnalytics.swift:1796-1814`)

**O2 [P2] — Per-HKObjectType result not captured.** Pass 1 K1 noted aggregate-only counts; this is the same issue from a different angle — the `HKHealthStore.authorizationStatus(for:)` API returns per-type status that the app could ship as `granted_categories: ["heart","sleep"]` (already coarsened). No code does this. (verified at `AppAnalytics.swift:1807-1814`)

---

## P. Property type & shape stability

**P1 [P1] — Boolean-as-Int convention is consistent in `sanitizeParameters` (`AppAnalytics.swift:2942-2943`) — every Bool is coerced to `1|0`.** That's fine internally but breaks the moment a raw `PostHogSDK.shared.capture(...)` call ships a real Bool: PostHog sees `true` in some events and `1` in others on the same property name. Pass 1 E1 enumerates the 4 raw call sites; this is the cross-cutting effect — `healthkit_authorized: Bool true` (raw) vs `granted: 1` (canonical) on permission-related dashboards. (verified at `OnboardingConnectHealthStep.swift:70`, `AppAnalytics.swift:1808-1810`)

**P2 [P2] — `trial_converted` is sent as both Int (1/0) and String ("yes"/"no"/"pending").** `subscription_purchased` ships `trial_converted: isTrialConversion ? 1 : 0` (`AppAnalytics.swift:1120`); `paywall_dismissed` ships `trial_converted: defaults.string(forKey: ...) ?? "pending"` (`:1097`). Same property name, two types — PostHog's column inference will reject one or coerce both to string, breaking funnel filters that test `= 1`. **Fix:** unify on Int-or-string for the same key across the codebase.

**P3 [P3] — Timestamp precision inconsistent.** `bedtime_epoch` and `sleep_onset_epoch` are seconds (`Int`, `AppAnalytics.swift:2174-2178`); `notif.sent.<id>` is also seconds; but `latency_minutes` is computed in minutes (`:1563`). Pass 1 didn't note the convention. Document it: prefer second-precision for absolute timestamps, integer-minute for durations under a day, integer-second for durations within a session.

**P4 [P3] — Property name collisions across canonical/raw paths.** `metric_used` (workout) vs `metric` (insight) vs `metric_a/metric_b` (correlation) — PostHog sees these as separate columns, no problem. But `screen` is sent both as event-name suffix (after canonical rewrite) AND as property — analysts have to know which to filter on. Pass 1 covered the two-name event problem; this is the property-side mirror.

---

## Q. Person-property staleness

**Q1 [P1] — Profile updates do not propagate to PostHog person properties immediately.** `setDemographicProperties()` (`AppAnalytics.swift:376-436`) reads age (from encrypted DOB), gender, country, language, etc. It is called only on `trackOnboardingCompleted` (`:528`) and `trackSessionStart` (`:739`). If the user edits their gender or DOB in Settings *between* sessions, PostHog will hold stale properties until the next foreground transition. Worse: with the L3 inflated-session bug, the user could effectively "fix" this on the next active-transition — but only because of the bug. **Fix:** add a `NotificationCenter` post on profile-mutating Settings flows, and have `AppAnalytics` listen and call `setDemographicProperties()` immediately. (verified at `AppAnalytics.swift:528, 739` — only two callers)

**Q2 [P2] — Subscription-tier $set fires per-transaction-update.** `updateSubscriptionProperties(status:)` (`AppAnalytics.swift:1207-1244`) is called from `SubscriptionManager.handleTransactionUpdate()` (`SubscriptionManager.swift:438`) which runs on every entry in the `Transaction.updates` async sequence — including Apple's periodic re-verification pings. Each call emits two `$set` events (`subscription_status`, `user_tier`) plus possibly `trial_day_check` event-property fires. On a slow morning that's 5-10 useless `$set` events per session. PostHog charges per event including `$set`. **Fix:** check whether properties actually changed before firing `$set` (read current value from a UserDefaults cache, compare, only fire on diff).

**Q3 [P2] — `trial_day_check` fires on every `.trial` status update.** Same loop. The intent appears to be "fire once per session" but the gate is missing. Daily-check semantics demand a per-day idempotency key. (verified at `AppAnalytics.swift:1216` — unconditional fire)

---

## R. Logout / multi-user

**R1 [P1] — Logout flow is non-existent.** Pass 1 D2 noted `reset()` is never called. New angle: there is **no logout UI** anywhere — grep of `logout|signOut|sign_out` returns 0 hits. Today the app is anonymous-only (Firebase Auth `signInAnonymously`). The first time the team adds Sign in with Apple / email, every existing anonymous Firebase UID will collide with the new authenticated UID. PostHog will see neither (because identify is never called), but Firestore will collide. This is a cross-cut into auth, but it's worth flagging here because the analytics-identity fix (Pass 1 D1 / V1) and the logout-reset fix (Pass 1 D2) need to be designed together, not separately.

---

## S. GDPR / DSAR

**S1 [P0] — "Delete All Data" leaves PostHog untouched.** `SettingsView.performDataDeletion()` (`SettingsView.swift:671-692`) wipes:
- EncryptedStore (name, email, DOB, full profile)
- HealthDataStore (`deleteAllData()` at line 680)
- All UserDefaults for the bundle (`removePersistentDomain` line 683)
- Then `exit(0)` after 0.3s (line 690).

It does **NOT** call `PostHogSDK.shared.reset()` and does **NOT** call PostHog's GDPR delete-person endpoint (`/api/projects/<id>/persons/<distinct_id>/delete/` — server-side only, requires API key). The PostHog distinct_id is stored inside PostHog's own SDK storage which `removePersistentDomain` may or may not catch (PostHog stores in its private app-group container, not standard UserDefaults — verified by grep showing PostHog SDK's own storage uses its `posthog` namespace). Result: every event the user ever generated remains on PostHog cloud, joinable across reinstalls if the same distinct_id is somehow re-derived. The user reasonably believes their data is gone.

**This is an EU-launch blocker.** GDPR Art.17 right-to-erasure requires controllers to delete the data from all processors. PostHog (the processor) requires an API call from the data controller (Laso) to delete server-side. **Fix:** before `exit(0)`:
1. `PostHogSDK.shared.reset()` (clears local distinct_id and queued events)
2. Persist the distinct_id to a "to-delete" queue in App Group storage
3. On next app launch (after re-install or if user changes their mind, or via a server-side cron) call PostHog's `DELETE /api/projects/<project>/persons/<id>` from a backend cloud function (the API key cannot be in the app). For a no-backend launch, document this gap in the privacy policy and set up a manual deletion runbook.

(verified by reading `SettingsView.swift:671-692` line by line; cross-checked against PostHog GDPR documentation — the deletion endpoint is server-only)

**S2 [P1] — DSAR (data export) is not offered to the user.** The Pass 1 audit speculated this; confirmed absent. No "Export My Data" in Settings. Same backend constraint: the export needs PostHog's API key on the server, not in the client. Flag for backend roadmap.

---

## T. Apple Privacy Nutrition Labels

**T1 [P0 — confirms Pass 1 B2 with new specifics] —** App Privacy "Health & Fitness" label must be marked `Linked to You` (because each event carries enough fingerprint to be re-identifiable: country + timezone + device_model + age_bracket + gender + IP), AND must list these data types:
- Health & Fitness (linked, used for Analytics + AppFunctionality)
- Identifiers (`device_id` from PostHog SDK, linked, Analytics)
- Diagnostics (Crash Data, Performance Data — linked)
- Usage Data (Product Interaction — linked, Analytics)
- Other Data (`subscription_status`, `streak_days`, `score_bracket` — linked, Analytics)

Pass 1's privacy-manifest analysis is correct but the App Store *labels* (a separate artifact entered in App Store Connect) will need to match. Often teams forget that the manifest XML and the Labels UI are two different sources of truth.

---

## U. Subscription lifecycle gaps

**U1 [P1] — `subscription_refunded` is missing.** Apple does not deliver refund notifications to clients (Pass 1 noted). New angle: the app *does* have a Firestore-side subscription doc (`SubscriptionManager.swift:457-479`) but no listener for App Store Server Notifications V2 → Firestore → client. Result: a refunded customer is still counted as `subscribed` until next StoreKit verification, which can be 24-48 hours. PostHog's revenue numbers will be stale. Flag for backend roadmap — server-to-server is mandatory for accurate revenue.

**U2 [P1] — `purchase_failed` ships only `error_type ∈ {user_cancelled, purchase_error}`.** No SKError code, no underlying domain. All real failure reasons (payment-method-failed, network-failed, in-house verification failed, parental controls, etc.) collapse into one bucket. Cannot tell if the paywall has a payment-card-failure problem or a network-flakiness problem. **Fix:** ship `error_code: SKError.code.rawValue` and `error_domain: error._domain` on `purchase_failed`. (verified at `SubscriptionManager.swift:149,159`)

**U3 [P2] — `restore_attempted` ships `success: 0|1` only.** No reason on failure. (verified at `AppAnalytics.swift:1190-1195`)

**U4 [P2] — `paywall_cta_tapped` does not differentiate "yearly toggle" from "monthly toggle" tap.** It fires only after the user taps the Subscribe button (`PaywallView.swift:276`). Toggling between yearly and monthly is captured as a `block_tapped(paywallPlanYearly|Monthly)` (Pass 1 noted). New angle: there is no `plan_selected` event with the `from→to` tier transition, so dashboards cannot show "what % of users toggle plans before subscribing". (`AppAnalytics.swift:1102-1109`)

---

## V. PII deepening

**V1 [P0] — PMF segment + benefit raw text shipped.** Already covered in TL;DR #1. **Most actionable Pass 2 finding.** Cross-ref: `PMFSurveySheet.swift:120-167` (segment + benefit are typed by user via `TextField` + axis: vertical), `AppAnalytics.swift:2985-2996` (no truncation beyond the 100-ch generic sanitizer), no whitelist, no length-only mode.

**V2 [P0] — Bedtime + sleep onset epochs.** Already covered in TL;DR #4. Reduce to bucketed values (e.g., `bedtime_hour: 0-23, bedtime_minute_5: 0-11`) instead of unix epochs.

**V3 [P0] — AFib count + clinical_stage + chronotype + cycle_phase + current_state.** Already covered in TL;DR #5. Add the relevant property keys to `metricParameterKeys` and write a `clinical-state` anonymizer that maps to coarse buckets (`afib_present: bool` instead of count; `cycle_phase: string` is already coarse but cross-tied to gender = re-identifiable on N=10 users; `chronotype` is fine as a 3-bucket value).

**V4 [P1] — Journal `category` exposes alcohol/stress/mood/supplements.** `JournalCategory` enum (`Core/Data/JournalStore.swift:7-95`) includes `alcohol`, `stress`, `mood`, `supplements`, `meditation`, `mealTiming`. Sending `category=alcohol` per journal entry to PostHog is tracking the user's drinking frequency. Pass 1 said "value/text not sent — good" but missed that the category itself is medically/legally sensitive in some jurisdictions (e.g., alcohol logs are discoverable in custody cases in some U.S. states). **Fix:** map to a single `journal_logged` event with `lifestyle_category` ∈ {`stimulant, depressant, mindfulness, sleep_signal, hydration`} — coarse buckets that preserve cohort analytics without leaking the specific category.

**V5 [P1] — `setting_changed.new_value` is unconstrained.** `trackSettingChanged(name:value:)` (`AppAnalytics.swift:1408-1422`) accepts `Any` and stringifies. Today the call sites pass Bool/Int/Double/preselected enums (Pass 1 verified). New angle: `NotificationsSettingsView.swift:103` passes `max_notifications_per_day: newValue` (an Int from a Slider 0-10), but `NotificationsSettingsView.swift:191` passes a generic dynamic-name slider value. If a future setting accepts free-text (e.g., a "notes for support" field), the wrapper accepts it silently. Lock the contract: either type the wrapper as `value: BoolOrIntOrEnum` with an explicit conversion, or whitelist `name ∈ KnownSettings`. (verified by reading both files)

**V6 [P2] — `notification_id` raw still sent.** Pass 1 N2 noted. New angle: the `notification_id` format includes both metric *and* level (e.g., `healthpulse.triage.menstrualFlow.high`). The `level` part (`high|medium|low`) is also a clinical signal — even after anonymizing the `metric` part to `cycle`, `cycle.high` reveals severity. Use a 3-part hash instead.

---

## W. Battery / connection / device super-properties

**W1 [P2] — `UIDevice.current.batteryLevel` not captured.** No correlation possible between battery state and behaviour (e.g., do low-battery users skip live-vitals streaming?). Trivial to add; flag for product-research utility.

**W2 [P2] — `isLowPowerModeEnabled` not captured.** Same shape.

**W3 [P3] — `thermalState` is read in ML pipeline (`MLOrchestrator.swift:169`, `MLPipelineRunner.swift:67`, `ThermalManager.swift:161`) but never sent to PostHog as event property.** Useful for understanding why ML-derived events are missing on hot devices.

**W4 [P3] — Connection type captured only on `session_start` (`AppAnalytics.swift:701-703`) — not on every event.** A user who starts a session on wifi, then walks outside (cellular), and crashes — the crash event will still report wifi as session-start property, not the actual connection at crash time. Document the limitation or capture connection on every event (cost: 1 ConnectivityMonitor read per event).

---

## X. Pass-2 PII Risk Table (additions to Pass 1's table)

| Event | Param | Risk | File:Line | Fix |
|---|---|---|---|---|
| `pmf_segment_response` | `segment` | **HIGH** — raw user free-text, may contain conditions/diagnoses | AppAnalytics.swift:2987 | Send only `text_length` (match PMFImprovement) |
| `pmf_benefit_response` | `benefit` | **HIGH** — same | AppAnalytics.swift:2994 | Same |
| `live_activity_sleep_outcome` | `bedtime_epoch`, `sleep_onset_epoch` | **HIGH** — precise time-of-day surveillance | AppAnalytics.swift:2174-2178 | Bucket to `bedtime_hour:0-23` only |
| `ecg_analysis_completed` | `afib_count` | **HIGH** — clinical diagnosis count | AppAnalytics.swift:1672 | Replace with `afib_present: bool` |
| `clinical_insight_generated` | `clinical_stage`, `trajectory` | HIGH — disease progression | AppAnalytics.swift:1687 | Add to anonymizer set |
| `health_state_timeline_viewed` | `current_state` | MEDIUM — composite health-mood state | AppAnalytics.swift:1696 | Coarsen to 4-bucket |
| `circadian_analysis_completed` | `chronotype` | MEDIUM — already 3-bucket; keep as-is | AppAnalytics.swift:1705 | OK |
| `workout_plan_generated` | `cycle_phase` | MEDIUM — when paired with `gender=female`, leaks cycle | AppAnalytics.swift:1988 | Drop on cellular/cross-checks |
| `insight_marked_unhelpful` | `reason` (free-text future) | MEDIUM-LATENT | AppAnalytics.swift:1919 | Whitelist enum |
| `recommendation_skipped` | `reason` | MEDIUM-LATENT | AppAnalytics.swift:1966 | Whitelist enum |
| `setting_changed` | `new_value` (any) | LOW today, MEDIUM if free-text settings ship | AppAnalytics.swift:1417 | Type the wrapper |
| `journal_entry_created` | `category` ∈ {alcohol, stress, mood} | MEDIUM — sensitive lifestyle | AppAnalytics.swift:2324 | Coarsen to lifestyle_category |
| `notification_id` | full id (e.g. `healthpulse.triage.menstrualFlow.high`) | MEDIUM | AppAnalytics.swift:1578 | Hash, or anonymize each part |

---

## Y. Dead / orphan / inconsistent code in analytics layer

**Y1 [P1] — `trackDeepLinkOpened` orphan.** Already covered in M1 / TL;DR #8.

**Y2 [P2] — `trackJournalEntryCreated(value:)` accepts an unused `value: Double` parameter.** The function signature takes `value` but the implementation does not include it in the params dict (`AppAnalytics.swift:2322-2327`). Caller (`JournalStore.swift:147-152`) passes the real value. **Either** the developer changed their mind (silent removal — value is sensitive) **or** it's a bug. Either way, mismatch between API contract and behaviour. Drop the parameter from the signature. (verified by reading both files)

**Y3 [P2] — `trackNotificationSent` (Pass 1 noted) is dead.** Confirmed: `grep -rn "trackNotificationSent"` returns only the definition. Delete it.

**Y4 [P3] — `recordCoreAction` increments `lifetimeCoreActions` on every call, including duplicates within a session.** `coreActionsThisSession` dedupes, but `lifetimeCoreActions` does not (`SessionTracker.swift:342-348`). A user who taps "viewedScore" 10× in a session adds 10 to lifetime, even though `coreActionsThisSession.count` only adds 1. Pass 1 inventory used `lifetime_core_actions` extensively as a quality signal — verify the dashboards account for this.

---

## Z. Consolidated Findings Table (Pass 2 only)

| # | Severity | Title | Where |
|---|---|---|---|
| A1 | P1 | No event schema version | grep returned 0; AppAnalytics.swift |
| A2 | P2 | Canonical-rewrite is the most fragile piece, unversioned | AppAnalytics.swift:2722-2877 |
| B1 | P2 | UI does not block on RC fetch — first-launch flicker | AppLaunchCoordinator.swift:35-37 |
| B2 | P1 | RC defaults dictionary not audited for safe-on-failure | RemoteConfigManager.swift:37 |
| B3 | P2 | Flag cache eviction across app upgrades not handled | RemoteConfigManager.swift:34 |
| B4 | P1 | `FeatureGate.canAccess` emits no telemetry | FeatureGate.swift:24-27 |
| C1 | P2 | PostHog group analytics unused (subscription tier) | grep returned 0 |
| D1 | P2 | No documented funnel sequence | repo |
| D2 | P3 | `subscription_expired` overloaded (trial-only) | AppAnalytics.swift:1067 |
| E1 | P3 | No PostHog cohort affects app behaviour | n/a (P1 unused) |
| F1 | P2 | PMF survey gating thresholds hardcoded | PMFSurveySheet.swift:242-249 |
| G1 | P1 | Heatmaps inseparable from session replay; risk vs benefit | PostHogManager.swift:29 |
| H1 | P2 | `os_log`/`Logger` errors not auto-captured | grep |
| I1 | P2 | A/B variant infrastructure absent | grep |
| J1 | P1 | `app_environment` super-property missing | grep |
| J2 | P2 | UITestMode does not protect raw direct-PostHog calls | OnboardingConnectHealthStep.swift:70 |
| K1 | P1 | Zero PostHog batching config (flushAt/Interval/maxQueueSize) | PostHogManager.swift:21-43 |
| K2 | P2 | No client-side per-event-name rate limit | AppAnalytics.swift:3109 |
| K3 | P3 | maxQueueSize eviction policy not documented | PostHogManager.swift:21-43 |
| L1 | P0 | `session_end` on background not flushed | ContentView.swift:138-141 |
| L2 | P1 | `applicationWillTerminate` not implemented | AppDelegate.swift |
| L3 | P1 | Session boundary broken — every active-transition is a new session | ContentView.swift:98-101, SessionTracker.swift:132 |
| L4 | P1 | `daily_active` no per-day client-side guard | AppAnalytics.swift:1717 |
| L5 | P2 | `applicationWillResignActive` not used | AppDelegate.swift |
| M1 | P1 | `trackDeepLinkOpened` orphan code | AppAnalytics.swift:3066, no onOpenURL anywhere |
| M2 | P2 | First-touch attribution not captured | grep |
| M3 | P3 | `$initial_*` super-properties unverified at runtime | PostHogManager.swift:22 |
| N1 | P1 | `app_crash` lacks pre-crash UI/state context | PostHogManager.swift:155-159 |
| N2 | P2 | Crash flush is best-effort, async race with SIG_DFL | PostHogManager.swift:160-163 |
| N3 | P3 | URLError silent swallow in many `Task { try? await }` blocks | grep |
| O1 | P1 | No `time_to_answer` on HK permission funnel | AppAnalytics.swift:1796-1814 |
| O2 | P2 | Per-HKObjectType result not captured | AppAnalytics.swift:1807-1814 |
| P1 | P1 | Bool-as-Int convention broken by raw direct-PostHog calls | OnboardingConnectHealthStep.swift:70 |
| P2 | P2 | `trial_converted` sent as both Int and String | AppAnalytics.swift:1097, 1120 |
| P3 | P3 | Timestamp precision conventions undocumented | AppAnalytics.swift:1563, 2174 |
| P4 | P3 | `screen` lives in event name AND property | AppAnalytics.swift:799, 2754 |
| Q1 | P1 | Profile updates do not propagate to PostHog person properties | AppAnalytics.swift:528, 739 |
| Q2 | P2 | Subscription `$set` fires per transaction-update tick | SubscriptionManager.swift:438, AppAnalytics.swift:1242-1243 |
| Q3 | P2 | `trial_day_check` fires on every status update | AppAnalytics.swift:1216 |
| R1 | P1 | Logout flow non-existent → identity scheme will collide on first auth release | grep |
| S1 | P0 | "Delete All Data" leaves PostHog untouched (GDPR Art.17) | SettingsView.swift:671-692 |
| S2 | P1 | DSAR (export) not offered | grep |
| T1 | P0 | App Store Privacy Labels misalign with PostHog data | App Store Connect (out-of-repo) |
| U1 | P1 | `subscription_refunded` not wired (server-to-server gap) | SubscriptionManager.swift:457 |
| U2 | P1 | `purchase_failed` ships only 2 buckets (no SKError code) | SubscriptionManager.swift:149,159 |
| U3 | P2 | `restore_attempted` ships success-only, no reason | AppAnalytics.swift:1190 |
| U4 | P2 | No `plan_selected` (yearly↔monthly toggle) event | PaywallView.swift |
| V1 | P0 | PMF segment+benefit raw user text shipped | AppAnalytics.swift:2985-2996 |
| V2 | P0 | Bedtime + sleep-onset epoch sent in clear | AppAnalytics.swift:2174-2178 |
| V3 | P0 | AFib count, clinical_stage, current_state, chronotype shipped raw | AppAnalytics.swift:1670-1709, 1986-1989 |
| V4 | P1 | Journal `category` exposes alcohol/stress/mood/supplements | AppAnalytics.swift:2322 |
| V5 | P1 | `setting_changed.new_value` accepts `Any`, future free-text leak | AppAnalytics.swift:1408-1422 |
| V6 | P2 | `notification_id` level part (high/med/low) leaks severity | AppAnalytics.swift:1578 |
| W1 | P2 | Battery level not captured | grep |
| W2 | P2 | `isLowPowerModeEnabled` not captured | grep |
| W3 | P3 | `thermalState` not shipped to PostHog | MLOrchestrator.swift:169 |
| W4 | P3 | Connection type captured only at session_start | AppAnalytics.swift:701-703 |
| Y1 | P1 | `trackDeepLinkOpened` orphan (dup of M1) | AppAnalytics.swift:3066 |
| Y2 | P2 | `trackJournalEntryCreated(value:)` unused parameter | AppAnalytics.swift:2322, JournalStore.swift:147-152 |
| Y3 | P2 | `trackNotificationSent` dead (Pass 1 noted; confirming) | AppAnalytics.swift:1424 |
| Y4 | P3 | `lifetimeCoreActions` increments per call (no per-action dedupe) | SessionTracker.swift:342-348 |

**P0 (NEW launch blockers — independent of Pass 1):** L1, S1, T1, V1, V2, V3.

**P1 (NEW high — fix before scale, independent of Pass 1):** A1, B2, B4, J1, K1, L2, L3, L4, M1, N1, O1, P1, Q1, R1, S2, U1, U2, V4, V5, Y1.

---

## Confidence per Pass-2 finding

| Finding | Confidence | Verified by |
|---|---|---|
| L1 session_end not flushed | 100/100 | direct read of `ContentView.swift:138-141`; no `flush()` call anywhere in the project except PostHogManager itself |
| L3 session boundary broken | 95/100 — code-traced, not runtime-reproduced | `ContentView.swift:98-101` + `SessionTracker.swift:132-150` |
| S1 Delete All Data leaves PostHog untouched | 100/100 | full read of `SettingsView.performDataDeletion()`; grep confirms no `reset()`/`optOut()` anywhere |
| V1 PMF segment+benefit raw text | 100/100 | direct read of `AppAnalytics.swift:2985-2996`, `PMFSurveySheet.swift:120-167`, sanitizeParameters at `:2920-2950` |
| V2 sleep epoch | 100/100 | direct read of `AppAnalytics.swift:2174-2178` |
| V3 AFib + clinical_stage | 95/100 — `metricParameterKeys` set verified absent of these keys; runtime that the values can be sensitive depends on backend value populations | `AppAnalytics.swift:1672, 1687, 1696, 1705, 1988`, anonymizer set at `:2899-2902` |
| K1 batching config absent | 100/100 | full re-read of `PostHogManager.swift:21-43` |
| M1 deepLinkOpened orphan | 100/100 | grep `onOpenURL\|application(_:open\|onContinueUserActivity` returns 0 product hits |
| Q1 profile changes do not propagate to PostHog | 95/100 — only verified the call sites (line 528 + 739); the absence of a profile-mutation observer is by inspection | `AppAnalytics.swift:376-436, 528, 739` |
| U2 purchase_failed ships only 2 buckets | 100/100 | direct read of `SubscriptionManager.swift:149,159` |
| B2 RC defaults safety not audited | 60/100 — based on absence of evidence; actual `Self.defaults` dictionary not read in this pass | `RemoteConfigManager.swift:37` (dictionary referenced but content unread) |
| L4 daily_active no client-side dedupe | 90/100 — code-traced; the inflation only manifests in conjunction with L3 | `AppAnalytics.swift:1717-1723` |
| O1 no time_to_answer on HK permission | 100/100 | direct read of `AppAnalytics.swift:1796-1814` |
| Y2 trackJournalEntryCreated unused parameter | 100/100 | direct read of definition + caller |
| All other Pass 2 findings | 85-100/100 — the gap from 100 is in each case "code path verified but runtime/cross-device behaviour unobserved" | per-table |

---

## Cross-cuts to Pass 1

- Pass 1 noted "no consent gate" (B3) — Pass 2 adds: even if consent is added, S1 (delete-all-data leaves PostHog) and Q1 (profile-edits don't propagate) need their own fixes.
- Pass 1 noted "identify() never called" (D1) — Pass 2 adds: when identify is wired, also wire R1 (logout/reset) and Q1 (profile-update push) at the same time, otherwise the identity will carry stale demographic properties across login transitions.
- Pass 1 noted referral-code PII (G2) — Pass 2 V1/V2/V3 lift the count of P0 PII issues from 1 to 4. The PII fix is no longer a one-place patch; it's a privacy-engineering pass.
- Pass 1 estimated event volume at 22-135M/mo (S1 there). Pass 2 L3+L4+Q2+Q3 *inflate* that count by ~2-3× because every active-transition spawns a fresh session_start + DAU + repeated `$set` events. Re-estimate: 50-300M/mo at 50k DAU. Cost mitigation in Pass 1 still applies; the multiplier is now larger.
