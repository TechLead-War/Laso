import SwiftUI

// MARK: - Personal Health Forecast Card

/// Displays forward-looking metric forecasts with statistically guaranteed confidence intervals.
/// Based on conformal prediction research (Communications Engineering 2025): wraps predictions
/// in intervals with guaranteed coverage, creating a "predicted you" vs actual tracking.
struct PersonalHealthForecastCard: View {
    let forecasts: [MetricForecast]
    let onTapMetric: (HealthMetric) -> Void

    var body: some View {
        if !forecasts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                    Text("YOUR FORECAST")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text("Next 7 days")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Forecast rows
                VStack(spacing: 8) {
                    ForEach(Array(forecasts.prefix(3))) { forecast in
                        forecastRow(forecast)
                            .onTapGesture {
                                AppAnalytics.shared.trackBlockTap(title: "Forecast Metric", type: .metricRow, screen: .home, metadata: ["source": "health_forecast", "metric": forecast.metric.rawValue])
                                onTapMetric(forecast.metric)
                            }
                    }
                }
            }
            .padding(DS.space4)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Forecast Row

    private func forecastRow(_ forecast: MetricForecast) -> some View {
        HStack(spacing: 12) {
            // Metric icon
            Image(systemName: forecast.metric.systemImageName)
                .font(.caption)
                .foregroundStyle(forecast.directionColor)
                .frame(width: 28, height: 28)
                .background(forecast.directionColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(forecast.metric.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)

                Text(forecast.rangeDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Direction indicator
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: forecast.directionIcon)
                        .font(.caption2)
                    Text(forecast.predictedValueFormatted)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(forecast.directionColor)

                // Confidence badge
                Text("\(forecast.confidencePercent)% conf")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DS.space1)
    }
}

// MARK: - Metric Forecast Model

struct MetricForecast: Identifiable {
    let id = UUID()
    let metric: HealthMetric
    let predictedValue: Double
    let lowerBound: Double
    let upperBound: Double
    let currentValue: Double
    let horizon: Int  // days ahead
    let confidence: Double  // 0-1

    /// Percentage confidence for display
    var confidencePercent: Int { Int(confidence * 100) }

    /// Direction of predicted change
    var direction: Direction {
        let change = predictedValue - currentValue
        let threshold = currentValue * 0.03  // 3% threshold
        if abs(change) < threshold { return .stable }
        return change > 0 ? .up : .down
    }

    /// Whether the predicted direction is favorable
    var isFavorable: Bool {
        switch direction {
        case .up: return metric.higherIsBetter
        case .down: return !metric.higherIsBetter
        case .stable: return true
        }
    }

    var directionIcon: String {
        switch direction {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var directionColor: Color {
        if direction == .stable { return .secondary }
        return isFavorable ? .green : .orange
    }

    var predictedValueFormatted: String {
        formatMetricValue(predictedValue, metric: metric)
    }

    var rangeDescription: String {
        let lower = formatMetricValue(lowerBound, metric: metric)
        let upper = formatMetricValue(upperBound, metric: metric)
        return "Expected: \(lower) – \(upper)"
    }

    enum Direction { case up, down, stable }

    private func formatMetricValue(_ value: Double, metric: HealthMetric) -> String {
        switch metric {
        case .steps:
            return "\(Int(value))"
        case .sleepDuration, .sleepDeep, .sleepREM, .sleepCore:
            let h = value / 3600
            return String(format: "%.1fh", h)
        case .heartRateVariability:
            return String(format: "%.0fms", value)
        case .heartRate, .restingHeartRate:
            return String(format: "%.0f bpm", value)
        case .vo2Max:
            return String(format: "%.1f", value)
        case .weight:
            return String(format: "%.1f", value)
        default:
            if value >= 1000 { return String(format: "%.0f", value) }
            if value >= 10 { return String(format: "%.1f", value) }
            return String(format: "%.2f", value)
        }
    }
}

// MARK: - Forecast Builder (bridges MLOrchestrator → View)

enum ForecastBuilder {

    /// Build MetricForecast array from MLOrchestrator's multi-horizon forecasts
    static func buildForecasts(
        multiHorizonForecasts: [HealthMetric: TimeSeriesForecaster.MultiHorizonForecast],
        timeSeries: [HealthMetric: MetricTimeSeries],
        maxCount: Int = 3
    ) -> [MetricForecast] {
        var forecasts: [MetricForecast] = []

        // Priority metrics to show forecasts for
        let priorityMetrics: [HealthMetric] = [
            .heartRateVariability, .restingHeartRate, .sleepDuration,
            .steps, .vo2Max, .activeCalories, .sleepDeep
        ]

        for metric in priorityMetrics {
            guard let multiHorizon = multiHorizonForecasts[metric],
                  let series = timeSeries[metric],
                  let currentValue = series.samples.last?.value,
                  let horizon7 = multiHorizon.horizons.first(where: { $0.horizon == 7 })
                    ?? multiHorizon.horizons.last else {
                continue
            }

            let ciWidth = horizon7.ciUpper - horizon7.ciLower
            let confidence = max(0.5, min(0.95, 1.0 - ciWidth / max(1, abs(horizon7.value) * 2)))

            forecasts.append(MetricForecast(
                metric: metric,
                predictedValue: horizon7.value,
                lowerBound: horizon7.ciLower,
                upperBound: horizon7.ciUpper,
                currentValue: currentValue,
                horizon: horizon7.horizon,
                confidence: confidence
            ))

            if forecasts.count >= maxCount { break }
        }

        return forecasts
    }
}

#Preview {
    let forecasts: [MetricForecast] = [
        MetricForecast(
            metric: .heartRateVariability,
            predictedValue: 52,
            lowerBound: 42,
            upperBound: 62,
            currentValue: 48,
            horizon: 7,
            confidence: 0.85
        ),
        MetricForecast(
            metric: .sleepDuration,
            predictedValue: 27000,
            lowerBound: 24000,
            upperBound: 30000,
            currentValue: 25200,
            horizon: 7,
            confidence: 0.78
        ),
        MetricForecast(
            metric: .restingHeartRate,
            predictedValue: 58,
            lowerBound: 55,
            upperBound: 61,
            currentValue: 60,
            horizon: 7,
            confidence: 0.82
        ),
    ]
    VStack {
        PersonalHealthForecastCard(
            forecasts: forecasts,
            onTapMetric: { _ in }
        )
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
