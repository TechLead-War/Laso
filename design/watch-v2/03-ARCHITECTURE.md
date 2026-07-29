# The architecture every concept needs

No amount of visual design fixes the shipping Watch app, because its problem is structural: it can
only render a struct the phone mails it, and the phone only mails it while the user is looking at
the phone. This document is the engineering change that unblocks all ten concepts. It is
concept-independent — build it and any of the ten becomes possible.

---

## 1. The split

**Two data paths, not one.**

```
┌────────────────────────── Apple Watch ──────────────────────────┐
│                                                                 │
│  PATH A — native, instant, always available                     │
│  HKHealthStore on watchOS  →  live HR, today's steps, exercise, │
│  stand, energy, last night's sleep, HRV, RHR, SpO2, resp rate,  │
│  wrist temp, workouts. No phone involved. Works in aeroplane    │
│  mode, works with the phone in another room.                    │
│                                                                 │
│  PATH B — cached verdicts from the phone                        │
│  WatchConnectivity  →  readiness, stress, strain target, sleep  │
│  debt, baselines, anomaly verdicts, today's action, the "why"   │
│  sentence. Changes a few times a day. Cached in the App Group   │
│  and rendered even when hours old, with its age shown.          │
└─────────────────────────────────────────────────────────────────┘
```

**Why the split is the whole answer:** Path A can never be stale, so the wrist always has something
true to say. Path B is a *verdict*, and a verdict that is four hours old is still a useful verdict
as long as its age is visible. The banned string "Open Laso on your iPhone" becomes structurally
impossible, because there is no state in which both paths are empty on a worn watch.

**The constraint that forces the split:** watchOS's local HealthKit store only reaches back about
7 days ([Athlytic's own support docs](https://athlyticapp.helpscoutdocs.com/article/12-widget-or-complication-out-of-sync)),
and Laso's baselines are 30-90 days. The watch genuinely cannot compute readiness. It can compute
everything about *today*.

---

## 2. Enabling Path A — native HealthKit on the wrist

The Watch target currently links no HealthKit at all. Four changes:

| Change | File | Why |
|---|---|---|
| Add `com.apple.developer.healthkit` | `LasoWatch/LasoWatch.entitlements` | Currently holds only an App Group |
| Add `NSHealthShareUsageDescription` | `LasoWatch/Info.plist` | Required or the authorization call traps |
| Add the HealthKit system capability | `project.yml` under `LasoWatch.attributes` | Mirror what the `Laso` target already does at `project.yml:161-166` |
| Add the same two to the complication extension | `LasoWatchWidgets/*` | R12: `RelevantContext.fitness(_:)` / `.sleep(_:)` need the matching permission on **both** app and widget extension, or Smart Stack relevance silently does nothing |

Then one new file, `LasoWatch/WatchHealthStore.swift`, holding an `@Observable @MainActor` store —
the same pattern as `WatchStore` and as every ViewModel in the app
(`@Observable`, no `ObservableObject`, no Combine).

**Do not port `HealthKitManager`.** It is built around 72 metrics, a registry, SwiftData
persistence, thermal gating and ML orchestration, none of which exists or belongs on the wrist. The
wrist needs roughly six queries:

- `HKAnchoredObjectQuery` on `.heartRate` for the live stream, foreground only
- `HKStatisticsQuery` sums for today's steps / active energy / exercise minutes
- `HKActivitySummaryQuery` for the three ring values (already used on the phone at
  `LiveViewModel.swift:689` — the shape is proven)
- `HKSampleQuery` on `.sleepAnalysis` for last night
- Latest-sample reads for RHR, HRV, respiratory rate, SpO2
- `HKObserverQuery` + `enableBackgroundDelivery` for the handful that drive complication reloads

Existing precedent to copy rather than reinvent: `LiveViewModel.swift:418` (anchored HR stream with
a 1/sec UI throttle), `LiveViewModel.swift:387` (observer set, coalesced to one per 15 s).

**The honest limits, which the design must absorb:**

- Live HR cannot stream in the background. R9: background execution is "a few seconds" and never
  guaranteed. Only a real `HKWorkoutSession` holds a long-lived session.
- A haptic stops HealthKit heart-rate sampling until the haptic engine finishes
  ([WKInterfaceDevice.play](https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:))).
  Any screen that samples HR must not fire haptics while it samples.
- Complications refresh at most ~4×/hour, shared across every complication on the active face.

---

## 3. Fixing Path B — three real defects in the shipping code

### 3.1 The watch never updates in the background (highest value, lowest effort)

`App/BackgroundRefreshCoordinator.swift:114-140` computes a fresh readiness score in a
`BGAppRefreshTask`, writes it to `WidgetDataStore` for the **iOS widget**, reloads the iOS widget
timelines — and never calls `PhoneWatchSession.shared.push`.

`PhoneWatchSession.push` is called from exactly one place: `writeWidgetSnapshots()`
(`DashboardViewModel.swift:2265`), reached only from `refreshCore` at
`DashboardViewModel.swift:766` and `:829` — all foreground paths.

**Result: the iPhone widget updates in the background and the Watch does not.** This is why the
wrist so often shows the 60-minute stale message. Adding the `push` call to the background
coordinator is a handful of lines and is the single highest-leverage fix in this entire document.

### 3.2 Three of ten payload fields are never rendered

`readinessGrade`, `actionDetail` and `actionIcon` are built in `PhoneWatchSession.buildPayload`
(`Core/Data/PhoneWatchSession.swift:117-131`), shipped over the wire, cached — and no Watch view
reads them. Either render them or stop sending them. Dead payload fields are dead code with a
battery cost.

### 3.3 A lost command answer disables the button forever

`WatchStore.pendingCommands` only clears when the phone answers
(`WatchStore.swift:83`), and `WatchRootView.swift:95` disables the action button whenever
`pendingCommands` is non-empty. The code's own `ponytail:` comment at `WatchStore.swift:27-29`
admits an answer that never arrives leaves the write pending until relaunch. Stamp entries with a
time and expire them.

---

## 4. What the payload has to become

Today's `WatchPayload` is a flat struct of ten fields with no version marker. Every concept needs
more, and adding fields to a `Codable` struct that an older watch build may decode is a
compatibility hazard.

Minimum shape change:

- **Add a `schemaVersion: Int`.** Without it, a phone update that adds a required field breaks
  decoding on a watch the user has not updated, and the wrist silently goes blank.
- **Make every new field optional** so an older watch decodes a newer payload and ignores what it
  does not know.
- **Split the payload in two:** a small hot part (score, band, one sentence, freshness) that ships
  on every push, and a cold part (baselines, weekly context) that ships once a day. The
  application-context transport coalesces, so a fat payload costs nothing per-send, but the
  complication transfer budget is finite and is spent only when the score changes
  (`PhoneWatchSession.swift` guards this already with `lastComplicationScore` — that logic is
  correct and should stay).

Fields the concepts commonly need that do not exist yet: the verdict *sentence* (not just the
grade), the personal baseline and band for the metrics the wrist displays, the strain target range,
the stress level, sleep debt, and the anomaly verdict with its confidence.

**Baselines are the important one.** Push the *baseline*, not just the score, and the wrist can
answer "is 74 bpm high for me?" natively for the rest of the day without another phone message.
That single change converts a large class of questions from Path B to Path A.

---

## 5. Surfaces that do not exist yet

| Surface | Status | Notes |
|---|---|---|
| Smart Stack widget | **Missing entirely** | The largest gap. Only `accessoryRectangular` and `accessoryCircular` reach the Smart Stack (R3). Relevance needs `TimelineProvider.relevance()` → `WidgetRelevance`, or `RelevanceConfiguration` on watchOS 26+. **`TimelineEntry.relevance` does nothing on watchOS** — it is dead code. |
| More than one complication | Only `LasoReadinessComplication` exists | Apple: define a *different* deep link per complication; sharing one makes them "seem less useful". |
| Gauge rendering in complications | Text only today | `.accessoryCircular` should be a `Gauge`; `.accessoryCorner` should use `widgetLabel`. |
| Any notification from the Watch target | None | |
| Any haptic | None | `WKInterfaceDevice.play(_:)` appears nowhere in the repo. |
| Always-On handling | None | `isLuminanceReduced` is not read anywhere. Health values must be **redacted**, not dimmed. |
| Double Tap primary action | None | `handGestureShortcut` unused. Note R11: cannot coexist with a list or scroll view on the same screen. |

---

## 6. Effort and risk, honestly

| Work | Effort | Risk |
|---|---|---|
| Push to watch from the background task | **Hours** | Very low. One call in an existing code path. |
| Expire stale pending commands | **Hours** | Very low. |
| Render or remove the 3 dead payload fields | **Hours** | None. |
| Colour band + gauge in the complication | **1 day** | Low. Uses `DS.recoveryTier`, which already exists. |
| Payload versioning + optional new fields | **1-2 days** | Low, but must land *before* any field is added, not after. |
| Smart Stack widget | **2-3 days** | Medium. Relevance API is easy to get wrong (R12) and untestable without real hardware. |
| Native HealthKit on the wrist | **3-5 days** | Medium. Entitlement + a second App Store review surface for health permissions; the authorization prompt is a new first-run moment that has to be designed, not bolted on. |
| Live HR screen | **2-3 days** | Medium. Battery cost is real; the haptic/HR interaction (R8) is a subtle bug generator. |
| Workout session | **1-2 weeks** | High. `HKWorkoutSession` is a large surface with real battery and correctness stakes. Out of scope for a first release. |

**The order matters more than the total.** The three defects in §3 and the complication gauge are a
few days of work and would measurably improve the app that is shipping *today*, independent of
which concept wins. Everything else should wait until the concept is chosen.
