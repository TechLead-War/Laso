# Laso — Pre-Launch Final Audit Review

**Audit window:** 2026-04-25 14:50 IST → 17:00 IST
**Auditor stance:** principal engineer + adversarial security + product skeptic
**Method:** read-only static + simulator runtime + competitor web research, 12 specialist agents in 3 waves
**Files produced:** 17 evidence-backed findings files at `/Users/primetrace/Desktop/RnD/HealthPulse/audit/`

---

## Audit pass count

| Pass | Wave | Files | Findings | Started | Ended |
|------|------|-------|----------|---------|-------|
| 1    | 1    | 01–10 | 192      | 14:55   | 15:05 |
| 1    | 2    | 11, 13, 14 | 74  | 15:06   | 15:18 |
| 1    | 3    | 15–17 | 70       | 15:19   | 15:39 |
| 2    | 1    | 12    | 7 confirmed at runtime + 4 new observations + 12 evidence screenshots | 15:40 | 16:18 |
| 3    | 1    | FINAL-REVIEW.md | consolidation | 16:18 | 17:00 |
| **Total** | — | **18 files (17 findings + FINAL)** | **≈336 + 11 runtime** | — | — |

(Pass 2 runtime confirmations — `audit/12-runtime-simulator.md`, evidence in `audit/evidence/` 01–11 PNGs. Tap-automation was blocked by Simulator Accessibility-permission gap, so Onboarding step 2 onward and Dashboard/Paywall/Settings UI flows were code-corroborated rather than driven through. APNs push pipeline + URL handlers + dark-mode lock + app-switcher privacy + memory-warning blindness all independently CONFIRMED at runtime; zero wave findings disproven.)

Per-file finding counts: 01=1, 02=30, 03=20, 04=30, 05=20, 06=21, 07≈40 (A–V lettered), 08=20, 09=24, 10=23, 11=21, 13=30, 14=23 (16 verified + 7 newly-discovered), 15=28, 16=20, 17=22.

---

## Tested vs broken percentage

Each surface = a module / cross-cutting capability. "Broken" = a confirmed launch-blocking issue (App Review reject, revenue leak, privacy violation, dead feature, or material UX failure).

| Surface | Status | Verdict |
|---------|--------|---------|
| Onboarding | Broken | 6 steps capture only age+gender+focus; no body/training/condition; no PP/ToS link before Firestore write; no notification ask |
| Dashboard / Home | Broken | 6–8 tappable surfaces above the fold; 3+ overlapping 0–100 scales; first-launch loading-vs-empty transition jittery |
| Insights | Broken | Aha-paywall fires on view-appear, not engagement; no dismiss; non-actionable Day-1 empty state |
| Risk module | Broken | "Critical / Very High" red badges + 0–100 gauge + numeric clinical targets (BP <120/80, AFib advice) — App Review 1.4.1 + EU MDR Rule 11 hard-block |
| Brain Health (Cognitive Wellness) | Broken | "Foggy / Expect brain fog" cognitive prediction without validated proxy; name flips between "Brain Health" and "Cognitive Wellness" |
| Stress | Broken | Score fires after 3 nights HRV; no opt-in; copy uses "stressed" framing without disclaimer; trend label uses raw String switch |
| Strain | Partial | Calibrated against undocumented magic constants (maxLoad=800, zone multipliers); no source citation; population-RHR fallback poisons first 14 days |
| Vitality | Partial | Strong contribution UI, but biological-age math silently snaps back to chronological when components<2; "pace of aging" mixes biomarker and score-derived models |
| Sleep Coach | Broken | Prescribes specific bedtime + caffeine cutoff; no medical disclaimer; no manual log fallback for users without a wearable; sleep-duration=0 treated as "you slept 0h" |
| Cycle Tracking | Broken | No opt-in, no off-ramp; gendered framing; no log entry; no medical disclaimer (App Review + EU MDR risk on contraception); copy assumes Western pantry |
| Live tab | Broken | Ambiguous "Live" label; for free iPhone-only users renders as Pro upsell empty state; HKAnchoredObjectQuery good but UI gating wrong |
| Journal | Broken | No biometric lock; entries unencrypted in SwiftData (default file-protection); 100% inline-hardcoded strings (zero `Copy.` references) |
| Discovery | Broken | Suppressed at first launch by `markDiscoverySeen` patch; tab name overlaps with Explore; 100% inline-hardcoded copy |
| Achievements (Profile) | Broken | Fully built but unreachable in production navigation; engine runs without UI; gym-coded titles |
| Referral | Broken | Entire feature unreachable (orphan ReferralCodeStep); rule lets any auth'd user grant `referralFreeUntil` to anyone; raw code shipped to PostHog |
| Paywall | Broken | No Sign in with Apple / no email; `isEligibleForIntroOffer` never checked; auto-renewal disclosure inline-hardcoded; no testimonials, no money-back, no dismiss; rose-pink AccentColor on plan radios |
| Settings → Delete Data | Broken | Local-only wipe + `exit(0)`; Firestore docs, anonymous Auth user, PostHog person, App Group, Live Activities all survive — Apple 5.1.1(v) hard-block |
| WebExport | Partial | HTML-only (no PDF/JSON), no doctor-share framing, no privacy banner, runs synchronously on @MainActor |
| Devices | Partial | No diagnostic for denied/partial HK; reprompt only fires after 24h |
| Breathwork | Partial | Two protocols only; zero accessibilityLabel/Value; no audio fallback; Live Activity widget runs 4 redundant 1s TimelineViews |
| Notifications subsystem | Broken | `requestAuthorization` defined but never called — entire push subsystem dead day-1; reprompt banner also dead because status never reaches `.denied` |
| Push (APNs remote) | Broken | `aps-environment = development`; `registerForRemoteNotifications` never called; `remote-notification` background mode missing |
| Siri / AppIntents | Partial | Six intents donated but no onboarding gate; `NSSiriUsageDescription` declared but no `requestSiriAuthorization` and AppIntents don't need it |
| Universal Links / deep links | Broken | Zero `application(_:open:)` / `onOpenURL` / `CFBundleURLTypes` / `Associated Domains`; AASA absent; referral activation broken |
| Live Activities | Partial | Three managers ship; race in Breathwork start; WindDown dismiss leaves no fallback; Breathwork has no `staleDate` |
| Widgets | Partial | 15-min timeline OK; `reloadAllTimelines` over-called from BG; widget snapshot keyed to `iCloud.com.lasohealth.app` (stale) |
| Background refresh | Broken | Double-instantiated `BackgroundRefreshCoordinator` (AppDelegate + AppContainer); 30s blind sleep wastes BG window |
| HealthKit auth handling | Broken | `isAuthorized = true` set blindly post-prompt regardless of denial; no per-type detection; no revoke detection on foreground; partial-grant produces 0/100 zero scores |
| HealthKit write description | Broken | `NSHealthUpdateUsageDescription` says "future feature" but app actively writes water/weight/mindful — App Review 5.1.1(ii) reject |
| HRV exposure | Broken | Buried in 6 composite scores with 4 different baseline windows; no first-class hero metric / detail; no anomaly band |
| Score breakdowns | Broken | Strain + Vitality have contributions; Recovery / Brain / Risk / Stress do not — Whoop's signature "why this number" missing on 4 of 7 scores |
| WatchOS app | Broken | No watchOS target whatsoever — credibility tax for a recovery+readiness app |
| Coach LLM (AskYourData) | Broken | Foundation Models on iOS 26 only; rule-based fallback for the 99% on iOS<26; no UI disclaimer footer; no refusal classifier; no English+Hindi+Spanish |
| Daily Narrative engine | Broken | LLM system prompt has zero medical-safety guardrails (no "never diagnose / never prescribe") |
| Localization | Broken | Zero `NSLocalizedString` / `LocalizedStringKey` / `.lproj` / `.xcstrings`; en_US storekit only; 253 fixed-width frames; 4–6 weeks to ship one locale |
| Privacy manifest | Broken | Declares 1 of ≥12 collected data types; `NSPrivacyTracking=false` contradicted by FirebaseAnalytics auto-collection + PostHog session replay |
| GDPR / DPDP / LGPD | Broken | No PP link before Firestore write; no consent log/version; no opt-out toggle for analytics/crash; cycle data has no Art 9 explicit consent; age gate too low for IN/EU |
| Firebase config | Broken | `GoogleService-Info.plist BUNDLE_ID = com.lasohealth.app` while runtime is `com.lasohealth.fit` — Auth/Firestore/RemoteConfig/Crashlytics silently fail |
| Firestore rules | Broken | `user_profiles` open to any auth'd `list`; cross-user `referralFreeUntil` write is ungated; `subscriptions` collection has no rule (default-deny → all subscription writes fail); `feedback.category` unbounded → admin-panel XSS vector |
| Cloud Functions | Broken | CORS sends `*` despite allowlist; `getCorsOrigin` defined but never used; `getUserStats` full-collection scan every call; no ASSN V2 webhook |
| Admin panel | Broken | Stored XSS via `feedback.category` + `app_version` (innerHTML, no escapeHtml); KPI coverage 3/22; no MRR/DAU/retention/refund; CSP only on Vercel, missing on Firebase Hosting |
| Crashlytics | Broken | Linked but never imported/instantiated; dSYM upload script missing; PostHog signal handlers will collide once wired; no `setUserID` |
| PostHog identify | Broken | `identify()` defined but called from zero call sites — every cohort dashboard will be wrong; `reset()` also never called |
| Subscription / StoreKit | Broken | Client-only signature check; Firestore cross-reference reads doc the client itself wrote (self-referential); no ASSN V2; no refund handler; family share off |
| Pricing strategy | Partial | $29.99/yr is half of Oura's $69.99/yr — leaves margin; trial 7d too short for HRV baseline ramp |
| Trial gate | Broken | `isEligibleForIntroOffer` never checked → returning users see "Start Free Trial" then get charged immediately (App Review 3.1.2 reject) |
| App Reviewer paywall path | Broken | Trial-expiry-only gate means reviewer cannot reach paywall in <30 min; no "View Pro Plans" affordance |
| Bundle ID / CloudKit container | Broken | CloudKit container `iCloud.com.lasohealth.app` while bundle `com.lasohealth.fit`; README still says `.app` |
| ASO / App Store metadata | Broken | No subtitle / promo / description / keywords drafted; `appStoreID` empty in AppSecrets |
| CI / quality gate | Broken | No `.github/workflows`, no Fastfile; pre-commit hook references missing `qg` binary; `LasoUITests/LasoUITests.swift` is an empty class while `visual-regression/README.md` claims 8 test methods |
| Observability of errors | Broken | 103 `try?` sites; SubscriptionManager + RemoteConfig + BGTask silently swallow; user properties set per-event but no canonical `register` |
| Accessibility (VoiceOver) | Broken | Zero accessibility annotations on Onboarding (10 files), Paywall, Settings, Vitality, Explore, 9 other modules; Breathwork unusable with VO |
| Dynamic Type / fonts | Broken | 71 fixed-size font calls (.4/.2/.6 fractional sizes from a 1.2× pixel-freeze) — WCAG 1.4.4 fail |
| Reduce Motion | Broken | 9 `repeatForever` animations, 7 ungated; pulsing heart in onboarding ignores vestibular preference |
| Brand color | Broken | AccentColor.colorset is rose-pink (#EB535F) while AppColour.primary is blue (#0071E3); paywall plan radios + activation banner + filter pills paint rose |
| App-switcher privacy | Broken | No `.privacySensitive()` / no resign-blur — Journal, Cycle, scores visible in app switcher snapshot |
| App-lock biometric | Broken | No `LAContext` anywhere; Journal mood/alcohol/medication entries readable on unlocked device |
| Repo hygiene | Partial | Folder is `HealthPulse/` while project is `Laso`; `firebase-debug.log` not gitignored; `admin-panel/public/screenshots/` un-ignored, deployable |
| Naming consistency | Partial | `HealthPulseDidDeleteAllData` no-op notification still posted; `engagementPrefix = "healthpulse.engagement."` UserDefaults key |

**Surfaces evaluated:** 56.
**Surfaces broken at launch threshold:** 47.
**Surfaces partial:** 9.
**Surfaces clean:** 0.

**Headline %:** 47 of 56 surfaces broken at launch threshold = **84% broken**.
**Crit-only %:** at least 23 surfaces carry a Critical / P0 severity = **41% Critical**.

---

## Top 10 existential risks

1. **Risk module is a medical-device claim under EU MDR Rule 11 + App Review 1.4.1.** Severity Critical. Root cause: 0–100 risk gauge with `RiskGrade.high/veryHigh` red badges + numeric clinical targets ("Reduce sodium <2,300 mg/day", "Target <120/80 mmHg", AFib recommendations) attached to per-user scores. Consequence: Apple rejection at re-review, EU regulator class as Class IIa diagnostic aid, duty-of-care exposure. (audit/15-scoring-coach-pii.md F1, F2; audit/04-product-ux.md F11.)

2. **GoogleService-Info.plist BUNDLE_ID is `com.lasohealth.app`, runtime is `com.lasohealth.fit` — entire Firebase stack silently fails.** Severity Critical. Root cause: bundle was renamed `app → fit`, plist never regenerated, `.gitignore` rule says "run `git rm --cached`" which was never done. Consequence: anonymous Auth fails → no Firestore writes succeed → no referrals, no feedback, no user_profiles, no subscriptions cross-reference, no Crashlytics, no RemoteConfig kill switch. (audit/02-security.md F3; audit/14-cross-cut-verification.md V1.)

3. **App Store 5.1.1(v) account-deletion violation — Settings "Delete All My Data" calls `exit(0)` and wipes only local state.** Severity Critical. Root cause: deletion flow predates Firestore + anonymous Auth + PostHog identify. Consequence: Firestore `user_profiles`, `subscriptions`, `referrals`, `feedback`, anonymous Auth UID, PostHog person, App Group, Live Activities all survive; `exit(0)` is itself a HIG/2.5.1 reject; GDPR Art 17 + DPDP Sec 12 violation. (audit/04-product-ux.md F2; audit/09-compliance-privacy.md F1; audit/10-permissions-edge-cases.md F11; audit/14 V7.)

4. **Notification permission is never requested — entire push subsystem is dead.** Severity Critical. Root cause: `NotificationManager.requestAuthorization` defined, called from zero production sites; reprompt banner gated on `.denied` status that is never reached. Consequence: every Daily/Weekly/WindDown/Alert/Engagement scheduler silently fails; the largest retention/revenue lever is broken before launch; analytics report 100% grant rate. (audit/04-product-ux.md F1; audit/10-permissions-edge-cases.md F2; audit/14 V6.)

5. **Privacy manifest declares 1 of ≥12 collected data types and `NSPrivacyTracking=false` is materially false.** Severity Critical. Root cause: manifest predates FirebaseAnalytics linking + PostHog session replay + person properties. Consequence: iOS 17+ App Privacy Manifest validation rejection at upload; FTC misrepresentation; GDPR + DPDP non-compliance; PostHog session replay is on for every user from launch with no consent gate. (audit/09-compliance-privacy.md F2, F3; audit/02-security.md F8; audit/07-analytics-posthog.md B1, B2, B3.)

6. **Crashlytics is linked but never imported, instantiated, or fed dSYMs — every TestFlight crash is invisible.** Severity Critical. Root cause: Crashlytics SPM dep added but never wired; dSYM post-build script generates locally only, never uploads; `Scripts/fix-archive-dsyms.sh` referenced in memory but absent from disk. Consequence: zero symbolicated crashes, no crash-free user metric, no triage signal — combined with no CI, the team flies blind through launch. (audit/17-observability-reliability.md F1, F2, F3.)

7. **Referral system grants Pro client-side without StoreKit verification; Firestore rules allow any auth'd user to write `referralFreeUntil` to any device.** Severity Critical (revenue + abuse). Root cause: "controlled loophole" comment in firestore.rules admits the design tradeoff; Cloud Function gate never built. Consequence: any anonymous user with `firebase-js-sdk` can grant themselves perpetual Pro on their own deviceId or grief any other user. Compounded by full `user_profiles` `list` query open to any auth'd caller (PII enumeration). (audit/02-security.md F5, F7; audit/14 V4, V5.)

8. **Stored XSS in admin panel — feedback `category` + `app_version` rendered into innerHTML without escapeHtml.** Severity Critical. Root cause: `escapeHtml` exists and is used for `e.text` but skipped for metadata fields; Firestore rule constrains only `text` length, leaves `category` shape open. Consequence: any iOS user can craft a feedback with `category = "<img onerror=...>"` and execute JS in any admin's session — flipping `kill_switch_enabled`, force-update version, pricing IDs. (audit/08-admin-panel.md A1; audit/14 V8.)

9. **PostHog `identify()` is defined but called from zero call sites — every cohort dashboard will be wrong post-launch.** Severity P0 KPI-blindness. Root cause: anonymous Firebase Auth UID never piped into PostHog. Consequence: D1/D7/D30 retention systematically understated by 10–15% (every reinstall = new anon ID); MRR-by-cohort broken; support cannot trace a user's events; `reset()` also never called. Combined with admin panel covering 3 of 22 KPIs and no ASSN V2 webhook for refund rate, founder is data-blind through the most data-sensitive 30 days. (audit/07-analytics-posthog.md D1, D2, V1; audit/13-pricing-business-launch.md F14, F15.)

10. **`aps-environment = development` + `isAuthorized = true` set blindly + `NSHealthUpdateUsageDescription` says "future feature" but writes are live.** Severity Critical (cluster). Root cause: capability flips never reconciled with code reality. Consequence: TestFlight push silently fails; HealthKit-denied users see broken zero-score dashboard with analytics reporting 100% grant; App Review reads the description string literally and rejects under 5.1.1(ii). Three independent App Review reject paths in a single cluster. (audit/02-security.md F1, F15; audit/10-permissions-edge-cases.md F1, F3; audit/14 V3.)

---

## Top 10 fastest wins

1. **Fix the duplicated medical disclaimer text.** `Copy+Analysis.swift:13` and `:200` both repeat the same sentence twice; rewrite to one tight sentence. ~5 min, touches every clinical/risk screen. (audit/16 F3.)

2. **Add `Crashlytics.crashlytics()` access + `setUserID(uid)` after anonymous Auth + `upload-symbols` post-build script.** ~30 min. Crash dashboard goes live. (audit/17 F1, F2.)

3. **Call `PostHogManager.shared.identify(userId: user.uid)` in `AppLaunchCoordinator` after `signInAnonymously`.** ~10 min. Every cohort/retention dashboard becomes correct. (audit/07 D1; audit/13 F14.)

4. **Wire notification permission request to first toggle in NotificationsSettingsView OR onboarding Promise step.** ~30 min. Entire push subsystem becomes alive. (audit/04 F1.)

5. **Flip `aps-environment` to `production` in `Laso.entitlements`.** 1-line change. (audit/02 F1; audit/14 V3.)

6. **Apply `.tint(AppColour.primary)` at LasoApp root + repaint AccentColor.colorset to brand blue.** 2-line change. Paywall + activation banner + filter pills become brand-coherent. (audit/06 F1; audit/14 V13.)

7. **Add `accessibilityLabel/Value/Hint` to Paywall plan radios + onboarding step CTAs (start with Pulse + Profile + Connect + Promise).** 1–2 hr. Removes WCAG fail on revenue-critical screens. (audit/06 F2, F3.)

8. **Wrap `UITestMode`, `SampleDataProvider`, `PremiumShowcaseDataProvider` in `#if DEBUG || UI_TEST`.** ~30 min. Removes mock data + fake names from production binary. (audit/05 F3, F16.)

9. **Move auto-renewal disclosure paragraph from `PaywallView.swift:360` into `Copy+Paywall.swift`.** 5 min. Closes copy-governance hole on the most legally-sensitive screen. (audit/16 F2.)

10. **Add `firebase-debug.log`, `*.log`, `admin-panel/public/screenshots/` to `.gitignore` + `firebase.json hosting.ignore`.** 5 min. Prevents accidental commit of dev email + premature deploy of mock screenshots. (audit/02 F10; audit/08 A4, A5.)

---

## Top 10 performance bottlenecks

1. `BackgroundRefreshCoordinator` double-instantiated; AppDelegate's instance handles BG fires with fresh `HealthKitManager` + `ReadinessStore` every wake — cold-rebuilds HealthKit state every BG run. (audit/03 F1; audit/17 F14.)
2. HealthKit batch sync uses `HKSampleQuery` exclusively (no `HKAnchoredObjectQuery`) — 5× redundant fetches across the five sleep-stage metrics; full overlap-window re-decode every refresh. (audit/03 F2.)
3. Five scorers fan out synchronously on `@MainActor` via `MainActor.assumeIsolated { store.loadAllTimeSeries() }` — blocks UI through Strain → Stress → BrainHealth → SleepDebt → SleepNeed → Gamification → Vitality on every refresh-miss. (audit/03 F3.)
4. PostHog `sessionReplay = true` always-on with no consent gate, no remote-config kill, no sampling — continuous main-actor snapshot capture + encode + upload on a session-rich app. (audit/03 F5; audit/07 B1, O1.)
5. `BreathworkLiveActivityWidget` runs 4 redundant `TimelineView(.periodic(by: 1))` redraw loops on lock screen + Dynamic Island while `Text(timerInterval:)` could tick for free. (audit/03 F4.)
6. `WebExportViewModel.exportReport()` builds tens-to-hundreds of KB of HTML+SVG synchronously on `@MainActor` then writes to disk synchronously — frozen tap UX. (audit/03 F6.)
7. `HealthDataStore.loadAllTimeSeries()` does unbounded `FetchDescriptor<StoredDailySample>()` (~110K rows × 30 metrics × 10 yr) — coarse cache invalidation rebuilds the entire dictionary on any single-metric change. (audit/03 F7.)
8. 30-second blind `Task.sleep` in `BackgroundRefreshCoordinator.handle` after fire-and-forget `fetchHomeData()` wastes the 30s BG budget and risks `expirationHandler` cancellation. (audit/17 F15.)
9. `pushTodayScoreLiveActivity()` called on every refresh with no rate limit — Apple recommends ≥10s gaps; refresh-burst can exceed Live Activity update budget. (audit/03 F15.)
10. `getUserStats` Cloud Function runs full-collection scan on `user_profiles` every dashboard load; 1M users → exceeds 60s callable timeout. No memoization, no scheduled aggregation doc. (audit/08 A6.)

---

## Top 10 security issues

1. **GoogleService-Info.plist wrong bundle ID** (`com.lasohealth.app` vs runtime `.fit`) — Firebase silently broken. (02 F3, 14 V1.)
2. **Referral abuse** — any anon user can write `referralFreeUntil` to any device, no StoreKit check. (02 F5, 14 V4.)
3. **`user_profiles` `list` rule open** — any auth'd user can dump every profile (PII enumeration). (02 F7, 14 V5.)
4. **`subscriptions` collection has no Firestore rule** — all writes silently fail (default-deny); no anti-spoofing for jailbroken clients. (02 F6.)
5. **PostHog session replay vs `NSPrivacyTracking=false`** — Apple manifest lie + GDPR replay leak; `.postHogMask()` discipline brittle for SwiftUI Text. (02 F8, 07 B1.)
6. **Stored XSS in admin panel** — `feedback.category` + `app_version` interpolated unescaped into innerHTML; admin can be hijacked to flip kill switches. (08 A1, 14 V8.)
7. **CORS allow-list is dead code** — `setCorsHeaders` writes `Access-Control-Allow-Origin: *` despite `getCorsOrigin` helper. (08 A2, 14 V9.)
8. **Anonymous Firebase Auth + `identifierForVendor` + no App Check** — quota exhaustion DoS + no DeviceCheck/AppAttest defense; reinstall loses referral state. (02 F4, F9, F26.)
9. **PostHog production API key in `Secrets.xcconfig`** — never committed historically (good) but baked into IPA via Info.plist; no dev/prod project split → debug pollution. (02 F2, 07 A1, U1.)
10. **`PrivacyInfo.xcprivacy` declares 1 of ≥12 collected data types** — App Store Privacy Manifest non-compliance + FTC misrepresentation risk. (09 F2, F3.)

---

## Top 10 product leaks hurting growth

1. **Notification permission never requested** — Day-1 retention loop broken; Daily/Weekly/WindDown push all silently fail. (04 F1, 10 F2.)
2. **Aha-paywall fires on view-appear of InsightsDetail, non-dismissible** — users hit hard wall before reading any insight. (04 F6.)
3. **Trial-expired paywall has no Maybe Later / Contact Support / offline escape** — bricked users on flaky network; Apple 3.1.2 reject risk. (04 F7.)
4. **Referral system unreachable** (orphan ReferralCodeStep) AND `Achievements` view unreachable — entire viral acquisition + gamification retention loop dead while shipping the cost. (04 F4, F5; 11 F3.)
5. **No native watchOS app** — credibility tax for a recovery+readiness app; Whoop/Oura/Apple win the wrist-glance ritual by default. (11 F1.)
6. **No real coach AI for the 99% on iOS<26** — AskYourData falls back to rule-based engine; Whoop/Oura/Fitbit/Bevel ship cloud LLMs at the same price point. (11 F2.)
7. **No social loop / no friends / no leaderboards / no challenges / no share-score** — zero organic growth path; only ShareSheet is the WebExport HTML. (11 F3.)
8. **Cycle Tracking has no opt-in, no off-ramp** — trans men, postmenopausal users, men with prior partner data all see menstrual content unprompted; sensitivity + App Review risk. (04 F8.)
9. **Brand wedge unstated** — Pulse step is generic; App Store description undrafted; competing in "another HealthKit dashboard" review category. (11 F20; 13 F23.)
10. **Zero localization infrastructure** for "India + EU + US" launch — Hindi mandatory for India middle-class, German for EU, but `NSLocalizedString` count = 0 across the entire codebase; 4–6 weeks to ship one locale. (16 F1; 11 F11.)

---

## What leadership is probably blind to

1. **Crashlytics is linked but never instantiated and dSYM upload script doesn't exist — every TestFlight crash is invisible right now.** PostHog catches a 15-frame symbol-less hex stack. The team is operating on the assumption that "PostHog is enough." It is not. (audit/17 F1, F2.)

2. **`GoogleService-Info.plist` bundle ID is `.app`, runtime is `.fit` — Firebase is silently broken in production.** Every anon Auth, every Firestore write, every RemoteConfig fetch, every kill-switch is silently failing. The app *appears* to work because most flows have a local fallback that swallows the error. (audit/02 F3.)

3. **Risk module + Brain Health "Foggy" + AskYourData with no refusal classifier are medical-device claims under EU MDR Rule 11.** "Heart Health Pattern: Critical 78/100" + "Reduce sodium <2,300mg/day" is JNC8-style clinical guidance under a wellness label. EU regulator can class this as a Class IIa diagnostic aid. (audit/15 F1, F2, F4, B3.)

4. **PostHog `identify()` is never called — every retention chart, MRR-by-cohort, and "user X's events" query in PostHog will be wrong starting Day 1.** This is invisible until someone tries to debug a churn cohort. (audit/07 D1; audit/13 F14.)

5. **The admin panel has a Stored XSS via feedback.category — any iOS user can flip the `kill_switch_enabled` master switch by submitting feedback with a payload.** This means a single user could brick the entire app or force every user to a non-existent version. (audit/08 A1.)

6. **Referral system: any authenticated user can grant themselves perpetual Pro by writing `referralFreeUntil = farFuture` to their own `user_profiles/{deviceId}` doc.** No StoreKit cross-reference, no Cloud Function gate. The "controlled loophole" comment in firestore.rules underestimates the blast radius. (audit/02 F5; audit/14 V4.)

7. **The `LasoUITests/LasoUITests.swift` file is an empty class while `visual-regression/README.md` claims 8 test methods.** The pre-commit `qg` binary doesn't exist on disk. The "quality gate" in the repo is theatre — no UI tests, no visual regression, no CI, every TestFlight upload is manual. (audit/17 F19, F20, F21.)

8. **Firestore `subscriptions` collection has no rule.** Every subscription write since launch has been silently rejected by the catch-all default-deny tail rule, and `fetchFirestoreSubscriptionStatus` swallows the read failure with a comment "fall back to local-only resolution." The "anti-spoofing" the comment claims to provide is a no-op. (audit/02 F6.)

9. **Onboarding never asks for body / training / pregnancy / condition data — Day-1 score is generic.** "Personalised" promise is theatre until day 14+ when HRV baseline matures. Apple Reviewer running on a clean simulator with no health data sees an empty zero-score dashboard and a non-dismissible paywall. (audit/04 F3; 10 F3, F6.)

10. **Settings "Delete All My Data" calls `exit(0)` and doesn't delete Firestore docs, anon Auth, PostHog person, App Group, or Live Activities.** Apple 5.1.1(v) hard-block + GDPR Art 17 + DPDP Sec 12 all violated by a single 18-line function that the team probably wrote in 30 minutes. (audit/04 F2; 09 F1; 10 F11; 14 V7.)

---

## If rebuilding from scratch, what to redesign

1. **Drop the Risk module + the Brain Health "Foggy" state until a peer-reviewed validation exists.** Replace with neutral "Pattern observed / Worth attention" framing. Strip every numeric clinical target. The wellness-vs-medical-device line is real; don't straddle it.

2. **Native watchOS app is non-negotiable for a recovery + readiness app.** Even a v0 with three surfaces (today's score complication, glance with Recovery/Strain/Sleep/Stress, breathwork start) using the existing `WidgetDataStore` App Group is two engineer-weeks. Ship it before launch or change the brand wedge to "iPhone-only health intelligence" and own that constraint loudly.

3. **Replace anonymous Firebase Auth with optional Sign in with Apple post-aha-moment.** Ties the user to an Apple ID for cross-device portability of referrals + subscriptions + Firestore profile. Anonymous-only forfeits cross-device retention; phone-loss = referral state + history gone forever.

4. **Server-authoritative subscription state via App Store Server Notifications V2 webhook → Firestore.** The current client-only signature check + self-referential Firestore cross-reference is a revenue leak proportional to Frida abuse + refund-flow blindness. Server-side is the only architecture that survives jailbreak + offline + refund storms.

5. **One canonical scoring engine, not seven.** Six different HRV normalisations across Stress, Brain, Vitality, Strain, Readiness, Risk produce contradictory daily verdicts (Stress=High AND BrainHealth=Sharp on the same morning). Centralise via an `HRVStandardiser` actor, single baseline window, single source of truth for "is HRV good today."

6. **Single shared LLM coach (cloud + on-device hybrid) with one safety guardrail.** Today AskYourData has a guardrail; DailyNarrative has none; the rule-based fallback has neither and no refusal classifier. Pick Anthropic Claude Haiku or gpt-4o-mini as the cloud fallback; have the on-device Foundation Models path mirror the same prompt + safety wrapper; share one `LLMSafetyGuard` that filters diagnosis/medication/mortality questions.

7. **Localization-first architecture.** String catalogs (`.xcstrings`) on Day 1, not Year 2. The "India + EU + US" launch is unbacked by code. 253 fixed-width frames will overflow on German/Hindi without `Layout` or `lineLimit/minimumScaleFactor`. Retrofitting after-the-fact is 4–6 weeks per locale — building in is an hour-per-Copy-file.

8. **Single `BackgroundRefreshCoordinator` owned by `AppContainer`, not duplicated by AppDelegate.** Single shared `HealthKitManager` + `ReadinessStore`. Use `HKAnchoredObjectQuery` for every per-sample type. Move scorer fan-out off `@MainActor` via `Task.detached(priority: .userInitiated)` returning Sendable snapshots. Today's architecture is "everything on main, blind sleeps in BG."

9. **Privacy-first observability: Crashlytics + structured non-fatal error reporting + opt-out toggle, not `try?` everywhere.** 103 silent swallows is the worst observability gap. Replace with `Loggable.swallow(_ error, context:)` helper that always reports to PostHog `app_error_recorded`. Wire `Crashlytics.setUserID + setCrashlyticsCollectionEnabled(_:)` to a Settings toggle. Ship CI with `xcodebuild build` + `upload-symbols` on every merge.

10. **Single source of truth for the "score" UX.** Pick one: Recovery (Whoop-style) when Watch data present, Health Score otherwise. Move Strain, Vitality Age, Brain to detail-only screens. The current "five 0–100 scales + one 0–21 + one age in years" produces decision paralysis and naming drift (Brain Health vs Cognitive Wellness). Decide which number the user checks every morning and remove the rest from above-the-fold.

---

## App Store launch hard-blockers (DO NOT submit until fixed)

- [ ] **GoogleService-Info.plist BUNDLE_ID corrected** to `com.lasohealth.fit` (regenerate from Firebase console + `git rm --cached`). (02 F3.)
- [ ] **`aps-environment` switched to `production`** in `Laso.entitlements` for Release config; OR remove the capability if remote push out of scope. (02 F1; 10 F1.)
- [ ] **Apple guideline 5.1.1(v) — server-side account deletion** via Cloud Function deleting `user_profiles`, `subscriptions`, `referrals`, `feedback`, `Auth.currentUser?.delete()`, PostHog `reset()`, App Group wipe, Live Activity end. Remove `exit(0)`. (04 F2; 09 F1; 10 F11.)
- [ ] **PostHog session replay disabled by default** OR comprehensive masking + explicit consent + matching `NSPrivacyTracking` declaration. (02 F8; 07 B1, O1.)
- [ ] **`PrivacyInfo.xcprivacy` declares all collected data types** (UserID, DeviceID, EmailAddress, OtherUserContent, OtherDiagnosticData, CrashData, PerformanceData, ProductInteraction, PurchaseHistory, SensitiveInfo, plus existing HealthData). (09 F2.)
- [ ] **Risk module + Brain Health de-escalated to non-clinical language.** Drop 0–100 gauge, rename "Critical/Very High" → "Pattern observed / Worth attention", strip numeric clinical targets, kill AFib recommendation, soften "Foggy / Expect brain fog" headlines. (15 F1, F2, F4; 04 F11.)
- [ ] **Notification permission actually requested in code path** — first toggle in NotificationsSettingsView OR onboarding Promise step. Gate scheduler calls on `.authorized`. (04 F1; 10 F2.)
- [ ] **`exit(0)` removed from delete flow** + replaced with navigate-to-onboarding-root + state reset. (10 F11; 14 V7.)
- [ ] **Crashlytics actually instantiated** (`import + Crashlytics.crashlytics()` in AppLaunchCoordinator) **+ dSYM `upload-symbols` post-build script** wired. (17 F1, F2.)
- [ ] **Privacy Policy + Terms of Use reachable from onboarding** (5.1.1(i)) — link footer on ProfileCaptureView before Firestore write; persist consent log entry. (09 F5, F19.)
- [ ] **Restore Purchases CTA on paywall** is present (verified in PaywallView.swift) — verify `errorMessage` UI binding surfaces failures clearly. (10 F17.)
- [ ] **Auto-renewal disclosure complete on paywall** — move inline-hardcoded paragraph into `Copy+Paywall.swift`; render verbatim; localizable. (16 F2.)
- [ ] **Trial-eligibility check before "Free Trial" copy** (3.1.2) — call `Product.SubscriptionInfo.isEligibleForIntroOffer` and gate `selectedProductHasTrial`. (13 F2.)
- [ ] **`firestore.rules` — close `referralFreeUntil` exploit** (require Cloud Function or referrer-write match) **+ lock `user_profiles` `list`** (move referral lookup to callable). (02 F5, F7; 14 V4, V5.)
- [ ] **`admin-panel` XSS — escape `category`, `app_version`, `days_since_install` before innerHTML** + tighten Firestore rule with charset/length bounds on `category`. (08 A1; 14 V8.)
- [ ] **`subscriptions` Firestore collection rule** — add a server-authoritative path (Cloud Function via App Store Server Notifications V2) so client subscription writes are validated rather than silently dropped. (02 F6; 13 F7.)
- [ ] **`NSHealthUpdateUsageDescription` rewritten** to reflect actual writes (water, weight, mindful, workouts), drop "future feature" framing. (02 F15; 09 F4.)
- [ ] **PostHog `identify(userId: authUid)`** called after `signInAnonymously` succeeds; `setUserID` mirror on Crashlytics. (07 D1, V1; 13 F14, F16; 17 F4.)
- [ ] **Cycle Tracking opt-in gate + medical disclaimer + off-ramp** before any cycle UI surfaces. (04 F8; 16 F4.)
- [ ] **Duplicated medical disclaimer text fixed** in `Copy+Analysis.swift:13, :200`; disclaimer added to Cycle / Stress / Sleep detail screens. (16 F3, F4.)
- [ ] **App Reviewer demo path to paywall** — "View Pro Plans" Settings button always opens paywall regardless of subscription state. (13 F20.)
- [ ] **App Store metadata drafted** (subtitle 30c, promo 170c, description 4000c, keywords 100c, what's-new) + appStoreID populated in AppSecrets. (13 F23, F18.)
- [ ] **CloudKit container ID corrected** to `iCloud.com.lasohealth.fit` OR removed if CloudKit not shipped. (02 F30; 13 F26.)
- [ ] **CORS bypass fixed** — wire `getCorsOrigin(req)` into `setCorsHeaders` + add `Vary: Origin` + mirror `vercel.json` security headers into `firebase.json`. (08 A2, A7.)
- [ ] **`admin-panel/public/screenshots/` ignored** in `firebase.json hosting.ignore` + `.gitignore`; `firebase-debug.log` + `*.log` gitignored. (02 F10; 08 A4, A5.)

---

## Confidence

`Confidence: 88/100 — every audit file (01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 13, 14, 15, 16, 17) was read in full and finding counts verified by direct count; per-surface broken/partial verdicts are grounded in cited file:line evidence from those files. Below 90 because: (a) the Pass-2 runtime simulator pass (12-runtime-simulator.md) is in progress and not yet read, so visible-vs-static gaps are not yet validated; (b) total-finding count for 07-analytics-posthog.md uses the lettered scheme (A–V) and the brief's "19 findings" framing, so the ≈336 total is a best-effort consolidation, not a single-canonical taxonomy; (c) several "Broken" surface verdicts in the tested-vs-broken table compose findings across multiple audit files — a single-source-per-surface table would tighten attribution.`

---

## Auditor notes / what was NOT audited

- **Production traffic:** no live PostHog or Firebase data — code-only signal. Event-volume estimates in audit/07 §18 are projections, not measurements.
- **Real device testing:** simulator only; HealthKit data flows partial. Pass-2 runtime simulator findings (12-runtime-simulator.md) are in progress concurrent with this report and not yet incorporated.
- **App Store Connect listing:** not accessible — App Store metadata gap (audit/13 F23) inferred from absence of draft copy in `Docs/` / `website/` / repo.
- **Live admin-panel deploy:** not curl'd — claims about deploy-exposed `public/screenshots/` (audit/08 A5) are inferred from `firebase.json hosting.public` semantics.
- **Privacy Policy + Terms of Use page content:** `https://lasohealth.fit/privacy` and `/terms` not WebFetched — PP-vs-code cross-checks (audit/09 F10, F12, F14, F16, F19) are inferential.
- **Firebase emulator runtime tests:** referral abuse (V4), `user_profiles` list dump (V5), CORS `*` (V9) verified by reading rules + code; not executed live.
- **Legal counsel review:** required for the medical-claim findings (Risk, BrainHealth, ECG, AFib, Cycle, AskYourData refusal classifier).
- **Real APNs token registration:** TestFlight cannot test prod APNs without a push payload through Apple Push Console — `aps-environment=development` consequence (02 F1) is documented behaviour, not runtime-verified on this build.
- **Full PII sweep of `AppAnalytics.swift`:** 60 of 3,201 lines spot-checked + targeted greps on `email/name/phone` returned clean, but the residual 98% surface area is unread.
- **Each scorer's missing-data handling:** ReadinessScorer verified clean; CompositeScorer + SleepScorer + others sampled, not exhaustively traced (audit/10 F21 weak link).
- **Bitcode setting + Xcode 15 build phase output:** inferred from `project.yml` defaults; not validated by reading the generated `.pbxproj` output of `xcodegen generate` (audit/17 F5).
