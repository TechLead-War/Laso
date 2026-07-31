# Concept 07 — The Coach

**File:** `design/home-v2/concepts/07-coach.html`
**Fictional user:** Alex, 34. Slept 6h 12m against a 7h 40m need. Sleep debt 4h 20m over the last five nights. Resting heart rate 58 bpm against a 55 baseline. 8,400 steps yesterday. Bedtime drifting 40 minutes later across the week.

---

## 1. The one-sentence philosophy

**Someone has already read your data, has exactly one thing to say, and says it with your number inside the sentence, so the verdict lands before you read a word and the reason is one tap away without leaving the screen.**

---

## 2. Why this layout order, element by element

The brief's most dangerous instruction for a conversational concept is C9 / F16: Fitbit took 3,419 revert votes for putting narration above the user's number, and Eight Sleep got "I don't know who thought anyone wanted to read that with their eyes half open" `[P §3.8; N §4.2]`. Both failures share one structural fact: **the paragraph and the number were different elements, stacked.** The paragraph was a toll gate on the way to the number.

This concept removes the stack. There is no paragraph and no number. There is one element that is both.

**Slot 0 — Header.** The date, 13px, tertiary. No greeting by name. `CoachGreetingView` scored 0 on the five questions and renders above the empty state, so a user with no data gets greeted by name while being told the app knows nothing `[CRIT §4.1]`. Cut.

**Slot 1 — The line.** The hero, and it owns the entire first viewport (632px of a 731px fold). Four parts, in this order:

1. **The band.** A positional bar with exactly one reference range, the personal goal range `[UX §11, F12, F14]`. Track, a marked-off "your usual" zone with edge ticks, and a marker with a shape cap. This is the 0 to 1 second channel and it carries **no text except the two words naming the range**. Position + shape + colour, three channels, so colour never encodes magnitude alone and the screen still reads for a colourblind user `[UX §8, §10]`. It is at the top because it is the only thing that has to work before the session begins.
2. **The line.** The instruction, 30px semibold, with the number set inline at 46px. "Get to bed by **10:30** tonight." Six words. This is the 1 to 3 second layer `[UX §7]`.
3. **The because.** One clause naming one cause with its magnitude, 18px, with the measured number inline at 27px. "You slept **1h 28m** under your usual." This is the 3 to 5 second layer and it is the C2 open lane: four of six competitor apps show no reason at all on the home screen, and all four are complained at for it `[W §7, §1.9]`.
4. **The reply.** `Why?` then one primary reply, both full width, both in the bottom third where the thumb reaches `[UX §7]`. The slack in the card sits between the because and the replies, so it reads as the gap between what was said and what you say back, not as a hole.

Layer cake, exactly as specified: short front-loaded visual, number under it, interpretation under that, nothing meaning critical on the right edge `[UX §6]`.

**Slot 2 — Everything else.** The health-warning slot, at position 2, every single day. On an ordinary day it says what was checked and found normal. On a warning day it takes a red rail, a "Worth telling you" tag, the named signals, and a one-tap expander for the three readings. It is never blurred, never paywalled, never hedged, never below position 3 `[N6; CRIT §4.13, §4.17]`. Because the slot exists on quiet days too, the warning does not arrive as an unfamiliar new object on the worst morning of the month.

**Slot 3 — The chart.** Same visual grammar as the hero band, rotated: the "your usual" range as a stripe, fourteen nights as dots, and a stem from the band edge only where a night fell outside it. Interpretation sits **above** the chart, which is Gentler Streak's inversion and almost nobody else's `[N §2.7, D3]`. No bars, so there is no truncated baseline to distort; no connecting line, because line graphs are the most used and among the hardest to read `[UX §10, F14]`.

**Slot 4 — Steps.** The only wearable metric with umbrella-review behaviour-change evidence, the only one that survives iPhone-only, and the only one that survives day 1 `[CL §10.2, §10.3]`. Positional bar against one goal range anchored at 7,000, not 10,000, with the reason in plain words. Fixes **B7**.

**Slot 5 — The proof.** `RecommendationEvaluator.buildActionProof`, aggregate only. "You've gone to bed early 6 times. Those mornings you slept 38 minutes longer than usual. It's working." Progress monitoring against a goal is the single best-evidenced item in the psychology corpus, 138 studies, N=19,951, d+ = 0.40 `[PSY §9]`, and it is currently buried on a detail screen `[CAP §9.8]`.

**Slot 6 — Footer.** Last updated, plus the escape hatch.

---

## 3. Psychological principles used, and the mechanism

| Principle | Mechanism here |
|---|---|
| **Fogg: spend the screen on ability, not motivation** `[PSY §1]` | A returning user is already above the activation threshold. The screen removes brain cycles by pre-deciding the one thing and pre-filling the time. Zero decisions before the first tap. |
| **Behaviour goal setting (β=+0.89) and graded tasks (β=+0.87)** `[PSY §10]` | The line is always a behaviour with a time attached ("by 10:30"), never a score target. It is graded to the day: on a quiet day it says carry on. |
| **Progress monitoring, d+ = 0.40** `[PSY §9]` | Slot 5 reports the aggregate effect of the user's own past compliance, never n=1. |
| **SDT autonomy support (ρ = .21 to .48)** `[PSY §5]` | Every reply row contains a way to decline. "Not tonight" lives inside the Why panel, so refusal happens after hearing the reason, not before. The response is "Fine. I'll bring it up again if the run keeps going." No guilt, no loss framing. |
| **Life context used, never solicited** `[CRIT §4.2; CAP §4]` | "Something feels off" appears exactly on the days the coach has nothing to prescribe or has already flagged something. It writes a real `LifeContextStore` override at advisor rung 0. It is not four always-on toggles asking 95% of users daily to declare a problem they do not have. |
| **Endowed progress, 19% to 34%** `[PSY §8]` | The brand-new state shows the goal shape already drawn with today's steps in it, plus thirteen empty day ticks. Never an empty 0-of-N. |
| **F9 refusals** | No streak of any kind. No loss framing. No variable reward. No deliberate incompleteness. One missed night costs nothing, because in the best real habit data it costs 0.29 points out of 42 and fully recovers `[PSY §3]`. |

---

## 4. UX principles applied

- **Layer-cake scanning, not F** `[UX §6]`. Every block is heading, number, interpretation, top to bottom.
- **Comparison inside the same visual element** `[UX §1, §5, N2]`. There is no number anywhere on this screen that needs another number on the screen to interpret it. Element interactivity is zero.
- **Exactly one reference range, and it is the personal goal range** `[UX §11, F12]`. Comprehension 14.49% to 43.45%, N=6,766. Substituting beats adding, so there is no population band anywhere.
- **Positional bars only** `[UX §10, F14]`. No pie, donut, gauge, treemap or 3D. Both visuals on the screen use the identical grammar so the user learns one thing once.
- **Harm anchor** `[UX §11, F13]`. Every explanation ends with one: "One short night is normal. It only starts to matter when the run keeps going." On the warning day: "This often shows up a day or two before a cold, and it often comes to nothing. On its own it is not a reason to call a doctor."
- **Two disclosure levels maximum** `[UX §4]`. Home, then one in-place expansion. Nothing on this screen navigates in order to explain.
- **Attrition, not cognition, as the justification for sparseness** `[UX §12]`. 53% uninstall in 30 days, median engagement 4.1 days.
- **Platform floors.** Body 17px, absolute floor 11px, all tap targets 44px or larger (measured: smallest is 275x44), 4.5:1 text contrast in both themes (measured: 24 of 24 pairs pass, worst text pair 4.80:1), no horizontal overflow from 320px up, `prefers-reduced-motion` respected, real focus rings, `aria-label` on every icon-only control, `role="img"` and a plain-language `aria-label` on both SVG visuals.

---

## 5. Which user problems it solves

| Problem | How |
|---|---|
| "Three components tell me what to do and none knows the others exist" `[CRIT §5]` | Exactly one component gives an instruction. When sleep debt is the biggest thing about today, sleep debt **becomes** the line. When the illness warning fires, the warning becomes the line and slot 2 carries the detail. Nothing else on the screen is imperative. |
| "The score doesn't match how I feel" `[W §7]` | There is no score. Every quantity on this screen is a unit the user already owns: hours, minutes, a clock time, steps, bpm, flights. |
| "It doesn't show its work" `[W §5.8]` | `Why?` is a full-width control directly under the sentence, and it expands in place. |
| "28 numbers, one verdict" `[CRIT §8]` | 11 numbers, and every one of them ships with its comparison and a plain-word verdict in the same element. |
| "A High warning at position 13, blurred behind a paywall" `[CRIT §4.13, §4.17]` | Position 1 and 2, unhedged, never blurred. |
| "The app asks me things it ignores" `[CRIT §4.10]` | The only input on the screen is the life-context reply, which writes a real override the advisor reads at rung 0. The morning check-in is gone. |
| Cold start, universally unsolved `[W §10.7; P §5.2]` | Three explicit hero states with the same slot structure, a neutral no-verdict marker on day 1, and the coach saying out loud that the target is not yours yet. |

---

## 6. Which metrics were given prominence, and why

1. **Time asleep against personal sleep need, in h:mm.** Devices exceed 90% sensitivity for sleep versus wake `[CL §3.1]`, clock time needs no interpretation, and `SleepNeedCalculator` already computes the personal target, which fixes **B6**. Expressed as a bedtime, because a bedtime is an action and a duration is only a report.
2. **Sleep debt in hours, 14-day rolling.** RISE's D2. A bad night dents a balance instead of resetting a streak `[N §1.2, §1.7]`. Framed as "you're running short", never as an hours-owed ledger, because repayment is not 1:1 `[CL §3.2]`.
3. **Steps against 7,000.** HR 0.53 for 7,000 versus 2,000 steps/day, the curve inflecting at 5,000 to 7,000 `[CL §10.2]`. Survives iPhone-only and day 1.
4. **Resting heart rate in bpm, multi-day.** MAE 0.98 to 1.78 bpm, the most reliable thing a consumer wearable measures `[CL §2]`. Shown only when the 3-consecutive-night, 5-bpm-or-10% gate fires. On the default morning the +3 bpm reading is explicitly named as too small to act on, inside the Why panel.
5. **The illness early warning.** The existing 2-metric, 2-day, 1.0σ, 14-day-baseline gate is genuinely honest and matches the clinical rule `[CAP §3c; CL §14]`. Promoted from position 13 to position 1 and 2.
6. **The aggregate action proof.** Best-evidenced component available, currently invisible on Home `[PSY §9; CAP §9.8]`.

---

## 7. Which metrics were deliberately hidden or removed, and why

**Every 0-to-100 index is off this screen.** Readiness, Daily Health Score, Stress, Strain, Brain Health, Vitality Age. This is the concept's hardest commitment and the direct expression of T4.

- **Readiness / Recovery.** No manufacturer discloses weights, none is validated against clinical outcomes, and in D1 swimmers WHOOP's Recovery score was **not** associated with perceived recovery while the raw HRV it measured **was** `[CL §4.2, §4.3]`. A composite that tracks worse than its own input does not get to be the thing a coach talks about. It also cannot be delivered to an iPhone-only user, which means it can never be the fixed hero `[CAP §7]`.
- **Daily Health Score.** Coverage shrinkage pulls sparse users toward a constant 75 presented at full confidence (**B4**), and it is currently substituted silently under a "Readiness" label (**B3**). Removing it removes both bugs.
- **Stress.** Recall for psychological stress from wearable signals is 50.0%, a coin flip in red, confounded by caffeine, cold hands and positive arousal `[CL §5]`. Not renamed, removed. This concept has no word for it because it makes no claim about it.
- **Strain 0-21.** A logarithmic scale presented as equal steps is a comprehension hazard, and session-RPE correlates with TRIMP at r = 0.79 to 0.86 `[CL §6.1, §6.2]`.
- **Sleep stages.** κ 0.21 to 0.53, Apple Watch deep-sleep sensitivity 50.7% `[CL §3.1]`. RISE omits them and is right to.
- **Vitality Age and Pace of Aging.** No effect on lifestyle intentions in 4 of 5 randomised experiments, and Laso's own norm tables are documented as heuristic with no DOIs `[CL §9.3; CAP B11]`.
- **Raw HRV in ms.** Only inside the plain-numbers escape hatch, and labelled "Heart rate variability (SDNN)" because SDNN is not RMSSD and must never share an "HRV" label `[CL §1.2]`.
- **`DataCoverageCard`, activation progress, "patterns found: 12", the streak share card, the weekly review entry, the watch tutorial, the CONCIERGE door, the morning check-in.** All scored 0 on the five questions `[CRIT §4.4, §4.8-4.12, §4.15, §4.17]`.
- **Forecasts.** Not promoted, because nothing back-tests them and "conf 82%" is an interval-width heuristic reading as calibrated `[CAP §6, F4]`.

**Vocabulary lock, one word per concept, used everywhere:** sleep, resting heart rate, heart rate variability, your usual, your goal. The verdict ladder is three words and only three: **under**, **inside your usual range**, **above**. No coined vocabulary appears anywhere in the file.

---

## 8. Expected impact on daily engagement, and the mechanism

**Fewer sessions, shorter sessions, higher satisfaction per session.** This is Athlytic's bet (D1), not Whoop's `[W §4.3, §1.8]`, and it is deliberate.

Mechanism: the screen answers in under one second without reading, so the marginal value of a long session drops to near zero. The above-fold region has 17 words and 3 numbers, which is roughly a 4-second read against a 72-second mobile session average `[UX §7]`. The one thing that can lengthen a session is `Why?`, and that is a want, not a tax.

The counterweight to banner blindness `[UX §8, §12, F17]` is that the hero's **quantity changes with the day**, not just its value. On a short-sleep morning the band is sleep hours; on a warning morning it is resting heart rate; on a quiet morning it is sleep again but the sentence is a permission rather than an instruction. The region is structurally fixed and semantically live, which is Oura's surviving single-slot morphing rather than its failed whole-screen morphing `[W §2.8, T8]`.

Honest expectation: DAU/MAU below Whoop's 83%. That is the trade being made on purpose.

---

## 9. Expected impact on retention, and the mechanism

Three mechanisms, in order of expected size:

1. **Cold start is a designed state, not a degraded one.** Nobody in the corpus ships a distinct first-14-days home screen and every one of them pays for it in reviews `[W §10.7; P §5.2, §7.4, C8]`. Here, day 1 with no history still produces a real, evidence-backed instruction, a drawn goal shape, and an explicit sentence saying the target is not yours yet and when it will be. Against a 4.1-day median engagement and 53% 30-day uninstall `[UX §12]`, the first week is the whole game.
2. **No guilt architecture at all.** Bevel's absence of guilt copy earned an unprompted App Store review `[W §5.4]`. The quiet day is the proof: the coach's honest answer is "carry on", and it says so instead of manufacturing a task. Every compliance streak eventually teaches users to stop opening the app on bad days, which are exactly the days it has the most value to add `[P §6.7, D7]`.
3. **Trust compounds through the proof slot.** Turning raw data into a score raises privacy concern from 40% to 60% `[PSY §11]`, and accuracy plus transparency account for roughly half of all mHealth review concerns. This screen ships no score, states its own uncertainty in one plain sentence, and reports the measured effect of its own past advice. The escape hatch is the final trust signal: it says the product does not need you to accept its interpretation.

---

## 10. Honest drawbacks, and who this design fails

**Who this fails, specifically:**

- **The quantified-self power user.** Someone who opens Laso to check whether HRV moved gets nothing here. Their number is behind the escape hatch, stripped of context, which is the opposite of what they want. Whoop's dense scroll and 83% DAU/MAU exist because this user is real and vocal.
- **Anyone who disagrees with the coach.** The screen is opinionated by construction. `Why?` and "Something feels off" are the only pressure valves, and neither lets the user say "no, focus on my training load instead". T10 is resolved almost entirely toward opinion, and the only pinning available is negative.
- **Users whose real limiter is not the thing the ladder picks.** `DashboardSmartActionAdvisor` has 8 rungs and 17 action types. When it is wrong, this screen is wrong loudly and with nothing beside it to correct the impression, because there is deliberately no second opinion on the page. The old screen's three contradictory instructions were a bug, but they were also, accidentally, a hedge.
- **Very tall or very short viewports.** The hero is sized to fill a 5.4 inch fold. On an iPhone SE the hero is essentially the whole screen, which is on-concept but leaves nothing visible to signal that anything is below. On a 6.9 inch phone the attention card sits fully above the fold, which pushes the above-fold word count up.
- **Anyone with an accessibility text size above the default.** The 46px inline number inside a 30px sentence is the most fragile element in the design at AX sizes. It will hold its hierarchy, but the line will wrap to four lines at AX3 and the hero will grow past the fold.

**Design-level drawbacks I am not hiding:**

- A single hero quantity is a single point of failure. If the sleep read is wrong on a given night, the whole screen is wrong, with no second number to hint at it.
- The conversational voice ("I'm reading five nights of sleep") is a persona, and personas age badly and localise badly. It also risks reading as an AI even though nothing on this screen is presented as one.
- Removing every index removes the thing many users came for. Some fraction will read "no score" as "the app got worse", exactly as Garmin's 2024 desaturation removed the only free emotional feedback and users noticed the loss `[W §6.4]`.
- The band's subject is named by the sentence beneath it, not on the band itself. That saves three words of a very tight budget, and it costs a small amount of standalone legibility if someone reads the graphic alone.

---

## 11. Five-questions scorecard for every component

Q1 what is happening · Q2 good or bad · Q3 why · Q4 what to do · Q5 what happens if I follow it. Nothing scoring zero is on the screen.

| Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Header (date only) | · | · | · | · | · | **n/a**, chrome, 0 tap targets, 2 words |
| **Slot 1a — the band** | ✔ | ✔ | · | · | · | **2** |
| **Slot 1b — the line** | · | ◐ | · | ✔ | ◐ | **2** |
| **Slot 1c — the because** | ✔ | ✔ | ✔ | · | · | **3** |
| **Slot 1d — Why? panel** | ✔ | ◐ | ✔ | · | ◐ | **3** |
| **Slot 1e — the reply** | · | · | · | ◐ | · | **0.5** |
| **Slot 2 — Everything else** | ✔ | ✔ | · | · | · | **2** |
| **Slot 3 — the chart** | ✔ | ✔ | ◐ | · | · | **2.5** |
| **Slot 4 — Steps** | ✔ | ✔ | · | · | ◐ | **2.5** |
| **Slot 5 — the proof** | · | · | ◐ | · | ✔ | **1.5** |
| **Slot 6 — footer + escape hatch** | · | · | · | · | · | **0**, kept deliberately: N7 mandates it and it is the cheapest block on the screen |

Total instruction-giving components: **1**. Total verdict-carrying numbers: **11 of 11**.

---

## The ten tensions, resolved

| # | Tension | Side taken | How |
|---|---|---|---|
| **T1** | Score-first or action-first | **Action-first, spoken, and there is no score to compete with it** | The imperative is the largest type on the screen. No index exists anywhere, so the failure mode the current build has (instruction, then a score contradicting it one card down) is structurally impossible. |
| **T2** | One hero number or a cluster | **One, and it lives inside the sentence rather than above it** | Exactly one measured quantity in the hero, set inline at 27px inside an 18px clause. The 46px number in the line above it is a target, not a reading. Welltory's three independently moving percentages cannot occur. |
| **T3** | Graded verdict or a range you sit inside | **Both, deliberately: a range you sit inside, graded in words** | The band is Gentler Streak's "inside or outside your usual", never pass/fail. The grade is carried by a locked three-word ladder (under / inside your usual range / above) plus three marker shapes plus colour. Never colour alone, and never a moral vocabulary: below the band is a magnitude, not a failure. |
| **T4** | Borrowed unit or native index | **Borrowed, absolutely, everywhere** | h:mm, a clock time, bpm, steps, flights. Zero native indices on the screen. A coach speaks in things you own, and the weakest home screens "require the app to teach a scale before the number means anything" `[N §12.2]`. |
| **T5** | Explanation inline, one tap, or a paragraph | **One tap, expanding in place, never navigating** | `Why?` is full width and directly under the sentence it explains. It reveals contributors with magnitudes, a harm anchor, the uncertainty statement, and the decline option. It is not five tappable rows that are each a navigation exit. |
| **T6** | Celebration or calm | **Calm, with acknowledgement and never congratulation about compliance** | Setting a reminder returns "Reminder set for 10pm". Declining returns "Fine. I'll bring it up again if the run keeps going." Reporting a bad day returns "Got it, I've marked you as unwell. I'll keep today easy and I won't push you." No confetti, no streak, no praise for opening the app. |
| **T7** | Density or scroll | **Sparse above the fold, dense below it** | 17 words and 3 numbers above the fold; 6 blocks and 11 numbers in total across roughly 2.2 screenfuls, which lands inside the 74%-within-two-screenfuls window `[UX §7]`. Not sparse for its own sake: the hero carries a graphic, two sentences and two controls, so it is not Google Health's "huge block of empty space". |
| **T8** | Fixed slots or contextual morphing | **Fixed slots, with morphing inside slot 1 and slot 2 only** | The six-slot order is byte-identical on every day and in every data state. What varies is the content inside two named slots, including which quantity the hero band plots. Oura's surviving pattern, not its failed one. |
| **T9** | Honest uncertainty or confident simplicity | **Honest, exactly once, in plain speech** | One mechanism on the whole screen: the coach saying how sure it is in a sentence. No band count, no percentage, no certainty bar, no "based on 3 of 5 signals". In the full-data state it lives inside `Why?`, because confidence is high. In the iPhone-only and brand-new states it is promoted into the hero and always visible, because confidence is low and the user must not have to ask. Laso currently ships four simultaneous widgets under one ring; this ships one. |
| **T10** | Opinionated hierarchy or user pinning | **Opinionated, with two structured ways to push back and one way out** | No customisation, no reordering, no optional hero, because an optional hero is not a hero (C7). The user's leverage is `Why?`, "Not tonight", "Something feels off" (which writes a real advisor override), and the plain-numbers escape hatch that turns the whole opinion off. |

---

## Literal budget counts

Measured in a headless browser at 375x812 (5.4 inch), default morning: full watch data, short-sleep day, loaded, nothing expanded. Fold measured at the top of the tab bar, y=731.

| Budget | Limit | This concept | |
|---|:--:|:--:|---|
| Cards above the fold | ≤ 3 | **2** | hero, plus 8px of the next card's blank top edge |
| Total blocks | ≤ 7 | **7** | header + 6 content blocks |
| Numbers on screen | ≤ 12 | **11** | date, 10:30, 1h 28m, 14, 4h 20m, 7h 20m, 8h, 8,400, 7,000, 6, 38. A naive whitespace token count returns 13, because it splits each duration ("1h 28m") into two. A duration is one quantity to parse, so the figure is 11. Excluding the calendar date it is 10. |
| Numbers above the fold | ≤ 5 | **3** | date, 10:30, 1h 28m |
| Tap targets | ≤ 8 | **7** | Why?, Remind me, Show plain numbers, and 4 tabs |
| Distinct exits from Home | ≤ 6 | **3** | Live, Explore, Settings. Nothing in the content area navigates. |
| Words above the fold | ≤ 20 | **17** | Wednesday July / your usual / Get to bed by tonight / You slept under your usual / Why? / Remind me |
| Uncertainty mechanisms | 1 | **1** | the coach saying how sure it is, in one sentence |
| Reference ranges per number | exactly 1 | **1** | the personal goal range, always. No population band anywhere. |
| Disclosure levels below Home | ≤ 2 | **1** | one in-place expansion, no navigation |
| Smallest font | ≥ 11px | **11px** | |
| Smallest tap target | ≥ 44px | **275 x 44** | |
| Text contrast pairs failing 4.5:1 | 0 | **0 of 24** | worst text pair 4.80:1, worst graphic pair 3.77:1 against a 3:1 floor |
| Horizontal overflow at 375px | none | **none** | |

---

## Every budget exceeded, and why

The budgets above hold on the default morning. They do not all hold in every state, and here is the complete list, measured, with the reason.

1. **Attention day: 27 words above the fold (limit 20).** The warning sentence names two signals, their magnitude and their persistence, which is what makes it honest and what the current build gets wrong by printing "Worth Noticing" beside a red "High" badge. N6 forbids hedging or shortening a warning and outranks the word budget. Numbers above the fold drop to 2 and total numbers drop to 8 on this day, so the reading load is still lower than the default morning; it is the sentence that is longer, not the data.

2. **iPhone-only: 37 words above the fold. Brand new: 41 words above the fold (limit 20).** Both overruns are caused entirely by the uncertainty sentence being promoted into the hero instead of hidden behind `Why?`. N5 requires a degraded hero to be a real, **labelled**, lower-confidence answer, and a label the user has to tap for is not a label. I would rather overrun the word budget than ship a confident-looking hero to a user I cannot be confident about. Both states stay inside every other budget: 3 numbers above the fold, 9 and 5 numbers total, 7 tap targets, 2 cards above the fold.

3. **Why panel open: 55 words above the fold, 12 numbers on screen, 8 tap targets (limits 20, 12, 8).** Post-interaction and user-initiated, so it is not a default-morning state. It sits exactly on the number and tap-target limits and blows the word limit, which is the correct trade for a control whose entire purpose is prose. Cards above the fold drops to 1 while it is open.

4. **Quiet day: exactly 20 words above the fold.** At the limit, not over it, but with no margin. Worth knowing.

5. **Context chips: 10 tap targets transiently (limit 8).** Tapping "Something feels off" reveals three chips. They exist for one interaction and collapse into an acknowledgement.

6. **Total blocks is exactly 7, at the limit.** If the proof slot ever needs a sibling, something else comes off the screen first.

Nothing exceeds a **§3 ban** or a **§8 non-negotiable** in any state.

---

## Prototype notes

- Single file, no network, no libraries, no web fonts, works from `file://`.
- Both visuals are hand-built inline SVG. All icons are inline SVG paths. No emoji anywhere.
- Dev toolbar, bottom right, deliberately low contrast and outside the design: appearance (auto / light / dark), screen state (loaded / loading / empty), data available (watch / phone only / brand new), and the day (short sleep / quiet / attention). The day switch is disabled with an explanation when the data state cannot support it.
- The three days exist specifically to test the wallpaper failure: a coach that says the same shape of thing every morning stops being read. The quiet day's honest answer is "carry on", and it changes the hero's tone, its marker shape, its reply buttons and its chart interpretation.
- Verified: 40 render permutations across every data state, day, and interaction flag produce valid output with no `undefined`, `NaN` or unhandled action; every emitted `data-act` has a handler; loading, empty, plain-numbers and all three tab stubs render.
