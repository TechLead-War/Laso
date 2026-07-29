# Final recommendation

---

## 1. Start with the finding that changes the brief

The brief asks for a Watch app users open **5-20 times a day**. All ten concepts were designed
against that target, and every one of them, independently, came back with the same answer:

| Concept | Honest app opens/day, self-reported |
|---|---|
| 05 Body Clock | ≈ 2.9 app-or-widget interactions |
| 08 Ask | ≈ 2.6 |
| 09 Fourth Ring | ≈ 2.2 |
| 02 One Word | ≈ 2.0 (plus **≈ 25 verdict views**) |
| 01 Body Battery | ≈ 1.9 |
| 10 Autonomic | ≈ 1.85 |
| 03 Live Pulse | ≈ 1.6-1.9 |
| 04 Recovery Compass | ≈ 1.4 |
| 07 Daily Mission | ≈ 0.7 |
| 06 Health Radar | ≈ 0.12 (44 per **year**) |

**No design in this set reaches 5 app opens per day, and none should claim to.** Apple states it
plainly: people *"use a watchOS app's related experiences — like complications, notifications, and
Siri interactions — more than they use the app itself"*, and *"may never explicitly launch your
app"*
([Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)).
The measured reality is 142.1 watch sessions per day at a **5.0 second median**
([CHI 2017 telemetry, 307 users](https://www.kostakos.org/papers/chi17.pdf)) — those are wrist
raises, not app launches.

**So the target is right and the unit is wrong.** 5-20 *encounters* per day is achievable and is
exactly what a good watch product delivers. 5-20 *app launches* is not achievable by anyone,
including WHOOP (which ships no watch app at all), and chasing it would mean deliberately
withholding the answer from the face to force a tap — the one thing guaranteed to get the
complication deleted.

**The redesign target, restated:**

> 15-25 zero-tap encounters a day on the watch face and in the Smart Stack, each under 5 seconds,
> each ending in a decision — plus 2-3 app opens when the user wants the reason behind one.

Every recommendation below optimises for that. It is the same ambition, measured where the value
actually lands.

---

## 2. How the ten scored

Weighted on what the research says actually matters: glance value first, decision value second,
buildability third.

| # | Concept | Glance value | Decision value | Differentiation | Buildability | Risk | Verdict |
|---|---|---|---|---|---|---|---|
| 01 | Body Battery | High | Medium | **Low** — Garmin owns it | Medium | **High** | Absorb one idea |
| 02 | **One Word** | **High** | **Highest** | **Highest** | **High** | Low | **SPINE** |
| 03 | Live Pulse | Medium | Medium | Medium | Medium | Medium | **Absorb — it is the data floor** |
| 04 | Recovery Compass | Medium | High | High | Medium | High | Absorb one idea |
| 05 | **Body Clock** | **Highest** | High | High | Medium | Low | **ENGINE** |
| 06 | Health Radar | Low as an app | **Highest when it fires** | High | Medium | Medium | **Absorb — as a notification policy** |
| 07 | Daily Mission | Medium | Medium | Low | **Highest** | **High** | Absorb one idea |
| 08 | Ask | Medium | High | **Highest** | Low | Medium | **Absorb — it is layer two** |
| 09 | Fourth Ring | High | High | Medium | Medium | **Highest** | Absorb one idea |
| 10 | Autonomic | Medium | High | Medium | Medium | **High** | Absorb — as one word + one action |

**Two concepts independently solved the hardest problem in the set**, and they solved it the same
way. The problem: a readiness score is computed once in the morning and is identical from 07:00 to
23:00, and Apple warns that *"a static complication that doesn't display meaningful data may be less
likely to remain in a prominent position on the watch face"*
([Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)), while the
checking-habit literature shows a habit needs *dynamic* content — adding real-time information to a
previously static screen **caused** checking to emerge
([Springer, peer-reviewed](https://link.springer.com/article/10.1007/s00779-011-0412-2)).

- **02 One Word** derives its headline from a deterministic ladder that runs **on the wrist**, off
  native sensors, so the wrist can speak while the readiness score sits at 62 all day. (Its first
  vocabulary was wrong and is corrected in §3 — the fix cost most of this dynamism, which is why 05
  below is not optional.)
- **05 Body Clock** shows a countdown to the next window. A countdown is different on every single
  wrist raise **by construction, and costs zero reload budget to stay right.**

That is the whole ballgame. Both make the wrist genuinely dynamic without inventing fake variance,
and both work with the phone in another room.

---

## 3. The recommendation — **"Now"**

> **One word telling you what to do, a countdown to when it stops being true, and the reason one tap
> away. Chosen on the wrist, from the wrist's own sensors, so it is never stale and never asks you
> to go find your phone.**

**Concept 02 is the spine. Concept 05 is the engine that keeps the spine moving.** After the
correction in this section, 02's headline is deliberately stable — so 05's live countdown is no
longer a nice addition, it is the only thing on the screen that moves. The two are now load-bearing
for each other.

### The earning rule

> **A word only reaches the headline if the user could not already know it.**
> Everything else is a *state*, not an order.

This rule was added after the first draft failed review, and it is the most important line in this
document. The original vocabulary had eight words, and Alex's traced Tuesday produced
`WALK · STAND · WALK · BREATHE · WALK · STAND · COAST · DRINK · SLEEP` — **six of nine were
WALK/STAND/DRINK**, which is exactly what Apple's own Activity rings and stand reminders already
nag about. The wrist has one line, and the first design spent it restating something the watch was
already saying for free. Worse, none of those six words used the thing that makes Laso worth
having: 60-day baselines, anomaly detection, causal chains.

**The corrected vocabulary has two tiers.**

| Tier | Words | Fires when | Why it is earned |
|---|---|---|---|
| **Imperative** (rare) | `REST` `TRAIN` `BREATHE` `SLEEP` | Laso knows something invisible to the user | Body-stress flag, band + strain headroom, HR elevated while sitting still, bedtime derived from sleep need and debt |
| **State** (most days) | `RECOVERING` `WARM` `STEADY` | Default | A fact about the body measured against **this user's own baseline** — never an order |

`STAND`, `DRINK`, `WALK` and `COAST` were **deleted from the headline entirely.**

### The entry screen

```
┌────────────────────────┐
│                        │   Line 1  the word — verdict, stable, band colour
│     RECOVERING         │   Line 2  the reason — a baseline fact, not an order
│                        │   Line 3  the headroom — live, changes every glance
│ 2 days after your      │   Line 4  freshness dot
│      hard run          │
│ Room for 18 more min   │
│  ● Fresh · 6 min       │
└────────────────────────┘
```

Four lines. One decision. Under 5 seconds. No score. **Nothing on this screen is something Alex
could have worked out alone.**

### The cost of the correction, stated honestly

The old ladder produced **six different words across nine evaluations**. The corrected one produces
**three words and two changes** — Alex is `RECOVERING` for most of the day. That is a real loss of
the dynamism that engagement mechanic #1 (the strongest evidence in the whole research set) depends
on, and pretending otherwise would be dishonest.

**The dynamism moves to line 3.** The headroom counts down all day from native sensor data
(`30 → 28 → 26 → 18 → ceiling reached`) and costs no reload budget to stay right. So the word is the
*verdict* — stable and therefore trustworthy — and the line under it is the *feed*.

That is exactly the split the research called the cleanest resolution found: Athlytic ships a frozen
morning `Recovery` and a live `Battery` **as two separately named things**, because a verdict that
silently drifts destroys trust while a feed that never moves cannot sustain checking.

The number is not gone — it is **one crown turn deeper**, because progressive disclosure is the
pattern every competitor converged on (Garmin: level at 0 presses, causal factors at 3; Fitbit:
2 taps to per-pillar reasoning). And the "why" is one tap below that, which is the gap nobody in the
competitive set has closed on a watch.

### Why this is superior

**1. It attacks the one weakness every competitor shares.** The single most consistent criticism
across the entire competitive set is guidance, not data: *"Bevel is big on data, but falls short on
guidance"*
([Yahoo Tech](https://tech.yahoo.com/wearables/articles/bevel-sort-makes-apple-watch-230000160.html));
*"The scores are a black box"*
([autonomous.ai](https://www.autonomous.ai/ourblog/bevel-app-review)); Ultrahuman flags a temperature
drop but *"doesn't explain why it could happen or what it could mean"*
([Garage Gym Reviews](https://www.garagegymreviews.com/ultrahuman-ring-review)). Meanwhile Laso's
phone runs a CausalChainEngine, a CompoundInsightEngine, a DecisionPolicyEngine and a
FoundationModels session with 10 tools — **and mails the wrist a single integer.** The gap between
what this codebase already knows and what the wrist currently says is the product opportunity.

**2. It is the only structure that survives the refresh cap honestly.** A complication updates at
most ~4×/hour. The vocabulary is built on a **regret asymmetry**: a state word (`RECOVERING`,
`WARM`, `STEADY`) costs nothing if it is 15 minutes stale, and so do `BREATHE`, `SLEEP` and `REST`.
Only `TRAIN` is expensive when wrong — training a body that needed rest costs real recovery — so
`TRAIN` alone is gated on payload freshness. That single
design decision is what lets the concept ignore a constraint that puts Bevel in a
[public bug thread](https://feedback.bevel.health/bug-reports/p/bevel-phone-app-and-watch-app-values-dont-match)
about watch values disagreeing with the phone.

**3. It makes "open Laso on your iPhone" structurally impossible.** The ladder's fallback rule 7
always produces `STEADY` plus a live headroom line from native sensor data. There is no state on a worn watch where both data
paths are empty. The app's most common message today becomes unreachable.

**4. It matches the proven pattern exactly.** Garmin — the most-loved glance in the category —
ships *number + colour + one word + a 2-4 word imperative*: "Time to slow down", "Let your body
recover". Nobody in the set ships a bare number. Laso currently ships a bare number under the phrase
"Progressive Overload".

**5. It is buildable.** The ladder runs on the wrist off HealthKit values the watch can read
natively. It needs no new score, no ML on-device, and no new phone-side engine — only the existing
readiness band, plus baselines the phone already computes and simply does not send.

---

## 4. What it takes from the other eight

Nothing here is a courtesy nod. Each is a specific mechanism.

| From | What is absorbed | Where it lands |
|---|---|---|
| **03 Live Pulse** | The **native HealthKit data path** and the "is 74 bpm high *for me*, sitting, at 14:32?" framing. This is the floor the whole product stands on. | Architecture (§5), and the `BREATHE` rule's HR trigger |
| **08 Ask** | The **"why" layer** — three factors behind today's verdict, phone-computed, cached, one tap from the word. Closes the black-box gap. | Screen 2 |
| **06 Health Radar** | The **sentinel** — but as a *notification policy*, not an app. Its own 0.12 opens/day proves it is not a product; its value is being right 4 times a year. Fire on **change vs a rolling average** with a user-set threshold and a hush control, never on absolute state. | Notifications (Phase 3) |
| **09 Fourth Ring** | The **ceiling** — "how much movement is wise today", not "how much have you done". Its own rationale concluded the fourth thing *is not a ring*, it is a limit. After the correction this limit became **line 3 of the entry screen**, and it is now the concept's only live element. | Line 3, every surface |
| **10 Autonomic** | `BREATHE` as a word, with a one-tap breathe action — already rule 2 of the ladder. Garmin's stress glance reaches breathwork in **one press**; that is the bar. | Ladder rule 2 + Phase 3 action |
| **07 Daily Mission** | **Double Tap to close** the action, with a `.success` haptic. Note R11: this forces the entry screen to not be a list or scroll view — which the four-line layout already satisfies. | Entry screen `Done` |
| **05 Body Clock** | The **window model and the countdown** — the dynamism engine, and the Smart Stack relevance clues that surface it at the right moment. | Line 3, and the widget |
| **01 Body Battery** | Only the **spend-rate sparkline** for `accessoryRectangular`. The battery *metaphor* is rejected: it breaks the moment the watch comes off to charge, and reviewers note it *"moves for too many reasons unrelated to exercise or readiness"*. | Rectangular complication |
| **04 Recovery Compass** | The **target range** framing (you are below your zone, you have room) as plain words rather than a 2-axis plot the user must learn. | The line-3 headroom wording |

**Explicitly rejected as structures:** the battery metaphor (01), the 2-axis plot (04), a fourth
ring (09), and the streak (07). The streak is the sharpest rejection: mechanic #8 rates it MEDIUM
and names the flaw — **a streak rewards wearing and opening, not recovering.** Gentler Streak, whose
name is literally a streak, ships manual *On a Break / Sick / Injured* states so users can stop
without penalty.

---

## 5. Phase 1 — MVP

**Goal: the wrist always has something true to say, and it is a decision.**

Ordered by value ÷ effort. Items 1-3 improve the app that is shipping *today* and are independent of
everything else — they should go out regardless of what happens to the rest of this plan.

| # | Work | Effort | Value | Engagement impact |
|---|---|---|---|---|
| 1 | **Push to the watch from the background task.** `BackgroundRefreshCoordinator.swift:114-140` computes a fresh score and updates only the iOS widget — it never calls `PhoneWatchSession.push`. **The iPhone widget updates in the background and the watch does not.** This is why the wrist so often shows the 60-minute stale message. | Hours | **Highest** | Direct — kills the most common failure state |
| 2 | Expire stale `pendingCommands` so a lost answer stops disabling the button forever (`WatchStore.swift:27-29` already admits the bug) | Hours | High | Removes a dead-end |
| 3 | Render or stop sending `readinessGrade`, `actionDetail`, `actionIcon` — 3 of 10 payload fields are shipped and never drawn | Hours | Medium | Housekeeping |
| 4 | **Colour band + `Gauge` in the complication.** Use `DS.recoveryTier`, which already exists. Today it is white text on black with no colour at any score. | 1 day | **Highest** | Pre-attentive verdict — the biggest glanceability win available |
| 5 | **Payload v2**: add `schemaVersion`, make every new field optional, add **baselines** and the verdict sentence. Baselines are the important one — send them once and the wrist can answer "is this high for me?" all day without another message. | 1-2 days | **Highest** | Converts a large class of questions from phone-only to instant |
| 6 | **Native HealthKit on the wrist**: entitlement, usage string, capability, and a small `WatchHealthStore` (~6 queries, not a port of `HealthKitManager`) | 3-5 days | **Highest** | The floor everything else stands on |
| 7 | **The word ladder + entry screen** — 8 words, deterministic, on-wrist | 3-4 days | **Highest** | The product |
| 8 | **Three complications** with distinct deep links: `accessoryCircular` (gauge + word), `accessoryRectangular` (word + countdown + sparkline), `accessoryInline` | 2-3 days | **Highest** | Where the 15-25 daily encounters actually happen |
| 9 | **One Smart Stack widget** (`accessoryRectangular`) | 2-3 days | **Highest** | The largest missing distribution channel today |
| 10 | **Haptics on every state change** — the app currently fires none, and its two "saved" strings are dead code no view shows | 1 day | High | Confirmation, trust |
| 11 | **Always-On redaction** — health values genuinely hidden, not dimmed. Apple's rule is unconditional. | 1 day | Medium | Compliance, not polish |

**Phase 1 is deliberately the whole glance experience and nothing else.** No live HR, no workouts,
no check-in rebuild.

---

## 6. Phase 2 — the reason, and the rhythm

**Goal: the user trusts the word, and the day has a shape.**

| # | Work | Effort | Value | Engagement impact |
|---|---|---|---|---|
| 1 | **The "why" screen** — three factors behind today's verdict, phone-computed and cached | 3-4 days | **Highest** | Closes the black-box gap; the category's #1 complaint |
| 2 | **Window countdown + Smart Stack relevance** via `TimelineProvider.relevance()` / `RelevanceConfiguration`. **Do not use `TimelineEntry.relevance` — it does nothing on watchOS.** Relevance needs the HealthKit permission on *both* app and widget extension. | 4-5 days | **Highest** | The dynamism engine; surfaces without a tap |
| 3 | **Wake-time verdict notification**, delta-gated. Garmin's Morning Report is the model. Budget it: notifications give a 3.5× next-hour lift but **no measurable long-term retention effect**. | 2-3 days | High | Highest-intent moment of the day |
| 4 | **Rebuild the check-in on the Digital Crown**, one question per screen. Today it puts 15 tap targets on a 162pt screen at roughly 30×25pt each, against Apple's 44pt floor. It must also work without the phone. | 3-4 days | High | Fixes an unusable screen and feeds the model |
| 5 | **Quick log as a complication + widget with a running count.** Today each tap sends `value: 1` and dismisses, and the count is never visible anywhere — a write-only hole with no reason to return. | 2-3 days | Medium | Adds a genuine zero-tap encounter |
| 6 | **Double Tap** on the entry screen's primary action | 1 day | Medium | Removes the last tap |

---

## 7. Phase 3 — the sensor, and the sentinel

**Goal: the two things only a wrist can do.**

| # | Work | Effort | Value | Engagement impact |
|---|---|---|---|---|
| 1 | **Live HR screen** — "is this high for me, right now". Beware: a haptic **stops HealthKit heart-rate sampling** until the engine finishes, and live HR cannot stream in the background. | 2-3 days | High | The one thing the phone cannot do |
| 2 | **The sentinel** — delta-gated anomaly alerts with a sensitivity control and a hush switch. Athlytic's absolute-threshold alerts drew an explicit complaint that they *increase anxiety* and a request for *"a big friendly toggle to hush stress for a while"*. Build the toggle first. | 4-5 days | High when it fires | Trust, not frequency. Judge it on being right ~4×/year |
| 3 | **Breathe in one tap** from `BREATHE`. Reuse Apple's Mindfulness rather than a custom timer. | 2-3 days | Medium | Verdict → action in one press |
| 4 | **Workout session / live strain** (`HKWorkoutSession`) | 1-2 weeks | Medium | Real battery and correctness stakes. Only after the glance layer is proven. |

---

## 8. What we are deliberately not building, and why

| Not building | Why |
|---|---|
| A readiness number on the entry screen | Every competitor pairs the number with words; none ships it bare. The number belongs one crown turn deeper, where it can be trusted rather than decoded. |
| A streak | It rewards wearing and opening, not recovering. |
| A fourth Activity ring | Two rings on one screen is a comparison rendered in the slowest possible encoding (radial: 1548-1772 ms vs bar: 159-285 ms). And competing with Apple's own Activity complication for a face slot is not a fight worth picking. |
| A battery metaphor | It breaks the moment the watch comes off to charge, and it moves for reasons unrelated to readiness. |
| A phone-dashboard mirror on the wrist | The explicit anti-pattern. Bevel's watch app was reviewed as doing things "the phone app can" already do. |
| Absolute-threshold stress alerts | The documented anxiety generator in this category. |
| Any spinner | Apple: an indeterminate indicator makes people think they must keep watching the screen. |

---

## 9. The honest risks

1. **A word can be wrong in a way a number cannot.** "62" is never *wrong*, just uninformative;
   `TRAIN` on a day the user is getting sick is a real error with a real cost. The regret asymmetry
   (only `TRAIN` gated on freshness) mitigates this but does not remove it. **This is the single
   biggest risk in the recommendation.**
2. **Users who want the number will feel it was taken away.** Progressive disclosure has to be
   genuinely one crown turn, discoverable on first run, and never more than that.
3. **Native HealthKit on the wrist is a new App Store review surface and a new first-run permission
   prompt.** That prompt is a designed moment, not a bolt-on.
4. **Smart Stack relevance is easy to get wrong and cannot be tested without real hardware.**
   `TimelineEntry.relevance` being dead on watchOS is exactly the kind of silent failure that ships.
5. **The research has real gaps**, listed honestly in `research/00-SYNTHESIS.md §7`. Notably: no
   competitor publishes its complication families, Reddit was blocked to every research agent so
   there is zero forum-level user commentary in the entire set, and the central "a moving value
   drives more checking than a static one" premise is **a well-supported inference from three
   peer-reviewed results, not a measured fact**. It is the load-bearing assumption under both
   02 and 05, and it has not been directly tested.

---

## 10. If only one thing gets built

**Fix the background push, and put colour and a gauge in the complication.**

That is roughly a day and a half of work against the app shipping today. It does not need the
redesign, the native HealthKit path, or a single new screen — and it turns the most common wrist
experience from *"-- , open Laso on your iPhone"* into a coloured ring that is actually current.

Everything else in this document is the argument for what to build after that.
