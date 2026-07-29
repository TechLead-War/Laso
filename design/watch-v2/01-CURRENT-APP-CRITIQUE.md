# Laso Apple Watch app — brutally honest teardown

Every claim below is from reading the shipping source in this repo, not from memory.
Line references are to the code as of commit `cbb674f` (v3.26).

---

## 1. What actually exists

The entire Watch product is **818 lines of Swift across 9 files**.

| File | Lines | What it is |
|---|---|---|
| `LasoWatch/LasoWatchApp.swift` | 13 | `@main`, one `WindowGroup`, one root view |
| `LasoWatch/WatchRootView.swift` | 109 | The only real screen |
| `LasoWatch/WatchCheckInView.swift` | 76 | Morning check-in sheet |
| `LasoWatch/WatchJournalView.swift` | 25 | Four-row quick log list |
| `LasoWatch/WatchStore.swift` | 199 | WatchConnectivity client + cache |
| `WatchShared/WatchBridge.swift` | 193 | Wire format |
| `WatchShared/WatchStrings.swift` | 92 | All copy |
| `LasoWatchWidgets/ReadinessComplication.swift` | 102 | One complication, four families |
| `LasoWatchWidgets/LasoWatchWidgetsBundle.swift` | 9 | Bundle |

Three screens. One complication. That is the whole product.

---

## 2. The single fact that explains everything

**The Watch app does not link HealthKit. At all.**

- `project.yml:242-252` lists `LasoWatch` sources file by file: `LasoWatch`, `WatchShared`,
  `Core/Extensions/Date+Extensions.swift`. Nothing else.
- `LasoWatch/LasoWatch.entitlements` contains exactly one key: an App Group. No
  `com.apple.developer.healthkit`.
- `LasoWatch/Info.plist` has no `NSHealthShareUsageDescription`.
- `WatchShared/WatchBridge.swift:7-8` states the intent outright: *"This file must stay free of
  UIKit, WidgetKit, HealthKit and Firebase because the watch targets link none of them."*

So the Watch is a **dumb terminal**. It renders a 10-field struct the phone mails it:

```
WatchPayload = dayKey, readinessScore, readinessGrade, dayType,
               actionHeadline, actionDetail, actionIcon, actionDone,
               checkInAvailable, updatedAt
```

That is the ceiling on everything the wrist can ever say. Three of those ten fields
(`readinessGrade`, `actionDetail`, `actionIcon`) **are never rendered by any Watch view** — grep
`WatchRootView.swift`: it draws `readinessScore`, `dayType`, `actionHeadline` and the done flag.
Thirty percent of the payload is dead weight on the wire.

**The consequence:** the phone runs ~40 analysis engines (AnomalyDetector, CrossMetricAnomalyDetector,
Isolation Forest, ChangePointDetector, GrangerCausalityEngine, IllnessEarlyWarning,
TodayIntelligenceEngine, CircadianAnalyzer, StrainScorer, StressScorer, BrainHealthScorer,
VitalityScorer, SleepDebtTracker, PredictiveScorer, DecisionPolicyEngine, and an Apple
FoundationModels session with 10 tools). The wrist gets **one integer**.

---

## 3. Screen-by-screen verdict

### Screen 1 — `WatchRootView` ("95 / Readiness / Progressive Overload / Today's Action")

**Purpose:** show today's readiness and one action.
**Real user value:** low, and falling. It answers *one* question ("what was my score when my phone
last opened?") out of the eleven questions a person actually has at the wrist.

**Concrete failures:**

1. **The number is not live and cannot be.** `PhoneWatchSession.push()` is only called from
   `DashboardViewModel.writeWidgetSnapshots()` (`DashboardViewModel.swift:2265`), which runs on
   dashboard refresh — app launch, pull to refresh, foreground return. `BackgroundRefreshCoordinator`
   updates the **iOS widget** but never calls `PhoneWatchSession.push`. **If the user does not open
   the iPhone app, the Watch never updates.** A watch app whose freshness depends on opening the
   phone app has inverted the value proposition of a watch app.
2. **Staleness is a dead end, not a recovery.** `WatchBridge.stalePayloadInterval` is 60 minutes.
   After 60 minutes the wrist shows `"Open Laso on your iPhone to refresh."`
   (`WatchStrings.swift:20`) and the complication renders `"--"` (`ReadinessComplication.swift:60`).
   So the most common state for a casual user is: **the Watch app telling them to go use the phone.**
   That is an anti-feature. It actively trains the user that the wrist is not where the answer lives.
3. **`dayType` is untranslated internal jargon.** The shipped screenshot reads **"Progressive
   Overload"** under the score. That string is `StrainCoach.TrainingZone.displayName`. Nobody
   glancing at a wrist at 07:06 parses "Progressive Overload" into a decision. It is a training-theory
   term rendered as if it were a status.
4. **No colour, no shape, no gauge.** The score is `Text("\(payload.readinessScore)")` at 44pt
   semibold, white on black (`WatchRootView.swift:57-59`). There is no ring, no arc, no colour band —
   even though the app already owns a three-band colour system (`DS.recoveryTier`: ≥67 green,
   45-66 amber, <45 red). **A glance has to read and interpret two digits instead of absorbing one
   colour.** This is the single biggest glanceability miss in the app. Every competitor encodes the
   verdict in colour first.
5. **"95" without context is meaningless.** No yesterday value, no arrow, no baseline, no "your
   usual is 78". A number with no reference frame cannot drive a decision.
6. **The action is a headline with no verb-level specificity on the wrist.** `actionHeadline` is
   `.title` only; `actionDetail` (the subtitle that explains it) is sent and thrown away.
7. **"Mark done" is the only interactive element and it is disabled half the time.**
   `WatchRootView.swift:95`: `.disabled(store.isActionDoneToday || !store.pendingCommands.isEmpty)`.
   Because `pendingCommands` only clears when the phone answers, **any unanswered command disables
   the button indefinitely** — the code's own `ponytail:` comment at `WatchStore.swift:27-29` admits
   a lost answer leaves it pending until app relaunch.

**Cognitive load:** deceptively high. Two digits + a jargon phrase + a sentence + a button, with no
visual hierarchy beyond font size, and no colour to pre-attentively carry the verdict.

**Frequency of use:** once a day at best, and only in the morning after opening the phone.

**Verdict: REBUILD.** The layout, the data model behind it, and the refresh architecture are all wrong.

---

### Screen 2 — `WatchCheckInView` (morning check-in)

**Purpose:** collect sleep quality / energy / soreness on a 1-5 emoji scale.
**Real user value:** moderate — subjective input genuinely improves a recovery model.

**Concrete failures:**

1. **15 tap targets on a 162pt-wide screen.** Three rows × five emoji
   (`WatchCheckInView.swift:55-73`), each `frame(maxWidth: .infinity)` inside an `HStack(spacing: 2)`.
   On a 40mm watch each target is roughly **30 × 25 points**. Apple's minimum comfortable tap target
   is 44×44pt. These are not reliably tappable, and the emoji glyphs at `.font(.footnote)` are
   ~13pt — unreadable at a glance.
2. **The Digital Crown is not used.** A 1-5 scale is the textbook case for crown rotation with
   detent haptics. Instead it is five tiny buttons.
3. **Emoji scales are ambiguous.** `😫 😕 😐 😊 😴` for sleep quality — is 😴 "slept well" or
   "still sleepy"? `🪫 😮‍💨 😐 💪 ⚡` for energy mixes a battery, a sigh, a face, an arm and a bolt:
   five different metaphor families in one row.
4. **It is gated by the phone.** `checkInAvailable` comes from `MorningCheckInManager.shouldShowCheckIn()`
   which is 05:00-11:00 local. But the payload only arrives when the phone app refreshes — so on a
   morning when the user has not opened their phone, **the check-in button does not appear on the wrist
   at all.** The one screen with genuine morning-ritual potential is invisible exactly when it matters.
5. **No confirmation.** `WatchStrings.CheckIn.saved = "Saved"` exists in the strings file and is
   **never used by any view.** The sheet just dismisses. No haptic, no tick.

**Verdict: KEEP THE INTENT, REBUILD THE INTERACTION.** Crown-driven, one question per screen,
haptic confirmation, and it must be available without the phone.

---

### Screen 3 — `WatchJournalView` (quick log)

**Purpose:** one-tap log of caffeine / water / alcohol / supplements.
**Real user value:** low as built.

**Concrete failures:**

1. **No count shown.** Each tap sends `value: 1` (`WatchStrings.swift:87-91`) and the sheet dismisses.
   The user can never see how many coffees they have logged today, on the wrist or in the complication.
   Logging with no visible running total is a write-only hole — there is no reason to come back.
2. **No confirmation.** `Journal.saved = "Logged"` is defined and **never used**. Same dead-string bug
   as the check-in.
3. **Wrong metaphor for water.** Water is the highest-frequency log and the one that most benefits
   from a running total and a goal ring. It is buried as row 2 of a list behind a button.
4. **It is a phone feature miniaturised.** This is exactly what the brief says the Watch app must not be.

**Verdict: KEEP AS AN ACTION, KILL AS A SCREEN.** Logging belongs on a Smart Stack widget and a
complication with a visible count, not behind two taps in a list.

---

### The complication — `ReadinessComplication`

**What is right:** it ships four families, it renders from the App Group cache so the extension needs
no session of its own, and the timeline policy correctly ages into a stale state
(`ReadinessComplication.swift:42-50`).

**What is wrong:**

1. **It is text-only in every family.** `.accessoryCircular` renders a `Text` + a 9pt caption
   (`:90-99`). The circular family's entire reason to exist is `Gauge` / `ProgressView(.circular)` —
   a ring is readable at a glance from the watch face, two digits at `.title2` are not.
2. **No colour.** Same bug as the app screen. The score band already exists in the codebase.
3. **`"--"` is the default state.** Any user whose phone has not refreshed in 60 minutes has a
   complication showing `--` on their watch face all day. **A complication that shows nothing is worse
   than no complication**: it occupies prime watch-face real estate and pays nothing back, and the
   user removes it. Once removed, the app is invisible forever.
4. **One complication for one metric.** No steps, no HR, no sleep, no "log water", no strain. A user
   can only give Laso one slot, and that slot shows a number that may be six hours old.
5. **No `.accessoryCircular` gauge, no `widgetLabel` progress, no `.complicationForeground` tinting.**

**Verdict: REBUILD.** Multiple complications, ring-based, colour-coded, never `--`.

---

### What does not exist at all

This is the more damning list.

| Missing | Why it matters |
|---|---|
| **Any Smart Stack widget** | On watchOS 10+ the Smart Stack is the primary glance surface — crown-down from the face. Laso has zero presence there. This is the single largest missed distribution channel on the device. |
| **Live heart rate** | The watch has the sensor. The app shows nothing from it. |
| **Workout session / live strain** | No `HKWorkoutSession`, no `HKLiveWorkoutBuilder` anywhere in the repo. |
| **Independent HealthKit reads on the wrist** | watchOS has a full `HKHealthStore`. The app uses none of it. |
| **Any notification** | The Watch target sends and handles zero notifications. |
| **Any haptic** | `WKInterfaceDevice.play(_:)` appears nowhere. Not one tap is confirmed by feel. |
| **Digital Crown input** | Not used on any screen. |
| **Always-On Display handling** | No `isLuminanceReduced` handling. |
| **Double Tap gesture** | No `handGestureShortcut` primary action anywhere. |
| **Trend, history, or any second data point** | The wrist shows exactly one number and cannot compare it to anything. |
| **Any accessibility work beyond one label** | One `accessibilityLabel` in the check-in emoji row. No Dynamic Type consideration, no VoiceOver ordering, no reduce-motion handling. |

---

## 4. The honest summary

The Watch app is **a read-only mirror of one integer, refreshed only when the user opens their
iPhone, rendered without colour, without a gauge, without haptics, without the crown, without a
Smart Stack widget, and without ever touching the health sensors strapped to the same wrist.**

Its most frequent message to the user is a request to go use the phone instead.

There is nothing here worth opening once a day, let alone 5-20 times. The three screens are not bad
implementations of the right idea — they are competent implementations of the wrong idea. The
architecture (`phone computes, watch displays`) was chosen for a defensible engineering reason
(`WatchStore.swift:9-11`: watchOS cannot see the phone's 60-day baselines or smoothing state), and
that reason is still valid for *the readiness score*. It is not a valid reason to keep the wrist away
from **live heart rate, today's steps, today's HR trend, movement, stand hours, workout state, and
sleep from last night** — all of which watchOS can read directly, instantly, with no phone involved.

**The fix is not more screens. It is a second data path: the wrist reads its own sensors for
everything that is "now", and keeps taking the phone's payload for everything that needs 60 days of
history.** Every concept in this redesign is built on that split.

---

## 5. Stay / change / remove

| Element | Verdict |
|---|---|
| Readiness score as the headline number | **Change** — keep the number, add colour band, ring, delta vs yesterday, and a plain-English verdict line |
| `dayType` ("Progressive Overload") | **Remove** — replace with a decision, not a training-theory noun |
| Today's Action + Mark done | **Change** — keep, but as a swipe/Double-Tap confirm with haptic, and show `actionDetail` |
| Morning check-in | **Change** — crown-driven, one question per screen, works without the phone |
| Quick log list | **Remove as a screen** — becomes a complication + Smart Stack widget with a visible running count |
| Single text complication | **Remove** — replaced by a family of gauge complications |
| Phone-only refresh architecture | **Change** — add a native watchOS HealthKit path for live data |
| "Open Laso on your iPhone" as the fallback state | **Remove entirely** — the wrist must always have something true to say |
