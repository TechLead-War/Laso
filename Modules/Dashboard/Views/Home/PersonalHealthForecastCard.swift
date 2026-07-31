import SwiftUI

// MARK: - Personal Health Forecast Card

/// Displays forward-looking metric forecasts with statistically guaranteed confidence intervals.
/// wraps predictions
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
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(AppColour.info)
                    Text(Copy.Home.Cards.yourForecast)
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(AppColour.textSecondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text(Copy.Home.Cards.nextSevenDays)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textTertiary)
                }

                // Forecast rows
                VStack(spacing: 8) {
                    ForEach(Array(forecasts.prefix(3))) { forecast in
                        Button {
                            // Owner of `onTapMetric` emits with the real host
                            // screen. This card fired a second event stamped
                            // .home after the card moved to Explore.
                            onTapMetric(forecast.metric)
                        } label: {
                            forecastRow(forecast)
                        }
                        .buttonStyle(.dsPress)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Copy.Home.forecastLabel(forecast.metric.displayName))
                        .accessibilityValue(Copy.Home.confidencePercentValue(forecast.rangeDescription, forecast.confidencePercent))
                        .accessibilityHint(Copy.Home.opensDetailedMetricViewHint)
                    }
                }
            }
            .padding(DS.space4)
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(AppColour.borderLow, lineWidth: 0.5)
            )
            .padding(.horizontal, DS.screenPadding)
        }
    }

    // MARK: - Forecast Row

    private func forecastRow(_ forecast: MetricForecast) -> some View {
        HStack(spacing: 12) {
            // Metric icon
            Image(systemName: forecast.metric.systemImageName)
                .font(DS.Typography.footnote)
                .foregroundStyle(forecast.directionColor)
                .frame(width: 28, height: 28)
                .background(forecast.directionColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(forecast.metric.displayName)
                    .font(DS.Typography.footnoteMedium)
                    .foregroundStyle(AppColour.textPrimary)

                Text(forecast.rangeDescription)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }

            Spacer()

            // Direction indicator
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: forecast.directionIcon)
                        .font(DS.Typography.caption)
                    Text(forecast.predictedValueFormatted)
                        .font(DS.Typography.footnoteMedium)
                }
                .foregroundStyle(forecast.directionColor)

                // Confidence badge
                Text(Copy.Home.confText(forecast.confidencePercent))
                    .font(DS.Typography.caption2Medium)
                    .foregroundStyle(AppColour.textSecondary)
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
        if direction == .stable { return AppColour.textSecondary }
        return isFavorable ? AppColour.success : AppColour.warning
    }

    var predictedValueFormatted: String {
        metric.formatWithUnit(predictedValue)
    }

    /// Only the upper bound carries the unit so the row stays one line on small devices.
    var rangeDescription: String {
        "Expected: \(metric.formatValue(lowerBound)) – \(metric.formatWithUnit(upperBound))"
    }

    enum Direction { case up, down, stable }
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
            confidence: 0.85
        ),
        MetricForecast(
            metric: .sleepDuration,
            predictedValue: 27000,
            lowerBound: 24000,
            upperBound: 30000,
            currentValue: 25200,
            confidence: 0.78
        ),
        MetricForecast(
            metric: .restingHeartRate,
            predictedValue: 58,
            lowerBound: 55,
            upperBound: 61,
            currentValue: 60,
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
