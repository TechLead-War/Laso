# Watch prototype spec — every concept must satisfy this

One concept = one standalone `.html` file plus one `.md` rationale. Nothing else. No build step,
no network.

---

## Hard technical rules

1. **Single file.** Embedded `<style>` and `<script>`. No external libraries, no CDN, no web fonts,
   no remote images.
2. Charts, rings and gauges are hand-built with inline SVG or CSS. No chart library.
3. Icons are inline SVG paths or unicode. No icon font.
4. Works offline opened straight from the filesystem with `file://`.
5. **Dark only.** No light-mode toggle. See `DESIGN-TOKENS.md`.
6. Renders inside a realistic Apple Watch bezel on desktop: rounded rectangle, black bezel,
   Digital Crown and side button drawn on the right edge.
7. Respect `prefers-reduced-motion`.
8. Accessible: real focus states, ≥44pt tap targets, `aria-label` on icon-only controls, text
   contrast ≥ 4.5:1 against `#000`.
9. No `alert()`. No dead links. Every control does something visible.
10. Must work at both canvas sizes (46mm and 40mm) via the dev toolbar.

---

## What the prototype must contain

**The whole experience, launch to every surface — not a screen gallery.**

### A. Off-app surfaces (these come first, because this is where 80% of the value is)

1. **Watch face screen** — a plausible Modular/Infograph-style face showing this concept's
   complications in real slots, with the other slots filled by generic system complications so the
   Laso ones must earn their place visually. Label which family each Laso complication is
   (`accessoryCircular` / `accessoryCorner` / `accessoryInline` / `accessoryRectangular`).
2. **Smart Stack** — the crown-down widget stack, showing this concept's widget(s) in context above
   and below system widgets. Must be scrollable through at least 3 widgets.
   **Only `accessoryRectangular` and `accessoryCircular` reach the Smart Stack** — Corner and Inline
   are watch-face only ([HIG: Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)).
   The widget canvas is `152 × 69.5 pt` at 40mm rising to `191 × 81.5 pt` at 49mm: realistically
   **one title plus two or three body lines**. Design to that box, not to a guess.
3. **Notification** — at least one short-look and one long-look notification for this concept, with
   its actions.

### B. App surfaces

4. **Launch / entry screen** — the first thing on tapping the icon, including the wrist-raise
   "returning to a frontmost app" state.
5. **Every screen of the concept**, navigable in the order the concept intends.
6. **Navigation model made visible** — vertical scroll, `TabView` page dots, or `NavigationStack`
   drill-in. Show it working, do not describe it.

### C. States (togglable from the dev toolbar)

7. **Loading** — first launch, no cache. **No spinner** (HIG: Feedback). Skeleton or last-known
   value only.
8. **Empty / cold start** — new user, no baseline yet. **Name the state, never fabricate a number.**
   Garmin ships "No Status", Fitbit states 7 nights, Oura 14 nights. Do the same: say what is
   missing and when it will be ready.
9. **Error** — phone unreachable, HealthKit denied, sensor unavailable. **The wrist must still say
   something true and useful in this state.** "Open Laso on your iPhone" is a banned string.
10. **Stale** — data older than the freshness horizon, shown honestly without becoming useless.
    Show the age. The wrist *will* disagree with the phone by up to 15 minutes and the design must
    absorb that rather than hide it.
11. **Always-On redacted** — `isLuminanceReduced` treatment, with health values genuinely hidden
    (see `DESIGN-TOKENS.md`). A dimmed-but-readable score is a spec violation, not a nicer choice.

### D. Interactions

12. **Digital Crown** — bind mousewheel and ↑/↓ keys to a visible crown rotation, with a rendered
    crown-detent haptic marker where `.click` would fire. At least one screen must have a genuine
    crown-driven value.
13. **Haptic markers** — a visible pulse plus a caption naming the `WKHapticType` on every
    state-changing interaction.
14. **Press states** — `scale(0.96)`, 80ms.
15. **Double Tap** — show the concept's primary action responding to a simulated Double Tap
    (a labelled button in the dev toolbar is fine).

---

## Dev toolbar

One small unobtrusive button in a corner, opening a panel that can switch:

- canvas size: 46mm / 40mm
- state: loaded / loading / empty / error / stale
- Always-On dimmed: on / off
- the concept's key variable, so a reviewer can see all three colour bands
  (e.g. readiness high / medium / low)
- "fire Double Tap"

It is not part of the design being judged. Keep it visually out of the way.

---

## The one shared fictional user

Every concept renders **the same person on the same day**, so the concepts are comparable.
Numbers on screen must be internally consistent with this and with each other.

> **Alex, 34.** It is **Tuesday 14:32**.
>
> **Recovery / readiness today 62** (yesterday 71, 7-day average 68). Band: fair/amber.
> **HRV 48 ms** last night (7-day avg 54, personal baseline 56 ± 9).
> **Resting HR 58 bpm** (baseline 55, so +3 and elevated).
> **Live HR right now 74 bpm**, sitting. Today's HR has ranged 52-141.
> **Slept 6h 12m** against a 7h 40m need. Deep 52m, REM 1h 04m, awake 22m. Went to bed 00:48,
> woke 07:00. **Sleep debt 4h 20m across 5 nights.** Bedtime has drifted 40 min later this week.
> **Respiratory rate 15.2/min** (baseline 14.6). **SpO2 96%.** **Wrist temp +0.3 °C vs baseline.**
> **Steps 5,240 today** (daily average 8,400). **Exercise 12 min** of a 30 min goal.
> **Stand 6 of 12 hours**, last stood 12:40 — so the stand hour is at risk.
> **Active energy 284 kcal** of a 620 kcal goal.
> **Strain today 6.2 of a 21 scale**; optimal target range for this recovery is 8-12.
> **Hard 10 km run 2 days ago** (strain 15.4). Nothing yesterday.
> **Stress 41/100**, moderate, rising since 11:00.
> **Caffeine: 2 logged**, last at 11:15. **Water 4 of 8 glasses.**
> **VO2 max 44.2.** **Vitality age 31** vs chronological 34.
> Signals worth flagging today: RHR +3 and respiratory rate +0.6 above baseline **on the same
> night**, which the phone's illness early-warning would read as a low-confidence body-stress flag.

### Data honesty rules

- Never fabricate a precision the sensor cannot support. No "biological age 27.3", no HRV to two
  decimals, no "94.7% recovered".
- Charts must plot plausible day-to-day and hour-to-hour variation, not a smooth invented curve.
- If a concept shows a prediction, it must show its uncertainty or its confidence.
- Anything the wrist cannot actually compute must be visibly sourced from the phone. See the
  data-availability table below.

---

## What the wrist can and cannot know — obey this

This is not a style rule, it is the architecture. A concept that shows phone-only data as if it
were live is not buildable.

**Available natively on watchOS, no phone needed** (watchOS has a full `HKHealthStore`, but its
local store only reaches back **about 7 days** — anything needing a longer window is phone work):

live heart rate · today's HR samples and range · HRV samples · resting HR · steps · active and
basal energy · exercise minutes · stand hours · distance · flights · workouts and workout sessions ·
last night's sleep stages · respiratory rate · SpO2 · wrist temperature · Activity ring values ·
`HKWorkoutSession` and `HKLiveWorkoutBuilder` for live sessions · mindful minutes · water and
caffeine writes

**Phone-only, must arrive over WatchConnectivity** (needs 60-90 days of history, remote config,
ML state, or smoothing the watch does not hold):

readiness/recovery score · overall health score · stress score · strain score and target range ·
vitality/biological age · brain health · sleep debt and sleep need · every personal baseline and
its confidence · anomaly and illness-warning verdicts · trends, correlations, causal chains ·
today's recommended action · any LLM/FoundationModels answer

**The split is the design opportunity.** Everything in the first list can be instant, live, and
correct with the phone in another room. Everything in the second list is a *verdict* that changes
at most a few times a day and can be cached. A concept that puts live data on the wrist and cached
verdicts behind it never has to show "open your iPhone".

---

## Naming

```
design/watch-v2/concepts/<NN>-<slug>.html      the prototype
design/watch-v2/concepts/<NN>-<slug>.md        the rationale
```

---

## Rationale document — required sections

1. **One-sentence philosophy.**
2. **The question it answers first**, and why that question was chosen.
3. **Screen-by-screen reasoning**, element by element, in order.
4. **Why this works on a watch specifically** — what would be worse on a phone.
5. **watchOS HIG guidance applied**, cited from `research/apple-hig.md` with the real URL.
6. **UX principles used** and the mechanism.
7. **Psychological principles that drive repeat opens**, each with its evidence strength
   (`strong: peer-reviewed` / `medium: vendor data` / `weak: anecdote`) from
   `research/engagement-science.md`. No invented citations.
8. **Complication strategy** — which families, what each shows, why a user would give up a face slot.
9. **Smart Stack strategy** — what the widget shows and when it should surface.
10. **Notification strategy** — what fires, when, and the cadence ceiling before it becomes noise.
11. **Haptic language** — which `WKHapticType` for which event.
12. **What was deliberately excluded and why.**
13. **Expected opens per day, with the mechanism for each open.** Be specific about the trigger.
14. **Buildability against this codebase** — which fields exist today, which need a new
    `WatchPayload` field, which need native HealthKit on the wrist, which need new phone-side work.
15. **Honest drawbacks, and who this design fails.**
16. **The 5-second test**, for every screen: can a user get a decision in under 5 seconds without
    reading a sentence? Mark pass/fail per screen and do not hide the failures.
