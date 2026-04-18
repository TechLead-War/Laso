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

    private static let readinessBaselineWindowDays = 42
    private static let readinessBaselineGapDays = 2
    private static let readinessBaselineRefreshInterval: TimeInterval = 6 * 3600

    private var readinessBaselines: [ReadinessMetric: ReadinessScorer.BaselineStats] = [:]
    private var lastReadinessBaselineRefresh: Date?
    private var readinessBaselineRefreshTask: Task<Void, Never>?
    private var deferredRefreshTask: Task<Void, Never>?
    private var smoothedReadinessScore: Double?
    private var dailyLockedScore: Int?
    private var dailyLockDate: Date?
    private var refreshState = LiveRefreshPlanner.State()
    private var lastHomeFetchDate: Date?
    private var lastTieredFetchDate: Date?
    private var isFetchingCumulativeStats = false
    private var pendingCumulativeStatsCallbacks = 0
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
           let birthDate = Calendar.current.date(from: dob) {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
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
        // Debounce: skip if called within 1 second of last fetch
        if let last = lastHomeFetchDate, now.timeIntervalSince(last) < Self.homeFetchDebounce {
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
        fetchLatestWorkout()
        fetchLastNightSleep()
        // Pre-fetch latest vitals so Live tab has data immediately when opened
        fetchFallbackHeartRate()
        fetchFallbackBloodOxygen()
        fetchFallbackRespiratoryRate()
        refreshPlanner.markFullRefresh(at: now, state: &refreshState)
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
        let startOfDay = Calendar.current.startOfDay(for: Date())
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
        let startOfDay = Calendar.current.startOfDay(for: Date())
        fetchTodayStat(.stepCount, unit: .count(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.activity.todaySteps = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.activeEnergyBurned, unit: .kilocalorie(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.activity.todayActiveCalories = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.appleExerciseTime, unit: .minute(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.activity.todayExerciseMinutes = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.appleStandTime, unit: .hour(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.activity.todayStandHours = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.activity.todayDistance = v
                self?.finishCumulativeStatsFetch()
            }
        }
        fetchTodayStat(.flightsClimbed, unit: .count(), from: startOfDay) { [weak self] v in
            Task { @MainActor in
                self?.activity.todayFlightsClimbed = v
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

        let calendar = Calendar.current
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
                self.computeReadinessScore()
            }
        }
        fetchLatestSampleWithDate(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), maxAge: 48 * 3600) { [weak self] value, date in
            Task { @MainActor in
                guard let self else { return }
                self.recovery.latestHRV = value
                self.recovery.latestHRVTimestamp = date
                self.computeReadinessScore()
            }
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
        let startOfDay = Calendar.current.startOfDay(for: Date())
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

    // MARK: - Readiness Score

    func computeReadinessScore() {
        // Daily lock: once a confident score is set for today, keep returning it.
        // This prevents the score from jumping on pull-to-refresh or background fetches,
        // giving users a stable, trustworthy number that only changes the next day.
        if let locked = dailyLockedScore,
           let lockDate = dailyLockDate,
           Calendar.current.isDateInToday(lockDate) {
            recovery.readinessScore = locked
            return
        }

        let input = ReadinessScorer.Input(
            now: Date(),
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

        guard let assessment = ReadinessScorer.assess(input) else {
            recovery.readinessScore = nil
            recovery.readinessConfidence = nil
            smoothedReadinessScore = nil
            return
        }

        smoothedReadinessScore = assessment.smoothedScore
        recovery.readinessScore = assessment.score
        recovery.readinessConfidence = assessment.confidence
        readinessStore.saveCachedScore(assessment.score)

        // Lock the score for today once we have sufficient confidence
        // (meaning HRV + RHR + sleep data have all arrived)
        if assessment.confidence >= 50 {
            dailyLockedScore = assessment.score
            dailyLockDate = Date()
        }
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
        let startOfDay = Calendar.current.startOfDay(for: Date())
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

            let rhrBaseline = ReadinessScorer.makeBaseline(values: await rhrValues, minimumSD: 2.0)
            let hrvBaseline = ReadinessScorer.makeBaseline(values: await hrvValues, minimumSD: 4.0)

            await MainActor.run {
                if let rhrBaseline {
                    self.readinessBaselines[.restingHeartRate] = rhrBaseline
                }
                if let hrvBaseline {
                    self.readinessBaselines[.heartRateVariability] = hrvBaseline
                }
                self.lastReadinessBaselineRefresh = Date()
                self.readinessBaselineRefreshTask = nil
                self.computeReadinessScore()
            }
        }
    }

    private func fetchHistoricalDailyAverages(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> [Double] {
        let calendar = Calendar.current
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
