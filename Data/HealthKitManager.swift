import Foundation
import HealthKit
import Observation

/// Manages all HealthKit interactions: authorization, queries, and background delivery
@Observable
final class HealthKitManager {
    let healthStore = HKHealthStore()

    struct SyncProgress {
        enum Phase: String {
            case preparing
            case fetching
            case saving
            case finalizing
            case completed

            var title: String {
                switch self {
                case .preparing: return "Preparing"
                case .fetching: return "Scanning Health Data"
                case .saving: return "Saving Data"
                case .finalizing: return "Finalizing"
                case .completed: return "Sync Complete"
                }
            }
        }

        var phase: Phase
        var startedAt: Date
        var metricsCompleted: Int
        var totalMetrics: Int
        var metricsWithSamples: Int
        var samplesDiscovered: Int
        var oldestSampleDate: Date?
        var latestMetric: HealthMetric?
    }

    var isAuthorized = false
    var isLoading = false
    var timeSeries: [HealthMetric: MetricTimeSeries] = [:]
    var lastRefresh: Date?
    var error: String?
    var syncProgress: SyncProgress?

    /// Result of a loadAndSync call — tells callers what changed
    struct SyncResult {
        let metricsWithNewData: Set<HealthMetric>
        let totalNewSamples: Int
        let isFirstSync: Bool

        var hasNewData: Bool { !metricsWithNewData.isEmpty }
    }

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

        let writeTypes: Set<HKSampleType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.dietaryWater),
            HKCategoryType(.mindfulSession)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
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
    /// - First launch: fetches HealthKit history (up to 5 years)
    /// - Subsequent launches: fetches only data since last sync (with 1-day overlap)
    /// - Returns a `SyncResult` indicating which metrics had new data
    @MainActor
    @discardableResult
    func loadAndSync(store: HealthDataStore) async -> SyncResult {
        let syncStartTime = Date()
        isLoading = true
        syncProgress = SyncProgress(
            phase: .preparing,
            startedAt: syncStartTime,
            metricsCompleted: 0,
            totalMetrics: HealthMetric.allCases.count,
            metricsWithSamples: 0,
            samplesDiscovered: 0,
            oldestSampleDate: nil,
            latestMetric: nil
        )

        // Phase 1: Instantly load stored data so the UI has something to show
        // Skip if we already have data (e.g. pull-to-refresh) to avoid redundant @Observable mutation
        if timeSeries.isEmpty {
            timeSeries = store.loadAllTimeSeries()
        }

        // Phase 2: Gather sync dates before entering the task group (ModelContext is not thread-safe)
        let syncDates = store.allSyncDates()
        let isFirstSync = syncDates.isEmpty
        let endDate = Date()
        syncProgress?.phase = .fetching

        // Phase 3: Fetch new data from HealthKit in parallel
        var newData: [(HealthMetric, MetricTimeSeries)] = []
        var fetchedMetrics = Set<HealthMetric>()

        await withTaskGroup(of: (HealthMetric, MetricTimeSeries?).self) { group in
            for metric in HealthMetric.allCases {
                let lastSync = syncDates[metric]
                group.addTask { [self] in
                    let startDate: Date
                    if let lastSync {
                        // Incremental: fetch from last sync minus 1 day for overlap safety
                        startDate = Calendar.current.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync
                    } else {
                        // First sync: fetch up to 5 years of HealthKit history
                        startDate = Calendar.current.date(byAdding: .year, value: -5, to: endDate) ?? endDate
                    }
                    let series = await self.fetchMetric(metric, from: startDate, to: endDate)
                    return (metric, series)
                }
            }

            for await (metric, series) in group {
                guard let series else { continue }
                fetchedMetrics.insert(metric)
                if !series.samples.isEmpty {
                    newData.append((metric, series))
                }
                syncProgress?.metricsCompleted += 1
                syncProgress?.latestMetric = metric
                if !series.samples.isEmpty {
                    syncProgress?.metricsWithSamples += 1
                    syncProgress?.samplesDiscovered += series.samples.count
                    if let seriesOldest = series.samples.first?.date {
                        if let existingOldest = syncProgress?.oldestSampleDate {
                            syncProgress?.oldestSampleDate = min(existingOldest, seriesOldest)
                        } else {
                            syncProgress?.oldestSampleDate = seriesOldest
                        }
                    }
                }
            }
        }

        // Phase 4: Save new data to SwiftData (sequential, main actor)
        syncProgress?.phase = .saving
        for (metric, series) in newData {
            store.saveSamples(series.samples, for: metric)
        }

        // Metrics that fetched successfully but had no new samples should still advance sync metadata.
        let metricsWithNewSamples = Set(newData.map { $0.0 })
        for metric in fetchedMetrics.subtracting(metricsWithNewSamples) {
            store.markSyncCompleted(for: metric, at: endDate)
        }

        // Phase 5: Reload complete stored data (includes both old + new)
        syncProgress?.phase = .finalizing
        let reloaded = store.loadAllTimeSeries()
        if reloaded.isEmpty && !newData.isEmpty {
            // SwiftData failed silently — use the fetched HealthKit data directly
            var directTimeSeries: [HealthMetric: MetricTimeSeries] = [:]
            for (metric, series) in newData {
                directTimeSeries[metric] = series
            }
            timeSeries = directTimeSeries
        } else {
            timeSeries = reloaded
        }

        lastRefresh = Date()
        isLoading = false
        syncProgress?.phase = .completed

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

        return SyncResult(
            metricsWithNewData: metricsWithNewSamples,
            totalNewSamples: totalNewSamples,
            isFirstSync: isFirstSync
        )
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
                let asleepStageValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]

                for sample in results {
                    // Attribute each sleep segment to the wake-up day to avoid overnight splits.
                    let day = sample.endDate.startOfDay
                    let duration = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0 // hours

                    let matchesStage: Bool
                    switch metric {
                    case .sleepDuration:
                        matchesStage = asleepStageValues.contains(sample.value)
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

    // MARK: - Write Support

    /// Metrics the user can log from the app
    static let writableMetrics: Set<HealthMetric> = [.weight, .waterIntake, .mindfulMinutes]

    /// Save a body weight sample to HealthKit
    func saveWeight(_ kg: Double, date: Date = Date()) async throws {
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: quantity,
            start: date,
            end: date
        )
        try await healthStore.save(sample)
    }

    /// Save a water intake sample to HealthKit (input in mL, stored in liters)
    func saveWaterIntake(milliliters: Double, date: Date = Date()) async throws {
        let liters = milliliters / 1000.0
        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let sample = HKQuantitySample(
            type: HKQuantityType(.dietaryWater),
            quantity: quantity,
            start: date,
            end: date
        )
        try await healthStore.save(sample)
    }

    /// Save a mindful session to HealthKit
    func saveMindfulSession(minutes: Double) async throws {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-minutes * 60)
        let sample = HKCategorySample(
            type: HKCategoryType(.mindfulSession),
            value: HKCategoryValue.notApplicable.rawValue,
            start: startDate,
            end: endDate
        )
        try await healthStore.save(sample)
    }

    /// Re-fetch a single metric from HealthKit and update SwiftData + timeSeries
    @MainActor
    func refreshMetric(_ metric: HealthMetric, store: HealthDataStore) async {
        let endDate = Date()
        let startDate = endDate.daysAgo(90)
        guard let series = await fetchMetric(metric, from: startDate, to: endDate) else { return }
        store.saveSamples(series.samples, for: metric)
        let reloaded = store.loadTimeSeries(for: metric)
        if let reloaded {
            timeSeries[metric] = reloaded
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

}
