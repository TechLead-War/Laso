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

// MARK: - HealthDataStore

/// On-device persistent store for all health metric data using SwiftData.
/// Enables years of historical data storage, incremental HealthKit sync, and score history.
@Observable
final class HealthDataStore {
    let modelContainer: ModelContainer
    private let modelContext: ModelContext

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
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
        let existing = (try? modelContext.fetch(descriptor)) ?? []

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
                modelContext.insert(StoredDailySample(
                    metricRawValue: rawValue,
                    date: sample.date,
                    value: sample.value
                ))
            }
        }

        try? modelContext.save()
        updateSyncMetadata(for: metric)
    }

    // MARK: - Load Samples

    /// Load time series for a single metric from the store
    func loadTimeSeries(for metric: HealthMetric) -> MetricTimeSeries? {
        let rawValue = metric.rawValue
        let predicate = #Predicate<StoredDailySample> { $0.metricRawValue == rawValue }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date)]

        guard let stored = try? modelContext.fetch(descriptor), !stored.isEmpty else { return nil }
        let samples = stored.map { MetricSample(date: $0.date, value: $0.value) }
        return MetricTimeSeries(metric: metric, samples: samples)
    }

    /// Load all stored time series in a single efficient query
    func loadAllTimeSeries() -> [HealthMetric: MetricTimeSeries] {
        var descriptor = FetchDescriptor<StoredDailySample>()
        descriptor.sortBy = [SortDescriptor(\.date)]

        guard let allSamples = try? modelContext.fetch(descriptor) else { return [:] }

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
        return try? modelContext.fetch(descriptor).first?.lastSyncDate
    }

    /// Get all sync dates at once (more efficient than per-metric queries)
    func allSyncDates() -> [HealthMetric: Date] {
        let descriptor = FetchDescriptor<StoredSyncMetadata>()
        guard let metadata = try? modelContext.fetch(descriptor) else { return [:] }

        var result: [HealthMetric: Date] = [:]
        for meta in metadata {
            if let metric = HealthMetric(rawValue: meta.metricRawValue) {
                result[metric] = meta.lastSyncDate
            }
        }
        return result
    }

    private func updateSyncMetadata(for metric: HealthMetric) {
        let rawValue = metric.rawValue
        let predicate = #Predicate<StoredSyncMetadata> { $0.metricRawValue == rawValue }
        let descriptor = FetchDescriptor(predicate: predicate)

        // Count total samples for this metric
        let samplePredicate = #Predicate<StoredDailySample> { $0.metricRawValue == rawValue }
        let totalSamples = (try? modelContext.fetchCount(FetchDescriptor(predicate: samplePredicate))) ?? 0

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lastSyncDate = Date()
            existing.totalSamples = totalSamples
        } else {
            modelContext.insert(StoredSyncMetadata(
                metricRawValue: rawValue,
                lastSyncDate: Date(),
                totalSamples: totalSamples
            ))
        }
        try? modelContext.save()
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
        let catJSON = (try? JSONEncoder().encode(catDict)) ?? Data()

        let baseDict = Dictionary(uniqueKeysWithValues:
            baselines.map { ($0.key.rawValue, $0.value) }
        )
        let baseJSON = (try? JSONEncoder().encode(baseDict)) ?? Data()

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.overallScore = overallScore
            existing.categoryScoresJSON = catJSON
            existing.baselinesJSON = baseJSON
        } else {
            modelContext.insert(StoredAnalysisSnapshot(
                date: Date(),
                overallScore: overallScore,
                categoryScoresJSON: catJSON,
                baselinesJSON: baseJSON
            ))
        }
        try? modelContext.save()
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
        let snapshots = (try? modelContext.fetch(descriptor)) ?? []
        return snapshots.map { ($0.date, $0.overallScore) }
    }

    /// Load baseline evolution over time for a single metric
    func loadBaselineHistory(for metric: HealthMetric) -> [(date: Date, baseline: UserBaseline)] {
        let descriptor = FetchDescriptor<StoredAnalysisSnapshot>(sortBy: [SortDescriptor(\.date)])
        let snapshots = (try? modelContext.fetch(descriptor)) ?? []

        return snapshots.compactMap { snapshot in
            guard let dict = try? JSONDecoder().decode([String: UserBaseline].self, from: snapshot.baselinesJSON),
                  let baseline = dict[metric.rawValue] else { return nil }
            return (snapshot.date, baseline)
        }
    }

    // MARK: - Stats

    /// Total number of daily samples stored on device
    var totalStoredSamples: Int {
        (try? modelContext.fetchCount(FetchDescriptor<StoredDailySample>())) ?? 0
    }

    /// Earliest data point stored
    var oldestDataDate: Date? {
        var descriptor = FetchDescriptor<StoredDailySample>(sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first?.date
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
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }
}
