# Concept 03 — Live Pulse (`pulse`)

Rationale for `03-pulse.html`. Every URL below appears in one of the six files in
`design/watch-v2/research/`. Nothing is invented. Evidence strength is marked per claim:
**A** = peer-reviewed measurement or first-party platform documentation ·
**B** = vendor documentation or reproducible product behaviour ·
**C** = single reviewer, inference, or snippet-level.

---

## 1. One-sentence philosophy

The wrist owns *now* and the phone owns *history*, so the only number on the entry screen is one the
watch measured itself, thirty seconds ago, with the phone in another room.

---

## 2. The question it answers first

**"Is my heart rate right now high or low *for me*, at this hour, on a normal day?"**

Not "how recovered am I" — that needs a 60-day baseline the watch cannot hold (R6,
https://athlytic.github.io/athlyticapp/troubleshooting/) and it is concept 01 and 02's job. Not
"what should I do" — that needs a causal model this concept does not have.

The question was chosen because it is the only health question a person actually asks *at the
moment they raise their wrist*, and it is the only one the wrist can answer completely on its own.
Apple's built-in Heart Rate app answers the first half of it — "74" — and refuses the second half.
A person who reads 91 with no reference frame has been handed a number, not an answer. That gap is
the whole concept, and §15 states honestly how thin it is.

**The constraint everything bends around, stated up front:** live heart rate exists only while the
app is frontmost. In the background it does not exist at all — R9 gives "a few seconds" of
non-guaranteed execution (https://developer.apple.com/documentation/watchkit/background-execution),
R16 caps extended runtime and allows one session type per app
(https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions), and no session
type covers "watch a pulse". Off-app, every surface shows *the last HealthKit sample and its age*,
never a fake live number. The age stamp is not an apology; it is the design.

---

## 3. Screen-by-screen reasoning, element by element

### Fixed constants (so two builders produce identical output)

```
NOW                74 bpm, sitting, Tue 14:32     (given in PROTOTYPE-SPEC.md)
RESTING_TODAY      58                              (given)
RESTING_BASELINE   55, 60-day, phone               (given)
TODAY_RANGE        52 … 141                        (given)
TODAY_LOW_AT       04:20 · TODAY_HIGH_AT 08:12     (fixed by this concept)
HOUR_BAND_1400     66 … 82  (p25 … p75, last 7 d)  (fixed by this concept)
USUAL_DAILY_PEAK   128, median of 7 daily maxima   (fixed by this concept)
HRV                48 ms last night, 54 ms 7-day   (given)
READINESS          62, "Moderate", iPhone 09:12    (given)
STEADY_RESULT      66 after 60 s                   (fixed by this concept)
GAUGE_SCALE        40 … 160 bpm, fixed forever
```

**The position formula, used on every single surface:**
`x(v) = (clamp(v, 40, 160) − 40) / 120 × trackWidth`

At `trackWidth = 188` (46 mm): 52→18.8 · 58→28.2 · 61→32.9 · 66→40.7 · 74→53.3 · 82→65.8 ·
91→79.9 · 102→97.1 · 108→106.5 · 141→158.2. The prototype computes these live; the rendered DOM
was checked and returns `left: 51.27px` for the 4 pt marker at 74 (centre 53.27) and a zone from
`40.73` to `65.80`. That is principle 5 — one scale, reused — made literal.

### The band verdict table (the only threshold table this concept adds)

| Marker vs the personal hourly band | Word | Colour | Colour-free carrier |
|---|---|---|---|
| below p25 | **Calm** | `optimal` #33C48D | marker sits **left of** the grey zone |
| p25 … p75 | **Typical** | `textPrimary` #F2F2F6 | marker sits **inside** the grey zone |
| above p75, below p75+20 | **Up** | `fair` #E3B45A | marker sits **right of** the grey zone |
| ≥ p75+20 | **Well up** | `poor` #E05C64 | marker sits **far right**, past the zone |

`strongExcursionBpm = 20` is a design constant, not a medical threshold, chosen so it never fires on
standing up or a warm room. There is **no clinical source** for this table and the UI never implies
one — it is a purely personal statistical comparison with both operands printed on screen.

**For Alex right now the answer is "Typical" and the marker is white.** The hero screen is
deliberately colourless for the shared user. A design that is good at saying *nothing is happening*
is the only kind that earns the right to say *something is*.

---

### Screen 1 — Now (TabView page 1, the entry screen)

**The one decision: do I need to do something about this, or is this just me at 2pm?**
3 text lines plus one button. Layout at 46 mm, 10 pt padding, 188 pt content width.

| Element | Why it is there, and why in that form |
|---|---|
| **Status chip** `● LIVE`, 11 pt, `textTertiary`, 6 pt dot in the band colour | Names the freshness *channel* before the number. The dot pulses 0.85→1.0 every 2 s so "live" is a behaviour, not a claim; it is killed under reduced motion and under Always-On. Every off-app surface prints an age instead — anti-pattern 2 (https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match). |
| **Hero** `74` at 52 pt/600, tabular, then `BPM` at 12 pt baseline-aligned | The one number on the screen. Baseline-aligned, not centre-aligned, so the numeral and the unit read as one token. Left-aligned at x=10 rather than centred because the eye lands on the left edge and the number is the first thing to find. |
| **Verdict** `Typical for 2pm` at 17 pt/600, in the band colour | Principle 3: never ship a bare number. The verdict names the *hour*, which is the whole claim — 74 is not "normal", it is normal *at 2pm for Alex*. |
| **The band** — 188 × 10 pt track (40→160 bpm), a grey `usual zone` from x(66) to x(82), a 2 pt rest tick at x(58), a 4 pt marker at x(74) with a 1.5 pt black outline | The core element and the reason the concept exists. The zone is `surfaceElevated` grey **on purpose**: the zone is a *place*, not a verdict. The marker's position relative to it is the verdict, and that reads in pure greyscale (R18). The black outline exists so the marker separates when it overlaps the zone edge. The marker animates 220 ms `cubic-bezier(.22,.61,.36,1)` on each new sample, and not at all under reduced motion or Always-On. |
| **Caption** `rest 58 · usual 66 to 82` at 11 pt | Both operands of the comparison, printed. This is the answer to anti-pattern 4, black-box scores (https://www.autonomous.ai/ourblog/bevel-app-review). Dropped to `usual 66 to 82` at 40 mm. |
| **Action** one 188 × 44 pt row, `Steady · 60s` | Principle 14: the verdict screen gets exactly one action and it is the obvious next step (https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface). |

At 40 mm the hero drops to 40 pt, the verdict to 16 pt, the track to 8 pt, the marker to 3.5 × 15 pt,
and the caption loses its `rest 58` half. Verified by rendering, not by arithmetic.

### Screen 2 — Steady (pushed, `NavigationStack`, depth 2)

Three states on one non-scrolling pushed screen. Non-scrolling is what makes the Double Tap primary
action legal here (R11, https://developer.apple.com/design/human-interface-guidelines/gestures).

- **2a Ready** — `Steady` / `Rest your arm and stay still for 60 seconds.` / a 188 × 60 pt `Start`
  button carrying `handGestureShortcut(.primaryAction)`.
- **2b Running** — a bare integer countdown, `seconds`, `Stay still`. **No BPM while running.**
  That removes the observer effect, removes the Always-On redaction problem entirely, and removes the
  reason to keep staring at the screen. No ring, no bar, no spinner — R13 plus Apple's rule against
  indicators that make people keep watching (https://developer.apple.com/design/human-interface-guidelines/feedback).
- **2c Result** — `AFTER 60s` / `66 BPM` / `Settled` / the same band with the marker at x(66) and a
  ghost tick at x(74) showing where it started / `8 down from 74 · back inside your usual`.

Result verdicts make **no causal claim**: `drop ≥ 6` → Settled · `drop 0–5` → Holding · `rose` →
Still up. The second half of the caption is always the band fact.

In the prototype the countdown runs at 6× so a reviewer does not wait a real minute. Everything else
is real time.

### Screen 3 — Today (page 2)

**The one decision: has today asked more of me than usual?**

24 bars, 3 pt wide with 2 pt gaps (118 pt, centred), mapping the *hourly average* onto 0–70 pt using
the same fixed 40–160 scale as Screen 1. Elapsed hours are `textSecondary`; the current hour is
`primary` **and 4 pt wide instead of 3** — the width carries "now" without colour (R18). Future
hours are 2 pt baseline stubs so the unfinished remainder of the day is visible.

The dashed 1 pt rest line at 58 bpm is the element that makes this a chart rather than decoration.
Without a reference frame a sparkline is an ornament.

Crown scrub is the genuine crown-driven value: turning the crown moves a 1 pt scrub line across the
24 bars, the two footnote lines swap to that hour (`08:00 avg 96 · usual 71 to 88` / `Up for 8am`),
and a `digitalCrownAccessory` appears beside the crown showing the scrubbed hour. Scrubbing past
hour 23 or before hour 00 hands crown control back to page navigation, so nobody gets trapped.

`.discreteAverage` is stated as *average*, not median, because HealthKit offers min/max/average only
and the label must not claim a statistic the query cannot produce.

### Screen 4 — Baseline (page 3)

**The one decision: has my reference frame itself shifted this week?** Zero prose sentences; three
labelled data rows and one source stamp.

Paired horizontal bars, never rings: bar comparison reads in 159–285 ms against a radial bar's
1548–1772 ms (https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf).
Deltas carry a **sign glyph** (`+3`, `−6`) so the amber never works alone.

Row 3 is where the phone's verdict honestly belongs: `Readiness 62 Moderate`, stamped
`iPhone 09:12`. The `Moderate` grade is `WatchPayload.readinessGrade` — a field the app already
sends today and no view has ever rendered (§14).

The footer — *"Watch data updates about 4 times an hour, so it can differ from your phone."* — is
Athlytic's move shipped as product copy: publish the platform cap before the user files the bug
(https://athlytic.github.io/athlyticapp/troubleshooting/ vs
https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match).

### Navigation model

Vertical `TabView`, three pages, plus one push. **Maximum depth 2. No page scrolls.**

```
Now  ←→ crown/swipe ←→  Today  ←→  Baseline
 └── push → Steady (ready → running → result) → pop
```

Each page down is a slower clock: this second, today, this week. That is progressive disclosure of
"why" — glance → factors → detail (principle 10).

---

## 4. Why this works on a watch specifically

Every other concept in the set could, in principle, be a phone widget. This one cannot.

1. **The hero number does not exist on the phone.** A live heart rate requires a sensor strapped to
   an artery. The iPhone has no such sensor. Screen 1's entire content is unbuildable on the device
   the user is holding.
2. **The question is asked at the wrist.** "Why does my heart feel fast?" is a bodily sensation. The
   watch is already touching the place the sensation is. Reaching for a phone to answer it inserts a
   10-second fetch into a 2-second question.
3. **It never needs the phone.** Screens 1, 2 and 3 are entirely native HealthKit. Screen 4 needs one
   cached field. The current shipping app's most frequent message is a request to go use the phone
   (`01-CURRENT-APP-CRITIQUE.md` §3); this concept structurally cannot produce that message.
4. **The complication moves all day**, which is exactly the property Apple says keeps a complication
   on a face and the checking-habit literature says is required for a habit to form
   (https://developer.apple.com/design/human-interface-guidelines/widgets ·
   https://link.springer.com/article/10.1007/s00779-011-0412-2).

**What would be worse on a phone:** Screen 4. It is a reference screen read maybe once a week, and
the phone shows it better at breakfast. That is why it is the deepest page and not the entry.

---

## 5. watchOS HIG guidance applied

Every rule R1–R18 from `research/00-SYNTHESIS.md`, and how the prototype obeys it.

| Rule | How this design obeys it | Strength |
|---|---|---|
| **R1** interactions are seconds | Three buttons in the entire app. Screen 1 reads in ~1 s. https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos · https://www.kostakos.org/papers/chi17.pdf | **A** |
| **R2** the app is not the product | 3 complications + 1 Smart Stack widget carry the concept; the app is the payoff, not the entry. https://developer.apple.com/documentation/watchos-apps | **A** |
| **R3** only 2 families reach the Smart Stack | Exactly one `accessoryRectangular` widget. Corner and circular stay on the face. https://developer.apple.com/design/human-interface-guidelines/widgets | **A** |
| **R4 / R5** refresh budgets, never real-time | Every off-app surface prints an age (`6m`), goes dashed past 20 min, and §9 of the prototype states the ~4/hour ceiling. https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date | **A** |
| **R6** watch HealthKit reaches ~7 days | The hourly band, the 7-day HRV average and the 7-day peak all sit inside 7 days. Only the 60-day resting baseline crosses the wire. https://athlytic.github.io/athlyticapp/troubleshooting/ | **B: vendor** |
| **R7** redact health data in Always-On | Number replaced by bars, marker removed entirely, rest tick removed, zone fill removed, caption removed, all colour dropped. Dimming is not redaction. https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state | **A** |
| **R8** no haptic while sampling HR | Zero haptics on Screen 1 and Screen 2b; strict fire-then-install and stop-then-fire ordering. https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:) | **A** |
| **R9** background is "a few seconds" | The design states outright that live HR does not exist in the background. https://developer.apple.com/documentation/watchkit/background-execution | **A** |
| **R10** crown is navigation, press is reserved | Crown press never handled. Scrub on Today is Apple's own second endorsed pattern (World Clock). https://developer.apple.com/design/human-interface-guidelines/digital-crown | **A** |
| **R11** Double Tap conflicts with vertical tabs | `primaryAction` set **only** on the pushed, non-scrolling Steady screen. Firing Double Tap anywhere else in the prototype prints the reason it is ignored. https://developer.apple.com/design/human-interface-guidelines/gestures | **A** |
| **R12** relevance on watchOS is a different API | `TimelineProvider.relevance()` → `WidgetRelevance`. `TimelineEntry.relevance` is never used. https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks | **A** |
| **R13** no spinners | Loading shows the cached number; Steady shows a determinate integer countdown. https://developer.apple.com/design/human-interface-guidelines/feedback | **A** |
| **R14** static surfaces get deleted | The complication value moves all day — the one property a frozen morning score cannot have. https://developer.apple.com/design/human-interface-guidelines/widgets | **A** |
| **R15** sizes, type and touch floors | Widget designed to the 152 × 69.5 pt floor; every control ≥ 44 pt; 11 pt minimum type, used only for units, timestamps and deltas; line widths ≥ 2 pt. https://developer.apple.com/design/human-interface-guidelines/complications · https://developer.apple.com/design/human-interface-guidelines/accessibility | **A** |
| **R16** extended runtime capped and single-type | No session claimed. Steady runs inside the ~2 min frontmost window. https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions | **A** |
| **R17** short look is not a channel | N1's short look carries **no number**; the long look carries the value, the chart and the actions. https://developer.apple.com/design/human-interface-guidelines/notifications | **A** |
| **R18** colour never alone | Word, marker position, stroke style, bar width, sign glyph — five carriers, tabulated in §10 below. https://developer.apple.com/design/human-interface-guidelines/widgets | **A** |

Also applied: *"Use vertical pagination to separate multiple views into distinct, purposeful
pages… In watchOS, this design is more effective than horizontal pagination or many levels of
hierarchical navigation"* (https://developer.apple.com/design/human-interface-guidelines/tab-views),
and *"prefer transitioning an interactive component to an unavailable appearance — don't just remove
it"*, which is why the Steady button is disabled and not deleted in the no-contact state.

---

## 6. UX principles used, and the mechanism

| # | Principle | Mechanism in this design | Strength |
|---|---|---|---|
| 1 | Readable in 5 s at 28 cm, off-axis | Screen 1 stacks three pre-attentive channels that agree: numeral size, colour, marker position. https://www.kostakos.org/papers/chi17.pdf · https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf | **A** |
| 2 | Complication + widget are the product | Three complications and one widget, each with its own deep link and its own destination. https://developer.apple.com/documentation/watchos-apps · https://www.myhealthyapple.com/monitor-hrv-apple-watch-heartanalyzer/ | **A** |
| 3 | Never ship a bare number | `74` is always paired with `Typical for 2pm`; `62` is always paired with `Moderate`. https://support.google.com/fitbit/answer/14236710?hl=en · https://developer.whoop.com/docs/whoop-101/ | **A/B** |
| 5 | One scale, reused | 40–160 bpm on Screen 1's band, Screen 3's sparkline, both complication gauges and the widget strip. One position formula everywhere. https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score | **B** |
| 6 | Bars, not rings, for comparison | Zero rings in the whole concept, including the Steady countdown. 159–285 ms vs 1548–1772 ms. https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf · https://developer.apple.com/design/human-interface-guidelines/complications | **A** |
| 7 | Show a slope, not just a level | Screen 3 and the rectangular complication both show the day's shape against the rest line. https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html · https://autosleepapp.tantsissa.com/watch-use | **B** |
| 8 | Separate the frozen verdict from the live feed, and name them differently | `Pulse` (live, watch-owned, Screen 1) vs `Readiness` (frozen, phone-owned, Screen 4, source-stamped). Athlytic's Recovery-vs-Battery split, applied structurally. https://www.athlyticapp.com/getting-started | **B** |
| 10 | Progressive disclosure: glance → factors → detail | Screen 1 → Screen 3 → Screen 4, each a slower clock. https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html | **B** |
| 11 | Name the cold start, never fabricate | `Learning your usual` + `7 days of wear and this gets a band.` https://support.google.com/fitbit/answer/14236710?hl=en · https://ouraring.com/blog/cardiovascular-age/ | **B** |
| 12 | Publish the staleness rule in-product | Screen 4's footer, verbatim in the UI. https://athlytic.github.io/athlyticapp/troubleshooting/ · https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match | **B** |
| 14 | Verdict screen gets exactly one action | Screen 1 has one button, one press from the verdict to a measurement — Garmin's stress-glance-to-Breathwork path. https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-DD8EE575-CC72-4829-B4C8-4BE1F8D3473E.html · https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585 | **B** |
| 15 | One deep link per complication | Three families, three destinations, no sharing. https://developer.apple.com/design/human-interface-guidelines/widgets · https://heartwatch.tantsissa.com/user-guide/quick-guide | **A/B** |
| 16 | Tiny colour system, never load-bearing alone | Four states, four words, four positions, reusing the existing `optimal`/`fair`/`poor` ramp. Nothing new. https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path | **A/B** |
| 17 | A score that contradicts felt state is worse than no score | This concept ships **no score**. It ships a measurement and a personal reference, so it is structurally incapable of the DC-Rainmaker failure (80 % recovery on 3 h 15 m of sleep). https://www.dcrainmaker.com/2021/11/whoop-platform-review.html | **B/C** |

**Principle 4 — "make the words an imperative" — is deliberately not applied**, and that is a
departure that needs its justification stated. An imperative requires a causal model. `74` at 2pm
can be caffeine, a phone call, standing up, or a warm room. Telling the user what to do on that
basis would be exactly the black-box behaviour anti-pattern 4 describes. The concept states the fact
and offers the measurement; the imperative belongs to concept 02 and the "why" to concept 08. This
is also this concept's largest product weakness — see §15.

**Anti-patterns explicitly avoided:** phone-dashboard mirroring (1), a live-feeling stale
complication (2), absolute-threshold anxiety alerts (3), black-box scores (4), radial encodings (5),
spinners (6), static complications (7), `primaryAction` on a tab page (8),
`TimelineEntry.relevance` (9), a haptic while reading heart rate (10), raw scores in Always-On (11),
incompatible scales (12), band-label copy drift (13), deep hierarchy (14), a shared deep link (15),
metaphors that break on imperfect wear (16), notifications as retention (17), and an app that only
exists behind a push (18).

Anti-pattern **16** is the one this concept is *structurally immune* to. Live HR is a measurement,
not an accumulator. Take the watch off for three hours and there is simply no sample for those
hours — nothing "resets", nothing lies. That is Body Battery's documented weak point
(https://www.androidauthority.com/garmin-body-battery-1209128/).

---

## 7. Psychological principles that drive repeat opens

| Rank | Mechanic | Application | Evidence |
|---|---|---|---|
| **1** | **Dynamic content at near-zero access cost** | The complication's number and marker visibly move all day inside R4's ~4 updates/hour. Oulasvirta's field experiment found that adding real-time information to a previously static screen *caused* checking to emerge. This is the concept's central bet and its best-supported one. | **strong: peer-reviewed** https://link.springer.com/article/10.1007/s00779-011-0412-2 · https://www.kostakos.org/papers/chi17.pdf |
| **2** | **Surviving the first 8 days** | Live HR is fully correct on install day, with no baseline, no phone and no history. >50 % of health-app users discontinue in week 1; the sub-cohort still engaged at day 8 gained **+25 days** median retention. Nothing else in the concept set can claim day-1 correctness. | **strong: peer-reviewed** https://arxiv.org/pdf/1910.01165 |
| **4** | **Bar encodings over radial** | Zero rings anywhere, including the countdown. 159–285 ms vs 1548–1772 ms against a 5 s budget. | **strong: peer-reviewed** https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf |
| **5** | **Uncertainty about the outcome** | A live pulse is genuinely unpredictable between glances, close to P = 0.5 for direction, and sustained anticipatory dopamine is maximal at P = 0.5. **No variance is manufactured** — the number is always the true sample, so principle 17 is not violated. | **strong (mechanism), inferred (application)** https://pubmed.ncbi.nlm.nih.gov/12649484/ |
| **7** | **Delta-triggered notifications** | N1 fires on change vs a 7-day average, never on absolute state, capped at 3 per rolling 7 days. Notifications buy a 3.5× next-hour open but only 1.04–1.3× over 24 h and **no measurable long-term retention effect**. | **strong** https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf · https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/ |
| **9** | **Resumption cue** | Screen 3's future hours are visible empty stubs. Justified as the **Ovsiankina** resumption effect, explicitly **not** as Zeigarnik memory, which fails to replicate in the 2025 meta-analysis. | **mixed** https://www.nature.com/articles/s41599-025-05000-w |
| **11** | **Committed measurement session** | Steady is 60 s of deliberate stillness, not a glance. Welltory's 3–5 min Breathe session is the precedent, shortened because 60 s is what a wrist-up posture actually supports. | **weak/structural** https://help.welltory.com/en/articles/4241383-taking-measurements-with-your-apple-watch |

**Mechanic 8 (streaks) and 10 (social comparison) are not used.** Streaks reward wearing and opening,
not recovering — a real risk for a recovery product, which is why Gentler Streak ships manual
"On a Break / Sick / Injured" states (https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/).
Mechanic 10 has **no verified watch-side implementation anywhere in the research** and is treated as
unproven (https://gadgetsandwearables.com/2025/01/24/whoop-daily-outlook/).

**Mechanic 3 (goal gradient) is not used either**, and it should be named as a loss. A live pulse has
no target and no shrinking distance, so the strongest motivational mechanic in the research set does
not apply to this concept at all. Concepts 01, 07 and 09 get it for free.

---

## 8. Complication strategy

Three families, three destinations, three deep links, **no sharing** — R14/R15: *"Define a different
deep link for each complication you support… If all the complications you support open the same area
in your app, they can seem less useful."*
(https://developer.apple.com/design/human-interface-guidelines/widgets)

| Family | Name | Content | Deep link |
|---|---|---|---|
| `accessoryCircular` | **Pulse** | Open gauge, 40→160 bpm, 2.5 pt stroke, 270° sweep with the gap centred at the bottom. Centre `74` in ≤3 glyphs at 14.5 pt (45 mm) / 12.5 pt (41 mm). `widgetLabel` = `bpm`. Gauge fill takes the band colour; the needle *position* carries the value independently of hue. **A sample older than 20 min renders the arc dashed, never `--`.** | `laso://watch/pulse/now` |
| `accessoryRectangular` | **Pulse Today** | Row 1: `74 BPM` + right-aligned `6m`. Row 2: a 12-bar sparkline of the last 12 hours with the current hour 4 pt wide, a dashed rest line, and `rest 58`. | `laso://watch/pulse/today` |
| `accessoryCorner` | **Rest** | Small open gauge 40→80 bpm with the needle at today's resting HR (58) and a 2 pt tick at the 60-day baseline (55), plus curved text `REST 58`. | `laso://watch/pulse/baseline` |

`accessoryInline` is **deliberately not shipped**. It offers one tap target and one row of text, and
there is no fourth destination worth a distinct deep link. Shipping it would force either a shared
link (R15 violation) or a fourth screen the concept does not need.

The rectangular family is the strongest-justified surface in the whole set: **Apple's own published
exemplar for that family is a 24-hour heart-rate graph**
(https://developer.apple.com/design/human-interface-guidelines/complications).

### Why would a user give up a face slot for this?

**The case for.** No Apple Watch face currently shows a heart rate *with a reference frame*. Apple's
own Heart Rate complication shows a bare number — anti-pattern 3 territory: a person who sees 91 has
no idea whether 91 is normal for them at 3pm. This gauge shows the number, its position in a personal
band, and its age, in 50 × 50 pt. And unlike a recovery score it **visibly moves through the day**,
which is the property Apple says keeps a complication in a prominent position (R14) and the property
the checking-habit literature says is required for a habit to form at all.

**The case against, not hidden.** Apple ships a Heart Rate complication for free, pre-installed. The
entire differentiated value here is the band and the age stamp. That is a real difference and a thin
one, and a user who does not care about the band will keep Apple's. This is the strongest argument
against the whole concept and it is restated in §15.

---

## 9. Smart Stack strategy

**One widget, `accessoryRectangular` only.** R3 permits `accessoryCircular` too, but the circular
form is already on the face and a second Smart Stack entry competes with itself for the same slot.

Designed to the 40 mm floor, **152 × 69.5 pt**, 6 pt padding → 140 × 57.5 pt content:

- **Title row** — `74` 19.5 pt tabular, `BPM` 11 pt baseline-aligned, right-aligned `6m`.
- **Band strip** — 140 × 8 pt, radius 4, with the identical encoding to Screen 1: track, grey usual
  zone, rest tick, marker in the band colour with a 1 pt black outline. **The widget teaches the
  app.**
- **Verdict line** — `Typical for 2pm`, 12 pt, single line, tail truncation.

One title plus two body lines, which is Apple's realistic ceiling for the family (R15). The prototype
also renders it at 46 mm, where the widget canvas is **interpolated, not published** — Apple's size
table has no row for 42 mm or 46 mm (`00-SYNTHESIS.md` §7).

**Background.** Black by default. On the **Well up** band only, the background becomes `poor`
#E05C64 at 22 % opacity, following the HIG's watchOS widget guidance about a colourful background
that conveys meaning (the Stocks red-for-falling example). The words `Well up for 2pm` are always
present, so the colour is never load-bearing alone (R18). Toggle the dev toolbar to `Well up` and
then open the Smart Stack in the prototype to see it.

**Tap target:** whole-widget deep link to `laso://watch/pulse/now`. No App Intent button — a widget
cannot sample live HR, so an in-widget action would have nothing true to do.

### Relevance (R12)

`TimelineEntry.relevance` **does nothing on watchOS** — anti-pattern 9, dead code
(https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks). This widget
uses the **`TimelineProvider.relevance()`** path, returning a `WidgetRelevance` built from
`WidgetRelevanceAttribute(configuration:context:)`, with two clues
(https://developer.apple.com/documentation/relevancekit/relevantcontext):

1. **`RelevantContext.fitness(_:)`** — surface after a workout ends. Heart-rate recovery is the
   single moment where "what is my body doing right now" is most worth asking, and it is fully native.
2. **`RelevantContext.date(range:kind:)` for 12:30–15:00** — the post-lunch window. Alex's stress has
   been rising since 11:00, and Bidargaddi et al.'s MRT independently found 12:30 pm the best
   engagement slot (8.8 % lift, 11.8 % at weekends)
   (https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/).

**Not `RelevantContext.sleep(_:)`.** Live heart rate at bedtime is concept 10's moment; claiming a
clue we do not act on wastes the permission.

**Not `RelevanceConfiguration` (watchOS 26+),** for two reasons. Apple states that with it *"people
can't configure widgets that use a `RelevanceConfiguration` to appear in the Smart Stack, add them to
the Smart Stack, or pin them to a fixed location"* — and a pulse widget is exactly the kind of thing
a user should be able to pin. Second, `project.yml:270` sets `WATCHOS_DEPLOYMENT_TARGET: "10.0"`, so
it is not available to this codebase without dropping four major versions of support.

**Permissions gate:** `RelevantContext.fitness(_:)` requires the matching HealthKit permission on
**both the app and the widget extension**, per Apple's explicit note. Ship both or the clue silently
no-ops.

---

## 10. Notification strategy

**Exactly one notification exists. It is delta-triggered, capped at 3 per rolling 7 days, and it
expects to fire about once a week.**

### The reasoning first

Notifications buy a **3.5× next-hour open** but only **1.04–1.3× over 24 hours** and **no measurable
long-term retention effect** — across two MRTs, time to disengagement was not significantly different
between notification policies
(https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf).
Only 9.4 % of notifications produce any session, and 82.3 % of watch sessions are self-initiated
(https://www.kostakos.org/papers/chi17.pdf).

Anti-pattern 3 is the one that specifically kills a live-HR concept. Athlytic's absolute-threshold
stress alerts drew an explicit user request for *"a big friendly toggle to hush stress for a while"*
because they increase anxiety rather than help
(https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/).
A "your heart rate is high!" push is the most obvious feature this concept could ship and it is the
worst one. **It is not shipped** — it is an absolute-threshold anxiety alert, and Apple already ships
high/low heart-rate notifications at OS level, so it would also be a duplicate.

### N1 — "Resting heart rate moved"

| Property | Spec |
|---|---|
| **Trigger** | Evaluated **once**, at wake time + 30 min, on the watch, inside a `WKApplicationRefreshBackgroundTask`. Fires when \|today's resting HR − 7-day average\| ≥ **4 bpm**. Delta, not absolute — Training Today's model. |
| **For Alex today** | 58 vs a 7-day average of ~55 → **+3 → does not fire.** The demonstration day is a silent day, on purpose. The prototype renders it anyway, with that fact printed under the actions. |
| **Cadence ceiling** | Hard maximum **3 per rolling 7 days**, and **never two days running**. A 4th qualifying day is silently skipped, no catch-up. |
| **Short look** | Title `Laso` (system-drawn). Body: `Your resting heart rate moved.` **No number** — R17: *"Avoid including potentially sensitive information in the notification's title"* and *"Avoid using a short look as the only way to communicate important information."* |
| **Long look, dynamic** | Sash `primary` with the Laso mark. `Rest 58` at 22 pt, `3 above your 7 day usual.` at 16 pt, then a 7-bar sparkline of the last 7 mornings' resting HR on a 40–80 sub-scale, today 4 pt wide and filled `fair`. |
| **Long look, static** | The required fallback, shipped as its own screen in the prototype. Same two text lines, chart omitted, resources bundled with the app in advance. HIG: *"At the minimum, provide a static interface."* |
| **Action 1** | `Steady 60s` — opens the pushed Steady screen and arms the recheck. Nondestructive and most-used, so it sits first and **Double Tap selects it** (HIG: *"the system selects the first nondestructive action"*). It is not "an action that merely opens your app" — it starts a measurement. |
| **Action 2** | `Mute 7 days` — silences this class for a week. This is the friendly hush toggle Athlytic's reviewer asked for, shipped from day one rather than after the complaint. |
| **Actions 3, 4** | None. Two custom actions against a cap of four. |
| **Dismiss** | System-supplied, always last, not customisable. |

**Total notification budget for the whole concept: ≤ 3 per week, expected ≈ 1.** Every other reason
to open the app is self-initiated, which is the 82.3 % slice worth competing for.

---

## 11. Haptic language

**The governing rule (R8):** *"When you engage the haptic engine, HealthKit stops gathering heart
rate data until after the haptic engine finishes"*
(https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)). Minimum spacing
100 ms. No background haptics outside a workout session.

**Consequence, stated plainly: no haptic ever fires while Screen 1 or Screen 2b is visible.** That is
this concept's tax for owning the live sensor. The prototype makes the tax visible — pressing
`Steady · 60s` on Screen 1 prints "no haptic" and the reason.

| Event | `WKHapticType` | Sampling state at fire time |
|---|---|---|
| Steady `Start` tapped, by touch or Double Tap | `.start` | Fires **first**; the `HKAnchoredObjectQuery` installs ≥ 100 ms **after** the haptic completes |
| 60 s elapsed, value stayed inside or entered the band | `.success` | HR query is **stopped first**, then the haptic. Never the reverse |
| 60 s elapsed, value crossed from above the band to inside it | `.directionDown` | Same ordering. Fires **instead of** `.success`, never in addition — Apple's documented meaning is "an important value decreased below a significant threshold" |
| 60 s elapsed, value still above the band | **none** | Deliberate. A haptic here would punish a body for doing something. The screen says `Still up` in words |
| Crown detent, Screens 3 and 4, and inside the Smart Stack | `.click` | No HR query is live on these surfaces |
| Crown detent, Screen 1 | **suppressed** | Screen 1 does not scroll; its only crown gesture is page navigation, by which point the query is torn down |
| Steady result rejected by the phone | `.failure` | Only reachable after the query stops |
| N1 arriving | `.notification` | System-fired. It **will** interrupt sampling if the app is frontmost. Unavoidable, and capped at ≤ 3/week — which is why the cap matters twice over |

**Never used, and why:** `.directionUp` — a rising heart rate never gets a haptic, by design
(anti-anxiety, anti-pattern 3). `.retry`, `.stop`, and the navigation and underwater patterns — no
documented meaning maps onto anything in this app, and the HIG forbids repurposing a pattern to mean
something else.

---

## 12. What was deliberately excluded, and why

1. **Background live heart rate.** R9 and R16 make it impossible. The three ways to fake it — a long
   background task, an extended runtime session, a permanently open `HKWorkoutSession` — are
   respectively unreliable, wrong-typed, and an API abuse that would pollute the user's workout
   history and drain the battery. All three declined; the age is labelled instead. *A concept named
   "Live Pulse" that is live on one surface is honest; one that pretends otherwise is a bug report
   waiting to be filed.*
2. **A recovery score as the hero.** Phone-only per the data split, and concepts 01 and 02's
   territory. Readiness appears once, on the deepest page, with an iPhone source stamp.
3. **Any haptic on the live screen.** R8. A real, felt loss of responsiveness, and the price of the
   concept.
4. **A high-heart-rate alert.** Anti-pattern 3, and Apple already ships one at OS level. Building it
   would be simultaneously anxiety-generating and redundant.
5. **All rings**, including the countdown ring on Steady, which was considered and cut — an animating
   60 s ring conflicts with Apple's own rule against indicators that make people keep watching.
6. **An imperative verdict** ("Time to slow down", "Let your body recover"). A deliberate departure
   from principle 4; justified in §6 and named as a weakness in §15.
7. **The morning check-in and the quick-log list.** Both cut. Neither is "now", and both would need
   haptics on a sampling screen. Real cost: the existing subjective check-in loses its wrist entry
   point, and that data genuinely improves a recovery model. A different concept should own it.
8. **`accessoryInline`.** No fourth destination worth its own deep link (R15).
9. **A second Smart Stack widget.** One widget, one job.
10. **Any extended runtime session.** Leaves the app's single session slot free for whatever ships
    later.
11. **Stress, strain, sleep debt, VO₂ max, vitality age.** All phone-only. Screen 4 is already at
    capacity and stuffing them in would be anti-pattern 1.

---

## 13. Expected opens per day, with the mechanism for each

**Complication glances are counted separately from app opens**, because they are different things and
conflating them is how watch apps get oversold.

### Glances, no app open

| Trigger | Time | Mechanism | Per day |
|---|---|---|---|
| Wrist raise with the circular or corner complication on the face | all day | passive; the value has visibly moved since the last look — the checking-habit reinforcer | **30 to 60** |
| Crown-down into the Smart Stack, post-lunch | 12:30–15:00 | `RelevantContext.date(range:kind:)` surfaces the widget | **~1** |
| Crown-down into the Smart Stack after a workout ends | variable | `RelevantContext.fitness(_:)` | **~0.4** (Alex trains 2–3×/week) |

### App opens

| Trigger | Time | Mechanism | Per day |
|---|---|---|---|
| *"Why does my heart feel fast?"* — the core trigger | any, skewed 11:00–16:00 | self-initiated; the user notices something (caffeine, a call, standing) and wants the band | **~0.8** |
| Complication tap because the marker was **outside** the grey zone | any | the only visual pull the complication has | **~0.3** (outside the band maybe 2 days in 7 for a healthy adult) |
| Post-workout tap-through to watch HR come down | after training | from the widget above | **~0.3** |
| Steady session | subset of the two above | — | **~0.3**, not an additional open |
| Morning check of Screen 4 | 07:00–09:00 | curiosity about readiness | **~0.2** — and honestly a *weak* trigger, because the phone is in hand at breakfast and shows it better |
| Notification-driven open | wake + 30 min | N1, ≤3/week, of which 9.4 % produce any session | **~0.04**, effectively zero, and correctly so |

### Total

**≈ 1.6 to 1.9 app opens per day, of which ~1.1 are the core "what is my body doing right now"
trigger. Plus ~1.4 widget views and 30 to 60 complication glances.**

**I am not going to claim 5 to 20 app opens per day.** No app in the competitive set has published
evidence of that, the median watch session is 5.0 s, and the CHI 2017 telemetry shows 142.1
sessions/day across *every app and the clock combined*, with roughly half of all smartwatch instances
being time checks (https://www.kostakos.org/papers/chi17.pdf). The defensible claim is different and
stronger: **this earns 30 to 60 glances a day on a face slot, and roughly two opens.** The glance is
the product; the app is where the glance gets explained. That is exactly what Apple says to expect
(R2), and it is the opposite of the shipping app, which earns one open a day and only after the
phone has been used.

---

## 14. Buildability against this codebase

Read against the shipping source at commit `cbb674f` (v3.26). `native` = watch HealthKit, no phone ·
`existing` = a `WatchPayload` field that ships today · `NEW-payload` = a new wire field ·
`phone-work` = new phone-side computation.

### The one structural cost, stated first because it dominates everything else

**The watch app and the widget extension must link HealthKit for the first time.** Today they link
none of it, by explicit design:

- `project.yml:249-252` lists `LasoWatch` sources file by file — `LasoWatch`, `WatchShared`,
  `Core/Extensions/Date+Extensions.swift`. Nothing else.
- `LasoWatch/LasoWatch.entitlements` contains exactly one key, an App Group. No
  `com.apple.developer.healthkit`.
- `LasoWatch/Info.plist` has no `NSHealthShareUsageDescription`.
- `WatchShared/WatchBridge.swift:5-8` states the intent outright: *"The phone is the only authority…
  This file must stay free of UIKit, WidgetKit, HealthKit and Firebase because the watch targets link
  none of them."*

This concept requires reversing that decision. Entitlement, usage description, and new source paths
on **both** `LasoWatch` and `LasoWatchWidgets` (the extension needs its own HealthKit entitlement to
read the newest sample inside the timeline provider, and again for
`RelevantContext.fitness(_:)`). `WatchBridge.swift` itself stays HealthKit-free — the new code is a
separate watch-side data layer, so the file's stated invariant survives.

**That is the concept's whole cost, and its whole point.** Everything below is small by comparison.

Also note `project.yml:270` — `WATCHOS_DEPLOYMENT_TARGET: "10.0"`. `digitalCrownAccessory` (watchOS
9+) and `handGestureShortcut` are available; `RelevanceConfiguration` (watchOS 26+) is not, which
independently forces the `TimelineProvider.relevance()` path chosen in §9.

### Per value

| Screen | Value | Source | Mechanism |
|---|---|---|---|
| 1 | `74` live bpm | **native** | `HKAnchoredObjectQuery` on `heartRate` with an `updateHandler`, installed on `.onAppear`, **torn down on `.onDisappear` and on `isLuminanceReduced`**. Frontmost only. |
| 1 | usual band `66 to 82` at 14:00 | **native, new watch-side computation** | `HKSampleQuery` over `heartRate` for the last 7 days, predicate-filtered to the 14:00–15:00 clock hour on each day, p25/p75 in Swift. Percentiles are **not** available from `HKStatisticsCollectionQuery`, so raw samples are required — roughly 80–120 samples at rest, cheap. Recomputed once per clock hour and written to the App Group so the widget extension never runs this scan. Sits inside the ~7-day watch store (R6). |
| 1 | rest `58` | **native** | Most recent `restingHeartRate` sample. |
| 1 | verdict word and colour | **derived on watch** | Pure function of the live value and the cached band. Zero phone dependency — this is why Screen 1 never degrades. |
| 2 | 60 s countdown | local | `Timer`, integer seconds. |
| 2 | `66` result | **native** | Mean of the last 15 s of samples from the same anchored query. Query stopped **before** any haptic. |
| 3 | 24 hourly bars | **native** | `HKStatisticsCollectionQuery` on `heartRate`, 1-hour interval, `.discreteAverage`. Average, not median — HealthKit offers min/max/average only and the label must not claim otherwise. |
| 3 | low `52` at `04:20`, high `141` at `08:12` | **native** | `.discreteMin` / `.discreteMax` for today, plus a 1-result `HKSampleQuery` sorted ascending/descending for the timestamp. |
| 3 | `You usually peak near 128` | **native, new watch-side computation** | `.discreteMax` per day over 7 days, median of those 7 in Swift. |
| 3 | `5,240 steps`, `12 exercise min` | **native** | `.cumulativeSum` on `stepCount` and `appleExerciseTime`. |
| 4 | resting HR today `58` | **native** | `restingHeartRate`. |
| 4 | usual `55`, the 60-day baseline | **NEW-payload** | `restingHrBaseline: Double?` — **the only new wire field this concept needs.** 60 days exceeds the ~7-day watch store, so it must come from the phone. Renders as `Learning` when nil. |
| 4 | HRV `48` ms last night | **native** | Most recent `heartRateVariabilitySDNN` inside last night's sleep window (`sleepAnalysis`). |
| 4 | usual `54`, the 7-day HRV average | **native** | 7 days is inside the watch window, so this is computed on the wrist deliberately. It survives a dead phone, and a payload field for it would be a needless dependency. |
| 4 | `Readiness 62` | **existing** | `WatchPayload.readinessScore` — `WatchShared/WatchBridge.swift:61`. |
| 4 | `Moderate` | **existing, currently dead** | `WatchPayload.readinessGrade` — `WatchShared/WatchBridge.swift:62`. Grepped across `LasoWatch/` and `LasoWatchWidgets/`: **no view reads it.** This concept revives it rather than adding anything, and satisfies principle 3 for free. |
| 4 | `iPhone 09:12` and stale rendering | **existing** | `WatchPayload.updatedAt`, `WatchPayload.isStale(now:)`, `WatchBridge.stalePayloadInterval` (60 min, `WatchBridge.swift:41`). |
| complications | last sample + age | **native, in the widget extension** | `HKSampleQuery` for the single newest `heartRate` sample, run inside the WidgetKit timeline provider. Requires the entitlement and usage description **on the extension itself**. |
| complications | band, rest, verdict word | **App Group cache** | Written by the app on each hourly recompute, read via `WatchBridge.watchAppGroup` — the same container the complication already uses (`WatchBridge.swift:23`). |
| notification | 7-day resting HR series and the trigger | **native, on the watch** | `HKStatisticsCollectionQuery` on `restingHeartRate`, daily, 7 days, evaluated in a `WKApplicationRefreshBackgroundTask` firing a local `UNNotificationRequest`. **Nothing routes through the phone**, which is why it still works with the phone off. |

### Build ledger

- **New `WatchPayload` fields: 1** (`restingHrBaseline`).
- **Revived dead fields: 1** (`readinessGrade`).
- **New phone-side computation: 1** — a 60-day resting HR baseline. The phone already runs ~40
  analysis engines including baseline machinery (`01-CURRENT-APP-CRITIQUE.md` §2), so this is very
  likely a read of state that already exists rather than new maths. **Unverified** — I did not open
  the phone-side baseline engines in this session.
- **New watch-side computations: 3** (hourly p25/p75 band, 7-day peak median, 7-day HRV average).
- **Everything else on every screen is native watch HealthKit.**
- **The `LasoWatch` target also gains its first notification code**, its first haptics, its first
  crown handling, its first `isLuminanceReduced` handling and its first Smart Stack widget. The
  critique lists all five as currently absent. None of them is hard; all of them are new surface area
  with no existing pattern in the repo to copy.

### What could break

- `WatchStore.pendingCommands` currently disables the only interactive control until the phone
  answers (`WatchRootView.swift:95`, and the `ponytail:` comment at `WatchStore.swift:27-29`). This
  concept's three buttons must not go through that path — Steady is entirely local and must never
  depend on a phone acknowledgement.
- Adding HealthKit to the watch app changes the App Store privacy declarations and the
  `PrivacyInfo.xcprivacy` files in both watch targets.
- A frontmost anchored heart-rate query raises the sampling rate. Battery cost is **unmeasured and
  there is no published figure**; it needs real hardware before ship.

---

## 15. Honest drawbacks, and who this design fails

### The strongest argument against the concept

**Apple already ships a Heart Rate complication and a Heart Rate app, both free and pre-installed,
and both show 74.** The entire differentiated value of Live Pulse is (a) the personal hourly band,
(b) the printed sample age, and (c) the 60-second Steady recheck. Those are real and they are thin.
A reviewer could fairly say: *this is Apple's Heart Rate complication with a grey rectangle behind
the number.* I do not have a rebuttal that makes that go away. The rebuttal I do have is that the
grey rectangle is the entire difference between a number and an answer, and no other app on the
wrist draws it — but that is an argument about design quality, not feature surface, and it will lose
to anyone who does not already care.

### The rest, in order of severity

1. **The hero is boring most of the time, by design.** For Alex right now the screen is a white
   marker in a grey box and the word `Typical`. A screen whose best outcome is *nothing is happening*
   struggles to earn a repeat open. The checking-habit mechanic is genuinely satisfied — the number
   moves — but the *interesting* movement only appears when something is off. **This concept's
   engagement is structurally back-loaded onto the user's worst days**, which is an uncomfortable
   place to build a business.
2. **"Live" is true on exactly one surface.** Live HR exists only while the app is frontmost. On the
   complication, the widget and the notification the number is a HealthKit sample 5 to 20 minutes
   old. Apple says most usage happens on those surfaces (R2). So the concept's name is accurate about
   its best surface and misleading about its most-used ones. Labelling the age is the only mitigation
   available and it does not fully solve it.
3. **Sampling costs battery.** A frontmost anchored heart-rate query raises the sampling rate, and a
   user who leaves the app open through the ~2-minute frontmost window several times a day will pay
   for it. There is **no published figure** and I am not going to invent one.
4. **The band has no clinical meaning and cannot explain itself.** `Up for 2pm` can be caffeine,
   posture, a warm room, a stressful email, or nothing. Ultrahuman's top user criticism is exactly
   this shape — *"it doesn't explain why it could happen or what it could mean"*
   (https://www.garagegymreviews.com/ultrahuman-ring-review). Never claiming a cause is honest, and
   it is also a way of saying the user is left holding the question.
5. **Zero haptics on the main screen.** R8's tax. `DESIGN-TOKENS.md` promises that every
   state-changing tap fires a haptic; on Screen 1 there are no state-changing taps at all, which is a
   legalistic way of satisfying the rule. The app will feel less alive than the token document
   implies.
6. **Screen 4 fails the 5-second test and Screen 3 fails it as a decision.** Two of thirteen
   surfaces, both at the bottom of the hierarchy. Detailed in §16 rather than hidden.
7. **The band degrades on imperfect wear.** It does not *break* — there is no accumulator to reset —
   but a user who charges the watch every afternoon has thin 14:00 data, so the p25–p75 band widens
   and every reading becomes `Typical`. **The verdict quietly becomes useless without ever becoming
   wrong.** There is no UI for this and there probably should be: a confidence indicator on the band
   width is the obvious next iteration.
8. **The concept gets no goal gradient at all** (§7). The strongest motivational mechanic in the
   research set does not apply to a measurement with no target.

### Who this design fails

- **The user who came for a verdict.** Live Pulse never says *train hard today* or *take it easy*. It
  says *your heart is 74 and that is normal for you*. Someone who installed a recovery app to be told
  what to do gets a measurement and a reference frame. That is a substantial fraction of the market,
  and concepts 01, 02, 07 and 09 all serve them better.
- **The anxious user, and this is the serious one.** This concept puts a heart rate in front of a
  person many times a day and occasionally colours it amber. For someone with health anxiety that is
  a nudge straight into the loop Athlytic's reviewer described. The mitigations are real — no
  absolute-threshold pushes, no `.directionUp` haptic, neutral wording, `Mute 7 days` in the box, red
  reserved for a single band and never on a notification — but the concept's centre of gravity is
  against this user and no amount of copy tuning changes that.
- **The user who takes the watch off at night.** Overnight HR is a large share of the day's samples.
  Night-off wear does not break the hourly band, which is per-clock-hour, but it empties the
  00:00–07:00 bars on Screen 3 and blanks Screen 4's HRV row most days.
- **The user with an arrhythmia.** A personal band computed across AFib episodes is statistically
  meaningless, and this design neither detects nor excludes them. Heart Analyzer at least integrates
  Apple Health AFib History (https://www.myhealthyapple.com/monitor-hrv-apple-watch-heartanalyzer/);
  this concept does not, and would need to before it could responsibly ship a band to that user.
- **The user whose phone rarely syncs** is the one group this serves completely. Screens 1, 2 and 3
  are entirely native and never degrade. Worth naming because it is the group the shipping app fails
  hardest.

---

## 16. The 5-second test, per surface

The median smartwatch session is exactly **5.0 seconds**
(https://www.kostakos.org/papers/chi17.pdf). The question is whether a user gets a *decision* in
under 5 seconds without reading a sentence. Failures are not hidden.

| Surface | Verdict | Honest reasoning |
|---|---|---|
| **1 · Now** | **PASS**, ~1 s | Number, word, marker in-or-out-of-zone. Three pre-attentive channels that agree. The fastest read in the concept. |
| **2a · Steady ready** | **PASS**, <1 s | One sentence, one button. |
| **2b · Steady running** | **PASS**, <1 s | One numeral. Nothing else on screen. |
| **2c · Steady result** | **PASS**, ~2 s | Number, word, and a marker that visibly moved left of the ghost tick. |
| **3 · Today** | **PARTIAL — passes as information, FAILS as a decision** | The day's shape and the rest line land in ~1 s. But the actual decision — *has today asked more of me than usual* — requires reading `You usually peak near 128`, holding it in memory, and comparing it to a `141` read off a different footnote. That is a ~3–4 s sentence read and the comparison is **not pre-attentive**. **Fail.** This page exists because the concept needs a second data point, not because it drives a decision. The fix would be to put 128 on the chart as a second reference line, and it was not done because two dashed reference lines on a 70 pt chart is unreadable at 28 cm. |
| **4 · Baseline** | **FAIL** | Two paired-bar comparisons, a phone verdict, a grade and a source stamp cannot be absorbed in 5 s. It is a reference screen read maybe once a week, and it is correctly the deepest page. I am not going to dress this up. |
| **`accessoryCircular`** | **PASS**, <1 s | Gauge needle position plus two or three digits. |
| **`accessoryRectangular`** | **PARTIAL** | `74 BPM · 6m` passes in <1 s. Understanding the 12-bar shape against the rest line takes ~2 s — still inside budget, but it is a second read, not the same read. |
| **`accessoryCorner`** | **PASS**, <1 s | `REST 58` plus a needle against a tick. |
| **Smart Stack widget** | **PASS**, ~1.5 s | The same three channels as Screen 1 in a third of the space. |
| **Notification long look** | **PASS**, ~3 s | Two short lines and a 7-bar chart. Reading the chart is optional; the two lines carry it. |
| **Always-On redacted** | **PASS as a deliberate non-answer** | It instantly communicates "nothing is legible here". That is the intended outcome, not a failure. |
| **Loading / snapshot** | **PASS**, ~1 s | A grey number and an outline marker read as "not live yet" before any word is read. |
| **Cold start** | **PASS**, ~2 s | A real number and an honest label about what is missing. |
| **Error / no contact** | **PASS**, ~2 s | Last sample, its age, and a disabled button that is still in place. |
| **Empty / permission denied** | **FAIL as a glance, correct as a screen** | `Heart rate is off` reads in <1 s, but the recovery instruction is a two-line sentence that must be read. There is no way around this: watchOS exposes no verified API to deep-link a third-party app into its own privacy settings, so the design cannot replace the sentence with a button. Naming it rather than pretending. |

**Three of sixteen surfaces fail or partially fail: Today as a decision, Baseline outright, and the
permission-denied screen as a glance. Two of the three are at the bottom of the hierarchy. The entry
screen and every off-app surface pass.**

---

## Implementation notes on the prototype

Things where the design specification could not be built exactly, with what was built instead:

1. **Screen 3, line 1 does not fit on one line.** `Low 52 at 04:20 · High 141 at 08:12` measures
   221 pt at 13 pt in a 188 pt content width — and roughly 205 pt even after allowing for SF Compact
   being narrower than the desktop substitute. The string was kept exactly and given a reserved
   two-line box, with lines 2 and 3 re-spaced beneath it. Screen 3 therefore renders 4 text rows for
   3 information lines.
2. **Screen 4's y-table does not survive real line heights.** The specified rows (54 / 96 / 152 / 198)
   overlap once labels, bars and trailing values are laid out with real metrics. Rows were re-spaced
   to 44 / 90 / 142 / 198 at 46 mm and 28 / 66 / 110 / 160 at 40 mm, trailing values were moved to a
   fixed x so they cannot drive the row height, and the footer wraps to 3 lines at both sizes rather
   than the specified 2 at 46 mm. The content is unchanged.
3. **The circular complication's gap is 90°, not 45°.** A 270° sweep leaves 90° of gap by arithmetic;
   both the design spec and `DESIGN-TOKENS.md` say "270° sweep, 45° gap". The gap is centred at the
   bottom, 45° either side, which is what both documents evidently mean.
4. **Complication gauge tracks use `borderLow` #2E2E36, not `surfaceSubtle` #17171C.** At a 2.5 pt
   stroke on a black face, `surfaceSubtle` is invisible, and an invisible track destroys the
   position-carries-meaning property that R18 depends on. The band on Screen 1, which is a filled
   shape rather than a hairline, keeps `surfaceSubtle` as specified.
5. **The Steady result verdict has a wrong-word edge case, inherited from the spec.** With the dev
   toolbar set to `Calm` (61 bpm), the result of 66 is a *rise*, so the specified rule
   (`value rose → Still up`) renders `Still up · 5 up from 61 · back inside your usual` for a value
   that is comfortably inside the usual band and rising *toward* it. The band fact in the caption is
   correct; the verdict word is not. The rule was implemented verbatim rather than quietly
   redesigned. The table needs a fourth row: *rose, and the new value is inside the band* → **Settled**.
6. **The prototype countdown runs at 6× speed** so a reviewer does not wait a real minute. Nothing
   else is time-compressed.
7. **The watch face is authored at 208 × 248 and scaled to fit the 40 mm canvas** rather than
   reflowed. Real watch faces reflow; the scaling preserves the composition for review.
8. **The Smart Stack widget at 46 mm is interpolated.** Apple publishes no widget size row for 42 mm
   or 46 mm (`00-SYNTHESIS.md` §7). The 40 mm rendering is the published 152 × 69.5 pt and is the one
   to judge.
9. **Small negative tracking (−0.1 px) is applied to the footnote and caption roles** to approximate
   SF Compact Rounded, which is not available to a desktop browser and is meaningfully narrower than
   the SF Pro substitute. Without it, line breaks in the prototype are pessimistic relative to the
   device.
10. **Dynamic Type is not implemented.** The spec's AX1+ reflow — verdict wraps to two lines, band
    moves below the action button, caption dropped — is described but not built. The prototype has no
    Dynamic Type control and adding one would not have been judged.
