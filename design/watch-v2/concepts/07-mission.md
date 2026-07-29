# Concept 07 — Daily Mission (`mission`)

Prototype: [`07-mission.html`](07-mission.html) · Design target 46mm (208×248pt), floor 40mm (162×197pt) · Dark only · Alex, Tuesday 14:32.

Evidence strength on every citation: **A** = peer-reviewed measurement or first-party platform documentation · **B** = vendor documentation or reproducible product behaviour · **C** = single reviewer, inference, or snippet-level. Every URL below appears in `research/`. Nothing is invented.

---

## 1. One-sentence philosophy

One job a day, closed with a tap, tracked as a chain that a rest day cannot break.

---

## 2. The question it answers first

**"Have I done my thing today?"** — and it must be answerable from shape alone, before any word is read.

That question was chosen because it is the only health question on the wrist whose answer is **binary, self-caused, and closable on the device**. "How recovered am I?" needs a number the watch cannot compute. "What is my body doing now?" needs a live sensor read and gives no action. "Have I done my thing?" has exactly two answers, and one of them the user can change with one tap.

That has three consequences the rest of the design falls out of:

- A binary answer can be encoded **pre-attentively**: a closed ring plus a checkmark against a partial ring plus a mission glyph. The median smartwatch session is exactly **5.0s** at ~28cm and ~10° off line-of-sight (**A** — https://www.kostakos.org/papers/chi17.pdf, https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf). A shape survives that budget; a two-digit score does not.
- A closable answer means the primary surface can be the **complication**, answered at zero taps, with the app as the detail view — Apple's own framing, since users "may never explicitly launch your app" (**A** — https://developer.apple.com/documentation/watchos-apps).
- A binary answer with a history is a **chain**, and a chain is the one engagement mechanic in this space with a published A/B number: Duolingo's Streak Wager, **+14% D7** (**B** — https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/).

The bet — and it is a bet — is that a person does not need a score to act, they need a job. Concept 02 makes the opposite bet with a word; concepts 01, 03 and 10 make it with a number that moves.

---

## 3. Screen-by-screen reasoning, element by element

### Screen 1 — Mission (entry, `NavigationStack` root, no scroll)

46mm, 10pt horizontal padding, 188pt of content. Top to bottom, with the reason each element earns its height:

| # | Element | Height | Why it is there |
|---|---|---|---|
| 1 | top inset | 6pt | rounded-corner clearance |
| 2 | **Mission arc**, 96×96, stroke 8pt, track `surfaceSubtle`, fill `primary` | 96pt | The one hero. Filled to **64%** for Alex. It is a *level*, absorbed not compared — the only legitimate use of a radial encoding in `DESIGN-TOKENS.md` |
| 2a | ↳ mission glyph `bed.double.fill`, 24pt, at arc centre −13pt | — | Says *what* the job is without a word. Replaced by `checkmark` when closed |
| 2b | ↳ target `22:35`, `title` 22pt/600, tabular, at arc centre +14pt | — | Says *when*. Tabular so it never reflows as the minute ticks |
| 3–4 | **Mission line** `Get to bed early`, `headline` 17pt/600, one line, tail truncation | 20pt | The verb. Principle 4: an imperative, not a bucket name (**A/B** — https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html) |
| 5–6 | **Freshness dot + reason** `4h 20m behind, 5 nights`, `caption` 12pt | 15pt | The "why" at **zero taps**, which is the fix for the black-box-score failure (**B** — https://www.autonomous.ai/ourblog/bevel-app-review). The dot is the freshness channel: filled = fresh, hollow ring = not |
| 7–8 | **Primary button**, 188×44, radius 10 | 44pt | Exactly one action. Out of window: `bell` + `Remind me at 21:35`. In window: `checkmark` + `Done`. Closed: `checkmark.circle.fill` + `Closed`, non-interactive |
| 9 | **Chain strip**, 7 bars 20×24 + count `12`, 44pt tap target | 44pt | The still-open distance, visible on the entry screen so completion never lands on "done, nothing next" |
| 10 | bottom inset | 6pt | — |

**6+96+6+20+2+15+8+44+44+6 = 247pt of 248.** One point of slack, and no scroll — which is forced, see §5.

Three lines of prose (mission, reason, button label) plus two numerals rendered inside graphic elements. Under the 4-line budget.

**Chain bar states are three shapes, never three colours:** closed = solid full-height bar; missed = 2pt outline; paused = half-height solid; today-open = 2pt `primary` outline. Alex reads as six solid `optimal` bars then one `primary` outline.

**At 40mm (146pt of content):** arc 68×68 stroke 6, glyph 18pt, target `headline` 17pt, mission line 16pt, bars 16×22 at 5pt gaps. **The reason line and its dot are dropped entirely**, and so is the trailing chain count — 7×16 + 6×5 = 142pt of bars leaves 4pt, which cannot hold a numeral. Truncating a reason is worse than omitting it, and the count lives one tap away on Screen 2. Total 4+68+4+18+6+44+44+5 = **193pt of 197**.

### Screen 2 — Chain (drill-in from the strip, depth 1)

Hero `12` at `heroNumber` 52pt with `days` baseline-aligned beside it · the same 7 bars at 20×26 with day letters `W T F S S M T` under them, today's letter in `textPrimary` · the **next distance** `7 to your longest` · one button, `Pause the chain`.

28+56+6+42+8+16+8+44 = **208pt**. No scroll at 46mm; 180pt at 40mm.

The next-distance line is not decoration, it is the goal-gradient mechanism, and the rule is exhaustive so it can never be blank: `N to your longest` below the best · `Longest chain yet. Next: 30 days.` at the best · `N to N` against {30, 50, 100, 200, 365} above it · `Close today to start a new chain.` at zero.

### Screen 3 — Pause (drill-in from Chain, depth 2)

Hero `3` days, crown-driven, range 1–14 · `Chain holds. Nothing breaks.` · `Pause 3 days`, label tracking the crown live. 186pt, no scroll.

This screen exists because of the single biggest known danger in the mechanic: *a streak rewards wearing and opening, not recovering*. Gentler Streak ships manual **Active / On a Break / Sick / Injured** states for exactly this reason (**B** — https://docs.gentler.app/understanding-your-activity-path/what-is-the-activity-path). Pause is free, unlimited, and holds the chain. A paused day renders half-height — neither a close nor a miss.

---

## 4. Why this works on a watch specifically, and would be worse on a phone

- **The answer is delivered by the watch face, at zero taps and zero launches.** On a phone the equivalent is a home-screen widget the user has to look for; on the wrist the face is looked at ~142 times a day already (**A** — https://www.kostakos.org/papers/chi17.pdf). This concept spends that existing attention instead of asking for new attention.
- **Closing is a physical gesture.** `handGestureShortcut(.primaryAction)` means the mission closes with a Double Tap while carrying something. A phone cannot do that, and the Smart Stack path (crown-down, Double Tap) closes the day without opening anything — the Waterllama pattern (**B** — https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585).
- **The notification arrives on the wrist at the moment the action becomes possible.** A bedtime prompt at 21:35 on a phone is a prompt on the device that is *causing* the late bedtime.
- **What would be better on a phone:** the chain history beyond 7 days, the reason behind the mission, and any editing of it. All three are deliberately absent here.

---

## 5. watchOS HIG guidance applied

| Rule | How this design obeys it | URL | Strength |
|---|---|---|---|
| R1 5.0s sessions | One arc, one verb, one reason, one button. §16 grades each state honestly. | https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos | A |
| R2 the app is not the product | Complication + Smart Stack carry the whole loop. §13 projects **0.7 app opens/day** and says so out loud. | https://developer.apple.com/documentation/watchos-apps | A |
| R3 two families reach the Smart Stack | `accessoryRectangular` in the Stack; `accessoryCircular` published for the face and available in the Stack unchanged. No Corner, no Inline. | https://developer.apple.com/design/human-interface-guidelines/widgets · https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline | A |
| R4/R5 refresh budgets | A Class B mission needs **zero** background refreshes — see §14. | https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date · https://developer.apple.com/documentation/watchkit/wkapplicationrefreshbackgroundtask | A |
| R6 watch HealthKit reaches ~7 days | Chain history is phone-sourced. The 7-day strip is coincidentally inside the wrist's reach and is still taken from the phone for correctness. | https://athlytic.github.io/athlyticapp/troubleshooting/ | B |
| R7 redact health data in Always-On | §9. The target, the verb, the reason, the chain count and every bar state are removed, not dimmed. Arc becomes a 2pt stroke. | https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state · https://developer.apple.com/documentation/swiftui/environmentvalues/isluminancereduced | A |
| R8 no haptic while sampling HR | **This concept never samples heart rate**, so all seven haptics are unconditionally safe. | https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:) | A |
| R9 background is "a few seconds" | No background work is required for correctness; the timeline is precomputed. | https://developer.apple.com/documentation/watchkit/background-execution | A |
| R10 crown is navigation | The crown drives the Pause value — Apple's data-inspection pattern, verbatim: *"In contexts where the Digital Crown doesn't need to navigate through lists or between pages, it's a great tool to inspect data."* Its absence on Screen 1 is stated as a cost, not hidden. | https://developer.apple.com/design/human-interface-guidelines/digital-crown · https://developer.apple.com/design/human-interface-guidelines/page-controls | A |
| R11 Double Tap vs lists/scroll/vertical tabs | **This rule sets the navigation model.** No `TabView`, no scroll view on the entry screen. | https://developer.apple.com/design/human-interface-guidelines/gestures · https://developer.apple.com/documentation/swiftui/view/handgestureshortcut(_:isenabled:) | A |
| R12 watchOS relevance is a different API | `TimelineProvider.relevance()` → `WidgetRelevance`. `TimelineEntry.relevance` appears nowhere in the build. | https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks · https://developer.apple.com/documentation/relevancekit/relevantcontext | A |
| R13 no spinners | Loading renders the cached mission at full opacity plus the word `Updating`. | https://developer.apple.com/design/human-interface-guidelines/feedback | A |
| R14 static surfaces get deleted; one link each | Two complications, two links. The Class B arc advances every 15 minutes. | https://developer.apple.com/design/human-interface-guidelines/widgets | A |
| R15 sizes and touch floors | Every target ≥44×44 except the 42×42 widget button, justified against Apple's 28×28 minimum. Line widths ≥2pt everywhere, including the outline bars. | https://developer.apple.com/design/human-interface-guidelines/accessibility · https://developer.apple.com/design/human-interface-guidelines/layout | A |
| R16 extended runtime | Not used. This concept needs no session. | https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions | A |
| R17 notifications | App name in the title only; static long look packaged with the app; `Done` first so Double Tap selects it; 3 custom actions plus Dismiss. | https://developer.apple.com/design/human-interface-guidelines/notifications | A |
| R18 colour never alone | Shape table in §10 of the build spec, reproduced under Accessibility below. No red anywhere. | https://developer.apple.com/design/human-interface-guidelines/widgets | A |

**The navigation model is forced, not chosen.** R11 is unambiguous: *"Avoid setting a primary action in views with lists, scroll views, or vertical tabs."* This concept's whole product is a Double-Tappable completion, so a vertical `TabView` — which R10 otherwise recommends as the watchOS default — would kill it. **R11 wins on the entry screen; R10 is honoured everywhere else.** Depth is 2 and depth 2 is reachable only through a control nobody uses daily, satisfying *"Minimize the depth of hierarchy"* (https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos).

The honest cost, stated: **the crown does nothing on Screen 1 and no crown accessory is shown there.** Apple warns *"If you don't provide visual feedback, people are likely to assume that turning the Digital Crown has no effect in your app"* — here that assumption is correct, so no affordance is offered. That is the price of Double Tap and it is paid knowingly.

---

## 6. UX principles used, and the mechanism

| # | Principle | Mechanism here | URL | Strength |
|---|---|---|---|---|
| 2 | Complication and widget are the product | The ring on the face answers the day's question at zero taps; the Smart Stack closes it without an app launch. | https://developer.apple.com/documentation/watchos-apps | A |
| 3 | Never ship a bare number | The hero is a **verb**. The arc and the checkmark carry state; no score appears anywhere. | https://support.google.com/fitbit/answer/14236710?hl=en | A/B |
| 4 | Imperative, not description | Every mission string the advisor emits is already verb-first. The wrist renders that and nothing else. | https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html | A/B |
| 6 | Bars, not rings, for comparison | The 7-day chain is **bars** — 159–285ms to read, against 1548–1772ms for a radial. One ring per screen, ever. | https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf | A |
| 10 | Progressive disclosure of "why" | Verdict at 0 taps (arc), reason at 0 taps (one line), chain at 1 tap, pause at 2. | https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html | B |
| 11 | Name the cold start, never fake a value | `First mission in 3 nights` with an empty ring — the Garmin "No Status" / Fitbit 7-nights precedent. | https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-6F81BF5B-B49A-4506-95E2-0F4A04D8B319.html · https://support.google.com/fitbit/answer/14236710?hl=en | B |
| 12 | Publish the staleness rule in-product | `Mission from 09:12` plus a hollow freshness dot. Only the *text* can age; the arc cannot. | https://athlytic.github.io/athlyticapp/troubleshooting/ · https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match | B |
| 14 | One action, the obvious next step | Exactly one button per screen. Never two side by side, anywhere. | https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface · https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585 | B |
| 15 | One deep link per complication; cap what you track | Two complications, two links. **One** mission a day — Streaks caps tracking at 24 tasks for the same reason. | https://developer.apple.com/design/human-interface-guidelines/widgets · https://apps.apple.com/us/app/streaks/id963034692?platform=appleWatch | A/B |
| 16 | Tiny colour system, never load-bearing | Four colours: `primary`, `optimal`, `textTertiary`, `borderLow`. Gentler Streak's one-hue, no-red discipline. | https://docs.gentler.app/understanding-your-activity-path/interpret-the-activity-path | A/B |
| 17 | A verdict that contradicts felt state destroys trust | Named as the strongest argument *against* this concept in §15, not argued away. | https://www.dcrainmaker.com/2021/11/whoop-platform-review.html | B/C |

**The one arc rule**, applied identically in the app, the complication and the widget:

> The arc shows how much of this mission is already behind you, 0–100%.
> **Class A (measurable)** — units done ÷ target units, read from native watch HealthKit (exercise minutes, steps, stand hours, mindful minutes, water).
> **Class B (moment)** — time elapsed from the day start to the target moment, from the watch clock (bedtime, caffeine cutoff, meal timing).
> **Closed** — 100%, full 360° sweep, checkmark glyph replaces the mission icon.

Alex is Class B: 00:00 → 22:35 is 22h 35m, and 14:32 is 14h 32m in = **64%**.

### Accessibility, and meaning without colour

Every distinction is a shape or a word first; colour only reinforces. *"In watchOS, the system may invert colors depending on the watch face a person chooses"* (https://developer.apple.com/design/human-interface-guidelines/widgets, **A**).

| Distinction | Shape | Colour (reinforcement only) |
|---|---|---|
| Closed vs open | full 360° sweep + `checkmark` vs partial sweep + mission glyph | `optimal` vs `primary` |
| Day closed vs missed | solid bar vs 2pt outline bar | `optimal` vs `borderLow` |
| Day paused | half-height bar | `textTertiary` |
| Today | outline bar + the only day letter in `textPrimary` | `primary` |
| Fresh vs stale | filled dot vs hollow ring, plus the age written in words | `optimal` vs `textTertiary` |

**No red exists anywhere in this design.** A missed day is an outline, never `poor #E05C64`. Red on a broken chain is the exact mechanism that turns a streak into a punishment; Gentler Streak ships no red at all and Athlytic's alarming alerts drew an explicit request for *"a big friendly toggle to hush stress for a while"* (**C** — https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/).

VoiceOver treats the arc as **one** element with a combined label — *"Today's mission. Get to bed early. Target 22:35. 64 percent of the way there. Not yet closed."* — per Apple's rule that an infographic carries a concise description of what it conveys (https://developer.apple.com/design/human-interface-guidelines/voiceover, **A**). The chain strip reads *"Chain. 12 days. 6 of the last 7 days closed, today still open. Button. Opens chain detail."* The Pause value is an `.accessibilityAdjustableAction`, so a VoiceOver user gets the crown's value without the crown.

Contrast against `bg #000000`: `textPrimary` ≈18:1, `textSecondary` ≈12.6:1, `textTertiary` ≈9.7:1, `primary` ≈7.6:1, `optimal` ≈9.4:1. All clear 4.5:1. `borderLow` is structural only and never carries text.

---

## 7. Psychological principles that drive repeat opens

| # | Mechanic | Evidence | Application here |
|---|---|---|---|
| 1 | **Dynamic content at near-zero access cost** | **strong: peer-reviewed** — checking habits are "brief, repetitive inspection of dynamic content quickly accessible on the device"; adding real-time information to a previously static screen *caused* checking to emerge (https://link.springer.com/article/10.1007/s00779-011-0412-2), and 82.3% of watch sessions are self-initiated (https://www.kostakos.org/papers/chi17.pdf) | The Class B arc advances every 15 minutes on the face all day; Class A advances with real movement. It is never static for 23 hours, which is what Apple warns gets a complication removed. |
| 2 | **Surviving the first 8 days** | **strong: peer-reviewed** — >50% of health-app users discontinue in week 1; the sub-cohort still engaged at day 8 gained **+25 days** median retention (https://arxiv.org/pdf/1910.01165) | The cold start is a named, actionable day-1 screen with a working button (`Set your reminder time`), not an empty ring. |
| 3 | **Goal gradient** | **strong: peer-reviewed** — 20% acceleration near the goal, 16% faster completion overall, and effort **resets once the reward is earned** (https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf) | Two nested distances. The day distance is the arc. The moment it closes, the chain strip and `7 to your longest` are already on screen — the design never leaves the user at "done" with nothing next. |
| 4 | **Bars over radial for comparison** | **strong: peer-reviewed** — 159–285ms vs 1548–1772ms (https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf) | Chain history is bars, on every surface that shows it. |
| 7 | **Delta-triggered notifications** | **strong on the near-term effect, strong that it is not retention** — 3.5× next-hour lift, 1.04–1.3× at 24h, **no measurable long-term retention effect**; best slot 12:30 (https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf · https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/) | One notification a day, fired at the moment the action becomes possible, carrying `Done` inline. Class A default slot 12:30 — the measured best. §13 does not credit them with retention. |
| 8 | **Streak / loss aversion** | **medium: vendor data** — Duolingo Streak Wager **+14% D7**, Weekend Amulet +4% return (https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/) | Applied with every published guardrail: rest days count, pauses hold, no red, no loss-aversion push, no repair purchase. The research's own warning — *"a streak rewards wearing and opening, not recovering"* — is answered in §15 rather than argued away. Gentler Streak's manual states are the direct precedent for Screen 3 (https://docs.gentler.app/understanding-your-activity-path/what-is-the-activity-path). |
| 9 | **Resumption cue** | **mixed — the memory half is dead.** A 2025 meta-analysis finds **no** memory advantage for unfinished tasks; the Ovsiankina *resumption* effect is reliable (https://www.nature.com/articles/s41599-025-05000-w) | The open bar on the strip is justified as a resumption cue only. It is never claimed to be "more memorable". |
| 10 | **Peer comparison** | **weak: anecdote** — WHOOP ships it and publishes no effect data (https://gadgetsandwearables.com/2025/01/24/whoop-daily-outlook/) | **Not used.** No social surface anywhere. |

---

## 8. Complication strategy

**Two families, two deep links, never shared.** Apple: *"Define a different deep link for each complication you support… If all the complications you support open the same area in your app, they can seem less useful"* (**A** — https://developer.apple.com/design/human-interface-guidelines/widgets).

### `accessoryCircular` → `laso-watch://mission`

Closed-gauge ring at the arc percentage (64% for Alex), ≥2pt stroke, `primary` on a `surfaceSubtle` track. Centre carries the mission glyph at 14pt; when closed the glyph becomes `checkmark` and the ring goes to a full 360° in `optimal`. `widgetLabel` carries `22:35`, which renders as curved bezel text on Infograph and as nothing on faces that do not support it — safe, because the ring already carries the answer.

**No text inside the ring.** The pixel budget is a 32×32pt gauge at 45/49mm and 28.5pt at 41mm, with default text at 14.5/12.5pt SF Compact Rounded. That is not enough for a mission verb, and a truncated verb is worse than a glyph.

### `accessoryRectangular` → `laso-watch://chain`

178.5×56pt at 45/49mm, 159×50 at 41mm. Three rows: mission glyph + `Get to bed early` at 15pt semibold · `22:35 · in 8h 03m` at 13pt · the 7-bar chain strip with the count trailing. Rows 2 and 3 collapse into one at 41mm. It links to `chain` and not `mission` because it is the family that *shows* the strip, and tapping a strip should open the strip.

### Deliberately not shipped

`accessoryCorner` — 10.5–12pt is the smallest text on the platform and this concept's content is a verb phrase; a corner slot showing only the chain count would duplicate the rectangular one and would need a third distinct destination it does not have. `accessoryInline` — one line and one tap target (https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline); its only honest content is `Bed by 22:35`, which is the rectangular family's row 2, and its only honest destination is `mission`, which circular already owns.

### Why a user would give up a face slot

**Because the ring closes.** Every other complication on that face *reports*; this one *completes*. A closed 360° ring with a checkmark is the only thing on the face that says *you are finished for today*, and a partial ring is the only thing that says *you are not*. That is a decision delivered at zero taps.

Against Apple's warning that *"a static complication that doesn't display meaningful data may be less likely to remain in a prominent position"*: the Class B arc advances every 15 minutes all day from a **single timeline push**, because the target is a fixed future `Date`. It is never static and it costs nothing from the ~4 background refreshes/hour budget (see §14).

**The counter-argument, stated:** for 22h 35m of Alex's Tuesday the ring is neither empty nor closed, and a 64%-full ring is exactly the ambiguous middle that principle 6 says is slow to read. The design accepts that. The checkmark, not the fill level, is the load-bearing signal.

---

## 9. Smart Stack strategy

`accessoryRectangular` only in the Stack (R3 also permits `accessoryCircular`, which is already published for the face and works there unchanged). Canvas **152×69.5pt at 40mm**, ~144×61.5pt usable after system insets.

**Out of window (Alex now, 14:32):** mission glyph + `Get to bed early` (16pt row) · `22:35 · in 8h 03m` (14pt row) · the 7-bar strip with `12` trailing (12pt row). 48pt of 61.5pt used. The whole surface deep-links to `laso-watch://mission`.

**In window (21:35–00:00) — the important one:** the title takes the full width, and below it the strip narrows to 5 bars beside a **real interactive 42×42pt Done button** backed by an `AppIntent`. The mission closes from the Smart Stack without ever opening the app, reachable by crown-down then Double Tap — the Waterllama pattern (**B** — https://apps.apple.com/us/app/water-tracker-waterllama/id1454778585). 42×42 is above Apple's 28×28pt minimum and below the 44×44 default, justified by the 61.5pt canvas ceiling (https://developer.apple.com/design/human-interface-guidelines/accessibility). On tap: `.success`, the button swaps to a filled `checkmark.circle.fill` in `optimal`, the strip's last bar fills, the count increments, and the title becomes `Closed. 7 to your longest.`

**When it should surface** — `TimelineProvider.relevance()` returning a `WidgetRelevance`. Clues in priority order:

1. `RelevantContext.date(interval:kind:)` over the mission window — 21:35 to 00:00 for Alex. Primary clue, and exact, because the window is a `DateInterval` the widget already holds.
2. `RelevantContext.sleep(.bedtime)` for Class B bedtime missions. Requires `HKCategoryTypeIdentifier.sleepAnalysis` permission on **both** the app and the widget extension — Apple states this explicitly and it is a shipping blocker if missed (**A** — https://developer.apple.com/documentation/relevancekit/relevantcontext).
3. `RelevantContext.fitness(_:)` for Class A movement missions, so the widget surfaces as a workout ends and the mission may already be satisfied.

No location clues — this concept has no location-dependent content and a false surface costs a Stack slot. **`TimelineEntry.relevance` is dead code on watchOS and must not appear anywhere in the build** (**A** — https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks).

---

## 10. Notification strategy

**Cadence ceiling: one scheduled notification per day, plus at most one unscheduled milestone per personal best. Nothing else, ever.**

That ceiling is derived, not chosen by taste. Notifications buy a **3.5× next-hour lift**, only **1.04–1.3× at 24 hours**, and **no measurable long-term retention effect**; only 9.4% of notifications produce any session (**strong: peer-reviewed** — https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf, https://pmc.ncbi.nlm.nih.gov/articles/PMC6293241/). So they are used for the one thing they are demonstrably good at: **being present at the moment the action becomes possible.**

### N1 — Mission window open (the only scheduled one)

Scheduled as a local `UNNotificationRequest` **on the watch**, so it fires with the phone in another room. Class B: window start = target − 60 min (**21:35** for Alex). Class A: user's reminder time, default **12:30** — the measured best slot, 8.8% lift, 11.8% at weekends.

Short look is the app name plus one sentence, because *"Avoid including potentially sensitive information in the notification's title"* (**A** — https://developer.apple.com/design/human-interface-guidelines/notifications). Long look is a **static interface packaged with the app**, so it renders with the phone unreachable: `Get to bed early` / `Lights out by 22:35.` / `Chain: 12 days.` Three lines, no score, no health value.

Actions — 3 custom plus system Dismiss, at the ceiling of 4:

1. **`Done`** — first and nondestructive, so a Double Tap on the notification selects it. Closes the mission, `.success`, no app launch.
2. **`Snooze 30 min`** — reschedules once. A second snooze is refused silently and the notification does not return.
3. **`Pause chain`** — opens Screen 3.

No action merely opens the app, per Apple's rule on the same page.

### N2 — New personal best (unscheduled, at most once per best)

Fires the morning after the chain passes the stored best, at the user's normal reminder slot, never at night. `20 days. Your longest yet.` / `Next: 30 days.` — and the second line is the new distance, which is the whole point (mechanic #3's post-reward reset). Dismiss only.

### Explicitly never sent

- **No streak-at-risk notification.** No "your chain ends in 2 hours." This is the single most obvious growth lever available to the concept and it is refused. Athlytic's absolute-threshold alerts drew an explicit user request for a way to silence them because they *increase* anxiety rather than help (https://craftingworlds.com/athlytic-the-apple-watch-coach-that-actually-tells-me-what-to-do/), and a loss-aversion push is the fastest way to turn this concept into the guilt spiral Gentler Streak was built to escape.
- No chain-broken notification. No "you have not opened Laso" notification. No morning verdict push — this concept has no verdict, it has a job, and the job is announced when it can be done.

---

## 11. Haptic language

| Event | `WKHapticType` | Why |
|---|---|---|
| Mission closed — screen tap, Double Tap, widget button, or notification action | `.success` | *"Tells the person that an action completed successfully."* |
| Phone rejects the write (`WatchCommandRejection`) | `.failure` | *"Tells the person that an action failed."* |
| Crown detent on the Pause days value | `.click` | *"the sensation of a dial clicking… progress at predefined increments"* |
| Pause confirmed | `.stop` | An activity the user explicitly stopped |
| Pause expires, chain resumes | `.start` | Its documented pair |
| Chain passes the personal best | `.directionUp` | *"an important value increased above a significant threshold"* |
| Mission window opens | `.notification` | Played by the system with the local notification; the app fires nothing of its own |

Minimum spacing 100ms, enforced by never queueing two haptics. **No background haptics** outside a workout session, which is why the window-open haptic comes from the notification and not from a background task. Both per https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:) (**A**).

**R8's heart-rate conflict does not exist here.** *"When you engage the haptic engine, HealthKit stops gathering heart rate data until after the haptic engine finishes."* This design never samples heart rate on any screen, so every haptic above is unconditionally safe — a real advantage over the live-HR concepts in this set, and the builder must not reintroduce a live HR read anywhere.

**Every state-changing tap fires a haptic. There are exactly five state-changing taps in the whole app** — close the mission, set the reminder, pause, confirm the pause, and the widget Done button — and all five are covered.

---

## 12. What was deliberately excluded, and why

| Excluded | Why |
|---|---|
| **The readiness score as a visible number** | The concept's claim is that a person does not need a score to act, they need a job. Adding `62` to Screen 1 would immediately make the score the hero again, because a number always wins attention over a verb. Readiness enters only as the *cause* of a mission, spoken in the reason line, and only when it is actually the cause. |
| **Live heart rate** | The strongest live signal on the wrist, and orthogonal to "have I done my thing today". Excluding it also eliminates R8's haptic/HR conflict entirely. |
| **The morning check-in** | A second daily job. "One job a day" is the whole rule; two jobs make the chain ambiguous (does a check-in close the day?) and turn the arc into a compound metric. |
| **Quick log (water, caffeine, alcohol)** | Same reason. Logging becomes the mission on days the advisor picks a hydration or caffeine action, and is invisible otherwise. |
| **Trends, HRV, sleep stages, strain, stress, VO₂ max, vitality age** | All phone-tab material. Oura demoted Resilience, VO₂ Max and Cardiovascular Age into "My Health" as *"not designed to be used every day"*, and R1 makes the same call here. |
| **`accessoryCorner` and `accessoryInline`** | R15 forbids sharing a deep link and this design has only two destinations worth a face slot. A third family would mean a duplicate or an invented screen. |
| **A streak-at-risk notification** | Anti-pattern #3. See §10. |
| **Red, anywhere** | A missed day is an outline bar. |
| **Streak freezes, repairs, or purchasable insurance** | Monetising the fear of a broken chain is what turns a health product into a slot machine. Pause is free, unlimited, and costs nothing. |
| **Peer comparison and any social surface** | Mechanic #10, weak evidence, no verified watch-side implementation in this research. |
| **Workout sessions, live strain, `HKWorkoutSession`** | Out of scope, and it would drag in a background session, extended runtime and a different refresh model entirely. |
| **A second ring** | `DESIGN-TOKENS.md`: *"Never put two rings on one screen."* The chain is bars for that reason. |
| **Undo on a closed mission** | `DailyActionCompletion.markDone` states outright that *"A mark cannot be undone; it resets on the next calendar day."* Wrist-side undo would require changing a phone invariant the result card depends on. Stated here so the builder does not add it. |

---

## 13. Expected opens per day, with the mechanism

Complication glances are counted separately from app opens, because they are not opens. R2 says people *"may never explicitly launch your app"*, and this concept is designed for that to be true.

| # | Trigger | Time | Mechanism | App opens | Non-app interactions |
|---|---|---|---|---|---|
| 1 | Passive complication glance on any wrist raise | all day | The arc is on the face. "Have I done my thing" is answered without touching anything. | **0** | ~4–8 glances that resolve the question |
| 2 | Morning first wrist raise, new mission appears | ~07:00 | The complication changes for the first time that day — the only genuinely *new* information event. | **0.20** | 1 glance |
| 3 | Midday reminder, Class A missions only | 12:30 default | Local notification with `Done` as the first action. Alex's Tuesday is Class B, so this fires **0 times today**; ~0.30 opens on a movement-mission day. | **0.00 today** | ~0.25 notification actions |
| 4 | Mission window opens | 21:35 | Local notification carrying the primary action inline, so most resolutions never reach the app. | **0.35** | ~0.50 `Done` taps from the long look |
| 5 | Self-initiated close from the Smart Stack | any time in the window | Crown-down, Double Tap on the widget's `Done` button. Never opens the app by design. | **0** | ~0.30 widget completions |
| 6 | Post-close confirmation | within ~2 min of closing | The chain count on the complication increments; some users open Screen 2 to see the strip. | **0.15** | 1 glance |
| 7 | Editing the reminder or pausing | rare | Screen 3. Realistically a few times a month. | **0.02** | 0 |

**Honest totals: ~0.7 app opens per day, ~1.0 completion interactions that never open the app, ~6 passive complication glances.**

**If the evaluation criterion is app opens per day, this concept loses on purpose.** Concepts 01, 03 and 10 will honestly claim 3–5, because a continuously changing number is a checking loop and this is not. What this maximises is the ratio of *questions answered* to *taps spent*, and the question it answers is answered from the watch face, for free, on every wrist raise.

The one row worth defending is **row 4**: the notification exists at the exact moment the action becomes possible, carries the action inline, and fires once. Mechanic #7's 3.5× next-hour lift is real, and this is the single place it is spent.

---

## 14. Buildability against this codebase

Exhaustive, and it is not a happy read. Legend: **[HK]** native watch HealthKit, no phone · **[EXISTS]** already on `WatchPayload` · **[NEW-FIELD]** new payload field · **[NEW-PHONE]** new phone-side computation that does not exist · **[WATCH-LOCAL]** on the wrist only · **[CLOCK]** the watch's own clock.

| Value | Where it appears | Source |
|---|---|---|
| `Get to bed early` | S1 mission line, rect complication, widget, N1 | **[EXISTS]** `WatchPayload.actionHeadline` ← `DailyActionStore.today()?.title` ← `DashboardSmartActionAdvisor` |
| `4h 20m behind, 5 nights` | S1 reason line | **[EXISTS]** `WatchPayload.actionDetail` — **sent today and rendered by no view.** This concept is its first consumer, but see the copy warning below |
| `bed.double.fill` | S1 arc centre, both complications, widget | **[EXISTS]** `WatchPayload.actionIcon` — also currently dead on the wire |
| Closed / open | everywhere | **[EXISTS]** `WatchPayload.actionDone`, **plus [WATCH-LOCAL] optimistic override** — see the offline invariant below |
| `22:35` target moment | S1 arc centre, circular `widgetLabel`, rect row 2, widget row 2, N1 body | **[NEW-FIELD]** `missionTarget: Date?` + **[NEW-PHONE]** wake time from the sleep schedule + sleep need + `SleepDebtTracker.paybackExtraMinutes`. **Does not exist today** — `DailyActionStore` carries prose only |
| Mission window `21:35–00:00` | button swap, N1 schedule, widget layout swap, relevance clue | **[NEW-FIELD]** `missionWindow: DateInterval?` + **[NEW-PHONE]** |
| Mission class A or B | arc rule selection everywhere | **[NEW-FIELD]** `missionKind: String` + **[NEW-PHONE]** derived from the rule that fired |
| Class A metric + target | arc fill for measured missions | **[NEW-FIELD]** `missionMetric: String?`, `missionTargetValue: Double?` + **[NEW-PHONE]**. `DashboardSmartActionAdvisor.Recommendation` has **no machine-readable target today** — only `icon`, `title`, `subtitle`, `source`, `rationale`, `expectedBenefit`. **This is the largest new phone-side piece in the concept** |
| Arc fill %, Class A | S1 arc, circular complication | **[HK]** `HKStatisticsQuery` on the wrist. **Requires adding HealthKit to the `LasoWatch` target** — `LasoWatch.entitlements` has exactly one key today (an App Group) and `Info.plist` has no `NSHealthShareUsageDescription` |
| Arc fill %, Class B | S1 arc, circular complication | **[CLOCK]** elapsed(day start → now) ÷ elapsed(day start → `missionTarget`). No data source at all |
| `in 8h 03m` | rect complication, widget | **[CLOCK]** |
| `12` chain length · `19` best · the 7-day pattern | every surface | **[NEW-FIELD]** `chainLength: Int`, `chainBest: Int`, `chainLast7: [Int]` (0 missed, 1 closed, 2 paused, index 6 = today) + **[NEW-PHONE]** — and see the blocker below |
| `7 to your longest` | S2 | **[WATCH-LOCAL]** arithmetic on `chainBest − chainLength` |
| Pause state | chain bars, S3 | **[NEW-FIELD]** `chainPausedUntil: Date?` + **[NEW-PHONE]** store + a **new `WatchCommand` case** `pauseChain(id:createdAt:days:)` |
| Reminder time | S1 button label, N1 schedule | **[WATCH-LOCAL]** only. Stored in the watch App Group, scheduled as a local `UNNotificationRequest` on the wrist. No new command, no phone round trip — which is what keeps the reminder working when the phone is unreachable |
| Freshness dot, `Mission from 09:12` | S1 | **[EXISTS]** `WatchPayload.updatedAt` + the existing `isStale(now:)` and `stalePayloadInterval` (60 min) |
| `First mission in 3 nights` | cold start | **[NEW-FIELD]** `missionColdStartNightsRemaining: Int?` + **[NEW-PHONE]** reading the same gate `ReadinessStore` uses for first readiness. **`3` is a placeholder — do not hardcode it** |
| Day letters `W T F S S M T` | S2 | **[WATCH-LOCAL]** `Calendar` with an explicit `TimeZone`, anchored on `WatchPayload.dayKey` so the two devices never disagree about where a day starts |
| Readiness 62, HRV 48, RHR 58, live HR, steps, strain, stress | **nowhere** | Deliberately absent. See §12 |

### The blocking fact: there is no completion history in this codebase

- `DailyActionCompletion` writes a single `Date` to `AppKeys.Data.dailyActionDoneDay` and **overwrites it every day**. `isDoneToday` is `Date.cal.isDateInToday(stored)` — a one-day window and nothing more.
- `DailyActionResultStore` keeps a single `Record` under one key and overwrites it on every `save`.

So `chainLength`, `chainBest` and `chainLast7` **cannot be computed from anything that exists**. A new date-keyed completion store must ship before any part of this concept works — a set in `UserDefaults` or a small SwiftData table, written from inside `DailyActionCompletion.markDone`, which is already the single choke point both the phone button and the wrist button route through, so it is a one-place change. **This is the largest prerequisite in the concept and it is completely invisible from the design.**

### The copy that does not fit, and is not the string the design shows

The shipping title is `Get to bed early tonight`, not `Get to bed early` — the wrist variant in this prototype is 9 characters shorter than what the phone sends. The shipping subtitle is a full sentence: *"You are 4h 20m down on sleep. 6 early nights clear it."* Neither fits one line at 17pt and 12pt in 188pt. **Both need a short wrist variant**, which under the project's copy standard means new keys in `Common/Copy/Copy+Home.swift` resolving through Remote Config, plus **[NEW-FIELD]** `actionReasonShort: String` capped at about 22 characters. Rendering `actionDetail` as-is, which is what "this concept is its first consumer" implies, would truncate on the first day.

Note also that the two nights numbers in the reason line are different things and must not be conflated: **5** is how many nights the balance accumulated across (from the shared user brief), while `SleepDebtTracker.nightsToClear(4.33) = 6` is how many early nights clear it. The prototype renders `4h 20m behind, 5 nights`, the accumulation window.

### The offline-completion invariant

Today `WatchStore.markActionDone()` sends a command, and `WatchRootView` disables the button on `store.isActionDoneToday || !store.pendingCommands.isEmpty` — while `WatchStore`'s own comment admits a lost answer leaves the command pending until relaunch. **This concept cannot ship on that behaviour**, because its one action would be dead whenever the phone is away.

Required: the wrist writes `closed` into the watch App Group cache immediately, renders closed, fires `.success`, and reconciles when the `WatchCommandResult` arrives. The button is disabled only by `closed`, never by `pendingCommands`. On rejection the cache reverts and `.failure` fires. This is watch-side work and it is small.

### Complication refresh economics — the concept's quiet advantage

R4 caps a watch app at ~4 background refresh tasks per hour shared across all its complications on the active face, plus 40–70 WidgetKit reloads/day at ≥5-minute entry spacing (**A** — https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date, https://developer.apple.com/documentation/watchkit/wkapplicationrefreshbackgroundtask).

A Class B mission needs **zero** background refreshes. `missionTarget` is a fixed future `Date`, so the `TimelineProvider` emits a full day of entries at 15-minute spacing in one pass — ~90 entries, inside the reload budget and well above the 5-minute floor — and the ring is correct for 24 hours from a single phone push. A Class A mission needs watch HealthKit reads, which are cheap and local.

**No other concept in this set can claim that**, and it also makes this concept immune to the Bevel watch-disagrees-with-phone bug class (https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match), because the number the ring encodes is not a phone-computed score.

### Effort, honestly

New completion store (**days**, and it is a prerequisite for everything) · `missionTarget` / `missionWindow` / `missionKind` + payload versioning (**1–2 days**) · machine-readable Class A targets out of the advisor (**2–4 days, the riskiest piece**) · chain fields and `pauseChain` command (**1–2 days**) · HealthKit on the watch target, entitlement, usage description, and the widget extension's matching permission for `RelevantContext.sleep(.bedtime)` (**3–5 days plus a new App Store health-permission surface**) · Smart Stack widget with an `AppIntent` button (**2–3 days**) · notifications scheduled on the wrist (**2 days**) · the app itself (**3–4 days**).

---

## 15. Honest drawbacks, and who this design fails

### 1. The chain measures compliance, not recovery — and this concept's own hero data proves it

The research states it flatly: *"a streak rewards wearing and opening, not recovering."* Look at what this spec renders. **Alex has a 12-day chain, 4h 20m of growing sleep debt, a bedtime that has drifted 40 minutes later this week, and a resting HR 3 bpm above baseline.** The chain is intact and the body is worse. Every mitigation in the design — rest days counting, no red, free pauses, no loss-aversion push — reduces the *guilt* the chain can generate. **None of them fix the measurement.** A user can hold a 200-day chain and be less healthy than when they started.

### 2. One job a day is wrong on the days that need two, and condescending on the days that need none

Alex on Tuesday has a bedtime problem *and* a strain deficit (6.2 against an 8–12 target). The concept can show only one. On a day where the honest answer is "nothing, you are fine", the advisor's ladder still produces a mission — see drawback 7.

### 3. The goal gradient works within the day and weakens badly across days

Kivetz's acceleration is proportional to *remaining distance* and **resets once the reward is earned**. The within-day arc has a real gradient. The next distance after closing — `7 to your longest` — shrinks by exactly 1 per day, which is a very shallow gradient by comparison. That is the honest limit of the post-completion fix: the design keeps *a* distance visible, but it is a weak one.

### 4. A bedtime mission cannot be closed for seven hours

From 14:32 the primary action is `Remind me at 21:35`, not `Done`. A user who opens at 15:00, 16:30 and 18:00 finds nothing to do three times in a row. For a concept whose engagement thesis rests on mechanic #1, a slowly ticking Class B countdown is dynamic in the technical sense and boring in the felt sense. Class A missions do not have this problem; Class B ones — bedtime, caffeine cutoff, meal timing — do, and they are a large share of what the advisor produces.

### 5. The target Alex is given is a 2h 13m bedtime jump, and it is a real product bug this design exposes

`paybackExtraMinutes = 45` on a 7h 40m need against a 07:00 wake yields **22:35**. Alex went to bed at **00:48**. Asking for a 2h 13m shift on night one is asking for a failure, and a failure on night one of a chain feature breaks the chain on day one. **The builder must cap the nightly ask** — something like 30 minutes earlier than the 7-day median bedtime — before this ships. The number is arithmetically correct and behaviourally wrong, and the chain UI makes that wrongness expensive in a way the phone card never did.

### 6. Who this design fails

- **Shift workers, new parents, frequent travellers.** A daily job with a fixed window assumes a stable day. Pause helps and does not solve it.
- **Anyone with a history of disordered exercise or eating.** Gentler Streak exists specifically because streak mechanics are dangerous for this group, and the entire mitigation set here is borrowed from them. It is harm reduction, not harm elimination.
- **People who do not want to be told what to do.** There is no browse mode, no data, no "just show me my numbers". If the mission is wrong, there is nothing else on the wrist.
- **Anyone whose recovery genuinely needs a week of nothing.** Pause caps at 14 days and the chain then holds indefinitely, but the product's whole shape still says "you should be doing something".
- **Colour-blind and low-vision users are explicitly served** — see the shape table in §6. One of the few groups this design does not fail.

### 7. The strongest argument against this concept

**It stakes the entire product on the weakest part of an existing ladder.**

`DashboardSmartActionAdvisor.recommend()` is an eight-step fallback chain. Steps 0, 0b and 1 are good: a user-set rest context, a growing sleep balance, and the ML policy engine at confidence ≥ 0.3. Steps 2 through 7 degrade — insight-driven, live-data rules, focus rules, activity progress, late-hour wind-down — and step 8 is a hardcoded default with the icon `figure.walk` and the title *"Get moving for 15 minutes"*.

On any day where the policy engine is under-confident and no insight clears the bar, the "mission" is a generic walk suggestion. This concept then renders that generic suggestion as **the one job of the day**, awards a chain link for closing it, and pushes a notification about it. **A chain built on the fallback default is a chain of fake accomplishments**, and principle 17 applies at full force: a verdict that contradicts felt state is worse than no verdict. DC Rainmaker's WHOOP critique is exactly this failure — an 80% recovery score after 3h 15m of sleep (https://www.dcrainmaker.com/2021/11/whoop-platform-review.html) — and a mission has the same failure mode with added moral weight, because the user did what they were told and it did not matter.

The dashboard card survives a mediocre suggestion because it is one card among many. **A wrist app that is only that suggestion cannot.** Before this concept is worth building, the advisor's steps 4–8 have to be good enough to bet a product on, or step 8 has to produce an honest `No mission today` instead of a walk. That is a phone-side change, not a watch-side one, and it is the first thing the builder should raise.

---

## 16. The 5-second test, per screen

Median smartwatch session is exactly **5.0 seconds**, at ~28cm and ~10° off line-of-sight (https://www.kostakos.org/papers/chi17.pdf, https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf). The failures are named, not hidden.

| Screen / state | Verdict | Reasoning |
|---|---|---|
| **S1 — closed** | **PASS**, the strongest state in the design | Full 360° sweep plus a checkmark. Answers "have I done my thing" pre-attentively at ~0.2s. Nothing to read at all. |
| **S1 — open, Class B (Alex, 14:32)** | **PASS for the decision, FAIL for the detail** | The partial ring says "not done" instantly. But knowing *what* the mission is requires reading `Get to bed early`, and knowing *when* requires parsing `22:35` in a 22pt numeral off-axis. Pass/fail in under a second; "what do I do" takes ~2.5s. The ring alone does not carry the job. |
| **S1 — open, Class A (e.g. 4 of 8 glasses)** | **PASS** | Ring fill plus a single fraction is the best case for this layout. |
| **S1 — cold start** | **FAIL** | `First mission in 3 nights` is a sentence, and an hourglass in an empty ring says "nothing here" without saying why or when. **There is no glyph that encodes "3 nights".** This cannot be fixed within the layout; it is the honest cost of naming the cold start instead of faking a number. |
| **S1 — empty (no mission today)** | **FAIL** | The same shape as the cold start with a different meaning, and the only thing distinguishing them is prose. A user who sees `circle.dashed` twice in a month will not remember which state it was. |
| **S1 — Always-On redacted** | **PASS as redaction, FAIL as information** | By design and by R7. The user learns the app is present and that the layout has not moved. They learn nothing else, which is exactly the requirement. |
| **S1 — stale** | **PASS** | The arc is clock- or sensor-driven and can never be stale; one short line changes and it states the age. |
| **S1 — error, not synced** | **PASS** | Button state plus one short line. The mission is still closable, which is the decision the user came for. |
| **S1 — error, rejected** | **PASS**, narrowly | `Not saved. Tap to try again.` is 6 words and the button is already under the thumb. |
| **S1 — Health access denied (Class A only)** | **BORDERLINE** | An empty ring plus `Progress needs Health access` is a sentence, and the fix is a permission sheet — a slow interaction by nature. Class B missions are unaffected. |
| **S2 — Chain** | **PASS for "is my chain intact", FAIL for "how close am I to my best"** | The 7-bar strip is a bar chart, read in **159–285ms**. The next-distance line is prose and takes ~2s. The split is deliberate: intactness is the glance, distance is the visit. |
| **S3 — Pause** | **FAIL, and it must** | Pausing a 12-day chain is a decision, not a glance. If a user could pause in 5 seconds they could pause by accident. Two deliberate taps plus a crown turn is the correct friction. |
| **`accessoryCircular` complication** | **PASS** | Ring plus checkmark, no text to parse. |
| **`accessoryRectangular` complication** | **PASS for the strip, BORDERLINE for row 1** | Three rows of 13–15pt text at 28cm off-axis is at the edge of what the family supports. Row 1 will truncate for long mission verbs, and the builder must test the **longest** string the advisor can emit — *"Go to bed 30 minutes earlier tonight"* — not the shortest. |
| **Smart Stack widget — out of window** | **PASS** | Three rows, one of which is a bar chart. |
| **Smart Stack widget — in window** | **PASS** | The 42pt Done button is the largest element on the card and it is the only action. |

**Two hard fails, two borderlines, and three split verdicts.** The cold-start and empty states are the weak point of this concept and no amount of layout work rescues them, because the honest content of both is "there is nothing to do yet" — and that is a sentence, not a shape.

---

## Deviations from the approved spec, and why

1. **Arc geometry.** `DESIGN-TOKENS.md` specifies the open-gap arc as *"270° sweep, 45° gap at the bottom"*, and 270 + 45 ≠ 360. The 270° figure is load-bearing because the fill arithmetic is quoted as "64% of the 270°", so the prototype draws a **270° track with the gap centred at the bottom, which makes the gap 90°**. The fill starts at the track's own start point rather than at 12 o'clock, because a fill that starts at 12 on an open-gap arc leaves a dead segment that reads as data. Closed still renders as a full, unbroken 360° ring, which keeps "closed" a distinct shape.
2. **The chain count is dropped at 40mm.** The spec's own 40mm arithmetic — 7×16 + 6×5 = 142pt of bars in 146pt of content — leaves 4pt, which cannot hold a numeral. The count is dropped and lives on Screen 2, matching the way the reason line is dropped at the same size.
3. **The prototype does not simulate Dynamic Type.** The spec's AX1/AX2 behaviour (arc 96→84, 7 bars → 5 at AX2, `Remind me at 21:35` → `Remind me`) is documented but not togglable, because the dev toolbar list in `PROTOTYPE-SPEC.md` does not include a type-size control and adding one would not be judged.
4. **Swipe-from-left back is a nav chevron plus the Escape key.** A pointer-drag gesture would be prototype plumbing that tests nothing about the design.

---

Confidence: 84/100 — the prototype was verified by extracting its script and running all 3456 combinations of size × screen × state × variant × Always-On × crown value through a DOM stub with zero errors, plus assertions that Alex's values render, that closing increments the chain to 13 and the distance to `6 to your longest`, that Always-On leaks none of `22:35` / `Get to bed early` / `4h 20m`, that 40mm drops the reason line, that no button is ever nested inside another, and that the banned string appears nowhere; the codebase claims in §14 were re-read from source this session (`DashboardSmartActionAdvisor.swift:50-121`, `SleepDebtTracker.swift:40-55`, `DailyActionCompletion.swift:14-41`, `Copy+Home.swift:107-118`, `WatchBridge.swift:1-60`) and every citation was copied from `research/`, never recalled. Held below 90 because **the layout has never been rendered in a browser or on hardware** — the 247pt/193pt/208pt/186pt column totals and the 42×42pt widget button are hand-computed against Apple's point tables and Apple publishes no Smart Stack row for 42mm or 46mm; the `actionDetail` fit at 12pt in 188pt is asserted, not measured; the chain values 12 and 19 are this concept's own invented product state rather than data from the shared user brief; and the `RelevantContext.sleep(.bedtime)` dual-permission requirement is taken from Apple's prose and has never been compiled. | Source: mixed: code+internet (repo source read this session + the research files in this repo) + a headless render harness run this session
