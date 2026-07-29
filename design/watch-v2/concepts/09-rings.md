# Concept 09 — Fourth Ring (`rings`)

Prototype: [`09-rings.html`](09-rings.html) · design target 46mm (208 × 248 pt), floor 40mm (162 × 197 pt) · shared user Alex, Tuesday 14:32.

> **Read this first.** The concept is called Fourth Ring. **The shipped element is not a ring.** It is a
> *ceiling*: Apple's Move-ring axis unrolled into a horizontal bar with a notch marking where today's
> recovery says the wise amount stops. No fourth arc is drawn anywhere, in any surface, in any state, and
> Laso ships **no rings complication in any family**. The four reasons are in §1.

---

## 1. One-sentence philosophy

**Apple's three rings tell you how far you are from your goal; Laso tells you whether that goal is a good idea today.**

### Why the fourth thing is a bar and not a ring

Four arguments, and the fourth is fatal:

1. **The tokens forbid it.** "Never put two rings on one screen. Two rings is a comparison rendered in the slowest possible encoding" (`DESIGN-TOKENS.md`, Gauges).
2. **Measurement forbids it.** Correct comparison of two values: bar `159–285 ms`, radial bar `1548–1772 ms`, against a 5.0 s median session — 6–10× the cost ([InfoVis 2018](https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf) · [CHI 2017](https://www.kostakos.org/papers/chi17.pdf)). Principle 6, mechanic #4, anti-pattern #5. **Evidence: A.**
3. **Apple forbids it.** "The Activity rings view is an Apple-designed element… Use them only for their documented purpose." The research file records this quote **without a source URL** (`research/apple-hig.md:340`), so it is cited to the file line, not to an invented Apple page. **Evidence: A for the quote, unattributed for the URL.**
4. **The mental model forbids it.** A ring means *"fill me to 100%."* Recovery is not a thing to fill. A recovery ring at 62 reads as "38% still to go" — an instruction to chase 100% recovery, which is advice nobody should follow, and it manufactures exactly the guilt spiral flagged in `02-CONCEPT-SET.md` (07/09 vs 02).

The tokens prescribe a **horizontal band with a marker** for "position inside a target range". That is the Ceiling, exactly.

---

## 2. The question it answers first

**"Have I moved enough, and can I afford more?"**

The two halves map precisely onto the data split in `PROTOTYPE-SPEC.md`:

| Half of the question | Answered by | Source |
|---|---|---|
| *Have I moved enough?* | Apple's Activity rings | **NATIVE** `HKActivitySummary` — instant, live, correct with the phone in another room |
| *Can I afford more?* | The Ceiling | **PHONE** verdict, cached, changes a few times a day |

That is why this concept structurally never needs to say "open your phone": the half that must be instant is native, and the half that is cached changes slowly enough that a stale value is still true. The banned string appears nowhere in the prototype (verified by grep) and there is no state in which it would be needed.

The question was chosen because it is the only one where Laso can be **additive rather than competitive**. Apple already answers half of it, perfectly, on hardware Laso cannot beat. Nobody has ever answered the other half on the same axis.

---

## 3. Screen-by-screen reasoning

Four screens. Two are pages of a vertical `TabView`; two are pushed. **Max depth 1.**
`NavigationStack { TabView(.verticalPage) { S1; S2 } }` — the stack wraps the tabs, so pushing S3 fully replaces the paged container (this is what makes the Double Tap on S3 legal, §5).

### The Ceiling bar — construction, because it is the concept

Left edge = 0 kcal. Right edge = the user's standing Move goal (620). **Same axis, same units, no new scale.** This is what "borrow the mental model" means in practice, and it is why anti-pattern #12 (multiple incompatible scales) never bites: **the 0–21 strain scale never touches the wrist.**

Layers, back to front:

| Layer | What it encodes | Non-colour channel |
|---|---|---|
| Track, `surfaceSubtle` | the axis | — |
| Over-ceiling zone, 45° hatch 1pt/4pt in `borderLow` | beyond today's wise amount | **texture** |
| Headroom zone, band colour @ 22% | what is left that is wise | length |
| Progress fill, `textSecondary` — **deliberately neutral** | how far you have moved: a fact, not a verdict | length |
| Cap mark, 3pt × 22pt, band colour | the ceiling | position |
| **Cap notch**, 7 × 6pt triangle | the ceiling | **shape at a position** |

For Alex: progress `284/620 = 45.8%` → 86.1pt at 46mm (verified in the running prototype), cap flush right at 100%, over-ceiling zone zero-width, headroom 336 kcal in amber @22%.

Band colour comes from `readinessScore` through the **shipping** thresholds (`DesignSystem.recoveryTier`, `optimalFloor = 67` / `fairFloor = 45`, verified at `Common/Components/DesignSystem.swift:189-200`). Alex 62 → `fair #E3B45A`.

### S1 — Today *(entry, page 1 of 2, does not scroll)*

**The one decision: do I move more in the next hour, or not?**

| Element | Why it is there |
|---|---|
| Status row: `"Today"` + freshness chip (`● 6m`) | Freshness is carried by **dot shape** — filled when fresh, hollow 1pt ring when stale. Never by colour (R18). Principle 12: say the quiet part out loud. |
| Apple's Activity rings, 92pt | Apple's element, Apple's colours, Apple's geometry. No arc added, nothing tinted, nothing restyled. This is the half of the question Laso must not touch. |
| The Ceiling bar, 188 × 14pt | The other half, on the same axis. |
| Verdict line, `body` 16 | An **imperative**, never a bucket name (principle 4): "Room to close them." — not "Moderate Readiness". |
| Sub-line, `caption` 12 | "Ceiling: full goal · recovery 62". The number is context, not the carrier. |
| One button, 188 × 44 | Verdict at 0 taps, action at 1 (principle 14). |

**4 text lines** (status, verdict, sub, button label); **3 at 40mm**, where the sub-line is dropped.

A user who reads nothing still gets the decision: ring sweep + fill length vs notch position are both pre-attentive.

### S2 — Ceiling *(page 2 of 2, crown-down, does not scroll)*

**The one decision: do I trust this ceiling enough to obey it?**

Three rows — Recovery 62 ↓, Sleep 6h 12m ↓, Resting HR 58 ↑ — each with a bar and a **baseline tick** (7-day recovery average 68, sleep need 7h 40m, RHR baseline 55). The heading dot is a legend: a row carrying **●** is phone-computed; a row without it is read by this watch. The `↑ ↓` arrows are the non-colour direction carriers.

Footer: **"Updates about 4 times an hour."** Published in-product, copied from [Athlytic](https://athlytic.github.io/athlyticapp/troubleshooting/), whose absence in [Bevel](https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match) produced a live public "watch disagrees with phone" bug thread.

Rows are **not interactive**. There is nothing to drill into, so the tap-target rule never applies and the shipping check-in's 5-targets-in-162pt mistake cannot recur.

Neither page scrolls, so vertical pagination is never broken by a scrolling detail view ([HIG: Tab views](https://developer.apple.com/design/human-interface-guidelines/tab-views), anti-pattern #14).

### S3 — Move *(pushed, depth 1)*

**The one decision: how long?** Title (crown-driven, tabular), one sub-line, a 6-dot duration rail where **position** carries the value, one 56pt Start button, one hint. The crown is the only value input in the app — 5–30 min in 5-minute steps, `.click` per detent, `digitalCrownAccessory` at the crown edge. Anything finer than 3 choices uses the crown, not more buttons (tokens, Tap targets).

### S4 — Walking *(pushed, replaces S3)*

**The one decision: stop now or keep going?** This is the only screen where the thesis becomes physical: **the ceiling is enforced, not just displayed.** Elapsed at 52pt, live HR, and the same Ceiling bar filling live from the workout builder's active energy. Cross the cap and `.directionUp` fires once.

**The crown is disabled here** and no haptic fires except at the two session boundaries — R8, §11.

---

## 4. Why this works on a watch specifically

- **The rings only exist here.** The whole concept is parasitic on an element that lives on the wrist and nowhere else. On a phone there is no Activity ring in peripheral vision, no Activity complication to sit beside, and no reason to express a recovery verdict in Move-kcal.
- **The verdict must arrive where the decision is made.** "Can I afford this session" is asked while standing up, in a corridor, before a class — not while sitting with a phone open.
- **The headroom number moves all day, natively.** `ceiling − todayMove` changes every time the user walks, with no phone involvement, which is the one thing a checking habit requires (mechanic #1) and the one thing the phone dashboard cannot do at zero access cost.
- **What would be worse on a phone:** the ceiling as a fraction of a Move goal is only legible next to the rings themselves. On a phone it would need a legend, an axis label and an explanation — three things that would make it a chart instead of a glance.
- **What is worse on the watch, honestly:** the "why" (S2) is cramped and slow here and genuinely belongs on the phone. It exists on the wrist only to stop the black-box criticism.

---

## 5. watchOS HIG guidance applied

Every URL below appears in `research/apple-hig.md` or `research/00-SYNTHESIS.md`. Nothing is invented.

| Rule | Applied as | Source |
|---|---|---|
| **R1** Interactions are seconds | 4 text lines on S1, one decision per screen, no screen scrolls | https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos · https://developer.apple.com/documentation/watchos-apps |
| **R2** The app is not the product | 3 complications + 1 Smart Stack widget carry the value; expected app opens are honestly ~2.2/day (§13) | https://developer.apple.com/documentation/watchos-apps |
| **R3** Only 2 families reach the Smart Stack | One `accessoryRectangular` widget, no circular duplicate; Inline is face-only | https://developer.apple.com/design/human-interface-guidelines/widgets · https://developer.apple.com/documentation/widgetkit/widgetfamily/accessoryinline |
| **R4/R5** ~4 updates/hour, never real-time | Published in-product on S2; the freshness dot changes shape at 60 min | https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date |
| **R6** Watch HealthKit reaches back ~7 days | Every baseline (7-day recovery average, sleep need, RHR baseline) is a phone field, never computed on the wrist | https://athlytic.github.io/athlyticapp/troubleshooting/ |
| **R7** Health data redacted in Always-On | Bar → outline, verdict → `———`, rings kept but monochrome and stroked; layout positionally identical | https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state · https://developer.apple.com/documentation/swiftui/environmentvalues/isluminancereduced |
| **R8** No haptic while sampling HR | Crown disabled on S4; boundary haptics only | https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:) |
| **R10** Crown is navigation | Crown pages S1 ↔ S2; crown press never handled | https://developer.apple.com/design/human-interface-guidelines/digital-crown · https://developer.apple.com/design/human-interface-guidelines/page-controls |
| **R11** Double Tap conflicts with lists/scroll/vertical tabs | `.primaryAction` on S3 only — the one screen with no list, no scroll view, no vertical tab | https://developer.apple.com/design/human-interface-guidelines/gestures · https://developer.apple.com/documentation/swiftui/view/handgestureshortcut(_:isenabled:) |
| **R12** Relevance is a different API on watchOS | `TimelineProvider.relevance()` → `WidgetRelevance`; `TimelineEntry.relevance` never written | https://developer.apple.com/documentation/widgetkit/widget-suggestions-in-smart-stacks · https://developer.apple.com/documentation/relevancekit/relevantcontext |
| **R13** No spinners | Loading = rings at full fidelity + a bare bar track. There is no spinner in any state | https://developer.apple.com/design/human-interface-guidelines/feedback |
| **R14** Static surfaces get deleted; one deep link each | Headroom moves all day; three complications, three deep links | https://developer.apple.com/design/human-interface-guidelines/widgets |
| **R15** Sizes, type, touch floors | 152 × 69.5pt widget; complication text 10.5–19.5pt; every target ≥ 44 × 44pt; min line width 2pt | https://developer.apple.com/design/human-interface-guidelines/widgets · https://developer.apple.com/design/human-interface-guidelines/accessibility · https://developer.apple.com/design/human-interface-guidelines/layout |
| **R16** Frontmost app lives ~2 min after wrist drop | Wrist-raise return inside that window snaps values: no sweep, no count-up (demonstrated in the strip) | https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state |
| **R17** Short look is not a channel | No notification title contains a health value; ≤ 2 actions; Double Tap takes the first nondestructive one | https://developer.apple.com/design/human-interface-guidelines/notifications |
| **R18** Colour alone never carries meaning | Notch, hatch, arrows, hollow dot, rail position, and the sentence | https://developer.apple.com/design/human-interface-guidelines/widgets |
| No full-screen colour in long-lived views | S4 stays black behind the workout | https://developer.apple.com/design/human-interface-guidelines/color |
| Complication point sizes stated twice in Apple's tables ("42x42 pt (84x84 px @2x)") | Circular designed to a 42 × 42pt content box | https://developer.apple.com/design/human-interface-guidelines/complications |
| WidgetKit is mandatory for complications | "As soon as you offer a widget-based complication, the system stops calling ClockKit APIs" | https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications |
| VoiceOver on infographics | "provide a concise description of each infographic that explains what it conveys" — the bar is one element with one sentence | https://developer.apple.com/design/human-interface-guidelines/voiceover |
| **Activity rings are restricted** | Laso never draws them and never adds to them | `research/apple-hig.md:340` (no URL recorded) |

---

## 6. UX principles used, and the mechanism

| Principle | Mechanism here | Evidence |
|---|---|---|
| **9 — Borrow an existing mental model** | The ceiling is expressed in the user's own Move-kcal goal. Zero new scales, zero new vocabulary. | **B/C** https://the5krunner.com/garmin-features/sleep/body-battery/ |
| **6 — Bars, not rings, for comparisons** | The whole concept turns on this. 159–285 ms vs 1548–1772 ms. | **Strong / A** https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf |
| **4 — Imperative, not description** | "Room to close them." / "Ease off. Stop at the mark." Never "Moderate Readiness". Missing guidance — not missing data — is the most consistent criticism across the competitive set. | **A/B** https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html |
| **3 — Never ship a bare number** | The headroom number always sits inside a bar with a cap, or under a sentence. | **A/B** https://support.google.com/fitbit/answer/14236710?hl=en |
| **10 — Progressive disclosure of "why"** | Glance (S1) → factors (S2). S2 exists solely to kill "the scores are a black box". | **B** https://www.dcrainmaker.com/2021/11/fitbit-readiness-review.html · https://athlytic.github.io/athlyticapp/troubleshooting/ |
| **11 — Name the cold start, never fabricate** | "No ceiling yet. Needs {n} nights. {m} done." — and `{n}` comes from the phone, never hardcoded. | **B** https://support.google.com/fitbit/answer/14236710?hl=en |
| **12 — Publish the staleness rule in-product** | S2 footer, permanently. | **B** https://athlytic.github.io/athlyticapp/troubleshooting/ · https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match |
| **14 — One action on the verdict screen** | Exactly one button on S1; the inline complication is one tap from the walk. | **B** https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface |
| **16 — Tiny reused colour system, never load-bearing alone** | Three band colours, reused identically on bar, cap, gauge and widget; every meaning has a second channel. | **A/B** https://developer.apple.com/design/human-interface-guidelines/widgets |
| **17 — A score that contradicts felt state is worse than no score** | Drives the `"Lift it for today"` override. | **B/C** https://www.dcrainmaker.com/2021/11/whoop-platform-review.html |
| **Anti-pattern 12 — incompatible scales** | 0–21 strain never reaches the wrist. | **B** https://developer.whoop.com/docs/whoop-101/ |

---

## 7. Psychological principles that drive repeat opens

| # | Mechanic | Evidence strength | How it is used — and its limit |
|---|---|---|---|
| 1 | **Dynamic content at near-zero access cost** | **strong: peer-reviewed** — checking habits require "brief, repetitive inspection of dynamic content quickly accessible on the device"; 82.3% of watch sessions self-initiated ([Oulasvirta](https://link.springer.com/article/10.1007/s00779-011-0412-2) · [CHI 2017](https://www.kostakos.org/papers/chi17.pdf)) | Headroom = `ceiling − todayMove`, and `todayMove` is native and live. The number moves all day without the phone doing anything. **Limit:** for a sedentary user it barely moves — §15.5. |
| 2 | **Surviving the first 8 days** | **strong: peer-reviewed** — >50% discontinue in week 1; those alive at day 8 gain +25 days median ([arXiv 1910.01165](https://arxiv.org/pdf/1910.01165)) | **This concept's strongest structural asset: it is useful on day 1 with no baseline at all**, because the rings are native. Cold start names itself and still ships a real screen. |
| 3 | **Goal gradient** | **strong: peer-reviewed** — 20% acceleration near a goal, 16% faster completion, effort resets once earned ([Kivetz et al.](https://home.uchicago.edu/ourminsky/Goal-Gradient_Illusionary_Goal_Progress.pdf)) | The Ceiling is a **second, closer threshold**, so a visible distance still exists on days the Move ring is already closed. The same paper's failure mode is why: once the reward is earned, motivation collapses unless a new distance is visible. |
| 4 | **Bar/donut over radial** | **strong: peer-reviewed** ([InfoVis 2018](https://www.microsoft.com/en-us/research/wp-content/uploads/2018/08/GlanceableVis-InfoVis2018.pdf)) | The entire encoding choice. |
| 5 | **Uncertainty about the outcome** | **strong mechanism, inferred application** — anticipatory dopamine maximal at P = 0.5 ([PubMed 12649484](https://pubmed.ncbi.nlm.nih.gov/12649484/)) | Headroom is genuinely unpredictable between glances because Move accrues continuously. **No fake variance is manufactured** — the number is always true. |
| 6 | **Push the verdict at wake** | **medium: vendor data** — Garmin's Morning Report is unprompted, one press, user-ordered; no published effect size ([Garmin](https://www8.garmin.com/manuals/webhelp/GUID-0221611A-992D-495E-8DED-1DD448F7A066/EN-US/GUID-4D26FDDC-63BD-4910-95B8-98937FEC2545.html)) | N1 + the `RelevantContext.sleep(_:)` relevance window. |
| 7 | **Delta-triggered notifications** | **strong: peer-reviewed** — 3.5× next-hour lift, 1.04–1.3× at 24 h, **no long-term retention effect**, 9.4% yield ([Bell et al. 2023](https://researchonline.lshtm.ac.uk/id/eprint/4670198/1/Bell-etal-2023-How-notifications-affect-engagement-with.pdf)) | Max 2/day, every one fires on a change or a crossing. Notifications buy an open now, never a habit — so they are budgeted, not leaned on. |
| 9 | **Resumption cue** | **mixed — half is dead.** Ovsiankina resumption replicates; **Zeigarnik memory does not** ([2025 meta-analysis](https://www.nature.com/articles/s41599-025-05000-w)) | An unclosed ring with visible headroom is a resumption cue. It is justified **only** on the reliable half; nothing here claims the unfinished thing is more memorable. |

**Deliberately not used:** mechanic #8 streaks (Duolingo's +14% D7 is real — https://blog.duolingo.com/how-streaks-keep-duolingo-learners-committed-to-their-language-goals/ — but a streak rewards *wearing and opening*, not *recovering*, and this concept already carries enough completion pressure); mechanic #10 social comparison (**weak**, no verified watch implementation exists in the research); mechanic #11 committed measurement session (nothing here needs stillness).

---

## 8. Complication strategy

Three WidgetKit kinds, three families, **three distinct deep links**, each its own `Widget` struct so `widgetURL` differs per family (R14/R15, anti-pattern #15).

| Family | Name | Shows | Deep link |
|---|---|---|---|
| `accessoryCircular` | **Headroom** | Gauge on the same axis as the bar, 4pt stroke, band-coloured fill, **radial ceiling tick outside the stroke**; centre = `336` (kcal to ceiling); `widgetLabel "to ceiling"` | `laso-watch://today` |
| `accessoryRectangular` | **Day** | Headline · Ceiling bar 152 × 10pt · `284/620 kcal · 12 of 30 min` · `● iPhone 6m` | `laso-watch://ceiling` |
| `accessoryInline` | **Verdict** | `arrow.up.forward` + "Room to close them" (18 chars, hard-capped at 22 for curved faces); one tap target only | `laso-watch://move` |

**`accessoryCorner` is deliberately not shipped:** its signature is a curved gauge — a fourth radial encoding on a face that already carries the rings — and there is nothing distinct left to say in it. Shipping a fourth kind for coverage is how you end up with a shared deep link.

**Laso ships no rings complication in any family, ever.** It would be a strictly worse copy of Apple's: capped at ~4 updates/hour (R4/R5) against a system-live original, and misuse of a restricted Apple element.

### Why a user would give up a face slot — the honest answer

**They would not give up the Activity complication, and they must not be asked to.** Laso takes a *secondary* slot beside it.

1. **Apple's Activity complication answers "how far to my goal". It has never answered "is that goal a good idea today."** The Laso circular is the only element on the face whose **ceiling notch moves when the user's body changes**. That is a genuinely new sentence on a crowded face.
2. **It is dynamic**, which is what keeps complications alive (R14: "A static complication that doesn't display meaningful data may be less likely to remain in a prominent position").
3. **It is never blank.** With no phone payload the ceiling falls back to the standing Move goal and the centre still shows a true native number. The `--` state — the shipping app's worst failure — is structurally impossible.

**The admission:** if the user has no Activity complication and does not think in rings, this complication is meaningless to them and they should install a different Laso concept. This design is a parasite on Apple's mental model.

---

## 9. Smart Stack strategy

**One widget, `accessoryRectangular` only.** Only rectangular and circular reach the Smart Stack (R3), and a circular Smart Stack widget would duplicate the face complication with none of the extra room.

Content is byte-identical to the face rectangular (same kind, same `widgetURL`). Inside **152 × 69.5pt**: title 13/600 · Ceiling bar 152 × 10pt · one 12pt data line · one 11pt freshness line — the upper edge of R15's realistic "1 title + 2–3 body lines". At 40mm the prototype merges the freshness line into the data line, because that 11pt line is the first thing that should go. Text is never rasterized.

**Relevance (R12):** `TimelineProvider.relevance()` returning `WidgetRelevance` — **not** `RelevanceConfiguration`, because widgets using it "can't be configured… added to the Smart Stack, or pinned to a fixed location" (`research/apple-hig.md:86`), and earning a permanent place is this concept's whole strategy. `TimelineEntry.relevance` is dead on watchOS and is never written.

| Window | Trigger | Why |
|---|---|---|
| Wake → wake+60 min | `RelevantContext.sleep(_:)` wakeup clue | Mechanic #6 |
| Any hour where headroom > 40% of ceiling **and** `appleExerciseTime` is behind pro-rata pace | `RelevantContext.fitness(_:)` | **The Alex 14:32 moment.** Mechanic #9, Ovsiankina resumption |
| 18:00–20:00 while headroom > 30% | timeline window | The decision point. Mechanic #3, goal gradient |

Timeline refresh: one entry per 15 min, ≥ 5 min apart, aiming at the low end of the 40–70 daily reload budget.

---

## 10. Notification strategy

**Cadence ceiling: max 2 delivered per day, at most 1 before noon, none between 21:30 and wake.** Plus one lifetime message. All individually opt-out.

**Every Laso notification fires on a change or a crossing, never on an absolute state.** Athlytic's absolute-threshold stress alerts drew an explicit user request for "a big friendly toggle to hush stress for a while" because they *increase* anxiety (anti-pattern #3). And notifications buy an open now, not a habit (mechanic #7), so they are budgeted rather than leaned on: 82.3% of watch sessions are self-initiated, which is why the complication — not the push — is this concept's primary surface (anti-pattern #18).

| # | Fires | Short look (no health value, R17) | Long look | Actions |
|---|---|---|---|---|
| **N1 Ceiling moved** | At wake, only if today's ceiling fraction differs from yesterday's by **≥ 0.15**. **For Alex this Tuesday it does not fire** — the ceiling is unchanged. That is correct behaviour and the honest example. | `"Today's ceiling"` | "Ease off today." + the reason + the bar with the cap at the new position | `Got it` *(first, nondestructive → Double Tap)* · `Why` → S2 |
| **N2 Ceiling reached** | The moment active energy crosses the ceiling; once per day. **Suppressed when the ceiling ≥ 95% of goal** so it never duplicates Apple's Move-ring close. | `"Ceiling reached"` | "That's today's ceiling." + "Going further is your call." + the bar filled to the cap | `Got it` · `Lift it for today` |
| **N3 Your ceiling is ready** | Once per lifetime, the first day the baseline completes | `"Your ceiling is ready"` | "Laso can read your day now." | `See it` → S1 |

**N2 is the notification that justifies the concept:** Apple tells you when a ring closes; nothing on the wrist has ever told you when you reached the amount that is *wise*.

**`"Lift it for today"` exists because a ceiling with no override is a rule, and a health app that hands out rules it cannot justify is anti-pattern #4 with a lock on it.** It is the [Gentler Streak](https://docs.gentler.app/using-gentler-streak-on-your-apple-watch/overview-of-the-apple-watch-app-interface) lesson: they ship manual "On a Break / Sick / Injured" states so a user can stop without penalty.

**Not shipped:** no stand reminder (watchOS already fires one at :50 — anti-pattern #1), no streak notification, no "you're behind on your rings" nudge (Apple owns that message and it is the guilt mechanic this concept must not amplify).

---

## 11. Haptic language

Every state-changing tap fires exactly one haptic. Minimum spacing 100 ms. All are rendered in the prototype as an edge pulse plus a caption naming the type.

| Event | `WKHapticType` | Screen |
|---|---|---|
| Crown detent, duration step | `.click` | S3 |
| Tap `Move 10 min` (push) | *(none — navigation, not a state change)* | S1 |
| Page change S1 ↔ S2 | *(none — system page transition)* | S1/S2 |
| Tap or Double Tap `Start` | `.start` | S3 → S4 |
| Session auto-ends / tap `End` | `.stop`, then `.success` **+120 ms** | S4 |
| Move crosses the ceiling while frontmost | `.directionUp` | S1/S4 |
| Ceiling drops a band overnight (opening N1) | `.directionDown` | N1 → S1 |
| Notification arrives | `.notification` (system) | — |
| Phone rejects a queued write (`WatchCommandRejection`) | `.failure` | S1 |

**R8 is a hard constraint on S4.** "When you engage the haptic engine, HealthKit stops gathering heart rate data until after the haptic engine finishes." Therefore: **no haptic anywhere inside S4 except the two session boundaries**, and **the crown is disabled on S4** — its detents would each punch a hole in the HR stream. The prototype demonstrates the refusal: turning the crown on S4 prints the reason instead of moving anything. No mid-session milestone haptics, no per-minute taps, no halfway buzz.

Haptics never fire from the background outside a workout session, so N1/N2 rely on the system notification haptic only.

---

## 12. What was deliberately excluded, and why

| Excluded | Why |
|---|---|
| **A fourth arc, anywhere, in any surface** | §1. This is the concept's defining constraint, not a preference. |
| **Any Laso-drawn Activity rings on a complication** | A strictly worse copy: ~4 updates/hour against a system-live original, plus misuse of a restricted Apple element. |
| **`accessoryCorner`** | A fourth radial encoding on a face that already carries the rings, and nothing distinct left to say. |
| **The 0–21 strain scale on the wrist** | Anti-pattern #12, and it contradicts the concept's own philosophy. The ceiling exists so the user never learns a second scale. |
| **The morning check-in** | Three subjective questions is a 30-second interaction against a 5.0 s median session. Keep it on the phone. |
| **The quick-log list** | The critique's verdict is "kill as a screen", and caffeine and water neither move a ring nor move the ceiling. |
| **The "Today's Action" card** | Replaced entirely. The ceiling *is* the action guidance, in units the user already reads. Shipping both is two verdicts on one wrist. |
| **A stand reminder** | watchOS already fires one. Anti-pattern #1. |
| **A streak** | A streak rewards wearing and opening, not recovering. Gentler Streak's own "On a Break / Sick / Injured" states are the tell. |
| **Any trend chart or history** | Watch HealthKit reaches back ~7 days (R6); the phone owns 60–90. |
| **Live heart rate on S1** | Not an input to today's decision; it would break the 4-line budget. It appears only on S4, where it is the session's own signal. |
| **The `--` state** | Structurally impossible: the rings are native and the ceiling falls back to the standing Move goal. |

---

## 13. Expected opens per day

Counting **app launches only.** Complication glances are not opens, and they are where most of this concept's value lives (R2). Inflating this table would be lying about the design.

| # | Trigger | Time | Mechanism | Opens |
|---|---|---|---|---|
| 1 | Wake — the Smart Stack surfaces the rectangular widget via the sleep clue; on a delta day N1 fires instead | ~07:00 | Mechanic #6. Most days the widget answers without an open — that is the design working | **0.3** |
| 2 | Mid-morning face glance, headroom has visibly moved | ~10:00 | Mechanics #1 + #5. The number is the answer; opening is the exception | **0.2** |
| 3 | **The Alex 14:32 moment** — rings behind pace, headroom large, `fitness` clue fires | 13:30–15:00 | Mechanic #9, Ovsiankina resumption | **0.5** |
| 4 | Pre-workout: "can I afford this session" | 17:30–19:00 | Mechanic #3, goal gradient. **Highest intent**, most likely to end in S3 → S4 | **0.6** |
| 5 | N2 "Ceiling reached" — only on days the ceiling is under 95% of goal | variable | Mechanic #7 at a 9.4% session-yield rate. Does not fire for Alex today | **0.2** |
| 6 | Evening close-out — did I close them, did I overshoot the cap | ~21:30 | Completion pressure + resumption | **0.4** |

**Honest total: ≈ 2.2 app opens per day**, plus roughly **8–15 passive complication reads** and **1–2 Smart Stack surfaces**.

The critique's yardstick ("nothing worth opening once a day, let alone 5–20 times") is met on the **glance** axis and **not** on the **launch** axis. That is deliberate. A design that hits 5–20 launches on a wrist is either lying or forcing the user into a surface where the answer should already have been. If launches are the metric being optimised, this is the wrong concept.

---

## 14. Buildability against this codebase

All facts below were verified by reading the shipping source in this session (commit `cbb674f`, v3.26). **This section is not softened.**

### 14.1 What exists today and can be reused as-is

| Thing | Where | Status |
|---|---|---|
| `readinessScore: Int` | `WatchShared/WatchBridge.swift:61` | **EXISTS** — Alex 62. Used for the band. |
| `updatedAt: Date` + `isStale(now:)` | `WatchBridge.swift:75`, `stalePayloadInterval = 60 * 60` at `:41` | **EXISTS** — drives the freshness dot and the "3h old" tail. |
| `dayKey` | `WatchBridge.swift:58` | **EXISTS** — arms N2 once per day. |
| `WatchPayloadCache` on the App Group `group.com.lasohealth.fit.watch` | `WatchBridge.swift:23,26,~150-163` | **EXISTS** and already backs the shipping complication. Extend the struct, do not build a new mechanism. |
| Band thresholds | `DesignSystem.recoveryTier`, `optimalFloor = 67`, `fairFloor = 45` (`Common/Components/DesignSystem.swift:189-200`) | **EXISTS** — no new threshold table. `readinessGrade` stays unused. |
| WatchConnectivity plumbing, command ledger, rejection type | `Core/Data/PhoneWatchSession.swift`, `WatchBridge.swift` | **EXISTS** — the `.failure` haptic hangs off `WatchCommandRejection`. |

### 14.2 New `WatchPayload` fields

`moveCeilingFraction: Double?` (nil = cold start) · `ceilingHeadline: String` · `ceilingSubline: String` · `readiness7dAvg: Int?` · `sleepNeedMinutes: Int?` · `restingHRBaseline: Int?` · `ceilingReadyNights: Int?`.

The two strings are **resolved on the phone from Firebase Remote Config and shipped finished**. `WatchBridge.swift:7-8` states the constraint outright — *"This file must stay free of UIKit, WidgetKit, HealthKit and Firebase because the watch targets link none of them"* — and that must not change. Do not compose the verdict on the wrist.

Fields this concept does not use and would delete if 09 ships alone: `dayType` (the critique's verdict is Remove), `actionIcon`, `actionHeadline`, `actionDetail`, `actionDone`, `checkInAvailable`, `readinessGrade`.

### 14.3 The three things that do not exist and must be built

**1. HealthKit on both watch targets. It is not there at all.**
- `LasoWatch/LasoWatch.entitlements` contains exactly one key — the App Group. **No `com.apple.developer.healthkit`.** Verified by reading the file.
- `LasoWatch/Info.plist` contains **zero** `NSHealth*` keys. Verified by grep (`grep -c NSHealth` → 0).
- `project.yml` lists both watch targets' sources file by file (`LasoWatch`, `WatchShared`, `Core/Extensions/Date+Extensions.swift`; the widget target the same with `LasoWatchWidgets`). Nothing HealthKit-shaped is linked.
- This concept needs the entitlement, both usage strings (share + update), and the framework on **`LasoWatch` *and* `LasoWatchWidgets`** — the widget extension needs its own HealthKit permission both to read `HKActivitySummary` and for the `RelevantContext` relevance clues (R12).
- `WATCHOS_DEPLOYMENT_TARGET` is **10.0** on both targets. Double Tap (`handGestureShortcut(.primaryAction)`) is a later watchOS API; the target must rise. **I have not verified the exact minimum version** — the research's "Enabling the double-tap gesture" page 404'd — so confirm before planning it.

**2. `moveCeilingFraction` — the load-bearing number, and it does not exist in any form.**
The phone computes strain (6.2 of 21) and its target range (8–12). It must **invert that model into a fraction of the user's own Move-kcal goal**. There is no precedent for this conversion anywhere in the repo and **no published validation for it anywhere in the research**. Everything in this concept rests on this one number. **If the phone cannot honestly convert a strain target into a Move-goal fraction, this concept has no product** — not a degraded product, no product.

**3. `PhoneWatchSession.push()` from the background.**
Verified by grep across the whole repo: the only call site is `Modules/Dashboard/ViewModels/DashboardViewModel.swift:2265`. `App/BackgroundRefreshCoordinator.swift` exists and refreshes the iOS widget but never pushes to the watch. **So today the wrist only updates when the user opens the iPhone app** — that is the root cause of the shipping `--` state, and it must be fixed wherever the iOS widget is refreshed. This concept survives a stale payload (the rings are native), but the ceiling would age badly without it.

### 14.4 What the current complication does wrong that this replaces

`LasoWatchWidgets/ReadinessComplication.swift:18` registers **one** `Widget` with `.supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])`, and **`widgetURL` appears nowhere in the watch widget target** (verified by grep). So today all four families share one destination — anti-pattern #15 — and none of them deep-link at all. Concept 09 replaces that with three separate `Widget` structs and three URLs, and drops Corner.

### 14.5 Build cost, ranked, with the honest cut line

`moveCeilingFraction` (new modelling, no precedent, blocks everything) → HealthKit entitlements + usage strings on both watch targets → `HKWorkoutSession`/`HKLiveWorkoutBuilder` for S3/S4 (largest UI and lifecycle surface, and the only thing needing HealthKit **write** permission) → three widget kinds + relevance → payload changes → notification scheduling.

**If scope must be cut, cut S3/S4 first** and make the S1 button a deep link into Apple's Workout app. That costs one open per day and one principle-14 satisfaction. **The concept survives without the walk. It does not survive without the ceiling.**

### 14.6 Deviations from the approved design spec, and why

Rendered and measured in a real browser at both canvases; these are the places the spec could not be built literally.

1. **Ceiling above the goal (optimal band).** The spec fixes the bar's right edge at the Move goal, but the optimal ceiling is 1.15× the goal, which would place the cap off-canvas. The prototype extends the axis to `max(goal, ceiling)` and draws a 1pt dashed tick at the standing goal. Closest correct thing; the axis is still Move-kcal and still Apple's.
2. **`accessoryCircular` gauge range.** The spec says `Gauge(value: move, in: 0...ceilingKcal)` but simultaneously states the current value is 45.8% (= `284/620`, i.e. move/**goal**) and that the tick "sits short of 12 o'clock" when the ceiling is below goal. Those two cannot both be true. The prototype uses the **bar's** axis so the two Laso surfaces can never disagree with each other.
3. **S1 text block is measured, not fixed at y=152/174.** At 16pt in 188pt, "Ease off. Stop at the mark." needs two lines and "Ceiling: above your goal · recovery 78" needs two more — the spec's fixed y-map collides with the button in the poor and optimal bands. Confirmed by rendering. The prototype measures each string and applies the spec's own §10 drop order: drop the recovery tail → drop the sub-line → let the verdict wrap to 2 lines. **The button is never shrunk and never dropped.**
4. **40mm S1 metrics.** Rings 60pt (spec: 68), bar at y=86 (spec: 100). At the spec's numbers the 2-line verdict overruns the 44pt button inside 197pt. Also, the spec's combined 40mm string "Room to close them. Ceiling: full goal." needs three lines at 16pt in 146pt, so the 40mm verdict stays the plain headline and the sub-line is dropped — which is what the spec's own drop order asks for.
5. **HealthKit-denied state.** The spec says the bar "renders normally"; it cannot. Active energy is exactly what was denied, so the prototype draws the track, headroom, cap and notch with **no progress fill**. Showing a fill there would be fabricated data.
6. **40mm rectangular widget.** The 11pt freshness line merges into the data line rather than being deleted, so freshness survives inside the R15 line budget.
7. **No system clock is drawn on app screens.** watchOS renders it above the content; the spec's y-map starts at y=8 and reproducing both would double-count the space.
8. **Notification long looks scroll** (crown), which is real watchOS behaviour — the second action and Dismiss sit below the fold on the 46mm canvas.
9. **Crown detents.** The prototype fires `.click` manually per integer step. Apple's Digital Crown page says the system already provides **linear haptic detents by default**, and the research could not resolve the `digitalCrownRotation` overload that controls them (`research/apple-hig.md:244`). On device this risks a *double* haptic — verify and, if the default detents fire, delete the manual call rather than adding a second one.

---

## 15. Honest drawbacks, and who this fails

**1. This is a parasite, and it dies with the host.** The design has no standalone value proposition. It is meaningful only to someone who already reads Apple's three rings fluently and already has the Activity complication on their face. For the large cohort who bought an Apple Watch for sleep, HRV and notifications and who have never closed a ring, the whole concept is noise. Strip the rings and nothing is left but a bar with no axis.

**2. Apple can delete this concept in one keynote.** The HIG already restricts the Activity rings element. If a future watchOS makes the Move goal recovery-aware — a small, obvious, widely-predicted feature — this ships as a redundant copy of a system behaviour overnight. Building on Apple's mental model means Apple owns the roadmap.

**3. The ceiling is a model output wearing Apple's clothes.** Converting a strain target of 8–12 into "a fraction of your Move goal" is a phone-side invention with no published validation anywhere in the research. Dressing an unvalidated output in a familiar, trusted unit **increases** the damage when it is wrong, because the user has no cue that they left Apple's data and entered ours. Principle 17 at its sharpest: a ceiling that tells a healthy person to stop at 60% of their goal on a day they feel great destroys trust faster than a wrong recovery number, because it **forbids** rather than describes. `"Lift it for today"` is a mitigation, not a fix.

**4. It adds a second completion pressure on top of Apple's.** On low-recovery days the ceiling *relieves* pressure — its best day. On Alex's fair day it *amplifies*: three rings to close **and** permission to close them, which reads as an instruction. **Who this fails: anyone with a history of compulsive exercise or disordered eating.** The mitigations here are copy-only (no red on a fair day, "Going further is your call", no streak), and copy-only mitigations against a structural incentive are weak. If this ships it needs a real "I'm taking a break" state that suppresses the ceiling entirely, and that is not in this spec.

**5. It goes static for the people who most need it to move.** For a user who routinely closes nothing, headroom sits near the full goal for weeks and the complication reads an almost-constant number — anti-pattern #7, and static complications get removed. The engagement engine only runs for people who are already active.

**6. It breaks for anyone whose Move goal is not a real frame.** Endurance athletes often set an absurd Move goal, or never set one. The ceiling is a fraction of that goal, so the axis is meaningless for them. There is no graceful degradation in this design.

**7. Two clocks that will visibly disagree.** The rings are live and native; the ceiling is capped at ~4 updates/hour. At the moment the user crosses the ceiling, the complication can lag by up to 15 minutes, so N2 and the face will contradict each other. We publish the cap in-product and still eat the confusion — that is [Bevel's live bug thread](https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match) waiting to happen with better documentation.

**8. The strongest single argument against this design.** Its entire value compresses to **one boolean per day**: *is your normal goal a good idea today, yes or no.* A boolean does not need four screens, three complications, a widget, a workout session and seven new payload fields. WHOOP's bet — no display, no watchOS app, no complications, just a haptic when your body is ready ([DC Rainmaker](https://www.dcrainmaker.com/2021/11/whoop-platform-review.html)) — is arguably the *correct* implementation of this exact idea, and this spec is a large surface area wrapped around a single bit. The defence is that Apple's own guidance (R2) sides against WHOOP for an Apple Watch app, and that the bit is worth more attached to the ring the user is already looking at than arriving alone. **That defence is a judgement call, not evidence.**

---

## 16. The 5-second test — per surface, failures shown

Criterion: **can a user reach a decision in under 5 seconds without reading a sentence?**

| Surface | Verdict | Reasoning |
|---|---|---|
| **S1 Today** | **PASS** | Two pre-attentive reads: ring sweep (how far along) and fill length vs notch position (how much is left that's wise). Both are length/position judgements at 159–285 ms. The sentence is confirmation, not the carrier — a user who reads nothing still gets the decision. |
| **S2 Ceiling** | **FAIL — deliberately** | Three labelled rows with baseline ticks and direction arrows is a comparison task. Realistically **8–12 seconds**, not 5. It is reached only by a deliberate crown-down and exists to satisfy principle 10 and kill anti-pattern #4. I will not claim a detail page is glanceable. If a reviewer wants it to pass, the only fix is deleting two of the three rows — and then the black-box criticism returns. |
| **S3 Move** | **PASS** | One number, one button. |
| **S4 Walking** | **PASS** | One 52pt number in the centre; the bar answers "stop or keep going" by position. |
| `accessoryCircular` | **PASS** | Arc sweep + notch + one 3-glyph number. |
| `accessoryRectangular` / Smart Stack | **PASS** | A bar with a cap notch, read at bar speed. The three text lines are optional detail. |
| `accessoryInline` | **BORDERLINE FAIL** | It is a sentence, and a sentence must be read. The family gives one row of text and nothing else, so there is no non-textual channel available. Its only defence is that the sentence is 18 characters. Shipped anyway because its deep link is the fastest verdict→action path in the product. **If a reviewer cuts one complication, cut this one.** |
| **N1 / N2 long look** | **PASS** | An imperative headline with the Ceiling bar under it. The short look alone is not a channel and is not treated as one (R17). |
| **N1 / N2 short look** | **N/A** | By design it carries no decision — no number, no band, no verdict. Passing would be an R17 violation. |
| **Always-On redacted** | **N/A** | It conveys nothing, by design. Passing would be the bug. |
| **Cold start (S1)** | **PASS on the rings, FAIL on the ceiling** | The rings still answer "have I moved enough" in under a second. "Can I afford more" is genuinely unanswerable for 14 nights, and the screen says so in words instead of inventing a number. That failure is honest and unavoidable. |

**Two of eleven surfaces fail, one is borderline, and three are N/A by design.** The two failures are the detail page and the cold-start half-answer. Neither is on the glance path.

---

### Accessibility summary

- **VoiceOver:** the ring group and the Ceiling bar are each **one** element with one written sentence ("Today's ceiling is your full Move goal. You are at 46 percent of it, with 336 calories of headroom."). Reading order is status → rings → ceiling → verdict → recovery → button. Implemented as `role="img"` + `aria-label` throughout the prototype.
- **Meaning without colour (R18):** arc sweep · bar fill length · **cap notch shape** · 45° hatch texture · ↑ ↓ arrows · filled vs hollow freshness dot · dot position in the crown rail · the sentence itself. **Every surface passes a full greyscale render — test it that way.**
- **Tap targets:** exactly three interactive elements exist in the whole app — `Move 10 min` (188 × 44 / 146 × 44), `Start` (188 × 56 / 146 × 52), `End` (188 × 56 / 146 × 48). All ≥ 44 × 44pt, and **there is never more than one target in a row**.
- **Dynamic Type:** drop order on S1 is sub-line → shrink rings → wrap the verdict to 2 lines → never shrink or drop the button. `caption2` at 11pt is used only for meta that is fully restated in the parent's VoiceOver label.
- **Motion:** 600 ms sweep on first appear only; nothing animates on wrist-raise return inside the 2-minute frontmost window; `prefers-reduced-motion` kills the sweep and leaves opacity only.

### How to drive the prototype

Strip along the top switches surfaces. **Mousewheel over the watch, or ↑/↓, is the Digital Crown**; a `.click` marker renders beside the crown when a detent fires. Drag right across the screen, or press ←, to go back (the watchOS edge swipe). The **Dev** button, bottom right, switches canvas (46/40mm), state (loaded, loading, cold start, empty, HealthKit denied, no phone ever, stale), Always-On, the recovery band across all three colours, and fires a simulated Double Tap. Every haptic prints its `WKHapticType` under the watch.

---

**Confidence: 88/100** — every screen, state, band and canvas in the prototype was rendered in a real browser and inspected, all 3,224 render/interaction permutations run without an exception, the Alex geometry was checked numerically (86.1pt fill, 336 kcal headroom, cap flush right), and every buildability claim in §14 was verified by reading `WatchShared/WatchBridge.swift`, `LasoWatch/LasoWatch.entitlements`, `LasoWatch/Info.plist`, `project.yml`, `LasoWatchWidgets/ReadinessComplication.swift`, `Common/Components/DesignSystem.swift` and grepping every `PhoneWatchSession.push` call site in this session. Dragging it down: (a) `moveCeilingFraction` — the concept's load-bearing value — still has no verified derivation from the phone's strain model, only a requirement that one must exist; (b) the exact watchOS minimum for `handGestureShortcut(.primaryAction)` is unverified because Apple's double-tap page 404'd in the research, so the deployment-target bump is a known-unknown; (c) crown detent behaviour is unresolved in the research and the manual `.click` may double up with the system's default linear detents on real hardware; (d) the Activity-rings HIG quote has no source URL in the research file, so the single constraint that turns the fourth ring into a bar is cited to a file line, not to Apple; (e) type metrics in a desktop browser are close to but not identical to SF Compact Rounded on device, so the measured text fitting must be re-checked on hardware. | Source: mixed: code+internet-research-files
