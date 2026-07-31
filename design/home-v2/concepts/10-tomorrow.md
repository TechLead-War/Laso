# Concept 10 — Tomorrow

**File:** `10-tomorrow.html` · **Date:** 2026-07-29

---

## 1. The one-sentence philosophy

**This morning is already decided, so the screen leads with tonight and tomorrow — the only
part of your health you can still change while you are looking at it.**

Every other app in the corpus reports the past and calls it guidance. By the time you read
this morning's recovery score, this morning has happened. A screen that opens with a plan
for the next sixteen hours is the only version of a health home screen whose advice can
actually alter the thing it is describing.

### The design law that falls out of it

**The screen never predicts. It states what is currently building, or not, and what you can
still change.**

That single rule is how this concept survives the brief's hardest bans. F4 forbids
probabilities as percentages, `[CAP §6]` says Laso's Holt-Winters forecaster is real but
nothing back-tests it, and its `conf 82%` is an interval-width heuristic dressed as a
calibrated coverage probability. So:

- The hero's forward quantity is **clock arithmetic, not a model**: your usual wake time,
  minus your computed sleep need, minus your own typical time to fall asleep. Zero model
  risk. If it is wrong, it is wrong the way a kitchen timer is wrong.
- The **only** thing the forecaster contributes anywhere on this screen is the **width of the
  soft edge on the bar**. Its residual spread sets how far the fade runs. It is never
  printed, never converted to a percentage, and never given a confidence label.
- The "Tomorrow" slot makes no forward claim at all. It says **"Nothing new is building"** —
  a statement about the present, verifiable from the anomaly and illness-warning gates the
  app already runs. That is honest anticipation. It is not prediction.

### And the answer to "what about the boringly average user?"

Most users, most days, have nothing interesting coming. That kills a forecast-led screen —
unless the forecast is not the point.

**The hero is a plan, not a prediction, so it never has to be interesting.** "In bed by
10:50 for a full night" is exactly as useful on the most ordinary Wednesday of your life as
it is on a dramatic one. It is the same shape of answer every day, and its value does not
depend on the day being unusual.

The Tomorrow slot then does the boring day's real job: it says, in four words, that nothing
is brewing. That is not filler. Ruling things out is a service, and no competitor offers it —
Whoop, Oura, Ultrahuman and Bevel all give you a number and leave you to infer whether
anything is wrong `[W §7]`.

---

## 2. Why this layout order, element by element

Fixed slot sequence, identical every morning. Only content inside a slot varies `[N8]`.

| # | Slot | Why it is here |
|---|---|---|
| 0 | Status bar + header ("Wednesday / Morning") | Two words. No name, no date numerals, no greeting. `CoachGreetingView` scored 0/5 and rendered above the empty state `[CRIT §4.1]`. This is the minimum orientation cue and nothing more. |
| 1 | **Attention** — renders only when something is actually building | N6 is absolute: a health warning is never blurred, paywalled, hedged, or below position 3. It is position **1**, it is a full sentence rather than a badge, and it carries a harm anchor per F13. It renders in **zero** of the default mornings, which is why it does not cost the default budget. |
| 2 | **Tonight** — the hero, and the only component that instructs | T1 resolved action-first, because on a forward-looking screen the action *is* the forecast. A clock time is simultaneously the instruction and the prediction, so N1 is satisfied structurally rather than by policing. |
| 3 | **Tomorrow** — one sentence, then the chart | Anticipation, not prediction. It holds the screen's only chart, and the chart's x-axis literally ends in the future: fourteen past nights, a dashed divider, then tonight's target. That single geometric move is the whole concept in one image. |
| 4 | **Already decided** — the past, demoted on purpose and collapsed by default | The philosophical punchline. Last night's sleep and yesterday's steps are real and are shown with full comparison and verdict — but one tap down, under a heading that says why they are down there. Every other concept in this brief will put them near the top. |
| 5 | **What moves tomorrow** — aggregate evidence, collapsed | Progress monitoring against a goal is the single best-evidenced item in the psychology corpus: 138 studies, N=19,951, d+ = 0.40 `[PSY §9]`. It uses `RecommendationEvaluator.buildActionProof` `[CAP §9.8]`, always aggregated, never n=1. It states, it never instructs. |
| 6 | Footer — timestamp + **Show raw numbers** | The N7 escape hatch. One tap turns every score, band, colour and verdict off and shows what the sensors recorded. |

The reading order top to bottom is **future → present → past**, which is the inverse of every
competitor and of the current Laso screen.

---

## 3. Psychological principles used, and the mechanism

**Implementation intentions, not motivation.** The hero is a specific time. "In bed by 10:50"
is a when-then plan with the *when* pre-filled. Fogg's position is that a returning user is
already above the activation threshold, so motivational copy is annoying or condescending;
spend the screen on **ability** instead `[PSY §1]`. A clock time removes the entire planning
step from the one behaviour that matters. C5's converged pattern — one canonical daily
action, pre-chosen, zero decision cost — but expressed in a unit the user already lives in.

**Progress monitoring, aggregated.** Slot 5 is the only place the screen makes an effect
claim, and it is always "N times, this is what those nights averaged." d+ = 0.40 `[PSY §9]`,
and the aggregation is what keeps it out of the trap the current build falls into, where the
code's own dead band calls ±2 noise and the copy leaks the magnitude anyway `[CRIT §4.3]`.

**No loss framing, no streak, no floor at zero.** F9. The bar has no zero and no failure
state; a short night moves a position, it does not break anything. There is no compliance
counter anywhere. λ is somewhere between 1.07 and 1.955 with a median 1.31 and only 6 of 19
studies significant `[PSY §7]`, and a missed day costs 0.29 points out of 42 and fully
recovers `[PSY §3]`. Nothing here can be "broken."

**Capacity framing over failure framing.** The attention state says "In bed by 10:45 gets you
close" and, one tap down, "One night cannot clear five short ones." This is Gentler Streak's
inversion `[N §2.2]` applied to time: being below the band is a statement about what tonight
can buy, not a verdict on you.

**F8 by construction.** The concept cannot lead with a bad number because the hero's number
is a *bedtime*, which has no valence. Between 1-in-33 and 1-in-7 users meet an orthosomnia
definition and are measurably harmed by a sleep score `[CL §3.4, §3.5]`. This screen has no
sleep score. It has a bedtime.

**Autonomy support.** SDT: controlled regulation predicts worse mental health, ρ = .13 to
.46; autonomy support predicts better outcomes, ρ = .21 to .48 `[PSY §5]`. "Remind me" is
opt-in, the reminder time is stated before you commit, and the escape hatch is one tap.

---

## 4. UX principles applied

**Layer cake, never F-pattern** `[UX §6]`. Every slot is: short front-loaded heading →
statement containing the number → visual → interpretation. Nothing meaning-critical touches
the right edge; the only right-edge elements are disclosure chevrons.

**The 0-1s channel is non-textual** `[P §2.7]`. The bar tip's position relative to the marked
goal band answers good / ordinary / worth-attention with no reading. Three redundant channels
carry it — **position** (tip inside or short of the band), **shape** (a solid mark plus a
notch under the bar), and **colour** — so colour is never the sole channel, per HIG and WCAG
`[UX §8]`, and colour never encodes magnitude on its own `[UX §10]`.

**A positional bar, and exactly one reference range** `[UX §10, §11]`. Horizontal line bars
with coloured blocks scored highest on satisfaction and usability and significantly reduced
intention to contact a physician. The one range is the **personal goal range** — your sleep
need from `SleepNeedCalculator`, which fixes B6's hardcoded 7.5h. Substituting the goal range
for the standard range moves comprehension from 14.49% to 43.45%, N=6,766, p<.001 `[UX §11]`.
No pie, donut, gauge, treemap or 3D anywhere.

**One honesty mechanism, expressed geometrically** `[UX §11; CRIT §2]`. The current build
ships four simultaneous uncertainty widgets under one ring. This ships **one**: the bar's
right edge fades. Wider fade = less certain. It carries no number, so it cannot be mistaken
for calibration, and it degrades on its own — a day-1 user's fade covers half the bar, which
is the honest picture without a single word of apology.

**Two disclosure levels, zero navigation** `[UX §4]`. Everything expands in place. Home has
**three** exits total, all of them tab-bar destinations. A screen with 21 exits is a menu
`[CRIT §3]`.

**Element interactivity held at zero** `[UX §1]`. No number on this screen requires another
number on this screen to interpret. `Strain 14.2 · High` needed a score seven cards away
`[CRIT §12]`; here every number ships its comparison inside its own visual element.

**Platform floors.** Body 17px, smallest text 11px (the chart's labels are 12 viewBox units,
which render at ~11.2px at phone width — checked, not assumed). All tap targets ≥44px.
Contrast ≥4.5:1 in both themes. `prefers-reduced-motion` respected. Designed and screenshot-
verified at a 375px viewport first `[W §6.8]`.

---

## 5. Which user problems it solves

| Problem | How |
|---|---|
| "Three components tell me what to do and they disagree" `[CRIT §5]` | One instruction, and it is a clock time. Nothing else on the screen uses an imperative verb. Slots 3, 4 and 5 are strictly descriptive. |
| "The score doesn't match how I feel" — the #1 complaint across four of six competitor apps `[W §7]` | There is no score. Nothing on this screen claims to know how you feel. It knows what time you wake and how long you need. |
| "It never shows its work" — the C2 open lane `[W §10.2]` | One clause, inline, naming one cause with its magnitude: "Bedtime slid 40 minutes this week." The chart directly under it is the evidence for that clause. |
| "By the time I read it, it's too late" | The entire premise. |
| Cold start `[W §10.7; P §5.2]` | Day 1 gets the same slot, the same shape, a real answer, and an honest fade. No empty ring, no upsell, no fluff article. |
| Trust `[PSY §11]` | Seamful design. The "Why" panel says in plain words: "None of this is a prediction. It is your wake time minus your need. Only the softness of the edge comes from a model." Turning raw data into a score raises distrust from 40% to 60%; this screen barely does it. |

---

## 6. Metrics given prominence, and why

| Signal | Placement | Why |
|---|---|---|
| **Tonight's bedtime, in clock time** | Hero, largest type | T4 borrowed unit. "The weakest home screens require the app to teach a scale before the number means anything, and the teaching never sticks" `[N §12.2]`. A clock time needs no teaching, and it is the only quantity on the screen that is also an action. |
| **Sleep you would get, against personal need** | Hero bar | Devices exceed 90% sensitivity for sleep vs wake `[CL §3.1]`. Duration is Tier 1. The need comes from `SleepNeedCalculator`, not a flat 7.5h — fixes **B6**. |
| **Bedtime regularity** | The chart, slot 3 | The brief's single biggest available addition and currently absent from Home. UK Biobank n=60,977, 7.8-year follow-up: all-cause mortality HR 0.70, cardiometabolic HR 0.62, and **a stronger mortality predictor than sleep duration** `[CL §3.3]`. It uses only bedtime and waketime — the parts wearables actually get right — and the "your usual hour" band expresses it as a behaviour, not a score. |
| **Steps against 7,000** | Hero, iPhone-only and day-1 states | The only wearable metric with umbrella-review behaviour-change evidence; 7,000 vs 2,000 steps/day gives HR 0.53 (0.46-0.60) `[CL §10.2, §10.3]`. Anchored at 7,000 with the reason stated in plain words, never 10,000 — fixes **B7**. |
| **Resting heart rate** | Attention slot only | The most reliable consumer wearable measurement, MAE 0.98-1.78 bpm `[CL §2]`, but it only earns screen space when it clears the ≥5 bpm / 3-consecutive-night gate `[CL §2.3]`. |
| **Sleep debt** | As a *cause*, never as a ledger | It raises the need in the attention state and is named in words ("Five short nights have raised what you need"). Never an hours-owed balance: repayment is not 1:1 `[CL §3.2]`. |

---

## 7. Metrics deliberately removed, and why

Everything below was computable and is not on this screen.

- **Readiness / Recovery 0-100.** Removed entirely. The least-validated element on the current
  screen; the composite tracked perceived recovery *worse than its own raw HRV input* `[CL
  §4.2, §4.3]`. Removing it also dissolves B3's silent substitution and the iPhone-only hero
  problem in one move.
- **Daily Health Score 0-100.** Removed. Coverage shrinkage pulls sparse users toward a
  constant 75 presented at full visual confidence (**B4**), and it is graded 67/45 in one
  place and 85/70/55 in another `[CAP B3, B4]`.
- **Stress 0-100.** Removed. Recall for psychological stress from wearable signals is 50.0% —
  a coin flip printed in red `[CL §5.2]`. Not renamed. Removed.
- **Strain 0-21.** Removed. A log scale where 18→19 and 8→9 are drawn as equal steps `[CL
  §6.1]`.
- **Brain Health, Vitality Age, Pace of Aging.** Removed. Age framing has no effect on
  lifestyle intentions (4/5) and no effect on behaviour, and Laso's own norm tables say
  "treat outputs as informational signals only" `[CL §9.3; CAP B11]` (**B11**).
- **Sleep stages.** Removed. κ 0.21-0.53, Apple Watch deep-sleep sensitivity 50.7% `[CL
  §3.1]`. The bedtime chart uses only the timestamps the watch gets right.
- **Raw HRV in ms.** Not on the surface. Laso stores SDNN, which is not RMSSD and must never
  sit under a shared "HRV" label `[CL §1.2]`. It appears once, spelled out, inside the
  attention warning where naming it is necessary, and once in the raw-numbers escape hatch
  where it is labelled `Heart rate variability (SDNN)`.
- **Any percentage of anything.** No confidence figure, no probability, no percentile, no
  relative risk (F4).
- **`DataCoverageCard`, `ActivationProgressBanner`, morning check-in, the streak share card,
  `AskYourDataCard`, `WeeklyReviewEntryCard`, life-context chips.** All scored 0/5 `[CRIT §5]`.
  Cut. The screen asks the user for nothing.

One vocabulary, used everywhere: **sleep**, **bedtime**, **wake**, **need**, **steps**,
**resting heart rate**. No coined words. No "Heart Calm Signal", no "CONCIERGE", no "Body
Intelligence" `[CRIT §7]`.

---

## 8. Expected impact on daily engagement, with the mechanism

**Direction: fewer opens, longer-lived.** This is Athlytic's bet, not Whoop's `[W §4.2]`.

The mechanism is a **second natural open**. Every competitor's home screen is a morning
object; it is stale by lunchtime and there is no reason to return. This screen's hero is
about a moment that has not happened yet, so it stays live all day and acquires a genuine
evening use — the reminder fires and the screen is the thing you check when it does. That is
one high-intent evening session that no competitor earns except Ultrahuman, which earns it
with a real-time score and pays for it with a store block in the same scroll `[W §3.7]`.

Working against engagement, deliberately: the past is collapsed, there is nothing to browse,
there are three exits, and the screen is finished in about eight seconds. Session length
should fall. Sessions-per-day should go from roughly one to roughly two. Total time in app
should fall, and I consider that the correct outcome — the category benchmark is ~2.5
minutes a day `[W §9]` and most of it is spent looking for the answer.

---

## 9. Expected impact on retention, with the mechanism

The defensible frame is attrition, not cognition: ~53% of mHealth apps are uninstalled within
30 days, mean engagement lasts **4.1 days**, and the top stated reason is declining interest
`[UX §12]`. Four days is the window.

Three mechanisms:

1. **Day 1 is a finished product.** C8 says cold start is universally unsolved and every app
   pays for it in reviews `[W §10.7]`. Here the day-1 hero has the same structure, a real
   answer, and a wide honest fade. The user is never told to come back later. Progressive
   unlock is literacy scaffolding, not a loading bar over the first week of the relationship.
2. **The value does not depend on the day being interesting.** A recovery score is only worth
   opening when it might be surprising, which trains users to stop opening it on ordinary
   days — and then on bad days, which are the days the app has most to add `[P §6.7]`. A
   bedtime is worth the same every night.
3. **Nothing can be broken.** No streak, no compliance counter, no zero. The failure mode
   where a user drops out because they cannot face the screen after a bad week does not have
   a surface here.

The cost: a user who wants a daily number to react to gets nothing, and some of them will
leave in the first week. That is a deliberate trade, stated in §11.

---

## 10. The five-questions scorecard

Q1 what is happening · Q2 good or bad · Q3 why · Q4 what to do · Q5 what happens if I follow.
**Rule: anything scoring zero is cut.**

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Header ("Wednesday / Morning") | · | · | · | · | · | **0 — chrome, 2 words, not a block. Kept only as orientation; it is the one thing on screen I would delete first if pushed.** |
| **Attention card** (conditional) | ✔ | ✔ | ✔ | · | · | **3** |
| **Tonight — the bar** | ✔ | ✔ | · | · | ✔ | **3** |
| **Tonight — the instruction line** | · | ✔ | · | ✔ | ✔ | **3** |
| **Tonight — the cause clause** | · | · | ✔ | · | · | **1** |
| **Tonight — Why (expanded)** | ✔ | · | ✔ | · | ✔ | **3** |
| **Tomorrow — the sentence** | ✔ | ✔ | · | · | · | **2** |
| **Tomorrow — the bedtime chart** | ✔ | ✔ | ✔ | · | · | **3** |
| **Tomorrow — what is being watched** | ✔ | ✔ | · | · | · | **2** |
| **Already decided** | ✔ | ✔ | · | · | · | **2** |
| **What moves tomorrow** | · | · | ✔ | · | ✔ | **2** |
| Footer / escape hatch | · | · | · | · | · | **0 — a safety mitigation required by N7, not a content block.** |

No component on the screen scores zero except the two acknowledged above, both of which are
chrome rather than content.

---

## 11. Honest drawbacks, and who this design fails

**It fails the person who wants to know how they are.** That is the question users say they
open with, and this screen refuses it. There is no "how am I" number anywhere. Someone who
opens Whoop for the recovery percentage will find this screen evasive, and calling it
"honest" will not change how it feels.

**It fails the athlete.** No strain, no training load, no HR zones, no VO2max. A user
training for something has no reason to open this.

**It is a sleep app for Watch users.** The hero is a bedtime. A user who genuinely cannot
control their bedtime — shift workers, new parents, carers — gets an instruction they cannot
follow, every single day, which is worse than no instruction. There is no mitigation for this
in the build beyond the escape hatch, and that is a real gap.

**The iPhone-only and day-1 hero changes subject, not just confidence.** The slot goes from
"Tonight / bedtime" to "Rest of today / steps." It is labelled, it is never empty, it is
never an upsell, and it keeps the identical structure and promise — *by when, and what does
it buy you* — but it is not the same quantity, and a strict reading of N5 could call that a
substitution. I judged a labelled change of subject to be more honest than pretending to know
a bedtime for a user whose sleep the app cannot see. It is the single most arguable decision
in the concept.

**The uncertainty mechanism is quiet.** The fade is the only honesty widget and it is
subtle — it can read as "the bar just ends there." I removed its on-screen label ("give or
take") to stay inside the 20-word above-fold budget, and the explanation now lives one tap
down under "Why". That is a real cost paid to a real constraint.

**Colour still carries the pre-attentive verdict**, and green/amber is still a moral
vocabulary even when the copy is not. T3 was resolved as a band you sit inside, but I did not
follow Gentler Streak all the way to no failure colour at all.

**Removing every index is a product bet, not a research finding.** The research supports
demoting Readiness, Stress, Strain, Brain Health and Vitality `[CL §4, §5, §6, §9]`. It does
not prove a home screen with none of them retains better. It might read as an app that does
less.

---

## 12. The ten tensions, resolved

| # | Tension | Resolution |
|---|---|---|
| **T1** | Score-first or action-first | **Action-first, absolutely.** The action *is* the forecast: a clock time is simultaneously the instruction and the forward quantity, so there is no second thing at equal weight to contradict it. There is no score anywhere on the screen. |
| **T2** | One hero number or a cluster | **One forward quantity plus the one current quantity that drives it.** Tonight's bedtime (forward) and the bedtime drift that made it necessary (current cause). Two numbers, one of which exists only to explain the other. Never Welltory's three independent percentages `[N §5.8]`. |
| **T3** | Graded verdict or a range you sit inside | **A range you sit inside** — twice. The hero's need band, and the chart's "your usual hour". Below the band is capacity, not failure: "gets you close", "one night cannot clear five short ones." No moral vocabulary in the copy. |
| **T4** | Borrowed unit or native index | **Borrowed, with no exceptions.** Clock times, hours and minutes, steps. A forecast expressed in index points is meaningless, and "the teaching never sticks" `[N §12.2]`. Not one 0-100 scale ships on this screen. |
| **T5** | Explanation inline, one tap, or a paragraph | **One clause inline, the chart as its evidence, and the full reasoning one tap down.** "Bedtime slid 40 minutes this week" sits directly under the bar; the chart below shows the slide; "Why" expands in place without navigating. No paragraph above the number `[N §4.2]`. |
| **T6** | Celebration or calm | **Calm.** No confetti, no milestone, no streak, no share card. Acknowledgement is a single state change: the Remind button turns green and reads "Reminder set." Returning users are above the activation threshold `[PSY §1]`. |
| **T7** | Density or scroll | **Sparse above the fold, dense on demand.** Two cards and five numbers in the first viewport; everything else expands in place rather than being scrolled to. This avoids Garmin's "At a Glance" paradox `[W §6.8]` and Google Health's "huge block of empty space" `[P §3.8]`, because the density is one tap away, not one scroll away. |
| **T8** | Fixed slots or contextual morphing | **Fixed, with morphing inside one named slot.** The six slots never reorder. "Tonight" becomes a wind-down state in the evening and "Rest of today" on iPhone-only — inside the same slot, never by reordering. Oura's natural experiment: single-slot morphing survived, whole-screen morphing was attacked `[W §2.8]`. |
| **T9** | Honest uncertainty or confident simplicity | **One uncertainty mechanism, geometric, never numeric.** The forecast edge fades, and the fade's width is the uncertainty. It has no number, so it cannot imply calibration Laso does not have `[CAP §6]`. It scales honestly from a narrow fade (a steady user) to half the bar (day 1). One mechanism, not four `[CRIT §2]`. |
| **T10** | Opinionated hierarchy or user pinning | **Opinionated. No pinning, no customisation, no reordering.** An optional hero is not a hero (C7). The only user control is the escape hatch, which is a safety valve, not a layout preference. |

---

## 13. Literal budget counts — default morning (Watch data, ordinary outlook)

Counted from the rendered HTML, not estimated. Method: collapsed panels are excluded (they
are `max-height:0; opacity:0; overflow:hidden`), a composite duration such as `7h 40m` counts
as **one** number, and the simulated iOS status bar and the tab bar are counted separately as
platform chrome.

| Constraint | Limit | **This concept** | |
|---|---|---|---|
| Cards above the fold (375×812) | ≤ 3 | **2** | ✅ |
| Total blocks | ≤ 7 | **6** (4 cards + header + footer) | ✅ |
| Numbers on screen | ≤ 12 | **5** — `10:50`, `7h 40m`, `40`, `11pm`, `12am` | ✅ |
| Numbers above the fold | ≤ 5 | **5** (all five are in the first viewport) | ✅ at the limit |
| Tap targets | ≤ 8 | **6** content (+ 4 tab bar chrome) | ✅ |
| Distinct exits from Home | ≤ 6 | **3** (Live, Explore, Settings) | ✅ |
| Words of copy above the fold | ≤ 20 | **30** prose (37 including chart axis + legend) | ❌ **exceeded** |
| Uncertainty widgets per number | 1 | **1** (the fade) | ✅ |
| Reference ranges per number | exactly 1 | **1**, and it is the personal goal range | ✅ |
| Disclosure levels below Home | ≤ 2 | **1** (everything expands in place; zero card-level navigation) | ✅ |
| Facts to combine to read any element | ≤ 2, target 0 | **0** | ✅ |

Other states, for comparison:

| State | Cards | Numbers | Hero words | Taps |
|---|---|---|---|---|
| Good outlook | 4 | 4 | 18 | 6 |
| Attention (warning fires) | 5 | 5 | 72 above the fold | 6 |
| iPhone only | 4 | 4 | 20 | 6 |
| New user, day 1 | 4 | 4 | 19 | 6 |

### Budgets exceeded, and why

**1. Words of copy above the fold: 30 against a limit of 20.** This is a genuine overage and
I am not going to argue it away. The breakdown is 2 words of header, **19 in the hero
cluster** (which is inside budget on its own), and 9 in the second card — its heading
("Tomorrow"), its one sentence ("Nothing new is building."), and its expander label ("What is
being watched"). Including chart axis and legend text, which I classify as chart furniture
rather than copy, it is 37.

I could clear the budget by making the hero ~250px taller so the Tomorrow card falls below
the fold. I did not, because that sentence is this concept's entire answer to the
boringly-average-day problem, and burying it below the fold to win a word count would be
optimising the metric instead of the screen. It is stated here so a reviewer can weigh it.

**2. Attention state, above-fold words: 72.** When a health warning fires, the first card is
four sentences. N6 says a warning is never hedged and F13 requires a harm anchor, and neither
survives abbreviation. I take this overage deliberately and only in the state where a
warning is present — which is not the default morning the budgets govern.

---

## 14. Prototype notes

- Single standalone file. No network, no libraries, no web fonts, no emoji as iconography.
  Every icon is inline SVG.
- Verified: inline JS passes `node --check`; every `data-act` and `data-exp` control has a
  live handler; the project's own `check_prototypes.py` passes; and all five states were
  rendered in headless Chrome at a 375px viewport and inspected, not assumed.
- **Dev toolbar** (bottom-left, deliberately ugly and out of the way): theme, data state
  (loaded / loading / empty), hero source (Watch / iPhone only / new user), and outlook
  (good / ordinary / attention). Outlook has no effect in the iPhone-only and new-user states,
  which is correct — those users have no outlook signal to vary.
- **Internal consistency:** every derived figure assumes a 6:45 wake and 15 minutes to fall
  asleep, and all three outlooks share a 14-night bedtime median near 11:30pm so the "your
  usual hour" band is 11pm-midnight in every state. The canonical fictional user (Alex, 6h 12m
  last night, need 7h 40m, in bed 12:18am, 8,400 steps, bedtime 40 min later this week) is the
  **ordinary** state; the good and attention states are labelled variants with their own
  internally consistent night data, including their own raw-numbers screen.
- Deviations from the brief's fictional user: this concept never displays Readiness 62/71 or
  HRV 48/54 as content, because it displays no index and no HRV. Both appear only in the
  raw-numbers escape hatch, where they belong.
