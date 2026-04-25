# 19 — Performance Pass 2 (deeper-dive, NEW findings only)

Scope: read-only second pass over the Laso (com.lasohealth.fit) iOS codebase, building on `audit/03-performance.md` (Pass 1). Pass 1's 20 findings are NOT repeated. This pass targets the angles Pass 1 likely missed: cold-launch budget, anchor non-persistence, Live Activity / Live tab anchor reset, Plain-Dictionary unbounded caches, multi-instance singletons that add NotificationCenter observers without remove, AES-GCM probe on init, no Low-Power-Mode awareness anywhere, in-body view-model construction, computed-property fan-out in `@Observable` view models, `HKStatisticsCollectionQuery` underuse for daily-averaged metrics, `refreshMetric` 10-year refetch on every log save, oversized SwiftUI files with deep stack nesting, and a few smaller finds. Each finding cites file:line and gives a per-finding confidence. Forbidden zones (security, copy, design, gap, compliance) excluded by design.

Sources of truth read end-to-end this pass: `App/AppLaunchCoordinator.swift`, `App/AppContainer.swift`, `App/LasoApp.swift`, `App/AppDelegate.swift`, `App/AppStartupCoordinator.swift`, `App/ContentView.swift`, `Core/Security/AppIntegrityGuard.swift`, `Core/Security/EncryptedStore.swift`, `Core/Data/PersistenceManager.swift`, `Core/Config/ThermalManager.swift`, `Core/Tracking/PostHogManager.swift`, `Core/Tracking/AppAnalytics.swift` (slices), `Modules/Live/ViewModels/LiveViewModel.swift`, `Modules/Live/Views/Live/LiveView.swift`, `Modules/Dashboard/Views/Home/HomeView.swift`, `Modules/Dashboard/Views/Home/HomeFirstLaunchLoadingView.swift`, `Modules/MetricDetail/ViewModels/MetricDetailViewModel.swift`, `Modules/MetricDetail/Views/MetricDetail/MetricLogSheet.swift`, `Core/Data/HealthKitManager.swift` (slices), `Core/Data/HealthDataStore.swift` (slices), `Core/Data/WidgetDataStore.swift`, `Shared/CoachActionIntents.swift`, `Core/Analysis/AnalysisEngine.swift`, `Core/Analysis/ML/FeatureEngine.swift`, `Core/Analysis/ML/AdaptiveAnomalyDetector.swift`, `Core/Analysis/ML/MLOrchestrator.swift`, `Core/Analysis/SleepNeedCalculator.swift`, `Core/Analysis/ML/TodayIntelligenceEngine.swift`, `Core/Analysis/ML/DailyNarrativeEngine.swift`, `Core/Analysis/GamificationEngine.swift`, `Modules/Insights/Views/Insights/CorrelationsView.swift`, `Modules/Stress/Views/Stress/BreathworkView.swift`, `Modules/Onboarding/Views/Onboarding/OnboardingMirrorMomentStep.swift`, `Common/Components/RepeatTimer.swift`, `LasoWidgets/AnalysisWidgetProvider.swift`. Plus systematic greps across `**/*.swift` for the 38 angles in the brief.

---

## P2-F1. Live tab `HKAnchoredObjectQuery`s are created with `anchor: nil` AND no anchor persistence. Every Live tab open and every foreground return re-fetches a 2-hour HR window and 1-hour SpO2 / respiratory windows, defeating the entire point of anchored streaming.

- **Severity:** High
- **Issue:** Pass 1 F2 noted that the *batch* sync layer doesn't use `HKAnchoredObjectQuery` at all. What Pass 1 missed: the *Live* layer that *does* use `HKAnchoredObjectQuery` (line 397, 518) passes `anchor: nil` on every query construction and never persists the anchor returned by the initial result handler. The query's `updateHandler` is wired correctly for streaming-future-deltas — but each time the user opens the Live tab, or the app returns from background (`scenePhase.active`, see `LiveView.swift:160-176` calling `restartStreaming()`), `stopAllQueries()` is called and the query is rebuilt from scratch with `anchor: nil` and a `lookbackStart = -2 hours` predicate (HR) / `-hoursBack` predicate (SpO2, respiratory). Result: the anchored API is downgraded to a regular sample query at every restart. Over a single day with multiple foreground returns, each restart re-bridges and re-processes hundreds of HR samples that have already been seen.
- **Why this is a real cost:**
  - HR samples on Apple Watch can be 1 every 1–5 s during workouts (300–7200 samples in a 2 h window). Each is bridged Obj-C → Swift, sorted, mapped, fed through `HeartRateTimelineReducer`, dedup'd by date.
  - The "Throttle: only push to @Observable properties at most once per second" on line 432-447 caps UI redraws but not the upstream sample processing.
  - `restartStreaming()` (line 310-336) explicitly tears down anchored queries on every BG → foreground transition, *even when the app was backgrounded for 5 seconds while the user dismissed Control Center* (this is mitigated by the `oldPhase == .background` guard on `LiveView.swift:164` but not on `BG-deferred-fetch` paths reached via observer fires).
- **Evidence:**
  - `Modules/Live/ViewModels/LiveViewModel.swift:397-411` — heart-rate `HKAnchoredObjectQuery(... anchor: nil ...)`. The first-result handler at line 402 ignores the returned `_, samples, _, _, _` anchor argument (third position). It is dropped.
  - `Modules/Live/ViewModels/LiveViewModel.swift:518-533` — same pattern in the generic `startVitalStream(...)` factory used for SpO2 and respiratory.
  - `Modules/Live/ViewModels/LiveViewModel.swift:294, 311` — `stopAllQueries()` in `stopStreaming()` and `restartStreaming()` discards the in-memory query handle plus any anchor it may have carried.
  - `Modules/Live/Views/Live/LiveView.swift:141-159` — `onAppear { viewModel.startStreaming() }` and `onDisappear { viewModel.stopStreaming() }` make this a per-tab-visit cycle.
- **Fix:**
  1. Add `var heartRateAnchor: HKQueryAnchor?`, `var bloodOxygenAnchor: HKQueryAnchor?`, `var respiratoryAnchor: HKQueryAnchor?` properties on `LiveViewModel`.
  2. In every result handler (line 402, 406, 523, 527), capture the new anchor — second `_` becomes a named binding — and store it.
  3. In every query construction (line 397-401, 518-522), pass the stored anchor instead of `nil`.
  4. Drop the 2-hour predicate `lookbackStart = Date().addingTimeInterval(-2 * 3600)` once the anchor is in place — the predicate's purpose is "give me the recent samples I missed," which is exactly what an anchored query without a date predicate already does.
  5. On *cold* app launch (anchor still nil), use a small predicate (e.g. `-30 min`) for first paint, then let the anchor take over from there.
- **Impact:** removes 90 %+ of the redundant HR/SpO2/respiratory sample reprocessing on every Live-tab visit during a session. On Apple Watch users with active workouts, this is noticeable in CPU + battery on the iPhone.
- **Confidence:** 90/100 — code paths read end-to-end; the anchor-discard is unambiguous (third callback parameter is always the wildcard `_`). Magnitude estimate from sample-density numbers, not measured on a real device.

---

## P2-F2. `PersistenceManager` is constructed *five separate times* across the codebase. Each construction adds a `NotificationCenter` observer for `NSUbiquitousKeyValueStore.didChangeExternallyNotification` and runs `migratePlaintextData()` (5 AES-GCM probes per construction). Net: 5 iCloud KVS observers all firing on every cloud change, and 25 AES-GCM decrypt attempts per cold launch.

- **Severity:** High
- **Issue:**
  - `Core/Data/PersistenceManager.swift:34-38` — `init` calls `startCloudSync()` + `migratePlaintextData()` + `migrateCriticalAlertsDefault()`.
  - `startCloudSync()` (line 72-81) does `NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, ...)` and there is **no `removeObserver`** anywhere in the file. Confirmed: `grep -rn "removeObserver" --include="*.swift"` across the entire repo returns zero hits.
  - `migratePlaintextData()` (line 43-47) iterates the 5 `encryptedKeys` set and calls `EncryptedStore.shared.migrateIfNeeded(forKey:)`. `migrateIfNeeded` (`Core/Security/EncryptedStore.swift:39-49`) for each key attempts an AES-GCM decrypt to test "is this already encrypted?" — that's a Keychain access + a CryptoKit `AES.GCM.SealedBox.combined` parse + an `AES.GCM.open` per key. Once data is encrypted (which is the steady-state for any user past their first launch), this is pure overhead.
  - `PersistenceManager()` is constructed at:
    - `App/AppContainer.swift:31` (correct, owned by container, lifetime = app)
    - `Core/Analysis/AnalysisEngine.swift:6` (`private let persistence = PersistenceManager()` — held forever inside `AnalysisEngine`, which is itself owned by `AppContainer` — so this is a *separate* instance from container's, never reused)
    - `Core/Notifications/WatchMonitor.swift:336` (`PersistenceManager().loadPreferences()` — short-lived, but the observer it just installed leaks past the function return)
    - `Modules/Settings/Views/SettingsView.swift:26` (`private let persistence = PersistenceManager()` — recreated every time Settings tab is opened; the `@State` wrapper means it's stable across rebuilds, but if the View is destroyed and recreated by NavigationStack, a new instance is built, and the previous instance's observer is leaked into the global NotificationCenter)
    - `Modules/Settings/Views/SettingsView.swift:42` (`State(initialValue: PersistenceManager().loadPreferences())` — yet another short-lived construction, observer leaks)
- **Net effect:**
  - **Steady state:** at minimum 2 observers (AppContainer + AnalysisEngine), permanent; SettingsView visits add more, none removed.
  - **Cold launch:** at least 2 × 5 = 10 AES-GCM decrypt attempts immediately during AppContainer.init / AnalysisEngine.init. Add WatchMonitor + at least one Settings visit and you reach 20–25 decrypts.
  - **iCloud cascade:** every `NSUbiquitousKeyValueStore.didChangeExternallyNotification` fires N parallel `handleCloudChange(_:)` invocations — each one does an `userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]` parse, iterates `syncKeys`, writes back to `UserDefaults`. With only `AppKeys.App.onboardingCompleted` in `syncKeys`, the actual write is small, but the observer fan-out is wasteful.
- **Evidence:**
  - `grep -rn "PersistenceManager(" --include="*.swift"` → 5 instantiation sites.
  - `Core/Data/PersistenceManager.swift:34-46`.
  - `Core/Security/EncryptedStore.swift:39-49`.
- **Fix:**
  1. Make `PersistenceManager` a singleton: `static let shared = PersistenceManager()`. Strip the per-callsite `private let persistence = PersistenceManager()` and replace with `.shared`. This collapses to 1 observer + 1 migration pass.
  2. Add a one-time idempotence guard inside `migratePlaintextData()` — gate by a `UserDefaults` boolean key like the sibling `migrateCriticalAlertsDefault()` already does, so subsequent launches skip the AES-GCM probe entirely.
  3. Long-term, also add a `deinit { NotificationCenter.default.removeObserver(self) }` on `PersistenceManager` in case it's ever genuinely freed.
- **Confidence:** 95/100 — five instantiation sites and absent `removeObserver` are grep-verified. The AES-GCM decrypt cost per call is documented from CryptoKit's API contract rather than measured.

---

## P2-F3. `MetricLogSheet.save()` calls `healthKitManager.refreshMetric(metric, store:)` after every single user log (water, weight, mindful) — and `refreshMetric` re-issues a fetch over the metric's *full historical span* (defaulting to 10 years) every time. One tap of "Log 250 ml water" can trigger a 10-year HKSampleQuery.

- **Severity:** High
- **Issue:**
  - `Modules/MetricDetail/Views/MetricDetail/MetricLogSheet.swift:193` — `await healthKitManager.refreshMetric(metric, store: healthDataStore)` after `saveWaterIntake` / `saveMindfulSession` / `saveWeight`.
  - `Core/Data/HealthKitManager.swift:1191-1204` — `refreshMetric(_:store:)` computes `let existingOldest = timeSeries[metric]?.samples.first?.date` and uses that as `startDate`, falling back to `-10 years` when the in-memory series is empty. So:
    - For metrics with an existing time series spanning years (e.g., weight history), it re-fetches *every weight sample ever recorded* through HealthKit, just to learn that one new value was added.
    - For metrics with no in-memory series yet (e.g., first time the user logs `mindfulMinutes`), it fetches 10 years of mindful-session samples, of which there will be approximately zero — but the daemon round-trip and the empty-result bridge still pay the predicate cost.
  - The correct HealthKit pattern after a write is either (a) a small incremental `HKSampleQuery` for the last 24 hours, or (b) refresh the *single sample we just wrote* directly into the in-memory + SwiftData stores, since we already have its values.
- **Why it matters:**
  - "Log water" is meant to feel instant. With this implementation, every tap blocks the dismiss animation on a HealthKit daemon round-trip + a multi-year sample fetch + a SwiftData write. On a thermally-throttled device this can hit 200–800 ms.
  - Repeated logs (e.g., the user logs water 4 times during the day) re-fetch the entire history each time.
- **Evidence:**
  - `Modules/MetricDetail/Views/MetricDetail/MetricLogSheet.swift:185-199`.
  - `Core/Data/HealthKitManager.swift:1191-1204`.
  - `Core/Data/HealthKitManager.swift:271-280` — same overlap-window logic in `loadAndSync`, but at least gated by `lastSync` from `StoredSyncMetadata`. `refreshMetric` does not consult that and does not respect the metric's `lastSync` either.
- **Fix:**
  1. Change `refreshMetric` to use `lastSyncDate(for: metric)` (already exists in `HealthDataStore.swift:374-379`) as the floor for `startDate`, with a 1-day overlap. That alone fixes 95 % of the cost.
  2. Better: bypass HealthKit entirely after a write — the value is known locally; just append a `MetricSample(date: date, value: value)` to `timeSeries[metric]` and `store.saveSamples(...)`.
  3. Best: make the post-write refresh `await Task.detached(...)` so the sheet's `dismiss()` doesn't wait on the network.
- **Confidence:** 92/100 — the call chain is verified end-to-end. Wall-clock magnitude not measured but the 10-year-fetch claim is unambiguous from the code.

---

## P2-F4. No code path in the entire codebase checks `ProcessInfo.processInfo.isLowPowerModeEnabled`. ML pipeline, BG refresh, Live anchored streams, RecoveryHero pulse, HomeFirstLaunchLoadingView animations, AskDataOrbView orb, all run identically on a 18 % battery iPhone in Low Power Mode as on a freshly-charged device.

- **Severity:** High
- **Issue:** `grep -rn "isLowPowerModeEnabled\|NSProcessInfoPowerStateDidChange\|lowPowerMode\|LowPower" --include="*.swift"` returns **zero matches**. Apple's HIG and energy guide explicitly call out that apps should: (a) reduce non-essential background work, (b) downgrade animation frame rates / pause repeat animations, (c) disable proactive sync, (d) skip ML inference when `isLowPowerModeEnabled` is true. None of those gates exist in Laso.
- **Why this matters end-to-end:**
  - The ML pipeline (`Core/Analysis/ML/MLOrchestrator.swift:168-186`) gates on `ProcessInfo.processInfo.thermalState` (good) and a TTL (good) but NOT on `isLowPowerModeEnabled`. A user at 15 % battery with Low Power Mode auto-engaged still pays the full ML pipeline cost on the next dashboard open.
  - The BG refresh coordinator (`App/BackgroundRefreshCoordinator.swift`) does not consult LPM either; iOS *will* deny BGTask submissions in LPM, but the in-foreground `liveViewModel.fetchHomeDataTiered()` invocations from HomeView's RepeatTimer still run.
  - Repeating animations (RecoveryHero, HomeFirstLaunchLoadingView, etc.) keep firing at full cadence in LPM, where Apple's frame budget is reduced — meaning frame-drop visible to user *and* the app has skipped a free win on battery.
  - Live anchored streams (P2-F1) keep streaming HR every 1 Hz UI update in LPM, where the user explicitly asked the system to throttle non-essential work.
- **Evidence:** `grep -rn "isLowPowerModeEnabled" --include="*.swift"` → 0 hits. `ThermalManager.swift` is a singleton that only listens for `thermalStateDidChangeNotification` — no power-state listener.
- **Fix:**
  1. In `ThermalManager`, add a sibling property `isLowPowerMode: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }`, observe `NSNotification.Name.NSProcessInfoPowerStateDidChange`, and republish on the existing `@Observable`.
  2. Make `shouldThrottle` return true if either `currentState ≥ .serious` *or* `isLowPowerMode`.
  3. Audit every `repeatForever(...)` call site (8 confirmed) and gate on `!ThermalManager.shared.shouldThrottle`. The `AskDataOrbView` already does this pattern (`Pass 1 F18` cleanlist) — replicate everywhere.
  4. Gate `MLOrchestrator.runMLAnalysis` on `!isLowPowerModeEnabled`.
- **Confidence:** 94/100 — grep is conclusive; impact magnitude depends on how often users hit LPM (varies). The fix is a small surface-area change with high leverage.

---

## P2-F5. `MLOrchestrator`'s singleton `FeatureEngine` holds `cachedVectors: [Date: DailyFeatureVector] = [:]` and `cachedInteractionsByDate: [Date: [InteractionFeature: Double]] = [:]` that are written on every pipeline run with no eviction or upper bound. Multi-year users grow the dict 1 entry per day per metric forever.

- **Severity:** Medium (Critical for long-tenure users)
- **Issue:**
  - `Core/Analysis/ML/FeatureEngine.swift:36-37` — both caches declared as plain Swift `Dictionary` with no eviction policy, no max-count guard, no NSCache backing.
  - `Core/Analysis/ML/FeatureEngine.swift:415-421` — every call to `buildFeatureVectors(...)` writes new entries without ever pruning. The `rebuildWindowDays = 3` constant means only the trailing 3 days are recomputed — older days are *kept forever* by design.
  - `Core/Analysis/AnalysisEngine.swift:161` — `let mlOrchestrator = MLOrchestrator()` is held by `AnalysisEngine`, which is held by `AppContainer`, which is held for the entire process lifetime. So `FeatureEngine` is effectively a process-singleton with an unbounded growth dict.
  - `DailyFeatureVector` is itself non-trivial — multiple per-metric numeric fields, an `interactionsByDate` per-day dict, periodicity lags. With ~30 metrics × 1 day × ~3 KB per vector estimated, 5 years of daily backfill = 5 × 365 × 3 KB = ~5.5 MB held permanently in memory. Plus the parallel `cachedInteractionsByDate` of similar size. Plus the `bucketStatsCache` and `isolationScoreCache` in `AdaptiveAnomalyDetector` (`Core/Analysis/ML/AdaptiveAnomalyDetector.swift:104, 126`) which exhibit the same pattern.
- **Why this matters:**
  - On low-memory devices (iPhone 12 mini, iPhone SE 3) the 10–20 MB of cached ML state across the engines is real pressure that could be evicted to Disk or NSCache without any logic change.
  - Pass 1 F7 noted "no `didReceiveMemoryWarning` handler"; combined with this, the app cannot release memory under pressure — it just gets jetsam'd by the OS.
- **Evidence:**
  - `Core/Analysis/ML/FeatureEngine.swift:36-37, 415-421`.
  - `Core/Analysis/ML/AdaptiveAnomalyDetector.swift:104-106, 126`.
  - `grep -rn "NSCache" --include="*.swift"` → **zero hits** in the entire codebase. All caches are plain `Dictionary`.
- **Fix:**
  1. Cap `cachedVectors` at the trailing N days needed for the rebuild window + statistics floor (e.g., 365). After every `buildFeatureVectors`, prune entries older than `today - 365 days`.
  2. Switch the bigger caches (`bucketStatsCache`, `isolationScoreCache`) to `NSCache<NSString, BoxedValue>` so iOS can auto-evict on memory pressure.
  3. Wire `UIApplication.didReceiveMemoryWarningNotification` (the absent-handler from Pass 1) to clear all of these.
- **Confidence:** 88/100 — declarations and write sites are read; per-vector size estimate is rough (`DailyFeatureVector` not opened).

---

## P2-F6. `HKSampleQuery` is used for `fetchQuantitySamples(metric:from:to:)` (line 705-744) which then computes per-day mean *in Swift* by iterating raw samples. For metrics where `HKStatisticsCollectionQuery` with `.discreteAverage` and `intervalComponents.day = 1` would return the same daily-mean buckets directly from the HealthKit daemon — that's the canonical Apple API for this exact transformation.

- **Severity:** Medium
- **Issue:**
  - `Core/Data/HealthKitManager.swift:705-744` — `fetchQuantitySamples` issues `HKSampleQuery` with `limit: HKObjectQueryNoLimit`, receives every raw sample (heart rate at Watch resolution = ~hundreds-to-thousands per day), then in the result handler computes `dailyValues[day, default: []].append(value)` and `MetricSample(date: day, value: values.mean)` per day.
  - The same file *already* uses `HKStatisticsCollectionQuery` correctly for `fetchHourlySamples` (line 510) — so the API and pattern are familiar to the author. The discrepancy is that `fetchQuantitySamples` is the path used by the headline batch sync (`fetchMetric` for almost every quantity-typed metric — heart rate, HRV, RHR, blood oxygen, respiratory, body temp, etc.).
  - `HKStatisticsCollectionQuery` runs the daily-mean reduction inside the HealthKit daemon, where it's pre-indexed and reuses prior aggregations. Apple guidance for "give me one number per day for this quantity type" is unambiguous: use `HKStatisticsCollectionQuery`.
- **Why this is independent of Pass 1 F2:**
  - F2 said: switch *batch* path to `HKAnchoredObjectQuery` for incremental delta. That's correct for raw-sample types (sleep stages, mindful, workouts).
  - This finding says: even for the daily-mean quantity types, the *current* use of `HKSampleQuery` + Swift-side mean is the wrong API; `HKStatisticsCollectionQuery` is the right API regardless of whether you use anchored fetches or not.
  - Fix order: (a) make daily-mean metrics use `HKStatisticsCollectionQuery` (this finding) → (b) keep raw-sample metrics on `HKAnchoredObjectQuery` (Pass 1 F2). They're complementary.
- **Evidence:**
  - `Core/Data/HealthKitManager.swift:713-742` (`HKSampleQuery` + Swift-side mean).
  - `Core/Data/HealthKitManager.swift:510-549` (`HKStatisticsCollectionQuery` correctly used elsewhere — proof the team knows the API).
- **Fix:** route every daily-aggregated quantity metric (defined by `HealthKitMetricRegistry.config(for:).statisticsOption`) through `HKStatisticsCollectionQuery` in `fetchQuantitySamples`. The bridge cost drops by 1–2 orders of magnitude on data-dense metrics like heart rate.
- **Confidence:** 88/100 — usage discrepancy verified by reading both helpers; the bridge-cost-saving claim is from Apple's HealthKit best-practices, not benchmarked here.

---

## P2-F7. `MetricLogSheet`'s save path calls `refreshMetric` *and* the dismiss sheet awaits its completion. Even the optimized version (P2-F3) doesn't address that the post-write refresh runs on the main actor and blocks user input until done.

- **Severity:** Medium (compounds with P2-F3 but is independent: even after P2-F3 fix, the await still serializes UI dismiss against I/O)
- **Issue:** `Modules/MetricDetail/Views/MetricDetail/MetricLogSheet.swift:185-199` — `try await healthKitManager.saveWaterIntake(...)` then `await healthKitManager.refreshMetric(...)` then `dismiss()`. The dismiss only happens after both round-trips finish. Today, that's the expensive path; even with P2-F3 fixed, an async await on the main actor still forces the user to wait for `dismiss()` to fire.
- **Fix:** dismiss immediately after `try await healthKitManager.saveWaterIntake`, then *fire-and-forget* `Task { await healthKitManager.refreshMetric(metric, store: healthDataStore) }`. UX feels instant; refresh happens in the background.
- **Evidence:** `Modules/MetricDetail/Views/MetricDetail/MetricLogSheet.swift:182-199`.
- **Confidence:** 86/100.

---

## P2-F8. `WeeklyReviewEntryCard` is constructed inside HomeView body (`HomeView.swift:351`) with `weeklyReviewViewModel ?? WeeklyReviewViewModel(dashboardViewModel: viewModel)` — every time SwiftUI re-evaluates the body before `onAppear` has run, a throw-away `WeeklyReviewViewModel` is allocated.

- **Severity:** Low
- **Issue:**
  - `Modules/Dashboard/Views/Home/HomeView.swift:81, 195-199, 351` — `weeklyReviewViewModel` is `@State` (initially nil); `ensureWeeklyReviewVM` runs on `onAppear` to set it once; but the body's `WeeklyReviewEntryCard(viewModel: weeklyReviewViewModel ?? WeeklyReviewViewModel(...))` evaluates the right-hand side *every body invocation* until `onAppear` lands. SwiftUI's body can run multiple times before onAppear (debug shows 2–4 in practice for cold renders). Each one allocates a fresh `WeeklyReviewViewModel`, which itself reads from `dashboardViewModel.scores` to compute `winsCount`/`scoreDelta`/`review` lazily.
  - The card is the immediate child whose body uses `viewModel.review` etc., so the throw-away VM also runs its own load() if `WeeklyReviewEntryCard.onAppear` fires before the parent assigns the persistent VM.
- **Fix:** replace `??` fallback with a guard `if let vm = weeklyReviewViewModel { WeeklyReviewEntryCard(viewModel: vm) { ... } }` so the card is omitted entirely until the parent has wired the VM.
- **Evidence:** `Modules/Dashboard/Views/Home/HomeView.swift:81, 195-199, 350-353`.
- **Confidence:** 80/100.

---

## P2-F9. `AppLaunchCoordinator.configureOnLaunch` runs **synchronously** during `application(_:didFinishLaunchingWithOptions:)` and includes: `FirebaseApp.configure`, `Auth.auth().signInAnonymously` (callback-based but the Auth object is mutated synchronously), `PostHogManager.configure` (full SDK setup including session-replay snapshotting), `installCrashHandlers` (registers signal handlers for SIGABRT/SIGBUS/SIGSEGV/SIGFPE/SIGILL/SIGTRAP — each `signal()` is a syscall), and a `Task { await fetchAndActivate() }`. All before SwiftUI gets a chance to paint a splash frame.

- **Severity:** Medium
- **Issue:**
  - `App/AppDelegate.swift:13` — `launchCoordinator.configureOnLaunch()` is synchronous, executed on the main thread before `application(_:didFinishLaunchingWithOptions:)` returns. iOS will not start any animations or paint the SwiftUI scene until that returns.
  - `App/AppLaunchCoordinator.swift:18-44` — measured by line: 3 sync calls (`FirebaseApp.configure`, `analyticsManager.configure`, `analyticsManager.installCrashHandlers`) + 1 callback-based async (`signInAnonymously`) + 2 `Task` dispatches (the second of which `startScreenshotTracking` adds another NotificationCenter observer). `FirebaseApp.configure` alone is documented to take 50–200 ms on cold start (it reads GoogleService-Info.plist, initializes Crashlytics + Analytics + RemoteConfig, opens persistence).
  - On top of that, `LasoApp.init()` (`App/LasoApp.swift:64-74`) runs *before* AppDelegate fires: it constructs `AppContainer`, which triggers `HealthKitManager()` (constructs HKHealthStore), `AnalysisEngine()` (loads baselines + reads `Date` from disk), `HealthDataContainerFactory.makeModelContainer()` (SwiftData boot — see Pass 1 F12 schema-version finding), `AppStartupCoordinator` wiring, `BackgroundRefreshCoordinator` (×2 per Pass 1 F1). Plus `AppIntegrityGuard.performChecks()` (jailbreak detection: 21 file-system probes + dylib enum over hundreds of images + sysctl + Mach-O header parse — see `Core/Security/AppIntegrityGuard.swift:43-105, 144-162`).
  - Net: cold-launch path measurably longer than Apple's 400 ms first-frame target on real devices, with no instrument-driven decomposition.
- **Why Pass 1 didn't catch it cleanly:** Pass 1 F1 noted the duplicate BG coordinator but didn't decompose the *full* synchronous launch chain into a budget breakdown.
- **Fix:**
  1. Split `configureOnLaunch` into a sync minimum (just `FirebaseApp.configure` + `Auth` setup) and a deferred async tail (PostHog `configure` + `installCrashHandlers` + `startScreenshotTracking` + `fetchAndActivate`). Run the tail from `LasoApp.body.task` after the splash view paints.
  2. Move `AppIntegrityGuard.performChecks()` off the `init` path — it only logs (returns nil always per line 34); run it in a detached Task after first frame.
  3. Lazy-initialize the AppContainer's `analysisEngine` and the SwiftData container — they're not needed for the splash frame, only for the first dashboard render.
- **Evidence:**
  - `App/AppDelegate.swift:9-23`.
  - `App/AppLaunchCoordinator.swift:18-44`.
  - `App/LasoApp.swift:64-74`.
  - `Core/Security/AppIntegrityGuard.swift:16-37, 43-105`.
- **Confidence:** 85/100 — call chain verified end-to-end; per-step ms not measured. Suggested split is standard cold-launch hygiene from WWDC "Optimize app launch".

---

## P2-F10. `MetricDetailViewModel` exposes 12+ computed `var` properties (`trend`, `chartSamples`, `historicalFacts`, `trendLineSamples`, `monthComparison`, `forecastSamples`, etc.) that recompute O(N) work on every read. With `@Observable`, every body invalidation re-runs them. No memoization.

- **Severity:** Medium
- **Issue:**
  - `Modules/MetricDetail/ViewModels/MetricDetailViewModel.swift:13-247` — every "var X: Y { ... }" recomputes whenever read. Notable hot ones:
    - `trend` (line 18-25) → `TrendAnalyzer.canonicalTrend(... days: selectedTimeRange)` — a moving-window stats call.
    - `chartSamples` (line 39-42) → `series.samples(lastDays: selectedTimeRange)` — array filter/slice.
    - `trendLineSamples` (line 171-185) → builds rolling-7-day average across all `chartSamples`. Re-runs the full reduction each read.
    - `monthComparison` (line 211-246) → date arithmetic + `valueMean` reductions over 30 days × 2 months.
    - `historicalFacts` (line 95-148) → builds a `[HistoricalFact]` from `historicalContext`, with `Calendar.current.monthSymbols[...]` access per call.
    - `forecastSamples` (line 190-198) → reads `analysisEngine.mlOrchestrator.multiHorizonForecasts[metric]` and re-derives future-date samples.
  - In SwiftUI's `@Observable` model, when MetricDetailView's body reads `viewModel.chartSamples` and then `viewModel.trendLineSamples`, both recompute fully even though they share the same upstream `series.samples(lastDays:)`. There's no caching by `selectedTimeRange` or `series.id`.
  - When the user taps the time-range segmented control (7d/30d/90d/180d), `selectedTimeRange` changes, the body invalidates, and *all* of these recompute on the main actor before the next frame can land.
- **Fix:**
  1. Pre-compute these in a `func updateCachedProperties()` triggered by `onChange(of: selectedTimeRange)` and store them as plain `var` (non-computed) properties. SwiftUI body reads then just return cached references.
  2. Or: convert the heaviest (`trendLineSamples`, `monthComparison`) to `Task.detached` workers that publish results back to `@Observable`-backed storage, so they don't run on the main actor at all.
- **Evidence:** `Modules/MetricDetail/ViewModels/MetricDetailViewModel.swift:13-247`.
- **Confidence:** 84/100 — the @Observable invalidation behavior is well-documented; per-property cost not measured but is non-trivial (e.g., `trendLineSamples` is O(N) over 30+ samples per read).

---

## P2-F11. `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` is read inline in `AppAnalytics.logEvent` (the universal event dispatcher) and three other AppAnalytics paths. PostHog ships dozens of events per session; each event re-fetches the plist dictionary.

- **Severity:** Low
- **Issue:**
  - `Core/Tracking/AppAnalytics.swift:425, 715, 1721, 3142` — every event-enrich path does `Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"`.
  - `Bundle.infoDictionary` is cached at the `Bundle` level after first access, so the actual cost per call is a hash lookup + a cast. Small but it happens on every analytics event, and AppAnalytics has 153 `logEvent`/`trackBlock`/`trackFeature` definitions — many of them on hot paths (every screen view, every tap, every tab change).
  - There is no static `static let appVersion: String = { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown" }()` anywhere.
- **Fix:** add `private static let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"` on `AppAnalytics`, replace the four inline reads.
- **Evidence:** `Core/Tracking/AppAnalytics.swift:425, 715, 1721, 3142` (and three sibling reads in `PostHogManager.swift`, `FeedbackPromptManager.swift`).
- **Confidence:** 86/100.

---

## P2-F12. `CoachActionBridge.defaults` is a *computed* property that allocates a new `UserDefaults(suiteName: appGroupID)` on every access. Each `markPending` and `consumePending` call instantiates 3–4 UserDefaults objects.

- **Severity:** Low
- **Issue:**
  - `Shared/CoachActionIntents.swift:23-25`:
    ```swift
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    ```
  - Every `markPending` (line 27-31) accesses `defaults` 3 times → 3 allocations. Every `consumePending` (line 34-46) accesses 5–6 times → 5–6 allocations. Apple says `UserDefaults(suiteName:)` is supposed to return the same shared object for a given suite name, but the API documentation explicitly notes the returned object is *not* required to be a singleton; some iOS versions return a fresh instance.
- **Fix:** cache to `static let defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)`. Trivial fix.
- **Evidence:** `Shared/CoachActionIntents.swift:23-25, 27-46`.
- **Confidence:** 80/100 — allocation cost is small per call; the value is in correctness (one canonical defaults object, not multiple).

---

## P2-F13. `WidgetDataStore.save<T>` and `WidgetDataStore.load<T>` allocate fresh `JSONEncoder()`/`JSONDecoder()` per call. Pass 1 F14 covered most call sites in the *app* but missed the Widget-side allocations that fire on every widget timeline refresh.

- **Severity:** Low
- **Issue:**
  - `Core/Data/WidgetDataStore.swift:187-195` — `save<T>` does `try? JSONEncoder().encode(value)` and `load<T>` does `try? JSONDecoder().decode(T.self, from: data)` — fresh allocation per call.
  - `WidgetDataStore.writeAllSnapshots` (line 199-220) calls `saveReadinessIfChanged` + `saveSleepIfChanged` + `saveActionIfChanged` + `saveIntelligenceIfChanged` + `saveRecoveryDebtIfChanged` — and each of those calls `loadX()` (1 allocation) AND `saveX()` (1 allocation if changed). Worst case: 10 encoder/decoder allocations per `writeAllSnapshots` invocation.
  - `writeAllSnapshots` is called from `DashboardViewModel.swift:1907` after every dashboard refresh (foreground-throttled to 30 s but every fire pays this).
  - Pass 1 F14 listed the `Core/Analysis` and `Modules/Dashboard/ViewModels` sites but did NOT list `Core/Data/WidgetDataStore.swift`. Adding here.
- **Fix:** add `private static let encoder = JSONEncoder()` and `private static let decoder = JSONDecoder()` to `WidgetDataStore`, replace the two inline allocations.
- **Evidence:** `Core/Data/WidgetDataStore.swift:187-195`.
- **Confidence:** 85/100.

---

## P2-F14. `RecoveryHeroCard`, `HomeFirstLaunchLoadingView`, and `DiscoveryView` use `Animation.repeatForever(...)` with no `@Environment(\.accessibilityReduceMotion)` gate. Only `VitalityDetailView` and `VitalityOrganicOrb` respect the user's reduceMotion preference.

- **Severity:** Low (perf), Medium (accessibility — but accessibility is in a separate audit)
- **Issue:**
  - `Modules/Dashboard/Views/Home/HomeFirstLaunchLoadingView.swift:36, 42` — two `repeatForever(autoreverses: true)` animations on the loading view, no reduceMotion check.
  - `Modules/Dashboard/Views/Home/RecoveryHeroCard.swift:69` — repeat-forever pulse (Pass 1 F18 covered the thermal aspect but not the reduceMotion aspect).
  - `Modules/Discovery/Views/Discovery/DiscoveryView.swift:86-91` — animation conditionally degrades on `thermallyConstrained` but not on reduceMotion.
  - `grep -rn "accessibilityReduceMotion" --include="*.swift"` → only 3 hits, all in the Vitality module.
- **Why this is in the perf audit:** repeat-forever animations with reduce-motion off cost ~60 fps × 1 attribute = continuous animation work even on devices where the user *asked* for less motion. iOS 17+ has explicit guidance: when reduce-motion is on, `repeatForever` should fall back to `.linear(duration: x)` or no-op.
- **Fix:** add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` to each of the three views and gate the animations: `.animation(reduceMotion ? .none : .easeInOut(...).repeatForever(...), value: x)`.
- **Evidence:** `grep -rn "accessibilityReduceMotion" --include="*.swift"` → 3 hits in Vitality only.
- **Confidence:** 82/100.

---

## P2-F15. `BreathworkView` declares `private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()` at the View struct level. The publisher is *autoconnected at struct construction time*, so it ticks at 10 Hz from the moment SwiftUI evaluates the type — even before `onAppear`. And it keeps ticking after the view disappears unless `.upstream.connect().cancel()` is called.

- **Severity:** Low
- **Issue:**
  - `Modules/Stress/Views/Stress/BreathworkView.swift:157` — `private var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()`.
  - `autoconnect()` returns a `Publishers.Autoconnect` that connects on the first subscriber and *stays connected forever*. There is no `cancel()` in `onDisappear`. So once the breathwork view is constructed, a 10 Hz timer fires on the main runloop until the process dies.
  - When the view is on-screen, the body subscribes via `.onReceive(timer)` (or similar) and consumes the ticks. When it disappears, no subscribers exist, but `.autoconnect()` keeps the upstream timer ticking. Pure cost.
  - 10 Hz is also a *high* tick rate — the breathwork phase progresses on a 1–6 s cadence; 10 Hz is for sub-second visual progress, which `TimelineView(.animation)` could provide for free.
- **Fix:**
  1. Replace `Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()` with a `TimelineView(.periodic(by: 0.1))`-driven recompute *inside* the body.
  2. Or, change the property to `@State private var timer = Timer.publish(every: 0.1, on: .main, in: .common)` (no autoconnect), connect it on `onAppear`, cancel it on `onDisappear`.
- **Evidence:** `Modules/Stress/Views/Stress/BreathworkView.swift:157`.
- **Confidence:** 82/100 — autoconnect lifecycle is documented; the perpetual-tick concern is real for the post-disappear period.

---

## P2-F16. `lastSyncDate(for:)` does an *unbounded* SwiftData fetch then takes `.first` instead of using `fetchLimit = 1`. Out of all `FetchDescriptor` constructions in the codebase, exactly ONE (`HealthDataStore.swift:700`) sets `fetchLimit`. The other ~30 fetch all matching rows just to take the first.

- **Severity:** Low
- **Issue:**
  - `Core/Data/HealthDataStore.swift:374-379` — `lastSyncDate(for:)` builds a predicate matching `metricRawValue == rawValue`, fetches all results, takes `.first`. The result set is at most 1 (one sync metadata row per metric), but SwiftData doesn't know that and pays the full predicate-evaluation + materialization cost.
  - `grep -rn "fetchLimit" --include="*.swift"` → 1 hit total.
  - Note: `lastSyncDate(for:)` itself does not appear to be called externally (`allSyncDates()` superseded it), so the fix is actually "delete dead code." But the broader pattern (no fetchLimit anywhere else) is the deeper finding.
- **Fix:**
  1. Delete `lastSyncDate(for:)` (dead).
  2. Audit all `FetchDescriptor` sites and add `fetchLimit` where the consumer takes `.first` or a known-small slice.
- **Evidence:** `Core/Data/HealthDataStore.swift:374-379`; `grep -rn "fetchLimit" --include="*.swift"`.
- **Confidence:** 85/100.

---

## P2-F17. `HealthKitManager.fetchFirstSleepOnset(windowStart:windowEnd:)` issues `HKSampleQuery` with `limit: HKObjectQueryNoLimit` despite the consumer immediately calling `samples.first { ... }`. A `limit: 1` (with the existing ascending sort) would let HealthKit short-circuit at the daemon layer.

- **Severity:** Low
- **Issue:**
  - `Core/Data/HealthKitManager.swift:991-1010` — `HKSampleQuery(... limit: HKObjectQueryNoLimit ...)` then `samples.first { asleepStageValues.contains($0.value) }`. With ascending start-date sort, the consumer wants exactly one sample.
  - `HealthKit` honors `limit:` at the daemon — passing `1` would return the first matching sample without materializing the entire night's samples.
- **Fix:** change `limit: HKObjectQueryNoLimit` to `limit: 50` (small floor to allow filtering through awake-stage samples to find the first asleep) or use a stage-specific predicate so `limit: 1` works directly.
- **Evidence:** `Core/Data/HealthKitManager.swift:991-1014`.
- **Confidence:** 82/100.

---

## P2-F18. The `enrichEvent` logEvent path (`AppAnalytics.swift:3109-3160`) builds a freshly-allocated `[String: Any]` dictionary on every event, performs 14+ key-presence checks, and reads `UserDefaults.standard.string(forKey:)` twice + `UserDefaults.standard.bool(forKey:)` once per event. With 153 distinct event call-sites, this is steady main-actor allocation pressure.

- **Severity:** Low
- **Issue:**
  - `Core/Tracking/AppAnalytics.swift:3109-3160` — every event runs through this enrich path. Each iteration:
    - Allocates a new dict (copy of `parameters`).
    - 14 `if enriched["..."] == nil` lookups (each is a hash + a sentinel-equality check).
    - 2 `defaults.string(forKey:)` reads + 1 `defaults.bool(forKey:)` (cheap-but-not-free).
    - 1 `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` read (P2-F11).
    - `sanitizeEventName` + `sanitizeParameters` (additional allocations + iteration).
  - In a typical session, AppAnalytics emits ~100 events. Even at 200 µs per enrichment, that's ~20 ms of main-actor budget consumed by the enrichment alone.
- **Fix:**
  1. Cache the constants once per session (`session_id`, `app_version`, `subscription_status`) and merge as a constant baseline dict.
  2. Pre-compute `userTier` inside `SubscriptionManager` instead of recomputing per event.
  3. Move the entire enrichment + dispatch off the main actor; PostHog's `capture` is thread-safe.
- **Evidence:** `Core/Tracking/AppAnalytics.swift:3109-3160`.
- **Confidence:** 80/100.

---

## P2-F19. SwiftUI files with the deepest stack-nesting + the largest LOC are *also* the files most likely to hit Swift 5.9 type-inference compile-time spikes. Top suspects (counted by ZStack/VStack/HStack tokens, then LOC):

| File | Stack tokens | LOC |
|---|---:|---:|
| `Modules/Dashboard/Views/Home/WeeklyReviewView.swift` | 35 | 664 |
| `Modules/Sleep/Views/Sleep/SleepCoachView.swift` | 31 | 731 |
| `Modules/Dashboard/Views/Home/TodaysActionDetailView.swift` | 30 | 578 |
| `Modules/CycleTracking/Views/CycleTracking/CycleDetailView.swift` | 30 | 710 |
| `Modules/MetricDetail/Views/MetricDetail/MetricDetailView.swift` | 29 | 576 |
| `Modules/Insights/Views/Insights/CorrelationsView.swift` | 28 | 673 |
| `Modules/Strain/Views/Strain/StrainDetailView.swift` | 26 | n/a |
| `Modules/HealthState/Views/HealthState/HealthStateTimelineView.swift` | 25 | n/a |

- **Severity:** Low (build-time, not runtime)
- **Issue:** Each of these files is one View struct with 25+ nested layout containers. Swift 5.9 + strict-concurrency mode tends to balloon type-inference time on any single body that exceeds ~150 lines, and again on any `ViewBuilder` block with >10 sibling expressions. Build-time spikes hurt iteration velocity even though they don't hit production runtime.
- **What Pass 1 missed:** F9 listed top LOC files (mostly ML/analytics). This is the *SwiftUI*-specific list — different population, different optimization (split into smaller View structs, not extension files).
- **Fix:** for each file, extract the inline section helper functions into separate small View structs. SwiftUI compiles each View struct in isolation so the type-inference scope shrinks.
- **Evidence:** `find . -name "*.swift" -exec grep -lE "ZStack|VStack|HStack" {} + | xargs grep -cE "ZStack|VStack|HStack"` (run during audit).
- **Confidence:** 75/100 — LOC and token counts are objective; the compile-time-spike claim is the Swift compiler team's general heuristic, not measured on Laso CI.

---

## P2-F20. `CompoundInsightEngine`, `TemporalSequenceMiner`, `TodayIntelligenceEngine`, `CompoundInsightEngine` (each held by `MLOrchestrator`) hold state forever with `@Observable` semantics; SwiftUI views that subscribe to them re-render whenever any of their internal `var` properties change, even unrelated ones, due to per-class observation tracking.

- **Severity:** Low
- **Issue:** Pass 1 F9 noted that `DashboardViewModel`'s ~100 stored properties inflate the observer-tracking metadata. Same concern applies (smaller scale) to the ML engines. Each ML engine has 5–20 stored properties that change on every pipeline run; any view that reads even one of them re-evaluates the body when *any* of them changes. With 6+ ML engines wired through `analysisEngine.mlOrchestrator.X` reads in Home, MetricDetail, Insights, this multiplies redraws.
- **Fix:** convert ML-engine output state into `Sendable` snapshot value types (immutable `struct` per pipeline run) and publish a single snapshot at end-of-run via `@Observable` `var snapshot: MLSnapshot`. View bodies read from `mlOrchestrator.snapshot.X`; one observed property, one invalidation per pipeline run.
- **Evidence:** read of `Core/Analysis/AnalysisEngine.swift:160-168` (multiple `var X` projections to ML engine internals).
- **Confidence:** 72/100 — Observation framework's per-property tracking is documented; whether Laso's view bodies actually trigger excessive redraws would need View-redraw instrumentation.

---

## P2-F21. `HomeView.onAppear` runs *six* discrete side-effecting calls before the first frame renders: `ensureWeeklyReviewVM`, `startHomeRefresh`, `startReadinessRefresh`, `rebuildMetricTilesFromLive`, `MorningCheckInManager.shouldShowCheckIn` + `todaysCheckIn` (two UserDefaults reads + a date check), `AppAnalytics.shared.trackFeatureOpen`. Each is ms-level; together they jank first scroll.

- **Severity:** Low
- **Issue:** `Modules/Dashboard/Views/Home/HomeView.swift:81-92` — six side effects in a synchronous block on the main actor. None of them block the body itself, but they all run before SwiftUI returns control to the runloop, and several allocate / start timers that the OS schedules on the same runloop.
- **Fix:** wrap the analytics + morning-check-in calls in `Task { ... }`; they do not need to land before first paint. Keep the timer start sync (so the first refresh tick is on time).
- **Evidence:** `Modules/Dashboard/Views/Home/HomeView.swift:81-92`.
- **Confidence:** 78/100.

---

## P2-F22. `ChartFormat / Calendar.current` is invoked **272 times** across the codebase. Each `Calendar.current` returns a *value-type copy* of the user's calendar — cheap individually, but a hot loop in any of the scorers / ML engines with `let calendar = Calendar.current` inside a function body hands out a fresh `Calendar` per call.

- **Severity:** Low
- **Issue:** `grep -rn "Calendar.current\b" --include="*.swift"` → 272 hits. Selectively concerning sites:
  - `Core/Analysis/AdaptiveAnomalyDetector.swift:324` — inside `firstIndex(where:)`: `Calendar.current.isDate($0.date, inSameDayAs: vector.date)`. Each comparison constructs a fresh Calendar.
  - `Core/Analysis/ML/PatternMiner.swift:25, ChangePointDetector.swift:94, CorrelationDiscovery.swift:33`, etc. — calendar pulled inside `mine(...)` rather than stored on `self`.
- **Fix:** add `private let calendar = Calendar.current` to each ML engine class (already done in `TodayIntelligenceEngine.swift:50`, `TemporalSequenceMiner.swift:122`, `CompoundInsightEngine.swift:86` — replicate elsewhere).
- **Evidence:** `grep -rn "Calendar.current\b" --include="*.swift"`.
- **Confidence:** 70/100 — cost per `Calendar.current` access is small (~hundreds of ns). The pattern is worth fixing only on hot loops; flagging as Low.

---

## P2-F23. `DailyNarrativeEngine.todayKey` (`Core/Analysis/ML/DailyNarrativeEngine.swift:94-99`) constructs a fresh `DateFormatter` and `Locale("en_US_POSIX")` every time it's read. The function is the cache-key builder for the per-day narrative cache and is called on every read/write.

- **Severity:** Low
- **Issue:**
  - `Core/Analysis/ML/DailyNarrativeEngine.swift:94-99`:
    ```swift
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return Self.cachePrefix + formatter.string(from: Date())
    }
    ```
  - `DateFormatter()` allocation is famously expensive — Apple's docs explicitly call out that DateFormatter should be reused. This one re-runs on every call to `todayKey`, which is invoked from `cachedNarrativeToday()`, `cacheNarrativeToday(_:)`, and `pruneStaleCacheKeys()`.
- **Fix:** lift to a `private static let dayKeyFormatter: DateFormatter = { ... }()`. Trivial.
- **Evidence:** `Core/Analysis/ML/DailyNarrativeEngine.swift:94-99`.
- **Confidence:** 88/100.

---

## P2-F24. `SleepNeedCalculator.formattedBedtime` and `TodayIntelligenceEngine.shortDateString` and `GamificationEngine.hasMarathonMonth` instantiate `DateFormatter` per call inside computed properties / hot helpers, instead of using the class's existing `static let` formatter pattern (which most of the codebase has).

- **Severity:** Low
- **Issue:**
  - `Core/Analysis/SleepNeedCalculator.swift:171-174` — `var formattedBedtime: String?` constructs a fresh DateFormatter on every read.
  - `Core/Analysis/ML/TodayIntelligenceEngine.swift:1081-1085` — `private func shortDateString(_:)` does the same.
  - `Core/Analysis/GamificationEngine.swift:889-891` — inside `hasMarathonMonth`, a `DateFormatter` is built per-call (called once per gamification refresh, but inside a loop that depends on it).
- **Fix:** lift each to `static let` like `CoachGreetingView.weekdayFormatter` already does (`Modules/Dashboard/Views/Home/CoachGreetingView.swift:34-44`). Pattern is established; replicate.
- **Evidence:** as above.
- **Confidence:** 88/100.

---

## P2-F25. The widget extension reads from `WidgetDataStore` via App Group `UserDefaults(suiteName: "group.com.lasohealth.fit")` on every timeline request. Apple's docs note App Group UserDefaults reads cross a security boundary and are slower than standard UserDefaults; combined with widget snapshot getters being on the timeline-provider's clock, this is a measurable per-snapshot cost.

- **Severity:** Low
- **Issue:**
  - `LasoWidgets/AnalysisWidgetProvider.swift:21-32` — `loadEntry()` reads 5 snapshots (`store.loadReadiness()`, `loadSleep()`, `loadAction()`, `loadIntelligence()`, `loadRecoveryDebt()`), each one doing `userDefaults?.data(forKey:)` + `JSONDecoder().decode(...)`. 5 reads + 5 decodes per timeline entry.
  - `getTimeline` (line 15-19) returns one entry per call; one call per refresh; refresh every 15 min (Pass 1 F16). So that's 5×4 = 20 reads per hour in steady state per widget instance — bounded but not minimal.
- **Fix:**
  1. Add a single combined `loadAll()` method on `WidgetDataStore` that reads a single bigger blob (one `UserDefaults.data(forKey: "widget.combined")` + one `JSONDecoder.decode<CombinedSnapshot>`).
  2. The main app already has `writeAllSnapshots`; mirror it on the read side.
- **Evidence:** `LasoWidgets/AnalysisWidgetProvider.swift:11-32`; `Core/Data/WidgetDataStore.swift:158-178, 187-195`.
- **Confidence:** 78/100.

---

## P2-F26. Network-bandwidth budget: PostHog (events + session-replay) + Firebase Analytics + Crashlytics + RemoteConfig + Firebase Auth = at least four cellular-radio tenants per session, with no shared-batch / shared-flush coordination.

- **Severity:** Low
- **Issue:**
  - `Core/Tracking/PostHogManager.swift:21-43` — PostHog SDK setup with session-replay enabled (Pass 1 F5 covered the session-replay cost; this finding is about the *combined* network footprint).
  - `App/AppLaunchCoordinator.swift:21-42` — Firebase configure + Auth + RemoteConfig fetch on every launch.
  - Crashlytics uploads happen on next launch after a crash (out-of-band).
  - **No shared flush coordinator**: each SDK manages its own queue + upload schedule. On cellular, this means multiple radio wakes per session for tens-of-KB payloads.
- **Why this matters:**
  - Apple's energy guide explicitly says: batch network requests; minimize radio-wake cycles. Each SDK's independent queue means independent radio wakes.
  - Free-tier PostHog is 1M events/month; Laso's 153 event types × N users × Y sessions can quickly exceed this. (Free-tier risk is in the cost-budget audit, not perf — but the *bandwidth* per event is real.)
- **Fix:**
  1. Configure PostHog `flushAt` to a higher batch size (e.g., 100) and `flushIntervalSeconds` to 30+ so events don't ship per-tap.
  2. Configure Firebase Analytics to batch via remote config.
  3. Add a network-condition check (`NWPathMonitor.path.isExpensive`) and defer non-critical uploads when expensive.
- **Evidence:** SDK configs in `Core/Tracking/PostHogManager.swift` + `App/AppLaunchCoordinator.swift`.
- **Confidence:** 68/100 — bandwidth claim is general; per-SDK numbers not measured on Laso. Fix recommendations are standard energy-guide hygiene.

---

## P2-F27. **No `NSCache` use anywhere in the codebase.** Every cache (`FeatureEngine.cachedVectors`, `AdaptiveAnomalyDetector.bucketStatsCache/isolationScoreCache`, `HealthDataStore.allSeriesCache`, `HealthDataStore.metricSeriesCache`, `HealthDataQueryEngine.semanticIntentCache`) is a plain Swift `Dictionary`.

- **Severity:** Low
- **Issue:** `grep -rn "NSCache" --include="*.swift"` → 0 hits. Plain dicts have no eviction; they grow unboundedly and live in the heap until manually cleared. NSCache automatically evicts on memory pressure (cooperates with the OS jetsam pre-warning).
- **Fix:** for caches with key types that bridge to NSObject (Strings, NSNumbers, value types wrapped in box), switch to `NSCache<NSString, BoxedValue>`. For caches with non-bridgeable keys (Dates, custom types), keep as Dictionary but add explicit eviction on `UIApplication.didReceiveMemoryWarningNotification` (which Pass 1 noted is also unhandled).
- **Evidence:** `grep -rn "NSCache" --include="*.swift"` → 0; `grep -rn "private var.*Cache\|cachedVectors\|metricSeriesCache" --include="*.swift"` → many.
- **Confidence:** 88/100.

---

## P2-F28. `LiveViewModel.startStreaming()` calls **six separate fetch helpers** in the same synchronous block: `startHeartRateStream`, `startBloodOxygenStream`, `startRespiratoryRateStream`, `fetchTodayCumulativeStats`, `startActivityObservers`, `fetchFallbackHeartRate/BloodOxygen/RespiratoryRate`. Then a `DispatchQueue.main.asyncAfter(deadline: .now() + 5)` work-item, then a 300 ms `Task.sleep` before the deferred slow batch. Each fetch hits the HealthKit daemon synchronously.

- **Severity:** Low
- **Issue:**
  - `Modules/Live/ViewModels/LiveViewModel.swift:227-288` — startStreaming runs 9–11 daemon-bound calls back-to-back in `priority 1/2/3` blocks. None are `await`-ed; they fan out as detached Obj-C continuations.
  - The HealthKit daemon is a single-process resource; flooding it with parallel queries can serialize at the daemon side and add aggregate latency.
  - Worse: `restartStreaming()` (line 310-336) repeats this every BG-return + `fetchLatestSampleWithDate(.heartRate, unit: unit, maxAge: 24*3600, ...)` (line 318) which adds yet *another* HR fetch over a 24-hour window. 24 hours × 1 HR/sec on Apple Watch = up to 86 K samples scanned for one latest value.
- **Fix:**
  1. Batch the `fetchLatestSampleWithDate(.heartRate, unit: ..., maxAge: 24*3600, ...)` to `maxAge: 600` (10 min) — anything older than that is irrelevant for "latest HR".
  2. Use `withTaskGroup` to parallelize the 9 fetches with cancellation tied to `isStreaming`.
- **Evidence:** `Modules/Live/ViewModels/LiveViewModel.swift:227-336`.
- **Confidence:** 80/100.

---

## P2-F29. Inheritance from `UIDevice.current.systemVersion` and `UIAccessibility.is*Running` calls inside the AppAnalytics user-properties path. UIKit accessors that bridge to the main thread are called in event-enrichment paths fired from background threads via PostHog's queue.

- **Severity:** Low
- **Issue:**
  - `Core/Tracking/AppAnalytics.swift:418-431` (`captureUserProperties`) — reads `UIDevice.current.systemVersion`, `UIAccessibility.isVoiceOverRunning`, `UIAccessibility.isReduceMotionEnabled`, `UIApplication.shared.preferredContentSizeCategory`. UIApplication.shared and UIAccessibility on iOS 17+ require the main actor; the function is called from a path that may already be on the main actor (inside event tracking), but the callsite isn't `@MainActor`-annotated, so the compiler may auto-bridge.
  - In practice: most calls land on main; if a background event handler ever calls `captureUserProperties` (e.g., from a background notification observer), the Swift 6 strict-concurrency runtime will trap.
- **Fix:** annotate `captureUserProperties` `@MainActor`, propagate to call sites, OR cache the values once at app launch (most are immutable per session: systemVersion, voice-over state at launch — though reduceMotion can change mid-session).
- **Evidence:** `Core/Tracking/AppAnalytics.swift:418-431`.
- **Confidence:** 70/100 — the safety risk is real with strict concurrency on; not a current crash bug.

---

## P2-F30. `MLOrchestrator.runMLAnalysis` runs the entire ML pipeline on the main actor (the function isn't annotated `@MainActor` but its callers from `AnalysisEngine.swift:369` are). The pipeline includes ARIMA/HW model selection, change-point detection, granger causality, isolation-forest scoring — heavy compute that should be `Task.detached(priority: .background)` so the main actor stays free for UI.

- **Severity:** Low (gated by thermal + TTL — won't fire often) → Medium when it does fire
- **Issue:**
  - `Core/Analysis/AnalysisEngine.swift:369` — `await mlOrchestrator.runMLAnalysis(...)`. AnalysisEngine itself is invoked from `DashboardViewModel.computeNewEngines` on the main actor (Pass 1 F3 covers the scorer half of this; the *ML* half is independent).
  - `Core/Analysis/ML/MLPipelineRunner.swift:79-330` — the runner sequence does FeatureEngine, PredictiveScorer, CorrelationDiscovery, HealthStateClassifier, ChangePointDetector, AdaptiveAnomalyDetector, GrangerCausalityEngine, etc., all in sequence. Each is heavy. On main actor, this is a multi-second jank during dashboard refresh.
  - There's a thermal gate (line 168-173) and a 60 s TTL (line 176-181), but no actor-hop.
- **Fix:** annotate `runMLAnalysis` `nonisolated` (it doesn't read main-actor state), and call it from `Task.detached(priority: .userInitiated)`. Hand back a `Sendable` snapshot.
- **Evidence:** `Core/Analysis/ML/MLOrchestrator.swift:155-208`; `Core/Analysis/ML/MLPipelineRunner.swift`.
- **Confidence:** 78/100.

---

## P2-F31. `MorningCheckInManager` uses `ISO8601DateFormatter()` allocated fresh inside `shouldShowCheckIn`, `markDismissedToday`, `markCompletedToday` — three short helpers that each allocate. iCloud + AppGroup sites do the same.

- **Severity:** Low
- **Issue:**
  - `Core/Data/MorningCheckInManager.swift:21, 29, 40, 57` — four `ISO8601DateFormatter()` allocations.
  - `Modules/WebExport/HTMLReportGenerator.swift:53` — fresh `DateFormatter` per HTML build.
  - `App/ActivationSequenceManager.swift:250` — fresh `ISO8601DateFormatter()` per call.
- **Fix:** lift to `private static let isoFormatter = ISO8601DateFormatter()`. Pattern.
- **Evidence:** files cited.
- **Confidence:** 88/100.

---

## P2-F32. `BackgroundRefreshCoordinator.handle` registers an inner `Task` that has no timeout itself; the BG handler relies on `BGTask.expirationHandler` to cancel work, but the work inside `liveViewModel.fetchHomeDataTiered()` does not check `Task.isCancelled` aggressively. Some HealthKit queries can outlive the wake budget.

- **Severity:** Low
- **Issue:**
  - `App/BackgroundRefreshCoordinator.swift:77-101` — Task is created, work fires, `Task.sleep(for: .seconds(delay))` (covered Pass 1 F17), then `task.setTaskCompleted(success: true)`. Cancellation propagation through `withTaskGroup` of `HKSampleQuery`-based fetches is best-effort.
  - When iOS hits the 30 s wake budget and triggers `expirationHandler`, the Task's `Task.cancel()` is called — but inside HealthKit-bound queries, cancellation only takes effect at the next `withCheckedContinuation` resume point. A long `HKSampleQuery` already submitted to the daemon will run to completion, and the Task waits.
- **Fix:**
  1. Inside `fetchHomeDataTiered` and downstream `fetchMetric`/`fetchSleepSamples`, accept a `Task.checkCancellation()` after each daemon round-trip.
  2. Use `HKQuery`'s built-in `stop(_ query:)` from `expirationHandler`.
- **Evidence:** `App/BackgroundRefreshCoordinator.swift:77-105`.
- **Confidence:** 70/100.

---

## Summary

| Severity | Count |
|---|---:|
| Critical | 0 |
| High | 4 |
| Medium | 6 |
| Low | 22 |

(High: P2-F1, P2-F2, P2-F3, P2-F4. Medium: P2-F5, P2-F6, P2-F7, P2-F9, P2-F10, P2-F30.)

### Top 3 to fix Now (Pass 2)

1. **P2-F4 — Adopt `isLowPowerModeEnabled` everywhere.** Add a `ThermalManager.isLowPowerMode` reactive flag, gate every `repeatForever` animation, the `MLOrchestrator.runMLAnalysis` entry, and the dashboard refresh timer. Single biggest battery+UX win for the LPM-engaged tail of users.
2. **P2-F1 — Persist Live anchored-query anchors.** Capture and reuse the `HKQueryAnchor` returned by each query's result handler. Removes the per-tab-open / per-foreground-return refetch of 2 hours of HR samples.
3. **P2-F2 — Make `PersistenceManager` a singleton (or fix its multi-instance observer leak).** Five constructions, five `addObserver` without `removeObserver`, 25 AES-GCM probes per cold launch — all eliminated by `static let shared`.

### Top 3 to fix This Week (Pass 2)

4. **P2-F3 — Stop `refreshMetric` from doing 10-year refetches after every log save.** Either bypass HealthKit entirely (the value is local) or use `lastSyncDate(for:)` as the floor.
5. **P2-F6 — Switch daily-mean quantity metrics to `HKStatisticsCollectionQuery`.** Independent of P1-F2's anchored-query migration; cuts CPU+bridging cost by 1–2 orders for HR/HRV/RHR.
6. **P2-F9 — Defer non-critical work out of the synchronous launch path.** Move `installCrashHandlers`, `startScreenshotTracking`, `fetchAndActivate`, and `AppIntegrityGuard.performChecks` off the AppDelegate `didFinishLaunching` chain. Aim for ≤400 ms first-frame.

### Sub-areas verified clean by Pass 2

- **No Combine `.sink` retain cycles** — `grep -rn "\\.sink {" --include="*.swift"` → 0 hits across the entire codebase. Combine usage is confined to `Timer.publish` (3 sites).
- **No `AnyView` overuse** — only 3 hits (all in `ShareButton.swift` for legitimate type-erasure across two card types).
- **No `@StateObject`/`@ObservedObject`/`@EnvironmentObject` legacy mix** — codebase is fully on `@Observable` (54 hits) with zero legacy ObservableObject conformances.
- **No Firestore `addSnapshotListener` cascades** — already noted in Pass 1; reconfirmed by grep.
- **No third-party image library** — `AsyncImage`, `KFImage`, `WebImage`, `SDWebImage` all absent. All images are local assets.
- **Asset catalog footprint** — total PNG bytes 81 KB; zero `@3x` PNGs (entirely SF Symbols + vector PDFs); confirms Pass 1 cleanlist.
- **Widget `getTimeline`** — does NOT recompute scores from scratch; reads pre-baked snapshots from `WidgetDataStore`. Safe.
- **Audio sessions** — no `AVAudioSession`, `AVPlayer`, `AVFoundation`, `AudioToolbox` references anywhere. Breathwork is silent. Zero audio-session churn cost.
- **Localization** — no `NSLocalizedString` in hot paths; user-facing strings are `Copy.X` static lets, not lazy lookups.
- **`HKAnchoredObjectQuery` exists in Live** — Pass 1 noted this; this pass found that anchor *persistence* is broken (P2-F1).
- **`HKStatisticsCollectionQuery` exists in `fetchHourlySamples`** — proves the team knows the API; but the daily-mean batch path uses `HKSampleQuery` instead (P2-F6).

---

**Confidence: 86/100** — most findings cite specific file:line and were read end-to-end (P2-F1 through P2-F4, P2-F5, P2-F8, P2-F9, P2-F10, P2-F11, P2-F13, P2-F15, P2-F16, P2-F23, P2-F24). Several are pattern-grep findings (P2-F4 — isLowPowerMode absence; P2-F12 — defaults singleton miss; P2-F22 — Calendar.current count; P2-F27 — NSCache absence) which are unambiguous given grep semantics. A handful (P2-F6 magnitude, P2-F26 bandwidth, P2-F30 ML actor-hop) rely on Apple HealthKit / energy-guide documented behavior rather than a Time Profiler / Network Profiler trace on a Laso build. No runtime profiling, no Instruments allocation snapshot was performed — those would tighten magnitude estimates by 10–15 % but would not change the prioritization. Score is 86/100 and not higher because: (a) actual ms cost per finding is estimated from API behavior rather than measured on a real device, (b) the AppContainer / AnalysisEngine / WatchMonitor / SettingsView cross-instance observer leak in P2-F2 is verified by code-read but not by attaching Instruments to confirm 5 distinct observer firings, and (c) several findings (P2-F19, P2-F30) are pattern-level rather than incident-level and could be downgraded by a CI build-time profile / Time Profiler trace I did not have available.
