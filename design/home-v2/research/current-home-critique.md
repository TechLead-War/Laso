# Laso Home Screen — Brutal Audit (current state)

Audit date: 2026-07-29. Source of truth: code read in this session, not memory.

Files read in full:
`Modules/Dashboard/Views/Home/HomeView.swift` (1205 lines), `RecoveryHeroCard.swift`,
`CoachGreetingView.swift`, `LifeContextChipRow.swift`, `DailyActionResultCard.swift`,
`SleepBankCard.swift`, `DataCoverageCard.swift`, `ActivationProgressBanner.swift`
(also contains `AskYourDataCard`), `MorningCheckInView.swift`, `WatchComplicationCard.swift`,
`AskYourDataView.swift`, `MetricStripView.swift`, `PersonalHealthForecastCard.swift`,
`HomeConnectHealthView.swift`, `WeeklyReviewView.swift` (entry card),
`Common/Copy/Copy+Home.swift` (674 lines), `Modules/Dashboard/ViewModels/DashboardViewModel.swift`
(targeted reads), `DashboardSmartActionAdvisor.swift`, `DashboardDerivedStateBuilder.swift`,
`Common/Components/DesignSystem.swift`, `Common/Theme/AppColour.swift`,
plus `LifeContextStore`, `MorningCheckInManager`, `DailyActionResultStore`,
`StreakMilestoneStore`, `ActivationSequenceManager`, `SleepDebtTracker`, `HealthScoreRing`.

---

## 0. The one-line verdict

The Home screen is a **dashboard pretending to be a coach**. It renders up to
18 blocks, ~28 numbers on a plain day and 50+ on a busy one, offers 23+ tap
targets and 15+ navigation destinations, and answers "what should I do next"
three separate times with three answers that can disagree. Most of what is on
screen is instrumentation output — things the team built to prove a subsystem
exists, not things a person needs at 7am.

---

## 1. Render order (ASCII)

```
HomeView.body
 ├─ [state gate] viewModel.ui.isLoading && timeSeries.isEmpty
 │    ├─ isFirstLaunchSync → firstLaunchLoadingView   (pulsing orb + dot ticker @2 Hz)
 │    └─ else              → LoadingView("Analyzing your health data...")
 ├─ [state gate] ui.errorMessage != nil → errorView
 └─ homeContent  ▼

┌──────────────────────────────────────────────────────────────────────┐
│  ScrollView > LazyVStack(spacing: DS.itemSpacing = 12)               │
├──────────────────────────────────────────────────────────────────────┤
│  1. CoachGreetingView                                 ALWAYS         │  L459
│     "Morning, Aman" + "Tuesday, April 26"                            │
│                                                                      │
│  ── branch: shouldShowEmptyState ─────────────────────────────────── │
│     └─ HomeConnectHealthView                          (no data)      │  L462
│  ── branch: hasData ──────────────────────────────────────────────── │
│                                                                      │
│  2. LifeContextChipRow                                ALWAYS         │  L469
│     4 chips (Injured/Unwell/Travelling/Sleeping badly)               │
│     + 0..4 "Still injured? Yes / No, all better" confirm rows        │
│                                                                      │
│  3. DailyActionResultCard              if dailyResult != nil  RARE   │  L479
│     "YESTERDAY'S RESULT · Your recovery is +3 higher this morning."  │
│                                                                      │
│  4. streakMilestoneCard                if milestone != nil  V.RARE   │  L489
│     "STREAK MILESTONE · 7 days in a row"  [Share this][No thanks]    │
│                                                                      │
│  5. primaryActionCard  "NEXT UP · TODAY"              ALWAYS         │  L496
│     title / subtitle / benefit chip  [Mark done][Remind 9:30]        │
│                                                                      │
│  6. RecoveryHeroCard                                  ALWAYS         │  L500
│     ┌ ring 104pt + glow ─┬ WHY list (up to 5 tappable rows) ─┐       │
│     │ "Likely 61 to 77"  │  ● Sleep was short      5h 40m    │       │
│     │ "4 up from yest."  │  ● Heart is calm     12 ms below  │       │
│     │ "Based on 3 of 5"  │  ● Resting HR is up   3 bpm above │       │
│     │ [confidence bar]   │  ● Energy is low     Below usual  │       │
│     └────────────────────┴  ● Stress             None yet ───┘       │
│     "Stress not recorded yet. Wear your watch tonight..."            │
│     ─────────────────────────────────────────────────────            │
│     "About usual today. / A steady day suits you."   [share icon]    │
│                                                                      │
│  7. SleepBankCard                      if debt >= 2h    ~DAILY       │  L558
│     "-3h 20m  [Behind]" + 14-bar chart + payback row                 │
│                                                                      │
│  8. DataCoverageCard                   if any signal = 0  COMMON     │  L567
│     5 rows "12 of 14 days" + hint + [Check Health settings]          │
│                                                                      │
│  9. ActivationProgressBanner           if day <= 7      FIRST WEEK   │  L579
│     "Day 5 of 7. Correlation Found in 2 days"  62%  ● ● ● ● ○ ○ ○ ○  │
│     (+ 4-second auto-dismissing celebration card on top)             │
│                                                                      │
│ 10. MorningCheckInView                 if 5–11am & not done  DAILY   │  L586
│     3 rows × 5 emoji = 15 tap targets  [Done]                        │
│                                                                      │
│ 11. WatchComplicationCard              if paired & not added  ONCE   │  L602
│                                                                      │
│ 12. AskYourDataCard  "CONCIERGE"                      ALWAYS         │  L607
│     italic rotating prompt in a capsule + →                          │
│                                                                      │
│ 13. compactAlertBanner                 if warning || risks   VARIES  │  L630
│     [Worth Noticing ... High >]  + up to 2 risk rows                 │
│                                                                      │
│ 14. sectionHeader("VITALS")                           ALWAYS         │  L633
│ 15. MetricStripView (h-scroll, up to 6 tiles)         ALWAYS         │  L637
│     [Vitality 32][Sleep 7h12m][Strain 14.2][Brain 85][Stress 1.2]    │
│                                                                      │
│ 16. sectionHeader("REVIEW")            if review != nil              │  L654
│ 17. WeeklyReviewEntryCard              if review != nil   WEEKLY+    │  L660
│     "Weekly Review · Score 72 (+4) · 3 wins · target 8,500/day >"    │
│                                                                      │
│ 18. Footer "Updated 3 minutes ago"                    ALWAYS         │  L681
└──────────────────────────────────────────────────────────────────────┘
   safeAreaInset(.bottom): softLockBottomBar   if paywall declined      L699
     "Patterns found in your data: 12"  [Unlock my report]

Sheets / covers hung off this screen:
  DiscoveryView (fullScreenCover) · ScoreGuideSheet · JournalEntryView ·
  PaywallView · RecoveryInfoSheet · ShareWinSheet
```

### Card count for a healthy user with full data

Cards that render unconditionally for a healthy, watch-wearing, day-9+ user:
**greeting, life-context chips, Next Up, Recovery hero, Ask Your Data, VITALS
header, metric strip, REVIEW header, weekly review, footer = 10 blocks.**

Add the realistically-frequent conditionals:
- **Sleep bank**: threshold is `SleepDebtTracker.actionableDebtHours = 2.0` hours
  across a 14-night window — an average shortfall of **8.5 minutes a night**.
  The card's own doc comment says "a balance of eight minutes is not a finding",
  but the threshold it ships with fires for almost everyone. This is daily
  furniture, not a rare card.
- **Data coverage**: fires if any one of sleep / HRV / resting HR / steps /
  blood oxygen has **zero** days in 14. Blood oxygen alone is off by default on
  many watches, so this is common, and it is not soft-locked.
- **Morning check-in**: every morning between 5 and 11am until dismissed.

**Realistic count for the target user on a weekday morning: 13 blocks.**
On day 3 of the first week, with an illness warning and a milestone:
**17 blocks before the footer.**

---

## 2. How many numbers are on screen at once

Counted as distinct numerals a person has to parse, not glyphs.

| Block | Numbers |
|---|---|
| Greeting date | 1 |
| Next Up title/subtitle/benefit/remind time | 2–4 |
| Recovery hero: score, range (2), delta chip, "3 of 5" (2), 5 why-values | 10–12 |
| Sleep bank: balance (2), baseline (2), "14 nights", payback (2), nights recorded, title "14" | 9 |
| Data coverage: 5 × "12 of 14 days" | 10 |
| Activation banner: "Day 5 of 7", "in 2 days", "62%" | 4 |
| Metric strip: 5–6 tiles × value + badge | 8 |
| Weekly review: score, delta, wins, step target | 4 |
| Footer "Updated 3 minutes ago" | 1 |
| Soft-lock bar "Patterns found: 12" | 1 |

**Healthy user, plain morning (10 blocks): ~28 numbers.**
**Same user with sleep bank + coverage + activation: ~51 numbers.**

The Recovery hero card alone puts **10–12 numbers inside one card**, three of
which (`Likely 61 to 77`, `4 up from yesterday`, `Based on 3 of 5 signals`,
plus the coloured confidence bar) are all *meta-commentary about the same
single score*. Four separate renderings of "how much should you trust this
number" sit under one 104pt ring.

---

## 3. Tap targets and navigation destinations

**Tap targets, healthy user, 10-block screen:**
4 chips + 3 on Next Up (card body, Mark done, Remind) + 8 on the hero card
(ring, 5 why rows, summary footer, share icon) + 1 Ask Your Data + 6 metric
tiles + 1 weekly review = **23**, plus pull-to-refresh.

With morning check-in (15 emoji + dismiss + Done = 17), coverage (1),
watch card (1 + steps), alerts (3): **45+ tap targets on one screen.**

**Distinct navigation destinations reachable from Home:**
`Route.todaysAction`, `Route.sleepCoach`, `HealthMetric.heartRateVariability`,
`HealthMetric.restingHeartRate`, `Route.stressMonitor`, `Route.askYourData`,
`Route.insightsDetail`, `risk.riskType` (n types), `Route.vitalityDetail`,
`Route.strainDetail`, `Route.brainHealth`, `Route.cycleDetail`,
`Route.weeklyReview`, iOS Settings (URL), plus 6 sheets/covers
(`ScoreGuideSheet`, `RecoveryInfoSheet`, `ShareWinSheet`, `PaywallView`,
`JournalEntryView`, `DiscoveryView`).
**≈ 15 in-app destinations + 6 modals = 21 exits from one screen.**

A screen with 21 exits has no opinion. It is a menu.

---

## 4. Component-by-component

Format per component: intent → does a user care → action or furniture → trust
→ cognitive load → which of the 5 questions it answers → verdict.

---

### 4.1 CoachGreetingView — "Morning, Aman" + date

1. **Why it exists.** Comment: "matching the Apple-style header the user
   requested." It exists because someone asked for it to look like Apple's
   Fitness header. Name comes from Sign In with Apple.
2. **Does a user care?** No. They know their name, they know it is morning,
   their phone shows the date on the lock screen they just unlocked.
3. **Action or furniture?** Pure furniture. Zero tap targets.
4. **Trust.** Neutral-to-negative. Personalisation theatre is cheap and reads
   as cheap. The class is called `CoachGreetingView` and there is no coaching
   in it — the naming reveals a coach that was designed and then never built.
5. **Cognitive load.** 1 number (date), 0 decisions. But it costs ~60pt of the
   most valuable real estate on the screen, and it renders **above the empty
   state too** (line 459 is outside the `if shouldShowEmptyState` branch), so a
   brand-new user with no data gets "Morning, Aman / Tuesday, April 26" bolted
   on top of "Waiting for data".
6. **Questions answered.** None.
7. **Verdict: CHANGE.** The slot is right; the content is wasted. This is the
   only place on the screen where a single sentence could say what today is
   about. Either it earns its height with a real one-line verdict, or it
   collapses into a 20pt inline date next to the score.

---

### 4.2 LifeContextChipRow — Injured / Unwell / Travelling / Sleeping badly

1. **Why it exists.** Genuinely well-reasoned. Doc comment: the watch cannot
   see a sprained ankle, and without it "a high readiness score produces 'push
   a little harder' to someone who must not." It is a hard override in
   `DashboardSmartActionAdvisor.recommend` rung 0.
2. **Does a user care?** The 5% who are injured or sick care enormously. The
   95% who are fine see four grey capsules asking them to declare a problem
   they do not have, every single day, above the fold.
3. **Action or furniture?** It creates an *input*, not an action. That is the
   wrong direction of flow for the top of a screen a user opens to be told
   something.
4. **Trust.** Builds it when used — it is the only place the app admits its
   sensors have limits. But asking daily and getting "no" daily trains the user
   that the app does not know them.
5. **Cognitive load.** 4 binary decisions offered unprompted, plus up to 4
   confirm rows ("Still injured? Yes / No, all better") every 3 days
   (`LifeContextStore.confirmationInterval = 3 * 24 * 3600`). Worst case: 4
   chips + 4 confirm rows = **12 tap targets before the user has read anything**.
6. **Questions answered.** None. It asks a question, it does not answer one.
7. **Verdict: CHANGE.** Keep the capability, kill the permanent row. This
   belongs behind one affordance ("Something going on?") or, better, triggered
   contextually — offer "unwell?" when resting HR jumps 8% and sleep drops,
   which is exactly when the app already suspects it. Four always-on toggles at
   position 2 is the single clearest sign that this screen was assembled from
   subsystems rather than designed.

---

### 4.3 DailyActionResultCard — "YESTERDAY'S RESULT"

1. **Why it exists.** The loop closer. Comment at L477: "the proof that
   yesterday's action moved the score leads the screen — it is the reason the
   user came back this morning."
2. **Does a user care?** Yes, in principle. This is the most valuable idea on
   the whole screen.
3. **Action or furniture?** Neither — it is *evidence*, which is the correct
   third category and the one the rest of the screen lacks.
4. **Trust. This is where it breaks.** The card makes a causal claim from n=1
   with no control: "You did [go to bed 30 min earlier] → your recovery is +3
   higher this morning." Readiness moves ±3 on nothing. The app itself knows
   this — `DailyActionResultStore.Result.direction` uses a ±2 dead band and the
   comment says "±2 keeps normal day-to-day noise out of the 'it moved' claim"
   — and then the up-branch prints the raw delta anyway, so a +2 (i.e. exactly
   at the noise floor the code just defined) renders as "Your recovery is +2
   higher this morning." The dead band protects the *direction* and then the
   copy leaks the *magnitude*. A user who marks done for a week and sees
   +3/−4/+1/−2 will conclude, correctly, that the app is guessing.
   The down-branch is worse: "Your recovery dipped 3. Rest is part of the plan
   too." — the app is consoling you for following its own advice.
5. **Cognitive load.** Low: 1 number, 1 dismiss.
6. **Questions answered.** *What happens if I follow the recommendation?* —
   the only component on the screen that even tries. Partially *why did this
   happen*.
7. **Verdict: KEEP the slot, CHANGE the claim.** This should be the anchor of
   the redesign, but it must stop attributing single-day score movement to a
   single action. The honest version aggregates: "You've done this 6 times.
   Your readiness the morning after averages 4 points higher than mornings you
   didn't." The machinery for that already exists —
   `RecommendationEvaluator.buildActionProof` and
   `Copy.Home.ActionProof.pastOutcomeSummary("Out of %d similar tips, %d led
   to a real improvement in your %@")` are built and are shown **only on the
   detail screen**, not here. The strongest, most defensible sentence the app
   can say is buried one tap deep while the weakest version leads Home.

---

### 4.4 streakMilestoneCard — "7 days in a row. Share this"

1. **Why it exists.** Growth. It offers a share card at 7/14/30/60/100 days
   and retires forever on either button. Both buttons fire
   `trackBlockTap(type: .shareCard)` with the same card id specifically so the
   team gets a decline rate (comment at L302).
2. **Does a user care?** A small minority. Most people do not post their sleep
   streak.
3. **Action or furniture?** It creates an action for *the company*, not the
   user. It is an ask, dressed as a reward.
4. **Trust.** Erodes it, mildly. It arrives at the top of a health screen and
   the only thing it wants is distribution. The instrumented decline rate makes
   the intent unmistakable in the code.
5. **Cognitive load.** 1 number, 2 decisions. Rare enough not to matter.
6. **Questions answered.** None.
7. **Verdict: REMOVE from Home.** It is genuinely rare and self-retiring, so it
   is not the biggest problem — but it occupies the #4 slot above the fold at
   exactly the moment the user is most engaged, and spends that moment asking
   for a favour. Move the offer to the Weekly Review or a post-action moment.

---

### 4.5 primaryActionCard — "NEXT UP · TODAY"

1. **Why it exists.** Comment at L493: "Laso's core promise is telling you what
   to do next, so the step comes before the score that explains it." Correct
   instinct, and it is the right card to lead with.
2. **Does a user care?** Yes. This is the product.
3. **Action or furniture?** The only genuine action card on the screen.
   `[Mark done]` + `[Remind 9:30]` are the two right buttons.
4. **Trust. Mixed, and the weak spot is the advisor behind it.**
   `DashboardSmartActionAdvisor.recommend` is an **8-rung fallback ladder**:
   life context → growing sleep debt → ML policy engine → high-priority insight
   → live-data rules → any insight → focus rules → activity progress → late-hour
   wind-down → hardcoded default "Get moving for 15 minutes." The card does not
   say which rung fired. Rung 8's "A short walk boosts mood, energy, and sleep
   quality tonight" is generic advice with a *rationale that admits it*: "No
   specific signals today." A user cannot tell a personalised ML
   recommendation from a fortune cookie, because they look identical.
   Worse: `expectedBenefit` — the "what do I get" chip, the single line that
   answers question 5 — is **only ever populated by the policy engine rung**
   (`Recommendation.expectedBenefit` defaults to `""` and is set in exactly one
   place, `recommendFromPolicyEngine`). Every one of the other seven rungs
   renders the card with no payoff line at all. The most important row is
   conditional on which internal subsystem happened to win.
5. **Cognitive load.** 2–4 numbers, 3 tap targets. Reasonable — this card is
   the best-designed thing on the screen.
6. **Questions answered.** *What should I do next?* (yes). *What happens if I
   follow?* (sometimes). *Why did this happen?* (only one tap deeper).
7. **Verdict: KEEP, and make it the screen.** It should not be one of thirteen
   cards. Every other block on this screen should either support this card or
   be gone.

---

### 4.6 RecoveryHeroCard — the ring, the Why list, the summary

1. **Why it exists.** "one readiness ring with a plain-word state ... the number
   never appears without a plain reason." The Why list is the best idea in the
   file.
2. **Does a user care?** Yes about the ring and the Why list. No about the
   three uncertainty widgets stacked under it.
3. **Action or furniture?** Furniture with 8 exits. Every Why row navigates
   away. It is a router.
4. **Trust. This card contains the two worst correctness bugs on the screen.**

   **(a) The delta chip describes a different number than the ring.**
   The ring shows `liveReadinessScore` = `liveViewModel.recovery.readinessScore
   ?? viewModel.overallScore.score` (HomeView L189-191). The chip under it shows
   `viewModel.scores.scoreDeltaFromYesterday`, which is
   `cachedYesterdayScore.map { overallScore.score - $0 }` (DashboardViewModel
   L159-161) — the **Daily Health Score** delta. When live readiness exists
   (the normal, watch-wearing case) the user sees a Readiness of 72 with
   "4 up from yesterday" where the 4 is the movement of a completely different
   index. The two series can move in opposite directions on the same morning.
   The same fabricated pairing is then sent to analytics:
   `trackScoreViewed(score: liveReadinessScore, previousScore:
   scoreChangeFromYesterday.map { liveReadinessScore - $0 })` (L547-550)
   manufactures a "previous score" that never existed.

   **(b) The label lies in the fallback case.** When `hasLiveReadiness` is
   false, the ring still reads `Copy.Home.scoreReadyLabel` = **"Readiness"**
   while displaying the Daily Health Score. It is graded by
   `DS.recoveryTier` (67/45), but tapping it opens `ScoreGuideSheet`, which
   grades the same number at **85/70/55**. A 60 is amber "Steady" on Home and
   "Fair — a few numbers have shifted" one tap away. Separately, `ringTint`
   forces `AppColour.scoreGood` for the radial glow in this case while the ring
   itself falls back to `DS.scoreColor(score)` — so a poor score renders a red
   ring inside a green glow.

   **(c) The Energy row is the ring restating itself.** In
   `recoveryWhyReasons`, the `.energy` candidate is built from
   `liveVM.recovery.readinessScore ?? overallScore.score` — the same number the
   ring is showing. The card explains its score with a row whose content is its
   score. `openWhySignal(.energy)` even routes back to the score explainer.
   Circular, and it consumes one of five Why slots.

5. **Cognitive load. Highest on the screen.** 10–12 numbers, 8 tap targets, and
   **four** simultaneous statements about confidence: the range band
   ("Likely 61 to 77"), the sentence ("Based on 3 of 5 signals"), the coloured
   progress bar under it, and the missing-signals paragraph ("Stress not
   recorded yet. Wear your watch tonight and tomorrow is a full read."). That
   last one duplicates the DataCoverageCard two cards below.
6. **Questions answered.** *What is happening inside my body?* (yes).
   *Is this good or bad?* (yes, via the summary footer — the only unambiguous
   good/bad verdict on the entire screen). *Why did this happen?* (correlational
   only). *What should I do next?* (yes — and this is the conflict, see §5).
7. **Verdict: CHANGE, aggressively.** Keep the ring + the Why list + the
   summary sentence. Delete the range band, the confidence bar, and the
   missing-signals paragraph — pick **one** honesty mechanism, not four. Fix
   the delta to describe the number it sits under, or delete the chip. Drop the
   Energy row. Stop labelling the health score "Readiness".

---

### 4.7 SleepBankCard — "-3h 20m Behind"

1. **Why it exists.** Best-written doc comment in the codebase: "Every other
   number on Home resets each morning, so nothing could say 'this has been
   building all week'."
2. **Does a user care?** Yes. Accumulated sleep debt is one of the few numbers
   in consumer health that a person can actually feel and actually fix.
3. **Action or furniture?** **Zero tap targets.** It is a read-only chart. It
   ends with a payback row — "45 minutes extra for 4 nights puts you back to
   level" — which is *a fourth instruction on a screen that already has three*,
   with no button to act on it.
4. **Trust.** The threshold undermines the intent. `actionableDebtHours = 2.0`
   over 14 nights is an 8.5-minute nightly average. The comment says a card
   that reads "you are fine" every morning teaches people to skip past it — and
   then ships a threshold that fires for nearly everyone, every day. A
   permanent "-3h 20m Behind" in warning-amber is exactly the "you are always
   failing" pattern the comment set out to avoid.
5. **Cognitive load.** 9 numbers, a 14-bar chart with **no y-axis and no
   labels** (`nightsChart` is `.accessibilityHidden(true)`, `axisRow` says only
   "14 nights ago" / "Last night"), 0 decisions, 0 tap targets. High parse cost,
   zero interaction payoff.
6. **Questions answered.** *What is happening inside my body?* (yes, and it is
   the only multi-day answer on the screen). *Is this good or bad?* (implicitly,
   via amber). *What should I do next?* (a fourth competing answer).
7. **Verdict: CHANGE.** The idea is the best on the screen; the execution is a
   silent chart. Either it becomes the Next Up card when it is the biggest
   thing about the day (the advisor already does this at rung 0b, gated on
   `debtTrend == .increasing`), or it collapses to one tappable line. It should
   never be a second full card competing with the action it justifies. And
   raise the threshold until it is genuinely a finding.

---

### 4.8 DataCoverageCard — "WHAT WE ARE READING"

1. **Why it exists.** "A score built on a missing signal has to say which one
   is missing on the same screen, otherwise silent zeros read as a broken app."
   Honest, defensible.
2. **Does a user care?** Once. On the day they find out. Not on day 40.
3. **Action or furniture?** One action — `[Check Health settings]` — which
   deep-links to the iOS Settings *root*, not to Laso's Health permissions
   page. `UIApplication.openSettingsURLString` opens the app's settings pane;
   the user then has to find Health → Data Access → Laso themselves. The card
   names the problem and abandons the user at the door.
4. **Trust.** Erodes it by repetition. It shows *all five* signal rows whenever
   *any one* is missing, so a user with 13/14 days of sleep, HRV, RHR and steps
   but no blood oxygen sees a five-row diagnostic panel every single day. The
   title "WHAT WE ARE READING" is engineering vocabulary about the app's own
   plumbing.
5. **Cognitive load.** Up to **10 numbers** ("12 of 14 days" × 5) plus a
   sentence plus a button, for information that changes maybe twice in a user's
   lifetime.
6. **Questions answered.** None of the five. It answers "what does the app
   know", which is a sixth question nobody asked at 7am.
7. **Verdict: REMOVE from Home.** This is a settings/diagnostics surface. The
   hero card's `missingSignalsRow` already says the same thing in one line, and
   says it better. If it must exist here, it is one dismissible line, once, with
   a deep link that actually lands on the permission toggle.

---

### 4.9 ActivationProgressBanner — "Day 5 of 7. 62%"

1. **Why it exists.** Comment: "Compact banner shown during the first 8 days.
   Displays calibration progress, next milestone preview, and celebratory
   animations." A retention scaffold: give the new user a progress bar so they
   come back before the data is good enough to be useful.
2. **Does a user care?** Marginally, for about two days. The milestone names
   are internal: `firstBaseline`, `firstComparison`, `firstTrend`,
   `firstPattern`, `firstCorrelation`, `firstAnomaly`. "Correlation Found in 2
   days" is a promise about a statistical artefact.
3. **Action or furniture?** Furniture with a celebration animation. The
   celebration auto-dismisses after 4 seconds via `.task(id:)`, so a user who
   glances away misses the thing that was supposed to reward them.
4. **Trust.** Neutral early, negative if the milestone lands and the "unlocked"
   insight is thin. It also sets a countdown the app must honour: the milestones
   fire on `currentDay >= N && <data condition>`, so a user with sparse data
   gets a bar that says day 5 of 7 and milestones that never arrive.
5. **Cognitive load.** 4 numbers, 8 dots, a percentage of an abstraction.
6. **Questions answered.** None. It answers "when will this app be useful",
   which is an admission that it currently is not.
7. **Verdict: REMOVE.** Progress bars toward "the product starts working" are
   a symptom, not a fix. The first-week problem is real; the answer is to say
   something true and useful on day 1 (Apple Health backfills a year of steps
   and sleep for most users — `firstLaunchLoadingView` literally says "Syncing
   your past year of health data"), not to draw a loading bar over the first
   week of the relationship.

---

### 4.10 MorningCheckInView — 3 questions, 15 emoji

1. **Why it exists.** Comment: "combining physiological signals (HRV, RHR) with
   subjective well-being scores significantly improves readiness prediction
   accuracy over either alone."
2. **Does a user care?** No — because the premise is not delivered. **Verified:
   the answers change nothing the user can see.**
   `MorningCheckIn.readinessAdjustment` is assigned to
   `DashboardViewModel.subjectiveReadinessAdjustment` in exactly two places
   (HomeView L119, DashboardViewModel L2666) and **read in zero**. Grep across
   the whole repo returns three hits, all writes or the declaration.
   `compositeScore`, `normalizedSleepQuality`, `normalizedEnergy` and
   `normalizedSoreness` — the "ML feature vector" the model comments promise —
   have **no consumers at all**. The only code outside the manager that reads
   `loadHistory()` is `RepermissionScheduler`, which counts entries to decide
   when to re-ask for notification permission.
   So: the user answers three questions every morning, the score does not move,
   nothing on screen changes, and the sole downstream effect is that the app
   becomes more likely to ask them for push permission.
3. **Action or furniture?** It is unpaid data entry.
4. **Trust. This is the most trust-corrosive component on the screen** — not
   because it is ugly, but because it is a false promise executed daily. A user
   who answers honestly for a week and notices the number never responds has
   learned something true about the app.
5. **Cognitive load. The highest of any block:** 3 questions × 5 options =
   **15 tap targets and 3 five-point decisions**, plus a dismiss and a submit,
   before 11am, above the metric strip.
6. **Questions answered.** None. It asks three.
7. **Verdict: REMOVE, or wire it up and prove it.** There is no third option.
   Either the adjustment visibly moves the ring and the card says so ("You said
   you feel rough — Readiness adjusted 72 → 65"), or this comes off the screen
   today. Also note: the check-in asks "Energy level" while the hero card three
   cards up already displays an "Energy" row derived from the score — the same
   word meaning two different things within one scroll.

---

### 4.11 WatchComplicationCard

1. **Why it exists.** "The complication never appears on its own, so without
   this most people who install the watch app never see their score on the
   face." Correct and well-gated: paired + app installed + complication not
   enabled + not dismissed.
2. **Does a user care?** The subset it targets, yes.
3. **Action or furniture?** It creates a real, one-time, valuable action.
4. **Trust.** Fine. It self-retires permanently on dismiss.
5. **Cognitive load.** Low, but it renders `WatchComplicationSteps` — a
   multi-step instruction list — inline in the middle of the home feed.
6. **Questions answered.** None.
7. **Verdict: KEEP the logic, MOVE the placement.** Correctly gated one-time
   nudges are how this should be done. But a step-by-step tutorial does not
   belong at position 11 of a daily screen; it belongs in a dismissible banner
   at the very top or in the Devices screen with a single-line pointer here.

---

### 4.12 AskYourDataCard — "CONCIERGE"

1. **Why it exists.** Entry point to the natural-language query screen.
   Rotates a sample prompt daily by day-of-year modulo.
2. **Does a user care?** Some. The feature behind it is real
   (`HealthDataQueryEngine`). But the card sells it with the word
   **"CONCIERGE"** in caps with 1.8pt tracking, which in a health app means
   nothing at all.
3. **Action or furniture?** One tap target, one destination.
4. **Trust.** The card is fine; the destination shows "%d%% confidence" on
   every answer, which is a number the engine cannot honestly produce and which
   invites the user to distrust every reply below 90.
5. **Cognitive load.** 0 numbers, 1 decision. Cheapest card on the screen.
6. **Questions answered.** It is a *door* to answers, which is different from
   an answer. On Home it answers nothing.
7. **Verdict: CHANGE.** Keep the feature, kill the card. This is a search
   affordance — it belongs as a persistent input at the top or bottom of the
   screen, or in the nav bar, not as a full-width card competing for vertical
   space with the health information it is meant to interrogate. And "CONCIERGE"
   has to go.

---

### 4.13 compactAlertBanner — "Worth Noticing" + risk rows

1. **Why it exists.** Merges illness early warnings and health risks into one
   red-tinted block instead of two sections.
2. **Does a user care?** Enormously, if real. This is the highest-stakes
   content the app can show.
3. **Action or furniture?** Three tap targets into detail screens. Real.
4. **Trust. The copy actively undercuts the signal.** The header is
   `Copy.Home.earlyWarning`, whose default string is **"Worth Noticing"** — a
   maximally hedged phrase — sitting next to a severity badge that reads
   **"High"** in `AppColour.danger` red. Hedged label, alarming badge, in the
   same row. The user gets neither reassurance nor urgency, just mixed signals.
   The risk rows show `riskGrade.displayName` with no baseline, no timeframe,
   and no statement of what to do.
5. **Cognitive load.** 1 severity word + up to 2 risk grades, 3 decisions.
6. **Questions answered.** *Is this good or bad?* (badly — see above).
   Not *why*, not *what to do*.
7. **Verdict: CHANGE.** This should be the highest-priority block on the
   screen when it fires and it currently renders at **position 13**, below the
   watch-face tutorial and the concierge card. Anything the app is willing to
   grade "High" must sit above the fold or not exist. And "Worth Noticing"
   must become a sentence that says what was noticed.

---

### 4.14 sectionHeader("VITALS") + MetricStripView

1. **Why it exists.** Comment: "Horizontally scrollable strip of compact metric
   tiles replacing the 6 vertical cards. Reduces ~700px of vertical scroll to
   ~120px." It is a compression fix for a previous over-long screen.
2. **Does a user care?** Occasionally, for one specific metric. Never for all
   six at once.
3. **Action or furniture?** Six navigation exits. It is the app's real
   navigation, wearing a data costume.
4. **Trust. This is the clearest case of "shows data, never says if it is good
   or bad."** `Strain 14.2 · High` — is high strain good today or bad today?
   The tile does not say, and it cannot, because the answer depends on the
   readiness score displayed seven cards above it. `Stress 1.2 · Mild`, `Brain
   85 · Sharp`, `Vitality 32 · 3y younger`, `Cycle Day 14 · Ovulation` — five
   numbers on five different, unexplained scales, with badges that are category
   labels, not verdicts. There is no baseline, no arrow, no comparison to the
   user's own usual — the exact comparison the Why rows on the hero card do
   correctly ("12 ms below usual") is absent here.
   The tiles are also **built conditionally with no placeholder**
   (`rebuildMetricTiles` appends only when data exists), so the strip silently
   changes length and order between days and the user cannot form a stable
   mental map of it.
5. **Cognitive load.** ~8 numbers, 6 decisions, and — because it is a
   horizontal scroll inside a vertical scroll — an unknown number of hidden
   tiles the user must discover by swiping.
6. **Questions answered.** *What is happening inside my body?* — raw values
   only, no interpretation. Nothing else.
7. **Verdict: CHANGE or REMOVE.** As navigation it is fine and should be
   labelled as navigation. As "VITALS" — a clinical word implying these numbers
   mean something medically — it is a promise the tiles do not keep. Either
   each tile gains a good/bad verdict against the user's own baseline, or the
   strip drops the numbers and becomes an honest row of section links.

---

### 4.15 sectionHeader("REVIEW") + WeeklyReviewEntryCard

1. **Why it exists.** Entry point to the weekly report.
2. **Does a user care?** Once a week. It renders every day.
3. **Action or furniture?** One tap target.
4. **Trust.** It puts **a second unlabelled score delta** on the screen:
   `(+4)` from `viewModel.scoreDelta` (a weekly EWMA comparison), directly
   below the hero card's `4 up from yesterday` (a daily health-score delta),
   both rendered as a bare signed number in green. Two deltas, two different
   series, two different windows, identical visual treatment, neither labelled.
   The `Score 72` it shows is a third score index alongside Readiness and the
   Daily Health Score.
5. **Cognitive load.** 4 numbers, 1 decision.
6. **Questions answered.** None on Home. It is a door.
7. **Verdict: CHANGE.** A weekly artefact should appear on the day it is
   generated, not as permanent daily furniture. When it does appear it should
   lead with a sentence, not `Score 72 (+4) · 3 wins · 8,500/day`.

---

### 4.16 Last-updated footer

1. **Why it exists.** Comment: "always rendered so the user can confirm the
   screen is alive."
2. **Does a user care?** Only if they already suspect it is stale — which
   means the footer is a fix for a trust problem, not a feature.
3. **Action or furniture?** Furniture. Pull-to-refresh is the actual affordance
   and it is undiscoverable except via the fallback string "Pull to refresh",
   which only shows when nothing has ever synced.
4. **Trust.** Mildly positive, mildly anxiety-inducing. "Updated 3 minutes ago"
   invites the user to wonder what happens at 30 minutes.
5. **Cognitive load.** 1 number.
6. **Questions answered.** None.
7. **Verdict: KEEP, minimised.** It is the cheapest block on the screen. But it
   is also the only place the screen admits it is a data view rather than a
   coach.

---

### 4.17 softLockBottomBar + SoftLockModifier

1. **Why it exists.** Monetisation for users who declined the paywall. Blurs
   four surfaces (`home_recovery_score`, `home_alerts`, `home_vitals`,
   `home_weekly_review`) with an "Unlock to read" badge, and pins a bar reading
   "Patterns found in your data: 12 / [Unlock my report]".
2. **Does a user care?** They care that they are being blocked.
3. **Action or furniture?** A conversion action.
4. **Trust. This is the most hostile configuration on the screen, and it is a
   design choice, not an accident.** The blurred set is: the score, the alerts,
   the vitals, the weekly review. The *unblurred* set includes the Next Up card
   — so a declined user is told exactly what to do today while the evidence
   justifying it is behind glass. The `compactAlertBanner` is blurred, which
   means a **health warning the app graded "High" is hidden behind a paywall.**
   Meanwhile `DataCoverageCard` is *not* soft-locked, so the same user still
   gets a five-row panel telling them their data is incomplete.
   "Patterns found in your data: 12" is `viewModel.insights.allInsights.count`
   — a raw array length presented as a quantity of withheld value.
5. **Cognitive load.** 1 number, 1 decision, plus four blurred rectangles the
   eye keeps trying to resolve.
6. **Questions answered.** None. It withholds answers.
7. **Verdict: CHANGE.** Never blur a health alert. Whatever the monetisation
   strategy, "we found something concerning, pay to see what" is not a position
   this product should be able to reach.

---

### 4.18 firstLaunchLoadingView

1. **Why it exists.** Cover the one-time year-long HealthKit import with
   phase text: Syncing → Analyzing N data points → Discovering patterns → Ready.
2. **Does a user care?** For 20 seconds, yes. The data-point counter is the one
   genuinely good touch — it is a real number that proves work is happening.
3. **Action or furniture?** Blocking. No exits.
4. **Trust.** Mostly builds it. "Discovering patterns" is the weak phase — it
   promises insight the app will then struggle to deliver on the empty Home
   screen the user lands on. "This only happens once" is defensive copy that
   pre-apologises for the wait.
5. **Cognitive load.** 1 number, 0 decisions.
6. **Questions answered.** None (correctly — it is a loading state).
7. **Verdict: KEEP.** Best-executed state in the file. Two nits: the dot ticker
   re-renders the whole view twice a second for no reason, and "Discovering
   patterns" should not promise what Home cannot deliver on day 1.

---

### 4.19 Empty state (HomeConnectHealthView)

1. **Why it exists.** "Deliberately shows one icon, one message, one primary
   action." It correctly distinguishes waiting / receiving / stale device.
2. **Does a user care?** Yes, and this is the moment they decide whether to
   keep the app.
3. **Action or furniture?** One action: `[Refresh now]`.
4. **Trust.** Good, with two flaws. First, the greeting renders **above** it
   (L459 is outside the branch), so the "no data yet" screen is topped with
   "Morning, Aman / Tuesday, April 26" — the app greeting you by name while
   telling you it knows nothing about you. Second, there is a **gap state**:
   `shouldShowEmptyState` requires `ui.hasCompletedInitialLoad`, and the loading
   gate requires `ui.isLoading`. A user who is neither loading, nor errored,
   nor finished-loading, with no data, gets `homeContent` containing **only the
   greeting** — a blank screen with their name on it.
5. **Cognitive load.** 1 number (sync progress), 1 decision.
6. **Questions answered.** None (correct for the state).
7. **Verdict: KEEP the content, FIX the gap.** Hide the greeting in this branch
   and make the no-data-not-loading case render something.

---

## 5. Duplicated and conflicting information

**Three components tell you what to do today, and they can disagree.**

| Source | Example output |
|---|---|
| `primaryActionCard` (advisor, 8-rung ladder) | "Go to bed 30 minutes earlier tonight" |
| `RecoveryHeroCard.summarySub` (`readinessSummary`, pure band lookup) | "Good to push a little." |
| `SleepBankCard.paybackRow` | "45 minutes extra for 4 nights puts you back to level" |

The hero summary is derived **only** from the score band — it knows nothing
about sleep debt, life context, or the advisor's decision. So a user with a
green readiness score and a growing sleep debt is told, in adjacent cards,
"Go to bed 30 minutes earlier" and "Good to push a little." The advisor has an
explicit rung (0b) that ranks growing sleep debt above the model precisely
because "a good-looking morning after five short nights still produced 'push a
little harder', which is exactly the advice that keeps the hole open" — and
then the hero card prints that exact advice anyway, unmediated, one card below.

**Sleep appears five times on one screen:** hero Why row ("Sleep was short ·
5h 40m"), SleepBankCard (-3h 20m + 14 bars), MetricStrip Sleep tile ("7h 12m ·
Good"), DataCoverageCard row ("Sleep duration · 12 of 14 days"), and frequently
the Next Up action itself. The Why row can say "Sleep was short" while the
metric tile badge says "Good" — they use different thresholds (`sleepHoursGoal
- 0.75` vs `LiveViewModel.sleepQualityLabel`).

**Stress appears three times:** hero Why row, MetricStrip tile, and the
advisor's high-stress rule.

**Two "what is missing" surfaces, two cards apart:** hero
`missingSignalsRow` ("Stress not recorded yet. Wear your watch tonight...")
and `DataCoverageCard` ("WHAT WE ARE READING ... has sent nothing").

**Four confidence widgets on one card:** score range band, "Based on 3 of 5
signals", coloured certainty bar, missing-signals paragraph.

**Two unlabelled score deltas:** hero `4 up from yesterday` (daily health score
delta, under a Readiness ring) and weekly review `(+4)` (weekly EWMA delta).

**Three score indices, undifferentiated:** Readiness (ring), Daily Health Score
(delta chip, fallback ring, ScoreGuideSheet), Weekly Score (review card).
Each has its own band table. `DS.recoveryTier` grades 67/45;
`ScoreGuideSheet` grades 85/70/55.

**The Energy Why row is the ring.** See §4.6(c).

---

## 6. Deltas shown on noisy metrics

- **`changeChip`** — day-over-day score delta with **no dead band**. Any
  non-zero value renders, including ±1. The same codebase decided ±2 is noise
  in `DailyActionResultStore.Result.direction`. Two components, same metric,
  contradictory noise floors.
- **`DailyActionResultCard`** — prints the raw delta magnitude ("+2 higher this
  morning") while its own direction logic treats ±2 as steady, and attributes
  that movement to one action taken once.
- **Hero Why rows** — "12 ms below usual" for single-night HRV against a
  baseline mean. Night-to-night HRV coefficient of variation is large; a single
  night's gap to the mean is mostly noise, presented as a finding with a
  coloured dot.
- **`WeeklyReviewEntryCard` `(+4)`** — weekly delta, unlabelled, green/red
  tinted.
- **Metric strip badges** — `Strain 14.2`, `Stress 1.2` to one decimal place on
  derived indices. Decimal precision on a synthetic score implies a resolution
  the model does not have.

---

## 7. Where the copy is jargon, hedged, or vague

Verified against `Copy+Home.swift` default strings.

**Jargon / invented vocabulary**
- `"CONCIERGE"` (AskYourData caption) — meaningless in a health context.
- `"WHAT WE ARE READING"` — engineering language about the app's own plumbing.
- `"Heart Calm Signal"` for HRV, used alongside `"Resting HR"` abbreviated and
  `heartRateVariability` raw. Three vocabularies for the cardiac signals in one
  screen's worth of copy.
- `"Body Intelligence"`, `"Generated by Laso intelligence"` — brand noise.
- Activation milestone names surfaced to users: `firstCorrelation` →
  "Correlation Found", `firstAnomaly` → anomaly.
- `"Based on 3 of 5 signals"`, `"Likely 61 to 77"` — statistical framing on a
  score that is itself an arbitrary index.
- `"Patterns found in your data: 12"` — an array length as a value proposition.

**Hedged**
- `earlyWarning` default = **"Worth Noticing"**, rendered next to a red
  **"High"** severity badge.
- `needsAttentionLabel` = **"Room to Grow"** for a score below 55.
- `"Your recovery dipped 3. Rest is part of the plan too."` — consoling the
  user for following the app's advice.
- `"This is for information only. Think of it as a daily check in with your
  body."` (ScoreGuide) — a disclaimer that dissolves the score it just
  explained.

**Vague / unactionable**
- `"About usual today." / "A steady day suits you."` — the modal case of the
  hero summary. Says nothing.
- `"Get moving for 15 minutes"` / `"A short walk boosts mood, energy, and sleep
  quality tonight"` — the rung-8 fallback, indistinguishable in presentation
  from an ML-derived recommendation, whose own rationale reads "No specific
  signals today."
- `"Almost there. %@ unlocking soon"`.

**The copy layer has decayed.** `Copy+Home.swift` now contains machine-lifted
placeholders with generated names: `Copy.Home.x` = `"·"`, `xText`, `xText2`,
`xLabel`, `dayText`, `dayText2`, `dayText3`, `confText`, `ofMetricsText`,
`baselineWithUnitText`. These are not authored copy; they are a string-extraction
script's output checked in as if it were.

**And the rule is broken anyway.** Inline user-visible strings still ship on
Home: `sectionHeader("VITALS")` and `sectionHeader("REVIEW")` (HomeView L633,
L655); `"Sleep quality"`, `"Energy level"`, `"Body soreness"`
(MorningCheckInView L57/64/71); every metric tile label and badge
(`"Vitality"`, `"3y younger"`, `"On track"`, `"Sleep"`, `"Strain"`, `"Brain"`,
`"Stress"`, `"Cycle"`, `"Day \(n)"` in `rebuildMetricTiles`);
`"\(winsCount) win\(...)"` in WeeklyReviewEntryCard; `"Expected: \(lower) –
\(upper)"` in MetricForecast.

---

## 8. Data shown without a good/bad verdict

The screen renders roughly 28 numbers on a plain morning. **Exactly one
component states a plain-language verdict**: the hero card's summary footer
("About usual today. / A steady day suits you.").

Everything else is uninterpreted:

| Shown | Verdict given? |
|---|---|
| `Strain 14.2 · High` | No — is high strain good today? Depends on readiness, which is 7 cards away. |
| `Stress 1.2 · Mild` | Scale unexplained. |
| `Brain 85 · Sharp` | Scale unexplained, no baseline. |
| `Vitality 32 · 3y younger` | Directionally positive, but 32 alone is meaningless without knowing the user's real age. |
| `Cycle Day 14 · Ovulation` | Phase label, not a verdict. |
| Sleep bank 14-bar chart | No axis, no labels, `accessibilityHidden(true)`. |
| `12 of 14 days` × 5 | Colour-coded at 0.6 with no explanation of the threshold. |
| Activation `62%` | Percent of an abstraction. |
| `Score 72 (+4) · 3 wins` | Three numbers, no interpretation. |
| `Updated 3 minutes ago` | n/a |

Coverage across the five questions, honestly:

| Question | Answered by | Quality |
|---|---|---|
| What is happening inside my body? | Hero ring + Why rows; sleep bank | Partial. The metric strip shows values without meaning. |
| Is this good or bad? | Hero summary footer only | **One sentence, on a screen of 28 numbers.** |
| Why did this happen? | Hero Why rows | Correlational, single-day, one row is circular. |
| What should I do next? | Next Up, hero summary, sleep bank payback | **Three answers, mutually unaware.** |
| What happens if I follow it? | `expectedBenefit` chip | Only when the policy-engine rung wins. Absent for 7 of 8 advisor paths. |

---

## 9. Analytics instrumentation density

Counts from this session:

- **27** `AppAnalytics.shared.*` calls in `HomeView.swift` alone, against
  ~18 rendered blocks.
- **40** `trackBlockTap` calls across `Modules/Dashboard/Views/Home/`.
- **4** `SectionTracker` instances in HomeView (`homeRecovery`, `homeIllness`,
  `homeRisks`, `homeWeeklyReview`) whose only job is impression + dwell.
- Plus `trackFeatureOpen/Close` (6 each), `trackScrollDepth` with three
  hand-placed depth markers (10 / 40 / 65 / 90), `trackScoreViewed`,
  `trackEmptyStateShown`, `trackPullToRefresh`, `trackActivationMilestone`,
  `trackPremiumFeatureAttempted` (×3), `trackCoreAction` (×4).

**What is being measured:** taps, impressions, dwell time, scroll depth, and
paywall-wall attribution (`SoftLockModifier` takes a `feature` string
specifically "so the six Home walls stay separable instead of collapsing into
one paywall_viewed"). Even the streak-share **dismiss** button fires an event
with the same card id as Share, explicitly so the offer has a decline rate.

**What is not being measured:** whether the recommendation was followed,
whether following it changed anything, whether the user believed the result
card. `DailyActionCompletion.markDone` is a tap. `trackDailyResultShown` fires
on *shown*, with the delta — but there is no paired event for whether the user
accepted or dismissed the claim, and no cohort comparison of markers vs
non-markers.

The outcome machinery exists — `RecommendationEvaluator.buildActionProof`
computes "Out of %d similar tips, %d led to a real improvement in your %@" —
and Home does not surface it or instrument it. The screen measures engagement
with a health product instead of health outcomes from a health product. That is
a strategy statement, and it is written in the code.

Secondary observation: this density has a **correctness cost**. Three separate
components carry a `hasTrackedImpression` guard with the identical comment
("LazyVStack re-fires onAppear on every scroll-back") — the analytics layer is
now complex enough to need per-component de-duplication workarounds.

---

## 10. Structural and performance problems found while reading

These are not design opinions; they are things the code does on every body pass.

- `viewModel.signalCoverage()` is called inline in `homeContent` (L567). Its own
  doc comment states "Home calls this on every body pass" and documents having
  been optimised for it. A view body should not be running a five-metric
  windowed scan.
- `viewModel.readinessSummary(score:)` is called **twice** in the same
  expression (L502 and L503) to get `.head` and `.sub`.
- `shareTemplates` is a computed property invoking `ShareTemplateBuilder.build`,
  evaluated on every render — once for the `onShare` nil-check (L528) and again
  inside the sheet closure (L542).
- `viewModel.recoveryWhyReasons(liveVM:)` (L504) runs its full candidate
  build + sort on every body pass.
- `WeeklyReviewViewModel(dashboardViewModel: viewModel)` is **allocated inline
  as a fallback** at L661 (`weeklyReviewViewModel ?? WeeklyReviewViewModel(...)`),
  so a nil VM constructs a fresh one on every render.
- `viewModel.smartDailyAction(liveVM:)` runs inside `primaryActionCard`'s body.
  Day-cached, but on a cache miss it runs the 8-rung advisor plus
  `RecommendationEvaluator.buildActionProof` (a store read) during layout.
- Two `RepeatTimer`s (home refresh, readiness refresh) drive re-render of this
  entire tree on a 60s / thermal-dependent cadence.
- `.sheet(isPresented: $showShareCard)` is attached to `RecoveryHeroCard`
  (L541) but `streakMilestoneCard`, which renders *above* it, also sets
  `showShareCard = true`. The presentation anchor lives in a LazyVStack child.
- The first-launch dot ticker re-renders the loading view at 2 Hz.
- `HomeView.swift` is **1205 lines** with ~15 `@State` properties, four section
  trackers, two timers, six sheet/cover modifiers and seven `.onChange`/lifecycle
  hooks. It is not a view; it is an orchestrator that also draws.

---

## 11. Verdict table

| # | Component | Frequency | Answers Qs | Action? | Verdict |
|---|---|---|---|---|---|
| 1 | CoachGreetingView | Always | 0/5 | No | **CHANGE** — earn the slot or shrink it |
| 2 | LifeContextChipRow | Always | 0/5 (asks) | Input | **CHANGE** — collapse to one affordance / trigger contextually |
| 3 | DailyActionResultCard | Rare | Q5, Q3 | Evidence | **KEEP slot, CHANGE claim** — aggregate, stop n=1 causality |
| 4 | streakMilestoneCard | Very rare | 0/5 | Company's | **REMOVE** from Home |
| 5 | primaryActionCard | Always | Q4, Q5* | **Yes** | **KEEP — make it the screen** |
| 6 | RecoveryHeroCard | Always | Q1,Q2,Q3,Q4 | Router | **CHANGE** — fix delta bug + label bug, cut 3 of 4 confidence widgets |
| 7 | SleepBankCard | ~Daily | Q1, Q4 | **None** | **CHANGE** — one line or become the action; raise threshold |
| 8 | DataCoverageCard | Common | 0/5 | Weak | **REMOVE** from Home |
| 9 | ActivationProgressBanner | First week | 0/5 | No | **REMOVE** |
| 10 | MorningCheckInView | Daily 5–11am | 0/5 (asks) | Unpaid data entry | **REMOVE or wire it up** — currently a no-op |
| 11 | WatchComplicationCard | Once | 0/5 | Yes | **KEEP logic, MOVE placement** |
| 12 | AskYourDataCard | Always | 0/5 | Door | **CHANGE** — become an input, drop "CONCIERGE" |
| 13 | compactAlertBanner | Varies | Q2 (badly) | Yes | **CHANGE** — promote to top, unhedge copy, never paywall |
| 14 | VITALS header + MetricStrip | Always | Q1 (raw only) | Nav | **CHANGE** — add verdicts or admit it is navigation |
| 15 | REVIEW header + WeeklyReview | Always | 0/5 | Door | **CHANGE** — weekly cadence, lead with a sentence |
| 16 | Last-updated footer | Always | 0/5 | No | **KEEP**, minimal |
| 17 | softLockBottomBar + blur | Decliners | — | Conversion | **CHANGE** — never blur a health alert |
| 18 | firstLaunchLoadingView | Once | 0/5 | No | **KEEP** |
| 19 | Empty state | No data | 0/5 | Yes | **KEEP, fix greeting + gap state** |

**Of 19 components: 4 KEEP, 11 CHANGE, 4 REMOVE.**
**Of 19 components, 1 gives a plain good/bad verdict and 1 gives an action.**

---

## 12. The three things that must be true after the redesign

1. **One answer to "what should I do today."** Not three, and not one that can
   contradict another card two positions down.
2. **Every number on screen carries a verdict.** Either the number says whether
   it is good or bad against the user's own baseline, or the number does not
   render. There is no third state.
3. **Nothing on the screen asks the user for input that the app then ignores.**
   The morning check-in is currently a daily, verifiable lie by omission. That
   class of thing cannot survive the redesign.
