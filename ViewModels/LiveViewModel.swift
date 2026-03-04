import Foundation
import HealthKit
import Observation
import SwiftUI

/// ViewModel for the Live tab — streams real-time health data from Apple Watch via HealthKit.
/// Properties are grouped into independently observable sub-objects so that changes in one group
/// (e.g. heart rate) don't trigger re-renders in views that only read another group (e.g. sleep).
@Observable
final class LiveViewModel {
    let healthKitManager: HealthKitManager
    private var healthStore: HKHealthStore { healthKitManager.healthStore }

    // MARK: - Grouped Observable Sub-Objects

    /// Real-time vitals from Apple Watch (HR, SpO2, respiratory rate, BP, temperature)
    let vitals = VitalsData()
    /// Last night's sleep analysis
    let sleep = SleepData()
    /// Today's cumulative activity stats and goals
    let activity = ActivityData()
    /// Recovery metrics (RHR, HRV, readiness, stress)
    let recovery = RecoveryData()
    /// Most recent workout info
    let workout = WorkoutData()

    // MARK: - Streaming State

    var isStreaming = false
    var lastUpdate: Date?

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var bloodOxygenQuery: HKAnchoredObjectQuery?
    private var respiratoryRateQuery: HKAnchoredObjectQuery?
    private var refreshTimer: Timer?
    private var respiratoryAvailabilityWorkItem: DispatchWorkItem?

    /// Throttle UI-facing property updates to max 1 per second to reduce GPU work.
    private var lastUIUpdateTime: Date = .distantPast
    private var pendingHeartRateUpdate: PendingHRUpdate?
    private var pendingUIUpdateWorkItem: DispatchWorkItem?

    private struct PendingHRUpdate {
        var merged: [(date: Date, value: Double)]
        var latestValue: Double
        var latestTimestamp: Date
    }

    /// Live polling cadence and chart density controls (CPU/GPU protection).
    private static let liveActivityRefreshInterval: TimeInterval = 120
    private static let heartRateBucketSize: TimeInterval = 10
    private static let maxHeartRatePoints = 180

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    // MARK: - Heart Rate Zone (needs healthStore for age)

    /// Estimated max heart rate (220 - age, defaults to 190 if unknown).
    /// Cached on first access — date of birth never changes.
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

    enum HeartRateZone: String {
        case rest = "Rest"
        case warmUp = "Warm Up"
        case fatBurn = "Fat Burn"
        case cardio = "Cardio"
        case peak = "Peak"
        case extreme = "Extreme"

        var color: Color {
            switch self {
            case .rest: return .gray
            case .warmUp: return .blue
            case .fatBurn: return .green
            case .cardio: return .yellow
            case .peak: return .orange
            case .extreme: return .red
            }
        }

        var index: Int {
            switch self {
            case .rest: return 0
            case .warmUp: return 1
            case .fatBurn: return 2
            case .cardio: return 3
            case .peak: return 4
            case .extreme: return 5
            }
        }
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

    enum VitalStatus: Equatable {
        case normal, elevated, low, critical, unknown

        var label: String {
            switch self {
            case .normal: return "Normal"
            case .elevated: return "Elevated"
            case .low: return "Low"
            case .critical: return "Critical"
            case .unknown: return "No Data"
            }
        }

        var color: Color {
            switch self {
            case .normal: return .green
            case .elevated: return .orange
            case .low: return .yellow
            case .critical: return .red
            case .unknown: return .gray
            }
        }
    }

    // MARK: - Readiness + Today Quick Fetch (for Home tab, no streams)

    /// Timestamps for tiered Home polling — avoids querying slow-changing data every tick
    private var lastSlowFetch: Date?   // RHR, HRV, workout, sleep
    private var lastMediumFetch: Date?  // goals, mindful minutes

    /// Tiered polling intervals (seconds)
    private static let fastInterval: TimeInterval = 60     // steps, calories, exercise, stand, distance, flights
    private static let mediumInterval: TimeInterval = 300   // goals, mindful minutes
    private static let slowInterval: TimeInterval = 120     // RHR, HRV, workout, sleep

    /// Full fetch — calls all tiers unconditionally (used on first appear and manual refresh).
    /// Also pre-fetches latest vitals so the Live tab opens instantly with data.
    func fetchHomeData() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
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
        lastSlowFetch = Date()
        lastMediumFetch = Date()
    }

    /// Tiered fetch — only queries data whose refresh interval has elapsed
    func fetchHomeDataTiered() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let now = Date()

        // Fast tier: always fetch (steps, calories, exercise, stand, distance, flights)
        fetchTodayCumulativeStats()

        // Medium tier: goals + mindful minutes (every 5 min)
        if lastMediumFetch == nil || now.timeIntervalSince(lastMediumFetch!) >= Self.mediumInterval {
            fetchActivityGoals()
            fetchTodayMindfulMinutes()
            lastMediumFetch = now
        }

        // Slow tier: RHR, HRV, workout, sleep (every 10 min)
        if lastSlowFetch == nil || now.timeIntervalSince(lastSlowFetch!) >= Self.slowInterval {
            fetchLatestDailyValues()
            fetchLatestWorkout()
            fetchLastNightSleep()
            lastSlowFetch = now
        }
    }

    // MARK: - Start / Stop

    func startStreaming() {
        guard !isStreaming, HKHealthStore.isHealthDataAvailable() else { return }
        isStreaming = true

        // Reset flags from previous session so fresh data takes priority
        vitals.respiratoryRateUnavailable = false

        startHeartRateStream()
        startBloodOxygenStream()
        startRespiratoryRateStream()
        fetchTodayCumulativeStats()
        fetchLatestDailyValues()
        fetchLatestBloodPressure()
        fetchLatestBodyTemperature()
        fetchLatestWorkout()
        fetchTodayHeartRateRange()
        fetchActivityGoals()
        fetchTodayMindfulMinutes()
        fetchLastNightSleep()
        computeReadinessScore()

        // Run fallback fetches immediately in parallel with anchored queries.
        // This ensures the user sees last-known values right away, even if the
        // anchored query's narrow window (30 min) has no recent samples.
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

        // Refresh cumulative stats every 2 minutes (vitals stream continuously via anchored queries).
        let timer = Timer.scheduledTimer(withTimeInterval: Self.liveActivityRefreshInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.fetchTodayCumulativeStats()
            }
        }
        timer.tolerance = 15
        refreshTimer = timer
    }

    func stopStreaming() {
        isStreaming = false

        for query in [heartRateQuery, bloodOxygenQuery, respiratoryRateQuery].compactMap({ $0 }) {
            healthStore.stop(query)
        }
        heartRateQuery = nil
        bloodOxygenQuery = nil
        respiratoryRateQuery = nil

        refreshTimer?.invalidate()
        refreshTimer = nil
        respiratoryAvailabilityWorkItem?.cancel()
        respiratoryAvailabilityWorkItem = nil
        pendingUIUpdateWorkItem?.cancel()
        pendingUIUpdateWorkItem = nil
        pendingHeartRateUpdate = nil

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

    // MARK: - Heart Rate Stream

    private func startHeartRateStream() {
        let heartRateType = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())

        // Start from 30 minutes ago to populate mini chart
        let thirtyMinAgo = Date().addingTimeInterval(-30 * 60)
        let predicate = HKQuery.predicateForSamples(withStart: thirtyMinAgo, end: nil, options: .strictStartDate)

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples, unit: unit)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples, unit: unit)
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    private func processHeartRateSamples(_ samples: [HKSample]?, unit: HKUnit) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }
        let sortedSamples = quantitySamples.sorted { $0.startDate < $1.startDate }
        let latestSample = sortedSamples.last

        // Pre-bucket off-main to avoid multiple @Observable writes per sample.
        var bucketedPoints: [(date: Date, value: Double)] = []
        bucketedPoints.reserveCapacity(sortedSamples.count)
        for sample in sortedSamples {
            let value = sample.quantity.doubleValue(for: unit)
            let bucketedDate = Self.bucketDate(sample.startDate, by: Self.heartRateBucketSize)
            if let last = bucketedPoints.last, last.date == bucketedDate {
                bucketedPoints[bucketedPoints.count - 1] = (date: bucketedDate, value: value)
            } else {
                bucketedPoints.append((date: bucketedDate, value: value))
            }
        }

        Task { @MainActor in
            // Merge new bucketed points into the existing (or pending) chart data.
            let base = pendingHeartRateUpdate?.merged ?? vitals.recentHeartRates
            var merged = base
            merged.reserveCapacity(merged.count + bucketedPoints.count)

            for point in bucketedPoints {
                if let last = merged.last, last.date == point.date {
                    merged[merged.count - 1] = point
                } else {
                    merged.append(point)
                }
            }

            // Keep only last 30 minutes
            let cutoff = Date().addingTimeInterval(-30 * 60)
            if let firstKeptIndex = merged.firstIndex(where: { $0.date >= cutoff }) {
                if firstKeptIndex > 0 {
                    merged.removeFirst(firstKeptIndex)
                }
            } else {
                merged.removeAll()
            }

            // Hard cap to avoid unbounded chart work in long sessions.
            if merged.count > Self.maxHeartRatePoints {
                merged.removeFirst(merged.count - Self.maxHeartRatePoints)
            }

            // Buffer the processed data
            if let latest = latestSample {
                pendingHeartRateUpdate = PendingHRUpdate(
                    merged: merged,
                    latestValue: latest.quantity.doubleValue(for: unit),
                    latestTimestamp: latest.startDate
                )
            } else {
                pendingHeartRateUpdate = PendingHRUpdate(
                    merged: merged,
                    latestValue: pendingHeartRateUpdate?.latestValue ?? 0,
                    latestTimestamp: pendingHeartRateUpdate?.latestTimestamp ?? Date()
                )
            }

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

        // Compute session stats
        if merged.isEmpty {
            vitals.heartRateMin30 = nil
            vitals.heartRateMax30 = nil
            vitals.heartRateAvg30 = nil
        } else {
            var minValue = Double.greatestFiniteMagnitude
            var maxValue = -Double.greatestFiniteMagnitude
            var sum = 0.0
            for point in merged {
                minValue = min(minValue, point.value)
                maxValue = max(maxValue, point.value)
                sum += point.value
            }
            vitals.heartRateMin30 = minValue
            vitals.heartRateMax30 = maxValue
            vitals.heartRateAvg30 = sum / Double(merged.count)
        }

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

    /// Generic anchored object query for vital sign streaming — eliminates duplicate setup code
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
            self?.processLatestSample(samples, unit: unit, update: update)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processLatestSample(samples, unit: unit, update: update)
        }

        healthStore.execute(query)
        return query
    }

    // MARK: - Helpers

    private func processLatestSample(_ samples: [HKSample]?, unit: HKUnit, update: @escaping @MainActor (Double, Date) -> Void) {
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
        let startOfDay = Calendar.current.startOfDay(for: Date())
        fetchTodayStat(.stepCount, unit: .count(), from: startOfDay) { [weak self] v in
            Task { @MainActor in self?.activity.todaySteps = v }
        }
        fetchTodayStat(.activeEnergyBurned, unit: .kilocalorie(), from: startOfDay) { [weak self] v in
            Task { @MainActor in self?.activity.todayActiveCalories = v }
        }
        fetchTodayStat(.appleExerciseTime, unit: .minute(), from: startOfDay) { [weak self] v in
            Task { @MainActor in self?.activity.todayExerciseMinutes = v }
        }
        fetchTodayStat(.appleStandTime, unit: .hour(), from: startOfDay) { [weak self] v in
            Task { @MainActor in self?.activity.todayStandHours = v }
        }
        fetchTodayStat(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: startOfDay) { [weak self] v in
            Task { @MainActor in self?.activity.todayDistance = v }
        }
        fetchTodayStat(.flightsClimbed, unit: .count(), from: startOfDay) { [weak self] v in
            Task { @MainActor in self?.activity.todayFlightsClimbed = v }
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
        fetchLatestSampleWithDate(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), maxAge: 48 * 3600) { [weak self] value, date in
            Task { @MainActor in
                self?.recovery.latestRestingHeartRate = value
                self?.recovery.latestRestingHeartRateTimestamp = date
                self?.computeReadinessScore()
            }
        }
        fetchLatestSampleWithDate(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), maxAge: 48 * 3600) { [weak self] value, date in
            Task { @MainActor in
                self?.recovery.latestHRV = value
                self?.recovery.latestHRVTimestamp = date
                self?.computeReadinessScore()
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
                }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Readiness Score

    func computeReadinessScore() {
        let hrv = recovery.latestHRV
        let rhr = recovery.latestRestingHeartRate

        // Need at least one metric to compute a score
        guard hrv != nil || rhr != nil else {
            recovery.readinessScore = nil
            return
        }

        if let hrv, let rhr {
            // Full score: both metrics available
            let hrvScore = min(max((hrv - 20) / 40.0 * 50, 0), 50)
            let rhrScore = min(max((80 - rhr) / 30.0 * 50, 0), 50)
            recovery.readinessScore = Int(hrvScore + rhrScore)
        } else if let rhr {
            // Partial score: RHR only — scale to full range (assume median HRV contribution)
            let rhrScore = min(max((80 - rhr) / 30.0 * 50, 0), 50)
            recovery.readinessScore = Int(rhrScore + 25) // 25 = neutral HRV midpoint
        } else if let hrv {
            // Partial score: HRV only — scale to full range (assume median RHR contribution)
            let hrvScore = min(max((hrv - 20) / 40.0 * 50, 0), 50)
            recovery.readinessScore = Int(hrvScore + 25) // 25 = neutral RHR midpoint
        }
    }

    // MARK: - Last Night's Sleep Fetch

    func fetchLastNightSleep() {
        let sleepType = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current

        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              let yesterdayEvening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday),
              let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startOfToday) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: yesterdayEvening, end: todayNoon, options: .strictStartDate)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        ) { [weak self] _, results, _ in
            guard let samples = results as? [HKCategorySample] else { return }

            var deep: TimeInterval = 0
            var rem: TimeInterval = 0
            var core: TimeInterval = 0
            var awake: TimeInterval = 0
            var total: TimeInterval = 0

            for sample in samples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
                switch value {
                case .asleepDeep:
                    deep += duration
                    total += duration
                case .asleepREM:
                    rem += duration
                    total += duration
                case .asleepCore:
                    core += duration
                    total += duration
                case .awake:
                    awake += duration
                case .asleepUnspecified, .inBed:
                    total += duration
                @unknown default:
                    break
                }
            }

            Task { @MainActor in
                self?.sleep.lastNightSleepDuration = total
                self?.sleep.lastNightDeepSleep = deep
                self?.sleep.lastNightREMSleep = rem
                self?.sleep.lastNightCoreSleep = core
                self?.sleep.lastNightAwakeTime = awake
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
        // Fetch if nil or stale (>2h old) — ensures recovery after watch is put back on
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

    private static func bucketDate(_ date: Date, by interval: TimeInterval) -> Date {
        let t = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: floor(t / interval) * interval)
    }
}

// MARK: - Observable Sub-Object Definitions

extension LiveViewModel {

    /// Real-time vitals — HR, SpO2, respiratory rate, blood pressure, body temperature
    @Observable
    final class VitalsData {
        // Heart rate
        var currentHeartRate: Double?
        var heartRateTimestamp: Date?
        var recentHeartRates: [(date: Date, value: Double)] = []
        var heartRateMin30: Double?
        var heartRateMax30: Double?
        var heartRateAvg30: Double?
        var todayHeartRateMin: Double?
        var todayHeartRateMax: Double?

        // Blood oxygen
        var currentBloodOxygen: Double?
        var bloodOxygenTimestamp: Date?

        // Respiratory rate
        var currentRespiratoryRate: Double?
        var respiratoryRateTimestamp: Date?
        var respiratoryRateUnavailable = false

        // Wrist temperature
        var currentWristTemperature: Double?
        var wristTemperatureTimestamp: Date?

        // Blood pressure
        var latestSystolic: Double?
        var latestDiastolic: Double?
        var bloodPressureTimestamp: Date?

        // Body temperature
        var latestBodyTemp: Double?
        var bodyTempTimestamp: Date?

        // MARK: - Freshness & Status (computed from vitals only)

        private static let freshnessThreshold: TimeInterval = 30 * 60

        var heartRateStatus: LiveViewModel.VitalStatus {
            guard let hr = currentHeartRate else { return .unknown }
            if hr > 120 { return .elevated }
            if hr < 45 { return .low }
            return .normal
        }

        var bloodOxygenStatus: LiveViewModel.VitalStatus {
            guard let spo2 = currentBloodOxygen else { return .unknown }
            if spo2 < 92 { return .critical }
            if spo2 < 95 { return .low }
            return .normal
        }

        var respiratoryRateStatus: LiveViewModel.VitalStatus {
            guard let rr = currentRespiratoryRate else { return .unknown }
            if rr > 24 { return .elevated }
            if rr < 10 { return .low }
            return .normal
        }

        var bloodPressureStatus: LiveViewModel.VitalStatus {
            guard let sys = latestSystolic else { return .unknown }
            if sys >= 140 { return .critical }
            if sys >= 130 { return .elevated }
            if sys < 90 { return .low }
            return .normal
        }

        var isHeartRateFresh: Bool {
            guard let ts = heartRateTimestamp else { return false }
            return Date().timeIntervalSince(ts) < Self.freshnessThreshold
        }

        var isBloodOxygenFresh: Bool {
            guard let ts = bloodOxygenTimestamp else { return false }
            return Date().timeIntervalSince(ts) < Self.freshnessThreshold
        }

        var isRespiratoryRateFresh: Bool {
            guard let ts = respiratoryRateTimestamp else { return false }
            return Date().timeIntervalSince(ts) < Self.freshnessThreshold
        }

        var hasAnyData: Bool {
            currentHeartRate != nil || currentBloodOxygen != nil || currentRespiratoryRate != nil
        }

        var hasFreshData: Bool {
            isHeartRateFresh || isBloodOxygenFresh || isRespiratoryRateFresh
        }

        var hasRecentData: Bool {
            let twoHours: TimeInterval = 2 * 3600
            let now = Date()
            if let ts = heartRateTimestamp, now.timeIntervalSince(ts) < twoHours { return true }
            if let ts = bloodOxygenTimestamp, now.timeIntervalSince(ts) < twoHours { return true }
            if let ts = respiratoryRateTimestamp, now.timeIntervalSince(ts) < twoHours { return true }
            return false
        }

        var isStale: Bool { hasAnyData && !hasRecentData }
        var isAging: Bool { hasAnyData && !hasFreshData && hasRecentData }

        var mostRecentTimestamp: Date? {
            [heartRateTimestamp, bloodOxygenTimestamp, respiratoryRateTimestamp]
                .compactMap { $0 }
                .max()
        }
    }

    /// Last night's sleep data
    @Observable
    final class SleepData {
        var lastNightSleepDuration: TimeInterval = 0
        var lastNightDeepSleep: TimeInterval = 0
        var lastNightREMSleep: TimeInterval = 0
        var lastNightCoreSleep: TimeInterval = 0
        var lastNightAwakeTime: TimeInterval = 0

        var hasSleepData: Bool { lastNightSleepDuration > 0 }

        var hasSleepStageBreakdown: Bool {
            lastNightDeepSleep > 0 || lastNightREMSleep > 0 || lastNightCoreSleep > 0
        }

        var sleepQualityLabel: String {
            let hours = lastNightSleepDuration / 3600
            if hours >= 7.5 { return "Great" }
            if hours >= 6.5 { return "Good" }
            if hours >= 5.5 { return "Fair" }
            return "Poor"
        }
    }

    /// Today's cumulative activity and goals
    @Observable
    final class ActivityData {
        var todaySteps: Double = 0
        var todayActiveCalories: Double = 0
        var todayExerciseMinutes: Double = 0
        var todayStandHours: Double = 0
        var todayDistance: Double = 0
        var todayFlightsClimbed: Double = 0
        var todayMindfulMinutes: Double = 0

        var moveGoal: Double = 500
        var exerciseGoal: Double = 30
        var standGoal: Double = 12

        var moveProgress: Double { min(todayActiveCalories / moveGoal, 1.0) }
        var exerciseProgress: Double { min(todayExerciseMinutes / exerciseGoal, 1.0) }
        var standProgress: Double { min(todayStandHours / standGoal, 1.0) }

        var hasAnyData: Bool {
            todaySteps > 0 || todayActiveCalories > 0 || todayExerciseMinutes > 0
        }
    }

    /// Recovery metrics — RHR, HRV, readiness score, stress
    @Observable
    final class RecoveryData {
        var latestRestingHeartRate: Double?
        var latestRestingHeartRateTimestamp: Date?
        var latestHRV: Double?
        var latestHRVTimestamp: Date?
        var latestHeartRateRecovery: Double?
        var readinessScore: Int?

        var isReadinessDataFresh: Bool {
            let fortyEightHours: TimeInterval = 48 * 3600
            let now = Date()
            let rhrFresh = latestRestingHeartRateTimestamp.map { now.timeIntervalSince($0) < fortyEightHours } ?? false
            let hrvFresh = latestHRVTimestamp.map { now.timeIntervalSince($0) < fortyEightHours } ?? false
            // Fresh if at least one metric is available (matches partial score logic)
            return rhrFresh || hrvFresh
        }

        var stressLevel: Int? {
            guard let hrv = latestHRV, let rhr = latestRestingHeartRate else { return nil }
            let hrvStress = min(max((60 - hrv) / 40.0 * 50, 0), 50)
            let rhrStress = min(max((rhr - 50) / 30.0 * 50, 0), 50)
            return Int(hrvStress + rhrStress)
        }

        var stressLabel: String {
            guard let level = stressLevel else { return "No Data" }
            switch level {
            case 0..<20: return "Relaxed"
            case 20..<40: return "Low"
            case 40..<60: return "Moderate"
            case 60..<80: return "High"
            default: return "Very High"
            }
        }

        var stressColor: String {
            guard let level = stressLevel else { return "gray" }
            switch level {
            case 0..<20: return "green"
            case 20..<40: return "green"
            case 40..<60: return "yellow"
            case 60..<80: return "orange"
            default: return "red"
            }
        }
    }

    /// Most recent workout info
    @Observable
    final class WorkoutData {
        var lastWorkoutType: String?
        var lastWorkoutDuration: Double?
        var lastWorkoutCalories: Double?
        var lastWorkoutTimestamp: Date?
    }
}

// MARK: - Workout Activity Type Name

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength"
        case .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .dance: return "Dance"
        case .coreTraining: return "Core"
        case .pilates: return "Pilates"
        case .crossTraining: return "Cross Training"
        case .mixedCardio: return "Mixed Cardio"
        case .stairClimbing: return "Stair Climbing"
        default: return "Workout"
        }
    }

    var systemImageName: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .walking: return "figure.walk"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .yoga: return "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "dumbbell.fill"
        case .highIntensityIntervalTraining: return "bolt.heart.fill"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rower"
        case .dance: return "figure.dance"
        case .stairClimbing: return "figure.stairs"
        default: return "figure.mixed.cardio"
        }
    }
}
