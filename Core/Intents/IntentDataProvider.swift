import Foundation
import HealthKit

/// Shared data provider for all App Intents. fetches health data without requiring
/// the full app's ViewModel/AnalysisEngine stack to be running.
/// All methods are static and self-contained so intents can run from background contexts.
enum IntentDataProvider {

    // MARK: - Health Score

    /// Reads the cached health score (written by DashboardViewModel after each analysis)
    /// and fetches live readiness from HealthKit. Returns nil only if the app has never run analysis.
    static func fetchCurrentHealthScore() async -> (score: Int, grade: String, summary: String, readinessScore: Int?, readinessLabel: String?)? {
        let cacheStore = IntentCacheStore()
        guard let snapshot = cacheStore.loadHealthSummary() else { return nil }

        let summary = "\(scoreLabel(for: snapshot.score)). \(snapshot.summary)".trimmingCharacters(in: .whitespaces)

        // Fetch live readiness in parallel
        let readiness = await fetchReadiness()

        return (
            snapshot.score,
            snapshot.grade,
            summary,
            readiness?.readinessScore,
            readiness.map { readinessLabel(for: $0.readinessScore) }
        )
    }

    private static func readinessLabel(for score: Int) -> String {
        switch score {
        case 80...100: "Great"
        case 60..<80: "Good"
        case 40..<60: "Fair"
        default: "Low"
        }
    }

    // MARK: - Sleep Summary

    /// Fetches last night's sleep data directly from HealthKit.
    /// Returns (totalHours, deepHours, remHours, qualityLabel) or nil.
    static func fetchLastNightSleep() async -> (totalHours: Double, deepHours: Double, remHours: Double, qualityLabel: String)? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let healthStore = HKHealthStore()

        let calendar = Date.cal
        let now = Date()
        // Look back from 3 PM yesterday to 3 PM today to capture a full sleep window
        guard let windowStart = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: -1, to: now)!),
              let windowEnd = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now) else {
            return nil
        }

        let sleepType = HKCategoryType(.sleepAnalysis)
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        var total: TimeInterval = 0
        var deep: TimeInterval = 0
        var rem: TimeInterval = 0

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            guard let stage = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { continue }
            switch stage {
            case .asleepDeep:
                deep += duration
                total += duration
            case .asleepREM:
                rem += duration
                total += duration
            case .asleepCore:
                total += duration
            case .asleepUnspecified, .inBed:
                total += duration
            case .awake:
                break // Don't count awake time
            @unknown default:
                break
            }
        }

        guard total > 0 else { return nil }

        let totalHours = total / 3600
        let deepHours = deep / 3600
        let remHours = rem / 3600
        let qualityLabel = sleepQualityLabel(hours: totalHours)

        return (totalHours, deepHours, remHours, qualityLabel)
    }

    // MARK: - Readiness

    /// Fetches readiness data from HealthKit using the shared readiness scorer.
    /// Returns (readinessScore, stressLevel, stressLabel) or nil.
    static func fetchReadiness() async -> (readinessScore: Int, stressLevel: Int, stressLabel: String)? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let healthStore = HKHealthStore()

        let now = Date()
        let oneDayAgo = Date.cal.date(byAdding: .day, value: -1, to: now)!

        async let rhrResult = fetchLatestQuantity(
            store: healthStore,
            identifier: .restingHeartRate,
            unit: HKUnit(from: "count/min"),
            from: oneDayAgo
        )
        async let hrvResult = fetchLatestQuantity(
            store: healthStore,
            identifier: .heartRateVariabilitySDNN,
            unit: HKUnit.secondUnit(with: .milli),
            from: oneDayAgo
        )

        guard let rhr = await rhrResult, let hrv = await hrvResult else { return nil }

        let readinessInput = ReadinessScorer.Input(
            now: now,
            hrv: hrv,
            hrvTimestamp: now,
            restingHeartRate: rhr,
            restingHeartRateTimestamp: now
        )
        guard let readiness = ReadinessScorer.assess(readinessInput) else { return nil }

        let stress = ReadinessScorer.stressLevel(hrv: hrv, restingHeartRate: rhr) ?? 0
        let stressLabel = ReadinessScorer.stressLabel(for: stress)

        return (readiness.score, stress, stressLabel)
    }

    // MARK: - Water Logging

    /// Writes water intake to HealthKit. Amount is in liters.
    static func logWater(liters: Double) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(), liters > 0 else { return false }
        let healthStore = HKHealthStore()
        let milliliters = liters * 1000
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: milliliters)
        let sample = HKQuantitySample(
            type: HKQuantityType(.dietaryWater),
            quantity: quantity,
            start: Date(),
            end: Date()
        )
        do {
            try await healthStore.save(sample)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Workout Logging

    /// Saves a quick workout to HealthKit.
    static func logWorkout(type: HKWorkoutActivityType, durationMinutes: Double) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(), durationMinutes > 0 else { return false }
        let healthStore = HKHealthStore()
        let end = Date()
        let start = end.addingTimeInterval(-durationMinutes * 60)

        let config = HKWorkoutConfiguration()
        config.activityType = type

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            try await builder.finishWorkout()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private static func fetchLatestQuantity(
        store: HKHealthStore,
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from startDate: Date
    ) async -> Double? {
        let quantityType = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, results, _ in
                guard let sample = results?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private static func scoreLabel(for score: Int) -> String {
        switch score {
        case 90...100: return "Your health is excellent"
        case 80..<90: return "Your health looks great"
        case 70..<80: return "Your health is good"
        case 60..<70: return "Your health needs some attention"
        default: return "Your health needs improvement"
        }
    }

    private static func sleepQualityLabel(hours: Double) -> String {
        if hours >= 7.5 { return "Great" }
        if hours >= 6.5 { return "Good" }
        if hours >= 5.5 { return "Fair" }
        return "Poor"
    }
}
