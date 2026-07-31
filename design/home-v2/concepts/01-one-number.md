# Concept 01 — The One Number

**File:** `design/home-v2/concepts/01-one-number.html`
**Fictional user:** Alex, 34. Readiness 62 today. Slept 6h 12m against a 7h 40m need.
Sleep shortfall 4h 20m over 5 nights. Resting heart rate 58 (usual 53–57). HRV 48 ms
(usual band). Hard run Monday. Bedtime drifting 40 min later across the week.

---

## 1. The one-sentence philosophy

**The screen answers one question with one number, one sentence and one cause, and then
it ends — because the design goal is that the user closes the app satisfied in five
seconds, not that they stay.**

---

## 2. Why this layout order, element by element

The screen has **two slots and a footer**. That is the whole product surface.

| # | Element | Why it is here, and why it is here *in this order* |
|---|---|---|
| 0 | **Header: one icon button, right, nothing else** | `CoachGreetingView` scored **0 of 5** on the questions scorecard and renders above the empty state, so a user with no data is greeted by name while being told the app knows nothing `[CRIT §4.1]`. It is deleted, not restyled. What survives in the header is the single most important control the harms literature actually recommends — the switch that turns scores off `[PSY §13; N §12.4]`. It sits top-right because it is a mode control, not content, and content must not compete with it. |
| 1a | **Label, then number, then bar** — in that vertical order | Layer-cake scanning: short front-loaded heading, number directly under it, interpretation under that `[UX §6]`. "Readiness" front-loads and does not begin with "Your". The number sits in the **top third** of the viewport because >65% of above-fold viewing time lands in the top half `[UX §7]`. |
| 1b | **The positional bar, immediately under the number** | F14: a positional bar is the default representation of one value; pie, donut, **gauge** and 3D are banned, and the current hero is a ring `[UX §10, §11]`. The bar carries the 0–1s job: band position + colour + shape, **no reading, no number** `[P §2.7]`. Exactly one reference range is drawn, and it is the personal one — substituting the personal range for a population range moved comprehension of "where does this sit" from **14.49% to 43.45%**, N=6,766 `[UX §11]`. |
| 1c | **Instruction — one sentence, ≤ 12 words** | 1–3s window `[§6 timeline]`. It is the **only** instruction on the screen (N1). Eight Sleep put a paragraph here and got "I don't know who thought anyone wanted to read that with their eyes half open" `[N §4.9]`. |
| 1d | **Cause — one clause, one cause, with its magnitude** | 3–5s window. "Last night was 1h 28m under usual." This is the **C2 open lane**: six well-funded competitors all ship a score with no reason, and all six are complained at for exactly that `[W §7, §10.2]`. It sits *under* the instruction because what to do beats why on a 72-second mobile session `[UX §7]`. |
| 1e | **Basis line + chevron, at the bottom hairline** | The single uncertainty mechanism (T9) and the single door to everything else. It is 12px tertiary and at the bottom because it must be present and must not compete. |
| 1f | **Expander: three contributor rows + one note** | The Why rows were rated **the best idea on the current screen** (2 of 5) `[CRIT §4.6c]`. They stay, but one tap down, so the fold stays at one number. |
| 2 | **"Last 7 days" — the one thing below the fold** | Same visual grammar as the hero bar, rotated 90°, so there is nothing new to learn. It is the honest 7-day window that F1/N3 demand instead of a day-over-day delta `[CL §1.5, §E]`. It is deliberately the *last* content block: below it the screen ends. |
| 3 | **Footer, one line** | "Cheapest block on the screen" `[CRIT §4.16]`. It also carries the date, which is why the date does not spend words above the fold. |

**The hero is sized in JS to fill the fold exactly, leaving 28px of the second card's
rounded top edge visible.** That 28px is the entire scroll affordance, and it costs zero
words. It is also the proof that the sparseness is engineered, not lazy: the hero is not
"a small card with space around it", it is a **full-viewport composition** with three
anchored zones (read / act / verify) and two calculated gaps between them.

---

## 3. Psychological principles used, and the specific mechanism

- **Simplicity as ability, not motivation (Fogg).** A returning user is already above the
  activation threshold, so motivational persuasion "would either be annoying or
  condescending"; the screen should spend itself on removing brain cycles `[PSY §1]`.
  Mechanism: the number of decisions on this Home screen is **zero**. There is one
  instruction, already chosen, with no alternatives offered — the C5 pattern that
  Headspace, Calm and Gentler Streak all converged on independently `[N §8.3, §9.3, §2.3]`.
- **Evaluability (Hsee).** An attribute that is hard to judge in isolation carries almost
  no weight until a comparison is present `[UX §5]`. Mechanism: the comparison is not on
  another card, it is *inside the same visual element* — the marker and the "usual" zone
  are the same object. Element interactivity, the mechanism behind every extraneous-load
  effect, is driven to **0 facts to combine** `[UX §1]`.
- **Never lead with a bad number (F8).** Two controlled sham-feedback experiments show
  fabricated negative sleep feedback measurably degraded alertness and cognition
  (Gavriloff n=63; Draganich & Erdal n=164), and 3.0–14.0% of a general sample already
  meets an orthosomnia definition `[CL §3.4, §3.5]`. Mechanism: **the bottom band is one
  undifferentiated block.** At 38 and at 12 the screen renders the same word, the same
  colour and the same sentence, and the expander says so in plain English. There is no
  gradient of failure to fall down.
- **No compliance mechanics (F9).** Lally: a missed day costs **0.29 points on a 0–42
  automaticity scale**, is not significant, and fully recovers `[PSY §3, §8]`. Mechanism:
  there is no streak, no counter, no "days in a row", no progress ring toward a weekly
  target, and no loss framing anywhere in the copy. Nothing on this screen can be broken.
- **Autonomy support (SDT).** Controlled regulation predicts *worse* mental health
  (ρ = .13 to .46); autonomy support predicts better (ρ = .21 to .48) `[PSY §5]`.
  Mechanism: the escape hatch is a **permanent, top-level, one-tap control**, not a
  buried setting. The user can switch the product's opinion off and keep the data.
- **Seamful design (clinical HCI).** Expose the limitation rather than hide it `[CL §13]`.
  Mechanism: one line, always in the same place — "From sleep and heart rate." — which in
  the iPhone-only state reads "From steps and walking only." and on day one reads "Your
  own usual range appears after seven days."
- **Attrition, not cognition, is the justification for the sparseness.** 53% of mHealth
  apps are uninstalled inside 30 days; mean engagement in one large study was **4.1 days**
  `[UX §12]`. The brief explicitly forbids citing Miller, Hick or the jam study, and none
  are used here.

---

## 4. UX principles applied

- **Layer-cake scanning, not F-pattern.** Every element: front-loaded heading → number
  under it → interpretation under that. Nothing meaning-critical touches the right edge
  `[UX §6]`.
- **≤ 2 disclosure levels.** Home → in-place expander. There is no third level, and the
  expanders **do not navigate**, so the current model's "five tappable rows that are each
  a navigation exit and therefore a router, not an explanation" is gone `[UX §4; CRIT §4.6]`.
- **Colour is never the sole channel.** Four redundant channels carry the verdict: marker
  position, band membership, a shape glyph (▲ above / ▬ inside / ▼ below), and the plain
  word `[UX §8]`.
- **Colour never encodes magnitude.** Only the marker and the verdict word are coloured;
  the reference band is neutral grey in both themes. Two coloured things could disagree,
  so there is only ever one.
- **17px body floor, 11px absolute floor, 44px targets, ≥4.5:1.** Instruction 17px
  semibold, cause 15px, basis 12px, band label 11px. Every tap target is ≥44px. The
  header control and both expanders are in the reachable zone or are read-only.
- **Designed at 375×812 first.** The desktop frame *is* 375×812, so the 5.4" case is the
  case being judged, not an afterthought `[W §6.8]`.
- **F17, banner blindness.** The hero region changes number, colour, marker position,
  verdict word, instruction and cause every day, and changes its **label** across data
  states. Only the slot is fixed `[UX §8, §12]`.

---

## 5. Which user problems it solves

| Problem, from the audit | How this concept kills it |
|---|---|
| Three components answer "what should I do today" and none knows the others exist `[CRIT §5]` | There is exactly one sentence in the entire screen written in the imperative. Structurally impossible to contradict, because there is nothing to contradict. |
| The hero number and the chip under it describe different quantities `[CRIT §4.6a]` | There is no chip. There is no second number in the hero. |
| The label lies in the fallback case — "Readiness" printed over the Daily Health Score (**B3**) | The label is data-bound. When Readiness cannot be computed, the label reads "Steps today" and the basis line says why. Nothing is ever printed under a name it is not. |
| 28 numbers, one verdict `[CRIT §8]` | 6 numbers on the default morning, and every one of them ships with its comparison and a plain word. |
| A "High" health warning at position 13, blurred behind a paywall `[CRIT §4.13, §4.17]` | When the illness gate fires, the warning **becomes the hero**. Position 1, full size, never blurred, with a harm anchor. |
| Four simultaneous uncertainty widgets under one ring `[CRIT §2]` | One line. |
| The screen collects input it verifiably ignores `[CRIT §4.10]` | The screen collects nothing. |
| Sparse screens read as broken ("why so much white wasted space?") `[P §3.8]` | The hero is a full-viewport composition with a measured rhythm, not a small card floating in a void. |

---

## 6. Which metrics were given prominence, and why

1. **Readiness 0–100 — the single hero, watch states.** Tier 3 in the brief, and the
   brief is right that it is the least validated element on the screen `[CL §4.2]`. It
   survives here only under four conditions the brief itself sets: it is not shown with a
   day-over-day delta, it carries no decimal, it carries exactly one reference range, and
   it is presented as a directional summary with its inputs named one tap down. T4 for
   this concept is mandated **native index**, and Readiness is the only native index Laso
   morning-locks, which is what makes "one number, all day, no drift" possible at all.
2. **Sleep, in h:mm — the named cause.** Tier 1. Devices exceed 90% sensitivity for sleep
   vs wake and clock time needs no interpretation `[CL §3.1]`. It is compared against
   `SleepNeedCalculator`'s personal need, never a flat 7.5h — **fixes B6**.
3. **Steps — the hero for every user without a wearable.** Tier 1 and the only wearable
   metric with umbrella-review behaviour-change evidence (+1,800 steps/day) and a
   dose-response mortality curve inflecting at 5,000–7,000 `[CL §10.2, §10.3]`. The day-1
   anchor is **7,000 with the reason stated in words** — **fixes B7**.
4. **Resting heart rate, in bpm, as a multi-day trend.** Tier 1, the most reliable thing a
   consumer wearable measures (nocturnal MAE 0.98–1.78 bpm) `[CL §2]`. It is only ever
   the hero when the persistence gate fires: ≥3 consecutive mornings, with a second signal
   moving `[CL §2.3, §14]`.

---

## 7. What was deliberately removed, and why

**Removed from the screen entirely:**

- **Greeting, life-context chips, morning check-in, data coverage, activation banner,
  watch tutorial, "CONCIERGE", weekly review entry, streak milestone card, metric strip.**
  All ten score **0 or 0.5 of 5** `[CRIT §11]`. The morning check-in is written twice and
  read zero times — the brief allows "remove or wire it up", and this concept removes it
  (N4).
- **Vitality Age / Pace of Aging.** Age framing increases emotion and risk perception,
  makes risk perception *less* accurate, and has **no effect on lifestyle intentions or
  behaviour** in 4 of 5 randomised experiments `[CL §9.2, §9.3]`. Laso's own norm tables
  say they are heuristic with no DOIs `[CAP B11]`.
- **Sleep stages.** κ 0.21–0.53, Apple Watch deep-sleep sensitivity 50.7% `[CL §3.1]`.
  The error bar swallows the number.
- **Stress 0–100.** Recall for psychological stress from wearable signals is **50.0%** —
  a coin flip in red `[CL §5.2]`.
- **Strain 0–21.** A log scale presented as linear steps, and session-RPE (one subjective
  question) matches it at r = 0.79–0.86 `[CL §6.1, §6.2]`.
- **Forecasts, "62% chance", "conf 82%".** F4 bans probability as a percentage; the
  confidence figure is an interval-width heuristic reading as calibrated `[CAP §6]`.
- **Every second, third and fourth number in the hero.** Ten to twelve numbers lived in
  `RecoveryHeroCard` alone `[CRIT §2]`. One survives.
- **The numeric endpoints of the reference range.** This is the sharpest removal in the
  concept and the one most likely to be argued with. "58" and "74" as bar ticks are two
  numbers that add nothing a labelled zone plus a marker does not already say — and
  horizontal line bars with coloured blocks scored **highest** on comprehension,
  satisfaction and usability, and significantly reduced intention to contact a physician
  `[UX §11]`. The endpoints live one tap down for the people who want them.

**Demoted to one tap down (still on Home, inside the expander):** raw HRV position, RHR
position, sleep detail, the seven daily values, the range endpoints, the load context.

**What this proves about the sparseness.** Removing the endpoints, the delta chip, the
certainty bar, the "3 of 5 signals" line and the missing-signals paragraph did not just
shrink the card — it made the remaining marker *mean* something, because there is now
exactly one thing on the track to compare it against. Density was hiding the comparison,
not providing it.

---

## 8. Expected impact on daily engagement, with the mechanism

**Sessions per day: flat to slightly down. Time per session: sharply down. This is the
intended direction.**

Mechanism: the screen is complete at 5 seconds. There is no unread card, no expandable
teaser with a number withheld, no "12 patterns found", no variable reward. F9 forbids
deliberate incompleteness and it is also refuted — Zeigarnik does not replicate `[PSY §9]`
and variable reward has no health-trial evidence; across 92 RCTs of mental-health apps
there was **no relationship** between the count of persuasive design principles and
completion (r=0.21, p=0.43) or efficacy (b=0.01, p=0.804) `[PSY §6]`.

This is a deliberate bet on the **Athlytic** side of the category's central split: one
score, alone, top-left, an explicit 10-second design budget, and eleven widgets so the
best version of the home screen is the one you never open `[W §4.2, §4.3, §4.7]`. It is
the exact opposite of Whoop's 83% DAU/MAU dense-scroll bet, whose own new users describe
it as "daunting" `[W §1.8, §1.10]`.

The one engagement mechanic retained is **structural, not persuasive**: the 28px peek of
the second card. Structural nudges — defaults and ordering — are the only nudge class the
publication-bias-corrected meta-analysis leaves standing, and information interventions
specifically are refuted at BF₀₁ = 33.84 `[PSY §12]`.

---

## 9. Expected impact on retention, with the mechanism

**Positive, via two mechanisms, and the honest ceiling is stated below.**

1. **Same thing, same place, every day.** Habit formation's strongest lever is being the
   same thing in the same place `[PSY §4]`, and the loudest single complaint in the entire
   niche teardown is not about any layout — it is about layouts *changing*: "redesigned
   five times in the last four years" `[N §12.6]`. Two slots in a fixed order is the most
   change-resistant structure available.
2. **Bad days stay openable.** Every compliance streak eventually teaches users to stop
   opening the app on bad days, which are the days it has the most value to add
   `[P §6.2]`. With no streak, a wide ungraded bottom band, and an instruction that is
   always "do less" rather than "you failed", the bad-day cost of opening is near zero.
   Bevel proves users *notice* the absence of guilt copy and write App Store reviews about
   it `[W §5.4]`.
3. **Day-1 parity.** The day-1 screen and the day-200 screen differ in **density, never in
   structure** — same slots, same shapes, honest labels. Nothing that needs 7 days renders
   confidently before it has 7 days `[P §2.5]`. Samsung left its hero empty for most of a
   65M-MAU base and the research stream calls it "the single biggest own-goal in this
   teardown" `[P §5.2]`. This screen has no empty hero in any state.

**Ceiling:** with 53% of mHealth apps uninstalled inside 30 days and a 4.1-day median
`[UX §12]`, no home screen fixes retention alone. What this one does is remove the two
documented *causes* of early abandonment it can control — feeling judged, and not
understanding the number.

---

## 10. Honest drawbacks, and who this design fails

- **One number is one point of failure.** On the morning the model is wrong and the user
  feels great, there is nothing else on the screen to rescue the relationship. Whoop,
  Oura, Ultrahuman and Athlytic all get "the score does not match how I feel" as their #1
  complaint `[W §7]`, and this concept doubles the blast radius of that complaint by
  removing the other cards that used to dilute it. The cause clause is the mitigation and
  it is a partial one.
- **It fails the 15% who came for data.** Whoop names this cohort explicitly — the users
  who want to correlate specific metrics `[W §1.5]`. They get two expanders and an escape
  hatch on Home; everything else is on Explore. Some of them will call this screen empty
  and be right about their own needs.
- **It fails anyone whose relevant metric is not the hero.** T10 is resolved as fully
  opinionated with **no pinning**, so a user tracking blood pressure, glucose, or a
  menstrual cycle cannot put that on top. Human Health and Bearable are correct that the
  relevant metric differs person to person `[N §6b, §11.7]`, and this concept knowingly
  pays that cost to keep one screen with one answer.
- **iPhone-only users get a genuinely different hero.** It is labelled, never an upsell,
  and never a silent substitution — but "Steps today" at 9:41 is a weaker morning answer
  than "Readiness 62", and pretending otherwise would be the B3 bug in new clothes.
- **The removed range endpoints will be argued with.** Some users read numbers better than
  bars. The escape hatch and the expander both restore them, but the default costs those
  users one tap every morning.
- **A full-viewport hero is one card per screenful.** On an iPhone 15 Pro Max the gaps
  grow further, and there is a real risk it reads as underfilled to a first-time viewer
  before they learn the shape. Google Health's "huge block of empty space" complaint is
  the live risk here `[P §3.8]`, and the mitigation is composition, not more content.
- **`prefers-reduced-motion` removes the marker slide**, which is the one animation
  carrying meaning (it shows *travel* into position). Reduced-motion users get a static
  marker, which is correct but slightly poorer.

---

## 11. The five-questions scorecard, every component on the screen

**Q1** what is happening · **Q2** good or bad · **Q3** why · **Q4** what next · **Q5** what if I follow it

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Hero — label + number + bar + verdict word | ✔ | ✔ | · | · | · | **2** |
| Hero — instruction sentence | · | · | · | ✔ | ◐ | **1.5** |
| Hero — cause clause | · | ◐ | ✔ | · | · | **1.5** |
| Hero — basis line (the one uncertainty mechanism) | ◐ | · | ◐ | · | · | **1** |
| Hero expander — 3 contributor rows, each with its own band + verdict | ✔ | ✔ | ✔ | · | · | **3** |
| Hero expander — closing note (load context, wide-bottom-band statement, window statement) | · | ◐ | ✔ | · | · | **1.5** |
| "Last 7 days" — chart + interpreting sentence above the detail | ✔ | ✔ | · | · | ◐ | **2.5** |
| "Last 7 days" expander — range endpoints + note | ✔ | ✔ | ◐ | · | · | **2.5** |
| Footer (updated time + date) | · | · | · | · | · | **0** — kept anyway; it is one line of provenance, the cheapest block on the screen `[CRIT §4.16]` |
| Raw-numbers escape hatch | ✔ | · | · | · | · | **1** — scores off by design; this is the mitigation the harms literature offers `[N §12.4]` |
| Tab bar | · | · | · | · | · | **0** — chrome, not content |

**Nothing on the screen scores 0 except chrome and one provenance line.** The current
build has **11 of 19 components scoring 0** `[CRIT §11]`.

---

## 12. How each of the ten tensions was resolved

| # | Tension | Side taken | How it shows on the screen |
|---|---|---|---|
| **T1** | Score-first or action-first | **Score-first.** | The number is the first thing rendered and the largest thing on the screen. The instruction sits below it, under a hairline, at 17px. The score answers "how am I", which is the question users open with; the action is subordinate to it and *derived* from it, which is why they cannot contradict each other. |
| **T2** | One hero number or a cluster of 3–6 | **One, alone.** | There is no second index anywhere above the fold, and no metric strip. The apps with the clearest identity have the fewest numbers; Oura's 5–6 chip cluster drew "it dilutes the information too much" from the most credible reviewer in the category `[W §2.8, §10.1]`. Welltory's three independently-moving percentages is the failure case being avoided `[N §5.8]`. |
| **T3** | Graded verdict or a range you sit inside | **Graded, with a wide ungraded bottom band.** | Three words exist: Optimal / Moderate / Low, from the app's single threshold table. Below 45 is **one block** — same word, same colour, same sentence shape at 44 and at 12 — and the expander states the refusal in plain words: "Anything under 45 reads the same here." This is Oura's D6 move `[W §2.4]`, applied because F8 says a graded slide into failure is an intervention with a measured harmful effect `[CL §3.4]`. "No emotion is not the safe answer", so the grading above the bottom band stays. |
| **T4** | Borrowed unit or native index | **Native index, and it says so when it cannot deliver one.** | Readiness 0–100 is the hero wherever Laso can morning-lock it. Where the sensors genuinely cannot produce it (no wearable, no baselines), the screen switches to a borrowed unit — steps — and **renames the label**. It never prints an index under a name it is not, and it never fakes one from a 75 prior (**B4**). |
| **T5** | Explanation inline, one tap down, or a paragraph | **One clause inline, everything else exactly one tap down, in place.** | The cause clause is a single sentence directly under the instruction. The full attribution is behind one chevron that expands *without navigating*, so the disclosure depth below Home is 1, not 3 `[UX §4]`. No paragraph appears above the number — C9 `[P §3.8]`. |
| **T6** | Celebration or calm | **Calm, zero celebration.** | There is no confetti, no badge, no "Great job", no exclamation mark, no streak, no share affordance. The best day the screen can render — Readiness 78 — says "Good day for a hard session." and nothing else. Fogg: a returning user is already above the activation threshold, so motivational persuasion would be annoying or condescending `[PSY §1]`. |
| **T7** | Density or scroll | **Sparse, and engineered so sparse is not empty.** | One card above the fold, one below, then the screen ends. The anti-pattern being avoided is Google Health's "huge block of empty space" `[P §3.8]`, so the hero is a **full-viewport composition** with three anchored zones and two computed gaps rather than a small card in a void, and the second card peeks by 28px so the screen never looks like it failed to load. |
| **T8** | Fixed slots or contextual morphing | **Fixed slots, content varies inside them.** | The slot sequence is identical in all seven rendered states — full data, iPhone-only, brand new, loading, empty, warning, raw. Only what is *inside* a slot changes. This is Oura's surviving pattern: full-screen morphing failed and was attacked; single-slot morphing shipped `[W §2.8]`. |
| **T9** | Honest uncertainty or confident simplicity | **Exactly one uncertainty mechanism.** | One line, one place, always present: what the reading is built from. The current build ships four simultaneously `[CRIT §2]`; Bevel ships zero and gets "presents confident daily conclusions" without showing its work `[W §5.8]`. There is no confidence percentage (F4), no interval band, no "3 of 5 signals" (F15), no coloured certainty bar. The reference band on the bar is a **comparison**, not an uncertainty widget, and it is the only one on screen (F12). |
| **T10** | Opinionated hierarchy or user pinning | **Fully opinionated. No pinning, no reordering, no customisation.** | Every app that could not decide its hierarchy shipped "customisable" instead, and Garmin's optional Essentials row means Garmin has no identity number `[W §6.2; P §1.8]`. An optional hero is not a hero. The only user control over content is binary and honest: scores on, or scores off. |

---

## 13. Literal budget counts

Counted on the **default morning**: watch data, moderate reading, both expanders closed,
light or dark, 375×812.

| Constraint | Limit | This concept | Inside? |
|---|---|---|---|
| Cards above the fold | ≤ 3 | **1** (28px of card 2's rounded top edge peeks, carrying no content) | ✅ |
| Total blocks | ≤ 7 | **4** — header, hero, "Last 7 days", footer line | ✅ |
| Numbers on screen | ≤ 12 | **6** — `62`, `40` (in the instruction), `1h 28m`, `7` (in "Last 7 days"), `9:38`, `Wed 29 Jul 2026` | ✅ |
| Numbers above the fold | ≤ 5 | **3** — `62`, `40`, `1h 28m` | ✅ |
| Facts to combine to read any element | ≤ 2, target 0 | **0** — every number's comparison and verdict are in the same visual element | ✅ |
| Tap targets | ≤ 8 | **7** — raw-numbers button, hero expander, week expander, 4 tabs | ✅ |
| Distinct exits from Home | ≤ 6 | **3** — Live, Explore, Settings. Expanders and raw mode are in-place, not exits | ✅ |
| Disclosure levels below Home | ≤ 2 | **1** — in-place expansion, no navigation | ✅ |
| Words of copy above the fold | ≤ 20 | **20** — `Readiness` (1) · `Moderate` (1) · `usual` (1) · "Sleep 40 minutes earlier tonight." (5) · "Last night was 1h 28m under usual." (7) · "From sleep and heart rate." (5). Hero numeral and status bar excluded | ✅ (exactly at budget) |
| Uncertainty widgets per number | 1 | **1** — the basis line | ✅ |
| Reference ranges per number | exactly 1 | **1** — the personal "usual" zone | ✅ |

**Both expanders open** (a user action, not the default morning): **12 numbers**, still
inside the ≤12 budget.

---

## 14. Budgets exceeded, honestly

**None on the default morning.** Every figure above is inside its limit, one exactly at it.

Four places where a stricter reading could count differently, stated so nobody has to find
them:

1. **Words above the fold is exactly 20, with zero headroom.** If a reviewer counts the
   hero numeral `62` as a word, it is **21 — one over**. It was written to 20 on the rule
   that the number is the thing being read, not copy about it. If the rule is stricter,
   the honest fix is to shorten the basis line, and that is the line I would defend last.
2. **The peek.** If the 28px of the second card's top edge counts as a card above the
   fold, cards above the fold is **2, not 1**. Still inside ≤3.
3. **The "needs attention" state exceeds the word budget above the fold — 43 words,
   measured, against a limit of 20.** Three things cost it: a three-word label ("Resting
   heart rate"), a longer cause clause naming the persistence and the second signal
   (11 words), and the harm anchor ("Common in the days before a cold. Worth easing off,
   not worth worrying about.", 14 words). This is deliberate and I would not cut it:
   F13's evidence is that adding a harm anchor significantly reduced perceived urgency and
   substantially cut the number of people wanting to contact a doctor urgently, N=1,618
   `[UX §11]`. The budget is specified for the default morning; a health warning is not
   the default morning, and a warning that is terse enough to alarm is worse than a
   warning that is 12 words longer.
4. **The "needs attention" state with the expander open renders 14 numbers.** Over the ≤12
   line, again only in a non-default state and only after a deliberate tap.

---

## 15. Bugs from the audit that this design fixes or defuses

| Bug | Status here |
|---|---|
| **B3** hero ring silently swaps Readiness for the Daily Health Score | **Fixed by design.** The label is data-bound; a different quantity gets a different label and a different basis line. |
| **B4** sparse user's score is mostly a constant 75, shown at full confidence | **Defused.** A user with no baselines never sees a 0–100 index. They see steps against a stated 7,000 anchor and a line saying their own range arrives after seven days. |
| **B5** the "Energy" Why row explains the score with the score | **Fixed.** No contributor row restates the hero. The three rows are sleep, heart rate variability and resting heart rate — inputs, not the output. |
| **B6** sleep goal hardcoded at 7.5h | **Fixed.** The comparison is 7h 40m, Alex's personal need. |
| **B7** steps goal hardcoded at 10,000 | **Fixed.** The anchor is 7,000, with the reason in plain words in the cause slot. |
| **B8** recovery-debt "trend" words are a size test labelled as a direction | **Avoided.** No trend word appears anywhere; direction is only ever shown as position in a 7-day chart. |
| **B10** ±2% weekly moves called "wins" | **Avoided.** No weekly wins block exists. |
| **B11** heuristic vitality norms printed as fact | **Avoided.** Vitality is not on the screen. |
| **B1 / B2** blood oxygen filter, sleep forecast unit divide | **Out of blast radius.** Neither metric is rendered, so neither can lie here. They still need fixing before either is ever promoted. |

---

## 16. Prototype notes

- Single file, no network, no libraries, no icon fonts, no emoji. All icons and both
  charts are inline SVG.
- Tokens are the shipping values from `DESIGN-TOKENS.md`, verbatim, including the 4pt
  grid, the radii (24 hero / 16 card), the three-band score table, and the light-shadow /
  dark-border card rule.
- **Dev toolbar** (bottom-right, deliberately ugly and out of the way): theme, data state
  (watch+phone / iPhone-only / brand new / loading / empty), reading (high / moderate /
  low / needs attention), and a fold-line overlay for verifying the above-fold budgets.
- States can also be deep-linked for review, e.g.
  `01-one-number.html#theme=light&data=phone`, `#reading=attention`, `#raw=true`,
  `#heroOpen=true&weekOpen=true`, `#fold=true`.
- The empty state's "Connect Apple Health" button runs the real loading → brand-new-user
  sequence.
- Closed expanders carry `inert`, so their contents are out of the accessibility tree as
  well as out of view.
