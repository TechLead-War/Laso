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
        var metricsCompleted: Int
        var totalMetrics: Int
        var metricsWithSamples: Int
        var samplesDiscovered: Int
        var oldestSampleDate: Date?
    }

    /// Seeded from the persisted grant. A HealthKit background-delivery wake
    /// relaunches the app off-foreground, where the permission request cannot run
    /// at all, so a plain `false` default would strand the dashboard on the error
    /// screen for the rest of that launch.
    var isAuthorized = UserDefaults.standard.bool(forKey: HealthKitManager.authorizationGrantedKey)
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

    /// Dedupes concurrent sleep-stage scans so one sync issues one .sleepAnalysis query.
    @ObservationIgnored
    private let sleepCoordinator = SleepStageCoordinator()

    /// Result of a loadAndSync call. tells callers what changed
    struct SyncResult {
        let metricsWithNewData: Set<HealthMetric>
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

    private static let authorizationGrantedKey = "Laso.HealthKitManager.authorizationGranted"

    /// Metric rawValue -> the day it was last reported stale, so a metric that
    /// stays stale for a month reports once a day instead of once per sync.
    private static let staleReportedDayKey = "Laso.HealthKitManager.staleReportedDay"

    /// In flight request, held process-wide because the system Health sheet is
    /// process-wide. A second `requestAuthorization` while the first sheet is on
    /// screen asks UIKit to present on a view controller that is already
    /// presenting, and what stays on screen is an empty sheet with no rows and no
    /// working buttons — only a force-quit clears it. Two `load()` calls race at
    /// every launch (ContentView's `.task` and its scenePhase-active retry), which
    /// is why the launch log showed `health_permission_requested` twice.
    @ObservationIgnored @MainActor private static var inFlightAuthorization: Task<Void, Never>?

    @MainActor
    func requestAuthorization() async {
        if let inFlight = Self.inFlightAuthorization {
            await inFlight.value
            return
        }
        let request = Task { await performAuthorizationRequest() }
        Self.inFlightAuthorization = request
        await request.value
        Self.inFlightAuthorization = nil
    }

    @MainActor
    private func performAuthorizationRequest() async {
        guard isHealthKitAvailable else {
            error = "HealthKit is not available on this device"
            return
        }

        // Background delivery relaunches the app without a foreground scene, and
        // HealthKit cannot take its privacy-service assertion there, so the request
        // always throws "Unable to acquire legacy assertion on
        // com.apple.HealthPrivacyService". Retrying cannot help while backgrounded:
        // keep the persisted grant and let the next foreground launch ask.
        #if os(iOS)
        let isBackgrounded = await MainActor.run { UIApplication.shared.applicationState == .background }
        if isBackgrounded { return }
        #endif

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

        // iOS shows no sheet once every requested type has been answered, so on a
        // normal launch this call has nothing to do. Skip it rather than hand the
        // system a presentation request during the app's first frames, where the
        // privacy daemon is still warming up (see the retry note below) and the
        // sheet can come up blank.
        if let status = try? await healthStore.statusForAuthorizationRequest(toShare: shareTypes, read: readTypes),
           status == .unnecessary {
            isAuthorized = true
            error = nil
            UserDefaults.standard.set(true, forKey: Self.authorizationGrantedKey)
            return
        }

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
            error = nil
            UserDefaults.standard.set(true, forKey: Self.authorizationGrantedKey)
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
                // The retry helper only rethrows from its final attempt, so
                // reaching here means every attempt was burned.
                AppAnalytics.shared.trackSyncFailed(
                    reason: .healthkitAuthorization,
                    retryCount: Self.authorizationAttempts
                )
            }
        }
    }

    private static let authorizationAttempts = 4

    /// Requests HealthKit authorization, retrying the transient cold-launch
    /// daemon error a few times with growing backoff (~0.3s, 0.6s, 1.2s). Only
    /// the final attempt's error propagates. Total wait is capped near 2s, which
    /// covers the daemon warm-up without a visible stall.
    private func requestAuthorizationWithRetry(
        share: Set<HKSampleType>,
        read: Set<HKObjectType>,
        attempts: Int = HealthKitManager.authorizationAttempts
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
            // Reported, not silent: a locked device skipping every pass is a
            // broken pipeline from the outside, and this used to emit nothing.
            AppAnalytics.shared.trackSyncFailed(reason: .protectedDataUnavailable)
            return SyncResult(metricsWithNewData: [], isFirstSync: false)
        }
        #endif
        let syncStartTime = Date()
        let previousRefresh = lastRefresh
        isLoading = true
        syncProgress = SyncProgress(
            metricsCompleted: 0,
            totalMetrics: HealthMetric.allCases.count,
            metricsWithSamples: 0,
            samplesDiscovered: 0,
            oldestSampleDate: nil
        )

        let syncDates = store.allSyncDates()
        let isFirstSync = syncDates.isEmpty
        // Use start-of-tomorrow so daily statistics buckets always include today's partial data
        let endDate = Date.cal.date(byAdding: .day, value: 1, to: Date.cal.startOfDay(for: Date())) ?? Date()

        // Sleep now counts on the day the user woke up. Stored days written under
        // the old rule split one night across two dates, so every sleep day is
        // read back from HealthKit once. Without this pass the older half of a
        // sleep baseline reads lower than the newer half.
        let sleepStageMetrics: Set<HealthMetric> = [.sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake]
        let sleepBackfillKey = "Laso.HealthKitManager.sleepWakeDayBackfill"
        let needsSleepBackfill = !isFirstSync && !UserDefaults.standard.bool(forKey: sleepBackfillKey)

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
                let rewriteSleepHistory = needsSleepBackfill && sleepStageMetrics.contains(metric)

                // Skip stale metrics: if the metric was synced within the last day AND
                // its most recent data is older than 7 days, skip it -- unless it's a
                // core metric or every 7th sync (to catch newly-appearing data).
                if !isFirstSync,
                   !rewriteSleepHistory,
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
                    if let lastSync, !rewriteSleepHistory {
                        startDate = Date.cal.date(byAdding: .day, value: -1, to: lastSync) ?? lastSync
                    } else {
                        // Fetch all available HealthKit history (up to 10 years) so the
                        // Explore "days" counter reflects the user's full data span, and
                        // so the one time sleep rewrite covers every stored day.
                        startDate = Date.cal.date(byAdding: .year, value: -10, to: endDate) ?? endDate
                    }
                    let series = await self.fetchMetric(metric, from: startDate, to: endDate)
                    return (metric, series)
                }
            }

            for await (metric, series) in group {
                syncProgress?.metricsCompleted += 1
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

        let persisted = persistFetchedData(
            newData: newData,
            fetchedMetrics: fetchedMetrics,
            store: store
        )

        // Marked only after the rewritten days are on disk, so a sync that is
        // killed part way runs the pass again instead of leaving half the
        // history on the old rule.
        if needsSleepBackfill, sleepStageMetrics.isSubset(of: fetchedMetrics) {
            UserDefaults.standard.set(true, forKey: sleepBackfillKey)
        }

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

        reportStaleCoreMetrics(staleCutoff: staleCutoff, coreMetrics: coreMetrics)

        lastRefresh = Date()
        isLoading = false

        // Track sync completion. Skipped entirely when persistence was
        // unavailable (`persisted` is nil): sync_failed already went out, and
        // emitting a zero-sample success next to it would read as "the user had
        // no new health data".
        if let persisted {
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
        }

        let changedMetrics = persisted?.metricsWithChanges ?? []

        // Activation: first data load + time-to-first-value
        if !changedMetrics.isEmpty {
            AppAnalytics.shared.trackActivationMilestone(.firstDataLoad)
            AppAnalytics.shared.trackTimeToFirstValue()
        }

        return SyncResult(
            metricsWithNewData: changedMetrics,
            isFirstSync: isFirstSync
        )
    }

    /// Emits `stale_data_detected` for core metrics whose newest sample is older
    /// than the staleness cutoff, at most once per metric per day.
    ///
    /// This used to live inside the "skip this metric" branch of the fetch
    /// fan-out, which is guarded on `!coreMetrics.contains(metric)` — so the
    /// exact cohort the signal exists for (watch not worn, pairing broken, sync
    /// dead) could never emit it. Peripheral metrics no longer emit: a weight or
    /// mindfulness gap is normal use, not a broken wearable.
    @MainActor
    private func reportStaleCoreMetrics(staleCutoff: Date, coreMetrics: Set<HealthMetric>) {
        let defaults = UserDefaults.standard
        var reportedDays = defaults.dictionary(forKey: Self.staleReportedDayKey) as? [String: Int] ?? [:]
        let now = Date()
        let today = Int(now.timeIntervalSince1970 / 86400)

        for metric in coreMetrics {
            // No samples at all is "never had this data", not stale data.
            guard let latest = timeSeries[metric]?.samples.last?.date, latest < staleCutoff else { continue }
            guard reportedDays[metric.rawValue] != today else { continue }
            reportedDays[metric.rawValue] = today
            AppAnalytics.shared.trackStaleDataDetected(
                staleSinceHours: Int(now.timeIntervalSince(latest) / 3600),
                metric: metric.rawValue
            )
        }
        defaults.set(reportedDays, forKey: Self.staleReportedDayKey)
    }

    @MainActor
    private func persistFetchedData(
        newData: [(HealthMetric, MetricTimeSeries)],
        fetchedMetrics: Set<HealthMetric>,
        store: HealthDataStore
    ) -> PersistedSyncSummary? {
        guard let context = store.modelContext else {
            // nil, not a zeroed summary: the caller must be able to tell a
            // persistence outage from "the user had no new health data", which a
            // zeroed summary made indistinguishable.
            AppAnalytics.shared.trackSyncFailed(reason: .noModelContext)
            return nil
        }

        let batchResult = HealthDataBatchWriter.persistAll(
            newData: newData,
            fetchedMetrics: fetchedMetrics,
            context: context
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
            samples: MetricSample.mergedByLocalDay(existing: existing.samples, incoming: incoming)
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
                        flowValueRaw: sample.value
                    )
                }
                continuation.resume(returning: samples)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Intraday (one day, in time order)

    /// One day split into fixed-width buckets in time order, `0` for a bucket
    /// with no data. Nil only when the day is completely empty.
    ///
    /// 15 minutes by default, not an hour: at 24 buckets a day is six or seven
    /// fat blocks and reads as a bar chart, where the same day at 96 buckets
    /// reads as the trace it actually is. The query cost is the same one
    /// statistics collection either way.
    ///
    /// Deliberately separate from `fetchHourlySamples` below rather than a
    /// parameter on it. That one windows a rolling span from `Date()`, discards
    /// zero-valued buckets, stacks several days onto the same hour-of-day, and
    /// gives up under 12 populated hours. All four are right for a circadian
    /// average and wrong for a single day: a quiet stretch is a real reading, and
    /// an app opened at 7am legitimately has only the morning.
    func fetchIntradayBuckets(
        _ metric: HealthMetric,
        on day: Date = Date(),
        bucketMinutes: Int = 15
    ) async -> [Double]? {
        let config = HealthKitMetricRegistry.config(for: metric)
        guard let quantityType = config.quantityType, bucketMinutes > 0 else { return nil }

        let startDate = Date.cal.startOfDay(for: day)
        guard let endDate = Date.cal.date(byAdding: .day, value: 1, to: startDate) else { return nil }

        // Measured, never assumed 24 hours: the two DST days are 23 and 25 hours
        // long, and a fixed count would drop or pad a bucket on exactly those days.
        let bucketSeconds = Double(bucketMinutes) * 60
        let bucketCount = max(1, Int((endDate.timeIntervalSince(startDate) / bucketSeconds).rounded()))

        return await withCheckedContinuation { continuation in
            var interval = DateComponents()
            interval.minute = bucketMinutes

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate),
                options: config.statisticsOption == .cumulativeSum ? .cumulativeSum : .discreteAverage,
                // Midnight, so bucket boundaries land on the hours the axis labels.
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                guard let results, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                var buckets = [Double](repeating: 0, count: bucketCount)
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let raw = config.statisticsOption == .cumulativeSum
                        ? statistics.sumQuantity()?.doubleValue(for: config.unit)
                        : statistics.averageQuantity()?.doubleValue(for: config.unit)
                    guard let raw else { return }
                    let offset = statistics.startDate.timeIntervalSince(startDate)
                    let index = Int(offset / bucketSeconds)
                    guard buckets.indices.contains(index) else { return }
                    buckets[index] = raw * config.valueScale
                }

                continuation.resume(returning: buckets.contains { $0 > 0 } ? buckets : nil)
            }

            healthStore.execute(query)
        }
    }

    /// Two full weeks: the shortest window where weekday and weekend rhythms
    /// both appear twice, so one unusual Saturday cannot pass as "usual".
    static let usualIntradayWindowDays = 14

    /// The user's usual intraday shape: the previous `days` full days (today
    /// excluded — a partial day would drag every bucket after "now" toward zero)
    /// at the same bucket resolution as `fetchIntradayBuckets`, averaged per
    /// bucket across the days that actually recorded anything. Nil when the
    /// whole window is empty.
    ///
    /// One statistics collection over the whole span, not one query per day:
    /// same HealthKit cost shape as `fetchIntradayBuckets`, fourteen times the
    /// rows. Each statistic is binned by its offset inside its own day, so the
    /// two DST days (23/25 h) still land their buckets on the wall-clock slot
    /// they belong to instead of drifting the rest of the window by an hour.
    func fetchUsualIntradayShape(
        _ metric: HealthMetric,
        days: Int = HealthKitManager.usualIntradayWindowDays,
        bucketMinutes: Int = 15
    ) async -> [Double]? {
        let config = HealthKitMetricRegistry.config(for: metric)
        guard let quantityType = config.quantityType, bucketMinutes > 0, days > 0 else { return nil }

        let endDate = Date.cal.startOfDay(for: Date())
        guard let startDate = Date.cal.date(byAdding: .day, value: -days, to: endDate) else { return nil }

        let bucketSeconds = Double(bucketMinutes) * 60
        let bucketCount = max(1, Int((24.0 * 3600 / bucketSeconds).rounded()))

        return await withCheckedContinuation { continuation in
            var interval = DateComponents()
            interval.minute = bucketMinutes

            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate),
                options: config.statisticsOption == .cumulativeSum ? .cumulativeSum : .discreteAverage,
                // Midnight, so bucket boundaries land on the hours the card's axis labels.
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                guard let results, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let calendar = Date.cal
                var sums = [Double](repeating: 0, count: bucketCount)
                // Divide by days that recorded anything, not by the window
                // length: a user with five days of history gets their real
                // usual shape, not one deflated to five fourteenths.
                var contributingDays = Set<Date>()
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let raw = config.statisticsOption == .cumulativeSum
                        ? statistics.sumQuantity()?.doubleValue(for: config.unit)
                        : statistics.averageQuantity()?.doubleValue(for: config.unit)
                    guard let raw, raw > 0 else { return }
                    let dayStart = calendar.startOfDay(for: statistics.startDate)
                    let index = Int(statistics.startDate.timeIntervalSince(dayStart) / bucketSeconds)
                    guard sums.indices.contains(index) else { return }
                    sums[index] += raw * config.valueScale
                    contributingDays.insert(dayStart)
                }

                guard !contributingDays.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let dayCount = Double(contributingDays.count)
                continuation.resume(returning: sums.map { $0 / dayCount })
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

    // MARK: - Sleep Sessions

    /// Sleep stage values that count as actually asleep.
    private static let asleepStageValues: Set<Int> = [
        HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        HKCategoryValueSleepAnalysis.asleepREM.rawValue
    ]

    /// A gap this long between asleep segments starts a new sleep session.
    /// 90 minutes matches how Whoop and Oura split sessions: a brief 6:17 wake
    /// followed by falling back asleep at 6:35 is still one night, not two.
    private static let sleepSessionGapThreshold: TimeInterval = 90 * 60

    /// Contiguous asleep segments that make up one sleep, plus the awake and
    /// in-bed samples that sit inside or right beside that window.
    /// `start` and `end` come from the asleep segments only, so bedtime and
    /// wake time stay the moments the user actually fell asleep and woke up.
    private struct SleepSession {
        var start: Date
        var end: Date
        var samples: [HKCategorySample]
    }

    /// Groups sleep analysis samples into sleep sessions. Samples that belong to
    /// no session (an awake stretch in the middle of the day) come back in
    /// `unassigned` so nothing is thrown away.
    private static func groupSleepSessions(
        _ results: [HKCategorySample]
    ) -> (sessions: [SleepSession], unassigned: [HKCategorySample]) {
        let asleep = results
            .filter { asleepStageValues.contains($0.value) }
            .sorted { $0.startDate < $1.startDate }

        var sessions: [SleepSession] = []
        for sample in asleep {
            if var last = sessions.last,
               sample.startDate.timeIntervalSince(last.end) <= sleepSessionGapThreshold {
                if sample.endDate > last.end { last.end = sample.endDate }
                last.samples.append(sample)
                sessions[sessions.count - 1] = last
            } else {
                sessions.append(SleepSession(start: sample.startDate, end: sample.endDate, samples: [sample]))
            }
        }

        // Awake time recorded just before falling asleep or just after waking
        // rides along with that session, otherwise a 23:00 awake stretch would
        // land on a different day than the sleep it belongs to.
        //
        // A forward-only cursor replaces a rescan-from-zero per sample. This holds
        // on two invariants that must stay true: `results` arrives sorted ascending
        // by start date (the query sets HKSampleSortIdentifierStartDate), and
        // `sessions` is built above in ascending, non-overlapping start order.
        // Break either and samples are silently mis-assigned rather than dropped.
        var unassigned: [HKCategorySample] = []
        var cursor = 0
        for sample in results where !asleepStageValues.contains(sample.value) {
            // A session that ends before this sample's window opens can never match
            // this sample, and samples only move forward, so it can never match a
            // later one either. The cursor therefore never rewinds.
            while cursor < sessions.count,
                  sessions[cursor].end.addingTimeInterval(sleepSessionGapThreshold) < sample.startDate {
                cursor += 1
            }
            // Sessions are non-overlapping and ascending, so if this one starts too
            // late for the sample, every later one does too — no match exists.
            if cursor < sessions.count,
               sample.endDate >= sessions[cursor].start.addingTimeInterval(-sleepSessionGapThreshold) {
                sessions[cursor].samples.append(sample)
            } else {
                unassigned.append(sample)
            }
        }
        return (sessions, unassigned)
    }

    /// The day a sleep session counts towards: the day the user woke up, which
    /// is what a person means by "last night's sleep". A night that starts at
    /// 23:20 and ends at 06:40 lands whole on the second day instead of being
    /// split across both. A night shift sleep that runs 09:00 to 17:00 lands on
    /// the day it ended, so it is never dropped either.
    /// ponytail: a sleep still running before midnight counts towards the day it
    /// started until the clock passes midnight, then it moves to the right day on
    /// the next sync. Only a live "is this sleep finished" check would remove that
    /// short overlap, and HealthKit does not offer one.
    private static func sleepDay(for session: SleepSession) -> Date {
        session.end.startOfDay
    }

    private func queryOvernightBoundaries(from startDate: Date, to endDate: Date) async -> (overnight: [Date: SleepSessionBoundary], naps: [Date: [SleepSessionBoundary]]) {
        return await withCheckedContinuation { continuation in
            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

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

                let sessions = HealthKitManager.groupSleepSessions(results).sessions

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
                        let day = HealthKitManager.sleepDay(for: session)
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

    /// Return one sleep-stage series. All stages come from a SINGLE .sleepAnalysis
    /// scan per sync: concurrent per-metric callers for the same window share one
    /// in-flight query via `sleepCoordinator`, replacing the old 4-5 full category
    /// scans with one.
    private func fetchSleepSamples(metric: HealthMetric, from startDate: Date, to endDate: Date) async -> MetricTimeSeries? {
        let key = "\(Int(startDate.timeIntervalSince1970))_\(Int(endDate.timeIntervalSince1970))"
        let all = await sleepCoordinator.stages(key: key) { [weak self] in
            await self?.fetchAllSleepStages(from: startDate, to: endDate) ?? [:]
        }
        return all[metric]
    }

    /// Run one HKSampleQuery over .sleepAnalysis and bucket every stage in a single
    /// pass. Stages are grouped into sleep sessions first, so one night counts on
    /// one day even when it starts before midnight, and each day's sample carries
    /// that day's wake time as its date.
    private func fetchAllSleepStages(from startDate: Date, to endDate: Date) async -> [HealthMetric: MetricTimeSeries] {
        return await withCheckedContinuation { continuation in
            let predicate = HealthKitQueryBuilder.datePredicate(from: startDate, to: endDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

            let query = HKSampleQuery(
                sampleType: HKCategoryType(.sleepAnalysis),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, error in
                if let error {
                    recordHealthKitFetchError(error, context: "healthkit_fetch_sleep", metadata: ["metric": "all_stages"])
                }
                guard let results = results as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: [:])
                    return
                }

                let sleepMetrics: [HealthMetric] = [.sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake]
                var durations: [HealthMetric: [Date: Double]] = [:]
                for m in sleepMetrics { durations[m] = [:] }

                // Add one sample's time to the day its sleep session counts towards.
                func route(_ sample: HKCategorySample, to day: Date) {
                    let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                    if HealthKitManager.asleepStageValues.contains(sample.value) {
                        durations[.sleepDuration]?[day, default: 0] += hours
                    }
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        durations[.sleepREM]?[day, default: 0] += hours
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        durations[.sleepDeep]?[day, default: 0] += hours
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        durations[.sleepCore]?[day, default: 0] += hours
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        durations[.sleepAwake]?[day, default: 0] += hours
                    default:
                        break
                    }
                }

                // The end of each day's longest session, used as the sample date so
                // callers can read the wake time straight off the series.
                var wakeTimes: [Date: Date] = [:]
                var longestSessionLength: [Date: TimeInterval] = [:]

                let grouped = HealthKitManager.groupSleepSessions(results)
                for session in grouped.sessions {
                    // A whole night belongs to one day, the day the user woke up,
                    // so a sleep that starts before midnight is not cut in two.
                    // Naps and night shift sleep follow the same rule and stay on
                    // the day they ended. A session that runs past a second night
                    // still counts once, on the morning it finally ended.
                    let day = HealthKitManager.sleepDay(for: session)
                    let length = session.end.timeIntervalSince(session.start)
                    if length > (longestSessionLength[day] ?? -1) {
                        longestSessionLength[day] = length
                        wakeTimes[day] = session.end
                    }
                    for sample in session.samples { route(sample, to: day) }
                }
                // Awake time recorded away from any sleep still counts on its own day.
                for sample in grouped.unassigned { route(sample, to: sample.endDate.startOfDay) }

                var out: [HealthMetric: MetricTimeSeries] = [:]
                for m in sleepMetrics {
                    let samples = (durations[m] ?? [:]).map { entry in
                        MetricSample(date: wakeTimes[entry.key] ?? entry.key, value: entry.value)
                    }.sorted { $0.date < $1.date }
                    out[m] = MetricTimeSeries(metric: m, samples: samples)
                }
                continuation.resume(returning: out)
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
    // heartRate deliberately excluded: WatchMonitor owns it at .immediate for
    // real-time monitoring. A second observer here would fire the full dashboard
    // refresh on every watch HR sample all day (immediate wins the per-type
    // background-delivery cadence), defeating the hourly battery choice below.
    private static let dashboardObserverMetrics: [HealthMetric] = [
        .steps,
        .activeCalories,
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

    /// Stop dashboard observers and disable their background delivery. Called on
    /// account/data deletion or logout so the app stops getting woken once the
    /// user no longer wants it observing HealthKit. Idempotent.
    @MainActor
    func stopDashboardObservers() {
        dashboardObserverDebounceTask?.cancel()
        dashboardObserverDebounceTask = nil
        for query in dashboardObserverQueries {
            healthStore.stop(query)
        }
        dashboardObserverQueries.removeAll()
        for metric in Self.dashboardObserverMetrics {
            guard let sampleType = HealthKitMetricRegistry.config(for: metric).sampleType else { continue }
            healthStore.disableBackgroundDelivery(for: sampleType) { _, _ in }
        }
        hasSetupDashboardObservers = false
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
        // A manual log only ever changes today, so refetching the full history here
        // made the save sheet wait on a statistics collection over every stored day.
        // Yesterday is included so a log made either side of midnight still lands.
        // Metrics with no stored data at all still take the 10-year path once, to
        // seed whatever history HealthKit already holds.
        let hasStoredHistory = timeSeries[metric]?.samples.isEmpty == false
        let startDate: Date
        if hasStoredHistory {
            startDate = Date.cal.date(byAdding: .day, value: -1, to: Date.cal.startOfDay(for: Date())) ?? endDate
        } else {
            startDate = Date.cal.date(byAdding: .year, value: -10, to: endDate) ?? endDate
        }
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

/// Dedupes concurrent sleep-stage scans: the first caller for a given window runs
/// the query; others await the same in-flight task, so one sync does one scan.
private actor SleepStageCoordinator {
    private var inFlight: [String: Task<[HealthMetric: MetricTimeSeries], Never>] = [:]

    func stages(
        key: String,
        build: @Sendable @escaping () async -> [HealthMetric: MetricTimeSeries]
    ) async -> [HealthMetric: MetricTimeSeries] {
        if let existing = inFlight[key] { return await existing.value }
        let task = Task { await build() }
        inFlight[key] = task
        let value = await task.value
        inFlight[key] = nil
        return value
    }
}
