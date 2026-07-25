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
}
