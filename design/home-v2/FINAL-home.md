# Laso Home v2 — FINAL, as built

**File:** `design/home-v2/FINAL-home.html` (single file, no network, opens from `file://`)
**Base concept:** `08-the-band`, with merges M1–M8 from `RECOMMENDATION.md` §3.
**Date:** 2026-07-29

One sentence: **every signal is a position inside your own range, the range is drawn and never
printed, and the width of the range is the only thing on the screen that expresses confidence.**

---

## 1. The design decisions that matter

**1. The band is a shape, not a pair of numbers.** Every bar draws its range at the same
x-position (`50 ± BAND_HALF`%), so four fully verdicted signals cost **four numbers**, not twelve.
This is the only structural answer in the ten concepts to the collision between "every number
carries a verdict" and "≤5 numbers above the fold". It also means the four markers form a readable
column — left, centre, right, right — that works with no reading at all.

**2. Band width is the confidence widget, and it cannot be hidden.**
`BAND_HALF = { full:16, phone:24, new:36 }`. One constant, every bar. On a day-3 user the bands are
drawn dashed and enormous. A phone-only user's bands narrow the day they buy a watch. That single
control satisfies N5 (degrade, never disappear), T9 (exactly one uncertainty mechanism) and the
cold-start problem, with zero apology copy — and it is visible without a tap, which four of the ten
concepts claimed and none of them delivered.

**3. There is no index, and there cannot be one.** The formatter object contains `h:mm`, steps,
clock time, bpm, km, flights, km/h and ms. There is no code path that can emit a 0–100 score.
F5, F3 and the Tier-3 demotion are enforced at the type level rather than by design review.

**4. The position word is derived at render time, so the word and the picture cannot disagree.**
`posWord(value, band, key)` returns one of five locked words — `under · inside · above · earlier ·
later` — and a build check fails if any rendered word falls outside that list. This is the `B8`
class of bug (a size test labelled as a direction) made structurally impossible.

**5. Colour is spent once, on the one bar the screen is pointing at.** The band tint is identical
on every bar in every position; it identifies "your range", never "good". The marker is neutral
ink everywhere except the single bar furthest outside its band, which is amber. This is a
deliberate narrowing of M5a: rendering *every* out-of-band marker in a verdict colour would put
three amber marks on the default morning while the copy underneath says `one morning only` — the
pre-attentive channel would contradict the sentence. One colour, one focal point, no contradiction.

**6. A reading inside your own range gets no clause.** Three words saved, and a signal created: the
morning a clause appears where there was none is itself the event. On the quiet day the screen
carries no clauses at all and is visibly shorter — which is also the answer to F17's banner
blindness, because the screen's own word count changes day to day without any furniture moving.

**7. Every printed fact is derived from one raw array.** `RAW` holds fourteen nights, fourteen
step counts, fourteen bedtimes, fourteen resting heart rates and fourteen wake times. The band, the
value, the position word, the clause, the chart, the chart's interpretation sentence, the attention
strip's magnitude and persistence, the expander's derivation and persistence sentences, and the
instruction's clock time are all computed from those arrays. A build sweep asserts that the chart's
last plotted point equals the first bar's value in every day state.

Bands are derived from the *same* arrays the bars and the chart plot, excluding the three days the
screen is currently reporting on (`baselineOf`). Reading `RAW` in one place and `tail()` in another
is exactly how a widget and a home screen end up disagreeing — `B9` in miniature.

**What is still typed, stated plainly:** the two degraded-state instruction texts
(`Walk 20 minutes before 6:00 pm.`, `Walk 7,000 steps before 6:00 pm.`) and their reminder hours,
the harm anchor, the `Not counted` list, and the fixed prose of the expander. Those are product
copy, not facts about the user. No number on the screen is typed.

**8. Markers are positioned from the computed value in the markup itself.** The winning concept's
highest-severity defect was `.mk { left: 50% }` plus a `requestAnimationFrame` reposition, which
renders a false *"all four signals are inside your range"* on first paint. Here the `left` is
written into the HTML string and the only animation is a ring pulse that never moves the marker.
A build check fails if any marker lacks an inline position.

---

## 2. Slot by slot, as built

| # | Slot | Always renders |
|---|---|---|
| 0 | **Header** — `Today` + date, right-aligned. Zero tap targets. | yes |
| 1 | **The card** — 1a attention strip · 1b message · 1c four bars · 1d legend · 1e state note | yes |
| 2 | **Today** — one instruction + Done + Remind + proof line | yes |
| 3 | **Your last 14 days** — interpretation, chart, expander | yes |
| 4 | **Just the numbers** — the escape hatch | yes |
| 5 | **Footer** — updated stamp + trust line | yes |
| — | Tab bar — Today · Live · Explore · Settings | chrome |

**6 blocks against a limit of 7. Nothing reorders, in any state, ever.** The only time-of-day
variation is inside Slot 2: after 18:00 the eyebrow reads `TONIGHT` and the instruction restates as
`In bed by 10:30 pm.` — the hour picks up `pm` exactly where `tonight` drops out. The slot does not
move, resize or scroll.

### 1a — Attention strip
Conditional. Renders **inside** the hero card at position 1, above the message. Never blurred,
never paywalled, never hedged, no badge. Fires only on the `IllnessEarlyWarning` gate. One plain
sentence with the magnitude and the persistence, both computed:

> Your resting heart rate has been about **7 bpm** above your average for **three** mornings,
> alongside shorter sleep.
> *Many doctors are not concerned until this lasts a week or comes with a fever.*

The magnitude is measured against the **average**, not against the top of the band, because the
average is the anchor the persistence rule in the expander uses (`5 or more above your average for
three mornings`). Two anchors sharing one number reads as one rule and is a trap.

The harm anchor carries **no imperative**, because Slot 2 owns the only imperative on the screen.
Absent on the default morning.

When the strip fires it also **takes the focal colour**. The one amber mark on the screen is the
signal the strip names, even when another bar is mechanically further outside its band. Two entry
points on the one morning that needs a single one is the split the strip exists to prevent.

### 1b — The message
One line, 20px semibold, ≤6 words, about the person and never the performance. Derived:

| Condition | Copy |
|---|---|
| sleep under band | `Short night. You showed up.` |
| everything inside | `Nothing new is building.` *(M3)* |
| illness gate fired | `Something here has repeated.` |
| something out, not sleep | `A quieter day. Nothing more.` |
| day 3 | `Day three. Still learning you.` |

### 1c — Four bars, fixed order: Sleep · Steps · Bedtime · Resting heart rate

```
[label ────────────────────────────── value  position-word]
[position word, 17px, verdict colour]      ← focal bar only
[────── track, band drawn at the same x on every bar ──────]
[clause, 13px]                             ← only when outside the band
```

- Band **drawn, never printed**. No endpoints render on any bar in any state (build-checked: no
  digit may appear inside a `.track`).
- Marker: a 16px solid mark with a card-coloured ring and a soft drop shadow. **Circle = inside,
  diamond = outside**, and the diamond is visually larger. Verified to survive a 7px Gaussian blur
  at 320pt — the four positions are still readable with the type completely illegible.
- **Focal rule:** the single bar furthest outside its band (measured in band half-widths) moves its
  position word under the label, left-aligned, at 17px semibold in the verdict colour. Every other
  bar keeps the small grey word on the right. If nothing is outside, there is no focal bar.

**Default morning, verbatim:**

| Bar | Value | Word | Clause |
|---|---|---|---|
| Sleep | `6h 12m` | **under** (focal, 17px) | `by about an hour` |
| Steps | `8,400` | inside | *(none)* |
| Bedtime | `12:35 am` | later | `later all week` |
| Resting heart rate | `58 bpm` | above | `one morning only` |

**Band anchoring, all computed:**

| Bar | Anchor | Value in the build |
|---|---|---|
| Sleep | personal sleep need ± 25 min (**fixes B6**, never a flat 7.5h) | `7h 15m – 8h 05m` from a need of `7h 40m` |
| Steps | 7,000 to your own 85th percentile, rounded to 500 (**fixes B7**, never 10,000) | `7,000 – 11,000` |
| Bedtime | **wake − sleep need − onset** *(M2)*, ± 45 min | `6:30 − 7h 40m − 20 min = 10:30 pm`, band `9:45 – 11:15 pm` |
| Resting heart rate | personal baseline ± 2 bpm | `53 – 57 bpm` from a baseline of `55` |

Every one of those windows is computed over the eleven days **before** the three the screen is
reporting on, so a band never contains the readings it is judging and never changes shape when the
day state changes.

Bedtime gets a wider tolerance than the other three because its anchor is *derived* rather than
measured. That is stated in the expander.

The ± 25 min, ± 45 min and ± 2 bpm tolerances are **fixed constants, not derived from the user's own
spread.** For this user ± 2 bpm is close to two standard deviations of their own fortnight, which is
why it looks right here; for a user whose resting heart rate swings 4 bpm it would be far too tight.
`BaselineCalculator` must supply a personal spread before this ships. Listed in §11.

**The shift-work guard (§11.8), implemented.** `sd(wakeTimes) > 60 min` re-anchors the bedtime band
to the user's own median bedtime **and** switches Slot 2 to wake-time consistency:
`Up by 8:00 am tomorrow.` with the reason under it. The expander stops claiming the clock-arithmetic
sum in that state and names the median it actually used. Toggle it in the dev panel under
*Sleep pattern*.

### 1d / 1e
One swatch + `your range`. Two words, once, for all four bars — except on day 3, where the shape is
not the user's range yet and the swatch reads `the starting range, not yours yet`, and on the empty
screen, where it reads `your range, once there is one`.
State note renders only for phone-only and day-3, and it is a caption on the one uncertainty
mechanism, not a second one.

### Slot 2 — Today *(M1, from 02-daily-briefing)*

```
TODAY
In bed by 10:30 tonight.
[ Done ]                    [ Remind me tonight ]
Done six times. Those mornings you slept 38 minutes longer than usual,
measured across your last eight weeks.
```

*(Counts are spelled everywhere on this screen — `three mornings`, `fourteen nights`, `eight
weeks`, `six times`. Measured quantities keep their numeral and their unit — `38 minutes`,
`58 bpm`, `1.2 km`. `Done 6 times` alongside `eight weeks` was the one place that broke the rule.)*

- **The only imperative verb on the screen.** A build sweep parses every rendered state, skips the
  element marked `data-instruction` and every `<button>`, and fails if a second prose sentence
  begins with an imperative. All 15 state combinations pass.
- The instruction **always carries a clock time**, so there is an hour to be reminded at, and that
  time is the same number the Bedtime band is centred on. The hour is never ambiguous: in the
  morning `tonight` disambiguates it, and in the evening state, where that word is gone, the time
  carries `pm` itself. `In bed by 10:30.` read at 7pm is a sentence a tired person can put twelve
  hours out.
- `Done` writes a completion record that feeds the proof line, and the proof line **moves when it is
  pressed** — `Done six times` becomes `Done seven times`. The acknowledgement says the record is
  joined, so the record has to agree. **Nothing counts consecutive days**, and the acknowledgement
  says so out loud.
- `Remind me tonight` is a two-step commit — `Remind me tonight` → `Remind at 10:00 pm?` →
  `Set for 10:00 pm` — because §10.3 requires the time to be stated *before* the user commits.
- Proof line uses 03's grammar *(M6)*: payoff + size + **window**, aggregate, borrowed unit, no
  causal verb. **Absent entirely** for the day-3 user. Never fabricated.
- **Life-context override changes the instruction text, not just an acknowledgement** (§11.7). With
  *Unwell* declared, the instruction becomes `In bed by 9:45 tonight.` and the note explains why.

### Slot 3 — Your last 14 days
Sleep only in the full state; the first bar's signal in the degraded states, because a phone cannot
see sleep. Filled band, one dot per day, **no connecting line**, last dot emphasised.

The **interpretation sentence sits above the chart** (D3) and is derived, not written:
> *Eight of the last fourteen nights sat inside your range. The last five ran under it.*

On quiet days a caption *(M5b, from 07)* names what was checked and found unremarkable:
> *Your heart rate, breathing and temperature all sat in your usual range last night.*

Expander **How your range is built**, in this order:
1. Where each band comes from, in plain words, with the actual arithmetic.
2. Why the band is this wide — the one confidence signal, restated.
3. **When we call something a change** — the persistence rule out loud: *"We do not call that a
   change until it is 5 or more above your average for three mornings."*
4. **Not counted** *(M4, from 09)* — including *"How you feel. We do not measure it, so it is not in
   these ranges."*
5. Why steps start at 7,000.

08's four-metric chart-cycle button is **cut**, to hold tap targets at 8.

### Slot 4 — Just the numbers
`Just the numbers — turn off ranges and words. Nothing gets judged.` One tap removes every band,
every position word, the message and the instruction. It is the **only** place raw HRV appears, and
it is labelled `Heart rate variability (SDNN)`. Reversible, and the preference persists in
`localStorage` (wrapped in try/catch, because `file://` blocks storage in some browsers).

### Slot 5 — Footer
```
Updated just now.
Every number here is compared with your own history, never with other people.   (M8, from 05)
```

---

## 3. Data states

| | **A · Full wearable** | **B · iPhone only** | **C · New, day 3** |
|---|---|---|---|
| Band half-width | 16% | 24% | 36%, **dashed** |
| Bars | Sleep · Steps · Bedtime · Resting HR | Steps · Distance · Stairs · Walking pace | Steps · Distance · Stairs · Walking pace |
| 1d legend | `your range` | `your range` | `the starting range, not yours yet` |
| 1e state note | *(absent)* | `No wrist data, so these ranges are wider.` | `Still learning your usual. These ranges narrow at seven days.` |
| Per-row note | — | — | `still learning it` |
| Slot 2 | `In bed by 10:30 tonight.` | `Walk 20 minutes before 6:00 pm.` | `Walk 7,000 steps before 6:00 pm.` + anchor named |
| Proof line | present | present | **absent** |
| Chart | Sleep, 14 nights | Steps, 14 days | Steps, 3 days, dashed band |
| Slot 5 trust line | M8 verbatim | M8 verbatim | `Nothing here is compared with other people. These ranges start wide and narrow into yours.` |

Day 3 shows the phone family, not sleep and heart rate, because on day 3 nothing with a 7-day
baseline is honest. A day-1 screen and a day-200 screen differ in **band width, never in structure**.

**Day 3 never calls the shape "your range."** The starting bands are public anchors, not the user's
own history, so the legend, the chart's interpretation sentence, every bar's `aria-label`, the
expander's derivation and the footer all say so. M8's promise survives day 3 only in the half that
is still true — *nothing is compared with other people* — because *compared with your own history*
is not yet a thing the screen can claim.

**Loading:** the four bar shapes, all four labels and all four bands render immediately. Only the
values and the buttons shimmer. The shimmer inside a track spans the **whole** track, because a
placeholder pinned to the centre of the band is a picture of "inside your range" drawn by a screen
that does not know yet — the §11.9 defect wearing a shimmer. The structure never flickers.

**Empty:** the bands render as goal shapes, not blanks, and at the **widest** width the screen can
draw, because no data is the lowest-confidence state there is. `Nothing to read yet. The shapes are
ready.` plus one `Connect Apple Health` button, which really runs the loading state and lands on
day 3.

---

## 4. Budget counts — measured in a browser, not estimated

Measured live at **full wearable, short-night default, nothing expanded**, at a real
390 × 844 layout viewport (Chrome `Emulation.setDeviceMetricsOverride`, not a pinned element inside
a 500px window). The fold is the top edge of the tab bar. Numbers are counted as rendered elements,
so `6h 12m` is one number, not two.

| Constraint | Limit | **390 × 844** | |
|---|---|---|---|
| Cards above the fold | ≤ 3 | **2** | ✅ |
| Total blocks | ≤ 7 | **6** | ✅ |
| Numbers on screen | ≤ 12 | **9** — `6h 12m` `8,400` `12:35 am` `58 bpm` `10:30` `38` `14` `8h 05m` `7h 15m` | ✅ |
| Numbers above the fold | ≤ 5 | **6** — `6h 12m` `8,400` `12:35 am` `58 bpm` `10:30` `38` | ❌ **over by 1** |
| Facts to combine per element | ≤ 2, target 0 | **0** | ✅ |
| Tap targets | ≤ 8 | **8** — Done · Remind · expander · escape hatch · 4 tabs | ✅ at ceiling |
| Distinct exits from Home | ≤ 6 | **3** — Live, Explore, Settings | ✅ |
| Disclosure levels below Home | ≤ 2 | **1** — one in-place expander, zero navigation | ✅ |
| Uncertainty mechanisms | 1 | **1** — band width, visible without a tap | ✅ |
| Reference ranges per number | exactly 1 | **1**, personal; endpoints never printed on a bar | ✅ |
| Components giving an instruction | 1 | **1** — Slot 2, build-swept across 15 states | ✅ |
| **Words above the fold — prose** | ≤ 20 | **38** | ❌ **over by 18** |
| Words above the fold — every token | ≤ 20 | **62** | ❌ |
| Smallest text | ≥ 11px | **11px**, chart axis and tab labels, at 320pt | ✅ |
| Smallest tap target | ≥ 44px | **48px** buttons, 44px expander, 44px tabs | ✅ |
| §3 bans breached | 0 | **0** | ✅ |
| §8 non-negotiables breached | 0 | **0** | ✅ |

### The same counts across every viewport, honestly

The above-fold figures move with the device, so every one was measured at a real device-metrics
viewport rather than assumed.

| Viewport | Cards above | Numbers above | Prose words above | All tokens above |
|---|---|---|---|---|
| 320 × 568 (4") | 1 | 4 ✅ | 12 ✅ | 29 |
| 375 × 667 (SE, 4.7") | 2 | 4 ✅ | 15 ✅ | 34 |
| **375 × 812 (the brief's 5.4" reference)** | **2** | **6** ❌ | **38** ❌ | 62 |
| **390 × 844** | **2** | **6** ❌ | **38** ❌ | 62 |
| 430 × 932 (6.7") | 3 | 7 ❌ | 54 ❌ | 82 |
| 320 × 1200 (audit viewport) | 3 | 7 ❌ | 38 ❌ | 66 |

**Correction to the previous version of this document.** It reported 5 numbers and 20 prose words
above the fold at 390 × 844. Those figures were taken with the phone element pinned to 390px inside
a 500 × 813 headless window, so the fold was measured 31px too high and the proof line fell below
it. At a true 390 × 844 the proof line is **above** the fold and the real figures are **6** and
**38**. The measurement was wrong, not the layout; nothing about the screen changed.

**The overrun, and why it is not bought back.** Above the fold on the default morning the screen
carries five numbers by construction — four bar values plus the instruction's hour — which is
exactly the budget. Any part of the proof line that clears the fold puts it over. Spelling `38
minutes` as a word would hit 5 on the counter and would be a dial gamed rather than a design fixed;
the figure is a measured borrowed unit and M6 requires it. `Done 6 times` → `Done six times` is
different: that is a copy rule the screen already follows everywhere else, and it removed one
number honestly.

Per RECOMMENDATION §1.2, budget overruns are **not gated** — *"a ban is a design decision; a budget
is a dial."* Three dials are over. Both bans and all eight non-negotiables are clean.

The 20-word all-token budget is not reachable by any four-bar N2-compliant screen; the arithmetic
floor is about 29, which is what the 4" column measures. The prose figure is over for one reason
only: 18 of those 38 words are the proof line, and on the two largest phones it clears the fold.

**Other states, for reference:** phone-only renders **10** numbers, day-3 renders **8**, the escape
hatch renders **7**, loading and empty render **0**.

---

## 5. Five-questions scorecard, every component

**Q1** what is happening inside my body · **Q2** is this good or bad · **Q3** why did this happen ·
**Q4** what should I do next · **Q5** what happens if I follow it.

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score | Note |
|---|:--:|:--:|:--:|:--:|:--:|:--:|---|
| Slot 0 header | · | · | · | · | · | **0** | Furniture, kept by the brief's own ruling on the cheapest blocks. One line, zero tap targets, no greeting by name. |
| 1a attention strip | ✔ | ✔ | ✔ | · | · | **3** | Names the signal, the magnitude, the persistence and the harm anchor. Deliberately gives no instruction. |
| 1b message | · | ✔ | ◐ | · | · | **1.5** | The 0–1s emotional read. Q3 partial because "Short night" names the cause without a magnitude. |
| 1c bar — Sleep | ✔ | ✔ | ✔ | · | · | **3** | Value, personal range, derived word, and a clause carrying the magnitude, in one visual element. |
| 1c bar — Steps | ✔ | ✔ | · | · | ◐ | **2.5** | Q5 partial: below the band reads as capacity, which the expander states explicitly. |
| 1c bar — Bedtime | ✔ | ✔ | ✔ | ◐ | · | **3.5** | The strongest bar. Sleep regularity reaches Home for the first time, as a clock time, and it is the same number Slot 2 instructs on. |
| 1c bar — Resting heart rate | ✔ | ✔ | ✔ | · | · | **3** | `one morning only` is the persistence gate rendered as copy — the app visibly declining to alarm you. |
| 1d legend | · | ✔ | · | · | · | **1** | Two words that make the whole grammar legible. |
| 1e state note | · | · | ✔ | · | · | **1** | Explains why the geometry changed. Renders only when it changed. |
| Slot 2 instruction | · | · | · | ✔ | · | **1** | The only imperative on the screen. |
| Slot 2 Done | · | · | · | ✔ | ✔ | **2** | Writes the record that produces the proof line, and says nothing counts consecutive days. |
| Slot 2 Remind | · | · | · | ✔ | · | **1** | Fogg's prompt, placed at the hour of the behaviour rather than 13 hours early. States its time before it commits. |
| Slot 2 proof line | · | · | · | · | ✔ | **1** | Aggregate, borrowed unit, window named, absent when there is no history. |
| Slot 3 interpretation | ✔ | ✔ | · | · | · | **2** | Above the chart, per D3. Derived from the same array the chart plots. |
| Slot 3 chart | ✔ | ✔ | · | · | · | **2** | The only place the *inside*-drift the band cannot show is visible. |
| Slot 3 quiet-day caption | ✔ | ✔ | · | · | · | **2** | Converts silence from "the app is thin" into "the app looked". |
| Slot 3 expander | · | · | ✔ | · | · | **1** | Derivation, persistence rule, what is not counted, why 7,000. One tap, in place, no navigation. |
| Slot 4 escape hatch | ✔ | · | · | · | · | **1** | Scores 1 on purpose: it is the component that *removes* Q2. The only mitigation the self-tracking harms literature offers. |
| Slot 5 footer | · | · | ✔ | · | · | **1** | Freshness plus the promise that F2 is being kept. |
| Tab bar | · | · | · | · | · | **0** | Chrome. Three exits. |

**Nothing on the screen scores zero except furniture that the brief itself rules should stay.**
The current screen has eleven components scoring zero out of nineteen.

---

## 6. What was merged, and from where

| Merge | From | Landed |
|---|---|---|
| **M1** the complete action card — behaviour + clock time, Done, Remind, aggregate proof | `02-daily-briefing` | Slot 2, including 02's `.btnrow` two-button geometry and its `aria-pressed` states |
| **M2** clock-arithmetic bedtime anchoring, `wake − need − onset` | `10-tomorrow` | Slot 1c bar 3, plus the wake-SD guard that 10 did not have |
| **M3** `Nothing new is building.` | `10-tomorrow` | Slot 1b on quiet days |
| **M4** word-first verdict emphasis on the furthest-out bar; the `Not counted` list | `09-because` | Slot 1c focal rule + the expander |
| **M5a** marker weight and contrast that survives a 7px blur | `07-coach` | all four bars — 07's ring-behind-the-mark trick, re-cut for a 14px track |
| **M5b** `Your heart rate, breathing and temperature all sat in your usual range last night.` | `07-coach` | Slot 3 caption, quiet days |
| **M6** proof grammar: payoff + size + **window** | `03-body-budget` | Slot 2 proof line |
| **M7** derive every printed string from one raw array | `04-sleep-first` | build-level rule, enforced by the assertion pass |
| **M8** `Every number here is compared with your own history, never with other people.` | `05-mission-control` | Slot 5 footer. **Not** repeated in the escape hatch: that screen compares nothing with anything, so the sentence would contradict `Nothing here is judged` one line above it. The hatch says `Nothing here is compared with anything, including other people.` |
| — | `01-one-number` | **nothing**, as ruled |
| — | `06-todays-story` | **nothing**, as ruled — its evening dominance is inseparable from the N8 auto-scroll |

---

## 7. Where this deviates from RECOMMENDATION.md, and why

Fourteen deviations. Each one is a decision, not a slip.

1. **`Something has repeated. Read this first.` → `Something here has repeated.`**
   The specified copy contains an imperative, and §10.3 requires exactly one imperative verb on the
   screen, enforced by a build sweep. The sweep cannot pass with the original line. The pointer was
   also wrong: the attention strip sits *above* the message, so "read this first" points backwards.

2. **`…so it is not in this number.` → `…so it is not in these ranges.`**
   Merged verbatim from 09, where it referred to 09's readiness index. This screen has no number for
   it to refer to, so verbatim would be incoherent. One word changed to keep the sentence true.

3. **Marker colour is spent on the focal bar only, not on every out-of-band bar.**
   M5a asks for redundancy across position, colour, size and shape. Three of those are on every bar
   (position, shape, size). Colour is on one. Colouring all three out-of-band markers amber on the
   default morning would put a warning colour on a bar whose own clause reads `one morning only` —
   the pre-attentive channel would contradict the copy, which is the exact failure the brief exists
   to remove.

4. **Marker shape reduced from four states to two** — circle inside, diamond outside. Three shapes
   in a 14px track read as mush at a squint; two read cleanly and still survive a 7px blur. Direction
   is already unambiguous from position and from the word.

5. **`Remind me tonight` is a two-step commit.** §10.3 requires the time to be stated before the
   user commits, which a single-tap button cannot do. Three states, one tap target, reversible.

6. **Steps band top is `11,000`** — the user's own 85th percentile over the eleven days before the
   three under report, rounded to the nearest 500. Computed rather than chosen. It is a round
   number here by arithmetic accident, not by anchoring.

7. **Bedtime tolerance is ± 45 min against ± 25 for the other bars.** Its anchor is derived from a
   median wake time rather than measured, so a wider window is the honest reflection of that. With a
   ± 25 window the derived target also makes Bedtime the focal bar on the default morning, which
   contradicts the specified default content.

8. **Day 3 shows the phone family** (Steps · Distance · Stairs · Walking pace), per §10.7 column C.
   Nothing that needs a 7-day baseline renders on day 3.

9. **Slot 3 plots the first bar's signal in the degraded states.** "Sleep only" is not available to
   a phone-only user. The slot, its structure and its expander are identical; only the series
   changes.

10. **The chart's y-axis prints the two band endpoints.** The "endpoints are never printed" rule is
    applied to the bars, and build-checked there. The director's own ten-number list includes
    `8h 05m` and `7h 15m`, which can only be the chart axis, so this is the intended reading.

11. **Dynamic Type is exercised through a dev-panel `Text size` control.** HTML has no Dynamic Type.
    The three settings map to Default / Large / AX3 and drive one block of type-scale variables plus
    the AX3 stacking rules. The simulated iOS status bar and tab bar do **not** scale, because the
    app does not own that chrome; everything the app draws does.

12. **On the illness morning the focal colour moves to the signal the strip names**, not to the bar
    that is mechanically furthest outside its band. M4 asks for one entry point. Two — an amber
    word on Sleep and a strip about resting heart rate — is worse than either.

13. **Day 3 never says "your range."** M8's footer sentence and the `your range` legend are both
    claims about the user's own history. On day 3 the bands are public starting anchors, so the
    legend, the chart sentence, the bar labels, the expander and the footer all say the other
    thing. A promise that is false in one state is not a promise.

14. **The proof line's completion count is spelled**, matching every other count on the screen, and
    it increments when `Done` is pressed. The previous build said `Logged. It joins the record
    below` above a record that did not move.

---

## 8. Accessibility, as built

- Every control is a real `<button>`. Full keyboard operation, `:focus-visible` ring at 2px in the
  primary colour with a 3px offset, and focus is restored to the pressed control after every
  re-render (the screen re-renders from a string, so this is not free).
- `Escape` closes the dev panel and the build-check report and returns focus.
- Every bar carries a plain-language `aria-label`: *"Sleep 6h 12m, under your range, by about an
  hour."* The five position words are expanded into sentences for the label, so Bedtime reads
  *"later than your range"* rather than the ungrammatical *"later your range"* — a screen-reader
  user has no picture to fall back on. The chart carries one too, including the range and the
  latest reading.
- Icon-only controls carry `aria-label`; every decorative SVG carries `aria-hidden`.
- Expander uses `aria-expanded` + `aria-controls`. Buttons that hold state use `aria-pressed`.
- **Dynamic Type at AX3:** value and position word leave the label's line and stack under it, the
  band keeps full width, the button row becomes a column, the raw-readings rows stack, and the card
  grows. Verified at 320pt + AX3: **nothing truncates and nothing clips.**
- **Contrast**, computed against the card each token actually sits on. Every text token clears
  4.5:1 in both themes; every graphic pair clears 3:1.

  | Token | Light | Dark |
  |---|---|---|
  | Primary text on a card | 16.2:1 | 15.4:1 |
  | Secondary text | 9.1:1 | 10.4:1 |
  | Tertiary captions, axis, tab labels | 6.3:1 | 7.7:1 |
  | The verdict amber | 5.1:1 | 8.9:1 |
  | Primary button label | 5.7:1 | 7.2:1 |
  | `Done` pressed, label on green | 5.6:1 | 9.3:1 |
  | Band boundary stroke vs track | 4.7:1 | 6.8:1 |
  | Live marker vs track | 4.5:1 (focal) / 16.2:1 (ink) | 9.3:1 / 15.4:1 |
  | Ghost markers vs track | 3.7:1 | 5.6:1 |

  Ghost markers were `opacity:.30`, which is **1.9:1** — below the 3:1 graphic floor, so a
  low-vision user could not see the persistence the design says it shows rather than asserts.
  They are now `.55`.
- **Reduced motion:** verified by rendering with `--force-prefers-reduced-motion`. Markers place
  instantly, there is no settle pulse and no stagger, and the screen is otherwise identical.

---

## 9. Verification actually performed

1. `python3 check_prototypes.py` → **11/11 clean**, including `FINAL-home.html`.
2. `node --check` on the extracted inline script → clean.
3. **In-page build sweep across 15 state combinations plus 3 chart assertions** (`#checks=1`, or
   *Run build checks* in the dev panel). Every one passes:
   - ≤ 1 element carrying an instruction;
   - no second prose sentence starting with an imperative;
   - every position word inside the locked five-word vocabulary;
   - no digit printed inside any `.track`;
   - every marker carries an inline position at first paint;
   - the chart's last plotted point equals the first bar's value, in all three day states.
4. **Budget measured at six real viewport sizes** — 320×568, 375×667, 375×812, 390×844, 430×932 and
   320×1200 — through `Emulation.setDeviceMetricsOverride`, so the layout viewport, the fold and the
   scroll position are all genuine.
5. **Headless Chrome renders, every one read back and corrected:** 320×1200 / 390×844 / 430×932 in
   light and dark; loading; empty; illness warning; quiet day; phone-only; day 3; escape hatch;
   expander open; evening; unwell override; shift-work guard; AX3 at 320 default and illness; Done
   and Reminder pressed states.
6. **7px Gaussian blur test at 320pt** on the four-bar cluster: all four marker positions remain
   readable with every glyph illegible.
7. **Per-element geometry probes** rather than eyeballing: horizontal overflow against the phone
   bounds, chart axis-label bounding boxes against the plot's left padding, expander scroll height
   against its `max-height` at AX3, and the smallest rendered font size and tap target in the phone.

**The harness limitation recorded in the previous version is gone.** Headless Chrome clamps its
*window* to 500px, but the CDP device-metrics override sets the layout viewport directly, so
320 / 390 / 430 are now measured as devices rather than as a pinned element inside a 500px window.
That override is what exposed the wrong above-fold counts in §4.

---

## 10. Honest drawbacks, and who this fails

**The power user who came for a number — fails, permanently.** No readiness, no delta, by
construction, at the formatter layer. Explore is now load-bearing in a way it was not before.

**The athlete deciding whether to train — fails.** No strain, no load, no zones, no VO2max. The
entire answer is the Steps bar's position. This is the largest cohort the screen loses.

**The low-motivation user — fails.** No streak, no failure state, nothing to push against. The proof
line is the substitute and it is a weaker lever than gamification, which survived withdrawal in a
1,062-patient RCT. It is, however, the lever the evidence and F9 permit.

**Anyone whose metric is not one of the four — fails, and it is deferred rather than solved.** Blood
pressure, glucose, cycle, training load cannot reach Home. The user-selectable fourth bar remains
specified and unbuilt.

**The user drifting *inside* the band — not solved, and cannot be.** Sliding from the top of your
sleep range to the bottom reads `inside` both weeks. The 14-day chart is the only place it shows and
it is below the fold. The new clause rule is a partial mitigation, not a fix.

**Build-level drawbacks I own:**

- **The band's fill is a low-contrast tint — 1.24:1 against the track, not the 1.5:1 previously
  claimed.** Its *boundary* clears 4.7:1, and the plain word is the compliant channel by design —
  but a user with low vision reading only the fill will not perceive the range. This is a deliberate
  trade: a band saturated enough to clear 3:1 as an area reads as "the good zone", which is the
  moral colour vocabulary T3 rejects.
- **The proof line is above the fold on the two largest phones**, and it carries `38` and eighteen
  words with it. That is the whole of the number and prose overrun in §4. It is a genuine cost: at
  6:45am those eighteen words compete with four bar readings for the first glance. The fix is a
  design decision nobody has taken — render the proof line only in the evening state, when the user
  is actually at the moment of the behaviour — and it is not taken here because it would remove the
  Q5 answer from the session most users have.
- **Three consecutive far-outside readings crowd on one bar.** `markX` compresses positions the
  further outside the band they sit, so on the illness morning Sleep's two ghost markers land 2%
  apart and the older one would render underneath the live marker. It is dropped rather than drawn
  invisible, so that bar shows one ghost where the data has two. The clause and the `aria-label`
  still carry the true count in words.
- **The tolerance constants are not personal.** ± 25 min, ± 45 min and ± 2 bpm are typed. The
  *centres* are all derived; the *widths* are not. See §2 and §11.
- **The escape-hatch preference persists, the completion record does not.** `Done` and the reminder
  reset on any dev-panel state change, which is right for a prototype and wrong for a product.
- **`8,400` and `inside` are one DOM node,** so the budget counter reports them as one number and
  one word. That is the correct count and it makes the report string read oddly.
- **On a 4.7" SE the instruction is below the fold.** At 375 × 667 the hero card fills the visible
  area on its own and Slot 2 needs one short scroll. It fits at the brief's stated 5.4" reference
  (375 × 812) and above. Buying those 60px back means compressing the bar rows, which is what
  created the marker-overlap defect in the first place.
- **The three other tabs do nothing.** They are exits this prototype does not build, so there is no
  handler at all — the previous build moved `aria-current="page"` onto `Explore` while Today's
  content stayed on screen, which is a lie the screen could tell with no code behind it.
- **The screen has no answer at 3pm.** 03's intra-day fill remains deferred. The evening reminder is
  the only mechanism that earns a second session, and it is untested.

---

## 11. What must exist in the app before this ships honestly

Unchanged from `RECOMMENDATION.md` §11, restated with what the prototype now demonstrates.

**Must fix:** B6 (sleep goal), B7 (steps goal), B9 (one shared derivation for Home, chart and
widget). **Fix anyway:** B1, B2.

**Capabilities the prototype exercises but the app does not yet have:**

1. Personal band derivation for Steps, Bedtime and Resting heart rate, built **once** and consumed
   by Home, the chart and the widget. The prototype's `bands()` is the shape of it, including its
   `baselineOf` window: a band must never be computed from the readings it is judging, and it must
   read the same array the chart plots.
2. A single `BAND_HALF` as a function of history and signals present. It must reach the **empty**
   state too — a screen with no readings at all cannot draw a narrow band.
3. **Personal band widths, not just personal centres.** ± 25 min, ± 45 min and ± 2 bpm are typed
   constants here. `BaselineCalculator` must supply the user's own spread, or a steady sleeper and
   a variable one get the same window and one of them is accused every morning.
4. Consecutive-out-of-band counts exposed from `IllnessEarlyWarning`. Without them `one morning
   only` and `three mornings running` cannot render, and those are the screen's best trust mechanic.
   The **magnitude** must come out on the same anchor the persistence rule uses — deviation from the
   personal baseline, not from the top of the drawn band.
5. **Still blocking:** can `RecommendationEvaluator.buildActionProof` emit `38 minutes longer`
   rather than readiness points? If it can only emit index deltas, Slot 2 loses its Q5 answer.
6. A reminder scheduler bound to the instruction's clock time, replacing the check-in's
   push-permission path.
7. A completion record that cannot become a streak, enforced in the data model, and that the proof
   line reads **live** — the acknowledgement claims the record moved, so it has to have moved.
8. The advisor re-deriving the instruction after a life-context override — demonstrated here, absent
   in the app.
9. The 14-day wake-time SD rule — demonstrated here, absent in the app. When it fires, every
   explanation that names the clock-arithmetic sum has to stop naming it.
10. Marker placement at first paint, covered by a snapshot test, because the silent failure mode is a
    clean bill of health. The same test must cover the **loading** state: a placeholder centred in
    the band is the same false "everything is inside your range".
11. Copy migration to `Common/Copy/Copy+Home.swift`, with compile-time defaults for every string the
    widget shares. Note that several strings are **state-dependent** — the legend, the trust line,
    the chart's interpretation sentence and the expander's derivation all change wording on day 3 —
    so they are templates with a data-state argument, not constants.

---

## 12. Using the prototype

Open `FINAL-home.html` in any browser. The dev control is the small tab on the right edge.

Every state is also reachable by URL hash, so any screenshot is reproducible:

```
#theme=dark&data=phone&screen=loading&day=attention&time=pm&ctx=unwell
&sleeper=irregular&type=ax3&raw=1&disc=1&done=1&remind=2&fold=1&dev=1&w=390&checks=1
```

`checks=1` runs the build sweep and prints the budget count for whatever is on screen.
