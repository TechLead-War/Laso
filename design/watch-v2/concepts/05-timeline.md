# Concept 05 — Body Clock (`timeline`)

Prototype: [`05-timeline.html`](05-timeline.html) · shared user: **Alex, 34, Tuesday 14:32** · design target 46mm (208 × 248 pt), floor 40mm (162 × 197 pt).

Evidence strength is marked on every claim: **A** = peer-reviewed measurement or first-party platform documentation · **B** = vendor documentation or reproducible product behaviour · **C** = single reviewer, inference, or snippet-level. Every URL below appears in `research/`. Nothing is invented.

---

## 1. One-sentence philosophy

Health is a sequence of time windows, not a daily verdict — and a window is the only health value on a wrist that stays correct while the phone is unreachable, because time is the one thing the watch always knows.

---

## 2. The question it answers first

**"What should I do in the next few minutes?"**

Not "how am I today". That question belongs to concepts 01, 02 and 07, and this concept deletes the readiness score from every surface it owns.

The question was chosen because of an arithmetic problem the other concepts share. A readiness score is computed once and is identical from 07:00 to 23:00. Apple warns that "a static complication that doesn't display meaningful data may be less likely to remain in a prominent position on the watch face" ([Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets), **A**), and the checking-habit literature is blunter: a checking habit is "brief, repetitive inspection of dynamic content quickly accessible on the device", and adding real-time information to a previously static screen *caused* checking to emerge ([Springer](https://link.springer.com/article/10.1007/s00779-011-0412-2), **A / strong, peer-reviewed**). A static number therefore cannot form the habit that keeps the face slot.

A countdown is different on every single wrist raise, by construction, and it needs no reload budget to stay right.

**The ranking rule that picks the window is deterministic and runs entirely on the watch:**

```
1. Windows in progress (start ≤ now < end) and unsatisfied outrank all others.
2. Among the rest: smallest positive time-to-deadline.
3. Tie-break: earlier start, then fixed order [move, caffeineCutoff, training, windDown, bedtime].
4. A window whose deadline passed unsatisfied is marked missed and never becomes "next".
```

At 14:32 rule 1 selects **Move**. Zero phone input is involved.

**Alex's Tuesday, derived once and reused on every surface:**

| Window | Time | Type | State at 14:32 |
|---|---|---|---|
| Woke | 07:00 | anchor | done |
| Stand hours 07:00–12:00 | hourly | act | 6 credited |
| Stand hour 13:00 | 13:00–14:00 | act | **missed** (last stood 12:40) |
| **Move** | 14:00–15:00 | act | **NOW — 28 min left** |
| Last coffee | 15:20 | stop | upcoming, 48 min |
| Train | 16:00–19:00 | act | upcoming, 1:28 |
| Wind down | 22:20 | rest | upcoming, 7:48 |
| Bed | 23:20 | rest | upcoming, 8:48 |

Sleep need 7 h 40 m + wake 07:00 → bed 23:20. Wind down = bed − 60 min (`WindDownScheduler.leadMinutes = 60`, verified) → 22:20. Caffeine cutoff = bed − 8 h → 15:20. Training = activity acrophase 17.5 ± 1.5 h → 16:00–19:00. 28 min = 15:00 − 14:32.

---

## 3. Screen-by-screen reasoning

Three app screens, maximum depth 2. Off-app surfaces are §8–§10.

### S0 — Launch / wrist-raise return

There is no separate launch screen. On cold launch the system shows the last snapshot ([Preparing to take your watchOS app's snapshot](https://developer.apple.com/documentation/watchkit/preparing-to-take-your-watchos-app-s-snapshot), **A**), then S1 renders from three sources, none of which blocks:

1. **Device clock** → NOW position, the countdown, which window is next. Frame 1.
2. **App Group cache** (`WatchPayloadCache`) → the window times. Frame 1.
3. **Native HealthKit read** → stand-hour cells, wake time, last-stood. Arrives 200–800 ms later and crossfades in with opacity only — no layout shift, no count-up.

No spinner, because "an animated indicator can make people think they need to continue paying attention to the display" ([Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback), **A**). The `why` line reads `Reading your stand hours` until the query returns, which is a true sentence rather than a placeholder.

**Wrist-raise return to a frontmost app** is the identical frame: no animation replay, no count-up, only the countdown digit and the freshness chip differ. The prototype ships both as separate switcher entries so a reviewer can see that they are the same picture.

### S1 — NOW (page 1 of 2), the entry screen

One decision: *do I act on this window now, or has it not started yet?*

| Element | Why it is there |
|---|---|
| **Freshness chip** `● Plan 2 min ago` | The dot is filled when the plan is under 60 min old and hollow when it is older, so age is carried by shape and by the word, never by colour alone (R18). Athlytic documents its refresh cap in-product and pre-empts the ticket; Bevel does not and carries a public bug thread about watch values being 1–5 points off ([Athlytic](https://athlytic.github.io/athlyticapp/troubleshooting/) · [Bevel](https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match), **B**). |
| **Verb** `Move now` (22 pt/600) | Garmin ships a number *plus* a 2–4 word imperative; Fitbit ships a recommendation sentence; nobody ships a bare integer ([Garmin Body Battery](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html) · [Fitbit](https://support.google.com/fitbit/answer/14236710?hl=en), **B**). Here the imperative *is* the headline. |
| **Countdown** `28` (52 pt) + `min left` | Rendered as `Text(timerInterval:countsDown:)` so it self-updates with no widget reload. This is the goal gradient made visible: effort scales with the proportion of remaining distance ([Kivetz et al.](https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf), **A / strong**). |
| **Why line** `Last stood 12:40` | The named failure of this category is opacity — "the scores are a black box" ([Bevel review](https://www.autonomous.ai/ourblog/bevel-app-review), **C**). Every window carries its own reason, on the glance, not one level down. |
| **Day rail** (188 × 22 pt) | Shows the slope of the day, not a level: Body Battery's glance is a value *plus* a multi-hour graph, because the slope answers "which way am I going" ([Garmin](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html), **B**). The current block is 12 pt, upcoming ticks are 8 pt, the missed 13:00 stand hour is a 4 pt hollow stroke — height, not colour, says "this is the one on the card". |
| **Primary button** (188 × 44) | Exactly one action, and it is the obvious next step — the Gentler Streak shape: verdict at 0 taps, prescription at 1 ([Gentler Streak docs](https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface), **B**). |

Four lines of text (chip, verb, countdown-with-unit, why). The rail labels are chart axis ticks and the button label is a control, so the 4-line budget holds. The screen never scrolls at either size, which is what keeps vertical page navigation working (see §5).

### S2 — DAY (page 2 of 2)

One decision: *am I behind on movement, and is my evening still reachable?*

Title row (`Today` / `6/12 stood`), a 3 pt window band, the 17-cell hour strip (07:00–23:00), axis labels, then a 5-row window list. Cell state is carried by height and fill first: future 3 pt flat, past-credited 6 pt solid, past-missed 6 pt **hollow**, current 14 pt with the NOW bar at 53 % across. Bars, not a radial — comparing two values costs 159–285 ms with bars against 1548–1772 ms with a radial bar ([Microsoft Research, InfoVis 2018](https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf), **A**), and Apple's own exemplar for the rectangular family is a 24-hour graph ([Complications](https://developer.apple.com/design/human-interface-guidelines/complications), **A**).

Rows are non-interactive by design, which is what allows them to be 28 pt instead of 44 pt. Scrolling up reveals `07:00 Woke` and `13:00 Missed`.

**This screen exceeds the 4-line budget and that is a declared violation, not an oversight.** A day timeline is a list of windows; there is no version of this concept that fits four lines. The mitigation is structural: S2 is never the entry screen, never a notification destination, and never where the countdown complication lands.

### S3 — Why this window

One decision: *act, or move it.* A stripe in the window colour, the window name, three label/value facts, a 44 pt primary button and a 44 pt secondary. Reached by tapping the S1 card, and it is the `accessoryCircular` deep-link destination.

Crown-editable facts (the caffeine cutoff, the training start, the wind-down time) are drawn with a 1 pt underline in the window colour and a trailing `arrow.up.and.down` glyph, so the affordance is visible before the crown is touched. Move's third fact reads `Hour ends 15:00 — Fixed by the clock` and the crown does nothing there: an hour boundary is not ours to move, and pretending otherwise would be a lie.

Only the *current* window is challengeable. Future windows' reasoning is a planning question and planning is a phone job.

---

## 4. Why this works on a watch specifically

1. **The wrist is the only device that is on you when the window opens.** A 15:20 caffeine cutoff and a 14:00 stand hour are events that happen while your phone is on a desk in another room. A phone version of this screen would be a calendar, and calendars already exist.
2. **The countdown is worthless on a phone and load-bearing on a wrist.** On a phone you unlock, find the app, and read a number that a lock-screen clock already implies. On a wrist the number is on the face, at zero taps, and it is different every time you look — which is exactly the condition the checking-habit literature identifies ([Springer](https://link.springer.com/article/10.1007/s00779-011-0412-2), **A**).
3. **This is the only concept in the set whose face surface is exact rather than approximately fresh.** Every other concept's complication decays between reloads under the 40–70 reloads/day and ~4 background tasks/hour budgets ([Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) · [WKApplicationRefreshBackgroundTask](https://developer.apple.com/documentation/watchkit/wkapplicationrefreshbackgroundtask), **A**). A `Text` with `.timer` / `.relative` / `.offset` "updates automatically" without a reload ([Always On](https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state), **A**), so the only thing needing a timeline entry is a window boundary change — 8 entries across Alex's whole day against a budget of 40–70.
4. **It survives the phone being off.** Times are times, not measurements. The plan, the countdown, the NOW marker, the stand strip and the missed hour are all either device clock or native watch HealthKit. Only *measurements* (strain, sleep debt) are withdrawn when the plan is old — dropped, never stale-rendered.

---

## 5. watchOS HIG guidance applied

| Rule | How this concept obeys it | Source |
|---|---|---|
| R1 — sessions are seconds | 4 lines on S1, 2 pages, one push, one action per screen. Median smartwatch session is exactly 5.0 s, 142.1 sessions/day | [designing-for-watchos](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos) · [CHI 2017](https://www.kostakos.org/papers/chi17.pdf) |
| R2 — the app is not the product | The complication and the Smart Stack widget carry the answer; the app is the detail view. Users "may never explicitly launch your app" | [watchos-apps](https://developer.apple.com/documentation/watchos-apps) |
| R3 — only 2 families reach the Smart Stack | Ships `accessoryRectangular` there only | [Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) |
| R4/R5 — reload budgets, never real-time | The countdown is a self-updating `Text`; timeline entries only at window boundaries (8/day) | [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) |
| R6 — watch HealthKit reaches back ~7 days | Only same-day stand hours and last night's sleep are read on-wrist; nothing needing 60 days | [Athlytic](https://athlyticapp.helpscoutdocs.com/article/12-widget-or-complication-out-of-sync) |
| R7 — redact health data in Always On | Every word and number describing the body is replaced; only time-domain information survives; the hour strip becomes identical-height hollow outlines | [Always On](https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state) · [isLuminanceReduced](https://developer.apple.com/documentation/swiftui/environmentvalues/isluminancereduced) |
| R8 — no haptics while sampling HR | This concept never samples heart rate, so the conflict cannot occur | [WKInterfaceDevice.play](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)) |
| R10 — anchor navigation to the crown | Crown pages S1 ↔ S2; on S3 it inspects data, the World Clock pattern | [Digital Crown](https://developer.apple.com/design/human-interface-guidelines/digital-crown) · [Page controls](https://developer.apple.com/design/human-interface-guidelines/page-controls) |
| R11 — no primary action on a vertical tab | S1 and S2 set **no** `handGestureShortcut(.primaryAction)`. Double Tap lives on S3, the widget and the notification | [Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures) · [handGestureShortcut](https://developer.apple.com/documentation/swiftui/view/handgestureshortcut(_:isenabled:)) |
| R12 — relevance is a different API on watchOS | `TimelineEntry.relevance` is never written; `TimelineProvider.relevance()` + a `RelevanceConfiguration` twin linked by `.associatedKind` | [Widget suggestions](https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks) · [RelevantContext](https://developer.apple.com/documentation/relevancekit/relevantcontext) |
| R13 — no spinners | Skeleton at 3 pt, then a 200 ms opacity crossfade | [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback) |
| R14 — static surfaces get deleted, minimise depth | The complication changes on every raise and is never `--`; maximum depth 2 | [Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) |
| R15 — one deep link per complication | Three families, three destinations: `/now` → S1, `/window` → S3, `/day` → S2 | [Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) |
| R16 — extended runtime is single-type | No extended runtime session is claimed; the 2-minute move timer is named as an upgrade path, not built | [Extended runtime](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions) |
| R17 — notification rules | No health value in any title; ≤ 4 actions; first non-destructive action is the Double Tap target; static long look required | [Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications) |
| R18 — colour is never the only channel | Four channels per state (height, fill, glyph, word), colour is always fourth; three hues total, no red | [Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) · [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) |

Sizes and floors from [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) and [Complications](https://developer.apple.com/design/human-interface-guidelines/complications): complication text 10.5–19.5 pt, controls 44 × 44 pt default and 28 × 28 pt minimum, line widths ≥ 2 pt.

---

## 6. UX principles used, and the mechanism

1. **Verdict at zero taps** — the complication carries `Move now · 28m`; the app is optional. Mechanism: removes the fetch step from the decision. (**A**, [watchos-apps](https://developer.apple.com/documentation/watchos-apps))
2. **Imperative, not description** — `Move now`, not "Stand hour 53 % elapsed". Mechanism: the user does not have to convert a state into an action. (**B**, Garmin's number + label + imperative)
3. **Bars for anything compared** — the hour strip and the rail are bar encodings; the only radial in the whole concept is the single-value `accessoryCircular` gauge, which is a level, not a comparison. Mechanism: 6–10× read-time difference inside a 5 s budget. (**A**, [InfoVis 2018](https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf))
4. **Slope, not just level** — the rail shows what is behind and what is ahead. (**B**, Garmin Body Battery)
5. **Progressive disclosure of "why"** — glance (verb + countdown) → why line → S3's three facts. (**B**, Garmin 0 presses → factor list at 3; Fitbit 2 taps to per-pillar reasoning)
6. **Small, reused colour language** — three hues only: act `optimal` #33C48D, stop `fair` #E3B45A, rest `primary` #4DA3FF, identical on every surface. Garmin reuses blue/orange/green/gray across two features for the same reason. No red anywhere: nothing in this concept is a failure state. (**B**, Garmin)
7. **Name the cold start, never fabricate** — `Day 2 of 7`, where 7 is the real `CircadianAnalyzer.minimumDays`. Garmin ships "No Status", Fitbit states 7 nights. (**B**, [Garmin HRV status](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-6F81BF5B-B49A-4506-95E2-0F4A04D8B319.html) · [Fitbit](https://support.google.com/fitbit/answer/14236710?hl=en))
8. **Publish your own staleness** — the chip carries the plan's age; the countdown, NOW marker and hour strip carry no age marker because they are live. Two clocks, and the UI says which is which. (**B**, Athlytic vs Bevel)
9. **The wrist owns today** — no weekly view. Oura demotes Resilience, VO₂ Max and Cardiovascular Age off the daily surface as "not designed to be used every day". (**B**, [Oura](https://ouraring.com/blog/symptom-radar/))
10. **A value that contradicts felt state is worse than no value** — this is why window times are never given false precision, and why the caffeine cutoff is flagged in §15 as the concept's weakest claim. (**B/C**, [DC Rainmaker on WHOOP](https://www.dcrainmaker.com/2021/11/whoop-platform-review.html))

---

## 7. Psychological principles that drive repeat opens

| # | Mechanic | Evidence | How it is used here |
|---|---|---|---|
| 1 | **Dynamic content at near-zero access cost** | **Strong: peer-reviewed.** Checking habits require dynamic content quickly accessible; 82.3 % of watch sessions are self-initiated, 142.1/day ([Springer](https://link.springer.com/article/10.1007/s00779-011-0412-2) · [CHI 2017](https://www.kostakos.org/papers/chi17.pdf)) | The complication's countdown is different on every raise and needs no reload to be exact |
| 2 | **Goal gradient** | **Strong: peer-reviewed.** 20 % interpurchase acceleration near the goal, 16 % faster completion; motivation collapses once the goal is met ([Kivetz et al.](https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf)) | The countdown is a shrinking distance to a deadline. Because motivation collapses at "done", the next window is always shown — the widget and the rectangular complication both name what comes after |
| 3 | **Surviving the first 8 days** | **Strong: peer-reviewed.** >50 % of health-app users quit in week 1; the cohort still engaged at day 8 gains **+25 days** median retention ([arXiv](https://arxiv.org/pdf/1910.01165)) | One of the six windows (the stand hour) needs zero history, so the wrist is genuinely useful on day 1 while `Day 2 of 7` counts down honestly |
| 4 | **Bar encodings inside a 5 s budget** | **Strong: peer-reviewed.** 159–285 ms vs 1548–1772 ms ([InfoVis 2018](https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf)) | Hour strip and rail are bars |
| 5 | **Uncertainty about the outcome** | **Strong mechanism, inferred application.** Anticipatory dopamine ramp scales with uncertainty ([PubMed](https://pubmed.ncbi.nlm.nih.gov/12649484/)) | The countdown is unpredictable since the last glance without any fabricated variance — it is literally a clock |
| 6 | **Push the verdict at wake time** | **Medium: vendor documentation, no published effect size.** Garmin's Morning Report arrives unprompted "based on your normal wake time" and costs one press ([Garmin](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-4D26FDDC-63BD-4910-95B8-98937FEC2545.html)) | N1 at wake + 10 min |
| 7 | **Delta-triggered notifications** | **Strong on the near-term effect, strong that it is not retention.** 3.5× next-hour lift, 1.04–1.3× over 24 h, no measurable long-term retention effect, 9.4 % of notifications produce any session ([LSHTM MRT](https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf)) | N1 fires only if a window moved ≥ 20 min versus the user's own 4-day average, and the whole app is capped at 2 proactive pushes/day |

**Deliberately not used:** streaks (**Medium**; [Duolingo](https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/) — a streak on "hit your wind-down" punishes a night out), peer comparison (**Weak**, no verified watch implementation anywhere in the research set), and the Zeigarnik effect (the 2025 meta-analysis finds **no** memory advantage; only the Ovsiankina resumption half survives — [Nature](https://www.nature.com/articles/s41599-025-05000-w)).

---

## 8. Complication strategy

Three families, three distinct deep links. `accessoryInline` is not shipped: R15 forbids sharing a deep link and this concept has exactly three destinations; a fourth family would need a fourth screen, which R14 forbids.

| Family | Content | Deep link |
|---|---|---|
| **accessoryCorner** | Open gauge along the corner arc = minutes elapsed in the current window (0–60). Text `28m`, self-updating. Glyph `figure.walk` = window type | `laso://watch/now` → S1 |
| **accessoryCircular** | Closed gauge = fraction of the window elapsed (53 % at 14:32). Centre glyph = window type. `widgetLabel: 28m` | `laso://watch/window` → S3 |
| **accessoryRectangular** | Row 1 `Move now` + `28m`. Row 2 the 17-cell hour strip. Row 3 `then 15:20 last coffee` | `laso://watch/day` → S2 |

**Why a user gives up a face slot:** because the slot pays back on every wrist raise, not once a morning. A readiness score is identical all day; Apple warns that static complications get removed and a static value cannot form a checking habit at all. **This complication is never `--`.** The fallback chain is: current window → next window from cached times → the current hour's stand progress, which is native and needs no phone. There is no state in which it shows nothing. That is the direct answer to the shipping app's failure, where a 60-minute-old payload renders `--` on the face all day.

**Rendering-mode safety:** in accented mode the system tints content to the face colour and "may invert colors depending on the watch face". Every complication above survives total colour removal — the corner is an arc *length*, the circular is a fill *fraction*, the rectangular is a height histogram, and all three carry a name or a glyph.

---

## 9. Smart Stack strategy

**This is the concept's primary surface.** One family: `accessoryRectangular`. `accessoryCircular` is legal in the Smart Stack but is not shipped there — it is the rectangular's content at a quarter of the density, and a stack entry that adds a surface without adding an answer is clutter.

Designed to the **40mm floor, 152 × 69.5 pt**, not the ceiling: title row (`Move now` + `28m` as a `Text(timerInterval:)`) 19 pt, hour strip 16 pt (17 cells × 8 pt + 16 × 1 pt gap = 152 exactly), button 29.5 pt. Two lines of text, one chart, one button — the shape of Apple's own widgets. At 49mm (191 × 81.5) the extra 12 pt goes to the strip and the button. **46mm and 42mm do not exist in Apple's table** (it has no rows for Series 10/11), so 46mm is treated as ≈ 45mm (184 × 80.5) and must be verified on device.

The button runs an `AppIntent` and is the Double Tap target — the Waterllama pattern, whose entire primary action is a Double Tap from the Smart Stack ([App Store listing](https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585), **Weak: single store listing**).

**Relevance — the honest version.** `TimelineEntry.relevance` does nothing on watchOS; Apple's own platform matrix marks it "No". Ship both legal paths, linked with `.associatedKind(_:)`:

1. A **timeline-based widget** whose `relevance()` returns a `WidgetRelevance`. It appears once and the user can add and pin it.
2. A **`RelevanceConfiguration` twin** (watchOS 26+), one instance per clue, so the right *window* surfaces at the right moment. Apple states the trade-off explicitly: "people can't configure widgets that use a `RelevanceConfiguration` to appear in the Smart Stack, add them to the Smart Stack, or pin them to a fixed location." `.associatedKind` lets the twin replace the pinned one instead of duplicating it.

| Window | Clue (`RelevantContext` cases that actually exist) | Permission needed on **both** targets |
|---|---|---|
| Morning plan | `.sleep(.wakeup)` | `sleepAnalysis` |
| Caffeine cutoff 15:20 | `.date(_:)` | none |
| Training 16:00 | `.date(interval:kind:)` + `.fitness(_:)` | workout |
| Wind down 22:20 | `.sleep(.bedtime)` | `sleepAnalysis` |

**Hard cap of 4 clues/day.** The stand hour would justify a clue at :40 of every waking hour — 16 a day — which is the hint spam users mute with a swipe-down for 24 hours ([Apple Support](https://support.apple.com/guide/watch/see-widgets-in-the-smart-stack-apdecf142fb9/watchos), **B**). The stand hour is served by the complication, which is already on the face. Location clues are excluded: a second permission on two targets for a marginal gain.

Background colour conveys meaning only in support of a shape change — the widget background shifts to a 12 %-opacity wash of the window colour when under 10 minutes remain, paired with the strip's height change.

---

## 10. Notification strategy

**Cadence ceiling: 2 proactive notifications per 24 hours, hard.** User-requested reminders (`Remind me at 16:00`) are exempt because the user asked for them in that session.

Why so low: notifications give a 3.5× next-hour lift but only 1.04–1.3× over 24 h and **no measurable long-term retention effect**; only 9.4 % produce any session ([LSHTM MRT](https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf), **A / strong: MRT**). And 82.3 % of watch sessions are self-initiated ([CHI 2017](https://www.kostakos.org/papers/chi17.pdf), **A**), so an app living behind pushes is fighting for the 17.7 % slice. The weight goes on the face and the Smart Stack.

| # | When | Title (no health value, R17) | Body | Actions (first = Double Tap target) |
|---|---|---|---|---|
| **N1** | wake + 10 min (~07:10), delta-gated: fires only if a window moved ≥ 20 min vs the user's own 4-day average | `Today's windows` | `Train 16:00 to 19:00. Last coffee by 15:20. Wind down 22:20.` | `Remind at 15:50` · `Skip training today` · `Mute plan for a week` |
| **N2** | 16:00, **opt-in only, off by default** | `Training window` | `16:00 to 19:00. Strain 6.2 of an 8 to 12 target.` — if the phone has not synced the strain sentence is **dropped**, not stale-rendered | `Snooze 30 min` · `Skip today` |
| **N3** | 22:20 (bed − 60 min), via the existing `WindDownScheduler` | `Wind down` | `Bed by 23:20 for 7h 40m. Last night you went to bed 00:48.` | `Start wind down` · `Bed 30 min later` · `Skip tonight` |

No action merely opens the app — Apple: "Avoid providing an action that merely opens your app." A **static long-look interface is required for all three**, because the system falls back to it "when there is no network or the iPhone companion app is unreachable", which for this app is a normal Tuesday.

**Deliberately not shipped: a stand-hour notification.** watchOS already fires one at :50, and Apple says "avoid sending multiple notifications for the same thing". It would also blow the ceiling six times over and would be an absolute-threshold nag — the exact shape that drew an explicit request for "a big friendly toggle to hush stress for a while" at Athlytic ([crafting worlds](https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/), **C**).

---

## 11. Haptic language

| Event | `WKHapticType` | Note |
|---|---|---|
| Crown detent while nudging a window time on S3 | `.click` | "the sensation of a dial clicking… communicate progress at predefined increments" |
| `Log a cup` / `Remind me at 16:00` / `Snooze` / `Skip` accepted | `.success` | Fires on local commit; for `WatchCommand.journalTag` it fires immediately and is **not** re-fired on phone ack |
| Phone returns a `WatchCommandRejection` | `.failure` | Paired with an inline `Not saved` label — never a silent revert |
| `Start wind down` | `.start` | Apple's stated meaning: "an activity started" |
| A window closes unsatisfied while the app is frontmost | `.stop` | Frontmost only. There are no background haptics outside a workout session |
| Notification arrival | `.notification` | Played by the system |
| The ranked next window changes | **none** | "Overusing the click haptic tends to diminish its utility" |

**R8 compliance is structural.** This concept never samples heart rate, so "when you engage the haptic engine, HealthKit stops gathering heart rate data until after the haptic engine finishes" ([WKInterfaceDevice.play](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)), **A**) can never bite. That is a real advantage over the live-HR concepts and it costs nothing. The only 100 ms-spacing risk is a rapid double-press, so every state-changing button debounces for 300 ms.

---

## 12. What was deliberately excluded, and why

| Excluded | Why |
|---|---|
| **Readiness 62, grade, `dayType`** | In the payload today and rendered nowhere. A score answers "how am I", a different product. `dayType` ("Progressive Overload") is training-theory jargon rendered as status — critique failure #3 |
| **Live heart rate** | Never sampled. Consequence: the R8 haptic/HR conflict cannot occur and the wrist can never disagree with the phone about a live number. Free correctness |
| **A stand notification** | watchOS already fires one at :50 |
| **Chronotype words ("Night Owl")** | Same jargon failure as `dayType`. The chronotype is *used* (it produces the training window) and never *shown* |
| **`accessoryInline`** | Would need a fourth distinct destination; R14 forbids the fourth screen |
| **`accessoryCircular` in the Smart Stack** | Legal, but it adds a surface without adding an answer |
| **Per-window drill-in from S2** | Only the current window gets challenged in the moment. This is also what keeps S2 rows non-interactive and therefore 28 pt |
| **A weekly / 7-day view** | The wrist owns today |
| **Streaks on windows hit** | Medium evidence, and a streak on "hit your wind-down" punishes a night out. Gentler Streak ships On a Break / Sick / Injured states precisely so users can stop without penalty |
| **Location relevance clues** | A location permission on two targets for a marginal gain |
| **A 2-minute move timer** | Needs a `WKExtendedRuntimeSession` of type Self care, and each app supports a single session type — committing Laso's one type to a stand timer forecloses a future Smart Alarm |
| **Plan editing beyond ±3 h on the current window** | Restructuring a day is a phone task. The wrist nudges; it does not plan |
| **Calendar integration** | Would make the training window enormously better and is the single biggest gap (§15.6). Needs EventKit on the watch, a new permission and phone-side conflict resolution — a separate project |

---

## 13. Expected opens per day

"Open" = the app is launched or a widget/notification is interacted with. Glancing at a complication is **not** an open and is counted at zero.

| # | Trigger | Time | Mechanism | Est. opens |
|---|---|---|---|---|
| 1 | Morning plan (N1) | ~07:10 | Delta-gated push; only ~9.4 % of notifications produce any session | **0.3** |
| 2 | Wrist raise, complication read | 6–10× | Self-initiated; the countdown differs every time. **Delivers value, produces no session** | **0.0** |
| 3 | Stand hour closing | ~7× 08:00–20:00 | Complication reads `12m`; most people stand and never tap | **0.5** |
| 4 | Caffeine cutoff | 15:20 | Smart Stack `.date(_:)` clue surfaces the widget; tap `Log a cup` or scroll past | **0.4** |
| 5 | Training window opens | 16:00 | `.date(interval:)` + `.fitness(_:)` clue, plus opt-in N2 | **0.4** |
| 6 | Wind down (N3) | 22:20 | Existing scheduler, highest-intent evening moment, one-tap `Start wind down` | **0.5** |
| 7 | Self-initiated "what's next" | ~11:00, ~17:30 | Curiosity — the countdown is unpredictable since the last glance | **0.8** |

**Honest total: ≈ 2.9 app-or-widget interactions/day, plus 6–10 zero-cost complication glances.**

Two caveats, stated rather than buried. First, the shipping app manages "once a day at best, and only in the morning after opening the phone" — so this is a real improvement, but it is ~3, not the 5–20 the brief hopes for. Second, **this concept's design goal is to reduce opens.** Its win condition is that the user never launches anything because the face already said `28m`. Any metric that counts sessions will read a successful Body Clock as a failing product. That is a strategic risk, not a rhetorical flourish — see §15.10.

*These estimates are mine, built from the 9.4 % notification-yield figure and nothing else. The research set states plainly that no watchOS-specific engagement benchmark exists.*

---

## 14. Buildability against this codebase

Every code claim below was verified by opening the file or grepping the repo in this session, at commit `cbb674f` (v3.26).

Legend: **W** = native watch HealthKit · **E** = exists in `WatchPayload` today · **N** = new `WatchPayload` field · **P** = new phone-side computation · **C** = device-clock arithmetic.

| Value | Source | Verified detail |
|---|---|---|
| Current time, NOW marker, all countdowns | **C** | Device clock. Zero dependencies |
| Which window is next (the ranking rule) | **C** | Runs on the watch over cached window times |
| Wake 07:00 | **W** primary / **N** fallback | `sleepAnalysis`, last night's session end, inside the ~7-day local store. Fallback `wakeMinutes` from `WakeUpTimeDetector.persistedWakeTime` (`Core/Notifications/WakeUpTimeDetector.swift:231` — confirmed present) |
| Stand 6 of 12, which hours, hollow 13:00, last stood 12:40 | **W** | `appleStandHour`, today. The entire hour strip |
| Hour ends 15:00, `28 min left` | **C** | Hour-boundary arithmetic |
| Last night 6h 12m | **W** | Sleep stages, last night |
| Training 16:00–19:00 | **N** | `trainingStartMinutes` / `trainingEndMinutes`. Phone-side from `CircadianAnalyzer.generateRecommendations` where `activity == .workout`; **confirmed at `Core/Analysis/ML/CircadianAnalyzer.swift:314-317`** — `Int(normalizeHour(activityAcrophase ± 1.5))`, i.e. integer hours, ±1.5 h. Needs ≥ 7 days: `static let minimumDays = 7` at **line 54** |
| Bedtime 23:20 | **N** | `bedtimeMinutes` from `SleepNeedCalculator` — `let recommendedBedtime: Date?` at **line 24**, computed at line 112 as `wake − totalHoursNeeded`, and **nil when there is no wake time** (line 114). The window then does not render |
| Wind down 22:20 | **N** | `windDownMinutes` = bedtime − 60, matching `WindDownScheduler`'s `private static let leadMinutes = 60` (**line 13**, used at line 51) so the wrist and the push cannot disagree |
| Caffeine cutoff 15:20 | **P** + **N** | **Nothing computes this today** — grep for `caffeineCutoff`, `halfLife`, `caffeineClearance` across the repo returns **zero hits**. `JournalStore` has a `.caffeine` category and stores counts only. New: `caffeineCutoffMinutes = bedtimeMinutes − caffeineClearanceHours`, with `caffeineClearanceHours = 8` in a named config constant. The research set records that no competitor publishes half-life constants or cut-offs, so this ships documented as a **product choice, not a clinical fact** |
| Cups today 2, last cup 11:15 | **N** | `caffeineCupsToday`, `caffeineLastMinutes` from `JournalStore` category `.caffeine`. Dies the day the app writes `HKQuantityTypeIdentifier.dietaryCaffeine`, which the watch could then read natively |
| Strain 6.2, target 8–12 | **N** | `strainToday`, `strainTargetLow/High`. Phone-only (60-day baselines). **Dropped, not stale-rendered**, when the plan is old |
| Sleep debt 4h 20m | **N** | `sleepDebtMinutes`. Phone-only, needs 5 nights. Not rendered in this concept but carried for the Wind-down card's future |
| `Day 2 of 7` | **N** | `daysUntilWindowsReady`, from the phone's count of days with hourly data — makes "7" honest instead of a guess |
| Plan age | **E** | Existing `updatedAt`; `WatchBridge.stalePayloadInterval` is `60 * 60` (**verified, WatchBridge.swift:41**) |
| Readiness 62 / grade / `dayType` / `actionHeadline` / `actionDetail` / `actionIcon` | **E — rendered nowhere** | Deliberate |
| `Log a cup` write | **E — ships today** | `WatchQuickTag(rawValue: "caffeine", … value: 1)` at `WatchShared/WatchStrings.swift:87` |
| `Start wind down` write | **P** | New `WatchCommand` case handing to the existing `App/WindDownLiveActivityManager.swift` (**file confirmed to exist**) |

### The smallest correct payload change

`WatchPayload` today has exactly **10 fields** (`dayKey, readinessScore, readinessGrade, dayType, actionHeadline, actionDetail, actionIcon, actionDone, checkInAvailable, updatedAt` — confirmed at `WatchShared/WatchBridge.swift:55-75`). It gains **one**:

```swift
struct WatchDayPlan: Codable, Equatable {
    let wakeMinutes: Int
    let trainingStartMinutes: Int?
    let trainingEndMinutes: Int?
    let caffeineCutoffMinutes: Int?
    let windDownMinutes: Int?
    let bedtimeMinutes: Int?
    let caffeineCupsToday: Int
    let caffeineLastMinutes: Int?
    let strainToday: Double?
    let strainTargetLow: Double?
    let strainTargetHigh: Double?
    let sleepDebtMinutes: Int?
    let planComputedAt: Date
    let daysUntilWindowsReady: Int   // 0 when ready
}

let dayPlan: WatchDayPlan?   // the only new field on WatchPayload
```

Times are **minutes from local midnight**, not `Date`, for the same reason `dayKey` already exists: the wire must not carry a timezone opinion.

### Two prerequisites that are not optional, and are not small

1. **The Watch target does not link HealthKit and must.** Verified: `LasoWatch/LasoWatch.entitlements` contains exactly one key, `com.apple.security.application-groups` — no `com.apple.developer.healthkit`. `project.yml:249-252` lists the `LasoWatch` sources as `LasoWatch`, `WatchShared`, `Core/Extensions/Date+Extensions.swift` and nothing else; the widget extension at `project.yml:285-288` is the same three. HealthKit is required on **both**, because `RelevantContext.sleep(_:)` and `.fitness(_:)` need the matching permission on the app *and* the widget extension. This also means adding `NSHealthShareUsageDescription` to `LasoWatch/Info.plist`, which today has none.
2. **`PhoneWatchSession.push()` is called from exactly one place.** Verified by grep: `Modules/Dashboard/ViewModels/DashboardViewModel.swift:2265`, and nowhere else. It must also be called from `BackgroundRefreshCoordinator`. Without that, the plan only arrives when the user opens the phone — the exact inversion the critique names. This concept survives a stale plan better than any other in the set, but "survives" is not "does not need".

### The honest size of this change

**This is the largest data-model change of any concept in the set**: fourteen new fields in one new struct, a HealthKit entitlement plus usage string on two targets that link neither today, a new `WatchCommand` case, a phone-side caffeine-cutoff computation that does not exist in any form, and a rewiring of the push path. It also means the watch app stops being the "dumb terminal" that `WatchShared/WatchBridge.swift:7-8` explicitly declares it to be — that comment ("This file must stay free of UIKit, WidgetKit, HealthKit and Firebase because the watch targets link none of them") stays true for `WatchShared`, but the `LasoWatch` target itself has to grow a native HealthKit layer with its own anchored queries.

And five of the six windows are phone-authored. **On day 1 after install, before a sync, the wrist shows one window and `Day 1 of 7`.** Honest, and unimpressive as a first impression.

---

## 15. Honest drawbacks, and who this fails

1. **The DAY page fails the 5-second test and it cannot be fixed.** A timeline is a comparison, comparisons cost 159–285 ms *per pair*, and this concept's hero element is inherently a comparison. The design's answer is to demote the timeline off the entry screen — which means the concept's own hero is not the first thing you see. Resolved honestly, not eliminated.
2. **Who this fails: anyone without a rhythm.** Shift workers, new parents, frequent flyers, students on an irregular timetable. `CircadianAnalyzer` needs 7 days of *consistent* hourly rhythm; a wake time swinging more than 2 h produces a low-confidence profile, and low-confidence windows are noise dressed as guidance. The only available answer is to hide windows below a confidence floor — which leaves those users with a stand-hour app and a bedtime they already knew. **There is no good answer here and I will not pretend there is one.**
3. **The caffeine cutoff constant has no source.** Eight hours before bed is a product decision. The research set explicitly records that no competitor publishes half-life constants or cut-off times. If Alex drinks a coffee at 16:00 and sleeps fine, the wrist is wrong at them every afternoon — and a value that contradicts felt state destroys trust in *everything else on the screen*, including the windows that are correct.
4. **The strongest argument against the whole concept: Apple already ships three of these six windows.** Stand reminders, the Sleep schedule with its own wind-down, and Activity rings cover Move, Wind down and Bed natively, for free, with better hardware integration. Laso's incremental contribution is the training window and the caffeine cutoff — one of which is a 3-hour range and the other of which has no citation. A fair reviewer could call this a second calendar for things the system already tells you, and I do not have a knockdown reply.
5. **The training window is 3 hours wide.** Verified in code: `generateRecommendations` emits `Int(normalizeHour(activityAcrophase ± 1.5))`, integer hours, so Alex gets `16:00–19:00`. "Train some time in a three-hour range" is weak guidance and it is the analyzer's shape, not a design choice. Narrowing to ±1 h is a one-line change — but it changes an output the phone app already consumes, so it is not free.
6. **The wrist has no calendar, so the plan can be flatly useless.** A 16:00–19:00 training window for someone with a standing 16:00 Tuesday meeting is not slightly wrong, it is wrong every week. This is the most likely single cause of complication removal, and once removed the app is invisible.
7. **The flagship widget's most common afternoon button is a dismiss.** `Snooze 15 min` is the honest label — the app cannot write an `appleStandHour` and must not claim to — but a primary action that means "go away" is the weakest button in the design.
8. **This is the largest data-model change of any concept** — see §14. Fourteen new fields, HealthKit on two targets, and a rewired push path, for a first impression that on day 1 is one window and a countdown to day 7.
9. **R11 blocks Double Tap on the entry screen.** The primary action can be double-tapped from the widget and the notification, but not from S1, because S1 is a vertical tab page. Users who learn Double Tap on the widget will try it in the app and get a page turn. The prototype demonstrates exactly this: firing Double Tap on S1 turns the page and says why.
10. **The concept optimises for a metric nobody measures.** Success here looks like fewer opens, shorter sessions and more complication impressions. If the business needs session count or in-app time — for ads, for upsell placement, for a "daily active" definition — this design actively works against it.

---

## 16. The 5-second test, per screen

| Surface | Verdict | Reasoning |
|---|---|---|
| **S1 NOW** | **PASS** | Two elements carry the whole decision: `Move now` + `28`. No sentence required, no colour required, no comparison required. Median session is 5.0 s; this reads in about one |
| **S2 DAY** | **FAIL at a glance. Passes at roughly 8–10 s.** | A 17-cell strip plus a 5-row list is a scan, not a glance. Bar comparisons run 159–285 ms **per pair** and this screen asks for many pairs. **This is the concept's structural cost and it is not fixable — a timeline is a comparison.** Mitigation: S2 is never the entry screen, never a notification destination, and never where the countdown complication lands |
| **S3 Why** | **PASS for the action, FAIL for the facts** | The 44 pt button is the largest element and is reachable without reading. The three label/value rows require reading and are not glanceable. Acceptable because S3 is depth 2, reached deliberately, and the 5 s budget governs the entry screen |
| **accessoryRectangular** | **PASS** | `Move now · 28m` is the entire decision at zero taps, on the face |
| **accessoryCorner** | **PASS** | `28m` plus a walking glyph plus an arc length |
| **accessoryCircular** | **PARTIAL** | The gauge says how much of the window is gone but not *which* window; the type is carried by a 14 pt glyph, which at 28 cm and ~10° off-axis is a guess. **This is the weakest surface in the set**, and it is the honest reason it deep-links to S3 — the screen that names the window — rather than to S1 |
| **Smart Stack widget** | **PASS** | Same two elements as S1, plus one button |
| **Notification short look** | **PASS** | Title only, no health value — and per R17 a short look is never the only channel; the long look carries the content |

Three of eight surfaces do not fully pass. They are named here rather than hidden, and each has a stated reason for existing anyway.

---

## Prototype notes — what the HTML does, and where it departs from the spec

**Implemented:** the watch face with all three complications in real slots (labelled, deep-linked, competing against system date / Activity rings / weather / calendar / battery / steps); the Smart Stack scrolling through four widgets; short-look and long-look notifications with N1/N2/N3 selectable; launch and wrist-raise return; S1, S2 and S3 with the real navigation model (crown pages S1 ↔ S2, one push to S3); loading, cold-start, empty, HealthKit-denied, phone-unreachable and stale states; Always-On redaction; crown bound to wheel and ↑/↓ with a detent marker and the `digitalCrownAccessory` delta; a visible haptic pulse and a caption naming the `WKHapticType` on every state-changing tap; and a dev toolbar with canvas size, state, Always-On, the window key variable across all three colour bands, the notification selector, "fire Double Tap" and a `.stop` simulator.

The prototype also accepts a URL fragment (`#screen=s2&size=40&state=cold&win=train&ao=1&notif=n3`) so a reviewer can link to an exact state.

**Deviations, all deliberate:**

1. **Always-On on S2 also redacts the row names.** The approved spec lists only two S2 changes in Always-On (the hour strip goes hollow, `6/12 stood` → `—/— stood`), which would leave `Last coffee` and `Wind down` legible while S1's verb is redacted for exactly that reason ("the name is what discloses"). Applying the spec's own rule consistently, row names become 1 pt rules and the times — time-domain — stay. Same treatment on S3's title and facts.
2. **40mm S2 row metrics.** The spec fixes the row anatomy at 46mm (time at x = 10, name at x = 56, 17 pt). At 146 pt of content width that truncates `Last coffee`, so 40mm uses time at x = 8 / 12 pt and name at x = 44 / 15 pt. The 28 pt row height and the 3 pt stripe are unchanged.
3. **The Train card's why line when the phone is unreachable** reads `Ends 19:00` rather than being left blank. The spec says the strain sentence is dropped; something true and time-domain replaces it rather than a gap.
4. **`Fixed by the clock`** renders at 10 pt in the 10 pt gap between fact 3 and the primary button, and the 40mm fact rows moved up 4 pt to make the same gap exist there.
5. **The widget's "under 10 minutes" background wash is implemented but not triggered**, because Alex has 28 minutes left in the Move window at 14:32 and no value on any surface may be invented.
6. **Bezel and crown are a drawing**, not a device: the case, crown grooves and side button are CSS. Crown rotation is shown by the grooves translating plus a detent dot; a real Taptic pulse is replaced by an edge ring and a caption, as `DESIGN-TOKENS.md` requires.

**Verified before delivery:** 980 render permutations (2 sizes × 7 states × Always-On on/off × 5 windows × 7 surfaces) produce no exception, no `undefined`, no `NaN` and no banned string; every absolutely-positioned element on S1 and S3 sits inside the canvas at both 46mm and 40mm; the crown clamp is exercised (moving the caffeine cutoff +40 min clamps to +35 so it cannot cross the 16:00 training start); and the file was rendered in a real browser at both canvas sizes and photographed for every screen.

---

*Confidence: 84/100 — every layout number, state string and citation above was checked against `PROTOTYPE-SPEC.md`, `DESIGN-TOKENS.md` and `research/00-SYNTHESIS.md` in this session, and every §14 code claim was verified by opening the file or grepping the repo this session (`WatchBridge.swift:41,55-75`, `CircadianAnalyzer.swift:54,314-317`, `WindDownScheduler.swift:13`, `SleepNeedCalculator.swift:24,110-119`, `WakeUpTimeDetector.swift:231`, `JournalStore.swift`, `WatchStrings.swift:87`, `DashboardViewModel.swift:2265` as the sole `push()` caller, the watch entitlements file, and `project.yml:249-252,285-288`); the prototype was rendered in Chrome at both canvas sizes and every screen was inspected. Below 90 because: (a) **no Swift was written or built** — the buildability section is a reading of the code, not a compiled proof, and the new native HealthKit layer on the watch target has never been attempted in this repo; (b) the 46mm and 42mm Smart Stack and complication sizes **do not exist in Apple's published tables**, so 46mm is treated as ≈45mm on the research report's own advice and is untested on hardware; (c) the claim that `Text(timerInterval:)` keeps a complication exact without consuming reload budget is inferred from Apple's Always-On statement that `.timer`/`.relative` "update automatically" — I found no first-party statement confirming it specifically for `accessoryCorner`/`accessoryRectangular`, and the whole §8 argument rests on it; (d) Double-Tap-from-Smart-Stack is supported only by the Waterllama store listing (evidence C), not by an Apple statement; (e) the §13 open estimates are mine, built from the 9.4 % notification-yield figure alone, because no watchOS engagement benchmark exists in the research set. | Source: mixed: code (WatchBridge.swift, CircadianAnalyzer.swift, WindDownScheduler.swift, SleepNeedCalculator.swift, WakeUpTimeDetector.swift, JournalStore.swift, WatchStrings.swift, DashboardViewModel.swift, project.yml, LasoWatch.entitlements — all opened or grepped this session) + user-statement (the five brief files and the approved design spec)*
