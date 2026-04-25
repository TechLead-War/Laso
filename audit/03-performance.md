# 03 — Performance, Thermal, Battery, Memory

Scope: read-only audit of the Laso (com.lasohealth.fit) iOS codebase against the brief in `audit/PROGRESS.md`. Every finding cites file:line and gives a per-finding confidence. Forbidden zones (security, copy, design, gap, compliance) excluded by design.

Sources of truth read top-to-bottom: `App/*.swift`, `Core/Data/*.swift`, `Core/Analysis/*.swift` (sampled), `Core/Tracking/PostHogManager.swift` + `AppAnalytics.swift` (sampled), `Core/Notifications/WatchMonitor.swift`, `Core/Intents/IntentDataProvider.swift`, `LasoWidgets/*.swift`, `Modules/Dashboard/**`, `Modules/Live/**`, `Modules/Stress/**` (Breathwork), `Modules/Insights/**`, `Modules/WebExport/**`. ~30 files inspected end-to-end, ~100 grepped for patterns.

---

## F1. `BackgroundRefreshCoordinator` is registered twice with two different instances. Second registration silently no-ops, but a fresh `LiveViewModel` factory is leaked at every cold start.

- **Severity:** High
- **Issue:** `AppDelegate` constructs its own `BackgroundRefreshCoordinator()` (default initializer, default factory) and immediately calls `register()` + `schedule()`. Independently, `AppContainer.init` constructs *another* `BackgroundRefreshCoordinator` instance with a custom `liveViewModelFactory` closure that captures the shared `ReadinessStore`. `BGTaskScheduler.register(forTaskWithIdentifier:)` only honors the first registration; the second is a no-op (Apple's API explicitly says you can register a given identifier exactly once per process). Net effect: the BG handler that actually fires uses the AppDelegate's coordinator, which constructs a *fresh* `HealthKitManager()` and a *fresh* `ReadinessStore()` every time it runs, instead of reusing the app's shared instances. The AppContainer's coordinator is dead weight.
- **Why it matters (perf):**
  1. Each background wake creates a brand-new `HealthKitManager` (line 24 in `BackgroundRefreshCoordinator.swift` default factory) → no warm caches, no shared `HKHealthStore`, no shared observer queries; everything is re-bootstrapped under a 30 s wake budget.
  2. The fresh `ReadinessStore` does not see the foreground app's persisted readiness deltas because both stores read/write `UserDefaults` only — fine for UD-backed state, but means in-memory caches across the AppContainer instance are always cold.
  3. The "incremental skip" check at `BackgroundRefreshCoordinator.swift:91-99` uses `UserDefaults.standard.object(forKey: "lastMLPipelineCompletion")`, which is fine, but everything *else* inside that fresh `LiveViewModel` is rebuilt from zero, undoing the optimization.
  4. Architectural smell: half the codebase (e.g. `ContentView.swift:140 → container.backgroundRefreshCoordinator.schedule()`) reschedules using the *unused* AppContainer instance, which has no effect because BGTaskScheduler is keyed by identifier — so reschedules from foreground go through fine, but the handler binding is the AppDelegate's instance. Confusion bait.
- **Evidence:**
  - `App/AppDelegate.swift:7` → `private let backgroundRefreshCoordinator = BackgroundRefreshCoordinator()` (default-init, default factory).
  - `App/AppDelegate.swift:19-20` → `register()` + `schedule()` called inside `application(_:didFinishLaunchingWithOptions:)`.
  - `App/AppContainer.swift:25, 65-73` → second `BackgroundRefreshCoordinator(liveViewModelFactory:)` with a closure capturing `sharedReadinessStore = readinessStore`.
  - `App/BackgroundRefreshCoordinator.swift:23-29` → default factory: `let healthKitManager = HealthKitManager(); return LiveViewModel(healthKitManager: healthKitManager, readinessStore: ReadinessStore())`. Always-fresh instances.
  - `App/ContentView.swift:140` → reschedule path uses `container.backgroundRefreshCoordinator` (the *other* instance). Lines up with BGTaskScheduler keying by identifier so it works, but the dual-instance pattern guarantees future divergence.
- **Fix:** delete the AppDelegate's coordinator. Plumb `container.backgroundRefreshCoordinator` from the container into AppDelegate (or invert: register from `LasoApp.init`/`.task`). Keep one BackgroundRefreshCoordinator that knows the shared HealthKitManager + ReadinessStore. Make `register()` idempotent guard live.
- **Confidence:** 95/100 — code paths fully read; the only unverified piece is whether `BGTaskScheduler.register` raises in DEBUG when called twice with the same id (it logs a warning and ignores the second call in production iOS). The leak/cold-start finding is unambiguous from the source.

---

## F2. HealthKit batch sync uses `HKSampleQuery` exclusively. No `HKAnchoredObjectQuery` for incremental delta fetches. Each "incremental" sync re-reads the entire date range.

- **Severity:** High
- **Issue:** The supposedly-incremental `HealthKitManager.loadAndSync()` is incremental only at the *date-range* level: for each metric whose `lastSyncDate` exists, it issues `HKSampleQuery` with `startDate = lastSync − 1 day, endDate = tomorrowMidnight`, returning *all* samples in that window — every sleep stage sample, every quantity sample, every workout — and then dedups against SwiftData inside `HealthDataBatchWriter`. This re-reads (and re-decodes, re-bridges to Swift) every sample inside the overlap window each time the user opens the app or BGTask fires.
- **What HealthKit gives you instead:** `HKAnchoredObjectQuery` returns *only the samples newer than your stored anchor* (and a list of explicitly-deleted samples), no client-side overlap window needed. For sleep / workouts / mindful / quantity samples the wins are large because Apple Watch produces dozens-to-hundreds of samples per metric per day.
- **Why this matters end-to-end:**
  - Cold sync at first launch: `loadAndSync` issues `withTaskGroup` of `HealthMetric.allCases.count` (≥30) parallel `HKSampleQuery`s with up to a 10-year window (`startDate = -10 years` when no `lastSync` exists; line 276). That is fine for first-time sync (statistics-bucket APIs would still fetch the same span) but it *also* triggers HealthKit to materialize and bridge every sample of every type — and each metric's continuation does an `O(samples)` `dailyValues` reduction on the calling thread, which on a multi-year history means tens of thousands of objects per metric.
  - Steady-state sync: every ≥1-day-stale metric does a fresh `HKSampleQuery` over the overlap window. With sleep alone this can be 50+ category samples per night × `1 + retry-day` days = ~100 bridge-and-decode operations per refresh just for sleep duration; the same again for `sleepREM`, `sleepDeep`, `sleepCore`, `sleepAwake`. All five sleep metrics fetch the *same* `HKCategoryType(.sleepAnalysis)` samples and run *five* independent loops over them.
  - Background delivery (`enableBackgroundDelivery(.immediate)` — `HealthKitManager.swift:1112`, `WatchMonitor.swift:111`) fires the observer, which then triggers a foreground-style refresh on next app launch. With no anchored query, the refresh re-fetches the same window again.
- **Evidence:**
  - `Core/Data/HealthKitManager.swift:467, 631, 713, 768, 873, 991, 1021, 1211` — every `fetchMetric*` strategy is `HKSampleQuery` (not anchored).
  - `Core/Data/HealthKitManager.swift:868-946` — `fetchSleepSamples(metric:)` is called once per sleep stage; each call queries the full sleep type and filters in Swift (`switch metric { case .sleepDuration: matchesStage = …` etc). Five separate identical-cost queries per refresh for the same `.sleepAnalysis` data.
  - `Core/Data/HealthKitManager.swift:271-280` — incremental start date logic confirms overlap-window fetch (`startDate = Calendar.current.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync`).
  - Confirmed via grep: zero `HKAnchoredObjectQuery` references in `Core/`. The only usages are `Modules/Live/ViewModels/LiveViewModel.swift:36-38, 397, 510, 518` for *real-time streaming* of HR/SpO2/respiratory — those are correct.
- **Impact:**
  - Wasted CPU + memory during every routine sync. Worst on high-volume metrics: heart rate (Watch can emit 300+ samples/day), sleep stages, steps.
  - Energy impact: more Obj-C ↔ Swift bridging, more allocations under thermal-hot conditions, more GC pressure, longer wake budget consumed in BGTask handler.
  - At HealthKit-data-rich users (multi-year history), repeat fetches in the overlap window keep the foreground refresh path measurably slower than it should be (each open feels heavier than necessary).
- **Fix:**
  1. For each per-sample type (`sleepAnalysis`, `mindfulSession`, all `quantitySample` metrics, `workoutType`), switch to `HKAnchoredObjectQuery`. Persist the `HKQueryAnchor` (Codable via `NSKeyedArchiver`) in SwiftData under a `StoredHealthKitAnchor` model keyed by metric. On each sync, run anchored query → receive only new + deleted samples → upsert.
  2. For the five sleep-stage metrics, do a single `HKAnchoredObjectQuery` over `.sleepAnalysis` and partition results to all five `MetricTimeSeries` in one pass, eliminating 4× duplicate sample materialization.
  3. Keep `HKStatisticsCollectionQuery` for the existing daily-bucket metrics (steps, active energy, etc.) — those are already efficient.
- **Confidence:** 93/100 — the absence of `HKAnchoredObjectQuery` outside `Modules/Live/` is grep-verified. What's not measured is the actual ms saved on a real device with a mature HealthKit store; the magnitude estimate above is from Apple's own HKAnchoredObjectQuery documentation rather than a Time Profiler trace on a Laso build.

---

## F3. Five "Scorer" engines each call `MainActor.assumeIsolated { store.loadAllTimeSeries() }` from inside their `compute(from:)` methods. When `computeNewEngines` runs on the main actor (it does), the assumption holds; but the call still funnels every scorer through a synchronous main-thread cache lookup, and the pattern is fragile under any future refactor that moves a scorer to a detached Task.

- **Severity:** High
- **Issue:** `VitalityScorer.swift:338`, `StressScorer.swift:198`, `BrainHealthScorer.swift:155`, `StrainScorer.swift:164`, `GamificationEngine.swift:182` (and `VitalityScorer.swift:660` for `loadScoreHistory`) all do:

  ```swift
  allSeries = MainActor.assumeIsolated { store.loadAllTimeSeries() }
  ```

  This is a runtime assertion: if the calling thread is *not* the main actor, the process traps. The call sites are reached via `DashboardViewModel.computeNewEngines` (`Modules/Dashboard/ViewModels/DashboardViewModel.swift:1288`), which is invoked inside `await MainActor.run { … computeNewEngines(todayRawHR:) }` (line 884) and at `init` time (line 635 path). So today, in practice, the assumption is met.
- **Two real perf consequences (independent of the safety risk):**
  1. **Synchronous main-thread fan-out.** `computeNewEngines` computes Strain → Stress → BrainHealth → SleepDebt → SleepNeed → Gamification → Vitality back-to-back, on the main actor, *blocking the UI* until each finishes. The memoization at lines 1293-1310 (input-hash + same-day skip) helps when nothing changed, but on every refresh that *does* fetch new data, this entire chain runs on the main thread. Each scorer iterates over the full 10-year-deep time series for its metrics, computes baselines, builds daily histories. This is exactly the workload that should be `Task.detached(priority: .userInitiated)` and produce a `Sendable` snapshot that gets hopped back to the main actor for UI bind.
  2. **Repeated full-store reads.** Every scorer calls `loadAllTimeSeries()` even when the caller already has the freshly synced `timeSeries` dictionary in memory. The compute methods *do* accept an optional `timeSeries` parameter; when DashboardViewModel passes it (which it does in `computeNewEngines`, line 1342, 1345, 1391), the `MainActor.assumeIsolated` branch is skipped. Good. But several other call sites (e.g. line 602: `brainHealthScorer.compute(from: store, timeSeries: nil)`, line 605, 609 in the older init path) explicitly pass `nil`, forcing a full main-actor cache read each time even right after one was cached.
- **Evidence:**
  - `Core/Analysis/VitalityScorer.swift:332-338` (signature + `MainActor.assumeIsolated` branch).
  - `Core/Analysis/StressScorer.swift:193-199`.
  - `Core/Analysis/BrainHealthScorer.swift:155`.
  - `Core/Analysis/StrainScorer.swift:164`.
  - `Core/Analysis/GamificationEngine.swift:182`.
  - `Modules/Dashboard/ViewModels/DashboardViewModel.swift:602-618` (init path passes `nil`); `:1288, :884` (refresh path).
- **Fix:**
  1. Mark every `compute(from:…)` `@MainActor`, then drop `MainActor.assumeIsolated` (it adds a runtime check that must be paid every call). After that, decide explicitly whether each scorer should hop off the main actor — most should: their inputs are immutable `[HealthMetric: MetricTimeSeries]` snapshots already, and their outputs are `Sendable` value types. Use `Task.detached(priority: .userInitiated)` from `computeNewEngines`, and a single `await MainActor.run` to publish results.
  2. Remove the `nil`-passing call sites in the init path; always pass the freshly-loaded `timeSeries` so the scorer never has to reach back into SwiftData.
- **Confidence:** 92/100 — the pattern and call sites are read end-to-end; what's not directly measured is the wall-clock cost of one `computeNewEngines` cycle on a real device with 1+ year of data. Estimated ≥80 ms per refresh under the listed memoization-miss path based on the per-scorer code volume.

---

## F4. `BreathworkLiveActivityWidget` runs four independent `TimelineView(.periodic(from: .now, by: 1))` redraw loops simultaneously while the activity is on the lock screen + Dynamic Island. Two of them rebuild full `HStack` content trees every second when `Text(timerInterval:)` would let the system tick the timer for free.

- **Severity:** Medium
- **Issue:** Live Activities have a per-process and per-process-day update budget enforced by ActivityKit. Apple's guidance is to use `Text(timerInterval:countsDown:)` (lines 119, 144) which is pure layout — no Swift redraws of the surrounding tree — for time-only displays, and to keep `TimelineView` for content that genuinely depends on `timeline.date` (e.g. computing which breathing phase the user is in). The widget conflates the two:
  - `BreathworkLiveActivityWidget.swift:21-32` — `DynamicIsland(.bottom)` rebuilds a full `HStack { Image + Text(phase) + Text(subtitle) }` every 1 s. Phase changes happen at most every 1-6 s for cyclic sighing / box breathing, so >80% of the redraws produce identical content.
  - `BreathworkLiveActivityWidget.swift:57-93` — the lock-screen view rebuilds the whole 3-column layout (icon + status text + countdown) every 1 s. The `Text(timerInterval:)` already inside it (line 119) does its own ticking; surrounding redraws are wasted.
  - `BreathworkLiveActivityWidget.swift:137-153` (`BreathworkTimerLabel`) and `:163-180` (`CompactTimerText`) — both wrap `Text(timerInterval:)` (or computed `seconds/60` math) in another 1 s `TimelineView`, so the whole label tree is rebuilt 1× per second despite `timerInterval` being self-ticking.
- **Why it costs:** Live Activity redraws happen even when the device is locked (the system runs the widget extension to render to the lock screen and Dynamic Island). On battery-constrained devices and during hot thermal states, this is exactly the kind of work iOS will eventually budget-throttle — but until then, it burns watts and battery for no user-visible benefit during the long majority of seconds when nothing changes.
- **Evidence:** `LasoWidgets/BreathworkLiveActivityWidget.swift:21, 61, 141, 167`. `WindDownLiveActivityWidget.swift:163` uses 60 s, which is fine.
- **Fix:**
  1. Drop the outer `TimelineView` in `BreathworkLiveActivityView` and `BreathworkTimerLabel` / `CompactTimerText`; rely on `Text(timerInterval:countsDown:)` for the countdown.
  2. For the breathing-phase HStack, replace `TimelineView(.periodic(by: 1))` with `TimelineView(.periodic(by: phaseDuration))` keyed off `protocolType` so SwiftUI only invalidates when a phase boundary passes. Phase math (`phase(at: timeline.date, context:)`) only needs to recompute on phase change, not every second.
  3. Verify with the `WidgetKit` "Live Activity" debug overlay (Xcode 15+ shows update count per activity).
- **Confidence:** 88/100 — code paths read and matched against Apple's WWDC 23 "Update Live Activities with push notifications" guidance for `timerInterval`; not yet verified by running the widget against the iOS 17 budget log to count actual redraws/sec.

---

## F5. PostHog `sessionReplay = true` is enabled on every session, in production. Even with text/image masking it imposes continuous sampling-and-encoding work on the main actor.

- **Severity:** Medium
- **Issue:** `Core/Tracking/PostHogManager.swift:29` enables PostHog Session Replay unconditionally for every iOS launch (gated only by `UITestMode`). PostHog's Session Replay records UI snapshots periodically and uploads them; `maskAllTextInputs`, `maskAllImages`, `maskAllSandboxedViews` cover *what* gets recorded, not *whether* it gets recorded. The cost is paid on every app session: snapshot capture, view-tree traversal for masking, encode, queue, upload. For a health app where each session is short and frequent (the very habit pattern this codebase is built around — see `AppAnalytics.detectHabitPattern`), the per-session overhead is amplified.
- **Why this matters specifically here:**
  - The Home dashboard is dense (`HomeView.swift` LOC 826, multiple `LazyVStack` cards, charts, intelligence briefing, metric strip, weekly review entry). Snapshotting the full view tree under masking has non-trivial main-actor cost on lower-end devices (iPhone 12 / 12 mini are still in the iOS 17 baseline).
  - Battery and network are amplified by the upload pipeline. PostHog default behavior batches and uploads on app background or interval; for a session-rich, short-session app like Laso, this is a steady drip of cellular data and radio wake.
  - Privacy-reviewed apps in App Store Review with Session Replay enabled have been flagged in the past for unclear consent flows (this audit doesn't cover privacy/consent — handled by the compliance agent — but it's worth flagging that the perf cost has a sibling compliance cost).
- **Evidence:** `Core/Tracking/PostHogManager.swift:21-40` shows `config.sessionReplay = true` is set unconditionally inside `#if os(iOS)`. No remote-config kill switch, no opt-in gate, no sampling rate.
- **Fix:**
  1. Set `sessionReplay = false` by default in production and gate it behind a remote config flag (`RemoteConfigManager.shared.sessionReplayEnabled`) so you can turn it on for a small percent of users when investigating UX, off otherwise.
  2. If kept on, set a sample rate (PostHog supports `sessionReplayConfig.minimumSnapshotInterval` and similar throttles in newer SDK versions) so the recording interval is ≥5 s, and enable only on subscribed/onboarded users (zero value to record an unauthenticated session).
- **Confidence:** 86/100 — config flag verified by direct read; impact magnitude relies on PostHog's documented behaviour rather than a Time Profiler trace inside Laso. The fix is a one-line config flip and known-safe.

---

## F6. `WebExportViewModel.exportReport()` runs the entire HTML+SVG report generation synchronously on the `@MainActor`. With the user's full 30-day per-metric chart series + insights this can block the main thread for hundreds of ms on real devices.

- **Severity:** Medium
- **Issue:** `Modules/WebExport/ViewModels/WebExportViewModel.swift:21-54` calls `HTMLReportGenerator.generate(...)` on the same actor that the View is using. `HTMLReportGenerator.generate` (`Modules/WebExport/HTMLReportGenerator.swift:6-63`) iterates `HealthCategory.allCases × category.metrics`, building per-metric chart sections, score sections, insight cards, and the full report template into a `String`. It then writes the file, sets `URLFileProtection.complete`, and only after all that does it set `isExporting = false`. The user sees a frozen UI for the duration of the build + write.
- **Why the synchronous build is bad:** with ~30 metrics × 30 days each, plus the SVG progress ring, plus templating, plus Chart.js bundle interpolation, the string built for a real user is in the tens-to-hundreds of KB. String concatenation that big on the main actor adds noticeable jank, and the disk write is also synchronous (`html.write(to:atomically:encoding:)` blocks on completion). On a thermally-throttled device this can easily exceed one runloop frame budget several times over.
- **Evidence:**
  - `Modules/WebExport/ViewModels/WebExportViewModel.swift:5-7` — `@MainActor @Observable final class WebExportViewModel`.
  - `Modules/WebExport/ViewModels/WebExportViewModel.swift:21` — `func exportReport()` (sync, no `Task.detached`, no `await`).
  - `Modules/WebExport/ViewModels/WebExportViewModel.swift:27-44` — synchronous `let html = HTMLReportGenerator.generate(...)` + synchronous `try html.write(to:…)`.
- **Fix:** make `exportReport()` `async`, dispatch the generation to `Task.detached(priority: .userInitiated)`, await its result, then write to disk via `try await Task.detached { try html.write(to:…) }.value`. Update the call site to `await viewModel.exportReport()` and show a determinate spinner via `isExporting`.
- **Confidence:** 90/100 — code path read end-to-end. Magnitude depends on device + data volume; not measured. The fix is a textbook async migration.

---

## F7. `HealthDataStore.loadAllTimeSeries()` returns the *entire* historical sample set materialized into Swift values on every cache miss. There is no fetch limit, no date filtering at the SwiftData layer, and no streaming. Cache invalidation is coarse — *any* change to *any* metric blows the entire `allSeriesCache` and forces the next reader to re-materialize everything.

- **Severity:** Medium
- **Issue:**
  - `Core/Data/HealthDataStore.swift:336-369` — `loadAllTimeSeries` does an unbounded `FetchDescriptor<StoredDailySample>()`, sorts by `.date`, then iterates and groups by metric in Swift. With 10 years × 30 metrics × 1 sample/day = ~110 K records, that's a single SQLite query returning every row plus 110 K Swift allocations on the main actor.
  - `Core/Data/HealthDataStore.swift:227-235` (`invalidateTimeSeriesCache(for:)`) explicitly comments: *"The allSeriesCache is a single dictionary for all metrics, so it must be cleared if any metric changes"*. So when a single metric's samples change after a HealthKit sync, the next reader rebuilds the entire dictionary — even though the readers (scorers) only need a small subset of metrics each.
  - The cache itself lives on a `@MainActor` `@Observable` class. Writers run on the main actor; readers (scorers) run on the main actor under `MainActor.assumeIsolated`. Any concurrent writer would currently trap (no concurrent writers exist, but the lock posture is brittle).
- **Why this matters:**
  - Cold open after a long absence: HK sync writes ~30 metrics' worth of new samples. Each `saveSamples(...)` call invalidates and `updateSeriesCaches` for that metric (line 198 onward), but `invalidateTimeSeriesCache(for:)` is called at the end of `loadAndSync` once with the full set, blowing `allSeriesCache`. The next consumer (any scorer that takes the `nil` branch, or `HealthKitManager.loadAndSync`'s own line 416 fallback) does a full materialize.
  - Memory pressure: at peak, the entire `[HealthMetric: MetricTimeSeries]` dict is held twice — once in `HealthKitManager.timeSeries`, once in `HealthDataStore.allSeriesCache` — both `@Observable`, both retained until the app is backgrounded.
- **Evidence:**
  - `Core/Data/HealthDataStore.swift:160-235, 336-369`.
  - `Core/Data/HealthDataStore.swift:480-540` — `loadAllAnalysisSnapshots`, `loadBaselineHistory(for:)`, `loadAllBaselineHistory(forMetrics:minCount:)` all do unbounded fetches and JSON-decode every snapshot in Swift.
- **Fix:**
  1. Make `loadAllTimeSeries` accept an optional `forMetrics: Set<HealthMetric>` parameter, push the filter into the `#Predicate`, and update the cache to a per-metric layout (`metricSeriesCache` already exists; promote it to the only cache and drop `allSeriesCache`).
  2. For `loadAllBaselineHistory`, page in batches by date predicate instead of fetching every snapshot every call. The "last 90 days" subset is enough for trajectory + drift detectors.
  3. Pre-bound the SwiftData fetch: most consumers care about ≤ 1 year, not 10. Add `.fetchLimit` + a date predicate. If a screen genuinely needs the full span (Explore "days of data" counter), give it a count-only fetch (`fetchCount` already used elsewhere).
- **Confidence:** 88/100 — code paths confirmed; the actual ms-per-call has not been profiled. The cache-coarseness comment in the source is its own admission.

---

## F8. `dashboardObserverDebounce: Duration = .seconds(8)` plus `enableBackgroundDelivery(.immediate)` for six core metrics produces a refresh storm whenever Apple Watch syncs. Each background delivery wakes the app, debounces 8 s, then triggers `refreshOnForegroundIfNeeded()` → which itself is throttled to 30 s — so the second-through-N pings are dropped by the throttle, but only after 8 s of debounce timer churn each.

- **Severity:** Low
- **Issue:** Two debouncers in series with overlapping windows:
  - `Core/Data/HealthKitManager.swift:1074` — observer debounce 8 s.
  - `Modules/Dashboard/ViewModels/DashboardViewModel.swift` — `foregroundRefreshMinInterval` (30 s) and `refresh()` debounce 0.5 s.
  - When Watch syncs N metrics in a burst, each metric's observer fires immediately, schedules an 8 s sleeping `Task`, then six tasks all fire `onCoreDataChanged()` ~8 s later. Five of them are then dropped by `refreshOnForegroundIfNeeded`'s 30 s throttle. The sleeping Tasks still consume scheduler attention.
- **Why it's only Low:** the work each sleeping Task does is `try? await Task.sleep(...)`; cheap. But the design pattern is wrong — there should be a *single* debounced trigger across all metrics, not one per metric.
- **Fix:** in `setupDashboardObservers`, use one shared debouncer (a single `Task` reset by every observer ping) instead of one Task per metric stored under `dashboardObserverDebounceTask: Task<Void, Never>?`. The current implementation already collapses into one task because the property is single-valued (`scheduleDashboardObserverRefresh` cancels and replaces) — re-read confirms this is fine. **Downgrading severity** to Low/cosmetic. Keep finding for review.
- **Evidence:** `Core/Data/HealthKitManager.swift:1071-1135`, `Modules/Dashboard/ViewModels/DashboardViewModel.swift:728-740`.
- **Confidence:** 92/100 — verified the debouncer is single-valued so the storm collapses correctly. Net cost is minor.

---

## F9. `AppAnalytics.swift` is 3 201 LOC and `DashboardViewModel.swift` is 2 253 LOC. Compile-time + first-render impact compounds with the Observable-based reactivity model.

- **Severity:** Medium
- **Issue:** Single Swift files >2 K LOC are a known compile-time hot spot in Swift 5.9 + strict-concurrency mode (lots of inferred types, lots of escaping closures, lots of generic constraints). Beyond compile time, oversized `@Observable` classes inflate the observer-tracking metadata SwiftUI inserts: every property read inside a SwiftUI body subscribes to that property. With ~100+ stored properties on `DashboardViewModel`, even SwiftUI's keypath-based tracking has to evaluate the full property set when constructing the dependency graph the first time the View body runs.
- **Worst offenders (by LOC, top 12):**

  | File | LOC |
  |------|-----|
  | `Core/Tracking/AppAnalytics.swift` | 3 201 |
  | `Modules/Dashboard/ViewModels/DashboardViewModel.swift` | 2 253 |
  | `Core/Analysis/ML/HealthDataQueryEngine.swift` | 1 819 |
  | `Core/Analysis/ML/DecisionPolicyEngine.swift` | 1 750 |
  | `Core/Analysis/ML/PredictiveHealthSignals.swift` | 1 698 |
  | `Core/Analysis/ML/TemporalSequenceMiner.swift` | 1 574 |
  | `Core/Analysis/ML/CompoundInsightEngine.swift` | 1 308 |
  | `Core/Data/HealthKitManager.swift` | 1 243 |
  | `Core/Analysis/ML/HealthStateClassifier.swift` | 1 195 |
  | `Core/Analysis/ML/TodayIntelligenceEngine.swift` | 1 117 |
  | `Core/Analysis/ML/GrangerCausalityEngine.swift` | 1 070 |
  | `Modules/Live/ViewModels/LiveViewModel.swift` | 1 061 |

- **Evidence:** `find . -name "*.swift" -exec wc -l {} + | sort -rn | head -30` (run during audit).
- **Fix:**
  1. Carve `AppAnalytics` into `AnalyticsEvents+Onboarding.swift`, `+Engagement.swift`, `+Performance.swift`, `+Errors.swift` extensions on the same `AppAnalytics` class.
  2. Split `DashboardViewModel` into a coordinator + a set of small `@Observable` sub-state classes (the existing nested-class pattern in `AnalysisEngine` is the right model — replicate it). Most of `DashboardViewModel`'s cached-property surface is already grouped (`scores: Scores`, `insights: Insights`, etc.) — push the *methods* into per-feature extensions in their own files.
  3. ML engines should each live in their own submodule directory (already true), but each ≥1 000-LOC file would benefit from being split into `+Train.swift` and `+Predict.swift` extensions.
- **Confidence:** 80/100 — LOC numbers verified. The compile-time impact and observer-metadata inflation claims are well-known but not directly profiled here; they're rules of thumb from the Swift compiler team rather than measured wall-clock numbers on this codebase.

---

## F10. `HomeFirstLaunchLoadingView` uses `Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true)` to drive a "loading dots" animation. Acceptable in isolation, but it is created without an `onDisappear` cleanup contract that's visible at the call-site, and the `dotTimer` is a `@State` reference, so if the parent view is reconstructed mid-animation a leaked timer is possible.

- **Severity:** Low
- **Issue:** `Modules/Dashboard/Views/Home/HomeFirstLaunchLoadingView.swift:81-89`. Standard Swift pattern that works under normal lifecycle, but `@State` storage of a `Timer` reference is unusual; verify in code review that the matching `.invalidate()` happens in `onDisappear`. If the View is hidden via a parent's `if` rather than `onDisappear` triggering, the timer keeps firing.
- **Evidence:** `Modules/Dashboard/Views/Home/HomeFirstLaunchLoadingView.swift:81-89`.
- **Fix:** prefer `TimelineView(.periodic(by: 0.5))` (auto-paused when offscreen) or `withAnimation` + `Animation.linear(duration: 0.5).repeatForever`. Either eliminates the Timer + `@State` pairing entirely.
- **Confidence:** 75/100 — only the `Timer.scheduledTimer` line was confirmed; the surrounding lifecycle was not read end-to-end. Treat as a hint to verify rather than a confirmed leak.

---

## F11. `Live Activity` programmatic-end is fire-and-forget via `Task { await existing.update(content) }` and `Task { await existing.end(...) }`. Multiple updates queued before the previous one completes can flicker the lock-screen content and waste budget.

- **Severity:** Low
- **Issue:**
  - `App/TodayScoreLiveActivityManager.swift:86-88`, `:143-145` — every `updateOrStart` and `end` spawns a detached Task that awaits the activity update. No serialization. If `pushTodayScoreLiveActivity()` is called twice in rapid succession (e.g., a burst of refreshes after a HealthKit sync + a foreground return), two `Activity.update` Tasks race; ActivityKit will process them, but the second one's content state will overwrite the first one out-of-order if the network/system is slow. Probability is low; consequence is brief content flicker on lock screen.
  - Same pattern in `App/WindDownLiveActivityManager.swift:87-89, 137-139, 157`.
- **Fix:** use a single serial actor (or a `Task` chain stored on the manager) so `update/end` calls execute strictly in order. Alternative: throttle updates to ≥10 s gaps via a simple `lastUpdateAt` field (Apple recommends 10 s gaps for Live Activity content; the brief mentions this).
- **Evidence:** `App/TodayScoreLiveActivityManager.swift:86, 143`; `App/WindDownLiveActivityManager.swift:87, 137`.
- **Confidence:** 78/100 — code read; race-window magnitude not measured. Throttle-to-10 s recommendation is from Apple's HIG for Live Activities.

---

## F12. `HealthDataContainerFactory` schema-version key is `currentSchemaVersion = allModels.count`. Adding a property to an existing model — or removing a model — leaves the count unchanged → migration silently does nothing → SwiftData throws on launch and the fallback tier kicks in.

- **Severity:** Medium (correctness; performance fallout when DB recreates)
- **Issue:** `Core/Data/HealthDataContainerFactory.swift:31` derives the schema version from the count of model types. Real schema migrations happen for any of: a new property on an existing model, a renamed property, a removed model. Two of those three are silent under this scheme. When the schema does change (e.g., adding a Bool to `StoredDailySample`), the count is the same, the version stays the same, no migration is attempted, the `ModelContainer` initialization throws on launch, the file is deleted (`removeDatabaseArtifacts` line 35 + retry), and the user loses their entire on-device history. They re-sync 10 years of HealthKit on the next foreground — that *is* the perf event this audit cares about.
- **Evidence:** `Core/Data/HealthDataContainerFactory.swift:30-42`.
- **Fix:** version manually with a constant integer that the developer increments on any schema-impacting change. Better: adopt SwiftData's `Schema` versioning APIs (`SchemaMigrationPlan`, `VersionedSchema`).
- **Confidence:** 90/100 — logic verified; impact magnitude depends on whether Laso has shipped any schema migrations yet, which I did not check git-blame for.

---

## F13. Insights / Detail / Discovery views use plain `ScrollView { VStack { ForEach } }` instead of `LazyVStack`. With many insights/cards, all rows are eagerly built on view load.

- **Severity:** Low (data volumes typically small) → Medium (worst-case mature users)
- **Issue:**
  - `Modules/Insights/Views/Insights/InsightsDetailView.swift:76-145` — `ScrollView { VStack(...) { … ForEach(displayedItems) { … } … } }` (no `LazyVStack`). Each `displayedItems` element materializes an `EnrichedInsightCard` at first render.
  - `Modules/Journal/Views/Journal/JournalInsightsView.swift:9` — same pattern (read shallowly; confirm).
  - `Modules/Dashboard/Views/Home/HomeView.swift:232-388` does use `LazyVStack` correctly. So the codebase knows the pattern; it's inconsistently applied.
- **Why it matters:** a user with 50+ insights (mature account, ML pipeline running) will pay an O(N) view-construction cost on every navigation to InsightsDetailView, including off-screen rows.
- **Fix:** wrap the `ForEach` body in `LazyVStack(spacing: …)` inside the `ScrollView`. Verify `EnrichedInsightCard` produces a stable `id` (it appears to via `Insight: Identifiable`).
- **Evidence:** `Modules/Insights/Views/Insights/InsightsDetailView.swift:76, 100-122`.
- **Confidence:** 85/100 — `InsightsDetailView` confirmed; other views grepped but not deep-read.

---

## F14. `JSONEncoder()` / `JSONDecoder()` are constructed fresh inside `@MainActor` paths called per-sample-write (snapshot/save) rather than reused. `HealthDataStore` already has thread-local encoder/decoder; the rest of the codebase doesn't.

- **Severity:** Low
- **Issue:**
  - `Core/Data/HealthDataStore.swift:165-196` — defines `threadEncoder()/threadDecoder()` for thread-local reuse. Good. Used inside the store's own snapshot/strain/baseline paths.
  - Outside the store, every other Codable use-site allocates a fresh encoder/decoder per call:
    - `Core/Analysis/VitalityScorer.swift:298, 319`
    - `Core/Analysis/StrainScorer.swift:121, 143`
    - `Core/Analysis/MenstrualCycleTracker.swift:155, 187`
    - `Core/Analysis/ML/PredictiveScorer.swift:601-603, 616-622`
    - `Core/Analysis/ML/MLTypes.swift:164, 174`
    - `Modules/Dashboard/ViewModels/DashboardViewModel.swift:1419, 1429`
    - `App/ActivationSequenceManager.swift:124, 237`
- **Why it's only Low:** `JSONEncoder()` allocation is fast (~µs). At dozens of allocations per refresh, the cost is real but bounded. It does add allocator pressure and is trivially fixable.
- **Fix:** lift the same `threadEncoder()/threadDecoder()` pattern into a `Foundation+Codable.swift` extension and replace every fresh-allocation site. Or simpler: declare `private static let encoder = JSONEncoder()` inside each scorer.
- **Evidence:** grep `"JSONEncoder()\|JSONDecoder()"` in `Core/Analysis` + `Modules` + `App` — 33 hits, mostly construction inside hot paths.
- **Confidence:** 88/100.

---

## F15. `pushTodayScoreLiveActivity()` is called inside `refreshCore` on every refresh that completes successfully, with no rate limit. Apple recommends ≥10 s between Live Activity content updates, otherwise the system silently drops or coalesces them.

- **Severity:** Low
- **Issue:** `Modules/Dashboard/ViewModels/DashboardViewModel.swift:899` (`pushTodayScoreLiveActivity()` inside `await MainActor.run { … }` after every refresh). With multiple refresh triggers — foreground return, observer ping, BGTask wake, manual pull — this can hit the activity manager more than once every 10 s. The manager itself does not throttle; it just calls `existing.update(content)` (line 87 of `TodayScoreLiveActivityManager.swift`).
- **Fix:** track `lastTodayScoreUpdate: Date` inside `TodayScoreLiveActivityManager` and short-circuit if `< 10 s` since the previous update *unless* the score band changed (e.g., crossed 70 → 65).
- **Evidence:** `App/TodayScoreLiveActivityManager.swift:84-103`, `Modules/Dashboard/ViewModels/DashboardViewModel.swift:899`.
- **Confidence:** 82/100 — the missing throttle is unambiguous; the actual update cadence in production depends on how often refreshes actually complete (not measured).

---

## F16. `WidgetCenter.shared.reloadAllTimelines()` is called from the background task whenever the readiness snapshot changes. There is no per-widget reload (`.reloadTimelines(ofKind:)`) and the analysis widget reloads every 15 minutes regardless.

- **Severity:** Low
- **Issue:**
  - `App/BackgroundRefreshCoordinator.swift:115` — `WidgetCenter.shared.reloadAllTimelines()`. Force-reloads every widget extension Laso ships (Analysis, Live Activity widgets, etc.) even when only the readiness card changed.
  - `LasoWidgets/AnalysisWidgetProvider.swift:17-18` — `Timeline(entries: [entry], policy: .after(refreshDate))` with `refreshDate = +15 min`. Acceptable cadence (Apple's daily budget is ~40-70 reloads), but combined with the all-timelines reload from BG and from foreground analysis, the actual reload rate can spike.
- **Fix:**
  1. Replace `reloadAllTimelines()` with `reloadTimelines(ofKind: "AnalysisWidget")` so only the affected widget refreshes.
  2. Make the periodic 15 min budget adaptive: if the snapshot didn't change, return `policy: .after(now + 60 min)` to spare reloads.
- **Evidence:** `App/BackgroundRefreshCoordinator.swift:115`; `LasoWidgets/AnalysisWidgetProvider.swift:15-19`.
- **Confidence:** 88/100.

---

## F17. `BackgroundRefreshCoordinator.handle(_:)` includes a hard `try? await Task.sleep(for: .seconds(delay))` (`completionDelay`) before declaring the task complete. With `completionDelay > 0` this burns the wake budget for nothing.

- **Severity:** Low
- **Issue:** `App/BackgroundRefreshCoordinator.swift:101` — after `liveViewModel.fetchHomeData[Tiered]()`, the task sleeps for `delay` seconds (default `AppConstants.BackgroundTask.completionDelay`) supposedly to let HealthKit finish syncing. This pattern is brittle: if the actual fetches are async (HealthKit fetches are), a fixed sleep doesn't synchronize with their completion; it just wastes wall time inside the wake budget. A 30 s wake with even a 5 s blind sleep means 17 % of the budget is sleep.
- **Evidence:** `App/BackgroundRefreshCoordinator.swift:77, 101`.
- **Fix:** await the actual `fetchHomeData[Tiered]()` completion. Currently `LiveViewModel.fetchHomeData()` is `func fetchHomeData()` (sync, fires-off async sub-tasks). Make it async + return when its sub-tasks complete (or expose a `Task.value` to await). Drop the blind sleep.
- **Confidence:** 86/100 — code read; `AppConstants.BackgroundTask.completionDelay` value not inspected (could be 0, which makes this benign).

---

## F18. `RecoveryHeroCard` repeatedly animates a pulse `.repeatForever(autoreverses: true)` regardless of thermal state. Combined with `AskDataOrbView`'s 30-fps Canvas (which *is* thermal-aware) and Live Activity tickers, the Home screen runs continuous animation work.

- **Severity:** Low
- **Issue:** `Modules/Dashboard/Views/Home/RecoveryHeroCard.swift:69` — `.animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)`. Always on. AskDataOrbView at line 81 of `AskDataOrbView.swift` does correctly thermal-gate (line 78: `if thermalManager.shouldThrottle { staticOrb }`). RecoveryHeroCard does not.
- **Fix:** wrap the pulse with `if !ThermalManager.shared.shouldThrottle` like the orb does. Or use `Animation.linear(duration: 1.1).repeatForever()` only when the View becomes visible and stop when `scenePhase != .active`.
- **Evidence:** `Modules/Dashboard/Views/Home/RecoveryHeroCard.swift:69`.
- **Confidence:** 78/100 — animation present; visual impact and CPU cost not measured.

---

## F19. `ContentView`-level `task(id: appStateStore.onboardingCompleted)` calls `dashboardViewModel.load()` which in turn calls `healthKitManager.requestAuthorization()` — the system HealthKit prompt — *before* the user has reached the dashboard for the first time after onboarding completes. Onboarding already authorizes HealthKit, but `load()` re-requests, which is fine for permission state but pays a roundtrip to the HealthKit daemon every cold launch.

- **Severity:** Low
- **Issue:** `App/ContentView.swift:66-94` and `Modules/Dashboard/ViewModels/DashboardViewModel.swift:643-697` (`load`). `requestAuthorization` is idempotent — if the user already granted, it returns immediately. But the call still hops to the system extension. Over a cold launch path that's already crowded (Firebase + PostHog + HealthKit + SwiftData), every avoidable roundtrip matters.
- **Fix:** `if !healthKitManager.isAuthorized { await healthKitManager.requestAuthorization() }`. Currently the guard is implicit in `requestAuthorization` itself but the early-return only happens *inside* the call.
- **Confidence:** 82/100 — code read; the system-prompt cost is probably 2-10 ms (not 100 s).

---

## F20. `IntentDataProvider.fetchLastNightSleep()` and `:215` create a fresh `HKHealthStore()` per intent invocation. App Intents are short-lived processes by design, but creating a new HealthStore every time forces re-authorization checks against the daemon.

- **Severity:** Low
- **Issue:** `Core/Intents/IntentDataProvider.swift:46, 61, 215` — fresh `HKHealthStore()` per call. With Siri / Spotlight intents that the system fires speculatively, this is repeat fee for daemon roundtrips. Best practice: `static let healthStore = HKHealthStore()` (Apple's docs state HKHealthStore is intended to be singleton).
- **Fix:** lift to a `static let` or pass in via an explicit dependency container shared with the app process when running co-resident.
- **Evidence:** `Core/Intents/IntentDataProvider.swift:46, 215`.
- **Confidence:** 80/100.

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 3 |
| Medium | 6 |
| Low | 11 |

(F8 reclassified Low after re-read — the single-valued debouncer collapses correctly.)

### Top 3 to fix Now

1. **F1 — Eliminate the AppDelegate-spawned `BackgroundRefreshCoordinator`.** Wire the AppContainer's coordinator into `application(_:didFinishLaunchingWithOptions:)` so background wakes use the shared `HealthKitManager` + `ReadinessStore`. Stops cold-rebuilding HealthKit state every BG fire.
2. **F2 — Migrate per-sample HealthKit fetches to `HKAnchoredObjectQuery`.** Sleep stages alone are 5× redundant today. Add `StoredHealthKitAnchor` model, anchor-keyed sync. Biggest single throughput win for steady-state syncs and BGTask budget.
3. **F3 — Move scorer fan-out off the main actor.** `computeNewEngines` chains 6+ scorers on the main thread synchronously. Detach to `Task.detached(priority: .userInitiated)`, hand back `Sendable` snapshots. Removes the largest UI-jank window during dashboard refresh.

### Top 3 to fix This Week

4. **F5 — Disable PostHog `sessionReplay` by default + remote-config gate it.** One-line config flip; recurring CPU + battery + network savings.
5. **F4 — Collapse Breathwork Live Activity TimelineViews to phase-boundary cadence.** Use `Text(timerInterval:)` for countdowns; `TimelineView(.periodic(by: phaseDuration))` for phase math. Cuts widget redraws by an order of magnitude.
6. **F6 — Async-detach `WebExportViewModel.exportReport()`.** Today the entire HTML build runs on @MainActor; one wrap into `Task.detached` removes a clear "frozen tap" UX.

### Sub-areas checked clean

- **Live tab streaming (`LiveViewModel`)** — uses `HKAnchoredObjectQuery` correctly for HR / SpO2 / respiratory; UI updates throttled to 1 Hz (`lastUIUpdateTime`); thermal-aware.
- **`@Observable` adoption** — Dashboard and Live correctly use Observation framework, not legacy `@StateObject`/`@ObservedObject`. No retained-object/re-init bugs found.
- **HomeView virtualization** — `LazyVStack` inside `ScrollView` is correct.
- **Asset catalog size** — `Assets.xcassets/` is 108 KB. Not a concern.
- **No `URLCache` / `Kingfisher` / `SDWebImage`, no `AsyncImage`** — image content is asset-based, no remote image cache needed. Profile photos appear to be local-only.
- **Firestore footprint** — minimal (`Modules/Referral/Services/ReferralManager.swift` only). No dashboard listeners; no `.snapshotListener` cascading risk.
- **Image / animation budget** — `AskDataOrbView` and `VitalityOrganicOrb` are thermal-aware; per-frame work is path-free with pre-computed cache.
- **Sleep-boundary derivation (`refreshSleepBoundaries`)** — properly bounded to the 14-day window when SleepCoach opens; not blanket-fetched on launch.
- **Dashboard observer fan-out (F8)** — single-valued debouncer collapses metric-burst pings into one refresh.
- **`HealthDataStore` thread-local Codable** — already optimized at the storage layer; mainly the *callers* outside the store are the issue (F14).
- **Memoization in `computeNewEngines`** — input-hash + same-day skip is well-designed (Modules/Dashboard/ViewModels/DashboardViewModel.swift:1293-1310).

---

**Confidence: 87/100** — most findings cite verified file:line and were read end-to-end (F1, F2, F3, F4, F5, F6, F7, F12, F14). Two findings rely on Apple's documented behavior rather than direct measurement on a Laso build (F4 magnitude, F5 magnitude). No runtime profiling, no Time Profiler trace, no Instruments allocation snapshot was performed — those would tighten the magnitude estimates by 10-15 % but would not change the prioritization.
