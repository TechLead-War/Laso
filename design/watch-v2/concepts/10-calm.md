# Concept 10 — Autonomic (`calm`)

Prototype: [`10-calm.html`](10-calm.html) · Alex, Tuesday 14:32 · Stress 41/100, moderate, rising since 11:00.

Evidence strength is marked on every claim: **A** = peer-reviewed measurement or first-party
platform documentation · **B** = vendor documentation or reproducible product behaviour ·
**C** = single reviewer, inference, or snippet-level. Every URL below appears in
`research/`. Nothing is invented.

---

## 1. One-sentence philosophy

**Stress is the only health signal on this wrist that a person can change in the next sixty seconds,
so the watch's job is not to report it — it is to show the slope and hand over the intervention.**

---

## 2. The question it answers first, and why

> **"Is my stress going up right now, and do I want to do something about it?"**

Not *"what is my stress"*. A level is not actionable — 41 out of 100 tells Alex nothing he can act
on, because he has no idea whether his usual 2 pm is 25 or 45. A **slope** is actionable, because
it is self-referential: it compares Alex to Alex, an hour ago.

This is Garmin's structural insight, taken literally. The Body Battery glance is "your current Body
Battery level **and a graph of your Body Battery level for the last several hours**" — the graph
answers "am I going up or down right now", which a static number structurally cannot
(**B**, https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html).

The question was chosen because it is the only health question on the wrist whose answer has a
**60-second remedy attached**. Readiness, sleep debt, VO₂ max and vitality age are all true and all
useless at 14:32 — nothing the user does in the next minute moves them. Stress is different, and
Garmin already ships the proof: its Stress glance goes from "you are stressed" to a Breathwork
activity in **one press**
(**B**, https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-DD8EE575-CC72-4829-B4C8-4BE1F8D3473E.html).

---

## 3. Screen-by-screen reasoning, element by element

### The number system, first — because every surface depends on it

Three inverted bands, one table, shared by phone and watch:

```
 0 – 33   "Calm"      #33C48D
34 – 55   "Moderate"  #E3B45A
56 – 100  "High"      #E05C64
```

Three, not four, because the median smartwatch session is **exactly 5.0 seconds** and a fourth label
costs a discrimination the user cannot afford
(**A**, https://www.kostakos.org/papers/chi17.pdf). Alex at 41 → **Moderate**, amber. Inverted
because stress is the only Laso score where high is bad.

The intra-day line comes from one formula, reproduced verbatim from `Core/Analysis/StressScorer.swift`:

```
score = clamp( (0.6·hrvDeviation + 0.4·hrElevation) / 0.5 × 100 , 0, 100 )
```

Alex: HRV 48 vs baseline 56, RHR baseline 55, current-bucket mean HR 71.4 → **40.4 → 41**. Because
last night's HRV is fixed for the whole day, the line collapses to
`score(HR) = 17.16 + 1.4545 × (HR − 55)`. §15.1 does not hide what that means.

**One implementation decision the prototype makes and the reader should check:** the band is read
off the **unrounded** score and the number is rounded only for display. The 11:40 bucket is 33.16 —
Moderate — and would flip to Calm if banded off the rounded 33, which would move the trend sentence
to "Rising since 11:40". The prototype carries a runnable `selfCheck()` that throws in the console
if that ever regresses.

### S1 — Now (entry screen, `laso://stress/now`)

| Element | Why it exists | Why it is that shape |
|---|---|---|
| **Header `Moderate 41`** | Never ship a bare number (**A/B**, https://support.google.com/fitbit/answer/14236710?hl=en). The word carries the verdict, the number carries the comparability. | Word first, left-aligned, band-coloured; number second in `textPrimary`. Reading order matches decision order. |
| **Freshness dot** | Publish staleness in-product or inherit Bevel's public bug thread (**B**, https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match · https://athlytic.github.io/athlyticapp/troubleshooting/). | 6pt filled `optimal` under 24 h, hollow ring beyond. Only the *calibration* ages, never the live bars. |
| **The line (hero, 188 × 96)** | The product. 24 bars × 20 minutes = the last 8 hours. | **Bars, not a line.** A line interpolates across a gap and thereby invents data. Alex's day has one gap (07:20, shower), one movement exclusion (12:20, HR peak 141) and one sleep stub (06:40). Bars can render all three honestly; a line cannot. |
| **Two band rules at 34 and 56** | The R18 non-colour verdict carrier. | 1pt `borderLow`, full width. "The line is sitting in the middle stripe" **is** "Moderate" — readable on an inverted watch face and by a colour-blind user. These are not decoration and must never be dropped for visual cleanliness. |
| **Per-bar band colour** | "Rising" becomes legible as a **colour change along the x-axis** before a single digit is read. | Morning green → 11:20 onward amber. This is the whole 5-second read. |
| **Current bar cap** | Answers "which one is now" without an axis label. | 2pt `textPrimary` across the top edge of bar 24. |
| **Exclusion glyphs** | Garmin ships exactly this: "Gray bars indicate times when you were too active to determine your stress level" (**B**, same Body Battery page as above). | Moving/asleep = 3pt neutral stub at the baseline. Gap = a 1pt tick **below** the baseline and nothing above it, because a short bar would read as "low stress", which is a lie. |
| **No axis labels** | Apple: "Strive to make your detail view so unmistakable at a glance that it doesn't need a title" (**A**, https://developer.apple.com/videos/play/wwdc2023/10138/). | The trend sentence carries the only time reference the screen needs. |
| **Trend sentence `Rising since 11:00`** | Generated by a rule, not written by hand, so it stays true in every state and at both canvas sizes. | `T` = most recent bucket in a lower band; if `current − score(T) ≥ 8` → "Rising since T". Alex: 41 − 29 = 12 → 11:00. |
| **`Breathe · 60s` button** | Give the verdict screen exactly one action and make it the obvious next step (**B**, https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface). | Full width × 44pt, `wind` glyph, carries `.handGestureShortcut(.primaryAction)`. The cost is in the label: "60s", not "start a session". |
| **`Why` row** | Kills the black-box failure (**B**, https://www.autonomous.ai/ourblog/bevel-app-review). | 22pt visual, **44pt hit area**. Deliberately quiet: it is the second-most-important thing on the screen and must not compete with the button. |

**Text lines: 4.** "Moderate 41" · "Rising since 11:00" · "Breathe · 60s" · "Why".

### S2 — Session (`laso://stress/breathe`)

Removes decisions on purpose. Phase word, breathing circle, a **linear** progress bar and a countdown.

The progress bar is a bar and not a ring for two reasons: never two rings on one screen, and radial
encodings cost 1548–1772 ms to read against a bar's 159–285 ms
(**A**, https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf).
The circle already owns the round shape.

**No extended-runtime session is used at all.** A frontmost app survives roughly two minutes after a
wrist drop, so a 60-second session fits inside the free window. Apple permits an app **one** extended
runtime session type, forever (**A**, https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions);
spending Laso's only slot on a breathing timer would permanently foreclose a smart alarm or physical
therapy session. This costs nothing and keeps the slot free.

**Handoff to Apple's Mindfulness app was considered and rejected.** The only documented competitor
flow in the research set is Welltory's, and it *instructs the user to open Breathe manually* — it
does not deep-link (**B/C**, https://help.welltory.com/en/articles/4241383-taking-measurements-with-your-apple-watch).
No public watchOS launch mechanism for Mindfulness appears anywhere in the research, and this
document will not specify an API it cannot cite. The handoff would also destroy the before/after HR
delta on S3, which is this concept's entire trust mechanism.

### S3 — After

Appears at t = 105 s: 60 s of session, then a 45 s measurement window. Proves the minute did
something, **or admits it did not**.

The no-change variant is mandatory, not optional. If HR did not fall, the hero renders in
`textPrimary` (never a band colour — an unchanged heart rate is not a failure), row 3 reads
`No change yet. Normal.` with a **dash glyph, not a triangle**, and the haptic is `.success`, never
`.failure`. Punishing someone for a physiological non-response is the exact anxiety loop this concept
exists to avoid. A score that contradicts felt state is worse than no score
(**B/C**, https://www.dcrainmaker.com/2021/11/whoop-platform-review.html).

Sensor-failure variant (< 10 HR samples in the window): `–– → ––`, `Could not read your heart rate`,
and row 4 **still** reads `1 mindful minute saved to Health` — because that part is true regardless.

### S4 — Why

Two contributors, ordered by weight, each against its own baseline: HRV (60%) and Resting HR (40%).
Progressive disclosure of "why" is the pattern every studied product uses — Garmin puts the factor
list at 3 presses, Fitbit at 2 taps
(**B**, https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html).

Each row uses a **horizontal position band with a marker**, the encoding `DESIGN-TOKENS.md`
prescribes for "position inside a target range", and a bar rather than a ring for the read-time
reason above. `Baselines from iPhone · 14:12` is mandatory: the prototype spec requires phone-sourced
values to be visibly sourced. That string attributes; it does not instruct, and it is not a
paraphrase of the banned string.

### S5 — Quiet

The "big friendly toggle to hush stress for a while" a reviewer explicitly asked for after Athlytic's
stress alerts "increase anxiety rather than help"
(**C**, https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/).
Three full-width 44pt targets — the maximum a 162pt-wide screen may hold. Each sends
`WatchCommand.hushStressAlerts` so the **phone stops its own stress notifications too**; a hush that
silences one device is not a hush. Apple ships a precedent: a Smart Stack hint can be swiped down to
mute for 24 hours (**B**, https://support.apple.com/guide/watch/see-widgets-in-the-smart-stack-apdecf142fb9/watchos).

### Navigation model

`NavigationStack`, depth 2, plus two modals. No `TabView`, no scroll view anywhere.

```
S1 Now ──push──▶ S4 Why ──sheet──▶ S5 Quiet
   └──fullScreenCover──▶ S2 Session ──replace──▶ S3 After ──▶ S1
```

Vertical `TabView` pages are what R10 nominally prefers, and they are rejected here because R11
forbids the combination this concept requires: "Avoid setting a primary action in views with lists,
scroll views, or vertical tabs"
(**A**, https://developer.apple.com/design/human-interface-guidelines/gestures). This concept's
entire thesis **is** a primary action. A vertical tab would trade the core interaction for a page dot.

Every screen is a fixed single screen height at both 46mm and 40mm, so nothing at depth 2 can strand
anyone, and every complication deep-links to depth 0.

---

## 4. Why this works on a watch specifically

Four things are strictly worse on a phone:

1. **The sensor is on the wrist.** The 20-minute HR buckets, the movement exclusions and the
   before/after delta are all watch-native. On a phone every one of them is a sync artefact.
2. **The intervention is haptic, not visual.** The 60-second session is paced by 18 `.click`
   haptics ≥1 s apart. It works with the screen dark and the eyes closed — which is why it survives
   Always-On, and why it can be done in a meeting. A phone cannot pace breathing through a pocket.
3. **The prompt is ambient.** The rectangular complication turns amber on the face with no push
   involved. **82.3% of watch sessions are self-initiated**; only 9.4% of notifications yield any
   session (**A**, https://www.kostakos.org/papers/chi17.pdf). The face is the cheap channel; the
   phone has no equivalent.
4. **The cost of a look is near zero.** A checking habit is "brief, repetitive inspection of dynamic
   content quickly accessible on the device" (**A**, https://link.springer.com/article/10.1007/s00779-011-0412-2).
   Unlocking a phone is not quickly accessible.

What is **worse** on the watch, honestly: the 24-bar chart is 188pt wide, so each bar is 6pt. At
AX1+ Dynamic Type the chart is replaced by three stacked text rows rather than shrunk into texture
(see §15).

---

## 5. watchOS HIG guidance applied

| Rule | Applied where | URL |
|---|---|---|
| R1 · interactions are seconds | 4 text lines per screen; 3 bands not 4; no axis labels | https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos |
| R2 · the app is not the product | Complication + widget carry the concept; the app is the detail view | https://developer.apple.com/documentation/watchos-apps |
| R3 · only 2 families reach the Smart Stack | Rectangular only in the Stack; Inline and Circular are face-only | https://developer.apple.com/design/human-interface-guidelines/widgets |
| R4/R5 · refresh budgets | 30-min timeline = 48 reloads/day; one background task serving both timeline reload and the N1 rule | https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date · https://developer.apple.com/documentation/watchkit/wkapplicationrefreshbackgroundtask |
| R6 · watch HealthKit reaches ~7 days | 7-day per-hour median comparator; 7-day fallback baseline; 14-day baselines stay on the phone | https://athlytic.github.io/athlyticapp/troubleshooting/ |
| R7 · redact health data in Always-On | Bar **heights** destroyed, colour destroyed, 41 → `––`, trend → `Raise to view`, button fill → stroke | https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state · https://developer.apple.com/documentation/swiftui/environmentvalues/isluminancereduced |
| R8 · never fire a haptic while sampling HR | The whole §11 sequence. **S1 deliberately shows no live BPM**, which is what makes crown detents legal on the entry screen | https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:) |
| R9 · background execution is never guaranteed | N1 can lag a real rise by up to 45 minutes; the designed fallback is the widget | https://developer.apple.com/documentation/watchkit/using-background-tasks |
| R10 · anchor navigation to the crown; crown press reserved | Crown scrubs time along the line — Apple's second endorsed crown pattern, "a great tool to inspect data"; no close button on S2 | https://developer.apple.com/design/human-interface-guidelines/digital-crown |
| R11 · primary action conflicts with lists/scroll/vertical tabs | `NavigationStack` over `TabView`; S1 and S4 fixed-height at both sizes | https://developer.apple.com/design/human-interface-guidelines/gestures |
| R12 · relevance is a different API on watchOS | `TimelineProvider.relevance()` + `RelevantContext`; `TimelineEntry.relevance` never set | https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks · https://developer.apple.com/documentation/relevancekit/relevantcontext |
| R13 · no spinners | Loading = 24 skeleton bars at 8pt, no animation, no shimmer | https://developer.apple.com/design/human-interface-guidelines/feedback |
| R14 · static surfaces get deleted | The complication visibly changes every 30 minutes; that is the argument for the face slot | https://developer.apple.com/design/human-interface-guidelines/widgets |
| R15 · sizes, type and touch floors; one deep link per complication | Three families, three destinations; no target under 44pt; nothing below 11pt | https://developer.apple.com/design/human-interface-guidelines/widgets · https://developer.apple.com/design/human-interface-guidelines/layout |
| R16 · extended runtime is single-type | 60 s session uses **none** | https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions |
| R17 · short look is not a channel; no sensitive info in the title | N1's title carries zero health data; `Breathe 60s` is the first nondestructive action | https://developer.apple.com/design/human-interface-guidelines/notifications |
| R18 · colour alone can never carry meaning | Band rules + bar height + word + glyph everywhere; colour is the fourth channel | https://developer.apple.com/design/human-interface-guidelines/widgets |

---

## 6. UX principles used, and the mechanism

| Principle | Mechanism | Evidence |
|---|---|---|
| **Show a slope, not a level** | A slope is self-referential, so it needs no population norm and no memorised baseline | **B** — https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html |
| **Bars, not rings, for anything compared** | Perceptual read time is the binding cost inside a 5 s session: 159–285 ms vs 1548–1772 ms | **A** — https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf |
| **Never ship a bare number** | Value + label + sentence, so the verdict survives being read at 28 cm and 10° off-axis | **A/B** — https://support.google.com/fitbit/answer/14236710?hl=en · https://www.kostakos.org/papers/chi17.pdf |
| **One scale, one band vocabulary** | 0–100 reused from `StressScale`; the same three bands on both devices, from one file | **B** — https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score |
| **Progressive disclosure of "why"** | Verdict at 0 taps, contributors at 1, the hush at 2. Black-box scores are a named product failure | **B** — https://www.autonomous.ai/ourblog/bevel-app-review |
| **Name the cold start, never fabricate** | Garmin ships "No Status"; Oura needs 5 days for Daytime Stress; Fitbit 7 nights | **B** — https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-6F81BF5B-B49A-4506-95E2-0F4A04D8B319.html · https://support.ouraring.com/hc/en-us/articles/21205822135315-Daytime-Stress · https://support.google.com/fitbit/answer/14236710?hl=en |
| **Publish staleness in-product** | Athlytic documents its cap and pre-empts the ticket; Bevel does not and carries a live bug thread | **B** — https://athlytic.github.io/athlyticapp/troubleshooting/ · https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match |
| **One action on the verdict screen** | Removes the choose-what-to-do step, which is the step people skip | **B** — https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-DD8EE575-CC72-4829-B4C8-4BE1F8D3473E.html |
| **Positional verdict, not colour** | Gentler Streak encodes judgement as position inside a band; the two band rules do the same job here | **B** — https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path |
| **A score that contradicts felt state is worse than no score** | Movement/sleep/gap exclusions; the mandatory no-change variant on S3 | **B/C** — https://www.dcrainmaker.com/2021/11/whoop-platform-review.html |

---

## 7. Psychological principles that drive repeat opens

| # | Mechanic | Evidence strength | Mechanism | How it is used here |
|---|---|---|---|---|
| 1 | **Dynamic content at near-zero access cost** | **strong: peer-reviewed** — https://link.springer.com/article/10.1007/s00779-011-0412-2 · https://www.kostakos.org/papers/chi17.pdf | Adding real-time information to a previously static screen *caused* checking behaviour to emerge | The complication and widget change every 30 minutes. A readiness complication is static for 23 hours and cannot form a checking habit at all. This is the whole face-slot argument. |
| 2 | **Surviving the first 8 days** | **strong: peer-reviewed** — https://arxiv.org/pdf/1910.01165 | >50% of health-app users quit in week 1; the sub-cohort alive at day 8 gained **+25 days** median retention | The cold-start state (§9.2 of the design spec) is a *working* uncalibrated wrist surface on day 1 — today's HR plotted as bpm — not an empty promise. |
| 3 | **Uncertainty about the outcome** | **strong (mechanism), inferred (application)** — https://pubmed.ncbi.nlm.nih.gov/12649484/ | Sustained anticipatory dopamine scales with uncertainty, maximal at P = 0.5 | The line genuinely cannot be predicted since the last glance. It is **never** faked to create variance — a fabricated value would trip the "contradicts felt state" failure and cost more than the variance is worth. |
| 4 | **Delta-triggered notifications** | **strong on the near-term effect, strong that it is not retention** — https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf · https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/ | 3.5× next-hour lift, 1.04–1.3× at 24 h, **no measurable long-term retention effect**; best slot 12:30 pm (+8.8%) | Exactly one notification exists, capped at 1/day, and it is budgeted as a near-term conversion device — never as a retention knob. |
| 5 | **Goal gradient** | **strong: peer-reviewed** — https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf | Effort scales with the proportion of remaining distance | Used **once, deliberately narrowly**: the S2 progress bar over 60 seconds. It is not used on S1, because a stress "goal" would imply the user has failed on a bad day. |
| 6 | **Streak / loss aversion** | **medium: vendor A/B** — https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/ | Loss aversion on accumulated progress; Streak Wager +14% D7 | **Rejected.** A stress streak rewards *being calm*, which punishes hard days and makes the app hostile exactly when the user needs it. Gentler Streak ships manual "On a Break / Sick / Injured" states specifically to escape this trap. |
| 7 | **Resumption cue (Zeigarnik)** | **mixed: meta-analysis, snippet-level** — https://www.nature.com/articles/s41599-025-05000-w | The memory half fails to replicate; only Ovsiankina resumption is reliable | **Not claimed anywhere.** No "unfinished thing" mechanic exists in this concept. |
| 8 | **Committed measurement session** | **weak/structural** — https://help.welltory.com/en/articles/4241383-taking-measurements-with-your-apple-watch | Scarcity plus ritual | Partially used: S2 is a committed 60 s, but it is not gated by a quota and it is not a measurement — it is an intervention that happens to be measurable. |

**The honest counterweight**: 82.3% of watch sessions are self-initiated and only 9.4% of
notifications yield any session (**A**, https://www.kostakos.org/papers/chi17.pdf). So this document
declares, **against the concept brief's own "Notification + Smart Stack" framing**, that the
**Smart Stack widget is the primary surface and the notification is the rare escalation**. Building
it the other way round would put the concept on the smaller half of the platform's traffic.

---

## 8. Complication strategy

Three families, three deep links. Apple: "Define a different deep link for each complication you
support… If all the complications you support open the same area in your app, they can seem less
useful" (**A**, https://developer.apple.com/design/human-interface-guidelines/widgets).

### `accessoryRectangular` → `laso://stress/now` → S1 — **the flagship, recommend this one**

Line 1 `Moderate 41` · line 2 a **12-bar sparkline** of the last 4 hours with both band rules drawn ·
line 3 `Rising since 11:00` in low-contrast grey. Apple's own exemplar for this family is a 24-hour
heart-rate **graph**, not a ring.

**Why a user gives up a face slot:** it is the only complication on the face that answers "how am I
doing right now" instead of "what happened last night", and it **visibly changes every 30 minutes**.
Apple's warning is explicit — a static complication "may be less likely to remain in a prominent
position" — and the checking-habit literature says a value that is static for 23 hours cannot form a
habit at all (**A**, https://link.springer.com/article/10.1007/s00779-011-0412-2).

### `accessoryCircular` → `laso://stress/why` → S4 — the fallback

Closed `Gauge`, 0–100, arc in the band colour, **two ticks etched into the track at 34 and 56** so
the band boundaries survive without colour (R18). A single hero value absorbed rather than compared
is the one case `DESIGN-TOKENS.md` permits a circular arc.

**Why a user gives up a face slot: honestly, most should not.** A ring cannot show slope, and slope
is this concept's product. This family exists for faces with no rectangular slot free — Infograph
corners, California, Chronograph Pro. That should be said in onboarding rather than pretended away.

**Why it opens S4 rather than S1:** a bare ring on a face provokes exactly one question — "why is it
that?" — so the tap should answer that question, not dump the user on the screen the rectangular one
already opens. That is R15's intent, not just its letter.

### `accessoryInline` → `laso://stress/breathe` → S2, session already running

`Stress 41 rising` with a leading `wind` glyph. Inline has exactly **one** tap target
(**A**, https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline), so it must
spend it on the single highest-value thing: Garmin's one-press bar delivered from the watch face at
zero taps.

**Honest risk**, flagged again in §15.7: a user who taps a number expecting a detail screen gets a
breathing session. The `wind` glyph and a 700 ms pre-roll help; some users will still be startled.

### `accessoryCorner` — deliberately not shipped

A fourth family showing the same integer earns nothing, demands a fourth destination that does not
exist, and dilutes the recommendation. Ten named complications with no published thresholds for any
of them is Bevel's mistake (**B**, https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249).

---

## 9. Smart Stack strategy

**One widget, `accessoryRectangular` only.** Circular is not shipped to the Stack because the Stack
is the slope surface and a ring cannot carry a slope.

**Content** (152 × 69.5 pt at 40mm, 184 × 80.5 at 46mm): header `Moderate 41` · a 16-bar / 24-bar
sparkline with both band rules · footer `Rising since 11:00` on the left and **`14:28` on the right**.
One title plus two body rows, which is what R15 says the box realistically holds.

**The freshness stamp is not optional.** The wrist will disagree with the phone. Athlytic publishes
its cap in-product and pre-empts the ticket; Bevel does not and carries a live bug thread about watch
values being 1–5 points off (**B**, https://athlytic.github.io/athlyticapp/troubleshooting/ ·
https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match).

**Background: 14% alpha of the band colour over black**, not full saturation. Apple's widget guidance
endorses a meaningful coloured background, but a fully saturated amber tile broadcasts a health
verdict to everyone in the room and reads as an alarm every single afternoon. The word `Moderate`
stays the meaning-carrier (R18); the tint is reinforcement only.

**Timeline: 30-minute entries → 48 reloads/day**, inside WidgetKit's 40–70/day budget and well above
the 5-minute minimum entry spacing
(**A**, https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

**Relevance (R12).** `TimelineEntry.relevance` is dead code on watchOS and is never set. The widget
implements `TimelineProvider.relevance()` returning `WidgetRelevance` with three `RelevantContext`
clues (**A**, https://developer.apple.com/documentation/relevancekit/relevantcontext):

| Clue | Window | Why |
|---|---|---|
| `.date(range:kind:)` | 11:00 – 15:00 local | The measured best notification slot is 12:30 pm with an 8.8% lift (**A**, https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/), and it is exactly when Alex's line rises. Converts an intent moment into a self-initiated glance instead of a push. |
| `.sleep(.bedtime)` | evening wind-down | The second moment of the day a stress reading is actionable. |
| `.fitness(_:)` | post-workout | The line is recovering and the shape is genuinely interesting. |

Each clue needs the matching HealthKit permission on **both** the app and the widget extension.

**`RelevanceConfiguration` (watchOS 26+) is deliberately not used.** It allows multiple simultaneous
instances, but Apple states the trade-off outright: people "can't configure widgets that use a
RelevanceConfiguration to appear in the Smart Stack, add them to the Smart Stack, or pin them to a
fixed location" (**A**, https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks).
For a concept whose primary surface **is** the Smart Stack, **pinnability beats multi-instance**.

---

## 10. Notification strategy

### There is exactly one notification in this design.

That is the most important sentence in this section. Absolute-threshold stress alerts are a named
failure — a reviewer asked Athlytic for "a big friendly toggle to hush stress for a while" because
they "increase anxiety rather than help"
(**C**, https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/).
The fix is not gentler copy. It is fewer notifications.

### N1 — sustained rise offer

Fires only when **all** of these hold: current bucket ≥ the median for **this clock hour over the
last 7 days** + 12 · sustained across two consecutive buckets (≥20 min) · neither bucket excluded for
movement, workout or sleep · band is Moderate or High · local time 09:00–21:00 · zero stress
notifications already sent today · hush not active · auto-hush counter < 2.

A **per-clock-hour** comparator, not a flat daily average, because the flat version fires "you are
stressed after lunch" every single day. Seven days because that is exactly what the wrist's own
HealthKit store holds without the phone (R6). The structural idea — fire on **change**, not state —
is Training Today's (**B**, https://apps.apple.com/us/app/training-today/id1507992127).

**Cadence ceiling, enforced in code:** 1 per day · 3 per rolling 7 days · never before 09:00 or after
21:00 · never during or within 30 min of a workout · **auto-hush: two consecutive dismissals without
any action → stop for 7 days, silently.**

**Short look** — the title carries **no health data at all**, not a score, not a band, not the word
"stress", because R17 says to avoid sensitive information in a notification's title
(**A**, https://developer.apple.com/design/human-interface-guidelines/notifications):

```
Laso
A minute if you want it
```

**Long look** — `Higher than your usual 2 pm, for the last 20 minutes.` + an 8-bar sparkline +
`Moderate 41`, then three custom actions (max is four): **`Breathe 60s` first**, because "when a
person responds to a notification with a double tap, the system selects the first nondestructive
action" — so a Double Tap starts breathing with zero taps and no screen read.

**Copy discipline.** "Your stress is high" is a verdict about the person with no remedy — the exact
shape that produced the anxiety complaint. "Time to calm down" is an imperative about a feeling the
user cannot command. **"A minute if you want it"** is an offer with the cost stated and consent built
into the grammar. **"Higher than your usual 2 pm"** is an observation about the data: self-referential,
time-bounded, falsifiable, and it never tells Alex how he feels.

### Deliberately not shipped

| Rejected | Why |
|---|---|
| "You've calmed down" | Pure noise. Doubles the daily push count to deliver zero decisions. |
| Session-complete push | S3 plus a `.stop` haptic already confirm it, in-app, at no notification cost. |
| Auto-hush announcement | A push saying "I will stop pushing you" is self-refuting. It appears as a one-line row on S1 instead. |
| Morning stress report | Overnight "stress" is sleep, which other concepts own. There is nothing true to say at 07:00 (see §15.2). |

---

## 11. Haptic language

Haptics and HR sampling are **time-separated, never concurrent** — "when you engage the haptic
engine, HealthKit stops gathering heart rate data until after the haptic engine finishes"
(**A**, https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)).

| Event | `WKHapticType` | HR sampling at that instant |
|---|---|---|
| Crown detent, one per bucket while scrubbing S1 | `.click` | **none** — S1 deliberately displays no live BPM, which is exactly what makes detents legal here |
| Tap `Breathe · 60s`, or Double Tap | `.start` | suspended |
| Each breath phase change (18 per session) | `.click` | suspended for the whole 60 s; ≥1 s apart, far above the 100 ms floor |
| Session complete | `.stop` | suspended; sampling starts 100 ms later |
| S3 appears, HR fell ≥3 bpm | `.directionDown` | sampling already finished |
| S3 appears, HR unchanged or up | `.success` | finished. **Never `.failure`** |
| S3 appears, sensor failed | `.retry` | finished |
| Tap Mute today / 3 days / off | `.success` | none |
| Band crossed upward while frontmost | `.directionUp` | none; at most once per band per day |
| N1 arrives | `.notification` | system-owned |
| `hushStressAlerts` rejected by the phone | `.failure` | none. Fail loudly — a hush the user thinks worked but did not is the worst failure here |

The sequence that matters, stated as a timeline:

```
t = 0s      .start           HR sampling SUSPENDED
t = 0–60s   .click ×18       HR sampling SUSPENDED
t = 60s     .stop            last haptic of the session
t = 60.1s   engine idle  →   HR anchored query STARTS
t = 60–105s                  sampling, ZERO haptics fired
t = 105s    S3, then one .directionDown / .success / .retry
```

Not used: `.navigation*` and `.underwaterDepth*` — no published semantics for the latter in the
research set, so they are not guessed at.

---

## 12. What was deliberately excluded, and why

| Excluded | Why |
|---|---|
| Readiness, sleep, strain, steps, HR zones, workouts | Nine other concepts own these. Mirroring the phone dashboard is the top anti-pattern and Bevel's reviewed failure (**B**, https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html). The wrist shows one thing. |
| **Live BPM on S1** | R8. Showing live HR would forbid crown detent haptics on the entry screen. The crown scrub is worth more than a second number. |
| A morning report / wake-time push | Overnight "stress" is sleep. This concept has nothing true to say at 07:00. Forfeits the wake-time mechanic knowingly — see §15.2. |
| A "you've calmed down" notification | Doubles push volume to deliver zero decisions. |
| Any streak or stress-free-day chain | A stress streak rewards being calm, which punishes hard days. |
| Handoff to Apple Mindfulness / Breathe | No verifiable watchOS launch mechanism in the research set; loses the S3 delta; cannot run cyclic sighing. |
| A `WKExtendedRuntimeSession` | One type per app, forever. A 60 s session fits in the frontmost window and costs nothing. |
| `accessoryCorner` | A fourth family showing the same integer earns nothing. |
| A circular Smart Stack widget | The Stack is the slope surface; a ring cannot carry a slope. |
| A four-band stress vocabulary on the wrist | Four labels against a 5-second budget. Three bands, one table, both devices. |
| Sub-20-minute buckets | Below 20 minutes HR sample sparsity makes buckets noisy and the line starts inventing texture. |
| Any colour-only encoding | R18, everywhere, without exception. |
| A second ring anywhere | S2's progress is a bar. |
| The phone's `stressScoreNow` as a rendered value | Rendering whichever number arrived last is precisely Bevel's public 1–5-point bug. The wrist computes; the phone calibrates. |

---

## 13. Expected opens per day

App opens means raising the wrist and tapping in — **not** passive complication glances.

| # | Trigger | Time | Mechanism | Est. |
|---|---|---|---|---|
| 1 | Complication turned amber and the user noticed | 11:30–15:00 | Dynamic content at near-zero access cost (**strong**). The colour change on the face **is** the prompt; no push involved. | **0.6** |
| 2 | Smart Stack rotated the widget up on the `.date(range:)` clue | 12:00–14:30 | R12 relevance; best measured slot 12:30 pm, +8.8% (**strong**) | **0.35** |
| 3 | N1 fired and was acted on | once, 09:00–21:00 | 3.5× next-hour lift (**strong**), but the trigger only fires ~2–3 days/week and only ~9.4% of wrist notifications yield any session. Discounted hard. | **0.25** |
| 4 | Smart Stack `.sleep(.bedtime)` clue | 21:30–23:00 | R12 relevance clue | **0.3** |
| 5 | Post-workout `.fitness(_:)` clue | after training, ~3×/week | R12 relevance clue; the line recovering is genuinely interesting | **0.2** |
| 6 | Unprompted deliberate breathing session | any | The only open with no cue behind it. Rarest and most valuable. | **0.15** |
| 7 | **Morning glance** | 07:00 | **None. This concept has no morning trigger.** Listed at zero rather than omitted, because its absence is the concept's biggest structural weakness. | **0.0** |

**Total ≈ 1.85 app opens/day**, plus roughly 6–10 passive complication glances at zero interaction
cost, which is where R2 says the actual value lives.

**Honesty about this number.** The shipping Watch app realistically achieves ~0.3 opens/day — it only
updates when the phone app is opened, and its most common message is a request to go use the phone.
So 1.85 is a **6× improvement claim with no measured basis**. The only component with real evidence
behind it is #3's 3.5× next-hour lift, and that same evidence says the effect does **not** persist
past 24 hours. Everything else is reasoning from the checking-habit literature, which is strong on
mechanism and silent on magnitude. **Do not put this number in a business case.**

---

## 14. Buildability against this codebase

Read from source at commit `cbb674f` (v3.26), this session. Every claim below was verified by opening
the file, not recalled.

### 14.1 What exists today and is directly reusable

| Asset | Where | State |
|---|---|---|
| The scoring formula | `Core/Analysis/StressScorer.swift` | ✅ verified: `hrvWeight = 0.6`, `hrWeight = 0.4`, `deviationAtMaxScore = 0.5`, `StressScale.maxScore = 100`, `hrvDeviation = max(0, (hrvBaseline.mean − currentHRV) / hrvBaseline.mean)`, `hrElevation = max(0, (hr − rhr.mean) / rhr.mean)`. The prototype reproduces 41 for Alex exactly. |
| Baseline computation | `StressScorer.computeBaseline(_:days:)` → `(mean, sd)` | ✅ exists and already returns the SD S4 needs. `baselineWindowDays = 14`, `minimumDaysRequired = 3`. **Both values are computed and then discarded** — emitting them is plumbing, not new maths. |
| Wire format | `WatchShared/WatchBridge.swift` | ✅ 10 fields, `Codable`, App Group `group.com.lasohealth.fit.watch`, `cachedPayloadKey` already used by the complication. |
| Cyclic-sighing phase model | `Modules/Stress/Views/Stress/BreathworkView.swift` and `Shared/BreathworkActivityAttributes.swift` | ⚠️ see 14.4 — the phase *sequence* is reusable, the *durations* are not what the design spec claims. |

### 14.2 The four-band vs three-band conflict — a real blocker, not a nit

`StressLevel` in `StressScorer.swift` is a **four**-band enum with cutoffs at **25 / 50 / 75**
(`.low` / `.mild` / `.moderate` / `.high`). **Alex at 41 reads `.mild` on the phone and "Moderate" on
the wrist.** Shipping both vocabularies is exactly the failure Fitbit shipped — "Low" in PR mockups,
"Good" in the app, and a vocabulary that drifted Low/Good/Excellent → Low/Moderate/High
(**B**, https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html).

**The fix is one file, and it must land before anything else:** move the three-band table into
`WatchShared/StressBands.swift` — a directory both targets already compile — and have
`StressLevel.displayName` resolve through it. Note the knock-on: `StressLevel` also drives
`Copy.StressMonitor.stressLevel*` strings and an icon per case, so collapsing four cases into three
touches the phone's stress UI. **This is the largest single piece of work in the concept and it is
phone-side, not watch-side.**

### 14.3 Seven new `WatchPayload` fields

```swift
let hrvBaselineMean: Double?      // ms.  Alex: 56
let hrvBaselineSD: Double?        // ms.  Alex: 9
let rhrBaselineMean: Double?      // bpm. Alex: 55
let stressScoreNow: Int?          // reconciliation/debug ONLY, never rendered
let baselineComputedAt: Date?     // freshness dot + S4 source line
let baselineDaysUsed: Int         // 0 = cold start
let stressAlertsHushedUntil: Date?
```

All are `Codable`-trivial and all five baseline values already exist inside `StressScorer`.
`stressScoreNow` is carried for reconciliation only. **Rendering whichever number arrived last is
precisely Bevel's public bug** — the wrist's displayed value is always wrist-computed.

Of the ten existing fields, this concept reads **two**: `dayKey` and `updatedAt`. `readinessScore`,
`readinessGrade`, `dayType`, `actionHeadline`, `actionDetail`, `actionIcon`, `actionDone` and
`checkInAvailable` are all unused. **That is the architectural difference: this concept does not read
the phone's verdict, it reads the phone's calibration** — which is why it survives the phone being in
another room for two weeks.

A new `WatchCommand.hushStressAlerts(id:createdAt:until:)` case is needed; the enum already carries
`id` + `createdAt` on every case and the phone already has an applied-ids ledger, so the round trip
is free.

### 14.4 The breathing protocol is **not** a verbatim reuse — the design spec is wrong here

The design spec says "reuse `BreathingProtocol.cyclicSighing` phases verbatim … 6 cycles × 10 s".
The shipping table is:

```swift
case .cyclicSighing: .inhale 2.0 · .inhaleTop 1.0 · .exhale 6.0      // 9 s per cycle, 5 min total
```

**9 seconds, not 10.** The spec's 3.5 / 1 / 5.5 is a new phase table. The prototype implements the
spec's numbers (6 × 10 s = exactly 60 s, matching the `Breathe · 60s` label and the 18-haptic count),
and this is flagged rather than hidden. Ship options: (a) a new 10 s wrist variant, which is what is
built; (b) 7 cycles of the shipping 9 s table = 63 s, which makes the button label a lie. Option (a),
declared as a new constant, not as a reuse.

There is also a **duplicate definition** to resolve: `BreathingProtocol` in `BreathworkView.swift`
and `BreathworkLiveProtocol` in `Shared/BreathworkActivityAttributes.swift` carry the same phase
table twice. The wrist should not become a third copy.

### 14.5 Entitlements and deployment target — two hard blockers

- `LasoWatch/LasoWatch.entitlements` contains **exactly one key**, the App Group. No
  `com.apple.developer.healthkit`. `LasoWatch/Info.plist` has no `NSHealthShareUsageDescription`.
  `project.yml`'s `LasoWatch` target compiles only `LasoWatch`, `WatchShared` and
  `Core/Extensions/Date+Extensions.swift`. **The watch does not link HealthKit at all today.**
  Every native read in this concept — HR statistics collection, HRV, resting HR, steps, workouts,
  sleep — needs the entitlement plus both usage strings on **`LasoWatch` and `LasoWatchWidgets`**,
  and the widget extension needs it too for the `.sleep` / `.fitness` relevance clues.
  `WatchBridge.swift`'s comment ("This file must stay free of … HealthKit") stays true — HealthKit
  goes in new files, not that one.
- `project.yml` sets `WATCHOS_DEPLOYMENT_TARGET: "10.0"`. **`handGestureShortcut(.primaryAction)`,
  `TimelineProvider.relevance()` and `RelevantContext` are all watchOS 11+.** So the Double Tap
  primary action and the entire relevance strategy in §9 require a deployment-target bump to 11.0.
  That is a product decision with an install-base cost, and it is not optional for this concept —
  Double Tap and relevance are two of its three engagement mechanisms.

### 14.6 New phone-side work (3 items)

1. Emit the five baseline fields in `PhoneWatchSession.push()`.
2. **Call `PhoneWatchSession.push()` from somewhere other than the dashboard.** Verified: the only
   call site in the whole repo is `Modules/Dashboard/ViewModels/DashboardViewModel.swift:2265`. This
   concept is unusually tolerant of that bug — baselines are valid for weeks — but the cold-start
   countdown and the hush round-trip both need a background path.
3. Handle `WatchCommand.hushStressAlerts` and suppress phone-side stress notifications for the window.

### 14.7 New watch-side work (4 items)

1. `WristStressLine` — bucketing, exclusions, scoring, trend rule. ~150 lines. Needs
   `HKStatisticsCollectionQuery` at a 20-minute interval over heart rate and step count, plus
   `HKWorkout` and `sleepAnalysis` samples for the exclusions.
2. `HourlyMedian7Day` — the N1 comparator. ~40 lines. Sits exactly at the wrist's ~7-day store limit.
3. The 60-second session plus the `HKCategoryTypeIdentifier.mindfulSession` write. ~120 lines. **No
   WatchConnectivity message** — the loop closes through HealthKit.
4. One `WKApplicationRefreshBackgroundTask` handler doing **two jobs in one task**: reload
   complication timelines and evaluate the N1 rule. Apple budgets "approximately four tasks per hour
   for each app with a complication on the active watch face" and **all complications share that
   budget** (**A**, https://developer.apple.com/documentation/watchkit/wkapplicationrefreshbackgroundtask),
   so with three families shipped one task must serve everything.

### 14.8 The latency this creates, named out loud

With a 20-minute sustain requirement and best-case 15-minute background wakes, **N1 can lag a real
rise by up to 45 minutes**, and delivery is "completely up to the system", throttled hardest when the
user is exercising (**A**, https://developer.apple.com/documentation/watchkit/using-background-tasks).
The designed fallback is the Smart Stack widget: if the task never fires, the notification simply does
not happen and the widget carries the same signal on the user's next self-initiated glance. Apple's
instruction is explicit — design a fallback mechanism.

### 14.9 The one thing I could not verify

Whether a **watchOS widget extension can run `HKStatisticsCollectionQuery` inside its
timeline-generation budget** at a 30-minute cadence. If it cannot, the widget falls back to the App
Group cache written by the app, which means the widget's line would be as old as the last app or
background-task wake rather than live. That would not break the design — the `14:28` freshness stamp
already exists to absorb exactly this — but it would weaken the "changes every 30 minutes" argument
that justifies the face slot. **This should be measured on device before the concept is costed.**

---

## 15. Honest drawbacks, and who this fails

### 15.1 The strongest argument against this concept

**The line is a heart-rate line with a stress label on it, and heart rate goes up for boring reasons.**

Apple Watch does not expose continuous HRV. SDNN samples arrive a handful of times a day, mostly at
rest, so `hrvDeviation` is a **constant for the whole day** and every bit of intra-day movement comes
from bucket-mean HR. That is why the line reduces to `score(HR) = 17.16 + 1.4545 × (HR − 55)`.

And the shared fictional user makes it vivid: **Alex logged caffeine at 11:15, and the line "rises
since 11:00."** The design cannot distinguish caffeine from stress. It will confidently render a
coloured, band-crossing, notification-triggering rise whose actual cause is a coffee. Body Battery
draws exactly this criticism — it "moves for too many reasons unrelated to exercise or readiness —
digestion, posture, caffeine, temperature"
(**B/C**, https://www.androidauthority.com/garmin-body-battery-1209128/).

Mitigations shipped: movement, workout and sleep exclusions; a 20-minute sustain requirement; a
per-clock-hour comparator that learns "Alex's 11:20 is always elevated" within a week and stops
firing. Mitigations **not** available: nothing excludes caffeine, a warm room, standing up, digestion,
a cold, or a beta-blocker. **If the evaluation kills one concept on data honesty, it should be this
one, and this paragraph is why.**

### 15.2 It has nothing to say in the morning

WHOOP, Oura, Garmin and Fitbit all anchor on a wake-time verdict. This concept structurally cannot —
overnight "stress" is sleep, which belongs to other concepts. It forfeits the highest-intent moment
of the day and replaces it with an afternoon that may never arrive. Concepts 01, 02 and 07 beat it on
this axis and will beat it on day-1 impressions.

### 15.3 It fails the person who is not stressed

A calm person sees a flat green line for three weeks, learns nothing, and removes the complication —
after which the app is invisible forever (R14). **This concept has no content for a good day.**
Concept 07 always has something to say; this one is silent by design when things are fine, and
silence is indistinguishable from broken.

### 15.4 It can make anxious people more anxious, and design cannot fully fix that

Every guard in §10 reduces *notification*-driven anxiety. None of them touch the deeper loop: a
visible stress line invites checking, and checking your stress raises your stress. The user who most
wants this feature is the user it most risks harming, and the honest answer is that a hush toggle is
a **mitigation, not a solution**. A truthful onboarding line — "if watching this makes it worse, turn
it off" — is required, and S5 must stay within two taps of S1 forever.

### 15.5 It will visibly disagree with the phone

The phone's `StressScorer` produces one daily number from last night's HRV plus a snapshot HR; the
wrist produces a 20-minute intra-day line. These are **different quantities**. At 20:00 the phone may
say 22 and the wrist 38, both correct, and the user will read that as a bug
(**B**, https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match).
The freshness stamp and the `Baselines from iPhone` attribution reduce support tickets; they do not
reconcile the two numbers. The real fix is for the phone to adopt the wrist's intra-day model, which
is out of scope and should be flagged as a follow-on.

### 15.6 The 60-second dose is platform-shaped, not physiology-shaped

The app's own cyclic-sighing protocol is 5 minutes. 60 seconds was chosen because it fits inside the
frontmost-app window and therefore needs no extended-runtime session. That is a good engineering
trade and an **unproven clinical one**. It must be described in-product as a nudge, never as a
treatment, and must never claim an effect size.

### 15.7 The inline complication surprises people

`Stress 41 rising` that launches a breathing session is a jump. Ship it, watch the immediate-exit
rate on `laso://stress/breathe`, and demote it to `laso://stress/now` if that rate exceeds ~30%.

### 15.8 Who this design fails outright

| Group | Why |
|---|---|
| **Shift workers and frequent travellers** | The 7-day per-clock-hour median is meaningless on a rotating schedule. N1 fires wrongly or never. |
| **People on beta-blockers, with atrial fibrillation, or with a pacemaker** | An HR-derived stress score is invalid for them, and the app has no way to know. |
| **Anyone who takes the watch off during the day** | Gaps dominate the line. Three gaps out of 24 buckets and the slope becomes unreadable. |
| **Calm people** | Nothing to look at. See 15.3. |
| **People with health anxiety** | See 15.4. |
| **Anyone who wants a morning verdict** | See 15.2. |

---

## 16. The 5-second test

Median smartwatch session is **exactly 5.0 seconds**, held at ~28 cm and ~10° off line-of-sight
(**A**, https://www.kostakos.org/papers/chi17.pdf ·
https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf).
The test: **can a decision be reached without reading a sentence?**

| Surface | Verdict | Honest reasoning |
|---|---|---|
| **S1 Now** | **PASS** | Bar-shape slope reads in the 159–285 ms band. The green→amber transition partway across the x-axis carries "rising" pre-attentively. The word and number confirm without being required. |
| **S2 Session** | **PASS** | Not an information screen. The circle tells you what to do without being read. |
| **S3 After** | **FAIL** | `74 → 68` is two numbers, an arrow and a mental subtraction. It cannot be absorbed in 5 s. **Accepted, not fixed:** this screen only appears at the end of a 60-second committed session, where the attention budget is 60 s, not 5. Applying the glance budget here would be applying the wrong test. |
| **S4 Why** | **FAIL** | Two baseline comparisons with position markers, each needing a "where is the marker relative to the grey band" read. Genuinely slow — roughly 3–4 s per row. **Accepted:** this is the progressive-disclosure layer. Detail views are where reading happens; the entry screen is where deciding happens. |
| **S5 Quiet** | **PASS** | Three labelled buttons, one decision, no data. |
| **`accessoryRectangular`** | **PASS** | Word + slope + band rules, in Apple's own exemplar shape for the family. |
| **`accessoryCircular`** | **PARTIAL** | **PASS** for "what is my number". **FAIL** for "is it rising" — a ring structurally cannot encode slope, and slope is this concept's product. This is the honest reason rectangular is the recommended family and circular is a fallback. |
| **`accessoryInline`** | **PARTIAL** | **PASS** for reading `Stress 41 rising`. **FAIL** for predicting the tap — that it opens a breathing session is not inferable from the label in 5 s. Mitigated by the `wind` glyph and a 700 ms pre-roll; **not eliminated**. |
| **Smart Stack widget** | **PASS** | Same encoding as the rectangular complication with more room, plus a freshness stamp. |
| **N1 long look** | **PASS** | The title is an offer; the first action button **is** the answer; a Double Tap resolves it without reading anything at all. |
| **Loading state** | **PASS** | 24 flat skeleton bars are unmistakably "not yet", and the button is live regardless. |
| **Cold-start state** | **FAIL** | `Heart rate today` with an unlabelled bpm axis and no bands requires reading two sentences to understand why there is no score. **Accepted and named:** it is a state that lasts three days and whose entire job is to *explain*, which is the one job that needs words. |
| **Always-On redacted** | **PASS** | Nothing to read. `Stress ––` plus a flat tick row communicates "hidden, raise your wrist" in well under a second, and it discloses nothing to a bystander. |

**Score: 8 pass, 2 partial, 3 fail.** The three outright failures are all one level below the glance
or are explanatory states by design, and none of them are on the entry screen. The two partials are
both on complications, and both are the same underlying admission: **a ring and a single line of text
cannot carry a slope, and slope is the whole product.**

---

## Confidence

**78/100.** The scoring formula, the four-band vs three-band conflict, the ten existing `WatchPayload`
fields, the absent HealthKit entitlement on both watch targets, the `WATCHOS_DEPLOYMENT_TARGET: "10.0"`
blocker, the single `PhoneWatchSession.push()` call site and the real cyclic-sighing phase durations
were all read from source this session, and every URL cited above was checked to appear in
`research/`. The prototype was rendered in a real browser at both canvas sizes, every state and every
screen, and carries a `selfCheck()` that asserts Alex's 41 / Moderate / "Rising since 11:00" and the
`score(HR)` formula.

Held below 90 because: (a) the design spec's own bucket table has three rounding inconsistencies
against its own formula (09:00, 13:00 and 14:00) which I preserved as authoritative display values
rather than recomputing, so the displayed numbers are the spec's and the band assignments are the
formula's; (b) the 40mm 30-minute aggregation of Alex's day is my derivation, not the spec's — only
the bucket count and the current value were specified; (c) §14.9's widget-HealthKit budget question is
untested and could weaken the face-slot argument; (d) the ~45-minute worst-case N1 latency is derived
from Apple's "approximately four tasks per hour", not from instrumented behaviour; (e) the S4 position
band uses ±2 bpm for the resting-HR usual range because no RHR standard deviation is given anywhere in
the brief — that number is an assumption, and it is the only invented figure in the prototype.

`Source: mixed: code + research files (both read this session) + rendered prototype`
