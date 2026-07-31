# Concept 03 — The Body Budget

**File:** `design/home-v2/concepts/03-body-budget.html`
**Date:** 2026-07-29
**Verified in:** Chrome headless at a real 375 × 812 viewport (5.4"), light and dark, every dev-toolbar state.

---

## 1. The one-sentence philosophy

**Today comes with an amount of effort you can afford to spend, and spending all of it is the good outcome — so the screen shows you the amount, in a unit you already own, and nothing else.**

There is no 0–100 score anywhere on this screen. Not the hero, not a chip, not a tile, not
behind a tap. The product's answer is a quantity of minutes, and the whole screen is built
to make spending them feel like the win.

The framing is deliberately Bevel's **Energy Bank** rather than Ultrahuman's **Movement
Index** — a resource you spend, not a score you are losing. `[W §5.4, D5]` The research
stream's own summary: *"Loss framing is the difference between Movement Index and Energy
Bank. Same maths, opposite emotion, and one of them earned a spontaneous thank-you review."*
`[W §10.4]` We take the emotion and refuse the maths that produces a score.

---

## 2. Why this layout order, element by element

Fixed slot order. Every morning, in this sequence. Only what is inside a slot changes.

| # | Slot | Why it is here |
|---|---|---|
| — | Status bar, header ("Tuesday") | Habit cue. One word, no number, no greeting by name. `CoachGreetingView` scored **0/5** on the five questions and greets a user by name while telling them the app knows nothing about them `[CRIT §4.1]`. The date word is the cue; the escape hatch is the only control in the top strip. |
| **A** | **Attention** — health warning, conditional | N6 is absolute: a warning is never blurred, paywalled, hedged, or below position 3. It is at **position 1** or it does not render. It is not present on the default morning, so it costs the default screen nothing. |
| **B** | **Today's budget** — the hero, ~446px tall, owns the first viewport | T1 resolved by merger: the budget *is* the state and *is* the instruction, so there is no second component to contradict it. One quantity, two supporting quantities in the same unit (spent, usual). One clause of cause, always visible. One expander for the arithmetic. |
| **C** | **Two weeks** — SVG bar chart, budget vs spent | The record-keeping surface. Positional bars, not a line `[UX §10, F14]`. It proves the budget genuinely moves, which is the only defence against F17 banner blindness. It also renders **overspend** as extra height and calls it allowed, which is the concept's moral position made visual. |
| **D** | **What spending buys** — aggregate proof | Progress monitoring against a goal is the single best-evidenced item in the psychology corpus: **138 studies, N=19,951, d+ = 0.40 (0.32–0.48), mediation confirmed** `[PSY §9]`. `RecommendationEvaluator.buildActionProof` already computes 24h/7d lift and Home never shows it `[CAP §9.8]`. It answers the only interesting objection to the hero: *why should I spend it?* |
| **E** | **Tonight's refill** — the one time-of-day slot | C6/T8: single-slot morphing survived at Oura, full-screen morphing was attacked `[W §2.8]`. The lede sentence changes at morning vs evening; the numbers, the slot and the position never move. Carries the two Tier-1 sleep signals: time asleep vs personal need, and bedtime regularity in the expander. |
| **F** | Footer | Cheapest block on the screen `[CRIT §4.19]`. One line. |
| — | Tab bar | Today · Live · Explore · Settings, unchanged. |

**The hero deliberately owns the first screen.** Measured: hero 446px in a 637px scroll
viewport at 375×812. That is Athlytic's D1 bet — *one thing, alone, no competing element*
`[W §4.2]` — and it is what keeps the screen inside the 20-word and 5-number above-fold
budgets. The next card's heading and the top of its chart peek above the fold as the scroll
affordance; its legend and caption fall below it.

---

## 3. Psychological principles used, and the specific mechanism

- **Budget framing over receipt framing.** MyFitnessPal has shipped *calories remaining*
  rather than *calories consumed* for a decade: *"remaining is a forward-looking budget you
  can spend, consumed is a backward-looking receipt you cannot change. Budget framing
  produces a decision; receipt framing produces a judgement"* `[P §6.2]`. Mechanism: the
  hero is a forward quantity, so the only available action is spending, and there is no
  state in which the user has already failed.
- **A borrowed unit removes the teaching step.** RISE's whole thesis, D2. `[N §1.2]` The
  weakest home screens *"require the app to teach a scale before the number means anything,
  and the teaching never sticks"* `[N §12.2]`. Minutes need no teaching.
- **No compliance streak, no loss framing, no guilt.** F9. Lally: a missed day costs **0.29
  points on a 0–42 automaticity scale**, is not significant, and recovers fully `[PSY §3]`.
  There is no streak on this screen. Spending 18 of 30 minutes produces no negative state
  and no copy about it.
- **Rest counts.** A small budget is not a bad day, it is a small day. Gentler Streak's
  inversion: below the band is *capacity*, not failure `[N §2.2, D3]`. Nothing on this
  screen colours a small budget differently from a big one.
- **Endowed progress on cold start.** `[PSY §8]` A new user gets a real budget shape with a
  range in it, never an empty ring or a 0-of-N.
- **Celebration only on spend (T6).** The single celebratory element is the green fill
  growing across the bar, plus the "What spending buys" card. Nothing celebrates restraint,
  nothing celebrates opening the app, nothing celebrates a streak.
- **Fogg on returning users.** A returning user is already above the activation threshold,
  so the screen spends itself on ability rather than motivation `[PSY §1]`. Hence one
  three-word instruction and no persuasion copy anywhere.

---

## 4. UX principles applied

- **Layer-cake scanning.** `[UX §6]` Every element: short front-loaded heading → number
  directly under it → interpretation under that. "Today's budget" / **30 min** / bar /
  "A smaller day. Spend it all." Nothing meaning-critical on the right edge — the only
  right-aligned content is the ruler's `usual 50`, which is redundant with the tick position.
- **The 0–1s channel is length, not colour.** Blocks are a fixed physical width (5 minutes
  each), so a 30-minute budget is literally half the bar of a 60-minute one. Colour encodes
  **spent vs not spent**, never magnitude — satisfying F14 without giving up a pre-attentive
  read. A small budget and a big budget are the same colour, on purpose.
- **Exactly one reference range, and it is personal (F12).** The bar draws today's budget
  and nothing else. The dashed rule to `usual 50` is a **ruler**, a single point marker for
  scale, not a second band you are graded against. 14.49% → 43.45% comprehension, N=6,766
  `[UX §11]`.
- **Never a bare number (F11).** Every number ships its comparison inside the same visual
  element: 30 sits on a bar with the usual mark; 12 is labelled "spent"; 7h 40m sits beside
  the five-night average in the same bordered pair.
- **Harm anchor (F13).** The warning card carries *"Most people do not need to do anything
  about this"* and names three innocent causes before it names a cold. N=1,618: adding a
  harm anchor significantly reduced perceived urgency and cut urgent doctor contact
  `[UX §11]`.
- **Two disclosure levels maximum (C4).** Home → one inline expander. Nothing on this screen
  navigates to explain itself. The current build's five tappable "Why" rows are a router,
  not an explanation `[CRIT §4.6]`.
- **Platform floors.** 17px body, 11px absolute minimum (tab labels and chart labels were
  raised from 10px to 11px for this), 44–52px tap targets, contrast checked: `textTertiary`
  6.2:1, `success` 5.2:1, `primary` 5.3:1, `warning` 4.85:1 on its tinted card, all ≥ 4.5:1
  in both themes. Designed on 5.4" first, verified there.
- **The escape hatch is real.** One tap in the header turns every score, budget and verdict
  off and shows raw recorded values with nothing said about them. This is the only mitigation
  the self-tracking harms literature actually offers `[N §12.4; N7]`.

---

## 5. Which user problems it solves

| Problem | How |
|---|---|
| **Three components tell me what to do and they disagree** `[CRIT §5]` | Exactly one component instructs. The hero absorbs sleep debt, recent load and the illness warning into the *size of the budget*, so a smaller budget **is** the "take it easy" advice. There is no second card left to contradict it. |
| **The score doesn't match how I feel** — the #1 complaint across four of six competitor apps `[W §7, C2]` | The budget is not a claim about how you feel. It is an amount of effort, derived visibly, that you are free to overspend. Overspending is drawn in the chart and labelled *allowed*. |
| **Nobody explains on the home screen** — the clearest open lane in the corpus `[W §10.2]` | One always-visible cause clause with its magnitude ("Sleep 1h 28m short."), and one tap to the full arithmetic: base 60, −20 sleep, −10 recent run, RHR no change, = 30. |
| **The hero lies to iPhone-only users** (B3, and Samsung's "single biggest own-goal") | The iPhone-only hero is the same slot, same shape, same instruction — in **steps**, as a labelled range, with the reason stated on the face of the card: *"No wrist data, so this is a range."* Not empty, not an upsell, not a silent substitution. |
| **Cold start is universally unsolved (C8)** | Day-1-no-history gets a real budget: 20–40 minutes, sourced on the card to the WHO 30-minutes-a-day standard, with the expander saying exactly when it becomes personal. Borrowed external authority makes the target defensible without a medical claim `[D8]`. |
| **A "High" health warning at position 13, behind a blur** `[CRIT §4.13, §4.17]` | Position 1, never blurred, states what was noticed in a sentence, carries a harm anchor, and gives no instruction — because the budget already did. |
| **The screen asks for input it ignores (B: `readinessAdjustment`)** | This screen asks for zero input. Compliance is measured, not self-reported, so there is no done/remind pair to ignore. |

---

## 6. Which metrics were given prominence, and why

| Metric | Where | Why |
|---|---|---|
| **Active/exercise minutes** — the budget itself | Hero, the only large number | Tier 1. Same umbrella-review behaviour-change evidence as steps, externally anchorable to WHO 30 min, and it is a unit people live in `[CL §A, §C; P §2.2]`. Critically, it is the only Tier-1 unit that has a natural *capacity* reading, which is what makes a budget honest rather than just a goal. |
| **Steps** — the budget for iPhone-only users | Hero, phone variant | The only metric with umbrella-review behaviour-change evidence, works on iPhone alone, works on day 1, anchored at **7,000** with the reason stated, never 10,000 (fixes B7) `[CL §10.2, §10.3]`. |
| **Time asleep vs personal need** | Hero expander (cause), Tonight's refill (numbers) | Devices exceed 90% sensitivity for sleep vs wake; clock time needs no interpretation `[CL §3.1]`. Against `SleepNeedCalculator`'s personal need, never a flat 7.5h (fixes B6). |
| **Sleep shortfall as a rolling five-night average** | Tonight's refill | RISE's rolling balance: a bad night dents a balance instead of resetting a streak `[N §1.7]`. Framed as *"running short"*, never as an hours-owed ledger, because repayment is not 1:1 `[CL §3.2]`. |
| **Sleep regularity (bedtime drift)** | Tonight's refill expander | UK Biobank, **n=60,977**, 7.8-year follow-up: all-cause mortality **HR 0.70** top vs bottom quintile, and regularity is a **stronger predictor than duration** `[CL §3.3]`. The brief calls it "the single biggest addition available" and it is absent from the shipping screen. |
| **Resting heart rate** | Hero expander, warning card | The most reliable thing a consumer wearable measures, MAE 0.98–1.78 bpm `[CL §2]`. Flagged only at ≥5 bpm above baseline sustained 3+ nights — Alex's +3 bpm is correctly shown as **"no change"**. |
| **Aggregate outcome of past spending** | What spending buys | d+ = 0.40, N=19,951 `[PSY §9]`. Stated as an aggregate over eight weeks, never n=1, never with a magnitude the dead band calls noise. |

**One word per concept, everywhere:** *budget*, *spend*, *refill*, *usual*, *sleep*,
*resting heart rate*. No "Heart Calm Signal", no "Body Intelligence", no "Stress", no
"Strain", no "Readiness". `[N8; CRIT §7]`

---

## 7. Which metrics were deliberately hidden or removed, and why

| Removed | Reason |
|---|---|
| **Readiness / Recovery 0–100** | Tier 3. The composite tracked perceived recovery **worse than its own raw HRV input** in D1 swimmers, and no manufacturer's weights are disclosed or clinically validated `[CL §4.2, §4.3]`. It is also unavailable to iPhone-only users. Removed entirely rather than demoted, because keeping it would re-open T1. |
| **Daily Health Score 0–100** | Coverage shrinkage pulls sparse users toward a constant **75** shown at full visual confidence (B4). Not shown, so B3's silent substitution cannot happen. |
| **Stress 0–100** | Recall for psychological stress from wearable signals is **50.0%** — a coin flip presented in red `[CL §5.2]`. Cut, not renamed. |
| **Strain 0–21** | Log scale is a real comprehension hazard, and session-RPE correlates with TRIMP at r = 0.79–0.86 `[CL §6.1, §6.2]`. Its *content* survives as the "recent hard session" row in the budget arithmetic, in minutes. |
| **Brain Health, Vitality Age, Pace of Aging** | F7. Age framing increases emotion and recall with **no effect on lifestyle intentions or behaviour**, and Laso's norm tables are self-documented as heuristic with no DOIs `[CL §9.3; CAP B11]`. |
| **Sleep stages (REM/deep/light)** | κ 0.21–0.53, Apple Watch deep-sleep sensitivity 50.7% `[CL §3.1]`. RISE omits stages entirely and is right to. |
| **HRV in ms** | Off Home. Laso stores **SDNN**, which is not the same quantity as RMSSD `[CL §1.2]`. It appears only in the escape hatch, explicitly labelled `(SDNN)`, with no comparison and no verdict. |
| **`DataCoverageCard`, activation banner, "Patterns found: 12", morning check-in, streak share card, `AskYourDataCard`, weekly review entry** | All scored **0/5** on the five questions `[CRIT §4.8–4.15]`. |
| **Forecasts and "62% chance"** | F4. Only 25% of the general population converts "1 in 1000" correctly, and the app's "conf 82%" is an interval-width heuristic reading as calibrated `[CL §11; CAP §6]`. Nothing on this screen is a probability. |
| **The 62%/28% AI briefing paragraph above the number** | F16/C9. 3,419 revert votes `[P §3.8]`. There is no AI element on this screen at all. |

---

## 8. Expected impact on daily engagement, and the mechanism

**Direction: fewer sessions, longer-lived.** This is Athlytic's bet, not Whoop's `[W §4.7,
§1.10]`, and it is the honest one given a **72-second** median mobile session `[UX §7]`.

Mechanisms that should raise *daily open rate*:
1. **The number changes every day and visibly moves.** Bar length is different on a
   30-minute day and a 65-minute day, which defeats F17 banner blindness (a static region
   takes 0.8% of fixations while occupying 25% of the area `[UX §12]`).
2. **The fill grows during the day.** Unlike a morning-locked score, the budget bar is a
   different picture at 8am and 7pm. This is the one thing Ultrahuman genuinely earns a 3pm
   reopen with `[W §3.7]` — without Ultrahuman's real-time-score honesty problem, because a
   spend counter is a measurement, not a re-scored composite.
3. **Nothing punishes opening the app on a bad day.** Every compliance streak eventually
   teaches users to stop opening on the days the app has the most value to add `[P §6.7]`.

Mechanisms that should *lower* session length, deliberately: 6 blocks, 9 printed numbers,
8 tap targets, 3 exits. There is very little to do here, which is the point.

---

## 9. Expected impact on retention, and the mechanism

The defensible frame is attrition, not cognition: **~53% of mHealth apps are uninstalled
within 30 days**, mean engagement **4.1 days**, top stated reason lack of interest /
declining motivation (31.6%) `[UX §12]`.

1. **Day 1 is not a waiting room.** First sync pulls 10 years of HealthKit history `[CAP §8]`,
   so a Watch-wearing new user gets a fully personal budget immediately. A genuinely new
   user gets a real WHO-anchored range and a named unlock date, not a blank tile. Cold start
   is the second open lane in the corpus and nobody has taken it `[C8]`.
2. **No failure state means no abandonment trigger.** The orthosomnia data is the sharp end:
   3.0% strict / 8.6% moderate / **14.0% lenient** prevalence, with significantly higher
   insomnia scores at every cutoff `[CL §3.5]`. Between 1-in-33 and 1-in-7 users are actively
   harmed by a bad score. This screen has no bad score to show them.
3. **The escape hatch keeps the harmed user installed.** Scores off, raw numbers, no verdict,
   one tap, and it stays off.
4. **Structural sameness.** The loudest complaint in the entire niche teardown is not about
   a layout, it is about layouts *changing* — "redesigned five times in four years"
   `[N §12.6]`. Fixed slots, one word per concept, forever.

**Risk to retention:** the budget is a smaller promise than a Recovery score. Users who came
for a 0–100 number will feel the app got less clever. See §11.

---

## 10. The ten tensions, resolved

| # | Tension | This concept's side |
|---|---|---|
| **T1** | Score-first or action-first | **Neither, by merger.** The budget IS the state and IS the instruction. One element, one sentence: "A smaller day. Spend it all." There is no second component with an opinion, so the `CRIT §5` contradiction is structurally impossible. |
| **T2** | One hero number or a cluster of 3–6 | **One hero quantity plus exactly two supporting quantities, all in minutes.** Budget 30, spent 12, usual 50. Welltory's failure case — three percentages that move independently with no rule for which to obey `[N §5.8]` — cannot occur when all three are the same unit on the same bar. |
| **T3** | Graded verdict or a range you sit inside | **A range you sit inside, with no failure state.** You are somewhere between 0 and your budget, and both ends are fine. Below is capacity, above is allowed. Whoop's green/yellow/red moral vocabulary is not used: colour marks spent vs unspent, never good vs bad. |
| **T4** | Borrowed unit or native index | **Borrowed unit, hard.** Minutes for wearable users, steps for iPhone-only, hours for the sleep slot. Zero native indices anywhere on the screen, including behind taps. |
| **T5** | Explanation inline, one tap down, or a paragraph | **Both, in that order.** One always-visible clause with its magnitude ("Sleep 1h 28m short."), and one inline expander with the four-row arithmetic that does not navigate. Not five tappable rows that are each an exit `[CRIT §4.6]`. |
| **T6** | Celebration or calm | **Celebration only on spend, never on restraint.** The green fill, the overspend caps in the chart, and "What spending buys". No streak, no badge, no celebration for opening the app, no celebration for resting. |
| **T7** | Density or scroll | **Sparse-to-medium.** 4 content cards, 6 blocks, one full-viewport hero, one dense chart. Not the Google Health "huge block of empty space" `[P §3.8]` — the hero's 446px is filled by an 84px number, a 62px bar, a ruler, a verdict, a cause and an expander. |
| **T8** | Fixed slots or contextual morphing | **Fixed.** Slot order never varies. Time-of-day morphing happens inside exactly one named slot ("Tonight's refill"), which is the Oura variant that survived `[W §2.8]`. The Attention slot appears or does not, at position 1, and never reorders anything below it. |
| **T9** | Honest uncertainty or confident simplicity | **One mechanism: the budget is a point when it is confident and a range when it is not.** That is the entire uncertainty vocabulary. No confidence percentage, no "based on 3 of 5 signals", no certainty bar, no interval width. The range renders as hatched blocks so the uncertainty is visible without a second widget. |
| **T10** | Opinionated hierarchy or user pinning | **Opinionated.** No pinning, no customisation, no reorder. An optional hero is not a hero `[C7]`. The user's only structural control is the one that matters: turning the whole interpretive layer off. |

---

## 11. Honest drawbacks, and who this design fails

1. **It fails the quantified-self power user, deliberately.** No HRV, no strain, no
   readiness, no sleep stages, no forecast, no correlations. Someone who bought Laso to see
   their SDNN trend gets one line in a screen they have to switch on. Whoop's 83% DAU/MAU
   comes from exactly the density we removed `[W §1.8]`.
2. **A budget still implies a forecast of capacity, and that is the concept's soft spot.**
   We made it as honest as we can — the number is a visible sum of four terms from the
   user's own history, the card says *"No forecast, no probability"*, and nothing claims
   injury risk or overtraining (F6). But the *weights* (−20 for a 1h28m sleep shortfall,
   −10 for a hard session two days back) are Laso's judgement, not validated science, and
   the screen only admits that in an expander. A reviewer is entitled to ask where −20 came
   from and we do not have a DOI for it.
3. **iPhone-only users get a different unit.** It is labelled, explained on the face of the
   card, and structurally identical — but a household where one person sees minutes and the
   other sees steps cannot compare notes. The alternative was a fabricated effort-minutes
   estimate from step cadence, which would have been worse.
4. **"Spend it all" can be read as pressure.** SDT says controlled regulation predicts worse
   mental health, ρ = .13 to .46 `[PSY §5]`. We mitigate with no streak, no failure state,
   no negative copy for an unspent budget and a shrinking budget on hard days — but the
   instruction is still an instruction, and a user prone to exercise compulsion is the wrong
   audience for it. The escape hatch exists for exactly this person.
5. **It can look thin next to competitors on an App Store screenshot.** Four cards. Bevel
   shows three rings, a bank, six vitals and a timeline in the same scroll.
6. **"20 more minutes asleep" is an association, not a causal claim, and users will read it
   as causal.** We phrase it as *"nights after a fully spent budget"* and refuse the word
   *because*, but the placement invites the inference. This is the single sentence on the
   screen most likely to fail a rigorous review.
7. **Steps and minutes both stop working for a user in a wheelchair, or one who swims.**
   The budget has no honest unit for them today.

---

## 12. Five-questions scorecard, every component

**Q1** what is happening · **Q2** good or bad · **Q3** why · **Q4** what to do · **Q5** what happens if I follow it.

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Header "Tuesday" | · | · | · | · | · | **0** — chrome, one word, not a card. Kept as the habit cue only. |
| Escape-hatch button | · | · | · | · | · | **0** — a safety control, exempt by N7. |
| **Attention card** (conditional) | ✔ | ✔ | ✔ | · | · | **3** — names the signal, the magnitude, the persistence gate and the harm anchor. Gives no instruction, by design. |
| **Hero: budget number + bar** | ✔ | ✔ | · | ✔ | · | **3** — the quantity, its comparison, and the only instruction on the screen. |
| **Hero: cause clause** | · | · | ✔ | · | · | **1** — one clause, one cause, its magnitude. The C2 open lane. |
| **Hero: "Why this size" expander** | ✔ | · | ✔ | · | · | **2** — the full arithmetic with each term's magnitude. |
| **Two weeks chart** | ✔ | ✔ | · | · | · | **2** — where today sits in your own fortnight; overspend drawn and labelled allowed. |
| **Chart caption + expander** | ✔ | · | ✔ | · | · | **2** — the range of your own budgets and which term moved them. |
| **What spending buys** | · | · | · | · | ✔ | **1** — the only Q5 answer available, stated as an aggregate. |
| **Tonight's refill** | ✔ | ✔ | · | · | ✔ | **3** — need vs five-night average, a plain verdict, and the mechanism that resets tomorrow's budget. |
| **Tonight's refill: bedtime expander** | ✔ | ✔ | · | · | · | **2** — sleep regularity, the strongest sleep finding in the corpus, currently on no Laso screen. |
| Footer | · | · | · | · | · | **0** — one line, cheapest block on the screen. |
| Tab bar | · | · | · | · | · | **0** — chrome. |

**Nothing scoring 0 survives except chrome and the safety control.** Twelve of the shipping
screen's nineteen components scored 0 or 0.5 `[CRIT §11]`.

---

## 13. Literal budget counts — default morning

State measured: full wearable data, small day (Alex's real numbers), morning, loaded,
every expander collapsed, 375 × 812 viewport. Counted from the rendered DOM, not estimated.

| Constraint | Limit | **This concept** | Pass |
|---|---|---|:--:|
| Cards above the fold | ≤ 3 | **2** (hero in full; the top 168px of "Two weeks") | ✅ |
| Total blocks | ≤ 7 | **6** — header, hero, Two weeks, What spending buys, Tonight's refill, footer | ✅ |
| Numbers on screen | ≤ 12 | **9 numerals** (30, 12, 50, 1h 28m, 30, 60, 20, 7h 40m, 6h 48m) **+ 3 written as words** (four days, eight weeks, five-night) = **12 total** | ✅ (at the cap) |
| Numbers above the fold | ≤ 5 | **4** — 30, 12, 50, 1h 28m | ✅ |
| Tap targets | ≤ 8 | **8** — escape hatch, 3 expanders, 4 tabs | ✅ (at the cap) |
| Distinct exits from Home | ≤ 6 | **3** — Live, Explore, Settings | ✅ |
| Words of copy above the fold | ≤ 20 | **19** | ✅ |
| Uncertainty widgets per number | 1 | **1** — point vs range, nothing else | ✅ |
| Reference ranges per number | exactly 1 | **1** — today's budget. The `usual` tick is a scale marker, not a band | ✅ |
| Components giving an instruction | 1 | **1** — the hero | ✅ |
| Disclosure levels below Home | ≤ 2 | **1** — inline expanders only, no navigation to explain anything | ✅ |
| Facts to combine to read any element | ≤ 2, target 0 | **0** — every number carries its comparison in its own element | ✅ |

Above-the-fold word list, verbatim: *Today's budget · min · spent · usual · A smaller day.
Spend it all. · Sleep 1h 28m short. · Why this size · Two weeks · usual* — plus the header
word *Tuesday*. 19 words.

### Budgets exceeded, and why

**In the default morning state: none.** Two sit exactly at the cap (12 numbers, 8 tap
targets) and neither goes over. The honest exceptions are all in non-default states:

1. **The Attention state exceeds the 20-word above-the-fold budget, by a lot (≈75 words).**
   The warning card alone is 56 words. This is deliberate and it is the one budget I would
   break again: N6 says a health warning is never hedged, and a hedged warning is what you
   get if you compress it to fit a copy budget written for a normal morning. The *number*
   budgets still hold in that state (5 numerals above the fold: 64, 55–60, 20, 8, 50).
2. **The Empty state has 9 tap targets, one over.** The extra one is "Turn on Health access".
   An empty state with no way out of it is not an empty state, it is a dead end.
3. **A non-Today tab view adds one "Back to Today" button.** Prototype scaffolding so no
   control is dead; it would not exist in the app.
4. **The dev toolbar** (1 button + 15 options) is excluded from every count per the prototype
   spec, and is the only element on screen below the 11px type floor.
5. **`12 numbers` counts three numbers written as words.** If your counting rule is numerals
   only, this screen shows 9. I have reported the stricter number.

---

## 14. Data honesty notes

Every number on the screen traces to something `[CAP]` says Laso computes today:

- **Budget base (60 min)** — a personal ceiling from the user's own exercise-minute history
  on well-rested days. `PersonalOptimizer.optimalProfile` / `idealDay` already computes this
  class of value `[CAP §3g, §9.9]`.
- **Sleep term (−20 min)** — `SleepNeedCalculator` personal need (7h 40m) minus
  `sleepDuration` summed per wake-day (6h 12m) `[CAP §1, §2]`. Fixes B6.
- **Recent-effort term (−10 min)** — `workoutDuration` / `StoredDailyStrain`, stated as a
  descriptive load fact ("Hard run Sunday, 96 min"), never as overtraining or injury risk
  (F6) `[CAP §2, §3b]`.
- **Resting heart rate term** — `BaselineCalculator` personal range, flagged only at ≥5 bpm
  for 3+ consecutive nights `[CL §2.3]`. Alex's 58 vs 55–60 correctly shows **no change**.
- **Usual day (50 min)** — the median of the 14 budgets drawn in the chart. Verified: the
  chart's own values sort to a median of exactly 50.
- **Five-night average (6h 48m)** — 7h 40m − 6h 48m = 52 min × 5 nights = **4h 20m**, which
  is the sleep debt in the prototype spec, to the minute. `SleepDebtTracker`, ≥7 of 14
  nights `[CAP §2]`. Framed as *running short*, never as an owed ledger.
- **Bedtime drift (40 min)** — sleep-timing variability, the ingredient already inside
  `CircadianAnalyzer` and `BrainHealthScorer`'s circadian-alignment term, surfaced nowhere
  today `[CAP §9.3; CL §3.3]`.
- **Illness warning** — the real `IllnessEarlyWarning` gate: ≥2 of 5 signals, ≥1.0σ, ≥2
  consecutive days, 14-day baseline `[CAP §3c]`. The card states 2 of 5 over 3 nights.
- **"20 more minutes asleep"** — `RecommendationEvaluator.buildActionProof` 24h/7d lift, and
  the registered `steps → sleep duration` correlation pair (≥14 aligned days)
  `[CAP §3d, §5]`. Aggregate over 8 weeks, never n=1.
- **Chart** — 14 days of real day-to-day variation, not a smooth curve. Budgets 30–60,
  spends 18–96, four days of overspend, the Sunday hard run at 96 minutes, yesterday's
  8,400 steps preserved in the iPhone-only series.
- **Blood oxygen (B1) and the sleep forecast (B2)** never appear, so neither bug can reach
  this screen.
