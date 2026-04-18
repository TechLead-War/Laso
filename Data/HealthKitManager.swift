import Foundation
import HealthKit
import Observation

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

    // MARK: - Dashboard Observer State

    /// Persistent observer queries that wake the app when core dashboard metrics
    /// (Steps, Sleep, HR, HRV, Active Energy, Resting HR) receive new samples
    /// (typically after an Apple Watch sync).
    @ObservationIgnored
    private var dashboardObserverQueries: [HKObserverQuery] = []
    @ObservationIgnored
    private var hasSetupDashboardObservers = false
    @ObservationIgnored
    private var dashboardObserverDebounceTask: Task<Void, Never>?

    /// Result of a loadAndSync call. tells callers what changed
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

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            error = "HealthKit is not available on this device"
            return
        }

        // Core read types only — request the minimal set needed for primary
        // features. HealthKit will still return data for types the user has
        // authorized via other apps, so non-core metrics work opportunistically.
        let readTypes: Set<HKObjectType> = [
            // Heart
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            // Blood
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.bloodPressureSystolic),
            HKQuantityType(.bloodPressureDiastolic),
            // Activity
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.appleStandTime),
            HKQuantityType(.distanceWalkingRunning),
            // Sleep
            HKCategoryType(.sleepAnalysis),
            // Body
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
            HKQuantityType(.height),
            // Respiratory
            HKQuantityType(.respiratoryRate),
            // Other
            HKQuantityType(.bodyTemperature),
            HKCategoryType(.mindfulSession),
            // Menstrual
            HKCategoryType(.menstrualFlow),
            // ECG
            HKObjectType.electrocardiogramType(),
        ]

        // Write permissions removed from onboarding — requested lazily in
        // each save method via requestWriteAuthorizationIfNeeded(for:) so
        // the system prompt appears only when the user actually logs data.
        let shareTypes: Set<HKSampleType> = []

        let totalRequested = readTypes.count

        do {
            await MainActor.run {
                AppAnalytics.shared.trackHealthPermissionRequested(
                    metrics: HealthMetric.allCases.map(\.rawValue) + ["menstrual_flow", "electrocardiogram"]
                )
            }
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
            await MainActor.run { AppAnalytics.shared.trackHealthPermissionResult(granted: totalRequested, denied: 0, total: totalRequested) }
        } catch {
            self.error = "Authorization failed: \(error.localizedDescription)"
            await MainActor.run {
                AppAnalytics.shared.trackHealthPermissionResult(granted: 0, denied: totalRequested, total: totalRequested)
                AppAnalytics.shared.trackError(type: "healthkit_authorization", screen: .home, message: error.localizedDescription)
            }
        }
    }

    func fetchAllMetrics(days: Int = 3650) async {
        isLoading = true
        defer { isLoading = false }

        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let startDate = Date().daysAgo(days)

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

    @MainActor
    @discardableResult
    func loadAndSync(store: HealthDataStore) async -> SyncResult {
        let syncStartTime = Date()
        let previousRefresh = lastRefresh
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

        if timeSeries.isEmpty {
            timeSeries = store.loadAllTimeSeries()
        }

        let syncDates = store.allSyncDates()
        let isFirstSync = syncDates.isEmpty
        // Use start-of-tomorrow so daily statistics buckets always include today's partial data
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        syncProgress?.phase = .fetching

        var newData: [(HealthMetric, MetricTimeSeries)] = []
        var fetchedMetrics = Set<HealthMetric>()

        // Core metrics are always fetched regardless of staleness
        let coreMetrics: Set<HealthMetric> = [
            .heartRate, .restingHeartRate, .heartRateVariability,
            .steps, .activeCalories, .exerciseMinutes,
            .sleepDuration, .sleepREM, .sleepDeep, .sleepCore,
            .bloodOxygen, .respiratoryRate, .vo2Max,
            .weight, .workoutCount, .workoutDuration
        ]

        // Sync counter for periodic full fetch of stale metrics (persisted across sessions)
        let syncCountKey = "Laso.HealthKitManager.syncCount"
        let syncCount = UserDefaults.standard.integer(forKey: syncCountKey)
        UserDefaults.standard.set(syncCount + 1, forKey: syncCountKey)

        let staleCutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentSyncCutoff = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        await withTaskGroup(of: (HealthMetric, MetricTimeSeries?).self) { group in
            for metric in HealthMetric.allCases {
                let lastSync = syncDates[metric]

                // Skip stale metrics: if the metric was synced within the last day AND
                // its most recent data is older than 7 days, skip it -- unless it's a
                // core metric or every 7th sync (to catch newly-appearing data).
                if !isFirstSync,
                   !coreMetrics.contains(metric),
                   syncCount % 7 != 0,
                   let lastSync,
                   lastSync > recentSyncCutoff {
                    // Check if this metric's latest sample is stale
                    let latestSampleDate = timeSeries[metric]?.samples.last?.date
                    if let latestSampleDate, latestSampleDate < staleCutoff {
                        syncProgress?.metricsCompleted += 1
                        fetchedMetrics.insert(metric)
                        continue
                    }
                }

                group.addTask { [self] in
                    let startDate: Date
                    if let lastSync {
                        startDate = Calendar.current.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync
                    } else {
                        // Fetch all available HealthKit history (up to 10 years) so the
                        // Explore "days" counter reflects the user's full data span.
                        startDate = Calendar.current.date(byAdding: .year, value: -10, to: endDate) ?? endDate
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
                guard !series.samples.isEmpty else { continue }
                newData.append((metric, series))
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

        syncProgress?.phase = .saving
        let persisted = persistFetchedData(
            newData: newData,
            fetchedMetrics: fetchedMetrics,
            store: store,
            endDate: endDate
        )

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
        AppAnalytics.shared.trackDataPipelineQuality(
            metricsAvailable: fetchedMetrics.count,
            metricsMissing: max(HealthMetric.allCases.count - fetchedMetrics.count, 0),
            dataCoveragePercent: (fetchedMetrics.count * 100) / max(HealthMetric.allCases.count, 1),
            lastSyncAgeSec: previousRefresh.map { Int(syncStartTime.timeIntervalSince($0)) } ?? -1,
            hasEnoughForScore: fetchedMetrics.count >= 8
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

    @MainActor
    private func persistFetchedData(
        newData: [(HealthMetric, MetricTimeSeries)],
        fetchedMetrics: Set<HealthMetric>,
        store: HealthDataStore,
        endDate: Date
    ) -> PersistedSyncSummary {
        guard let context = store.modelContext else {
            return PersistedSyncSummary(metricsWithChanges: [], totalInsertedSamples: 0, totalChangedSamples: 0)
        }

        let batchResult = HealthDataBatchWriter.persistAll(
            newData: newData,
            fetchedMetrics: fetchedMetrics,
            context: context,
            endDate: endDate
        )

        // Invalidate only the metrics that actually changed, not the entire cache
        store.invalidateTimeSeriesCache(for: batchResult.metricsWithChanges)

        return PersistedSyncSummary(
            metricsWithChanges: batchResult.metricsWithChanges,
            totalInsertedSamples: batchResult.totalInsertedSamples,
            totalChangedSamples: batchResult.totalChangedSamples
        )
    }

    @MainActor
    private func finalizeInMemoryTimeSeries(
        isFirstSync: Bool,
        newData: [(HealthMetric, MetricTimeSeries)],
        store: HealthDataStore
    ) {
        if isFirstSync {
            // First sync fetched full history for each populated metric. avoid full reload.
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
                if let error {
                    PostHogManager.shared.captureError(error, context: "healthkit_fetch")
                }
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

    func fetchHourlySamples(_ metric: HealthMetric, days: Int = 30) async -> [[Double]]? {
        let config = HealthKitMetricRegistry.config(for: metric)
        guard let quantityType = config.quantityType else { return nil }

        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let startDate = Date().daysAgo(days)

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
                if let error {
                    PostHogManager.shared.captureError(error, context: "healthkit_fetch_raw_hr")
                }
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

            query.initialResultsHandler = { [metric] _, results, error in
                if let error {
                    PostHogManager.shared.captureError(error, context: "healthkit_fetch_daily_stats", metadata: ["metric": metric.rawValue])
                }
                guard let results, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                var samples: [MetricSample] = []
                // Use midnight boundaries so daily buckets include today's partial data
                results.enumerateStatistics(from: startDate.startOfDay, to: endDate) { statistics, _ in
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
            ) { [metric] _, results, error in
                if let error {
                    PostHogManager.shared.captureError(error, context: "healthkit_fetch_quantity", metadata: ["metric": metric.rawValue])
                }
                guard let results = results as? [HKQuantitySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

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
            ) { [metric] _, results, error in
                if let error {
                    PostHogManager.shared.captureError(error, context: "healthkit_fetch_sleep", metadata: ["metric": metric.rawValue])
                }
                guard let results = results as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                var dailyDurations: [Date: Double] = [:]
                let asleepStageValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]

                var dailyWakeTimes: [Date: Date] = [:]

                for sample in results {
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
                        // Track wake time from overnight sleep only (ends 4 AM–noon).
                        // This filters out afternoon naps that would skew the average.
                        let endHour = Calendar.current.component(.hour, from: sample.endDate)
                        if endHour >= 4 && endHour < 12 {
                            if let existing = dailyWakeTimes[day] {
                                if sample.endDate > existing { dailyWakeTimes[day] = sample.endDate }
                            } else {
                                dailyWakeTimes[day] = sample.endDate
                            }
                        }
                    }
                }

                // Use actual wake time as the sample date so downstream
                // consumers (e.g. SleepNeedCalculator) can infer when the
                // user woke up instead of seeing midnight for every sample.
                let samples = dailyDurations.map { entry in
                    MetricSample(date: dailyWakeTimes[entry.key] ?? entry.key, value: entry.value)
                }
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
            ) { [metric] _, results, error in
                if let error {
                    PostHogManager.shared.captureError(error, context: "healthkit_fetch_workouts", metadata: ["metric": metric.rawValue])
                }
                guard let workouts = results as? [HKWorkout], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

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

    // MARK: - Dashboard Background Observers

    /// Core dashboard metrics that should trigger an auto-refresh when new data
    /// arrives (typically via Apple Watch sync). Kept deliberately small to avoid
    /// refresh storms from seldom-changing metrics.
    private static let dashboardObserverMetrics: [HealthMetric] = [
        .steps,
        .activeCalories,
        .heartRate,
        .restingHeartRate,
        .heartRateVariability,
        .sleepDuration
    ]

    /// Coalesce debounce window: wait this long after the last observer ping
    /// before invoking the change callback so multiple metric updates in the
    /// same sync burst collapse into a single refresh.
    private static let dashboardObserverDebounce: Duration = .seconds(8)

    /// Start `HKObserverQuery` + `enableBackgroundDelivery(.immediate)` for the
    /// core dashboard metrics so new HealthKit data (e.g. fresh Apple Watch
    /// samples) automatically triggers a dashboard refresh without user
    /// interaction.
    ///
    /// `onCoreDataChanged` is invoked on the MainActor after a short debounce
    /// window coalesces rapid-fire per-metric notifications into one callback.
    /// Callers should wire this to a throttled, idempotent refresh entry point
    /// (e.g. `DashboardViewModel.refreshOnForegroundIfNeeded()`).
    ///
    /// Idempotent: repeat calls are a no-op. Requires `isAuthorized` to be true.
    @MainActor
    func setupDashboardObservers(onCoreDataChanged: @escaping @MainActor @Sendable () async -> Void) {
        guard isHealthKitAvailable else { return }
        guard isAuthorized else { return }
        guard !hasSetupDashboardObservers else { return }
        hasSetupDashboardObservers = true

        for metric in Self.dashboardObserverMetrics {
            let config = HealthKitMetricRegistry.config(for: metric)
            guard let sampleType = config.sampleType else { continue }

            let observer = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                defer { completionHandler() }
                if error != nil { return }
                guard let self else { return }
                Task { @MainActor in
                    self.scheduleDashboardObserverRefresh(onCoreDataChanged: onCoreDataChanged)
                }
            }

            healthStore.execute(observer)
            dashboardObserverQueries.append(observer)

            // .immediate = wake the app as soon as new data arrives, not
            // hourly-batched. Matches the pattern in WatchMonitor.
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { _, bgError in
                if let bgError {
                    PostHogManager.shared.captureError(
                        bgError,
                        context: "healthkit_enable_background_delivery",
                        metadata: ["metric": metric.rawValue]
                    )
                }
            }
        }
    }

    /// Cancel and reschedule the debounced refresh callback. Multiple observer
    /// pings in the same sync burst collapse into a single invocation.
    @MainActor
    private func scheduleDashboardObserverRefresh(
        onCoreDataChanged: @escaping @MainActor @Sendable () async -> Void
    ) {
        dashboardObserverDebounceTask?.cancel()
        dashboardObserverDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: Self.dashboardObserverDebounce)
            guard !Task.isCancelled else { return }
            await onCoreDataChanged()
        }
    }

    // MARK: - Write Support

    static let writableMetrics: Set<HealthMetric> = [.weight, .waterIntake, .mindfulMinutes]

    /// Lazily requests write authorization for the given sample types.
    /// Called just before saving so the system prompt appears at the
    /// contextually appropriate moment (when the user taps "Log"),
    /// not during onboarding.
    func requestWriteAuthorizationIfNeeded(for types: Set<HKSampleType>) async throws {
        try await healthStore.requestAuthorization(toShare: types, read: [])
    }

    func saveWeight(_ kg: Double, date: Date = Date()) async throws {
        let weightType = HKQuantityType(.bodyMass)
        try await requestWriteAuthorizationIfNeeded(for: [weightType])
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: quantity,
            start: date,
            end: date
        )
        try await healthStore.save(sample)
    }

    func saveWaterIntake(milliliters: Double, date: Date = Date()) async throws {
        let waterType = HKQuantityType(.dietaryWater)
        try await requestWriteAuthorizationIfNeeded(for: [waterType])
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

    func saveMindfulSession(minutes: Double) async throws {
        let mindfulType = HKCategoryType(.mindfulSession)
        try await requestWriteAuthorizationIfNeeded(for: [mindfulType])
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

    @MainActor
    func refreshMetric(_ metric: HealthMetric, store: HealthDataStore) async {
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        // Use the existing stored data's oldest date to preserve full history,
        // falling back to 10 years for metrics without stored data yet.
        let existingOldest = timeSeries[metric]?.samples.first?.date
        let startDate = existingOldest ?? Calendar.current.date(byAdding: .year, value: -10, to: endDate) ?? endDate
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
                if let error {
                    PostHogManager.shared.captureError(error, context: "healthkit_fetch_mindful")
                }
                guard let results = results as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

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
