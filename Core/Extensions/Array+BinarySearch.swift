import Foundation

/// Binary-search helpers on a sorted-by-date array of `MetricSample`. The
/// array is assumed to be sorted ascending by `date` (the invariant
/// `MetricTimeSeries` enforces at construction).
extension Array where Element == MetricSample {
    /// Returns the first index whose sample date is `>= date`. Returns `count`
    /// if every sample is strictly earlier than `date`.
    func firstIndex(onOrAfter date: Date) -> Int {
        var low = 0
        var high = count
        while low < high {
            let mid = (low + high) / 2
            if self[mid].date < date {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    /// Returns the first index whose sample date is `> date`. Returns `count`
    /// if every sample is `<= date`.
    func firstIndex(after date: Date) -> Int {
        var low = 0
        var high = count
        while low < high {
            let mid = (low + high) / 2
            if self[mid].date <= date {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}
