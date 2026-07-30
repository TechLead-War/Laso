import Foundation
import SwiftData
import Observation
import UserNotifications

// MARK: - SwiftData Models

/// Stores a single daily-aggregated metric value on device
@Model
final class StoredDailySample {
    var metricRawValue: String
    var date: Date
    var value: Double

    init(metricRawValue: String, date: Date, value: Double) {
        self.metricRawValue = metricRawValue
        self.date = date
        self.value = value
    }
}

/// Tracks the last successful HealthKit sync date per metric for incremental fetching
@Model
final class StoredSyncMetadata {
    @Attribute(.unique) var metricRawValue: String
    var lastSyncDate: Date
    var totalSamples: Int

    init(metricRawValue: String, lastSyncDate: Date, totalSamples: Int = 0) {
        self.metricRawValue = metricRawValue
        self.lastSyncDate = lastSyncDate
        self.totalSamples = totalSamples
    }
}

/// Daily snapshot of analysis results for historical score tracking
@Model
final class StoredAnalysisSnapshot {
    var date: Date
    var overallScore: Int
    var categoryScoresJSON: Data
    var baselinesJSON: Data
    /// Vitality age as it was actually computed on this day. Optional so the
    /// field is a lightweight migration, and so days recorded before this
    /// existed stay honestly empty instead of being back-filled with a guess.
    var vitalityAge: Double?

    init(date: Date, overallScore: Int, categoryScoresJSON: Data, baselinesJSON: Data, vitalityAge: Double? = nil) {
        self.date = date
        self.overallScore = overallScore
        self.categoryScoresJSON = categoryScoresJSON
        self.baselinesJSON = baselinesJSON
        self.vitalityAge = vitalityAge
    }
}

/// Daily persisted strain snapshot for historical charting and coaching context
@Model
final class StoredDailyStrain {
    var date: Date
    var strain: Double
    var level: String
    var hrZoneMinutesJSON: Data

    init(date: Date, strain: Double, level: String, hrZoneMinutesJSON: Data) {
        self.date = date
        self.strain = strain
        self.level = level
        self.hrZoneMinutesJSON = hrZoneMinutesJSON
    }
}

/// Tracks a recommendation shown to the user and its outcome
@Model
final class StoredRecommendation {
    @Attribute(.unique) var insightId: String
    var metricRawValue: String
    var recommendation: String
    var severityRawValue: String
    var categoryRawValue: String
    var baselineValue: Double
    var shownDate: Date
    var tappedDate: Date?
    var evaluated24h: Bool = false
    var evaluated7d: Bool = false
    var lift24h: Double?
    var lift7d: Double?
    var outcomeRawValue: String?

    init(insightId: String, metricRawValue: String, recommendation: String, severityRawValue: String, categoryRawValue: String, baselineValue: Double, shownDate: Date) {
        self.insightId = insightId
        self.metricRawValue = metricRawValue
        self.recommendation = recommendation
        self.severityRawValue = severityRawValue
        self.categoryRawValue = categoryRawValue
        self.baselineValue = baselineValue
        self.shownDate = shownDate
    }
}

/// Tracks notification send/open events for optimizer feedback loop
@Model
final class StoredNotificationEvent {
    @Attribute(.unique) var notificationId: String
    var typeRawValue: String
    var sentDate: Date
    var openedDate: Date?
    var actionTaken: Bool = false
    var hourSent: Int
    var dayOfWeek: Int
    // Added optional/defaulted ONLY so SwiftData stays a lightweight migration (a required
    // non-defaulted prop would crash existing installs). presentedDate = first foreground
    // surfacing; deliveredConfirmed = APNS/UN actually delivered, so open-rate is computed
    // vs DELIVERED not vs scheduled. init signature deliberately unchanged.
    var presentedDate: Date? = nil
    var deliveredConfirmed: Bool = false

    init(notificationId: String, typeRawValue: String, sentDate: Date, hourSent: Int, dayOfWeek: Int) {
        self.notificationId = notificationId
        self.typeRawValue = typeRawValue
        self.sentDate = sentDate
        self.hourSent = hourSent
        self.dayOfWeek = dayOfWeek
    }
}

/// Persists learned ML model parameters for on-device ML components
@Model
final class StoredMLModelState {
    @Attribute(.unique) var componentName: String
    var version: Int
    var parametersJSON: Data
    var dataPointsUsed: Int
    var lastTrainedDate: Date

    init(componentName: String, version: Int, parametersJSON: Data, dataPointsUsed: Int, lastTrainedDate: Date) {
        self.componentName = componentName
        self.version = version
        self.parametersJSON = parametersJSON
        self.dataPointsUsed = dataPointsUsed
        self.lastTrainedDate = lastTrainedDate
    }
}

// MARK: - HealthDataStore

/// On-device persistent store for all health metric data using SwiftData.
/// Enables years of historical data storage, incremental HealthKit sync, and score history.
///
/// All ModelContext operations are confined to the main actor for thread safety.
/// Background tasks that need store data should `await` calls on this actor boundary.
@MainActor
@Observable
final class HealthDataStore {
    struct DailyStrainRecord {
        let date: Date
        let strain: Double
    }

    let modelContainer: ModelContainer?
    private(set) var modelContext: ModelContext?
    private var allSeriesCache: [HealthMetric: MetricTimeSeries]?
    private var metricSeriesCache: [HealthMetric: MetricTimeSeries] = [:]

    private static let encoderKey = "Laso.HealthDataStore.encoder"
    private static let decoderKey = "Laso.HealthDataStore.decoder"


    private static func threadEncoder() -> JSONEncoder {
        let dictionary = Thread.current.threadDictionary
        if let encoder = dictionary[encoderKey] as? JSONEncoder {
            return encoder
        }

        let encoder = JSONEncoder()
        dictionary[encoderKey] = encoder
        return encoder
    }

    private static func threadDecoder() -> JSONDecoder {
        let dictionary = Thread.current.threadDictionary
        if let decoder = dictionary[decoderKey] as? JSONDecoder {
            return decoder
        }

        let decoder = JSONDecoder()
        dictionary[decoderKey] = decoder
        return decoder
    }

    private static func encodeJSON<T: Encodable>(_ value: T) -> Data? {
        try? threadEncoder().encode(value)
    }

    private static func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? threadDecoder().decode(type, from: data)
    }

    private func updateSeriesCaches(metric: HealthMetric, incomingSamples: [MetricSample]) {
        guard !incomingSamples.isEmpty else { return }

        if let existingMetricSeries = metricSeriesCache[metric] {
            metricSeriesCache[metric] = MetricTimeSeries(
                metric: metric,
                samples: MetricSample.mergedByLocalDay(existing: existingMetricSeries.samples, incoming: incomingSamples)
            )
        }

        if var allCache = allSeriesCache {
            let existing = allCache[metric]?.samples ?? []
            let merged = MetricTimeSeries(
                metric: metric,
                samples: MetricSample.mergedByLocalDay(existing: existing, incoming: incomingSamples)
            )
            allCache[metric] = merged
            allSeriesCache = allCache
            metricSeriesCache[metric] = merged
        }
    }

    /// Clear cached metric series so future reads reload from SwiftData.
    func invalidateTimeSeriesCache() {
        allSeriesCache = nil
        metricSeriesCache.removeAll(keepingCapacity: true)
    }

    /// Invalidate cached series only for the given metrics, leaving unrelated caches intact.
    func invalidateTimeSeriesCache(for metrics: Set<HealthMetric>) {
        guard !metrics.isEmpty else { return }
        // The allSeriesCache is a single dictionary for all metrics, so it must be cleared
        // if any metric changes (stale entries would be served otherwise).
        allSeriesCache = nil
        for metric in metrics {
            metricSeriesCache.removeValue(forKey: metric)
        }
    }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
    }

    /// Emergency init when SwiftData is unavailable. all reads return empty, writes are no-ops
    init() {
        self.modelContainer = nil
        self.modelContext = nil
    }

    // MARK: - Helpers

    /// Save the model context and track failures to PostHog.
    @discardableResult
    private func saveContext(_ context: String) -> Bool {
        do {
            try modelContext?.save()
            return true
        } catch {
            AppAnalytics.shared.recordNonFatal(error, context: context)
            return false
        }
    }

    // MARK: - Save Samples

    /// Upsert daily samples for a metric. Efficiently batches by loading only the relevant date range.
    func saveSamples(_ samples: [MetricSample], for metric: HealthMetric) {
        guard let modelContext, !samples.isEmpty else { return }

        let result = HealthDataBatchWriter.upsertSamples(samples, for: metric, context: modelContext)

        guard saveContext("swiftdata_save_samples") else { return }
        updateSyncMetadata(for: metric, sampleDelta: result.insertedCount)
        updateSeriesCaches(metric: metric, incomingSamples: samples)
    }

    // MARK: - Load Samples

    /// Load time series for a single metric from the store
    func loadTimeSeries(for metric: HealthMetric) -> MetricTimeSeries? {
        if let cached = metricSeriesCache[metric] {
            return cached
        }
        if let allCache = allSeriesCache {
            return allCache[metric]
        }

        let rawValue = metric.rawValue
        let predicate = #Predicate<StoredDailySample> { $0.metricRawValue == rawValue }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date)]

        guard let stored = try? modelContext?.fetch(descriptor), !stored.isEmpty else { return nil }
        let samples = stored.map { MetricSample(date: $0.date, value: $0.value) }
        let series = MetricTimeSeries(metric: metric, samples: samples)
        metricSeriesCache[metric] = series
        return series
    }

    /// Load only the recent window of every metric.
    ///
    /// `loadAllTimeSeries` has no predicate and no fetch limit, and the daily
    /// sample table is deliberately never pruned, so its cost grows for the life
    /// of the install. Launch does not need the whole history: the scorers all
    /// work inside a one-year window. Deliberately does NOT write `allSeriesCache`
    /// or `metricSeriesCache` — a truncated series in those caches would silently
    /// shorten every later full-history read.
    func loadRecentTimeSeries(days: Int) -> [HealthMetric: MetricTimeSeries] {
        if let cached = allSeriesCache {
            return cached
        }

        guard modelContext != nil else {
            AppAnalytics.shared.recordNonFatal("modelContext is nil — SwiftData unavailable", context: "load_recent_time_series")
            return [:]
        }

        guard let cutoff = Date.cal.date(byAdding: .day, value: -days, to: Date()) else {
            return loadAllTimeSeries()
        }

        var descriptor = FetchDescriptor<StoredDailySample>(
            predicate: #Predicate { $0.date >= cutoff }
        )
        descriptor.sortBy = [SortDescriptor(\.date)]

        guard let samples = try? modelContext?.fetch(descriptor) else {
            AppAnalytics.shared.recordNonFatal("fetch failed", context: "load_recent_time_series")
            return [:]
        }

        var grouped: [String: [MetricSample]] = [:]
        for stored in samples {
            grouped[stored.metricRawValue, default: []].append(
                MetricSample(date: stored.date, value: stored.value)
            )
        }

        var result: [HealthMetric: MetricTimeSeries] = [:]
        for (rawValue, samples) in grouped {
            guard let metric = HealthMetric(rawValue: rawValue) else { continue }
            result[metric] = MetricTimeSeries(metric: metric, samples: samples)
        }
        return result
    }

    /// Load all stored time series in a single efficient query
    func loadAllTimeSeries() -> [HealthMetric: MetricTimeSeries] {
        if let cached = allSeriesCache {
            return cached
        }

        guard modelContext != nil else {
            AppAnalytics.shared.recordNonFatal("modelContext is nil — SwiftData unavailable", context: "load_all_time_series")
            return [:]
        }
        var descriptor = FetchDescriptor<StoredDailySample>()
        descriptor.sortBy = [SortDescriptor(\.date)]

        guard let allSamples = try? modelContext?.fetch(descriptor) else {
            AppAnalytics.shared.recordNonFatal("fetch failed", context: "load_all_time_series")
            return [:]
        }

        // Group by metric in one pass
        var grouped: [String: [MetricSample]] = [:]
        for stored in allSamples {
            grouped[stored.metricRawValue, default: []].append(
                MetricSample(date: stored.date, value: stored.value)
            )
        }

        var result: [HealthMetric: MetricTimeSeries] = [:]
        for (rawValue, samples) in grouped {
            guard let metric = HealthMetric(rawValue: rawValue) else { continue }
            result[metric] = MetricTimeSeries(metric: metric, samples: samples)
        }
        allSeriesCache = result
        metricSeriesCache = result
        return result
    }

    // MARK: - Sync Metadata

    /// Get all sync dates at once (more efficient than per-metric queries)
    func allSyncDates() -> [HealthMetric: Date] {
        let descriptor = FetchDescriptor<StoredSyncMetadata>()
        guard let metadata = try? modelContext?.fetch(descriptor) else { return [:] }

        var result: [HealthMetric: Date] = [:]
        for meta in metadata {
            if let metric = HealthMetric(rawValue: meta.metricRawValue) {
                result[metric] = meta.lastSyncDate
            }
        }
        return result
    }

    /// Mark a metric as successfully synced, even if no new samples were inserted.
    func markSyncCompleted(for metric: HealthMetric, at date: Date = Date()) {
        updateSyncMetadata(for: metric, lastSyncDate: date, recalculateSampleCount: false)
    }

    private func updateSyncMetadata(
        for metric: HealthMetric,
        lastSyncDate: Date = Date(),
        recalculateSampleCount: Bool = true,
        sampleDelta: Int? = nil
    ) {
        let rawValue = metric.rawValue
        let predicate = #Predicate<StoredSyncMetadata> { $0.metricRawValue == rawValue }
        let descriptor = FetchDescriptor(predicate: predicate)
        let existingMetadata = (try? modelContext?.fetch(descriptor))?.first

        let totalSamples: Int?
        if recalculateSampleCount {
            if let sampleDelta, let existingMetadata {
                totalSamples = max(0, existingMetadata.totalSamples + sampleDelta)
            } else {
                let samplePredicate = #Predicate<StoredDailySample> { $0.metricRawValue == rawValue }
                totalSamples = (try? modelContext?.fetchCount(FetchDescriptor(predicate: samplePredicate))) ?? 0
            }
        } else {
            totalSamples = nil
        }

        if let existing = existingMetadata {
            existing.lastSyncDate = lastSyncDate
            if let totalSamples {
                existing.totalSamples = totalSamples
            }
        } else {
            modelContext?.insert(StoredSyncMetadata(
                metricRawValue: rawValue,
                lastSyncDate: lastSyncDate,
                totalSamples: totalSamples ?? 0
            ))
        }
        saveContext("swiftdata_save_sync_metadata")
    }

    // MARK: - Analysis Snapshots

    /// Save today's analysis results (one snapshot per day, upserts if already exists)
    func saveAnalysisSnapshot(
        overallScore: Int,
        categoryScores: [HealthScore],
        baselines: [HealthMetric: UserBaseline]
    ) {
        let today = Date.cal.startOfDay(for: Date())
        guard let tomorrow = Date.cal.date(byAdding: .day, value: 1, to: today) else { return }
        let predicate = #Predicate<StoredAnalysisSnapshot> { $0.date >= today && $0.date < tomorrow }
        let descriptor = FetchDescriptor(predicate: predicate)

        let catDict = Dictionary(uniqueKeysWithValues:
            categoryScores.compactMap { score -> (String, Int)? in
                guard let cat = score.category else { return nil }
                return (cat.rawValue, score.score)
            }
        )
        let catJSON = Self.encodeJSON(catDict) ?? Data()

        let baseDict = Dictionary(uniqueKeysWithValues:
            baselines.map { ($0.key.rawValue, $0.value) }
        )
        let baseJSON = Self.encodeJSON(baseDict) ?? Data()

        if let existing = try? modelContext?.fetch(descriptor).first {
            // Anchor stored date at start-of-day so any callers filtering by
            // calendar-day cutoffs see a deterministic boundary instead of
            // whatever clock-second the first save of the day happened to land on.
            existing.date = today
            existing.overallScore = overallScore
            existing.categoryScoresJSON = catJSON
            existing.baselinesJSON = baseJSON
        } else {
            modelContext?.insert(StoredAnalysisSnapshot(
                date: today,
                overallScore: overallScore,
                categoryScoresJSON: catJSON,
                baselinesJSON: baseJSON
            ))
        }
        saveContext("swiftdata_save_snapshot")
    }

    /// Inserts a snapshot for a *historical* day during the first-run
    /// backfill. No-op if a snapshot already exists for that day so we never
    /// overwrite a real lived score with a replayed one.
    func saveBackfillSnapshot(
        date: Date,
        overallScore: Int,
        categoryScores: [HealthScore],
        baselines: [HealthMetric: UserBaseline]
    ) {
        let dayStart = Date.cal.startOfDay(for: date)
        guard let dayEnd = Date.cal.date(byAdding: .day, value: 1, to: dayStart) else { return }
        let predicate = #Predicate<StoredAnalysisSnapshot> { $0.date >= dayStart && $0.date < dayEnd }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let existing = try? modelContext?.fetch(descriptor), !existing.isEmpty { return }

        let catDict = Dictionary(uniqueKeysWithValues:
            categoryScores.compactMap { score -> (String, Int)? in
                guard let cat = score.category else { return nil }
                return (cat.rawValue, score.score)
            }
        )
        let catJSON = Self.encodeJSON(catDict) ?? Data()

        let baseDict = Dictionary(uniqueKeysWithValues:
            baselines.map { ($0.key.rawValue, $0.value) }
        )
        let baseJSON = Self.encodeJSON(baseDict) ?? Data()

        modelContext?.insert(StoredAnalysisSnapshot(
            date: dayStart,
            overallScore: overallScore,
            categoryScoresJSON: catJSON,
            baselinesJSON: baseJSON
        ))
        saveContext("swiftdata_backfill_snapshot")
    }

    /// Load all analysis snapshots (used for CloudKit backup)
    func loadAllAnalysisSnapshots() -> [StoredAnalysisSnapshot] {
        let descriptor = FetchDescriptor<StoredAnalysisSnapshot>(sortBy: [SortDescriptor(\.date)])
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    /// Insert a restored snapshot from CloudKit backup (skips dedup. only called on fresh install)
    func insertRestoredSnapshot(date: Date, overallScore: Int, categoryScoresJSON: Data, baselinesJSON: Data) {
        modelContext?.insert(StoredAnalysisSnapshot(
            date: date,
            overallScore: overallScore,
            categoryScoresJSON: categoryScoresJSON,
            baselinesJSON: baselinesJSON
        ))
        saveContext("swiftdata_restore_snapshot")
    }

    /// The score and the baselines that were in force on one calendar day.
    ///
    /// The day sheet has to compare a past reading against the baseline the
    /// scorer actually used then, not today's, or a day would be described
    /// against a body average it never saw.
    func analysisSnapshot(on day: Date) -> (score: Int, baselines: [HealthMetric: UserBaseline])? {
        let dayStart = Date.cal.startOfDay(for: day)
        guard let dayEnd = Date.cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let predicate = #Predicate<StoredAnalysisSnapshot> { $0.date >= dayStart && $0.date < dayEnd }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\StoredAnalysisSnapshot.date)])
        descriptor.fetchLimit = 1
        guard let snapshot = try? modelContext?.fetch(descriptor).first else { return nil }

        let decoded = Self.decodeJSON([String: UserBaseline].self, from: snapshot.baselinesJSON) ?? [:]
        let baselines = decoded.reduce(into: [HealthMetric: UserBaseline]()) { result, pair in
            guard let metric = HealthMetric(rawValue: pair.key) else { return }
            result[metric] = pair.value
        }
        return (snapshot.overallScore, baselines)
    }

    /// The strain recorded for one calendar day, with the level word the
    /// scorer assigned at the time.
    func dailyStrain(on day: Date) -> (strain: Double, level: String)? {
        let dayStart = Date.cal.startOfDay(for: day)
        guard let dayEnd = Date.cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let predicate = #Predicate<StoredDailyStrain> { $0.date >= dayStart && $0.date < dayEnd }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\StoredDailyStrain.date)])
        descriptor.fetchLimit = 1
        guard let record = try? modelContext?.fetch(descriptor).first else { return nil }
        return (record.strain, record.level)
    }

    /// Load score history for charting (optional day limit, nil = all time)
    func loadScoreHistory(days: Int? = nil) -> [(date: Date, score: Int)] {
        var descriptor: FetchDescriptor<StoredAnalysisSnapshot>
        if let days {
            let cutoff = Date.cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let predicate = #Predicate<StoredAnalysisSnapshot> { $0.date >= cutoff }
            descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        } else {
            descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.date)])
        }
        let snapshots = (try? modelContext?.fetch(descriptor)) ?? []
        return snapshots.map { ($0.date, $0.overallScore) }
    }

    /// Record today's vitality age on today's snapshot.
    /// Deliberately does not create a snapshot: inserting one here would put a
    /// row with `overallScore` 0 into the score history every caller reads.
    /// The daily analysis pass writes the snapshot first, so this lands on it.
    func saveVitalityAge(_ age: Double) {
        guard age > 0 else { return }
        let today = Date.cal.startOfDay(for: Date())
        guard let tomorrow = Date.cal.date(byAdding: .day, value: 1, to: today) else { return }
        let predicate = #Predicate<StoredAnalysisSnapshot> { $0.date >= today && $0.date < tomorrow }
        guard let snapshot = try? modelContext?.fetch(FetchDescriptor(predicate: predicate)).first else { return }
        guard snapshot.vitalityAge != age else { return }
        snapshot.vitalityAge = age
        saveContext("swiftdata_save_vitality_age")
    }

    /// Vitality ages actually recorded in the window, oldest first.
    /// Days with no recorded age are omitted rather than interpolated.
    func loadVitalityAgeHistory(days: Int) -> [(date: Date, age: Double)] {
        let cutoff = Date.cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<StoredAnalysisSnapshot> { $0.date >= cutoff && $0.vitalityAge != nil }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\StoredAnalysisSnapshot.date)])
        let snapshots = (try? modelContext?.fetch(descriptor)) ?? []
        return snapshots.compactMap { snapshot in
            guard let age = snapshot.vitalityAge else { return nil }
            return (snapshot.date, age)
        }
    }

    /// Load baseline history for ALL metrics in a single pass (avoids N separate full-table fetches + JSON decodes)
    func loadAllBaselineHistory(forMetrics metrics: Set<HealthMetric>, minCount: Int = 30) -> [HealthMetric: [(date: Date, baseline: UserBaseline)]] {
        let descriptor = FetchDescriptor<StoredAnalysisSnapshot>(sortBy: [SortDescriptor(\.date)])
        let snapshots = (try? modelContext?.fetch(descriptor)) ?? []
        let metricRawValues = Set(metrics.map(\.rawValue))

        var result: [HealthMetric: [(date: Date, baseline: UserBaseline)]] = [:]

        for snapshot in snapshots {
            guard let dict = Self.decodeJSON([String: UserBaseline].self, from: snapshot.baselinesJSON) else { continue }
            for (rawValue, baseline) in dict where metricRawValues.contains(rawValue) {
                guard let metric = HealthMetric(rawValue: rawValue) else { continue }
                result[metric, default: []].append((snapshot.date, baseline))
            }
        }

        // Filter to metrics with enough history
        return result.filter { $0.value.count >= minCount }
    }

    // MARK: - Daily Strain Snapshots

    /// Save or update a day's strain record (upsert by calendar day, dedups any legacy duplicates)
    func saveDailyStrain(
        date: Date = Date(),
        strain: Double,
        level: String,
        hrZoneMinutes: [Double]
    ) {
        let calendar = Date.cal
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }

        let predicate = #Predicate<StoredDailyStrain> { $0.date >= dayStart && $0.date < dayEnd }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )

        let encodedZones = Self.encodeJSON(hrZoneMinutes) ?? Data()
        let existing = (try? modelContext?.fetch(descriptor)) ?? []

        if let primary = existing.first {
            primary.date = dayStart
            primary.strain = strain
            primary.level = level
            primary.hrZoneMinutesJSON = encodedZones

            if existing.count > 1 {
                for duplicate in existing.dropFirst() {
                    modelContext?.delete(duplicate)
                }
            }
        } else {
            modelContext?.insert(StoredDailyStrain(
                date: dayStart,
                strain: strain,
                level: level,
                hrZoneMinutesJSON: encodedZones
            ))
        }

        saveContext("swiftdata_save_strain")
    }

    /// Load persisted strain history from [today-lookbackDays, today], sorted ascending.
    func loadDailyStrainHistory(lookbackDays: Int = 7) -> [DailyStrainRecord] {
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -max(lookbackDays, 0), to: today) ?? today
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }

        let predicate = #Predicate<StoredDailyStrain> { $0.date >= startDate && $0.date < endDate }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date)]
        )

        let records = (try? modelContext?.fetch(descriptor)) ?? []
        if records.isEmpty { return [] }

        // Dedup by local day so historical charts stay stable even if old duplicates exist.
        // The date comes from `startOfDay`, not from the bucket: the bucket is a wall clock
        // day index, so multiplying it back into a Date would land it off by the zone offset.
        var dedupedByDay: [Int64: DailyStrainRecord] = [:]
        for record in records {
            dedupedByDay[MetricSample.localDayBucket(for: record.date)] = DailyStrainRecord(
                date: record.date.startOfDay,
                strain: record.strain
            )
        }

        return dedupedByDay.values.sorted { $0.date < $1.date }
    }

    // MARK: - ML Model State

    /// Save an ML component's learned parameters
    func saveMLModelState(_ state: MLModelState) {
        let name = state.componentName
        let predicate = #Predicate<StoredMLModelState> { $0.componentName == name }
        let descriptor = FetchDescriptor(predicate: predicate)

        if let existing = try? modelContext?.fetch(descriptor).first {
            existing.version = state.version
            existing.parametersJSON = state.parametersJSON
            existing.dataPointsUsed = state.dataPointsUsed
            existing.lastTrainedDate = state.lastTrainedDate
        } else {
            modelContext?.insert(StoredMLModelState(
                componentName: state.componentName,
                version: state.version,
                parametersJSON: state.parametersJSON,
                dataPointsUsed: state.dataPointsUsed,
                lastTrainedDate: state.lastTrainedDate
            ))
        }
        saveContext("swiftdata_save_ml_state")
    }

    /// Load all ML model states
    func loadAllMLModelStates() -> [MLModelState] {
        let descriptor = FetchDescriptor<StoredMLModelState>()
        guard let stored = try? modelContext?.fetch(descriptor) else { return [] }
        return stored.map {
            MLModelState(
                componentName: $0.componentName,
                version: $0.version,
                parametersJSON: $0.parametersJSON,
                dataPointsUsed: $0.dataPointsUsed,
                lastTrainedDate: $0.lastTrainedDate
            )
        }
    }

    // MARK: - Stats

    /// Total number of daily samples stored on device
    var totalStoredSamples: Int {
        (try? modelContext?.fetchCount(FetchDescriptor<StoredDailySample>())) ?? 0
    }

    /// True when any restorable on-device state already exists.
    var hasRestorableState: Bool {
        guard let modelContext else { return false }

        if ((try? modelContext.fetchCount(FetchDescriptor<StoredDailySample>())) ?? 0) > 0 {
            return true
        }
        if ((try? modelContext.fetchCount(FetchDescriptor<StoredAnalysisSnapshot>())) ?? 0) > 0 {
            return true
        }
        if ((try? modelContext.fetchCount(FetchDescriptor<StoredMLModelState>())) ?? 0) > 0 {
            return true
        }

        return false
    }

    /// Earliest data point stored
    var oldestDataDate: Date? {
        var descriptor = FetchDescriptor<StoredDailySample>(sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return try? modelContext?.fetch(descriptor).first?.date
    }

    /// Human-readable description of how much data is stored
    var dataSpanDescription: String {
        guard let oldest = oldestDataDate else { return "No data yet" }
        let days = Date.cal.dateComponents([.day], from: oldest, to: Date()).day ?? 0
        if days < 30 { return "\(days) days of data" }
        let months = days / 30
        if months < 12 { return "\(months) months of data" }
        let years = months / 12
        let remainingMonths = months % 12
        if remainingMonths == 0 { return "\(years) year\(years == 1 ? "" : "s") of data" }
        return "\(years)y \(remainingMonths)m of data"
    }

    /// Number of metrics that have stored data
    var metricsWithData: Int {
        let descriptor = FetchDescriptor<StoredSyncMetadata>()
        return (try? modelContext?.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Recommendations

    /// Save a recommendation when an insight is shown to the user (upsert by insightId)
    func saveRecommendation(_ insight: Insight) {
        let idString = insight.id.uuidString
        let predicate = #Predicate<StoredRecommendation> { $0.insightId == idString }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard (try? modelContext?.fetch(descriptor))?.isEmpty ?? true else { return }

        modelContext?.insert(StoredRecommendation(
            insightId: idString,
            metricRawValue: insight.metric.rawValue,
            recommendation: String(insight.actionSummary.prefix(500)),
            severityRawValue: insight.severity.rawValue,
            categoryRawValue: insight.category.rawValue,
            baselineValue: insight.baselineValue,
            shownDate: Date()
        ))
        saveContext("swiftdata_save_recommendation")
    }

    /// Record that the user tapped on an insight recommendation
    func recordRecommendationTapped(insightId: UUID) {
        let idString = insightId.uuidString
        let predicate = #Predicate<StoredRecommendation> { $0.insightId == idString }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let rec = try? modelContext?.fetch(descriptor).first else { return }
        rec.tappedDate = Date()
        saveContext("swiftdata_save_recommendation_tap")
    }

    /// Load recommendations that still need 24h or 7d evaluation
    func loadPendingRecommendations() -> [StoredRecommendation] {
        let predicate = #Predicate<StoredRecommendation> { !$0.evaluated24h || !$0.evaluated7d }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    /// Load evaluated recommendations within a date range
    func loadEvaluatedRecommendations(days: Int) -> [StoredRecommendation] {
        let cutoff = Date.cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<StoredRecommendation> { $0.shownDate >= cutoff && $0.evaluated7d }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    /// Delete recommendations older than 60 days
    func pruneOldRecommendations() {
        let cutoff = Date.cal.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let predicate = #Predicate<StoredRecommendation> { $0.shownDate < cutoff }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let old = try? modelContext?.fetch(descriptor) else { return }
        for rec in old { modelContext?.delete(rec) }
        saveContext("swiftdata_prune_recommendations")
    }

    // MARK: - Notification Events

    /// Record that a notification was sent
    func recordNotificationSent(id: String, type: String) {
        let now = Date()
        let cal = Date.cal
        modelContext?.insert(StoredNotificationEvent(
            notificationId: id,
            typeRawValue: type,
            sentDate: now,
            hourSent: cal.component(.hour, from: now),
            dayOfWeek: cal.component(.weekday, from: now)
        ))
        saveContext("swiftdata_save_notification_sent")
    }

    /// Record that a notification was opened by the user
    func recordNotificationOpened(id: String) {
        let predicate = #Predicate<StoredNotificationEvent> { $0.notificationId == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let event = try? modelContext?.fetch(descriptor).first else { return }
        event.openedDate = Date()
        event.actionTaken = true
        saveContext("swiftdata_save_notification_opened")
    }

    /// Record that a notification was surfaced in the foreground (willPresent).
    /// First impression wins (set presentedDate only if nil). If no row exists yet
    /// (e.g. a push that was never locally scheduled), insert a minimal row stamped
    /// from the present time so the funnel is not lost.
    func recordNotificationPresented(id: String) {
        let predicate = #Predicate<StoredNotificationEvent> { $0.notificationId == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        let now = Date()
        if let event = try? modelContext?.fetch(descriptor).first {
            if event.presentedDate == nil {
                event.presentedDate = now
            }
        } else {
            let cal = Date.cal
            let event = StoredNotificationEvent(
                notificationId: id,
                typeRawValue: NotificationManager.notificationType(id),
                sentDate: now,
                hourSent: cal.component(.hour, from: now),
                dayOfWeek: cal.component(.weekday, from: now)
            )
            event.presentedDate = now
            modelContext?.insert(event)
        }
        saveContext("swiftdata_save_notification_presented")
    }

    /// Reconcile against the system's delivered list so open-rate is measured vs
    /// notifications iOS actually delivered, not vs everything we scheduled.
    /// Caller must invoke this on foreground/scene-active or deliveredConfirmed stays false.
    func reconcileDeliveredNotifications() async {
        guard modelContext != nil else { return }
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        guard !delivered.isEmpty else { return }
        for notification in delivered {
            let id = notification.request.identifier
            let predicate = #Predicate<StoredNotificationEvent> { $0.notificationId == id }
            let descriptor = FetchDescriptor(predicate: predicate)
            guard let event = try? modelContext?.fetch(descriptor).first else { continue }
            event.deliveredConfirmed = true
        }
        saveContext("swiftdata_reconcile_delivered")
    }

    /// Load notification events from the last N days
    func loadNotificationEvents(days: Int) -> [StoredNotificationEvent] {
        let cutoff = Date.cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<StoredNotificationEvent> { $0.sentDate >= cutoff }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.sentDate)])
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    /// Delete notification events older than 90 days
    func pruneOldNotificationEvents() {
        let cutoff = Date.cal.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let predicate = #Predicate<StoredNotificationEvent> { $0.sentDate < cutoff }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let old = try? modelContext?.fetch(descriptor) else { return }
        for event in old { modelContext?.delete(event) }
        saveContext("swiftdata_prune_notifications")
    }

    // MARK: - Delete All Data

    /// Deletes every record across all SwiftData model types and clears in-memory caches.
    /// Called during account data deletion to satisfy App Store data deletion requirements.
    func deleteAllData() {
        guard let ctx = modelContext else { return }

        do { try ctx.delete(model: StoredDailySample.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredSyncMetadata.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredAnalysisSnapshot.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredDailyStrain.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredRecommendation.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredNotificationEvent.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredMLModelState.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredAdherenceRecord.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredECGFeatures.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredModelEvaluation.self) } catch { /* best effort */ }
        do { try ctx.delete(model: StoredJournalEntry.self) } catch { /* best effort */ }

        saveContext("swiftdata_delete_all_data")

        // Clear in-memory caches so stale data is never served
        allSeriesCache = nil
        metricSeriesCache.removeAll()
    }
}
