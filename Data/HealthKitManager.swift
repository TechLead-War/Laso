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

    private struct PersistedSyncSummary {
        let metricsWithChanges: Set<HealthMetric>
        let totalInsertedSamples: Int
        let totalChangedSamples: Int
    }

    /// Raw menstrual flow sample used for cycle-phase analytics.
    struct MenstrualFlowSample: Sendable {
        let startDate: Date
        let endDate: Date
        let flowValueRaw: Int

        var day: Date { startDate.startOfDay }

        var isBleedingDay: Bool {
            if let flow = HKCategoryValueMenstrualFlow(rawValue: flowValueRaw) {
                return flow != .none
            }
            return flowValueRaw != 0
        }
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

        var readTypes = HealthKitMetricRegistry.allSampleTypes
        if let menstrualFlowType = HKObjectType.categoryType(forIdentifier: .menstrualFlow) {
            readTypes.insert(menstrualFlowType)
        }
        readTypes.insert(HKObjectType.electrocardiogramType())

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
            AppAnalytics.shared.trackError(type: "healthkit_authorization", screen: .home, message: error.localizedDescription)
        }
    }

    /// Fetch all metrics for the given number of days (legacy, in-memory only)
    func fetchAllMetrics(days: Int = 365) async {
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
    /// - First launch: fetches HealthKit history (up to 1 year)
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
                        // First sync: fetch up to 1 year of HealthKit history
                        startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate) ?? endDate
                    }
                    let series = await self.fetchMetric(metric, from: startDate, to: endDate)
                    return (metric, series)
                }
            }

            for await (metric, series) in group {
                syncProgress?.metricsCompleted += 1
                syncProgress?.latestMetric = metric
                guard let series else { continue }
                fetchedMetrics.insert(metric)
                if !series.samples.isEmpty {
                    newData.append((metric, series))
                }
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
        let persisted = persistFetchedData(
            newData: newData,
            fetchedMetrics: fetchedMetrics,
            store: store,
            endDate: endDate
        )

        // Phase 5: Finalize in-memory state incrementally
        syncProgress?.phase = .finalizing
        finalizeInMemoryTimeSeries(
            isFirstSync: isFirstSync,
            newData: newData,
            store: store
        )

        lastRefresh = Date()
        isLoading = false
        syncProgress?.phase = .completed

        // Track sync completion
        let totalNewSamples = persisted.totalInsertedSamples
        let changedMetricsCount = persisted.metricsWithChanges.count
        let syncDuration = Int(Date().timeIntervalSince(syncStartTime))
        AppAnalytics.shared.trackDataSync(
            metricsCount: changedMetricsCount,
            newSamplesCount: totalNewSamples,
            durationSec: syncDuration,
            isFirstSync: isFirstSync
        )
        AppAnalytics.shared.trackSyncPerformance(
            durationMs: Int(Date().timeIntervalSince(syncStartTime) * 1000),
            metricsCount: changedMetricsCount,
            samplesLoaded: persisted.totalChangedSamples,
            isIncremental: !isFirstSync
        )

        // Activation: first data load + time-to-first-value
        if !persisted.metricsWithChanges.isEmpty {
            AppAnalytics.shared.trackActivationMilestone(.firstDataLoad)
            AppAnalytics.shared.trackTimeToFirstValue()
        }

        return SyncResult(
            metricsWithNewData: persisted.metricsWithChanges,
            totalNewSamples: totalNewSamples,
            isFirstSync: isFirstSync
        )
    }

    /// Persist fetched series and return a summary of actual changes written to storage.
    private func persistFetchedData(
        newData: [(HealthMetric, MetricTimeSeries)],
        fetchedMetrics: Set<HealthMetric>,
        store: HealthDataStore,
        endDate: Date
    ) -> PersistedSyncSummary {
        var metricsWithChanges = Set<HealthMetric>()
        var totalInsertedSamples = 0
        var totalChangedSamples = 0

        for (metric, series) in newData {
            let saveResult = store.saveSamples(series.samples, for: metric)
            if saveResult.hasChanges {
                metricsWithChanges.insert(metric)
            }
            totalInsertedSamples += saveResult.insertedCount
            totalChangedSamples += saveResult.changedSampleCount
        }

        // Metrics that fetched successfully but had no samples still need sync advancement.
        let metricsWithFetchedSamples = Set(newData.map { $0.0 })
        for metric in fetchedMetrics.subtracting(metricsWithFetchedSamples) {
            store.markSyncCompleted(for: metric, at: endDate)
        }

        return PersistedSyncSummary(
            metricsWithChanges: metricsWithChanges,
            totalInsertedSamples: totalInsertedSamples,
            totalChangedSamples: totalChangedSamples
        )
    }

    /// Apply persisted sync results to in-memory time series without full-store reloads.
    private func finalizeInMemoryTimeSeries(
        isFirstSync: Bool,
        newData: [(HealthMetric, MetricTimeSeries)],
        store: HealthDataStore
    ) {
        if isFirstSync {
            // First sync fetched full history for each populated metric — avoid full reload.
            if !newData.isEmpty {
                var initialSeries = timeSeries
                for (metric, series) in newData {
                    initialSeries[metric] = series
                }
                timeSeries = initialSeries
            } else if timeSeries.isEmpty {
                timeSeries = store.loadAllTimeSeries()
            }
            return
        }

        // Incremental sync: refresh only touched metrics from persistence.
        for (metric, series) in newData {
            if let persisted = store.loadTimeSeries(for: metric) {
                timeSeries[metric] = persisted
            } else {
                // Fallback if persistence read fails: merge overlap data directly in memory.
                timeSeries[metric] = mergeSeries(metric: metric, existing: timeSeries[metric], incoming: series.samples)
            }
        }
        if timeSeries.isEmpty {
            timeSeries = store.loadAllTimeSeries()
        }
    }

    /// Merge incremental daily samples into an in-memory series with day-level deduplication.
    private func mergeSeries(
        metric: HealthMetric,
        existing: MetricTimeSeries?,
        incoming: [MetricSample]
    ) -> MetricTimeSeries {
        guard let existing else {
            return MetricTimeSeries(metric: metric, samples: incoming)
        }
        guard !incoming.isEmpty else { return existing }

        return MetricTimeSeries(
            metric: metric,
            samples: MetricSample.mergedByUTCDay(existing: existing.samples, incoming: incoming)
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

    /// Fetch menstrual flow category samples for cycle-phase analysis.
    /// Returns empty when data is unavailable or permission is denied.
    func fetchMenstrualFlowSamples(days: Int = 365) async -> [MenstrualFlowSample] {
        guard isAuthorized,
              let menstrualType = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else {
            return []
        }

        let endDate = Date()
        let startDate = endDate.daysAgo(days)

        return await withCheckedContinuation { continuation in
            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: menstrualType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                guard let results = results as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                let samples = results.map { sample in
                    MenstrualFlowSample(
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        flowValueRaw: sample.value
                    )
                }
                continuation.resume(returning: samples)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Hourly Data (Circadian Analysis)

    /// Fetch hourly-binned samples for circadian rhythm analysis.
    /// Returns 24 arrays (one per hour), each containing the daily values for that hour slot.
    func fetchHourlySamples(_ metric: HealthMetric, days: Int = 30) async -> [[Double]]? {
        let config = HealthKitMetricRegistry.config(for: metric)
        guard let quantityType = config.quantityType else { return nil }

        let endDate = Date()
        let startDate = endDate.daysAgo(days)

        return await withCheckedContinuation { continuation in
            var interval = DateComponents()
            interval.hour = 1

            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: config.statisticsOption == .cumulativeSum ? .cumulativeSum : .discreteAverage,
                anchorDate: startDate.startOfDay,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                guard let results, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                // Bin values by hour-of-day (0-23)
                var hourBins: [[Double]] = Array(repeating: [], count: 24)
                let calendar = Calendar.current

                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let value: Double?
                    if config.statisticsOption == .cumulativeSum {
                        value = statistics.sumQuantity()?.doubleValue(for: config.unit)
                    } else {
                        value = statistics.averageQuantity()?.doubleValue(for: config.unit)
                    }
                    if let value, value > 0 {
                        let hour = calendar.component(.hour, from: statistics.startDate)
                        guard hour >= 0, hour < 24 else { return }
                        hourBins[hour].append(value)
                    }
                }

                // Only return if we have meaningful data
                let hoursWithData = hourBins.filter { !$0.isEmpty }.count
                guard hoursWithData >= 12 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: hourBins)
            }

            healthStore.execute(query)
        }
    }

    /// Fetch menstrual cycle phase data for cycle-aware circadian analysis.
    struct CyclePhaseDay {
        let date: Date
        let phase: CyclePhase
    }

    enum CyclePhase: String, Codable {
        case menstrual
        case follicular
        case ovulatory
        case luteal
    }

    func fetchMenstrualCycleData(days: Int = 365) async -> [CyclePhaseDay]? {
        let flowSamples = await fetchMenstrualFlowSamples(days: days)
        guard flowSamples.count >= 2 else { return nil }

        // Find bleeding periods (menstrual phase markers)
        let bleedingDays = flowSamples.filter { $0.isBleedingDay }.map { $0.day }
        guard bleedingDays.count >= 2 else { return nil }

        // Group bleeding days into cycles (gap > 20 days = new cycle)
        var cycles: [[Date]] = []
        var currentCycle: [Date] = []
        for day in bleedingDays.sorted() {
            if let last = currentCycle.last,
               Calendar.current.dateComponents([.day], from: last, to: day).day ?? 0 > 20 {
                if !currentCycle.isEmpty { cycles.append(currentCycle) }
                currentCycle = [day]
            } else {
                currentCycle.append(day)
            }
        }
        if !currentCycle.isEmpty { cycles.append(currentCycle) }
        guard cycles.count >= 2 else { return nil }

        // Estimate cycle length from consecutive cycle starts
        var phaseDays: [CyclePhaseDay] = []
        let calendar = Calendar.current

        for i in 0..<(cycles.count - 1) {
            guard let cycleStart = cycles[i].first,
                  let nextCycleStart = cycles[i + 1].first else { continue }
            let cycleLength = calendar.dateComponents([.day], from: cycleStart, to: nextCycleStart).day ?? 28

            // Assign phases: menstrual (days 1-5), follicular (6-13), ovulatory (14-16), luteal (17-end)
            for dayOffset in 0..<cycleLength {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: cycleStart) else { continue }
                let phase: CyclePhase
                switch dayOffset {
                case 0..<5: phase = .menstrual
                case 5..<13: phase = .follicular
                case 13..<16: phase = .ovulatory
                default: phase = .luteal
                }
                phaseDays.append(CyclePhaseDay(date: date, phase: phase))
            }
        }

        return phaseDays.isEmpty ? nil : phaseDays
    }

    // MARK: - Raw Intra-Day Heart Rate (for Strain Zone Classification)

    /// Fetch today's individual heart rate samples (not daily-aggregated).
    /// The sync pipeline stores daily averages, which loses the per-minute granularity
    /// needed for accurate HR zone classification in the strain scorer.
    func fetchTodayRawHeartRateSamples() async -> [MetricSample] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let type = HKQuantityType(.heartRate)
        let unit = HKUnit.count().unitDivided(by: .minute())

        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: startOfDay,
                end: Date(),
                options: .strictStartDate
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                guard let results = results as? [HKQuantitySample], error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                let samples = results.map { sample in
                    MetricSample(date: sample.startDate, value: sample.quantity.doubleValue(for: unit))
                }
                continuation.resume(returning: samples)
            }

            self.healthStore.execute(query)
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
        let startDate = endDate.daysAgo(365)
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
