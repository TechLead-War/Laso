# Concept 08 — The Band

**File:** `design/home-v2/concepts/08-the-band.html`
**Date:** 2026-07-29

---

## 1. The one-sentence philosophy

**Every signal is a position inside your own range, drawn in a unit you already own — there
is no score, no grade, and no way to fail this screen.**

---

## 2. Why this layout order, element by element

Fixed slot order. Only content inside a slot varies. Five blocks, top to bottom.

| # | Slot | Why here |
|---|---|---|
| 0 | **Header — "Today" + date** | Read-only. The top strip is for reading, not tapping: 49% of use is one-handed and thumbs drive ~75% of interactions, so every control on this screen lives in the lower two-thirds. `[UX §7]` |
| 1a | **Attention strip** (inside the hero card, position 1, conditional content) | N6 is absolute: a health warning is never blurred, paywalled, hedged, or below position 3. Rather than reserve a permanently-present alert slot (which F17's banner-blindness data would kill at up to 33x under-attention), the warning renders **inside** the hero card, above everything, in the same grammar as the rest of the screen. It carries the plain sentence, a harm anchor, and no colour-only badge. Today's build has this content at position **13**, blurred behind a paywall. `[CRIT §4.13, §4.17; UX §12]` |
| 1b | **The message** | Gentler Streak's signature inversion: interpretation precedes data. "Almost every other health app puts the chart first and the caption below." `[N §2.7]` One short human sentence, written about the person rather than the performance. This is the concept's whole emotional channel — see §10. |
| 1c | **Four positional bars** | The hero. Every band is drawn in the *same place* on every bar (34–66% of the track at full confidence), so the four markers form a vertical column the eye reads pre-attentively — high, inside, low — with **zero text**. That is the 0-1s requirement, and it is met without colour encoding magnitude. `[P §2.7; UX §10]` |
| 1d | **Legend — "your range"** | Two words, one swatch. F12 requires exactly one reference range and that it be the personal one; the legend names it once so the four bars do not have to repeat it. |
| 1e | **State note** (iPhone-only / new user only) | One sentence explaining *why the bands got wider*. It is not a second uncertainty widget — it is a caption on the only one. |
| 2 | **Today — the single instruction** | N1: exactly one component on this screen gives an instruction. It sits **below** the bars because T1 is resolved state-first — but the state is a position, not a grade. One sentence ≤12 words, one reason clause, one button. |
| 3 | **Your last 14 days** | The same band grammar over time. A real SVG chart: one filled band, one dot per day, no connecting line. Line graphs are the most used (35%) and among the hardest to read; bars and number lines beat them for patient comprehension. `[UX §10]` It also carries the "How your range is built" expander — the model explained on the same screen it is used, not one navigation away. |
| 4 | **Just the numbers** | The mandated escape hatch (N7). One tap turns off every band, every position word and the instruction, leaving raw readings with no verdict attached. Placed low, where the thumb is. |
| 5 | **Updated just now** | The brief's own table keeps this: "one line, minimal, cheapest block on the screen." `[CRIT §4.16]` |

**Above the fold on a 5.4" viewport:** the message, all four bars, the legend, and the
instruction sentence. Verified by measuring the live DOM at 375×812 — hero card bottom at
576px, instruction sentence top at 629px, fold at 675px.

---

## 3. Psychological principles used, and the specific mechanism

**Removing the failure state, not softening it.** Gentler Streak's band has no failure state
at all: below the band is *capacity*, and the docs literally say a low position means the
body "can handle a more intense workout if you choose." That inversion won a 2024 Apple
Design Award for Social Impact. `[N §2.2, §2.6]` This concept takes it to its end — there is
no zero, no grade, no "you missed", and rest is the recommended action on the default day.

**Mechanism, precisely:** a target produces a binary. A band produces a location. A location
has no moral value, so the affective loading has to be supplied by copy, and copy can be
written to be kind. That is why the position word ("under") and the consequence clause ("by
about an hour") are separated: the first is geometry, the second is meaning, and only the
second is written.

**F8 — never lead with a bad number.** Two sham-feedback experiments (Gavriloff n=63;
Draganich & Erdal n=164) show fabricated negative sleep feedback measurably degrades
cognition and increases fatigue by evening. Orthosomnia runs 3.0% strict to 14.0% lenient in
a general sample (n=523). `[CL §3.4, §3.5]` On this screen a short night produces
"Short night. You showed up." and a suggestion to keep the day easy. There is no number that
can be bad, because there is no number that is scored.

**F9 — no persuasion mechanics.** No streak of any kind, no loss framing, no variable
reward, no informational nudge copy, no deliberate incompleteness. Lally's own data says a
missed day costs 0.29 points on a 0-42 automaticity scale and fully recovers; nudging
collapses from d=0.43 to d=0.04 after publication-bias correction, with BF₀₁=33.84 against
information interventions specifically. `[PSY §3, §8, §12]` The button says "That works",
not "Commit".

**SDT.** Controlled regulation predicts *worse* mental health (ρ = .13 to .46); autonomy
support predicts better (ρ = .21 to .48). `[PSY §5]` The instruction is phrased as a fit
("A walk is plenty"), the confirm is an acknowledgement, and the escape hatch is one tap
away and named without shame.

**Fogg.** A returning user is already above the activation threshold, so the screen spends
itself on ability, not motivation — one pre-chosen action with zero decision cost, matching
Gentler Streak's Go Gentler and Headspace's Today's Meditation. `[PSY §1; N §2.3, §8.3]`

**Endowed progress, inverted.** For the day-3 user we do not show an empty 0-of-7. We show a
real reading inside a deliberately enormous band. An empty goal-shape beats an absent number;
a blank tile says the app is broken. `[PSY §8; P §7.4]`

---

## 4. UX principles applied

- **F11 — never a bare number.** Every value ships with its band (drawn), its position
  (one word, on the same line as the number), and its consequence (one clause underneath).
  Three comparisons, one visual element, zero facts to combine from elsewhere. `[UX §5, §11]`
- **F12 — exactly one reference range, and it is personal.** Comprehension of a result's
  relative location: standard range only 14.49% → goal range added 35.92% → **goal range only
  43.45%** (N=6,766, p<.001). Substituting beats adding. There is exactly one band per bar and
  it is built from the user's own history. No population norms anywhere. `[UX §11]`
- **F13 — harm anchor.** The resting-heart-rate bar reads "one morning only" on the default
  day, and the attention state adds "This is not an emergency. If it carries on, or you feel
  unwell, speak to a doctor." Adding a "many doctors are not concerned until here" style
  anchor significantly reduced perceived urgency and urgent contact intent (N=1,618, p<.001).
  `[UX §11]`
- **F14 — positional bars, and colour never encodes magnitude.** No pie, donut, gauge,
  treemap or 3D. The band tint is the *same colour at the same opacity on every bar
  regardless of position* — it identifies "your range", not "good". The marker is plain ink.
  Position is the only magnitude channel. `[UX §10, §11]`
- **F15 — one vocabulary.** Four names, used identically in the hero, the chart and the raw
  view: **Sleep · Steps · Bedtime · Resting heart rate**. One phrase for the reference:
  **your range**. No "readiness", "recovery", "strain", "stress", "brain health", "vitality",
  "concierge", "signal", "index". Verified: a regex over every copy string in the file matches
  no score/index/percentage vocabulary.
- **Layer cake, not F.** Short front-loaded heading, number beside it, interpretation
  directly under it, in every one of the four bars and in the Today card. `[UX §6]`
- **Two disclosure levels maximum.** Home → the inline expander. Nothing on this screen
  navigates except the tab bar. `[UX §4]`
- **Platform floors.** Body 17px, absolute smallest text 11px (chart axis labels only,
  measured). All tap targets ≥44px (measured: 0 under 44). Contrast ≥4.5:1 on every text
  token in both themes. `prefers-reduced-motion` honoured — markers place instantly.
- **5.4" first.** The top cluster was laid out at 375×812 and measured there, not scaled down
  from a large phone. Garmin's "the glance section is squished" is a breakpoint failure.
  `[W §6.8]` Verified no horizontal overflow at 320px.

**One deliberate deviation.** The brief says "never place meaning-critical content on the
right edge." The numeral is right-aligned in its row, paired with its left-aligned label.
The brief also permits "the number directly under or beside it", and the meaning-critical
channel here is the marker on the full-width track, not the numeral. Stacking the value under
the label costs ~96px and pushes the instruction below the fold — a worse trade. Called out
so it is a decision, not an oversight.

---

## 5. Which user problems it solves

| Problem | How |
|---|---|
| "The score doesn't match how I feel" — the #1 complaint across Whoop, Ultrahuman, Bevel and Athlytic communities `[W §7]` | There is no score to disagree with. Every number is a measurement the user can verify against their own memory of last night. |
| "It doesn't show its work" — Bevel's named trust cost `[W §5.8]` | The comparison is drawn, not asserted. The band is visible; the distance from it is the argument. |
| Three components giving three instructions `[CRIT §5]` | One. The bars describe; only the Today card instructs. |
| 28 numbers, one verdict `[CRIT §8]` | 7 numbers, and every one of them carries its comparison and a plain word. |
| A health warning at position 13, blurred `[CRIT §4.13, §4.17]` | Position 1, unblurred, with a harm anchor. Measured. |
| Score anxiety / orthosomnia `[CL §3.4]` | No score, no grade, no zero, no failure state, plus a one-tap way to turn even the words off. |
| The iPhone-only user with an empty hero — "the single biggest own-goal in this teardown" `[P §5.2]` | Same slot structure, four real bars from real iPhone-only signals, visibly wider bands, and a sentence saying why. No upsell, no empty ring, no silent substitution. |
| Cold start, universally unsolved `[W §10.7; P §7.4]` | Day 3 renders the identical structure with real same-day readings inside bands drawn at maximum width, and says so. |

---

## 6. Which metrics were given prominence, and why

| Metric | Unit | Why |
|---|---|---|
| **Sleep** | h:mm | Devices exceed 90% sensitivity for sleep vs wake. Clock time needs no interpretation. Compared against the personalised sleep need `SleepNeedCalculator` already computes — **fixes B6's hardcoded 7.5h**. `[CL §3.1; CAP B6]` |
| **Steps** | steps | The only wearable metric with umbrella-review behaviour-change evidence (+1,800 steps/day, ~1 kg); 7,000 vs 2,000 steps/day gives all-cause mortality HR 0.53. Survives iPhone-only and day 1. Band is personal, **not the hardcoded 10,000 of B7**. `[CL §10.2, §10.3; CAP B7]` |
| **Bedtime** | clock time | Sleep regularity is the strongest sleep finding of the last three years: UK Biobank n=60,977, all-cause mortality HR 0.70 top vs bottom SRI quintile, cardiometabolic HR 0.62 — a **stronger predictor than sleep duration**. It uses only bedtime and waketime, the parts wearables get right, and expresses as a behaviour rather than a score. It is computed inside `CircadianAnalyzer` today and surfaced nowhere. `[CL §3.3; CAP §9.3]` |
| **Resting heart rate** | bpm | The most reliable thing a consumer wearable measures: nocturnal MAE 0.98-1.78 bpm, CCC 0.86-0.98. Familiar unit, real population meaning. Flagged **only** at the ≥5 bpm / ≥10% sustained 3+ nights rule — which is exactly why 58 bpm against a 53-57 band reads "one morning only" and not an alert. `[CL §2, §2.3]` |

iPhone-only substitutes four signals `[CAP §7]` verifies the phone can produce alone: Steps,
Distance, Stairs, Walking pace. Same grammar, same slot, wider bands.

---

## 7. Which metrics were deliberately hidden or removed, and why

**Removed from Home entirely:**

- **Readiness / Recovery 0-100** — no manufacturer discloses weights, none is validated
  against clinical outcomes, and in D1 swimmers WHOOP's Recovery score was *not* associated
  with perceived recovery while its own raw HRV input *was*. The composite is worse than its
  inputs. `[CL §4.2, §4.3]`
- **Daily Health Score 0-100** — coverage shrinkage pulls sparse users toward a constant 75
  presented at full visual confidence (B4), and it is currently substituted silently under a
  "Readiness" label (B3). `[CAP B3, B4]`
- **Stress 0-100** — recall for psychological stress from wearable signals is 50.0%, a coin
  flip in red. `[CL §5.2]`
- **Strain 0-21** — a logarithmic scale rendered as equal steps, where a one-question
  subjective rating performs about as well (session-RPE r = 0.79-0.86 vs TRIMP). `[CL §6.1]`
- **Brain Health 0-100** — an invented composite with an unfamiliar name. Its best ingredient
  (circadian alignment) is promoted here as Bedtime.
- **Vitality Age / Pace of Aging** — age framing increases emotion and risk perception, makes
  risk perception *less accurate*, and has **no effect on lifestyle intentions or behaviour**
  (5 experiments n=5,514; 5 RCTs n=9,582). Laso's norm tables say themselves they are
  heuristic with no DOIs. `[CL §9.2, §9.3; CAP B11]`
- **Sleep stages** — κ 0.21-0.53, Apple Watch deep-sleep sensitivity 50.7%. `[CL §3.1]`
- **Data coverage card, activation progress, "patterns found: 12", streak milestone share,
  morning check-in, weekly review entry** — all score 0 on the five questions. The check-in
  in particular is written twice and read zero times. `[CRIT §4.8, §4.9, §4.10, §4.4, §4.15]`
- **AI / "CONCIERGE" entry point** — C9 is unambiguous: AI above the user's own number drew
  3,419 revert votes and a 39-item apology roadmap in 8 days. `[P §3.8]`
- **Sleep debt as an hours-owed ledger** — the hours are real but repayment is not 1:1 and
  the current 2.0h threshold fires for nearly everyone every day. It is expressed here as the
  sleep bar's position and the chart's visible downward drift, never as a debt. `[CL §3.2]`

**Demoted to the escape hatch only:** raw HRV in ms (Laso stores SDNN, not RMSSD, and must
never share an "HRV" label with it), and the 14-night sleep list. `[CL §1.2; CRIT §7]`

**Deliberately not shown anywhere:** VO2max, blood oxygen (B1 makes it dishonest today),
respiratory rate, weight, body fat, calories.

---

## 8. Expected impact on daily engagement, with the mechanism

**Sessions get shorter and slightly less frequent. That is the intended direction.**

Mechanism: this is Athlytic's D1 bet — a stated short-session budget, optimising for the
version of the screen you barely open. `[W §4.2, §4.3]` Four markers against four identical
bands is a sub-second read; there is no dense scroll to explore, no second score to
reconcile, and only three exits off the screen. Category benchmark is ~2.5 min/day and mobile
sessions average 72s; this screen is designed to be finished in under 10.

The one thing that should *increase* is the reopen after acting: the button state persists
("Noted. Rest counts."), so the screen remembers the day. There is no real-time recovery
score, so nothing manufactures a 3pm reopen — Ultrahuman is the only app that genuinely earns
one, and it pays for it with a store block in the same scroll. `[W §3.7]`

**Honest risk:** Whoop's dense scroll gets 83% DAU/MAU, roughly 3-10x category. A screen this
sparse will not produce that number, and should not be measured against it.

---

## 9. Expected impact on retention, with the mechanism

**Retention is where this concept spends everything it saves on engagement.**

The defensible constraint is attrition, not cognition: ~53% of mHealth apps are uninstalled
within 30 days, mean engagement in one large study lasted **4.1 days**, and the top stated
reason for abandonment is declining motivation (31.6%). `[UX §12]`

Three mechanisms:

1. **No failure state means no avoidance day.** Every compliance-based streak eventually
   teaches the user to stop opening the app on bad days — which are precisely the days the
   app has the most value to add. `[P §6.7]` A user who slept 6h 12m opens this screen and is
   met with "Short night. You showed up." There is no reason to hide.
2. **The removal is the feature.** A Bevel user wrote an App Store review specifically to
   praise the *absence*: "No calorie goals or you didn't hit your macro target or cyber
   guilting." In a category whose primary complaint is score anxiety, that is a moat.
   `[W §5.4, §5.7]`
3. **Day 1 and day 200 differ in band width, not in structure.** A user who joins on a phone
   and later buys a watch watches the bands narrow — the interface visibly rewards continuity
   without a streak. And trust is the actual constraint: 40% of tracker users are concerned
   about data privacy, rising to **60%** when they subscribe to a service that turns their
   data into a score. The act of scoring increases distrust. `[PSY §11]` This concept never
   scores.

---

## 10. The two hard problems

### 10a. "No emotion is not the safe answer" — Garmin desaturated and users noticed

Garmin's 2024 desaturation removed the only free emotional feedback the screen had `[W §6.4]`.
The failure was not that Garmin removed colour; it was that Garmin removed the *channel* and
put nothing in its place. This concept replaces it with three others:

1. **The message row is the emotional object.** It is 20px semibold, it is the first thing
   read, and it is written about the person rather than the performance: "Short night. You
   showed up." / "Everything landed inside your range." / "Something has repeated. Read this
   first." Gentler Streak's "Kudos for Taking Action" sits above the path for exactly this
   reason `[N §2.2]`. Acknowledgement is for showing up (T6), never for hitting a number.
2. **Motion carries the affect colour would have carried.** Every marker starts at the centre
   of its band and *settles* into position over 520ms on a spring curve, staggered 70ms apart,
   with a one-shot halo pulse. The screen arrives rather than appears. It re-animates only
   when the underlying reading actually changed — pressing a button or opening a section does
   not make the whole screen move again.
3. **The band changes shape as the relationship develops.** Narrow when the app knows you,
   wide when it does not, dashed on day 3. That is a visible, felt property of the interface
   that a colour ramp cannot express.

What is deliberately *not* used: colour as a verdict. The band tint is identical on all four
bars in all positions. Colour identifies "your range"; it never says "good".

### 10b. A positional bar with no grade still has to answer "is this good or bad"

It is answered three times inside the same visual element, and the question is re-asked into a
form that has a non-moral answer:

| Channel | Reads in | Example |
|---|---|---|
| **Marker distance from the band** | <1s, no text | far left of the band = well short |
| **One position word, on the number's line** | ~1s | `6h 12m` **under** |
| **One consequence clause** | ~3s | *by about an hour* |

And the reframing: the question the screen answers is **not** "was this good" but **"what can
today hold"**. That has an honest answer in every direction. Under the movement band is
capacity you have not spent. Under the sleep band is less in reserve, which is why the
instruction gets *lighter*, not harder. Above the heart-rate band for one morning is normal;
for three it is worth a look. None of those is a grade, and the expander says so in plain
words under "Below the band".

---

## 11. Honest drawbacks, and who this design fails

- **The power user who wants the number.** Someone tracking a training block wants Readiness
  72 and a delta. This screen refuses both, permanently. They will find it thin, and they are
  not wrong about what they want — they are wrong about what the number can support
  `[CL §4.2]`, which is not a satisfying thing to be told.
- **Insufficient activation energy.** Gentler Streak's own documented risk is "the *opposite*
  of anxiety" `[N §2.4]`. A screen with no failure state gives a user with low intrinsic
  motivation nothing to push against. Gamification survived withdrawal in a 1,062-patient
  cardiology RCT (+459.8 steps/day at 6-month follow-up); this concept forgoes that lever
  entirely. `[PSY §5]`
- **Four bars is more parsing than one number.** Athlytic-style single-number clarity is
  strictly faster. This concept trades ~1s of read time for the removal of the composite.
- **The band is silent about movement inside it.** A user drifting from the top of their sleep
  band to the bottom sees "inside" both weeks. The 14-day chart is the only place that drift
  is visible, and it is below the fold. This is Gentler Streak's exact documented weakness —
  "a dotted line inside a band tells you where you are but not what changed" `[N §2.9]` — and
  I did not fully solve it, because solving it means a delta, and a daily delta on these
  signals is banned by F1.
- **The band can enshrine a bad habit.** The steps, bedtime and heart-rate bands are built
  from the user's own recent behaviour. A user whose bedtime has drifted an hour later over
  six months will eventually be "inside" their range at 1:30am. Only the sleep band is
  anchored to a computed need rather than recent behaviour. Mitigated on screen by the chart
  and the "later all week" clause; not structurally solved.
- **Someone who genuinely needs alarm.** The attention state is the loudest thing this screen
  can be, and it is one amber rule, one icon and two sentences. That is correct for the 2-of-5
  / 2-consecutive-day gate `IllnessEarlyWarning` actually applies `[CAP §3c]` — but a user in
  real trouble will not be shouted at by this design.
- **A screen with no failure state cannot congratulate either.** "Everything landed inside
  your range" is the ceiling. There is no personal best, no celebration. Some users want one.

---

## 12. The five-questions scorecard

**Q1** what is happening inside my body · **Q2** is this good or bad · **Q3** why did this
happen · **Q4** what should I do next · **Q5** what happens if I follow it.

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Attention strip (conditional content, position 1) | ✔ | ✔ | ✔ | ◐ | · | **3.5** |
| The message | ◐ | ✔ | · | · | · | **1.5** |
| Sleep bar | ✔ | ✔ | ◐ | · | · | **2.5** |
| Steps bar | ✔ | ✔ | · | · | · | **2** |
| Bedtime bar | ✔ | ✔ | ◐ | · | · | **2.5** |
| Resting heart rate bar | ✔ | ✔ | ◐ | · | · | **2.5** |
| Today (the one instruction) | · | · | ✔ | ✔ | ◐ | **2.5** |
| Your last 14 days (chart) | ✔ | ✔ | ✔ | · | · | **3** |
| "How your range is built" (expander) | · | ◐ | ✔ | · | · | **1.5** |
| Just the numbers (escape hatch) | ✔ | · | · | · | · | **1** |
| Updated just now (footer) | · | · | · | · | · | **0** |

Two justifications for the low scorers, since the brief cuts anything scoring zero:

- **Just the numbers** scores 1 only, and does so on purpose. Its job is to *remove* the
  answers to Q2-Q5 for the fraction of users harmed by any interpreted screen. N7 names it as
  "the only mitigation the self-tracking harms literature actually offers." It is not a
  component that has to earn a slot on the five questions; it is the exit from them.
- **The footer** scores 0 and is kept because the brief's own component table keeps it:
  "Keep, one line, minimal. Cheapest block on the screen." `[CRIT §4.16]` Three words.

---

## 13. How each of the ten tensions was resolved

| # | Tension | Resolution taken |
|---|---|---|
| **T1** | Score-first or action-first | **State-first, where state is a position and not a grade.** The four bars come first; the single instruction sits under them. This is not "both at equal weight" — the bars describe and never instruct, the Today card instructs and shows no number. |
| **T2** | One hero number or a cluster of 3-6 | **Four positional bars sharing one grammar.** Not four independent numbers — one grammar, one band shape, one position vocabulary, all bands drawn in the same place so the four markers read as a single column. This is the Welltory failure case (three percentages that disagree) specifically avoided: the bars cannot disagree because none of them is a verdict about the whole body. |
| **T3** | A graded verdict or a range you sit inside | **A range you sit inside, no failure state, taken as far as it goes.** No score, no grade, no zero, no red. Below the band is capacity or reserve, never failure. Rest is the default recommended action. |
| **T4** | A borrowed unit or a native index | **Borrowed units only. There is no index anywhere in the file.** Hours and minutes, steps, a clock time, beats per minute — plus kilometres, flights and km/h in the iPhone-only state. Verified by regex over every copy string. |
| **T5** | Explanation inline, one tap down, or a paragraph | **Inline, one clause per bar**, never a paragraph, never above the number. Four clauses, 3-4 words each. The deeper model explanation lives in an inline expander that does not navigate. |
| **T6** | Celebration or calm | **Calm, with acknowledgement for showing up rather than for performance.** "Short night. You showed up." No streak, no badge, no confetti, no personal best. |
| **T7** | Density or scroll | **Sparse — 5 blocks, 7 numbers — but not empty.** Google Health's redesign produced "a huge block of empty space"; the answer is not whitespace but a card that is full of *structure* (four aligned bands) rather than full of numbers. |
| **T8** | Fixed slots or contextual morphing | **Fixed.** Identical slot order in all 27 data × day × screen combinations tested. Only content inside a slot varies: the message, the four bar readings, the attention strip's presence, the instruction. Nothing reorders, ever. |
| **T9** | Honest uncertainty or confident simplicity | **The band widens when confidence is lower. Uncertainty is geometric, and it is the only mechanism on the screen.** Half-width 16% at full watch data, 24% on a phone alone, 36% and dashed on day 3. No confidence percentage, no "3 of 5 signals", no certainty bar, no interval text. One mechanism where the current build ships four. |
| **T10** | An opinionated hierarchy or user pinning | **Opinionated.** Four signals, chosen for this product, in this order, for everyone. No pinning, no reordering, no "customise your home". An optional hero is not a hero (C7). |

---

## 14. Literal budget counts

Measured from the live DOM at 375×812, light theme, full watch data, "short night" —
the default morning. Fold taken conservatively at 675px.

| Budget | Limit | This concept | |
|---|---|---|---|
| Cards above the fold | ≤ 3 | **2** | ✅ |
| Total blocks | ≤ 7 | **5** | ✅ |
| Numbers on screen | ≤ 12 | **7** | ✅ |
| Numbers above the fold | ≤ 5 | **4** | ✅ |
| Tap targets | ≤ 8 | **8** | ✅ at the ceiling |
| Distinct exits from Home | ≤ 6 | **3** | ✅ |
| Words of copy above the fold | ≤ 20 | **44** | ❌ **exceeded by 24** |
| Reference ranges per number | exactly 1 | **1** | ✅ |
| Uncertainty mechanisms | 1 | **1** (band width) | ✅ |
| Disclosure levels below Home | ≤ 2 | **1** | ✅ |
| Tap targets under 44px | 0 | **0** | ✅ |
| Smallest text | ≥ 11px | **11px** (chart axis only) | ✅ |

**The 7 numbers:** `6h 12m` · `8,400` · `12:35 am` · `58 bpm` · `14` (in "Your last 14 days")
· `8h 05m` · `7h 15m` (the chart's two band edges). The four hero bars print **no band
endpoints at all** — the range is a shape, not a pair of numbers. That single decision is what
keeps four bars inside a 5-number above-fold budget.

**The 8 tap targets:** "That works" · "Show steps" · "How your range is built" ·
"Just the numbers" · 4 tab bar items. The dev toolbar is excluded per the prototype spec
("it must not be part of the design being judged").

---

## 15. Every budget exceeded, and why

### Words above the fold: 44 against a limit of 20

This is the only budget missed, and it is missed by a lot. The honest arithmetic:

```
message                              5 words   ("Short night. You showed up.")
4 bar labels                         6 words   (Sleep / Steps / Bedtime / Resting heart rate)
4 position words                     4 words   (under / inside / later / above)
4 consequence clauses               13 words   (3-4 words each)
legend                               2 words   ("your range")
section heading                      1 word    ("Today")
the one instruction                  7 words
its reason clause                    6 words
                                    ---------
                                    44 words
```

**Why it cannot be fixed inside this concept.** The mandated T2 resolution is three to four
positional bars, and the mandated T5 resolution is one explanatory clause per bar. Four bars
each needing a name, a plain-word position (required by N2, because ~1 in 3 users cannot read
the graph) and a clause costs **23 words before a single word of message, heading or
instruction is written**. Adding the ≤12-word instruction the 1-3s window requires takes any
honest version past 30.

**What I would cut, in order, if forced closer:**

1. The instruction's reason clause (−6 → 38). It restates the sleep bar's clause one card
   below it; the bars already carry the 3-5s "why".
2. Drop from four bars to three (−7 → 31). Costs the resting-heart-rate harm anchor, which is
   the screen's best demonstration of F13 and of the N3 "3+ consecutive nights" rule.
3. Drop the clause on bars that are *inside* the band (−3 → 28), on the rule that a reading
   inside your own range has nothing to explain. This is arguably a better rule than the one
   shipped, and it would make the "rested" day almost wordless.

**The floor for any four-bar band screen with N2-compliant plain-word verdicts is ~29 words.**
The 20-word budget appears to be calibrated against a single-hero-number concept. That is a
real finding about the budget, not an excuse: a concept that hits 20 words above the fold
cannot also put four inline-explained positional bars there.

### Near-misses worth flagging

- **Tap targets: 8 of 8.** At the ceiling with nothing to spare. The chart's metric switch is
  a single cycling button rather than a four-segment control specifically to stay inside it.
- **Smallest text: 11px**, used only for the chart's two band-edge labels and the two x-axis
  captions. That is the absolute HIG minimum, not a comfortable choice.
- The instruction's reason clause sits at ~665px, i.e. within ~10px of the fold on a 5.4"
  device. On a smaller device it would drop below.

---

## 16. What was verified, and how

Rendered in headless Chromium at 375×812 (5.4" class), 320×700, and 1100×900 desktop.

- **JS parses clean** (`node --check`), **zero page errors and zero console errors** across
  every state.
- **All 27 combinations** of data state × day state × screen state render non-empty. No blank
  renders.
- **Every `data-act` value has a handler**, and every handler has a `data-act` — no dead
  controls, no dead branches. No `alert()`, no `href`, no external requests, no CDN.
- **Interaction round-trips:** the action button toggles and toggles back; the chart cycle
  wraps through all four metrics back to the first; the expander opens and closes; the escape
  hatch removes every bar, every position word and the instruction, and restores them.
- **Data integrity:** an assertion pass confirms the chart's last plotted point equals the
  hero bar's value for every metric in every state — no number on this screen can contradict
  another. Position words are derived from value-vs-band at render time, never hard-coded.
- **Geometry:** every marker stays inside 7-93% of its track at all three band widths, for
  in-range, out-of-range and absurd inputs.
- **Warning placement:** measured at position 1 of block 1, `filter: none`, `opacity: 1`.
- **No horizontal overflow at 320px.**
