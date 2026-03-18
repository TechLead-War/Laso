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
        context: ModelContext,
        endDate: Date
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
            PostHogManager.shared.captureError(error, context: "batch_writer_save", metadata: [
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

    private struct UpsertResult {
        let insertedCount: Int
        let updatedCount: Int
        var hasChanges: Bool { insertedCount > 0 || updatedCount > 0 }
        var changedSampleCount: Int { insertedCount + updatedCount }
    }

    private static func upsertSamples(
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

        let predicate = #Predicate<StoredDailySample> {
            $0.metricRawValue == rawValue && $0.date >= minDate && $0.date <= maxDate
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let existing = (try? context.fetch(descriptor)) ?? []

        var existingByDate: [Date: StoredDailySample] = [:]
        for sample in existing {
            existingByDate[MetricSample.utcDayBucket(for: sample.date)] = sample
        }

        var insertedCount = 0
        var updatedCount = 0
        for sample in samples {
            let dateKey = MetricSample.utcDayBucket(for: sample.date)
            if let existingSample = existingByDate[dateKey] {
                if existingSample.value != sample.value {
                    existingSample.value = sample.value
                    updatedCount += 1
                }
            } else {
                context.insert(StoredDailySample(
                    metricRawValue: rawValue,
                    date: sample.date,
                    value: sample.value
                ))
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
