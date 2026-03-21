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

    /// Full evaluation: anomalies + heart rate spikes + trend reversals + improvements.
    /// Suppressed within 1 hour of the daily summary time to avoid duplicate morning alerts.
    static func evaluate(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        previousTrends: [HealthMetric: TrendDirection],
        preferences: NotificationPreferences
    ) {
        // Morning suppression: skip real-time alerts within 1 hour of the daily summary
        // since the summary already includes the top anomaly info.
        if preferences.dailySummaryEnabled, isNearDailySummaryTime(preferences.dailySummaryTime) {
            return
        }

        // Hard cap: real-time alerts get at most 1 slot per day.
        // The daily summary (repeating) uses the other slot → total max 2/day.
        let maxPerDay = 1

        // 1. Anomaly-based alerts (critical only. warnings disabled by default)
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
        evaluateAnomalies(anomalies: anomalies, preferences: preferences, maxPerDay: 1)
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
                let triage = triageAssessment(for: anomaly)
                let isEscalatedSafetyCase = triage.level == .seekCare
                if isEscalatedSafetyCase,
                   (preferences.criticalAlertsEnabled || preferences.warningAlertsEnabled) {
                    sendWarningAlert(anomaly: anomaly, maxPerDay: maxPerDay)
                } else if preferences.warningAlertsEnabled,
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
            let triage = SafetyTriageEngine.assess(
                metric: .restingHeartRate,
                currentValue: latestRHR,
                baselineValue: avg7d > 0 ? avg7d : nil
            )

            if triage.level != .normal {
                sendSafetyTriageAlert(
                    assessment: triage,
                    identifier: "healthpulse.triage.restingHeartRate.\(triage.level.rawValue)",
                    maxPerDay: maxPerDay,
                    useHeartCap: true
                )
            } else if avg7d > 0 && latestRHR > avg7d * RemoteConfigManager.shared.heartRateSpikeMultiplier {
                // Fallback for milder spikes that do not cross triage thresholds.
                sendHeartRateAlert(
                    title: Copy.Notifications.restingHRTitle,
                    body: Copy.Notifications.restingHRElevated(current: Int(latestRHR), average: Int(avg7d)),
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
                let avg7d = hrSeries.mean(lastDays: 7)
                let triage = SafetyTriageEngine.assess(
                    metric: .heartRate,
                    currentValue: latestHR,
                    baselineValue: avg7d > 0 ? avg7d : nil
                )

                if triage.level != .normal {
                    sendSafetyTriageAlert(
                        assessment: triage,
                        identifier: "healthpulse.triage.heartRate.\(triage.level.rawValue)",
                        maxPerDay: maxPerDay,
                        useHeartCap: true
                    )
                } else if latestHR >= spikeThreshold {
                    sendHeartRateAlert(
                        title: Copy.Notifications.highHRTitle,
                        body: Copy.Notifications.highHRBody(current: Int(latestHR), threshold: Int(spikeThreshold)),
                        identifier: "healthpulse.spike.hr.high",
                        maxPerDay: maxPerDay
                    )
                } else if latestHR <= dropThreshold {
                    sendHeartRateAlert(
                        title: Copy.Notifications.lowHRTitle,
                        body: Copy.Notifications.lowHRBody(current: Int(latestHR), threshold: Int(dropThreshold)),
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
                    title: Copy.Notifications.hrvLowTitle,
                    body: Copy.Notifications.hrvLowBody(current: Int(latestHRV), dropPercent: Int(((avg7d - latestHRV) / avg7d) * 100)),
                    identifier: "healthpulse.spike.hrv.low",
                    maxPerDay: maxPerDay
                )
            }
        }

        // Check blood oxygen for dangerous drops
        if let spo2Series = timeSeries[.bloodOxygen],
           let latestSpO2 = spo2Series.latestValue {
            let avg7d = spo2Series.mean(lastDays: 7)
            let triage = SafetyTriageEngine.assess(
                metric: .bloodOxygen,
                currentValue: latestSpO2,
                baselineValue: avg7d > 0 ? avg7d : nil
            )

            if triage.level != .normal {
                sendSafetyTriageAlert(
                    assessment: triage,
                    identifier: "healthpulse.triage.bloodOxygen.\(triage.level.rawValue)",
                    maxPerDay: maxPerDay,
                    useHeartCap: true
                )
            } else if latestSpO2 < RemoteConfigManager.shared.spo2CriticalThreshold {
                sendHeartRateAlert(
                    title: Copy.Notifications.spo2CriticalTitle,
                    body: Copy.Notifications.spo2CriticalBody(value: String(format: "%.1f", latestSpO2)),
                    identifier: "healthpulse.spike.spo2.critical",
                    maxPerDay: maxPerDay
                )
            } else if latestSpO2 < RemoteConfigManager.shared.spo2WarningThreshold {
                sendHeartRateAlert(
                    title: Copy.Notifications.spo2WarningTitle,
                    body: Copy.Notifications.spo2WarningBody(value: String(format: "%.1f", latestSpO2)),
                    identifier: "healthpulse.spike.spo2.warning",
                    maxPerDay: maxPerDay
                )
            }
        }

        // Check respiratory rate spikes
        if let rrSeries = timeSeries[.respiratoryRate],
           let latestRR = rrSeries.latestValue {
            let avg7d = rrSeries.mean(lastDays: 7)
            let triage = SafetyTriageEngine.assess(
                metric: .respiratoryRate,
                currentValue: latestRR,
                baselineValue: avg7d > 0 ? avg7d : nil
            )

            if triage.level != .normal {
                sendSafetyTriageAlert(
                    assessment: triage,
                    identifier: "healthpulse.triage.respiratoryRate.\(triage.level.rawValue)",
                    maxPerDay: maxPerDay,
                    useHeartCap: true
                )
            } else if avg7d > 0 && latestRR > avg7d * RemoteConfigManager.shared.respiratoryRateSpikeMultiplier {
                sendHeartRateAlert(
                    title: Copy.Notifications.respiratoryRateTitle,
                    body: Copy.Notifications.respiratoryRateBody(current: String(format: "%.1f", latestRR), average: String(format: "%.1f", avg7d)),
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
                    title: Copy.Notifications.trendRecoveringTitle(metric: metric.displayName),
                    body: Copy.Notifications.trendRecoveringBody(metric: metric.displayName.lowercased()),
                    identifier: "healthpulse.reversal.\(metric.rawValue).recovering",
                    maxPerDay: maxPerDay
                )
            } else if previousDirection == .improving && currentDirection == .declining {
                NotificationManager.shared.scheduleNotification(
                    title: Copy.Notifications.trendDecliningTitle(metric: metric.displayName),
                    body: Copy.Notifications.trendDecliningBody(metric: metric.displayName.lowercased()),
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
                title: Copy.Notifications.improvementTitle(metric: metric.displayName, percent: String(format: "%.0f", abs(trend.weekOverWeekChange))),
                body: Copy.Notifications.improvementBody(metric: metric.displayName.lowercased()),
                identifier: "healthpulse.celebration.\(metric.rawValue)",
                maxPerDay: maxPerDay
            )
        }
    }

    // MARK: - Alert Senders

    private static func sendCriticalAlert(anomaly: AnomalyDetector.AnomalyResult, maxPerDay: Int) {
        let triage = triageAssessment(for: anomaly)
        if triage.level != .normal {
            sendSafetyTriageAlert(
                assessment: triage,
                identifier: "healthpulse.triage.\(anomaly.metric.rawValue).\(triage.level.rawValue)",
                maxPerDay: maxPerDay
            )
            return
        }

        let direction = anomaly.isAboveBaseline ? "above" : "below"
        let body = Copy.Notifications.anomalyBody(
            metric: anomaly.metric.displayName.lowercased(),
            deviation: String(format: "%.0f", abs(anomaly.deviationPercent)),
            direction: direction,
            current: String(format: "%.1f", anomaly.currentValue),
            unit: anomaly.metric.unit
        )
        sendAlert(
            title: Copy.Notifications.criticalMetric(anomaly.metric.displayName),
            body: body,
            identifier: "healthpulse.alert.\(anomaly.metric.rawValue).critical",
            maxPerDay: maxPerDay
        )
    }

    private static func sendWarningAlert(anomaly: AnomalyDetector.AnomalyResult, maxPerDay: Int) {
        let triage = triageAssessment(for: anomaly)
        if triage.level != .normal {
            sendSafetyTriageAlert(
                assessment: triage,
                identifier: "healthpulse.triage.\(anomaly.metric.rawValue).\(triage.level.rawValue)",
                maxPerDay: maxPerDay
            )
            return
        }

        let direction = anomaly.isAboveBaseline ? "above" : "below"
        let body = Copy.Notifications.anomalyWarningBody(
            metric: anomaly.metric.displayName.lowercased(),
            deviation: String(format: "%.0f", abs(anomaly.deviationPercent)),
            direction: direction
        )
        sendAlert(
            title: Copy.Notifications.warningMetric(anomaly.metric.displayName),
            body: body,
            identifier: "healthpulse.alert.\(anomaly.metric.rawValue).warning",
            maxPerDay: maxPerDay
        )
    }

    private static func sendSafetyTriageAlert(
        assessment: SafetyTriageAssessment,
        identifier: String,
        maxPerDay: Int,
        useHeartCap: Bool = false
    ) {
        guard assessment.level != .normal else { return }
        if useHeartCap {
            sendHeartRateAlert(
                title: assessment.alertTitle,
                body: assessment.alertBody,
                identifier: identifier,
                maxPerDay: maxPerDay
            )
        } else {
            sendAlert(
                title: assessment.alertTitle,
                body: assessment.alertBody,
                identifier: identifier,
                maxPerDay: maxPerDay
            )
        }
    }

    private static func triageAssessment(for anomaly: AnomalyDetector.AnomalyResult) -> SafetyTriageAssessment {
        SafetyTriageEngine.assess(
            metric: anomaly.metric,
            currentValue: anomaly.currentValue,
            baselineValue: anomaly.baselineValue
        )
    }

    private static func sendAlert(title: String, body: String, identifier: String, maxPerDay: Int) {
        guard !isOnCooldown(identifier: identifier) else { return }

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

    /// Returns true if the current time is within 1 hour of the daily summary time.
    private static func isNearDailySummaryTime(_ summaryTime: DateComponents) -> Bool {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let nowMinutes = hour * 60 + minute
        let summaryMinutes = (summaryTime.hour ?? 8) * 60 + (summaryTime.minute ?? 0)
        let diff = abs(nowMinutes - summaryMinutes)
        return diff <= 60 || diff >= (24 * 60 - 60) // handle midnight wrap
    }

    private static func hasSubdailyResolution(_ series: MetricTimeSeries) -> Bool {
        let calendar = Calendar.current
        return series.sortedSamples.contains { sample in
            let components = calendar.dateComponents([.hour, .minute, .second], from: sample.date)
            return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0 || (components.second ?? 0) != 0
        }
    }
}
