import Foundation
import HealthKit
import SwiftData

/// Shared data provider for all App Intents — fetches health data without requiring
/// the full app's ViewModel/AnalysisEngine stack to be running.
/// All methods are static and self-contained so intents can run from background contexts.
enum IntentDataProvider {

    // MARK: - Health Score

    /// Computes the current overall health score by loading stored data and running core analysis.
    /// Returns (score, grade, summary) or nil if no data is available.
    static func fetchCurrentHealthScore() async -> (score: Int, grade: String, summary: String)? {
        let store = createHealthDataStore()
        guard let store else { return nil }

        let timeSeries = store.loadAllTimeSeries()
        guard !timeSeries.isEmpty else { return nil }

        let engine = AnalysisEngine()
        engine.runCoreAnalysis(timeSeries: timeSeries)

        let score = engine.overallScore.score
        let grade = engine.overallScore.grade

        // Build a brief summary from category scores
        let topCategories = engine.categoryScores
            .sorted { $0.score < $1.score }
            .prefix(2)
            .compactMap { s -> String? in
                guard let cat = s.category else { return nil }
                return "\(cat.shortName) \(s.score)"
            }

        let summary: String
        if topCategories.isEmpty {
            summary = scoreLabel(for: score)
        } else {
            summary = "\(scoreLabel(for: score)). Areas to watch: \(topCategories.joined(separator: ", "))."
        }

        return (score, grade, summary)
    }

    // MARK: - Sleep Summary

    /// Fetches last night's sleep data directly from HealthKit.
    /// Returns (totalHours, deepHours, remHours, qualityLabel) or nil.
    static func fetchLastNightSleep() async -> (totalHours: Double, deepHours: Double, remHours: Double, qualityLabel: String)? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let healthStore = HKHealthStore()

        let calendar = Calendar.current
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

    /// Fetches readiness data from HealthKit (RHR + HRV based).
    /// Returns (readinessScore, stressLevel, stressLabel) or nil.
    static func fetchReadiness() async -> (readinessScore: Int, stressLevel: Int, stressLabel: String)? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let healthStore = HKHealthStore()

        let now = Date()
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now)!

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

        // Readiness: same formula as LiveViewModel.computeReadinessScore
        let hrvScore = min(max((hrv - 20) / 40.0 * 50, 0), 50)
        let rhrScore = min(max((80 - rhr) / 30.0 * 50, 0), 50)
        let readiness = Int(hrvScore + rhrScore)

        // Stress: same formula as RecoveryData.stressLevel
        let hrvStress = min(max((60 - hrv) / 40.0 * 50, 0), 50)
        let rhrStress = min(max((rhr - 50) / 30.0 * 50, 0), 50)
        let stress = Int(hrvStress + rhrStress)

        let stressLabel: String
        switch stress {
        case 0..<20: stressLabel = "Relaxed"
        case 20..<40: stressLabel = "Low"
        case 40..<60: stressLabel = "Moderate"
        case 60..<80: stressLabel = "High"
        default: stressLabel = "Very High"
        }

        return (readiness, stress, stressLabel)
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

    // MARK: - Trends Summary

    /// Returns a brief trends summary from stored analysis data.
    static func fetchTrendsSummary() async -> String? {
        let store = createHealthDataStore()
        guard let store else { return nil }

        let timeSeries = store.loadAllTimeSeries()
        guard !timeSeries.isEmpty else { return nil }

        let engine = AnalysisEngine()
        engine.runCoreAnalysis(timeSeries: timeSeries)

        let improvingCount = engine.trends.values.filter { $0.direction == .improving }.count
        let decliningCount = engine.trends.values.filter { $0.direction == .declining }.count
        let stableCount = engine.trends.values.filter { $0.direction == .stable }.count

        return "\(improvingCount) improving, \(stableCount) stable, \(decliningCount) declining"
    }

    // MARK: - Helpers

    private static func createHealthDataStore() -> HealthDataStore? {
        let storeDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("HealthData", isDirectory: true)
        let dbURL = storeDir.appendingPathComponent("health.store")

        guard FileManager.default.fileExists(atPath: dbURL.path) else { return nil }

        // Must match the main app's schema exactly
        let allModels: [any PersistentModel.Type] = [
            StoredDailySample.self, StoredSyncMetadata.self,
            StoredAnalysisSnapshot.self, StoredMLModelState.self,
            StoredRecommendation.self, StoredNotificationEvent.self,
            StoredAdherenceRecord.self, StoredECGFeatures.self
        ]

        do {
            let config = ModelConfiguration(url: dbURL)
            let container = try ModelContainer(for: Schema(allModels), configurations: [config])
            return HealthDataStore(modelContainer: container)
        } catch {
            return nil
        }
    }

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
