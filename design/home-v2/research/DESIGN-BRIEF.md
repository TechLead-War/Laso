# Laso Home Screen v2 — Design Brief

**Date:** 2026-07-29. **Audience:** every concept designer working on Home v2.
**Status:** this is the single source of constraints. Concepts may disagree with each
other on the ten tensions in §7. Nothing may disagree with §3, §6 or §8.

**Research streams cited throughout:**

| Tag | File |
|---|---|
| `[W]` | `apps-recovery-wearables.md` — Whoop, Oura, Ultrahuman, Athlytic, Bevel, Garmin |
| `[P]` | `apps-platform-mass-market.md` — Apple Health, Apple Fitness, Fitbit/Google Health, Google Fit, Samsung Health, MyFitnessPal |
| `[N]` | `apps-niche-behavioral.md` — RISE, Gentler Streak, Levels, Eight Sleep, Welltory, Human, Strava, Headspace, Calm, ZOE, Bearable |
| `[UX]` | `ux-research.md` — cognitive load, scanning, mobile, HIG, patient-facing display literature |
| `[PSY]` | `psychology-research.md` — Fogg, Lally, Wood & Neal, SDT, nudge, streaks, self-tracking harms |
| `[CL]` | `clinical-metric-comprehension.md` — what people understand, what is validated, what is noise |
| `[CRIT]` | `current-home-critique.md` — line-by-line audit of the shipping screen |
| `[CAP]` | `data-capability-inventory.md` — what Laso can actually compute, and when |

---

## 1. The verdict on the current screen

**Laso's Home screen is a dashboard pretending to be a coach.** It was assembled from
subsystems, not designed. Every block on it exists because a team shipped an engine and
needed somewhere to render the output.

### Quantified

| Measure | Current | Source |
|---|---|---|
| Blocks rendered, healthy watch-wearing user, plain weekday morning | **13** | `[CRIT §1]` |
| Blocks on day 3 with an illness warning and a milestone | **17** | `[CRIT §1]` |
| Distinct numbers to parse, plain morning | **~28** | `[CRIT §2]` |
| Distinct numbers with sleep bank + coverage + activation | **~51** | `[CRIT §2]` |
| Numbers inside the Recovery hero card alone | **10 to 12** | `[CRIT §2]` |
| Separate statements about confidence in that one score | **4** (range band, "Based on 3 of 5 signals", coloured certainty bar, missing-signals paragraph) | `[CRIT §2, §5]` |
| Tap targets, plain morning | **23** | `[CRIT §3]` |
| Tap targets with morning check-in, coverage, watch card, alerts | **45+** | `[CRIT §3]` |
| Exits from Home (15 in-app routes + 6 modals) | **21** | `[CRIT §3]` |
| Components that give a plain good/bad verdict | **1 of 19** | `[CRIT §8, §11]` |
| Components that give an action | **1 of 19** | `[CRIT §11]` |
| Components that answer zero of the five user questions | **11 of 19** | `[CRIT §11]` |
| Components telling the user what to do today | **3, mutually unaware, able to contradict** | `[CRIT §5]` |
| Score indices on screen at once, each with its own band table | **3** (Readiness, Daily Health Score, Weekly Score) | `[CRIT §5]` |
| Analytics calls in `HomeView.swift` | **27**, against ~18 rendered blocks | `[CRIT §9]` |
| Lines in `HomeView.swift` | **1205** | `[CRIT §10]` |

### The seven structural failures

1. **Three components answer "what should I do today" and none of them knows the others
   exist.** The advisor has an explicit rung (0b) that ranks growing sleep debt above the
   model because "a good-looking morning after five short nights still produced push a
   little harder" — and then `RecoveryHeroCard` prints exactly that advice one card below,
   unmediated, from a pure band lookup. `SleepBankCard` adds a third instruction with no
   button to act on it. `[CRIT §5]`

2. **The hero number and the delta chip under it describe different quantities.** The ring
   shows live Readiness; the chip shows the Daily Health Score delta. The two series can
   move in opposite directions on the same morning, and the fabricated pairing is sent to
   analytics as a real previous score. `[CRIT §4.6a; CAP B3]`

3. **The label lies in the fallback case.** With no morning lock, the ring reads
   "Readiness" while displaying the Daily Health Score, graded at 67/45 by `DS.recoveryTier`
   and at 85/70/55 by the explainer sheet one tap away. A 60 is amber "Steady" on Home and
   "Fair" one tap deeper. The radial glow is forced green while the ring itself renders red.
   `[CRIT §4.6b; CAP B3]`

4. **The screen collects input it verifiably ignores.** `MorningCheckIn.readinessAdjustment`
   is written in two places and read in zero. Three questions, fifteen tap targets, every
   morning, and the sole downstream effect is that the app becomes more likely to ask for
   push permission. `[CRIT §4.10; CAP §9.6]`

5. **The screen's own good/bad verdict count is one.** 28 numbers, one plain-language
   verdict sentence. `Strain 14.2 · High` cannot say whether high strain is good today,
   because the answer depends on a score seven cards above it. `[CRIT §8]`

6. **The best content the app computes never reaches Home.** The intelligence briefing
   (10 card types, computed every refresh) renders only on Explore. `scoreExplanation` —
   real per-category attribution with the top 3 named factors — renders only on Explore,
   while Home builds its own separate 5-row "Why" list, one row of which explains the score
   with the score. `RecommendationEvaluator.buildActionProof` ("Out of N similar tips, M led
   to a real improvement") is computed and shown only on a detail screen. Circadian
   biomarkers are computed every refresh and rendered nowhere. `[CAP §9; CRIT §4.3, §4.6c]`

7. **A health warning graded "High" renders at position 13, below a watch-face tutorial and
   a card captioned "CONCIERGE", and is blurred behind a paywall for declined users — while
   the unblurred Next Up card still tells them what to do.** `[CRIT §4.13, §4.17]`

### Plus eleven correctness bugs that make Home actively wrong

Blood oxygen is ingested and 100% discarded by an outlier filter expecting a 0-1 fraction
against 0-100 data, so `DataCoverageCard` permanently tells every Watch user their SpO2 is
missing (**B1**). The sleep forecast divides hours by 3600 and prints "0.0h" (**B2**). A
sparse user's score is dominated by a constant 75 prior presented with full visual
confidence (**B4**). The Energy "Why" row is the ring restating itself (**B5**). The sleep
goal is hardcoded at 7.5h in one place and personalised elsewhere (**B6**). The steps goal
is hardcoded at 10,000 for the Live Activity (**B7**). Recovery-debt "trend" words are a
size test labelled as a direction (**B8**). Widget and Home can show different numbers by
design (**B9**). Weekly "wins" are unfiltered ±2% moves with no significance test (**B10**).
Vitality norm tables are self-documented as heuristic with no DOIs, and Home prints
"3y younger" as a flat fact (**B11**). `[CAP §10]`

**None of this is a styling problem. Do not solve it with a nicer card.**

---

## 2. What the competition proves

### 2a. Converged patterns — everyone independently arrived here

| # | Pattern | Who | What it buys |
|---|---|---|---|
| **C1** | **A pinned score cluster in the top ~30%, count 1 to 6.** Athlytic 1, Whoop 3 dials, Bevel 3, Ultrahuman 3, Oura 5-6 chips, Garmin 4 (July 2026, optional), Samsung 1, Google Health 3-5. | All 6 wearable apps, 3 of 4 platforms `[W §0, §10.1; P §7.1]` | A stable "the product's answer" region readable before any scroll. The apps with the clearest identity have the **fewest**; Oura, with the most, drew the "dilutes the information" critique from the most credible reviewer in the category. |
| **C2** | **No delta vs yesterday and no reason on the home screen.** Six independent, well-funded teams, all six chose this. | Whoop, Oura, Ultrahuman, Athlytic, Bevel, Garmin `[W §7]` | Nothing. It is a shared blind spot: "the score does not match how I feel" is the #1 complaint in the Whoop community thread, the Ultrahuman info-button review, the Bevel "does not show its work" critique and the Athlytic cardio-bias critique. **Four of six apps, four independent sources. This is the open lane.** |
| **C3** | **Colour is the pre-attentive verdict channel; the number is secondary.** Whoop green/yellow/red on every screen, Oura, Athlytic, Welltory tinting the entire background by Health score. | `[W §1.4, §2.4; N §5.2]` | A verdict before reading, and it is why a dense scroll below the fold survives: colour carries the load so density is scanned chromatically, not parsed. Cost: it imposes a moral frame. |
| **C4** | **Exactly three disclosure tiers.** Whoop names them: overview dials with "no graphs, no charts, no noise" → trend views → deep-dive graphs "for the 15% of users who want to correlate specific metrics." | Whoop, Oura (tabs split by time horizon), Apple Health `[W §1.5, §2.7]` | Home stays glanceable and nobody gets lost. NN/g: more than **two** levels of disclosure "typically show low usability." `[UX §4]` |
| **C5** | **One canonical daily action, pre-chosen, zero decision cost.** Headspace's Today's Meditation (same session for everyone, same day), Calm's Daily Calm, Gentler Streak's pre-scaled Go Gentler (type + intensity + duration + Start), Levels' three-item checklist, MyFitnessPal's inline `+` per meal. | `[N §8.3, §9.3, §2.3, §3.3; P §6.3]` | Removes the choice from the one behaviour that matters. Fogg: brain cycles are a designable simplicity axis; a returning user is already above the activation threshold, so spend the screen on ability, not motivation. `[PSY §1]` |
| **C6** | **One fixed slot whose content varies by time of day.** Oura's Daily Highlight, Gentler Streak's For You in the morning and logged workouts later, Headspace's time-of-day rows, Eight Sleep, Apple Health. | `[W §2.7; N §2.7, §8.7]` | One region answers a different question at 7am than at 9pm **without adding a card**. Note the evolution: Oura's pre-2025 app morphed the *whole screen* by time of day and that was the thing designers attacked; single-slot morphing survived. `[W §2.8]` |
| **C7** | **Every app that could not decide its hierarchy shipped "customisable" instead.** Garmin's Essentials row is optional and off by default, so Garmin has no identity number. Google's 39-item apology roadmap contains exactly one home-layout item, and it is "make it easier to customize." Apple Health's Favorites are alphabetical and have been unreorderable for seven years. | `[W §6.2; P §1.8, §7.3; §5]` | Nothing. **An optional hero is not a hero.** Customisation is what you ship when you cannot decide, and most users never touch it. |
| **C8** | **Cold start is universally unsolved.** Whoop shows "fluff articles" until data arrives; Athlytic's "calibration period can feel unreliable in the first two weeks"; Ultrahuman ships invented vocabulary with broken info buttons; Samsung's hero Energy Score is empty for most of a 65M-MAU base. **Nobody ships a distinct first-14-days home screen, and every one of them pays for it in reviews.** | `[W §10.7; P §5.2, §7.4]` | Nothing. Second open lane, and Laso is unusually well placed: first sync pulls **10 years** of HealthKit history, so a Watch-wearing new user is not data-poor on day 1. `[CAP §8]` |
| **C9** | **Putting AI narration above the user's own number is uniformly punished.** Fitbit/Google Health: 3,419 votes and 3,255 comments on the revert thread, Play Store review-bombing, a 39-item apology roadmap in 8 days. Eight Sleep: "I don't know who thought anyone wanted to read that with their eyes half open." Samsung: a softer version of the same. MyFitnessPal alone kept AI out of the hero. | `[P §3.8, §7.3; N §4.2]` | Nothing. The user came for a number; the paragraph is a tax on reaching it. Reading is a high-effort act at 6:45am. |

### 2b. Differentiators — exactly one app does this, and it works

| # | Move | Who | Why it wins |
|---|---|---|---|
| **D1** | **One score, alone, top-left, no competing element, with a stated 10-second design budget** — and 11 iPhone widgets + 8 complications so the best version of the home screen is the one you never open. | Athlytic `[W §4.2, §4.3, §4.7]` | The only app in the corpus optimising for **short sessions**. A lower-engagement, higher-satisfaction bet, and the exact opposite of Whoop's. |
| **D2** | **The hero is a unit the user already owns: sleep debt in h:mm, not a 0-100 score.** And it is a 14-day rolling balance, so a bad night dents a balance instead of resetting a streak. | RISE `[N §1.2, §1.7]` | "12h 30m of debt" is self-explaining, self-normalising and directly convertible into tonight's action. "Sleep score 62" is a unit only the app understands. Structurally prevents the "I blew it, why bother" collapse. |
| **D3** | **A band you sit inside, not a target you hit or miss — and the interpreting sentence sits ABOVE the chart.** Below the band is not failure, it is *capacity*: the docs literally say a low position means your body "can handle a more intense workout if you choose." Rest counts as compliance. | Gentler Streak `[N §2.2, §2.7]` | Inverts the moral polarity of fitness UI and eliminates the binary pass/fail. Won a 2024 Apple Design Award for Social Impact. Interpretation precedes data; almost every other health app puts the chart first and the caption below. |
| **D4** | **The scale is floored above zero (60 to 100, "functioning similarly to letter grades"), and exercise-induced spikes are excluded from the score.** | Levels `[N §3.2, §3.7]` | A score that cannot reach zero cannot produce total-failure affect. And the model refuses to punish healthy behaviour that happens to move the metric the wrong way — a scoring-integrity decision most apps get wrong. |
| **D5** | **Removing guilt copy is a shipped, noticed feature.** A user wrote an App Store review specifically to praise the *absence*: "No calorie goals or you didn't hit your macro target or cyber guilting." | Bevel `[W §5.4, §5.7]` | In a category whose primary complaint is score anxiety, this is a moat. Compare the framing pair: Ultrahuman's **Movement Index** (100 at wake, decays with inactivity — a score you are losing) vs Bevel's **Energy Bank** (a resource you spend). Same maths, opposite emotion. |
| **D6** | **A 3-month rolling baseline instead of the 7-day window everyone else uses, plus band labels that are complete sentences and a single wide 0-69 bottom band.** "Pay attention, you're not fully recovered." | Oura `[W §2.4, §2.5]` | The quiet reason Oura reads calmer than Whoop is not the palette, it is the statistics. And the wide bottom band is a deliberate refusal to grade *degrees* of bad: a 15 and a 68 read identically. |
| **D7** | **The streak is on the record-keeping, not on compliance.** You can eat a whole cake and keep the streak. And "calories **remaining**" is a budget you can spend, not a receipt you cannot change. | MyFitnessPal `[P §6.2, §6.7]` | Every compliance-based streak eventually teaches the user to stop opening the app on bad days, which are precisely the days the app has the most value to add. |
| **D8** | **A composite you read without reading a number.** Three concentric rings in ~40% of the first viewport; Move is personalised and adjustable, Exercise is externally anchored (WHO 30 min), Stand is an hourly micro-goal so something is always closable. Trends are time-locked until enough history exists. | Apple Fitness `[P §2]` | **The only home screen in the entire corpus readable in under one second with zero health literacy** — and the only one nobody revolted against during the 2025-2026 redesign wave. Borrowed external authority makes the target defensible without a medical claim. Time-locking prevents the trust-destroying move of computing a trend from four days of noise. |
| **D9** | **The user pins what stays above the fold; the algorithm does not choose.** | Human Health, Bearable `[N §6b, §11.7]` | Correct wherever the relevant metric differs person to person. Distinct from C7: this is pinning *within* a fixed hierarchy, not replacing the hierarchy with a settings screen. |

**One more worth stealing, buried in the wrong place:** Apple Health's **Highlights** compares
"flights climbed last week versus the week beforehand." For a health-illiterate audience,
**a delta is legible where an absolute is not** — and Apple ships it below the fold, under
a grid of raw numbers. `[P §1.7, §7.2]`

**And the cautionary ones.** Strava is the only home screen whose first element is another
person, and therefore the only one whose emotion the product cannot control; personal stats
moved off Home entirely `[N §7.6]`. Ultrahuman is the only app with a real-time recovery
score (everyone else freezes at wake), which genuinely earns a 3pm reopen — and the only one
that puts a store block and a referral banner in the same scroll as recovery data, which
reviewers name as a trust cost `[W §3.7, §3.8]`. Eight Sleep has been "redesigned five times
in the last four years" and the loudest complaint is not about any layout, it is about
layouts *changing* `[N §4.8, §12.6]`.

---

## 3. What the research forbids

These are bans. A concept that violates one is rejected, not debated.

### On noisy numbers

- **F1. No day-over-day delta on HRV, recovery/readiness, stress, sleep stages, VO2max,
  vitality age, or any sleep score.** Consumer wearable RMSSD limits of agreement are
  ±10 to 24 ms against a healthy population SD of 15 ms; single-night device error is the
  same size as real between-person variation, and biological day-to-day swings stack on top.
  The 14-day study authors' own words: "single-day HRV readings offer limited insight,
  whereas multi-day trajectories provide a more robust signal." Minimum honest window:
  **7 days**, shown as a band. `[CL §1.5, §1.6, §E]`
  *Laso-specific:* `changeChip` today has **no dead band at all** and renders ±1, while the
  same codebase declares ±2 to be noise in `DailyActionResultStore`. `[CRIT §6]`

- **F2. No cross-person HRV comparison, percentile, cohort, or "your HRV is low for your
  age."** The healthy 5-minute RMSSD range is 19 to 75 ms — a 4x spread. A 30 ms reading is
  normal for one person and a red flag for another. Only within-person deviation carries
  signal. `[CL §1.3]`

- **F3. No decimal precision on a derived index, and no minute-level precision on sleep
  stages.** `Strain 14.2` and `Stress 1.2` imply a resolution the model does not have.
  Consumer sleep staging runs κ 0.21 to 0.53 (Apple Watch 0.53, deep-sleep sensitivity
  50.7%), with WASO bias +13.3 min and onset latency bias +2.6 min. `[CRIT §6; CL §3.1]`

- **F4. No probability or percentile as a percentage, and no relative risk.** Only **25%**
  of the general population correctly converts "1 in 1000" to 0.1% (**21%** among
  well-educated adults). About **40%** of US adults have inadequate graph literacy; ~1 in 3
  have both low graph literacy and low numeracy. Use absolute numbers and natural
  frequencies. `[CL §11]`
  *Laso-specific:* "There is about a 62% chance tomorrow feels tougher than usual" and the
  forecast card's "conf 82%" both violate this. The confidence figure is a display heuristic
  derived from interval width, **not a calibrated coverage probability**, and it reads as
  calibrated. `[CAP §6]`

### On unvalidated numbers

- **F5. No unvalidated composite as the largest number on the screen.** A 2025 review
  catalogued **14 composite health scores across 10 manufacturers**: HRV appears in 86%,
  RHR in 79%, and "no manufacturer disclosed how they are algorithmically weighted, nor
  were any validated against clinical outcomes." In D1 swimmers, WHOOP's Recovery score was
  **not** associated with perceived recovery, stress or resting metabolic rate — while the
  raw HRV it measured **was**. The composite is worse than its own inputs. `[CL §4.2, §4.3]`

- **F6. No injury risk, overtraining detection, or burnout detection. Ever.** The ACWR
  literature's own methodologists filed a formal request to retract or correct the founding
  "sweet spot" figure, citing severe mathematical coupling and no causal estimate. The
  ECSS/ACSM consensus is that **no single blood test or biomarker reliably diagnoses
  overtraining syndrome.** Sports medicine cannot do this with blood work. `[CL §6.3, §8]`
  *Laso-specific:* `HealthRiskEngine` ships an `overtraining` profile. It must be renamed
  and re-scoped to a descriptive load statement or removed. `[CAP §3b]`

- **F7. No consumer biological, fitness, or vitality age presented as a fact.** The
  heart-age systematic review (5 randomised web experiments, n=5,514; 5 RCTs, n=9,582) found
  age framing increases emotional response (4/5), increases risk perception but **makes it
  less accurate** ("low-risk people may think they are high risk"), improves recall (4/4) —
  and has **no effect on lifestyle intentions** (4/5) and no effect on behaviour. It is an
  engagement metric dressed as a health metric. Wearable VO2max carries ±3 to 5 mL/kg/min
  error, which is ±3 to 5 years of displayed age. `[CL §9.2, §9.3]`
  *Laso-specific:* the norm tables say so themselves — "no specific source DOIs are linked;
  treat outputs as informational signals only" — and the Home tile prints "3y younger" as a
  flat fact. `[CAP B11]`

- **F8. Never lead with a bad number.** Two controlled sham-feedback experiments:
  Gavriloff et al. (n=63, DSM-5 insomnia) gave **fabricated** sleep-efficiency feedback and
  the negative-feedback group showed decreased alert cognition and increased
  sleepiness/fatigue by evening. Draganich & Erdal (n=164) told participants a fabricated
  REM percentage and those told "below average" performed **worse on memory and attention
  tests**. Orthosomnia prevalence in a general sample (n=523) is **3.0% strict, 8.6%
  moderate, 14.0% lenient**, with significantly higher insomnia scores at every cutoff.
  Between 1-in-33 and 1-in-7 of your users are actively harmed by a sleep score. A negative
  number on Home is not neutral information delivery; it is an intervention with a measured
  harmful effect. `[CL §3.4, §3.5]`

### On persuasion mechanics

- **F9. No compliance streak, no loss framing, no variable reward, no informational nudge
  copy, no deliberate incompleteness.** Each of these is separately refuted or negligible:
  - Lally (n=96, 84 days): a missed day costs **0.29 points on a 0-42 automaticity scale**,
    is not significant, and recovers fully; timing of the miss is irrelevant (r=0.099,
    p=0.246). **A streak lies about the biology.** `[PSY §3, §8]`
  - Loss aversion λ is somewhere between **1.07** (Yechiam & Zeif 2025 re-meta) and **1.955**
    (Brown et al. 2024), median 1.31 with only 6 of 19 studies significant (Walasek 2024).
    Health-message framing effects are "negligible when aggregated." `[PSY §7]`
  - Nudging: **d = 0.43 → d = 0.04** after publication-bias correction (same 334 effect
    sizes, Robust Bayesian Meta-Analysis), with **strong evidence against information
    interventions specifically** (BF₀₁ = 33.84). Structural nudges — defaults and ordering —
    are merely undecided, not refuted. `[PSY §12]`
  - Zeigarnik does not replicate: no memory advantage for unfinished tasks. `[PSY §9]`
  - Variable reward has **no health-trial evidence**; and across 92 RCTs of mental health
    apps there was **no relationship** between number of persuasive design principles and
    completion (r=0.21, p=0.43) or efficacy (b=0.01, p=0.804). `[PSY §6]`
  - SDT (184 data sets): controlled regulation predicts **worse** mental health
    (ρ = .13 to .46). Pressure is not neutral, it is negatively valenced. `[PSY §5]`

- **F10. No asking for input the app then ignores, and no false promise of personalisation.**
  Trust in health tech is the actual constraint: 40% of tracker users are concerned about
  data privacy, **rising to 60% when they subscribe to a service that produces reports from
  that data — the act of turning raw data into a score increases distrust.** Accuracy,
  efficacy, transparency and scientific reliability account for roughly half of all user
  concerns in mHealth app reviews. `[PSY §11]`

### On display form

- **F11. Never show a bare number.** Hsee's evaluability: attributes hard to evaluate in
  isolation carry almost no weight until a comparison is present. And **presentation format
  did not significantly affect recall in any of the three memory studies** in an 18-study,
  12,225-participant systematic review — you cannot design a card that makes people remember
  their number. You can only remove the need to remember it. Ship the comparison on the same
  line, in the same glance. `[UX §5, §11]`

- **F12. Show exactly ONE reference range, and make it the personal goal range.** N=6,766,
  three conditions. Comprehension of the result's relative location: standard range only
  **14.49%** → goal range *added* **35.92%** → goal range *only* **43.45%** (χ²₂=126.9,
  p<.001). Comprehension of expected future location: 22.97% → 37.39% → **46.97%**
  (p<.001). Multiple reference ranges create confusion about which one is relevant.
  **Substituting beats adding.** `[UX §11]`

- **F13. Add a harm anchor to anything that could read as alarming.** N=1,618: adding
  "many doctors are not concerned until here" significantly reduced perceived urgency of
  close-to-normal results (p<.001) and substantially cut the number of people wanting to
  contact a doctor urgently. `[UX §11]`

- **F14. A positional bar, not a line chart, is the default representation of one value.**
  39-study review (27 with human subjects, mean n=369): line graphs are the **most used
  (35%) and among the hardest to read**; "more patients understand the number lines and bar
  graphs compared with line graphs." Horizontal line bars with coloured blocks scored
  highest on satisfaction and usability and **significantly reduced intention to contact a
  physician**. Medium-risk / borderline values were the hardest case across every
  visualisation type, and **confidence in interpretation did not track actual
  comprehension**. Also banned: pie, donut, **gauge**, treemap, and all 3D; colour is
  preattentive but people do not perceive colours as ordered, so colour must never encode
  magnitude. `[UX §10, §11]`

- **F15. No jargon, no invented vocabulary, no engineering language.** Currently shipping:
  `"CONCIERGE"`, `"WHAT WE ARE READING"`, `"Heart Calm Signal"` (used alongside `"Resting
  HR"` and raw `heartRateVariability` — three vocabularies for the cardiac signals in one
  screen), `"Body Intelligence"`, `"Correlation Found"`, `"Patterns found in your data: 12"`
  (an array length as a value proposition), `"Based on 3 of 5 signals"`, `"Likely 61 to 77"`.
  Plus hedged copy that undercuts its own signal: `"Worth Noticing"` rendered beside a red
  `"High"` badge; `"Room to Grow"` for a score below 55. `[CRIT §7]`
  **And rename Stress.** The word promises psychology and delivers physiology; recall for
  psychological stress from wearable signals is **50.0%**. A score that fires on caffeine, a
  hard workout and genuine excitement must not be presented in red under the word "stress."
  The HCI review's recommendation is neutral terminology such as "bodily strain."
  `[CL §5.2, §5.3]`

- **F16. No AI paragraph, and no AI entry point, above the user's own number.** See C9.

- **F17. No permanently identical region.** Banner blindness persists across 1997, 2007 and
  2018 eye-tracking: users skip by location, by visual treatment, and by proximity. One
  right rail took **0.8% of fixations while occupying 25% of the content area — 33x less
  attention than its size warrants.** Apple says the same for widgets: "if a widget's
  content never appears to change, people may not keep it in a prominent position."
  `[UX §8, §12]`

- **F18. Never blur, paywall, hedge, or bury a health warning.** The current build blurs
  `home_alerts`, so a warning the app itself graded "High" sits behind a paywall while the
  Next Up card telling the user what to do stays visible. `[CRIT §4.17]`

### And three things you may NOT cite to justify a minimal screen

Because they will not survive review, and using them will cost the brief its credibility:

| Claim | Status |
|---|---|
| "Miller's 7±2 caps the number of cards" | Refuted. Miller himself said it had "nothing to do with a person's capacity to comprehend printed text." NN/g: "confused designers will sometimes misuse this finding to justify unnecessary design limitations." Visible items are recognition, not recall, and do not consume the limit. `[UX §2]` |
| "Hick's Law says fewer options are faster" | Refuted for HCI (CHI 2020). The original paradigm required trained, equiprobable, direct stimulus-response mappings; real interfaces violate all three and the dominant cost is visual search, not decision. `[UX §3]` |
| "The jam study proves less choice converts better" | Meta-analysis of 63 conditions from 50 experiments, **N=5,036: mean effect size virtually zero.** `[UX §3]` |
| "Decision fatigue / ego depletion" | 23-lab preregistered replication, n=2,141: consistent with a **null**. The hungry-judges effect is overestimated 2-3x by unmodelled case sequencing. `[UX §12]` |

**The defensible justification is attrition, not cognition.** Roughly **53% of mHealth apps
are uninstalled within 30 days**; in one large study mean engagement lasted **4.1 days**;
the top stated reason for abandonment is lack of interest / declining motivation (31.6%).
We have a 30-day window and a 4-day median to prove value. `[UX §12]`

---

## 4. The metric tier list

Every metric and derived score Laso actually computes, placed. Source for capability and
time-to-first-value throughout: `[CAP]`.

### Tier 1 — everyone understands it, it drives behaviour, it belongs on Home

These are the only signals with umbrella-review-level evidence of changing behaviour, or
with a unit the user already owns.

| Signal | Laso source | Why Tier 1 | Display rule |
|---|---|---|---|
| **Steps today** | `stepCount`, daily sum, **iPhone alone works** | The only wearable metric with umbrella-review behaviour-change evidence: **+1,800 steps/day, +40 min/day walking, ~1 kg**. Dose-response: 7,000 vs 2,000 steps/day gives all-cause mortality **HR 0.53 (0.46-0.60)**, with the curve inflecting at 5,000-7,000. `[CL §10.2, §10.3]` | Positional bar against **one** goal range. Anchor at 7,000 with the reason stated in plain words, not 10,000 by default (**fixes B7**). |
| **Active / exercise minutes** | `appleExerciseTime`, Watch | Same evidence base; duration is a unit people live in. Externally anchorable to WHO 30 min, which is what makes Apple's Exercise ring defensible without a medical claim. `[CL §A, §C; P §2.2]` | Progress against goal, same bar grammar as steps. |
| **Time asleep last night** | `sleepAnalysis` summed per wake-day, stored in **hours** | Devices exceed **90% sensitivity for sleep vs wake**. Clock time needs no interpretation. `[CL §3.1, §A]` | h:mm against personal sleep need (`SleepNeedCalculator` already computes this — **fixes B6**), never against a flat 7.5h. |
| **Sleep regularity** — how close to your usual bedtime and wake time | Computable today from wake timestamps; the ingredient already exists inside `BrainHealthScorer`'s circadian-alignment term and `CircadianAnalyzer`, and is **surfaced nowhere** | **The strongest sleep finding of the last three years.** UK Biobank, **n=60,977**, >10M hours of accelerometry, 7.8-year follow-up: all-cause mortality **HR 0.70 (0.59-0.83)** top vs bottom SRI quintile, cardiometabolic **HR 0.62**. Model comparison: regularity is a **stronger predictor of mortality than sleep duration**. It uses only bedtime and waketime — the parts wearables get right — and expresses as a behaviour, not a score. `[CL §3.3]` | "Within 30 minutes of your usual" as a band. This is the single biggest addition available and it is currently absent from Home. |
| **Sleep debt, in hours** | `SleepDebtTracker`, 14-day rolling deficit, needs 7 of last 14 nights | RISE's whole thesis: hours are a unit you already own and can repay tonight. A rolling balance means a bad night dents a balance instead of resetting a streak. `[N §1.2, §1.7]` | **Raise the threshold.** `actionableDebtHours = 2.0` over 14 nights is an 8.5-minute nightly average; it fires for nearly everyone every day, which is exactly the "you are always failing" pattern the card's own doc comment set out to avoid. And frame it as "you are running short," never as an hours-owed ledger — repayment is **not 1:1** and full recovery from chronic restriction takes weeks. `[CRIT §4.7; CL §3.2]` |
| **Resting heart rate, as a multi-day trend in bpm** | `restingHeartRate`, Watch | The most reliable thing a consumer wearable measures: nocturnal MAE **0.98 to 1.78 bpm**, CCC 0.86-0.98. Familiar unit, real population meaning (per +10 bpm, all-cause mortality RR 1.09 to 1.17). `[CL §2]` | Flag **only** at ≥5 bpm or ≥10% above personal baseline sustained **3+ consecutive nights**. One elevated night means almost nothing. `[CL §2.3, §14]` |
| **Today's one action** | `DashboardSmartActionAdvisor` + the 17 policy action types | Not a metric, but the product. Goal setting on *behaviour* (β=+0.89, p=0.001) and graded tasks (β=+0.87, p=0.008) are the two evidence-backed BCTs a Home screen can carry cheaply; digital interventions overall SMD 0.42. `[PSY §10]` | One action, one card, with the two right buttons (done / remind). See §8.1. |
| **Did yesterday's action work** | `RecommendationEvaluator.buildActionProof`, 24h and 7d lift per past recommendation — **computed, and shown only on a detail screen** | Progress monitoring against a goal is the best-evidenced item in the entire psychology corpus: **138 studies, N=19,951, d+ = 0.40 (0.32-0.48), mediation confirmed.** `[PSY §9]` | **Aggregate, never n=1.** "You have done this 6 times; your readiness the morning after averages 4 points higher" is defensible. "Your recovery is +3 higher this morning" is not — the code's own dead band calls ±2 noise and then the copy leaks the magnitude anyway. `[CRIT §4.3]` |

### Tier 2 — understandable with one sentence of framing

Allowed on Home only if the framing sentence ships in the same visual element.

| Signal | Laso source | The sentence it needs |
|---|---|---|
| Distance, flights climbed | iPhone alone works | Needs a comparison ("more than your usual Tuesday"), not a goal. Apple's Highlights proves the delta is legible where the absolute is not. `[P §1.7]` |
| Illness early warning | `IllnessEarlyWarning`: ≥2 of {RHR up, HRV down, sleep down, steps down, resp rate up}, ≥1.0σ, **≥2 consecutive days**, 14-day baseline, suppressed if calories exceeded 1.5x baseline | The gating is genuinely honest and matches the clinical rule (persistence, not a single reading). It needs a plain sentence naming what was noticed and one harm anchor. Currently headed `"Worth Noticing"` next to a red `"High"` badge, at position 13. `[CAP §3c; CRIT §4.13; CL §14]` |
| VO2max as a **broad category**, never a decimal | `vo2Max`, Watch | Cardiorespiratory fitness is the strongest mortality predictor on any consumer screen: elite vs low **HR 0.20 (0.16-0.24)**, larger than smoking (1.41), diabetes (1.40) and CAD (1.29). But wearable estimates carry MAE 3-5 mL/kg/min with LoA to ±7 — enough to move someone a whole category. Show the category and the error, bury the number. `[CL §10.1, §9.2]` |
| Mindful minutes, time in daylight | Watch | Both are behaviours, not scores. Circadian: outdoor light shortly after waking, dim light 2-3h before bed, consistent wake time. Three behaviours, not a number. `[CL §7]` |
| Journal entries, especially alcohol | `StoredJournalEntry`, 9 categories | Alcohol's effect on reported sleep quality (β ≈ **−0.99**) is roughly **twice** the size of HRV's own association with sleep quality (β = 0.51). The behaviour is a bigger lever than the metric, and it needs zero interpretation. `[CL §1.6]` |
| Life context (injured / unwell / travelling / poor sleep week) | `LifeContextStore`, hard override at advisor rung 0 | Genuinely well reasoned: the watch cannot see a sprained ankle. But four always-on toggles at position 2 asks 95% of users daily to declare a problem they do not have. Trigger it contextually — offer "unwell?" exactly when RHR jumps 8% and sleep drops, which is when the app already suspects it. `[CRIT §4.2]` |
| Menstrual cycle phase | `MenstrualCycleTracker`, 365 days of flow samples | A phase label is not a verdict. Needs one sentence about what it means for today. |
| Weight, BMI, body fat | Manual / smart scale | Familiar units, but lagging, noisy and shame-loaded. Apple Fitness omits weight from its home screen entirely and omits intake entirely, deliberately — "the moment burn and intake appear on one screen you have built a diet app." Default off. `[P §2.6]` |
| Blood pressure | External cuff | Clinical, familiar, but needs a range and a harm anchor per F12/F13. |

### Tier 3 — confuses people; belongs one level down, behind exactly one tap

| Signal | Laso source | Why it is demoted |
|---|---|---|
| **Recovery / Readiness 0-100** | `ReadinessScorer`, morning-locked, EMA α=0.7 | The single least-validated element on the current screen. No manufacturer discloses weights, none is validated against clinical outcomes, and the composite tracked perceived recovery **worse than its own raw HRV input**. Users across four of six competitor apps report it contradicting how they feel. If it survives on Home it must not be the largest number, must carry no daily delta, and must be labelled a directional summary. `[CL §4.2, §4.3, §D1]` |
| **Daily Health Score 0-100** | `AnalysisEngine.overallScore` | Coverage shrinkage pulls sparse users toward a constant **75**, presented with the same visual confidence as a fully covered user's score (**B4**). Graded 67/45 in one place and 85/70/55 in another. And it is currently substituted silently for Readiness under a "Readiness" label (**B3**). `[CAP B3, B4; CRIT §4.6b]` |
| **Stress 0-100** | `StressScorer`, HRV vs 14-day baseline 60% + RHR 40%, ready at 3 days | Recall for psychological stress from wearable signals is **50.0%** — a coin flip presented in red. Five documented failure modes: conceptualisation, measurement, transparency, interpretation (red/green imposes a negative frame even on eustress), responsibility. Confounded by caffeine, exercise, illness, alcohol, dehydration, cold hands, loose strap, digestion, and **positive arousal**. `[CL §5]` |
| **Strain 0-21** | `StrainScorer`, log scale, needs DOB | The logarithmic scale is a real comprehension hazard: 18→19 is not the same work as 8→9, but the UI presents them as equal steps. And session-RPE — one subjective 0-10 rating times minutes — correlates with TRIMP variants at **r = 0.79 to 0.86**. A one-question subjective rating performs about as well as the sensor metric. `[CL §6.1, §6.2]` |
| **Brain Health 0-100** | `BrainHealthScorer`, 5 weighted sub-scores, 7-day minimum | An invented composite with no external validation and an unfamiliar name. Its most valuable ingredient (circadian alignment from sleep-timing CV) should be promoted to Tier 1 as sleep regularity and the wrapper demoted. |
| **Sleep stages** (REM / deep / light minutes) | `sleepAnalysis` | κ 0.21 to 0.53. Apple Watch deep-sleep sensitivity **50.7%**. "You got 42 minutes of deep sleep" has an error bar wide enough to swallow the number, and it is the worst accuracy-vs-perceived-authority gap on any health screen. RISE omits stages entirely and is right to. `[CL §3.1; N §1.6]` |
| Health State labels | `HealthStateClassifier`, GMM, 14-day minimum | ML output in ML vocabulary. |
| Blood oxygen, respiratory rate, breathing disturbances | Watch | SpO2 is currently **100% discarded by a bug** (B1) and Home tells every Watch user it is missing. Fix first, then decide. `[CAP B1]` |
| Forecasts (1 / 3 / 7 day, with CIs) | `TimeSeriesForecaster`, Holt-Winters, 7-day minimum | The machinery is real and the intervals are real, but **nothing back-tests forecast accuracy**, and the card's "conf 82%" is an interval-width heuristic reading as a calibrated probability. Sleep forecasts currently render as "0.0h" (B2). `[CAP §6, B2]` |

### Tier 4 — expert vanity; remove, or bury behind two taps in a settings-grade surface

| Signal | Disposition |
|---|---|
| **Vitality Age and Pace of Aging** | **Remove from Home.** Age framing increases emotion, risk perception (less accurately) and recall, with **no effect on lifestyle intentions or behaviour**. Laso's norm tables are documented as heuristic with no DOIs. `[CL §9.3; CAP B11]` |
| **Raw HRV in ms** | Bury. Laso stores **SDNN**, which is not time-invariant and mixes sympathetic, parasympathetic, circadian and respiratory components — it is not the same quantity as RMSSD and must never be shown under a shared "HRV" label. Range 19-75 ms. Home currently calls it "Heart Calm Signal" in one place and `heartRateVariability` in another. `[CL §1.2, §1.3; CRIT §7]` |
| Running form: power, ground contact time, vertical oscillation, stride | Bury. Watch S8+ only, expert-only. |
| Dive depth, water temperature, swimming strokes | Bury. |
| Perfusion index, EDA, PEF / FVC / FEV1, AFib burden as a daily % | Bury. |
| **Activation progress "Day 5 of 7 · 62%"** | **Remove.** A percent of an abstraction, with internal milestone names surfaced to users (`firstCorrelation` → "Correlation Found"). It answers "when will this app be useful," which is an admission that it currently is not. `[CRIT §4.9]` |
| **"Patterns found in your data: 12"** | **Remove.** An array length presented as withheld value. `[CRIT §4.17]` |
| **`DataCoverageCard`, five rows of "12 of 14 days"** | **Remove from Home.** Up to 10 numbers for information that changes twice in a user's lifetime, shown in full whenever any one signal is missing, with a button that deep-links to the Settings root rather than the permission toggle. `[CRIT §4.8]` |
| **Morning check-in composite, `subjectiveReadinessAdjustment`** | **Remove or wire it up.** Written twice, read zero times. There is no third option. `[CRIT §4.10]` |
| **Streak milestone share card** | **Remove from Home.** It occupies slot 4 above the fold at the moment of peak engagement and spends it asking for distribution. `[CRIT §4.4]` |
| **`overtraining` risk profile** | **Remove or rename.** Not a validated capability. `[CL §8]` |

---

## 5. The five questions scorecard

**Q1** What is happening inside my body · **Q2** Is this good or bad · **Q3** Why did this
happen · **Q4** What should I do next · **Q5** What happens if I follow it.

**Rule: anything scoring zero is cut from Home.** No exceptions for "it is only one line."

### Current components

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score | Verdict |
|---|:--:|:--:|:--:|:--:|:--:|:--:|---|
| `CoachGreetingView` (name + date) | · | · | · | · | · | **0** | **CUT.** Renders above the empty state too, so a user with no data is greeted by name while being told the app knows nothing about them. `[CRIT §4.1]` |
| `LifeContextChipRow` (4 chips + up to 4 confirm rows) | · | · | · | · | · | **0** | **CUT as permanent furniture.** It asks a question, it does not answer one, and it is up to 12 tap targets before the user has read anything. Keep the capability, trigger it contextually. `[CRIT §4.2]` |
| `primaryActionCard` "NEXT UP" | · | · | ◐ | **✔** | ◐ | **1.5** | **KEEP, and make it the screen.** `expectedBenefit` (the Q5 line) is populated by **only 1 of 8 advisor rungs**, so the payoff row is conditional on which internal subsystem happened to win, and a fortune-cookie fallback is visually indistinguishable from an ML recommendation. `[CRIT §4.5]` |
| `RecoveryHeroCard` — ring | **✔** | ◐ | · | · | · | **1.5** | Keep the slot. Fix the delta bug, the label bug and the glow bug first. |
| `RecoveryHeroCard` — Why rows (contributors vs personal baseline) | **✔** | · | **✔** | · | · | **2** | **KEEP. Best idea on the current screen.** Drop the circular Energy row; use the real `scoreExplanation` attribution the app already computes. `[CRIT §4.6c; CAP §9.7]` |
| `RecoveryHeroCard` — summary sentence | · | **✔** | · | ◐ | · | **1.5** | Keep as the *only* verdict, but it must stop being a pure band lookup that contradicts the advisor. `[CRIT §5]` |
| `RecoveryHeroCard` — range band + "3 of 5 signals" + certainty bar + missing-signals paragraph | · | · | · | · | · | **0** | **CUT three of the four.** Pick one honesty mechanism. `[CRIT §4.6]` |
| `DailyActionResultCard` (yesterday's result) | · | · | ◐ | · | **✔** | **1.5** | **KEEP the slot, CHANGE the claim to aggregate.** Only component that even tries Q5. `[CRIT §4.3]` |
| `SleepBankCard` (14-bar chart, zero tap targets) | **✔** | ◐ | · | ◐ | · | **2** | **COLLAPSE to one line, or become the action.** A 14-bar chart with no y-axis, no labels, `accessibilityHidden(true)`, 9 numbers and 0 interactions. `[CRIT §4.7]` |
| `DataCoverageCard` | · | · | · | · | · | **0** | **CUT.** `[CRIT §4.8]` |
| `ActivationProgressBanner` | · | · | · | · | · | **0** | **CUT.** `[CRIT §4.9]` |
| `MorningCheckInView` (15 emoji) | · | · | · | · | · | **0** | **CUT or wire.** `[CRIT §4.10]` |
| `WatchComplicationCard` | · | · | · | · | · | **0** | **MOVE.** Good logic, correctly gated, wrong placement — an inline multi-step tutorial at position 11. `[CRIT §4.11]` |
| `AskYourDataCard` "CONCIERGE" | · | · | · | · | · | **0** | **CUT the card, keep the feature.** It is a door, not an answer. Make it a nav-bar affordance. `[CRIT §4.12]` |
| `compactAlertBanner` (illness + risks) | ◐ | ◐ | · | · | · | **1** | **PROMOTE to position 1-3, unhedge, never blur.** Highest-stakes content on the screen, currently at position 13. `[CRIT §4.13]` |
| `MetricStripView` (6 tiles: Vitality, Sleep, Strain, Brain, Stress, Cycle) | ◐ | · | · | · | · | **0.5** | **ADD a verdict per tile, or admit it is navigation.** Five numbers on five unexplained scales with category labels instead of verdicts, and no baseline comparison — the exact comparison the Why rows do correctly. Tiles are built conditionally with no placeholder, so the strip silently changes length and order between days. `[CRIT §4.14]` |
| `WeeklyReviewEntryCard` (daily) | · | · | · | · | · | **0** | **CUT from the daily screen.** A weekly artefact rendering every day, carrying a second unlabelled score delta in the same green treatment as the hero's. `[CRIT §4.15]` |
| Last-updated footer | · | · | · | · | · | **0** | Keep, one line, minimal. Cheapest block on the screen. |
| `softLockBottomBar` + blur | · | · | · | · | · | **0** | **CUT the blur from alerts entirely.** `[CRIT §4.17]` |

### Candidate components for v2

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score | Note |
|---|:--:|:--:|:--:|:--:|:--:|:--:|---|
| **Sleep regularity band** ("within 30 min of your usual") | **✔** | **✔** | · | **✔** | · | **3** | Best-evidenced sleep signal, uses only the parts wearables get right, expresses as a behaviour. `[CL §3.3]` |
| **Steps positional bar vs one goal range** | **✔** | **✔** | · | **✔** | ◐ | **3.5** | Only metric with proven behaviour change; survives iPhone-only; survives day 1. `[CL §10.2, §10.3]` |
| **Action + aggregated proof, in one card** | · | · | ◐ | **✔** | **✔** | **2.5** | Highest-scoring single component available. The machinery exists and is buried one tap deep. `[CAP §9.8]` |
| **Intelligence briefing, one sentence** | **✔** | · | **✔** | · | · | **2** | Computed on every refresh, rendered only on Explore. The cheapest large win available. `[CAP §9.1]` |
| **Delta vs last week, in plain words** | **✔** | **✔** | · | · | · | **2** | Apple's Highlights pattern. A delta is legible where an absolute is not. Weekly window only, never daily on a noisy signal. `[P §1.7; CL §E]` |
| **One-clause cause attached to the verdict** ("sleep 52 min short") | · | · | **✔** | · | · | **1** | The single thing no competitor does. See C2. |

---

## 6. Hard design constraints

Numbers, not adjectives. Every concept is measured against these.

### Budgets

| Constraint | Limit | Now | Basis |
|---|---|---|---|
| Cards above the fold | **≤ 3** | 5-6 | NN/g eye tracking (130,000+ fixations, 120 participants): **57%** of viewing time above the fold, **74%** within two screenfuls, only 26% beyond; **>65%** of above-fold time in the **top half**; content 100px above the fold gets **102% more views** than content 100px below. Headspace's own fix was to cap Today at three cards. `[UX §7; N §8.9]` |
| Total blocks on the default morning | **≤ 7** | 13 | `[CRIT §1]` |
| Numbers on screen, default morning | **≤ 12** | ~28 | `[CRIT §2]` |
| Numbers above the fold | **≤ 5** | 10-12 in the hero card alone | Cowan: focus-of-attention capacity ≈ **4 chunks**, not 7. `[UX §2]` |
| Facts a user must combine to interpret any one element | **≤ 2, and 0 is the target** | `Strain 14.2 · High` requires a score 7 cards away | Element interactivity is the mechanism behind every extraneous-load effect. **Put the comparison inside the same visual element.** `[UX §1]` |
| Tap targets, default morning | **≤ 8** | 23 (45+ worst case) | `[CRIT §3]` |
| Distinct exits from Home | **≤ 6** | 21 | A screen with 21 exits has no opinion; it is a menu. `[CRIT §3]` |
| Disclosure levels below Home | **≤ 2** | 3+ | More than two levels "typically show low usability because users often get lost." `[UX §4]` |
| Words of copy above the fold | **≤ 20** | ~45 | See the reading budget below. |
| Confidence / uncertainty widgets per number | **1** | 4 | `[CRIT §2]` |
| Reference ranges shown per number | **exactly 1**, the personal goal range | mixed | 14.49% → 43.45% comprehension, N=6,766, p<.001. `[UX §11]` |

### The 5-second comprehension goal, broken into a timeline

Category benchmark for time in a health app is ~2.5 minutes/day; mobile sessions average
**72 seconds** against 150 on desktop; Athlytic ships an explicit **10-second** readiness
target. `[W §9, §4.3; UX §7]` Our budget is tighter than all of those, because the top of
the screen has to work before the session begins.

| Window | What must land | How |
|---|---|---|
| **0 to 1s** | Is today good, ordinary, or worth attention | A **non-textual** channel: band position plus colour plus shape. **No reading, no number.** This is the Apple Fitness rings standard and it is the only home screen in the corpus that clears it. `[P §2.7]` Colour must never be the sole channel (HIG + WCAG). `[UX §8]` |
| **1 to 3s** | The one thing to do today | **One sentence, ≤ 12 words.** Not a paragraph. Eight Sleep put a paragraph above the number and got "I don't know who thought anyone wanted to read that with their eyes half open." `[N §4.9]` |
| **3 to 5s** | Why today looks like this | **One clause**, attached to the verdict, naming one cause with its magnitude. Example shape: "sleep 52 minutes short of your usual." This is the C2 open lane. `[W §1.9]` |
| Beyond 5s | Everything else | Below the fold or one tap down. Assume everything past screen two is optional. `[UX §7]` |

### Typography, contrast, touch

Non-negotiable platform floors, from Apple HIG and WCAG. `[UX §8, §9]`

- Body text **17pt** default, **11pt** absolute minimum. Avoid light weights; prefer Regular,
  Medium, Semibold, Bold.
- Contrast **4.5:1** up to 17pt, **3:1** at 18pt or bold. Aim **7:1** for custom small text.
- Dynamic Type **Large through AX5**. Keep primary elements at the top at every size;
  maintain hierarchy regardless of font size; minimise truncation at the largest sizes.
- Touch targets **44pt** (Apple) / **48dp** (Material) with **≥8dp** separation.
- Line length **50 to 75 characters**.
- Design the top cluster on a **5.4" viewport first.** Garmin's "the glance section is
  squished, since I don't own a jumbo-screen phone apparently" is a breakpoint failure, not
  a taste failure. `[W §6.8]`
- Interactive controls in the lower two-thirds where the thumb reaches; the top strip is for
  reading, not tapping (49% one-handed, thumbs drive ~75% of interactions). `[UX §7]`
- Scanning target is **layer-cake**, not F. Every element gets a short, front-loaded,
  information-carrying heading with the number directly under or beside it and the
  interpretation under that. Never place meaning-critical content on the right edge.
  Front-load headings so they do not all begin with "Your". `[UX §6]`

### What must survive with iPhone-only data

With no Watch, these are **all unavailable**: Recovery/Readiness, Stress, Brain Health,
Sleep Debt, Sleep Need, the sleep tile, Strain HR zones, and **4 of the 5 Why rows**.
Vitality still runs but loses VO2max (.25), HRV (.20) and RHR (.15) — 60% of its weight.
`[CAP §7]`

**What an iPhone-only user genuinely has:** steps, distance, flights climbed, the whole
mobility family (walking speed, step length, asymmetry, double support, stair speeds,
steadiness, falls), headphone/environmental audio, anything a third-party app or manual
entry writes, journal, life context, week-over-week movement trends, and a coverage-shrunk
Daily Health Score.

**Constraint:** every concept must define its hero slot's **iPhone-only variant**, and that
variant must be a real, labelled, lower-confidence answer — **not an empty ring, not a
hardware upsell, and not a silently substituted different score.** Samsung gated its hero
Energy Score behind a Galaxy Watch or Ring and left the top slot empty for most of a
65M-MAU install base; the research stream calls it "the single biggest own-goal in this
teardown." `[P §5.2]` Laso's current answer is worse: it substitutes a different index
under the same label (**B3**).

### What must survive on day 1 with no history

Critical nuance: **first sync pulls 10 years of HealthKit history**, so "new user" is not
the same as "data-poor." `[CAP §8]` Three distinct day-1 states, and every concept must
render all three:

| State | What is honest | Time-to-first-value |
|---|---|---|
| **A. Day 1, 1+ year of Watch history** | Everything except Vitality's full personalisation (7-day hold) and the 30-day discovery reveal. This is the common case and it should feel like a finished product. | immediate |
| **B. Day 1, genuinely new wearable data** | Same-day steps and distance only. Then Stress at day 3; the 7-day wall opens baselines, brain health, sleep debt, sleep need, forecasts, circadian; days 14-30 open illness warning, correlations, ML state, tomorrow risk, Vitality personalisation. | 7 days for anything with a baseline |
| **C. Day 1, iPhone only, no wearable** | Steps, distance, flights, mobility, journal, life context, and a Daily Health Score dominated by a **75 prior**. **Nothing else is honest.** | immediate, permanently limited |

Rules that follow:

1. **Nothing that needs ≥7 days may render as a confident number before it has 7 days.**
   Apple Fitness time-locks Trends until enough history exists, deliberately, "because a
   trend computed on 4 days of data is noise, and showing noise as insight destroys trust
   permanently." `[P §2.5]`
2. **Never show an empty 0-of-N where backfill can legitimately fill it.** Endowed progress
   is the cheapest, best-evidenced mechanic in the psychology corpus: car wash field study,
   300 loyalty cards, identical real effort, completion **19% → 34%** by reframing "not yet
   begun" as "already underway." `[PSY §8]`
3. **An empty goal-shape beats an absent number.** An unfilled ring says "fill me"; a blank
   tile says "this app is broken." `[P §7.4]`
4. **A day-1 screen and a day-200 screen may differ in density, not in structure.**
   Progressive unlock is literacy scaffolding, not a loading bar over the first week of the
   relationship.

### Bugs that must be fixed before the redesign can be honest

**B1** blood oxygen filter (one line: bounds should be 50-100, not 0.5-1.0) and **B2** sleep
forecast unit divide are one-line fixes that today make Home actively lie. **B3** hero ring
substitution, **B5** circular Energy row, **B6** hardcoded 7.5h sleep goal and **B7**
hardcoded 10,000 step goal are all inside the redesign's blast radius. **B4** (75 prior
presented at full confidence), **B8** (size test labelled as a trend), **B10** (±2% moves as
"wins") and **B11** (heuristic norms printed as fact) each require a labelling decision, not
just a code fix. `[CAP §10]`

---

## 7. The ten open design tensions

These are the real tradeoffs. **Every concept must resolve each one explicitly and state
which side it took.** Concepts that resolve all ten the same way are the same concept.

**T1. Score-first or action-first.**
The current card comment says "Laso's core promise is telling you what to do next, so the
step comes before the score that explains it" — and then the hero score renders directly
below it and contradicts it `[CRIT §4.5, §5]`. Athlytic, Whoop, Oura, Samsung and Eight
Sleep all put the score first. RISE, Gentler Streak and Headspace put the instruction first.
The trade: a score answers "how am I," which is the question users say they open with; an
action answers "what now," which is the only thing that changes an outcome. **Do not do
both at equal weight** — that is the current failure.

**T2. One hero number, or a cluster of three to six.**
Athlytic 1 vs Oura 5-6. The apps with the clearest identity have the fewest; Oura's cluster
drew "it dilutes the information too much, and doesn't really make your actual data very
clear" from the most credible reviewer in the category `[W §2.8, §10.1]`. But one number
means one point of failure, and Laso's most defensible single number (Readiness) is
unavailable to iPhone-only users and is the least validated thing on the screen `[CL §4.2;
CAP §7]`. Welltory's three simultaneous percentages that move independently is the failure
case: users have no rule for which to obey when they disagree `[N §5.8]`.

**T3. A graded verdict, or a range you sit inside.**
Whoop's green/yellow/red is a moral vocabulary with no neutral state; Gentler Streak's band
has **no failure state at all**, and below the band means capacity rather than failure
`[W §1.4; N §2.2]`. Oura splits the difference: a single wide 0-69 bottom band that refuses
to grade degrees of bad `[W §2.4]`. The trade is signal strength against harm: F8 says
never lead with a bad number and 3-14% of tracker users already meet an orthosomnia
definition, but Garmin's 2024 desaturation removed the only free emotional feedback the
screen had and users noticed the loss `[W §6.4]`. **No emotion is not the safe answer.**

**T4. A borrowed unit, or a native index.**
Debt in hours (RISE), battery percent (Welltory, Garmin), a bank you spend (Bevel), a green
band (Gentler Streak), a floored letter grade (Levels), minutes toward 30 (Human) — versus
"Readiness 72," "Sleep Fitness Score 82," "ZOE score 68." The research stream's verdict is
blunt: the weakest home screens "require the app to teach a scale before the number means
anything, and the teaching never sticks" `[N §12.2]`. Laso already owns two borrowed units
it under-uses: **sleep debt in hours** and **steps against 7,000**. The trade is that a
borrowed unit constrains what you can express; an index can express anything and means
nothing.

**T5. Explanation inline, one tap down, or a paragraph.**
No competitor explains on the home screen, and every competitor gets complained at for not
explaining — this is the single clearest open lane in the corpus `[W §10.2]`. But Eight
Sleep put a paragraph above the number and was punished, and Google put AI narration above
the metrics and got 3,419 revert votes `[N §4.2; P §3.8]`. The available resolutions:
one clause inline on the same line as the number; two contributor chips under it; a
`Because →` affordance that expands without navigating; or the current model, which is five
tappable rows that are each a navigation exit and therefore a router, not an explanation
`[CRIT §4.6]`.

**T6. Celebration, or calm.**
Fogg's position is that a returning user is already above the activation threshold, so
motivational persuasion "would either be annoying or condescending" and the screen should
spend itself on removing brain cycles `[PSY §1]`. Against that: immediate acknowledgement at
the moment of completion is cheap and low risk `[PSY §2]`, and gamification **survived
withdrawal** in a 1,062-patient cardiology RCT (+459.8 steps/day at 6-month follow-up,
p significant) where pure financial incentive did not `[PSY §5]`. But absolute effect sizes
are 500-900 steps/day, and attrition was **lower** in apps *without* gamification features
in one narrative review `[PSY §13]`. If a concept keeps any streak at all, it must be on the
record-keeping, never on compliance (D7), and it must have a forgiveness mechanic from day
one (F9).

**T7. Density, or scroll.**
Whoop shipped a dense scroll and gets 83% DAU/MAU, roughly 3-10x the category — but new
users find it "daunting" `[W §1.8, §1.10]`. Garmin went the other way and got "the emphasis
on larger cards and a cleaner aesthetic means less information fits on the screen at once,
forcing users to scroll more frequently to access the same metrics they could previously see
with a quick glance," plus the "At a Glance" paradox of having to scroll to see something
labelled at-a-glance `[W §6.8]`. Google Health's redesign produced "a huge block of empty
space" and "why so much white wasted space?" `[P §3.8]`. **Sparse is not automatically
calm.** Apple's own rule: "sparse layouts can make the widget seem unnecessary, while overly
dense layouts are less glanceable" `[UX §8]`.

**T8. Fixed slots, or contextual morphing.**
Habit formation says the strongest lever an app has is **being the same thing in the same
place at the same time**, and a screen that reorders daily is destroying the cue-response
associations it needs `[PSY §4]`. Banner blindness says the opposite: a region that renders
identically every day stops being seen, at up to 33x under-attention `[UX §12]`. Oura ran
the natural experiment — full-screen time-of-day morphing failed and was attacked by
designers; **single-slot** morphing inside a fixed structure survived and shipped `[W §2.8]`.
And the loudest single complaint in the entire niche teardown is not about any layout, it is
about layouts changing: "redesigned five times in the last four years" `[N §12.6]`.

**T9. Honest uncertainty, or confident simplicity.**
The clinical literature's explicit recommendation is **seamful design**: expose the
limitation rather than hiding it, and involve people in data sense-making rather than
handing them "judgmental interfaces that dictate interpretations" `[CL §5.2, §13]`.
Communicating point estimates **and** intervals produces better decisions than point
estimates alone — but showing a confidence number alone is insufficient, and explanations
themselves can become trust heuristics that worsen over-reliance when the advice is wrong
`[PSY §11]`. Meanwhile Laso currently ships **four** simultaneous uncertainty widgets under
one ring, which is the reductio `[CRIT §2]`. The tension: one honesty mechanism is required,
four is noise, and zero is the Bevel failure ("presents confident daily conclusions" without
"showing its work") `[W §5.8]`.

**T10. An opinionated hierarchy, or user pinning.**
Every app that could not decide shipped customisation instead (C7), and Google answered a
hierarchy complaint with a customisation roadmap item `[P §7.3]`. But Apple Health's
Favorites is a **user-declared salience filter** that stops the app from guessing, and it is
the change MacStories appreciated most `[P §1.7]`; Human Health's Pinned Insights and
Bearable's fully user-configured home are correct precisely because the relevant metric
differs per person `[N §6b, §11.7]`. SDT says autonomy support predicts better outcomes
(ρ = .21 to .48) `[PSY §5]`. The resolution space is whether pinning happens **inside** a
fixed hierarchy (allowed) or **instead of** one (banned).

---

## 8. Non-negotiables

Every concept ships these regardless of its philosophy. A concept missing one is not a
concept, it is a draft.

**N1. One answer to "what should I do today."**
Exactly one component on the screen gives an instruction. Not three, and not one that can
contradict another card two positions down. If sleep debt is the biggest thing about today,
sleep debt **becomes** the action card; it does not sit beside it giving a fourth
instruction. `[CRIT §5, §12]`

**N2. Every number ships with its comparison and a plain-word verdict, in the same visual
element, or it does not ship.**
A positional bar with **exactly one** reference range — the personal goal range, not a
population band, and never both. A plain sentence alongside the visual, because ~1 in 3
users cannot read the graph. A harm anchor on anything that could alarm. No bare numbers.
No number that requires another number on the screen to interpret it. `[UX §11; CL §11]`

**N3. No day-over-day delta on anything HRV-derived, and no single-reading alerts.**
Minimum honest window for HRV, recovery, stress, sleep stages, VO2max and any sleep score is
**7 days**, shown as a band the user sits inside. RHR flags only at ≥5 bpm or ≥10% above
baseline sustained **3+ consecutive nights**. Illness warnings keep their existing 2-metric
/ 2-day persistence gate. `[CL §E, §2.3, §14]`

**N4. The screen never asks for input it does not use, and never shows a number it cannot
honestly compute.**
The morning check-in either visibly moves the number and says so, or it comes off the
screen. B1 and B2 are fixed before anything is promoted. B3's silent score substitution is
replaced by an explicit different state. B6 and B7's hardcoded goals are replaced by the
personalised values the app already computes. `[CRIT §4.10, §12; CAP §10]`

**N5. Degrade, never disappear.**
Every concept defines its hero slot for three states: full wearable data, iPhone-only, and
genuinely new. Each state is a real, labelled, lower-confidence answer using the **same slot
structure**. No empty hero. No hardware upsell in the hero. No silent substitution of a
different index under the same label. Nothing that needs 7 days renders confidently before
it has 7 days. `[CAP §7, §8; P §5.2, §2.5]`

**N6. A health warning is never blurred, paywalled, hedged, or below position 3.**
Anything the app is willing to grade "High" sits above the fold or does not exist. The
header states what was noticed in a sentence; it does not say "Worth Noticing" next to a red
badge. Whatever the monetisation strategy, "we found something concerning, pay to see what"
is not a position this product can reach. `[CRIT §4.13, §4.17]`

**N7. No guilt architecture, and a working escape hatch.**
No compliance streak (record-keeping streaks only, with forgiveness built in from day one).
No loss framing. No score floor at zero. No "you failed today" state. Rest counts as
compliance. One missed day costs the user nothing, because in the best real-world habit data
it costs 0.29 points out of 42 and fully recovers. And because some fraction of users are
harmed by any screen we build, there is a one-tap way to hide metrics, turn scores off, and
see raw data with no verdict attached — this is the only mitigation the self-tracking harms
literature actually offers. `[PSY §3, §7, §13; N §12.4]`

**N8. Fixed slot order, plain English, every day.**
The slot sequence is identical every morning; only the content inside a slot changes.
Time-of-day variation happens **inside one named slot**, never by reordering the screen.
Every user-visible string lives in `Common/Copy/Copy+*.swift`. No coined vocabulary, no
engineering language, no jargon: "CONCIERGE", "WHAT WE ARE READING", "Heart Calm Signal",
"Body Intelligence", "Correlation Found", "Patterns found in your data: N", "Based on 3 of 5
signals" are all gone. One vocabulary per concept — pick one word for the cardiac signal and
use it everywhere. No decimal precision on a derived index. And "Stress" is renamed to
something that describes what the sensor measures. `[PSY §4; CRIT §7; CL §5.2; N §12.6]`

---

## Appendix: the three sentences that must be true after the redesign

1. **One answer to "what should I do today."** Not three, and not one that can contradict
   another card two positions down.
2. **Every number on screen carries a verdict.** Either the number says whether it is good or
   bad against the user's own baseline, or the number does not render. There is no third
   state.
3. **Nothing on the screen asks the user for input that the app then ignores.**

`[CRIT §12]`
