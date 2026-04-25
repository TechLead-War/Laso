# 07 — Analytics / PostHog Audit (Pre-Launch)

App: Laso (com.lasohealth.fit), iOS 17+, PostHog SDK v3+, EU host.
Repo: /Users/primetrace/Desktop/RnD/HealthPulse
Scope: PostHog instrumentation, business KPI coverage, taxonomy, privacy alignment of analytics, identity, sessions, feature flags, errors. Security, PrivacyManifest, copy semantics out of scope (cross-cuts only on the privacy-manifest lie which is explicitly allowed).

Method: read every line of `Core/Tracking/PostHogManager.swift` (185), `Core/Tracking/AppAnalytics.swift` (3,201), `Core/Tracking/SessionTracker.swift` (430), `Core/Tracking/SectionTracker.swift` (124), `App/AppDelegate.swift`, `App/AppLaunchCoordinator.swift`, `Core/Config/AppSecrets.swift`, `Secrets.xcconfig`, `Secrets.xcconfig.template`, `Info.plist`, `PrivacyInfo.xcprivacy`. Greps over all 398 `AppAnalytics.shared.*` call sites, all `PostHogSDK.shared.*` / `PostHogManager.shared.*` calls (excluding `/build/`), all `logEvent`/`capture(event:` invocations, all `.postHogMask()` annotations, all `RemoteConfigManager` usages, plus targeted reads of representative call sites in Onboarding, Paywall, Subscription, Referral, Live, Stress, Journal, Home. Approx 110 unique base event names extracted programmatically.

Severity scale: P0 catastrophic (revenue/legal), P1 high (analytics integrity), P2 medium (cost/cleanliness), P3 low (cosmetic/nit).

---

## TL;DR (one screen)

The instrumentation is unusually deep for a pre-launch consumer app — ~110 base event names, an end-to-end PMF/activation/retention/engagement framework, behavioral intelligence (rage-tap, ghost session, ritual detection), session quality, churn-risk scoring. **But four pre-launch blockers exist:**

1. **Hardcoded production PostHog API key in committed `Secrets.xcconfig`** (`phc_bBp1OaF9Ta…`). Even though "personal API keys" in PostHog are write-only / public-by-design, this file should match the template (empty string). Anyone forking the repo gets prod-pollution rights. (P0)
2. **Privacy manifest says `NSPrivacyTracking=false`** while PostHog is performing **session replay** (`config.sessionReplay = true` — `PostHogManager.swift:29`) plus auto-capture of lifecycle events, screen names, OS/device/timezone, and a server-side IP. Apple's *App Privacy* "tracking" definition can be argued either way, but session replay of a *health* app — even with text masking — is the reddest flag App Review can find, and the manifest's `NSPrivacyCollectedDataTypeTracking=false` claim becomes hard to defend. (P0)
3. **No `identify()` call exists anywhere outside the wrapper.** `PostHogManager.identify(...)` is defined (`PostHogManager.swift:67`) but is never invoked from anywhere in `Modules/`, `App/`, or `Core/` (verified by `grep -rn "\.identify\("`). Every Laso user is tracked under the auto-generated anonymous distinct_id forever — anonymous-then-never-identify is one of two failure modes (the other being identify-before-auth). Funnels survive, but cohort joins to Firestore/CRM are impossible. (P1)
4. **No `posthog.reset()` on logout/account-switch and no opt-out path.** `reset()` is never called; `optOut`/`isOptedOut` strings appear nowhere. There is no consent gate before `PostHogSDK.shared.setup(...)` runs in `AppLaunchCoordinator.configureOnLaunch`, so events ship from first launch regardless of user state. For an EU-targeted app on the EU host, this is the GDPR weak spot. (P0)

Plus: session replay enabled on a paywall/score screen risks capturing $$ amounts and HRV charts despite masking; `recordSessionsByDefault` is the new SDK default (true); no PostHog Feature Flags despite Firebase Remote Config existing — split source of truth waiting to happen; ~110 events × 50/session × 10k DAU = ~165M events/mo at scale — far beyond PostHog's free tier.

---

## 1. SDK Setup (`PostHogManager.swift`)

| Setting | Value | File:Line | Verdict |
|---|---|---|---|
| API key source | `Bundle.main.infoDictionary["POSTHOG_API_KEY"]` then fallback to `AppSecrets.PostHog.apiKey` (which is `""`) | `PostHogManager.swift:172-177`, `AppSecrets.swift:69` | OK pattern, but the xcconfig containing the prod key is committed (see Finding A1) |
| Host | `Bundle.main.infoDictionary["POSTHOG_HOST"]`, fallback `https://eu.i.posthog.com` | `PostHogManager.swift:178-183`, `AppSecrets.swift:70` | EU host — good for GDPR |
| `captureApplicationLifecycleEvents` | **true** | `PostHogManager.swift:22` | Auto-emits `Application Installed/Updated/Opened/Backgrounded` plus device/OS/locale/timezone/screen-size super-properties; not gated by consent |
| `captureScreenViews` | false | `PostHogManager.swift:23` | Good — screens are emitted manually via `PostHogManager.screen(...)` from `AppAnalytics.trackFeatureOpen` |
| `enableSwizzling` | false | `PostHogManager.swift:24` | Good |
| `captureElementInteractions` | false | `PostHogManager.swift:26` | Good — no autocapture taps |
| `sessionReplay` | **true** | `PostHogManager.swift:29` | Major risk in a health app. See Finding B1 |
| `sessionReplayConfig.maskAllTextInputs` | true | `PostHogManager.swift:34` | Good but does not mask SwiftUI `Text` values (only `TextField`/`SecureField`) |
| `sessionReplayConfig.maskAllImages` | true | `PostHogManager.swift:35` | Good |
| `sessionReplayConfig.maskAllSandboxedViews` | true | `PostHogManager.swift:36` | Good — masks WebView/Map |
| `surveys` | false (gated `iOS 15+`) | `PostHogManager.swift:38` | Good |
| `recordSessionsByDefault` | **not explicitly set** | `PostHogManager.swift:21-43` | PostHog default is `true` since v3.20. Combined with `sessionReplay=true`, every user is replay-recorded from day 1 with no kill switch. |
| `optOut` discipline | none | grep `optOut\|optIn\|isOptedOut` returned 0 hits in product code | No consent gate, no opt-out, no opt-in. See Finding C1 |
| `posthog.identify` call | only the wrapper | `PostHogManager.swift:67` is the only definition; **0 invocations** in modules | See Finding D1 |
| `posthog.alias` | not implemented | `grep alias` returns no hits | OK — only matters if you support email→anonymous merging |
| `posthog.reset` | not implemented | `grep reset` returns 0 hits | Logout/account-switch will collide identities. Finding D2 |
| Crash handlers | `installCrashHandlers` installs `NSSetUncaughtExceptionHandler` and POSIX signal handlers (`SIGABRT/BUS/SEGV/FPE/ILL/TRAP`) that capture `app_crash` + `flush()` then `SIG_DFL+raise` | `PostHogManager.swift:126-166`, called from `AppLaunchCoordinator.swift:40` | Solid. Note: PostHog has no native iOS crash module so this is a custom add — see Finding F2 (overlap with Firebase Crashlytics? Crashlytics absent — see below) |
| Screenshot tracking | `startScreenshotTracking` listens to `userDidTakeScreenshotNotification` and emits `screenshot_taken` | `AppAnalytics.swift:2461-2477`, `AppLaunchCoordinator.swift:42` | Good — proxy for share intent |

### Findings — SDK setup

**A1 [P0] — Production PostHog API key committed to repo.** `Secrets.xcconfig:5` contains `POSTHOG_API_KEY = phc_bBp1OaF9TabDqJ9iA9uxbObl8YAIIIYn049Tt8AS7km`. The `.template` exists at `Secrets.xcconfig.template:5` with `your_posthog_api_key_here`. PostHog "project API keys" are designed to be public-ish (write-only ingestion), so the *blast radius* is event-pollution / spam, not theft of historical data — but for a pre-launch app this is still wrong: anyone forking the repo or unzipping the IPA can flood prod analytics with garbage events, poison cohorts, drain quota, and there is no clean rotation path because the key is bound to a specific project. *(Cross-cuts with security audit — flagging as instructed.)* **Fix:** delete the value from `Secrets.xcconfig` (pre-commit hook should refuse non-empty), inject via CI / Xcode Cloud secret, rotate the leaked key in PostHog UI before launch.

**A2 [P2] — `recordSessionsByDefault` not set explicitly.** PostHog iOS SDK default for v3.20+ is `true`. Even though `sessionReplay=true` is the bigger lever, if you ever flip `sessionReplay=false` you might still find sessions being recorded under the new SDK default. Belt-and-braces: set `config.sessionReplayConfig.recordSessionsByDefault = false` and explicitly call `PostHogSDK.shared.startSessionRecording()` only on consented users. (`PostHogManager.swift:21-43`)

**A3 [P1] — `captureApplicationLifecycleEvents=true` ships device/OS/timezone/locale on every $auto event before the user has a chance to refuse.** This is what the privacy manifest will need to declare. (`PostHogManager.swift:22`) See Finding B2.

---

## 2. Privacy Alignment (the lie)

`PrivacyInfo.xcprivacy` declares:

- `NSPrivacyTracking = false` (line 6)
- `NSPrivacyTrackingDomains` empty (line 8)
- `NSPrivacyCollectedDataTypes` lists only `NSPrivacyCollectedDataTypeHealthData` with `NSPrivacyCollectedDataTypeLinked=false` and `NSPrivacyCollectedDataTypeTracking=false`, purpose `AppFunctionality` (lines 11-22)

What PostHog actually collects (verified from SDK config):

| Data | Where set | In manifest? |
|---|---|---|
| User-tier identifier (`subscription_status`, `user_tier`, `streak_days`, etc.) on every event | `AppAnalytics.swift:3144-3157` enriches every event with these | **Not declared as `OtherUserContent` / `UserID`** |
| Device identifier (`$device_id` auto-prop, hw.machine `iPhone17,1`, marketing name) | `captureApplicationLifecycleEvents=true` and `setDemographicProperties()` `AppAnalytics.swift:417-425` | **Not declared as `DeviceID`** |
| OS version, app version, locale, timezone, country | `AppAnalytics.swift:404-425` | **Not declared as `CoarseLocation` (country) / `OtherUsageData`** |
| Age bracket, gender (from encrypted DOB + UserDefaults) | `AppAnalytics.swift:381-401` | **Not declared as `OtherUserContent`** — note PostHog strips raw DOB but bracket+gender on a country+timezone+device is identifiable |
| Health data signals (`hk_heart_has_data`, `score_bracket`, `streak_days`, `metrics_available_count`, `data_freshness`) on `user_health_snapshot` and on every session_start | `AppAnalytics.swift:2115-2139`, `709-744` | **Not declared as `HealthData`** in the *Linked* sense — manifest says HealthData is `Linked=false` and purpose `AppFunctionality`. Sending derived health properties to a third-party analytics vendor cannot be honestly described as `AppFunctionality` only — it's also `Analytics`. |
| IP address (server-side capture by PostHog) | inherent to PostHog ingestion | **Not declared** — IP+timezone+device is enough for re-identification under GDPR's "indirectly identifiable" prong |
| Session replay — masked but recorded | `PostHogManager.swift:29-36` | **Not declared at all** |

### Findings — privacy

**B1 [P0] — Session replay on a health app with the privacy manifest claiming `NSPrivacyTracking=false`.** Even with `maskAllTextInputs=true`, `maskAllImages=true`, and surgical `.postHogMask()` calls on 30+ score/HRV/cycle views, session replay records the *visual structure* of every screen the user navigates. The Stress / Cycle / Sleep / Vitality / BrainHealth modules contain user-specific UI that is identifiable in aggregate (e.g., a calendar showing a menstrual cycle timeline, a HealthState timeline with mood states) — even masked, the layout itself can leak attributes. App Review reviewers have rejected health apps for less. **Recommendation:** disable `sessionReplay` for v1 launch entirely. If retained, gate it behind explicit in-app consent tied to `NSUserTrackingUsageDescription` (which is also missing — `Info.plist` has no `NSUserTrackingUsageDescription` key, confirmed by grep).

**B2 [P0] — Manifest declares `NSPrivacyCollectedDataTypeTracking=false` but PostHog enrichment is sending `subscription_status`, `device_model`, `country`, `timezone`, `health_score_bracket`, `streak_days`, `watch_paired`, etc., all keyed against a stable distinct_id and the server-recorded IP. Apple's tracking definition (linking user/device data to data from other companies for ads/measurement) is debatable here — PostHog is not an ad network — but the manifest also under-declares `NSPrivacyCollectedDataTypes`. At minimum it must add: `DeviceID`, `ProductInteraction`, `OtherDiagnosticData`, and probably `OtherUserContent` and `HealthAndFitness` (linked=true, since person properties travel with the distinct_id). Today the only entry is HealthData with `Linked=false` — that's a misdeclaration the moment `setDemographicProperties()` runs.

**B3 [P0] — No consent gate, no `NSUserTrackingUsageDescription`, EU host but EU compliance is half-baked.** `PostHogSDK.shared.setup(...)` is called unconditionally in `AppLaunchCoordinator.configureOnLaunch` *before* any user interaction. There is no consent screen, no `optOut()`, no `optIn()`. For an iOS app distributed in the EU (the Secrets template even points at the EU host), GDPR Art.6 lawful basis for analytics is "consent" (recital 32) — implicit consent is no longer valid after Schrems II. This is a launch blocker for EU TestFlight/App Store. **Fix:** show a one-screen consent before `configure()`, store the choice in encrypted storage, call `PostHogSDK.shared.optIn()` only after consent, and offer a Settings toggle. Until consent: do not call `setup()` or call it with `config.optOut = true`.

**B4 [P1] — Privacy policy + ToS at `https://lasohealth.fit/privacy` (`AppSecrets.swift:55`) — outside this audit, but this is where the EU-host data residency disclosure must live. Confirm before launch that this policy mentions PostHog by name, EU residency, retention, and the user's right to deletion via PostHog GDPR endpoint.**

---

## 3. User Identification

| Concern | Status | File:Line |
|---|---|---|
| `posthog.identify(distinctId:)` called after auth? | **Never called** | `PostHogManager.swift:67` is the only definition; 0 hits across `App/`, `Modules/`, anywhere else |
| Anonymous-then-identify merge done correctly? | N/A — never identified, so no merge | — |
| `posthog.alias` used? | Not used | grep returns 0 |
| Logout `posthog.reset()` called? | **Never called** | grep `\.reset()` returns no analytics hits |
| Distinct ID source | PostHog auto-generated UUID per install (default behavior) | inherent |
| Anonymous Firebase Auth UID linked to PostHog distinct_id? | No. `AppLaunchCoordinator.swift:27-33` calls `Auth.auth().signInAnonymously` separately, never feeds the UID back to PostHog | `AppLaunchCoordinator.swift:21-43` |

### Findings — identity

**D1 [P1] — PostHog distinct_id is never tied to anything.** Every install is a new anonymous user. Firestore writes (referrals, subscriptions, feedback) use the anonymous Firebase UID. These two ID spaces never meet. Consequences: cannot join PostHog cohorts to Firestore subscription truth; cannot follow a user across iPhone reinstall (Firebase Auth UID survives via Keychain restore, PostHog distinct_id does not — fresh anon ID); cannot run support investigations from a Firestore record back to behavior. **Fix:** in `AppLaunchCoordinator` after `signInAnonymously` succeeds, call `PostHogManager.shared.identify(userId: authResult.user.uid)`. Do this *before* the first `capture(...)` to avoid creating an orphan anon profile that needs an `alias` later.

**D2 [P1] — `posthog.reset()` never invoked.** Today Laso has no auth account flow (anonymous-only). The day someone adds account login or "switch user" or "delete my data," forgetting `reset()` will merge two real users into one PostHog profile. Add a `PostHogManager.reset()` wrapper now and document the contract.

**D3 [P3] — Reinstall creates a zombie identity.** Without `identify(authUid)`, PostHog's UUID is regenerated on uninstall+reinstall. Same human → two PostHog profiles → broken D7/D30 retention math. Solved by D1.

---

## 4. Event Taxonomy

### Naming convention

All event names verified `snake_case` and lowercase, sanitized through `sanitizeEventName(_:)` (`AppAnalytics.swift:2709-2720`) which lowercases, replaces non-`[a-z0-9_]` with `_`, trims leading/trailing underscores, caps at 80 chars. Good discipline.

### Two-name problem (P1)

`AppAnalytics.canonicalEventName(...)` (`AppAnalytics.swift:2722-2877`) **rewrites** event names at send time. So the developer-facing name in code is *not* the name PostHog receives. Examples:

| Source name (in code) | PostHog name (after canonical) |
|---|---|
| `session_start` | `app_session_started` |
| `session_end` | `app_session_ended` |
| `daily_active` | `app_daily_active_recorded` |
| `screen_viewed` | `<screen>_screen_viewed` (e.g. `home_screen_viewed`, `cycle_detail_screen_viewed`) |
| `block_tapped` | `<screen>_block_tapped` |
| `core_action_completed` | `<screen>_<action>_completed` |
| `chart_interaction` | `<screen>_<metric>_chart_interacted` |
| `setting_changed` | `settings_<setting>_changed` |
| `notification_opened` | `<type>_notification_opened` |

**Implication:** the README/Q1-Q5 reference comment block (`AppAnalytics.swift:208-345`) lists logical names; PostHog dashboards must be built against the *canonical* names. New analysts will spend a week wondering why `session_start` doesn't exist. **And** the dynamic composition explodes the unique event-name count: `screen_viewed` becomes ~40 distinct events (one per `AppFeature` + sub-screen). PostHog's "Events" dropdown becomes unmanageable; cohort definitions become brittle (a renamed `AppFeature.rawValue` silently renames the event). **Recommendation:** keep one canonical name per logical action with `screen` as a *property*, not part of the event name. The current approach makes `WHERE screen='home'` filtering harder, not easier.

### Duplicates / overlaps

- `notification_opened` (`AppAnalytics.swift:1551`) **and** `<type>_notification_opened` (canonical rewrite at `AppAnalytics.swift:2787`) — same event under two names depending on whether `type` is set. Will cause dashboards to undercount. (P2)
- `feedback_submitted` from `Settings` (manual `trackFeedbackSubmitted`, `AppAnalytics.swift:1474`) and `query_feedback` for "Ask Your Data" (`AppAnalytics.swift:3099`) — both LLM/insight-quality signals, segmented oddly. (P3)
- `subscription_expired` (`AppAnalytics.swift:1067`) is fired from `trackTrialExpired` and contains `converted: 0` — but there's no `subscription_expired` for non-trial expiry; instead `trackSubscriptionCancelled` fires `subscription_cancelled`. Clean but easy to confuse. (P3)
- `notification_sent` (`AppAnalytics.swift:1424`) and `notification_scheduled` (`AppAnalytics.swift:1726`) — only `notification_scheduled` is actually called from notification code; `notification_sent` appears to be dead (`grep -rn trackNotificationSent` returns only the definition). (P2 dead code)

### Vague events

None observed. There is no generic `button_tapped` — `block_tapped` is enriched with `card_id`, `card_label`, `screen`, `tab`, plus dual `interaction_id` / `action_id` (`AppAnalytics.swift:871-893`). Strong taxonomy.

### Event Inventory (full, by category)

> 110 unique base names extracted programmatically from `logEvent(...)` and `capture(event: ...)` calls. Canonical-rewrite versions noted where applicable.

| Event name (source) | Call site (file:line) | Key parameters | Category |
|---|---|---|---|
| `session_start` → `app_session_started` | AppAnalytics.swift:709 | session_id, hour_of_day, day_of_week, streak_days, session_source, network_type, engagement_level, subscription_age_days, months_subscribed | session |
| `session_end` → `app_session_ended` | AppAnalytics.swift:751 | duration_sec, screens_visited, max_depth, core_actions_count | session |
| `return_session` → `app_return_session_recorded` | AppAnalytics.swift:767 | session_number, days_since_last_session, streak_days | session |
| `daily_active` → `app_daily_active_recorded` | AppAnalytics.swift:1718 | session_source, weekly_active_days | retention |
| `screen_viewed` → `<screen>_screen_viewed` | AppAnalytics.swift:799 | screen, screen_id, tab, depth, previous_screen, transition | engagement |
| `screen_exited` → `<screen>_screen_exited` | AppAnalytics.swift:830 | screen, duration_sec | engagement |
| `block_tapped` → `<screen>_block_tapped` | AppAnalytics.swift:889 | card_id, card_label, screen, tab, interaction_id | engagement |
| `core_action_completed` → `<screen>_<action>_completed` | AppAnalytics.swift:859 | action, screen, lifetime_core_actions | activation |
| `insight_tapped` | AppAnalytics.swift:900 | insight_category, severity, metric, screen | content engagement |
| `correlation_tapped` | AppAnalytics.swift:909 | metric_a, metric_b, strength, screen | content engagement |
| `risk_tapped` | AppAnalytics.swift:918 | risk_type, grade, screen | content engagement |
| `chart_interaction` → `<screen>_<metric>_chart_interacted` | AppAnalytics.swift:926 | metric (anonymized), interaction_type, period, screen | content engagement |
| `pull_to_refresh` → `<screen>_pull_to_refresh_triggered` | AppAnalytics.swift:936 | screen, tab | engagement |
| `time_range_changed` | AppAnalytics.swift:943 | screen, context, from_days, to_days | engagement |
| `filter_changed` | AppAnalytics.swift:952 | screen, filter_type, from_filter, to_filter | engagement |
| `weekly_score_change` → `health_score_weekly_changed` | AppAnalytics.swift:971 | score_bracket, direction, days_since_install | outcome |
| `analysis_completed` → `health_analysis_completed` | AppAnalytics.swift:1003 | insights_count, score_bracket, signal_density, analysis_depth | outcome |
| `data_sync_completed` → `health_data_sync_completed` | AppAnalytics.swift:1393 | metrics_count, new_samples_count, duration_sec, is_first_sync | pipeline |
| `data_pipeline_quality` | AppAnalytics.swift:1858 | data_coverage_pct, last_sync_age_sec, coverage_bucket, freshness_bucket | pipeline |
| `first_score_generated` | AppAnalytics.swift:1878 | score_bracket, time_since_install_sec, metrics_used | activation |
| `stale_data_detected` | AppAnalytics.swift:1887 | stale_since_hours, metric (anonymized) | pipeline |
| `sync_failed` → `health_data_sync_failed` | AppAnalytics.swift:2358 | reason, retry_count | error |
| `sync_performance` → `health_data_sync_performance_measured` | AppAnalytics.swift:1756 | duration_ms, samples_loaded, is_incremental | perf |
| `ml_analysis_performance` | AppAnalytics.swift:1766 | duration_ms, components_run, data_points_used | perf |
| `score_generation_failed` → `health_score_generation_failed` | AppAnalytics.swift:2350 | reason | error |
| `health_permission_requested` → `healthkit_permission_requested` | AppAnalytics.swift:1797 | metrics_requested, includes_cycle_data, includes_ecg, metric_preview | permission |
| `health_permission_result` → `healthkit_permission_result_recorded` | AppAnalytics.swift:1808 | granted, denied, total, grant_rate | permission |
| `source_connected` → `<source_type>_source_connected` | AppAnalytics.swift:1818 | source_type, metrics_available | onboarding |
| `device_detected` | AppAnalytics.swift:1375 | device_type, metrics_count, is_active | engagement |
| `device_disconnected` | AppAnalytics.swift:2294 | device_type, days_since_last_data | engagement |
| `notification_permission_requested` | AppAnalytics.swift:3081 | source | permission |
| `notification_permission_result` | AppAnalytics.swift:3088 | granted, source | permission |
| `notification_scheduled` → `<type>_notification_scheduled` | AppAnalytics.swift:1741 | notification_id, hook_category, hour_scheduled | push |
| `notification_opened` → `<type>_notification_opened` | AppAnalytics.swift:1587 | notification_id, type, hook_category, latency_minutes, alert_metric | push |
| `notification_suppressed` | AppAnalytics.swift:1747 | type, reason | push |
| `notification_sent` (DEAD?) | AppAnalytics.swift:1425 | type | push |
| `onboarding_step_completed` | AppAnalytics.swift:508 | step, step_name, duration_sec | onboarding |
| `onboarding_completed` | AppAnalytics.swift:517 | focuses, focuses_count, duration_sec, steps_completed | onboarding |
| `onboarding_drop_off` | AppAnalytics.swift:533 | last_step, last_step_name, duration_sec | onboarding |
| `activation_milestone` | AppAnalytics.swift:561 | milestone, time_since_install_sec, milestones_completed | activation |
| `activation_completed` | AppAnalytics.swift:589 | days_to_activate, sessions_to_activate | activation |
| `aha_moment_reached` | AppAnalytics.swift:577 | milestone, time_since_install_sec | activation |
| `time_to_first_value` | AppAnalytics.swift:603 | seconds, session_number | activation |
| `retention_milestone` | AppAnalytics.swift:619 | day, total_sessions, streak_days | retention |
| `streak_milestone` | AppAnalytics.swift:630 | days, days_since_install | retention |
| `streak_broken` | AppAnalytics.swift:640 | previous_streak, longest_streak | churn |
| `streak_rest_credit_granted` | AppAnalytics.swift:680 | credits_remaining, streak_days | retention |
| `streak_rest_credit_spent` | AppAnalytics.swift:687 | credits_remaining, streak_days_saved | retention |
| `inactive_period_detected` | AppAnalytics.swift:655 | days_inactive, was_activated, lifetime_core_actions | churn |
| `paywall_viewed` | AppAnalytics.swift:1081 | source, days_since_install, was_activated | monetization |
| `paywall_dismissed` | AppAnalytics.swift:1093 | time_on_paywall_sec, source | monetization |
| `paywall_cta_tapped` | AppAnalytics.swift:1103 | product_id, price | monetization |
| `subscription_purchased` | AppAnalytics.swift:1129 | product_id, price, region, price_tier, trial_converted, revenue, currency, subscription_period | monetization |
| `subscription_renewed` | AppAnalytics.swift:1168 | months_subscribed, renewal_count | monetization |
| `subscription_cancelled` | AppAnalytics.swift:1179 | months_subscribed, renewal_count, lifetime_core_actions | monetization |
| `subscription_expired` | AppAnalytics.swift:1067 | converted, milestones_completed, was_activated | monetization |
| `restore_attempted` | AppAnalytics.swift:1191 | success | monetization |
| `purchase_failed` | AppAnalytics.swift:1199 | product_id, error_type | monetization |
| `trial_started` | AppAnalytics.swift:1043 | days_remaining | monetization |
| `trial_day_check` | AppAnalytics.swift:1053 | days_remaining, milestones_completed, lifetime_core_actions | monetization |
| `billing_grace_started` | AppAnalytics.swift:1515 | days_since_install | monetization |
| `billing_grace_resolved` | AppAnalytics.swift:1521 | days_in_grace | monetization |
| `pro_feature_funnel` | AppAnalytics.swift:1775 | feature, step | monetization |
| `premium_feature_attempted` | AppAnalytics.swift:1605 | feature, screen | monetization |
| `pro_feature_upgrade_tapped` (raw) | ProFeatureOverlay.swift:50 | (direct PostHog) | monetization |
| `nps_submitted` | AppAnalytics.swift:1332 | score, source, was_activated | trust |
| `feedback_submitted` → `<category>_feedback_submitted` | AppAnalytics.swift:1475 | category, text_length, sentiment | trust |
| `feedback_prompt_shown` | AppAnalytics.swift:1469 | days_since_install | trust |
| `pmf_survey_response` → `pmf_survey_response_submitted` | AppAnalytics.swift:2973 | response, source, was_activated | PMF |
| `pmf_segment_response` | AppAnalytics.swift:2986 | segment | PMF |
| `pmf_benefit_response` | AppAnalytics.swift:2993 | benefit | PMF |
| `pmf_improvement_response` | AppAnalytics.swift:3000 | text_length only (text not sent — good) | PMF |
| `query_feedback` → `ask_your_data_query_feedback` | AppAnalytics.swift:3099 | helpful, confidence, query_length | trust |
| `recommendation_viewed/started/completed/skipped/outcome` | AppAnalytics.swift:1937, 1946, 1954, 1962, 1547 | recommendation_type, metric (anonymized), lift_24h, lift_7d | recommendation lifecycle |
| `insight_marked_helpful/unhelpful` | AppAnalytics.swift:1908, 1916 | insight_category, metric, reason | trust |
| `insight_engagement` | AppAnalytics.swift:1784 | insight_category, metric, action | trust |
| `explanation_viewed` | AppAnalytics.swift:1899 | explanation_type, screen | trust |
| `privacy_page_viewed` | AppAnalytics.swift:1925 | source | trust |
| `report_exported` | AppAnalytics.swift:1397 | score_bracket, metrics_count | engagement |
| `share_sheet_presented` | AppAnalytics.swift:1431 | content_type | engagement |
| `share_completed` | AppAnalytics.swift:3012 | content_type, activity_type, completed | viral |
| `referral_code_shared` | AppAnalytics.swift:2245 | **code** (PII risk — see Finding G2) | referral |
| `referral_code_redeemed` | AppAnalytics.swift:2256 | **code**, success, failure_reason | referral |
| `referral_completed` | AppAnalytics.swift:2260 | role | referral |
| `simulation_run` | AppAnalytics.swift:1653 | adjusted_metrics, score_delta, confidence | feature |
| `roi_recommendation_tapped` | AppAnalytics.swift:1662 | metric, predicted_gain, effort_level | feature |
| `ecg_analysis_completed` | AppAnalytics.swift:1671 | recordings_count, afib_count | feature |
| `nutrition_correlation_discovered` | AppAnalytics.swift:1679 | nutrition_metric (anonymized), outcome_metric (anonymized), correlation | feature |
| `clinical_insight_generated` | AppAnalytics.swift:1687 | metric (anonymized), clinical_stage, trajectory | feature |
| `health_state_timeline_viewed` | AppAnalytics.swift:1695 | current_state, days_in_state, total_states | feature |
| `circadian_analysis_completed` | AppAnalytics.swift:1704 | chronotype, metrics_analyzed, confidence | feature |
| `workout_plan_generated/opened` | AppAnalytics.swift:1980, 1998 | training_zone, recovery_band, target_duration_min, has_cycle_adjustment, cycle_phase | feature |
| `breathwork_protocol_selected` | AppAnalytics.swift:2009 | protocol_type, planned_duration_sec, phase_count | feature |
| `breathwork_session_started/paused/resumed/completed/abandoned` | AppAnalytics.swift:2018-2096 | protocol_id, planned_duration_sec, actual_duration_sec, completion_rate, mood, pause_count | feature |
| `journal_entry_created` | AppAnalytics.swift:2323 | category, has_notes (boolean only — text not sent — good) | journal |
| `journal_entry_deleted` | AppAnalytics.swift:2330 | category | journal |
| `live_activity_state_changed` | AppAnalytics.swift:2149 | activity_kind, activity_state | live activity |
| `live_activity_action_performed` | AppAnalytics.swift:2156 | activity_kind, action_kind | live activity |
| `live_activity_sleep_outcome` | AppAnalytics.swift:2183 | bedtime_epoch, sleep_onset_epoch, delta_minutes | live activity |
| `widget_snapshot_updated` | AppAnalytics.swift:2199 | trigger, snapshots_written, completeness_count | widget |
| `widget_tapped` | AppAnalytics.swift:3173 | widget_kind | widget |
| `widget_displayed` | AppAnalytics.swift:3181 | widget_kind, has_data | widget |
| `watch_app_session_start/end` | AppAnalytics.swift:3189, 3196 | duration_sec | watch |
| `streaming_started/stopped` → `live_vitals_*` | AppAnalytics.swift:1444, 1455 | duration_sec | live |
| `live_first_data_received` → `live_vitals_first_data_received` | AppAnalytics.swift:1462 | screen | live |
| `setting_changed` → `settings_<setting>_changed` | AppAnalytics.swift:1417 | setting_name, new_value | settings |
| `discovery_shown/page_viewed/completed` | AppAnalytics.swift:1619, 1627, 1634 | count, types, page_index, pages_viewed | onboarding |
| `empty_state_shown` → `<screen>_empty_state_shown` | AppAnalytics.swift:2341 | screen, reason | friction |
| `connectivity_recovered` | AppAnalytics.swift:1529 | offline_duration_sec, sync_triggered, backup_triggered | pipeline |
| `error_occurred` → `<screen>_<error_type>_error_occurred` | AppAnalytics.swift:1357 | error_type, screen, message (truncated 100ch) | error |
| `app_error_recorded` (raw via PostHogManager.captureError) | PostHogManager.swift:96, 110 | error_message, error_context, error_domain, error_code | error |
| `app_crash` (raw, fired from signal/exception handlers) | PostHogManager.swift:132, 155 | crash_type, exception_name, signal_name, stack_trace | error |
| `screenshot_taken` | AppAnalytics.swift:2469 | screen, tab, subscription_status | trust signal |
| `ghost_session` | AppAnalytics.swift:2377 | duration_sec, screens_visited | churn |
| `session_quality` | AppAnalytics.swift:2393 | quality, duration_sec, core_actions | engagement |
| `score_viewed` | AppAnalytics.swift:2422 | score_bracket, direction | outcome |
| `score_reaction` | AppAnalytics.swift:2445 | reaction_type, next_action, reaction_time_sec, score_delta | outcome |
| `habit_ritual_formed` | AppAnalytics.swift:2512 | ritual_strength, peak_hour, streak_days | retention |
| `feature_discovered` | AppAnalytics.swift:2554 | feature, total_discovered, discovery_pct | activation |
| `rage_tap` | AppAnalytics.swift:2585 | element, screen, tap_count | friction |
| `pre_churn_signal` | AppAnalytics.swift:2624 | avg_engagement_score, trend, latest_score | churn |
| `background_refresh_result` → `background_refresh_completed` | AppAnalytics.swift:2647 | success, duration_ms, samples_loaded | pipeline |
| `value_delivered` → `analysis_value_delivered` | AppAnalytics.swift:2662 | has_new_value, new_insights, score_changed, new_anomalies | outcome |
| `cloud_backup_completed/failed` | AppAnalytics.swift:3025, 3033 | snapshot_count, ml_state_count, reason | pipeline |
| `cloud_restore_completed` | AppAnalytics.swift:3040 | snapshot_count, success | pipeline |
| `app_store_review_prompted` | AppAnalytics.swift:3053 | trigger, was_activated | trust |
| `deep_link_opened` | AppAnalytics.swift:3072 | url (200ch truncated), source, campaign | attribution |
| `achievement_unlocked` | AppAnalytics.swift:2270 | achievement_id, achievement_title, achievement_category | engagement |
| `level_up` | AppAnalytics.swift:2278 | new_level, total_days_tracked | engagement |
| `alert_acted_on` | AppAnalytics.swift:2307 | alert_type, metric (anonymized), action | push |
| `alert_dismissed` | AppAnalytics.swift:2315 | alert_type, metric (anonymized) | push |
| `user_health_snapshot` | AppAnalytics.swift:2115 | watch_paired, daily_completeness_7d_pct, push_authorized, hk_*_has_data, churn_health_score, churn_bucket | health-pipeline composite |
| `section_viewed/tapped` → `<section>_section_*` | AppAnalytics.swift:1493, 1503 | section_id, tab, duration_ms | engagement |
| `scroll_depth` → `<screen>_scroll_depth_recorded` | AppAnalytics.swift:1484 | screen, max_depth_percent | engagement |
| `healthkit_authorized` (raw) | OnboardingConnectHealthStep.swift:70 | healthkit_available | onboarding |
| `calibration_completed` (raw) | OnboardingMirrorMomentStep.swift:330 | elapsed_sec, metrics_with_data, highlights_count | onboarding |
| `calibration_failed` (raw) | OnboardingMirrorMomentStep.swift:320 | error_message (could leak — see below), elapsed_sec | onboarding |

**E1 [P2] — Three events bypass `AppAnalytics` and call `PostHogManager.shared.capture` directly** (`OnboardingConnectHealthStep.swift:70`, `OnboardingMirrorMomentStep.swift:320,330`, `ProFeatureOverlay.swift:50`). They skip the canonical-name rewrite, the param sanitization (`anonymizeMetricValue`, 100ch truncation, bool→int normalization), and the auto-enrichment in `logEvent` (session_id, days_since_install, subscription_status, etc.). Result: these four events land in PostHog without any of the cross-cutting properties every dashboard query expects. **Fix:** route through `AppAnalytics` — or expose a `logRawEvent` that still applies the enrichment but skips the canonical rewrite for known-clean names.

---

## 5. Funnel Coverage — Onboarding (`Modules/Onboarding/`)

Six steps in `OnboardingView.swift:9-16`: `pulse → profile → connect → priority → mirror → promise`.

| Step | `step_started` event? | `step_completed` event? | Verdict |
|---|---|---|---|
| pulse | NO | YES (`onChange` of currentStep — `OnboardingView.swift:111-120`) | partial |
| profile | NO | YES (same mechanism) | partial |
| connect | NO | YES + extra `healthkit_authorized` raw event when user grants HK | partial |
| priority | NO | YES | partial |
| mirror | NO | YES + `calibration_completed`/`calibration_failed` raw events | partial |
| promise | NO | `onboarding_completed` instead | partial |

**F1 [P1] — No `step_started` events for any onboarding step.** `OnboardingView.swift` only fires `trackOnboardingStepCompleted` on transition (line 114), so the *first* step (`pulse`) has no started event at all, and time-on-step measurement starts from app launch (`stepStartDate = Date()` set in `onAppear`, line 101) which is wrong if the user takes 30s to reach the first step. Drop-off math like "of users who started step 3, what % completed it" is impossible: you can only see "completed step 2 → completed step 3 transition," which conflates "started step 3 and quit" with "never started step 3." **Fix:** fire `onboarding_step_started` in each step's `.onAppear`. Two-event-per-step is the only PostHog-funnel-friendly pattern.

**F2 [P2] — `onboarding_drop_off` only fires if `appStateStore.onboardingCompleted == false` when `OnboardingView.onDisappear` runs.** Edge case: if the app is force-quit mid-onboarding (user swipes up from app switcher), `onDisappear` may not run — silent loss. PostHog's `app_session_ended` lifecycle event will fire on next launch, but `onboarding_drop_off` will not. **Fix:** persist `onboarding_in_progress` flag in UserDefaults; on next session_start, if flag is set and `onboardingCompleted=false`, fire a delayed `onboarding_drop_off` retroactively.

**F3 [P3] — `OnboardingView.swift:111` uses `onChange(of: currentStep)` to mark the *previous* step completed when the new step appears. If the user taps Continue on `connect` but HK permission sheet is dismissed without authorization, the `connect` step is still marked "completed" in analytics. The `healthkit_authorized` event is the only signal of real outcome. Funnel will overstate connect-step completion. (`OnboardingConnectHealthStep.swift:67-75`)

---

## 6. Paywall Coverage (`Modules/Paywall/`)

Required vs present:

| Required event | Present? | File:Line |
|---|---|---|
| paywall_viewed | YES | PaywallView.swift:79, also fired with `source: "trial_expired"` and `source: "aha_moment"` (InsightsDetailView.swift:198) |
| paywall_dismissed | YES (`onDisappear`) | PaywallView.swift:85-91 |
| plan_selected | **NO** — only `paywall_cta_tapped` is fired when subscribe button is tapped, and it carries the chosen `product_id` (PaywallView.swift:276), so plan-tier selection (yearly vs monthly toggle, `paywallPlanYearly`/`paywallPlanMonthly` BlockTypes exist in AppFeature) is captured only as a `block_tapped` event. Acceptable but not labeled as a funnel-step. (P2) |
| purchase_initiated | **NO** discrete event — `paywall_cta_tapped` is the closest. Apple's purchase sheet may take 5-30s; if user cancels we fire `purchase_failed(user_cancelled)` from `SubscriptionManager.swift:149`. So funnel is `paywall_cta_tapped → (purchase_failed | subscription_purchased)`. Workable. (P2) |
| purchase_succeeded | YES (`subscription_purchased`) | SubscriptionManager.swift:560 |
| purchase_failed (with reason) | YES, with `error_type` ∈ {`user_cancelled`, `purchase_error`} only — no Apple SKError code, no `errorMessage` content (PaywallView.swift:159 sets `errorMessage = "Purchase failed."` but it's not propagated to PostHog) | SubscriptionManager.swift:149, 159. **P2** — log the underlying SKError code so you can distinguish payment-method-failed vs network-failed vs in-house verification failed |
| restore_purchase_tapped | implicitly via `block_tapped` BlockType.paywallRestore (AppFeature.swift:184) — not as a discrete tracked event with that name | partial |
| restore_purchase_succeeded | `restore_attempted(success: Bool)` | PaywallView.swift:326 — works but the API is `success` not `succeeded`; will need fixed dashboard naming. (P3) |
| free_trial_started | YES (`trial_started`) | AppAnalytics.swift:1218, fired from `updateSubscriptionProperties` when previousStatus was "unknown" — **fragile.** This means the trial_started event is only fired the *first* time the app sees a trial state. If user installs, opens app, trial state hasn't loaded yet (StoreKit is async), `previousStatus` is "unknown" → trial_started fires. But if app is killed before status persists, on next launch `previousStatus` is still "unknown" → fires again. Duplication risk. **P1** |
| trial_to_paid_converted | YES (`subscription_purchased` with `trial_converted=1`) | AppAnalytics.swift:1131-1134; SubscriptionManager.swift:143-146 captures `wasTrialBefore` correctly |
| subscription_renewed | YES with deduplication via `lastRenewalExpirationDate` (60s window) | AppAnalytics.swift:1150-1175 — solid |
| subscription_canceled | YES (`subscription_cancelled`) — fired when status transitions from `pro` or `billing_grace` → `expired` | AppAnalytics.swift:1230-1231 |
| refund_requested | **NO** — Apple does not surface refund events to client; would need server-side App Store Server Notifications V2. **P2** — out of scope for client SDK but flag for backend roadmap |
| trial_expired | YES | AppAnalytics.swift:1063 |
| billing_grace_started/resolved | YES | AppAnalytics.swift:1514, 1520 |

**G1 [P1] — `trial_started` may double-fire** because `updateSubscriptionProperties` infers it from `previousStatus == "unknown"` rather than persisting "we already announced this trial." (`AppAnalytics.swift:1217-1219`). Add a `trialStartedTracked: Bool` flag in UserDefaults keyed on the trial transactionID, gate the call.

**G2 [P0 — PII] — `referral_code_shared` and `referral_code_redeemed` ship the full referral code as `code` parameter** (`AppAnalytics.swift:2245-2257`). The code is generated server-side per user (Modules/Referral/Services/ReferralManager.swift), is short, alpha-numeric, and is **a stable identifier of the inviting user**. Sending this through PostHog means: (a) the inviter's PostHog profile becomes joinable to the redeemer's PostHog profile via `code` equality; (b) the code itself is now stored in PostHog forever; (c) if the inviter later requests GDPR deletion, the code in redeemer events is orphaned but discoverable. **Fix:** hash the code before sending (`SHA256(code)[:8]` is enough for cohort analysis) or send only `code_present: true`. Funnel/conversion analytics work fine on the hash.

---

## 7. Conversion / Activation Events

| Required | Present? | File:Line |
|---|---|---|
| first_session | YES (`session.isFirstSession` — first totalSessions==1) | SessionTracker.swift:322 — but never emitted as a discrete event; only as a property on `session_start`. (P3) |
| hk_authorized | YES (`healthkit_authorized` raw) + `health_permission_result` | OnboardingConnectHealthStep.swift:70, AppAnalytics.swift:1808 |
| first_score_seen | YES (`first_score_generated` with `firstScoreGeneratedTracked` UserDefaults guard) | AppAnalytics.swift:1027-1034 |
| first_journal_entry | **NO discrete event** — `journal_entry_created` fires every time, no "first" flag | AppAnalytics.swift:2322 — P2 |
| first_workout_logged | **NO** — workout_plan_generated/opened are *plan*-level, no workout completion event | AppAnalytics.swift:1980 — P2 |
| daily_active | YES | AppAnalytics.swift:1717 |
| weekly_active | YES (as user property `weekly_active_days` on every event) | AppAnalytics.swift:732 |
| day_2 / day_7 retention signals | YES (`retention_milestone` for days 1,2,3,7,14,30) | SessionTracker.swift:265-275, AppAnalytics.swift:619 |

**H1 [P3] — Add a `first_journal_entry` and `first_workout_completed` activation milestone** (extend `ActivationMilestone` enum at `AppAnalytics.swift:540-553`). They're listed conceptually in the Q1 reference comment but never wired up.

---

## 8. Feature Engagement — Module × Stage × Tracked Matrix

Every module has at least a `trackFeatureOpen(.<feature>)`. Verified by grep at the call sites listed in §earlier output.

| Module | `<module>_opened`? | Action verbs tracked? | Verdict |
|---|---|---|---|
| Dashboard / Home | YES (`HomeView.swift:91`) | block_taps for `recovery_card`, `sleep_card`, `smart_action`, `headline_insight`, `home_daily_action`, `home_brain_health_card`, `home_recovery_info_button`, `share_card`, `home_risk_row`, `data_confidence_badge` | strong |
| Insights | YES (`InsightsDetailView.swift:151`) + `insight_tapped`, `insight_marked_helpful/unhelpful`, `insight_engagement` | strong |
| Sleep | YES (`SleepCoachView.swift:121`) | no `sleep_action_<verb>` granular events; relies on generic block_taps | medium |
| Strain | YES (`StrainDetailView.swift:107`) | only screen open + `screen_exited`; no per-action verbs | medium |
| Stress / Breathwork | YES (`StressMonitorView.swift:31`, `BreathworkView.swift:191`) + 5 breathwork lifecycle events | strong |
| BrainHealth | YES (`BrainHealthDetailView.swift:34`) | only open; no per-action; no `brain_health_self_test_started` etc | medium-low |
| CycleTracking | YES (`CycleDetailView.swift:163`) | no per-action verbs; cycle phase changes / log entries not tracked | low — sensitive feature, undertracked |
| Journal | YES (3 sub-screens) + `journal_entry_created/deleted`, `journal_category_selected/journal_entry_saved/cancelled` block_types | strong |
| Live | YES (`LiveView.swift:143`) + `streaming_started/stopped`, `live_first_data_received`, `live_activity_*` | strong |
| WeeklyReview | YES (`WeeklyReviewView.swift:162`) | no per-action verbs; `weekly_review_card`/`weekly_review_score` sections tracked via SectionTracker | medium |
| Discovery | YES + `discovery_shown/page_viewed/completed` | strong |
| Explore | YES (`ExploreView.swift:278`) + 9 ExploreXxx block_types | strong |
| Referral | NO `referral_screen_opened` event (referral flow tracked only by code share/redeem) — but Modules/Referral has no Views directory shown; the screen open is implicit (P3) | strong on outcomes |
| WebExport | NO `web_export_opened` event; only `report_exported` outcome (`WebExportViewModel.swift:46`) | medium |
| Achievements (Profile) | YES (`AchievementsView.swift:188`) + `achievement_category_filter`, `achievement_unlocked`, `level_up` | strong |
| Risk | YES (`HealthRiskDetailView.swift:38`) + `risk_tapped` | medium |
| HealthState | YES (`HealthStateTimelineView.swift:60`) + `health_state_timeline_viewed`, `health_state_prev/next_month` | strong |
| Vitality | YES (`VitalityDetailView.swift:47`) | medium — no per-action |
| MetricDetail | YES (`MetricDetailView.swift:163`) + `metric_log_*` block_types, `chart_interaction` | strong |
| Devices | YES (`ConnectedDevicesView.swift:152`, `DeviceDetailView.swift:28`, `DeviceSetupGuideView.swift:44`) + `device_detected`, `device_disconnected`, `manage_devices`/`device_row` block_types | strong |
| Settings | YES (`SettingsView.swift:119`) + `setting_changed`, `metric_alerts_picker` | strong |
| Onboarding | YES (`OnboardingView.swift:102`) + step events | medium (see §5) |
| Paywall | YES (`PaywallView.swift:75`) + paywall events | strong |

### Coverage Matrix (compact)

```
                                  open  start   complete   action_verbs   error
Dashboard/Home                     ✓     —        —           ✓ many        ✓
Insights                           ✓     —        —           ✓             —
Sleep                              ✓     —        —           ~             —
Strain                             ✓     —        —           —             —
Stress / Breathwork                ✓     ✓        ✓           ✓ many        —
BrainHealth                        ✓     —        —           —             —
CycleTracking                      ✓     —        —           —             —
Journal                            ✓     —        ✓ create    ✓ block       —
Live                               ✓     ✓ stream ✓ stream    ✓             —
WeeklyReview                       ✓     —        —           ~ block       —
Discovery                          ✓     ✓ page   ✓           ✓             —
Explore                            ✓     —        —           ✓ many        —
Referral                           — implicit                   ✓ outcome   ✓ failure_reason
WebExport                          —     —        ✓           —             —
Achievements                       ✓     —        ✓           ✓             —
Risk                               ✓     —        —           ✓ tapped      —
HealthState                        ✓     —        ✓           ✓             —
Vitality                           ✓     —        —           —             —
MetricDetail                       ✓     —        —           ✓             —
Devices                            ✓     —        ✓ connect   ✓             ✓
Settings                           ✓     —        ✓ change    ✓             —
Onboarding                         ✓     ✗        ✓ step      ✓             ✓ calibration_failed
Paywall                            ✓     —        ✓ purchase  ✓             ✓ purchase_failed
```

**I1 [P2] — Strain, BrainHealth, Vitality, CycleTracking, WeeklyReview lack per-action verbs.** These are major user-facing features. CycleTracking is also the most privacy-sensitive feature in the app — undertracking is *good* for privacy but bad for product analytics. Spec a minimal verb set per module (e.g., `cycle_phase_acknowledged`, `cycle_log_added`, `cycle_calendar_navigated`) and add them as events, **not** as block_taps so they survive UI refactors.

**I2 [P3] — `WebExport` has no `web_export_opened` event, only `report_exported` on success.** Funnel from "user enters export flow" → "user receives PDF" cannot be measured.

---

## 9. Notification + Push Events

| Event | Present? | File:Line |
|---|---|---|
| push_received | NO — local notifications only, no remote push framework wired (no APNs registration in AppDelegate) | — |
| push_opened | YES via `notification_opened` (local notif) | AppAnalytics.swift:1551, called from `AppDelegate.swift:45` |
| notification_permission_requested | YES | AppAnalytics.swift:3081 |
| notification_permission_granted/denied | YES (`notification_permission_result(granted: Bool)`) | AppAnalytics.swift:3088 |
| notification_scheduled | YES | AppAnalytics.swift:1726 |
| notification_suppressed | YES (cap/filter visibility) | AppAnalytics.swift:1746 |

**J1 [P3] — App is local-notifications-only, so `push_received` is not applicable.** Confirm with product that remote push is post-launch; if it's coming, leave a TODO marker.

---

## 10. Permission Events

| Permission | Requested? | Result? |
|---|---|---|
| HealthKit (per-type ideally) | YES (`health_permission_requested` with `metrics_requested` count, `includes_cycle_data`, `includes_ecg`, plus `metric_preview` showing first 5) | YES (`health_permission_result` aggregate counts only) |
| Motion | NO instrumentation | NO |
| Siri / App Intents | NO instrumentation | NO |
| Location | NO instrumentation | (app may not use location) |
| Notifications | YES | YES |
| Contacts | NO (app may not use) | — |

**K1 [P2] — `health_permission_result` aggregates by count, not by HKObjectType.** So you cannot answer "what % of users grant *menstrual flow* read access vs *resting heart rate*?" — which is critical for understanding which permission requests are scaring users. **Fix:** emit one event per HKObjectType, or include a `denied_types` array in the result event. The privacy guard against shipping condition names is `anonymizeMetricValue`, but here you'd need to invert it: HK type names like `HKQuantityTypeIdentifierMenstrualFlow` are arguably medical info. Use coarse HealthCategory groupings (heart, sleep, body, cycle) — same scheme already used for metric anonymization.

**K2 [P2] — `metric_preview` parameter on `health_permission_requested`** (`AppAnalytics.swift:1801`) sends the first 5 metric raw values comma-joined. This is captured as a string and run through `anonymizeMetricValue` (which replaces with HealthCategory) thanks to `metric_preview` being in the `metricParameterKeys` set (`AppAnalytics.swift:2899-2902`). Verified safe.

---

## 11. Error Tracking

Three layers:

1. **Domain errors via PostHog** — 11 call sites (verified `grep -rn "trackError\|recordNonFatal"` returns 11 in product code), e.g. `HealthKitManager.swift:171`, `DashboardViewModel.swift:659/668`, `HomeView.swift:797`, `HealthDataStore.swift:257/342/349`. Plus 11 `PostHogManager.shared.captureError` direct calls in HealthKitManager / HealthDataContainerFactory / HealthDataBatchWriter / EncryptedStore / AppIntegrityGuard.
2. **Crash reporting via PostHog `app_crash`** — uncaught NSException + POSIX signals. (`PostHogManager.swift:130-165`)
3. **No Firebase Crashlytics or Sentry** — verified by `grep -rln "Crashlytics\|Sentry"` returning 0 hits.

**L1 [P1] — PostHog is the *only* crash reporter.** PostHog's signal-handler approach captures the stack symbolicated via `callStackSymbols.prefix(15)` (`PostHogManager.swift:131`) but: (a) iOS dSYMs are not uploaded to PostHog (no Crashlytics-style postBuildScript for PostHog symbol upload exists in this repo — verified by reading the project memory note about Firebase dSYM uploads, which only handles Firebase), so stack frames will be `0x0000000100123abc` hex addresses; (b) no rate-limit / dedup at the SDK level, so a tight crash loop could exceed PostHog quotas; (c) no offline persistence — if the crash happens before network, `flush()` may fail silently (the capture is sync but the network is async; the subsequent `signal(SIG_DFL); raise(signalNumber)` will kill the process before a network round-trip in many cases). **Fix:** add Firebase Crashlytics or Sentry (recommended) and let PostHog see only domain errors. The `app_crash` event still has value as a counter, but symbolicated stacks belong in a real crash reporter.

**L2 [P2] — `app_error_recorded` event is fired by `PostHogManager.captureError` but never canonicalized through `AppAnalytics.logEvent`.** It bypasses the auto-enrichment (no `session_id`, no `days_since_install`, no `subscription_status`). Two paths to error tracking exist (`AppAnalytics.recordNonFatal` → `PostHogManager.captureError` AND direct `PostHogManager.captureError` from HealthKitManager etc.). They produce inconsistent property shapes. **Fix:** route everything through `AppAnalytics.recordNonFatal` and have *that* call `logEvent("app_error_recorded", parameters: ...)` so enrichment kicks in.

**L3 [P3] — `error_occurred` event** (`AppAnalytics.swift:1357`) captures `message` truncated to 100 chars. Inspection of `OnboardingMirrorMomentStep.swift:320` shows `calibration_failed` ships `error_message` raw with no truncation — could leak Swift error descriptions that include user-data fragments. Pipe this through `recordNonFatal` instead.

---

## 12. Super-Properties

PostHog terminology: the iOS SDK auto-enriches with `$lib`, `$device_*`, `$os_*`, `$screen_*`, `$timezone`. Beyond that, Laso adds *per-event enrichment* in `AppAnalytics.logEvent` (`AppAnalytics.swift:3109-3157`):

- `session_id` (default)
- `tab` (default)
- `screen` (current)
- `session_source`
- `session_number`
- `days_since_install`
- `streak_days`
- `weekly_active_days`
- `nav_depth`
- `organic_session_pct`
- `app_version`
- `subscription_status`
- `user_tier`
- `onboarding_completed`
- `activation_status`

And user properties (`$set` via `setUserProperties`): age_bracket, gender, country, language, timezone, device_model, phone_model, os_version, app_version, uses_voiceover, uses_reduce_motion, uses_dynamic_type, has_apple_watch, health_source_count, primary_health_source, days_since_first_sync, watch_model, wearable_model, notifications_enabled, subscription_status, user_tier, health_score_bracket, churn_health_score, churn_bucket, hk_*_has_data, watch_paired, daily_completeness_7d_pct, push_authorized, notif_categories_enabled, longest_streak, streak_days, total_sessions, lifetime_core_actions, weekly_active_days, organic_session_pct, activation_status, engagement_level, subscription_age_days, retention_day, trial_converted, journey_stage, last_meaningful_action, last_active_screen, has_morning_ritual, usage_pattern, feature_discovery_pct, rest_credits_remaining.

**M1 [P3] — No actual `posthog.register(...)` call (true PostHog super-properties).** All "super-property"-like enrichment happens manually in `logEvent`. Pros: control. Cons: every direct `PostHogSDK.shared.capture(...)` (the 4 raw call sites) lacks them. **Fix:** call `PostHogSDK.shared.register([...])` once after `setup()` for the truly invariant ones (`app_version`, `device_model`, `os_version`) so even raw captures get them. Keep dynamic ones (session_id, days_since_install) in `logEvent`.

**M2 [P3] — Missing super-properties:** `has_premium` (computed but only in user_tier; expose as a boolean), `app_environment` (DEBUG/Beta/AppStore — would let you filter dev pollution), `tracker_version` (your own analytics schema version — when you change event shapes, dashboards need to know).

---

## 13. PII Risk Table

| Event | Param | Risk | File:Line | Fix |
|---|---|---|---|---|
| `referral_code_shared` | `code` | **HIGH** — stable per-user identifier; joins inviter/redeemer in third-party | AppAnalytics.swift:2245 | Hash before send |
| `referral_code_redeemed` | `code` | HIGH — same | AppAnalytics.swift:2256 | Hash before send |
| `deep_link_opened` | `url` (200 ch truncated) | MEDIUM — universal links could carry referral codes, campaign IDs that are user-identifiable | AppAnalytics.swift:3072 | Strip query params; send only `path` and `host` |
| `calibration_failed` | `error_message` raw | MEDIUM — Swift error descriptions can include data fragments | OnboardingMirrorMomentStep.swift:320 | Truncate + scrub |
| `app_error_recorded` | `error_message` from `error.localizedDescription` | MEDIUM — same | PostHogManager.swift:90 | Truncate + scrub |
| `notification_opened` | `notification_id` (full identifier including metric name in some hooks like `healthpulse.triage.menstrualFlow.high`) | MEDIUM — leaks specific HK metrics | AppAnalytics.swift:1573-1587 | Already partially anonymized via `alert_metric` parsing, but `notification_id` itself is sent raw — apply `anonymizeMetricValue` to the parts |
| `setting_changed` | `new_value` (raw) | LOW — could include user-typed preferences if a future setting accepts free text | AppAnalytics.swift:1417 | Whitelist allowed values per setting |
| `health_permission_requested` | `metric_preview` | LOW — anonymized to category | AppAnalytics.swift:1797 | OK as-is |
| `feedback_submitted` | `category`, `text_length`, `sentiment` (no text) | LOW — text is intentionally not sent | AppAnalytics.swift:1474 | OK |
| `pmf_improvement_response` | `text_length` only | NONE | AppAnalytics.swift:3000 | OK |
| `journal_entry_created` | `category`, `has_notes` (boolean) | NONE — value/text not sent | AppAnalytics.swift:2322 | OK |
| `subscription_purchased` | `product_id`, `price`, `region`, `revenue`, `currency` | LOW — region is country-coarse | AppAnalytics.swift:1112 | OK; consider redacting price for users who use family-share / subsidized regions |
| `score_viewed`, `weekly_score_change`, `analysis_completed`, `first_score_generated` | `score_bracket` (already coarsened to 20-pt bucket) | NONE — `scoreBracket(_:)` is the privacy guard | AppAnalytics.swift:2677 | OK — verified |
| All metric-bearing events | `metric` / `metric_a` / `metric_b` / `alert_metric` / `nutrition_metric` / `outcome_metric` | NONE — `anonymizeMetricValue` replaces with HealthCategory | AppAnalytics.swift:2899-2918 | OK — verified |
| `chart_interaction` | `metric` (anonymized) | OK | AppAnalytics.swift:926 | OK |
| `screenshot_taken` | `screen`, `tab`, `subscription_status` | LOW | AppAnalytics.swift:2469 | OK |
| `session_replay` (the *recording itself*) | full screen | **HIGH** — see Finding B1 | PostHogManager.swift:29 | **Disable for v1** |

**N1 — The metric-anonymization pattern is a real strength.** `metricParameterKeys` set + `anonymizeMetricValue` ensures any `HealthMetric.rawValue` ("bloodPressure", "menstrualFlow") gets remapped to `HealthCategory.rawValue` ("heart", "cycle"). This is the rare analytics implementation that takes health-data PII seriously.

**N2 — But the strength has two leaks: (a) raw `PostHogSDK.shared.capture(...)` calls (4 sites) bypass `sanitizeParameters`; (b) `notification_id` carries metric names un-anonymized.** Both fixable.

---

## 14. Session Replay (separate call-out because of severity)

Already analyzed in §1 and §2. Headline:

- `sessionReplay = true` (`PostHogManager.swift:29`).
- Masks: `maskAllTextInputs=true` masks only `UITextField`/`UITextView`/`SecureField` — *not* SwiftUI `Text`. The 30+ `.postHogMask()` annotations on score/HRV/cycle/strain/stress views (`grep -rn "postHogMask" --include="*.swift"`) are the only protection for non-input text. Any new screen that ships without `.postHogMask()` on its values is a leak. Maintenance burden.
- `maskAllImages=true` is solid — chart images are masked.
- `maskAllSandboxedViews=true` masks WebView/Map.
- **No event-property gate / no consent** → replay is on for everyone from launch.

**O1 [P0] — DISABLE session replay for v1 launch.** Re-enable post-launch behind explicit consent + ATT prompt + privacy-policy update. See §2 B1.

**O2 [P1] — Even if kept, audit every health-value-rendering view for `.postHogMask()`. The SwiftUI/Text-default no-mask behavior is a bug-magnet.** Add a lint rule or runtime check.

---

## 15. Feature Flags

**P1 [P1] — PostHog Feature Flags are not used at all.** No `getFeatureFlag`, `isFeatureEnabled` (in PostHog sense), `reloadFeatureFlags`, or any related calls. Verified by grep. Instead, `Core/Config/RemoteConfigManager.swift:3` uses `import FirebaseRemoteConfig` (`RemoteConfigManager` has 380+ lines), and `Core/Config/FeatureGate.swift` reads from it (`FeatureGate.swift:8,24`). Firebase Remote Config is the source of truth for: subscription product IDs, trial days, analysis thresholds, feedback prompt cadence, etc.

**P2 [P2] — Two flag systems is one too many.** Today only Firebase RC is used — that's fine. But if the team adds PostHog flags later (very common to do so for A/B tests against a behavior cohort), you'll have two truth sources, two SDKs that must agree, two cache lifetimes, and silent drift. Recommendation: stay with Firebase RC for runtime config; if A/B testing on PostHog cohorts is needed, define a hard line — "PostHog only for experiments, RC only for config."

**P3 [P3] — No fallback safety check exists for PostHog flags because there are no PostHog flags. If/when added: `getFeatureFlag(_:defaultValue:)` MUST be used; never block app initialization on flag fetch.**

---

## 16. A/B Test Framework Risk

Today: zero A/B tests. Firebase RC supports A/B (Firebase A/B Testing) but no `setDefaults` / `experimentResults` calls observed. PostHog supports experiments but not configured.

**Q1 [P2] — Pre-launch is the right time to pick one and document it.** Recommendation: PostHog experiments (because PostHog already owns the user identity and event stream once D1 is fixed) for behavior experiments; Firebase RC for plain config rollouts (kill switches, threshold tuning).

---

## 17. Crashlytics + PostHog Overlap

**R1 — No overlap, because Crashlytics is not present.** `grep -rln "Crashlytics\|FirebaseCrashlytics"` returns 0 hits in product code. Firebase is integrated for Auth, Firestore, RemoteConfig — not Crashlytics. Combined with §11 L1, this means PostHog is the sole crash + error reporter, and crash *symbolication* will be poor.

**Recommendation:** add Crashlytics for crash + symbolication (it's free); keep PostHog for product errors and the `app_crash` ping event so cohort dashboards see crash incidence. Two systems is fine when each has a clear role.

---

## 18. Event Volume Estimate

Per-session event count, conservative count from a typical 90-second session that opens Home → views score → taps insight → returns to Home → backgrounds:

- `app_session_started` (1)
- `home_screen_viewed` (1)
- `home_section_viewed` × 5 sections (5)
- `score_viewed` (1)
- `home_recovery_card_block_tapped` (1)
- `recovery_info_screen_viewed` + sections (3-4)
- `home_headline_insight_block_tapped` (1)
- `insights_detail_screen_viewed` + sections (3-4)
- `insight_tapped` (1)
- `home_screen_exited` ×2, `recovery_info_screen_exited`, `insights_detail_screen_exited` (4)
- `core_action_completed` × 2 (2)
- `feature_discovered` (1, first time only)
- `app_session_ended` + `session_quality` (2)
- Auto-capture `$pageview` events: 0 (`captureScreenViews=false`) ✓
- Auto-capture lifecycle: `Application Opened`, `Application Backgrounded` (2)

Rough total: **~30 events / session** for a brief active session. A *deeply engaged* session (Live tab + breathwork + simulation + paywall) easily reaches **80-120 events**. Plus background events: `notification_scheduled`, `widget_snapshot_updated`, `data_sync_completed`, `data_pipeline_quality`, `background_refresh_result` — fire on cron, not user-driven; ~5-10/day per active user.

At 10k DAU × 50 events/session × 1.5 sessions/day × 30 days = **22.5M events/month**.
At 50k DAU × 60 events × 1.5 × 30 = **135M/month**.
PostHog Cloud paid tier starts at $0.000248/event after 1M free → **22.5M would cost ~$5,300/month**, **135M would cost ~$33k/month**.

**S1 [P1] — Cost projection is significant.** Mitigations:
- (a) Disable `section_viewed` events entirely (they fire on every section appear and provide marginal info beyond `screen_viewed` + scroll_depth). Easy 30-40% reduction.
- (b) Sample `chart_interaction` and `block_tapped` at 50% — cohort funnels survive.
- (c) Drop the 4 raw direct-PostHog events into the canonical pipeline so they're countable.
- (d) Self-host PostHog on EU infra → pure infra cost, no per-event surcharge. ~$300-800/mo for a single-node deployment that handles 50M events.
- (e) Alternative: send only "summary" events at session end (one event per session with all aggregates) for the ultra-frequent ones. Lossy but cheap.

---

## 19. Self-Host vs Cloud / Data Residency

- Host: `https://eu.i.posthog.com` confirmed in template default + `AppSecrets.swift:70`.
- Privacy policy URL: `https://lasohealth.fit/privacy` (`AppSecrets.swift:55`) — **content not in repo, cannot verify GDPR disclosure of PostHog by name + EU residency**.
- ToS: `https://lasohealth.fit/terms` — same.

**T1 [P0] — Pre-launch deliverable: confirm Privacy Policy text names PostHog explicitly, names the EU residency, names the data categories listed in the privacy manifest, and explains the user's GDPR rights including PostHog's GDPR deletion endpoint.** Without that, App Review (especially EU storefronts) will reject. This is the privacy-policy pair to the privacy-manifest fix in §2.

---

## 20. Test/Debug Events into Production Project

- `UITestMode.isEnabled` short-circuits `configure()` (`PostHogManager.swift:18`) — verified, good.
- `#if DEBUG` only adds `print(...)` for local debugging (`PostHogManager.swift:50,107`) — does not gate event sending.
- **There is no separate dev/staging PostHog project.** A single API key (`phc_bBp1...`) is used regardless of build configuration. So every developer's debug build, every TestFlight build, every CI simulator run that does *not* set `UITestMode` ships events to the production PostHog project.

**U1 [P1] — Pollute risk is real today.** Add a build-config check:

```swift
#if DEBUG
let apiKey = AppSecrets.PostHog.apiKeyDev   // separate project
#else
let apiKey = ... // prod
#endif
```

Or read `app_environment` super-property and filter on PostHog dashboards. Cleaner: separate project. Costs nothing on PostHog Cloud free tier.

**U2 [P3] — `UITestMode.isEnabled` returning early is correct, but the integration tests will then run against an SDK that's not configured. If any test asserts on captured events, those tests will silently no-op.** Already scoped to "no formal tests" per CLAUDE.md, but flagging.

---

## 21. Identity Reset on Uninstall + Reinstall

Already covered in §3. Without `identify(authUid)`:

- Uninstall → keychain typically retained → Firebase Auth UID restored on reinstall → same Firestore record.
- PostHog distinct_id (UUID stored in PostHog SDK's local storage / UserDefaults) is *lost* on uninstall → fresh anon ID → orphan profile.

This means **D7 retention numbers in PostHog will be systematically understated** because every uninstall/reinstall looks like a brand-new user. For a pre-launch app this is silent, but post-launch it becomes a real metric distortion (10-15% understated retention is normal in this failure mode).

**V1 [P1] — Wire `identify(Firebase Auth UID)` after the first `signInAnonymously` succeeds (`AppLaunchCoordinator.swift:27-33`).** Same fix as D1.

---

## Consolidated Findings Table

| # | Severity | Title | Where |
|---|---|---|---|
| A1 | P0 | Production PostHog key in committed Secrets.xcconfig | Secrets.xcconfig:5 |
| A2 | P2 | recordSessionsByDefault not explicitly false | PostHogManager.swift:21-43 |
| A3 | P1 | Lifecycle auto-capture sends device/locale before consent | PostHogManager.swift:22 |
| B1 | P0 | Session replay enabled on health app under "tracking=false" manifest | PostHogManager.swift:29 |
| B2 | P0 | Privacy manifest under-declares collected data types | PrivacyInfo.xcprivacy:9-23 |
| B3 | P0 | No consent gate, no opt-out, no NSUserTrackingUsageDescription, EU compliance broken | AppLaunchCoordinator.swift:39, Info.plist |
| B4 | P1 | Privacy policy must name PostHog + EU residency (out-of-repo) | AppSecrets.swift:55 |
| D1 | P1 | identify() never called → distinct_id never tied to Firebase UID | PostHogManager.swift:67 (only definition) |
| D2 | P1 | reset() never called — future logout will collide identities | grep returned 0 |
| D3 | P3 | Reinstall creates zombie identity (resolved by D1) | — |
| E1 | P2 | 4 events bypass AppAnalytics enrichment + sanitization | OnboardingConnectHealthStep.swift:70, OnboardingMirrorMomentStep.swift:320,330, ProFeatureOverlay.swift:50 |
| F1 | P1 | No onboarding step_started events — funnel math broken | OnboardingView.swift:111 |
| F2 | P2 | onboarding_drop_off lost on force-quit | OnboardingView.swift:121-130 |
| F3 | P3 | step_completed fires before HK auth resolves | OnboardingConnectHealthStep.swift:67-75 |
| G1 | P1 | trial_started may double-fire on cold-start race | AppAnalytics.swift:1217-1219 |
| G2 | P0 | referral_code shipped raw — joinable PII across users | AppAnalytics.swift:2245-2257 |
| H1 | P3 | first_journal_entry / first_workout_completed milestones missing | AppAnalytics.swift:540-553 |
| I1 | P2 | Strain/BrainHealth/Vitality/Cycle/WeeklyReview lack action verbs | various |
| I2 | P3 | WebExport has no opened event | WebExportViewModel.swift:46 |
| J1 | P3 | push_received N/A (no remote push) | — |
| K1 | P2 | health_permission_result aggregates by count, not by HK type | AppAnalytics.swift:1808 |
| K2 | — | metric_preview correctly anonymized | AppAnalytics.swift:1801 — verified safe |
| L1 | P1 | PostHog is sole crash reporter — no symbolication, no Crashlytics | PostHogManager.swift:130-165 |
| L2 | P2 | app_error_recorded bypasses canonicalization/enrichment | PostHogManager.swift:96, 110 |
| L3 | P3 | calibration_failed leaks raw error_message | OnboardingMirrorMomentStep.swift:320 |
| M1 | P3 | No posthog.register super-properties | AppAnalytics.swift:3109+ |
| M2 | P3 | Missing has_premium / app_environment / tracker_version super-props | — |
| N1 | OK | Metric anonymization is a real strength | AppAnalytics.swift:2899-2918 |
| N2 | P2 | notification_id leaks metric names un-anonymized | AppAnalytics.swift:1573 |
| O1 | P0 | Disable session replay for v1 | PostHogManager.swift:29 |
| O2 | P1 | postHogMask discipline is brittle for SwiftUI Text values | 30+ files |
| P1 | P1 | PostHog Feature Flags unused — pick one truth source | grep returned 0 |
| P2 | P2 | Two-flag-system risk for the future | — |
| Q1 | P2 | A/B framework not chosen pre-launch | — |
| R1 | — | No Crashlytics — recommend adding | — |
| S1 | P1 | Event volume / cost projection 22M-135M/mo | — |
| T1 | P0 | Privacy policy must declare PostHog + EU residency | AppSecrets.swift:55 |
| U1 | P1 | Single PostHog project for dev + prod → pollution risk | PostHogManager.swift:21 |
| V1 | P1 | identify(authUid) missing — same as D1 | AppLaunchCoordinator.swift:27-33 |

**P0 (launch blockers): A1, B1, B2, B3, G2, O1, T1.**

**P1 (high — fix before scale): A3, B4, D1, D2, F1, G1, L1, O2, P1, S1, U1, V1.**

---

## Confidence per finding

| Finding | Confidence | Verified by |
|---|---|---|
| A1 hardcoded prod key | 100/100 | direct cat of `Secrets.xcconfig:5` |
| B1 session replay on | 100/100 | direct read of `PostHogManager.swift:29` |
| B2 manifest under-declares | 95/100 — Apple's Tracking definition is debatable; under-declaration of CollectedDataTypes is firm | read of PrivacyInfo.xcprivacy + AppAnalytics.swift:381-435 |
| B3 no consent gate | 100/100 | grep `optOut\|optIn\|isOptedOut` returns 0; AppLaunchCoordinator unconditional |
| D1 identify never called | 100/100 | grep `\.identify\(` returns only the definition |
| D2 reset never called | 100/100 | grep `\.reset()` returns 0 product hits |
| E1 raw direct-PostHog calls | 100/100 | 4 sites enumerated by grep |
| F1 no step_started | 100/100 | OnboardingView.swift fully read |
| G1 trial_started double-fire | 80/100 — depends on StoreKit state-loading order at launch; logic-traced but not runtime-reproduced | AppAnalytics.swift:1217-1219 |
| G2 referral code PII | 100/100 | direct read of AppAnalytics.swift:2245-2257 + ReferralManager |
| L1 sole crash reporter | 100/100 | grep `Crashlytics` returns 0 |
| O1 session replay disable | 100/100 — recommendation; risk is high but ultimate decision is product+legal | — |
| P1 no PostHog feature flags | 100/100 | grep returns 0 |
| S1 event volume | 60/100 — estimate based on per-session walkthrough; not runtime-measured | logical projection |
| U1 single project for dev+prod | 100/100 | direct read of `Secrets.xcconfig` + lack of build-config branching in PHConfig |
| V1 identify on Firebase UID | 100/100 | same evidence as D1, paired with AppLaunchCoordinator.swift:27-33 |

Confidence: 88/100 — every code path was read first-hand and every grep result enumerated; the unverified weak link is the runtime cost projection in S1 (estimated, not measured) and the runtime ordering of StoreKit status loading in G1 (logic-traced, not reproduced). Apple's "tracking" definition in B2 is a known gray zone — the under-declaration of `NSPrivacyCollectedDataTypes` is firm but the `NSPrivacyTracking=false` claim itself could be defended by a privacy lawyer; nevertheless the manifest as written is misleading and a P0 review risk.
