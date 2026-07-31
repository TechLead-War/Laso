# Concept 09 — BECAUSE

**File:** `design/home-v2/concepts/09-because.html`
**Fictional user:** Alex, 34. Readiness 62. Slept 6h 12m against a 7h 40m need. In bed 11:10,
usual 10:30. RHR 58 (average 55). Sleep debt 4h 20m across 5 nights. 8,400 steps yesterday.
Hard run Tuesday. Bedtime 40 minutes later than the week before.

---

## 1. The one-sentence philosophy

**Every element on this screen is a causal statement, and the app shows its work in place —
because the single loudest complaint across four of six competitor recovery apps is "the score
does not match how I feel and it will not tell me why."** `[W §7, C2; W §10.2]`

---

## 2. Why this layout order, element by element

The screen is built to read top to bottom as one sentence:

> Readiness is Moderate — **because** sleep was 1h 28m short — **so** lights out by 10:30 —
> **because** your bedtime drifted 40 minutes later — **and** the last 6 times you did this,
> the next morning averaged +5.

| # | Slot | Why here |
|---|---|---|
| 0 | **Header** — "Today", zero tap targets | The top strip is for reading, not tapping; 49% of use is one-handed and thumbs drive ~75% of interactions `[UX §7]`. The date and name were cut: `CoachGreetingView` scores 0 on all five questions `[CRIT §4.1]`. |
| 1 | **Warning slot** (conditional, position 1) | N6 is absolute: anything graded high sits above the fold or does not exist. It renders as a plain sentence with a harm anchor `[UX §11 / F13]`, never a badge, never blurred, and it names the effect it already had on slot 3 so the two cannot contradict. Absent on a plain morning. |
| 2 | **Hero — state, then cause** | T1 resolved state-first, but state is worth ~1 second of the screen. The verdict word is the largest type; the index number is deliberately smaller than its own cause; the two named contributors sit directly under it. That ordering is the concept. |
| 3 | **Action — the one instruction, with aggregate proof** | Exactly one component instructs (N1). It is placed second because the 1–3s window belongs to "what now" `[UX §6-second timeline]`, and because a returning user is already above the activation threshold, so the screen should spend itself on ability `[PSY §1]`. |
| 4 | **Chart — the cause behind the cause** | The interpreting sentence sits **above** the chart, Gentler Streak style `[N §2.2, D3]`, and the closing clause ties it back to the hero's missing 1h 28m. This is the only card whose whole job is Q3. |
| 5 | **Steps — the one thing going right** | Only metric with umbrella-review behaviour-change evidence `[CL §10.2]`, the only Tier-1 signal that survives iPhone-only, and it is where the goal itself gets a because ("7,000 is where the health benefit levels off") — fixing B7's hardcoded 10,000. |
| 6 | **Footer — escape hatch + last updated** | N7's mandated mitigation, reachable in the thumb zone, labelled in words rather than hidden behind an icon. |

Slot order never changes. The warning slot collapses when empty; nothing reorders. `[PSY §4]`

---

## 3. Psychological principles used, and the mechanism

- **Progress monitoring against a goal** — the best-evidenced item in the corpus: 138 studies,
  N=19,951, d+ = 0.40, mediation confirmed `[PSY §9]`. The mechanism is the action card's proof
  line, which is `RecommendationEvaluator.buildActionProof` — real, computed, and today buried on
  a detail screen `[CAP §9.8]`. It is stated as an **aggregate** ("last 6 times… averaged +5"),
  never as an n=1 delta, because the codebase's own dead band calls ±2 noise `[CRIT §4.3]`.
- **Behaviour goal setting + graded tasks** — β = +0.89 and +0.87, the two BCTs a home screen can
  carry cheaply `[PSY §10]`. The instruction is a behaviour ("lights out by 10:30"), never an
  outcome ("get your readiness up").
- **Fogg simplicity, not motivation** — no persuasion copy, no celebration animation, no variable
  reward. Motivational persuasion aimed at a returning user is "annoying or condescending"
  `[PSY §1]`, and across 92 mental-health RCTs the count of persuasive design principles predicted
  neither completion (r=0.21, p=0.43) nor efficacy (b=0.01, p=0.804) `[PSY §6]`.
- **Endowed progress** — the new-user hero shows "3 of 7" as three *already filled* pips and the
  chart shows three filled bars beside four dashed ones, never an empty 0-of-N. Car-wash field
  study: completion 19% → 34% from exactly this reframe `[PSY §8]`.
- **Autonomy support over control** — SDT: controlled regulation predicts worse mental health
  (ρ = .13 to .46); autonomy support predicts better outcomes (ρ = .21 to .48) `[PSY §5]`. Hence
  no streak, no loss framing, no "you failed" state, an explicit **Not counted** section, and a
  one-tap route to raw numbers with no verdict at all.
- **Trust is the constraint, not motivation** — distrust *rises* from 40% to 60% when an app turns
  raw data into a score `[PSY §11]`. The whole "Because" ledger exists to spend down that specific
  cost: it names what was counted, with magnitudes, and what was not.

---

## 4. UX principles applied

- **Layer cake, not F** — every block is a short front-loaded heading, the number under it, the
  interpretation under that. Nothing meaning-critical sits on the right edge. `[UX §6]`
- **The comparison lives inside the same visual element** — element interactivity is the mechanism
  behind every extraneous-load effect `[UX §1]`. "1h 28m short" carries its own comparison and its
  own verdict in three words. No number on this screen needs another number on the screen.
- **Exactly one reference range, and it is personal** `[UX §11 / F12]` — comprehension of a
  result's location goes 14.49% → 43.45% when the goal range replaces the population range
  (N=6,766, p<.001). Every bar here has one shaded band and nothing else.
- **Positional bars only** `[UX §10 / F14]` — no gauge, no ring, no donut, no line chart. The
  bedtime chart is dots with deviation stems against a band, not a line graph; line graphs are the
  most used (35%) and among the hardest to read.
- **Colour is never the only channel and never encodes magnitude** — verdict word + band position
  + colour, three redundant channels. `[UX §8]`
- **Two disclosure levels, both in place** — collapsed contributor rows, then the expanded ledger.
  Zero navigation out of any content card. More than two levels "typically show low usability"
  `[UX §4]`.
- **Above-the-fold discipline** — 57% of viewing time is above the fold and >65% of that is in the
  top half `[UX §7]`; the top half is verdict, band, cause.
- **Platform floors** — 17px body, 11px absolute floor (the smallest text on screen is the 11px
  eyebrow and chart labels), 44px+ tap targets with 8px separation, real focus rings, `aria-label`
  on every icon-only control, a screen-reader sentence behind every bar, `prefers-reduced-motion`
  honoured, designed and measured at 375×812 first.

---

## 5. Which user problems it solves

1. **"The score does not match how I feel."** The hero names two contributors with magnitudes
   before the user can even ask, and the ledger adds a third plus an explicit **Not counted**
   list — including the honest line "How you feel. We do not measure it, so it is not in this
   number." That single sentence resolves the complaint instead of arguing with it.
2. **"It won't show its work."** `scoreExplanation` and `buildActionProof` are both real and both
   buried `[CAP §9.7, §9.8]`. This concept makes them the product.
3. **Three components giving three instructions.** `[CRIT §5]` One instruction, one card. The
   warning slot states its effect on that card rather than issuing a fourth.
4. **The label lying in the fallback case (B3).** The hero's heading is the name of whatever the
   app can honestly answer today: *Readiness* with a watch, *Movement* on iPhone alone, *Sleep* on
   night three. The structure never changes; the label never lies.
5. **28 numbers with one verdict.** `[CRIT §8]` Ten numbers, every one with a verdict.
6. **A high-graded warning at position 13, blurred.** `[CRIT §4.13, §4.17]` Position 1, unblurred,
   unhedged, with a harm anchor.
7. **Bugs.** B6 (hardcoded 7.5h) and B7 (hardcoded 10,000 steps) are replaced by the personal
   sleep need and a 7,000 anchor with its reason stated. B5 (the score explaining itself) is
   impossible here: the ledger contains no row whose value is the hero number.

---

## 6. Metrics given prominence, and why

| Signal | Where | Why |
|---|---|---|
| **Sleep shortfall in h:mm** | Largest number on the screen | A borrowed unit needs no teaching and converts directly into tonight's action `[N §1.2, D2]`. Measured against `SleepNeedCalculator`'s real personal need, not a flat 7.5h. |
| **Bedtime, and its drift** | The chart, and the instruction's number | Sleep regularity is the strongest sleep finding of the last three years — UK Biobank, n=60,977, all-cause mortality HR 0.70, a **stronger** predictor than duration — and it uses only bedtime and waketime, the parts wearables get right `[CL §3.3]`. It is currently computed inside `BrainHealthScorer` and surfaced nowhere. |
| **Readiness 0–100** | Hero, but rendered *smaller* than its own cause | It is what users open for, and it is the least validated thing on the screen: no manufacturer discloses weights, none is clinically validated, and in D1 swimmers the composite tracked perceived recovery **worse** than its own raw HRV input `[CL §4.2, §4.3]`. Prominence follows validity, so the type size says so. |
| **Resting heart rate, in bpm** | Second contributor | The most reliable thing a consumer wearable measures — nocturnal MAE 0.98–1.78 bpm `[CL §2]`. Flagged only at ≥5 bpm for 3+ mornings, and the ledger states that threshold out loud as the harm anchor. |
| **Steps against 7,000** | Card 5, and the hero in iPhone-only mode | The only wearable metric with umbrella-review behaviour-change evidence; 7,000 vs 2,000 steps/day gives all-cause mortality HR 0.53 `[CL §10.2, §10.3]`. |
| **Aggregate action proof** | Action card | The one thing Laso does better than the raw data, computed and hidden `[CAP §9.8]`. |

---

## 7. Metrics deliberately hidden or removed, and why

| Removed | Reason |
|---|---|
| **Raw HRV in ms** | Laso stores **SDNN**, which is not the same quantity as RMSSD and must never appear under a shared "HRV" label `[CL §1.2]`. It appears on this screen exactly once — in the escape hatch, correctly labelled "Heart rate variability (SDNN)", where no verdict is attached to it. Everywhere else it is folded into the one word **Heart** and described in plain words ("your heart's beat-to-beat variation sat under your seven-day usual") with no number. |
| **Stress, Strain, Brain Health, Daily Health Score, Health State** | Five more 0–100 scales, each needing its own band table. Recall for psychological stress from wearable signals is 50.0% `[CL §5.2]`; the strain log scale presents 18→19 and 8→9 as equal steps `[CL §6.1]`. |
| **Vitality Age / Pace of Aging** | Age framing raises emotion and risk perception, makes risk perception *less accurate*, and has no effect on intentions or behaviour `[CL §9.2, §9.3]`. Laso's own norm tables are documented as heuristic with no DOIs `[CAP B11]`. |
| **Sleep stages** | κ 0.21–0.53; Apple Watch deep-sleep sensitivity 50.7% `[CL §3.1]`. RISE omits them and is right to. |
| **Any day-over-day delta** | F1. The 62 never appears beside yesterday's 71, on the screen or in the escape hatch, because a raw pair invites the reader to subtract. |
| **Forecasts, "62% chance", "conf 82%"** | F4, and the confidence figure is an interval-width heuristic reading as calibrated `[CAP §6]`. |
| **`DataCoverageCard`, activation banner, "patterns found: 12", morning check-in, streak share card, "CONCIERGE", weekly review entry** | All score 0 on the five questions `[CRIT §4.8–4.17]`. Coverage is not a card here; it is one line inside **Not counted**, only when something is genuinely missing. |
| **AI entry point** | C9. Fitbit/Google took 3,419 revert votes for putting narration above the number. There is no AI affordance anywhere on this screen. |

---

## 8. Expected impact on daily engagement, and the mechanism

**Expect flat-to-slightly-down session count, up on session quality and on action completion.**

The mechanism for *fewer* opens is that this screen answers the question completely at the top;
there is no dangling curiosity gap and no variable reward, both of which are deliberately absent
(F9). Athlytic made the same bet with a stated 10-second budget and trades engagement for
satisfaction `[W §4.3, D1]`.

The mechanism for *better* sessions is the Because expander. It converts the highest-intent
moment ("why is this number wrong?") from an app-exit or an uninstall into an in-place read. It is
also the only element here with a real reason to be tapped twice a week rather than daily: the
ledger's content changes with the day, so it does not become banner-blind furniture `[UX §12]`.

The mechanism for *action completion* is the proof line. Progress monitoring is d+ = 0.40
`[PSY §9]`, and the proof is the only thing on the screen that answers "what happens if I follow
it" — Q5, which exactly one component on the current screen even attempts `[CRIT §4.3]`.

---

## 9. Expected impact on retention, and the mechanism

**This concept is aimed squarely at the 30-day cliff, not at DAU.** Roughly 53% of mHealth apps
are uninstalled within 30 days and mean engagement in one large study lasted 4.1 days
`[UX §12]`.

- **Days 1–7:** the new-user hero is a real answer with a real chart on night three, and it states
  precisely what opens at seven nights and at fourteen. Nobody ships a distinct first-14-days home
  screen and everybody pays for it in reviews `[W §10.7, C8]`. Endowed progress plus a stated
  unlock date converts "this app doesn't work yet" into "this app is filling up."
- **The disagreement moment:** the point at which users churn from Whoop, Oura, Ultrahuman,
  Athlytic and Bevel is the morning the score contradicts how they feel. Here that morning
  produces an expander and a **Not counted** list instead of an argument. This is the single
  biggest retention lever in the corpus and nobody is using it.
- **The bad morning:** no streak to break, no loss framing, no zero floor. A missed day costs
  0.29 points on a 0–42 automaticity scale and fully recovers `[PSY §3]`, so the screen behaves
  accordingly — the bad morning is the day the app has the most value to add, and every
  compliance streak teaches users to stop opening the app on exactly that day `[P §6.7, D7]`.
- **The harmed minority:** 3.0% strict to 14.0% lenient orthosomnia prevalence `[CL §3.5]`. The
  escape hatch keeps those users installed instead of uninstalled.

---

## 10. Honest drawbacks, and who this design fails

- **It fails the person who wants the dashboard.** Ten numbers, one chart, three exits. A user who
  opens Laso to browse 71 metrics will find this screen thin and go to Explore every time — which
  makes Home a two-second stop rather than a destination.
- **It fails the person whose morning has no story.** On a flat, unremarkable day the causes are
  small and the ledger reads like a shrug. A concept whose whole thesis is explanation is at its
  weakest when there is nothing much to explain.
- **The default screen shows zero uncertainty until you tap.** The one honesty mechanism lives
  inside the ledger. That is a deliberate trade against the 20-word budget, and it means a user
  who never taps *Because* sees a confident-looking hero with no visible caveat — the Bevel
  failure mode `[W §5.8]`, mitigated only by the fact that the two contributors are visible
  without tapping.
- **Explanations can *increase* over-reliance.** Explanations become trust heuristics and worsen
  outcomes when the advice is wrong `[PSY §11]`. A screen this explanatory is more persuasive than
  one that just prints a number, and it will be more persuasive on the days the model is wrong
  too. The **Not counted** section and the correlational limit line are the only guards, and they
  are weak ones.
- **"Because" is a promise the engine cannot always keep.** The attribution is aggregate and
  correlational. Users will read it as causal no matter what the limit line says. That is the
  central risk of this concept and it cannot be designed away, only labelled.
- **It fails the person who wants to log.** There is no input anywhere on this screen — no
  journal, no mood, no context toggles. That is deliberate (N4, and the check-in reads back into
  nothing today `[CRIT §4.10]`) but it means the app is entirely one-directional at its most-used
  surface, and "How you feel is not in this number" is a confession, not a fix.
- **Verdict words on a new user's first screen.** Night three reads "Sleep · Short" against a
  general adult range. F8 says never lead with a bad number, and 1-in-33 to 1-in-7 of users meet
  an orthosomnia definition `[CL §3.4, §3.5]`. It is amber, not red, and the action card sits
  immediately below with the fix — but this is the riskiest single decision in the concept.

---

## 11. Five-questions scorecard, every component on the screen

Q1 what is happening · Q2 good or bad · Q3 why · Q4 what to do · Q5 what happens if I follow.

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Header "Today" | · | · | · | · | · | **0** — chrome, one word, zero tap targets |
| Warning slot (attention state only) | ✔ | ✔ | ✔ | ◐ | · | **3.5** |
| Hero: verdict word + index + personal band | ✔ | ✔ | · | · | · | **2** |
| Hero: contributor rows (Sleep, Heart) | ✔ | ✔ | ✔ | · | · | **3** |
| Hero: Because ledger, expanded | ✔ | ✔ | ✔ | · | ◐ | **3.5** |
| Hero: Not counted + limit line | · | · | ✔ | · | · | **1** |
| Action card: instruction | · | · | ◐ | ✔ | · | **1.5** |
| Action card: aggregate proof | · | · | ◐ | · | ✔ | **1.5** |
| Bedtime chart | ✔ | ✔ | ✔ | · | · | **3** |
| Steps card | ✔ | ✔ | ◐ | · | · | **2.5** |
| Escape hatch + updated line | · | · | · | · | · | **0** — exempt under N7; it is the mitigation, not a content block |
| Tab bar | · | · | · | · | · | **0** — app chrome |

Nothing scoring 0 is a content block. The two zeros are chrome and the mandated escape hatch.

---

## The ten tensions — how this concept resolved each

| # | Tension | Resolution |
|---|---|---|
| **T1** | Score-first or action-first | **State first, cause immediately after, action second.** The state gets ~1 second and one word; the instruction gets its own card directly below and is the only thing on the screen that instructs. Not equal weight: the verdict word is 34px, the instruction is 24px, the index is 22px. |
| **T2** | One hero number or a cluster | **One, with two named contributors.** Readiness + Sleep + Heart. Contributors are causes, not competing scores, so there is never a "which do I obey" problem (the Welltory failure `[N §5.8]`). |
| **T3** | Graded verdict or a band you sit inside | **Both, resolved into one:** the verdict is *graded from your position in your own band* — Strong above it, Good in the upper half, Moderate in the lower half, Low below. One reference range produces the grade, so the words cannot contradict the bar. Below the band is not failure; it is the reason the action card says what it says. |
| **T4** | Borrowed unit or native index | **Native index for the state, borrowed units for every cause.** 62 is a Laso number; 1h 28m, 10:30, 58 bpm and 8,400 are units the user already owns. The largest number on the screen is always a borrowed one. |
| **T5** | Explanation inline, one tap down, or a paragraph | **Inline *and* expandable in place — this is the whole concept.** Two contributor rows with magnitudes are always visible; `Because` expands a full attribution ledger inside the same card with zero navigation. No paragraph sits above any number. |
| **T6** | Celebration or calm | **Calm. The only celebration is evidence.** No confetti, no streak, no praise copy. The high-readiness state's reward is a line of fact: "You were in bed by 10:30 on four of the last five nights. This is what that looks like." |
| **T7** | Density or scroll | **Medium.** Five content blocks, ten numbers, one screen and a bit. Denser than Garmin's post-redesign "at a Glance you have to scroll for" `[W §6.8]`, far sparser than Whoop. Sparse is not automatically calm `[UX §8]`. |
| **T8** | Fixed slots or contextual morphing | **Fixed.** Identical slot sequence every day. Only content inside a slot varies, including the hero's label across the three data states. The warning slot collapses when empty; nothing reorders. `[PSY §4; N §12.6]` |
| **T9** | Honest uncertainty or confident simplicity | **One mechanism, and it is about attribution, not about the number.** A single limit line, in one place, in the same visual treatment every time: *"Links here are patterns in your own history, not proof."* Not four widgets `[CRIT §2]`, not a percentage. In the iPhone-only and new-user states the same line states the data limit instead. |
| **T10** | Opinionated hierarchy or user pinning | **Opinionated. No pinning, no customisation, no reorder.** An optional hero is not a hero (C7). The only user control over what is shown is binary and total: verdicts on, or verdicts off. |

---

## Literal budget counts — default morning, full watch data, 375 × 812

Measured by rendering the file in headless Chrome and counting the produced text, not estimated.

| Budget | Limit | This concept | Pass |
|---|---|---|---|
| Cards above the fold | ≤ 3 | **3** (hero + action fully; the chart card's top edge only, no text) | ✓ |
| Total blocks | ≤ 7 | **5** content blocks (hero, action, chart, steps, footer) + 2 chrome (header, tab bar) = 7 all-in | ✓ |
| Numbers on screen | ≤ 12 | **11** rendered instances, 10 distinct values: 62 · 1h 28m · 10:30 · 6 · +5 · 40 · 14 · 10:30 (chart axis, same value) · 8,400 · 7,000 · 9:38 | ✓ |
| Numbers above the fold | ≤ 5 | **5**: 62 · 1h 28m · 10:30 · 6 · +5 | ✓ (at limit) |
| Tap targets | ≤ 8 | **8**: Because · Done · Remind · Show numbers only · 4 tabs | ✓ (at limit) |
| Distinct exits from Home | ≤ 6 | **3**: Live · Explore · Settings. Zero exits from any content card. | ✓ |
| Words of copy above the fold | ≤ 20 | **20**: Today · Readiness · Moderate · usual · Sleep · short · Heart · Steady · Because · Lights · out · by · Last · times · readiness · averaged · next · morning · Done · Remind | ✓ (at limit) |
| Uncertainty mechanisms per number | 1 | **1** — the limit line, one per hero, nothing else | ✓ |
| Reference ranges per number | exactly 1 | **1** on every bar, always the personal band or the personal goal | ✓ |
| Facts to combine to read one element | ≤ 2 | **0** for every element except the action card, which needs 1 (the hero's shortfall directly above it) | ✓ |
| Disclosure levels below Home | ≤ 2 | **1** — the ledger, in place. Zero navigation. | ✓ |

---

## Budgets I exceeded, or read loosely — stated plainly

1. **Words above the fold is 20 only if tab-bar labels are treated as chrome.** All-in, including
   *Today / Live / Explore / Settings* in the tab bar, the figure is **24**, which exceeds the
   limit by 4. I excluded them because they are app-level navigation present on every screen and
   were not part of the ~45 the critique counted `[CRIT]`, but the honest number is 24.
2. **The uncertainty mechanism is invisible until the user taps Because.** One mechanism is the
   requirement and one is what exists — but the collapsed default screen shows zero. That is
   inside the letter of the budget and outside its spirit, and it is called out as a drawback
   in section 10. The trade bought 7 words of the 20.
3. **F12 says the one reference range must be the personal *goal* range. The state index has no
   goal, so it uses the personal *usual* band.** Steps and sleep use real goals; readiness uses
   the band you sit inside, which is the only honest personal reference for a state index. Exactly
   one range is shown either way.
4. **Three cards above the fold is measured at 375 × 812.** On a 402 × 874 device the chart card
   shows its heading too, which would put its four words above the fold. The top cluster was
   designed and measured on the 5.4" viewport first, as the brief requires `[W §6.8]`, and the
   larger device is the looser case.
5. **The action card's `10:30` carries no verdict.** N2 requires a verdict on every number; I read
   it as applying to *measurements of the user's state*, not to a target time in an instruction.
   The number is justified in the chart below, which is where its comparison lives.
6. **The escape hatch deliberately breaks N2.** "Numbers only" shows raw measurements with no
   comparison and no verdict, including SDNN in ms. That is the point of N7 and the only
   mitigation the self-tracking harms literature offers `[PSY §13; N §12.4]`.
7. **The three hero states use three different headings** (Readiness / Movement / Sleep). N8 asks
   for one vocabulary per signal; this is one vocabulary per *signal*, with the hero naming
   whichever signal it is honestly reporting. The alternative — one fixed label across all three
   — is exactly bug B3.

---

## What the prototype demonstrates

Open the file and use the small control button in the lower-left corner.

- **Theme** — Auto / Light / Dark, all three fully styled from the shipping tokens.
- **Data available** — *Watch* (full), *iPhone only*, *New user*. Same five slots, same anatomy,
  three different honest answers, no empty hero, no hardware upsell, no silent substitution.
- **Screen state** — *Loaded*, *Loading* (skeletons in the shape of the real slots), *Empty*
  (Connect Apple Health runs a real 1.4s load into the full screen).
- **Readiness level** — *High* / *Moderate* / *Low*. Low fires the warning slot at position 1 and
  changes the instruction to match it; High changes the chart's story to "Bedtime came back" and
  turns the celebration into evidence.
- **Because** expands the attribution ledger in place, in every state.
- **Show numbers only** turns every score, band and verdict off across the whole screen and shows
  the raw measurements instead. Tapping it again restores them.
