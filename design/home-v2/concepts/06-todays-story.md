# Concept 06 — Today's Story

**File:** `design/home-v2/concepts/06-todays-story.html`
**Date:** 2026-07-29

---

## 1. The one-sentence philosophy

**Home is not a dashboard of metrics, it is a single thread through the twenty-four hours
around now — last night, this morning, the day ahead, tonight — where each moment carries
one number and one meaning, and the thread always ends with the one thing to do tonight.**

Every other concept in this set organises by metric category or by score. This one organises
by **time**, because time is the only axis a health-illiterate user already owns. Nobody has
to be taught what "last night" means.

---

## 2. Why this layout order, element by element

The slot order is **fixed and identical every day**. Only the content inside a slot changes.
This is the direct answer to N8 and to T8's habit-formation constraint.

| # | Slot | Why here |
|---|---|---|
| 0 | Status bar | Chrome. Its clock tracks the story time (7:04 / 2:12 / 9:18) — see §12 for why this deviates from the spec's 9:41. |
| 1 | Header — date + one icon button | One word, one numeral, one control. The control is the escape hatch (N7). Nothing above the user's own number, so C9 / F16 is satisfied structurally: there is no AI paragraph and no AI entry point anywhere on this screen. |
| 2 | **Last night** | The story starts where the day starts — with sleep, which is the only Tier 1 signal that is already finished when the user opens the app at 7am. `[CL §3.1]` It is also the causal parent of everything below it, so putting it first makes the rest of the thread explain itself. When a body-stress notice fires it pins here, at **position 1** (N6). |
| 3 | **Morning** | The now-marker at 7am. This is the hero slot. It carries the one native index on the screen, because this is the one moment nothing borrowed can express. |
| 4 | **Day ahead** | Steps against the personal goal range. The only metric with umbrella-review behaviour-change evidence (+1,800 steps/day; 7,000 vs 2,000 → HR 0.53) and the only Tier 1 signal that survives iPhone-only and day 1. `[CL §10.2, §10.3]` |
| 5 | **Tonight** | The thread closes with the instruction. Exactly one component on this screen gives an instruction (N1), and it is this one, and it is always last, because the last thing you read at 7am should be the thing you do at 10:30pm. |
| 6 | Footer | One line of provenance. `[CRIT §4.16]` calls this the cheapest block on the screen. |
| 7 | Tab bar | Chrome. Today · Live · Explore · Settings. |

### The rule that makes the screen change with the clock without changing structure

One deterministic rule governs density:

> **The node you are standing in is dominant. The node just before it is full. Everything
> earlier collapses to a single line on the rail. Everything later is drawn in dashes.**

So at 7am the screen is mostly empty ahead of you and solid behind you. At 9pm it is solid
almost the whole way down and Tonight is the dominant card. **The ink density of the thread
is a clock.** The rail behind the now-marker is a solid line with filled, ticked dots; the
rail ahead of it is dashed with hollow dots. Nothing is reordered, nothing is added, nothing
is removed — the same four slots, in the same order, every single morning.

### The honest-anticipation rule

At 7am the day ahead and tonight **have not happened**. They are never given a forecast.
The day ahead shows its goal shape with the small amount already walked filling it, and no
number and no verdict, because there is nothing yet to judge. Tonight shows a target, which
is a decision, not a prediction. There is no "you will probably…" anywhere on this screen.

---

## 3. Psychological principles used, and the specific mechanism

| Principle | Mechanism in this design | Source |
|---|---|---|
| **Behavioural goal setting (β=+0.89) and graded tasks (β=+0.87)** | Tonight is a single behaviour with a single time on it, and it is graded — 10:30 is 1h 15m earlier than last night, not a jump to a perfect schedule. | `[PSY §10]` |
| **Progress monitoring against a goal (138 studies, N=19,951, d+=0.40)** | "You have gone to bed earlier 6 times. Across those mornings your readiness averaged 4 points higher." Aggregate, never n=1 — the code's own dead band calls ±2 noise. | `[PSY §9; CRIT §4.3]` |
| **Endowed progress (19% → 34%)** | At 7am the steps track already has a sliver in it. The day is never presented as "not yet begun". | `[PSY §8]` |
| **Fogg — spend the screen on ability, not motivation** | A returning user is above the activation threshold, so there is no encouragement copy, no praise, no exclamation. The screen removes brain cycles: four labels you already know, one instruction, one button. | `[PSY §1]` |
| **SDT autonomy support (ρ = .21 to .48)** | The escape hatch is one tap from Home and turns every score, band and verdict off. Marking yourself unwell overrides the model. No pressure, no controlled regulation. | `[PSY §5, §11]` |
| **Lally — a missed day costs 0.29 of 42 and fully recovers** | There is no streak of any kind. "Winding down" is a record, not a chain; the toast literally reads *"Nothing to keep up, nothing to break."* And the expander closes with *"One earlier night will not clear the week, and it does not need to."* | `[PSY §3, §8]` |
| **F8 — never lead with a bad number** | The thread never opens on the index. It opens on hours of sleep, a unit that carries no grade. Even in the low state the first thing rendered is a plain sentence about what was noticed, not a red 41. | `[CL §3.4, §3.5]` |
| **Harm anchor (N=1,618, p<.001)** | *"This pattern often shows up a day or two before a cold. It is not a reason to call a doctor."* | `[UX §11]` |
| **Nudging is d=0.04 after publication-bias correction; structural nudges survive** | No informational nudge copy anywhere. The only persuasion used is **ordering** — the instruction is at the end of a thread you are already reading. | `[PSY §12]` |

---

## 4. UX principles applied

- **Layer-cake scanning.** Every node is heading → number → comparison → interpretation,
  top to bottom, left-aligned. Nothing meaning-critical sits on the right edge. `[UX §6]`
- **Positional bars only (F14).** One value, one horizontal track, one tinted band, one
  marker. No pie, donut, gauge, treemap or 3D. Colour is never the magnitude — the marker's
  *position* is; the verdict word repeats it in text for the ~1 in 3 users who cannot read
  the graph. `[UX §10, §11; CL §11]`
- **Exactly one reference range, and it is the personal goal range (F12).** Sleep against
  the personal need, readiness against the personal 7-day range, steps against the personal
  goal band. Never a population band, never two. 14.49% → 43.45% comprehension. `[UX §11]`
- **Comparison inside the same visual element (F11 / N2).** The number, its band and its
  verdict word are one row plus one bar. Zero facts must be combined from elsewhere on the
  screen. `[UX §1, §5]`
- **Two disclosure levels, not three (C4).** Home → an in-place expander. The expanders do
  not navigate, so they are not exits. `[UX §4]`
- **5.4-inch first.** The top cluster is laid out for a 375×812 viewport; the dev toolbar
  ships a 5.4" frame and a fold guide so the claim is checkable rather than asserted.
  `[W §6.8]`
- **Type and touch floors.** Body 17px, smallest text 11px, all targets ≥44px, contrast
  ≥4.5:1 in both themes using the shipping tokens verbatim.
- **F17 — no permanently identical region.** The thread's shape genuinely changes through the
  day, so no slot renders identically at 7am and 9pm, while the *structure* is unchanged.
- **The chart.** Seven nights drawn as bars on a shared clock axis, with a tick at each
  bedtime. This is the only chart on the screen and it shows duration **and** sleep
  regularity at once — the strongest sleep finding available (UK Biobank n=60,977, mortality
  HR 0.70, a stronger predictor than duration) using only bedtime and waketime, which are the
  parts wearables get right. The interpreting sentence sits **above** the chart, per D3.
  `[CL §3.3; N §2.2]`

---

## 5. Which user problems it solves

| Problem | How the thread answers it |
|---|---|
| "Three components tell me what to do and they disagree." `[CRIT §5]` | One instruction exists, in one slot, at the end. Sleep debt does not sit beside it giving a fourth instruction — it *is* the reasoning inside it. |
| "The score does not match how I feel." (the #1 complaint across four of six competitor apps, C2) | Every node names its cause inline. The morning node says *"Sleep was 1h 28m short."* Causality runs **along the thread**: each node's explanation points at the node directly above it. |
| "28 numbers and one verdict." `[CRIT §8]` | 6 numbers on the whole screen, every one of them with a band and a verdict word. |
| "I do not know what 62 means." | It sits inside a drawn range labelled *range*, with the word *Usual* beside it. The scale never has to be taught. |
| "The app collects input it ignores." `[CRIT §4.10]` | The only input on the screen is "I feel unwell", it appears only when the data already suspects it, and tapping it visibly rewrites tonight's instruction. |
| "A high-graded warning is at position 13, behind a blur." `[CRIT §4.13, §4.17]` | The notice pins inside the first node, at position 1, in full text, with a harm anchor, at every hour of the day, never blurred, never paywalled, never hedged. |
| "Nothing works without a Watch." `[P §5.2]` | Three labelled data states, same four slots, same structure, lower confidence. Never empty, never an upsell, never a silent substitution. |

---

## 6. Metrics given prominence, and why

| Signal | Slot | Why |
|---|---|---|
| **Time asleep, in h:mm** | Last night | Devices exceed 90% sensitivity for sleep vs wake; clock time needs no interpretation; and it is compared against `SleepNeedCalculator`'s personal need, **not** the hardcoded 7.5h (fixes **B6**). `[CL §3.1; CAP B6]` |
| **Sleep regularity (bedtime drift)** | Last night → expander | The strongest sleep finding of the last three years, computable today, currently surfaced nowhere on Home. `[CL §3.3]` |
| **Sleep debt in hours** | Last night → expander | RISE's borrowed unit. A rolling balance dents instead of resetting. `[N §1.2, §1.7]` |
| **Readiness 0-100** | Morning | Demoted but kept, under strict conditions — see §7. |
| **Steps against 7,000** | Day ahead | The only metric with umbrella-review behaviour-change evidence, anchored at 7,000 where the curve inflects, not 10,000 (fixes **B7**). `[CL §10.2; CAP B7]` |
| **Bedtime, as a clock time** | Tonight | The instruction is a unit you already own and can act on tonight. |
| **Aggregate action proof** | Tonight → expander | The highest-scoring component available and currently buried on a detail screen. `[CAP §9.8]` |
| **Resting heart rate in bpm** | Morning (new-user state) / notice | Most reliable consumer wearable measurement (MAE 0.98-1.78 bpm). Only ever flagged at the clinical persistence gate. `[CL §2, §2.3]` |

### On the one native index

Readiness appears **once**, in the morning node, and only there, and it is bound by four rules:

1. **It is never the largest number.** Every number on this screen renders at the same 34px.
   No moment of the day outranks another typographically. This is a direct answer to **F5**.
2. **It carries no delta.** The fictional user's yesterday-readiness of 71 exists in the data
   model and is never rendered. Fixes **B2's cousin** — the hero-chip mismatch (**B3**).
3. **It is a band you sit inside**, not a target you hit — 62 inside 56-74 reads *Usual*.
4. **It is labelled honestly.** In the iPhone-only and new-user states the slot does not
   silently substitute a different index under the same label; it changes the label, changes
   the unit, widens the band and says which device it came from (**fixes B3 properly**).

---

## 7. Metrics deliberately removed or hidden, and why

| Removed | Reason |
|---|---|
| Day-over-day delta on **anything** | F1. Consumer RMSSD limits of agreement ±10-24 ms against a population SD of 15 ms. `changeChip` today has no dead band at all. |
| **Daily Health Score** and **Weekly Score** | Three indices with three band tables was the original failure. `[CRIT §5]` One index survives; the other two do not render on Home. |
| **Stress 0-100** | Recall for psychological stress from wearable signals is 50.0% — a coin flip in red. Not renamed, **removed from Home**. `[CL §5]` |
| **Strain 0-21** | A log scale presented as linear steps is a comprehension hazard, and session-RPE matches TRIMP at r=0.79-0.86. `[CL §6]` |
| **Brain Health 0-100** | Invented composite, unfamiliar name. Its best ingredient (circadian alignment) is promoted to sleep regularity in the Last night expander; the wrapper is gone. |
| **Vitality Age / Pace of Aging** | F7. No effect on lifestyle intentions or behaviour in 4 of 5 RCTs; Laso's own norm tables are self-documented as heuristic with no DOIs. `[CAP B11]` |
| **Sleep stages** | κ 0.21-0.53, Apple Watch deep-sleep sensitivity 50.7%. The error bar swallows the number. |
| **Raw HRV in ms** | Buried. SDNN is not RMSSD and must never share an "HRV" label. It appears in exactly one place: the plain-numbers escape hatch, where no verdict is attached to anything. |
| **Data coverage card, activation banner, "Patterns found: 12", streak share card, morning check-in, watch tutorial, "CONCIERGE"** | All score 0 on the five questions. `[CRIT §4.4, §4.8-4.12, §4.17]` |
| **Forecast confidence "conf 82%"** | F4. An interval-width heuristic reading as a calibrated probability. |
| **Blood oxygen** | Not shown until **B1** is fixed. Today it is 100% discarded by an outlier filter. |
| Any percentage as a probability, any relative risk, any cross-person comparison | F2, F4. |

---

## 8. Expected impact on daily engagement, with the mechanism

**Mechanism: the screen has a different answer at 7am, 2pm and 9pm, and the user knows it,
because the now-marker visibly moves.** Ultrahuman is the only app in the corpus that
genuinely earns a 3pm reopen, and it earns it with a live recovery score `[W §3.7]`. This
concept earns it with time itself, at zero statistical cost — nothing is recomputed
dishonestly, the marker simply moves and the future segments become the present.

The 9pm session is the valuable one and it is the one this design creates. Tonight's slot is
inert at 7am (a target and a Remind button) and is the dominant card at 9pm with a
completion affordance. That is a second daily session on a screen that today has one.

**Countervailing force, stated honestly:** F17 says a static region loses up to 33x its
deserved attention, and this design fixes that. But the same movement is friction for
habit formation. It is bounded by keeping the four labels, the order, the rail and the
grammar byte-identical every day; only ink density and which node is dominant vary.

---

## 9. Expected impact on retention, with the mechanism

Retention is the real constraint: ~53% of mHealth apps are uninstalled within 30 days,
mean engagement 4.1 days, top abandonment reason "lack of interest / declining motivation"
(31.6%). `[UX §12]` Three mechanisms:

1. **Day 1 is a finished product, not a loading bar.** First sync pulls 10 years of
   HealthKit history, so a Watch-wearing new user gets the full thread on day 1 `[CAP §8]`.
   The genuinely-new state still fills all four slots with real numbers and real
   comparisons — resting heart rate against the range of the four mornings actually
   recorded, sleep against the goal the user chose at sign-up. Nobody sees an empty ring.
   C8 says cold start is universally unsolved and everyone pays for it in reviews.
2. **Bad days stay openable.** No streak to break, no compliance framing, no zero floor, no
   "you failed" state, and a one-tap way to turn every verdict off. The self-tracking harms
   literature offers exactly one mitigation and this is it. `[PSY §13; N §12.4]`
3. **The screen answers the complaint every competitor gets.** C2 is the open lane: four of
   six recovery apps are told their score does not match how the user feels, and none of them
   explains on the home screen. Every node here explains itself in a clause, inline, for free.

---

## 10. Honest drawbacks, and who this design fails

- **It fails the user who wants a dashboard.** Six numbers is a deliberate starvation diet.
  A quantified-self user who opens the app to compare HRV, respiratory rate and deep sleep
  will find none of them on Home and will call it a toy. Whoop's 83% DAU/MAU came from
  exactly the density this concept refuses. `[W §1.8]`
- **It fails the shift worker and the person with an irregular life.** "Last night → morning
  → day → tonight" assumes a day that starts in the morning and ends at night. A night-shift
  nurse's thread is wrong at every node, and the concept has no answer for that yet.
- **It fails the user who opens the app at 11pm.** Tonight has already passed; the instruction
  is stale. The prototype does not model a fourth time state, and it should.
- **The 9pm auto-scroll is a real risk.** The screen scrolls itself to centre the now-marker.
  That is the concept working, and it is also the app moving content under the user's thumb.
  It needs a real usability test, not a designer's confidence.
- **A thread invites scrolling that a health screen does not need.** Four segments is the
  right number. Five would be the beginning of the end.
- **It commits hard to one instruction being right.** If the advisor picks badly, this design
  gives the user nothing else to look at. Density is a hedge and this concept has none.
- **The escape hatch is the least-designed part of it.** It is a plain list on purpose, but
  a user who lives in it is a user for whom the whole product has failed, and the design does
  not currently notice or respond to that.

---

## 11. The five-questions scorecard

**Q1** what is happening · **Q2** good or bad · **Q3** why · **Q4** what next · **Q5** what if I follow it.
Rule: anything scoring 0 is cut. Nothing content-bearing on this screen scores 0.

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Header — date + Display button | · | · | · | · | · | **chrome** — it is navigation plus the N7 escape hatch, not a content block |
| **Node 1 — Last night** (h:mm, band, verdict) | ✔ | ✔ | ◐ | · | · | **2.5** |
| Node 1 expander — 7 nights on a clock | ✔ | · | ✔ | · | · | **2** |
| Node 1 notice — body-stress warning (fires in the low state) | ✔ | ✔ | ✔ | ◐ | · | **3.5** |
| **Node 2 — Morning** (index, band, verdict, cause clause) | ✔ | ✔ | ✔ | · | · | **3** |
| **Node 3 — Day ahead** (steps, goal band, verdict) | ✔ | ✔ | · | ◐ | · | **2.5** |
| **Node 4 — Tonight** (the one instruction) | · | · | ◐ | ✔ | ◐ | **2** |
| Node 4 expander — why this time + aggregate proof | · | · | ✔ | · | ✔ | **2** |
| Footer — one provenance line | · | · | · | · | · | **kept** — `[CRIT §4.16]` explicitly keeps this as the cheapest block on the screen |
| Tab bar | · | · | · | · | · | **chrome** |

---

## 12. The ten tensions — how this concept resolved each

| # | Tension | Resolution taken |
|---|---|---|
| **T1** | Score-first or action-first | **Both, separated by time, never at equal weight.** The thread *opens* with state (last night, this morning) and *closes* with the instruction (tonight). The instruction is the last thing you read and the only imperative on the screen. |
| **T2** | One hero number, or a cluster | **One number per time segment, never a cluster.** Four numbers across four moments, each alone in its node, each with its own band. No two numbers ever sit side by side competing to be obeyed — the Welltory failure case is structurally impossible here. |
| **T3** | A graded verdict, or a range you sit inside | **A band you sit inside.** Every value is a marker on a track with one tinted personal range. The verdict vocabulary is Short / Usual / Strong / Below / Met / On the way — no moral grades, no failure state, and *below the band* is described as capacity, not failure. |
| **T4** | A borrowed unit, or a native index | **Mixed, exactly as mandated.** Borrowed units for everything measurable — hours asleep, steps, a clock time for bedtime. The native index (readiness) appears once, in the morning slot, because that is the one moment nothing borrowed can express. It is never the largest number and never carries a delta. |
| **T5** | Explanation inline, one tap, or a paragraph | **Inline at each node, one clause.** *"Sleep was 1h 28m short."* Depth lives behind two in-place expanders that do not navigate. No paragraph anywhere. A future node has no inline explanation because it has nothing yet to explain. |
| **T6** | Celebration or calm | **Calm, with acknowledgement at completed nodes.** A completed node gets a filled dot and a tick, and a completed goal gets one flat sentence (*"Goal met, and the evening is still yours"*). Marking wind-down replies *"Nothing to keep up, nothing to break."* No confetti, no praise, no streak. |
| **T7** | Density or scroll | **Medium.** Six numbers, six blocks, one screen plus a short scroll. The visual richness comes from the thread — rail, dots, bands, the seven-night chart — not from number count. Sparse is not automatically calm, so the screen is never empty; it is quiet ahead of now and full behind it. |
| **T8** | Fixed slots, or contextual morphing | **Contextual morphing inside a fixed structure.** Four slots, same order, same labels, same grammar, every day, forever. What moves is the now-marker and, with it, which node is dominant, which are compact, and where the rail turns from solid to dashed. This is Oura's surviving single-slot morphing generalised to a whole thread without ever reordering it. |
| **T9** | Honest uncertainty, or confident simplicity | **One mechanism: the band.** A wider band means less certainty. The iPhone-only and new-user states widen it and name their source in one line. There is no confidence percentage, no certainty bar, no "based on 3 of 5 signals", no missing-signals paragraph. One, not four. |
| **T10** | Opinionated hierarchy or user pinning | **Opinionated.** There is no customisation, no reordering, no pinning. An optional hero is not a hero (C7). The single user control is the escape hatch, which does not rearrange anything — it turns interpretation off. |

### The hard problem, and how it was resolved

Habit formation says the strongest lever is being the same thing in the same place every
day; a screen that changes with the clock fights that. **The resolution is that the
structure is invariant and only the ink moves.** Four slots, fixed order, fixed labels,
fixed grammar, a rail that is always a rail. Compare the 7am and 9pm states in the dev
toolbar: nothing has been added, removed or reordered — the marker has moved down, three
nodes have compacted into rail lines, and the dashed part of the rail has become solid.
A user who opens the app every morning at 7am sees the identical screen every morning at
7am. The variation is *within a day*, not *between days*.

---

## 13. Budget counts — measured, not estimated

Counted from the actual rendered DOM in the **default morning state**: 7:04am, Apple Watch,
usual level, loaded, everything collapsed, 375×812 viewport, light or dark.

| Budget | Limit | This concept | Pass |
|---|---|---|---|
| Cards above the fold | ≤ 3 | **3** — Last night, Morning (hero), Tonight. *Day ahead is a rail line, not a card.* | ✅ |
| Total blocks on the default morning | ≤ 7 | **6** — header, 4 thread nodes, footer. *Status bar and tab bar are chrome.* | ✅ |
| Numbers on screen | ≤ 12 | **6** — `29`, `6h 12m`, `62`, `1h 28m`, `10:30 PM`, `7:04 AM` | ✅ |
| Numbers above the fold | ≤ 5 | **5** — `29`, `6h 12m`, `62`, `1h 28m`, `10:30 PM` | ✅ (at the limit) |
| Tap targets | ≤ 8 | **8** — Display, Last week expander, Remind, Why this time expander, 4 tabs. *4 if the tab bar is excluded, as `[CRIT §3]`'s count of 23 appears to be.* | ✅ (at the limit) |
| Distinct exits from Home | ≤ 6 | **4** — Live, Explore, Settings, Display sheet. *Expanders open in place and are not exits.* | ✅ |
| Words of copy above the fold | ≤ 20 | **20** — see the count below | ✅ (at the limit) |
| Confidence / uncertainty widgets per number | 1 | **1** — the band | ✅ |
| Reference ranges per number | exactly 1 | **1**, always the personal goal range | ✅ |
| Disclosure levels below Home | ≤ 2 | **1** — in-place expanders; nothing navigates | ✅ |
| Facts to combine to read any element | ≤ 2, target 0 | **0** — number, band and verdict are one element | ✅ |

**The 20 words above the fold, literally:**
`Tuesday` · `LAST NIGHT` `Short` `Last week` · `MORNING` `readiness` `Usual` `range`
`Sleep was … short.` · `Day ahead` · `TONIGHT` `lights out` `target` `Remind`
= 1 + 4 + 6 + 2 + 4 + 3 = **20**.

Counting notes, stated so the count can be checked rather than trusted:
- Numerals and their units (`10:30`, `PM`, `6h 12m`) are counted as **numbers**, not words —
  they are counted once each in the numbers row above.
- The Tonight expander label *"Why this time"* (3 words) sits below the 5.4" fold. Turn on
  the fold guide in the dev toolbar with the 5.4" frame to verify. On a 6.1" frame it rises
  above the fold and the count becomes **23**.

### Budgets exceeded

**None.** Two are at the limit (numbers above the fold: 5 of 5; tap targets: 8 of 8; words:
20 of 20) and would be breached by adding a single element, which is the intended
constraint.

Three things were *changed* rather than exceeded, and are disclosed here:

1. **The status bar reads 7:04 / 2:12 / 9:18, not the spec's 9:41.** A screen whose entire
   thesis is a now-marker cannot print a status-bar time that contradicts it. The status bar
   tracks the story time.
2. **The instruction is a labelled target, not a sentence.** The brief's 1-3s window asks for
   "one sentence, ≤12 words". Tonight renders `10:30 PM` + `lights out` instead. It is
   shorter, it lands faster, and — critically — it means the one number in that node is never
   printed twice. The sentence form lives one tap down in *Why this time*. This is a
   deliberate deviation, not an oversight.
3. **The band label appears on the node you are standing in, not on every bar.** The
   convention is taught once per screen, at the now-marker, and the other bars carry the
   reference in their `aria-label` and in their verdict word. This buys 2 words against the
   20-word budget and is the one place where the concept trades a little explicitness for
   the budget.

---

## 14. What the prototype ships

- Four data-state / time-state axes in the dev toolbar: **time** (7am / 2pm / 9pm),
  **data** (Watch / iPhone-only / genuinely new), **readiness level** (high / usual / low,
  where low also fires the body-stress notice), **screen state** (loaded / loading / empty),
  plus theme, a 5.4" frame and a fold guide.
- **Three hero states, same slot structure, all labelled, all lower-confidence rather than
  empty:** full wearable (readiness against a 7-day band); iPhone-only (7-day step average
  against a personal range, with *"Your phone cannot read your morning. This is your week
  instead."*); genuinely new (resting heart rate against the range of the four mornings
  actually recorded, with *"Four mornings recorded. The range tightens as more arrive."*).
  No empty state, no hardware upsell, no silent substitution.
- **Loading**: the four slots are already drawn with their labels; only the values shimmer.
  The structure never flickers.
- **Empty** (no Health access): four slots, four honest one-liners, one button.
- **Escape hatch**: header → Display → *Plain numbers*. Turns off every score, band, colour
  and verdict and renders the readings grouped by the same four time segments. One tap from
  Home, reversible.
- Real inline-SVG chart, working expanders, working press states and haptic-feel scale,
  `prefers-reduced-motion` honoured throughout, light and dark, 320px to desktop, no network,
  no libraries, no emoji as iconography.
