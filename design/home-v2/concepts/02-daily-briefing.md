# Concept 02 — The Daily Briefing

**File:** `design/home-v2/concepts/02-daily-briefing.html`
**Date:** 2026-07-29. **User:** Alex, 34. Three authored mornings: Wed 29 (steady), Thu 30 (strong), Fri 31 (below usual, with a health notice).

---

## 1. The one-sentence philosophy

**The app writes you a dated one-page dispatch while you sleep, and the Home Screen is that dispatch — a masthead, a headline verdict, the one thing to do, the story behind it, and a sign-off — visibly authored, visibly new every morning.**

### The hard problem, and how it is solved

C9 and F16 are absolute: no AI paragraph, no AI entry point, above the user's own number. Google put narration above the metrics and took 3,419 revert votes; Eight Sleep got "I don't know who thought anyone wanted to read that with their eyes half open" `[P §3.8; N §4.2]`. A briefing concept dies on this rule unless the briefing stops being a paragraph.

It is solved **typographically, not with a ring**:

1. **There are no paragraphs above the number.** The only text above `Readiness 62` is a 3-word dateline and a 3-word headline. Prose does not begin until slot 3, which is below the number and below the action.
2. **The headline is headlinese, not prose.** `Steady, short night.` — verb-free, 32px, tight leading, left-aligned, the verdict word carrying the band colour. It is read as a shape before it is read as language, in the same way a newspaper front page is.
3. **The masthead rule is the positional bar.** Immediately under the headline sits a full-width rule with the user's own range drawn as a recessed slot and a coloured tick at today's position. That is the 0-1s channel: **position + shape + colour, zero text, zero digits, no zero point.** It is also the editorial rule that a printed page uses to separate the dateline from the story, so the pre-attentive element and the editorial device are the same object.
4. **No AI word, no sparkle glyph, no accent colour anywhere on the screen.** The `accent` token (`#0E7490` / `#22D3EE`, reserved in the design system for the ask-your-data affordance) is deliberately unused. Per `[CRIT §4.12]` that door belongs in the nav bar, not on Home.

The result: the verdict and the number land pre-attentively, and the authored voice arrives afterwards, where reading is optional. **A briefing that you never have to read still works.**

---

## 2. Why this layout order, element by element

Fixed slot order, identical every morning. Only the content inside a slot varies `[N8; PSY §4]`.

| # | Slot | Why it sits here |
|---|---|---|
| 1 | **The brief** — dateline · headline · `Readiness 62` · positional rule · cause clause · `Why` | 0-1s and 3-5s in one block. The dateline carries the single uncertainty statement (T9). The clause `Sleep 1h 28m short of your usual.` is the 3-5s "one clause naming one cause with its magnitude" — the C2 open lane that no competitor ships `[W §1.9]`. The comparison and the plain-word verdict live in the same visual element as the number `[N2; UX §11]`. |
| 2 | **Today** — one instruction, two buttons, aggregated proof | 1-3s. T1's mandate is verdict-first *then* action, so it is position 2, not position 1. The instruction is ≤ 8 words. `Mark done` / `Remind me tonight` are the two right buttons `[§4 Tier 1]`. The proof line sits *below* the buttons so the signifier is adjacent to the instruction and the evidence reads as a footnote. |
| 3 | **Overnight** — the narrative, or the health notice | The lede of the dispatch, and the escalation slot. When `IllnessEarlyWarning` fires, this same slot becomes `Heart and sleep both shifted` with a red left rule and a harm anchor — **position 3, never blurred, never paywalled, never hedged** `[N6; CRIT §4.13, §4.17]`. Same slot, same position, escalated content. |
| 4 | **The last seven nights** — interpretation, then chart, then caption | The evidence for slots 1-3. Interpretation sits **above** the chart, which is Gentler Streak's inversion and almost nobody else's `[N §2.7]`. The chart is the only real disclosure of depth on the screen, so it earns its place below the fold. |
| 5 | **Yesterday** — steps against one goal range | The only signal with umbrella-review behaviour-change evidence, the only one that survives iPhone-only and day 1 `[CL §10.2, §10.3]`. Same bar grammar as the hero, so the user learns one visual language, not two. |
| 6 | **Sign-off** — the written-at line and the escape hatch | The colophon. `Written at 6:04 am from last night's data.` is what makes the dispatch a dispatch. The escape hatch is here because that is where a reader ends up, and because a control that turns the whole product off should not compete with the product. |

**Why a single sheet instead of a card stack.** Six floating cards would read as a dashboard, which is exactly the thing `[CRIT §1]` says Laso already is. One continuous surface with hairline rules and tracked small-caps section headings reads as a *document*. It also delivers the brief's own layer-cake requirement literally: short front-loaded heading, number under it, interpretation under that, nothing meaning-critical on the right edge `[UX §6]`.

---

## 3. Psychological principles used, and the mechanism

- **Fogg — spend the screen on ability, not motivation.** A returning user is already above the activation threshold, so persuasion "would either be annoying or condescending" `[PSY §1]`. The action is pre-chosen, pre-scaled and one tap from done. No motivational copy anywhere.
- **Progress monitoring (138 studies, N=19,951, d+ = 0.40)** `[PSY §9]`. `Done 6 times before. Your readiness averaged 4 points higher the next morning.` Aggregate over 6 occurrences, never n=1, exactly the defensible form the brief prescribes. On Friday, where no history exists, the line is simply absent rather than fabricated.
- **Endowed progress (car wash, 300 cards, 19% → 34%)** `[PSY §8]`. The new-user chart draws 2 recorded nights and 5 dashed outlines: the goal shape is already begun, not a `0 of 7`. There is no percentage, no "Day 5 of 7 · 62%" — that pattern is explicitly removed `[CRIT §4.9]`.
- **Habit formation needs sameness of place** `[PSY §4]`, **banner blindness punishes sameness of content** `[UX §12; F17]`. This concept is the cleanest possible resolution of that pair: the slots never move, and the words inside them are rewritten every night. That is what a dated dispatch *is*.
- **SDT — controlled regulation predicts worse mental health (ρ = .13 to .46)** `[PSY §5]`. No streak, no loss frame, no pressure verb. `Under your 7,000 goal. Rest counts here.` is the Gentler Streak polarity inversion: below the band is capacity, not failure `[N §2.2]`.
- **Lally — a missed day costs 0.29 of 42 and fully recovers** `[PSY §3]`. Nothing on the screen counts consecutive days of anything.
- **Sham-feedback harm (Gavriloff n=63; Draganich & Erdal n=164) and orthosomnia at 3.0–14.0%** `[CL §3.4, §3.5]`. Friday's headline is `Below your usual.` — a location statement, not a grade. Following Oura's single wide bottom band, this design refuses to grade degrees of bad `[W §2.4]`. And the escape hatch exists because it is the only mitigation the harms literature actually offers `[N7; N §12.4]`.
- **T6 — calm with quiet acknowledgement.** Marking the action done produces one green tick and one line: `Logged at 9:41 am. Tomorrow's brief will say whether it helped.` No confetti, no score bump, no share sheet.

---

## 4. UX principles applied

- **Layer cake, not F-pattern** `[UX §6]`. Every slot: tracked small-caps heading → number or interpretation → detail. Nothing information-carrying on the right edge; the seven-night chart puts day labels on the **left** and lets the bars run right.
- **Positional bars only** `[F14]`. Two bars on the screen, both horizontal, both with **exactly one** reference range — the personal one. No pie, donut, gauge, treemap or 3D. Colour is never the sole channel: the marker's position inside/outside the slot carries the same information, and the words repeat it.
- **The hero axis has no numbers and no zero.** It runs from "well below your usual" to "well above." This kills the cross-person read `[F2]`, kills the zero floor `[N7]`, and makes the personal goal range the *only* reference on the axis, which is the substitution that took comprehension from 14.49% to 43.45% `[UX §11]`.
- **Exactly two disclosure levels below Home** `[C4; UX §4]`: `Why` (expands in place, no navigation) and `Show plain numbers instead` (a mode switch, no navigation). Neither is an exit.
- **One uncertainty mechanism, in the dateline** `[T9; CRIT §2]`. `WED 29 JULY · Nothing missing` becomes `· Phone only` and `· Still learning your usual`. There is no confidence percentage, no certainty bar, no range band, no coverage card. Compare with the four simultaneous widgets shipping today.
- **Harm anchor** `[F13]`. The Friday notice ends: *"Doctors do not act on this pattern on its own. It starts to matter if it runs past about a week, or if you begin to feel unwell."*
- **Platform floors.** Body 17px, 11px floor (section labels and axis labels), 44px minimum targets, 4.5:1 contrast in both themes (amber 6.6:1 light / 8.8:1 dark; green 5.3:1; red 5.3:1), real `:focus-visible` rings, `aria-expanded` / `aria-pressed` / `aria-label` on every icon-only control, `prefers-reduced-motion` honoured for the stagger, the marker slide and the skeleton sweep.
- **Thumb zone** `[UX §7]`. Every interactive control is in the lower two-thirds or below the fold. The top cluster is for reading and contains zero tap targets until the `Why` link at its base.
- **Designed on 5.4" first.** At 375 × 812 the fold lands inside slot 3, so slot 1 (verdict + number + cause) and slot 2 (the action) are both fully visible without scrolling.

---

## 5. Which user problems it solves

| Problem | Resolution |
|---|---|
| Three components give three unaware instructions `[CRIT §5]` | Exactly one instruction exists. Verified by sweeping every rendered state for imperative verbs outside the Today slot. Sleep debt does not get its own card giving a fourth instruction — on Wednesday it **becomes** the action `[N1]`. |
| Hero number and chip describe different quantities `[CRIT §4.6a]` | There is no chip. One number, one bar, one comparison, one verdict word, all in the same block. |
| The label lies in the fallback case `[B3]` | Three explicitly different briefs. iPhone-only says `Phone only` in the dateline and puts **steps** in the hero under the label `Steps yesterday` — a real, labelled, lower-confidence answer, never a readiness number under a readiness label. |
| 28 numbers, one verdict `[CRIT §2, §8]` | 12 numbers, and every one of them ships its comparison and a plain-word verdict inside the same element. |
| The best content never reaches Home `[CRIT §6]` | The intelligence-briefing sentence, the real `scoreExplanation` attribution and `buildActionProof` are all on Home. All three were computed every refresh and rendered elsewhere. |
| A "High" warning at position 13, blurred `[CRIT §4.13, §4.17]` | Position 3, in a fixed slot, unhedged, with a harm anchor, never blurred. |
| "The score doesn't match how I feel" — the #1 complaint across four apps `[C2]` | The number never appears without the clause that explains it. `Readiness 62` and `Sleep 1h 28m short of your usual.` are 40px apart. |
| Cold start is universally unsolved `[C8]` | A day-2 brief with the same six slots, an honest hero, no empty ring, no hardware upsell, and a `What opens next` slot that states in plain words what seven nights and two weeks will add. |

---

## 6. Metrics given prominence, and why

| Metric | Placement | Why |
|---|---|---|
| **Time asleep, against personal need** | The cause clause in the hero, and the whole of slot 4 | >90% device sensitivity for sleep vs wake; clock time needs no interpretation `[CL §3.1]`. Compared against `SleepNeedCalculator`'s 7h 40m, never a flat 7.5h — **fixes B6**. |
| **Sleep regularity (bedtime vs your usual window)** | The chart | "The strongest sleep finding of the last three years." UK Biobank n=60,977, mortality HR 0.70, a **stronger predictor than duration**, computed from only the parts wearables get right `[CL §3.3]`. Currently absent from Home. This is the single biggest addition available and the chart is built around it. |
| **Steps against one goal at 7,000** | Slot 5, plus the entire hero in both degraded states | The only metric with umbrella-review behaviour-change evidence; HR 0.53 at 7,000 vs 2,000 `[CL §10.2]`. Anchored at 7,000 with the reason in plain words — **fixes B7's hardcoded 10,000**. |
| **Today's one action + aggregate proof** | Slot 2 | Highest-scoring single component available (2.5) `[§5]`; goal setting on behaviour β=+0.89 `[PSY §10]`. |
| **Readiness 0-100** | Hero number, *not* the largest thing on the screen | Tier 3, kept only under its three conditions: not the largest number (the headline is), no daily delta, labelled a directional summary `[CL §4.2]`. The headline verdict word is 32px; the number is 36px but neutral-coloured, so the *meaning* is carried by the words and the bar, not by the index. |
| **Resting heart rate + heart rate variability, as a two-day co-movement** | Slot 3 on Friday only | Gated exactly as `IllnessEarlyWarning` gates it: ≥2 metrics, ≥2 consecutive days `[CAP §3c; N3]`. Thursday's brief notes RHR is "at the top of your usual range. Not a flag on its own" — day 1 of the streak, correctly silent. Friday's brief fires. The prototype demonstrates the persistence gate across two consecutive days. |

---

## 7. Metrics deliberately hidden or removed, and why

**Removed from Home entirely:** Vitality Age and Pace of Aging (no effect on lifestyle intentions or behaviour, heuristic norm tables, **B11**) `[CL §9.3]` · Stress 0-100 (recall for psychological stress from wearable signals is 50.0% — a coin flip in red; also the word itself is banned) `[CL §5]` · Strain 0-21 (log scale presented as linear steps; session-RPE matches it at r = 0.79-0.86) `[CL §6]` · Brain Health 0-100 (invented composite, unfamiliar name; its circadian ingredient is promoted to the chart instead) · Sleep stages (κ 0.21-0.53, Apple Watch deep-sleep sensitivity 50.7%) `[CL §3.1]` · Daily Health Score as a second index (three indices on one screen is the current failure) · `DataCoverageCard` · `ActivationProgressBanner` · morning check-in · watch-complication tutorial · "CONCIERGE" · weekly-review entry · streak milestone share card · "Patterns found in your data: 12" `[§4 Tier 4]`.

**Demoted to the escape hatch only:** raw HRV in ms. Laso stores **SDNN**, which is not RMSSD, so the plain view labels it `Heart rate variability (SDNN)` and nothing else on the screen ever prints a millisecond value `[CL §1.2]`.

**Never shown at all:** any percentage-as-probability, any forecast confidence figure (`conf 82%` is an interval-width heuristic reading as a calibrated coverage probability `[CAP §6]`), any cohort or percentile, any relative risk, any decimal on a derived index.

**One vocabulary, used everywhere:** *readiness*, *sleep*, *bedtime*, *heart rate variability*, *resting heart rate*, *steps*, *your usual*. Spelled the same way in the hero, the expander, the notice and the plain view. No coined terms, no engineering language.

---

## 8. Expected impact on daily engagement, with the mechanism

**Mechanism: dated novelty inside a fixed frame.** Apple's own widget rule — "if a widget's content never appears to change, people may not keep it in a prominent position" — and the 33x under-attention finding for stable regions `[UX §8, §12]` both say the same thing: sameness of *content* is what kills attention, not sameness of *place*. A brief that is visibly written for today, with a date, a time it was written, and prose that differs morning to morning, is the strongest available defence against banner blindness while keeping the cue-response structure habit formation needs `[PSY §4]`.

**Directional expectation:** session *count* roughly flat or slightly down versus the current screen; session *completion* up. This concept is closer to Athlytic's 10-second, short-session bet than Whoop's dense-scroll 83% DAU/MAU bet `[W §4.3, §1.10]`. It is explicitly not optimised for reopens: there is no live-updating number and no reason to check at 3pm. Ultrahuman earns a 3pm reopen with a real-time score and pays for it with a store block in the same scroll `[W §3.7]`.

**The measurable claim:** a briefing you can act on without reading it should raise *action-completion* rate, because the instruction is above the fold, pre-chosen, and one tap wide. Action completion, not time-in-app, is the number this design is built to move.

---

## 9. Expected impact on retention, with the mechanism

**The constraint is attrition, not cognition** `[UX §12]`: ~53% of mHealth apps uninstalled within 30 days, mean engagement 4.1 days, top stated reason "lack of interest / declining motivation" (31.6%).

1. **Day 1 already looks finished.** First sync pulls 10 years of HealthKit history `[CAP §8]`, so the common new user gets the full brief immediately. The genuinely-new user gets the same six slots with honest content, which is the case every competitor fails `[C8]`.
2. **Nothing is a placeholder.** `applyCoverageAdjustment` pulls sparse users toward a constant 75 and renders it at full confidence (**B4**). This design never shows a readiness number that the data cannot support; it shows steps instead and says so in the dateline. Trust in health tech rises with transparency and collapses with the appearance of fabricated personalisation `[PSY §11]`.
3. **Bad days stay openable.** Every compliance streak eventually teaches users to stop opening the app on bad days, which are the days the app has the most to add `[D7]`. There is no streak, no failure state, and rest counts.
4. **The escape hatch keeps the harmed user installed.** 3.0-14.0% of a general sample already meet an orthosomnia definition `[CL §3.5]`. One tap turns every score and verdict off and leaves the measurements. That is a retention mechanism as much as a safety one.
5. **The layout will not be redesigned out from under them.** The loudest single complaint in the niche teardown is not about any layout, it is about layouts changing `[N §12.6]`. Six fixed slots, forever; the writing is what changes.

---

## 10. Honest drawbacks, and who this design fails

**It fails the data-maximalist.** A Whoop or Ultrahuman power user who wants six numbers before breakfast gets one number and 12 total. Whoop's dense scroll earns 83% DAU/MAU, roughly 3-10x category `[W §1.10]`, and this design deliberately declines that trade. Those users will find Home thin and live on Explore.

**It is the most translation-fragile concept of the ten.** Its identity is prose. A headline that must survive German compounds, Japanese line breaking and AX5 Dynamic Type at 375px is a real, recurring, per-string engineering cost that a ring does not have. Every day's copy has to be written by the templating layer and every template has to hold at every size in every language.

**Voice is a permanent editorial liability.** Slot 3 is 2-3 sentences of prose assembled from `TodayIntelligenceEngine`, and the difference between "authored" and "templated" is a handful of words. Three authored mornings prove the voice *can* vary; production has to prove it varies for 365. If it does not, this becomes exactly the AI paragraph the brief bans, just written by a rule engine instead of a model.

**A prose lede is slow for a low-literacy reader.** ~40% of US adults have inadequate graph literacy and ~1 in 3 have low graph *and* low numeracy `[CL §11]`. The bar and the headline are built for them; slot 3 is not, and they will get less out of this screen than out of a pure-visual concept.

**It reports on yesterday.** The movement slot is deliberately about yesterday, because at 6:45am today's step count is honestly near zero and a bar at 3% is a demoralising thing to wake up to. Users who open at 9pm wanting today's progress will not find it here without the Live tab.

**"Readiness" is still on the screen at all.** It is Tier 3, no manufacturer discloses its weights, none is validated against clinical outcomes, and in D1 swimmers it tracked perceived recovery *worse than its own raw HRV input* `[CL §4.2, §4.3]`. This concept keeps it because T4's mandate is a native index, and it constrains it hard — not the largest element, no delta, labelled a directional summary, always paired with a borrowed-unit cause in hours. A stricter reading of F5 would delete it and make time-asleep the hero. That is a defensible alternative and this concept did not take it.

**The escape hatch is a cliff, not a dial.** It is all-or-nothing. A user who wants readiness off but steps on has to choose between the whole brief and the whole raw list.

---

## 11. Five-questions scorecard for every component

**Q1** what is happening · **Q2** good or bad · **Q3** why · **Q4** what to do · **Q5** what happens if I follow it.
Rule: anything scoring zero is cut.

| # | Component | Q1 | Q2 | Q3 | Q4 | Q5 | Score |
|---|---|:--:|:--:|:--:|:--:|:--:|:--:|
| 1a | Dateline + confidence phrase | ◐ | · | · | · | · | **0.5** |
| 1b | Headline verdict word | · | ✔ | · | · | · | **1** |
| 1c | `Readiness 62` + positional rule + one range | ✔ | ✔ | · | · | · | **2** |
| 1d | Cause clause (`Sleep 1h 28m short of your usual.`) | ✔ | ◐ | ✔ | · | · | **2.5** |
| 1e | `Why` expander (3 named factors vs personal baseline) | ✔ | ✔ | ✔ | · | · | **3** |
| 2 | **Today** — instruction + 2 buttons + aggregate proof | · | · | ◐ | ✔ | ✔ | **2.5** |
| 3 | **Overnight** / health notice + harm anchor | ✔ | ✔ | ✔ | · | · | **3** |
| 4 | **Seven nights** — interpretation + chart + caption | ✔ | ✔ | ✔ | · | · | **3** |
| 5 | **Yesterday** — steps bar vs one goal range | ✔ | ✔ | · | · | ◐ | **2.5** |
| 6a | Sign-off line | ◐ | · | · | · | · | **0.5** |
| 6b | Escape hatch → plain numbers | ✔ | · | · | · | · | **1** |

Two components score below 1. **1a** is kept because it is the screen's single uncertainty mechanism (T9) and it qualifies every number below it — deleting it means either zero honesty mechanisms (the Bevel failure) or putting one back somewhere worse. **6a** is kept because "written at 6:04 am from last night's data" is the whole product claim of this concept in nine words, and it is the cheapest block on the screen. Both are disclosed rather than argued away.

---

## The ten tensions, resolved

| | Tension | Side taken |
|---|---|---|
| **T1** | Score-first or action-first | **Verdict first, then action.** Headline + number is slot 1; the single instruction is slot 2. The verdict does not tell you what to do and the action never restates the score — the failure mode in `[CRIT §5]` is structurally impossible because only one component holds an imperative verb. |
| **T2** | One hero number or a cluster | **One**, embedded in the headline block, no ring, no dials. Athlytic's side of the Oura split `[W §2.8]`. |
| **T3** | Graded verdict or a band you sit inside | **Graded in words, three grades, but the bottom band refuses to grade degrees of bad.** `Strong` / `Steady` / `Below your usual` — the last is a location statement, following Oura's single wide 0-69 band `[W §2.4]`. No emotion is not the safe answer, so the verdict word is coloured; but the colour is redundant with position and words `[T3; F14]`. |
| **T4** | Borrowed unit or native index | **Native index, meaning carried by the headline and by borrowed units underneath.** `Readiness 62` is the index; `Sleep 1h 28m short` and `8,400 steps` are the units the user already owns. The index never appears without a borrowed unit explaining it. |
| **T5** | Explanation inline, one tap, or a paragraph | **Inline clause + one in-place expander.** The cause is on the hero at 17px; three named contributors are one tap and zero navigations away. Not a router of five tappable rows `[CRIT §4.6]`. |
| **T6** | Celebration or calm | **Calm, with one quiet acknowledgement.** A green tick and `Logged at 9:41 am. Tomorrow's brief will say whether it helped.` No confetti, no streak, no share. |
| **T7** | Density or scroll | **Medium: one screenful plus a short tail.** Three blocks above the fold, three below, and it ends. Not Whoop's endless scroll, not Google's "huge block of empty space" `[P §3.8]`. |
| **T8** | Fixed slots or contextual morphing | **Fixed slots, content written fresh daily.** The slot sequence never changes; slot 3 escalates to the health notice in place. This is the strongest available answer to F17 because novelty comes from the writing, not from moving furniture. |
| **T9** | Honest uncertainty or confident simplicity | **Exactly one honesty line, in the dateline.** `Nothing missing` / `Phone only` / `Still learning your usual`. One mechanism, not four `[CRIT §2]`, not zero `[W §5.8]`. |
| **T10** | Opinionated hierarchy or user pinning | **Opinionated.** No customisation, no reorder, no optional hero. "An optional hero is not a hero" `[C7]`. The one autonomy affordance is the escape hatch, which turns the opinion off entirely rather than letting the user rearrange it. |

---

## Budget counts — literal, measured on the rendered default morning

Default morning = Watch data, Wednesday 29 July, loaded, `Why` collapsed. Counted from the actual generated DOM, not by eye.

| Budget | Limit | This concept | |
|---|---|---|---|
| Cards above the fold | ≤ 3 | **3 blocks in 1 sheet** | ✅ |
| Total blocks | ≤ 7 | **6** (5 sheet sections + sign-off) | ✅ |
| Numbers on screen | ≤ 12 | **12** | ✅ (at limit) |
| Numbers above the fold | ≤ 5 | **3** | ✅ |
| Tap targets | ≤ 8 | **8** (4 content + 4 tabs) | ✅ (at limit) |
| Distinct exits from Home | ≤ 6 | **3** (Live, Explore, Settings) | ✅ |
| Disclosure levels below Home | ≤ 2 | **2** (`Why`, plain numbers) | ✅ |
| Uncertainty widgets per number | 1 | **1** (dateline) | ✅ |
| Reference ranges per number | exactly 1 | **1** (personal, on both bars) | ✅ |
| Words of copy above the fold | ≤ 20 | **24 prose words** | ⚠️ over by 4 |

**The 12 numbers, itemised:** `62` · `1h 28m` · `10:30` (tonight) · `6` (times) · `4` (points) · `40` (minutes) · `8,400` · `7,000` · `6:04 am` · `10 PM` and `6 AM` (chart axis, 2) · `29` (the date). Nothing else on the screen is a digit. `7,000` renders once. The three `Why` rows add `6 h 12 m` and `7 h 40 m` when expanded, which is a disclosure, not the default state.

**The 8 tap targets:** `Why` · `Mark done` · `Remind me tonight` · `Show plain numbers instead` · Today · Live · Explore · Settings. The dev toolbar is excluded, per spec.

**Other states:** plain-numbers mode 5 tap targets, loading 4, empty 5.

### Budgets exceeded, honestly

**1. Words of copy above the fold: 24 against a limit of 20.**
On a 5.4" viewport (375 × 812) the fold falls inside slot 3, so the visible prose is:

- headline `Steady, short night.` — 3
- clause `Sleep 1h 28m short of your usual.` — 5
- action `Start winding down at 10:30 tonight.` — 5
- proof `Done 6 times before. Your readiness averaged 4 points higher the next morning.` — 11

The overage is entirely the proof line. It stays because `[§5]` ranks "action + aggregated proof, in one card" as the highest-scoring single component available (2.5), and progress monitoring is the best-evidenced item in the whole psychology corpus (d+ = 0.40, N=19,951) `[PSY §9]`. Cutting 4 words from it costs more than the overage. **Excluding it, above-fold prose is 13 words**, and the budget's intent — that nothing must be read before the verdict lands — is met absolutely: the verdict, the number and the bar are readable with zero words consumed.

Counting *every* visible token above the fold, including the dateline, the two section headings, the bar's range label and the four control labels, the number is **38**. Those are labels the brief separately mandates (layer-cake headings `[UX §6]`, the personal goal range label `[F12]`, button labels), so they are reported separately rather than folded into the copy budget.

**2. Numbers on screen and tap targets are both exactly at the limit, not under.** No headroom. Any future addition to this screen has to remove something first, which is the point.

**Nothing else is over.** No ban in §3 is violated: swept programmatically across all nine data-state combinations for banned vocabulary, percentages, probability language and imperative verbs outside the Today slot.

---

## What ships in the prototype

- iOS status bar, iOS large-title collapse into a compact header on scroll, 4-tab bar with the active tab highlighted, press states on every control (`scale` in at `easeIn 80ms`, spring out), staggered "fresh print" entrance, `prefers-reduced-motion` fully honoured.
- Light and dark from `prefers-color-scheme`, plus an explicit override. All colours, radii, spacing and type from `DESIGN-TOKENS.md` verbatim.
- Two hand-built SVG charts sharing one bar grammar: a seven-night sleep chart drawn on a 10 PM - 8 AM clock axis with the usual-bedtime window as a shaded column, and a seven-day steps chart with the goal range shaded.
- **Three hero states in the same six slots:** full wearable data, iPhone-only (`Phone only`, steps hero, no readiness anywhere), and genuinely new (`Still learning your usual`, 2 recorded nights + 5 dashed outlines, no fabricated baseline).
- **Three authored mornings** proving the voice varies: Wednesday's short night and bedtime drift, Thursday's recovery and a training instruction, Friday's below-usual reading plus the two-signal health notice at position 3 with a harm anchor. Thursday's brief deliberately does *not* flag the resting heart rate that Friday's brief flags — day 1 of a 2-day gate, correctly silent.
- Loading state ("Writing this morning's brief"), empty state (no name, no greeting, no fake numbers, one working button that runs the load).
- A working one-tap escape hatch that turns every score and verdict off and shows the raw measurements, including the SDNN label, with a way back.
- An unobtrusive dev toolbar (theme · screen state · hero data source · which morning), excluded from the design being judged.
