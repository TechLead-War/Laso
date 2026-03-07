import Foundation
import HealthKit

/// Builds HealthKit queries with appropriate predicates
struct HealthKitQueryBuilder {

    /// Create a date predicate for the given range
    static func datePredicate(from startDate: Date, to endDate: Date) -> NSPredicate {
        let effectiveStart = min(startDate, endDate)
        let effectiveEnd = max(startDate, endDate)
        return HKQuery.predicateForSamples(withStart: effectiveStart, end: effectiveEnd, options: .strictStartDate)
    }

    /// Build a statistics collection query for daily aggregated data
    static func statisticsCollectionQuery(
        for metric: HealthMetric,
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (HKStatisticsCollectionQuery, HKStatisticsCollection?, Error?) -> Void
    ) -> HKStatisticsCollectionQuery? {
        let config = HealthKitMetricRegistry.config(for: metric)
        guard let quantityType = config.quantityType else { return nil }

        let predicate = datePredicate(from: startDate, to: endDate)

        var interval = DateComponents()
        interval.day = 1

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: config.statisticsOption,
            anchorDate: startDate.startOfDay,
            intervalComponents: interval
        )

        query.initialResultsHandler = completion
        return query
    }

    /// Build a sample query for individual data points
    static func sampleQuery(
        for metric: HealthMetric,
        from startDate: Date,
        to endDate: Date,
        limit: Int = HKObjectQueryNoLimit,
        completion: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void
    ) -> HKSampleQuery? {
        let config = HealthKitMetricRegistry.config(for: metric)
        guard let sampleType = config.sampleType else { return nil }

        let predicate = datePredicate(from: startDate, to: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: limit,
            sortDescriptors: [sortDescriptor],
            resultsHandler: completion
        )
    }

    /// Build a workout query
    static func workoutQuery(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void
    ) -> HKSampleQuery {
        let predicate = datePredicate(from: startDate, to: endDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor],
            resultsHandler: completion
        )
    }

    /// Build an observer query for background delivery
    static func observerQuery(
        for metric: HealthMetric,
        updateHandler: @escaping (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void
    ) -> HKObserverQuery? {
        let config = HealthKitMetricRegistry.config(for: metric)
        guard let sampleType = config.sampleType else { return nil }

        return HKObserverQuery(sampleType: sampleType, predicate: nil, updateHandler: updateHandler)
    }
}
