import SwiftUI

struct CalibrationDiscovery {
    var oldestDataDate: Date?
    var metricsWithData: Int = 0
    var totalDataPoints: Int = 0
    var highlights: [MetricHighlight] = []

    struct MetricHighlight: Identifiable {
        let id = UUID()
        let metricName: String
        let stat: String
        let detail: String
        let icon: String
        let color: Color
    }

    var dataSpanDescription: String? {
        guard let oldest = oldestDataDate else { return nil }
        let days = Date.cal.dateComponents([.day], from: oldest, to: Date()).day ?? 0
        if days >= 365 {
            let years = days / 365
            let months = (days % 365) / 30
            if months > 0 {
                return "\(years)y \(months)mo"
            }
            return "\(years) year\(years == 1 ? "" : "s")"
        } else if days >= 30 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        } else if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        }
        return nil
    }

    /// Build discovery from HealthKitManager's time series after calibration
    static func build(from timeSeries: [HealthMetric: MetricTimeSeries]) -> CalibrationDiscovery {
        var discovery = CalibrationDiscovery()

        let populatedSeries = timeSeries.filter { !$0.value.samples.isEmpty }
        discovery.metricsWithData = populatedSeries.count
        discovery.totalDataPoints = populatedSeries.values.reduce(0) { $0 + $1.totalDataPoints }

        // Find oldest data date
        let allFirstDates = populatedSeries.values.compactMap { $0.samples.first?.date }
        discovery.oldestDataDate = allFirstDates.min()

        // Priority metrics to highlight (user-facing, commonly available)
        let priorityMetrics: [(metric: HealthMetric, label: String)] = [
            (.restingHeartRate, "Resting HR"),
            (.sleepDuration, "Sleep"),
            (.steps, "Daily Steps"),
            (.heartRateVariability, "HRV"),
            (.vo2Max, "VO2 Max"),
            (.exerciseMinutes, "Exercise"),
            (.activeCalories, "Active Calories"),
            (.weight, "Weight"),
        ]

        for entry in priorityMetrics {
            guard discovery.highlights.count < 4 else { break }
            guard let series = populatedSeries[entry.metric], series.samples.count >= 3 else { continue }

            let avg = series.mean
            let formatted: String
            if entry.metric == .sleepDuration {
                let hours = Int(avg)
                let minutes = Int((avg - Double(hours)) * 60)
                formatted = "\(hours)h \(minutes)m"
            } else if entry.metric == .steps {
                formatted = Self.formatSteps(Int(avg))
            } else {
                formatted = entry.metric.formatWithUnit(avg)
            }

            let days = series.daysOfData
            let detail: String
            if days >= 30 {
                let months = days / 30
                detail = "\(months) month\(months == 1 ? "" : "s") of data"
            } else {
                detail = "\(days) day\(days == 1 ? "" : "s") of data"
            }

            discovery.highlights.append(.init(
                metricName: entry.label,
                stat: formatted,
                detail: detail,
                icon: entry.metric.systemImageName,
                color: entry.metric.category.color
            ))
        }

        return discovery
    }

    /// Cached step formatter — `formatSteps` runs once per priority
    /// metric (up to 4 calls per discovery build) and `discovery.build(from:)`
    /// is invoked on the Mirror Moment onboarding step. One static avoids the
    /// per-call NumberFormatter allocation.
    private static let stepsFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()

    private static func formatSteps(_ value: Int) -> String {
        return (stepsFormatter.string(from: NSNumber(value: value)) ?? "\(value)") + " steps"
    }
}
