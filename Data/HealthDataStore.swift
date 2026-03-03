import Foundation
import SwiftData
import Observation

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

    init(date: Date, overallScore: Int, categoryScoresJSON: Data, baselinesJSON: Data) {
        self.date = date
        self.overallScore = overallScore
        self.categoryScoresJSON = categoryScoresJSON
        self.baselinesJSON = baselinesJSON
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
@Observable
final class HealthDataStore {
    let modelContainer: ModelContainer?
    private let modelContext: ModelContext?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let encoderKey = "HealthPulse.HealthDataStore.encoder"
    private static let decoderKey = "HealthPulse.HealthDataStore.decoder"

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

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
    }

    /// Emergency init when SwiftData is unavailable — all reads return empty, writes are no-ops
    init() {
        self.modelContainer = nil
        self.modelContext = nil
    }

    // MARK: - Save Samples

    /// Upsert daily samples for a metric. Efficiently batches by loading only the relevant date range.
    func saveSamples(_ samples: [MetricSample], for metric: HealthMetric) {
        guard !samples.isEmpty else { return }

        let rawValue = metric.rawValue
        let dates = samples.map(\.date)
        guard let minDate = dates.min(), let maxDate = dates.max() else { return }

        // Load only existing samples in the new data's date range
        let predicate = #Predicate<StoredDailySample> {
            $0.metricRawValue == rawValue && $0.date >= minDate && $0.date <= maxDate
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let existing = (try? modelContext?.fetch(descriptor)) ?? []

        // Build lookup by date string for O(1) dedup
        let formatter = Self.dayFormatter
        var existingByDate: [String: StoredDailySample] = [:]
        for sample in existing {
            existingByDate[formatter.string(from: sample.date)] = sample
        }

        // Upsert: update existing or insert new
        for sample in samples {
            let dateKey = formatter.string(from: sample.date)
            if let existingSample = existingByDate[dateKey] {
                if existingSample.value != sample.value {
                    existingSample.value = sample.value
                }
            } else {
                modelContext?.insert(StoredDailySample(
                    metricRawValue: rawValue,
                    date: sample.date,
                    value: sample.value
                ))
            }
        }

        try? modelContext?.save()
        updateSyncMetadata(for: metric)
    }

    // MARK: - Load Samples

    /// Load time series for a single metric from the store
    func loadTimeSeries(for metric: HealthMetric) -> MetricTimeSeries? {
        let rawValue = metric.rawValue
        let predicate = #Predicate<StoredDailySample> { $0.metricRawValue == rawValue }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date)]

        guard let stored = try? modelContext?.fetch(descriptor), !stored.isEmpty else { return nil }
        let samples = stored.map { MetricSample(date: $0.date, value: $0.value) }
        return MetricTimeSeries(metric: metric, samples: samples)
    }

    /// Load all stored time series in a single efficient query
    func loadAllTimeSeries() -> [HealthMetric: MetricTimeSeries] {
        guard modelContext != nil else {
            print("[HealthDataStore] loadAllTimeSeries: modelContext is nil — SwiftData unavailable")
            return [:]
        }
        var descriptor = FetchDescriptor<StoredDailySample>()
        descriptor.sortBy = [SortDescriptor(\.date)]

        guard let allSamples = try? modelContext?.fetch(descriptor) else {
            print("[HealthDataStore] loadAllTimeSeries: fetch failed")
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
        return result
    }

    // MARK: - Sync Metadata

    /// Get the last sync date for a metric (nil if never synced)
    func lastSyncDate(for metric: HealthMetric) -> Date? {
        let rawValue = metric.rawValue
        let predicate = #Predicate<StoredSyncMetadata> { $0.metricRawValue == rawValue }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try? modelContext?.fetch(descriptor).first?.lastSyncDate
    }

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
        recalculateSampleCount: Bool = true
    ) {
        let rawValue = metric.rawValue
        let predicate = #Predicate<StoredSyncMetadata> { $0.metricRawValue == rawValue }
        let descriptor = FetchDescriptor(predicate: predicate)

        let totalSamples: Int
        if recalculateSampleCount {
            let samplePredicate = #Predicate<StoredDailySample> { $0.metricRawValue == rawValue }
            totalSamples = (try? modelContext?.fetchCount(FetchDescriptor(predicate: samplePredicate))) ?? 0
        } else {
            totalSamples = 0
        }

        if let existing = try? modelContext?.fetch(descriptor).first {
            existing.lastSyncDate = lastSyncDate
            if recalculateSampleCount {
                existing.totalSamples = totalSamples
            }
        } else {
            modelContext?.insert(StoredSyncMetadata(
                metricRawValue: rawValue,
                lastSyncDate: lastSyncDate,
                totalSamples: totalSamples
            ))
        }
        try? modelContext?.save()
    }

    // MARK: - Analysis Snapshots

    /// Save today's analysis results (one snapshot per day, upserts if already exists)
    func saveAnalysisSnapshot(
        overallScore: Int,
        categoryScores: [HealthScore],
        baselines: [HealthMetric: UserBaseline]
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
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
            existing.overallScore = overallScore
            existing.categoryScoresJSON = catJSON
            existing.baselinesJSON = baseJSON
        } else {
            modelContext?.insert(StoredAnalysisSnapshot(
                date: Date(),
                overallScore: overallScore,
                categoryScoresJSON: catJSON,
                baselinesJSON: baseJSON
            ))
        }
        try? modelContext?.save()
    }

    /// Load all analysis snapshots (used for CloudKit backup)
    func loadAllAnalysisSnapshots() -> [StoredAnalysisSnapshot] {
        let descriptor = FetchDescriptor<StoredAnalysisSnapshot>(sortBy: [SortDescriptor(\.date)])
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    /// Insert a restored snapshot from CloudKit backup (skips dedup — only called on fresh install)
    func insertRestoredSnapshot(date: Date, overallScore: Int, categoryScoresJSON: Data, baselinesJSON: Data) {
        modelContext?.insert(StoredAnalysisSnapshot(
            date: date,
            overallScore: overallScore,
            categoryScoresJSON: categoryScoresJSON,
            baselinesJSON: baselinesJSON
        ))
        try? modelContext?.save()
    }

    /// Load score history for charting (optional day limit, nil = all time)
    func loadScoreHistory(days: Int? = nil) -> [(date: Date, score: Int)] {
        var descriptor: FetchDescriptor<StoredAnalysisSnapshot>
        if let days {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let predicate = #Predicate<StoredAnalysisSnapshot> { $0.date >= cutoff }
            descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        } else {
            descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.date)])
        }
        let snapshots = (try? modelContext?.fetch(descriptor)) ?? []
        return snapshots.map { ($0.date, $0.overallScore) }
    }

    /// Load baseline evolution over time for a single metric
    func loadBaselineHistory(for metric: HealthMetric) -> [(date: Date, baseline: UserBaseline)] {
        let descriptor = FetchDescriptor<StoredAnalysisSnapshot>(sortBy: [SortDescriptor(\.date)])
        let snapshots = (try? modelContext?.fetch(descriptor)) ?? []

        return snapshots.compactMap { snapshot in
            guard let dict = Self.decodeJSON([String: UserBaseline].self, from: snapshot.baselinesJSON),
                  let baseline = dict[metric.rawValue] else { return nil }
            return (snapshot.date, baseline)
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
        try? modelContext?.save()
    }

    /// Load an ML component's learned parameters
    func loadMLModelState(componentName: String) -> MLModelState? {
        let predicate = #Predicate<StoredMLModelState> { $0.componentName == componentName }
        let descriptor = FetchDescriptor(predicate: predicate)

        guard let stored = try? modelContext?.fetch(descriptor).first else { return nil }
        return MLModelState(
            componentName: stored.componentName,
            version: stored.version,
            parametersJSON: stored.parametersJSON,
            dataPointsUsed: stored.dataPointsUsed,
            lastTrainedDate: stored.lastTrainedDate
        )
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

    /// Earliest data point stored
    var oldestDataDate: Date? {
        var descriptor = FetchDescriptor<StoredDailySample>(sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return try? modelContext?.fetch(descriptor).first?.date
    }

    /// Human-readable description of how much data is stored
    var dataSpanDescription: String {
        guard let oldest = oldestDataDate else { return "No data yet" }
        let days = Calendar.current.dateComponents([.day], from: oldest, to: Date()).day ?? 0
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
        try? modelContext?.save()
    }

    /// Record that the user tapped on an insight recommendation
    func recordRecommendationTapped(insightId: UUID) {
        let idString = insightId.uuidString
        let predicate = #Predicate<StoredRecommendation> { $0.insightId == idString }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let rec = try? modelContext?.fetch(descriptor).first else { return }
        rec.tappedDate = Date()
        try? modelContext?.save()
    }

    /// Load recommendations that still need 24h or 7d evaluation
    func loadPendingRecommendations() -> [StoredRecommendation] {
        let predicate = #Predicate<StoredRecommendation> { !$0.evaluated24h || !$0.evaluated7d }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    /// Load evaluated recommendations within a date range
    func loadEvaluatedRecommendations(days: Int) -> [StoredRecommendation] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<StoredRecommendation> { $0.shownDate >= cutoff && $0.evaluated7d }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    /// Delete recommendations older than 60 days
    func pruneOldRecommendations() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let predicate = #Predicate<StoredRecommendation> { $0.shownDate < cutoff }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let old = try? modelContext?.fetch(descriptor) else { return }
        for rec in old { modelContext?.delete(rec) }
        try? modelContext?.save()
    }

    // MARK: - Notification Events

    /// Record that a notification was sent
    func recordNotificationSent(id: String, type: String) {
        let now = Date()
        let cal = Calendar.current
        modelContext?.insert(StoredNotificationEvent(
            notificationId: id,
            typeRawValue: type,
            sentDate: now,
            hourSent: cal.component(.hour, from: now),
            dayOfWeek: cal.component(.weekday, from: now)
        ))
        try? modelContext?.save()
    }

    /// Record that a notification was opened by the user
    func recordNotificationOpened(id: String) {
        let predicate = #Predicate<StoredNotificationEvent> { $0.notificationId == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let event = try? modelContext?.fetch(descriptor).first else { return }
        event.openedDate = Date()
        event.actionTaken = true
        try? modelContext?.save()
    }

    /// Load notification events from the last N days
    func loadNotificationEvents(days: Int) -> [StoredNotificationEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = #Predicate<StoredNotificationEvent> { $0.sentDate >= cutoff }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.sentDate)])
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    /// Delete notification events older than 90 days
    func pruneOldNotificationEvents() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let predicate = #Predicate<StoredNotificationEvent> { $0.sentDate < cutoff }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let old = try? modelContext?.fetch(descriptor) else { return }
        for event in old { modelContext?.delete(event) }
        try? modelContext?.save()
    }

    // MARK: - Adherence Records

    /// Save new adherence records
    func saveAdherenceRecords(_ records: [StoredAdherenceRecord]) {
        guard let ctx = modelContext else { return }
        for record in records { ctx.insert(record) }
        try? ctx.save()
    }

    /// Load pending (unevaluated) adherence records
    func loadPendingAdherenceRecords() -> [StoredAdherenceRecord] {
        let descriptor = FetchDescriptor<StoredAdherenceRecord>(
            sortBy: [SortDescriptor(\.givenDate, order: .reverse)]
        )
        let all = (try? modelContext?.fetch(descriptor)) ?? []
        return all.filter { !$0.isEvaluated }
    }

    /// Load evaluated adherence records
    func loadEvaluatedAdherenceRecords() -> [StoredAdherenceRecord] {
        let descriptor = FetchDescriptor<StoredAdherenceRecord>(
            sortBy: [SortDescriptor(\.givenDate, order: .reverse)]
        )
        let all = (try? modelContext?.fetch(descriptor)) ?? []
        return all.filter { $0.isEvaluated }
    }

    /// Save updated adherence records (after outcome measurement)
    func updateAdherenceOutcomes() {
        try? modelContext?.save()
    }

    // MARK: - ECG Features

    /// Save ECG feature extraction results
    func saveECGFeatures(_ features: StoredECGFeatures) {
        modelContext?.insert(features)
        try? modelContext?.save()
    }

    /// Load all stored ECG features sorted by date
    func loadECGFeatures() -> [StoredECGFeatures] {
        let descriptor = FetchDescriptor<StoredECGFeatures>(
            sortBy: [SortDescriptor(\.ecgDate, order: .reverse)]
        )
        return (try? modelContext?.fetch(descriptor)) ?? []
    }
}
