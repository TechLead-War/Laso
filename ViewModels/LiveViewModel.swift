import Foundation
import HealthKit
import Observation

/// ViewModel for the Live tab — streams real-time health data from Apple Watch via HealthKit
@Observable
final class LiveViewModel {
    let healthKitManager: HealthKitManager
    private let healthStore = HKHealthStore()

    // MARK: - Live Vitals

    var currentHeartRate: Double?
    var heartRateTimestamp: Date?
    var currentBloodOxygen: Double?
    var bloodOxygenTimestamp: Date?
    var currentRespiratoryRate: Double?
    var respiratoryRateTimestamp: Date?
    var currentWristTemperature: Double?
    var wristTemperatureTimestamp: Date?

    // MARK: - Heart Rate Session Stats (last 30 min)

    var recentHeartRates: [(date: Date, value: Double)] = []
    var heartRateMin30: Double?
    var heartRateMax30: Double?
    var heartRateAvg30: Double?

    // MARK: - Today's HR Range

    var todayHeartRateMin: Double?
    var todayHeartRateMax: Double?

    // MARK: - Latest Resting / Recovery Values

    var latestRestingHeartRate: Double?
    var latestHRV: Double?
    var latestHeartRateRecovery: Double?

    // MARK: - Blood Pressure

    var latestSystolic: Double?
    var latestDiastolic: Double?
    var bloodPressureTimestamp: Date?

    // MARK: - Body Temperature

    var latestBodyTemp: Double?
    var bodyTempTimestamp: Date?

    // MARK: - Today's Cumulative Activity

    var todaySteps: Double = 0
    var todayActiveCalories: Double = 0
    var todayExerciseMinutes: Double = 0
    var todayStandHours: Double = 0
    var todayDistance: Double = 0
    var todayFlightsClimbed: Double = 0

    // Activity goals — fetched from HealthKit, with evidence-based defaults
    // Defaults: WHO recommends 150 min/week (~30 min/day exercise),
    // Apple Watch default stand goal is 12 hrs (1 min standing in 12 waking hours)
    var moveGoal: Double = 500     // kcal
    var exerciseGoal: Double = 30  // minutes
    var standGoal: Double = 12     // hours

    // MARK: - Mindfulness

    var todayMindfulMinutes: Double = 0

    // MARK: - Latest Workout

    var lastWorkoutType: String?
    var lastWorkoutDuration: Double? // minutes
    var lastWorkoutCalories: Double?
    var lastWorkoutTimestamp: Date?

    // MARK: - Readiness Score (computed from HRV + RHR + sleep)

    var readinessScore: Int? // 0-100

    // MARK: - State

    var isStreaming = false
    var lastUpdate: Date?

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var bloodOxygenQuery: HKAnchoredObjectQuery?
    private var respiratoryRateQuery: HKAnchoredObjectQuery?
    private var refreshTimer: Timer?

    init(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    // MARK: - Heart Rate Zone

    /// Estimated max heart rate (220 - age, defaults to 190 if unknown)
    var estimatedMaxHR: Double {
        if let dob = try? healthStore.dateOfBirthComponents(),
           let birthDate = Calendar.current.date(from: dob) {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 30
            return Double(220 - age)
        }
        return 190
    }

    enum HeartRateZone: String {
        case rest = "Rest"
        case warmUp = "Warm Up"
        case fatBurn = "Fat Burn"
        case cardio = "Cardio"
        case peak = "Peak"
        case extreme = "Extreme"

        var color: String {
            switch self {
            case .rest: return "gray"
            case .warmUp: return "blue"
            case .fatBurn: return "green"
            case .cardio: return "yellow"
            case .peak: return "orange"
            case .extreme: return "red"
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
        guard let hr = currentHeartRate else { return .rest }
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
        guard let hr = currentHeartRate else { return 0 }
        return min(hr / estimatedMaxHR, 1.0)
    }

    // MARK: - Vital Status

    var heartRateStatus: VitalStatus {
        guard let hr = currentHeartRate else { return .unknown }
        if hr > 120 { return .elevated }
        if hr < 45 { return .low }
        return .normal
    }

    var bloodOxygenStatus: VitalStatus {
        guard let spo2 = currentBloodOxygen else { return .unknown }
        if spo2 < 92 { return .critical }
        if spo2 < 95 { return .low }
        return .normal
    }

    var respiratoryRateStatus: VitalStatus {
        guard let rr = currentRespiratoryRate else { return .unknown }
        if rr > 24 { return .elevated }
        if rr < 10 { return .low }
        return .normal
    }

    var bloodPressureStatus: VitalStatus {
        guard let sys = latestSystolic else { return .unknown }
        if sys >= 140 { return .critical }
        if sys >= 130 { return .elevated }
        if sys < 90 { return .low }
        return .normal
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
    }

    // MARK: - Data Availability

    var hasAnyLiveData: Bool {
        currentHeartRate != nil || currentBloodOxygen != nil || currentRespiratoryRate != nil
    }

    var hasAnyActivityData: Bool {
        todaySteps > 0 || todayActiveCalories > 0 || todayExerciseMinutes > 0
    }

    // MARK: - Activity Ring Progress

    var moveProgress: Double { min(todayActiveCalories / moveGoal, 1.0) }
    var exerciseProgress: Double { min(todayExerciseMinutes / exerciseGoal, 1.0) }
    var standProgress: Double { min(todayStandHours / standGoal, 1.0) }

    // MARK: - Readiness + Today Quick Fetch (for Home tab, no streams)

    /// Lightweight fetch for Home screen — gets readiness data + today's activity without starting live streams
    func fetchHomeData() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        fetchLatestDailyValues()
        fetchTodayCumulativeStats()
        fetchActivityGoals()
        fetchTodayMindfulMinutes()
        fetchLatestWorkout()
    }

    // MARK: - Start / Stop

    func startStreaming() {
        guard !isStreaming, HKHealthStore.isHealthDataAvailable() else { return }
        isStreaming = true

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
        computeReadinessScore()

        // After 2 seconds, fill in any gaps the anchored queries didn't cover
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.fetchFallbackHeartRate()
            self?.fetchFallbackBloodOxygen()
            self?.fetchFallbackRespiratoryRate()
        }

        // Refresh cumulative stats every 30 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.fetchTodayCumulativeStats()
            }
        }
    }

    func stopStreaming() {
        isStreaming = false

        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        if let query = bloodOxygenQuery {
            healthStore.stop(query)
            bloodOxygenQuery = nil
        }
        if let query = respiratoryRateQuery {
            healthStore.stop(query)
            respiratoryRateQuery = nil
        }
        refreshTimer?.invalidate()
        refreshTimer = nil
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

        Task { @MainActor in
            for sample in quantitySamples {
                let value = sample.quantity.doubleValue(for: unit)
                let date = sample.startDate
                recentHeartRates.append((date: date, value: value))
            }

            // Keep only last 30 minutes
            let cutoff = Date().addingTimeInterval(-30 * 60)
            recentHeartRates.removeAll { $0.date < cutoff }

            // Compute session stats
            let values = recentHeartRates.map(\.value)
            heartRateMin30 = values.min()
            heartRateMax30 = values.max()
            heartRateAvg30 = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)

            // Set current to most recent
            if let latest = quantitySamples.max(by: { $0.startDate < $1.startDate }) {
                currentHeartRate = latest.quantity.doubleValue(for: unit)
                heartRateTimestamp = latest.startDate
                lastUpdate = Date()
            }
        }
    }

    // MARK: - Blood Oxygen Stream

    private func startBloodOxygenStream() {
        let spo2Type = HKQuantityType(.oxygenSaturation)
        let unit = HKUnit.percent()

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-6 * 3600),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: spo2Type,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processLatestSample(samples, unit: unit) { val, date in
                self?.currentBloodOxygen = val * 100
                self?.bloodOxygenTimestamp = date
                self?.lastUpdate = Date()
            }
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processLatestSample(samples, unit: unit) { val, date in
                self?.currentBloodOxygen = val * 100
                self?.bloodOxygenTimestamp = date
                self?.lastUpdate = Date()
            }
        }

        healthStore.execute(query)
        bloodOxygenQuery = query
    }

    // MARK: - Respiratory Rate Stream

    private func startRespiratoryRateStream() {
        let respType = HKQuantityType(.respiratoryRate)
        let unit = HKUnit.count().unitDivided(by: .minute())

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-6 * 3600),
            end: nil,
            options: .strictStartDate
        )

        let query = HKAnchoredObjectQuery(
            type: respType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processLatestSample(samples, unit: unit) { val, date in
                self?.currentRespiratoryRate = val
                self?.respiratoryRateTimestamp = date
                self?.lastUpdate = Date()
            }
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processLatestSample(samples, unit: unit) { val, date in
                self?.currentRespiratoryRate = val
                self?.respiratoryRateTimestamp = date
                self?.lastUpdate = Date()
            }
        }

        healthStore.execute(query)
        respiratoryRateQuery = query
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

        fetchTodayStat(.stepCount, unit: .count(), from: startOfDay) { [weak self] value in
            Task { @MainActor in self?.todaySteps = value }
        }
        fetchTodayStat(.activeEnergyBurned, unit: .kilocalorie(), from: startOfDay) { [weak self] value in
            Task { @MainActor in self?.todayActiveCalories = value }
        }
        fetchTodayStat(.appleExerciseTime, unit: .minute(), from: startOfDay) { [weak self] value in
            Task { @MainActor in self?.todayExerciseMinutes = value }
        }
        fetchTodayStat(.appleStandTime, unit: .hour(), from: startOfDay) { [weak self] value in
            Task { @MainActor in self?.todayStandHours = value }
        }
        fetchTodayStat(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), from: startOfDay) { [weak self] value in
            Task { @MainActor in self?.todayDistance = value }
        }
        fetchTodayStat(.flightsClimbed, unit: .count(), from: startOfDay) { [weak self] value in
            Task { @MainActor in self?.todayFlightsClimbed = value }
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
                if move > 0 { self?.moveGoal = move }
                if exercise > 0 { self?.exerciseGoal = exercise }
                if stand > 0 { self?.standGoal = stand }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Latest Daily Values

    func fetchLatestDailyValues() {
        fetchLatestSample(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] value in
            Task { @MainActor in
                self?.latestRestingHeartRate = value
                self?.computeReadinessScore()
            }
        }
        fetchLatestSample(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli)) { [weak self] value in
            Task { @MainActor in
                self?.latestHRV = value
                self?.computeReadinessScore()
            }
        }
    }

    // MARK: - Blood Pressure

    func fetchLatestBloodPressure() {
        fetchLatestSample(.bloodPressureSystolic, unit: .millimeterOfMercury()) { [weak self] value in
            Task { @MainActor in self?.latestSystolic = value }
        }
        fetchLatestSample(.bloodPressureDiastolic, unit: .millimeterOfMercury()) { [weak self] value in
            Task { @MainActor in self?.latestDiastolic = value }
        }
    }

    // MARK: - Body Temperature

    func fetchLatestBodyTemperature() {
        let type = HKQuantityType(.bodyTemperature)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, results, _ in
            if let sample = results?.first as? HKQuantitySample {
                let value = sample.quantity.doubleValue(for: .degreeCelsius())
                let date = sample.startDate
                Task { @MainActor in
                    self?.latestBodyTemp = value
                    self?.bodyTempTimestamp = date
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
                self?.todayHeartRateMin = minVal
                self?.todayHeartRateMax = maxVal
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Latest Workout

    func fetchLatestWorkout() {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: nil,
            limit: 1,
            sortDescriptors: [sort]
        ) { [weak self] _, results, _ in
            if let workout = results?.first as? HKWorkout {
                let typeName = workout.workoutActivityType.displayName
                let duration = workout.duration / 60.0
                let caloriesType = HKQuantityType(.activeEnergyBurned)
                let calories = workout.statistics(for: caloriesType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
                let date = workout.startDate
                Task { @MainActor in
                    self?.lastWorkoutType = typeName
                    self?.lastWorkoutDuration = duration
                    self?.lastWorkoutCalories = calories
                    self?.lastWorkoutTimestamp = date
                }
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Readiness Score

    func computeReadinessScore() {
        // Simple readiness: based on HRV (higher=better) and RHR (lower=better)
        // Score 0-100
        guard let hrv = latestHRV, let rhr = latestRestingHeartRate else {
            readinessScore = nil
            return
        }

        // HRV component: 20ms = poor (0), 60ms+ = excellent (50 pts)
        let hrvScore = min(max((hrv - 20) / 40.0 * 50, 0), 50)

        // RHR component: 80bpm = poor (0), 50bpm = excellent (50 pts)
        let rhrScore = min(max((80 - rhr) / 30.0 * 50, 0), 50)

        readinessScore = Int(hrvScore + rhrScore)
    }

    // MARK: - Stress Level (derived from HRV + RHR)

    /// Stress level 0–100 (inverse of readiness — low HRV + high RHR = high stress)
    var stressLevel: Int? {
        guard let hrv = latestHRV, let rhr = latestRestingHeartRate else { return nil }
        // High HRV = low stress, Low RHR = low stress
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
                self?.todayMindfulMinutes = totalSeconds / 60.0
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Fallback Latest-Sample Fetches

    /// Fetches the most recent sample with no time window, returning both value and date
    private func fetchLatestSampleWithDate(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double, Date) -> Void) {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
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
        guard currentHeartRate == nil else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        fetchLatestSampleWithDate(.heartRate, unit: unit) { [weak self] value, date in
            Task { @MainActor in
                guard self?.currentHeartRate == nil else { return }
                self?.currentHeartRate = value
                self?.heartRateTimestamp = date
                self?.lastUpdate = Date()
            }
        }
    }

    private func fetchFallbackBloodOxygen() {
        guard currentBloodOxygen == nil else { return }
        fetchLatestSampleWithDate(.oxygenSaturation, unit: .percent()) { [weak self] value, date in
            Task { @MainActor in
                guard self?.currentBloodOxygen == nil else { return }
                self?.currentBloodOxygen = value * 100
                self?.bloodOxygenTimestamp = date
                self?.lastUpdate = Date()
            }
        }
    }

    private func fetchFallbackRespiratoryRate() {
        guard currentRespiratoryRate == nil else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        fetchLatestSampleWithDate(.respiratoryRate, unit: unit) { [weak self] value, date in
            Task { @MainActor in
                guard self?.currentRespiratoryRate == nil else { return }
                self?.currentRespiratoryRate = value
                self?.respiratoryRateTimestamp = date
                self?.lastUpdate = Date()
            }
        }
    }

    // MARK: - Query Helpers

    private func fetchLatestSample(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, completion: @escaping (Double) -> Void) {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
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
