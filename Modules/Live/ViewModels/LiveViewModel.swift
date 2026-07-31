import Foundation
import HealthKit
import Observation
import SwiftUI

/// ViewModel for the Live tab. streams real-time health data from Apple Watch via HealthKit.
/// Properties are grouped into independently observable sub-objects so that changes in one group
/// (e.g. heart rate) don't trigger re-renders in views that only read another group (e.g. sleep).
@MainActor @Observable
final class LiveViewModel {
    let healthKitManager: HealthKitManager
    private let readinessStore: ReadinessStore
    private let heartRateTimelineReducer: LiveHeartRateTimelineReducer
    private let refreshPlanner: LiveRefreshPlanner
    private let sleepSummaryBuilder: LiveSleepSummaryBuilder
    private var healthStore: HKHealthStore { healthKitManager.healthStore }

    // MARK: - Grouped Observable Sub-Objects

    /// Real-time vitals from Apple Watch (HR, SpO2, respiratory rate, BP, temperature)
    let vitals = VitalsData()
    /// Last night's sleep analysis
    let sleep = SleepData()
    /// Today's cumulative activity stats and goals
    let activity = ActivityData()
    /// Recovery metrics (RHR, HRV, readiness, stress)
    let recovery: RecoveryData
    /// Most recent workout info
    let workout = WorkoutData()

    // MARK: - Streaming State

    var isStreaming = false
    var lastUpdate: Date?

    /// The 14-day average intraday active-energy shape, same bucket layout as
    /// `activity.intradayActiveEnergy`. Empty until the first fetch lands.
    var usualIntradayEnergy: [Double] = []
    /// Day guard: yesterday's average shape cannot change during the day, so
    /// re-running a 14-day statistics collection on every home fetch is waste.
    @ObservationIgnored private var usualIntradayFetchDay: Date?

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var bloodOxygenQuery: HKAnchoredObjectQuery?
    private var respiratoryRateQuery: HKAnchoredObjectQuery?
    private var activityObserverQueries: [HKObserverQuery] = []
    private var lastCumulativeFetch: Date = .distantPast
    private static let cumulativeThrottleInterval: TimeInterval = 15

    private var respiratoryAvailabilityWorkItem: DispatchWorkItem?

    /// Persistent observer for background delivery. survives app backgrounding so HealthKit
    /// keeps syncing Apple Watch data to iPhone even when Laso is suspended.
    private var backgroundHRObserver: HKObserverQuery?
    private var backgroundDeliveryRegistered = false

    /// Throttle UI-facing property updates to max 1 per second to reduce GPU work.
    private var lastUIUpdateTime: Date = .distantPast
    private var pendingHeartRateUpdate: PendingHRUpdate?
    private var pendingUIUpdateWorkItem: DispatchWorkItem?

    private enum ReadinessMetric {
        case heartRateVariability
        case restingHeartRate
    }

    // 60-day window matches the Plews/Altini methodology used by HRV4Training
    // and athlete-grade HRV studies: long enough to capture menstrual cycle
    // and travel variance, short enough that a sustained training adaptation
    // still moves the personal baseline within a few weeks.
    private static let readinessBaselineWindowDays = 60
    private static let readinessBaselineGapDays = 2
    private static let readinessBaselineRefreshInterval: TimeInterval = 6 * 3600
    private static let weeklyTrendDays = 7

    private var readinessBaselines: [ReadinessMetric: ReadinessScorer.BaselineStats] = [:]
    private var lastReadinessBaselineRefresh: Date?
    private var readinessBaselineRefreshTask: Task<Void, Never>?
    private var deferredRefreshTask: Task<Void, Never>?
    private var smoothedReadinessScore: Double?
    private var refreshState = LiveRefreshPlanner.State()
    private var lastHomeFetchDate: Date?
    private var lastTieredFetchDate: Date?
    private var isFetchingCumulativeStats = false
    private var pendingCumulativeStatsCallbacks = 0
    /// Today's cumulative stats arrive as six independent HealthKit callbacks. They
    /// stage here and publish in a single batch so the tiles fill together in one
    /// render pass instead of popping in one at a time.
    @ObservationIgnored private var stagedTodaySteps: Double = 0
    @ObservationIgnored private var stagedTodayActiveCalories: Double = 0
    @ObservationIgnored private var stagedTodayExerciseMinutes: Double = 0
    @ObservationIgnored private var stagedTodayStandHours: Double = 0
    @ObservationIgnored private var stagedTodayDistance: Double = 0
    @ObservationIgnored private var stagedTodayFlightsClimbed: Double = 0
    @ObservationIgnored private var hasPendingReadinessRecompute = false
    private static let homeFetchDebounce: TimeInterval = 1.0
    private static let tieredFetchDebounceNominal: TimeInterval = 10
    private static let tieredFetchDebounceFair: TimeInterval = 20

    private typealias PendingHRUpdate = LiveHeartRateTimelineReducer.PendingUpdate

    init(
        healthKitManager: HealthKitManager,
        readinessStore: ReadinessStore = ReadinessStore(),
        heartRateTimelineReducer: LiveHeartRateTimelineReducer = LiveHeartRateTimelineReducer(),
        refreshPlanner: LiveRefreshPlanner = LiveRefreshPlanner(),
        sleepSummaryBuilder: LiveSleepSummaryBuilder = LiveSleepSummaryBuilder()
    ) {
        self.healthKitManager = healthKitManager
        self.readinessStore = readinessStore
        self.heartRateTimelineReducer = heartRateTimelineReducer
        self.refreshPlanner = refreshPlanner
        self.sleepSummaryBuilder = sleepSummaryBuilder
        recovery = RecoveryData(readinessStore: readinessStore)
    }

    deinit {
        // Tear down any HealthKit queries and pending Tasks that outlive `stopStreaming()`.
        // `backgroundHRObserver` is registered once per app session by `registerBackgroundDelivery()`
        // and is intentionally NOT stopped in `stopStreaming()` (so background delivery survives
        // tab switches). If this view-model is ever deallocated (e.g. ContentView re-creation),
        // the observer must be stopped to prevent it firing into a dead instance.
        // Class is `@MainActor` so the `deinit` runs there — and the `MainActor.assumeIsolated`
        // bridge tells the compiler the captured properties are accessed on their actor.
        MainActor.assumeIsolated {
            let store = healthKitManager.healthStore
            if let bgObserver = backgroundHRObserver {
                store.stop(bgObserver)
            }
            for query in [heartRateQuery, bloodOxygenQuery, respiratoryRateQuery].compactMap({ $0 }) {
                store.stop(query)
            }
            for query in activityObserverQueries {
                store.stop(query)
            }
            deferredRefreshTask?.cancel()
            readinessBaselineRefreshTask?.cancel()
            respiratoryAvailabilityWorkItem?.cancel()
            pendingUIUpdateWorkItem?.cancel()
        }
    }

    // MARK: - Background Delivery

    /// Start a persistent observer query for heart rate so HealthKit keeps syncing
    /// Apple Watch HR data to iPhone even when Laso is suspended. Called once per app session.
    func registerBackgroundDelivery() {
        guard !backgroundDeliveryRegistered, HKHealthStore.isHealthDataAvailable() else { return }
        backgroundDeliveryRegistered = true

        // Persistent observer query for heart rate. tells HealthKit to keep syncing
        // Apple Watch HR data to iPhone. Fires even when app is suspended.
        let heartRateType = HKQuantityType(.heartRate)
        let observer = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }
            guard error == nil, let self else { return }

            // If actively streaming, the anchored query handles updates.
            // Otherwise, pre-fetch latest HR so it's ready when Live tab opens.
            Task { @MainActor in
                guard !self.isStreaming else { return }
                let unit = HKUnit.count().unitDivided(by: .minute())
                self.fetchLatestSampleWithDate(.heartRate, unit: unit, maxAge: 24 * 3600) { [weak self] value, date in
                    Task { @MainActor in
                        self?.vitals.currentHeartRate = value
                        self?.vitals.heartRateTimestamp = date
                        self?.lastUpdate = Date()
                    }
                }
            }
        }
        healthStore.execute(observer)
        backgroundHRObserver = observer
    }

    // MARK: - Heart Rate Zone (needs healthStore for age)

    /// Estimated max heart rate (220 - age, defaults to 190 if unknown).
    /// Cached on first access. date of birth never changes.
    private var _cachedMaxHR: Double?
    var estimatedMaxHR: Double {
        if let cached = _cachedMaxHR { return cached }
        let result: Double
        if let dob = try? healthStore.dateOfBirthComponents(),
           let birthDate = Date.cal.date(from: dob) {
            let age = Date.cal.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
            result = Double(220 - age)
        } else {
            result = 190
        }
        _cachedMaxHR = result
        return result
    }

    var currentHeartRateZone: HeartRateZone {
        guard let hr = vitals.currentHeartRate else { return .rest }
        let maxHR = estimatedMaxHR
        let pct = hr / maxHR * 100
        switch pct {
        case ..<50: return .rest
        case 50..<60: return .warmUp
        case 60..<70: return .fatBurn
        case 70..<80: return .cardio
        case 80..<90: return .peak
        default: return .extreme
        }
    }

    var heartRateZonePercent: Double {
        guard let hr = vitals.currentHeartRate else { return 0 }
        return min(hr / estimatedMaxHR, 1.0)
    }

    // MARK: - Readiness + Today Quick Fetch (for Home tab, no streams)

    /// Full fetch. calls all tiers unconditionally (used on first appear and manual refresh).
    /// Also pre-fetches latest vitals so the Live tab opens instantly with data.
    func fetchHomeData() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let now = Date()
        // Debounce against both timestamps. On the legacy tab-return path the tab
        // change fires `fetchHomeDataTiered()` milliseconds before HomeView's
        // `onAppear` gets here, and checking only `lastHomeFetchDate` let this
        // re-issue the same three to six HealthKit queries.
        let lastAnyFetch = [lastHomeFetchDate, lastTieredFetchDate].compactMap { $0 }.max()
        if let last = lastAnyFetch, now.timeIntervalSince(last) < Self.homeFetchDebounce {
            return
        }
        if ThermalManager.shared.shouldThrottle {
            return
        }
        lastHomeFetchDate = now
        lastTieredFetchDate = now
        fetchLatestDailyValues()
        fetchTodayCumulativeStats()
        fetchActivityGoals()
        fetchTodayMindfulMinutes()
        fetchIntradayActivity()
        fetchLatestWorkout()
        fetchLastNightSleep()
        // Pre-fetch latest vitals so Live tab has data immediately when opened
        fetchFallbackHeartRate()
        fetchFallbackBloodOxygen()
        fetchFallbackRespiratoryRate()
        refreshPlanner.markFullRefresh(at: now, state: &refreshState)
    }

    /// Today's active energy by hour, for the intraday chart on Home. Its own
    /// task because it is a statistics-collection query over the whole day, far
    /// heavier than the single-value reads around it, and nothing on screen
    /// blocks on it.
    private func fetchIntradayActivity() {
        Task { [weak self] in
            guard let self else { return }
            guard let buckets = await healthKitManager.fetchIntradayBuckets(.activeCalories) else { return }
            activity.intradayActiveEnergy = buckets
        }
        fetchUsualIntradayEnergyIfNeeded()
    }

    /// Refreshes the usual-day overlay at most once per day.
    private func fetchUsualIntradayEnergyIfNeeded() {
        let today = Date.cal.startOfDay(for: Date())
        guard usualIntradayFetchDay != today else { return }
        usualIntradayFetchDay = today
        Task { [weak self] in
            guard let self else { return }
            if let usual = await healthKitManager.fetchUsualIntradayShape(.activeCalories) {
                usualIntradayEnergy = usual
            } else {
                // Locked health DB or empty history: clear the guard so the
                // next home fetch retries instead of waiting for tomorrow.
                usualIntradayFetchDay = nil
            }
        }
    }

    /// Tiered fetch. only queries data whose refresh interval has elapsed
    func fetchHomeDataTiered() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if ThermalManager.shared.shouldThrottle {
            return
        }
        let now = Date()
        let debounceInterval = tieredFetchDebounceInterval(for: ThermalManager.shared.currentState)
        if let last = lastTieredFetchDate, now.timeIntervalSince(last) < debounceInterval {
            return
        }
        lastTieredFetchDate = now
        let decision = refreshPlanner.decisionForTieredRefresh(now: now, state: refreshState)

        if decision.shouldFetchFast {
            fetchTodayCumulativeStats()
        }
        if decision.shouldFetchMedium {
            fetchActivityGoals()
            fetchTodayMindfulMinutes()
        }
        if decision.shouldFetchSlow {
            fetchLatestDailyValues()
            fetchLatestWorkout()
            fetchLastNightSleep()
        }
        refreshPlanner.apply(decision, at: now, state: &refreshState)
    }

    // MARK: - Start / Stop

    func startStreaming() {
        guard !isStreaming, HKHealthStore.isHealthDataAvailable() else { return }
        isStreaming = true

        // Register background delivery once so HealthKit syncs Apple Watch data to iPhone
        registerBackgroundDelivery()

        // Reset flags from previous session so fresh data takes priority
        vitals.respiratoryRateUnavailable = false

        // Priority 1: Real-time vital streams. anchored queries deliver samples instantly
        startHeartRateStream()
        startBloodOxygenStream()
        startRespiratoryRateStream()

        // Priority 2: Cumulative activity. observer queries push updates in real time
        fetchTodayCumulativeStats()
        startActivityObservers()

        // Priority 3: Fallback latest vitals. ensures data appears immediately even if
        // the anchored query's narrow window (30 min) has no recent samples
        fetchFallbackHeartRate()
        fetchFallbackBloodOxygen()
        fetchFallbackRespiratoryRate()

        // After 5 seconds, if respiratory rate is still nil, mark as unavailable
        respiratoryAvailabilityWorkItem?.cancel()
        let availabilityWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.vitals.currentRespiratoryRate == nil else { return }
            self.vitals.respiratoryRateUnavailable = true
        }
        respiratoryAvailabilityWorkItem = availabilityWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: availabilityWorkItem)

        // Priority 4: Deferred slow-changing data. don't compete with real-time queries
        let now = Date()
        deferredRefreshTask?.cancel()
        deferredRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, self.isStreaming else { return }

            let decision = self.refreshPlanner.decisionForDeferredStreamingRefresh(
                now: now,
                state: self.refreshState
            )

            if decision.shouldFetchMedium {
                self.fetchActivityGoals()
                self.fetchTodayMindfulMinutes()
            }
            if decision.shouldFetchSlow {
                self.fetchLatestDailyValues()
                self.fetchLatestBloodPressure()
                self.fetchLatestBodyTemperature()
                self.fetchLatestWorkout()
                self.fetchTodayHeartRateRange()
                self.fetchLastNightSleep()
            }
            self.refreshPlanner.apply(decision, at: now, state: &self.refreshState)
            self.computeReadinessScore()
        }
    }

    func stopStreaming() {
        isStreaming = false
        deferredRefreshTask?.cancel()
        deferredRefreshTask = nil
        stopAllQueries()

        // Clear stale vital data so fresh queries populate on next startStreaming().
        // Without this, old values block fallback fetches and the UI stays stuck on
        // "Wear your Apple Watch" indefinitely after the watch is put back on.
        vitals.currentHeartRate = nil
        vitals.heartRateTimestamp = nil
        vitals.currentBloodOxygen = nil
        vitals.bloodOxygenTimestamp = nil
        vitals.currentRespiratoryRate = nil
        vitals.respiratoryRateTimestamp = nil
        vitals.respiratoryRateUnavailable = false
    }

    /// Restart streaming without clearing displayed data. keeps the UI populated
    /// while new queries spin up. Used on foreground return to avoid a blank flash.
    func restartStreaming() {
        stopAllQueries()
        isStreaming = false
        startStreaming()

        // Force-fetch latest HR immediately to bridge any gap from the background period.
        // The anchored query may take a moment to deliver; this ensures instant display.
        let unit = HKUnit.count().unitDivided(by: .minute())
        fetchLatestSampleWithDate(.heartRate, unit: unit, maxAge: 24 * 3600) { [weak self] value, date in
            Task { @MainActor in
                guard let self, self.isStreaming else { return }
                // Only apply if anchored query hasn't already delivered something newer
                if self.vitals.currentHeartRate == nil ||
                   (self.vitals.heartRateTimestamp ?? .distantPast) < date {
                    self.vitals.currentHeartRate = value
                    self.vitals.heartRateTimestamp = date
                    self.lastUpdate = Date()
                }
            }
        }
    }

    private func stopAllQueries() {
        for query in [heartRateQuery, bloodOxygenQuery, respiratoryRateQuery].compactMap({ $0 }) {
            healthStore.stop(query)
        }
        heartRateQuery = nil
        bloodOxygenQuery = nil
        respiratoryRateQuery = nil

        for query in activityObserverQueries {
            healthStore.stop(query)
        }
        activityObserverQueries.removeAll()

        respiratoryAvailabilityWorkItem?.cancel()
        respiratoryAvailabilityWorkItem = nil
        pendingUIUpdateWorkItem?.cancel()
        pendingUIUpdateWorkItem = nil
        pendingHeartRateUpdate = nil
    }

    // MARK: - Activity Observer Queries (Real-Time Push)

    /// Sets up HKObserverQuery for each cumulative activity type so HealthKit pushes
    /// updates as soon as new samples arrive (e.g. Apple Watch syncs steps).
    /// Replaces 30-second timer polling with instant, event-driven updates.
    private func startActivityObservers() {
        let startOfDay = Date.cal.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: nil, options: .strictStartDate)

        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .appleExerciseTime,
            .appleStandTime, .distanceWalkingRunning, .flightsClimbed
        ]

        for identifier in identifiers {
            let type = HKQuantityType(identifier)
            let observerQuery = HKObserverQuery(sampleType: type, predicate: predicate) { [weak self] _, completionHandler, error in
                defer { completionHandler() }
                guard error == nil, let self else { return }

                Task { @MainActor in
                    guard self.isStreaming else { return }
                    // Throttle: coalesce rapid-fire notifications to at most once per 3 seconds
                    let now = Date()
                    guard now.timeIntervalSince(self.lastCumulativeFetch) >= Self.cumulativeThrottleInterval else { return }
                    self.lastCumulativeFetch = now
                    self.fetchTodayCumulativeStats()
                }
            }
            healthStore.execute(observerQuery)
            activityObserverQueries.append(observerQuery)
        }
    }

    // MARK: - Heart Rate Stream

    private func startHeartRateStream() {
        let heartRateType = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())

        // Start from 2 hours ago to catch data that synced from Apple Watch while app was backgrounded.
        // The chart trims to 30 minutes anyway, but this ensures we pick up the latest HR value.
        let lookbackStart = Date().addingTimeInterval(-2 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: lookbackStart, end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in self?.processHeartRateSamples(samples, unit: unit) }
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in self?.processHeartRateSamples(samples, unit: unit) }
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    private func processHeartRateSamples(_ samples: [HKSample]?, unit: HKUnit) {
        guard isStreaming else { return }
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }
        let sortedSamples = quantitySamples.sorted { $0.startDate < $1.startDate }
        let points = sortedSamples.map { sample in
            (date: sample.startDate, value: sample.quantity.doubleValue(for: unit))
        }
        guard let latestSample = points.last else { return }

        Task { @MainActor in
            let base = pendingHeartRateUpdate?.merged ?? vitals.recentHeartRates
            pendingHeartRateUpdate = heartRateTimelineReducer.reduce(
                existing: base,
                incoming: points,
                latestSample: latestSample,
                now: Date()
            )

            // Throttle: only push to @Observable properties at most once per second
            let now = Date()
            let elapsed = now.timeIntervalSince(lastUIUpdateTime)
            if elapsed >= 1.0 {
                applyPendingHeartRateUpdate()
            } else {
                // Schedule a deferred flush if one isn't already pending
                if pendingUIUpdateWorkItem == nil {
                    let delay = 1.0 - elapsed
                    let workItem = DispatchWorkItem { [weak self] in
                        guard let self else { return }
                        Task { @MainActor in
                            self.applyPendingHeartRateUpdate()
                            self.pendingUIUpdateWorkItem = nil
                        }
                    }
                    pendingUIUpdateWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
                }
            }
        }
    }

    /// Flush buffered heart rate data to @Observable properties (triggers view redraws).
    @MainActor
    private func applyPendingHeartRateUpdate() {
        // Streaming may have stopped between buffering and this flush; drop the
        // stale batch so old HR never overwrites the live vitals after stop.
        guard isStreaming else { pendingHeartRateUpdate = nil; return }
        guard let update = pendingHeartRateUpdate else { return }
        pendingHeartRateUpdate = nil
        lastUIUpdateTime = Date()

        let merged = update.merged
        vitals.recentHeartRates = merged
        let stats = heartRateTimelineReducer.sessionStats(for: merged)
        vitals.heartRateMin30 = stats.minimum
        vitals.heartRateMax30 = stats.maximum
        vitals.heartRateAvg30 = stats.average

        // Set current to most recent
        vitals.currentHeartRate = update.latestValue
        vitals.heartRateTimestamp = update.latestTimestamp
        lastUpdate = Date()
    }

    // MARK: - Blood Oxygen Stream

    private func startBloodOxygenStream() {
        bloodOxygenQuery = startVitalStream(
            identifier: .oxygenSaturation,
            unit: .percent(),
            hoursBack: 6
        ) { [weak self] val, date in
            self?.vitals.currentBloodOxygen = val * 100
            self?.vitals.bloodOxygenTimestamp = date
            self?.lastUpdate = Date()
        }
    }

    // MARK: - Respiratory Rate Stream

    private func startRespiratoryRateStream() {
        respiratoryRateQuery = startVitalStream(
            identifier: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            hoursBack: 24
        ) { [weak self] val, date in
            self?.vitals.currentRespiratoryRate = val
            self?.vitals.respiratoryRateTimestamp = date
            self?.vitals.respiratoryRateUnavailable = false
            self?.lastUpdate = Date()
        }
    }

    /// Generic anchored object query for vital sign streaming. eliminates duplicate setup code
    private func startVitalStream(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        hoursBack: Double,
        update: @escaping @MainActor (Double, Date) -> Void
    ) -> HKAnchoredObjectQuery {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-hoursBack * 3600),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: type,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in self?.processLatestSample(samples, unit: unit, update: update) }
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in self?.processLatestSample(samples, unit: unit, update: update) }
        }

        healthStore.execute(query)
        return query
    }

    // MARK: - Helpers

    private func processLatestSample(_ samples: [HKSample]?, unit: HKUnit, update: @escaping @MainActor (Double, Date) -> Void) {
        guard isStreaming else { return }
        guard let quantitySamples = samples as? [HKQuantitySample],
              let latest = quantitySamples.max(by: { $0.startDate < $1.startDate }) else { return }

        let value = latest.quantity.doubleValue(for: unit)
        let date = latest.startDate

        Task { @MainActor in
            update(value, date)
        }
    }

    // MARK: - Today's Cumulative Stats

    func fetchTodayCumulativeStats() {
        guard beginCumulativeStatsFetch(expectedCallbacks: 6) else { return }
        let startOfDay = Date.cal.startOfDay(for: Date())
        fetchTodayStat(.stepCount, unit: .count(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.stagedTodaySteps = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.activeEnergyBurned, unit: .kilocalorie(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.stagedTodayActiveCalories = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.appleExerciseTime, unit: .minute(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.stagedTodayExerciseMinutes = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.appleStandTime, unit: .hour(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.stagedTodayStandHours = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.stagedTodayDistance = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.flightsClimbed, unit: .count(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.stagedTodayFlightsClimbed = v
                self?.finishCumulativeStatsFetch()
            }
        }
    }

    private func beginCumulativeStatsFetch(expectedCallbacks: Int) -> Bool {
        guard !isFetchingCumulativeStats else { return false }
        isFetchingCumulativeStats = true
        pendingCumulativeStatsCallbacks = expectedCallbacks
        return true
    }

    private func finishCumulativeStatsFetch() {
        guard isFetchingCumulativeStats else { return }
        pendingCumulativeStatsCallbacks = max(0, pendingCumulativeStatsCallbacks - 1)
        if pendingCumulativeStatsCallbacks == 0 {
            isFetchingCumulativeStats = false
            // One publish for all six. Observation fires per set regardless of
            // value, so writing them as they landed cost six render passes and
            // showed the tiles popping in one at a time.
            activity.todaySteps = stagedTodaySteps
            activity.todayActiveCalories = stagedTodayActiveCalories
            activity.todayExerciseMinutes = stagedTodayExerciseMinutes
            activity.todayStandHours = stagedTodayStandHours
            activity.todayDistance = stagedTodayDistance
            activity.todayFlightsClimbed = stagedTodayFlightsClimbed
        }
    }

    private func tieredFetchDebounceInterval(for thermalState: ProcessInfo.ThermalState) -> TimeInterval {
        switch thermalState {
        case .nominal:
            return Self.tieredFetchDebounceNominal
        case .fair:
            return Self.tieredFetchDebounceFair
        case .serious, .critical:
            return Self.tieredFetchDebounceFair
        @unknown default:
            return Self.tieredFetchDebounceFair
        }
    }

    private func fetchTodayStat(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, completion: @escaping (Double) -> Void) {
        let quantityType = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
            completion(value)
        }

        healthStore.execute(query)
    }

    // MARK: - Activity Goals from HealthKit

    func fetchActivityGoals() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let calendar = Date.cal
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        // Build DateComponents with calendar + all fields HealthKit requires
        var components = DateComponents()
        components.calendar = calendar
        components.era = calendar.component(.era, from: startOfDay)
        components.year = calendar.component(.year, from: startOfDay)
        components.month = calendar.component(.month, from: startOfDay)
        components.day = calendar.component(.day, from: startOfDay)

        let predicate = HKQuery.predicateForActivitySummary(with: components)

        let query = HKActivitySummaryQuery(predicate: predicate) { [weak self] _, summaries, error in
            guard error == nil, let summary = summaries?.first else { return }
            let move = summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
            let exercise = summary.exerciseTimeGoal?.doubleValue(for: .minute()) ?? 0
            let stand = summary.standHoursGoal?.doubleValue(for: .count()) ?? 0
            Task { @MainActor in
                if move > 0 { self?.activity.moveGoal = move }
                if exercise > 0 { self?.activity.exerciseGoal = exercise }
                if stand > 0 { self?.activity.standGoal = stand }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Latest Daily Values

    func fetchLatestDailyValues() {
        refreshReadinessBaselinesIfNeeded()

        // Batch recovery metric updates — each callback sets properties + recomputes readiness
        fetchLatestSampleWithDate(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), maxAge: 48 * 3600) { [weak self] value, date in
            Task { @MainActor in
                guard let self else { return }
                self.recovery.latestRestingHeartRate = value
                self.recovery.latestRestingHeartRateTimestamp = date
                self.scheduleReadinessRecompute()
            }
        }
        fetchLatestSampleWithDate(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), maxAge: 48 * 3600) { [weak self] value, date in
            Task { @MainActor in
                guard let self else { return }
                self.recovery.latestHRV = value
                self.recovery.latestHRVTimestamp = date
                self.scheduleReadinessRecompute()
            }
        }
    }

    /// Coalesces the resting-HR and HRV callbacks into one readiness compute.
    /// Deferring rather than counting to two keeps the score correct when only
    /// one of the two metrics has a sample inside its 48 h window.
    private func scheduleReadinessRecompute() {
        guard !hasPendingReadinessRecompute else { return }
        hasPendingReadinessRecompute = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hasPendingReadinessRecompute = false
            self.computeReadinessScore()
        }
    }

    // MARK: - Blood Pressure

    func fetchLatestBloodPressure() {
        fetchLatestSample(.bloodPressureSystolic, unit: .millimeterOfMercury()) { [weak self] value in
            Task { @MainActor in self?.vitals.latestSystolic = value }
        }
        fetchLatestSample(.bloodPressureDiastolic, unit: .millimeterOfMercury()) { [weak self] value in
            Task { @MainActor in self?.vitals.latestDiastolic = value }
        }
    }

    // MARK: - Body Temperature

    func fetchLatestBodyTemperature() {
        let type = HKQuantityType(.bodyTemperature)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        // Only show body temp from the last 24 hours
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: Date(), options: .strictStartDate)

        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { [weak self] _, results, _ in
            if let sample = results?.first as? HKQuantitySample {
                let value = sample.quantity.doubleValue(for: .degreeCelsius())
                let date = sample.startDate
                Task { @MainActor in
                    self?.vitals.latestBodyTemp = value
                    self?.vitals.bodyTempTimestamp = date
                }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Today's HR Range

    func fetchTodayHeartRateRange() {
        let type = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let startOfDay = Date.cal.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: [.discreteMin, .discreteMax]
        ) { [weak self] _, result, _ in
            let minVal = result?.minimumQuantity()?.doubleValue(for: unit)
            let maxVal = result?.maximumQuantity()?.doubleValue(for: unit)
            Task { @MainActor in
                self?.vitals.todayHeartRateMin = minVal
                self?.vitals.todayHeartRateMax = maxVal
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Latest Workout

    func fetchLatestWorkout() {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        // Only show workouts from the last 7 days
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: Date(), options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, results, _ in
            if let w = results?.first as? HKWorkout {
                let typeName = w.workoutActivityType.displayName
                let duration = w.duration / 60.0
                let caloriesType = HKQuantityType(.activeEnergyBurned)
                let calories = w.statistics(for: caloriesType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
                let date = w.startDate
                Task { @MainActor in
                    self?.workout.lastWorkoutType = typeName
                    self?.workout.lastWorkoutDuration = duration
                    self?.workout.lastWorkoutCalories = calories
                    self?.workout.lastWorkoutTimestamp = date
                    self?.computeReadinessScore()
                }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Recovery → Live Energy

    /// Locks today's Recovery anchor each morning, then drains it through the
    /// day from accumulated active calories. The single number on Home is:
    /// • the morning Recovery lock when the watch is off-wrist,
    /// • `max(energyFloor, lock - strainDrain)` rounded to Int when on-wrist,
    /// • blank only when no lock exists today AND the watch is off.
    func computeReadinessScore() {
        let now = Date()
        let hrAge = vitals.heartRateTimestamp.map { now.timeIntervalSince($0) } ?? .infinity

        if hrAge > ReadinessScorerConfig.onWristMaxAgeSeconds {
            recovery.isWearingWatch = false
            recovery.scoreLabel = "Recovery"
            // On-wrist preserve: a morning lock is a legitimate snapshot from
            // when the watch WAS on the wrist overnight; mid-day wrist removal
            // does not invalidate it. Keep showing the anchor (no live drain
            // because we have no current activity stream).
            if let lock = readinessStore.loadMorningLock(for: now) {
                recovery.readinessScore = lock
                recovery.readinessConfidence = readinessStore.loadMorningLockConfidence(for: now) ?? recovery.readinessConfidence
            } else if recovery.hasCheckedOnWristOnce {
                recovery.readinessScore = nil
                recovery.readinessConfidence = nil
                // Travels with the score it describes. Left behind, the card
                // falls back to the Daily Health Score and prints last
                // readiness reading's range around an unrelated number.
                recovery.readinessUncertainty = nil
            }
            // else: cold-launch flicker guard — the very first call after
            // `init` may run before HR has streamed in. Leave whatever the
            // initialiser loaded so the ring does not flash empty for a frame.
            recovery.hasCheckedOnWristOnce = true
            return
        }

        recovery.isWearingWatch = true
        recovery.hasCheckedOnWristOnce = true

        guard let lock = resolveMorningRecoveryLock(now: now) else {
            // No lock yet today and the gates have not been met. Do not blank
            // a previously displayed lock — `recovery.readinessScore` already
            // holds whatever the last successful pass produced.
            return
        }

        let strainDrain = computeStrainDrainSinceWake()
        let liveEnergy = Int((max(ReadinessScorerConfig.energyFloor, Double(lock) - strainDrain)).rounded())
        recovery.readinessScore = liveEnergy
        recovery.scoreLabel = strainDrain < ReadinessScorerConfig.energyLabelStrainThreshold ? "Recovery" : "Energy"
        // Legacy widget compat: the existing widget reads `loadCachedScore`,
        // so keep mirroring the live number there. The widget snapshot in
        // `DashboardViewModel.writeWidgetSnapshots` independently prefers the
        // morning lock for stability — this only feeds the legacy timeline.
        readinessStore.saveCachedScore(liveEnergy)
    }

    /// Returns today's morning Recovery anchor, computing and persisting it
    /// the first time the gates pass. Gate: last-night sleep present plus HRV
    /// and RHR each within `morningLockFreshnessHours` so we never anchor on
    /// stale overnight data.
    private func resolveMorningRecoveryLock(now: Date) -> Int? {
        if let existing = readinessStore.loadMorningLock(for: now) {
            return existing
        }

        guard sleep.hasSleepData else { return nil }

        let freshnessSeconds = ReadinessScorerConfig.morningLockFreshnessHours * 3600
        let hrvAge = recovery.latestHRVTimestamp.map { now.timeIntervalSince($0) } ?? .infinity
        let rhrAge = recovery.latestRestingHeartRateTimestamp.map { now.timeIntervalSince($0) } ?? .infinity
        guard hrvAge <= freshnessSeconds, rhrAge <= freshnessSeconds else { return nil }

        let input = ReadinessScorer.Input(
            now: now,
            hrv: recovery.latestHRV,
            hrvTimestamp: recovery.latestHRVTimestamp,
            hrvBaseline: readinessBaselines[.heartRateVariability],
            restingHeartRate: recovery.latestRestingHeartRate,
            restingHeartRateTimestamp: recovery.latestRestingHeartRateTimestamp,
            restingHeartRateBaseline: readinessBaselines[.restingHeartRate],
            sleepDuration: sleep.lastNightSleepDuration,
            deepSleep: sleep.lastNightDeepSleep,
            remSleep: sleep.lastNightREMSleep,
            hasSleepStageBreakdown: sleep.hasSleepStageBreakdown,
            workoutTimestamp: workout.lastWorkoutTimestamp,
            workoutDurationMinutes: workout.lastWorkoutDuration,
            workoutCalories: workout.lastWorkoutCalories,
            previousSmoothedScore: smoothedReadinessScore
        )

        guard let assessment = ReadinessScorer.assess(input) else { return nil }

        smoothedReadinessScore = assessment.smoothedScore
        readinessStore.saveMorningLock(assessment.score, for: now)
        readinessStore.saveMorningLockConfidence(assessment.confidence, for: now)
        recovery.readinessConfidence = assessment.confidence
        recovery.readinessUncertainty = assessment.uncertainty
        return assessment.score
    }

    /// Strain drain in score-points since wake. HealthKit's `activeEnergyBurned`
    /// already includes any workout calories — adding `lastWorkoutCalories` on
    /// top would double-count and over-drain Energy after a workout.
    private func computeStrainDrainSinceWake() -> Double {
        let raw = activity.todayActiveCalories / ReadinessScorerConfig.kcalPerStrainPoint
        return min(raw, ReadinessScorerConfig.maxStrainDrain)
    }

    // MARK: - Last Night's Sleep Fetch

    func fetchLastNightSleep() {
        let sleepType = HKCategoryType(.sleepAnalysis)
        guard let window = sleepSummaryBuilder.queryWindow(containing: Date()) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: window.start,
            end: window.end,
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { [weak self] _, results, _ in
            guard let self, let samples = results as? [HKCategorySample] else { return }
            let summary = self.sleepSummaryBuilder.summarize(samples: samples)

            Task { @MainActor in
                self.sleep.apply(summary: summary)
                self.computeReadinessScore()
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Today's Mindful Minutes

    func fetchTodayMindfulMinutes() {
        let mindfulType = HKCategoryType(.mindfulSession)
        let startOfDay = Date.cal.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: mindfulType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, results, _ in
            let totalSeconds = (results ?? []).reduce(0.0) { sum, sample in
                sum + sample.endDate.timeIntervalSince(sample.startDate)
            }
            Task { @MainActor in
                self?.activity.todayMindfulMinutes = totalSeconds / 60.0
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fallback Latest-Sample Fetches

    private func fetchLatestSampleWithDate(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, maxAge: TimeInterval, completion: @escaping (Double, Date) -> Void) {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let cutoff = Date().addingTimeInterval(-maxAge)
        let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: Date(), options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { _, results, _ in
            if let sample = results?.first as? HKQuantitySample {
                let value = sample.quantity.doubleValue(for: unit)
                completion(value, sample.startDate)
            }
        }

        healthStore.execute(query)
    }

    private func fetchFallbackHeartRate() {
        // Fetch if nil or stale (>2h old). ensures recovery after watch is put back on
        let needsFetch = vitals.currentHeartRate == nil || vitals.isStale
        guard needsFetch else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        fetchLatestSampleWithDate(.heartRate, unit: unit, maxAge: 24 * 3600) { [weak self] value, date in
            Task { @MainActor in
                self?.vitals.currentHeartRate = value
                self?.vitals.heartRateTimestamp = date
                self?.lastUpdate = Date()
            }
        }
    }

    private func fetchFallbackBloodOxygen() {
        let needsFetch = vitals.currentBloodOxygen == nil || vitals.isStale
        guard needsFetch else { return }
        fetchLatestSampleWithDate(.oxygenSaturation, unit: .percent(), maxAge: 24 * 3600) { [weak self] value, date in
            Task { @MainActor in
                self?.vitals.currentBloodOxygen = value * 100
                self?.vitals.bloodOxygenTimestamp = date
                self?.lastUpdate = Date()
            }
        }
    }

    private func fetchFallbackRespiratoryRate() {
        let needsFetch = vitals.currentRespiratoryRate == nil || vitals.isStale
        guard needsFetch else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        fetchLatestSampleWithDate(.respiratoryRate, unit: unit, maxAge: 48 * 3600) { [weak self] value, date in
            Task { @MainActor in
                self?.vitals.currentRespiratoryRate = value
                self?.vitals.respiratoryRateTimestamp = date
                self?.vitals.respiratoryRateUnavailable = false
                self?.lastUpdate = Date()
            }
        }
    }

    // MARK: - Query Helpers

    private func fetchLatestSample(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let cutoff = Date().addingTimeInterval(-48 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: Date(), options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: 1,
            sortDescriptors: [sort]
        ) { _, results, _ in
            if let sample = results?.first as? HKQuantitySample {
                let value = sample.quantity.doubleValue(for: unit)
                completion(value)
            }
        }

        healthStore.execute(query)
    }

    private func refreshReadinessBaselinesIfNeeded(force: Bool = false) {
        let now = Date()
        if !force,
           let last = lastReadinessBaselineRefresh,
           now.timeIntervalSince(last) < Self.readinessBaselineRefreshInterval {
            return
        }
        guard readinessBaselineRefreshTask == nil else { return }

        readinessBaselineRefreshTask = Task { [weak self] in
            guard let self else { return }

            async let rhrValues = self.fetchHistoricalDailyAverages(
                identifier: .restingHeartRate,
                unit: HKUnit.count().unitDivided(by: .minute())
            )
            async let hrvValues = self.fetchHistoricalDailyAverages(
                identifier: .heartRateVariabilitySDNN,
                unit: HKUnit.secondUnit(with: .milli)
            )
            async let recentHRV = self.fetchRecentDailyAverages(
                identifier: .heartRateVariabilitySDNN,
                unit: HKUnit.secondUnit(with: .milli),
                days: Self.weeklyTrendDays
            )

            let rhrBaseline = ReadinessScorer.makeBaseline(values: await rhrValues, minimumSD: 2.0)
            let hrvBaseline = ReadinessScorer.makeBaseline(values: await hrvValues, minimumSD: 4.0)
            let recent = await recentHRV

            await MainActor.run {
                if let rhrBaseline {
                    self.readinessBaselines[.restingHeartRate] = rhrBaseline
                }
                if let hrvBaseline {
                    self.readinessBaselines[.heartRateVariability] = hrvBaseline
                }
                self.recovery.weeklyTrend = self.computeWeeklyHRVTrend(recent: recent)
                self.lastReadinessBaselineRefresh = Date()
                self.readinessBaselineRefreshTask = nil
                self.computeReadinessScore()
            }
        }
    }

    /// Classifies the last 7 days of daily HRV averages against the personal
    /// baseline. Threshold is a multiple of the baseline standard deviation so
    /// noisy daily swings stay "stable" while a sustained shift surfaces. The
    /// caption is hidden until we have both a baseline and at least
    /// `weeklyTrendMinDays` recent samples.
    private func computeWeeklyHRVTrend(recent: [Double]) -> WeeklyHRVTrend {
        let baselineMean = readinessBaselines[.heartRateVariability]?.mean
        let baselineSD = readinessBaselines[.heartRateVariability]?.standardDeviation
        guard recent.count >= ReadinessScorerConfig.weeklyTrendMinDays,
              let mean = baselineMean,
              let sd = baselineSD else {
            return .insufficientData
        }
        let recentMean = recent.reduce(0, +) / Double(recent.count)
        let threshold = ReadinessScorerConfig.weeklyTrendThresholdSDMultiplier * sd
        if recentMean > mean + threshold { return .improving }
        if recentMean < mean - threshold { return .declining }
        return .stable
    }

    /// Fetches `days` of daily averages ending today, no baseline gap. Mirrors
    /// `fetchHistoricalDailyAverages` so the two queries share their HK setup
    /// and stay easy to compare side-by-side.
    private func fetchRecentDailyAverages(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int
    ) async -> [Double] {
        let calendar = Date.cal
        let now = Date()
        let end = now
        let start = calendar.date(byAdding: .day, value: -days, to: now)
            ?? now.addingTimeInterval(-Double(days) * 24 * 3600)

        return await withCheckedContinuation { continuation in
            let type = HKQuantityType(identifier)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            var interval = DateComponents()
            interval.day = 1

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: calendar.startOfDay(for: start),
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: [])
                    return
                }

                var values: [Double] = []
                results.enumerateStatistics(from: start, to: end) { statistics, _ in
                    guard let average = statistics.averageQuantity()?.doubleValue(for: unit),
                          average.isFinite,
                          average > 0 else { return }
                    values.append(average)
                }
                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }
    }

    private func fetchHistoricalDailyAverages(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> [Double] {
        let calendar = Date.cal
        let now = Date()
        let baselineEnd = calendar.date(byAdding: .day, value: -Self.readinessBaselineGapDays, to: now) ?? now
        let baselineStart = calendar.date(
            byAdding: .day,
            value: -(Self.readinessBaselineWindowDays + Self.readinessBaselineGapDays),
            to: now
        ) ?? baselineEnd.addingTimeInterval(-Double(Self.readinessBaselineWindowDays) * 24 * 3600)

        return await withCheckedContinuation { continuation in
            let type = HKQuantityType(identifier)
            let predicate = HKQuery.predicateForSamples(withStart: baselineStart, end: baselineEnd, options: .strictStartDate)
            var interval = DateComponents()
            interval.day = 1

            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage,
                anchorDate: calendar.startOfDay(for: baselineStart),
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results else {
                    continuation.resume(returning: [])
                    return
                }

                var values: [Double] = []
                results.enumerateStatistics(from: baselineStart, to: baselineEnd) { statistics, _ in
                    guard let average = statistics.averageQuantity()?.doubleValue(for: unit),
                          average.isFinite,
                          average > 0 else { return }
                    values.append(average)
                }
                continuation.resume(returning: values)
            }

            healthStore.execute(query)
        }
    }
}
