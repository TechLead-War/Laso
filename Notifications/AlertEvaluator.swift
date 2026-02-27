import Foundation

/// Evaluates real-time health data and triggers critical/warning/spike/trend alerts
struct AlertEvaluator {

    /// Minimum hours between repeated alerts for the same identifier
    private static var cooldownHours: Double { RemoteConfigManager.shared.alertCooldownHours }

    /// Check if an alert was recently sent (within cooldown window)
    private static func isOnCooldown(identifier: String) -> Bool {
        let key = AppKeys.Notifications.alertCooldownPrefix + identifier
        let lastFired = UserDefaults.standard.double(forKey: key)
        guard lastFired > 0 else { return false }
        let elapsed = Date().timeIntervalSince1970 - lastFired
        return elapsed < cooldownHours * 3600
    }

    /// Record that an alert was sent
    private static func recordAlert(identifier: String) {
        let key = AppKeys.Notifications.alertCooldownPrefix + identifier
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
    }

    // MARK: - Main Evaluation Entry Point

    /// Full evaluation: anomalies + heart rate spikes + trend reversals + improvements
    static func evaluate(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        previousTrends: [HealthMetric: TrendDirection],
        preferences: NotificationPreferences
    ) {
        let maxPerDay = preferences.maxNotificationsPerDay

        // 1. Anomaly-based alerts (critical + warning for ALL configured metrics)
        evaluateAnomalies(anomalies: anomalies, preferences: preferences, maxPerDay: maxPerDay)

        // 2. Heart rate spike/drop detection
        if preferences.heartRateSpikeAlertsEnabled {
            evaluateHeartRateSpikes(
                timeSeries: timeSeries,
                spikeThreshold: preferences.heartRateSpikeThreshold,
                dropThreshold: preferences.heartRateDropThreshold,
                maxPerDay: maxPerDay
            )
        }

        // 3. Trend reversal alerts
        if preferences.trendReversalAlertsEnabled {
            evaluateTrendReversals(
                currentTrends: trends,
                previousTrends: previousTrends,
                maxPerDay: maxPerDay
            )
        }

        // 4. Improvement celebration alerts
        if preferences.improvementAlertsEnabled {
            evaluateImprovements(trends: trends, maxPerDay: maxPerDay)
        }
    }

    /// Legacy entry point for backward compatibility
    static func evaluate(
        anomalies: [AnomalyDetector.AnomalyResult],
        preferences: NotificationPreferences
    ) {
        evaluateAnomalies(anomalies: anomalies, preferences: preferences, maxPerDay: preferences.maxNotificationsPerDay)
    }

    // MARK: - Anomaly Alerts

    private static func evaluateAnomalies(
        anomalies: [AnomalyDetector.AnomalyResult],
        preferences: NotificationPreferences,
        maxPerDay: Int
    ) {
        for anomaly in anomalies {
            switch anomaly.severity {
            case .critical:
                if preferences.criticalAlertsEnabled {
                    sendCriticalAlert(anomaly: anomaly, maxPerDay: maxPerDay)
                }
            case .warning:
                if preferences.warningAlertsEnabled,
                   preferences.warningAlertMetrics.contains(anomaly.metric) {
                    sendWarningAlert(anomaly: anomaly, maxPerDay: maxPerDay)
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
        dropThreshold: Double,
        maxPerDay: Int
    ) {
        // Check resting heart rate for sustained elevation
        if let rhrSeries = timeSeries[.restingHeartRate],
           let latestRHR = rhrSeries.latestValue {
            let avg7d = rhrSeries.mean(lastDays: 7)
            // Alert if RHR suddenly jumped 15%+ above 7-day average
            if avg7d > 0 && latestRHR > avg7d * RemoteConfigManager.shared.heartRateSpikeMultiplier {
                sendHeartRateAlert(
                    title: "Resting Heart Rate Elevated",
                    body: "Your resting heart rate (\(Int(latestRHR)) bpm) is significantly above your recent average (\(Int(avg7d)) bpm). Consider rest or consult your doctor if persistent.",
                    identifier: "healthpulse.spike.rhr.elevated",
                    maxPerDay: maxPerDay
                )
            }
        }

        // Check heart rate for spikes above threshold
        if let hrSeries = timeSeries[.heartRate],
           let latestHR = hrSeries.latestValue {
            // Threshold spikes require sub-daily granularity; skip if only daily aggregates exist.
            if hasSubdailyResolution(hrSeries) {
                if latestHR >= spikeThreshold {
                    sendHeartRateAlert(
                        title: "High Heart Rate Detected",
                        body: "Your heart rate reached \(Int(latestHR)) bpm (threshold: \(Int(spikeThreshold)) bpm). If you weren't exercising, consider medical attention.",
                        identifier: "healthpulse.spike.hr.high",
                        maxPerDay: maxPerDay
                    )
                }
                if latestHR <= dropThreshold {
                    sendHeartRateAlert(
                        title: "Low Heart Rate Detected",
                        body: "Your heart rate dropped to \(Int(latestHR)) bpm (threshold: \(Int(dropThreshold)) bpm). Seek medical attention if you feel dizzy or faint.",
                        identifier: "healthpulse.spike.hr.low",
                        maxPerDay: maxPerDay
                    )
                }
            }
        }

        // Check HRV for sudden drops (stress/overtraining indicator)
        if let hrvSeries = timeSeries[.heartRateVariability],
           let latestHRV = hrvSeries.latestValue {
            let avg7d = hrvSeries.mean(lastDays: 7)
            // Alert if HRV dropped 30%+ below 7-day average
            if avg7d > 0 && latestHRV < avg7d * RemoteConfigManager.shared.hrvDropMultiplier {
                sendHeartRateAlert(
                    title: "HRV Significantly Low",
                    body: "Your heart rate variability (\(Int(latestHRV)) ms) dropped \(Int(((avg7d - latestHRV) / avg7d) * 100))% below your recent average. This may indicate stress or overtraining.",
                    identifier: "healthpulse.spike.hrv.low",
                    maxPerDay: maxPerDay
                )
            }
        }

        // Check blood oxygen for dangerous drops
        if let spo2Series = timeSeries[.bloodOxygen],
           let latestSpO2 = spo2Series.latestValue {
            if latestSpO2 < RemoteConfigManager.shared.spo2CriticalThreshold {
                sendHeartRateAlert(
                    title: "Blood Oxygen Critically Low",
                    body: "Your blood oxygen is \(String(format: "%.1f", latestSpO2))%. Values below 92% may require immediate medical attention.",
                    identifier: "healthpulse.spike.spo2.critical",
                    maxPerDay: maxPerDay
                )
            } else if latestSpO2 < RemoteConfigManager.shared.spo2WarningThreshold {
                sendHeartRateAlert(
                    title: "Blood Oxygen Below Normal",
                    body: "Your blood oxygen is \(String(format: "%.1f", latestSpO2))%. Normal range is 95-100%. Monitor closely.",
                    identifier: "healthpulse.spike.spo2.warning",
                    maxPerDay: maxPerDay
                )
            }
        }

        // Check respiratory rate spikes
        if let rrSeries = timeSeries[.respiratoryRate],
           let latestRR = rrSeries.latestValue {
            let avg7d = rrSeries.mean(lastDays: 7)
            if avg7d > 0 && latestRR > avg7d * RemoteConfigManager.shared.respiratoryRateSpikeMultiplier {
                sendHeartRateAlert(
                    title: "Respiratory Rate Elevated",
                    body: "Your respiratory rate (\(String(format: "%.1f", latestRR)) br/min) is elevated compared to your average (\(String(format: "%.1f", avg7d)) br/min).",
                    identifier: "healthpulse.spike.rr.elevated",
                    maxPerDay: maxPerDay
                )
            }
        }
    }

    // MARK: - Trend Reversal Alerts

    private static func evaluateTrendReversals(
        currentTrends: [HealthMetric: TrendAnalyzer.TrendResult],
        previousTrends: [HealthMetric: TrendDirection],
        maxPerDay: Int
    ) {
        for (metric, currentTrend) in currentTrends {
            guard let previousDirection = previousTrends[metric] else { continue }
            let currentDirection = currentTrend.direction

            // Alert only on meaningful reversals
            if previousDirection == .declining && currentDirection == .improving {
                NotificationManager.shared.scheduleNotification(
                    title: "\(metric.displayName) Recovering",
                    body: "Good news! Your \(metric.displayName.lowercased()) was declining but is now trending upward.",
                    identifier: "healthpulse.reversal.\(metric.rawValue).recovering",
                    maxPerDay: maxPerDay
                )
            } else if previousDirection == .improving && currentDirection == .declining {
                NotificationManager.shared.scheduleNotification(
                    title: "\(metric.displayName) Needs Attention",
                    body: "Your \(metric.displayName.lowercased()) was improving but has started declining. Check your recent habits.",
                    identifier: "healthpulse.reversal.\(metric.rawValue).declining",
                    maxPerDay: maxPerDay
                )
            }
        }
    }

    // MARK: - Improvement Celebration

    private static func evaluateImprovements(
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        maxPerDay: Int
    ) {
        let strongImprovements = trends.filter { _, trend in
            trend.direction == .improving && abs(trend.weekOverWeekChange) > 10
        }

        // Celebrate the most improved metric
        if let (metric, trend) = strongImprovements.max(by: { abs($0.value.weekOverWeekChange) < abs($1.value.weekOverWeekChange) }) {
            NotificationManager.shared.scheduleNotification(
                title: "\(metric.displayName) Up \(String(format: "%.0f", abs(trend.weekOverWeekChange)))%!",
                body: "Your \(metric.displayName.lowercased()) improved significantly this week. Keep up the great work!",
                identifier: "healthpulse.celebration.\(metric.rawValue)",
                maxPerDay: maxPerDay
            )
        }
    }

    // MARK: - Alert Senders

    private static func sendCriticalAlert(anomaly: AnomalyDetector.AnomalyResult, maxPerDay: Int) {
        let identifier = "healthpulse.alert.\(anomaly.metric.rawValue).critical"
        guard !isOnCooldown(identifier: identifier) else { return }

        let title = "Critical: \(anomaly.metric.displayName)"
        let direction = anomaly.isAboveBaseline ? "above" : "below"
        let body = "Your \(anomaly.metric.displayName.lowercased()) is \(String(format: "%.0f", abs(anomaly.deviationPercent)))% \(direction) your baseline. Current: \(String(format: "%.1f", anomaly.currentValue)) \(anomaly.metric.unit)"

        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            maxPerDay: maxPerDay
        )
        recordAlert(identifier: identifier)
    }

    private static func sendWarningAlert(anomaly: AnomalyDetector.AnomalyResult, maxPerDay: Int) {
        let identifier = "healthpulse.alert.\(anomaly.metric.rawValue).warning"
        guard !isOnCooldown(identifier: identifier) else { return }

        let title = "Warning: \(anomaly.metric.displayName)"
        let direction = anomaly.isAboveBaseline ? "above" : "below"
        let body = "Your \(anomaly.metric.displayName.lowercased()) is \(String(format: "%.0f", abs(anomaly.deviationPercent)))% \(direction) your baseline."

        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            maxPerDay: maxPerDay
        )
        recordAlert(identifier: identifier)
    }

    private static func sendHeartRateAlert(title: String, body: String, identifier: String, maxPerDay: Int) {
        guard !isOnCooldown(identifier: identifier) else { return }

        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            maxPerDay: min(RemoteConfigManager.shared.heartAlertCap, maxPerDay)  // Heart alerts capped, but respect user's lower cap
        )
        recordAlert(identifier: identifier)
    }

    private static func hasSubdailyResolution(_ series: MetricTimeSeries) -> Bool {
        let calendar = Calendar.current
        return series.sortedSamples.contains { sample in
            let components = calendar.dateComponents([.hour, .minute, .second], from: sample.date)
            return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0 || (components.second ?? 0) != 0
        }
    }
}
