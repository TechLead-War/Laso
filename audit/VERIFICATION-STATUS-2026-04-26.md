# Verification Status — 2026-04-26

**Method:** 27 parallel read-only agents, one per audit file, cross-referencing each finding against current working-tree (HEAD + uncommitted) + `PASS5-FIX-LOG.md` claims.

**Status legend:**
- ✅ **RESOLVED** — fix verified in current code
- ❌ **OPEN** — bad pattern still present in working tree
- ⏳ **NEEDS-RUNTIME** — needs built-app / device / external system to verify
- ✳️ **PARTIAL** — partly fixed, gap remains
- 🟢 **PASS** — finding never applied (clean by default)

---

## Headline Tally

| Bucket | Count | % |
|---|---|---|
| RESOLVED | ~68 | ~10% |
| OPEN | ~474 | ~74% |
| NEEDS-RUNTIME | ~98 | ~15% |
| PASS / Informational | ~3 | ~1% |
| **TOTAL** | **~643** | **100%** |

> The earlier `PROGRESS.md` claim of "709 findings, 694 done, 15 left" was **not accurate**. After per-finding grep verification + 60-sample audit-claim spot-check, only ~10% of findings are actually fixed; ~74% are still present despite `PASS5-FIX-LOG.md` claiming many were resolved. The original 27-agent pass had **~17-20% false-RESOLVED rate** — items audited as fixed but bad pattern still in current code (e.g., AccentColor still rose-pink, CloudKit container still `.app`, `interruptionLevel` not added, `signInAnonymously` still callback, `excludedActivityTypes` absent, `privacySensitive` not in Journal, multi-device onboarding flag absent, remote-notification BG mode absent, body redaction absent, `fatalError` calls still present). 11 such items were flipped from RESOLVED→OPEN below; one O→R recovery: SIWA actually wired in `OnboardingPromiseStep.swift:60` + `Core/Auth/AppleAuthService.swift`.

## Audit-Claim Spot-Check Results

Two 30-sample passes were run against current working tree:

| Sample | Result |
|---|---|
| 30 RESOLVED claims | 25/30 confirmed fixed (5 actually still OPEN) |
| 30 OPEN claims | 29/30 confirmed open (1 actually fixed — SIWA) |
| 30 mixed random | 23/30 audit matched truth (6 R-claimed but actually O, 1 grep noise) |

Net inflation rate on RESOLVED bucket: ~17-20%.

---

## 01-naming-disturbance.md

| ID | Status | Evidence | Note |
|---|---|---|---|
| F1 | ❌ OPEN | repo folder still `HealthPulse/` | Source code clean of name; only filesystem rename pending |

**Subtotal:** 1 total · 0 R · 1 O · 0 NR

---

## 02-security.md

| ID | Status | Evidence | Note |
|---|---|---|---|
| F1 | ✅ RESOLVED | `Laso.entitlements:6` = `production` | APNs entitlement fixed |
| F2 | ❌ OPEN | `Secrets.xcconfig:5` live PostHog key present | Key not rotated |
| F3 | ✅ RESOLVED | `GoogleService-Info.plist:12` = `com.lasohealth.fit` | Bundle id matches runtime |
| F4 | ❌ OPEN | only `signInAnonymously` in `AppLaunchCoordinator.swift:28` | No SIWA |
| F5 | ❌ OPEN | `ReferralManager.swift:215-271` client grant intact | Move to Cloud Function pending |
| F6 | ✅ RESOLVED | `firestore.rules:86-90` subscriptions rule added | |
| F7 | ✅ RESOLVED | `firestore.rules:74` list = admin only | Needs callable Cloud Function for client |
| F8 | ❌ OPEN | `PrivacyInfo.xcprivacy:5-6` Tracking=false + `PostHogManager:29` sessionReplay=true | Manifest contradicts |
| F9 | ❌ OPEN | App Check not added to `project.yml` | |
| F10 | ✅ RESOLVED | `admin-panel/.gitignore` created | |
| F11 | ❌ OPEN | `AppIntegrityGuard.swift:16-37` returns nil | Dead detection |
| F12 | ❌ OPEN | `functions/index.js:92` CORS = `*`, `getCorsOrigin` unused | |
| F13 | ❌ OPEN | no privacy blur in `AppDelegate.swift` | |
| F14 | ❌ OPEN | no `LAContext` anywhere | No biometric lock |
| F15 | ❌ OPEN | `Info.plist:31-32` still says "future feature" | App actively writes HealthKit |
| F16-F19 | ❌ OPEN | EncryptedStore, MorningCheckIn, JournalStore, PostHog crash handler | |
| F20 | ❌ OPEN | UITestMode launch flag in production binary | |
| F21-F23 | ❌ OPEN | feedback rule, early_access rule, firebase-adminsdk.sample.json | |
| F24 | ✅ RESOLVED | `firestore.rules:28` early_access read = admin | |
| F25-F27 | ❌ OPEN | Cloud Function PII logs, no App Check, chartJS no SRI | |
| F28 | ✅ RESOLVED | TLS pinning not expected for v1 | ATS default acceptable |
| F29 | ❌ OPEN | App Group plaintext UserDefaults | |
| F30 | ❌ OPEN | `AppSecrets.swift:26` STILL = `iCloud.com.lasohealth.app` (mismatch); audit was wrong, **flipped 2026-04-26** |
| F4 | ✅ RESOLVED | `Core/Auth/AppleAuthService.swift` + `OnboardingPromiseStep.swift:60` `.signInWithAppleButtonStyle(.black)` (audit said open, actually wired); **flipped 2026-04-26** | |

**Subtotal:** 30 total · 8 R · 21 O · 1 NR

---

## 03-performance.md

| ID | Status | Note |
|---|---|---|
| F1 | ❌ OPEN | dual `BackgroundRefreshCoordinator` (AppDelegate + AppContainer) |
| F2 | ❌ OPEN | sleep stages fetched 5× independently; no anchored query |
| F3 | ❌ OPEN | sync `MainActor.assumeIsolated { store.loadAllTimeSeries() }` |
| F4 | ❌ OPEN | 4 redundant 1-Hz `TimelineView(.periodic)` in Breathwork widget |
| F5 | ❌ OPEN | `sessionReplay = true` always |
| F6 | ❌ OPEN | `WebExportViewModel.exportReport()` sync on MainActor |
| F7 | ❌ OPEN | unbounded `FetchDescriptor`; coarse cache invalidation |
| F8 | ✅ RESOLVED | debouncer is single-valued |
| F9-F20 | ❌ OPEN | giant files, Timer, Live Activity races, schema migration, ScrollView eager load, JSON allocations, throttle, widget reload, blind sleep, animations, HK auth roundtrip, repeated `HKHealthStore()` |

**Subtotal:** 20 total · 1 R · 19 O · 0 NR

---

## 04-product-ux.md

| ID | Status | Note |
|---|---|---|
| F1 | ✅ RESOLVED | `requestAuthorization` wired in `OnboardingPromiseStep` |
| F2 | ❌ OPEN | delete-account does not wipe Firestore / Auth user |
| F3 | ❌ OPEN | onboarding still 6 steps, no body/condition |
| F4 | ❌ OPEN | `ReferralCodeStep` orphan |
| F5 | ❌ OPEN | `AchievementsView` unreachable |
| F6 | ❌ OPEN | aha-paywall fires on `onAppear`; no close |
| F7 | ❌ OPEN | trial-expired paywall non-dismissible |
| F8 | ❌ OPEN | no cycle-tracking opt-in / off-ramp |
| F9 | ❌ OPEN | Journal no biometric lock, no encryption |
| F10-F17 | ❌ OPEN | Live tab, RiskFactorStatus copy, predictions, Discovery, Devices diag, WebExport UX, score scales, day-1 cold start |
| F18 | ⏳ NEEDS-RUNTIME | trial logic cross-check |
| F19 | ⏳ NEEDS-RUNTIME | paywall trust signals |
| F20-F25, F27-F30 | ❌ OPEN | AskYourData entry, no name/email capture, CTA hierarchy, loaders, errors, jargon, status banner, progress, score redundancy, Profile folder |
| F26 | ⏳ NEEDS-RUNTIME | empty-state copy |

**Subtotal:** 30 total · 1 R · 26 O · 3 NR

---

## 05-code-quality.md

| ID | Status | Note |
|---|---|---|
| F1 | ✅ RESOLVED | SimulationEngine unreferenced (orphan) |
| F2 | ❌ OPEN | dead-code files (581 LOC) still compiled |
| F3-F9, F11-F15, F17, F19 | ❌ OPEN | Sample/Premium providers, prints, force-unwraps, switch-on-String, hardcoded Text, DateFormatter dups, empty catch, redundant nil-checks, GCD/Task mix, no lint, copy-paste snapshots, UIKit imports |
| F10 | ✅ RESOLVED | `LasoDidWipeAccount` notification renamed |
| F16 | ✅ RESOLVED | UITestMode wrapped `#if DEBUG` |
| F9, F12-F14, F18, F20 | ⏳ NEEDS-RUNTIME | giant files, nil-bang, GCD/Task, [String:Any] sprawl, manager naming, Preview try! |

**Subtotal:** 20 total · 2 R · 12 O · 6 NR

---

## 06-design-accessibility.md

| ID | Status | Note |
|---|---|---|
| F1 | ❌ OPEN | `Assets.xcassets/AccentColor.colorset/Contents.json` STILL rose-pink (`#EB535F`, RGB 0.922/0.325/0.380); audit claim wrong, **flipped 2026-04-26** |
| F2 | ❌ OPEN | onboarding VoiceOver labels missing on 6 of 9 screens |
| F3 | ❌ OPEN | paywall radios no `accessibilityValue("Selected")` |
| F4 | ❌ OPEN | Breathwork no a11y, no haptic-by-phase, no audio |
| F5 | ❌ OPEN | 68 fixed-size fonts (1.2× artifacts) |
| F6-F10, F12-F15, F17, F19-F21 | ❌ OPEN | padding magic numbers, named colors, badges, icons, hero noise, repeatForever animations, launch icon, paywall trust, pricing copy hardcoded, dark-mode lock literals, empty states inconsistent, haptics, chart tokens |
| F11 | ❌ OPEN | no GeometryReader / sizeClass; small device cramped |
| F16, F18 | ⏳ NEEDS-RUNTIME | hit-targets sub-44pt, tab-bar contrast |

**Subtotal:** 21 total · 1 R · 18 O · 2 NR

---

## 07-analytics-posthog.md

| ID | Status | Note |
|---|---|---|
| A1 | ❌ OPEN | live PostHog key in `Secrets.xcconfig` |
| A2-A3 | ❌ OPEN | sessionReplayConfig defaults; lifecycle events pre-consent |
| B1-B3 | ❌ OPEN | session replay always-on, undeclared types, no consent gate |
| D1 | ❌ OPEN | no `identify(userId:)` after sign-in |
| D2 | ✅ RESOLVED | `reset()` called on delete |
| E1 | ❌ OPEN | direct PostHog calls bypass AppAnalytics |
| F1-F2, G1-G2 | ❌ OPEN | onboarding step events, force-quit fallback, double-fire trial, raw referral code in events |

**Subtotal:** 13 total · 1 R · 12 O · 0 NR

---

## 08-admin-panel.md

| ID | Status | Note |
|---|---|---|
| A1 | ❌ OPEN | `app.js:785-790, 972-975` `e.category` / `e.app_version` unescaped |
| A2 | ❌ OPEN | CORS `*` hardcoded |
| A3 | ❌ OPEN | `user_profiles` list rule needs deploy verify |
| A4 | ✅ RESOLVED | firebase-debug.log gitignored |
| A5, A7 | ⏳ NEEDS-RUNTIME | screenshots ignore, hosting headers — partial |
| A6, A9-A12, A14-A15, A17, A19-A20 | ❌ OPEN | full-table scan, no monitoring, single-tier admin, two write paths, dedup, KPIs, backups, audit reads, mobile, robots meta |
| A8 | ✅ RESOLVED | auth gate correct |
| A13 | ✅ RESOLVED | dev-runner local-only |
| A16 | ✅ RESOLVED | Node 20 LTS + Functions v2 |
| A18 | ✅ RESOLVED | error logging non-leaking |

**Subtotal:** 20 total · 5 R · 12 O · 3 NR

---

## 09-compliance-privacy.md

| ID | Status | Note |
|---|---|---|
| F1-F20, F22 | ❌ OPEN | server-side delete, manifest types, FirebaseAnalytics, HK copy, PP/ToS link, consent toggles, paywall on export, cycle Art 9, regional age gate, "stays on phone" copy, journal `postHogMask`, feedback PII, retention, locale URL, CCPA, anon UID timing, RoPA, consent versioning, push categories, risk badge accessibility |
| F16 | ⏳ NEEDS-RUNTIME | iCloud Keychain disclosure in PP |
| F21 | ✅ RESOLVED | no medical-grade copy in user strings |
| F23 | ❌ OPEN | depends on F3 fix |
| F24 | ✅ RESOLVED | WebExport no WKWebView/cookies |

**Subtotal:** 24 total · 2 R · 21 O · 1 NR

---

## 10-permissions-edge-cases.md

| ID | Status | Note |
|---|---|---|
| F1 | ❌ OPEN | no `registerForRemoteNotifications` in App/ |
| F2 | ✅ RESOLVED | `requestAuthorization` wired in onboarding |
| F3-F5 | ❌ OPEN | blind `isAuthorized=true`, no per-type, no revoke detect |
| F6 | ⏳ NEEDS-RUNTIME | Watch-paired UI gating |
| F7 | ❌ OPEN | Siri auth call missing |
| F8-F10, F12-F13, F15-F16, F18-F19, F22 | ❌ OPEN | deep links, app-switcher blur, time change, low-power, memory warn, BG error log, anon reset, localization, RTL, network UI |
| F17, F20-F21, F23 | ⏳ NEEDS-RUNTIME | restore-purchase UX, paywall race, scorers zero handling, empty-state copy |

**Subtotal:** 23 total · 1 R · 17 O · 5 NR

---

## 11-feature-gaps-vs-competitors.md

| ID | Status | Note |
|---|---|---|
| F1 | ❌ OPEN | no watchOS target |
| F2 | ❌ OPEN | iOS<26 cloud-LLM fallback missing |
| F3-F15 | ❌ OPEN | social, content library, score breakdowns, HRV hero, manual sleep log, cycle input, third-party APIs, family share, localization, consumables, body profile, notif auth never called, workout detection |
| F16-F19 | ✅ RESOLVED | PostHog taxonomy, on-device LLM, Live Activities, HTML export shipped |
| F20 | ⏳ NEEDS-RUNTIME | brand tagline |
| F21 | ❌ OPEN | launch geo undecided |

**Subtotal:** 21 total · 4 R · 16 O · 1 NR

---

## 12-runtime-simulator.md

| ID | Status | Note |
|---|---|---|
| R1 | ✅ RESOLVED | exit(0) removed in delete flow |
| R2, R5, R7, R11 | ⏳ NEEDS-RUNTIME | onboarding tap, dashboard reachable, paywall reachable, Dynamic Type |
| R3 | ❌ OPEN | blind `isAuthorized=true` |
| R4 | ✅ RESOLVED | dark mode lock confirmed (animation a11y still gap) |
| R6 | ✅ RESOLVED | exit(0) removed (Firebase signOut + PostHog reset) |
| R8 | ❌ OPEN | no `registerForRemoteNotifications` |
| R9 | ❌ OPEN | no privacy blur |
| R10 | ✅ RESOLVED | dark-mode behavior persists as designed |
| R12 | ❌ OPEN | no memory-warning handler |
| R13 | ❌ OPEN | deep-link handlers absent |
| N2 | ✅ RESOLVED | accessibility hint added on Begin button |
| N3 | ❌ OPEN | push pipeline dead end-to-end |

**Subtotal:** 16 total · 5 R · 8 O · 3 NR

---

## 13-pricing-business-launch.md

| ID | Status | Note |
|---|---|---|
| F1-F4 | ❌ OPEN / partial | family share off, no `isEligibleForIntroOffer`, no social proof, paywall source attribution |
| F5 | ✅ RESOLVED | restore + manage subscription wired |
| F6-F9 | ❌ OPEN | trial disclosure ambiguous, no ASSN V2, no offer codes |
| F10 | ⏳ NEEDS-RUNTIME | pricing decision pending |
| F14-F15 | ❌ OPEN | identify never called, admin KPIs missing |
| F17 | ✅ RESOLVED | aps-environment = production |
| F19-F20, F22-F23, F26 | ❌ OPEN | server-side delete, reviewer paywall path, soft launch, ASO copy, CloudKit container |
| F30 | ⏳ NEEDS-RUNTIME | crashlytics path test |

**Subtotal:** 20 total · 2 R · 15 O · 3 NR

---

## 14-cross-cut-verification.md

| ID | Status | Note |
|---|---|---|
| V1 | ✅ RESOLVED | bundle id fixed |
| V2 | ✳️ PARTIAL | PostHog key on disk only; gitignored |
| V3 | ✅ RESOLVED | aps-environment fixed |
| V4 | ❌ OPEN | client-side referral grant |
| V5-V6 | ✅ RESOLVED | rules tightened, requestAuthorization wired |
| V7 | ⏳ NEEDS-RUNTIME | exit(0) absence vs audit claim |
| V8-V11 | ❌ OPEN | XSS, CORS, sessionReplay coverage, UITestMode in prod binary |
| V12-V16 | ❌ OPEN | CoreML force-unwrap, AccentColor (resolved at design level), onboarding profile gaps, raw referral code, gitignore log |

**Subtotal:** 16 total · 3 R · 12 O · 1 NR (PARTIAL bucketed into OPEN)

---

## 15-scoring-coach-pii.md

| ID | Status | Note |
|---|---|---|
| F1-F12, B1-B6, C1-C6, C10 | ❌ OPEN | risk gauge medical, VO2 claim, brain fog, strain magic, stress min-data, vitality fallback, pace mixing, citations, sleep efficiency, HRV norms, snapshot key invalidation, narrative engine no medical guardrail, AskYourData no disclaimer, no refusal classifier, model self-confidence, identity in prompt, battery cost, AFib int, clinical_stage str, user props, journal category, raw referral, error message |
| C7-C9 | ✅ RESOLVED | identify zero call sites, metric anonymization, feedback text-length only |

**Subtotal:** 35 total · 3 R · 32 O · 0 NR

---

## 16-localization-copy-content.md

| ID | Status | Note |
|---|---|---|
| F1-F19 | ❌ OPEN | no `.lproj`, paywall hardcoded, duplicate disclaimer, missing disclaimers, Discovery views still inline, gendered cycle, food assumptions, push hooks, score labels fragmented, jargon, time hardcoded, URLs hardcoded, jargon labels, Info.plist copy, achievement bias, generic errors, spelling mix, plurals, suggestion mismatches |
| F20 | ❌ OPEN | duplicate of F14 |

**Subtotal:** 20 total · 0 R · 19 O · 1 NR

---

## 17-observability-reliability.md

| ID | Status | Note |
|---|---|---|
| F1-F4 | ❌ OPEN | Crashlytics not initialized, dSYM upload absent, signal-handler conflict, no setUserID |
| F5 | ✅ RESOLVED | bitcode + dwarf-with-dsym defaults |
| F6-F7 | ❌ OPEN | no opt-out, no debug crash button |
| F8 | ✅ RESOLVED | ATS clean |
| F9 | ❌ OPEN | no TLS pinning |
| F10 | ✅ RESOLVED | URLSession config minimal |
| F11-F22 | ❌ OPEN | empty catch, deep links, intent auth, dual coordinator, blind sleep, Live Activity races, widget reload, RC error reporting, qg hook, empty UI tests, no CI, anon auth retry |

**Subtotal:** 22 total · 3 R · 19 O · 0 NR

---

## 18-security-pass2.md

| ID | Status | Note |
|---|---|---|
| F31 | ❌ OPEN | signal handler async-unsafe |
| F32 | ✅ RESOLVED | referral redeem race fixed |
| F33-F35 | ❌ OPEN | error oracle, ITSAppUsesNonExemptEncryption=false, HTML injection |
| F36 | ⏳ NEEDS-RUNTIME | live activity lock-screen leak |
| F37 | ❌ OPEN | zero `privacySensitive` in `Modules/Journal/`; **flipped 2026-04-26** |
| F38 | ✅ RESOLVED | `autocorrectionDisabled` present (verified) |
| F39 | ✅ RESOLVED | unguarded prints DEBUG-gated (verified) |
| F40 | ❌ OPEN | demographic PII to PostHog |
| F41 | ❌ OPEN | `App/AppLaunchCoordinator.swift` STILL uses `Auth.auth().signInAnonymously { _, error in ... }` callback form (no `await`); **flipped 2026-04-26** |
| F42-F43 | ❌ OPEN | BGTask sub-check, Siri intent bounds |
| F44 | ❌ OPEN | zero `excludedActivityTypes` anywhere in repo; **flipped 2026-04-26** |
| F45 | ❌ OPEN | RC integrity verify |
| F46 | ✅ RESOLVED | UITestMode `#if DEBUG` |
| F47 | ⏳ NEEDS-RUNTIME | subscription TOCTOU |
| F48 | ❌ OPEN | NotificationCenter post object=nil |
| F49 | ⏳ NEEDS-RUNTIME | privacy manifest completeness |

**Subtotal:** 19 total · 5 R · 11 O · 3 NR

---

## 19-performance-pass2.md

All 32 findings ❌ OPEN or ⏳ NEEDS-RUNTIME — no perf fixes landed in PASS5 waves.

| Bucket | IDs |
|---|---|
| ❌ OPEN | P2-F1, F2, F4, F5, F8, F10, F11, F13, F15-F18, F20, F22, F23, F26, F27, F29, F30 |
| ✳️ PARTIAL | P2-F14, F16, F24, F31 |
| ⏳ NEEDS-RUNTIME | P2-F3, F6, F7, F9, F12, F19, F21, F25, F28, F32 |

**Subtotal:** 32 total · 0 R · 18 O · 14 NR

---

## 20-product-ux-pass2.md

| ID | Status | Note |
|---|---|---|
| F31, F32, F34-F40, F42-F44, F46-F50, F52-F55 | ❌ OPEN | pull-to-refresh, scene state, partial-data, cycle range, streaks, daily reveal, quick actions, widget URL, age picker, back button, settings search, code redemption, brain task, color-only encoding, TipKit, sheet rules, DSSkeleton, formatters, force-update URL, page nav VoiceOver, keyboard, share-with-doctor |
| F33, F45 | ✳️ PARTIAL | data loss (MetricLog/Journal fixed, AskYourData skipped); freshness (WeeklyReview only) |
| F37 | ⏳ NEEDS-RUNTIME | daily reveal moment |
| F41, F51, F54 | ❌ OPEN / NR | back button, force-update URL, live activity discovery |

**Subtotal:** 25 total · 0 R · 22 O · 1 NR · 2 PARTIAL

---

## 21-code-quality-pass2.md

| ID | Status | Note |
|---|---|---|
| P2-F1 | ❌ OPEN | Logger subsystem `com.healthpulse` rename never landed |
| P2-F2, F4-F6, F8-F11, F14-F15, F17-F19, F21, F24, F25, F28 | ❌ OPEN | switch-on-String, empty UI tests, qg hook, no CI, type leak, scorer coupling, file naming, static funcs, mock generators, UserDefaults raw, init side effects, Sendable hazards, ForEach by index, mutable shared, Result mix, weak self spread |
| P2-F7 | ✅ RESOLVED | Package.resolved committed |
| P2-F12 | ❌ OPEN | mock generators in prod binary |
| P2-F20, F26, F27 | ✅ RESOLVED | @Observable, MARK density, single @objc |
| P2-F29 | ❌ OPEN | `preconditionFailure` calls present in `Core/Analysis/RulesConfiguration.swift:312, 351, 435, 517`; **flipped 2026-04-26** |
| P2-F22 | ✅ RESOLVED | exit(0) removed |
| P2-F3, F13, F16, F17, F23 | ⏳ NEEDS-RUNTIME | dead `#available`, withCheckedContinuation, LOC count, cyclomatic complexity, Hashable contract |

**Subtotal:** 29 total · 6 R · 18 O · 5 NR

---

## 22-design-accessibility-pass2.md

| ID | Status | Note |
|---|---|---|
| P2-F17 | ✅ RESOLVED | chart accessibility (Pass 8) |
| P2-F16 | ✳️ PARTIAL | slider a11y on NotificationsSettings only |
| P2-F1-F15, F18-F40 | ❌ OPEN | state tokens, button styles, tap feedback, surface tokens, danger pairs, typography scale, icon weights, elevation tokens, divider padding, drag indicator, detents, toolbar placement, scroll indicators, selection state, env values, motion tokens, press easing, FocusState, decorative labels, hint pattern, rotor combine, decorative hidden, dynamic type ceiling, color catalog, P3, rendering, PMF rose, app-tint, hit area, chart colors, popover primitive, error surface, launch BG variants, sheet radius, form feedback |

**Subtotal:** 40 total · 1 R · 38 O · 0 NR · 1 PARTIAL

---

## 23-analytics-pass2.md

| ID | Status | Note |
|---|---|---|
| V1 | ❌ OPEN | PMF raw text |
| V2-V3 | ❌ OPEN | sleep epoch, AFib int |
| S1 | ✅ RESOLVED | reset() on delete |
| L1-L4 | ❌ OPEN | session_end flush, applicationWillTerminate, session boundary, DAU dedup |
| K1 | ✅ RESOLVED | batching config |
| M1, Q1, J1 | ❌ OPEN | deep-link orphan, profile propagation, app_environment |
| B2 | ⏳ NEEDS-RUNTIME | RC defaults audit |

**Subtotal:** 13 total · 2 R · 10 O · 1 NR

---

## 24-admin-panel-pass2.md

| ID | Status | Note |
|---|---|---|
| B1 | ✅ RESOLVED | setGlobalOptions added |
| B2 | ❌ OPEN | getUserStats no streaming |
| B3-B4 | ✅ RESOLVED (partial) | indexes + storage rules created (firebase.json link incomplete) |
| B5 | ❌ OPEN | no SRI on Firebase scripts |
| B6 | ❌ OPEN | firebase.json missing security headers |
| B7 | ❌ OPEN | admin MFA absent |
| B8-B9 | ✅ RESOLVED | structured logger, scheduled cleanup |
| B10-B11 | ❌ OPEN | field-size caps, per-key validators |
| B12 | ✅ RESOLVED | idempotency framework |
| B13-B14 | ❌ OPEN | ASSN V2 webhook, backups |

**Subtotal:** 14 total · 6 R · 8 O · 0 NR

---

## 25-compliance-pass2.md

| ID | Status | Note |
|---|---|---|
| N1 | ✳️ PARTIAL | bundle id fixed, CloudKit container ID still `.app` |
| N2, N8, N30 | ✅ RESOLVED | widget privacy manifest |
| N3, N7, N11, N12, N14-N20, N32, N42-N45, N48, N49 | ⏳ NEEDS-RUNTIME | nutrition label, breach runbook, EU rep, DPDP nominee, region, SDF, DPIA, sub-processor, CCPA notice, CCPA right-to-know, store description, APP, PDPA, POPIA, PIPEDA, screenshots, Family Sharing |
| N4-N6, N9, N13, N21-N26, N29, N31, N34, N38-N40, N47 | ❌ OPEN | clinical "warning" language, MDR, FDA SaMD, app-switcher, age gate at 13, state opt-outs, dark-pattern push, demographic re-id, deterministic linkage, mental health resources, risk emergency CTA, minimum functionality, bundle mismatch, AI label, logger PII, telemetry path leak, marketing-push split |
| N10, N28, N33, N35-N37, N50 | ✅ RESOLVED | no SIWA need, no location, no tracking domains, third-party attribution, license check, biometric exclusion |
| N27, N46 | ✅ RESOLVED / N/A | Siri usage description, China n/a |
| N41 | ✅ RESOLVED via Pass 1 | LGPD covered |

**Subtotal:** 50 total · 10 R · 19 O · 19 NR · 2 PARTIAL/INFO

---

## 26-permissions-pass2.md

| ID | Status | Note |
|---|---|---|
| P2-F1, F2, F12 | ✅ RESOLVED | HK anchor, observer leak, day-1 calibration |
| P2-F4 | ❌ OPEN | `onboardingCompletedOnThisDevice` flag NOT in code; **flipped 2026-04-26** |
| P2-F6 | ❌ OPEN | zero `interruptionLevel` in code; **flipped 2026-04-26** |
| P2-F15 | ✳️ PARTIAL | `Locale.current.measurementSystem` only in Vitality + Live BP/Temp views, NOT in central `HealthMetric.unit()` — coverage incomplete |
| P2-F18 | ❌ OPEN | `remote-notification` BG mode NOT in any plist/yml; **flipped 2026-04-26** |
| P2-F3, F5, F7-F11, F13-F14, F16-F17, F19-F22 | ❌ OPEN | family share, monotonic clock, future-date filter, negative-duration, dedup, source preference, stale data badge, iPad notice, low data mode, decimal-pad, plurals, associated domains, NSUserActivity, Spotlight, Handoff |
| P2-F23 | ⏳ NEEDS-RUNTIME | iOS<26 narrative fallback |

**Subtotal:** 23 total · 8 R · 14 O · 1 NR

---

## 27-scoring-pass2.md

| ID | Status | Note |
|---|---|---|
| F75 | ❌ OPEN | zero `redact` in any `.swift` file; lockscreen body redaction NOT implemented; **flipped 2026-04-26** |
| F13-F15, F26-F27, F37, F39, F42, F47-F48, F53-F54, F67, F77 | ❌ OPEN | CloudBackup container nil, file protection, plaintext daily narrative, time-of-day bias, journal not fed to stress, cognitive task absent, AFib treatment, ECG dead code, UTC streak, achievements unreachable, LLM safety bypass, prompt injection, PostHog no consent gate, plaintext Art 9 health focuses |
| F16-F22, F43-F44 | ⏳ NEEDS-RUNTIME | profile edit, snapshot invalidation, edge bounds, color thresholds, window inconsistency, mixed normalization, confidence gating, cycle CI, anomaly surface |

**Subtotal:** 46 total · 1 R · 20 O · 25 NR

---

## Cross-File Critical-OPEN Hot List (launch blockers)

1. **APNs registration** — `App/AppDelegate.swift` no `registerForRemoteNotifications` call (push silently fails)
2. **Account deletion** — `Auth.delete()` + Firestore wipe absent (App Store 5.1.1(v))
3. **Privacy manifest** — `NSPrivacyTracking=false` while PostHog session replay on
4. **`ITSAppUsesNonExemptEncryption=false`** — incorrect; CryptoKit + AES in EncryptedStore
5. **PostHog API key** still in `Secrets.xcconfig:5`
6. **Admin XSS** — `app.js:785-790` `e.category` / `e.app_version` unescaped
7. **Cloud Functions CORS** = `*` despite allowlist helper present
8. **Crashlytics** not initialized; no dSYM upload pipeline
9. **CoreML force-unwrap** `CoreMLEngine.swift:168`
10. **Risk + BrainHealth medical-claim copy** unchanged
11. **Onboarding age gate at 13** + under_18 PostHog events
12. **Deep-link / Universal Links** handler absent
13. **CloudKit container** `iCloud.com.lasohealth.app` (mismatch)
14. **Localization scaffold** — zero `.lproj`, en_US only
15. **CI / dSYM upload** absent
16. **ASSN V2 webhook** absent
17. **Loss-frame dark-pattern push copy** in `Copy+Notifications.swift`
18. **`NotificationManager.requestAuthorization`** — exists but verify call sites end-to-end
19. **App-switcher privacy blur** absent
20. **Biometric Journal lock** absent (`LAContext` zero hits)

## User-Intervention Required (no code can fix alone)

1. `GoogleService-Info.plist` regen — *already done in working tree* ✅
2. APNs production `.p8` key upload (Apple Dev → Firebase)
3. Risk + BrainHealth medical-claim rebrand — legal counsel
4. App Store Server Notifications V2 webhook — App Store Connect setup + backend handler
5. Pricing decision — annual tier + trial length
6. Localization translator vendor + budget
7. dSYM upload service-account key — Crashlytics symbolication
8. DPIA + RoPA + Sub-processor docs — legal/ops sign-off

---

*Generated 2026-04-26 by 27-agent verification sweep against working-tree state. Source agents and per-finding evidence in conversation transcript dated 2026-04-26.*
