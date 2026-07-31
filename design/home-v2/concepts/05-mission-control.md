# 05 — Mission Control

**File:** `design/home-v2/concepts/05-mission-control.html`
**Date:** 2026-07-29
**User rendered:** Alex, 34. Readiness 62. Sleep 6h 12m against a 7h 40m need. Sleep 4h 20m
short over 5 nights. Steps 8,400 yesterday. Resting heart rate 58 against a usual 55. Hard
run Sunday. Bedtime 40 minutes later than usual across the week.

---

## 1. The one-sentence philosophy

**Density is not the enemy of calm — uninterpretable density is; so put the comparison and
the plain-word verdict inside every single element, let colour carry the pre-attentive load,
and lock the whole thing to one rigid grid so twenty numbers are scanned chromatically in
one sweep instead of parsed one at a time.**

This concept takes the opposite side of the argument from a sparse screen and tries to win
it on the evidence. Whoop ships a dense scroll and gets **83% DAU/MAU, roughly 3-10x the
category** `[W §1.8]`. Garmin went cleaner and was told "the emphasis on larger cards and a
cleaner aesthetic means less information fits on the screen at once, forcing users to scroll
more frequently to access the same metrics they could previously see with a quick glance"
`[W §6.8]`. Google Health's redesign produced "a huge block of empty space" and "why so much
white wasted space?" `[P §3.8]`. Apple's own rule is two-sided: "sparse layouts can make the
widget seem unnecessary, while overly dense layouts are less glanceable" `[UX §8]`.

The brief's own numbers say the same thing more precisely. The card-count and number-count
budgets in §6 are **proxies**. The mechanism they are proxying for is stated one row down in
the same table: *"Facts a user must combine to interpret any one element — ≤ 2, and 0 is the
target. Element interactivity is the mechanism behind every extraneous-load effect. Put the
comparison inside the same visual element."* `[UX §1]`

`Strain 14.2 · High` is expensive because you must fetch a score from seven cards away to
know whether high is good. `Sleep last night · 6h 12m · [bar with the 7h 40m need marked] ·
Under` is cheap no matter how many of them are on the screen, because it costs zero
lookups. Mission Control therefore spends the number budget and refuses to spend the
element-interactivity budget. **Element interactivity on this screen is 0 for every one of
its 22 numbers.**

---

## 2. Why this layout order, element by element

Fixed slots, top to bottom. The order never changes. Only content inside a slot varies.

| # | Slot | Why here |
|---|---|---|
| 0 | **Body stress warning** (conditional) | N6: a health warning is never below position 3. When `IllnessEarlyWarning` fires it takes position 1, full width, unblurred, with a harm anchor. It is absent on an ordinary morning, which is what makes its presence meaningful. The current build puts this at position 13 behind a paywall blur `[CRIT §4.13, §4.17]`. |
| 1 | **The cluster** — readiness, its band, two contributor chips, the one action, two pinned tiles | The whole top-of-screen answer in one container. Score first in reading order (T1), action pinned into the same container so the two are computed and rendered together and cannot contradict each other the way three components do today `[CRIT §5]`. The two pinned tiles complete the 3-item cluster (T2). |
| 2 | **The board** — four self-contained tiles in two named groups | Below the fold, where NN/g says 26% of viewing time goes and everything is optional `[UX §7]`. Grouped "Sleep" and "Movement and heart" so a returning user learns two fixed addresses rather than six floating tiles. Every tile is complete: label, value, its one reference range, its verdict. |
| 3 | **Last 14 nights** — a real chart, with the interpreting sentence above it | D3, Gentler Streak: the interpreting sentence sits **above** the chart, not below `[N §2.2]`. The expander reveals bedtime over the same 14 nights, which is the second-order question the chart provokes. |
| 4 | **Past results** | The only Q5 component. `RecommendationEvaluator.buildActionProof` is computed today and shown only on a detail screen `[CAP §9.8]`. Progress monitoring against a goal is the best-evidenced item in the whole psychology corpus: **138 studies, N=19,951, d+ = 0.40** `[PSY §9]`. Stated as an aggregate over 6 instances, never as an n=1 delta. |
| 5 | **Footer** — updated stamp, the escape hatch, and the honesty sentence | The "Readiness is a directional summary, not a measurement" line is always rendered, never behind a tap, because Tier 3 requires that label and hiding it behind an info button would make it optional. |

The single most important ordering decision: **the action lives inside the score's own card.**
The brief's structural failure #1 is that three components answer "what should I do today"
and none knows the others exist `[CRIT §5]`. Making the instruction a row of the score
container makes that architecturally impossible — there is one action row, it sits under the
number that justifies it, and no tile anywhere else on the screen is allowed to instruct.

---

## 3. Psychological principles used, and the specific mechanism

**Pre-attentive colour as the load-carrying channel (C3).** Every tile has a 3px coloured
left rail, a coloured verdict word, and a coloured square glyph before that word. Whoop,
Oura, Athlytic and Welltory all converged here, and the research names the mechanism: colour
gives "a verdict before reading, and it is why a dense scroll below the fold survives:
colour carries the load so density is scanned chromatically, not parsed" `[W §1.4, §2.4]`.
Colour is never the sole channel (HIG + WCAG) and never encodes magnitude — it encodes a
three-level verdict that is also stated as a word and as a marker position `[UX §10]`.

**Element interactivity, not chunk count, is the real constraint `[UX §1]`.** Cowan's
focus-of-attention capacity of ~4 chunks applies to items you must hold simultaneously to
reach a conclusion. Nothing here requires holding two items simultaneously. Miller's 7±2 is
explicitly not citable, and NN/g says visible items are recognition, not recall `[UX §2]`.

**Goal setting on behaviour and graded tasks (β = +0.89 and +0.87) `[PSY §10]`.** One
action, pre-chosen, with Done and Remind me. Zero decision cost, C5.

**Progress monitoring `[PSY §9]`.** Past results, aggregated over repetitions.

**Endowed progress `[PSY §8]`.** In the new-user state the goal shape is drawn hatched with
"2 of 7 days recorded", never as an absent number and never as 0-of-N.

**Autonomy support without abandoning hierarchy (SDT, ρ = .21 to .48) `[PSY §5]`.** The user
picks which two tiles ride in the cluster. The panel says so in words: "Pick any two. The
order of everything else on this screen never changes."

**Habit cue stability `[PSY §4]`.** Same slots, same order, every morning.

**What is deliberately not used:** no compliance streak (Lally: a missed day costs 0.29
points on a 0-42 scale and fully recovers, so a streak lies about the biology `[PSY §3]`),
no loss framing (λ median 1.31, 6 of 19 studies significant `[PSY §7]`), no variable reward
(no health-trial evidence; 92 RCTs found no relationship between persuasive-principle count
and efficacy `[PSY §6]`), no informational nudge copy (d = 0.43 → **0.04** after
publication-bias correction, BF₀₁ = 33.84 against information interventions specifically
`[PSY §12]`), no deliberate incompleteness (Zeigarnik does not replicate `[PSY §9]`).

---

## 4. UX principles applied

- **Layer cake, not F-pattern `[UX §6]`.** Every tile is: short front-loaded heading →
  number directly under it → single reference range under that → verdict under that. Four
  rows, identical geometry, every tile, every state. Nothing meaning-critical on the right
  edge. Headings are front-loaded and none of them begins with "Your".
- **One reference range, and it is the personal goal range (F12) `[UX §11]`.** Comprehension
  of a result's relative location: standard range only 14.49% → goal range added 35.92% →
  **goal range only 43.45%** (N=6,766, p<.001). Substituting beats adding. Every meter here
  draws exactly one shaded region. Where a personal range does not yet exist (new user), the
  external goal is drawn instead and labelled as the general goal — one range, never two.
- **Positional marks, never colour-for-magnitude (F14) `[UX §10]`.** No pie, donut, gauge,
  treemap or 3D anywhere. Tiles use positional bars. The 14-night chart is a lollipop plot of
  distance from the one reference, which keeps the bar grammar (a stem from a baseline) while
  making a 90-minute deficit legible — a zero-baseline bar chart of 6-8 hour nights
  compresses the entire week's variation into the top 8% of the plot, which is honest and
  unreadable. The reference is the origin, so the encoded quantity *is* the comparison.
- **Non-textual 0-1s channel `[P §2.7]`.** Marker position on a band, plus the verdict
  colour, plus the tile rail. Readable with the text blurred out.
- **1-3s: one sentence, ≤12 words.** "Keep today easy. Walk, not run." — 6 words.
- **3-5s: one clause, one cause, with magnitude `[W §1.9]`.** "Sleep short 1h 28m". This is
  the C2 open lane: four of six competitor apps ship no reason on the home screen and all
  four get complained at for it.
- **Two disclosure levels maximum `[UX §4]`.** Home → the two inline expanders. There is no
  third level from this screen.
- **Platform floors `[UX §8, §9]`.** Body 17px, absolute floor 11px, all tap targets ≥44px
  with ≥8px separation, text contrast ≥4.5:1 (tertiary captions sit near 7:1), real
  `:focus-visible` rings, `aria-label` on the icon-only pin control, `aria-expanded` on both
  expanders, `aria-hidden` on the collapsed drawer, `prefers-reduced-motion` respected.
- **5.4" first `[W §6.8]`.** Measured in a real browser at 375×812: the cluster occupies
  y=97 to y=669 and the fold sits at y=737, so the whole cluster and only the board's group
  heading are above the fold. At 375×667 (4.7") the fold cuts inside the pinned tile row and
  the score, the action and both buttons remain visible.
- **Thumb zone `[UX §7]`.** Every interactive control is at y≥740 in the scrolled document or
  inside the lower two-thirds of the cluster. The top strip is reading only.

---

## 5. Which user problems it solves

| Problem | How |
|---|---|
| "The score does not match how I feel" — the #1 complaint across four independent apps `[W §7]` | Two contributor chips with magnitudes sit under the score, permanently, no tap. If 62 feels wrong, the screen has already told you it is a short night plus Sunday's run. |
| Three components giving three instructions `[CRIT §5]` | Exactly one row on the whole screen is imperative. Tiles state, they never instruct. |
| 28 numbers, one verdict `[CRIT §8]` | 22 numbers, 22 verdicts. Every number renders with its comparison and its plain word or it does not render. |
| Four uncertainty widgets under one ring `[CRIT §2]` | One mechanism: the band. It is the same object in all five states and it degrades rather than being swapped out. |
| Silent score substitution under a "Readiness" label (B3) | The iPhone-only state changes the heading, the number, the unit and adds a visible "IPHONE ONLY" chip. Nothing is silently substituted. |
| Sparse users shown a 75 prior at full confidence (B4) | The Daily Health Score is not on this screen in any state. |
| A "High" warning at position 13, blurred `[CRIT §4.13]` | Position 1, full width, never blurred, with a harm anchor sentence (F13: N=1,618, adding "many doctors are not concerned until here" significantly reduced perceived urgency and requests to contact a doctor). |
| Hardcoded 7.5h sleep goal and 10,000 steps (B6, B7) | 7h 40m personal need from `SleepNeedCalculator`; 7,000 anchored to the dose-response evidence (7,000 vs 2,000 steps/day, **HR 0.53**, curve inflecting at 5,000-7,000 `[CL §10.3]`). |
| Users harmed by scores at all (3.0% strict to 14.0% lenient orthosomnia `[CL §3.5]`) | One tap in the footer turns every score, colour, band and verdict off and shows recorded values only. |

---

## 6. Which metrics were given prominence, and why

**In the cluster (above the fold):**

1. **Readiness 62** — first in reading order, and deliberately **not the largest number on
   the screen**. F5 forbids an unvalidated composite from being the largest number: a 2025
   review of 14 composite scores across 10 manufacturers found none disclosed its weights and
   none was validated against clinical outcomes, and in D1 swimmers WHOOP's Recovery score was
   *not* associated with perceived recovery while the raw HRV it measured **was** `[CL §4.2,
   §4.3]`. So the composite gets **position** (28px, top-left, first read, full-width band,
   the colour) and the validated borrowed units get **size** (30px). No daily delta anywhere
   near it — the band is 7 days, per F1 and N3.
2. **Sleep last night, 6h 12m** — devices exceed 90% sensitivity for sleep vs wake and clock
   time needs no interpretation `[CL §3.1]`. Against the personal need, never a flat 7.5h.
3. **Steps yesterday, 8,400** — the only wearable metric with umbrella-review behaviour-change
   evidence (+1,800 steps/day, +40 min walking/day) and the only Tier 1 signal that survives
   iPhone-only and day 1 `[CL §10.2]`.

**On the board:** bedtime steadiness (UK Biobank n=60,977: sleep regularity **HR 0.70** and a
stronger mortality predictor than duration, using only the timestamps wearables get right —
the single biggest addition available and absent from Home today `[CL §3.3]`); sleep
shortfall over 5 nights in hours (D2, RISE: a rolling balance a bad night dents rather than
resets); resting heart rate in bpm (nocturnal MAE 0.98-1.78 bpm, the most reliable thing a
consumer wearable measures `[CL §2]`) flagged only at ≥5 bpm or ≥10% above baseline for 3+
consecutive nights, which is exactly why 58 against a usual 55 renders **green**; movement
minutes against the WHO-anchorable 30.

---

## 7. Which metrics were deliberately hidden or removed, and why

| Removed | Reason |
|---|---|
| **Raw HRV in ms** | Tier 4. Laso stores **SDNN**, which is not the same quantity as RMSSD and must never share an "HRV" label; healthy range 19-75 ms is a 4x spread so a number means nothing without a personal band `[CL §1.2, §1.3]`. It appears in exactly one place in this prototype: the raw-numbers escape hatch, unjudged. That is what "bury" means. |
| **Vitality Age / Pace of Aging** | F7. Age framing increases emotion and risk perception, makes risk perception *less* accurate, and has **no effect on lifestyle intentions or behaviour** (5 RCTs, n=9,582). Laso's own norm tables say "treat outputs as informational signals only" `[CL §9.2; CAP B11]`. |
| **Stress 0-100** | Tier 3. Recall for psychological stress from wearable signals is **50.0%** — a coin flip in red `[CL §5.2]`. F15 also demands the word be renamed; the cleanest answer is not to ship the concept on Home at all. |
| **Strain 0-21** | Log scale is a comprehension hazard (18→19 ≠ 8→9) and session-RPE — one subjective 0-10 rating × minutes — matches TRIMP at **r = 0.79 to 0.86** `[CL §6.1, §6.2]`. |
| **Sleep stages** | κ 0.21-0.53, Apple Watch deep-sleep sensitivity **50.7%**. The worst accuracy-vs-perceived-authority gap on any health screen `[CL §3.1]`. |
| **Brain Health 0-100** | Invented composite, unfamiliar name. Its best ingredient — circadian alignment from sleep-timing CV — is promoted to the bedtime steadiness tile and the wrapper is dropped. |
| **Daily Health Score** | Coverage shrinkage toward a constant 75 presented at full visual confidence (B4), and graded 67/45 in one place and 85/70/55 in another. |
| **Data coverage rows, activation banner, "Patterns found: 12", morning check-in, streak share card, watch tutorial, Ask Your Data card, weekly review entry** | All score 0 on the five questions `[CRIT §5 scorecard]`. The morning check-in specifically is written twice and read zero times `[CAP §9.6]` — N4 gives two options and this concept takes the removal one. |
| **AI narration and any AI entry point above the number** | F16 / C9. Fitbit-Google: 3,419 revert votes, review bombing, a 39-item apology roadmap in 8 days. Nothing AI-shaped appears on this screen at all. |
| **Forecasts and "62% chance tomorrow feels tougher"** | F4: only 25% of the general population converts "1 in 1000" to 0.1%, and the app's "conf 82%" is an interval-width heuristic reading as a calibrated probability `[CAP §6]`. |

---

## 8. Expected impact on daily engagement, and the mechanism

**Direction: up, with shorter sessions.** The mechanism is not persuasion, it is
**information yield per second**. The screen answers more questions per glance than a sparse
alternative, so the reason to open it survives the day the score is boring — which sparse
concepts struggle with, because a single number that reads "Moderate" three days running is
the definition of banner blindness (F17: one right rail took **0.8% of fixations while
occupying 25% of the content area, 33x under-attention** `[UX §12]`). Twenty-two numbers
means the screen is never identical two days running even when the hero verdict is.

Two specific engagement mechanics, both structural rather than motivational:

- The action row changes daily and is the only imperative on the screen, so the "what now"
  question has exactly one address (C5).
- Pinning creates ownership of the top region without letting the user dismantle the
  hierarchy (D9, and explicitly *not* C7 — an optional hero is not a hero, and Garmin has no
  identity number because it shipped customisation instead of a decision `[W §6.2]`).

**Honest counter-evidence:** Athlytic's bet is the opposite one — one score, alone, a stated
10-second budget, and 11 widgets so the best home screen is the one you never open `[W §4.2]`
— and it is a lower-engagement, *higher-satisfaction* bet. If satisfaction is the metric
rather than sessions, this concept may lose.

---

## 9. Expected impact on retention, and the mechanism

The defensible frame is attrition, not cognition: **~53% of mHealth apps are uninstalled
within 30 days** and one large study found mean engagement lasted **4.1 days**, with the top
abandonment reason being lack of interest / declining motivation (31.6%) `[UX §12]`. Four
days is the window.

Three retention mechanisms, in order of expected size:

1. **Day-1 completeness.** First sync pulls 10 years of HealthKit history, so a
   Watch-wearing new user is not data-poor `[CAP §8]`. This screen is full on day 1 for that
   user. C8 says cold start is universally unsolved and every competitor pays for it in
   reviews; a dense screen that is *already* full is the strongest possible first impression
   inside a 4-day window.
2. **No guilt architecture.** No streak to break, no zero floor, no "you failed today". A
   user who sleeps badly for a week sees "More than usual" and "Later than usual", not a
   broken counter. D5: Bevel got an App Store review praising the *absence* of guilt copy,
   and every compliance streak eventually teaches users to stop opening the app on exactly
   the days it has the most value to add (D7).
3. **Trust through seams.** 40% of tracker users are concerned about data privacy, **rising
   to 60% among subscribers to a service that turns their data into a score — the act of
   scoring increases distrust** `[PSY §11]`. The permanent "not a measurement" footer line,
   the visible personal band rather than a hidden population table, and the one-tap
   scores-off switch are the mitigations the literature actually offers.

**The risk:** Eight Sleep's loudest complaint is not about any layout, it is about layouts
*changing* `[N §12.6]`. A dense fixed grid can only be retained if it is never reshuffled.
That is why slot order is a hard constraint here and pinning is confined to two cells.

---

## 10. Honest drawbacks, and who this design fails

**It fails the anxious tracker.** Between **3.0% strict and 14.0% lenient** of a general
sample meet an orthosomnia definition, with significantly higher insomnia scores at every
cutoff `[CL §3.5]`. This screen is a graded verdict on 22 things at once. For a user who is
already checking their sleep score at 3am, more graded verdicts is more surface to worry
about. The escape hatch is a real mitigation and it is one tap away — it is also, honestly,
the only one, and it requires the user to notice they are being harmed and act on it.

**It fails the brand-new, health-illiterate user on day 3.** The new-user state is honest but
it is still a grid with three locked cells. Apple Fitness's three rings are readable in under
a second with zero health literacy `[P §2]`; this is not. The design bets on a returning
user, and pays for it at first launch.

**It fails on the largest Dynamic Type sizes.** A two-column rigid grid at AX5 has to become
one column, and when it does, the "one sweep" property — the whole argument for the density —
is gone. The screen degrades into exactly the long scroll the concept was arguing against.

**The scan is chromatic, so it is worse for colour-vision deficiency than for anyone else.**
Every colour is redundantly encoded (verdict word + marker position + rail), so nothing is
*lost* — but the speed advantage that justifies the density is reduced to the speed of
reading, which is the sparse concepts' baseline.

**A grid of amber is a bad morning rendered four times.** On the low-readiness day the board
shows five warning-coloured tiles. F8 says never lead with a bad number, and two controlled
sham-feedback experiments show negative feedback measurably degrades alertness and cognition
`[CL §3.4]`. Position 1 is the warning with its harm anchor, and the action is "Rest today",
which is the mitigation — but five amber rails is still five amber rails.

**One number was left ambiguous on purpose and it is the weakest thing here.** Readiness's
verdict word comes from the app's shipping band table (≥67 / 45-66 / <45) while the bar shows
the personal usual range. Today they agree, and in all three rendered states they agree — but
they are two sources and on some future day a score of 80 could sit below a personal band of
82-90 and the word and the position would disagree. The correct fix is to derive the word
from band position and retire the population table for this number; that is a scoring change,
not a layout change, so it is flagged rather than faked here.

---

## 11. The five-questions scorecard for every component

Q1 what is happening · Q2 good or bad · Q3 why · Q4 what to do · Q5 what happens if I follow.
**Rule: anything scoring zero is cut.** Nothing on this screen scores zero.

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Body stress warning (slot 0, conditional) | ✔ | ✔ | ✔ | · | · | **3** |
| Readiness number + verdict word | ✔ | ✔ | · | · | · | **2** |
| Personal band + marker (the one uncertainty mechanism) | ✔ | ✔ | · | · | · | **2** |
| Contributor chip 1 — "Sleep short 1h 28m" | ✔ | · | ✔ | · | · | **2** |
| Contributor chip 2 — "Hard run Sunday" | · | · | ✔ | · | · | **1** |
| Action row + Done / Remind me | · | · | ◐ | ✔ | ◐ | **2** |
| Pinned tile — Sleep last night | ✔ | ✔ | · | ◐ | · | **2.5** |
| Pinned tile — Steps yesterday | ✔ | ✔ | · | ◐ | · | **2.5** |
| Pin control | · | · | · | · | · | control, not content |
| Board tile — Bedtime steadiness | ✔ | ✔ | · | ✔ | · | **3** |
| Board tile — Sleep shortfall, last 5 nights | ✔ | ✔ | ◐ | ◐ | · | **3** |
| Board tile — Movement yesterday | ✔ | ✔ | · | ◐ | · | **2.5** |
| Board tile — Resting heart rate | ✔ | ✔ | · | · | · | **2** |
| Chart — last 14 nights + sentence above it | ✔ | ✔ | ✔ | · | · | **3** |
| Chart drawer — bedtime, same 14 nights | ✔ | ✔ | ✔ | · | · | **3** |
| Past results | · | · | ◐ | · | ✔ | **1.5** |
| Footer — updated stamp + honesty line | · | · | ◐ | · | · | **0.5**, and it is the Tier 3 label F5 requires |
| Escape hatch | · | · | · | · | · | harm mitigation, N7 |

For comparison, the current screen: 11 of 19 components score zero, 1 of 19 gives a verdict,
1 of 19 gives an action `[CRIT §11]`.

---

## 12. How each of the ten tensions was resolved

| | Tension | Side taken | How it is built |
|---|---|---|---|
| **T1** | Score-first or action-first | **Score-first, action pinned in the same top cluster** | Readiness is the first thing read; the action is a bordered row *inside the same card*, directly under the number and its two causes. They cannot contradict because they are one component. This is the direct fix for structural failure #1, where three separate components instruct and none knows the others exist `[CRIT §5]`. |
| **T2** | One hero, or a cluster of 3-6 | **A cluster of 3** | Readiness + two user-pinned Tier 1 tiles. Three, not Oura's five to six, because that drew "it dilutes the information too much" from the category's most credible reviewer `[W §2.8]`; not one, because Laso's most defensible single number is unavailable to iPhone-only users and is the least validated thing on the screen `[CL §4.2; CAP §7]`. And unlike Welltory's three independent percentages, only one of the three ever instructs, so there is no rule needed for which to obey. |
| **T3** | Graded verdict, or a range you sit inside | **Graded verdict, colour-led — and the grade is also a position** | Three levels using the app's only threshold table, rendered as colour + word + a marker inside a personal band, so every tile carries both the Whoop-style grade and the Gentler Streak-style position. No emotion is not the safe answer: Garmin's 2024 desaturation removed the only free emotional feedback the screen had and users noticed `[W §6.4]`. Colour never encodes magnitude alone and is never the sole channel. |
| **T4** | Borrowed unit, or native index | **Native index for the composite, borrowed units everywhere they exist** | Readiness stays 0-100 because that is what the engine computes, but it is not the largest number. Everything else is in a unit the user already owns: h:mm, steps, bpm, minutes, minutes-past-your-usual. Laso already owns two under-used borrowed units and this screen uses both `[N §12.2]`. |
| **T5** | Explanation inline, one tap, or a paragraph | **Two contributor chips under the hero, always visible, zero taps** | This is the C2 open lane and it costs 5 words. Not a paragraph (Eight Sleep: "I don't know who thought anyone wanted to read that with their eyes half open" `[N §4.9]`), and not five tappable rows, which are a router rather than an explanation `[CRIT §4.6]`. |
| **T6** | Celebration, or calm | **Quiet celebration** | "Goal met" in green with a filled square. No confetti, no share sheet, no streak, no milestone card in slot 4 at the moment of peak engagement `[CRIT §4.4]`. Fogg: a returning user is already above the activation threshold, so motivational persuasion "would either be annoying or condescending" `[PSY §1]` — but immediate acknowledgement at the moment of completion is cheap and low risk `[PSY §2]`, so the acknowledgement stays and everything around it goes. |
| **T7** | Density, or scroll | **Density, deliberately, and this is the concept's whole thesis** | 22 numbers, each with its own comparison and verdict, on a rigid four-row tile grammar that never varies. The bet: extraneous load comes from element interactivity, which is 0 here, not from item count, for which the citable evidence is refuted (Miller, Hick, the jam study, ego depletion — all four listed as non-citable in §3). |
| **T8** | Fixed slots, or contextual morphing | **Fixed slots** | Identical order every morning. Content inside a slot varies — the alert appears or does not, the pinned pair changes, the chart plots sleep or steps depending on hardware — but nothing reorders. Oura ran the natural experiment: full-screen morphing failed, single-slot morphing survived `[W §2.8]`. Banner blindness is answered by 22 changing values, not by moving furniture. |
| **T9** | Honest uncertainty, or confident simplicity | **Exactly one mechanism: the band** | One object, five states. Full data: your personal 7-day range, solid. iPhone-only: your goal range, solid, plus a visible state chip. New user: the general goal range, drawn **hatched**, labelled "your own usual range opens once you have 7 days recorded". Locked tiles: an empty hatched rail with no marker. Never a confidence percentage, never "3 of 5 signals", never a certainty bar. The current build ships four simultaneous widgets under one ring `[CRIT §2]`; this ships one that degrades instead of being swapped. |
| **T10** | Opinionated hierarchy, or user pinning | **Opinionated hierarchy with pinning inside it** | The user chooses which two of six tiles occupy the cluster's secondary row. They cannot reorder slots, cannot remove the action, cannot demote readiness, cannot hide the warning. The panel states the boundary in words. This is D9 (pinning within a fixed hierarchy) and explicitly not C7 (customisation instead of a decision). |

---

## 13. Literal budget counts — default morning, Watch data, moderate readiness, nothing expanded

Counted from the rendered DOM at 375×812 with the fold measured in a real browser
(scroll viewport 97px to 737px; the cluster card occupies 97 to 669).

| Constraint | Budget | **Mission Control** | Inside? |
|---|---|---|---|
| Cards above the fold | ≤ 3 | **2** (the cluster in full; the board card's top edge and its "SLEEP" group heading) | ✅ |
| Total blocks | ≤ 7 | **6** — header, cluster, board, chart, past results, footer. **7** on a warning morning. | ✅ |
| Numbers on screen | ≤ 12 | **22** | ❌ **exceeded by 10** |
| Numbers above the fold | ≤ 5 | **8** — 62, 58, 74, 1h 28m, 6h 12m, 7h 40m, 8,400, 7,000 | ❌ **exceeded by 3** |
| Facts to combine to read any one element | ≤ 2, target 0 | **0** for all 22 | ✅ |
| Tap targets | ≤ 8 | **5** — Done, Remind me, Pinned, chart expander, Show raw numbers | ✅ |
| Distinct exits from Home | ≤ 6 | **3** — the Live, Explore and Settings tabs. Every other control acts in place. | ✅ |
| Disclosure levels below Home | ≤ 2 | **1** — two inline expanders, no navigation | ✅ |
| Words of copy above the fold | ≤ 20 | **31** | ❌ **exceeded by 11** |
| Uncertainty widgets per number | 1 | **1** — the band | ✅ |
| Reference ranges per number | exactly 1 | **1** everywhere | ✅ |

Counting rules used: a "number" is a distinct numeral group a person parses, matching the
method in `[CRIT §2]`; the status-bar clock and the dev toolbar are excluded as chrome, and
the four bottom tabs are excluded from the tap-target count for the same reason the brief's
own baseline of 23 excludes them (they are enumerated separately as exits). Including the tab
bar, tap targets are **9**. Content inside the collapsed chart drawer is not counted, since it
is not on screen.

### The three budgets I broke, and why

**1. Numbers on screen: 22 against 12.** This is the concept, stated as a number. The
sanctioned defence is that every extra number carries its own comparison and verdict inside
its own element, and it holds literally: all 22 are one of (a) a value, (b) that value's
single reference range, or (c) a magnitude inside a verdict phrase — and the brief's own
element-interactivity metric, which is the mechanism the number budget proxies for, is **0**.
The current screen shows 28 numbers with **1** verdict `[CRIT §8]`. Mission Control shows 22
with 22. If the budget's purpose is extraneous load, this passes on the mechanism and fails
on the proxy; if the budget's purpose is visual quiet, it fails outright and a sparse concept
should win the bake-off.

**2. Numbers above the fold: 8 against 5.** The excess is 3: the two reference-range labels
on the pinned tiles (`7h 40m need`, `7,000 goal`) and one band edge. Removing them would mean
either dropping the pinned tiles — which collapses T2 back to a single hero — or shipping a
bare number, which F11 forbids. Given the choice between violating a count and violating a
ban, I violated the count.

**3. Words above the fold: 31 against 20.** This is the exceedance I am least comfortable
with, and it is not a rounding error — it is 55% over. The mitigating fact is the *shape* of
those 31 words: they are 16 discrete labels averaging 1.9 words each, and exactly **one** of
them is a sentence, the 6-word action. There is no prose above the fold at all, which is what
the budget's cited failure case — Eight Sleep's paragraph above the number — was actually
about. The floor for this layout is the count itself: screen title 1 + score label 1 +
verdict 1 + band label 2 + two contributor chips 5 + action sentence 6 + two buttons 3 +
sleep tile 5 + steps tile 5 + pin control 1 + the peeking group heading 1 = **31**. Every
word above the fold is either a slot name, a verdict, or the one instruction; there is
nothing decorative left to delete. Getting to 20 requires removing the second contributor
chip (which is the T5 resolution) or one pinned tile (which is the T2 resolution), so this
concept cannot reach the budget without becoming a different concept. I report the number
rather than shrink the design to fit it.

**Not exceeded, and treated as hard:** tap targets, exits, blocks, cards above the fold,
reference ranges per number, uncertainty mechanisms, and every ban in §3.

---

## 14. States shipped, and how to see them

Dev toolbar, bottom right, deliberately utilitarian and outside the design.

| Control | States |
|---|---|
| Theme | Auto (follows `prefers-color-scheme`) · Light · Dark |
| Data state | **Watch** · **iPhone only** · **New user** · **Loading** · **Empty** |
| Readiness | High · Moderate · Low (Low also fires the body stress warning at slot 0) |

**Hero in three data states, same slot structure, never empty, never an upsell, never a
silent substitution (N5):**

- **Watch:** `Readiness · 62 · Moderate` on your personal 58-74 band; contributors "Sleep
  short 1h 28m" and "Hard run Sunday".
- **iPhone only:** `Steps a day, this week · 8,100 · Goal met` on the 7,000-10,000 goal band,
  with an "IPHONE ONLY" chip and the line "Based on movement only. Readiness needs heart and
  sleep data this phone cannot record." No buy button, no store link, no watch imagery. The
  board keeps the Sleep and Resting heart rate slots and marks them "Needs a wearable" with
  the goal shape drawn — degrade, never disappear.
- **New user, day 3:** `Steps yesterday · 8,100 · Goal met` on a **hatched** goal band, a
  "DAY 3" chip, and "7,000 is the general goal. Your own usual range opens once you have 7
  days recorded." Chips read "2 of 7 days recorded" and "Readiness opens on day 7". Sleep,
  bedtime and resting heart rate render as locked goal shapes, because the personal need and
  the personal band need 7 days and N2 forbids a number without its comparison. The chart
  plots the two complete days and eleven dashed placeholders; today is never plotted next to
  full days.

**Escape hatch (N7).** Footer, one tap, "Show raw numbers": every score, band, colour and
verdict disappears and the screen becomes recorded values with units and a neutral chart with
no reference line. This is the only place raw HRV in ms appears anywhere in the design.

---

## 15. Verification performed

- **JS syntax:** extracted and `node --check`ed clean.
- **Render sweep:** every combination of the 5 data states × 3 readiness levels × {default,
  raw, expanded, action done, reminder set} plus all 6 pin selections rendered in a stubbed
  DOM. No `undefined`, no `NaN`, no `[object Object]`, no empty slot. 26 render passes.
- **Handlers:** all 5 content controls plus the empty state's Connect button are wired
  through one delegated listener and every one changes the render. The 4 tabs move the
  active state. The dev toolbar's 8 buttons all repaint.
- **Layout measured in Chromium** at 375×812 and 375×667, light and dark, all 5 data states.
- **Internal consistency, checked arithmetically:** 7h 40m − 6h 12m = 1h 28m matches the
  chip and the chart's last stem. The chart's last five nights are 46 + 22 + 64 + 40 + 88 =
  260 min = the 4h 20m on the shortfall tile. The bedtime tile's 40 min equals the mean of
  the last seven bedtime dots. In the low state the alert's "6 bpm above your usual" equals
  61 − 55 on the heart rate tile, and 7h 40m − 5h 35m = the 2h 05m on the chip. Readiness's
  colour band agrees with its marker position in all three levels.
