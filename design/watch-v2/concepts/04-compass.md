# 04 — Recovery Compass (`compass`)

Rationale for `04-compass.html`. Every citation below is a URL that appears in
`design/watch-v2/research/`. Nothing is invented. Evidence strength is marked **A** (peer-reviewed
measurement or first-party platform documentation), **B** (vendor documentation or reproducible
product behaviour), **C** (single reviewer, inference, or snippet-level).

Verified against the shipping source in this repo: `WatchShared/WatchBridge.swift`,
`Core/Analysis/StrainCoach.swift`, `Core/Analysis/Config/StrainCoachConfig.swift`,
`Common/Components/DesignSystem.swift:189`, `Common/Copy/Copy+Home.swift:164`.

---

## 1. One-sentence philosophy

One number cannot hold two forces, so the wrist shows a **position** instead of a score: where today
sits against the load today deserves.

---

## 2. The question it answers first

**Am I in balance right now — under, in, or over?**

It was chosen because it is the only question on the list whose answer is *already a decision*. A
readiness score of 62 still needs a second thought ("so… do I run?"). A dot sitting left of a lit
box has the decision baked into the picture, and the word underneath it is an imperative, not a
label. Garmin ships number + label + a 2–4 word imperative for exactly this reason ("Time to slow
down", "Let your body recover"); Fitbit's label repeats the band and the *sentence* carries the
verdict — **B**
(https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html
· https://support.google.com/fitbit/answer/14236710?hl=en).

It also deliberately does **not** answer "what is my score", "how did I sleep" or "what is my heart
rate". Those are concepts 01, 03 and others. The entry screen has one job.

The divergent bet being tested: Gentler Streak's Activity Path, where the verdict is *where your dot
sits inside a band* — upper = back off, middle = balanced, lower = you have room. A positional glyph
encodes value **and** judgement in one mark, which no scalar score does without a second element —
**B** (https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path).

---

## 3. Screen-by-screen reasoning

Vocabulary is fixed on every surface: **Readiness** (matches `Copy.Home.scoreReadyLabel`, whose
default is literally `"Readiness"`) and **Strain** (matches the Strain module). Never "Recovery",
never "Load", never "Exertion". Vocabulary drift between marketing and product is anti-pattern #13
(Fitbit shipped 30 as "Low" in mockups and "Good" in the app) —
**B** (https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html). `dayType`
("Progressive Overload") is never rendered anywhere; that string is the critique's failure #3.

### The shared plot mapping

Used identically on Page 1, the Trail sheet, the Smart Stack widget and all three complications, so
the shape is learned once:

- **X = Strain, 0 → 18.** 18 is the top of `greenBuildingRange` — the hardest day the coach ever
  prescribes. Above 18 the dot clamps to the right edge and renders as a half dot with a chevron
  (the toolbar's "19.2 off scale" shows this).
- **Y = Readiness, 0 → 100.** Up is more recovered.
- **Corridor** = three stacked rounded steps climbing left to right, straight out of
  `TrainingZone.strainRange(for:)`: readiness < 45 → strain 0–5, 45–66 → 8–12, ≥ 67 → 14–18.
- **Today's step is always the phone's `strainTargetMin`/`strainTargetMax`**, never the constant
  table, because the phone applies dial-back and after-rest logic. The other two steps are a
  constant copy baked into `WatchShared` and are illustrative. They teach the model without a word
  of copy: *the box moves right when you are more recovered.* Switch the toolbar's readiness band
  and watch the lit box jump — that is the whole product in one interaction.

Alex, Tuesday 14:32: readiness 62, strain 6.2, today's step 8 → 12. The dot lands at (84.1, 78.1)
and the step's near edge is at 96.9. The dot is **12 points left of the box**. That is the message.

### Page 1 — Compass (entry)

| Element | Why it exists |
|---|---|
| Plot card, 152 × 152 | One object, one glance. Every state keeps this geometry so nothing jumps between loading, loaded, stale and Always-On |
| Readiness rail (left, 4pt) | A supplementary "up is better" legend. It is the one colour-only element in the design and **no decision depends on it** — its information is fully repeated by the dot's height, by Page 2's numbers and by VoiceOver |
| Three corridor steps | The teaching device. Two are grey and illustrative, one is lit and real |
| End ticks on the lit step | The band edges survive colour inversion and tinted faces (R18) |
| Today dot, Ø12, with a 2pt black outer ring | So it never merges into a step at any position |
| Shortfall chevron | Points at the gap. This is the goal-gradient distance made visible — **Strong** (https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf) |
| "Easy" / "Hard" axis words | The only labelling the X axis gets. Costs two words, kills half the learning curve |
| Verdict, 22pt — "Room to add" | Derived on the wrist from three numbers, no new payload field. `strain < min` → Room to add · in range → In your zone · `> max` → Ease off now |
| Prescription, 13pt — "Easy 30 min gets you there" | `actionDetail`, which the shipping app sends over the wire and throws away |

No readiness number here, on purpose. See §12.

### Page 2 — Why

Two bars with band markers, because bars are the fast encoding for a comparison: 159–285 ms against
1548–1772 ms for a radial bar — **A**
(https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf).
Row 1 is readiness against the 7-day usual (68) with a baseline tick. Row 2 is strain on the same
0–18 scale as the plot, with the aim drawn as a band and a marker that projects above and below the
bar. Row 3 is HRV 48 / rest 58 / now 74 — all native watch HealthKit. Row 4 states the split once:
**"Readiness and aim from iPhone."** Convention: anything not named in row 4 is read by this watch.
That is one line of chrome instead of a source badge on every value.

### Page 3 — Move

One headline (`actionHeadline`), one detail (`actionDetail`), the same strain rail as Page 2 row 2,
and two full-width 44pt buttons. Gentler Streak's path is verdict at 0 taps → prescription at 1
swipe → workout at 2, which is the tightest verdict-to-action path in the competitive set — **B**
(https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path). This is the
same shape. `Mark done` writes `WatchCommand.markActionDone`; on accept the button fills, shows a
tick and **"Done 14:41"**, and disables. On `WatchCommandRejection` it reverts and says
**"Not saved. Tap to try again."** — the dev toolbar's "Simulate WatchCommandRejection" shows it.

### Screen 4 — Last 7 days (modal sheet)

The one thing a position cannot answer alone: *is this normal for me?* Seven dots on the identical
mapping, a trail polyline in date order, and the crown scrubbing a selection. Selecting a day lights
**that day's** corridor step, so you see the aim that applied then. It sits behind two deliberate
steps (crown to Page 3, tap a button) precisely so it never intercepts a glance.

> **Prototype honesty:** only three numbers in the trail come from the brief — today 62 / 6.2,
> Monday's readiness 71, and Sunday's 15.4 (the hard 10 km run two days ago). The other four days
> are filler, chosen so the mean readiness is 68 (the brief's 7-day average) and Monday sits below
> `StrainCoachConfig.restDayThreshold` 5.0. The HTML labels them `filler:` in the data and calls it
> out in the Data honesty panel. **Do not ship invented history.**

---

## 4. Why this works on a watch specifically

- **It is a picture, not a sentence.** The median smartwatch session is exactly 5.0 s across 142.1
  sessions/day — **A** (https://www.kostakos.org/papers/chi17.pdf). A 2-D position is absorbed
  pre-attentively once learned; a paragraph is not.
- **The wrist is where the decision happens.** "Should I train now" is asked standing in a doorway
  in kit, not sitting at a desk. On a phone, this screen is a worse version of a chart that has room
  for axes, gridlines, a legend and 30 days of history.
- **A phone would render this as a scatter plot and be right to.** The compass only earns its place
  at 208 × 248 because it throws away everything a phone would add. On a phone it is a toy.
- **The complication moves during the day.** Checking habits require dynamic content at near-zero
  access cost; adding real-time information to a previously static screen *caused* checking to
  emerge — **Strong** (https://link.springer.com/article/10.1007/s00779-011-0412-2 ·
  https://www.kostakos.org/papers/chi17.pdf). The needle advances from the watch's own active
  energy, which nothing on the phone can do while the phone is in another room.

---

## 5. watchOS HIG guidance applied

| Rule | Applied as | Source |
|---|---|---|
| R1 — interactions are seconds | Three pages, no scroll views, ≤ 4 text lines per screen | https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos |
| R2 — "users may never explicitly launch your app" | Complication + Smart Stack widget carry the product; the app is the detail view. Honest expectation ≈ 1.4 opens/day (§13) | https://developer.apple.com/documentation/watchos-apps |
| R3 — only 2 families reach the Smart Stack | `accessoryRectangular` + `accessoryCircular` there, and nothing else | https://developer.apple.com/design/human-interface-guidelines/widgets |
| R4 / R5 — ~4 updates/hour, never real-time | The dot advances at most 4×/hour and the design publishes its own staleness instead of pretending | https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date · https://athlytic.github.io/athlyticapp/troubleshooting/ |
| R6 — watch HealthKit reaches back ~7 days | The trail is 7 days and comes from the phone; only last night and today are read natively | https://athlyticapp.helpscoutdocs.com/article/12-widget-or-complication-out-of-sync |
| R7 — redact health data in Always-On | Dot removed, lit step removed, rail removed, layout held stable | https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state |
| R8 — no haptic while sampling heart rate | Page 2 is the only screen running an `HKAnchoredObjectQuery`; it suppresses every haptic while the query is in flight, and the crown detent that lands you there fires *before* the query starts. 100 ms minimum spacing. The prototype logs "suppressed" when this trips | https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:) |
| R10 — crown is navigation, crown press is reserved | `TabView(.verticalPage)`; every page fits one screen height with no scroll, so pagination is legal; crown press never bound | https://developer.apple.com/design/human-interface-guidelines/digital-crown · https://developer.apple.com/design/human-interface-guidelines/page-controls |
| R11 — no primary action in vertical tabs | Double Tap lives on the Smart Stack widget, not in the app. Waterllama's pattern | https://developer.apple.com/design/human-interface-guidelines/gestures · https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585 |
| R12 — watchOS relevance is a different API | `TimelineProvider.relevance()` with sleep / fitness / date contexts. `TimelineEntry.relevance` is never set — it is dead code on watchOS | https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks · https://developer.apple.com/documentation/relevancekit/relevantcontext |
| R13 — no spinners | Loading shows the outlined corridor plus a sentence | https://developer.apple.com/design/human-interface-guidelines/feedback |
| R14 / R15 — static surfaces get deleted, one deep link each | The dot moves all day; three complications, three destinations; `accessoryInline` dropped rather than sharing a link | https://developer.apple.com/design/human-interface-guidelines/widgets |
| R17 — short look is not a channel; no sensitive titles | Every notification has a long look with the full sentence; no title carries a readiness score | https://developer.apple.com/design/human-interface-guidelines/notifications |
| R18 — colour is never the only channel | Eight non-colour channels, enumerated in §6 | https://developer.apple.com/design/human-interface-guidelines/widgets |

Rejected on HIG grounds: a horizontal `.page` TabView (swipe-driven, crown inert — violates R10) and
a `NavigationStack` drill-in ("Minimize the depth of hierarchy"; "If your detail views scroll,
people won't be able to use vertical page-based navigation to swipe among them" —
https://developer.apple.com/design/human-interface-guidelines/tab-views).

The Trail sheet is the one exception to "crown = navigation", and it exists for one reason: R10 and
R11 both bind the crown at the top level, so a crown-driven *value* can only live outside the pager.

---

## 6. UX principles used, and the mechanism

1. **Never ship a bare number** (**A/B**). The number is not even on Page 1; the word is.
2. **Make the words an imperative** (**A/B**). "Room to add" / "In your zone" / "Ease off now",
   never "Moderate". The single most consistent criticism across the competitive set is guidance,
   not data.
3. **Target-range framing over ceiling framing** (**B**, https://www.athlyticapp.com/getting-started).
   Everything says "6.2 of 8 to 12". **"of 21" is never printed anywhere** — WHOOP asking users to
   hold three incompatible scales at once is anti-pattern #12
   (https://developer.whoop.com/docs/whoop-101/).
4. **Bars, not rings, for comparisons** (**A**). The only arc in the whole design is
   `accessoryCircular`, where the family's shape forces it — and there the read is categorical
   (inside/outside a ticked segment, plus a glyph), never a radial magnitude comparison. Never two
   rings on one screen.
5. **Progressive disclosure of why** (**B**, https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html).
   Position → factors → history, one crown click apart.
6. **Name the cold start, never fabricate** (**B**). "No position yet. Day 3 of 7." The 7 is
   `StrainCoachConfig.coldStartDays`, not a made-up number. Garmin ships "No Status"; Fitbit states
   7 nights (https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-6F81BF5B-B49A-4506-95E2-0F4A04D8B319.html
   · https://support.google.com/fitbit/answer/14236710?hl=en).
7. **Publish your own staleness** (**B**). "Readiness held from 09:12", a hatched step, a hollow
   freshness ring, a hollow dot past the estimate cap. Athlytic documents its 4-per-hour cap
   in-product and pre-empts the ticket; Bevel does not and carries a live public bug thread about
   watch values being 1–5 points off
   (https://athlytic.github.io/athlyticapp/troubleshooting/ ·
   https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match).
8. **A tiny colour system, never load-bearing alone** (**A/B**). Three colours, all from
   `DS.recoveryTier`.

**What carries meaning with all colour stripped (R18):**

| Channel | Where |
|---|---|
| Position — dot left of / inside / right of the step | Page 1, Trail, widget, every complication |
| Word — "Room to add" / "In your zone" / "Ease off now" | Page 1, widget, rectangular complication, `widgetLabel`, every notification |
| Glyph — `+` / `✓` / `−` | `accessoryCircular` centre |
| End ticks on the target band | Page 1 step, Page 2 bar, Page 3 rail, circular arc, corner arc |
| Marker projection beyond the bar edges | Page 2 both bars, Page 3 rail |
| Hatch fill = held / stale | Page 1 step (the 2pt rail tick goes dashed instead — see §15) |
| Hollow vs filled dot = estimate vs measured | Page 1, Trail |
| Chevron pointing at the gap | Page 1 |

---

## 7. Psychological principles that drive repeat opens

| Mechanic | Evidence | How this design uses it |
|---|---|---|
| **Dynamic content at near-zero access cost** | **Strong: peer-reviewed** (https://link.springer.com/article/10.1007/s00779-011-0412-2 · https://www.kostakos.org/papers/chi17.pdf) | The needle on the circular complication advances all day from native active energy × a phone-supplied slope, inside R4's ~4 updates/hour. A frozen morning score structurally cannot form a checking habit, and Apple warns static complications get removed |
| **Goal gradient — a visible shrinking distance** | **Strong: peer-reviewed**, 20% acceleration near the goal; effort resets after the reward (https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf) | The chevron and the gap to the step's near edge are the distance. And when the dot lands inside, the design does not leave the user at "done with nothing next": the step's **far** edge becomes the new distance and N3 guards it |
| **Surviving the first 8 days** | **Strong: peer-reviewed**, >50% of health-app users quit in week 1; the cohort still engaged at day 8 gained +25 days median retention (https://arxiv.org/pdf/1910.01165) | Cold start is a named state on day 1 with a countdown, not an empty screen. Honestly, this is also the concept's weakest flank — see §15 drawback 3 |
| **Uncertainty about the outcome** | **Strong (mechanism), inferred (application)** (https://pubmed.ncbi.nlm.nih.gov/12649484/) | You cannot predict the dot's position since the last glance, because one axis moves with your own effort. No fake variance is manufactured: readiness is frozen and labelled frozen |
| **Push the verdict at wake** | **Medium: vendor data** (https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-4D26FDDC-63BD-4910-95B8-98937FEC2545.html) | Delivered by the Smart Stack's `RelevantContext.sleep` wake clue, **not** by a notification |
| **Delta-triggered notifications** | **Strong on the near-term effect, strong that it is not retention**: 3.5× next-hour lift, 1.04–1.3× over 24 h, no measurable long-term retention effect, 9.4% of notifications yield any session (https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf) | Three notifications, all fired on a **change of position class**, ceiling 2/day. See §10 |
| **Streaks / loss aversion** | **Medium: vendor A/B** (https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/) | **Not used.** A streak on a recovery product rewards *opening*, not *recovering*. Gentler Streak ships "On a Break / Sick / Injured" specifically so users can stop without penalty — that tells you what a streak would do here |
| **Resumption cue** | **Mixed — Zeigarnik fails to replicate; Ovsiankina resumption is reliable** (https://www.nature.com/articles/s41599-025-05000-w) | The unclosed gap is a resumption cue on a surface the user already sees. It is not justified as "memorable" |

---

## 8. Complication strategy

Three families. Each is a **preview of the page it opens** — that rule assigns the deep links, and
satisfies "Define a different deep link for each complication you support"
(https://developer.apple.com/design/human-interface-guidelines/widgets).

**`accessoryInline` is deliberately not shipped.** One line of text and one tap target is the
weakest possible expression of a positional verdict, and this app has exactly three destinations
worth opening. A fourth family would force two complications to share a deep link, which is
anti-pattern #15.

Apple publishes no pixel dimensions for complication families (synthesis §7), so budgets are stated
in the units Apple does publish: complication text 10.5–19.5pt SF Compact Rounded, line widths ≥ 2pt.

### `accessoryCircular` → `laso://watch/compass`

The synthesis says a positional verdict is hard to fit in this family. The solve: **the 2-D field
projects to 1-D without losing the decision**, because the target step's position on the strain axis
*is* the readiness axis — a green day puts the band at 14–18, a fair day at 8–12, a red day at 0–5.
The band moves; the axis does not. So the circular family drops Y and keeps the verdict.

Open-gap arc, 270° sweep with the gap at the bottom, 6pt stroke, strain 0 → 18 clockwise from the
gap's left end. The aim is a bright segment with radial end ticks. The marker is a needle crossing
the ring. The centre glyph is `+` / `✓` / `−`. `widgetLabel` is **"Room to add"**.

**Why a user gives up a face slot:** it answers "should I train today, and how hard" at zero taps,
and the needle **visibly advances during the day**. Apple's own warning is that a static
complication "may be less likely to remain in a prominent position on the watch face". **Honest
cost:** this is a lossy projection — you cannot tell from the circular whether your readiness went
up or down, only whether your effort matches whatever it is.

### `accessoryRectangular` → `laso://watch/why`

Line 1 "Room to add" · line 2 a full-width strain rail with the 8–12 band and a marker · line 3
"6.2 of 8 to 12". One title, one graphic, one body line — Apple's own exemplar for this family is a
24-hour heart-rate **graph**, not a ring
(https://developer.apple.com/design/human-interface-guidelines/complications).

**Why a user gives up a face slot:** it is the only surface on the whole watch that shows the
distance left to close **as a length**, which is what a goal gradient needs.

### `accessoryCorner` → `laso://watch/move`

Curved gauge along the corner arc, 0 → 18, aim as a bright segment with end ticks, marker at 6.2,
curved label **"Add"** / **"Hold"** / **"Ease"**.

**Why a user gives up a face slot:** it is a verb. It is the only Laso surface that says what to do
in one word, from the face itself.

---

## 9. Smart Stack strategy

**This is the concept's primary surface.** Both families that can reach the Smart Stack are shipped;
the circular is the identical implementation to the complication.

The `accessoryRectangular` widget is designed to the published box — 152 × 69.5 pt at 40 mm rising
to 191 × 81.5 pt at 49 mm — as a 52 × 52 mini plot on the left and a right column of one title line,
one body line and one 86 × 28 button. No rail and no axis words at that size: the text carries the
message and the plot carries the identity. At 49 mm the extra height buys one more body line
("Easy 30 min"); the prototype renders 46 mm and 40 mm only, per the canvas rule.

The button is an `AppIntent` Button carrying `.handGestureShortcut(.primaryAction)`, so **Double Tap
marks the day's action done without opening anything**. The widget is not a list, a scroll view or a
vertical tab, so R11 is satisfied — which is precisely why the primary action lives here and not in
the app. When `actionDone` is true it renders as a non-interactive chip with a tick.

**Relevance (R12).** `TimelineEntry.relevance` does nothing on watchOS and is never set — that is
anti-pattern #9. `TimelineProvider.relevance()` returns a `WidgetRelevance` with:

1. `RelevantContext.sleep(...)` on the wake clue — the day's aim at the highest-intent moment, with
   no notification spent.
2. `RelevantContext.fitness(...)` at workout end — the one moment the dot actually jumps.
3. A date context at **17:30 local** — the last honest moment to act on "room to add".

Both the app target **and** the widget extension need the matching HealthKit entitlement or these
contexts are ignored (https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks
· https://developer.apple.com/documentation/relevancekit/relevantcontext).

**Builder warning:** the exact `SleepClue` / fitness case names could not be verified from the
research — synthesis §7 lists four Apple articles that 404'd. Verify against the SDK; do not guess.

---

## 10. Notification strategy

**Design rule: fire on a change of position class, never on an absolute health value.** Training
Today's delta model (fire on a change vs a 4-day average, user-set threshold) is the one that
survives; Athlytic's absolute-threshold stress alerts drew an explicit request for "a big friendly
toggle to hush stress for a while" — anti-pattern #3
(https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/).

**All three fire from the phone's own strain crossing, never from the wrist's local estimate.** A
false "you're done" is a trust kill, and firing on an estimate is anti-pattern #2.

| # | Trigger | Short look | Actions | Cap |
|---|---|---|---|---|
| **N1 Zone reached** | Phone strain crosses **into** `[min, max]` | "In your zone" · "Strain 8.1 of 8 to 12" | `Mark done` · `See compass` | 1/day |
| **N2 Day closing under** | Local 19:30 (user editable), only if strain < `min − 1.5`, N1 did not fire, "Not today" not tapped | "Still room today" · "Strain 6.2 of 8 to 12" | `Not today` · `See compass` | 1/day |
| **N3 Above the zone** | Phone strain crosses **above** `max` | "Above your zone" · "Strain 12.6 of 8 to 12" | `See compass` · `Hush today` | 1/day |

Every one has a long look carrying the mini plot and the full sentence, because "Avoid using a short
look as the only way to communicate important information". No title carries a readiness score,
because "Avoid including potentially sensitive information in the notification's title"
(https://developer.apple.com/design/human-interface-guidelines/notifications).

**Cadence ceiling: 2 per day, hard.** N1 suppresses N2. Weekly ceiling 7. `Not today` and
`Hush today` are the requested friendly toggles, and they are the escape hatch for someone who is
deliberately not training.

**Deliberately not shipped: a wake-time push.** Every competitor has one. It is cut because the
Smart Stack's `sleep` relevance already owns that moment at zero notification cost, and 82.3% of
watch sessions are self-initiated while only 9.4% of notifications yield any session — a wake push
competes for the small slice against a surface that already owns the moment
(https://www.kostakos.org/papers/chi17.pdf).

---

## 11. Haptic language

| Event | `WKHapticType` |
|---|---|
| Crown detent between pages | `.click` |
| Crown detent selecting a day in the Trail sheet | `.click` |
| Mark done accepted (Page 3 or widget Double Tap) | `.success` |
| Write rejected by the phone (`WatchCommandRejection`) | `.failure` |
| N1 / N2 / N3 arriving | `.notification` |
| Strain crosses **into** the zone while the app is frontmost | `.directionUp` |
| Strain crosses **above** the zone while the app is frontmost | `.directionDown` |

Build rules that follow from R8: Page 2 suppresses every haptic while a heart-rate query is in
flight; the crown detent that lands the user on Page 2 fires *before* the query starts; minimum
100 ms between any two haptics; no haptics from background refresh, because this concept starts no
`HKWorkoutSession` and there are no background haptics outside one
(https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)).

The prototype renders every one of these as a pulse ring plus a named caption, and logs
"suppressed — heart-rate query in flight" when R8 trips.

---

## 12. What was deliberately excluded, and why

| Excluded | Why |
|---|---|
| **A readiness number on the entry screen** | The concept's claim is that a position beats a score. Put 62 on Page 1 and users read the number and ignore the picture, and the concept never gets tested. The number is one crown click away |
| **The morning check-in** (`checkInAvailable` unused) | A genuinely good feature that belongs to a different concept. Here it means a fourth page and three crown inputs that have nothing to do with "am I in balance" |
| **The quick log** (water, caffeine, alcohol) | The critique is right that logging belongs on a widget with a running count. A log list on Page 3 creates a list view, and R11 says that kills the Double Tap primary action |
| **`accessoryInline`** | One line, one tap target, no fourth destination. Shipping it forces a shared deep link — anti-pattern #15 |
| **A wake-time push** | Smart Stack `sleep` relevance owns that moment at zero cost; notifications are not retention |
| **Live heart rate as a hero** | That is concept 03. Here it is one third of one caption |
| **Sleep stages, debt, need** | Phone-only for debt and need, and a sleep hero is a different first question |
| **Any streak or chain** | Medium evidence at best, and it would reward opening rather than recovering |
| **`dayType` / "Progressive Overload"** | Training-theory jargon rendered as a status. The critique's failure #3 |
| **A second ring anywhere** | Never two rings on one screen. The only arc is the circular complication, forced by the family's shape |
| **Double Tap inside the app** | R11 forbids a primary action in a vertical-tab view. On the widget it is strictly better — it acts without opening anything |
| **Starting a workout from the wrist** | An `HKWorkoutSession` changes the app's whole lifecycle, background budget and haptic rules, and is not needed to answer "am I in balance" |

---

## 13. Expected opens per day, with the mechanism

**"Encounter" = the user sees Laso content at zero taps. "Open" = the app launches.**

| # | Trigger | Time | Mechanism | Opens |
|---|---|---|---|---|
| 1 | Watch-face glance | all day, 6–10× | `accessoryCircular` glyph + needle. Zero taps. This is where the product lives | **0** (6–10 encounters) |
| 2 | Wake | ~07:00 | Smart Stack widget surfaced by `RelevantContext.sleep`; crown-down from the face. Occasionally taps in to read the prescription | **0.3** |
| 3 | Midday "have I done enough" | 13:00–15:00 | The dot has advanced, the gap has shrunk. Self-initiated glance; taps in when the answer is ambiguous | **0.4** |
| 4 | Workout end | ~4 days/week | `RelevantContext.fitness` surfaces the widget; the dot has just jumped, sometimes into the step. Often followed by Mark done | **0.35** |
| 5 | N1 "In your zone" | when it fires | Notification → `Mark done` action usually resolves without an open | **0.15** |
| 6 | N2 "Still room today" | 19:30, ~3 days/week | Converts above the 9.4% baseline because the action is one tap | **0.2** |
| 7 | "Is this normal for me" | 1–2×/week | Trail sheet, two deliberate steps in | **0.2** |

**Honest total: ~1.4 app opens per day, plus 7–12 zero-tap encounters.**

That is **low** against a live-heart-rate or body-battery concept, and it is a property of the
design, not an accident: a position that changes meaningfully three or four times a day cannot
honestly justify twenty opens. What it buys instead is a complication a user does not remove. Do not
compare this number to concept 03's — compare the encounter counts.

---

## 14. Buildability against this codebase

Legend: **[E]** existing `WatchPayload` field · **[N]** new wire field · **[HK]** native watch
HealthKit · **[P]** new phone-side work · **[C]** constant baked into `WatchShared` · **[D]** derived
on the wrist.

| Value | Source | Status |
|---|---|---|
| Readiness 62 | **[E]** `readinessScore` | ships today |
| "Moderate" band word (VoiceOver only) | **[E]** `readinessGrade` | on the wire today and **never rendered** — revived |
| "Add an easy 30 min" | **[E]** `actionHeadline` | ships today |
| "Easy 30 min gets you there" | **[E]** `actionDetail` | on the wire today and **never rendered** — revived |
| Mark done state + write | **[E]** `actionDone`, `WatchCommand.markActionDone` | ships today |
| Freshness / staleness | **[E]** `updatedAt`, `dayKey`, `WatchBridge.stalePayloadInterval` (verified: `60 * 60`) | ships today |
| Strain 6.2 at sync (dot X) | **[N]** `strainNow: Double` — `StrainScorer` value at push time | new field |
| Aim 8 → 12 | **[N]** `strainTargetMin`, `strainTargetMax` — already computed as `StrainCoach.StrainTarget.minStrain` / `.maxStrain` (`StrainCoach.swift:49-51`, set at `:111-112`), just not on the wire | new field, zero new maths |
| 7-day trail | **[N]** `weekTrail: [WatchTrailDay]` — the phone already holds both series | new field |
| "usual 68" | **[D]** mean of `weekTrail`. **Do not add a field** | free |
| Live strain advance | **[HK]** today's active energy × **[N]** `strainPerActiveKcal: Double`. The watch snapshots kcal when the payload lands, so no `activeKcalAtSync` field is needed. Capped at +2.5; past the cap the dot goes hollow and says "estimate" | new field + **[P]** ~10 lines: the marginal `d(strain)/d(kcal)` at today's point in `StrainScorer` |
| The other two corridor steps | **[C]** copy of `redRestoringRange` `0...5`, `yellowMaintainingRange` `8...12`, `greenBuildingRange` `14...18` (all verified in `StrainCoachConfig.swift`). Illustrative only — today's row is always overwritten by the phone's min/max, so the two can never disagree about today | free |
| Verdict word | **[D]** `strainNow` vs `[min, max]` | free |
| HRV 48 · rest 58 · now 74 | **[HK]** `heartRateVariabilitySDNN` (last night), `restingHeartRate`, `HKAnchoredObjectQuery` on `heartRate` — Page 2 only | needs the entitlement below |
| Cold-start "Day 3 of 7" | **[C]** `StrainCoachConfig.coldStartDays` = 7 (verified) | free |
| Band colours and thresholds | `DS.recoveryTier`, `optimalFloor = 67`, `fairFloor = 45` (`DesignSystem.swift:189`) | ships today |

**New wire fields: 5** (`strainNow`, `strainTargetMin`, `strainTargetMax`, `strainPerActiveKcal`,
`weekTrail`). **New phone maths: 1** (the marginal slope).

### The four blockers, stated plainly

1. **The watch target does not link HealthKit at all.** `project.yml:242-252` lists `LasoWatch`
   sources file by file; `LasoWatch/LasoWatch.entitlements` has exactly one key (an App Group);
   `LasoWatch/Info.plist` has no `NSHealthShareUsageDescription`. This concept needs
   `com.apple.developer.healthkit` and the usage description **on the watch app**, and the same
   entitlement **on the widget extension** or §9's relevance contexts are silently ignored. Without
   this, the dot never advances during the day and mechanic #1 — the strongest evidenced driver in
   the whole research set — is gone. This is the single largest piece of work.
2. **The phone only pushes when the user opens the phone app.** `PhoneWatchSession.push()` is called
   only from `DashboardViewModel.writeWidgetSnapshots()` (`DashboardViewModel.swift:2265`);
   `BackgroundRefreshCoordinator` updates the iOS widget and never calls it. Ship this concept on
   that architecture and **"Readiness held from 09:12" becomes the normal state, not the error
   state.** The design absorbs it honestly — which is exactly why it must not be used as an excuse
   to skip the fix. `BackgroundRefreshCoordinator` must call `PhoneWatchSession.push`.
3. **`Mark done` can disable itself forever.** `WatchRootView.swift:95` disables on
   `!store.pendingCommands.isEmpty`, and the code's own `ponytail:` comment at
   `WatchStore.swift:27-29` admits a lost answer leaves it pending until relaunch. Page 3 and the
   widget button both depend on that write, so the pending-command path needs a timeout before this
   ships.
4. **New copy goes in `WatchShared/WatchStrings.swift`, not `Common/Copy/`.** The watch targets link
   no Firebase, which is the same exception the widget target already has. This is a deliberate
   deviation from the Copy Files Standard and must be stated in the PR, not smuggled.

### Deviations from the approved spec, and why

1. **Trail VoiceOver count.** The spec's line says "Three of the last seven days were inside the
   aim." Computed against the seven days in the spec, using each day's own readiness band, the true
   count is **one** (only Sunday, 74 readiness / 15.4 strain, lands inside 14–18). The prototype
   computes the number instead of printing it. Do not ship the literal "three".
2. **Held rail tick.** The spec asks for a 45° hatch on the readiness rail tick. The tick is 2pt
   tall; a hatch is invisible at that size. It renders as a dashed rule instead — still a shape
   channel, not a colour change. The step's hatch is unchanged.
3. **Over-the-zone chevron.** The spec defines only the shortfall chevron. The mirrored left-pointing
   chevron for the "Ease off now" case is mine, for symmetry.
4. **49 mm widget layout** (third line, taller button) is specified but not rendered — the canvas
   rule is 46 mm and 40 mm.
5. **Non-Alex band/strain combinations** in the dev toolbar use generic action copy, because
   `actionHeadline` / `actionDetail` are phone strings and inventing them would be inventing data.
   The prototype says so in the Data honesty panel.
6. **`widgetLabel`** is drawn as a text line under the circular slot, because HTML has no watch-face
   renderer to place it.

---

## 15. Honest drawbacks, and who this fails

**1. On any single day this is a 1-D range gauge wearing a 2-D costume. This is the strongest
argument against the concept and it goes first.** The target step's vertical extent is always the
user's current readiness band, so the dot is *always* vertically inside its own step. The Y axis
never produces a verdict on its own — it only selects which step is lit. The proof is §8: the
`accessoryCircular` projection to one dimension is **lossless for the decision**, which means the
second axis contributes nothing to the glance. Y only pays for itself across *days* (the trail) and
across *states* (the box jumping right on a green morning). If a reviewer concludes that a
horizontal band with a marker — exactly what Page 2 row 2 already is — delivers 95% of the value at
20% of the learning cost, that reviewer is not wrong.

**2. There is no number to say out loud.** "I'm a 62 today" is real self-tracking behaviour and this
design pushes it one page deep. Users who joined for a score will read Page 1 as evasive.

**3. The first run fails the 5-second test** (§16, ~15–20 s). There is no onboarding tour, because a
tour on a watch is worse than the problem. The bet is that the verdict word carries the decision
while the picture is being learned. If it does not, the concept loses users in week one — and week
one is where >50% of health-app users are lost and where the whole retention effect lives
(https://arxiv.org/pdf/1910.01165).

**4. Both axes are phone verdicts.** The wrist never computes readiness or strain — it caches them
and advances one of them with a phone-supplied coefficient. "Works with the phone in another room"
is *true but partial*: the position is real and useful, the readiness half of it is frozen. That is
honest, it is labelled, and it is better than the shipping app — but it is not the same claim as a
concept whose hero is a live sensor read.

**5. It fails the person who does not train.** For someone who walks and does nothing else, the dot
sits permanently left of the step and the app becomes a daily reproach. N2's `Not today` is one day
at a time. The proper fix is Gentler Streak's manual "On a Break / Sick / Injured", which is **not
in this design** and should be added before shipping to a general audience.

**6. The band itself is an unvalidated heuristic.** `StrainCoachConfig`'s own header says so:
*"HEURISTIC — unvalidated… inspired by WHOOP-style periodisation guidance but not anchored to a
specific peer-reviewed dataset."* This design promotes that heuristic to a target on the watch face,
which is a stronger claim than the phone makes for it. A score that contradicts felt state is worse
than no score (https://www.dcrainmaker.com/2021/11/whoop-platform-review.html).

**7. The shortfall gap can be visually tiny.** Alex is 1.8 strain under an 18-unit axis: 12pt of
separation at 46 mm, 6pt at 40 mm. That is *honest* — being 1.8 under really is nearly there — but
the picture alone cannot separate "just outside" from "inside" at a glance. The word does that work,
and on a tinted face the word is the only remaining channel.

**8. Whom it serves.** Best: someone training 3–5 days a week who already understands training load
and wants a wrist that says "more or less today". Worst: a new user with no baseline, someone who
tracks health without training, and anyone who came to Laso for one number to watch go up.

---

## 16. The 5-second test, per screen

| Screen | Verdict | Reason |
|---|---|---|
| **Page 1, first-ever view** | **FAIL** | An unlabelled 2-D field is not free. A new user needs roughly 15–20 s and one glance at Page 2 to learn that up is readiness and right is effort. The verdict word rescues the *decision* in under 2 s, but the *picture* is not self-explanatory on first contact. This is the concept's entry tax and it is real |
| **Page 1, third view onward** | **PASS (~2 s)** | The read collapses to "white dot is left of the lit brick, and it says Room to add". Pure pattern match, no chart parsing |
| **Page 2** | **PASS (~3 s) for "how far off am I"** — two bars with band markers, the fastest encoding available. **FAIL for "why is my readiness 62"** — it shows HRV and resting HR and never the weighting between them. That is a black box by anti-pattern #4's definition (https://www.autonomous.ai/ourblog/bevel-app-review), and it stays one, because the causal breakdown is a phone screen |
| **Page 3** | **PASS (~2 s)** | One headline, one detail, one button. Nothing to decode |
| **Trail sheet** | **FAIL as a glance, PASS as a 15-second exploration** | Seven dots and a polyline cannot be read in 5 s and are not meant to be. It sits behind two deliberate steps so it never intercepts a glance |
| **`accessoryCircular`** | **PASS (~1 s)** | The centre glyph is the answer; the needle is confirmation |
| **`accessoryRectangular`** | **PASS (~1.5 s)** | Word first, bar second |
| **`accessoryCorner`** | **BORDERLINE** | The word ("Add") passes instantly; the curved band and marker are small enough that the *magnitude* of the gap is not reliably readable at 28 cm off-axis. It carries the verb, not the distance. Shipped on that basis |
| **Smart Stack widget** | **PASS (~2 s)** | Two text lines carry it; the 52pt plot is recognition, not reading |
| **Notification short look** | **PASS (~1.5 s)** | Title is the verdict, body is "6.2 of 8 to 12" |
| **Always-On redacted** | **PASS (~0.5 s)** | It says nothing, and it says it fast |
| **Loading / cold start** | **PASS (~2 s)** | Named states with a countdown, no spinner, no fabricated number |

Three of twelve surfaces fail, and the one that fails hardest is the entry screen on first contact.
That is the price of the bet in §2, stated in full rather than argued away.

---

## Prototype notes

`04-compass.html` — single file, no network, opens from `file://`. Ten screens in the strip: watch
face (Modular), watch face (Corners), Smart Stack, notification short look, notification long look,
app launch, Compass, Why, Move, Last 7 days. Dev toolbar (bottom right) switches 46 mm / 40 mm, ten
states, Always-On redaction, the readiness band across all three colour ramps, four strain values
including one off the scale, and fires a Double Tap. Crown = mouse wheel or ↑/↓, with a rendered
detent that fires `.click`. Every state change renders a pulse and names the `WKHapticType`;
`prefers-reduced-motion` is respected. Verified by a headless render of all 4,800
screen × state × size × band × strain combinations with zero failures, and by checking that every
plotted coordinate matches the approved spec table to 0.1 pt.
