# 06 — Health Radar (`radar`) — rationale

Prototype: [`06-radar.html`](06-radar.html). Design target 46mm (208 × 248 pt), also renders at 40mm
(162 × 197 pt). All data is Alex, Tuesday 14:32, from `PROTOTYPE-SPEC.md`.

Evidence strength throughout: **A** = peer-reviewed measurement or first-party platform
documentation · **B** = vendor documentation or reproducible product behaviour · **C** = single
reviewer, inference, or snippet-level. Every URL below appears in
`design/watch-v2/research/`. Nothing is invented.

---

## 1. One-sentence philosophy

A sentinel that stays silent 93% of the year, shows its guard rails while it is silent so you can
see it working, and spends its one push on the day two things move together.

---

## 2. The question it answers first, and why that question

**"Is anything outside its usual range right now — and if so, which one?"**

Every other concept in the set asks the user to interpret a value. This one asks nothing. The
chosen question is the only one whose *default answer is "no"*, and a default answer of "no" is the
only thing a wrist can deliver inside the measured 5.0-second median session without the user
reading a digit (**A**, https://www.kostakos.org/papers/chi17.pdf).

It was chosen over "how am I today" deliberately. The shipping app already answers that badly — a
bare `Text("95")` with no colour, no reference frame and the untranslated jargon "Progressive
Overload" underneath (`01-CURRENT-APP-CRITIQUE.md` §3.1). The failure there is not the rendering,
it is that a daily score demands interpretation the user has not been taught. An exception report
demands none.

The cost is stated up front and not hidden: on 340 days a year the answer is boring, and §15
argues that is this concept's largest commercial risk.

---

## 3. Screen-by-screen reasoning, element by element, in order

### The five watched signals, and why exactly these five

Taken verbatim from the shipping engine at `Core/Analysis/IllnessEarlyWarning.swift:48-54`
(`signalMetrics`) — resting heart rate (unfavourable above), HRV (below), sleep duration (below),
steps (below), respiratory rate (above). Not chosen by me. All five are readable natively on
watchOS inside the ~7-day local store (**B**,
https://athlyticapp.helpscoutdocs.com/article/12-widget-or-complication-out-of-sync).

Each signal has a **line** = 60-day baseline ± (sensitivity × 60-day SD). The phone ships the
baseline, the SD and therefore the line. The watch reads today's value itself.
**The phone ships the goalposts; the wrist reads the ball.** That split is the reason this concept
never needs the phone to be present, and it is the whole architecture in one sentence.

Three states, named: **Clear** (0 or 1 signal outside), **Watching** (≥2 outside on one night,
**never notifies**), **Flagged** (≥2 outside on ≥2 consecutive nights *and* the delta gate passed,
notifies once per episode). Alex today is **Watching**, and Health Radar therefore sends her
nothing. That is the concept demonstrating its own discipline, not a gap.

### Screen 1 — Status (entry, page 1 of 3)

The one decision it enables: **look further, or drop the wrist.**

| Element | Why it is there |
|---|---|
| **Freshness dot**, 6 × 6pt top-right | Filled = lines synced <24h · 1.5pt ring = 1–7 days · ring + slash = >7 days. Three states carried by **shape**, so it survives the watch face inverting colours (R18). Sits top-right and is read **last** by VoiceOver, because freshness is context, not the headline. |
| **State glyph**, 28 × 28pt, 2.5pt stroke | Check-in-circle / hollow diamond / filled notched triangle. This is the fastest channel on the screen and the only one that reads pre-attentively at 28cm. |
| **State word**, `title` 22pt in the band colour | "Watching". Words carry judgement natively where a number does not — the Gentler Streak position (**B**, https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface). |
| **Two signal rows** — name, value, unit, delta chip | Principle 3: never ship a bare number (**A/B**, https://support.google.com/fitbit/answer/14236710?hl=en). The **▲ / ▼ / –** glyph in the chip is the non-colour channel for direction. |
| **Two margin bars**, 188 × 6pt | X-axis is 0σ (left) → 2.0σ (right). A 2pt tick sits at the sensitivity line. Fill left of the tick is `textTertiary`; fill right of it is `fair`. **The bar crossing the tick is the verdict rendered as position**, which is what makes colour the fourth channel rather than the first. Bars, not rings: 159–285 ms to read a comparison versus 1548–1772 ms radial (**A**, https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf). |
| **Meta line**, `caption2` | "First night · heart 74 now". The "74" is the only element that moves during the day — a one-shot `HKSampleQuery` on a 60s timer. It is the concept's answer to R14 ("a static complication… may be less likely to remain in a prominent position"). |
| **Action button**, 188 × 44pt | Exactly one action per page (principle 14). "Take it easy today" is an imperative, not a description (principle 4, **A/B**, https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html). |

**Button state machine**, which exists to fix a real shipping bug. `WatchRootView.swift:95` disables
the action button whenever `pendingCommands` is non-empty, and `WatchStore.swift:27-29` admits in
its own comment that a lost reply leaves it pending until relaunch. Here: tap → `.success` +
"Easy day set ✓" disabled → **no phone reply within 10s** → re-enable, "Not saved · tap again",
`.failure`. Never permanently disabled by a lost answer. The dev toolbar's *phone answers /
never answers* switch drives both paths (2s in the prototype, labelled).

**Clear-day variant** (the 340 days): check glyph, "All clear", row 1 is the *closest* signal to its
line, both bars short of the tick, and the button becomes "Mute for 7 days" — a silent day needs no
prescription.

### Screen 2 — Signals (page 2 of 3)

The one decision it enables: **is this flag believable — did the signals I actually trust move?**

Five rows at 34pt pitch: name · value · delta chip · margin bar, plus one caption. This is a
**labelled chart**, not a prose screen, and Apple's own prescription for dense comparative content
in a small canvas is a chart — its `accessoryRectangular` exemplar is a 24-hour heart-rate graph
(**A**, https://developer.apple.com/design/human-interface-guidelines/complications). I am flagging
in §16 that this argument is about 70% honest and that this screen fails the glance test.

**Row 5 is the honest detail that carries the whole concept.** Steps reads 5,240 and is drawn as a
**hollow outline with no line applied**, labelled "reads at midnight". At 14:32 today's step count
is a partial day; `IllnessEarlyWarning.computeDailySignals` evaluates completed days; comparing a
partial day to a full-day baseline would be wrong. So it is drawn unjudged. This is not a
placeholder — it is a correct statement about what the engine can honestly say right now, and it
directly answers anti-pattern 4, the black-box score (**B**,
https://www.autonomous.ai/ourblog/bevel-app-review).

Fixed height, **never scrolls**. That is the precondition for crown paging to work at all
(**A**, https://developer.apple.com/design/human-interface-guidelines/tab-views).

### Screen 3 — Sensitivity (page 3 of 3)

The one decision it enables: **how far off is far enough before this thing taps my wrist?**

Hero "1.0" at `heroNumber` 52pt, caption "of your usual swing" — plain English for one standard
deviation. **The word "sigma" appears nowhere on screen.** Five mini bars restate pages 1–2 with
the tick redrawn live as the crown turns, and a count line "2 of 5 outside today" recomputes on
every detent. Turning the crown from 1.0 to 1.4 visibly walks Alex's day from *Watching* to
*All clear*, and the prototype propagates that everywhere — face, widget, complications, page 1.
That is what makes an abstract statistical threshold concrete.

This is the Training Today model: notify on "average RTT changes compared to the previous four
days", with the change threshold set by the user (**B**,
https://trainingtodayapp.helpscoutdocs.com/article/80-getting-started-with-training-today).

### Deviations from the approved spec, and why

Every one of these is a "closest correct thing", not a redesign.

1. **Page-1 row columns.** The spec places the value right-aligned at x160, the unit at x164 and the
   delta chip right-aligned at x198. At real SF glyph widths "bpm" occupies roughly 164–188 and
   "▲ +3" roughly 168–198, so the two collide. Implemented as three non-overlapping columns —
   name (w 66) · value + unit right-aligned · delta chip right-aligned at x198. Same content, same
   reading order, same right edge.
2. **40mm page 1 also drops the unit**, not just the meta line. 146pt of content width cannot hold
   name + value + unit + chip without clipping. VoiceOver still says "beats per minute".
3. **Page-2 steps note wraps to two lines** ("reads at / midnight") and that row's bar drops 8pt
   (46mm) / 6pt (40mm) to stay clear. One-line at a legible size does not fit the chip column.
4. **Page-2 value/name type steps down at 40mm** (name 11pt, value 14pt, chip 10pt, caption 10pt).
   The spec gives 15pt values at 40mm; at 146pt width with a delta chip, 15pt clips "6h 12m". Page 3
   at 40mm also moves the bars up 4pt and the button up 2pt so nothing sits inside the display's
   24pt bottom corner radius.
4b. **The empty state drops its third line at 40mm** ("Daytime signals still watched."), keeping the
   two live figures. Same trade the loaded screen already makes with the meta line. The `accessoryRectangular`
   complication and the Smart Stack widget also step their type down inside the 41mm box
   (171.5 × 73pt), which Apple publishes and the 46mm box, which it does not.
5. **The long look scrolls.** Its four lines plus three actions exceed 248pt. This is real watchOS
   behaviour and R14's no-scroll rule applies to app detail views under vertical tabs, not to
   notifications. Crown scrolls it; the caption tells the reviewer.
6. **Crown on page 3 drives the dial, not paging.** That is exactly what binding
   `digitalCrownRotation(_:)` to a page does on device, so it is faithful rather than a compromise —
   but it does mean you leave page 3 by swiping or tapping a page dot, both of which work.
7. **The live "74" does not tick in the prototype.** Animating it would mean inventing heart-rate
   values the shared fiction does not contain. The 60s re-read is described, not faked.
8. **The Smart Stack clear-day line reads "5 of 5 inside" verbatim from the spec**, which is very
   slightly inconsistent with steps being unjudged before midnight. Kept as specified and flagged
   here rather than silently corrected.
9. **The Always-On freshness dot is drawn in `textTertiary`.** The spec's redaction table does not
   list the dot, but §9 says no colour survives Always-On on this screen, so the green filled dot
   is stroked neutral.

### The illustrative sigma constants

The shared fiction gives Alex's raw values and three baselines (RHR 55, RR 14.6, HRV 56 ± 9) but no
SD for resting HR, respiratory rate or sleep. A margin bar cannot be drawn without one. Declared in
the prototype in a single labelled block:

```
/* ILLUSTRATIVE: SDs for resting HR, respiratory rate and sleep are NOT specified
   in the shared fiction. These sigma positions drive bar fills only and are never
   printed on screen. HRV is fully derived: 48 vs 56 +/- 9 = -0.89 sigma. */
```

RHR at **+1.3σ**, RR at **+1.2σ**, sleep at **−0.6σ**, HRV at **−0.89σ** (derived, not assumed).
**No σ value is ever printed.** Every number the user sees — 58, 15.2, 48, 6h 12m, 5,240, 55, 14.6,
56, +3, +0.6, −8, 74 — comes straight from the fiction.

---

## 4. Why this works on a watch specifically — and would be worse on a phone

1. **The sensor is on this wrist, all night.** Resting HR, HRV, respiratory rate and sleep are
   overnight measurements taken by the device that is showing the result. On a phone they are a
   report about a night that happened elsewhere.
2. **A sentinel has to be passively visible or it is not a sentinel.** 142.1 watch sessions per day,
   82.3% of them self-initiated (**A**, https://www.kostakos.org/papers/chi17.pdf). A complication
   that changes glyph shape the morning something is off is seen 15–40 times a day at zero marginal
   cost. A phone app that would have to be opened to deliver the same news gets opened on the days
   the user is already worried — which is exactly when the news is least useful.
3. **The verdict is one bit.** A phone screen would demand that a whole screen be filled, and
   filling it is how the concept turns into the dashboard-mirroring anti-pattern that Bevel already
   demonstrates (**C**, https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html).
4. **The phone genuinely cannot be assumed present.** With the split above, page 1 renders fully
   normal with the phone in another room, in aeroplane mode, or after a week without a sync. The
   only visible difference is the freshness dot and one caption. There is no state in which this app
   asks the user to go and use their phone.

**What this concept gives the phone instead:** all history. Per-signal 7-day charts, the accuracy
ledger, the false-positive log. Oura demotes slow metrics into "My Health" because they are "not
designed to be used every day", and Training Today keeps AIS/OFI on iPhone. Same line, drawn on
purpose (synthesis §2, convergent pattern 6).

---

## 5. watchOS HIG guidance applied

| Rule | What this design does | URL |
|---|---|---|
| **R1** — interactions are seconds | Entry screen delivers the verdict in a glyph + a word; no page needs a digit read to decide | https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos |
| **R2** — the app is not the product | Complication + Smart Stack widget carry all 340 quiet days; the app is the detail view | https://developer.apple.com/documentation/watchos-apps |
| **R3** — only 2 families reach the Smart Stack | `accessoryRectangular` only; Corner and Inline stay watch-face-only; Inline gets exactly one tap target | https://developer.apple.com/design/human-interface-guidelines/widgets · https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline |
| **R4 / R5** — reload budget, never real-time | Three timeline entries a day (wake+15, local midnight when steps become evaluable, 12:00) against a 40–70 reload budget, well inside the 5-minute minimum spacing | https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date |
| **R6** — watch HealthKit reaches ~7 days | Phone ships 60-day lines; watch reads today's values. Nothing on the wrist needs a window longer than last night | https://athlyticapp.helpscoutdocs.com/article/12-widget-or-complication-out-of-sync |
| **R7** — redact health data in Always-On | Values → en-dash rows of matching glyph count, delta chips removed entirely, bars → stroked outlines, state word → "Radar", **no colour at all**. Layout identical so nothing jumps on wake | https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state |
| **R8** — no haptic while sampling HR | **No live HR gathering exists in this concept.** One-shot `HKSampleQuery` on a 60s timer, no `HKWorkoutSession`, no anchored streaming query — so the forbidden window is never entered | https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:) |
| **R9** — background execution is never guaranteed | The wake+15 check is best-effort; late by ~30 min is normal and stated as such in §15 drawback 8 | https://developer.apple.com/documentation/watchkit/background-execution |
| **R10** — crown is navigation | Vertical `TabView`, 3 pages, depth 1, every page fixed height and non-scrolling. Crown also inspects data on page 3, Apple's second endorsed use | https://developer.apple.com/design/human-interface-guidelines/digital-crown · https://developer.apple.com/design/human-interface-guidelines/page-controls |
| **R11** — no primary action on vertical tabs | **No `handGestureShortcut(.primaryAction)` anywhere in the app.** In-app, Double Tap advances the vertical tab, which is the watchOS 11 default. The concept's Double Tap primary action lives on the notification long look | https://developer.apple.com/design/human-interface-guidelines/gestures |
| **R12** — relevance is a different API on watchOS | `TimelineProvider.relevance()` → `WidgetRelevance`; `TimelineEntry.relevance` is never touched because it does nothing on Apple Watch | https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks · https://developer.apple.com/documentation/relevancekit/relevantcontext |
| **R13** — no spinners | Loading renders the cached state **fully, at full opacity**, with the dot in its ringed form. Only the meta line changes to "reading now" | https://developer.apple.com/design/human-interface-guidelines/feedback |
| **R14** — static surfaces get deleted | Margin bars move every morning; live HR moves hourly. Acknowledged as thin in §15 drawback 2 | https://developer.apple.com/design/human-interface-guidelines/widgets |
| **R15** — one deep link per complication | Three complications, three genuinely different destinations (§8) | https://developer.apple.com/design/human-interface-guidelines/widgets |
| **R16** — extended runtime capped | Not used. No session type is claimed | https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions |
| **R17** — short look is not a channel | Short look carries no numbers, no metric names, no verdict word. Long look is 4 lines, 3 custom actions under the 4 cap, and the first action is non-destructive so Double Tap picks it | https://developer.apple.com/design/human-interface-guidelines/notifications |
| **R18** — colour never alone | Word + glyph shape + bar position vs tick, colour fourth. `poor` red is used nowhere | https://developer.apple.com/design/human-interface-guidelines/widgets |

**Crown specifics** (**A**, https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation(_:) ·
https://developer.apple.com/documentation/swiftui/digitalcrownrotationalsensitivity ·
https://developer.apple.com/documentation/swiftui/view/digitalcrownaccessory(_:)):
`digitalCrownRotation(_:)` (watchOS 6+) with `DigitalCrownRotationalSensitivity` tuned so one finger
sweep covers 1.0 → 2.0; `digitalCrownAccessory(_:)` (watchOS 9+) shows the live value beside the
crown. Apple: *"You may need to experiment to find the level of sensitivity that works for your use
case."* Crown **press** does nothing — watchOS reserves it. Visual feedback is mandatory
(*"If you don't provide visual feedback, people are likely to assume that turning the Digital Crown
has no effect"*, `research/apple-hig.md:239`), which is why the hero number, all five ticks and the
count line all move on every detent.

---

## 6. UX principles used, and the mechanism

| Principle | Mechanism in this design | Evidence |
|---|---|---|
| **3 — never ship a bare number** | Every value carries a name, a delta with a direction glyph, and a bar against its own line | **A/B** https://support.google.com/fitbit/answer/14236710?hl=en |
| **4 — imperative, not description** | "Take it easy today", not "Moderate body stress". "Doesn't match", not "Provide feedback" | **A/B** https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html |
| **6 — bars, not rings, for comparisons** | Every comparison on every surface is a horizontal bar with a tick. The only radial encoding in the whole concept is the `accessoryCircular` gauge, which is a single absorbed level, not a comparison | **A** https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf |
| **10 — progressive disclosure of "why"** | Glance → state word · page 2 → all five margins and their lines · phone → history | **B** https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html |
| **11 — name the cold start, never fabricate** | "Radar needs 14 nights. 6 done." + a progress bar + "It starts watching on 12 Aug." The 14 is `IllnessEarlyWarning.minimumDataDays` (line 60), not invented | **B** https://support.google.com/fitbit/answer/14236710?hl=en |
| **12 — publish the staleness rule in-product** | Page 2 stale caption gains: "The wrist updates about 4 times an hour, so it can trail the phone." Athlytic does this and pre-empts the ticket; Bevel does not and has a live public bug thread | **B** https://athlytic.github.io/athlyticapp/troubleshooting/ · https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match |
| **14 — one action per verdict screen** | Exactly one button per page. Three tappable elements in the entire app | **B** https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface |
| **16 — tiny reused colour system** | Two tokens only: `optimal` and `fair`. `poor` (#E05C64) appears **nowhere** | **A/B** https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path |
| **17 — a score that contradicts felt state is worse than none** | "Doesn't match" is a first-class notification action, not buried in settings. It mutes the episode 72h, lifts the involved lines by 0.2σ for 14 days, and reports the rejection to the phone | **B/C** https://www.dcrainmaker.com/2021/11/whoop-platform-review.html |

**The deliberate token deviation, stated plainly:** `poor` red is used nowhere. Flagged escalates by
glyph fill (hollow diamond → filled notched triangle) and bar solidity, not by hue. Rationale:
Gentler Streak ships no red anywhere and won on the gentler read, while Athlytic's alarming
treatment drew the explicit anxiety complaint (**C**,
https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/). The
pre-attentive decision a user makes at 28cm is *clear vs not-clear*, and `optimal` vs `fair` carries
it completely. Watching vs Flagged is a fine distinction that shape and word carry adequately.

---

## 7. Psychological principles that drive repeat opens

| # | Mechanic | Evidence strength | How it is applied — and where it is thin |
|---|---|---|---|
| 3 | **Goal gradient — visible shrinking distance to a threshold** | **strong: peer-reviewed** (https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf) | The margin bar **is** a goal gradient, inverted: it renders distance to the line rather than distance to a reward. This is the single strongest mechanic in the concept, and unlike a streak it cannot be gamed, because the user does not control it. Note the paper's own failure mode — effort resets once the goal is reached — which here means a user who is far inside every line has nothing to watch. |
| 4 | **Bar encodings over radial** | **strong: peer-reviewed** (https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf) | Every comparison surface is a bar. 159–285 ms versus 1548–1772 ms is a 6–10× saving against a 5.0-second budget. |
| 2 | **Surviving the first 8 days** | **strong: peer-reviewed** (https://arxiv.org/pdf/1910.01165) | Cold start is named with a date and a count, never a fake number. **This is also where this concept is weakest** — see §15 drawback 3. >50% of health-app users discontinue in week 1, and this concept has 14 nights of cold start on top. |
| 6 | **Push the verdict at wake time** | **medium: vendor data** (https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-4D26FDDC-63BD-4910-95B8-98937FEC2545.html) | N1/N2 fire at wake+15; the Smart Stack widget's relevance is keyed to `RelevantContext.sleep(.wakeup)`. No published effect size exists — treated as directional. |
| 7 | **Delta-triggered notifications** | **strong on the near-term effect, strong that it is NOT retention** (https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf · https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/) | 3.5× next-hour lift, but only 1.04–1.3× over 24h, **no measurable long-term retention effect**, and only 9.4% of notifications produce any session. **Design response: notifications are explicitly not budgeted as the retention mechanism.** ~8 pushes a year cannot hold anyone and are not expected to. They buy the near-term open at the one moment where a near-term open has real value. |
| 1 | **Dynamic content at near-zero access cost** | **strong (mechanism), weak (this application)** (https://link.springer.com/article/10.1007/s00779-011-0412-2) | Margin bars move every morning; the live HR figure moves hourly. **Acknowledged as thin.** Overnight vitals settle at wake and do not move again. See §15 drawback 2. |
| 5 | **Uncertainty about the outcome** | **strong (mechanism), inferred (application)** (https://pubmed.ncbi.nlm.nih.gov/12649484/) | The user genuinely cannot predict from yesterday whether a bar has crossed its tick. Critically, no fake variance is manufactured — the numbers stay true, or principle 17 kills the concept. |
| 8 | **Streaks / loss aversion** | **medium: vendor data** (https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/) | **Rejected.** A streak on *not being ill* rewards nothing the user controls and breaks on the day they most need support. See §12. |
| 10 | **Social / peer comparison** | **weak: anecdote** (https://gadgetsandwearables.com/2025/01/24/whoop-daily-outlook/) | Not used. No verified watch-side implementation exists in the research set. |

**Anti-pattern 18, stated as the concept's largest structural risk:** 82.3% of watch sessions are
self-initiated and only 9.4% of notifications yield any session, so an app living only behind a push
fights for the 17.7% slice (**A**, https://www.kostakos.org/papers/chi17.pdf). Health Radar's daily
presence is therefore the complication and the Smart Stack widget, both of which work on the 340
days when no push fires. **If the complication is removed, this concept is dead — not degraded,
dead.**

---

## 8. Complication strategy

Three families, three distinct deep links — R15 / anti-pattern 15: *"If all the complications you
support open the same area in your app, they can seem less useful"*
(https://developer.apple.com/design/human-interface-guidelines/widgets).

### `accessoryCircular` — Radar state → `laso://radar/status`
Closed gauge, 2.5pt stroke (≥2pt floor), 32 × 32pt at 45/49mm. Fill fraction = the **margin on the
signal closest to its line**, mapped 0 (at or past the line) → 1.0 (2σ inside). Alex today: RHR is
past its line, so the ring reads **empty** with a 2.5pt `fair` overshoot arc drawn *outside* the
track. Centre glyph 11 × 11pt carries the state by shape. `widgetLabel` on faces that support it:
"Watching · RHR".

### `accessoryRectangular` — Five margins → `laso://radar/signals`
193 × 82pt at 45/49mm. Line 1 "Watching · 2 of 5" with the state glyph leading; rows 2–6 are five
3pt bars with the tick; line 7 is "heart 74 now", the one element that changes hourly.

### `accessoryInline` — One line → `laso://radar/signal/restingHeartRate`
`◇ Radar: 2 signals out` (clear day: `✓ Radar: clear, RHR closest`). **Glyph first**, so the meaning
survives the system's tint and colour inversion (R18). One tap target
(https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline). It opens page 2
with the closest signal's row focused for VoiceOver — a genuinely different destination.

### `accessoryCorner` — deliberately NOT shipped
Corner is 10.5–12pt text and 2–4 characters. A radar state cannot compress to "CLR"/"WCH"/"FLG"
without becoming internal jargon — which is precisely the failure the shipping app already has with
"Progressive Overload" (`01-CURRENT-APP-CRITIQUE.md` §3.1.3). Shipping nothing beats shipping a
code.

### Why would a user give up a face slot for this?

Honestly: **because it is the only complication on the face that is allowed to be boring.** The
Activity rings ask you to close them; a readiness score asks you to interpret it; the weather asks
you to plan. The Radar circular asks nothing 340 days a year and is the single glyph that changes
*shape* the morning something is genuinely off. The user is buying peripheral vision, not
information.

The counter-argument is real and I am not hiding it: R14 warns that *"a static complication that
doesn't display meaningful data may be less likely to remain in a prominent position on the watch
face."* The ring moves every morning as margins shift, and the rectangular family carries a live
heart rate — but this is **weaker day-to-day dynamism than a Body Battery concept**, and that is the
concept's structural risk (§15 drawback 2).

---

## 9. Smart Stack strategy

**`accessoryRectangular` only.** R3 permits a circular Smart Stack variant; it is declined because a
radar state in a 32pt gauge with no room for the two signal names loses to the rectangular version
at every size, and shipping two variants of one idea is how a widget gets scrolled past twice.

Content in the 152 × 69.5pt (40mm) → 191 × 81.5pt (49mm) box — 1 title + 2 body lines, the realistic
ceiling. Apple publishes no line count and **no rows for 42mm or 46mm** (Series 10/11) in its own
size table, so 46mm is treated as ≈45mm and flagged for on-device verification (synthesis §7).

```
◇ Watching · 2 signals                 15pt/600
Resting HR 58   ▲+3   ▓▓▓▓▓▓│▓▓        12pt + 3pt bar
Breathing 15.2  ▲+0.6 ▓▓▓▓▓▓│▓         12pt + 3pt bar
```

Clear day: `✓ All clear` / `Closest: resting HR  ▓▓▓▓│▓▓▓▓` / `5 of 5 inside · checked 07:04`.

**Background stays true black.** Apple explicitly endorses a meaningful coloured background here
(*"the Stocks app uses a red background for falling stock values"*). Health Radar declines it,
because a coloured card broadcasts a health verdict to everyone who can see the wrist and it is the
one element that cannot be redacted in Always-On. Colour stays inside the glyph, the chip and the
bar fill.

### When it should surface

- `TimelineProvider.relevance()` returning `WidgetRelevance`, built from
  `WidgetRelevanceAttribute(configuration:context:)`. **Not** `TimelineEntry.relevance`, which does
  nothing on watchOS and is dead code (R12).
- Exactly two clues: `RelevantContext.sleep(.wakeup)` — the whole radar payload settles at wake —
  and `RelevantContext.fitness(_:)`, because the highest-value moment to distinguish "hard session
  yesterday" from "something else" is right after a workout.
- `HKCategoryTypeIdentifier.sleepAnalysis` must be requested by **both the app and the widget
  extension** or the clue silently does nothing
  (https://developer.apple.com/documentation/relevancekit/relevantcontext).
- **Timeline-provider path, not `RelevanceConfiguration` (watchOS 26+), on purpose.**
  `RelevanceConfiguration` lets a widget appear multiple times per clue, but Apple states plainly
  that people cannot configure such widgets, add them to the Smart Stack, or pin them to a fixed
  location. A sentinel's value is being **pinned and permanent** across 340 quiet days. Pinnability
  beats opportunistic surfacing here. A builder should not "upgrade" this.
- Cadence: three entries a day — wake+15, local midnight (when steps become evaluable), 12:00 —
  against a 40–70 reload budget (R4).

---

## 10. Notification strategy

Two notifications exist. That is the entire inventory.

### N1 — Radar flag (the only unprompted alert)

Trigger, all three required:
1. `radarState == .flagged` — ≥2 signals outside their lines on ≥2 consecutive completed nights,
   after the existing `isExerciseRecoveryLikely()` exclusion.
2. **AND** the 3-night mean of the signalling set has moved more than the user's sensitivity
   threshold versus the **prior 4-night mean**. This is the delta gate, copied from Training Today.
   **Absolute state alone never fires anything.**
3. **AND** not muted, not inside an already-notified episode, not between 22:00 and 05:00.

Fires at wake + 15 min, best-effort, from a watch-side background refresh task. Late by ~30 min is
acceptable and normal (R9).

**Short look:** "Laso Radar / Two signals moved together last night." No numbers, no metric names,
no verdict word — someone reading over a shoulder learns nothing (R17: *"Avoid including
potentially sensitive information in the notification's title"*).

**Long look:** sash `fair` amber, never `poor` red. Four lines: the headline, two evidence rows each
with a 3pt margin bar, and "Second night at these levels · confidence low" with a 3-segment
confidence bar, 1 of 3 filled. Three custom actions under the 4 cap plus system Dismiss:

| # | Label | Effect |
|---|---|---|
| 1 | **Take it easy today** | Writes an easy-day flag to the phone, `.success`. Non-destructive and first, so **this is the Double Tap target** (R17) |
| 2 | **Doesn't match** | False-positive feedback: mutes the episode 72h, raises the involved lines by 0.2σ for 14 days, sends the rejection to the phone |
| 3 | **Mute 7 days** | Global mute — literally the *"big friendly toggle to hush stress for a while"* the Athlytic reviewer asked for and did not get |

No "Open app" action — Apple: *"Avoid providing an action that merely opens your app."* The long
look already contains the evidence.

### N2 — Radar clear

Fires once when state leaves Flagged, at wake. **No custom actions** — an all-clear needs no
decision. "Back to clear / Resting HR 55, back at baseline / Breathing 14.5, back at baseline /
Flagged for 2 days."

N2 exists because **an alert with no all-clear is the thing that generates the anxiety, not the
alert itself.** This is the specific counter to anti-pattern 3 and it costs one push per episode.

### Cadence ceiling before it becomes noise

- **Max 2 pushes per episode** (one open, one close).
- **Max 1 episode per 72 hours.**
- **Hard cap 4 pushes per calendar month.** When the cap is hit the state still changes on the
  complication, the widget and in the app — **silently**. The cap suppresses the tap, never the
  truth.
- **Expected real-world volume: ~8 pushes per year.**
- **No re-engagement pushes, no "you haven't checked in", no weekly digest.** Anti-pattern 17: across
  two MRTs, time to disengagement was *not* significantly different between notification policies.
  Sending one anyway would spend the user's trust on a lever that does not work.

---

## 11. Haptic language

| Event | `WKHapticType` | Note |
|---|---|---|
| N1 / N2 arriving | `.notification` | Played by the system with the notification; the app never calls `play(_:)` for it |
| Crown detent on the sensitivity dial | `.click` | One per 0.1 step, 11 detents across 1.0–2.0 |
| Crown detent moving between vertical tabs / Smart Stack widgets | `.click` | Same value-step semantics |
| "Take it easy today" / "Doesn't match" / "Mute" accepted | `.success` | Fires on the tap, optimistically |
| Phone rejects the write, or the 10s timeout expires | `.failure` | Also re-enables the button and swaps the label |
| "Ask again" when `requestAuthorization` silently no-ops | `.failure` | Fails loudly. Label becomes "Already asked · use Settings" |
| Clear → Watching/Flagged **while frontmost** | `.directionDown` | *"an important value decreased below a significant threshold"* |
| Flagged/Watching → Clear **while frontmost** | `.directionUp` | Demonstrated in the prototype by turning the crown past 1.3σ |

**R8 compliance, and how this concept sidesteps it entirely.** Apple: *"When you engage the haptic
engine, HealthKit stops gathering heart rate data until after the haptic engine finishes"*
(https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)). **Health Radar
never starts live heart-rate gathering.** The "heart 74 now" figure is a one-shot `HKSampleQuery`
for the most recent stored `heartRate` sample on a 60s timer. No `HKWorkoutSession`, no
`HKLiveWorkoutBuilder`, no anchored streaming query. The app is therefore never inside the forbidden
window and no haptic ever needs suppressing. It is also the lazier build.

Two further constraints observed: minimum 100ms spacing (only one haptic fires per interaction
here), and no background haptics outside a workout session — which is why every direction haptic is
gated on `applicationState == .active`.

---

## 12. What was deliberately excluded, and why

| Excluded | Why |
|---|---|
| **A readiness / recovery score anywhere** | A sentinel that also grades you is two products. The moment a number appears, the user optimises the number instead of trusting the silence. `readinessScore` stays on the wire and is never rendered |
| **Red (`poor` #E05C64)** | Gentler Streak ships no red and won on it; Athlytic's alarming treatment drew the anxiety complaint. Escalation is by glyph fill, not hue |
| **Per-signal 7-day history / any drill-in** | Adds a navigation level (anti-pattern 14) and forces 5 tap targets at 28pt, below the 44pt default. History is a phone job — Oura, Training Today and Athlytic all draw the same line |
| **A lifetime accuracy ledger on the wrist** ("flagged 4, you rejected 1") | Tempting, and it was in an earlier draft. Cut because it is permanent chrome consuming a text line on 340 silent days to show a number that changes 4 times a year. The false-positive *mechanism* ships in full; only the scoreboard moves to the phone. Replaced by a one-day inline confirmation: after "Doesn't match", the meta line reads "Noted. This one won't flag again for 3 days." |
| **`accessoryCorner`** | 2–4 characters forces an abbreviation code. The shipping app already fails this way with "Progressive Overload" |
| **A circular Smart Stack widget** | R3 allows it; it loses to the rectangular one at every size. Two variants of one idea gets scrolled past twice |
| **Any workout / live-strain surface** | `HKWorkoutSession` would give background haptics and continuous runtime, both irrelevant to an overnight sentinel — and it would drag R8 back into scope |
| **Any re-engagement or digest notification** | Anti-pattern 17: notification policy had no measurable effect on time-to-disengagement across two MRTs |
| **A coloured Smart Stack widget background** | Apple explicitly endorses it. Declined because a coloured card broadcasts a health verdict at arm's length and cannot be redacted in Always-On |
| **Streaks, badges, "days clear" counters** | Mechanic 8 is medium-evidence and structurally wrong here: a streak on *not being ill* rewards nothing the user controls and breaks on the day they most need support |
| **Morning check-in and quick-log** | Both live in the existing app and belong to other concepts. Radar writes exactly three things and reads five |
| **`handGestureShortcut(.primaryAction)` in the app** | R11 forbids it on vertical tabs. Double Tap keeps its system meaning in-app |

---

## 13. Expected opens per day, with the mechanism for each

Counting **app launches only**. Complication glances are counted separately because they are not
opens.

| # | Trigger | Time | Mechanism | Frequency |
|---|---|---|---|---|
| 1 | Wrist raise onto a face carrying the circular complication | all day | Zero-cost passive glance. 142.1 watch sessions/day, of which a plausible 15–40 land on the face carrying it | **not an open** — ~15–40 glances/day |
| 2 | Crown-down to the Smart Stack at wake, widget surfaced by `RelevantContext.sleep(.wakeup)` | 06:30–08:00 | Relevance-driven placement; the user is crowning down anyway | **~0.6 widget views/day** (not an open) |
| 3 | State changed to Watching overnight; user noticed the diamond on the face and opened to see which signals | 07:00–09:00 | Curiosity, driven by a glyph shape change | ~20 opens/year |
| 4 | Flagged episode: user opens repeatedly across the 2–3 days of an episode | scattered | Genuine concern. ~4 episodes/year × ~10 days × 2 | ~20 opens/year |
| 5 | Opened from an N1/N2 long-look action, or after dismissing one | 07:15 | 9.4% of notifications produce any session; ~8 pushes/year | ~1 open/year |
| 6 | Sensitivity tuning after a false positive, or during onboarding | evening | Deliberate settings visit | ~3 opens/year |

**Honest total: ~44 app opens per year ≈ 0.12 app opens per day.** Plus ~0.6 Smart Stack widget
views/day and 15–40 passive complication glances/day.

I am not going to inflate this. **This concept has the lowest app-open count of the ten and it is
not close.** If the success metric is app DAU, Health Radar fails on arrival. Its defence is R2 —
Apple states outright that users *"may never explicitly launch your app"* — and the arithmetic of
142 sessions/day: a complication seen 30 times a day at zero marginal cost delivers more total
exposure than an app opened twice a day, and it delivers it during the 340 days when there is
nothing to say. Whether that exposure is *worth* anything is the open question in §15.

---

## 14. Buildability against this codebase

Line references are to commit `cbb674f` (v3.26), read this session.

### 14a. What exists today and is reused unchanged

| Asset | Location | Used for |
|---|---|---|
| `WatchPayload.dayKey` · `.updatedAt` · `.isStale(now:)` | `WatchShared/WatchBridge.swift` | Freshness dot, "synced 07:04", the stale caption |
| `WatchBridge.dayKey(for:)` | same | Day boundary, so the wrist and phone agree across midnight and timezone changes |
| `AppliedCommandLedger` de-duplication (`appliedCommandIdsKey`, limit 200) | same | Both new commands reuse it verbatim |
| `WatchCommandResult` rejection path | `LasoWatch/WatchStore.swift` | Drives the `.failure` haptic and the "Not saved · tap again" label |
| App Group `group.com.lasohealth.fit.watch` | same | Complication reads the cached payload without its own session |
| `IllnessEarlyWarning.signalMetrics` (`:48-54`), `minimumDataDays = 14` (`:60`), `minSignalingMetrics = 2`, `minDaysElevatedForWarning = 2` (`:76-77`), `exerciseRecoveryMultiplier = 1.5`, `computeConfidence` | `Core/Analysis/IllnessEarlyWarning.swift` | The five signals, the cold-start count, the state definitions and the confidence band. **No new clinical threshold is invented anywhere in this concept** |

**Unused by Health Radar but left on the wire for other surfaces:** `readinessScore`,
`readinessGrade`, `dayType`, `actionHeadline`, `actionDetail`, `actionIcon`, `actionDone`,
`checkInAvailable`. Three of those (`readinessGrade`, `actionDetail`, `actionIcon`) are already
dead weight today — built in `PhoneWatchSession.buildPayload` (`Core/Data/PhoneWatchSession.swift:117-131`),
shipped, cached, and rendered by no view (`01-CURRENT-APP-CRITIQUE.md` §2).

### 14b. New `WatchPayload` fields

```swift
struct RadarLine: Codable, Equatable {
    let key: String          // "restingHeartRate" | "hrv" | "sleepDuration" | "steps" | "respiratoryRate"
    let baseline: Double     // 60-day mean
    let sd: Double           // 60-day SD
    let unfavourable: String // "above" | "below"
}

// added to WatchPayload:
let radarLines: [RadarLine]              // 5 entries
let radarActiveEnergyBaseline: Double    // for the exercise-recovery exclusion
let radarSensitivitySigma: Double        // user's threshold, 1.0...2.0
let radarBaselineNightsDone: Int         // 0...14, cold start only
let radarMutedUntil: Date?
```

Five small structs plus four scalars. `WatchPayload` is a flat `Codable` with **no version marker**
(`03-ARCHITECTURE.md` §4), so this needs the payload versioning work that document already
identifies — an older watch build decoding a newer payload is the risk, not these fields.

**`radarState`, `radarConfidence` and `radarDaysElevated` are deliberately NOT in the payload.**
The watch computes them. That is what makes the concept work with the phone in another room.

### 14c. New `WatchCommand` cases

```swift
case radarFeedback(id: UUID, createdAt: Date, kind: String, signalKeys: [String])
    // kind: "easyDay" | "doesNotMatch" | "mute7d"
case radarSensitivity(id: UUID, createdAt: Date, sigma: Double)
```

Both reuse the existing de-duplication ledger and rejection path unchanged.

### 14d. New shared code — one implementation, not two

`WatchShared/RadarEvaluator.swift`, roughly 150 lines of pure arithmetic, linked by **both** the
phone and the watch targets. A direct port of `IllnessEarlyWarning`'s day-signal, consecutive-day,
exercise-exclusion, severity and confidence logic, taking `[RadarLine]` plus per-day readings
instead of `[HealthMetric: MetricTimeSeries]`. It imports nothing beyond Foundation, which satisfies
the constraint stated at `WatchShared/WatchBridge.swift:7-8` (*"This file must stay free of UIKit,
WidgetKit, HealthKit and Firebase because the watch targets link none of them"*).
`IllnessEarlyWarning` then calls into it, so there is exactly one copy of the thresholds.

### 14e. Native HealthKit on the wrist — the largest build cost, and it is not specific to this concept

The watch target links **no HealthKit at all** today. Confirmed: `project.yml:242-252` lists
`LasoWatch` sources file by file (`LasoWatch`, `WatchShared`, `Core/Extensions/Date+Extensions.swift`
and nothing else); `LasoWatch/LasoWatch.entitlements` contains exactly one key, an App Group;
`LasoWatch/Info.plist` has no `NSHealthShareUsageDescription`.

Required:
- `com.apple.developer.healthkit` on the watch app **and on the widget extension** — the extension
  entitlement is not optional, because `RelevantContext.sleep` needs the matching permission on both
  (R12).
- `NSHealthShareUsageDescription` in `LasoWatch/Info.plist`, or the authorization call traps.
- HealthKit in the target's link phase, mirroring what the `Laso` target already does at
  `project.yml:161-166`.
- One new `@Observable @MainActor` store, `LasoWatch/WatchHealthStore.swift`, following the existing
  `WatchStore` pattern. **Do not port `HealthKitManager`** — it is built around 72 metrics, a
  registry, SwiftData persistence, thermal gating and ML orchestration, none of which belongs on the
  wrist. This concept needs six latest-sample / statistics queries and no streaming query at all.

### 14f. New phone-side work — including the one item that is not optional

1. **Expose the sub-threshold tier.** `IllnessEarlyWarning.evaluate()` returns `[]` when
   `daysElevated < 2` (line 76). The signalling-metric set at day 1 must be *returned* rather than
   discarded. **Without this, Alex's state does not exist and the prototype's default screen is
   unbuildable.**
2. **Make `signalThresholdSigma` user-settable.** It is `private static let = 1.0` today (line 57).
   Becomes an instance parameter, persisted, defaulted to 1.0 — **the default is the shipping
   constant, so no new clinical threshold is introduced.**
3. **The delta gate.** The 3-night versus prior-4-night comparison for N1 does not exist anywhere in
   the codebase. `IllnessEarlyWarning` fires purely on absolute σ deviation today. **This is the
   single largest new piece of phone work and the entire anti-anxiety argument rests on it.** If it
   is cut, the concept degrades into the exact Athlytic absolute-threshold alert that drew the
   anxiety complaint, and should not ship.
4. **False-positive store.** Persist "Doesn't match" rejections and apply a +0.2σ line lift for 14
   days on the involved signals.
5. **Fix the push path — non-negotiable prerequisite.** `PhoneWatchSession.push()` is called from
   exactly one place, `DashboardViewModel.writeWidgetSnapshots()` (`DashboardViewModel.swift:2265`),
   reached only from foreground paths (`:766`, `:829`). `BackgroundRefreshCoordinator`
   (`App/BackgroundRefreshCoordinator.swift:114-140`) computes a fresh score in a `BGAppRefreshTask`,
   writes it for the **iOS widget**, and never calls `push`. **Result: the iPhone widget updates in
   the background and the watch does not.** Without this the 60-day lines never reach the wrist
   unless the user opens the phone, and the concept's entire promise fails on day one. It is a
   handful of lines and it is the highest-leverage fix in the whole redesign.

### 14g. Honest build-cost summary

| Bucket | Size | Risk |
|---|---|---|
| Watch HealthKit enablement (entitlements, plist, link phase, one store) | Medium | Shared with every concept in the set; the review burden is App Store health-data justification, not code |
| `RadarEvaluator` port + payload fields + 2 commands | Small | Pure arithmetic, testable off-device |
| Payload versioning | Small–medium | Already flagged in `03-ARCHITECTURE.md` §4 as needed regardless |
| Sub-threshold tier + user-settable sigma | Small | Touches shipping clinical code — needs a test that the default path is byte-identical to today |
| **The delta gate** | **Medium–large, new** | **The concept's load-bearing new logic. No existing code to lean on** |
| `BackgroundRefreshCoordinator.push()` | Trivial | Should ship regardless of which concept wins |

Nothing here is impossible. The delta gate is the only genuinely new algorithm, and it is the one
that must not be descoped.

---

## 15. Honest drawbacks, and who this design fails

**1. 0.12 app opens per day.** Stated in §13. If app engagement is the goal, stop here.

**2. The complication is close to static within a day, which is the failure mode Apple names by
name.** Overnight vitals settle at wake and do not move again until the next morning. Live HR is the
only intra-day element, and a heart rate with no judgement attached is thin dynamism. Mechanic 1 is
unambiguous that checking habits require *dynamic* content
(https://link.springer.com/article/10.1007/s00779-011-0412-2), and R14 warns that a static
complication is less likely to keep a prominent slot. Concept 01 (Body Battery) beats this concept
outright on that axis and I would not argue otherwise.

**3. The strongest argument against the whole concept:** *a sentinel that is right four times a year
is indistinguishable, to the user, from a sentinel that is broken.* There is no proof of function on
a silent day. The margin bars are a partial answer — they show the guard rails moving — but they are
a second-order signal most users will never learn to read. The 8-day retention cliff (>50% of
health-app users discontinue in week 1, https://arxiv.org/pdf/1910.01165) hits this concept hardest
of the ten, because in the first week there is by definition nothing to report *and* a 14-night cold
start on top of that.

**4. Apple already ships most of this, for free, deeply integrated.** High/low/irregular heart-rate
notifications, and Vitals on watchOS 11+, do multi-metric overnight outlier detection against a
personal typical range and surface it on the wrist without a third-party app. *(This is my
assessment, not from the research files — the research set contains no Apple Vitals coverage, so
treat it as unverified.)* Health Radar's differentiators reduce to the user-set threshold, the
false-positive feedback loop and the 60-day baseline window. That is a narrower moat than any other
concept in the set.

**5. Sensitivity tuning is a settings screen almost nobody will visit.** Training Today's delta model
works partly because their users are self-selected endurance athletes who tune things. A general
Laso user will run at the default forever, which means the default *is* the product and the crown
dial is decoration for ~95% of users. It stays because the other 5% are the ones who would otherwise
uninstall after a false positive.

**6. The false-positive action is asked for at the worst possible moment.** "Doesn't match" is
offered on the morning of day 2 of an episode — which, if it is a real illness, is exactly the
morning the user does not yet know they are ill and will dismiss it. The mechanism systematically
collects rejections from true positives, which then lifts the lines by 0.2σ and makes the *next*
true positive later. That is a real feedback pathology and I do not have a clean fix for it.

**7. Two of the five signals will produce mundane false positives the design does not handle.**
Sleep duration and steps both drop hard on travel days, holidays and desk-bound weeks. The
"watch not worn" empty state covers one cause; nothing covers a long-haul flight. The
exercise-recovery exclusion (`exerciseRecoveryMultiplier = 1.5` on active calories) handles hard
training and nothing else.

**8. Background execution is not guaranteed, and the wake check can silently not happen.** R9:
delivery is *"completely up to the system"* and is explicitly throttled *"when the user is performing
high-priority activities, such as exercising"*. A sentinel that sometimes does not run is a trust
problem of a different class from a score that is slightly stale. The fallback — state corrects on
the next WidgetKit reload or app open — is correct but invisible.

**9. Page 2 breaks the 4-line budget** (five legend labels) and fails the 5-second test at 7–10
seconds. I have argued it is a chart and reached for Apple's `accessoryRectangular` precedent, and I
still think that argument is only about 70% honest. If a reviewer rejects it, the fix is to cut page
2 to the two closest signals plus a "3 more inside" line — which is exactly what the AX1 layout
already does, and that layout is arguably the one that should ship at every size.

### Who this design fails

- **Anyone who wants a daily verdict.** 93% of the time the answer is "nothing to report", which is
  correct and useless to someone asking "how am I today".
- **The health-anxious user.** The concept was designed against anti-pattern 3 and it still fails
  this person, in the opposite direction: five bars creeping toward five lines is a monitoring
  device, and giving an anxious person a live proximity readout to five thresholds is not a
  kindness. `Watching` being silent helps; page 2 existing does not.
- **New users in week 1.** 14 nights of cold start against a >50% week-1 churn rate. This concept has
  the worst day-1-to-day-8 story of the ten.
- **Anyone training hard.** Elevated RHR and depressed HRV after a hard session are normal recovery.
  The shipping exclusion is a blunt heuristic on active calories; this population will see flags they
  can already explain, which is the fastest possible route to the complication being removed — and
  §7 says that removal kills the concept outright.

---

## 16. The 5-second test, every screen, failures shown

Median smartwatch session is **exactly 5.0 seconds**, at a mean 28cm and ~50° off-axis
(https://www.kostakos.org/papers/chi17.pdf ·
https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf).
"Pass" means a decision without reading a sentence.

| Surface | Verdict | Why |
|---|---|---|
| **`accessoryCircular`** | **PASS** (~0.5s) | One glyph shape. Check vs diamond vs triangle is pre-attentive at 28cm |
| **`accessoryInline`** | **PASS** (~1.5s) | Glyph first, then five words. Reads as language |
| **`accessoryRectangular`** | **PASS for state (~1s), FAIL for all five margins (~4s+)** | The title line delivers the verdict fast. Reading *which* of five bars crosses its tick is a 3–5 bar comparison at 159–285 ms each plus saccades — right at the budget, not inside it |
| **Smart Stack widget** | **PASS** (~2s) | Title + two named signals with deltas. The named rows are what make it faster than the rectangular complication |
| **Notification short look** | **PASS** (~2s) | One sentence, no numbers |
| **Notification long look** | **PASS on state (~1.5s), FAIL on full evidence (~6s)** | The headline lands instantly; two numeric rows plus a confidence bar do not. Acceptable — a long look is a lean-in surface by definition and only appears when the wrist is already raised and held |
| **Screen 1, Status** | **PASS** (~1.5s) | Glyph + coloured word + two names. A user can decide "nothing to do" without reading a single digit |
| **Screen 2, Signals** | **FAIL** (~7–10s) | Five names, five values, five deltas, five bars. This screen cannot be glanced and is not meant to be — it is reached by a deliberate crown turn when the user has already decided to look. **Stated as a failure, not excused.** It is also the screen that breaks the 4-prose-line budget, which is the same failure seen from a different angle |
| **Screen 3, Sensitivity** | **FAIL** (~8s+) | A settings screen with a live dial. Used twice in a user's lifetime. Failing the glance test is the correct outcome for a screen that should never be glanced |
| **Always-On, page 1** | **PASS at ~0.5s, and it passes by conveying nothing** | The only information available is "Radar, checked 07:04". That is R7 working exactly as intended, not a design failure |
| **Cold start** | **PASS** (~3s) | "Learning your lines · Radar needs 14 nights. 6 done." plus a progress bar |
| **Empty (watch not worn)** | **PASS** (~2.5s) | "No night to read" is the decision. The two live figures underneath are the consolation, not the headline |
| **Error, Health denied** | **PASS** (~3s) | "Radar can't read" plus one settings path. Fails loudly |

**Score: 8 pass, 2 fail, 2 partial.** Both failures are deliberate lean-in surfaces. The partial on
`accessoryRectangular` is the one I would fix first if the concept survives review — probably by
cutting the widget and complication bar count from five to the two closest.

---

## Accessibility notes

**VoiceOver reading order, page 1:** glyph and state word combined into one `.isHeader` element
("Radar. Watching. Two signals outside their usual range."), then each signal row combined with its
bar ("Resting heart rate 58 beats per minute. 3 above your usual 55. Outside the line."), then the
meta line, then **the freshness dot last** despite sitting top-right, then the button. Page 3's
hero is `.adjustable` with a 0.1 increment, and VoiceOver announces the new value **and** the new
count on every step. The five mini bars on page 3 are `.accessibilityHidden(true)` — they restate
the count line, and reading them twice is noise.

**Meaning without colour (R18):** four channels per verdict, three of them non-colour — the word
("All clear" / "Watching" / "Flagged"), the glyph shape (check in a circle / hollow diamond / filled
notched triangle), the bar position relative to the tick (short of it / crossing it / crossing it
drawn solid), and colour fourth. Per-signal direction is a **▲ / ▼ / –** glyph in every chip.

**Tap targets:** every control is a full-width row, 44 × 44pt minimum — the watchOS default, not the
28pt floor. There are exactly three tappable elements in the whole app, one per page. No row on page
2 is tappable by design, which removes the entire class of sub-44pt list-row targets that the
shipping check-in screen demonstrates (5 targets at ~30 × 25pt in a 162pt row,
`01-CURRENT-APP-CRITIQUE.md` §3.2.1).

**Dynamic Type:** at xxLarge, page 1 drops the meta line, page 2's pitch grows to 40pt and drops the
caption, page 3's hero shrinks to `title` 22pt. At **AX1 and above**, page 2 shows only the signals
that are outside their lines (2 for Alex) plus one line "3 more inside" — which, per §15 drawback 9,
is arguably the layout that should ship at every size. No text is rasterised.

**Reduce Motion:** kills the count-up on the hero number and the 600ms bar sweep; opacity crossfades
stay. The crown detent visual on page 3 is a direct value binding, not an animation, and is
unaffected.

---

## Prototype notes for the reviewer

- **Screen switcher** is the left rail: watch face → Smart Stack → four notification looks → app
  launch → the three app pages → a state index.
- **Crown** is the mouse wheel over the watch, or ↑ / ↓. What it is bound to right now is printed
  beside the crown, and the 11-position detent strip lights up on page 3. `.click` fires per detent.
- **Double Tap**: the dev toolbar button, or the `D` key. On the long look it takes the first
  non-destructive action; in-app it advances the vertical tab.
- **Dev toolbar** (bottom right): 46mm / 40mm, seven states, Always-On, the three radar states, a
  phone-answers switch that drives the button's failure path, and a colour-token strip showing
  `poor` struck out as unused.
- **The three radar states are reached honestly.** "Clear" sets the sensitivity dial to 1.4σ, which
  is Alex's own night read against a wider line — 0 of 5 outside. No hypothetical health figures are
  introduced anywhere in the prototype.
- **The banned phone-redirect string exists in no state and on no code path.** Verified by grep.
