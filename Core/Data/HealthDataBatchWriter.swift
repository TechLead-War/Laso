import Foundation
import SwiftData

/// Performs batch SwiftData writes in a single save() call to reduce I/O overhead.
struct HealthDataBatchWriter {

    struct BatchResult {
        let metricsWithChanges: Set<HealthMetric>
        let totalInsertedSamples: Int
        let totalChangedSamples: Int
    }

    /// Batch-write all fetched metric data in a single save() call on the provided ModelContext.
    /// Uses the caller's context so reads from the same context see the written data immediately.
    static func persistAll(
        newData: [(HealthMetric, MetricTimeSeries)],
        fetchedMetrics: Set<HealthMetric>,
        context: ModelContext
    ) -> BatchResult {

        var metricsWithChanges = Set<HealthMetric>()
        var totalInserted = 0
        var totalChanged = 0

        for (metric, series) in newData {
            let result = upsertSamples(series.samples, for: metric, context: context)
            if result.hasChanges {
                metricsWithChanges.insert(metric)
            }
            totalInserted += result.insertedCount
            totalChanged += result.changedSampleCount
        }

        // Update sync metadata for all fetched metrics
        let metricsWithFetchedSamples = Set(newData.map { $0.0 })
        for metric in fetchedMetrics {
            upsertSyncMetadata(
                for: metric,
                context: context,
                sampleDelta: metricsWithFetchedSamples.contains(metric) ? nil : 0
            )
        }

        // Single save for everything
        do {
            try context.save()
        } catch {
            AnalyticsBackend.provider.captureError(error, context: "batch_writer_save", metadata: [
                "metrics_count": newData.count,
                "inserted": totalInserted
            ])
        }

        return BatchResult(
            metricsWithChanges: metricsWithChanges,
            totalInsertedSamples: totalInserted,
            totalChangedSamples: totalChanged
        )
    }

    /// Slack added past the newest sample's local midnight so the lookup always covers the
    /// whole of that day. Two days is deliberate: it clears the longest daylight saving day
    /// without a calendar call, and the extra rows only sit unused in the lookup.
    private static let dayWindowPadding: TimeInterval = 2 * 86400

    struct UpsertResult {
        let insertedCount: Int
        let updatedCount: Int
        var hasChanges: Bool { insertedCount > 0 || updatedCount > 0 }
        var changedSampleCount: Int { insertedCount + updatedCount }
    }

    /// Shared by the batch path and `HealthDataStore.saveSamples`. One copy only: the
    /// day-key and lookup-window rules below decide whether a day gets a second row,
    /// and two copies drifting apart is what produced duplicate rows in the first place.
    static func upsertSamples(
        _ samples: [MetricSample],
        for metric: HealthMetric,
        context: ModelContext
    ) -> UpsertResult {
        guard !samples.isEmpty else { return UpsertResult(insertedCount: 0, updatedCount: 0) }

        let rawValue = metric.rawValue
        let dates = samples.map(\.date)
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            return UpsertResult(insertedCount: 0, updatedCount: 0)
        }

        // Widen to whole local days. A row already stored for the same day as a boundary
        // sample often sits just outside the raw min/max window (a later wake time, for
        // example), and missing it makes this insert a second row for that day.
        let rangeStart = minDate.startOfDay
        let rangeEnd = maxDate.startOfDay.addingTimeInterval(dayWindowPadding)

        let predicate = #Predicate<StoredDailySample> {
            $0.metricRawValue == rawValue && $0.date >= rangeStart && $0.date < rangeEnd
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let existing = (try? context.fetch(descriptor)) ?? []

        var existingByDate: [Int64: StoredDailySample] = [:]
        var duplicateDayRows = 0
        for sample in existing {
            let dateKey = MetricSample.localDayBucket(for: sample.date)
            if existingByDate[dateKey] != nil {
                duplicateDayRows += 1
            }
            existingByDate[dateKey] = sample
        }

        // Rows written before the day key was fixed can leave two rows on one local day,
        // which double counts in the baseline. Report it rather than let it pass quietly.
        if duplicateDayRows > 0 {
            AnalyticsBackend.provider.captureError(
                "more than one stored row for a single local day",
                context: "batch_writer_duplicate_day",
                metadata: [
                    "metric": rawValue,
                    "duplicate_rows": duplicateDayRows
                ]
            )
        }

        var insertedCount = 0
        var updatedCount = 0
        for sample in samples {
            let dateKey = MetricSample.localDayBucket(for: sample.date)
            if let existingSample = existingByDate[dateKey] {
                if existingSample.value != sample.value {
                    existingSample.value = sample.value
                    updatedCount += 1
                }
            } else {
                let insertedSample = StoredDailySample(
                    metricRawValue: rawValue,
                    date: sample.date,
                    value: sample.value
                )
                context.insert(insertedSample)
                // A later sample on the same local day has to update this row, not add a
                // second one, so it joins the lookup right away.
                existingByDate[dateKey] = insertedSample
                insertedCount += 1
            }
        }

        return UpsertResult(insertedCount: insertedCount, updatedCount: updatedCount)
    }

    private static func upsertSyncMetadata(
        for metric: HealthMetric,
        context: ModelContext,
        sampleDelta: Int?
    ) {
        let rawValue = metric.rawValue
        let predicate = #Predicate<StoredSyncMetadata> { $0.metricRawValue == rawValue }
        let descriptor = FetchDescriptor(predicate: predicate)
        let existingMetadata = (try? context.fetch(descriptor))?.first

        let now = Date()

        if let existing = existingMetadata {
            existing.lastSyncDate = now
            if let sampleDelta {
                existing.totalSamples = max(0, existing.totalSamples + sampleDelta)
            }
        } else {
            context.insert(StoredSyncMetadata(
                metricRawValue: rawValue,
                lastSyncDate: now,
                totalSamples: 0
            ))
        }
    }
}
