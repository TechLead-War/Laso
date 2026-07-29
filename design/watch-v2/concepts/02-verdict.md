# Concept 02 — One Word (`verdict`)

> ## ⚠ Corrected after review — read this first
>
> The eight-word vocabulary described below **was wrong and has been replaced.** Alex's traced
> Tuesday produced `WALK · STAND · WALK · BREATHE · WALK · STAND · COAST · DRINK · SLEEP` — six of
> nine words were WALK/STAND/DRINK, which Apple's own Activity rings and stand reminders already
> say for free. The wrist has one line and the original design spent it on advice the user already
> had, while using none of Laso's baselines, anomaly detection or causal chains.
>
> **The rule now: a word only reaches the headline if the user could not already know it.**
>
> - **Imperatives (rare, earned):** `REST` `TRAIN` `BREATHE` `SLEEP`
> - **States (most days):** `RECOVERING` `WARM` `STEADY` — a fact against the user's own baseline,
>   never an order
> - **Deleted from the headline:** `STAND` `DRINK` `WALK` `COAST`
>
> Alex at 14:32 now reads **RECOVERING / 2 days after your hard run / Room for 18 more minutes.**
>
> **The honest cost:** three words and two changes across the day instead of six and six. The
> dynamism moved to line 3, the live headroom, which counts down all day off native sensors. The
> word is the verdict, the line under it is the feed.
>
> `02-verdict.html` implements the corrected ladder and its self-check passes 9/9. Sections 2, 3
> and 11 below still describe the superseded eight-word model and are kept only to show what
> changed. See `../04-RECOMMENDATION.md` §3 for the current design.


Prototype: [`02-verdict.html`](02-verdict.html)
Shared user: **Alex, 34. Tuesday 14:32.** Every number in the prototype is from `PROTOTYPE-SPEC.md`.

> Alex, Tuesday 14:32 → **WALK** · 20 minutes, easy pace · 12 of 30 exercise minutes · Fresh · 6 min

---

## 1. One-sentence philosophy

The watch should answer, not report — so the entry screen carries one imperative word and no number at
all, and the number is one crown turn away for anyone who wants to audit the answer.

---

## 2. The question it answers first

**"What should I do in the next hour?"**

Not *how am I*, not *what is my score*. The choice matters because it changes what counts as a good
screen. If the question is "what is my score", the hero is a value and everything else is decoration.
If the question is "what do I do", the hero is a verb and the score becomes evidence — which is where
the research says it belongs.

Every studied product pairs its number with words, and none ships a bare integer as the verdict
(principle 3, **A/B**: https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html ·
https://support.google.com/fitbit/answer/14236710?hl=en). Garmin ships number + label + a two-to-four
word imperative; Fitbit ships number + recommendation sentence; Gentler Streak ships the sentence and
**refuses the number outright** — "avoid putting your daily form into a score, percentage, or body
battery concept" (https://gentlerstories.com/newsroom/20230216newwellbeing).

This concept takes principle 3 to its limit and tests the end of that spectrum: what if the entry
screen has no number at all?

### The closed vocabulary — eight words

| Word | Class | Colour | Imperative sub-line | Cost if wrong by 15 minutes |
|---|---|---|---|---|
| **REST** | verdict | band | `No training today` | One skipped session. Low regret. |
| **BREATHE** | upkeep | `primary` | `One minute, slow out-breath` | None. |
| **SLEEP** | upkeep | `primary` | `Lights out by 23:20` | None. |
| **TRAIN** | verdict | band | `A hard session is on` | **High.** Training a body that needed rest costs real recovery. |
| **STAND** | upkeep | `primary` | `One minute on your feet` | None. |
| **DRINK** | upkeep | `primary` | `Glass 5 of 8` | None. |
| **WALK** | verdict | band | `20 minutes, easy pace` | None. |
| **COAST** | verdict | band | `You have done enough today` | You did nothing extra. Low regret. |

Seven of the eight are low- or zero-regret **by construction** — that is why they were chosen. Only
**TRAIN** is expensive when wrong, so TRAIN is the only word gated on payload freshness. That single
asymmetry is what lets the whole vocabulary survive R4's ~4-updates-per-hour ceiling
(https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date).

### The selection ladder — deterministic, runs on the wrist

Implemented in the prototype as `ladder()`. First match wins.

```
GUARDS   HealthKit denied       -> accessDenied (no word)
         < 7 nights + no payload-> coldStart (rules 2,3,5,6,7,9 only)
         payload absent/> 60 min-> phoneAware = false (rules 1 and 4 skipped)

1 REST     phoneAware && (band == poor || bodyStressFlag == "elevated")
2 BREATHE  (liveHR − restingHR) >= 20 && steps(10 min) < 50 && no workout && HR sample < 5 min old
3 SLEEP    now >= bedtimeTarget − 60 min && now < bedtimeTarget + 90 min
4 TRAIN    phoneAware && payloadAge <= 60 && band == optimal && stress == "none"
           && exerciseToday < 0.5 × goal
5 STAND    no stand credit this hour && minute(now) >= 40
6 DRINK    water <= ceil(8 × hoursAwake / 16) − 3
7 WALK     exerciseToday < goal && (phoneAware ? band != poor : true)
8 COAST    exerciseToday >= goal
9 WALK     fallback — the wrist is never left without a word
```

**Alex at 14:32, traced:** band fair (62); `bodyStressFlag` = `"low"` (RHR +3 and respiratory +0.6 on
the same night is the phone's *low-confidence* flag, not `"elevated"`) → rule 1 no. 74 − 58 = +16 < 20
→ rule 2 no. Bedtime 23:20 is 528 min away → rule 3 no. Band is fair not optimal → rule 4 no. Last
stood 12:40 so the 14:00 hour has no credit, but minute 32 < 40 → rule 5 no. Water 4, pace
`ceil(8 × 7.53/16)` = 4, so `4 <= 1` is false → rule 6 no. Exercise 12 < 30 → **rule 7: WALK.**

**Alex's whole Tuesday** — nine evaluations, six distinct words, six changes, every one caused by real
sensor data while the readiness score sat at 62 all day:

| Time | Word | Rule |
|---|---|---|
| 07:05 | WALK | 7 — exercise 0/30 |
| 09:40 | STAND | 5 — no stand credit, minute 40 |
| 11:15 | WALK | 7 — exercise 4/30 |
| 13:05 | BREATHE | 2 — HR 79 vs RHR 58 = +21, sitting |
| **14:32** | **WALK** | **7 — exercise 12/30** |
| 14:40 | STAND | 5 |
| 18:30 | COAST | 8 — exercise 37/30 after the walk |
| 20:10 | DRINK | 6 — 4 glasses vs pace 7 |
| 22:20 | SLEEP | 3 — bedtime target 23:20 |

All nine are wired into the prototype's dev toolbar and a self-check re-runs the ladder against them
on load: **`ladder self-check: 9/9`**. Two builders implementing this ladder produce identical output.

---

## 3. Screen-by-screen reasoning

### Page 1 — VERDICT (entry screen)

*The one decision it enables: do I add load in the next hour, or not?*

| Element | Why it is there, and why in that order |
|---|---|
| **Band rail** — 3 segments, `58 × 6pt` [`44 × 6pt`], active segment filled + a `6 × 3pt` white tick above | Position is the primary band channel and the tick is the non-chromatic one (R18). Pinned to the top inset so it never moves between states. Outline-only when no payload has ever arrived; **dashed with the tick kept** when the payload is merely old. |
| **HERO WORD**, 52pt [40pt], uppercase, ≤5 chars; 40pt [32pt] at 6–7 chars | The whole concept. A 4–5 letter word has a stronger silhouette at a glance than two digits, and it is an instruction rather than a measurement. |
| **Imperative sub-line**, 16pt `textSecondary` | This is why there is no legend screen: the word is explained every single time it appears. A word that needs a glossary is the wrong word. |
| **Evidence line**, 13pt `textTertiary` | Deliberately **100% watch-native** (`12 of 30 exercise minutes` is `HKQuantityTypeIdentifier.appleExerciseTime`) so it stays true with the phone in another room. This is the line that makes the screen survive the phone being absent. |
| **Freshness footer** — dot + `Fresh · 6 min` | Principle 12, applied in-product. The word before the duration carries the same meaning without colour: `Fresh` / `Ageing` / `Stale`. |

**Four text lines. Zero controls.** The absence of controls is not minimalism, it is R8 compliance —
see §11.

### Page 2 — WHY

*The one decision it enables: do I believe the word?*

Title row (`Readiness` · `from iPhone · 14:26`) → `62` at 52pt in **neutral `textPrimary`** → three
comparison bars → driver line `6h12m sleep · HRV 48 · RHR +3`.

Two deliberate choices. First, the number is **not** coloured: the colour lives on the word one page
up, and colouring the number too would make it the hero and kill the concept. Second, the source tag
is mandatory — this is the only screen showing a phone-computed value and the data split must be
visible on the glass.

The driver line is the answer to anti-pattern #4, "the scores are a black box"
(https://www.autonomous.ai/ourblog/bevel-app-review): three inputs, on the wrist, at zero extra taps
from the number.

### Page 3 — DO

*The one decision it enables: am I done with today's move?*

`figure.walk` + `Zone 2 walk, 20 min` → `Keeps you inside your 8-12 strain window` → one full-width
`188 × 48pt` button. Nothing else fits and nothing else belongs.

**Deliberately absent: the quick-log row.** The critique's verdict on `WatchJournalView` — *"keep as an
action, kill as a screen"* — is honoured literally. Water logging moved to the Smart Stack widget
**with a visible running count**, which is the fix for the write-only hole the critique identified.

### Navigation

Vertical `TabView`, `.verticalPage`, three fixed-height pages, depth 1, no `NavigationStack`, no page
scrolls. R10 is explicit: *"Use vertical pagination to separate multiple views into distinct,
purposeful pages… In watchOS, this design is more effective than horizontal pagination or many levels
of hierarchical navigation"* and *"Consider limiting the content of an individual page to a single
screen height"* (https://developer.apple.com/design/human-interface-guidelines/page-controls ·
https://developer.apple.com/design/human-interface-guidelines/digital-crown). A drill-in would put the
number at depth 2 and break page swiping (anti-pattern #14,
https://developer.apple.com/design/human-interface-guidelines/tab-views).

---

## 4. Why this works on a watch specifically

**What is better here than on a phone:**

- **The decision beats the data when the screen is 208pt wide and the session is 5.0 s.** Median
  smartwatch session is exactly 5.0 s across 142.1 sessions/day
  (https://www.kostakos.org/papers/chi17.pdf). A single word is consumable inside that; a dashboard
  is not.
- **The wrist is where the *feeling* is.** Rule 2 (BREATHE) fires off a live HR sample against
  resting HR with a movement check. A phone cannot know you are sitting still with an elevated heart
  rate at 13:05. This word only exists because the sensor is strapped to the same limb.
- **A word survives peripheral vision.** The complication is read at ~28 cm, ~50° pitch, ~10° off
  line-of-sight (principle 1). Four uppercase letters resolve there; a two-digit number needs
  fixation.

**What would be worse on a phone:** all of it. On a phone, "WALK" with no number is patronising —
the user has a 6-inch screen and expects the reasoning. The compression that makes this design work
on a wrist is exactly what makes it insulting on a phone. This concept does not scale up.

---

## 5. watchOS HIG guidance applied

| Rule | What the design does | Source |
|---|---|---|
| **R1** interactions are seconds | One word, four lines, zero controls on page 1 | https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos |
| **R2** the app is not the product | Three complications + a Smart Stack widget carry the identical word; the app is the detail view | https://developer.apple.com/documentation/watchos-apps |
| **R3** only 2 families reach the Smart Stack | Ships `accessoryRectangular` only; `accessoryCircular` is eligible but wastes 78% of a 152 × 69.5pt card | https://developer.apple.com/design/human-interface-guidelines/widgets |
| **R4/R5** ~4 updates/hour, never real-time | The word changes 6× a day, comfortably inside the cap. No live-ticking value anywhere | https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date |
| **R6** watch HealthKit reaches ~7 days | Every native read used (exercise minutes, stand, water, HR, RHR, sleep, HRV, the 7-bar sparkline) is inside 7 days. Baselines and the readiness score stay on the phone | https://athlytic.github.io/athlyticapp/troubleshooting/ |
| **R7** redact health data in Always-On | The word **is** the verdict, so it is replaced by an empty stroked rectangle. Rail stroked, no fill, no tick. See §15 drawback 1 | https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state |
| **R8** no haptic while sampling HR | Page 1 has zero controls and fires zero haptics | https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:) |
| **R9** background execution is a few seconds | N2 is best-effort in a `WKApplicationRefreshBackgroundTask`; the complication carries the change silently when it does not fire | https://developer.apple.com/documentation/watchkit/using-background-tasks |
| **R10** crown is navigation; press is reserved | Crown pages 1↔2↔3, backed by swipe. Crown presses never handled | https://developer.apple.com/design/human-interface-guidelines/digital-crown |
| **R11** no primary action on vertical tabs | **No page sets `handGestureShortcut(.primaryAction)`.** Double Tap keeps its system meaning in-app; the concept's Double-Tap action lives on the widget | https://developer.apple.com/design/human-interface-guidelines/gestures |
| **R12** relevance on watchOS is a different API | `TimelineEntry.relevance` unused. `TimelineProvider.relevance()` → `WidgetRelevance` with four clues | https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks · https://developer.apple.com/documentation/relevancekit/relevantcontext |
| **R13** no spinners | Loading shows `One moment` / `Reading last night`, never an indeterminate indicator | https://developer.apple.com/design/human-interface-guidelines/feedback |
| **R14** static surfaces get deleted | Six word changes a day, all sensor-driven | https://developer.apple.com/design/human-interface-guidelines/widgets |
| **R15** sizes, type and touch floors | Designed to 152 × 69.5 → 191 × 81.5pt; the one 28pt control is flagged in §10 | https://developer.apple.com/design/human-interface-guidelines/widgets |
| **R16** extended runtime capped | Not used. No timed session anywhere | https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions |
| **R17** short look is not a channel | Every long look carries the full verdict + comparison; no title contains health data | https://developer.apple.com/design/human-interface-guidelines/notifications |
| **R18** colour never alone | Four channels before colour — see §10 | https://developer.apple.com/design/human-interface-guidelines/widgets |

---

## 6. UX principles used, and the mechanism

| Principle | Mechanism in this design | Evidence |
|---|---|---|
| **4 — imperative, not description** | All eight words are verbs. "Moderate Readiness" appears nowhere. Garmin's *"Time to slow down"* is the model | **A/B** https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html · https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html |
| **3 — never a bare number** | Pushed to its limit: no number on the entry screen at all | **A/B** https://gentlerstories.com/newsroom/20230216newwellbeing |
| **10 — progressive disclosure of "why"** | Word at 0 turns; number + comparison at 1 crown turn; per-day history at 1 turn + 1 tap. Garmin: level at 0 presses, factors at 3 | **B** https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html · https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html |
| **6 — bars, not rings** | Page 2 uses three horizontal bars; the rectangular complication uses a bar sparkline; **there is not one ring in this design**. Bar 159–285 ms vs radial 1548–1772 ms | **A** https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf · https://developer.apple.com/design/human-interface-guidelines/complications |
| **11 — name the cold start** | `Recovery verdict: 3 more nights`, and half the vocabulary works on day one with no baseline | **B** https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-6F81BF5B-B49A-4506-95E2-0F4A04D8B319.html |
| **12 — publish the staleness rule** | `Stale · 1h 47m · wrist data live` on the glass, plus TRAIN's freshness gate. Bevel's public bug thread is the counter-example | **B** https://athlytic.github.io/athlyticapp/troubleshooting/ · https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match |
| **14 — one action, the obvious next step** | Page 3 has one button; the widget has one button; Double Tap fires it from the Smart Stack | **B** https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface · https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585 |
| **16 — colour never load-bearing alone** | Four channels before colour | **A/B** https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path |
| **17 — a score that contradicts felt state** | Why the vocabulary is built from low-regret words. It does not solve the problem — see §15 drawback 5 | **B/C** https://www.dcrainmaker.com/2021/11/whoop-platform-review.html |

---

## 7. Psychological principles driving repeat opens

| # | Mechanic | Evidence strength | How this design uses it |
|---|---|---|---|
| 1 | **Dynamic content at near-zero access cost** | **strong: peer-reviewed.** Checking habit = "brief, repetitive inspection of dynamic content quickly accessible on the device"; adding real-time information to a previously static screen *caused* checking to emerge. 82.3% of watch sessions are self-initiated (https://link.springer.com/article/10.1007/s00779-011-0412-2 · https://www.kostakos.org/papers/chi17.pdf) | The direct answer to "no number means nothing changes": the **word** changes six times on Alex's Tuesday from live sensor data while the score never moves off 62 |
| 2 | **Surviving the first 8 days** | **strong: peer-reviewed.** >50% of health-app users quit in week 1; those still engaged at day 8 gained **+25 days** median retention (https://arxiv.org/pdf/1910.01165) | Six of nine ladder rules need no history at all, so the wrist says something true and useful on day one. Cold start is named, never faked |
| 5 | **Uncertainty about the outcome** | **strong (mechanism), inferred (application).** Anticipatory dopamine ramp scales with uncertainty, maximal at P = 0.5 (https://pubmed.ncbi.nlm.nih.gov/12649484/) | The word is genuinely unpredictable between glances because its inputs are. **No manufactured variance anywhere** — every change traces to a sensor read |
| 6 | **Push the verdict at wake time** | **medium: vendor data.** Garmin's Morning Report is shipped, user-ordered, one press. No published effect size (https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-4D26FDDC-63BD-4910-95B8-98937FEC2545.html) | N1, plus `RelevantContext.sleep(.wakeup)` on the widget |
| 7 | **Delta-triggered notifications** | **strong, and unflattering.** 3.5× next-hour lift but only 1.04–1.3× over 24 h and **no measurable long-term retention effect**; only 9.4% of notifications produce any session (https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf) | Why there are only three notifications with a 2/day ceiling. N2 fires on a **class crossing**, never an absolute threshold, with a user-set threshold |
| 4 | **Bar over radial encodings** | **strong: peer-reviewed.** 159–285 ms vs 1548–1772 ms (https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf) | Zero rings in the entire design |

**Deliberately not used:** streaks (#8, **medium** only, and a streak rewards *wearing and opening*, not
recovering — https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/);
social comparison (#10, **weak**, no verified watch implementation exists in the research); committed
measurement sessions (#11, **weak/structural**).

---

## 8. Complication strategy

Three families, **three destinations, one deep link each, never shared** — R14/R15:
*"Define a different deep link for each complication you support… If all the complications you support
open the same area in your app, they can seem less useful"*
(https://developer.apple.com/design/human-interface-guidelines/widgets).

| Family | Content | Deep link |
|---|---|---|
| **`accessoryCircular`** | Word glyph centred + 3-segment band rail beneath, active segment filled with a white tick. `widgetLabel` on the bezel carries the full word | `laso://watch/verdict` → page 1 |
| **`accessoryRectangular`** | Row 1 glyph + WORD + micro-rail · row 2 imperative · row 3 a 7-day exercise-minute bar sparkline, today highlighted | `laso://watch/why` → page 2 |
| **`accessoryCorner`** | Word glyph + open corner gauge stroked in the band colour with a 2pt white tick at the active boundary. **No text** — corner text is 10.5–12pt and no word in the vocabulary truncates gracefully to 4 characters | `laso://watch/do` → page 3 |

`accessoryInline` is **not shipped**. This concept has exactly three destinations; a fourth family
would force either a shared deep link (R15 violation) or an invented fourth screen (depth violation).
That is the whole justification and it is not a capacity excuse.

Apple's own exemplar for the rectangular family is a graph, not a ring
(https://developer.apple.com/design/human-interface-guidelines/complications) — hence the sparkline.

**Why a user would give up a face slot — honestly.** Every other recovery complication on the market
shows a number set once each morning that then sits there. Apple is explicit that *"a static
complication that doesn't display meaningful data may be less likely to remain in a prominent position
on the watch face."* **This complication changed six times on Alex's Tuesday**, every change caused by
a real sensor read, and it is the only thing on the face that says what to *do* rather than what you
*are*. The counter-argument is §15 drawback 6, and it is serious.

The prototype renders both faces with the other slots filled by system complications, so the Laso ones
have to earn their place next to Weather, Activity and Timer at the same size.

---

## 9. Smart Stack strategy

**One widget, `accessoryRectangular` only.** `accessoryCircular` is technically eligible (R3) but a
50pt circle inside a 152 × 69.5pt card wastes 78% of the surface; shipping it would be filling a slot,
not using one.

Inside the 40mm floor of 152 × 69.5pt with 6pt padding → 140 × 57.5pt usable:

- **Row 1 (22pt)** — 16pt glyph + `WALK` at 19pt/600 in the band colour + a right-aligned `24 × 4pt`
  micro-rail with its white tick. For DRINK the rail is replaced by a live `4/8` count.
- **Row 2 (28pt)** — a full-width `Done` button running an `AppIntent`. 28pt is the HIG **minimum**
  control height (default 44pt); it is flagged in §10, not hidden.
- **Background** — band colour at 12% over black. Apple: *"Provide a colorful background that conveys
  meaning."* In **accented** rendering mode this background does not survive, so the word and the
  micro-rail carry all the meaning — R18 satisfied by construction.
- At ≥45mm the imperative line returns between the rows. It is dropped at 40mm because the word *is*
  the instruction and a bare `WALK` is still complete.

**The button label is always `Done`, for every word.** One label, one intent, no per-word table. This
is the Waterllama pattern (principle 14,
https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585) and it is this concept's Double-Tap
primary action — which is why the app itself never overrides Double Tap.

**When it should surface.** Do **not** set `TimelineEntry.relevance` — it is dead code on watchOS
(R12/anti-pattern #9: *"Smart Stacks on iPhone and iPad don't consider relevance information you
provide with your timeline provider's `relevance()` callback… `RelevanceConfiguration` API is available
in watchOS only"*, https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks).
Instead `TimelineProvider.relevance()` returns a `WidgetRelevance` built from four
`RelevantContext` clues (https://developer.apple.com/documentation/relevancekit/relevantcontext):

| Clue | Why |
|---|---|
| `sleep(.wakeup)` | The day's first word at the highest-intent moment (mechanic #6) |
| `sleep(.bedtime)` | SLEEP in the wind-down window |
| `fitness(_:)` | Re-surfaces the word after a workout, when it has genuinely just changed |
| `date(range:kind:)` 12:00–14:00 | The midday attention peak; the notification literature's best slot is 12:30 |

**`RelevanceConfiguration` (watchOS 26+) is deliberately not used**: per Apple, *"people can't
configure widgets that use a `RelevanceConfiguration` to appear in the Smart Stack, add them to the
Smart Stack, or pin them to a fixed location."* A once-a-day verdict wants a predictable, pinnable
position. Trade-off stated, not hidden.

---

## 10. Notification strategy

**Three notifications. Hard ceiling: 2 scheduled per day, plus at most 1 user-requested snooze.**

The budget comes straight from mechanic #7's unflattering finding: notifications buy an open *now*,
not a habit. So they are spent on the three moments where an open is worth the most, and never on
absolute-threshold states — anti-pattern #3, where Athlytic's stress alerts drew an explicit request
for *"a big friendly toggle to hush stress for a while"*
(https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/).
Anti-pattern #18 (82.3% of watch sessions are self-initiated) is why the complications and the widget
carry the load and the pushes stay this thin.

**No title contains health data** (R17). Every long look is the real channel; the short look never
carries the whole message.

| | Trigger | Short look | Actions |
|---|---|---|---|
| **N1 Morning verdict** | 20 min after the watch detects sleep end, or the stated wake time. Once/day | `Today's call` / `WALK — 20 minutes, easy pace. Readiness 62, down 9 from yesterday.` | `Got it` ← Double-Tap target · `How do you feel?` · `Show why` |
| **N2 The call changed** | The word **crosses a class boundary** (upkeep ↔ verdict-amber ↔ verdict-green ↔ REST). WALK→COAST does not fire; WALK→REST does. ≥3 h since any Laso push, 09:00–21:00, max 1/day. User-set threshold: `Off` / `Big changes only` (default) / `Any change` | `The call changed` / `REST — no training today. Resting heart rate is 3 above your normal.` | `Got it` · `Show why` · `Mute today` |
| **N3 Wind-down** | 60 min before bedtime target, **and only when** sleep debt > 180 min **and** bedtime drift > 30 min this week. For Alex: 22:20. Suppressed if N2 fired after 18:00 | `Wind-down` / `SLEEP — lights out by 23:20. You are 4h 20m short across 5 nights.` | `Got it` · `Remind me at 23:00` · `Mute today` |

Double Tap selects the first nondestructive action, so `Got it` is always first (R17). `Mute today`
silences N2 and N3 for 24 h — the "big friendly toggle" shipped rather than argued about.

**A static interface must be packaged with the app** and must render the word and imperative from the
payload alone, because *"the system defaults to the static interface when the dynamic interface is
unavailable, such as when there is no network or the iPhone companion app is unreachable"*
(https://developer.apple.com/design/human-interface-guidelines/notifications).

**The check-in modal** is reachable only from N1's second action. Not a tab, not in the page order.
One question, a crown-driven 5-position rail with `.click` at each detent, and a 44pt Save button —
against the shipping app's 15 targets at ~30 × 25pt each, which is exactly what the 44 × 44pt floor
exists to prevent.

**No notification in this design contains the banned string, and none exists to ask the user to go
somewhere else.**

---

## 11. Haptic language

Obeying R8 (*"When you engage the haptic engine, HealthKit stops gathering heart rate data until after
the haptic engine finishes"*), no background haptics outside a workout session, 100 ms minimum spacing
(https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)).

| Event | `WKHapticType` |
|---|---|
| Crown detent between vertical pages | *system default* — we never call `play(_:)` |
| Crown detent scrubbing the 7-day chart on page 2 | `.click` — legal because page 2 never samples heart rate |
| Crown detent on the check-in 1–5 rail | `.click` |
| `Mark done` (page 3) | `.success` |
| `Done` on the Smart Stack widget / via Double Tap | `.success` |
| `Save` on the check-in modal | `.success` |
| `WatchCommandResult.rejection != nil` from the phone | `.failure` |
| Word crosses into a **worse** class, app frontmost | `.directionDown` |
| Word crosses into a **better** class, app frontmost | `.directionUp` |
| N1 / N2 / N3 arriving | `.notification` — played by the system |
| **Anything while page 1 is visible** | **none** |

**The R8 fall-out, and why page 1 has no controls.** Rule 2 (BREATHE) needs a live heart-rate sample,
and page 1 is where that sample window is open. Page 1 therefore has zero controls and fires zero
haptics — there is no state-changing tap on it to require one. `.directionUp` / `.directionDown` are
queued and fired only after the window closes or the user leaves page 1.

This is not a compromise; it is the reason page 1 ended up as pure output. The cost is stated honestly
in §15 drawback 7.

---

## 12. What was deliberately excluded, and why

| Excluded | Why |
|---|---|
| **Any number on page 1** | The bet. A number would immediately become the hero and the word would become its label |
| **Live BPM anywhere** | That is concept 03. A ticking number out-competes a static word for attention and turns the entry screen into a feed |
| **`accessoryInline`** | Three destinations, three complications. A fourth family forces a shared deep link (R15) or an invented screen (depth) |
| **Streaks and "days in a row"** | **medium** evidence only, and a streak rewards wearing and opening, not recovering. Gentler Streak ships manual "On a Break / Sick / Injured" states so users can stop without penalty |
| **`RelevanceConfiguration`** | It forbids pinning. A once-a-day verdict wants a predictable position |
| **`HKWorkoutSession` / live workouts** | This concept never asks the user to start something timed on the wrist. The word points at the real world; a session would make the app the destination |
| **A stand-reminder notification** | Apple already ships one. STAND appears in the vocabulary but never as a push |
| **The check-in as a tab** | Kept as intent, moved to a modal behind N1's second action. A fourth tab would dilute a three-page structure that maps one-to-one onto three complications |
| **The quick-log screen** | Deleted per the critique. Water logging is a widget button with a visible running count |
| **`dayType` ("Progressive Overload")** | Removed from the wire format. It is training-theory jargon rendered as a status |
| **A vocabulary legend or onboarding screen** | The imperative sub-line explains the word every time |
| **Any ring, anywhere** | Principle 6. Even for the one hero value, the word replaced the gauge |

---

## 13. Expected opens per day

**App opens and complication views are different things and are counted separately.** Folding one into
the other is the standard dishonesty here.

| # | Trigger | Time | Mechanism | Opens |
|---|---|---|---|---|
| 1 | N1 arrives; user taps `Show why` or the body | ~07:05 | Push at wake (#6). Only 9.4% of notifications yield any session; a wake-time verdict with an explicit "Show why" affordance sits above that floor | **0.40** |
| 2 | Complication word visibly changed (WALK → STAND); user taps it | ~09:40 | Dynamic complication content (#1). Most changes are absorbed on the face without a tap | **0.30** |
| 3 | Smart Stack surfaced by the midday `date(range:)` clue; user crowns down, may tap `Done` | ~12:30 | Relevance clue (R12) + widget button. About half stay in the widget and never open the app | **0.50** |
| 4 | Word differs from what the user remembers from the morning | ~14:30 | Uncertainty (#5) — genuinely unpredictable between glances | **0.30** |
| 5 | Exercise goal crossed, word flips to COAST | ~18:30 | Complication change. `.directionUp` cannot fire (R8), so this arrives silently and is mostly absorbed | **0.20** |
| 6 | N3 wind-down (~3 nights/week for Alex, amortised) | ~22:20 | Push | **0.15** |
| 7 | Unprompted curiosity | any | Baseline | **0.20** |
| | | | **Total app opens** | **≈ 2.0/day** |

**Complication views, not opens.** CHI 2017 telemetry gives 142.1 watch sessions/day, 82.3%
self-initiated. With a Laso complication in a face slot the word is *seen* on a meaningful fraction of
those raises with no tap. Conservatively **20–30 verdict views/day**.

**Honest total: ~2 app opens and ~25 verdict views per day.**

That open count is **lower** than a live-gauge concept could claim, and it should be. This concept is
not trying to be opened; it is trying to be seen and obeyed, which is what R2 says the platform
rewards. Judge it on decisions-per-view, not opens-per-day.

---

## 14. Buildability against this codebase

Everything in this section was checked by reading the shipping source in this session, not taken from
the critique. File and line references are to `main` at `cbb674f` (v3.26).

### What exists today and is already used

| Field / API | Where | Status |
|---|---|---|
| `readinessScore` | `WatchShared/WatchBridge.swift` | Used. Page 2's `62` |
| `actionHeadline`, `actionDone` | same | Used. Page 3 |
| `updatedAt` | same | Used. The freshness footer and `from iPhone · 14:26` |
| `WatchBridge.stalePayloadInterval` | `WatchBridge.swift` — **verified `= 60 * 60`** | The 60-minute horizon the ladder's `phoneAware` guard uses |
| `WatchCommand.markActionDone(id:createdAt:)` | `WatchBridge.swift:97` | Exists. Page 3's button and the widget intent both enqueue it |
| `WatchCommand.journalTag(id:createdAt:category:value:)` | `WatchBridge.swift:99` | Exists. The DRINK path on the widget |
| `WatchBridge.watchAppGroup` + `cachedPayloadKey` | `WatchBridge.swift` | Exists. The complication extension reads the phone half from here with no session of its own |

### Dead fields this concept revives — **verified dead**

`WatchRootView.swift` renders `readinessScore` (line 57), `dayType` (64–65), `actionHeadline` (75) and
the done flag (86–95). It never touches:

| Field | Revived as |
|---|---|
| `readinessGrade` | The 3-segment band rail on every surface, and the ladder's `band` input |
| `actionDetail` | Page 3's `Keeps you inside your 8-12 strain window` |
| `actionIcon` | Page 3's leading glyph |

Three of ten payload fields are dead weight on the wire today. This concept uses all three without
adding a byte.

### New `WatchPayload` fields — five

```swift
let readinessLast7: [Int?]        // 7 entries, index 0 = today; nil renders "—", never a fake value
let restingHRBaseline: Double?    // bpm, 60-90 day baseline — the "+3" in RHR +3
let bedtimeTargetLocal: Date?     // tonight's target lights-out — ladder rule 3 and N3
let sleepDebtMinutes: Int?        // N3's copy and the SLEEP evidence line
let bodyStressFlag: String?       // "none" | "low" | "elevated" — from IllnessEarlyWarning
```

`dayType` is **removed** from the wire format.

### Native HealthKit on the wrist — the architectural change

**The watch target does not link HealthKit at all.** Verified:

- `project.yml` lists `LasoWatch` sources file by file: `LasoWatch`, `WatchShared`,
  `Core/Extensions/Date+Extensions.swift`. Nothing else.
- `LasoWatch/LasoWatch.entitlements` contains **exactly one key**, an App Group. No
  `com.apple.developer.healthkit`.
- `LasoWatchWidgets/LasoWatchWidgets.entitlements` is identical — one App Group, no HealthKit.
- Neither `Info.plist` contains `NSHealthShareUsageDescription`.

Ladder rules 2, 5, 6, 7, 8 and 9, the entire evidence line, the driver line and the 7-day sparkline all
depend on a wrist-side `HKHealthStore`. So this concept needs the HealthKit entitlement and usage
description added to **both** the app and the widget extension — R12 requires the sleep permission on
the extension anyway for the relevance clues.

### The one thing this concept cannot ship without — **verified, and it is worse than the critique says**

`PhoneWatchSession.shared.push(` is called from **exactly one place in the whole repo**:
`Modules/Dashboard/ViewModels/DashboardViewModel.swift:2265`.

`App/BackgroundRefreshCoordinator.swift` imports `WidgetKit`, writes a `WidgetReadinessSnapshot`, calls
`WidgetDataStore.shared.saveReadinessIfChanged` and `WidgetCenter.shared.reloadAllTimelines()` — and
never references `PhoneWatchSession`. **The iOS widget gets refreshed in the background. The watch does
not.**

Consequence, stated plainly: without wiring `BackgroundRefreshCoordinator` to call
`PhoneWatchSession.push()`, the payload goes stale within 60 minutes of the last phone-app open,
`phoneAware` flips false, **REST and TRAIN become permanently unreachable**, and the vocabulary
collapses to the five blue upkeep words. The app then nags about standing and drinking water and never
says anything about recovery — strictly worse than what ships today.

**This concept's floor is lower than the current app's floor, and it depends on phone-side work that is
not on the watch.** It is the single highest-risk item in the design.

### Other buildability findings from reading the source

- **`WatchCommand.checkIn` does not match this concept's modal.** Its signature is
  `checkIn(id:createdAt:sleepQuality:energyLevel:soreness:)` — three Ints (`WatchBridge.swift:98`).
  This concept asks **one** question ("How rested?") on a 1–5 crown rail. Either the case gains an
  optional single-value form or two values go as sentinels and the phone learns to ignore them. Not
  hard, but it is a wire-format change nobody would notice until integration.
- **`WATCHOS_DEPLOYMENT_TARGET` is `"10.0"`** in `project.yml`. Double Tap / `handGestureShortcut` and
  the `WidgetRelevance` relevance API are later-OS surface, so the deployment target has to move. The
  research set could **not** verify the exact minimum — Apple's "Enabling the double-tap gesture"
  article 404'd for every research agent (synthesis §7) — so treat the exact number as unconfirmed and
  check it against the SDK before committing.
- **Notifications are entirely new.** The watch target sends and handles zero notifications today. N1
  and N3 are local `UNNotificationRequest`s scheduled on the watch. N2 needs the ladder to re-run in a
  `WKApplicationRefreshBackgroundTask`, which under R4/R9 is ~4 tasks/hour, a few seconds each, and
  **not guaranteed** — so N2 is best-effort by construction.
- **The complication extension needs its own HealthKit reads**, not just the App Group cache, because
  the word is computed from live wrist data. That is a bigger change to
  `ReadinessComplication.swift` than "add a colour".

### Honest summary of the build

| Layer | Size of the change |
|---|---|
| Watch UI (3 pages, modal, states) | Full rewrite of `WatchRootView`, delete `WatchJournalView`, rebuild `WatchCheckInView` |
| Watch data | **New**: a HealthKit layer on watchOS that does not exist today, plus the ladder |
| Wire format | 5 added fields, 1 removed, 1 command case widened, 3 dead fields revived |
| Widget extension | HealthKit entitlement + usage description + its own reads + an `AppIntent` + relevance |
| Notifications | All new on the watch |
| **Phone** | **`BackgroundRefreshCoordinator` must call `PhoneWatchSession.push()`. Without it the concept is worse than what ships.** |

---

## 15. Honest drawbacks, and who this fails

**1. Always-On is a structural loss, and it is worse here than for any other concept.**
The hero *is* health data — "REST" discloses recovery state as completely as "38" does — so R7 forces
it to a blank stroked rectangle. A gauge concept can stroke its ring neutral and still convey "there is
a level here"; this concept shows literally nothing. On a Series 5-and-later wrist that spends most of
the day in reduced luminance, that is a large fraction of all possible impressions worth zero. There is
no design fix.

**2. The dynamism argument is an inference, not a measurement.**
The synthesis flags this explicitly in §7: *"The central 'depleting gauge drives more checking than a
static score' claim has no direct empirical test."* My mirror-image claim — that a word changing six
times a day sustains checking as well as a number changing continuously — is **equally unmeasured**,
and it is the load-bearing assumption of the entire concept.

**3. The vocabulary is a compression, and users will notice.**
Readiness 46 and readiness 66 both produce WALK. Eight words over a 0–100 space is roughly 12-point
resolution. A user who works this out concludes the word is coarse and goes looking for the number — at
which point this is concept 01 with an extra crown turn in front of it.

**4. Who this fails: athletes and quantified-self users.**
Anyone running structured training needs the number, the strain target and the trend, every time.
Telling them WALK when they planned intervals is not guidance, it is an obstacle, and a two-page detour
to the data they came for will be resented. Bevel's audience and Athlytic's audience are both
explicitly this person.

**5. Principle 17 bites harder on a word than on a number.**
DC Rainmaker got 80% recovery after 3 h 15 m of jet-lagged sleep while he *"still felt like crap"*
(https://www.dcrainmaker.com/2021/11/whoop-platform-review.html). A wrong **number** is a wrong
measurement you can argue with. A wrong **word** is a wrong *instruction*, and being told REST on a
morning you feel excellent is more insulting than seeing 44. The low-regret vocabulary limits the
damage; TRAIN and REST still carry it.

**6. The strongest single argument against this concept.**
**R2 says the app is not the product, and this concept's declared primary surface is the app screen.**
It is arguing with the platform's own guidance. The mitigation — three complications and a widget
carrying the identical word — works, but it works by quietly converting this into a complication-first
concept, at which point a fair reviewer should ask what the app screen is still for. The honest answer
is that the *why* has to live somewhere and page 1 is that destination's front door rather than its
purpose. That is defensible. It is not strong.

**7. Most word changes arrive silently.**
No background haptics outside a workout (R8), so `.directionUp` / `.directionDown` fire only when the
app is already frontmost — which is when the user is already looking. The six changes a day are real;
the *notification* of them mostly is not.

**8. The buildability risk is concentrated in one phone-side change.** See §14. Verified in source, and
worse than the critique implied: `BackgroundRefreshCoordinator` refreshes the iOS widget and ignores
the watch entirely.

### Deviations from the approved spec, found while building

| Spec said | What was built | Why |
|---|---|---|
| Element 1: *"If `phoneAware == false`: outline-only, no tick."* Stale row: *"the active segment becomes a stroked outline with a 1.5pt dashed border, keeping the tick."* | Split into two flags: `phoneAware` (gates ladder rules 1 and 4) and `bandKnown` (drives rail and word colour). Payload **absent** → outline, no tick. Payload **stale** → dashed, tick kept | The two spec sentences contradict each other. A stale band is *known but old*; an absent band is *unknown*. Only the second justifies hiding position |
| REST's colour is listed as `band (poor #E05C64)` | REST renders in **whatever the band is**, which for the N2 scenario is amber, because ladder rule 1 also fires on `bodyStressFlag == "elevated"` while the band is still fair | Following the stated rule ("verdict words take the band colour") literally. **This is a real weakness**: an amber REST is a weaker pre-attentive signal than a red one. The word and the imperative still carry it, but a reviewer should decide whether REST should force the poor colour regardless of band |
| Imperative sub-line ≤22 chars | `One minute, slow out-breath` is 27 and `You have done enough today` is 26 | The spec's own copy exceeds its own budget. Implemented as a size-rung drop plus `minimumScaleFactor`. **At 40mm those two lines land on the 12pt HIG minimum with nothing left below it** |
| Rectangular complication `178.5 × 56pt` (45/49mm) / `159 × 50pt` (41mm) | `146 × 50pt` at the 40mm canvas | A 40mm screen is 162pt wide; 159pt leaves no margin. No 40mm row exists in Apple's published table (synthesis §7) |
| Alex data covers 14:32 only | Freshness values for the other eight times in the Tuesday timeline are plausible fill-ins | Only 14:32 is canonical. They exist to show all three freshness words; they are not claimed as shared-user data |

---

## 16. The 5-second test — every surface, failures shown

Honest, per surface. Median smartwatch session is exactly **5.0 s**
(https://www.kostakos.org/papers/chi17.pdf).

| Surface | Verdict | Reasoning |
|---|---|---|
| **Page 1 — VERDICT** | **PASS** | One uppercase word at 52pt plus a pre-attentive band colour and a 3-segment position. The decision is available in roughly 0.5 s, before any reading. This is the only surface that *has* to pass |
| **Page 2 — WHY** | **FAIL — by design** | A 52pt number, three labelled bars, a three-metric driver line and a source tag is a 7–9 s read. It is not a glance screen and is not reachable without a deliberate crown turn. Calling it a pass would be dishonest |
| **Page 3 — DO** | **PASS, marginally** | Headline plus a full-width button is ~3 s. The two-line detail pushes it to ~5 s if actually read, and it is skippable |
| **`accessoryCircular`** | **PASS** | Glyph plus 3-segment rail. No reading required |
| **`accessoryRectangular`** | **PASS at row 1** | Word and micro-rail read in ~1 s. The 7-bar sparkline is a second-order read most glances will not perform — which is fine, it is context, not the verdict |
| **`accessoryCorner`** | **PASS** | Glyph plus corner gauge |
| **Smart Stack widget** | **PASS** | Word plus one button |
| **Launch / wrist raise** | **PASS** | The cached word is on screen before the HealthKit read returns. No spinner, ever |
| **Cold start** | **PASS** | The word still fires from the wrist-only subset; `Recovery verdict: 3 more nights` is second-order |
| **Empty** | **PASS** | `Nothing yet today` is the answer in three words |
| **Stale** | **PASS** | Word and imperative unchanged; the dashed rail and the footer are second-order |
| **Error — phone unreachable** | **PASS** | Word, imperative and evidence all real, all watch-native |
| **Error — HealthKit denied** | **FAIL** | Three lines of settings instruction, ~8 s. Unavoidable: a permissions dead-end cannot be a glance, and shortening it would make it unactionable. This is also the only state in the whole design with no word, because with no sensor reads there is nothing honest to say |
| **N1 / N2 / N3 short look** | **PASS** | Title plus a body whose first word is the instruction |
| **N1 / N2 / N3 long look** | **FAIL** | Carries the bar comparison and the driver line by design. It is the one place per day where a longer read is warranted, because the wrist is already raised and the user chose to look |
| **Check-in modal** | **N/A** | Not a glance surface. A deliberate ~10 s input reached from one notification action |
| **Always-On** | **STRUCTURAL FAIL** | Nothing is readable. That is R7 working correctly, and it is a real cost, not a design win |

**Five failures. Three deliberate (page 2, the long looks, Always-On), one forced (HealthKit denied),
and one — Always-On — that this concept pays more heavily than any other concept in the set.**

---

## Prototype notes

- `02-verdict.html` is a single file. No network, no libraries, no fonts, no images. Opens from
  `file://`.
- The ladder is real JavaScript, not a lookup table. A self-check re-runs it against all nine of
  Alex's Tuesday evaluations on load and reports `9/9` in the dev panel; if the ladder ever drifts, the
  check goes red.
- Dev toolbar: 46mm / 40mm · loaded, loading, cold start, empty, phone unreachable, HealthKit denied,
  stale · Always-On on/off · readiness band across all three colours (poor → REST, fair → WALK,
  optimal → TRAIN) · the nine times of Alex's Tuesday · face slot labels · **Fire Double Tap**.
- Crown: mouse wheel over the watch, or ↑/↓. Crown presses are never handled. `.click` detents fire
  on the page-2 7-day scrub and the check-in rail; page changes use system detents and the app never
  calls `play(_:)` for them.
- Every state-changing tap shows a pulse ring at the screen edge and names the real `WKHapticType`
  underneath, and the last six haptics are logged in the right-hand column.
- A `#screen=app&page=1&canvas=40&state=stale&aod=1&band=poor` URL hash deep-links any state, for
  reviewers who want to link a specific screen.
