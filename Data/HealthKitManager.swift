import Foundation
import HealthKit
import Observation

/// Manages all HealthKit interactions: authorization, queries, and background delivery
@Observable
final class HealthKitManager {
    let healthStore = HKHealthStore()

    var isAuthorized = false
    var isLoading = false
    var timeSeries: [HealthMetric: MetricTimeSeries] = [:]
    var lastRefresh: Date?
    var error: String?

    /// Check if HealthKit is available on this device
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request authorization for all tracked metrics
    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            error = "HealthKit is not available on this device"
            return
        }

        let readTypes = HealthKitMetricRegistry.allSampleTypes

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
        } catch {
            self.error = "Authorization failed: \(error.localizedDescription)"
        }
    }

    /// Fetch all metrics for the given number of days (legacy, in-memory only)
    func fetchAllMetrics(days: Int = 90) async {
        isLoading = true
        defer { isLoading = false }

        let endDate = Date()
        let startDate = endDate.daysAgo(days)

        await withTaskGroup(of: (HealthMetric, MetricTimeSeries?).self) { group in
            for metric in HealthMetric.allCases {
                group.addTask { [self] in
                    let series = await self.fetchMetric(metric, from: startDate, to: endDate)
                    return (metric, series)
                }
            }

            for await (metric, series) in group {
                if let series {
                    timeSeries[metric] = series
                }
            }
        }

        lastRefresh = Date()
    }

    /// Load stored data from SwiftData, then incrementally sync new data from HealthKit.
    /// - First launch: fetches ALL available HealthKit history (up to 10 years)
    /// - Subsequent launches: fetches only data since last sync (with 1-day overlap)
    @MainActor
    func loadAndSync(store: HealthDataStore) async {
        isLoading = true
        let syncStartTime = Date()

        // Phase 1: Instantly load stored data so the UI has something to show
        timeSeries = store.loadAllTimeSeries()

        // Phase 2: Gather sync dates before entering the task group (ModelContext is not thread-safe)
        let syncDates = store.allSyncDates()
        let isFirstSync = syncDates.isEmpty
        let endDate = Date()

        // Phase 3: Fetch new data from HealthKit in parallel
        var newData: [(HealthMetric, MetricTimeSeries)] = []

        await withTaskGroup(of: (HealthMetric, MetricTimeSeries?).self) { group in
            for metric in HealthMetric.allCases {
                let lastSync = syncDates[metric]
                group.addTask { [self] in
                    let startDate: Date
                    if let lastSync {
                        // Incremental: fetch from last sync minus 1 day for overlap safety
                        startDate = Calendar.current.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync
                    } else {
                        // First sync: fetch all available HealthKit history
                        startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate) ?? endDate
                    }
                    let series = await self.fetchMetric(metric, from: startDate, to: endDate)
                    return (metric, series)
                }
            }

            for await (metric, series) in group {
                if let series, !series.samples.isEmpty {
                    newData.append((metric, series))
                }
            }
        }

        // Phase 4: Save new data to SwiftData (sequential, main actor)
        for (metric, series) in newData {
            store.saveSamples(series.samples, for: metric)
        }

        // Phase 5: Reload complete stored data (includes both old + new)
        timeSeries = store.loadAllTimeSeries()

        lastRefresh = Date()
        isLoading = false

        // Track sync completion
        let totalNewSamples = newData.reduce(0) { $0 + $1.1.samples.count }
        let syncDuration = Int(Date().timeIntervalSince(syncStartTime))
        AppAnalytics.shared.trackDataSync(
            metricsCount: newData.count,
            newSamplesCount: totalNewSamples,
            durationSec: syncDuration,
            isFirstSync: isFirstSync
        )

        // Activation: first data load + time-to-first-value
        if !newData.isEmpty {
            AppAnalytics.shared.trackActivationMilestone(.firstDataLoad)
            AppAnalytics.shared.trackTimeToFirstValue()
        }
    }

    /// Fetch a single metric's time series
    func fetchMetric(_ metric: HealthMetric, from startDate: Date, to endDate: Date) async -> MetricTimeSeries? {
        let config = HealthKitMetricRegistry.config(for: metric)

        switch config.strategy {
        case .statisticsDaily:
            return await fetchStatisticsDaily(metric: metric, from: startDate, to: endDate)
        case .quantitySample:
            return await fetchQuantitySamples(metric: metric, from: startDate, to: endDate)
        case .categorySample:
            if metric == .mindfulMinutes {
                return await fetchMindfulSamples(from: startDate, to: endDate)
            }
            return await fetchSleepSamples(metric: metric, from: startDate, to: endDate)
        case .workoutQuery:
            return await fetchWorkouts(metric: metric, from: startDate, to: endDate)
        }
    }

    // MARK: - Private Query Methods

    private func fetchStatisticsDaily(metric: HealthMetric, from startDate: Date, to endDate: Date) async -> MetricTimeSeries? {
        let config = HealthKitMetricRegistry.config(for: metric)
        guard let quantityType = config.quantityType else { return nil }

        return await withCheckedContinuation { continuation in
            var interval = DateComponents()
            interval.day = 1

            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: config.statisticsOption,
                anchorDate: startDate.startOfDay,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                guard let results, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                var samples: [MetricSample] = []
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let value: Double?
                    if config.statisticsOption == .cumulativeSum {
                        value = statistics.sumQuantity()?.doubleValue(for: config.unit)
                    } else {
                        value = statistics.averageQuantity()?.doubleValue(for: config.unit)
                    }
                    if let value, value > 0 {
                        samples.append(MetricSample(date: statistics.startDate, value: value))
                    }
                }

                let series = MetricTimeSeries(metric: metric, samples: samples)
                continuation.resume(returning: series)
            }

            healthStore.execute(query)
        }
    }

    private func fetchQuantitySamples(metric: HealthMetric, from startDate: Date, to endDate: Date) async -> MetricTimeSeries? {
        let config = HealthKitMetricRegistry.config(for: metric)
        guard let sampleType = config.sampleType as? HKQuantityType else { return nil }

        return await withCheckedContinuation { continuation in
            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                guard let results = results as? [HKQuantitySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Aggregate to daily averages
                var dailyValues: [Date: [Double]] = [:]
                for sample in results {
                    let day = sample.startDate.startOfDay
                    let value = sample.quantity.doubleValue(for: config.unit)
                    dailyValues[day, default: []].append(value)
                }

                let samples = dailyValues.map { (day, values) in
                    MetricSample(date: day, value: values.mean)
                }.sorted { $0.date < $1.date }

                let series = MetricTimeSeries(metric: metric, samples: samples)
                continuation.resume(returning: series)
            }

            healthStore.execute(query)
        }
    }

    private func fetchSleepSamples(metric: HealthMetric, from startDate: Date, to endDate: Date) async -> MetricTimeSeries? {
        return await withCheckedContinuation { continuation in
            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                guard let results = results as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Group by night and sum durations per sleep stage
                var dailyDurations: [Date: Double] = [:]

                for sample in results {
                    let day = sample.startDate.startOfDay
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0 // hours

                    let matchesStage: Bool
                    switch metric {
                    case .sleepDuration:
                        matchesStage = sample.value != HKCategoryValueSleepAnalysis.awake.rawValue
                    case .sleepREM:
                        matchesStage = sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                    case .sleepDeep:
                        matchesStage = sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    case .sleepCore:
                        matchesStage = sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    case .sleepAwake:
                        matchesStage = sample.value == HKCategoryValueSleepAnalysis.awake.rawValue
                    default:
                        matchesStage = false
                    }

                    if matchesStage {
                        dailyDurations[day, default: 0] += duration
                    }
                }

                let samples = dailyDurations.map { MetricSample(date: $0.key, value: $0.value) }
                    .sorted { $0.date < $1.date }

                let series = MetricTimeSeries(metric: metric, samples: samples)
                continuation.resume(returning: series)
            }

            healthStore.execute(query)
        }
    }

    private func fetchWorkouts(metric: HealthMetric, from startDate: Date, to endDate: Date) async -> MetricTimeSeries? {
        return await withCheckedContinuation { continuation in
            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                guard let workouts = results as? [HKWorkout], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Group by day
                var dailyValues: [Date: (count: Int, duration: Double)] = [:]
                for workout in workouts {
                    let day = workout.startDate.startOfDay
                    var entry = dailyValues[day] ?? (count: 0, duration: 0)
                    entry.count += 1
                    entry.duration += workout.duration / 60.0 // minutes
                    dailyValues[day] = entry
                }

                let samples = dailyValues.map { (day, values) in
                    let value = metric == .workoutCount ? Double(values.count) : values.duration
                    return MetricSample(date: day, value: value)
                }.sorted { $0.date < $1.date }

                let series = MetricTimeSeries(metric: metric, samples: samples)
                continuation.resume(returning: series)
            }

            healthStore.execute(query)
        }
    }

    private func fetchMindfulSamples(from startDate: Date, to endDate: Date) async -> MetricTimeSeries? {
        return await withCheckedContinuation { continuation in
            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: HKCategoryType(.mindfulSession),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                guard let results = results as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Group by day and sum session durations in minutes
                var dailyMinutes: [Date: Double] = [:]
                for sample in results {
                    let day = sample.startDate.startOfDay
                    let minutes = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
                    dailyMinutes[day, default: 0] += minutes
                }

                let samples = dailyMinutes.map { MetricSample(date: $0.key, value: $0.value) }
                    .sorted { $0.date < $1.date }

                let series = MetricTimeSeries(metric: .mindfulMinutes, samples: samples)
                continuation.resume(returning: series)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Background Delivery

    /// Enable background delivery for all health-critical metrics
    func enableBackgroundDelivery() {
        let criticalMetrics: [HealthMetric] = [
            // Heart — most critical for spike/drop detection
            .restingHeartRate, .heartRate, .heartRateVariability,
            .heartRateRecovery, .bloodOxygen,
            // Blood pressure
            .bloodPressureSystolic, .bloodPressureDiastolic,
            // Respiratory
            .respiratoryRate, .vo2Max,
            // Body temperature
            .bodyTemperature,
            // Atrial fibrillation
            .atrialFibrillationBurden
        ]

        for metric in criticalMetrics {
            let config = HealthKitMetricRegistry.config(for: metric)
            guard let sampleType = config.sampleType else { continue }

            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { success, error in
                if let error {
                    print("Background delivery failed for \(metric): \(error.localizedDescription)")
                }
            }
        }
    }
}
