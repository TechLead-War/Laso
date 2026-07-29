# Concept 01 — Body Battery (`energy`)

Rationale for `01-energy.html`. watchOS · dark only · design target 46 mm (208 × 248 pt), floor 40 mm (162 × 197 pt).
Every citation below is a URL that appears verbatim in `research/`. Nothing is invented.
Every number on every surface is recomputed by the prototype from the model in §12 of the design spec — none of it is typed into the markup.

---

## 1. One-sentence philosophy

Your body is a battery: the phone decides how much you woke up with, and the wrist watches you spend it.

---

## 2. The question it answers first, and why that one

**How much have I got left right now?**

The shipping Watch app answers "what was my readiness score when my phone last opened?" — a question that has one answer per day, arrives late, and cannot drive an afternoon decision. Three things pushed the question to this one instead:

1. **A static number cannot sustain a glance.** A checking habit is "brief, repetitive inspection of **dynamic** content quickly accessible on the device", and the field experiment behind that definition found that adding real-time information to a previously static screen *caused* checking to emerge (**strong: peer-reviewed** — https://link.springer.com/article/10.1007/s00779-011-0412-2). Apple says the same thing from the platform side: "a static complication that doesn't display meaningful data may be less likely to remain in a prominent position on the watch face" (**strong: first-party** — https://developer.apple.com/design/human-interface-guidelines/widgets).
2. **The wrist can actually answer it without the phone.** Every input to the drain half — awake time from `sleepAnalysis`, active energy, heart rate, steps, mindful minutes — is native on watchOS. Only the ceiling needs the phone.
3. **The metaphor is already installed.** A phone battery already means "fills overnight, drains with use, plan your day around it" (**medium/weak: vendor + reviewer** — https://the5krunner.com/garmin-features/sleep/body-battery/). No teaching screen is needed.

The one decision each screen enables:

| Screen | Decision |
|---|---|
| Now | Do I have enough left for the thing I was about to do? |
| Spend | Was today's spend worth it, or should I stop now? |
| Tonight | Recharge now, or ride it out? |
| Recharge | How long am I willing to sit still? |

---

## 3. Screen-by-screen reasoning, element by element

### Screen 1 — NOW (page 1 of 3, the launch screen)

| Element | Why it is there, and why in that form |
|---|---|
| Hero `48`, 52 pt / 600, `textPrimary`, left-aligned | The answer, in one glyph pair. **Deliberately not band-coloured**: the bar fill is roughly 2 600 pt² of colour against a 52 pt digit, so colour is already carried pre-attentively by the largest area on screen, and the digit is freed to be maximally legible at the measured viewing geometry — 28 cm, ~50° pitch, ~10° off line-of-sight (**strong: peer-reviewed** — https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf) |
| `Moderate · live` | Never ship a bare number. Every studied product pairs the value with words (**strong/medium** — https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html · https://support.google.com/fitbit/answer/14236710?hl=en). The freshness word is the second half of the same 20 pt row because a watch value without its age is a lie waiting to happen |
| **Battery bar**, full content width, 14 pt, pill | The hero gauge. Bars read a comparison in 159–285 ms; a radial bar takes 1 548–1 772 ms — 6–10× the cost against a 5.0 s median session (**strong** — https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf · https://www.kostakos.org/papers/chi17.pdf). The 3 × 6 pt terminal nub carries no data; it is there purely so the shape reads as "battery" before the eye reaches the word |
| **Ceiling tick** at `0.62 × width`, `textSecondary` | This is the whole architectural idea rendered as one glyph. The phone's frozen verdict is the *geometry*; the wrist's live number is the *fill*; the distance between them is the spend. Deliberately neutral-coloured so it never reads as a second verdict |
| 16-bar, 8-hour sparkline | Show a slope, not just a level — Garmin's own glance is "your current Body Battery level **and a graph** … for the last several hours" (**medium: vendor** — https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html). Off-wrist buckets render as 3 × 4 pt **stubs**, never an interpolation: the hole is the honest rendering |
| `−2/hr · 38 at bedtime` | Direction and consequence in 13 pt. The minus sign carries direction without colour (R18) |

Text lines: **3**. The `62` under the tick is a gauge axis label, not a sentence.

**40 mm degradation order:** sparkline → footnote → tick label. The prototype drops the sparkline at 40 mm and keeps bar, tick and footnote, which fits in 159 pt of the ~168 pt usable. The bar and tick are never dropped, because without them the screen is the shipping app again.

### Screen 2 — SPEND (page 2 of 3)

Three rows, each `label · bar · signed value`, plus a title and a footnote. This screen exists because a battery that drains without saying what drained it **is** anti-pattern #4: "the scores are a black box … the app doesn't show which inputs drove the number" (**medium: reviewer** — https://www.autonomous.ai/ourblog/bevel-app-review).

The raw input is shown *as the label* (`Moving 284kc`), and the model's output is shown as the value (`−6`), so the arithmetic is inspectable without a second screen. Progressive disclosure of "why" is Garmin's shape too: level at 0 presses, factor list at 3 (**medium: vendor** — https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html).

**The honest note on the line budget:** the tokens allow 4 lines of text per screen. This screen has 2 body lines plus a 3-row labelled bar chart, which under a strict reading is 5 text elements. It is the tightest screen in the concept and it is a deliberate trade against shipping an unexplained number. If a builder must cut one, cut row C and fold rest into the title (`Spent 14 net`).

The rows always sum to the title. All three dev-toolbar scenarios were checked for that: 9 + 6 − 1 = 14, 11 + 11 − 1 = 21, 2 + 1 − 0 = 3.

### Screen 3 — TONIGHT (page 3 of 3)

| Element | Why |
|---|---|
| `38 at bedtime`, the number in `poor` | Turns a level into a consequence. This is where the goal gradient lives: a visible, shrinking distance to a threshold (**strong** — https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf) |
| Forecast band, 12 pt, with a `poor` tick at the 45 crossing | The tokens' prescribed encoding for "position inside a range": a horizontal band with a marker. Never a second ring |
| `Doing nothing: Low by 17:00` | States its own assumption. A prediction that hides its assumption is the thing that destroys trust (**medium/weak** — https://www.dcrainmaker.com/2021/11/whoop-platform-review.html) |
| One action row, `Recharge 5 min` `+2` | One action per verdict screen, and it is the obvious next step — Gentler Streak's verdict → prescription path and Garmin's stress-glance → Breathwork in one press (**medium: vendor** — https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface · https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-DD8EE575-CC72-4829-B4C8-4BE1F8D3473E.html). **The `+2` is not decoration** — the button states the size of its own effect, from the same published constant as the charge |

### Screen 4 — RECHARGE (pushed leaf, depth 2)

Crown-driven duration `3 / 5 / 10 / 20`, a live `+N charge` projection, one Start button. On completion it writes an `HKCategoryTypeIdentifier.mindfulSession` sample for the **real elapsed** duration, recomputes the charge, and pops back to Tonight with the new number already on screen — the prototype does exactly this, and `48 → 50` with `38 → 40` at bedtime.

This screen exists for one reason only: Apple's Mindfulness app cannot show a Laso charge climbing. Everything else about breathing is deferred to the platform.

**No haptic fires during the session.** The session samples heart rate, and "when you engage the haptic engine, HealthKit stops gathering heart rate data until after the haptic engine finishes" (**strong: first-party** — https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)). That is also why there is no per-breath pacing haptic anywhere in the concept.

Extended runtime registers the **Mindfulness** session type (1 h cap). One type per app, and this is it (https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions).

---

## 4. Why this works on a watch specifically — what would be worse on a phone

- **The value is only interesting because it is on the wrist.** A drain gauge you must unlock a phone to see is a report. On a face slot it is a resource meter you consult mid-decision, which is what makes the goal gradient bite.
- **The inputs are wrist inputs.** Awake time, active energy, heart rate, steps, stillness. On the phone every one of those is a mirror of the watch's own sensors, arriving later.
- **The 5-second budget forced the design to be good.** Median smartwatch session is 5.0 s across 142.1 sessions/day (**strong** — https://www.kostakos.org/papers/chi17.pdf). That budget is what killed the second ring, the stress score, the sleep-debt line and the quick-log list. On a phone the same concept would have grown a dashboard and become Bevel, whose watch app a reviewer scoped to things "the phone app can" already do (**medium: reviewer** — https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html).
- **What would be genuinely better on the phone:** the 28-day usual-spend curve, the ceiling model, and any explanation longer than three rows. All three stay on the phone.

---

## 5. watchOS HIG guidance applied

| Applied where | Guidance | URL |
|---|---|---|
| 3 vertical pages, no scrolling detail views | "Use vertical pagination to separate multiple views into distinct, purposeful pages… In watchOS, this design is more effective than horizontal pagination or many levels of hierarchical navigation." | https://developer.apple.com/design/human-interface-guidelines/page-controls |
| Max depth 2, one leaf | "Minimize the depth of hierarchy in your app's navigation, and use the Digital Crown to provide vertical navigation." | https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos |
| Every page is one screen height and none of them scroll — which is why the 4-line budget is enforced per page | "If your detail views scroll, people won't be able to use vertical page-based navigation to swipe among them." | https://developer.apple.com/design/human-interface-guidelines/tab-views |
| Double Tap bound only on Recharge, never on a tab page | "Avoid setting a primary action in views with lists, scroll views, or vertical tabs." | https://developer.apple.com/design/human-interface-guidelines/gestures · https://developer.apple.com/documentation/swiftui/view/handgestureshortcut(_:isenabled:) |
| Crown pages the tabs; crown drives the Recharge value; crown **presses** are not handled | "Anchor your app's navigation to the Digital Crown." "In contexts where the Digital Crown doesn't need to navigate through lists or between pages, it's a great tool to inspect data in your app." | https://developer.apple.com/design/human-interface-guidelines/digital-crown |
| Loading shows the cached charge dimmed, never a spinner | "Avoid displaying an indeterminate progress indicator… reassure people that they'll receive a notification when the process completes." | https://developer.apple.com/design/human-interface-guidelines/feedback |
| Three complications, three different deep links | "Define a different deep link for each complication you support… If all the complications you support open the same area in your app, they can seem less useful." | https://developer.apple.com/design/human-interface-guidelines/widgets |
| `accessoryRectangular` is a chart, not a ring | Apple's exemplar for the family is a 24-hour heart-rate graph | https://developer.apple.com/design/human-interface-guidelines/complications |
| Always-On genuinely redacts | "always hide any highly sensitive information, such as financial information or health data" | https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state |
| N1's title carries no number | "Avoid including potentially sensitive information in the notification's title"; "Avoid using a short look as the only way to communicate important information" | https://developer.apple.com/design/human-interface-guidelines/notifications |
| The complication is the product, the app is the detail view | People "may never explicitly launch your app" | https://developer.apple.com/documentation/watchos-apps |
| Timeline precomputed 4 h ahead at 15-min spacing; freshness published in-product | "Widgets don't support continuous, real-time updates" | https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date |
| N2 rides `WKApplicationRefreshBackgroundTask` and is never used for anything time-critical | Delivery is "completely up to the system"; the system throttles "when the user is performing high-priority activities, such as exercising" | https://developer.apple.com/documentation/watchkit/wkapplicationrefreshbackgroundtask |
| Both tap targets are full-width × 44 pt | 44 × 44 pt default, 28 × 28 pt minimum | https://developer.apple.com/design/human-interface-guidelines/accessibility |
| Sparkline and forecast band get a one-sentence VoiceOver value string | "a concise description of each infographic that explains what it conveys" | https://developer.apple.com/design/human-interface-guidelines/voiceover |

---

## 6. UX principles used, and the mechanism

| Principle | Mechanism in this concept |
|---|---|
| **One scale, one band vocabulary** | A single 0–100 scale with one threshold table (`≥67 Optimal / 45–66 Moderate / <45 Low`), reused by the charge, the ceiling and the forecast. Oura's structural advantage; WHOOP's three incompatible scales are the anti-case (**medium: vendor** — https://support.ouraring.com/hc/en-us/articles/360025589793-Readiness-Score) |
| **Never a bare number** | `48` never appears without the band word, a slope and a bar. On the inline complication it never appears without the battery glyph's own fill level |
| **Imperative, not description** | `Front-load the hard work before 13:00`, `Low by 17:00`, `Recharge 5 min +2`. The most consistent criticism across the whole competitive set is guidance, not data (**medium: reviewer** — https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html · https://ibikerun.substack.com/p/athlytic-app-review-iosapple-watch) |
| **Separate the frozen verdict from the live feed** | Athlytic's two-named-products answer, resolved here as *one* glyph: tick vs fill, one scale, zero extra screen elements (**medium: vendor** — https://www.athlyticapp.com/getting-started) |
| **Publish the staleness rule in-product** | The Spend footnote gains `· updates 4x/hr` whenever the payload is over 15 minutes old. Athlytic does this and pre-empts the ticket; Bevel does not and has a live public bug thread about watch values being 1–5 points off (**medium: vendor** — https://athlytic.github.io/athlyticapp/troubleshooting/ · https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match) |
| **Name the cold start, never fabricate** | `Ceiling needs 3 more nights of sleep.` Garmin ships "No Status"; Fitbit states 7 nights (**medium: vendor** — https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-6F81BF5B-B49A-4506-95E2-0F4A04D8B319.html · https://support.google.com/fitbit/answer/14236710?hl=en) |
| **Floor at 5, not 0** | Garmin's published range is 5–100 (**medium: vendor** — https://www8.garmin.com/manuals/webhelp/GUID-5D183A14-BB43-4A9B-B441-5F824214CE40/EN-US/GUID-87E1392B-2C55-40B7-A1FF-3AB9252DA0A0.html). A battery that reads empty tells a living person they are dead |
| **Trust before precision** | The ceiling is a hard cap — you cannot out-rest your recovery, and the wrist can never display a number the phone's verdict does not permit. A score that contradicts felt state is worse than no score (**medium/weak** — https://www.dcrainmaker.com/2021/11/whoop-platform-review.html) |
| **Tiny colour system, never load-bearing alone** | Four colours: `optimal`, `fair`, `poor`, plus a neutral tick. In a monochrome or inverted rendering the fill length, the band word, the sign on `−2/hr` and the battery glyph's fill level all still carry it (**strong/medium** — https://developer.apple.com/design/human-interface-guidelines/widgets · https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path) |

---

## 7. Psychological principles that drive repeat opens

| Rank | Mechanic | Evidence strength | Use here |
|---|---|---|---|
| **#1** | Dynamic content at near-zero access cost | **strong: peer-reviewed** — https://link.springer.com/article/10.1007/s00779-011-0412-2 · https://www.kostakos.org/papers/chi17.pdf | The complication moves ~2 points an hour, every hour, inside the ~4 reloads/hour cap. The precomputed awake-drain timeline is what makes that possible with no background execution |
| **#2** | Surviving the first 8 days (>50 % churn in week 1; the day-8 cohort gains +25 days median retention) | **strong: peer-reviewed** — https://arxiv.org/pdf/1910.01165 | The drain half is 100 % wrist-native, so day 1 shows a real `Spent 14`, not an empty screen. The ceiling's absence is named with a countdown |
| **#3** | Goal gradient — visible shrinking distance, 20 % acceleration near a goal, **effort resets once the reward is earned** | **strong: peer-reviewed** — https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf | The bar is a continuously shrinking distance; Tonight makes it explicit; Recharge states its own effect size. The reset failure mode is handled by the ceiling recomputing every morning — the user is never left at "done" with nothing next |
| **#4** | Bar/donut over radial | **strong: peer-reviewed** — https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf | Hero is a bar; sparkline is bars; the only ring in the product is `accessoryCircular`, where the family leaves no choice |
| **#5** | Uncertainty — anticipatory dopamine, maximal at P = 0.5 | **strong (mechanism), inferred (application)** — https://pubmed.ncbi.nlm.nih.gov/12649484/ | The charge since your last glance genuinely depends on what you did. **No fake variance is manufactured** — every point traces to a published constant times a real HealthKit value |
| **#6** | Push the verdict at wake | **medium: vendor** — https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-4D26FDDC-63BD-4910-95B8-98937FEC2545.html | N1 plus `RelevantContext.sleep(.wakeup)` |
| **#7** | Delta-triggered notifications — 3.5× next-hour lift, 1.04–1.3× over 24 h, **no measurable long-term retention effect** | **strong: peer-reviewed** — https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf · https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/ | Two pushes total, budgeted as *moments*, never as a growth lever |
| **#9** | Resumption (Ovsiankina), **not** Zeigarnik | **mixed — one half is dead** — https://www.nature.com/articles/s41599-025-05000-w | The unspent gap between fill and tick is a resumption cue on a surface the user already sees. It is explicitly **not** justified as "memorable" — the 2025 meta-analysis kills that |

**Not used:** streaks (#8). A streak rewards *wearing and opening*, not *recovering*, and this product's accumulated progress is a health state the user does not fully control. Gentler Streak ships manual "On a Break / Sick / Injured" states specifically so people can stop without penalty.

**The honest caveat, stated once:** the central claim behind this whole concept — that a depleting gauge drives more checking than a static score — has **no direct empirical test** anywhere in the research set. It is an inference assembled from three peer-reviewed results. Treat it as well reasoned, not measured. That is also precisely why this concept is worth prototyping: it is the one that runs the experiment.

---

## 8. Complication strategy

**Three families. Not four.**

| Family | Content | Deep link | Why give up a face slot |
|---|---|---|---|
| `accessoryCircular` | `Gauge(value:in:)` with `.accessoryCircularCapacity`, `48` at 14.5 pt in the centre, ring tinted by band, `widgetLabel { Text("−2/hr") }` for the Infograph bezel | `laso://watch/energy` → **Now** | Because the number is different almost every time you look at it. The readiness score it replaces moved **once, at 07:04, then sat there for 17 hours** |
| `accessoryRectangular` | `48 Moderate` / battery bar with the ceiling tick / 16-bar sparkline + `−2/hr` | `laso://watch/energy/spend` → **Spend** | Because it is the only complication on the face that shows the *shape* of the day rather than a point on it. Apple's cited exemplar for this family is a 24-hour heart-rate graph |
| `accessoryInline` | `Label("48 · falling", systemImage:)`, symbol chosen **by band**: `battery.75percent` / `battery.50percent` / `battery.25percent` | `laso://watch/energy/tonight` → **Tonight** | Because it costs the least face real estate of any family and still carries a **word**, which a ring cannot say |

Three families, three genuinely different destinations, per https://developer.apple.com/design/human-interface-guidelines/widgets.

**`accessoryCorner` is deliberately omitted.** At 21 × 21 pt of gauge plus 10.5–12 pt of text it can only restate what circular already says, and R15 would then force a fourth invented destination. Inventing a screen to justify a family is how face slots get wasted.

**The inline symbol is the concept's cleanest colour-independence answer:** the battery glyph's own fill level restates the band as *shape*, so it survives accented mode and colour inversion with zero loss of meaning.

**Circular omits the ceiling tick, stated rather than hidden.** `Gauge` has no marker API, and faking one inside a 32 pt closed gauge produces a sub-2 pt artefact, below the HIG line-width floor. The ceiling lives on rectangular and in the app.

**The counter-argument, stated:** all three are decoration if the user does not believe the drain model, and they compete against Activity rings and weather, both of which the user already trusts more. See §15.

---

## 9. Smart Stack strategy

**One widget, `accessoryRectangular` only.** Only rectangular and circular reach the Smart Stack at all (https://developer.apple.com/design/human-interface-guidelines/widgets). Circular is not shipped there: the stack's whole value is that a widget can say more than a face slot, and a circular widget in the stack says exactly what the circular complication already says one crown-turn away.

Laid out at the published 40 mm floor of 152 × 69.5 pt and scaled up: row 1 `48 Moderate` + trailing `live`; row 2 the battery bar with the ceiling tick; row 3 `−2/hr · 38 at bedtime`. 62 pt of 69.5. One tap target, the whole widget, → `laso://watch/energy`.

**Background** is black by default. Apple asks for "a colorful background that conveys meaning" on watchOS Smart Stack widgets; this widget uses `poor` at **12 % opacity** in exactly one condition — charge below 45 **before 18:00**, i.e. earlier than this user's own normal. Colour amplifies a state the words already state. (Visible in the prototype: dev toolbar → band **Low**, which is the same Tuesday at 16:20.)

**Relevance (R12), and the trap:**

- **Do not set `TimelineEntry.relevance`.** It does nothing on watchOS — dead code (https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks).
- Implement `TimelineProvider.relevance()` returning a `WidgetRelevance` built from `WidgetRelevanceAttribute`s (https://developer.apple.com/documentation/relevancekit/relevantcontext): `RelevantContext.sleep(.wakeup)` (the ceiling has just been set — highest-intent moment of the day), `.sleep(.bedtime)` (the projection is now the payload), `.fitness(_:)` (post-workout, the largest single move the number makes all day), and `.date(interval:kind:)` for **15:00–16:00 local** (the afternoon trough, where the projection first becomes decision-relevant).
- **The clues are gated by permissions:** the sleep clues need `sleepAnalysis` authorisation on **both the app and the widget extension**. If either is missing, the clue silently does nothing.
- **Do not use `RelevanceConfiguration`** even when the deployment target allows it: its documented trade-off is that people "can't configure widgets that use a `RelevanceConfiguration`… add them to the Smart Stack, or pin them to a fixed location". A pinnable widget is worth more here than four simultaneous ones.

---

## 10. Notification strategy

**Two, ever. Both individually toggleable. Neither is a "your battery is low" alarm.**

### N1 — Charged (wake)

- Fired by the **iPhone**, once, when the new ceiling is computed after a detected wake. It cannot fire without the phone, because the ceiling is phone-computed — no pretence otherwise.
- Within 10 min of wake (Alex: ~07:06). Exactly once per day, suppressed entirely on a cold-start ceiling.
- Short look, title only: `Today's charge is ready` — **no number**, because a short look is visible to anyone standing near the wrist.
- Long look body: `62 to spend. 6 under your usual 68.` / `Front-load the hard work before 13:00.` The `13:00` is derived: it is the hour the projection under this ceiling first crosses 45 if the user hits their full Move goal.
- Actions: `See the day` (first nondestructive → the Double-Tap target), `Plan tonight`.

### N2 — Draining faster than usual (delta)

- Fired by the **watch itself**, from a `WKApplicationRefreshBackgroundTask`, comparing today's cumulative spend against `usualSpendByHour` for the current hour. **Works with the phone in another room**, because the comparison curve is cached and the spend is wrist-native.
- Trigger: today's spend exceeds the user's own curve for this hour by more than a **user-set threshold, default 8 points**. This is Training Today's model exactly — notifications on change versus the previous four days, threshold user-set (**medium: vendor** — https://trainingtodayapp.helpscoutdocs.com/article/80-getting-started-with-training-today).
- Cadence ceiling: **max 1 per day**, never before 10:00, never within 4 h of N1, suppressed 24 h by `Mute today`. Expected frequency roughly **1 day in 4**.
- Actions: `Recharge 5 min` (first nondestructive → Double Tap), `See spend`, `Mute today`.

**Latency honesty:** N2 rides a background refresh, so it arrives **15–30 minutes after the crossing, or not at all**. That is acceptable precisely because it is a news alert, never a safety alert.

**There is deliberately no absolute-threshold alert.** Athlytic's absolute stress alerts drew an explicit reviewer demand for "a big friendly toggle to hush stress for a while" because they "increase anxiety rather than help" (**medium: reviewer** — https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/). A depleting battery would fire that alarm every single evening by design, which is the fastest possible route to the user turning Laso off.

**Neither push is justified as retention.** Across two MRTs, time to disengagement was not significantly different between notification policies (https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf). And 82.3 % of watch sessions are self-initiated while only 9.4 % of notifications yield any session (https://www.kostakos.org/papers/chi17.pdf) — so the complication is the product and the two pushes are the exception.

---

## 11. Haptic language

| Event | `WKHapticType` |
|---|---|
| Crown detent on the Recharge duration (pre-session only) | `.click` |
| Recharge session start | `.start` |
| Recharge session end, then mindful sample written | `.stop`, then `.success` at +100 ms minimum |
| `Mute today` applied | `.success` |
| Phone rejected a write (`WatchCommandRejection`) | `.failure` |
| N1 / N2 arriving | `.notification` (system-played) |
| Charge crosses **down** through 45 **before 18:00** | `.directionDown` |
| Charge crosses **up** through 45 after a recharge | `.directionUp` |

Hard rules obeyed:

- **No haptic fires while the Recharge screen is sampling heart rate.** This is why no breath-pacing haptic exists at all (https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)).
- **No background haptics** outside a workout session, so `.directionDown` fires only when the app is frontmost or via the notification path — never silently from a background refresh. The prototype models this: band-crossing haptics fire only on app screens.
- The `.directionDown` crossing is **gated by an 18:00 clock**. After 18:00 the crossing is routine, not news, and firing it daily is habituation.
- Minimum 100 ms between any two. All haptics individually disableable in settings.

---

## 12. What was deliberately excluded, and why

| Excluded | Why |
|---|---|
| Live BPM anywhere | Concept 03's job. Here it is a second live number competing with the charge, and a screen sampling HR cannot fire haptics, which would kill the crown detents |
| The readiness score as a headline | It is the ceiling, i.e. the geometry. Promoting it re-creates the shipping app's static-number problem |
| Stress, strain, sleep debt, vitality age, VO₂ max | All phone-only, and each is a fourth, fifth, sixth number on a 5-second screen. Oura's answer — demote the slow metrics to a place you visit rarely — is the right one |
| Streaks and any chain mechanic | A streak rewards wearing and opening, not recovering |
| The morning check-in | Different ritual, different concept. The wake moment here is owned by N1, at zero taps |
| The quick-log list | Logging with no visible running total is a write-only hole, and adding a total means a second scale on the wrist |
| Any workout screen or `HKWorkoutSession` | A workout drains the battery; the app does not need to run the workout |
| `accessoryCorner` | Duplicates circular at lower fidelity, and would need a fourth invented destination |
| A second ring anywhere | Two rings is a comparison rendered in the slowest encoding available |
| Any red-state alarm at any threshold | The battery reaches Low every evening by design. Alarming on it daily is habituation and anxiety with no decision attached |
| A breathing animation on Recharge | Apple owns Breathe. Recharge exists only to show the number climb |
| Colour as the only carrier of anything | watchOS may invert colours depending on the face |

---

## 13. Expected opens per day, with the mechanism for each

"Open" = the app comes to the foreground. Complication and widget glances are **not** opens, and this concept is designed so most of its value is consumed at zero opens.

| # | Trigger | Time | Mechanism | Opens/day |
|---|---|---|---|---|
| 1 | N1 long look — the ceiling arrives | ~07:06 | Pushed verdict at the highest-intent moment. Most users read the long look and drop the wrist | **0.6** |
| 2 | Mid-morning face glance — the number has moved 3–4 points since wake | ~10:00 | Checking habit on dynamic content. **Zero opens** — the complication is the whole interaction | 0.0 |
| 3 | Post-lunch check — the largest visible drop of the morning | ~13:30 | Uncertainty: the number cannot be predicted from memory | **0.3** |
| 4 | Post-exercise — the largest step change the number makes | after a workout | Curiosity about the cost, plus `RelevantContext.fitness` surfacing the widget. Alex trains ~3 days/week, so amortised | **0.2** |
| 5 | Afternoon trough — Smart Stack relevance window 15:00–16:00 | ~15:30 | Widget surfaces without a tap; some fraction drill into Spend | **0.2** |
| 6 | Commitment moment — train tonight or not | ~17:30 | Goal gradient: the distance to bedtime is now short enough to matter | **0.3** |
| 7 | Bedtime — `RelevantContext.sleep(.bedtime)` surfaces the widget | ~22:30 | The projection has become the actual | **0.2** |
| 8 | N2 delta alert — fires ~1 day in 4, ~50 % act | variable, ≥10:00 | Delta notification, 3.5× next-hour lift | **0.1** |

**Honest total: ~1.9 app opens per day**, of which 0.6 is the wake notification — so the genuinely self-initiated rate is **~1.3/day**.

**Complication glances (0 opens): 6–10 per day** out of the ~142 daily wrist sessions CHI 2017 measured. **This number has no supporting data.** The synthesis is explicit that no user-behaviour data exists for Body Battery — Garmin publishes population averages only, never view counts. Treat 6–10 as a design target, not a forecast.

**Do not inflate this.** A concept whose whole claim is "the complication is the product" should expect *low* app opens. If this design produced 6 app opens a day it would mean the complication had failed.

---

## 14. Buildability against this codebase

Read this session: `WatchShared/WatchBridge.swift`, `project.yml` (watch targets), `LasoWatch/LasoWatch.entitlements`, `Common/Components/DesignSystem.swift:185-201`, `Core/Data/PhoneWatchSession.swift:120`, `Core/Models/HealthScore.swift:44-61`.

### What exists today and can be used unchanged

| Need | Exists |
|---|---|
| Ceiling `62` | `WatchPayload.readinessScore` — already on the wire, already rendered |
| Band table `≥67 / 45–66 / <45` | `DesignSystem.recoveryTier`, `optimalFloor = 67`, `fairFloor = 45` (`Common/Components/DesignSystem.swift:189-200`). One threshold table, and this concept adds none |
| Complication reads with no connectivity session | `WatchBridge.watchAppGroup` + `WatchPayloadCache` already do exactly this |
| Stale detection | `WatchPayload.isStale(now:)` and `WatchBridge.stalePayloadInterval` (3 600 s) already exist |
| Write rejection path for the `.failure` haptic | `WatchCommandRejection` already models `earlierDay` / `notStored` / `notDelivered` |

### Three corrections to the design spec, found by reading the code

1. **`readinessGrade` is a letter grade, not a band word.** `PhoneWatchSession.swift:120` sends `readinessGrade: core?.grade ?? ""`, and `HealthScore.grade` returns `"A"`/`"B"`/… . The spec's claim that the Spend footnote "renders `readinessGrade`, currently dead on the wire" is wrong in one respect: rendering it verbatim would print `Ceiling 62 · B · set 07:04`. The prototype therefore derives the ceiling's band word from `DesignSystem.recoveryTier(for: readinessScore)`, which is the only correct source. **`readinessGrade` stays dead**, and should be deleted from the wire rather than resurrected.
2. **The watch targets are on `WATCHOS_DEPLOYMENT_TARGET: "10.0"`** (`project.yml`, both `LasoWatch` and `LasoWatchWidgets`). `TimelineProvider.relevance()` / `RelevantContext` need watchOS 11, and `RelevanceConfiguration` needs 26. So §9's relevance work is **blocked on raising the deployment target to 11.0**, or every clue must sit behind `if #available`. This is not in the design spec and it is the first thing that will bite a builder.
3. **`WatchBridge.stalePayloadInterval` is 60 minutes and is the wrong horizon for this concept.** A 2-day-old ceiling is still a usable geometry here (the spend half stays true), so the concept needs its own two-step ageing — `fresh / ceiling-set-at / days-old` — rather than the existing binary. The existing constant can stay for other consumers.

### New `WatchPayload` fields — 3

| Field | Why it cannot be derived on the wrist |
|---|---|
| `ceilingSetAt: Date` | `updatedAt` is *push* time, not *freeze* time. Conflating them makes the wrist lie about when the verdict was set |
| `bedtimeTargetLocal: Date` | Sleep need is phone-only (60–90 days of history) |
| `usualSpendByHour: [Int]` (24) | Needs 28 days of HealthKit, which the wrist's ~7-day store cannot reach |

All three fit inside the application-context size limit. `WatchPayload` is `Codable` with `let` members, so adding fields is a straight edit plus a decode-compat check for older cached payloads.

### Native HealthKit on the wrist — 7 reads, 1 write

`activeEnergyBurned`, `restingHeartRate`, `heartRate`, `stepCount`, `sleepAnalysis`, `mindfulSession`, `HKActivitySummary` (for `activeEnergyBurnedGoal`). Write: `mindfulSession`.

This is the single biggest change, because **the Watch app does not link HealthKit at all today**:

- `LasoWatch/LasoWatch.entitlements` contains exactly one key, an App Group. `com.apple.developer.healthkit` must be added.
- `LasoWatch/Info.plist` needs `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`.
- `project.yml` lists the watch sources file by file (`LasoWatch`, `WatchShared`, `Core/Extensions/Date+Extensions.swift`). A new `LasoWatch/Energy/` group and `HealthKit.framework` must be added there.
- **The widget extension needs HealthKit and `sleepAnalysis` read permission too**, or the Smart Stack sleep clues silently no-op.
- `WatchShared/WatchBridge.swift:7-8` states the wire format "must stay free of UIKit, WidgetKit, HealthKit and Firebase". **That comment stays true**: all HealthKit lives in `LasoWatch/Energy/`, never in `WatchShared/`.

### New phone-side work — 1 substantial item

The phone must run the **identical drain model** over 28 days of HealthKit to produce `usualSpendByHour`. If the phone's constants drift from the watch's, N2 fires wrongly. So `AWAKE_RATE`, `EXERTION_WEIGHT`, `STILL_STRESS_RATE`, `QUIET_RATE`, `MINDFUL_RATE`, the floor and the cap go into **`WatchShared/`** as one struct that both targets compile against. This is the largest single item of work in the concept, and it is a correctness requirement, not a nicety.

### The one-line bug this concept cannot ship without

`PhoneWatchSession.shared.push(` is called from **exactly one place** — `Modules/Dashboard/ViewModels/DashboardViewModel.swift:2265`, inside `writeWidgetSnapshots()`. `BackgroundRefreshCoordinator` updates the iOS widget and never pushes to the watch. **If the user does not open the iPhone app, the ceiling never updates.** Everything in §9 and §10 is decoration until `BackgroundRefreshCoordinator` also calls `PhoneWatchSession.push`.

### Existing payload fields this concept does not render — 6 of 10

`dayType`, `actionHeadline`, `actionDetail`, `actionIcon`, `actionDone`, `checkInAvailable`. Stated rather than papered over: this concept replaces the phone's recommended action with a wrist-native one and replaces the morning check-in with a wake notification. If those features survive in another concept the fields stay; if not, they should be deleted from the wire along with `readinessGrade`.

### Rough cost

| Item | Size |
|---|---|
| 3 payload fields + decode compat | small |
| Watch HealthKit target/entitlement/Info.plist wiring | small, but touches signing |
| `LasoWatch/Energy/` — model, App Group history buffer, off-wrist gap detection | medium |
| 3 complication families + 1 Smart Stack widget + timeline provider | medium |
| Shared constants struct + phone-side 28-day `usualSpendByHour` | **largest single item** |
| `BackgroundRefreshCoordinator` → `PhoneWatchSession.push` | one line |
| Deployment target 10.0 → 11.0 for relevance clues | small, but it is a support-matrix decision |

---

## 15. Honest drawbacks, and who this design fails

**1. The metaphor still breaks on the charger, and the fix is a bandage.** Holding and marking beats Garmin, whose Body Battery "resets if the watch is removed for several hours" (https://www.androidauthority.com/garmin-body-battery-1209128/). But a user who charges 90 minutes a day sees `paused` daily and gets a number biased high for that window. Someone who charges in two 2-hour blocks trips `est.` every day and the hero becomes an admitted estimate. **Mitigated, not solved.** There is no fully honest depleting gauge on a device that must be removed to charge.

**2. The drain model is invented and validated against nothing.** `AWAKE_RATE = 1.2`, `EXERTION_WEIGHT = 13`, `MINDFUL_RATE = 0.40` were chosen to produce a plausible daily arc, not fitted to any outcome. The5krunner's criticism of Garmin's applies verbatim — a battery "moves for too many reasons unrelated to exercise or readiness" and "measures nervous system state, not how you actually feel" (https://the5krunner.com/garmin-features/sleep/body-battery/). Mine measures calorie burn and elapsed wakefulness, which is arguably worse.

**The strongest argument against this entire concept:** readiness 62 is a modelled verdict from 60 days of data. **48 is 62 minus arithmetic on an activity-ring estimate.** The concept takes a soft signal and gives it hourly resolution and integer precision, which is exactly what "a score that contradicts felt state is worse than no score" warns against.

**3. It double-counts the Move ring.** `exertionDrain` is a linear function of active energy. A user who closes their Move ring gets 13 points drained regardless of how they feel, and the face already shows that same fact in a ring they trust more. Closing the ring *and* watching Laso punish you for it reads as contradictory.

**4. The Spend screen fails the 5-second test and there is no fix.** Explanation and glanceability are structurally opposed. Page 2 limits the damage; it does not remove it.

**5. Two numbers exist and users will conflate them.** "Why does my phone say 62 and my watch say 48?" is the exact Bevel bug thread (https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match), and this design **invites** it by construction. The tick-and-fill geometry is the best available answer, but it only works if the user looks at the bar. A user who reads only the digit sees two Laso numbers 14 points apart.

**6. The hero is anchored to a phone value that can go stale.** Two days without a push and the tick is two days old and the whole geometry is wrong, even though the spend half stays perfectly true. The stale state says so honestly, but "honestly wrong" is still wrong — and the fix lives outside the watch app entirely (§14).

### Who this design fails

- **Shift workers and anyone with an irregular wake time.** The model is anchored to a wake event. A 03:00 wake produces an awake drain that is arithmetically correct and experientially meaningless.
- **People who do not wear the watch to sleep.** No wake time, no ceiling, cold-start screen permanently.
- **People with energy-limiting conditions (ME/CFS, long COVID, POTS).** Body Battery is genuinely loved by this group for avoiding push-crash cycles. But the exertion term is normalised to the user's own Move goal, so a person with a 200 kcal goal drains 13 points from a walk to the kitchen. That is arguably correct pacing feedback and it will read as punishment.
- **Athletes wanting a training decision.** This answers "how much have I got", not "should I go hard". A 48 does not tell you whether to do intervals.
- **Colour-blind users in accented mode on a face that inverts colours.** Protected by the band word and the battery symbol's fill level, but the amber-vs-red distinction that carries the fastest read is gone. They fall back to reading a word, which costs the 5-second budget.
- **Anyone who wants the app to be quiet.** Two pushes a day, a haptic on early band crossings, and a complication that changes every 30 minutes is an active presence. That user should be given concept 06.

---

## 16. The 5-second test, per surface

"Pass" = a decision without reading a sentence.

| Surface | Verdict | Reasoning |
|---|---|---|
| `accessoryCircular` | **PASS** | Ring fill length plus 2 digits. Donut read time measured at 216–245 ms |
| `accessoryRectangular` | **PASS** | Number + bar fill + tick position. The sparkline is a bonus, not the decision |
| `accessoryInline` | **PASS** | Battery glyph fill + the word `falling`. No sentence |
| Smart Stack widget | **PASS** | Same three elements as rectangular plus one derived number. Read in under 1 s |
| **Screen 1 — Now** | **PASS** | Bar fill lands in ~250 ms and that is the decision. The number and the word are confirmations, not requirements |
| **Screen 2 — Spend** | **FAIL, honestly** | This screen answers *why*, and "why" cannot be delivered in 5 seconds. The reader must compare three bars and read three labels. It passes a weaker test — the largest drain term is identifiable in ~300 ms — but it **fails the stated test and is not defended as passing it.** It is on page 2 precisely because it is not a glance surface |
| **Screen 3 — Tonight** | **PASS** | `38` plus the tick position on the forecast band. The number's colour and the tick's x-position both say "you run low before evening" without reading |
| **Screen 4 — Recharge** | **PASS** | One duration, one gain, one button |
| **N1 short look** | **FAIL by design** | It carries no number, because R17 forbids sensitive data in a notification title. The short look says a thing is ready; the long look says what it is. Apple's own rule is that a short look must not be the only channel |
| **N2 short look** | **PASS** | `Draining faster than usual` is itself the decision: slow down |
| **Cold-start Now** | **PASS** | `14` / `Spent today` is one number and two words |
| **Always-On Now** | **N/A — intentionally unreadable** | Passing this test in Always-On would be a spec violation. A bystander sees a Laso-branded empty battery outline and a time |

**Two failures and one intentional non-answer. All three named, none hidden.**

---

## Appendix — what the prototype file contains

Screens, all reachable from the left rail and from each other the way the concept intends:

**Off-app:** Watch face (three Laso slots labelled by family, four system complications around them, each Laso slot deep-linking to its own screen) · Smart Stack (4 widgets, crown-scrollable, Laso's one rectangular widget in context).
**Notifications:** N1 short look · N1 long look · N2 short look · N2 long look, with real actions and the Double-Tap target marked.
**App:** Launch / wrist raise (cached value first, no spinner, then the live recompute) · 1 Now · 2 Spend · 3 Tonight, as a 3-page vertical `TabView` with a page indicator beside the crown · Recharge, pushed, depth 2, with a running state and a real countdown.

**States**, from the dev toolbar: loaded · loading with cache · loading first launch · cold start · empty · HealthKit denied · phone unreachable · stale · off wrist. Plus an Always-On toggle that genuinely removes every health value on every screen, and a band switcher covering all three colour bands.

**Interactions:** mouse wheel and ↑/↓ drive the Digital Crown with a visible crown indicator and rendered `.click` detents on Recharge; every state-changing tap fires a visible pulse and a caption naming the real `WKHapticType`; press states are `scale(0.96)` at 80 ms; `prefers-reduced-motion` is honoured; the dev toolbar can fire a simulated Double Tap, which reports honestly that Now / Spend / Tonight have no primary action by design.

**Verification run on the prototype:** 1 188 render combinations (11 screens × 9 states × 3 bands × 2 sizes × Always-On on/off) execute with no exceptions, no `undefined`/`NaN` in the output, and non-empty markup; 75 content assertions confirm the Alex numbers and every state string; the model reproduces `62 − 9 − 6 + 1 = 48`, spend 14, slope −2/hr, bedtime 38, Low crossing 17:00, and `+1 / +2 / +4 / +8` for 3 / 5 / 10 / 20 minutes.
