# Concept 04 — Sleep and body clock first

**File:** `design/home-v2/concepts/04-sleep-first.html`
**Date:** 2026-07-29
**Fictional user:** Alex, 34. Slept 6h 12m against a 7h 40m personal need. Bedtime has
drifted 40 minutes later across the week. 8,400 steps yesterday. Resting heart rate 58 bpm.

---

## 1. The one-sentence philosophy

**Sleep timing is the biggest lever most people actually own, so the screen shows two clock
quantities — when to go to bed tonight, and how last night landed — and nothing else has a
score attached to it.**

There is no index anywhere on this screen. No Readiness, no Daily Health Score, no Stress,
no Strain, no Brain Health, no sleep score, no vitality age, no stages, no percentage. Every
number on the default morning is either hours and minutes or a clock time. That is the whole
commitment.

---

## 2. Why this layout order, element by element

The slot sequence is fixed and never reorders. Only the content inside a slot varies.

| # | Slot | Renders when | Why here |
|---|---|---|---|
| 0 | **Header** — day name + escape hatch | always | One word and one 44px control. No greeting. `CoachGreetingView` scores 0/5 on the questions scorecard and renders above the empty state, greeting a user by name while telling them the app knows nothing `[CRIT §4.1]`. Cut. |
| 1 | **Notice** — a health warning | only when the illness gate fires | N6 says a warning is never blurred, paywalled, hedged, or below position 3. This is position 1, unblurred, with no paywall and no button. It states what was noticed in a sentence and carries a harm anchor. It gives **no instruction** — that stays in slot 2. Absent on the default morning, so it costs the budget nothing on a normal day. |
| 2 | **Tonight** — the hero, and the only instruction | always | Two quantities. The big one is **tonight's lights-out time**, a forward-looking clock time the user can still act on. Below the divider, **last night's hours** against the personal need. The order is deliberate: the remedy sits physically above the reading. |
| 3 | **Nights** — 14 nights of sleep timing, as a chart | always | The regularity evidence, and the one thing on this screen no competitor ships. Below the fold by design; the hero has already answered the 0-5s questions. |
| 4 | **Everything else** — movement and resting heart rate, collapsed | always | The thesis made structural. If sleep is upstream, everything else is literally downstream, below, and folded shut. Collapsed it carries a verdict and zero numbers; expanded it carries two numbers with their bands. |
| 5 | **Footer** — last updated | always | The cheapest honest block on the screen `[CRIT §4.16]`. |

### The hero's internal order is the 5-second timeline, top to bottom

- **0 to 1s, no reading required.** The clock rail. A soft band is your usual lights-out
  window, a solid marker is tonight, seven ghost dots are your last seven bedtimes, and a
  curved arrow points from last night back into the band. Position, shape and colour all
  carry the same message, so colour is never the sole channel (HIG + WCAG, `[UX §8]`). The
  arrow only appears when the drift is real (≥25 min), so a steady week reads calm with no
  chromatic event at all.
- **1 to 3s.** *Lights out — 10:30 PM.* Two words and a clock time. Not a paragraph. Eight
  Sleep put prose above the number and got "I don't know who thought anyone wanted to read
  that with their eyes half open" `[N §4.9]`.
- **3 to 5s.** *Bedtime slipped **40 minutes** later.* One clause, one cause, its magnitude.
  This is the C2 open lane — four of six competitor apps show no reason at all `[W §7]`.

---

## 3. Psychological principles used, and the specific mechanism

**Remedy above, reading below — the F8 mitigation.** F8 forbids leading with a bad number,
and it is not a style rule: Gavriloff et al. (n=63, DSM-5 insomnia) gave *fabricated*
sleep-efficiency feedback and the negative-feedback group showed measurably decreased alert
cognition and increased fatigue by evening; Draganich & Erdal (n=164) told people a
fabricated REM figure and the "below average" group performed **worse** on memory and
attention tests `[CL §3.4]`. Orthosomnia prevalence is 3.0% strict to 14.0% lenient, with
significantly higher insomnia scores at every cutoff `[CL §3.5]`. Between 1-in-33 and
1-in-7 users are harmed by a sleep score.

So the largest element on this screen is **not** last night. It is tonight. 6h 12m still
appears — hiding it would be dishonest — but it can only be reached by reading past its own
fix, at 28px instead of 56px, with no grade, no colour, no band label like "Poor". The
positional marker is the verdict. This is the concept's single most important structural
decision and it is why the whole screen is arranged the way it is.

**A behaviour, not an outcome.** You cannot decide to have more deep sleep. You can decide
when to switch the light off. Goal setting on *behaviour* is β=+0.89, p=0.001, and graded
tasks β=+0.87, p=0.008 — the two evidence-backed BCTs a home screen can carry cheaply
`[PSY §10]`. The hero's instruction is a behaviour with a time attached, which is RISE's
"avoid caffeine after 1:14pm" pattern: the difference between advice and an instruction
`[N §1.7]`.

**A balance, not a streak.** No compliance streak exists anywhere. A missed night moves a
14-night picture slightly; it resets nothing. Lally (n=96, 84 days): a missed day costs
0.29 points on a 0-42 automaticity scale, is not significant, and fully recovers `[PSY §3]`.
Four late nights in a row still render as "Mostly steady" with 10 of 14 inside the window,
because that is what the data says.

**No loss framing and no debt ledger.** The word "debt" never appears. Repayment is not 1:1
and full recovery from chronic restriction takes weeks `[CL §3.2]`, so an hours-owed balance
implies an exchange rate the literature explicitly denies. The shortfall is stated once, in
plain words, inside an expander: "roughly 45 minutes less sleep a night."

**Endowed progress, day 1 only.** The new-user hero shows a 7-pip shape with 2 filled beside
"From 2 nights. Yours appears at 7." Car-wash field study, 300 loyalty cards, identical real
effort: completion 19% → 34% by reframing "not yet begun" as "already underway" `[PSY §8]`.
It is a record-keeping shape, not a compliance shape, and it disappears the moment the
window exists.

**Autonomy, not pressure.** SDT across 184 data sets: controlled regulation predicts *worse*
mental health (ρ = .13 to .46); autonomy support predicts better outcomes (ρ = .21 to .48)
`[PSY §5]`. The only persuasion mechanic on the screen is one optional reminder, and its
confirmation copy is "Reminder set. One nudge, then nothing."

---

## 4. UX principles applied

**Layer-cake scanning `[UX §6]`.** Every element is a short front-loaded heading, then the
number directly under it, then the interpretation under that. Headings are `Tonight`,
`Nights`, `Everything else`, `Last night`, `Up and moving` — none begins with "Your".
Nothing meaning-critical sits on the right edge; the one right-edge object is the
progress-pip shape in the new-user state, which restates in shape what the sentence beside
it already says in words.

**A positional bar, never a line chart `[UX §10, §11]`.** Every quantity on this screen is a
number line: a track, one goal band, one marker. The 14-night chart is 14 positional bars on
a shared clock axis. No pie, donut, gauge, treemap or 3D anywhere. Colour never encodes
magnitude — all 14 bars are the same ink, and the *band* is the coloured object, so a late
night is communicated by where it sits, not by turning red.

**Exactly one reference range, and it is personal `[UX §11]`.** Comprehension of a result's
relative location: standard range only 14.49% → goal range added 35.92% → goal range **only**
43.45% (N=6,766, χ²₂=126.9, p<.001). Substituting beats adding. Last night's hours are shown
against the personal 7h 40m need that `SleepNeedCalculator` already computes — never against
a flat 7.5h, which fixes **B6**. Steps are shown against a personal goal range anchored at
7,000, not a hardcoded 10,000, which fixes **B7**.

**Harm anchor on the only alarming element `[UX §11]`.** N=1,618: adding "many doctors are
not concerned until here" significantly reduced perceived urgency and cut the number of
people wanting to contact a doctor urgently. The notice ends with "Doctors do not usually
act on a change this size unless it lasts more than a week."

**One honesty mechanism, not four.** The current build ships four simultaneous uncertainty
widgets under one ring `[CRIT §2]`. This screen ships exactly one: a single line naming what
the answer was built from and where it stops being exact. It is the same line in all three
data states and it is the only place uncertainty is discussed.

**Two levels of disclosure, both in place `[UX §4]`.** More than two levels "typically show
low usability." Home → an expander that opens without navigating. No modal, no push, no
router. The five tappable "Why" rows on the current screen are each a navigation exit, which
makes them a router, not an explanation `[CRIT §4.6]`.

**5.4-inch first `[W §6.8]`.** Every measurement below was taken in a real browser at
375×812 with the scroll area clamped to 678px, which is what an iOS app gets after the
status bar and tab bar. The hero card ends at 644px; the Nights card begins at 656px, so
only its heading touches the fold.

**Thumb zone `[UX §7]`.** The only controls above the midpoint are the escape hatch (44×44,
top right, conventional position) and the reminder button (372×52, at y≈590, comfortably in
reach). Everything else is in the lower third or the tab bar.

---

## 5. Which user problems it solves

| Problem | How |
|---|---|
| "Three components tell me what to do and none knows the others exist" `[CRIT §5]` | One component gives an instruction. The Nights card describes, the Everything-else card verdicts, the notice reports. None of them instructs. |
| "The hero number and the chip under it describe different quantities" `[CRIT §4.6a]` | Both hero quantities are the same substance (sleep timing) in the same unit family (clock time and h:mm), derived from one array of nights. |
| "The label lies in the fallback case" (**B3**) | There is no fallback substitution. Three explicitly different, explicitly labelled hero states, all with the same slot structure. |
| "28 numbers and one verdict sentence" `[CRIT §8]` | 10 numbers, every one with a band and a plain-word verdict inside the same element. |
| "The screen collects input it ignores" `[CRIT §4.10]` | The screen asks for nothing. The only input is one optional reminder, and it fires. |
| "A High warning at position 13, blurred behind a paywall" `[CRIT §4.13, §4.17]` | Position 1, unblurred, unhedged, no paywall, with a harm anchor. |
| "The best content the app computes never reaches Home" `[CAP §9]` | Sleep regularity — the ingredient already sitting inside `BrainHealthScorer`'s circadian term and `CircadianAnalyzer`, surfaced nowhere — becomes the centrepiece. |
| Orthosomnia and sleep anxiety `[CL §3.4, §3.5]` | No score, no stages, no grade, no red on any sleep number, the fix above the reading, and a one-tap way to switch every verdict off. |
| Cold start `[W §10.7; P §5.2]` | A distinct, real, labelled day-1 hero in the same slot, with a provisional window and an honest "yours appears at 7". |

---

## 6. Which metrics were given prominence, and why

| Metric | Placement | Why |
|---|---|---|
| **Tonight's lights-out time** | hero, 56px | Tier 1 behaviour. A clock time needs no scale taught (T4, `[N §12.2]`). It is the only quantity on the screen the user can still change today. |
| **Time asleep last night, h:mm** | hero, 28px, below the fix | Devices exceed **90% sensitivity for sleep vs wake** `[CL §3.1]` — this is one of the few sleep numbers a wrist device is actually right about. |
| **Sleep regularity** | whole second card + the hero's ghost dots and drift clause | UK Biobank, n=60,977, >10M hours of accelerometry, 7.8-year follow-up: regularity is a **stronger predictor of all-cause mortality than sleep duration**, and it uses only bedtime and waketime — the parts wearables get right `[CL §3.3]`. It is currently absent from Home. This concept exists to fix that. |
| **Personal sleep need, 7h 40m** | the single reference band on the hours line | Fixes **B6**. |
| **Steps, against 7,000** | inside the collapsed card | The only wearable metric with umbrella-review behaviour-change evidence; 7,000 vs 2,000 steps/day gives all-cause mortality HR 0.53 `[CL §10.2]`. Anchored at 7,000, not 10,000 (fixes **B7**). Demoted because it is not the concept's lever. |
| **Resting heart rate** | inside the collapsed card; escalates to slot 1 only on the persistence gate | The most reliable thing a consumer wearable measures, nocturnal MAE 0.98–1.78 bpm `[CL §2]`. Flags only at the ≥5 bpm / ≥10% over 3+ nights rule, so 58 against a 55 baseline correctly does **not** fire. |

---

## 7. What was deliberately removed, and why

| Removed | Reason |
|---|---|
| **Every 0-100 index** — Readiness, Daily Health Score, Stress, Strain, Brain Health | F5: 14 composite scores across 10 manufacturers, none disclosing weights, none validated against clinical outcomes; in D1 swimmers WHOOP's Recovery score was **not** associated with perceived recovery while the raw HRV it measured **was** `[CL §4.2, §4.3]`. If the composite is worse than its own inputs, a screen with a strong thesis does not need it. |
| **Any sleep score** | F8 plus the orthosomnia data. A sleep score is the single highest-harm object available to this product. |
| **Sleep stages (REM / deep / light)** | κ 0.21–0.53, Apple Watch deep-sleep sensitivity **50.7%** `[CL §3.1]`. "42 minutes of deep sleep" has an error bar wide enough to swallow the number, and it is unactionable. RISE omits stages entirely and is right to `[N §1.6]`. |
| **The word "debt" and any hours-owed number** | Loss framing, and the exchange rate it implies does not exist `[CL §3.2]`. Laso's own `actionableDebtHours = 2.0` over 14 nights is an 8.5-minute nightly average, which fires for nearly everyone every day `[CRIT §4.7]`. |
| **Raw HRV in ms** | Laso stores SDNN, which is not the same quantity as RMSSD and must never share an "HRV" label `[CL §1.2]`. Tier 4. Also invisible to iPhone-only users, so it cannot anchor a hero. |
| **Vitality age / pace of aging** | F7. Age framing increases emotion and risk perception while making it *less* accurate, and has **no effect on lifestyle intentions or behaviour**. Laso's own norm tables are documented as heuristic with no DOIs (**B11**). |
| **Life-context chip row, morning check-in, data-coverage card, activation banner, streak share card, "CONCIERGE", weekly review entry, watch tutorial** | All score 0 on the five-questions scorecard `[CRIT §11]`. |
| **Any AI entry point above the user's number** | F16 / C9. Fitbit's revert thread ran to 3,419 votes and a 39-item apology roadmap in 8 days `[P §3.8]`. |
| **A percentage anywhere** | F4. Only 25% of the general population converts "1 in 1000" to 0.1%; ~40% of US adults have inadequate graph literacy `[CL §11]`. |

---

## 8. Expected impact on daily engagement, with the mechanism

**Direction: fewer sessions, higher completion per session — deliberately.** This is
Athlytic's bet, not Whoop's `[W §4.3]`. The hero answers the morning question in about two
seconds and there is nothing to reconcile, so the morning session should get shorter.

The mechanism that adds a *second* daily open is the evening flip inside the Tonight slot.
At 6pm the same slot stops showing last night and starts showing the wind-down time. This is
the C6 pattern — one fixed slot whose content varies by time of day — and it is the version
that survived: Oura's full-screen time-of-day morphing was attacked by designers and pulled,
while single-slot morphing shipped `[W §2.8]`. It creates a genuine second reason to open
without adding a card or moving anything.

The reminder is the real engagement mechanic and it is intentionally weak: one optional
nudge, at one time, that the user set. Nudging effect sizes collapse from d = 0.43 to
d = 0.04 after publication-bias correction, with **strong evidence against information
interventions specifically** (BF₀₁ = 33.84) `[PSY §12]`. Structural nudges — defaults and
ordering — are the only ones not refuted, so the screen spends its influence on *what is
biggest and what is first*, and almost nothing on persuasion copy.

---

## 9. Expected impact on retention, with the mechanism

Roughly **53% of mHealth apps are uninstalled within 30 days**; in one large study mean
engagement lasted **4.1 days** `[UX §12]`. Three mechanisms are aimed at that window.

1. **Day 1 is a finished product, not a loading bar.** First sync pulls 10 years of
   HealthKit history `[CAP §8]`, so a Watch-wearing new user gets the full hero immediately.
   The genuinely-new user gets the same slot with a provisional window and an honest "yours
   appears at 7" — a real answer, not an empty ring. Nobody in the corpus ships a distinct
   first-14-days home screen and every one of them pays for it in reviews `[W §10.7]`.
2. **Bad days do not punish, so bad days do not drive uninstalls.** Every compliance streak
   eventually teaches the user to stop opening the app on bad days, which are exactly the
   days the app has the most value to add `[P §6.7]`. Four late nights here still read
   "Mostly steady", and the fix is stated before the shortfall.
3. **The screen stops changing.** The loudest single complaint in the whole niche teardown
   is not about any layout, it is about layouts changing: "redesigned five times in the last
   four years" `[N §12.6]`. Five blocks, fixed order, one vocabulary, forever.

**The retention risk this concept accepts** is the flip side of the same coin: a user who
sleeps well and regularly will find the screen says the same calm thing every day. F17's
banner blindness applies — a region that renders identically stops being seen, at up to 33x
under-attention `[UX §12]`. The mitigations are the evening flip and the fact that the ghost
dots and the 14-bar chart genuinely change shape every night, but this is a real exposure,
not a solved problem.

---

## 10. Honest drawbacks, and who this design fails

**It fails the athlete outright.** There is no strain, no training load, no readiness, no
HRV, no VO2max, no workout anywhere on this screen. A user who bought Laso to decide whether
to do intervals today gets no answer and will churn. That is not an oversight; it is the
cost of committing to one lever.

**It fails anyone whose sleep timing is not theirs to choose.** A shift worker, a parent of a
newborn, a carer, someone on call. For those users the hero is a permanent instruction they
cannot follow, and "Bedtime slipped 40 minutes later" reads as an accusation about a night
spent with a sick child. This is RISE's unresolved structural problem `[N §1.8]` and it is
unresolved here too. The escape hatch is the only mitigation available and it is a blunt one.
The honest fix is a "my nights are not mine to set" mode that switches the hero to wake-time
consistency alone, and it is not built.

**One instruction means one point of failure.** If the advisor picks the wrong bedtime — the
user has a flight, a night shift, a newborn — the whole screen is wrong, because there is no
second card offering an alternative. T2's tradeoff, taken knowingly.

**The iPhone-only hero is the weakest thing here and I will not pretend otherwise.** With no
Watch, HealthKit has no sleep data at all. What the phone genuinely has is the hour your step
count first moves, from `fetchHourlySamples()` — real, but a rough stand-in for waking, not a
measurement of sleep. The lights-out target is then counted back 8 hours from that, using an
external anchor rather than a personal need. It is honest, it is labelled, it is rounded to
five minutes so it does not read as precise, and it is structurally identical to the Watch
version — but it is a weaker answer, and a user who compares the two will notice.

**The 14-bar chart demands more graph literacy than the brief is comfortable with.** ~1 in 3
users have both low graph literacy and low numeracy `[CL §11]`. The sentence above it
("10 of the last 14 nights started inside your usual window") carries the whole message for
those users, which is the required mitigation — but the chart is the card's centre of
gravity and some people will simply not read it.

**A calm screen is not automatically a good screen.** Garmin's 2024 desaturation removed the
only free emotional feedback the screen had and users noticed the loss `[W §6.4]`. This
concept deliberately has almost no chromatic event; on a steady week there is no colour at
all beyond the band. Some users will read that as the app having nothing to say.

**"Everything else" is a bet that could be wrong.** Collapsing steps and resting heart rate
behind one tap is the concept's philosophy made structural, but a user whose actual goal is
step count now has to tap for it every single day.

---

## 11. Five-questions scorecard for every component

Q1 what is happening · Q2 good or bad · Q3 why · Q4 what to do · Q5 what happens if I follow.

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Header (day + escape hatch) | · | · | · | · | · | **0** — chrome, one word and one control. Kept only because the escape hatch is mandated by N7. |
| Notice (health warning) | ✔ | ✔ | ✔ | · | · | **3** |
| Hero — clock rail | ✔ | ✔ | ✔ | ✔ | · | **4** |
| Hero — "Lights out 10:30 PM" | · | · | · | ✔ | ◐ | **1.5** |
| Hero — why clause ("bedtime slipped 40 minutes") | ✔ | · | ✔ | · | · | **2** |
| Hero — "Last night 6h 12m" + band + verdict | ✔ | ✔ | · | · | · | **2** |
| Hero — source line (the one uncertainty mechanism) | ◐ | · | · | · | · | **0.5** — the only sub-1 element that ships, and it ships because N2/T9 require exactly one honesty mechanism. |
| Hero — reminder button | · | · | · | ✔ | ◐ | **1.5** |
| Nights — verdict word + sentence | ✔ | ✔ | ✔ | · | · | **3** |
| Nights — 14-night chart | ✔ | ✔ | ✔ | · | · | **3** |
| Nights — "Why this matters" expander | ✔ | · | ✔ | · | ◐ | **2.5** |
| Everything else — collapsed summary | ✔ | ✔ | · | · | · | **2** |
| Everything else — steps row | ✔ | ✔ | · | · | · | **2** |
| Everything else — resting heart rate row | ✔ | ✔ | · | · | · | **2** |
| Footer (updated at) | · | · | · | · | · | **0** — one line, kept as the cheapest honesty signal on the screen `[CRIT §4.16]`. |

Nothing scoring 0 carries data. Every element that carries a number scores ≥2.

---

## 12. The ten tensions, resolved

| # | Tension | Side taken | How it shows up |
|---|---|---|---|
| **T1** | Score-first or action-first | **Action-first, absolutely** | Tonight's lights-out window is the largest object on the screen. There is no score anywhere to compete with it. The current build's failure was doing both at equal weight; this concept removes one side of the argument entirely. |
| **T2** | One hero number or a cluster of 3-6 | **Two, in one substance** | Last night in h:mm and tonight's lights-out as a clock time. Not one (a single point of failure, and Laso's most defensible single number is unavailable to iPhone-only users), not six (Oura's cluster "dilutes the information", `[W §2.8]`). Both are sleep timing, so they can never move in opposite directions the way the current ring and its chip can `[CRIT §4.6a]`. |
| **T3** | A graded verdict or a band you sit inside | **A band, in both dimensions** | A clock band for bedtime and an hours band for duration. There is no pass/fail and no letter grade. Late is a *position*, not a failure — Gentler Streak's inversion `[N §2.2]`. The verdict vocabulary is "Steady / Mostly steady / Drifting", none of which is a moral term. |
| **T4** | A borrowed unit or a native index | **Borrowed, exclusively** | Hours, minutes and clock times. Zero native indices on the entire screen. "The weakest home screens require the app to teach a scale before the number means anything, and the teaching never sticks" `[N §12.2]`. |
| **T5** | Explanation inline, one tap down, or a paragraph | **One clause inline, plus one in-place expander** | The magnitude clause sits in the hero with the number. Deeper explanation opens *in place* under the chart — no navigation, no exit, no router. Never a paragraph above the number `[N §4.2]`. |
| **T6** | Celebration or calm | **Calm** | No confetti, no streak, no badge, no milestone card. Acknowledgement is one quiet state change: the reminder button becomes a check and says "Reminder set. One nudge, then nothing." Fogg: a returning user is already above the activation threshold, so motivational persuasion "would either be annoying or condescending" `[PSY §1]`. |
| **T7** | Density or scroll | **Sparse, but the hero is dense** | Five blocks total. But the hero fills 85% of the first viewport rather than leaving Google Health's "huge block of empty space" `[P §3.8]`. Sparse is not automatically calm — the resolution is one big, information-rich, deeply considered element instead of many thin ones. |
| **T8** | Fixed slots or contextual morphing | **Fixed slots, one slot morphs** | The five-slot order never changes. Slot 2 flips morning ("Lights out / Last night") to evening ("Wind down / Usual wake"), with the rail marker following the number. Full-screen morphing failed at Oura; single-slot morphing shipped `[W §2.8]`. Toggle it in the dev toolbar. |
| **T9** | Honest uncertainty or confident simplicity | **Exactly one mechanism, seamful** | One line, one place, three states: *"From 14 nights."* / *"From when your phone starts moving. Less exact than a watch."* / *"From 2 nights. Yours appears at 7."* No confidence bar, no percentage, no "based on 3 of 5 signals", no range band on a score. The current build's four simultaneous widgets are the reductio `[CRIT §2]`. |
| **T10** | Opinionated hierarchy or user pinning | **Opinionated** | Nothing is reorderable, pinnable or hideable. "An optional hero is not a hero" (C7). The single user control is the escape hatch, which turns verdicts *off* — an autonomy affordance, not a layout preference. |

---

## 13. The three hero states (N5: degrade, never disappear)

Same slot, same structure, same unit, same instruction, different confidence. Switch with the
dev toolbar's **Hero data** control.

| State | Big number | Second quantity | Rail | Uncertainty line |
|---|---|---|---|---|
| **A. Full wearable** | Lights out **10:30 PM** — the centre of the learned window | Last night **6h 12m** against the personal 7h 40m need | Solid band, 7 ghost bedtimes, nudge arrow | "From 14 nights." |
| **B. iPhone only** | Lights out **10:30 PM** — 8 hours back from when you usually start moving, rounded to 5 min | Up and moving **6:34 AM** against your usual first-movement window | Dashed band labelled "estimated", **no ghost dots** because the phone cannot see bedtimes | "From when your phone starts moving. Less exact than a watch." |
| **C. Genuinely new** | Lights out **10:30 PM** — the centre of a common adult window, labelled as such | Last night **7h 40m** against a dashed common range | Dashed band labelled "starting point", 2 real dots, 7-pip progress shape | "From 2 nights. Yours appears at 7." |

No empty ring. No hardware upsell. No silent substitution of a different index under the
same label — which is precisely bug **B3**, and precisely what Samsung did with Energy Score
`[P §5.2]`. The Nights card follows: it becomes **Mornings** with a first-movement chart on
iPhone-only, and a 2-of-14 chart with a dashed provisional window for a new user.

Also shipped: a **loading** state (same slot shapes, no spinner in the hero, "Reading your
last two weeks of nights") and an **empty** state (same slot, an unfilled goal shape rather
than a blank tile, one Connect button — `[P §7.4]`: "an unfilled ring says fill me; a blank
tile says this app is broken").

**The escape hatch** is the `#` button in the header, one tap, always visible. It removes
every verdict, band, target, colour and comparison and leaves the readings: asleep 6h 12m,
lights out 11:53 PM, up 6:05 AM, the last 7 nights, steps, resting heart rate. This is the
only mitigation the self-tracking harms literature actually offers `[N §12.4]`, and on a
sleep-led screen it is the difference between a product and a liability.

---

## 14. Literal budget counts

Measured in Chrome at **375 × 812** with the scroll region clamped to **678px** (status bar
50 + tab bar 84 removed), in the default state: Watch data, morning, drifting nights, no
health notice, nothing expanded.

| Constraint | Limit | **This concept** | |
|---|---|---|---|
| Cards above the fold | ≤ 3 | **2** — hero (68→644px), Nights heading touching the fold at 656px | ✅ |
| Total blocks | ≤ 7 | **5** — header, hero, Nights, Everything else, footer | ✅ |
| Numbers on screen | ≤ 12 | **10** — `10:30 PM`, `40 min`, `6h 12m`, `7h 40m`, `14 nights`, `10`, `14`, `10 PM`, `6 AM`, `7:12 AM` | ✅ |
| Numbers above the fold | ≤ 5 | **5** — `10:30 PM`, `40 min`, `6h 12m`, `7h 40m`, `14 nights` | ✅ at limit |
| Words of copy above the fold | ≤ 20 | **19** — Wednesday · Tonight · Lights out · usual · Bedtime slipped … minutes later · Last night · short of usual · From … nights · Remind me · Nights | ✅ |
| Tap targets | ≤ 8 | **8** — escape hatch (44×44), Remind me (372×52), two expanders (372×44), four tabs (104×48) | ✅ at limit |
| Distinct exits from Home | ≤ 6 | **3** — Live, Explore, Settings. Expanders and the escape hatch are in-place | ✅ |
| Disclosure levels below Home | ≤ 2 | **1** — expanders open in place; nothing on this screen navigates deeper | ✅ |
| Uncertainty widgets per number | 1 | **1** — the source line | ✅ |
| Reference ranges per number | exactly 1 | **1 each**, always the personal goal range | ✅ |
| Components giving an instruction | 1 | **1** — the hero | ✅ |
| Facts to combine to read any element | ≤ 2, target 0 | **0** — every comparison is inside its own element | ✅ |
| Body text | 17px, 11px floor | 17px body; smallest rendered text is **11px** (verified: zero elements below 11px) | ✅ |
| Tap target size | 44px | smallest is 44×44 | ✅ |
| Horizontal overflow | none | `scrollWidth == clientWidth == 375` | ✅ |

### Budgets exceeded — the honest list

**One, and only in a user-initiated state.**

- **Numbers on screen: 13 when both expanders are open simultaneously** (adds `45 minutes`
  from the Why explanation, plus `8,400` and `58 bpm` from the metric rows). That is **1 over
  the 12 budget**. The brief's budget is specified "on the default morning", and both
  expanders start closed, so the default is 10 — but a user who opens both does exceed it and
  I am not going to round that away. The fix if it mattered would be to make the two
  expanders mutually exclusive; I did not do it because forcing a card shut when the user
  opens another one is worse than one number over budget.

Everything else is inside its limit. Two budgets sit exactly *at* the limit — 5 numbers above
the fold and 8 tap targets — which means this layout has no headroom for another element
above the fold or another control anywhere. That is a design constraint worth stating: this
screen is full.

### Also worth flagging honestly

- **When the health notice fires**, cards above the fold stay at 2, but the hero's reminder
  button drops below the fold. The instruction's *number* (10:30 PM) is still above it. I
  accepted this because N6 outranks the fold: a warning the app graded high must be at
  position 1.
- **The 19-word count treats `PM`, `h` and `m` as unit markers on their numbers rather than
  as words.** Counting `PM` as a word makes it 20, still inside. Counting the date as chrome
  rather than copy makes it 18.
- **The weekday letters on the chart (W T F S S M T …) are 11px**, exactly on the floor, and
  they are decorative-adjacent: the chart is fully readable without them.

---

## 15. Verification performed

- **JS syntax:** `node --check` clean.
- **Every state combination:** all 218 combinations of source × time-of-day × nights level ×
  notice × reminder-set were rendered through the real builder functions; zero exceptions,
  zero `undefined`, zero `NaN`.
- **Numeric consistency:** every printed fact — last night's hours, lights-out and wake
  times, the drift in minutes, the inside-window count, the late run, the wake shift, the
  five-night shortfall, the raw-mode 7-night list — is **derived in JS from one array of
  bedtimes and wake times**. Nothing is typed in twice, so no two numbers on the screen can
  disagree. Verified across all three night datasets.
- **Handlers:** all four content buttons (escape hatch, reminder, two expanders), four tabs
  and the six dev-toolbar groups confirmed live in a headless browser. Expanders confirmed to
  reach 341px and 307px open and 0px closed, with `aria-expanded` tracking. Raw mode, tab
  placeholders and the connect-then-load flow all confirmed to change the render.
- **Screenshots** taken at 390×844 for: light, dark, expanded, health notice, iPhone-only,
  new user, evening, raw mode, loading, empty, steady nights, and the dev panel.
- **A clipping bug was found and fixed:** the expanders originally used a `max-height: 640px`
  transition, which would clip long copy at large Dynamic Type. Replaced with a
  `grid-template-rows: 0fr → 1fr` transition that animates to the content's natural height and
  cannot clip.
- **A precision bug was found and fixed:** the iPhone-only target time and the evening "usual
  wake" were printed to the minute from an *average*, which reads as accuracy the derivation
  does not have. Both are now rounded to the nearest five minutes.
- **A consistency bug was found and fixed:** in evening mode the rail marker still pointed at
  the lights-out time while the big number showed the wind-down time. The marker now always
  shows whatever the big number says.
