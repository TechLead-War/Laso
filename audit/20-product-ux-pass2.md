# 20 — Product / UX / Copy / Friction Audit, Pass 2 (deeper)

**Auditor stance:** principal product designer + adversarial product skeptic doing a SECOND, deeper read-only pass on the Laso build. Pass 1 (`audit/04-product-ux.md`, F1–F30) is treated as covered: notification permission, delete-account, onboarding length, paywall trust signals, dead Discovery / Achievements / Referral, dark patterns, jargon density, score overlap, etc. This pass intentionally skips those areas and goes after **what Pass 1 missed**. All findings reference real files at absolute paths in this repo. No code modified.

**Format:** Severity / Issue / Why this exists / Impact / Evidence / Verify fast / Fix / Priority / Confidence.

---

## F31. Pull to refresh is implemented on only 3 of 13 user-facing surfaces. The mental model is "swipe down to refresh on Home, give up everywhere else"

- **Severity:** High
- **Issue:** A repo-wide grep for `.refreshable` returns matches in only `HomeView.swift:69`, `ConnectedDevicesView.swift:158`, `ExploreView.swift:299`. Every other detail surface — `InsightsDetailView`, `MetricDetailView`, `CategoryDetailView`, `SleepCoachView`, `StrainDetailView`, `StressDetailView` (if any), `VitalityDetailView`, `BrainHealthDetailView`, `CycleDetailView`, `HealthRiskDetailView`, `LiveView`, `WeeklyReviewView`, `JournalInsightsView`, `SettingsView`, `PaywallView` — has no pull-to-refresh. Worst offender is `LiveView` (Modules/Live/Views/Live/LiveView.swift) which is supposed to show **real-time** vitals but has no manual refresh, no "force re-poll" affordance — a stale heart-rate reading can sit there indefinitely until iOS HKObserverQuery fires (which can take minutes when Watch background-delivery throttles). Devices view has it but spins a `ProgressView` without showing what changed.
- **Why this exists:** `.refreshable` was added incrementally on the screens that were tested most. The convention "every list/detail should support pull" was never enforced.
- **Impact:** Lost trust when users on a flaky network or a freshly-paired Watch don't see fresh data and have no obvious way to ask for it. This is the single most universal "is this app broken?" signal in iOS, and it's missing from the highest-stakes screen (Live vitals). Apple App Review will sample MetricDetail / CycleDetail and find no refresh path.
- **Evidence:**
  - `Modules/Live/Views/Live/LiveView.swift:47-100` — ScrollView, no refreshable.
  - `Modules/Insights/Views/Insights/InsightsDetailView.swift:75-145` — ScrollView, no refreshable.
  - `Modules/MetricDetail/Views/MetricDetail/MetricDetailView.swift:138-172` — no refreshable.
  - `Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift:136-168` — no refreshable.
  - `Modules/BrainHealth/Views/BrainHealth/BrainHealthDetailView.swift:14-36` — no refreshable.
  - Repo-wide grep `refreshable` → 5 hits across 3 production views (and 2 ViewModel comments).
- **Verify fast:** Open Live tab on a paired-Watch device, walk away from the watch, return. Try to "pull" the list. Nothing happens. Vitals are whatever HealthKit decided to surface last.
- **Fix:** Add `.refreshable { await viewModel.refresh() }` to every detail and list surface. Where there's no obvious refresh action, surface "Last updated 2 min ago" footer with a tap-to-refresh affordance. For LiveView specifically, add a `Button("Refresh now")` near the header AND `.refreshable` — users will reach for both.
- **Priority:** This Week — universal expectation gap.
- **Confidence:** 96/100 — verified by exhaustive grep; the 4-point gap is whether some custom gesture handler I didn't read implements an equivalent.

---

## F32. Selected tab does not persist across launches. Users who live on Explore or Settings always cold-launch into Home

- **Severity:** Medium
- **Issue:** `ContentView.selectedTab` is a plain `@State private var selectedTab: AppTab = .home` (`App/ContentView.swift:10`) — not `@SceneStorage`, not `@AppStorage`, no persistence. There is no read-from-defaults init path either; the only initial-tab override is the UI-test launch flag (`UITestMode.initialTab`, ContentView.swift:32-34). A power user who lives on the Stats / Explore tab cold-launches and gets bumped back to Home every single time. Worse, navigation paths (`homePath`, `explorePath`) are also non-persisted `@State` — any deep navigation (Home → MetricDetail → InsightsDetail) is wiped when the app is force-quit or the OS evicts the scene.
- **Why this exists:** Default SwiftUI pattern. SceneStorage was the right tool but never adopted.
- **Impact:** Friction for the daily-engaged user who just wanted to check yesterday's trend. Particularly painful for the Settings → Notifications → Daily Summary toggle journey — a user who wants to fix a notification setting always lands on Home first and re-navigates.
- **Evidence:**
  - `App/ContentView.swift:10-14` — `@State private var selectedTab`, `navigationPath`, `homePath`, `explorePath` all non-persisted.
  - Grep `@SceneStorage` → zero matches in repo.
- **Verify fast:** Launch app, navigate to Settings, force-quit. Relaunch. App lands on Home. Repeat 5 times — same behaviour, by design.
- **Fix:** `@SceneStorage("selectedTab") private var selectedTabRaw: String = AppTab.home.rawValue` with a computed selectedTab. Same for the navigation paths via `NavigationPath`'s codable / `@SceneStorage`. Exclude the paywall-active state so a cold launch never restores into a paywall destination.
- **Priority:** This Month — quality-of-life for return users.
- **Confidence:** 92/100 — verified by file read; the 8-point gap is whether a launch-time restoration is silently happening via state restoration somewhere I missed.

---

## F33. Sheets used as one-way data-loss traps: JournalEntry, AskYourData, MetricLog all let pull-to-dismiss silently discard typed input with no confirmation

- **Severity:** High
- **Issue:** `JournalEntryView` is presented as a SwiftUI sheet from Home. Its toolbar `Cancel` button calls `dismiss()` directly with no confirmation (`Modules/Journal/Views/Journal/JournalEntryView.swift:46-58`). The view also accepts `axis: .vertical` notes in a TextField (line 237) — a user can type a long mood entry, then accidentally drag the sheet down and lose everything. There is no `.interactiveDismissDisabled` gate, no "you have unsaved changes — Discard / Keep Editing" `.confirmationDialog`, no `isDirty` state at all. Same pattern in `MetricLogSheet` (`MetricDetailView.swift:142-150`) — pull-down dismisses an in-progress log. Same in `AskYourDataView` — typed query gone on swipe-down. Repo-wide grep `confirmationDialog` returns zero matches in production code paths for these flows.
- **Why this exists:** SwiftUI's default sheet behaviour is "any drag is dismiss". Apple HIG says to gate this when there's unsaved work; it requires `.interactiveDismissDisabled(condition)` plus a confirmation alert. None of these flows implement either.
- **Impact:** Silent data loss on every accidental swipe. Mood/journal entries are exactly the field where trust matters most (the whole proposition of the app). One lost long entry is enough to break a user's habit loop.
- **Evidence:**
  - `Modules/Journal/Views/Journal/JournalEntryView.swift:6-78` — no dirty check, no `.interactiveDismissDisabled`, Cancel just dismisses.
  - `Modules/MetricDetail/Views/MetricDetail/MetricDetailView.swift:142-150` — `.sheet` + `.presentationDetents([.medium])` only.
  - `Modules/Dashboard/Views/Home/AskYourDataView.swift:55` — TextField for query, parent sheet has no dirty gating.
  - Repo-wide grep `interactiveDismissDisabled` → 4 hits (LasoApp paywall, CompromisedEnvironment, MedicalDisclaimer, OnboardingView, Discovery) — none on user-input sheets.
- **Verify fast:** Open Home, tap Journal, pick category, type 200 chars in notes. Drag the sheet down 100pt. Sheet dismisses. Reopen. Empty.
- **Fix:** Track `isDirty: Bool` (any non-default field touched). Apply `.interactiveDismissDisabled(isDirty)`. On the toolbar Cancel button when `isDirty`, show `.confirmationDialog("Discard your entry?", isPresented:)` with Discard / Keep Editing. Same pattern for MetricLog and AskYourData. This is a 30-line per-file change, very high ROI.
- **Priority:** Now — silent data loss is brand-trust kryptonite.
- **Confidence:** 94/100 — verified by reading all three sheets and grep-confirming no dirty gating anywhere.

---

## F34. Charts hard-fail under 2 data points with "Not Enough Data" — no list/sparkline fallback, no "log first entry" CTA

- **Severity:** Medium
- **Issue:** `MetricChartView.body` checks `if samples.count < 2` and returns `ContentUnavailableView("Not Enough Data", ..., description: Text("At least 2 data points needed"))` (`Common/Components/MetricChartView.swift:71-76`). Day-1 to day-2 users who logged a single weight or HR reading hit this. There is no fallback list view ("Yesterday: 158 lbs"), no sparkline-of-one (Apple Health shows a single dot), no "Log another entry" CTA to break the cold-start loop. The same state appears across every detail screen that uses `MetricChartView`. The copy is also clinical — "At least 2 data points needed" is engineering-speak.
- **Why this exists:** SwiftUI Charts requires ≥2 points to draw a line; the simplest dodge is to gate on `< 2`. Nobody designed the empty path.
- **Impact:** Day-1 detail screen feels broken. The first metric a user logs in Journal does not visually appear anywhere, breaking the "I see what I did" feedback loop that every habit app needs in week 1.
- **Evidence:**
  - `Common/Components/MetricChartView.swift:70-77`.
  - Used by `MetricDetailView.swift:261-269`, `CategoryDetailView.swift`, `WeeklyReviewView.swift`, etc.
- **Verify fast:** Reset simulator. Log one Journal entry for weight. Open Body category → Weight metric detail. See "Not Enough Data".
- **Fix:** Replace the gated branch with: (a) if `samples.count == 1`, show a single-dot mini-chart with the value labeled, and a "Log another to see your trend" CTA that opens MetricLogSheet, (b) if `samples.count == 0`, show a "Log your first {metric}" CTA, (c) if `samples.count >= 2`, the existing chart. Same component, three branches.
- **Priority:** This Week — first-week retention surface.
- **Confidence:** 90/100 — verified by reading the component; the 10-point gap is whether some downstream view already shimmies a single-point shim that I didn't trace.

---

## F35. Cycle prediction shows a single hard number ("12 days") with no confidence range — Whoop / Oura industry standard is a probability band

- **Severity:** Medium
- **Issue:** `CycleDetailView.nextPeriodSection` (`Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift:517-570`) renders a countdown circle with a single integer `daysUntilPeriod` and the formatted target date. There is no probability band (e.g., "12-15 days, 70% confidence"), no "based on N cycles", no caveat about variability. The underlying tracker (`MenstrualCycleTracker`) has a confidence concept internally (it tracks data freshness for stale snapshots, `MenstrualCycleTracker.swift:137`) but the CycleDetailView doesn't surface it. Whoop, Oura, Clue, Flo all show prediction ranges on this exact screen because cycle-length variance is real and a hard date sets a wrong expectation.
- **Why this exists:** First-cut UX shipped a deterministic countdown.
- **Impact:** Trust fail when the period arrives 2 days early or late vs the prediction. This screen is also one of the most-screenshotted in fertility-adjacent apps, so a single number that turns out to be wrong damages organic word of mouth.
- **Evidence:**
  - `Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift:517-570`.
  - `Core/Analysis/MenstrualCycleTracker.swift` — internal cycle-history modeling exists but no confidence-band export.
- **Verify fast:** Open a profile with 3-4 cycles of data, navigate to CycleDetail, observe the next-period section. One number, one date, no caveats.
- **Fix:** Compute `cycleLengthStdev` from `cycleHistory`. Show range `cycleLength - stdev..cycleLength + stdev` with copy "Likely between {start} and {end}". Add micro-text below: "Based on your last {n} cycles. Variability is normal." Same pattern for ovulation window if surfaced.
- **Priority:** This Month — accuracy framing.
- **Confidence:** 88/100 — verified the view; tracker internals not exhaustively re-read for whether stdev is already exposed.

---

## F36. AchievementsView levels and streaks exist as compute, but there is no streak surfacing on Home and no "you almost lost your streak" loss-aversion prompt

- **Severity:** Medium (NOT a duplicate of F5 which was about Achievements being unrouted)
- **Issue:** Pass 1 F5 said the Achievements ROUTE is unwired. The deeper problem: even if the route gets wired, `Copy.Profile.Achievements` defines a rich streak vocabulary (`weekWarriorDescription = "7-day activity streak"`, `dreamMachineDescription = "30 day sleep streak"`, `dailyDevoteeDescription = "14 day check-in streak"`) — but **no Home surface shows the active streak count, and no notification fires on streak risk**. Whoop, Strava, Duolingo's entire retention loop is "you have a 14-day streak — don't lose it tonight". Laso computes the streak (PersonalRecordAnalyzer.swift:50, GamificationEngine), then drops it on the floor. There is `Copy.Home.Greeting.streakBadge` (referenced in Pass 1) but it is not wired to a conspicuous streak chip in the greeting.
- **Why this exists:** Streak surfacing was scoped into Achievements, then Achievements got dropped from nav, then nobody moved the streak to Home.
- **Impact:** A high-leverage retention mechanic computed at runtime cost is invisible. Most-engaged users do not feel rewarded for consistency. Day-30+ churn higher than it should be.
- **Evidence:**
  - `Modules/Profile/Copy+Achievements.swift:37-77` — 8+ streak achievements defined.
  - `Modules/Dashboard/Views/Home/CoachGreetingView.swift:58-78` — greeting has time-of-day branches but no streak counter.
  - `Core/Notifications/EngagementSequenceScheduler.swift` — fires on first/second score gates, no streak-loss-warning notification.
- **Verify fast:** Build a 7-day-active profile. Open Home. There is no "7-day streak" badge anywhere.
- **Fix:** (a) Surface the active streak in `CoachGreetingView` as a small chip ("7-day streak"). (b) Schedule a 9pm notification on day-of-streak when no Watch activity has been logged: "Wear your watch tonight to keep your 7-day streak". (c) Add a confirm dialog when a user has not logged for 23+ hours: "Don't lose your 14-day streak — log a quick journal entry?". This is a bog-standard retention pattern; the data is already there.
- **Priority:** This Month — retention.
- **Confidence:** 88/100 — verified definitions and absence on Home; not yet runtime-tested for what GamificationEngine actually emits to subscribers.

---

## F37. Home has no daily-ritual moment. Whoop's "5-min daily reveal" loop is structurally absent — Recovery score appears the moment the user opens the app, no anticipation, no ceremony

- **Severity:** Medium
- **Issue:** Whoop's product design is built around a deliberate morning "score reveal" — a brief animated unveiling that turns checking your score into a daily ritual. Laso has the components (`firstLaunchLoadingView` with phase animation, `RecoveryHeroCard` with `appeared`/`pulse` `@State`) but the score is rendered immediately on every Home appearance. There is no morning-reveal lock, no "your score for today is ready — tap to reveal", no consent moment. Once a day, the first appearance of the recovery score should feel different from the 14th appearance. Currently they are identical.
- **Why this exists:** Engineering optimised for "show data fast"; product never staged a daily reveal.
- **Impact:** Loss of the single most powerful daily-engagement mechanic in the category. Users habituate to "open app, see number" — there is no emotional spike, no reason to come back unless something acute is happening.
- **Evidence:**
  - `Modules/Dashboard/Views/Home/HomeView.swift:231-388` — Recovery card appears unconditionally.
  - No `dailyRevealCompleted` UserDefault key in `AppKeys` (grep returns no matches).
  - `Core/Notifications/EngagementSequenceScheduler.swift` — fires once on first score, never on day-N reveal.
- **Verify fast:** Open the app at 7am. The score is just there. Open it at 7:01. Same.
- **Fix:** Once per day on the first foreground after `wakeUpTime`, gate the Recovery hero behind a 1.2-second tap-to-reveal animation: subdued ring → score reveals → dayType label slides in. Use `AppKeys.Engagement.dailyRevealLastShown`. Pair with a 7am morning notification "Your recovery score is ready". This is the daily-ritual loop; cheap to ship, high retention impact.
- **Priority:** This Month — category-level retention design.
- **Confidence:** 80/100 — competitor-pattern argument is strong; runtime impact is empirical.

---

## F38. No quick actions on the app icon (3D-touch / long-press). No alternate app icons. Info.plist is bare

- **Severity:** Low
- **Issue:** `Info.plist` (`/Users/primetrace/Desktop/RnD/HealthPulse/Info.plist:1-56`) defines NSHealthShareUsageDescription, NSSiriUsageDescription, BGTaskSchedulerPermittedIdentifiers, Live Activities, but: (a) no `UIApplicationShortcutItems` array — no long-press home-screen quick actions, (b) no `CFBundleIcons / CFBundleAlternateIcons` — no alternate icon support. Long-press the Laso icon today and you get the standard "Edit Home Screen / Remove App / Share" sheet. Competing apps (Strava, Whoop, Oura, Apple Fitness) all expose at least "Log workout" / "Today" / "Sleep" as long-press shortcuts. Alternate icons are also a common Pro-tier perk that Laso doesn't ship.
- **Why this exists:** Standard Xcode template ships neither.
- **Impact:** Power-user friction (one tap saved per session is high-leverage). Conversion delta on alternate icons (small but compounds — Pro users feel rewarded).
- **Evidence:**
  - `Info.plist:1-56` — no `UIApplicationShortcutItems`, no `CFBundleAlternateIcons`.
  - Grep `UIApplicationShortcut\|setAlternateIconName\|alternateIcon` → zero matches.
- **Verify fast:** Long-press the app icon on a device. Standard menu only.
- **Fix:** (a) Add 3 quick actions: "Today's Score" → Home, "Log entry" → JournalEntry sheet, "Vitals" → Live tab. (b) Ship 3 alternate icons (Light, Dark, Pro-gradient) — wire `setAlternateIconName(_:)` in a Settings → Appearance row, gate non-Light variants behind `FeatureGate.hasFullAccess`.
- **Priority:** This Month — polish + Pro-tier perk.
- **Confidence:** 95/100 — Info.plist read end to end.

---

## F39. Live Activity has tappable AppIntent buttons (CoachBreatheIntent, CoachWindDownIntent, CoachSetIntentionIntent) but the lock-screen view itself has no deep-link to a specific in-app destination — tap routes to root

- **Severity:** Low
- **Issue:** `TodayScoreLiveActivityWidget` renders a rich lock-screen view + Dynamic Island with action bar buttons that fire `AppIntent`s (LiveView.swift:271-305). However the **lock-screen container view** itself has no `.widgetURL(URL(string: "laso://home/score"))` modifier — when the user taps anywhere outside the action buttons they are dropped into the app at whatever tab/path was last selected (and per F32 that is always Home). There is no deep-link to "open the score breakdown" or "open recovery detail" on tap. Same pattern in BreathworkLiveActivityWidget and WindDownLiveActivityWidget — the AppIntent buttons work, but a tap on the rest of the surface is ambiguous.
- **Why this exists:** AppIntent pattern was implemented for the action buttons; deep-link via `widgetURL` was missed.
- **Impact:** A user who taps the score-shaped pixel on the lock screen expecting "open my score" gets dropped into an arbitrary app state. Confusion, especially when paired with F32 (no tab persistence).
- **Evidence:**
  - `LasoWidgets/TodayScoreLiveActivityWidget.swift:8-49` — no `.widgetURL` on the lock-screen view.
  - `LasoWidgets/BreathworkLiveActivityWidget.swift:1-100` — same gap.
  - Repo-wide grep `widgetURL` → zero matches.
- **Verify fast:** Trigger the today-score Live Activity, lock the device, tap the score (not the breathe button). App opens to whichever tab was last on, not specifically the score detail.
- **Fix:** Wrap the lock-screen view body in `.widgetURL(URL(string: "laso://route/recovery"))`. Wire `onOpenURL` in `LasoApp` to push `Route.recoveryDetail` onto `homePath`. Same for Breathwork → `laso://route/breathwork-session`, WindDown → `laso://route/windDown`.
- **Priority:** This Month — depth-of-engagement lever.
- **Confidence:** 92/100 — file-grep verified.

---

## F40. Onboarding "About You" age input is a numeric TextField, not a wheel/picker — risk of typos, no birth-year clarity, age 13 GDPR-K boundary not enforced explicitly

- **Severity:** Medium
- **Issue:** `ProfileCaptureView` collects age as a free-text numeric `TextField` with `keyboardType(.numberPad)` and validates `value >= 13, value <= 120` (`Modules/Onboarding/Views/Onboarding/ProfileCaptureView.swift:10-22, 59-65`). This means: (a) a user fat-fingers "82" instead of "28" and there is no upstream UX safeguard, (b) the under-13 boundary is GDPR/COPPA-relevant and is enforced via a silent error message ("Enter a valid age between 13 and 120") rather than a clear "Sorry, Laso is for ages 13+" route, (c) for under-16 users in EU markets there's no DPDP/GDPR-K parental-consent flow. Date-of-birth wheel pickers (Apple Health uses one) prevent typos AND give the app a real DOB which is more useful for cohort analysis than self-reported age. The `saveUserProfile` then back-derives a synthetic DOB by subtracting the integer age from today (`OnboardingView.swift:158-163`) — losing the actual birth-month/year fidelity.
- **Why this exists:** "Less friction = a number field". Wheel pickers are heavier UX but more correct for this data class.
- **Impact:** (a) Age-reported-as-82 users get scored against a population baseline that is wildly wrong. (b) GDPR-K under-16 onboarding is a legal exposure in EU/UK markets. (c) Birthday-cake / birthday-themed retention triggers cannot be built on a synthetic DOB.
- **Evidence:**
  - `Modules/Onboarding/Views/Onboarding/ProfileCaptureView.swift:10, 16-22, 59-65` — TextField with `>=13, <=120` int validation.
  - `Modules/Onboarding/Views/Onboarding/OnboardingView.swift:158-163` — synthetic DOB derivation.
  - `Modules/Onboarding/Copy+Onboarding.swift:18` — error copy "Enter a valid age between 13 and 120."
  - Grep `under.*13\|GDPR-K\|parentalConsent\|underage` → zero matches.
- **Verify fast:** Onboard with age "12" — see error and retry. Onboard with "150" — same error. Onboard with "82" instead of "28" — silently accepted.
- **Fix:** (a) Replace TextField with a `DatePicker(selection: $birthDate, in: ...minDate, displayedComponents: .date).datePickerStyle(.wheel)`. (b) On <13 result, route to a polite "Laso requires age 13+" terminal screen with parental-account contact link, NOT inline error. (c) For 13-15 in EU storefronts, add a parental-consent confirmation step. (d) Persist actual DOB. Use age-derivation in viewmodels where age is needed.
- **Priority:** This Week — legal + scoring-credibility.
- **Confidence:** 90/100 — code verified; the EU-storefront detection logic does not exist anywhere yet, so adding the gate is a green-field change.

---

## F41. Onboarding has no back button. Once you advance past Profile you cannot fix a wrong age or gender without restarting from `pulse`

- **Severity:** Medium
- **Issue:** `OnboardingView.body` uses a `TabView(selection: $currentStep)` with `.scrollDisabled(true)` (`OnboardingView.swift:38-78`). There is no toolbar back button, no swipe gesture, no `previous()` action — only forward `advance(to:)` calls from each step's continue button. Once a user enters a wrong age in `ProfileCaptureView` and taps Continue, they cannot return to fix it. The only "undo" is to force-quit and reinstall (which resets the install-trial — not a reasonable ask). `OnboardingMirrorMomentStep` has a "Skip Mirror" but not "Back". The Pulse step has no progress indicator either (Pass 1 F28) and no back is the bigger usability gap.
- **Why this exists:** "Linear forward-only flow" was the redesign intent. Defensible for emotional moments but wrong for data capture.
- **Impact:** A user who realises in Mirror Moment that they entered wrong gender (changing scoring assumptions) cannot fix it. Either drops off or finishes onboarding with corrupt profile data, then hunts for a Profile-edit screen — which doesn't exist (Pass 1 F30).
- **Evidence:**
  - `Modules/Onboarding/Views/Onboarding/OnboardingView.swift:38-78` — TabView, scrollDisabled, no back action.
  - Grep `previousStep\|onBack\|navigateBack` in `Modules/Onboarding` → zero matches.
- **Verify fast:** Enter wrong age, advance to Connect step. There is no way back.
- **Fix:** Add a toolbar/leading "Back" chevron in steps 2–5 (not step 1; not step 6 since promise is terminal). On tap call `advance(to: previousStep)`. Track in analytics so back-presses become a signal of confusing copy. Combine with F30 (add a Profile-edit Settings row) so post-onboarding fixes are also possible.
- **Priority:** This Week — data-correctness.
- **Confidence:** 92/100 — verified by reading.

---

## F42. Settings has no in-Settings search. With ~25+ rows across 7 sections, finding a specific toggle (e.g., "Critical Alerts", "Daily Summary", "Privacy Lock") requires linear scroll

- **Severity:** Low
- **Issue:** `SettingsView.body` lists 7+ sections (profile, subscription, notifications, devices, data, support, danger zone) without a `.searchable` modifier. iOS 18 ships `.searchable(text:placement:)` natively and Apple's own Settings app offers search. Repo-wide grep `searchable` returns zero matches (the keychain/SubscriptionManager `searchQuery` hits are unrelated). Power users who want to flip "Watch Not Worn Reminder" need to scroll through Profile, Subscription, Notifications, Devices to find it.
- **Why this exists:** Settings was built when the row count was small.
- **Impact:** Search-shaped friction. Particularly bad given the Settings → Notifications subtree depth (per Pass 1 F1, the toggles are also dead until permission is granted — finding a needle in a haystack of mostly-broken needles).
- **Evidence:**
  - `Modules/Settings/Views/SettingsView.swift:83-130` — NavigationStack with deepLinkPath, no searchable.
  - Grep `\.searchable` → zero matches.
- **Verify fast:** Open Settings, attempt to pull-down for search bar. Nothing.
- **Fix:** Add `.searchable(text: $settingsQuery, placement: .navigationBarDrawer)` and filter visible rows by title-substring match. iOS 18 free upgrade.
- **Priority:** This Month — power-user QoL.
- **Confidence:** 88/100 — verified by grep.

---

## F43. Paywall has no "Apply Promo Code" or "Redeem Offer" affordance. StoreKit 2's `presentCodeRedemptionSheet` is never invoked. Marketing offer codes (and App Store offer codes) cannot be redeemed in app

- **Severity:** Medium
- **Issue:** `PaywallView` (`Modules/Paywall/Views/Subscription/PaywallView.swift:100-358`) lists features, pricing, subscribe, restore, retry-load, T&C / privacy links. There is no "Have a code? Redeem" row. Repo-wide grep `presentCodeRedemptionSheet\|offerCode\|promoCode` returns zero matches. App Store Connect supports custom offer codes for retention/win-back; without the in-app redemption sheet, Marketing cannot run an offer-code campaign without the user manually typing the code into the App Store app. Combined with the dead Referral system (Pass 1 F4), there is no in-app discount surface at all.
- **Why this exists:** v1 ship; offer codes are a launch+1 feature.
- **Impact:** Marketing channel for win-back, "first month free" coupons, and influencer partnerships is structurally absent. Every code sent in a campaign suffers the App Store extra-clicks-to-redeem leakage.
- **Evidence:**
  - `Modules/Paywall/Views/Subscription/PaywallView.swift:100-358` — no redeem CTA.
  - Grep `presentCodeRedemptionSheet\|offerCode` → zero matches.
- **Verify fast:** Open Paywall. There is no "Have a code?" link.
- **Fix:** Add a single text-link below the secondary actions: `Button("Have an offer code?") { SKPaymentQueue.default().presentCodeRedemptionSheet() }`. iOS 14+. 5 lines.
- **Priority:** This Month — marketing flexibility.
- **Confidence:** 92/100 — file read + grep verified.

---

## F44. Brain Health is purely passive. No cognitive task, no n-back, no reaction-time test, no daily quiz — yet the module is branded "Cognitive Wellness" implying active assessment

- **Severity:** Medium
- **Issue:** `BrainHealthDetailView` renders a hero score, weekly chart, top drivers, and a "learn more" disclosure (`Modules/BrainHealth/Views/BrainHealth/BrainHealthDetailView.swift:14-36`). The score derives from passive sleep / HRV / circadian metrics (`BrainHealthScorer.swift`). There is **no interactive cognitive task** anywhere — no reaction-time test, n-back, Stroop, simple-recall quiz. Yet the module is branded "Cognitive Wellness" (`Copy+BrainHealth.swift:8`) implying ongoing active assessment. Competitor positioning: Apple Mindfulness, Headspace, Lumosity, MindLabs all combine passive signals with at least one interactive measure. Without any active task the credibility ceiling on the score is low — it's a derivative of metrics already shown elsewhere in Sleep + Recovery.
- **Why this exists:** BrainHealthScorer was scoped as a derived score; no interactive layer was built.
- **Impact:** "Cognitive Wellness" branding writes a check the implementation cannot cash. App Review can question medical-claim adjacency on a metric that has no behavioural validation. Engagement on the module is shallow because there is nothing to do.
- **Evidence:**
  - `Modules/BrainHealth/Views/BrainHealth/BrainHealthDetailView.swift:14-36` — passive layout only.
  - `Core/Analysis/BrainHealthScorer.swift` — uses sleep, HRV, circadian inputs.
  - Grep `cognitiveTask\|reactionTime\|n-back\|stroop\|interactiveTest` → zero matches.
- **Verify fast:** Open Brain Health detail. There is no "Take today's quick test" CTA.
- **Fix:** Either (a) rename the module to "Cognitive Recovery" and de-emphasize the active-assessment connotation, OR (b) ship a 30-second daily simple-reaction-time test (single Button, measure tap latency vs visual cue, 5 trials, log mean RT). Even a primitive RT test gives the module behavioural validation and a daily-action surface the current view lacks. Existing analytics already have a `reactionTimeSec` field (`AppAnalytics.swift:2433`) — confirms the measurement pattern is partly thought through.
- **Priority:** This Month — brand-credibility + engagement.
- **Confidence:** 86/100 — verified by reading the view + scorer; the existing `reactionTimeSec` analytics field strongly suggests a quiz was planned and dropped.

---

## F45. No data-freshness indicator on Insights / Weekly Review / detail screens. Recovery has one (Pass 1 noticed); everything else does not. Users cannot tell when the analysis they're reading was computed

- **Severity:** Medium
- **Issue:** `RecoveryHeroCard` shows a "Right now" pulse + an "Updated X ago" badge when stale (`Modules/Dashboard/Views/Home/RecoveryHeroCard.swift:62-149`). Excellent. But `InsightsDetailView`, `WeeklyReviewView`, `BrainHealthDetailView`, `VitalityDetailView`, `StressDetailView`, `StrainDetailView`, `HealthRiskDetailView` — none surface "as-of" time. A user reading "Sleep was short last night — push hard today" has no idea whether the engine ran 30 seconds ago or 6 hours ago against stale data. The internal `lastUpdate`, `lastUpdated`, `lastSync` exist (HealthScorer.swift:269 talks about freshness factor, BaselineCalculator.swift:37 uses `daysSinceUpdate`) but the UI surface for the user is missing on every non-Home screen.
- **Why this exists:** Recovery was prioritised; other detail screens were not retrofitted.
- **Impact:** Trust gap — "is this still accurate?" anxiety on advice screens. Apple App Review may also flag risk-claim screens that are computed but not timestamped.
- **Evidence:**
  - `Modules/Dashboard/Views/Home/RecoveryHeroCard.swift:62-149` — has staleness badge.
  - `Modules/Insights/Views/Insights/InsightsDetailView.swift:75-145` — no staleness UI.
  - `Modules/Risk/Views/Risk/HealthRiskDetailView.swift:34-90` — no staleness UI.
  - `Modules/Dashboard/Views/Home/WeeklyReviewView.swift` — no staleness UI.
- **Verify fast:** Open Insights, then Risk, then Weekly Review. None show a "last updated" line.
- **Fix:** Standardise a `LastUpdatedBadge(time: Date)` component used by Recovery and add it as a footer to every analysis-driven detail screen. Format: "Last analysed 2 min ago" / "Last analysed yesterday at 4:12 PM". Also surface a "Force re-analyse" affordance for power users when staleness > 6 hours, gated to avoid abuse.
- **Priority:** This Week — universal trust signal.
- **Confidence:** 90/100 — surveyed primary surfaces; not exhaustively read every detail variant.

---

## F46. Color-only signaling on score badges and risk severities. Red/yellow/green is the sole encoding — no icons, shapes, or labels for color-blind users beyond the text label which is hidden behind an accessibility-only path

- **Severity:** Medium
- **Issue:** `AppColour.scoreOptimal` (#10B981 green), `scorePoor` (red), `scoreSuboptimal` (yellow/orange) are used across Recovery hero, Brain Health, Vitality, Strain, Risk, Sleep cards as the primary severity signal. A red protanopic user reading the Recovery hero sees a desaturated indistinct ring with a number — the day-type pill colour blends with the background. The accessibility label is verbose (`RecoveryHeroCard.swift:175 "Recovery score 82. Fully Recovered. ..."`) but VoiceOver-only — sighted color-blind users get no compensating shape/icon encoding. Risk module's `RiskFactorStatus.critical` (red) suffers the same gap — no icon-shape doubling.
- **Why this exists:** Color-coding is the design-system default; shape/icon doubling was not adopted.
- **Impact:** ~8% of male users have some form of red-green CVD. Score legibility is reduced for them. Apple's Accessibility guidelines (and the reviewer audit checklist) call this out.
- **Evidence:**
  - `Common/Theme/AppColour.swift:93` — scoreOptimal #10B981 green.
  - `Modules/Dashboard/Views/Home/RecoveryHeroCard.swift:128-131` — day-type pill uses `scoreColor` only, no icon.
  - `Modules/Risk/Views/Risk/HealthRiskDetailView.swift:149-200` — factor row colored by status, no icon doubling.
  - Grep `colorBlind\|differentiate.*color\|.colorBlind` → zero matches.
- **Verify fast:** Enable iOS Settings → Accessibility → Display & Text Size → Color Filters → Greyscale. Open Home. Day-type pill, score ring, and pricing badge all collapse to the same value.
- **Fix:** Double-encode every color-meaningful element: green-check icon for optimal, dot-icon for moderate, exclamation for poor; or use shape (filled circle / hollow / triangle). Add `.symbolVariant(.fill)` and `.foregroundStyle(.tint)` consistently. Same for risk badges. Test under iOS Color Filters → Tritanopia, Deuteranopia, Protanopia.
- **Priority:** This Month — accessibility + App Review.
- **Confidence:** 86/100 — verified primary surfaces; not every score color path was traced.

---

## F47. No first-run TipKit / coachmark layer. iOS 17's `Tip` API is not used at all, and there is no in-house tooltip system

- **Severity:** Medium
- **Issue:** Repo-wide grep `TipKit\|popoverTip\|Tip\b` produces only an unrelated `siriTip` UserDefaults key in Settings + the SleepCoach's local SleepTip struct (which is a different concept — a list of tips, not an interactive coachmark). Apple's TipKit framework (`import TipKit`, `Tip` protocol) is the standard iOS 17+ first-run education layer — Laso uses iOS 17+ but never adopts it. The Recovery hero's "Tap to understand score" footer (`RecoveryHeroCard.swift:156-162`) is permanent text not a tip, so it does not retire after first use.
- **Why this exists:** TipKit was new at the time of build; the team never adopted it.
- **Impact:** First-time users encountering "Cognitive Wellness", "Vitality Age", "Strain of 21" get no coachmark explaining what those numbers mean. Pass 1 F25 noted the jargon; this is its UX-layer corollary — even if copy were clearer, the first-touch education layer is missing.
- **Evidence:**
  - Grep `TipKit\|popoverTip\|TipsCenter` → zero matches.
  - `Core/Config/AppKeys.swift:112` — single `siriTip` dismissal key (manual).
  - `Modules/Dashboard/Views/Home/RecoveryHeroCard.swift:156-162` — permanent text affordance.
- **Verify fast:** Fresh install, complete onboarding, open Home. No popover tooltips appear over any score.
- **Fix:** Adopt TipKit. Define 6-8 tips (`RecoveryScoreTip`, `StrainOf21Tip`, `VitalityAgeTip`, `BrainHealthScoreTip`, `JournalEntryTip`, `RefreshGestureTip`, `CycleHistoryTip`, `HRVMeaningTip`). Apply via `.popoverTip(_:)` on each hero element. TipKit handles the once-per-user logic plus invalidation rules. ~2 days work; high comprehension uplift.
- **Priority:** This Month — first-week comprehension.
- **Confidence:** 95/100 — grep exhaustive.

---

## F48. Sheet vs full-screen-cover decisions are inconsistent. Onboarding (immersive) uses .interactiveDismissDisabled but is not a fullScreenCover. Disclaimer and Compromised env are fullScreenCover. Paywall is fullScreenCover. There's no documented rule

- **Severity:** Low
- **Issue:** Catalog of presentation choices reveals the inconsistency:
  - `OnboardingView` is a regular root view in LasoApp gating, but uses `.interactiveDismissDisabled()` (`OnboardingView.swift:97`) — defensive coding for a flow that wouldn't be dismissable anyway.
  - `MedicalDisclaimerView` is a fullScreenCover with `.interactiveDismissDisabled()` (`Common/Components/MedicalDisclaimerView.swift:54`).
  - `CompromisedEnvironmentView` is a fullScreenCover with `.interactiveDismissDisabled()`.
  - `DiscoveryView` is a fullScreenCover (HomeView.swift:49) with `.interactiveDismissDisabled()` — but also has its own X-close button.
  - `PaywallView` is a fullScreenCover (LasoApp.swift:118) with `.interactiveDismissDisabled()` — and NO close button (Pass 1 F7).
  - `InsightsDetailView`'s aha-paywall is a fullScreenCover with no `.interactiveDismissDisabled` on the inner — relies on container semantics (Pass 1 F6).
  - `JournalEntryView` is a regular sheet with no dismiss-disable (per F33 above).
  - `MetricLogSheet` is a sheet with `.presentationDetents([.medium])`.
  - `TodayBriefingView` is a sheet with `.presentationDetents([.medium, .large])` + drag indicator.

  No documented rule for when fullScreenCover vs sheet vs in-place push. Some "cannot escape" surfaces (Onboarding) are in-place; some non-escape surfaces (Disclaimer) are fullScreenCover.
- **Why this exists:** Per-view decisions accumulated organically.
- **Impact:** UX feels patchwork. Reviewers and users notice slightly different swipe-down behaviours between similar-looking screens.
- **Evidence:** All cited files above.
- **Verify fast:** Open each, attempt swipe-down. Behaviour varies.
- **Fix:** Document a rule in CLAUDE.md or a design.md: "fullScreenCover for legal/blocking flows; sheet for review/cancel-friendly content; in-place push for onboarding-style step flows". Audit every presentation in the app against this rule.
- **Priority:** Backlog — codebase hygiene.
- **Confidence:** 90/100 — catalog verified.

---

## F49. No skeleton placeholders inside Home cards. DSSkeleton component exists but is referenced only in its own definition file — no Home/Live/Insights surface uses it

- **Severity:** Low (extends Pass 1 F23 which catalogued the inconsistency. This finding is the deeper detail — the in-house skeleton DSSkeleton EXISTS but is unused)
- **Issue:** `Common/Components/DSSkeleton.swift:5-40` defines `DSSkeleton` and `DSSkeletonCard` — full-width shimmer placeholder. Repo-wide grep `DSSkeleton` returns only the file itself. Zero call sites in any view. Meanwhile every loading surface in Home, Live, Insights uses either `LoadingView(message:)` or raw `ProgressView()`. The skeleton-shimmer pattern that the app already pays the cost to define is unused.
- **Why this exists:** Component built, never adopted. Common pattern when design-system work outpaces feature integration.
- **Impact:** Wasted code + worse loading UX than achievable.
- **Evidence:**
  - `Common/Components/DSSkeleton.swift:1-40` — definition only.
  - Grep `DSSkeleton` → only the definition file.
- **Verify fast:** Throttle network. Watch loaders. ProgressView spinners only.
- **Fix:** Replace `LoadingView` and `ProgressView` placeholders on Home cards with `DSSkeletonCard` matching real card heights. ~30 minute change.
- **Priority:** Backlog — polish.
- **Confidence:** 96/100 — grep exhaustive.

---

## F50. Number formatting drift. `String(format: "%.1f", ...)` is sprinkled across analyzers + insight/recommendation strings; no central HealthMetric formatter is enforced — same metric reads "65.5 kg" in one card and "65.5" or "66" elsewhere

- **Severity:** Low
- **Issue:** Repo-wide grep for `String(format: "%.1f"` and `"%.0f"` returns 100+ hits across SleepPerformanceAnalyzer, WeeklyPatternAnalyzer, PersonalRecordAnalyzer, IllnessEarlyWarning, HealthRiskEngine, MultiMetricClusterAnalyzer, DiscoveryEngine, WorkoutEffectivenessAnalyzer, etc. The unit (kg, bpm, %) is inlined inconsistently. There is a `metric.formatWithUnit(value)` helper used in WeeklyPatternAnalyzer:76 — but most analyzer/recommendation strings build their own `String(format:)`, dropping the unit and the rounding contract. Same metric appears as "72.0 bpm" in one insight and "72" in another. HealthRiskEngine.swift:227-229 has a tri-branch local rounder. There's no single source of truth.
- **Why this exists:** Each analyzer was authored separately; no per-metric formatter contract was enforced.
- **Impact:** Inconsistent presentation hurts perceived quality. A user comparing two cards on the same metric sees different precision and reads it as "the app contradicts itself".
- **Evidence:**
  - `Core/Analysis/HealthRiskEngine.swift:227-229` — local rounding rules.
  - `Core/Analysis/SleepPerformanceAnalyzer.swift:67-68, 136-137, 193-218` — many ad-hoc `%.0f` / `%.1f`.
  - `Core/Analysis/WeeklyPatternAnalyzer.swift:76, 149-205` — mix of `metric.formatWithUnit()` AND `String(format: ...)` in adjacent lines.
  - `Core/Models/HealthMetric.swift` (assumed location of `formatWithUnit`) — formatter exists but not universally adopted.
- **Verify fast:** Grep `String(format: "%."` — 100+ scattered hits.
- **Fix:** Make `HealthMetric.format(_:precision:)` and `HealthMetric.formatWithUnit(_:)` mandatory. Replace every `String(format: "%.1f", value)` adjacent to a metric value with `metric.format(value)`. Lint via SwiftLint custom rule that flags `String(format:` containing `%.\\df` near a HealthMetric type.
- **Priority:** Backlog — polish + analytics consistency.
- **Confidence:** 86/100 — grep gives the volume; not every site was hand-traced.

---

## F51. Force-update view points to manage-subscriptions URL on update tap — wrong URL, wrong action. Should open the App Store product page

- **Severity:** Medium
- **Issue:** `ForceUpdateView` (`Common/Components/ForceUpdateView.swift:23`) opens `AppSecrets.URLs.manageSubscriptions = "https://apps.apple.com/account/subscriptions"`. That URL takes the user to Apple ID → Subscriptions, not to the Laso App Store product page where the update button lives. A force-update flow's CTA must take the user to the App Store install/update sheet for THIS app — typical URL is `itms-apps://itunes.apple.com/app/idXXXXXXXXX` or `https://apps.apple.com/app/idXXXXXXXXX`. Opening the subscription page instead means the user lands somewhere unrelated, gets confused, and may re-download a stale build by guessing.
- **Why this exists:** Cut-and-paste reuse of the manage-subscriptions URL constant (the only `apps.apple.com` URL defined in `AppSecrets`). The correct app-product-page URL was never added.
- **Impact:** Force-update flows fail. Users on a deprecated build cannot self-rescue. Critical for any release that needs a hotfix push.
- **Evidence:**
  - `Common/Components/ForceUpdateView.swift:23` — opens `AppSecrets.URLs.manageSubscriptions`.
  - `Core/Config/AppSecrets.swift:56` — only this single Apple URL defined.
  - Grep `itms-apps\|apps.apple.com/app/` → zero matches.
- **Verify fast:** Trigger ForceUpdateView (force the version-check to fail), tap Update. Subscription management page loads.
- **Fix:** Add `AppSecrets.URLs.appStoreProductPage = "https://apps.apple.com/app/id<ID>"` and an itms-apps variant. Open the itms-apps URL via UIApplication, fall back to https. Wire ForceUpdateView's button to this constant.
- **Priority:** Now — release-safety.
- **Confidence:** 95/100 — code path read end to end.

---

## F52. Onboarding TabView is a `.page` style with `scrollDisabled(true)` — accessibility users navigating via VoiceOver swipe-right can't progress, must hunt for the Continue button on each step

- **Severity:** Low
- **Issue:** `OnboardingView.body` uses `TabView(selection: $currentStep) ... .tabViewStyle(.page(indexDisplayMode: .never)) .scrollDisabled(true)` (`OnboardingView.swift:38, 77-78`). `scrollDisabled(true)` means VoiceOver users who use the standard right-swipe-to-next-element gesture cannot advance the page — they must tab to the on-screen Continue button. For motor-impaired users this is high-friction. For VoiceOver users the ordering is also confusing because TabView's Tab elements are not the standard accessibility interaction model when scrolling is disabled.
- **Why this exists:** `scrollDisabled(true)` was a defence against accidental swipe progression — a real concern, but it sacrificed accessible navigation.
- **Impact:** A11y users encounter higher onboarding drop-off. Apple a11y reviewer can flag.
- **Evidence:** `Modules/Onboarding/Views/Onboarding/OnboardingView.swift:38-78`.
- **Verify fast:** Enable VoiceOver, run onboarding. Three-finger right-swipe does nothing.
- **Fix:** Replace TabView+scrollDisabled with a NavigationStack / explicit ZStack switcher driven by `currentStep`. Each step is its own view with proper accessibility focus management on appearance. Continue button gets `.accessibilityHint("Advances to step X")`.
- **Priority:** Backlog — a11y polish.
- **Confidence:** 80/100 — VoiceOver behaviour with scrollDisabled tab pages is documented as an a11y anti-pattern; not explicitly runtime-tested here.

---

## F53. PMFSurveySheet TextField uses `axis: .vertical` for free-text answers but the sheet has no `.scrollDismissesKeyboard` or keyboard-aware padding. On smaller devices (iPhone SE / mini) the keyboard hides the active field

- **Severity:** Low
- **Issue:** `Common/Components/PMFSurveySheet.swift:125, 151, 177` — three vertical-axis TextField inputs for segment / benefit / improvement answers. The sheet uses a regular VStack/ScrollView, no `.scrollDismissesKeyboard(.interactively)` and no keyboard avoidance hints. On iPhone SE 3rd gen and iPhone 13 mini, the keyboard occupies ~⅓ of the viewport. When the user focuses the second or third field, the field can be partially or fully hidden. SwiftUI's automatic keyboard avoidance helps with TextEditor but is unreliable when the parent uses a ScrollView and the field is below the visible area.
- **Why this exists:** Designed on a large device; small-device check skipped.
- **Impact:** Survey-completion drop-off on small devices, exactly the cohort that already has lower screen real estate.
- **Evidence:** `Common/Components/PMFSurveySheet.swift:125, 151, 177`.
- **Verify fast:** Run on iPhone SE simulator. Open PMF survey. Tap the 3rd answer field. Field is hidden by keyboard.
- **Fix:** Wrap in a ScrollView with `.scrollDismissesKeyboard(.interactively)`. On focus change, programmatically scroll the focused field to the visible area using `ScrollViewReader.scrollTo(_:anchor:)`. Same pattern for FeedbackSheet (which uses similar inputs).
- **Priority:** Backlog — small-device polish.
- **Confidence:** 80/100 — verified the inputs; small-device behaviour is well-documented but not runtime-tested here.

---

## F54. Live Activity actions (CoachBreatheIntent, CoachWindDownIntent) fire AppIntents but there is no in-app surface that explains which actions are supported on the Live Activity. First-time users don't know they can act from the lock screen

- **Severity:** Low
- **Issue:** `LiveView.actionButton<I: AppIntent>(...)` (`Modules/Live/Views/Live/LiveView.swift:271-305`) implies the Live Activity in-app surface, but the lock-screen Live Activity itself surfaces these intents (`TodayScoreLiveActivityWidget.swift:33`). Yet there is no in-app coachmark, no Settings → Live Activities row, no "your Live Activity supports breathwork from the lock screen" first-run prompt. The capability exists; users do not learn about it.
- **Why this exists:** Live Activity was implemented, the in-app discovery layer wasn't added.
- **Impact:** A power feature that should drive cross-mode engagement (lock screen tap → in-app session) is unused by users who don't read release notes.
- **Evidence:**
  - `LasoWidgets/TodayScoreLiveActivityWidget.swift:33` — CoachActionBar with intent buttons.
  - `LasoWidgets/BreathworkLiveActivityWidget.swift:5` — full breathwork Live Activity.
  - Grep `Live Activity\|liveActivit` in user-facing copy → minimal hits.
- **Verify fast:** Onboard a new user. Nothing teaches them the Live Activity is interactive.
- **Fix:** First-run TipKit popover after the user has seen the score 3 times: "Start a breathwork session right from your lock screen". Add a Settings → Live Activities & Lock Screen row that explains.
- **Priority:** Backlog — discovery.
- **Confidence:** 85/100 — capability verified by widget read; a comprehensive copy-grep would close the last gap.

---

## F55. Doctor-share / health-records export framing missing entirely. Pass 1 F15 noted WebExport's HTML lacks PDF and disclaimer. The deeper UX gap: there's no "Share with my doctor" entry surface, no PDF, no per-category include/exclude

- **Severity:** Medium (NOT a duplicate of F15. F15 talked about the HTML output. This finding is about the absence of an entry-surface for the doctor-share use case)
- **Issue:** Settings → Data Export generates a generic HTML file via `HTMLReportGenerator`, presented as a `UIActivityViewController` (`Modules/Settings/Views/SettingsView.swift:281-334`). The use case "I want to send my heart rate trend to my cardiologist" has no dedicated surface. There is no "Share with my doctor" button on Risk module screens (where it would matter most). There is no per-metric or per-category include/exclude. The output is HTML, not PDF — most clinicians want PDF. Apple Health Records integration (HKClinicalRecord) is also not surfaced.
- **Why this exists:** Pass-1-style data-export was scoped; the patient-share workflow wasn't specifically designed.
- **Impact:** Users in the Risk module (the most clinically-relevant tab) have no path to share specific findings with a clinician without exporting everything.
- **Evidence:**
  - `Modules/Settings/Views/SettingsView.swift:281-334` — only general export.
  - `Modules/Risk/Views/Risk/HealthRiskDetailView.swift:1-300` — no share-to-doctor button.
  - Grep `HKClinicalRecord\|HealthRecords\|share.*doctor` → zero matches.
- **Verify fast:** Open Risk → Heart Pattern. There's no Share button.
- **Fix:** (a) Add a `Share` toolbar button to HealthRiskDetailView and CategoryDetailView that exports JUST that section as PDF. (b) Rename Settings export to "Share Health Summary" with category checkboxes. (c) Add a Settings → Apple Health → Health Records hand-off link. (d) PDF as primary format, HTML fallback.
- **Priority:** This Month — clinical-utility positioning.
- **Confidence:** 88/100 — file-grep verified; not yet runtime-tested for clinician workflow.

---

## Summary table

| ID  | Severity | Theme | Headline | Priority |
|-----|----------|-------|----------|----------|
| F31 | High | Refresh affordance | Pull-to-refresh on 3/13 surfaces; Live tab worst | This Week |
| F32 | Medium | Tab persistence | Selected tab + nav paths reset every cold launch | This Month |
| F33 | High | Sheet data loss | Journal/MetricLog/AskYourData lose typed input on swipe-down | Now |
| F34 | Medium | Empty charts | "Not Enough Data" hard-fails under 2 points, no fallback | This Week |
| F35 | Medium | Cycle UX | Hard countdown number, no probability band | This Month |
| F36 | Medium | Streaks | Streak compute exists; never surfaced on Home; no loss-aversion | This Month |
| F37 | Medium | Daily ritual | No score-reveal moment; no ceremony loop | This Month |
| F38 | Low | Quick actions | No 3D-touch shortcuts; no alternate icons | This Month |
| F39 | Low | Live Activity link | No widgetURL on lock-screen view; tap routes to root | This Month |
| F40 | Medium | Age input | TextField, not DatePicker; no GDPR-K under-16 flow | This Week |
| F41 | Medium | Onboarding back | No back action between steps; can't fix wrong age | This Week |
| F42 | Low | Settings search | No .searchable in Settings; 25+ rows | This Month |
| F43 | Medium | Promo code | No StoreKit code-redemption sheet on Paywall | This Month |
| F44 | Medium | Brain Health | Branded "Cognitive Wellness", no interactive task | This Month |
| F45 | Medium | Freshness | "Last analysed" badge only on Recovery, missing elsewhere | This Week |
| F46 | Medium | Color blindness | Color-only severity encoding; no shape/icon doubling | This Month |
| F47 | Medium | TipKit / coachmarks | Zero TipKit adoption; no first-run education | This Month |
| F48 | Low | Sheet vs cover | Inconsistent presentation choices; no documented rule | Backlog |
| F49 | Low | Skeleton | DSSkeleton defined, never used in any view | Backlog |
| F50 | Low | Number format | 100+ ad-hoc String(format:) sites; metric formatter not enforced | Backlog |
| F51 | Medium | Force update | Update CTA opens manage-subs URL, not App Store | Now |
| F52 | Low | Onboarding a11y | scrollDisabled TabView blocks VoiceOver swipe-right | Backlog |
| F53 | Low | Keyboard avoid | PMF survey fields hidden by keyboard on small devices | Backlog |
| F54 | Low | Live Activity discovery | Lock-screen actions exist, no in-app teach | Backlog |
| F55 | Medium | Doctor share | No dedicated share-to-doctor entry; no PDF; no per-category | This Month |

---

## Top 3 Now (act before TestFlight wider rollout)

1. **F33 — Sheet data loss on JournalEntry / MetricLog / AskYourData.** Silent data loss on accidental swipe-down breaks the trust loop the app is built on. 30 lines per file, very high ROI.
2. **F51 — ForceUpdateView opens the wrong URL.** Release-safety blocker. Any hotfix push will fail to route users to the actual update.
3. **F31 — Pull-to-refresh on Live tab and 9+ other surfaces.** Universal iOS expectation; without it the Live tab in particular feels broken when Watch background-delivery throttles.

---

## What this Pass deliberately did NOT cover (already in Pass 1 / out of scope)

- Notification permission request gap (Pass 1 F1)
- Delete-account / Firebase residual (F2)
- Onboarding length / no body capture (F3) and progress hint missing (F28)
- Referral / Achievements / Discovery dead-code (F4, F5, F13)
- Aha-paywall on view-appear, no Maybe-Later (F6, F7)
- Cycle no opt-in copy (F8) — covered. F35 is about prediction confidence range, distinct.
- Journal biometric lock (F9)
- Live tab name ambiguity (F10)
- Risk Critical badge medical-claim (F11)
- Briefing copy predictions (F12)
- Devices troubleshooting (F14)
- WebExport HTML disclaimer (F15) — F55 is about the missing entry-surface, distinct.
- Score-name overlap (F16)
- Cold-start zero-data UX (F17)
- Two-trial pricing (F18), paywall trust signals (F19)
- AskYourData "Concierge" framing (F20)
- Email/identity capture (F21)
- Home CTA hierarchy (F22)
- Loading idiom inconsistency (F23) — F49 is the deeper "DSSkeleton unused" finding, distinct.
- Error states (F24)
- Reading-level / jargon (F25)
- Empty-state CTAs (F26)
- Billing grace banner timing (F27)
- Strain/Stress narrative overlap (F29)
- Profile module hygiene (F30)
- Auth, performance, color/typography systems, admin-panel, third-party SDK exposure, analytics taxonomy.

---
