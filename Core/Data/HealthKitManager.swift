import Foundation
import HealthKit
import Observation
#if os(iOS)
import UIKit
#endif

/// Records a HealthKit fetch failure, dropping errorDatabaseInaccessible: the
/// health DB is sealed whenever the device is locked, so a background wake makes
/// every in-flight query of the metric fan-out fail at once and floods analytics
/// with same-second bursts that are device state, not app errors.
private func recordHealthKitFetchError(_ error: Error, context: String, metadata: [String: Any] = [:]) {
    if (error as? HKError)?.code == .errorDatabaseInaccessible { return }
    AnalyticsBackend.provider.captureError(error, context: context, metadata: metadata)
}

@Observable
final class HealthKitManager: @unchecked Sendable {
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

    /// Per-day overnight sleep session boundaries derived from
    /// `HKCategoryType(.sleepAnalysis)` asleep* samples. Keyed by the wake-day
    /// `startOfDay` (Apple's convention: a sleep "belongs" to the day you wake up).
    /// Populated as a side-effect of fetching `.sleepDuration` so we don't pay
    /// the cost of a second category query.
    struct SleepSessionBoundary: Sendable {
        let bedtime: Date
        let wakeTime: Date
        /// Sum of `asleepCore` + `asleepUnspecified` samples within the session, in hours.
        let coreHours: Double
        /// Sum of `asleepDeep` samples within the session, in hours.
        let deepHours: Double
        /// Sum of `asleepREM` samples within the session, in hours.
        let remHours: Double
        /// Time inside the bedtime…wakeTime window not classified as any asleep stage.
        let awakeHours: Double
    }
    var sleepSessionBoundaries: [Date: SleepSessionBoundary] = [:]

    /// Per-day daytime naps (sessions ≥ 20 min that don't qualify as the
    /// overnight session). Keyed by the *start*-day `startOfDay` so a nap
    /// taken on Tuesday afternoon shows up under Tuesday. Multiple naps on
    /// the same day are preserved in order so the Sleep Coach 14-Day History
    /// can surface them.
    var napSessionBoundaries: [Date: [SleepSessionBoundary]] = [:]

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

        // Read types are derived from the metric registry so every supported
        // HealthMetric is included in the permission prompt. HealthKit returns
        // empty data for types the user never authorized, so a partial list
        // silently blanks entire categories (Hearing, Mobility, etc.).
        var readTypes: Set<HKObjectType> = []
        for metric in HealthMetric.allCases {
            if let sampleType = HealthKitMetricRegistry.config(for: metric).sampleType {
                readTypes.insert(sampleType)
            }
        }
        readTypes.insert(HKCategoryType(.menstrualFlow))
        readTypes.insert(HKObjectType.electrocardiogramType())

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
            // Cold-launch race: HealthKit's privacy daemon (HealthPrivacyService)
            // is often not ready in the first second after launch and throws
            // "Unable to acquire legacy assertion on com.apple.HealthPrivacyService".
            // It warms up shortly after, which is why killing and reopening works.
            // A read-denial never throws (Apple hides read grants), so a throw here
            // is a transient system error — retry with backoff before failing, so
            // the first launch no longer shows a false "Unable to Load Data".
            try await requestAuthorizationWithRetry(share: shareTypes, read: readTypes)
            isAuthorized = true
            // Do NOT emit health_permission_result here: HealthKit never reveals which
            // READ permissions the user granted (Apple hides it so apps cannot infer
            // conditions from denials), so an all-granted count would be fabricated.
            // It is reported once from the first loadAndSync() using real data
            // availability instead.
        } catch {
            self.error = "Authorization failed: \(error.localizedDescription)"
            await MainActor.run {
                reportHealthPermissionGrantOnce(granted: 0, denied: totalRequested, total: totalRequested)
                AppAnalytics.shared.trackError(type: "healthkit_authorization", screen: .home, message: error.localizedDescription)
                // Data-pipeline failure signal: lets analytics see HealthKit auth/sync
                // failures separately from generic errors so churn analysis can isolate
                // permission-related drop-off from runtime errors.
                AppAnalytics.shared.trackSyncFailed(reason: "healthkit_authorization: \(error.localizedDescription)")
            }
        }
    }

    /// Requests HealthKit authorization, retrying the transient cold-launch
    /// daemon error a few times with growing backoff (~0.3s, 0.6s, 1.2s). Only
    /// the final attempt's error propagates. Total wait is capped near 2s, which
    /// covers the daemon warm-up without a visible stall.
    private func requestAuthorizationWithRetry(
        share: Set<HKSampleType>,
        read: Set<HKObjectType>,
        attempts: Int = 4
    ) async throws {
        var delayNs: UInt64 = 300_000_000
        for attempt in 1...attempts {
            do {
                try await healthStore.requestAuthorization(toShare: share, read: read)
                return
            } catch {
                guard attempt < attempts else { throw error }
                try? await Task.sleep(nanoseconds: delayNs)
                delayNs *= 2
            }
        }
    }

    func fetchAllMetrics(days: Int = 3650) async {
        isLoading = true
        defer { isLoading = false }

        let endDate = Date.cal.date(byAdding: .day, value: 1, to: Date.cal.startOfDay(for: Date())) ?? Date()
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

    /// Emits `health_permission_result` at most once per install. HealthKit never
    /// reports which READ permissions were granted, so callers pass the best real
    /// signal available: data availability after the first fetch, or a hard 0 when
    /// authorization itself failed. A type the user simply has no history for counts
    /// as not-granted, so grant_rate is an effective read-availability rate (a lower
    /// bound on true grants), not the old fabricated 1.0.
    @MainActor
    private func reportHealthPermissionGrantOnce(granted: Int, denied: Int, total: Int) {
        let key = "Laso.HealthKitManager.permissionResultReported"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        AppAnalytics.shared.trackHealthPermissionResult(granted: granted, denied: denied, total: total)
    }

    @MainActor
    @discardableResult
    func loadAndSync(store: HealthDataStore) async -> SyncResult {
        // Hydrate persisted series before any early return: on a cold background
        // relaunch the caller analyzes whatever is in memory, and an empty
        // timeSeries would overwrite today's snapshot and widgets with zeros.
        if timeSeries.isEmpty {
            timeSeries = store.loadAllTimeSeries()
        }

        // The health DB is sealed while the device is locked: every query in the
        // fan-out below would fail with errorDatabaseInaccessible. Skip the pass;
        // the next unlock/foreground trigger syncs instead.
        #if os(iOS)
        guard UIApplication.shared.isProtectedDataAvailable else {
            return SyncResult(metricsWithNewData: [], totalNewSamples: 0, isFirstSync: false)
        }
        #endif
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

        let syncDates = store.allSyncDates()
        let isFirstSync = syncDates.isEmpty
        // Use start-of-tomorrow so daily statistics buckets always include today's partial data
        let endDate = Date.cal.date(byAdding: .day, value: 1, to: Date.cal.startOfDay(for: Date())) ?? Date()
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

        let staleCutoff = Date.cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentSyncCutoff = Date.cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()

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
                        // Stale data signal: latest sample is older than 7 days,
                        // strongest churn precursor for wearable users (device
                        // not worn, paired wrong, sync broken).
                        let staleHours = Int(Date().timeIntervalSince(latestSampleDate) / 3600)
                        await MainActor.run {
                            AppAnalytics.shared.trackStaleDataDetected(
                                staleSinceHours: staleHours,
                                metric: metric.rawValue
                            )
                        }
                        syncProgress?.metricsCompleted += 1
                        fetchedMetrics.insert(metric)
                        continue
                    }
                }

                group.addTask { [self] in
                    let startDate: Date
                    if let lastSync {
                        startDate = Date.cal.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync
                    } else {
                        // Fetch all available HealthKit history (up to 10 years) so the
                        // Explore "days" counter reflects the user's full data span.
                        startDate = Date.cal.date(byAdding: .year, value: -10, to: endDate) ?? endDate
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

        // Truthful health_permission_result, reported once per install after the first
        // real sync populates timeSeries. HealthKit hides read-grant status, so data
        // availability (metrics that returned samples) is the only honest signal. This
        // lives here, not in requestAuthorization, because loadAndSync is the actual
        // post-auth entry point that fetches data.
        let permissionTotal = HealthMetric.allCases.count
        let permissionGranted = HealthMetric.allCases.filter { timeSeries[$0]?.samples.isEmpty == false }.count
        reportHealthPermissionGrantOnce(granted: permissionGranted, denied: permissionTotal - permissionGranted, total: permissionTotal)

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
                    recordHealthKitFetchError(error, context: "healthkit_fetch")
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

        let endDate = Date.cal.date(byAdding: .day, value: 1, to: Date.cal.startOfDay(for: Date())) ?? Date()
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
                let calendar = Date.cal

                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let raw: Double?
                    if config.statisticsOption == .cumulativeSum {
                        raw = statistics.sumQuantity()?.doubleValue(for: config.unit)
                    } else {
                        raw = statistics.averageQuantity()?.doubleValue(for: config.unit)
                    }
                    let value = raw.map { $0 * config.valueScale }
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
               Date.cal.dateComponents([.day], from: last, to: day).day ?? 0 > 20 {
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
        let calendar = Date.cal

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
        let startOfDay = Date.cal.startOfDay(for: Date())
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
                    recordHealthKitFetchError(error, context: "healthkit_fetch_raw_hr")
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
                    recordHealthKitFetchError(error, context: "healthkit_fetch_daily_stats", metadata: ["metric": metric.rawValue])
                }
                guard let results, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                var samples: [MetricSample] = []
                // Use midnight boundaries so daily buckets include today's partial data
                results.enumerateStatistics(from: startDate.startOfDay, to: endDate) { statistics, _ in
                    let raw: Double?
                    if config.statisticsOption == .cumulativeSum {
                        raw = statistics.sumQuantity()?.doubleValue(for: config.unit)
                    } else {
                        raw = statistics.averageQuantity()?.doubleValue(for: config.unit)
                    }
                    let value = raw.map { $0 * config.valueScale }
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
                    recordHealthKitFetchError(error, context: "healthkit_fetch_quantity", metadata: ["metric": metric.rawValue])
                }
                guard let results = results as? [HKQuantitySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                var dailyValues: [Date: [Double]] = [:]
                for sample in results {
                    let day = sample.startDate.startOfDay
                    let value = sample.quantity.doubleValue(for: config.unit) * config.valueScale
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

    /// One-shot refresh of `sleepSessionBoundaries` for the trailing `days` window.
    /// Called when Sleep Coach opens so the 14-day history shows correct bedtime/wake
    /// times even after a cold start (when the routine sync only fetches the last 1–2 days).
    @MainActor
    func refreshSleepBoundaries(days: Int = 14) async {
        let endDate = Date.cal.date(byAdding: .day, value: 1, to: Date.cal.startOfDay(for: Date())) ?? Date()
        let startDate = Date.cal.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let result = await queryOvernightBoundaries(from: startDate, to: endDate)
        sleepSessionBoundaries.merge(result.overnight) { _, new in new }
        napSessionBoundaries.merge(result.naps) { _, new in new }
    }

    private func queryOvernightBoundaries(from startDate: Date, to endDate: Date) async -> (overnight: [Date: SleepSessionBoundary], naps: [Date: [SleepSessionBoundary]]) {
        return await withCheckedContinuation { continuation in
            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let asleepStageValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]

            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                guard let results = results as? [HKCategorySample] else {
                    continuation.resume(returning: (overnight: [:], naps: [:]))
                    return
                }

                // Keep only asleep segments and sort by start.
                let asleep = results
                    .filter { asleepStageValues.contains($0.value) }
                    .sorted { $0.startDate < $1.startDate }

                // Group contiguous asleep segments into sessions, retaining the
                // raw samples per session so we can later attribute time to each
                // stage. A gap > 60 min between asleep samples splits sessions —
                // brief wakeups stay inside the same session, preserving bedtime.
                struct SleepSession {
                    var start: Date
                    var end: Date
                    var samples: [HKCategorySample]
                }
                var sessions: [SleepSession] = []
                // 90 min gap matches industry practice (Whoop / Oura) for
                // "wake-within-sleep" — a brief 6:17 wake followed by a fall
                // back to sleep at 6:35 should stay one session, not split.
                let gapThreshold: TimeInterval = 90 * 60
                for sample in asleep {
                    if var last = sessions.last,
                       sample.startDate.timeIntervalSince(last.end) <= gapThreshold {
                        if sample.endDate > last.end { last.end = sample.endDate }
                        last.samples.append(sample)
                        sessions[sessions.count - 1] = last
                    } else {
                        sessions.append(SleepSession(start: sample.startDate, end: sample.endDate, samples: [sample]))
                    }
                }

                /// Builds a SleepSessionBoundary by attributing each stage sample's
                /// duration to its category, then deriving awake time from the rest
                /// of the bedtime…wakeTime window.
                func buildBoundary(for session: SleepSession) -> SleepSessionBoundary {
                    var coreSec: TimeInterval = 0
                    var deepSec: TimeInterval = 0
                    var remSec: TimeInterval = 0
                    for sample in session.samples {
                        let dur = sample.endDate.timeIntervalSince(sample.startDate)
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            deepSec += dur
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            remSec += dur
                        case HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                             HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                            coreSec += dur
                        default:
                            break
                        }
                    }
                    let totalSec = session.end.timeIntervalSince(session.start)
                    let asleepSec = coreSec + deepSec + remSec
                    let awakeSec = max(0, totalSec - asleepSec)
                    return SleepSessionBoundary(
                        bedtime: session.start,
                        wakeTime: session.end,
                        coreHours: coreSec / 3600.0,
                        deepHours: deepSec / 3600.0,
                        remHours: remSec / 3600.0,
                        awakeHours: awakeSec / 3600.0
                    )
                }

                // Classify each session as either the day's overnight sleep
                // (ends 4 AM–noon, ≥ 2 h) or a daytime nap (≥ 20 min, ends
                // outside the overnight window OR shorter than 2 h). Naps go
                // into a parallel dict keyed by *start*-day so a Sunday 1pm
                // nap surfaces under Sunday in the Sleep Coach history.
                var overnight: [Date: SleepSessionBoundary] = [:]
                var naps: [Date: [SleepSessionBoundary]] = [:]
                for session in sessions {
                    let endHour = Date.cal.component(.hour, from: session.end)
                    let durationHours = session.end.timeIntervalSince(session.start) / 3600.0
                    let isOvernight = endHour >= 4 && endHour < 12 && durationHours >= 2
                    let candidate = buildBoundary(for: session)
                    if isOvernight {
                        let day = session.end.startOfDay
                        if let existing = overnight[day] {
                            let existingDur = existing.wakeTime.timeIntervalSince(existing.bedtime)
                            let newDur = session.end.timeIntervalSince(session.start)
                            if newDur > existingDur { overnight[day] = candidate }
                        } else {
                            overnight[day] = candidate
                        }
                    } else if durationHours >= (20.0 / 60.0) {
                        let day = session.start.startOfDay
                        naps[day, default: []].append(candidate)
                    }
                }
                continuation.resume(returning: (overnight: overnight, naps: naps))
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
                    recordHealthKitFetchError(error, context: "healthkit_fetch_sleep", metadata: ["metric": metric.rawValue])
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
                        let endHour = Date.cal.component(.hour, from: sample.endDate)
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

    /// Days (0...`days`) in the trailing window with at least one sample for any of the
    /// core daily metrics (steps, heart rate, sleep duration). Used by analytics to emit
    /// a `daily_data_completeness_7d` signal so analysts can segment retention by how
    /// complete a user's data pipeline is — the wellness-app industry's standard proxy
    /// for "active user".
    func daysWithAnyDataInLast(days: Int = 7) -> Int {
        let calendar = Date.cal
        let endDay = calendar.startOfDay(for: Date())
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) else {
            return 0
        }

        let coreMetrics: [HealthMetric] = [.steps, .heartRate, .sleepDuration]
        var coveredDays = Set<Date>()

        for metric in coreMetrics {
            guard let series = timeSeries[metric] else { continue }
            for sample in series.samples {
                let day = calendar.startOfDay(for: sample.date)
                if day >= startDay && day <= endDay {
                    coveredDays.insert(day)
                }
            }
        }

        return coveredDays.count
    }

    /// Returns the start date of the earliest "asleep*" category sample within the window,
    /// or `nil` if none exist. Used by `WindDownOutcomeTracker` to validate whether the user
    /// actually fell asleep after a Wind-Down Live Activity was shown, and how far that sleep
    /// onset deviated from the target bedtime.
    func fetchFirstSleepOnset(windowStart: Date, windowEnd: Date) async -> Date? {
        return await withCheckedContinuation { continuation in
            let predicate = HealthKitQueryBuilder.datePredicate(from: windowStart, to: windowEnd)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let asleepStageValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]

            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                if let error {
                    recordHealthKitFetchError(error, context: "healthkit_fetch_sleep_onset")
                }
                guard let samples = results as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let firstAsleep = samples.first { asleepStageValues.contains($0.value) }
                continuation.resume(returning: firstAsleep?.startDate)
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
                    recordHealthKitFetchError(error, context: "healthkit_fetch_workouts", metadata: ["metric": metric.rawValue])
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
                Task { @MainActor [weak self] in
                    self?.scheduleDashboardObserverRefresh(onCoreDataChanged: onCoreDataChanged)
                }
            }

            healthStore.execute(observer)
            dashboardObserverQueries.append(observer)

            // .hourly, not .immediate: the dashboard is not a real-time surface
            // (it refreshes on foreground), so waking the app on every watch
            // sample all day — steps/HR arrive constantly during activity — is
            // pure battery waste. Hourly background refresh is plenty. Real-time
            // heart-rate monitoring stays on its own .immediate query in WatchMonitor.
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { _, bgError in
                if let bgError {
                    AnalyticsBackend.provider.captureError(
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
        let endDate = Date.cal.date(byAdding: .day, value: 1, to: Date.cal.startOfDay(for: Date())) ?? Date()
        // Use the existing stored data's oldest date to preserve full history,
        // falling back to 10 years for metrics without stored data yet.
        let existingOldest = timeSeries[metric]?.samples.first?.date
        let startDate = existingOldest ?? Date.cal.date(byAdding: .year, value: -10, to: endDate) ?? endDate
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
                    recordHealthKitFetchError(error, context: "healthkit_fetch_mindful")
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
