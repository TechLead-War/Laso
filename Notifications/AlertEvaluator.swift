import Foundation

/// Evaluates real-time health data and triggers critical/warning/spike/trend alerts
struct AlertEvaluator {

    // MARK: - Main Evaluation Entry Point

    /// Full evaluation: anomalies + heart rate spikes + trend reversals + improvements
    static func evaluate(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        previousTrends: [HealthMetric: TrendDirection],
        preferences: NotificationPreferences
    ) {
        // 1. Anomaly-based alerts (critical + warning for ALL configured metrics)
        evaluateAnomalies(anomalies: anomalies, preferences: preferences)

        // 2. Heart rate spike/drop detection
        if preferences.heartRateSpikeAlertsEnabled {
            evaluateHeartRateSpikes(
                timeSeries: timeSeries,
                spikeThreshold: preferences.heartRateSpikeThreshold,
                dropThreshold: preferences.heartRateDropThreshold
            )
        }

        // 3. Trend reversal alerts
        if preferences.trendReversalAlertsEnabled {
            evaluateTrendReversals(
                currentTrends: trends,
                previousTrends: previousTrends
            )
        }

        // 4. Improvement celebration alerts
        if preferences.improvementAlertsEnabled {
            evaluateImprovements(trends: trends)
        }
    }

    /// Legacy entry point for backward compatibility
    static func evaluate(
        anomalies: [AnomalyDetector.AnomalyResult],
        preferences: NotificationPreferences
    ) {
        evaluateAnomalies(anomalies: anomalies, preferences: preferences)
    }

    // MARK: - Anomaly Alerts

    private static func evaluateAnomalies(
        anomalies: [AnomalyDetector.AnomalyResult],
        preferences: NotificationPreferences
    ) {
        for anomaly in anomalies {
            switch anomaly.severity {
            case .critical:
                if preferences.criticalAlertsEnabled {
                    sendCriticalAlert(anomaly: anomaly)
                }
            case .warning:
                if preferences.warningAlertsEnabled,
                   preferences.warningAlertMetrics.contains(anomaly.metric) {
                    sendWarningAlert(anomaly: anomaly)
                }
            case .info:
                break
            }
        }
    }

    // MARK: - Heart Rate Spike/Drop Detection

    private static func evaluateHeartRateSpikes(
        timeSeries: [HealthMetric: MetricTimeSeries],
        spikeThreshold: Double,
        dropThreshold: Double
    ) {
        // Check resting heart rate for sustained elevation
        if let rhrSeries = timeSeries[.restingHeartRate],
           let latestRHR = rhrSeries.latestValue {
            let avg7d = rhrSeries.mean(lastDays: 7)
            // Alert if RHR suddenly jumped 15%+ above 7-day average
            if avg7d > 0 && latestRHR > avg7d * 1.15 {
                sendHeartRateAlert(
                    title: "Resting Heart Rate Elevated",
                    body: "Your resting heart rate (\(Int(latestRHR)) bpm) is significantly above your recent average (\(Int(avg7d)) bpm). Consider rest or consult your doctor if persistent.",
                    identifier: "healthpulse.spike.rhr.elevated"
                )
            }
        }

        // Check heart rate for spikes above threshold
        if let hrSeries = timeSeries[.heartRate],
           let latestHR = hrSeries.latestValue {
            if latestHR >= spikeThreshold {
                sendHeartRateAlert(
                    title: "High Heart Rate Detected",
                    body: "Your heart rate reached \(Int(latestHR)) bpm (threshold: \(Int(spikeThreshold)) bpm). If you weren't exercising, consider medical attention.",
                    identifier: "healthpulse.spike.hr.high"
                )
            }
            if latestHR <= dropThreshold {
                sendHeartRateAlert(
                    title: "Low Heart Rate Detected",
                    body: "Your heart rate dropped to \(Int(latestHR)) bpm (threshold: \(Int(dropThreshold)) bpm). Seek medical attention if you feel dizzy or faint.",
                    identifier: "healthpulse.spike.hr.low"
                )
            }
        }

        // Check HRV for sudden drops (stress/overtraining indicator)
        if let hrvSeries = timeSeries[.heartRateVariability],
           let latestHRV = hrvSeries.latestValue {
            let avg7d = hrvSeries.mean(lastDays: 7)
            // Alert if HRV dropped 30%+ below 7-day average
            if avg7d > 0 && latestHRV < avg7d * 0.7 {
                sendHeartRateAlert(
                    title: "HRV Significantly Low",
                    body: "Your heart rate variability (\(Int(latestHRV)) ms) dropped \(Int(((avg7d - latestHRV) / avg7d) * 100))% below your recent average. This may indicate stress or overtraining.",
                    identifier: "healthpulse.spike.hrv.low"
                )
            }
        }

        // Check blood oxygen for dangerous drops
        if let spo2Series = timeSeries[.bloodOxygen],
           let latestSpO2 = spo2Series.latestValue {
            if latestSpO2 < 92 {
                sendHeartRateAlert(
                    title: "Blood Oxygen Critically Low",
                    body: "Your blood oxygen is \(String(format: "%.1f", latestSpO2))%. Values below 92% may require immediate medical attention.",
                    identifier: "healthpulse.spike.spo2.critical"
                )
            } else if latestSpO2 < 95 {
                sendHeartRateAlert(
                    title: "Blood Oxygen Below Normal",
                    body: "Your blood oxygen is \(String(format: "%.1f", latestSpO2))%. Normal range is 95-100%. Monitor closely.",
                    identifier: "healthpulse.spike.spo2.warning"
                )
            }
        }

        // Check respiratory rate spikes
        if let rrSeries = timeSeries[.respiratoryRate],
           let latestRR = rrSeries.latestValue {
            let avg7d = rrSeries.mean(lastDays: 7)
            if avg7d > 0 && latestRR > avg7d * 1.25 {
                sendHeartRateAlert(
                    title: "Respiratory Rate Elevated",
                    body: "Your respiratory rate (\(String(format: "%.1f", latestRR)) br/min) is elevated compared to your average (\(String(format: "%.1f", avg7d)) br/min).",
                    identifier: "healthpulse.spike.rr.elevated"
                )
            }
        }
    }

    // MARK: - Trend Reversal Alerts

    private static func evaluateTrendReversals(
        currentTrends: [HealthMetric: TrendAnalyzer.TrendResult],
        previousTrends: [HealthMetric: TrendDirection]
    ) {
        for (metric, currentTrend) in currentTrends {
            guard let previousDirection = previousTrends[metric] else { continue }
            let currentDirection = currentTrend.direction

            // Alert only on meaningful reversals
            if previousDirection == .declining && currentDirection == .improving {
                NotificationManager.shared.scheduleNotification(
                    title: "\(metric.displayName) Recovering",
                    body: "Good news! Your \(metric.displayName.lowercased()) was declining but is now trending upward.",
                    identifier: "healthpulse.reversal.\(metric.rawValue).recovering"
                )
            } else if previousDirection == .improving && currentDirection == .declining {
                NotificationManager.shared.scheduleNotification(
                    title: "\(metric.displayName) Needs Attention",
                    body: "Your \(metric.displayName.lowercased()) was improving but has started declining. Check your recent habits.",
                    identifier: "healthpulse.reversal.\(metric.rawValue).declining"
                )
            }
        }
    }

    // MARK: - Improvement Celebration

    private static func evaluateImprovements(
        trends: [HealthMetric: TrendAnalyzer.TrendResult]
    ) {
        let strongImprovements = trends.filter { _, trend in
            trend.direction == .improving && abs(trend.weekOverWeekChange) > 10
        }

        // Celebrate the most improved metric
        if let (metric, trend) = strongImprovements.max(by: { abs($0.value.weekOverWeekChange) < abs($1.value.weekOverWeekChange) }) {
            NotificationManager.shared.scheduleNotification(
                title: "\(metric.displayName) Up \(String(format: "%.0f", abs(trend.weekOverWeekChange)))%!",
                body: "Your \(metric.displayName.lowercased()) improved significantly this week. Keep up the great work!",
                identifier: "healthpulse.celebration.\(metric.rawValue)"
            )
        }
    }

    // MARK: - Alert Senders

    private static func sendCriticalAlert(anomaly: AnomalyDetector.AnomalyResult) {
        let title = "Critical: \(anomaly.metric.displayName)"
        let direction = anomaly.isAboveBaseline ? "above" : "below"
        let body = "Your \(anomaly.metric.displayName.lowercased()) is \(String(format: "%.0f", abs(anomaly.deviationPercent)))% \(direction) your baseline. Current: \(String(format: "%.1f", anomaly.currentValue)) \(anomaly.metric.unit)"

        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: "healthpulse.alert.\(anomaly.metric.rawValue).critical"
        )
    }

    private static func sendWarningAlert(anomaly: AnomalyDetector.AnomalyResult) {
        let title = "Warning: \(anomaly.metric.displayName)"
        let direction = anomaly.isAboveBaseline ? "above" : "below"
        let body = "Your \(anomaly.metric.displayName.lowercased()) is \(String(format: "%.0f", abs(anomaly.deviationPercent)))% \(direction) your baseline."

        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: "healthpulse.alert.\(anomaly.metric.rawValue).warning"
        )
    }

    private static func sendHeartRateAlert(title: String, body: String, identifier: String) {
        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            maxPerDay: 3  // Heart alerts are high-priority but capped
        )
    }
}
