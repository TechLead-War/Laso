# 16 — Localization, Copy, Disclosure & Content Audit

**Auditor lens:** principal copy editor + localization engineer + plain-language reviewer
**App identity:** Laso (`com.lasohealth.fit`), iOS 17+, target launch India + EU + US, SwiftUI, copy convention `Common/Copy/Copy+*.swift`
**Stance:** read-only research, evidence-backed, file:line citations
**Scope (and out-of-scope):**
- IN: copy quality, tone, voice, reading level, error/empty/loading states, headlines, CTAs, localization-readiness (NSLocalizedString, lproj, RTL, plurals, currency, dates), legally-mandated disclosures, sensitive-screen disclaimers, notification frequency/copy, microcopy, cultural sensitivity, accessibility-of-language.
- OUT: code structure, security secrets, perf numbers, color tokens (covered in 02/03/06).
- CROSS-CUT (referenced, not duplicated): inline-hardcoded strings already flagged as a code-quality issue in `05-code-quality.md`; medical-write entitlement / consent in `09-compliance-privacy.md`.

---

## Copy file inventory

Total lines across 23 Copy files = 3,231 LOC.

| File | Role | Quality (A-F) | Top issue |
|------|------|---------------|-----------|
| `Common/Copy/Copy.swift` | Root namespace, medical disclaimer, common buttons, privacy labels | B+ | Disclaimer copy is good but ONLY surfaced in onboarding footer; never on per-feature scoring screens |
| `Common/Copy/Copy+Common.swift` | Shared UI tokens (Avg, This Week, etc.) | B | Anaemic — only 6 strings; missing standard "Save", "Edit", "Share", "Loading", "No internet" |
| `Common/Copy/Copy+Policy.swift` | Recovery headline pools, time-to-benefit | B | "wellness trend analysis" / "circadian rhythm analysis" / "counterfactual" leak engineering jargon to source labels users see |
| `Modules/Onboarding/Copy+Onboarding.swift` | 6-step onboarding | A- | Strong empathic voice; one weak link is `pulseHeadline` poetic but vague: "See what your body has been telling you." |
| `Modules/Paywall/Copy+Paywall.swift` | Paywall copy | C | Header & feature bullets are solid, BUT no auto-renewal-disclosure or trial-cancel copy lives here — it is **inline-hardcoded** in `PaywallView.swift:360`. Violates the project's own "all user-facing strings live in Copy/Copy+*.swift" rule |
| `Modules/Dashboard/Copy+Home.swift` | Home/dashboard copy (427 lines, largest) | A- | Excellent narrative tone; one minor: "Today's Action" is generic — competitor verbs like "Recover", "Push", "Maintain" are stronger |
| `Modules/Dashboard/Copy+Briefing.swift` | Today briefing intelligence cards | A | Best-written file; consistently uses 2-clause sentence pattern (observation + soft action) |
| `Modules/Insights/Copy+Insights.swift` | Insight templates, causal hints | B | "in the bottom 10% of your history", "evidence: high/medium/early" — "early" is unclear to users |
| `Modules/Insights/Copy+Causation.swift` | Whoop-style causal sentences | C+ | Templates can output "Your data confidence is still building. Keep syncing daily" but most strings depend on `metricName` interpolation — those metric names come from somewhere else and need uniform Copy treatment |
| `Modules/Insights/Copy+Analysis.swift` | Clinical / risk titles | C | **Bug:** `medicalDisclaimer = "This is for informational purposes only and is not medical advice. This is for informational purposes only."` — the sentence is duplicated. Same duplication on `RiskDetail.disclaimer` last sentence |
| `Modules/CycleTracking/Copy+CycleTracking.swift` | Cycle tracking | B- | Gendered framing ("Your period is here"), no inclusive alternative for trans/non-binary; nutrition tip "red meat, lentils" is OK for India but "Dark chocolate and nuts" assumes Western pantry |
| `Modules/BrainHealth/Copy+BrainHealth.swift` | Cognitive wellness | B | Title flips between "Cognitive Wellness" and "Brain Health" — pick one ("Cognitive Wellness" feels clinical, "Brain Health" feels approachable; current schizoid mix is worst of both) |
| `Modules/Sleep/Copy+SleepCoach.swift` | Sleep coach | A- | Good. Imperial-only temperature: "65 to 68°F (18 to 20°C)" — OK because parenthetical present, but "Aim for lights-out by 10:30 PM" in `Copy+Notifications` is 12-hour-only with no 24-hour alternative |
| `Modules/Strain/Copy+Strain.swift` | Strain coach | B+ | Fine. "Active Recovery / Fat Burn / Aerobic / Threshold / Anaerobic" zones use clinical names — fine for fitness audience but "Fat Burn" is body-conscious branding that some users dislike |
| `Modules/Stress/Copy+StressMonitor.swift` | Stress monitor | B | "scaleAndDirection: out of 3 · Lower is better" — UNUSUAL scale (max=3) and there's NO disclaimer enum in this file (sensitive screen) |
| `Modules/Vitality/Copy+Vitality.swift` | Vitality age | A- | "Could use some care" is great, body-positive. "Aging too quickly" is harsher; consider "Speeding up" |
| `Modules/Profile/Copy+Achievements.swift` | Gamification copy | B | "Triple Threat", "Iron Will", "Hundred Day Hammer" — male/military-coded. Could alienate non-gym audience |
| `Modules/Settings/Copy+Settings.swift` | Settings | A- | Comprehensive; minor: "Danger Zone" as a header is HARDCODED in `SettingsView.swift:610`, not in this file |
| `Modules/Devices/Copy+Devices.swift` | Device pairing prompts | A- | Clean per-device-type variants; best-in-class |
| `Modules/Explore/Copy+Explore.swift` | Explore tab | B | "Strong momentum", "Solid progress", "Building up", "Getting started" — 4 score labels but they conflict with the Score Guide labels on Home ("Excellent / Good / Fair / Room to Grow") |
| `Modules/Journal/Copy+Journal.swift` | Journal | F | Only **17 lines** for an entire module. Confirmed (see "Microcopy gaps" below): Journal entry view text is **all hardcoded inline** in `JournalEntryView.swift` ("What would you like to log?", "Amount", "Notes", "Logged"...) |
| `Modules/WeeklyReview/Copy+Reports.swift` | Weekly + annual reports | A- | Strong. "Here's to a healthier {year}" is warm and on-brand |
| `Core/Notifications/Copy+Notifications.swift` | All push copy (487 lines) | B+ | Largest single file. Smart psychology hooks (Zeigarnik, loss-frame, endowed-progress). Concern: variants such as "Your \(streakDays)-day streak expires tonight." can feel manipulative if not gated by real strain (loss-aversion farming) |

**Tone consistency:** mostly second-person ("Your"), warm, observational. Onboarding tone matches Briefing tone. Paywall is more transactional (intentional). Settings is functional. **Lane is consistent**, A-grade discipline overall.

**Voice:** consistently second-person ("Your score", "You are"). Good.

**English standard:** **mixed and inconsistent.** The codebase uses British spelling for symbols (`AppColour` × 1,008 occurrences), but every user-facing copy string uses American spelling ("Behavior Correlations", "Color"). Pick one and audit.

**Reading level (Flesch-Kincaid sample):**
- Onboarding `aboutSubtitle`: "Heart, sleep, and recovery patterns change across life stages. Yours are yours alone." → ~Grade 8. Good.
- Dashboard `ScoreGuide.howItsCalculatedBody`: "Your Health Score is a weighted average across four categories. Categories with more data and more variability carry greater weight." → ~Grade 13. Above target.
- BrainHealth `headlineSharpStrong`: "Strong REM and high HRV. Great day for demanding work." → "REM" and "HRV" are jargon. ~Grade 11.
- Notifications `windDownBody`: "Tonight's target bedtime is 10:30 PM. Give yourself the runway." → Grade 8. Good.
- Insights `causalHintHRV`: "Based on your history, this level typically follows nights with less than 6 hours of sleep." → Grade 8. Good.

**Verdict:** mostly Grade 8-9 (good). Falls to Grade 12+ on Score Guide explainers and any sentence containing HRV/REM/VO2 acronyms with no first-mention expansion.

---

## Localization-readiness scorecard

| Aspect | Status | Evidence |
|---|---|---|
| `NSLocalizedString` usage in Swift | **No** | `grep -rn "NSLocalizedString" --include="*.swift"` returns zero matches across the entire repo |
| `LocalizedStringKey` usage in SwiftUI | **No** | `grep -rn "LocalizedStringKey"` returns zero matches |
| `.lproj` folders in app target | **No** | No `*.lproj` outside SPM checkouts (Firebase/PostHog) |
| `.strings` / `.stringsdict` / `.xcstrings` files | **No** | Zero strings catalogs in repo |
| `Info.plist` `CFBundleDevelopmentRegion` | Set to `$(DEVELOPMENT_LANGUAGE)` (Xcode default) — `Info.plist:9-10` | Default "en", no localized variants |
| Plurals via `String.localizedStringWithFormat` / stringsdict | **No** | Plurals done by ad-hoc ternaries: `"\(count) item\(count == 1 ? "" : "s")"` (e.g. `Settings:138`, `Insights/Copy+Insights.swift` MetricDetail) |
| Currency formatting | Partial — StoreKit shows `product.displayPrice` (auto-localized by App Store storefront) `PaywallView.swift:163`. Subscription price tier mapping by region works (`SubscriptionConfig.swift:53-77`) |
| Date formatting | Partial — `RelativeDateTimeFormatter` used in `Copy+Home.swift:19-23`, BUT `DailyNarrativeEngine.swift:96` pins to `Locale(identifier: "en_US_POSIX")` (parser-only — fine), and notification body strings hardcode `"10:30 PM"` (12-hour) `Copy+Notifications.swift:296-300` |
| RTL handling | **No** | Zero `.environment(\.layoutDirection, .rightToLeft)`, zero `.flipsForRightToLeftLayoutDirection` |
| Hardcoded Indian rupee / dollar / euro symbols in code | **No** (good — `displayPrice` from StoreKit) |
| Layout adaptability | Risky — 253 occurrences of `.frame(width:` literal constants across views; German +30% / Hindi line-height changes will overflow |

**Verdict: ZERO localization infrastructure.** Every user-facing string is a Swift `String` literal output directly. Translating Laso requires:
1. Migrating ~3,231 lines of Copy files to a String Catalog (`.xcstrings` Xcode 15+).
2. Migrating ~213 inline `Text("...")` literals to Copy first, then catalog.
3. Setting `CFBundleLocalizations` in Info.plist.
4. Manually localizing every interpolated function (e.g. `priorityCardSubtitle(for:)`).

**Time to ship one new locale:** realistically 4-6 weeks of focused work. **There is no "translate later by flipping a switch" path.**

---

## Mandated disclosure presence

| Disclosure | Status | Evidence |
|---|---|---|
| "Not a medical device / not medical advice" — initial onboarding | **Present** | Footer copy `Copy+Onboarding.swift:116`, full sheet via `MedicalDisclaimerView` opened from `OnboardingPromiseStep.swift:65` |
| Same — Risk detail (sensitive) | **Present** | `HealthRiskDetailView.swift:214` renders `Copy.Analysis.RiskDetail.disclaimer` |
| Same — Brain Health detail (sensitive) | **Present** | `BrainHealthDetailView.swift:411` |
| Same — Vitality detail (sensitive) | **Present** | `VitalityDetailView.swift:32` |
| Same — Insights detail (sensitive) | **Present** | `InsightsDetailView.swift:135` |
| Same — Strain detail (sensitive, exercise-prescriptive) | **Present** | `StrainDetailView.swift:99` + `Copy+Strain.swift:75` |
| Same — Cycle Tracking detail (sensitive, period prediction) | **MISSING** | `grep "disclaimer" Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift` → no match |
| Same — Stress Monitor detail (sensitive, mental-health adjacent) | **MISSING** | `grep "disclaimer" Modules/Stress/Views/Stress/StressMonitorView.swift` → no match |
| Same — Sleep Coach detail (prescribes exact bedtime / advises caffeine cutoff) | **MISSING** | `grep "disclaimer" Modules/Sleep/Views/Sleep/SleepCoachView.swift` → no match |
| Same — Clinical Intelligence (BP / Glucose / Resp Rate) | **DUPLICATED BUG** | `Copy+Analysis.swift:13` reads `"This is for informational purposes only and is not medical advice. This is for informational purposes only."` — the sentence is repeated verbatim |
| Same — RiskDetail disclaimer | **DUPLICATED BUG** | `Copy+Analysis.swift:200` ends "...should not replace professional medical advice. These scores are for informational purposes only and should not replace professional guidance." — repeats the disclaimer |
| Privacy Policy URL (literal) | **Hardcoded literal** | `Core/Config/AppSecrets.swift:55` — `https://lasohealth.fit/privacy`. Linked from Settings (`SettingsView.swift:387`) and Paywall footer (`PaywallView.swift:372`). URL is NOT remote-config'd — domain change requires app update |
| Terms of Use URL (literal) | **Hardcoded literal** | `AppSecrets.swift:54` `https://lasohealth.fit/terms` |
| Auto-renewal disclosure (Apple App Review §3.1.2) — title of subscription | Implicit ("Yearly"/"Monthly" only `Copy+Paywall.swift:21-22`) — no formal product title |
| — length of subscription | **Present** (1 month / 1 year via product label) |
| — price (not free) | **Present** via `displayPrice` (StoreKit auto-localized) |
| — free trial duration | **Present** `Copy.Paywall.trialDuration(_:)` `Copy+Paywall.swift:31` |
| — what user is charged after trial | **Present** `Copy.Paywall.afterTrial(_:)` `Copy+Paywall.swift:32` |
| — link to Terms + Privacy | **Present** `PaywallView.swift:367-374` |
| — auto-renews unless cancelled 24h before period end + manage in Settings | **Present** | Inline-hardcoded paragraph at `PaywallView.swift:360`, full Apple-mandated template (correct wording) |
| — copy file home for the above | **VIOLATES PROJECT RULE** | The mandatory paragraph is hardcoded in `PaywallView.swift:360`, not in `Copy+Paywall.swift` |
| StoreKit "Payment will be charged to Apple ID..." sentence | **Present** | Quoted above |
| `NSHealthShareUsageDescription` | **Present, accurate** | `Info.plist:30` |
| `NSHealthUpdateUsageDescription` | **Present but suspicious** — copy says "future features" while `HealthDataBatchWriter` already exists in the binary (cross-cut: see `09-compliance-privacy.md`) |
| `NSSiriUsageDescription` | **Present** | `Info.plist:34` |
| App Tracking (`NSUserTrackingUsageDescription`) | **Absent** (PostHog claims `NSPrivacyTracking=false` — cross-cut to `09-compliance-privacy.md`) |
| App Store description / metadata | Not in repo (no `Docs/` or `website/` review copy file) |

---

## Findings

### F1 — ZERO localization infrastructure; "India + EU + US" launch cannot ship in any language but English

**Severity:** Critical
**Issue:** Every user-facing string is a final-output Swift `String`. There is no `NSLocalizedString`, no `LocalizedStringKey`, no `.strings`/`.stringsdict`/`.xcstrings`, no `*.lproj`. Translating to Hindi, German, French, Spanish, Arabic — all impossible without code changes.
**Why this exists:** The team prioritized shipping the v1 English experience and adopted the discipline of centralizing copy in `Copy+*.swift` files. They stopped one step short — the Copy files contain raw `String`, not `LocalizedStringKey`.
**Impact:** Per the brief, target launch markets are India + EU + US. India alone needs Hindi at minimum (Devanagari script — taller line height) for any chance at non-English-speaking-Indian-middle-class adoption. EU markets expect French / German / Spanish at minimum (German strings run ~30% longer than English — the 253 fixed `.frame(width:)` constants in views will overflow). At launch, Laso will be a US-only app shipped to global storefronts.
**Evidence:**
- `grep -rn "NSLocalizedString" --include="*.swift"` → 0 matches
- `grep -rn "LocalizedStringKey" --include="*.swift"` → 0 matches
- `find . -type d -name "*.lproj"` (excluding SPM) → 0 matches
- `find . -name "*.xcstrings" -o -name "*.stringsdict"` → 0 matches
- 253 occurrences of `.frame(width:` literal constants across views
**How to verify fast:** Run all four greps above. Toggle the simulator to German (`Settings > General > Language & Region`) — Laso will display 100% English regardless.
**Fix:** Adopt Xcode 15 String Catalogs (`.xcstrings`) for all Copy files. Wrap every `Text(...)` literal — both Copy refs and inline literals — with localizable string lookups. Replace fixed-width frames with `Layout` or `lineLimit/minimumScaleFactor`. Add an RTL preview to design-review checklist. Realistic effort: 4-6 weeks (one-time investment) plus per-locale translation.
**Priority:** P0 if any non-English market is on the launch slate. P1 if you accept English-only v1 and add localization for v1.1.
**Confidence:** 99 — verified by direct grep across full source tree.

### F2 — Auto-renewal disclosure paragraph is hardcoded inline in PaywallView, violating the project's own copy-file rule

**Severity:** High
**Issue:** Apple App Review §3.1.2 mandates the long auto-renewal paragraph. The team correctly wrote the Apple-approved template, BUT it lives at `Modules/Paywall/Views/Subscription/PaywallView.swift:360` as a hardcoded `Text("Payment will be charged...")` literal. Project rule states "every user-visible string MUST live here" (`Common/Copy/Copy.swift:3`). The most legally-sensitive sentence on the most legally-scrutinized screen sits OUTSIDE the Copy file system.
**Why this exists:** Likely added late during App Review compliance work without a corresponding Copy update.
**Impact:** (a) Cannot localize the legal disclosure even if the rest of the app is localized. (b) A future copy edit could miss this string. (c) Code-review hygiene weak point — anyone can silently break the legal copy.
**Evidence:**
- `Modules/Paywall/Views/Subscription/PaywallView.swift:360`: `Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase.")`
- `Modules/Paywall/Copy+Paywall.swift` is only 34 lines and does not contain this paragraph.
**How to verify fast:** `grep -n "Payment will be charged" Modules/Paywall/Copy+Paywall.swift` — no match. Same grep on the View file — 1 match.
**Fix:** Move the paragraph into `Copy+Paywall.swift` as `Copy.Paywall.autoRenewalDisclosure`. Replace inline literal with `Text(Copy.Paywall.autoRenewalDisclosure)`.
**Priority:** P1 (one-line fix; no behavior change; closes a copy-governance hole).
**Confidence:** 99.

### F3 — Medical disclaimer is duplicated/garbled in two strings (clinical screens)

**Severity:** High
**Issue:** Two disclaimer strings have a copy-paste defect where the same sentence is repeated. Users see the same sentence twice in a row inside a single paragraph.
**Why this exists:** Likely a merge or refactor where two variants were concatenated and not deduplicated.
**Impact:** Looks unprofessional on a legally-sensitive screen. Reads like an LLM hallucination. Erodes trust precisely where you need to demonstrate it (clinical / risk screens).
**Evidence:**
- `Modules/Insights/Copy+Analysis.swift:13`: `static let medicalDisclaimer = "This is for informational purposes only and is not medical advice. This is for informational purposes only."` (sentence "This is for informational purposes only" appears twice)
- `Modules/Insights/Copy+Analysis.swift:200`: `static let disclaimer = "These scores are based on patterns in your health data and published wellness ranges. They are not medical diagnoses and should not replace professional medical advice. These scores are for informational purposes only and should not replace professional guidance."` (the "should not replace" + "informational purposes" idea repeats)
**How to verify fast:** Read the two lines above; both render to users on Risk / Insights / Brain / Vitality detail screens (since `RiskDetail.disclaimer` is reused widely).
**Fix:** Rewrite as one tight sentence: `"These scores are based on patterns in your data and published wellness ranges. They are not medical diagnoses and should not replace professional advice."`
**Priority:** P0 — a 30-second fix that touches a disclaimer literally rendered on every clinical/risk screen.
**Confidence:** 99 — copy-pasted from source.

### F4 — Three sensitive screens lack ANY medical disclaimer (Cycle, Stress, Sleep)

**Severity:** High
**Issue:** App Review reviewers and class-action plaintiffs both look at sensitive-content screens for prominent "not medical advice" framing. Three screens prescribe behavior, predict events, or score mental state — all WITHOUT a disclaimer:
- **Cycle Tracking detail**: predicts "Next Period Estimate", prescribes nutrition ("iron-rich foods like leafy greens, red meat, and lentils"), exercise.
- **Stress Monitor detail**: scores nervous system pressure 0-3, prescribes breathing exercises.
- **Sleep Coach**: prescribes specific bedtime, caffeine cutoff time, room temperature.
**Why this exists:** Disclaimer pattern was applied to Risk / Brain / Vitality / Insights / Strain (5 screens), but missed on these three. Possibly because Cycle / Stress / Sleep were perceived as "lifestyle", not "medical".
**Impact:** App Review may reject. EU MDR (Medical Device Regulation) treats menstruation prediction as a borderline medical claim. India (CDSCO) has comparable scrutiny. A user mis-timing contraception, mismanaging caffeine while pregnant, or skipping a real anxiety diagnosis because the app said "Calm" all become legal/PR risk vectors.
**Evidence:**
- `grep "Disclaimer\|disclaimer" Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift` → no match
- `grep "Disclaimer\|disclaimer" Modules/Stress/Views/Stress/StressMonitorView.swift` → no match
- `grep "Disclaimer\|disclaimer" Modules/Sleep/Views/Sleep/SleepCoachView.swift` → no match
- For comparison: `Modules/Strain/Views/Strain/StrainDetailView.swift:99` does render `disclaimerNote`.
**How to verify fast:** Open each detail screen on simulator, scroll to bottom — no fine-print disclaimer.
**Fix:** Add `Text(Copy.Analysis.RiskDetail.disclaimer)` (after fixing F3) at the bottom of all three screens. Add a Cycle-specific reminder above the period-prediction card: "Predictions are based on your past cycles and not a substitute for medical advice. Do not use this for contraception."
**Priority:** P0 for Cycle (contraception risk), P1 for Stress and Sleep.
**Confidence:** 96 — verified by grep absence; the 4-point drag is I have not opened the simulator screens to confirm there isn't a disclaimer rendered through some shared chrome I missed.

### F5 — Copy file rule is enforced unevenly: Discovery and Journal entry screens are 100% inline-hardcoded literals

**Severity:** High
**Issue:** The project rule (`Common/Copy/Copy.swift:3`) states "Every user-visible string MUST live here." Reality: 213 inline `Text("...")` literals across the Module views. Two screens are entirely hardcoded with **zero** Copy references:
- **Discovery flow** (`Modules/Discovery/Views/Discovery/DiscoveryView.swift`, 285 LOC): inline strings `"We analyzed your health history"`, `"Here is what we found"`, `"Swipe to explore"`, `"Your Dashboard is Ready"`, `"Track these patterns and more. Updated every time you open the app."`, `"Continue"`. Zero `Copy.` calls. **No Discovery copy file exists in the repo at all.**
- **Journal entry** (`Modules/Journal/Views/Journal/JournalEntryView.swift`): inline `"What would you like to log?"`, `"Amount"`, `"Notes"`, `"Logged"`, `"Log {category.displayName}"`. Only 17 lines exist in `Copy+Journal.swift` (just Insights labels). The Journal entry surface has no Copy file representation.
**Why this exists:** Likely shipped under deadline pressure; the rule is honored where the team had time, ignored where they didn't.
**Impact:** (a) Translation pass cannot translate these screens. (b) Copy review by a writer cannot see them in one place. (c) Hidden A/B test or copy-experiment risk. (d) The Journal "Log behavior" flow is one of the most-used surfaces — having it untracked is a real product hole.
**Evidence:**
- `grep -c 'Text("' Modules/Discovery/Views/Discovery/DiscoveryView.swift` → 6
- `grep -c 'Copy\.' Modules/Discovery/Views/Discovery/DiscoveryView.swift` → 0
- `wc -l Modules/Journal/Copy+Journal.swift` → 17
- Total inline `Text("` in Modules: 213
**How to verify fast:** Run the same two greps; open the Discovery view file and the Journal entry view file — count strings.
**Fix:** Create `Modules/Discovery/Copy+Discovery.swift`. Move all 6 strings. Expand `Copy+Journal.swift` to cover the Entry view. Add a CI check (`grep -L "Copy\." Modules/*/Views/*.swift` plus a curated allowlist) to fail PRs that introduce inline literals.
**Priority:** P1 — pre-launch, before any localization work.
**Confidence:** 98.

### F6 — Onboarding gendered framing on Cycle Tracking has no inclusive alternative

**Severity:** Medium
**Issue:** `Copy+CycleTracking.swift` uses gendered framing ("Your period is here", "Hormone levels at their lowest"). For trans men, non-binary users who menstruate, and users who track cycles for partners, the copy doesn't adapt. The wider app uses second-person neutral ("Your") which makes the cycle-specific phrasing fine in isolation — but there's no opt-in / opt-out at onboarding. Gender selection on `OnboardingAboutStep` (`Copy+Onboarding.swift:17-19`) is not surfaced as inclusive.
**Why this exists:** Cycle Tracking modeled after typical period-tracking app conventions (Flo, Clue used this language until ~2019).
**Impact:** Modern competitor apps (Flo, Apple Health, Oura) all moved to inclusive language and an "I track cycles for: myself / a partner" toggle. Indian millennial/Gen-Z users in metros + EU LGBTQ+ users will notice. Reviews on App Store will dock stars.
**Evidence:** `Copy+CycleTracking.swift:19-22` uses "Your" but the framing is implicitly menstrual-bodied.
**Fix:** Add a "Cycle tracking is optional. You can use it for yourself or someone else." line on enablement. Replace "may notice changes in appetite, sleep, and mood" with a softer "the body in this phase often shows..."
**Priority:** P2.
**Confidence:** 88 — copy reading is solid; fix recommendation is editorial judgment so subjective.

### F7 — Cycle nutrition tip leans Western pantry; reduces relevance for India launch

**Severity:** Low
**Issue:** `Copy+CycleTracking.swift:50` — luteal nutrition tip is `"Your body needs a bit more food. Add healthy fats and magnesium-rich foods. Dark chocolate and nuts can help with cravings."` Dark chocolate is uncommon in middle-income Indian household pantries; "magnesium-rich foods" is jargon (vs "rajma, palak, kaddu seeds"); the menstrual tip `"red meat, lentils"` mentions red meat which is culturally inapplicable for vegetarian-majority Indian audiences.
**Why this exists:** Generic Western women's health content.
**Impact:** Not legally risky, just brand-tonal-mismatch for India.
**Fix:** Localize examples per region. India variant: `"daal, palak, kaddu seeds, kheere mein chunked, dahi"`. US variant unchanged. This is exactly what the missing localization layer would unlock.
**Priority:** P3.
**Confidence:** 85.

### F8 — Notification copy uses heavy psychology levers (loss-aversion, streak-anxiety) that may breach Apple's recent guidance on manipulative engagement

**Severity:** Medium
**Issue:** `Copy+Notifications.swift:144-150` and `:178-187` literally taxonomize psychology-backed engagement hooks: `case curiosity (Zeigarnik)`, `case lossFrame (loss aversion)`, `case progress (endowed progress)`. Resulting strings:
- `"Your \(streakDays)-day streak expires tonight."`
- `"You are losing ground from last week."`
- `"Yesterday's gains are slipping."`
- `"Before you stepped away, your HRV trend was slipping. Check where it is today."`

Apple's Human Interface Guidelines on notifications (2024 update) and EU Digital Services Act §25 ("dark patterns") both call out manipulation framed as urgency / loss when the urgency is engineered, not real.
**Why this exists:** D7/D30 retention engineering — common pattern in consumer apps.
**Impact:** (a) Apple App Review may reject under guideline 4.5.4 (push abuse) if these fire on cold-cache days where there is no actual data. (b) EU/UK users can complain under DSA dark-pattern provisions. (c) Reputationally — competitors Oura/Apple Health adopt a calmer voice and beat Whoop on App Store rating largely because of this.
**Evidence:** Strings cited above. The `dynamicDailySummaryTitle` function at `Copy+Notifications.swift:154` rotates psychological categories actively.
**How to verify fast:** Read the `HookCategory` enum and the `candidates.append((.lossFrame, ...))` blocks.
**Fix:** Keep curiosity + progress + question hooks; soften loss-frame hooks. `"Your streak expires tonight"` → `"Your streak ends if you skip today. No pressure."` Add user-controllable toggle in Settings: `"Use motivational nudges"` default ON, with an explanation. Cap loss-frame hooks at 1 per week per user.
**Priority:** P1 for EU launch, P2 elsewhere.
**Confidence:** 80 — the legal-policy reading is judgment-based; the strings are verified.

### F9 — Inconsistent score-label vocabulary across screens

**Severity:** Medium
**Issue:** The same idea ("you're doing well") is labeled differently across screens. Users see different word for the same thing:
- Home Score Guide: `"Excellent / Good / Fair / Room to Grow"` (`Copy+Home.swift:189-198`)
- Explore Score Hero: `"Strong momentum / Solid progress / Building up / Getting started"` (`Copy+Explore.swift:18-21`)
- Vitality pace labels: `"Improving / Stable / Declining"` (`Copy+Vitality.swift:85-87`)
- Recovery Hero in Dashboard: `"Fully Recovered / Well Recovered / Moderate / Fatigued / Strained"` (`Copy+Home.swift:119-123`)
- Briefing labels: `"Heads Up / Something Changed / Cascade Alert"` (`Copy+Briefing.swift:13-22`)
**Why this exists:** Each module designed in isolation; no global terminology dictionary.
**Impact:** Users have to mentally re-map across tabs. Translation amplifies the cost — every variant needs translation. Premium-brand voice consistency drops.
**Fix:** Create `Copy+Common.swift > Tier { excellent, good, fair, low }` with one canonical adjective + one canonical descriptor each. Every module references those. Expand the existing `Copy.Common` (currently only 6 tokens).
**Priority:** P2.
**Confidence:** 92.

### F10 — Reading level spikes to Grade 12+ on Score Guide and on any sentence containing HRV / REM / VO2 with no first-mention expansion

**Severity:** Medium
**Issue:** Most copy targets Grade 8 well. Two patterns push it higher:
- Score-explainer paragraphs: `"Your Health Score is a weighted average across four categories. Categories with more data and more variability carry greater weight."` ("weighted average" + "variability" — Grade ~13).
- Acronyms used without first-mention expansion: `headlineSharpStrong = "Strong REM and high HRV. Great day for demanding work."` (BrainHealth). User who has never heard "REM" or "HRV" gets no help.
**Why this exists:** Health-tech writers default to fitness/clinical jargon.
**Impact:** New users who quit during onboarding because they don't know what HRV is. India general-public audience (target market) has even less familiarity.
**Evidence:**
- `Copy+Home.swift:203`: `howItsCalculatedBody = "Your Health Score is a weighted average across four categories. Categories with more data and more variability carry greater weight. Each metric is scored against your personal baseline, and deviations and trends move the score up or down."`
- `Copy+BrainHealth.swift:20`: `headlineSharpStrong = "Strong REM and high HRV. Great day for demanding work."`
**Fix:** First-mention pattern: "HRV (heart rate variability)" the first time per session. Replace "weighted average" with "blended average". Replace "variability" with "swing". Add a `Glossary` enum in Copy with one-line definitions and link from acronyms via tap.
**Priority:** P2.
**Confidence:** 90.

### F11 — Notification body has hardcoded 12-hour times; will look broken in 24-hour locales

**Severity:** Medium
**Issue:** `Copy+Notifications.swift:296-300` hardcodes bedtime targets in 12-hour format: `"Aim for lights-out by 10:30 PM..."`, `"...11:00 PM to protect tomorrow's score."`. India, France, Germany default to 24-hour clock; users with 24-hour preference will see "10:30 PM" instead of "22:30".
**Why this exists:** String concatenation chosen over `DateFormatter` with locale awareness for the static evening-anchor strings.
**Impact:** Cosmetic in English-speaking markets, more jarring in 24-hour-default markets.
**Fix:** Replace literals with a function `Copy.Notifications.bedtimeAnchor(targetDate:)` that uses `Date.FormatStyle(date: .omitted, time: .shortened)` so the system clock preference applies.
**Priority:** P3.
**Confidence:** 95.

### F12 — Privacy Policy and Terms URLs are hardcoded literals not remote-config'd

**Severity:** Medium
**Issue:** `Core/Config/AppSecrets.swift:54-55` hardcodes:
```
static let termsOfUse = "https://lasohealth.fit/terms"
static let privacyPolicy = "https://lasohealth.fit/privacy"
```
There are 4+ link sites in the binary (Settings, Paywall × 2, Onboarding) but a domain change requires an app update + App Review + 1-7 day rollout window during which the legally-mandated link is broken or stale.
**Why this exists:** No URL-config pipeline existed when these screens were built.
**Impact:** Legal teams typically version Privacy Policies and need short-cycle updates. Stale link = a regulator cite waiting to happen.
**Fix:** Wire URLs through `RemoteConfigManager` (already used for product IDs and trial days — `SubscriptionConfig.swift:17`). Cache the latest URL on disk so airplane-mode users still see something.
**Priority:** P2.
**Confidence:** 95.

### F13 — Engineering jargon leaks into user-visible source labels via `Copy+Policy.swift`

**Severity:** Low
**Issue:** `Common/Copy/Copy+Policy.swift:59-66` defines source labels rendered to users:
```
sourcePredictive  = "wellness trend analysis"
sourceCausal      = "pattern analysis"
sourceCircadian   = "circadian rhythm analysis"
sourceCounterfactual = "what-if analysis"
```
"Counterfactual" (rendered via `sourceCounterfactual` to users somewhere if it ever propagates) is a research term, not a consumer term. "Circadian" is borderline.
**Why this exists:** Labels mirror the analytics module names.
**Impact:** Low — these may be rendered as fine-print "powered by..." labels, not as headlines, so impact is small. But on the day a user does see "what-if analysis", it reads alien.
**Fix:** Map to user-friendly: `sourceCounterfactual = "scenario analysis"` or just `"insight"`. Drop "circadian" → `"body clock"` (the Briefing module already uses `"Your Body Clock"` correctly).
**Priority:** P3.
**Confidence:** 85.

### F14 — `NSHealthUpdateUsageDescription` says "future feature" but write code already exists — App Review rejection vector for Info.plist <-> code mismatch

**Severity:** High (cross-cut, owned by `09-compliance-privacy.md`)
**Issue:** `Info.plist:32` says writing to Apple Health is a "future feature." But `HealthDataBatchWriter` exists in the binary today. App Review rejects health apps where the manifest and behavior don't match.
**Note:** flagged here because the root issue is **copy in the manifest is misleading**. The remediation (rewrite the description string) is a copy edit, not a code change.
**Fix:** `"Laso writes journal entries (water, mood, mindful minutes) you log to Apple Health so the data lives in one place."` (only if writes are actually used — verify in `09-compliance-privacy.md`).
**Priority:** P0 — App Review blocker.
**Confidence:** 92.

### F15 — Achievement copy uses gym/military-coded titles that may alienate non-fitness users

**Severity:** Low
**Issue:** `Copy+Achievements.swift` uses titles like `"Iron Will"`, `"Hundred Day Hammer"`, `"Triple Threat"`, `"Step King"`, `"Absolute Legend"`, `"Centurion"`. The earlier user levels (`Newcomer / Explorer / Committed / Dedicated / Champion / Legend`) are softer, but mid-tier achievement titles lean masculine-fitness. India launch + female-leaning Cycle module suggest a more universal vocabulary would land better.
**Fix:** Optional. Mix in titles like `"Steady Hand"` (already there), `"Daily Devotee"` (already there), and add `"Calm Streak"`, `"Sleep Hero"`, `"Heart Hero"`. Or A/B test.
**Priority:** P3.
**Confidence:** 80.

### F16 — Empty-state copy is good; loading copy is repetitive; error copy is mostly specific (one offender)

**Severity:** Low
**Empty states (good):**
- Onboarding `connectUnavailable = "Apple Health is not available on this device."` — specific, kind.
- Insights `noDataYet = "No Data Yet"` + descriptive body. Good.
- Explore `almostThereBody = "A few more days of tracking and your score will be ready"` — empathetic, not blank.

**Loading (repetitive):**
- Both `Copy+Home.swift:27` (`"Analyzing your health data..."`) and `LoadingView.swift:153` (`"Analyzing your health data..."`) use identical text. Cycling skeleton labels in `LoadingView.swift:19-20` adds variety but also overlaps. Loading copy is fine; just unify.

**Error (one offender):**
- `Modules/Referral/Services/ReferralManager.swift:202`: `redeemError = "Something went wrong. Try again."` — generic, not actionable. Compare against the rest of the app where errors are specific (`unableToLoadData`, `Failed to save: \(localizedDescription)`).
- `Modules/Dashboard/ViewModels/DashboardViewModel.swift:2159`: `answer: "Something went wrong processing your question. Try asking again."` — better than the referral case but still generic.

**Fix:** Replace "Something went wrong" with "We couldn't redeem your code. Check the code and try again." and "We couldn't process your question. Try rephrasing it."
**Priority:** P3.
**Confidence:** 92.

### F17 — Spelling standard mismatch: code symbols are British (`AppColour`), user copy is American

**Severity:** Low
**Issue:** Code uses British spelling for shared types (`AppColour` × 1,008 occurrences). Every user-facing string uses American: `"Behavior Correlations"` (`Copy+Reports.swift:83`), `"color"` in HTML output (`HTMLReportGenerator.swift`).
**Why this exists:** Likely an Indian-team default (British-leaning) for code, plus an American-leaning copy pass.
**Impact:** Internal-only confusion. Users only see the American copy. **No user-visible impact.** But picks up tomorrow's localization work — a clean "en" baseline + later "en-GB" variant requires deciding which side to standardize.
**Fix:** Decide and document. American is the safer default for App Store. British becomes a one-line `en-GB.lproj` later. Either way, pick one for symbol AND copy.
**Priority:** P3.
**Confidence:** 95.

### F18 — Plurals are done by ad-hoc ternaries throughout — will break in any non-English locale

**Severity:** Medium
**Issue:** Plural rules use English-style ternaries:
- `Settings.connectedCount(_ count: Int)` → `"\(count) connected"` (no plural)
- `Notifications.metricsNeedAttention(_ count: Int)` → `"\(count) metric\(count == 1 ? "" : "s") worth a quick look."` (`Copy+Notifications.swift:135`)
- `Insights.dataPointsSummary(_ count: Int)` → `"Based on \(count) data points"`
- `Explore.insightCount(_ count: Int)` → `"\(count) insight\(count == 1 ? "" : "s")"`
- `Insights.MetricDetail.expandedRangeNotice(_ days: Int)` → `"Expanded to \(days) days to show available data"`

Polish has 3 plural forms, Russian 4, Arabic 6. Hindi has nuanced rules. None of these will translate correctly via mechanical pluralization.
**Why this exists:** No `stringsdict` or `.xcstrings` plural support adopted.
**Fix:** When migrating to String Catalogs (per F1), use the catalog's plural variations editor. `String.localizedStringWithFormat` + `%d` is the API.
**Priority:** P1 (bundled with localization work).
**Confidence:** 95.

### F19 — Concierge / "Ask your data" suggested questions are hardcoded in Copy but appear to be the app's only answers fallback if model unavailable

**Severity:** Medium
**Issue:** `Copy+Home.swift:344-365` lists the seeded prompts and `suggestedQuestions`. The list is editorially good, but cross-cutting:
- These are also the implicit fallback if AskYourData has no on-device LLM answer.
- If the rule-based answer engine returns generic answers like "Something went wrong processing your question. Try asking again." (`DashboardViewModel.swift:2159`), then a user who taps a suggested question gets a poor experience.
**Fix:** Verify each suggested question maps to a real answer template. If not, prune the list.
**Priority:** P2 (cross-cut to product/UX `04-product-ux.md`).
**Confidence:** 75 — I have not exhaustively read the AskYourData engine.

### F20 — Apple Health write-permission usage description (Info.plist) and HealthKit code mismatch (cross-cut F14)

Same finding as F14, repeated for index visibility because it's a copy issue at the manifest layer.

---

## Summary

**Posture (Pass 1, copy-and-localization lens):**
- Copy quality is **A-** overall. Tone is empathic, second-person, consistent. The Briefing and Onboarding modules are the strongest writing in the app. The disclaimer-duplication bug (F3) and the missing disclaimers on Cycle/Stress/Sleep (F4) are the only quality red flags but they sit on legally sensitive screens.
- Localization-readiness is **F**. Zero infrastructure. The "India + EU + US" launch headline is unbacked by any code path that supports a second language. This is the #1 finding by impact.
- Mandated disclosures are **B**. Auto-renewal paragraph is correct but inline-hardcoded (F2). Five sensitive screens have disclaimers; three do not (F4). Disclaimer text is duplicated/garbled on the screens that DO have it (F3).
- Notification copy is sophisticated but pushes loss-aversion levers that risk Apple App Review § and EU DSA scrutiny (F8).

**Verdict:** Copy file discipline (the project's "all strings live in Copy/" rule) is **80% honored, 20% leaking** — Discovery and Journal entry are entirely uncovered, and the legally most-sensitive paragraph (auto-renewal) sits inline in PaywallView. Translation-readiness is **0%** — there is no path to ship one new locale in under 4-6 weeks.

---

## Top 3 fixes to do RIGHT NOW (under 90 minutes total)

1. **Fix F3 — disclaimer duplication.** Rewrite `Copy+Analysis.swift:13` and `:200` to single-sentence form. ~5 minutes of editing. Touches every clinical/risk screen instantly.
2. **Fix F4 — add medical disclaimer to Cycle, Stress, Sleep detail views.** Three files, three `Text(Copy.Analysis.RiskDetail.disclaimer)` additions at the bottom of the scroll view, plus a Cycle-specific contraception caveat. ~30 minutes.
3. **Fix F2 — move auto-renewal paragraph from `PaywallView.swift:360` into `Copy+Paywall.swift` as `Copy.Paywall.autoRenewalDisclosure`.** ~5 minutes. Closes a copy-governance hole on the most legally-sensitive screen.

These three will reduce App Review rejection risk and EU MDR exposure without touching architecture.

---

## Open questions for the product team

1. Is English-only v1 acceptable, or is Hindi mandatory for India launch? Answer dictates whether F1 (localization) is P0 or P1.
2. Is "Cycle Tracking" intentionally targeted only at menstruating women in v1, or is inclusive framing in scope?
3. Is the `NSHealthUpdateUsageDescription` "future feature" framing intentional? If writes are live in v1, that string is a rejection vector (F14).
4. Are PostHog session-replay-style hooks fired off the loss-frame notifications? If yes, EU DSA exposure compounds (cross-cut to `09-compliance-privacy.md`).

`Confidence: 88/100 — every finding is grep-verified at file:line and the cited Copy source is read in full; the 12-point gap reflects (a) I have not opened the simulator to confirm visual rendering of the missing disclaimers on Cycle/Stress/Sleep, (b) the EU DSA dark-pattern judgment in F8 is policy-interpretive not literal-compliance, and (c) reading-level grades are sampled, not Flesch-Kincaid'd over the full corpus.`
