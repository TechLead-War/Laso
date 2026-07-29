# Concept 08 — Ask (`coach`)

Rationale for `08-coach.html`. Design target 46mm, 208 × 248 pt. Floor 40mm, 162 × 197 pt. Dark
only. All data is Alex, Tuesday 14:32, exactly as `PROTOTYPE-SPEC.md` defines it.

Every URL below appears in `research/`. Nothing is invented. Evidence strength is marked
**A** peer-reviewed or first-party platform doc · **B** vendor doc or reproducible product
behaviour · **C** single reviewer, snippet, or inference.

---

## 1. One-sentence philosophy

The wrist is where the "why" is asked, because the wrist is where the feeling happens — so the
wrist must carry the answer, not the score.

---

## 2. The question it answers first, and why

**"Why do I feel tired?"**

Every other concept in this set answers a question the user could also have asked their phone. This
one answers the question that only ever gets asked at the moment the body produces the symptom —
14:32 on a Tuesday, mid-slump, phone in a bag. The felt state is the trigger, and the felt state
happens at the wrist.

It was chosen because the single most consistent failure across the entire competitive set is
explanation, not measurement: *"Bevel is big on data, but falls short on guidance"*
([tech.yahoo.com](https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html));
*"The scores are a black box"* and the app does not show *"which inputs drove the number"*
([autonomous.ai](https://www.autonomous.ai/ourblog/bevel-app-review)); Ultrahuman flags a
temperature drop but *"doesn't explain why it could happen or what it could mean"*
([garagegymreviews.com](https://www.garagegymreviews.com/ultrahuman-ring-review)). **A/B.**

Laso's phone already runs a CausalChainEngine, a CompoundInsightEngine and a DecisionPolicyEngine.
The wrist currently receives one integer from all of it. The gap between what the phone knows and
what the wrist says *is* the product opportunity, and it is a gap nobody in the competitive set has
closed on a watch.

The consequence, stated up front: the hero is prose, so the pre-attentive channel has to be carried
by something else. That is the severity strip. See §16 — this design's central trade is not hidden
anywhere in this document.

---

## 3. Screen by screen, element by element

### S0 — Launch and wrist-raise return

**S0a, cold launch.** watchOS shows the dock snapshot first, so the snapshot **is** page 1 rendered
with the last cached answer — never a splash, never a logo. On appear the fresh values swap in with
no animation and no count-up; the 400ms count-up fires only on the very first appearance after
install. In the prototype, **Replay snapshot** in the dev toolbar shows yesterday's cached sentence
(`You slept 40m short. Heart was normal.` — Monday: 7h 00m against a 7h 40m need, RHR 55 = baseline)
being replaced by today's.

**S0b, wrist raise back into a frontmost app.** The app was in the Always-On redacted state. On
raise, the redaction crossfades out over 220ms `cubic-bezier(.22,.61,.36,1)`. Page position, scroll
offset and crown selection are preserved. No haptic. No re-run of any appear animation.

### S1 — ANSWER (root page 1)

**The one decision: is there a real reason, and is it bad enough to change my plan?**

| Element | Why it is there |
|---|---|
| **Question header**, `Why you feel tired`, 12pt `textTertiary`, chevron, 208 × 44 hit area | Names the question being answered so the sentence below is an answer and not an announcement. It is also the entry to the deck. 44pt hit area around a 12pt label. |
| **Severity strip**, 4pt, three segments at 74.6 / 58.2 / 49.1pt | The pre-attentive verdict: *how many things are off, and how bad.* Segment widths are the phone's attribution weights, so the strip is not decoration — the widest segment is the biggest cause. Readable in well under 300ms, which is what rescues a prose hero from a 5.0 s session. |
| **Hero sentence**, 17pt/600, max 2 lines: `You slept 1h 28m short. That's most of it.` | The whole concept. It names the cause and puts the number inside the sentence. Bare numbers are what every studied product refuses to ship alone (**A/B**, [Garmin](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html), [Fitbit](https://support.google.com/fitbit/answer/14236710?hl=en)); this takes it to its limit and ships **no** headline number at all. |
| `That's most of it.` | The attribution weight said in English, and the promise that page 2 exists. It converts the glance into a question the user already wants answered, which is the navigation mechanism of the whole concept. |
| **Source line**, filled 5pt dot + `Your phone, 14:05` | Source and age on every screen. Athlytic publishes its staleness rule in-product and pre-empts the ticket; Bevel does not and carries a [live public bug thread](https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match) about watch values being 1–5 points off. **B.** |

Text lines: 1 + 2 + 1 = **4**. At 40mm the hero drops to 16pt with a 3-line ceiling.

### S2 — BECAUSE (root page 2)

**The one decision: which one of these do I actually control today?**

Three 44pt rows, no page title. Each row is one accessibility element and one tap target.

| Row | Value | Scale | Fill | "Your usual" tick |
|---|---|---|---|---|
| `Sleep` **short** | `6h 12m` | 0 → 10h | 62% | 76.7% = 7h 40m need |
| `Heart` **high** | `58 bpm` | 40 → 80 | 45% | 37.5% = 55 |
| `Breaths` **up** | `15.2/min` | 10 → 20 | 52% | 46% = 14.6 |

The scales are **fixed**, which is the load-bearing detail: the tick does not move day to day, so
the user learns one picture of "where my usual sits" and reads position against it rather than
re-reading a number. Fill left of the tick = under, right = over. That is the second non-colour
carrier, after the state word in the label.

**Why bars and not a ring.** Three values that must each be compared to a baseline is a comparison
task. Measured time to correctly compare two values: bar 159–285ms, radial bar 1548–1772ms
([Blascheck et al., InfoVis 2018](https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf)).
**A.** Against a 5.0 s session that is the difference between three factors read and one.

**Why these three and not HRV.** All three are plain English with no training-theory jargon, all
three are watch-native, and all three are exactly what Alex's data flags on the same night. HRV is
the strongest recovery driver but "HRV" is jargon at a wrist; it appears one level deeper on S4 as
`Heart variation`, which is Athlytic's parenthesised-baseline pattern (principle 10).

### S3 — DO (root page 3)

**The one decision: do I do this, and did I do it?**

`figure.walk` glyph · `Walk 20 minutes before 17:00.` at 17pt/600 · `Keep it easy.` at 12pt · a
44pt `Did it` button.

The imperative form is deliberate. Garmin ships a 2–4 word imperative next to its number ("Time to
slow down", "Let your body recover"); "Moderate Readiness" only names a bucket. **A/B**
([Garmin manual](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html)).

`actionDetail` and `actionIcon` are shipped over the wire today and rendered by no view
(`01-CURRENT-APP-CRITIQUE.md` §2). This screen renders both.

**The bug this fixes.** On tap: fire `.success`, send `markActionDone`, and **immediately** swap the
button to `Done 14:32`. Do not wait for the phone. If a `WatchCommandResult` comes back rejected,
fire `.failure` and revert with `Not saved. Tap to retry.` The shipping app disables the button
whenever `pendingCommands` is non-empty, and `pendingCommands` only clears when the phone answers —
so a lost answer disables the button until relaunch. Toggle **Phone rejects the next
markActionDone** in the dev toolbar to see the rejection path.

### S4 — FACTOR (pushed, depth 2)

**The one decision: is this a one-night thing or a pattern?**

Single screen height, **does not scroll** — which is precisely what frees the crown to scrub the
sparkline. Title · hero value with its baseline right-aligned · primary bar with the tick ·
supporting row (the thing that did not fit on S2) · a live readout · a 7-night bar sparkline with
today highlighted.

Showing a slope and not just a level is Garmin's Body Battery insight: the glance is *"your current
Body Battery level and a graph of your Body Battery level for the last several hours"* — the slope
answers "am I going up or down", which a static number cannot. **B**
([Garmin](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html)).

7 nights is not a design choice, it is the watch's own local HealthKit window (R6), so the sparkline
needs zero wire traffic.

### S5 — DECK (pushed, depth 2)

Six fixed questions, crown-scrolled, every label ≤21 characters so it never wraps at 40mm. The
pinned row carries a 3pt `accent` leading bar **and** the word `now` — colour never carries the
selection alone (R18). Tapping fires `.click`, pins the question, pops to root and re-seeds pages
1–3. No deeper push: the deck is a selector, not a hierarchy.

All six answers are rendered in the prototype and are switchable from the toolbar:

| # | Hero sentence | Factor rows | Confidence |
|---|---|---|---|
| 1 | `You slept 1h 28m short. That's most of it.` | Sleep short 6h 12m · Heart high 58 bpm · Breaths up 15.2/min | high |
| 2 | `Yes, but keep it easy today.` | Recovery 62 · Strain 6.2 of 8 to 12 · Sleep short 6h 12m | high |
| 3 | `It's 74 now, sitting. Normal for you.` | Now 74 bpm · Today 52 to 141 · Resting 58 bpm | high |
| 4 | `Short, not broken. 22 min awake is normal.` | In bed 6h 12m · Deep 52m · Awake 22m | high |
| 5 | `Stress 41 and rising since 11:00.` | Stress 41 · Caffeine 2, last 11:15 · Heart high 58 bpm | medium |
| 6 | `Two small signs last night. Watch it.` | Heart high 58 bpm · Breaths up 15.2/min · Temp up 0.3 °C | **low** |

All six share **one** action on page 3, because the phone's DecisionPolicyEngine emits one action
per day. Principle 14: the verdict screen gets exactly one action. Question 6 renders its
uncertainty in the source line — `Your phone, low confidence, 14:05` — because it is the only
prediction in the set and `PROTOTYPE-SPEC.md` requires a prediction to show its confidence.

**Honest flag:** S5 is the one screen that exceeds the 4-line budget. Recorded in §15, not buried.

### Navigation model

```
[Watch face / Smart Stack / Notification]
        │  three distinct deep links
        ▼
   ROOT ── vertical TabView, crown ──────────────
   page 1  ANSWER ──── tap header ──► S5 DECK  (depth 2, pops to page 1)
   page 2  BECAUSE ─── tap a row ───► S4 FACTOR (depth 2)
   page 3  DO
```

Three fixed-height pages, depth 2 everywhere. The page order **is** the progressive disclosure:
glance → factors → detail-and-do. Turning the crown down is the act of asking "why?" again.

---

## 4. Why this works on a watch, and would be worse on a phone

1. **The trigger is physical and the device is already on the trigger.** "Why do I feel tired" is
   asked by the body, not by a calendar. A phone requires a fetch: find it, unlock it, open the app.
   The wrist requires a raise. 82.3% of watch sessions are self-initiated, 142.1/day
   ([CHI 2017](https://www.kostakos.org/papers/chi17.pdf)). **A.**
2. **One sentence is the right size for a wrist and the wrong size for a phone.** On a 6-inch screen
   a single sentence with 90% of the display empty reads as an under-built app. On 208 × 248 pt it
   reads as an answer. The line budget that constrains the watch is what makes the concept feel
   confident rather than thin.
3. **The wrist holds the sensors, so the offline state is genuinely useful.** Sleep, resting heart,
   breathing, HRV, SpO2, wrist temperature, stand and exercise are all watch-native. The phone
   contributes judgements. A phone version of this concept has no equivalent fallback — with no
   network it has nothing.
4. **The complication does the job before the app is opened.** Apple: users *"may never explicitly
   launch your app"* ([watchOS apps](https://developer.apple.com/documentation/watchos-apps)). **A.**
   A sentence on the face is a product; a sentence in a phone widget competes with 40 other widgets.
5. **What would be better on the phone:** dictation and free-text questions, the six-question set
   growing to sixty, any chart with more than 7 points, and the reasoning behind the attribution.
   All of it is deliberately left on the phone (§12).

---

## 5. watchOS HIG guidance applied

Cited from `research/apple-hig.md` via the synthesis rule table.

| Rule | How this design obeys it | Source |
|---|---|---|
| R1 seconds not minutes | 3 fixed-height pages, depth 2, one action. **Honestly noted:** S1 costs ~1.5 s of reading against a 5.0 s median session. | [designing-for-watchos](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos) · [chi17](https://www.kostakos.org/papers/chi17.pdf) |
| R2 the app is not the product | C1 and the Smart Stack widget carry the daily verdict; the app is the detail view. | [watchos-apps](https://developer.apple.com/documentation/watchos-apps) |
| R3 two families reach the Smart Stack | Ships `accessoryRectangular` only. | [HIG: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) |
| R4 four refresh budgets | The answer changes ~1×/day; three complications share ~4 background tasks/hour comfortably. | [keeping-a-widget-up-to-date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) |
| R5 widgets are never real-time | Nothing on a complication is presented as live except C3's exercise minutes, which are read natively. | [HIG: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) |
| R6 watch HealthKit reaches ~7 days | 7-night sparklines and the 7-night cold-start threshold are both set to that window; every 60-day baseline arrives over the wire. | [athlytic support](https://athlyticapp.helpscoutdocs.com/article/12-widget-or-complication-out-of-sync) |
| R7 redact health data in Always-On | Sentence, factor labels, bars, sparkline and action all genuinely replaced. No severity colour at all. | [always-on state](https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state) |
| R8 no haptic while sampling HR | All haptics suppressed, crown detents included, while answer 3 samples live heart rate. 100ms minimum spacing elsewhere. No background haptics. | [WKInterfaceDevice.play](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)) |
| R9 background execution is never guaranteed | No design element depends on a background task firing; the fallback is the watch's own HealthKit. | [background-execution](https://developer.apple.com/documentation/watchkit/background-execution) |
| R10 crown is navigation, press is reserved | Crown drives root pages, the S4 scrub and the S5 scroll. No crown-press handling anywhere. | [HIG: Digital Crown](https://developer.apple.com/design/human-interface-guidelines/digital-crown) · [Page controls](https://developer.apple.com/design/human-interface-guidelines/page-controls) · [Tab views](https://developer.apple.com/design/human-interface-guidelines/tab-views) |
| R11 no primaryAction on tabs/lists/scrolls | No `handGestureShortcut(.primaryAction)` anywhere in the root. Double Tap advances the vertical tab, the watchOS 11 default. | [HIG: Gestures](https://developer.apple.com/design/human-interface-guidelines/gestures) |
| R12 relevance is a different API on watchOS | `TimelineProvider.relevance()` with `RelevantContext.sleep(.wakeup)` and `.fitness(_:)`. `TimelineEntry.relevance` explicitly not used. | [Widget suggestions in Smart Stacks](https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks) |
| R13 no spinners | No spinner in any state. Skeleton bars at the exact y of the hero lines, plus `Reading last night.` | [HIG: Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback) |
| R14 static surfaces get deleted | C2 changes 0–3 daily, C1's sentence and strip change every morning, C3 fills through the day. One deep link each. | [HIG: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) |
| R15 sizes, type and touch floors | 44pt targets everywhere except the sparkline bars (16 × 40pt, above the 28pt minimum). Widget designed to the 152 × 69.5pt box. 11pt floor on complication text. Line widths ≥2pt. | [HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) |
| R16 extended runtime is capped | No extended runtime session of any kind. | [extended runtime sessions](https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions) |
| R17 short look is not a channel | Short-look title `Today's answer` carries no health data. 3 actions of the allowed 4. First action nondestructive, so Double Tap picks it. No "Open" action. | [HIG: Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications) |
| R18 colour alone never carries meaning | Six non-colour carriers, listed below. | [HIG: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) |

**Meaning without colour, the six carriers:** the sentence itself (S1, C1, widget, both
notifications) · the state word in the row label — `short`, `high`, `up` (S2, long looks) · the
position of the fill relative to the tick (every bar) · the filled-segment count plus the digit `3`
(C2) · the word `now` plus a leading edge bar (S5) · stroke versus fill (Always-On; stale hollow
ring versus fresh filled dot).

---

## 6. UX principles used, and the mechanism

| # | Principle | Evidence | Mechanism here |
|---|---|---|---|
| 3 | Never ship a bare number | **A/B** [Garmin](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-C21BE0C8-A08E-4DA1-B6C6-2E0E2DDDB372.html), [Fitbit](https://support.google.com/fitbit/answer/14236710?hl=en) | Taken to its limit: the wrist ships no headline number at all. `readinessScore` appears exactly once, as a factor row inside answer 2. |
| 4 | Imperative, not description | **A/B** [Bevel review](https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html), [Ultrahuman review](https://www.garagegymreviews.com/ultrahuman-ring-review) | `Walk 20 minutes before 17:00.` with a verb first and a number second, not `Moderate readiness`. |
| 6 | Bars, not rings, for comparisons | **A** [InfoVis 2018](https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf) | Every S2 row, every S4 bar, the severity strip, the sparkline. The only ring in the design is C2, and it is a count, not a comparison. |
| 7 | Show a slope, not just a level | **B** [Garmin Body Battery](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html) | S4's 7-night sparkline with today highlighted and a crown scrub. |
| 10 | Progressive disclosure: glance → factors → detail | **B** [Garmin](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-28BA6B01-9460-4FF3-8499-5D91269FD50B.html), [Fitbit review](https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html), [black-box critique](https://www.autonomous.ai/ourblog/bevel-app-review) | **The spine of the concept.** Sentence at 0 turns, three factors at 1, evidence at 1 tap. Garmin puts the level at 0 presses and the factor list at 3. |
| 11 | Name the cold start | **B** [Garmin "No Status"](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-6F81BF5B-B49A-4506-95E2-0F4A04D8B319.html), [Fitbit 7 nights](https://support.google.com/fitbit/answer/14236710?hl=en) | `Not enough nights yet.` + `4 more nights.` and three real measured values with no tick. |
| 12 | Publish the staleness rule in-product | **B** [Athlytic](https://athlytic.github.io/athlyticapp/troubleshooting/) vs [Bevel's bug thread](https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match) | A source-and-age line on every screen; the reference frame visibly changes offline. |
| 14 | One action on the verdict screen | **B** [Gentler Streak](https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface), [Garmin Stress → Breathwork](https://www8.garmin.com/manuals/webhelp/GUID-F41EAFB3-6CC9-42DE-9C6C-9E358DBB0671/EN-US/GUID-DD8EE575-CC72-4829-B4C8-4BE1F8D3473E.html) | All six questions share the same single daily action. |
| 15 | One deep link per complication | **A/B** [HIG: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets) | `/answer`, `/because`, `/do`. |
| 16 | Tiny reused colour system | **A/B** [Gentler Streak](https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path) | Exactly three severity tokens, reused identically in the strip, the bars and C2. `primary` blue used only for goals. |
| 17 | A score that contradicts felt state is worse than none | **B/C** [DC Rainmaker on WHOOP](https://www.dcrainmaker.com/2021/11/whoop-platform-review.html) | The entry question *is* the felt state. If the sentence disagrees with how you feel, page 2 shows the three measurements so you can judge it yourself. |

---

## 7. Psychological principles that drive repeat opens

| Mechanic | Evidence strength | Applied |
|---|---|---|
| **Surviving the first 8 days** | **strong: peer-reviewed** — >50% of health-app users churn in week 1; the cohort still engaged at day 8 gained **+25 days** median retention ([Pratap et al., 109,914 participants](https://arxiv.org/pdf/1910.01165)) | The cold-start screen shows three real measured values and one real action from day 1, with a named 7-night countdown. Nothing in week 1 is empty. |
| **Uncertainty about the outcome** | **strong (mechanism), inferred (application)** — anticipatory dopamine ramp scales with uncertainty ([Fiorillo et al., Science 2003](https://pubmed.ncbi.nlm.nih.gov/12649484/)) | The morning sentence is genuinely unpredictable from yesterday's. No fake variance is manufactured — principle 17 would kill it. |
| **Push the verdict at wake time** | **medium: vendor data** — [Garmin Morning Report](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-4D26FDDC-63BD-4910-95B8-98937FEC2545.html), [Oura Symptom Radar](https://ouraring.com/blog/symptom-radar/). No published effect size. | N1 plus `RelevantContext.sleep(.wakeup)` on the widget — the pull surface costs the user no notification budget. |
| **Delta-triggered notifications** | **strong on the near-term effect, strong that it is not retention** — 3.5× next-hour lift, 1.04–1.3× over 24h, **no measurable long-term retention effect**; only 9.4% of notifications produce any session ([Bell et al.](https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf), [Bidargaddi et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/), [CHI 2017](https://www.kostakos.org/papers/chi17.pdf)) | Both notifications fire on a **change**, never on a state. Ceiling 2/day, typical 1. |
| **Dynamic content at near-zero access cost** | **strong: peer-reviewed** — checking habits require dynamic content quickly accessible ([Oulasvirta et al.](https://link.springer.com/article/10.1007/s00779-011-0412-2)) | **Applied weakly, and that is this concept's structural flaw.** The sentence is static for ~23 hours. Only C2's 0–3 count, C3's exercise minutes and the natively-read factor values move during the day. Quantified honestly in §13. |
| **Streaks / loss aversion** | **medium: vendor A/B** — Duolingo Streak Wager +14% D7 ([Duolingo](https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/)) | **Deliberately not used.** A streak rewards wearing and opening, not recovering. Gentler Streak's own name is ironic — they ship manual On a Break / Sick / Injured states so users can stop without penalty. |

---

## 8. Complication strategy

Three families, **one deep link each, never shared** — R14/R15: *"If all the complications you
support open the same area in your app, they can seem less useful."*

### C1 — `accessoryRectangular` → `laso://ask/answer`

Canvas 178.5 × 56pt at 45mm (Apple publishes no 46mm row; 46 ≈ 45 is an acknowledged gap, see §15).
`Why tired` + `14:05` on the top line at 11pt; a two-line 15pt/600 sentence; the 4pt three-segment
severity strip at the bottom.

**Pixel budget honesty:** at 15pt SF Compact Rounded (~7.05pt average advance) 178.5pt holds ~25
characters per line. The phone must therefore author a **rectangular variant of the sentence capped
at 50 characters**, sent as its own field (`headlineShort`). Truncating the app sentence is not
acceptable — a half-sentence is a broken product.

**Why a user gives up a face slot:** it is the only complication on any recovery app's face that
tells you *why* rather than *what*. Every competitor's rectangular slot shows a number or a chart
you still have to interpret. This one has done the interpreting, and it changes every morning.

### C2 — `accessoryCircular` → `laso://ask/because`

32 × 32pt closed gauge. A three-segment ring, 120° per segment, 8° gaps, stroke 8pt (6pt at 40mm),
sweeping from 12 o'clock. A segment is **filled** if that factor is off its usual and left as track
if it is not. Centre: `3` at 14.5pt with `off` at 10.5pt beneath.

**Why a user gives up a slot:** it is a 0-to-3 count that moves daily and creates a real information
gap ("which three?"), resolved in one tap. A bare score in that slot is static for 23 hours, and
Apple warns that a static complication *"may be less likely to remain in a prominent position"*.

**One deviation from the approved spec, stated:** the spec calls for round caps. At r = 16pt with an
8pt stroke a round cap extends ~14° past each segment end, which completely swallows the 8° gaps and
renders the ring as one solid donut. Since the *filled-segment count* is one of this design's two
non-colour carriers for C2, countability wins: the prototype uses **butt caps** so the three
segments stay distinguishable. Round caps become viable again only if the gaps widen to ~36°, which
shrinks each segment to 84° and reads worse.

### C3 — `accessoryCorner` → `laso://ask/do`

`figure.walk`, `12/30`, corner gauge at 40% in `primary` blue. **Deliberately a goal metric, not a
verdict.** Exercise minutes are watch-native, so this complication is never stale, and because
`primary` blue is a goal colour and not a health band, C3 discloses no verdict and needs no
Always-On redaction.

**Why a user gives up a slot:** honestly, it earns nothing on novelty — it is a goal gauge like a
dozen others. It exists so the person who only wants the action can have it without the
explanation, and because it is the only Laso complication that is always live with the phone off.
**This is the weakest of the three. If a user is only giving Laso one slot, ship C1.**

### Not shipped: `accessoryInline`

Cut with a reason. Inline is one row of text with **one tap target**, and *"on some watch faces, the
system renders the complication along a curve"*
([accessoryInline](https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline)).
A concept whose product is a sentence cannot ship a surface that truncates that sentence along a
curve.

---

## 9. Smart Stack strategy

**`accessoryRectangular` only.** R3: only rectangular and circular reach the Smart Stack.
`accessoryCircular` in the stack would show the same `3 off` glyph in more space than it needs — one
widget, one job.

Designed to **152 × 69.5pt** (40mm) rising to 191 × 81.5pt (49mm), 8pt padding, 136pt content:
`Why you feel tired` + `14:05` at 11pt · a two-line 15pt/600 sentence · a 6pt three-segment strip.

**Read-only, no interactive button.** Apple: *"avoid creating app-like layouts in your widgets"*, and
at 69.5pt tall a 28pt button costs one of the two sentence lines. Principle 7: every studied
competitor's watch surfaces are read-only except where the watch is uniquely good at the action, and
reading a sentence is not that.

**Black background, not a coloured card.** The HIG suggests coloured backgrounds and Stocks uses
one, but a full-bleed amber card makes a moderate Tuesday look like an alert.

**When it should surface (R12).** `TimelineProvider.relevance()` returning a `WidgetRelevance` built
from `WidgetRelevanceAttribute(configuration:context:)` with two clues:

1. **`RelevantContext.sleep(.wakeup)`** — surface the overnight answer when it is worth the most.
   This is the wake-time verdict mechanic executed as a *pull* rather than a push.
2. **`RelevantContext.fitness(_:)`** — surface after a workout ends, the highest-density "why do I
   feel like this" moment of the day.

Both clues require the matching HealthKit permission **on the app target and on the widget extension
independently**. `LasoWatchWidgets` requests neither today and the entitlement exists on neither.

`RelevanceConfiguration` (watchOS 26+) is **not** used: Apple states plainly that *"people can't
configure widgets that use a RelevanceConfiguration to appear in the Smart Stack, add them to the
Smart Stack, or pin them"*. For a once-a-day answer, being pinnable is worth more than being
multiply surfaced.

---

## 10. Notification strategy

**Cadence ceiling: 2 per day maximum, 1 per day typical, 0 between 21:00 and the wake window.** On
Alex's Tuesday the app sends **exactly one**.

The budget is set before the inventory because it constrains everything:

- Notifications buy an open now, not a habit: 3.5× next-hour lift, 1.04–1.3× over 24h, **no
  measurable long-term retention effect**, and across two MRTs time to disengagement was not
  significantly different between notification policies
  ([Bell et al.](https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf),
  [Bidargaddi et al.](https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/)). **strong.**
- Only **9.4%** of notifications produce any session and **82.3%** of watch sessions are
  self-initiated ([CHI 2017](https://www.kostakos.org/papers/chi17.pdf)). A push-only app fights for
  the 17.7% slice, so the complication and the widget carry the load.
- Athlytic's absolute-threshold stress alerts drew an explicit user request for *"a big friendly
  toggle to hush stress for a while"*
  ([craftingworlds](https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/)).
  So N2 fires on a **change**, never on an absolute value, and ships a mute action.

**N1 — Morning answer.** First wrist-raise-detected wake after the phone finishes overnight
analysis, 0–15 min after wake. Fires **only if today's hero sentence differs from yesterday's** — a
delta trigger, copying Training Today's model. Once per day, hard.
Short look title: `Today's answer` — no number, no verdict, no health data (R17).
Long look: caption, the full sentence, the severity strip, `Walk 20 minutes before 17:00.`
Actions: **`Did it`** (first, nondestructive, so Double Tap picks it) · `Ask something else`
(→ `laso://ask/deck`) · `Not today`. No `Open` action.

**N2 — Answer changed.** The phone's answer for the currently pinned question crosses a confidence
band during the day. Only questions 5 and 6 can trigger it. Never within 4h of N1, never after
21:00, once per day. **On Alex's Tuesday this does not fire** — the illness signal stays at low
confidence and is delivered passively on the widget. It is in the prototype as the state that
*would* fire it. Actions: `Log a symptom` · `Ask something else` · `Mute for 24h`.

**Nothing else fires.** No stand nudges, no hydration reminders, no streak reminders, no "you
haven't opened Laso in 3 days". Each of those buys a 3.5× next-hour open and zero retention, at the
cost of the trust that makes N1 worth reading.

---

## 11. Haptic language

| Event | `WKHapticType` |
|---|---|
| Crown detent between root pages | `.click` |
| Crown detent scrubbing the S4 sparkline | `.click`, one per night stepped, 7 max then it stops at the ends |
| Tap `Did it` on S3 | `.success`, fired immediately on tap, before the phone answers |
| Tap a question in S5 | `.click` — a value step, not a completion |
| `WatchCommandResult` returns a rejection | `.failure`, paired with the visible `Not saved. Tap to retry.` |
| The pinned answer's severity band moves while the app is open | `.directionUp` / `.directionDown` |
| N1 / N2 arriving | `.notification`, system-played |

**Nothing else fires a haptic.** No haptic on navigation push or pop. Apple: *"Overusing the click
haptic tends to diminish its utility."*

**R8, the rule that overrides all of the above.** *"When you engage the haptic engine, HealthKit
stops gathering heart rate data until after the haptic engine finishes"*
([WKInterfaceDevice.play](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:))).
Deck question 3 runs a live `HKAnchoredObjectQuery` on `heartRate`. While that answer is pinned and
any root page is frontmost: **all haptics are suppressed**, crown detents included. Minimum spacing
between any two haptics elsewhere is 100ms. No haptics at all in the background — the only exception
Apple allows is an active workout session, and this app never starts one. Pin `Why is my heart up?`
in the prototype toolbar and the haptic caption changes to say so.

---

## 12. What was deliberately excluded, and why

1. **Voice dictation and free-text questions.** The biggest cut and the one most likely to be
   second-guessed. Three independent reasons, any one sufficient: **(a)** dictation costs a raise, a
   tap, 2–4 s of speech and a recognition round trip — 8–15 s against a 5.0 s median session; **(b)**
   an arbitrary question needs the phone's FoundationModels session, so the feature breaks exactly
   when the phone is in another room, which is the one state this design refuses to fail in; **(c)**
   an unbounded question set cannot be pre-computed, and pre-computation is the only way an
   LLM-quality answer reaches a device that cannot run an LLM. A fixed deck of six is the honest
   architecture. Dictation belongs on the iPhone.
2. **LLM-authored wrist strings.** Unbounded length, unbounded latency, non-deterministic across two
   glances at the same day. Templates only. FoundationModels may *rank* factors; it may not write
   the sentence.
3. **A readiness ring or hero score.** The score is not the product here.
4. **`accessoryInline`.** One tap target and text rendered along a curve on some faces.
5. **Live heart rate on the root pages.** It appears only in answer 3, where haptics are suppressed
   for the whole screen. Putting it on S1 would silence the crown detents on the most-used screen.
6. **Streaks, badges, and "you haven't opened Laso" pushes.** See §7.
7. **The morning check-in and the quick-log journal, as screens.** A 3-page `TabView` that sometimes
   has 4 or 5 pages is an unstable mental model. **This is an unresolved dependency, not a solved
   problem** — the critique is right that the check-in has genuine value and that it is currently
   invisible on mornings when the phone has not synced. If it must ship inside this concept it ships
   as a fourth page that exists only in its 05:00–11:00 window, and that instability is a real cost.
8. **Two rings on one screen.** Never happens. C2 is the only ring and there is one of it.
9. **Any red on Alex's day.** Nothing in the fictional data is below 45. Manufacturing a red state to
   make the prototype look dramatic would violate the data-honesty rule. The dev toolbar's band
   control is labelled a **preview** and says so in the panel: it recolours the bands without
   touching a single number, and Alex's real Tuesday is fair.
10. **A coloured widget background.**

---

## 13. Expected opens per day, with the mechanism

*Open* = the app becomes frontmost. A complication or widget *view* is not an open.

| # | Trigger | Time | Mechanism | Opens |
|---|---|---|---|---|
| 1 | N1 morning answer | ~07:05 | Delta-triggered push. The long look carries the full answer, so many users never open — that is the design working, and it also *satisfies* the need. Baseline notification-to-session rate is 9.4%; a wake-time recovery answer is far above that. | **0.4** |
| 2 | Watch face wrist raise, C1's sentence changed | 07:00–09:00 | Self-initiated glance. The sentence is new, so it is read on the face; converts to an open when the user wants the three factors. | **0.5** |
| 3 | Smart Stack, crown-down at wake | 06:45–08:00 | `RelevantContext.sleep(.wakeup)`. Mostly a view; converts when the strip shows more segments than yesterday. | **0.3** |
| 4 | Post-workout / post-effort | ~40% of days | `RelevantContext.fitness(_:)` surfaces the widget when "why do I feel like this" peaks. | **0.3** |
| 5 | Afternoon slump, self-initiated | 14:00–15:30 | The concept's namesake moment. **This is the open the whole design exists for, and it is the only one with no external trigger at all.** | **0.5** |
| 6 | Marking the action done | 15:00–19:00 | Netted down because some are absorbed by N1's `Did it` action. | **0.4** |
| 7 | Asking a second question from the deck | follows any of the above | Curiosity / information gap. Incremental only — it never starts a session. | **0.2** |

**Honest total: ~2.6 app opens per day**, plus roughly **6–10 passive complication and widget views.**

That is well below the 5–20 the brief hopes for, and the reason is structural, not fixable by
polish: **the hero sentence is static for ~23 hours.** Checking habits require dynamic content
([Oulasvirta et al.](https://link.springer.com/article/10.1007/s00779-011-0412-2), **strong**), and a
once-a-day explanation has none. The only genuinely moving things here are C2's 0–3 count, C3's
exercise minutes and the natively-read factor values on S2 — all secondary. Concept 08 buys trust
and differentiation and pays for it in frequency. A concept built on a depleting gauge (01) or a
live measurement (03) will beat it on opens per day and lose to it on "did the app ever tell me
anything I didn't already know."

---

## 14. Buildability against this codebase

Read this section as a work estimate, not a promise. Line references are to `01-CURRENT-APP-CRITIQUE.md`
and `03-ARCHITECTURE.md`, both of which were written from the shipping source at `cbb674f`.

### What exists today and is reused unchanged

| Field / mechanism | Where | Used for |
|---|---|---|
| `actionHeadline` | `WatchPayload` | S3 headline. Already sent, already rendered. |
| `actionDetail` | `WatchPayload` | S3 detail. **Sent today and rendered by no view.** This design renders it. |
| `actionIcon` | `WatchPayload` | S3 glyph and C3 symbol. **Sent today and rendered by no view.** |
| `actionDone` + `WatchCommand.markActionDone` | `WatchPayload` / `WatchStore` | The `Did it` button and its confirmed state. |
| `readinessScore` | `WatchPayload` | Appears once, as a factor row inside answer 2. |
| `readinessGrade` | `WatchPayload` | Picks the strip colour for answer 2. **Sent today and rendered by no view.** |
| `updatedAt` | `WatchPayload` | Every source line. |
| App Group cache read by the widget extension | `ReadinessComplication` | The pattern is correct and stays: the extension needs no session of its own. |
| `PhoneWatchSession.lastComplicationScore` guard | `PhoneWatchSession.swift` | Already spends the complication transfer budget only when the score changes. Correct, keep it. |

**`dayType` is dropped from the wire.** "Progressive Overload" is training-theory jargon and the
critique is right that nobody parses it at a wrist.

### New `WatchPayload` fields

```swift
struct WatchAnswer: Codable, Equatable {
    let questionId: String            // "tired" | "train" | "heart" | "sleep" | "stress" | "sick"
    let questionText: String          // "Why do I feel tired?"        ≤21 chars
    let headline: String              // app sentence                  ≤44 chars
    let headlineShort: String         // complication / widget variant ≤50 chars over 2 lines
    let confidence: String            // "high" | "medium" | "low"
    let factors: [WatchAnswerFactor]  // exactly 3, ordered by weight descending
}

struct WatchAnswerFactor: Codable, Equatable {
    let id: String                    // "sleep" | "restingHR" | "respiratory" | "stress" | ...
    let label: String                 // "Sleep short"                 ≤13 chars
    let severity: String              // "optimal" | "fair" | "poor"
    let weight: Double                // 0...1, sums to 1 across the 3
    let value: Double?                // nil = the watch reads it from HealthKit
    let baseline: Double?
    let baselineLabel: String         // "usually 55"
    let scaleMin: Double
    let scaleMax: Double
    let supportingLabel: String?      // "Heart variation"
    let supportingValue: Double?      // nil = HealthKit
    let supportingBaseline: Double?
}

// added to WatchPayload
let answers: [WatchAnswer]            // exactly 6
let pinnedQuestionId: String
```

**`value: nil` is the load-bearing detail.** Nil means "you are holding the sensor, read it
yourself." That is why the wrist is never 1–5 points off the phone on any measured value — the only
things that can disagree are baselines and severity bands, and those are labelled with their source
and their age on every screen. It is the direct answer to the bug Bevel has shipped in public.

**Payload size:** 6 answers × (~110 B of strings + 3 factors × ~130 B) ≈ **2.5 KB**, well inside what
`updateApplicationContext` carries. `03-ARCHITECTURE.md` §4 also requires a `schemaVersion: Int` and
optional new fields **before** any field is added, not after; this design assumes that lands first.

### What needs native HealthKit on the wrist

The Watch target links no HealthKit at all today: `LasoWatch.entitlements` holds one App Group key,
`Info.plist` has no `NSHealthShareUsageDescription`, and `project.yml:242-252` lists the target's
sources file by file with nothing health-related in them.

| Value | Type |
|---|---|
| `6h 12m` sleep, and the 7-night sleep sparkline | `HKCategoryTypeIdentifier.sleepAnalysis` |
| `58 bpm` resting heart, and its 7-night sparkline | `restingHeartRate` |
| `15.2/min` breathing, and its 7-night sparkline | `respiratoryRate`, overnight mean |
| `48 ms` heart variation | `heartRateVariabilitySDNN`, overnight mean |
| `96%` blood oxygen | `oxygenSaturation` |
| `0.3 °C` wrist temperature | `appleSleepingWristTemperature` |
| `74 bpm` live and `52 to 141` today (answer 3 only) | live `HKAnchoredObjectQuery` on `heartRate` |
| `12/30` exercise minutes (C3) | `appleExerciseTime` |
| `6 of 12` stand, `Last stood 12:40` (offline S3) | `appleStandHour` |
| 7-night local means for the phone-unreachable state | computed on the wrist from the above |

New watch-side code: **`WatchVitals`**, one `@Observable @MainActor` reader with a per-type
`HKAnchoredObjectQuery` and **one anchor stored per type, never a shared anchor**, plus a 7-night
local mean cache. `03-ARCHITECTURE.md` §2 is explicit that `HealthKitManager` must **not** be ported
— it is built around 72 metrics, a registry, SwiftData persistence, thermal gating and ML
orchestration, none of which belongs on the wrist. Existing precedent to copy:
`LiveViewModel.swift:418` (anchored HR stream with a 1/sec UI throttle) and `LiveViewModel.swift:387`
(observer set coalesced to one per 15 s).

**The entitlement also has to go on `LasoWatchWidgets`.** `RelevantContext.sleep(_:)` and
`.fitness(_:)` need the matching HealthKit permission on the widget extension independently (R12), or
Smart Stack relevance silently does nothing. Today neither target has it.

### New phone-side work

1. **`WatchAnswerBuilder`** — runs once per readiness refresh, calls the existing CausalChainEngine
   (attribution weights), CompoundInsightEngine (co-occurring factors) and DecisionPolicyEngine (the
   one action), and emits six `WatchAnswer` structs.
2. **Sentences are deterministic templates, not LLM output.** An LLM sentence has unbounded length
   and unbounded latency, and R1 gives the whole interaction 5 seconds. A template with interpolated
   numbers is also the only form that can be pre-computed for a payload.
3. **Copy templates live in `Common/Copy/Copy+WatchAnswers.swift` and resolve through Firebase Remote
   Config on the phone**, and the phone sends the *finished* string. This is a genuine architectural
   win rather than a workaround: the watch and widget targets link no Firebase, so payload-carried
   strings are the only way Laso's copy standard reaches the wrist at all.
4. **Hook `PhoneWatchSession.push()` into `BackgroundRefreshCoordinator`.** Today `push()` is called
   from exactly one place, `DashboardViewModel.writeWidgetSnapshots()` at
   `DashboardViewModel.swift:2265`, reached only from foreground paths. The background task computes
   a fresh score, writes it for the iOS widget, reloads the iOS widget timelines — and never pushes
   to the watch. **That single missing call is the root cause of "the most common state is telling
   the user to go use the phone."** It is a handful of lines and the highest-leverage fix in the
   whole document.
5. **On-watch fallback template table** — a fixed `[(condition, sentence)]` list, ~8 rows, used only
   when no payload exists. Deterministic, testable, offline. This is watch-side, not phone-side, and
   is the only piece of sentence generation that ever runs on the wrist.
6. **Expire `pendingCommands` entries.** They only clear when the phone answers
   (`WatchStore.swift:83`), and the shipping button is disabled whenever the list is non-empty, so a
   lost answer disables it until relaunch. Stamp entries with a time.

### Effort, honestly

Taking `03-ARCHITECTURE.md` §6's own numbers: the background push and the pending-command expiry are
**hours**. Payload versioning is **1–2 days and must land first**. The Smart Stack widget is
**2–3 days, medium risk** because the relevance API is easy to get wrong and untestable without real
hardware. Native HealthKit on the wrist is **3–5 days, medium risk** — entitlement plus a second App
Store review surface for health permissions, and the authorisation prompt is a new first-run moment
that has to be designed, not bolted on.

On top of that baseline, this concept specifically adds: `WatchAnswerBuilder` and six template sets
(the largest single item, and a permanent maintenance surface — see §15.4), three complication
families instead of one, the on-watch fallback table, and the S4/S5 screens. **Call it two to three
weeks on top of the shared architecture work, and the architecture work is a prerequisite, not a
parallel track.**

**The three things most likely to go wrong:**

- **The attribution weights.** The strip's segment widths and the sentence's `That's most of it.`
  both come from CausalChainEngine attribution. If those weights are noisy day to day, the strip
  flickers and the sentence contradicts itself across two glances at the same day. This needs
  smoothing on the phone and it is not designed here.
- **Six answers is six of everything.** Six template sets, six cold-start variants, six
  low-confidence variants, six copy rows in Remote Config, six sets of attribution logic. The cap at
  six should be defended hard; a seventh is not free.
- **`HKCategoryTypeIdentifier.sleepAnalysis` on the wrist is not the same thing as the phone's sleep
  model.** The watch reads stages; the phone reads stages plus a need model plus 5 nights of debt.
  The offline sleep row will therefore sometimes disagree with the online one. The design labels the
  reference frame on every screen rather than hiding it, which is the right call and is also
  something a user can be confused by (§15.5).

---

## 15. Honest drawbacks, and who this design fails

1. **It fails the strict 5-second test on its two most important surfaces (S1 and C1), because its
   hero is prose.** No amount of design fixes this. The severity strip mitigates it to "verdict in
   <300ms, reason in ~1.5 s" and that is the ceiling. Every other concept in this set gets a decision
   faster.

2. **The strongest argument against it: it fails everyone who cannot read a 17pt sentence at 28cm,
   off-axis, quickly.** Presbyopia, low vision, dyslexia, non-native English readers, anyone glancing
   mid-stride, anyone in bright sun. A colour-and-shape concept serves all of those people better on
   the same hardware. The design mitigates with Dynamic Type to AX5, a VoiceOver reading order and
   the pre-attentive strip — but the mitigations are consolation, not parity. **If Laso's audience
   skews older or global-multilingual, this concept is the wrong bet and concept 02 (One Word) or 09
   (Fourth Ring) is the right one.**

3. **A wrong explanation destroys trust faster than a wrong number.** If the CausalChainEngine
   attributes tiredness to sleep when the real cause was alcohol, the wrist states it confidently in
   full sentences. DC Rainmaker's WHOOP critique — an 80% recovery after 3h15m of jet-lagged sleep
   while he *"still felt like crap"* ([DC Rainmaker](https://www.dcrainmaker.com/2021/11/whoop-platform-review.html))
   — is a wrong *number*, and it already cost the product his trust. A wrong *sentence* is worse
   because it cannot be dismissed as a model quirk; it reads as the app not knowing you. Principle 17
   is the load-bearing risk of this entire concept.

4. **Six pre-computed answers is a permanent maintenance surface.** Every question needs its own
   attribution logic, template set, cold-start and low-confidence variants, and copy row.

5. **The offline answer will sometimes disagree with the phone's answer.** The wrist's reference
   frame is 7 nights, the phone's is 60 days. On a week when Alex has been consistently short on
   sleep, the watch's "your week, 6h 56m" reads *normal* while the phone's "you need 7h 40m" reads
   *short*. The design shows the reference frame on every screen rather than hiding the disagreement,
   which is the right call and is also a thing a user can be confused by.

6. **`Did it` is self-reported and unverifiable.** The watch could check whether a 20-minute walk
   actually happened via `appleExerciseTime`, and this design does not. A deliberate scope cut, but
   the completion signal is soft.

7. **The morning check-in has no home in this concept.** §12 item 7. It is the one piece of the
   shipping app the critique credits with genuine value, and this design does not place it.

8. **S5 is the only screen that breaks the 4-line budget**, and the second-question path (crown
   scroll, tap, re-render) is 4–6 seconds — well past R1. It is reached deliberately and never
   surfaced off-app, but it is a screen that does not obey the rules the rest of the design obeys.

9. **Double Tap in-app does nothing this concept invented.** It advances the page, the system default.
   The concept's Double-Tap primary action lives only on the notification long look. That is R11-clean
   and it is also a thinner Double Tap story than concepts whose primary action is a single tappable
   button on a non-tab screen.

10. **It cannot sustain the checking habit** — ~2.6 opens/day, quantified in §13. If the evaluation
    criterion is opens, this concept loses.

**Known gaps carried from the research, not papered over:** Apple publishes no numeric watchOS
safe-area insets and no Smart Stack size row for 42mm or 46mm, so C1's 178.5 × 56pt canvas is the
45mm figure treated as 46mm, and the widget's 46mm box is interpolated between the published 40mm
and 49mm rows. The `digitalCrownRotation` overload carrying haptic-detent parameters could not be
resolved in the research, so "crown detents fire `.click`" is stated as intent rather than as a
verified API call. Both are listed in `research/00-SYNTHESIS.md` §7.

**Two deviations from the approved spec, both because the spec's own geometry does not close:**
C2's ring uses butt caps rather than round caps (§8, round caps swallow the 8° gaps at r = 16pt and
destroy the segment count), and the severity strip's segment widths are computed from the weights and
the stated gap rather than hard-coded, because the spec's C1 and widget figures sum to a total that
does not match the stated canvas width. Both changes preserve the design's intent exactly.

**One spec fidelity note the reviewer should see.** S4's sparkline maps the factor's fixed bar scale
onto 0 → 36pt, as the spec states for resting heart (40 → 80 bpm). On Alex's real 55–58 bpm week that
compresses seven nights into a 2.7pt height range, and on the breathing variant it is worse. The
prototype implements the spec as written rather than silently re-scaling, because the tick position
and the sparkline should share one scale vocabulary — but the honest verdict is that the sparkline's
*shape* carries very little on a low-variance week and the readout number carries all of it. Fixing
it means either a second scale for the chart (breaks the shared vocabulary) or accepting that the
sparkline is a "is today the outlier" glyph rather than a trend chart. It is currently the latter.

---

## 16. The 5-second test

The strict test from `PROTOTYPE-SPEC.md`: *can a user get a decision in under 5 seconds **without
reading a sentence**?* Median smartwatch session is exactly **5.0 s**, the watch is read at ~28cm,
~50° pitch, ~10° off line-of-sight
([CHI 2017](https://www.kostakos.org/papers/chi17.pdf), [InfoVis 2018](https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf)).

| Screen | Verdict | Reasoning |
|---|---|---|
| **S1 Answer** | **FAIL** | The hero is a sentence. There is no reading of this that passes a test whose criterion is "without reading a sentence." What *does* pass in <300ms is the severity strip: three amber segments = "three things are off, all moderate, nothing red", which gets the user to *"something's off, it's not serious."* Getting to *why* costs ~1.5–2 s of reading. **This is the concept's central trade and it is not hidden.** |
| **S2 Because** | **PASS** | Three bars with baseline ticks. Fill-versus-tick position is a bar comparison at 159–285ms each. All three read in well under 1 s. |
| **S3 Do** | **MARGINAL PASS** | `Walk 20 minutes before 17:00.` is 5 words, verb first, number second — ~1.5 s. Passes as a decision, fails the strict "without reading" clause. The `figure.walk` glyph carries the category pre-attentively; the duration and the deadline do not. |
| **S4 Factor** | **PASS** | One number at 22pt, one tick, one sparkline with today highlighted. Level and direction in <500ms. |
| **S5 Deck** | **FAIL — by design** | A picker is not a verdict surface. It is reached deliberately, is never the entry screen, and is never surfaced in a complication or widget. |
| **C1 rectangular** | **FAIL strict / PASS practical** | Same trade as S1: the strip passes, the sentence does not. |
| **C2 circular** | **PASS** | The digit `3` plus the filled-segment count. Two independent non-colour carriers, both pre-attentive. |
| **C3 corner** | **PASS** | Symbol + `12/30` + gauge fill. |
| **Smart Stack widget** | **FAIL strict / PASS practical** | Identical to C1. |
| **N1 short look** | **PASS** | `Today's answer` — 2 words. It intentionally carries no verdict, because R17 forbids sensitive information in the title, so it passes the read test and deliberately fails the information test. Apple: *"Avoid using a short look as the only way to communicate important information."* |
| **N1 / N2 long look** | **FAIL strict / PASS practical** | The strip reads in <300ms; the sentence and the action line cost ~2 s. A long look is a reading surface by construction. |
| **Always-On** | **N/A** | Redacted by requirement. Nothing to read is the correct outcome. |

**Summary: two hard fails on the two most important surfaces — S1 and C1 — plus the long looks, and
all of them are the concept, not a bug.** A concept whose hero is an explanation cannot win a test
scored on not-reading.

What it can win is the test the whole competitive set fails. *"Bevel is big on data, but falls short
on guidance."* *"The scores are a black box."* Ultrahuman *"doesn't explain why it could happen or
what it could mean."* Concept 08 trades ~1.5 s of reading for the answer nobody else ships, and it
is the only concept in this set that can be wrong in a way the user can check — because it shows the
three measurements it used.

---

## Appendix — the prototype

`08-coach.html`. Single file, no network, opens from `file://`. Screen switcher on the left lists
every surface; the dev toolbar is bottom-right.

**Surfaces implemented:** watch face with C1/C2/C3 in real slots against system complications ·
Smart Stack scrollable through 5 widgets · notification short look · N1 and N2 long looks with their
actions · cold launch with the dock snapshot swap · wrist-raise return from Always-On · root pages
S1/S2/S3 · S4 factor detail in all three variants plus the phone-only variants · S5 deck.

**States:** loaded · loading with no cache · cold start · HealthKit denied · phone unreachable ·
stale 2h · stale with yesterday's `dayKey` · Always-On redacted, on every screen.

**Interactions:** mouse wheel and Up/Down arrows drive the crown, with a rotating crown indicator and
a rendered `.click` detent marker; the crown's target changes per screen (pages, sparkline scrub,
list scroll, stack scroll, long-look scroll, and crown-down from the face into the Smart Stack).
Every state-changing tap shows an edge pulse and a caption naming the `WKHapticType` — including the
suppression caption when answer 3 is pinned. `Fire Double Tap` is in the toolbar, and its effect
changes per surface. Press states are `scale(0.96)` / 80ms. `prefers-reduced-motion` is respected.

**Verified:** the file passes the required structural check (75 KB, balanced tags, no external
references, no `alert(`), the banned "go and use the phone instead" string appears zero times — the
word "iPhone" itself appears zero times anywhere in the file — and a headless harness renders all 45,360 combinations of
size × Always-On × band × pinned question × screen × state × page × factor with zero exceptions and
zero console errors.
