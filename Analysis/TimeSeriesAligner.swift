import Foundation

/// Shared utility for aligning and grouping time series data across metrics
struct TimeSeriesAligner {

    /// A paired data point from two aligned series
    struct AlignedPair {
        let date: Date
        let valueA: Double
        let valueB: Double
    }

    /// Build a Date→Double dictionary keyed by start-of-day for fast lookup
    static func dailyValueMap(_ series: MetricTimeSeries) -> [Date: Double] {
        var map: [Date: Double] = [:]
        for sample in series.samples {
            let day = sample.date.startOfDay
            // If multiple samples per day, use the latest (overwrite)
            map[day] = sample.value
        }
        return map
    }

    /// Align two series by calendar date (same-day pairing)
    static func alignByDate(
        _ seriesA: MetricTimeSeries,
        _ seriesB: MetricTimeSeries
    ) -> [AlignedPair] {
        let mapA = dailyValueMap(seriesA)
        let mapB = dailyValueMap(seriesB)

        var pairs: [AlignedPair] = []
        for (date, valueA) in mapA {
            if let valueB = mapB[date] {
                pairs.append(AlignedPair(date: date, valueA: valueA, valueB: valueB))
            }
        }
        return pairs.sorted { $0.date < $1.date }
    }

    /// Align series A day N with series B day N+offset
    /// Useful for sleep→next-day HRV analysis (dayOffset = 1)
    static func alignWithOffset(
        _ seriesA: MetricTimeSeries,
        _ seriesB: MetricTimeSeries,
        dayOffset: Int
    ) -> [AlignedPair] {
        let mapA = dailyValueMap(seriesA)
        let mapB = dailyValueMap(seriesB)

        var pairs: [AlignedPair] = []
        for (dateA, valueA) in mapA {
            let dateB = Calendar.current.date(byAdding: .day, value: dayOffset, to: dateA)?.startOfDay ?? dateA
            if let valueB = mapB[dateB] {
                pairs.append(AlignedPair(date: dateA, valueA: valueA, valueB: valueB))
            }
        }
        return pairs.sorted { $0.date < $1.date }
    }

    /// Group samples by day of week (1=Sunday ... 7=Saturday)
    static func groupByDayOfWeek(_ series: MetricTimeSeries) -> [Int: [Double]] {
        var groups: [Int: [Double]] = [:]
        for day in 1...7 {
            groups[day] = []
        }
        for sample in series.samples {
            let weekday = sample.date.dayOfWeek
            groups[weekday, default: []].append(sample.value)
        }
        return groups
    }
}
