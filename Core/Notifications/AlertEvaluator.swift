import Foundation

/// Single source of truth mapping a clinical triage level to the notification
/// severity + cap-bypass it must fire at.
///
/// SOURCE: SafetyTriageLevel.minimumSeverity (Severity.swift) — the same
/// .seekCare->.critical / .monitor->.warning / .normal->.info ladder, with the
/// added cap-bypass decision. Thresholds are NOT duplicated here; they live in
/// SafetyTriageEngine.assess. .seekCare bypasses the daily cap because
/// life-safety alerts must never be dropped by the cap, fatigue, priority
/// filter, or kill switch (mirrors WatchMonitor's battery bypassCap precedent).
///
/// CLINICAL REVIEW REQUIRED: before shipping a .critical-priority alert, confirm
/// each .seekCare threshold in SafetyTriageEngine is clinically correct, and
/// that AlertEvaluator's direct SpO2/HR critical branches match those triage
/// thresholds so a dangerous reading never fires only as .warning.
enum AlertSeverityMapping {
    static func map(_ level: SafetyTriageLevel) -> (severity: Severity, bypassCap: Bool) {
        switch level {
        case .seekCare: return (.critical, true)
        case .monitor:  return (.warning, false)
        case .normal:   return (.info, false)
        }
    }
}

/// Manages cooldown tracking for alert deduplication
struct CooldownManager {
    private let defaults: UserDefaults
    private let prefix: String

    init(defaults: UserDefaults = .standard, prefix: String = AppKeys.Notifications.alertCooldownPrefix) {
        self.defaults = defaults
        self.prefix = prefix
    }

    func isOnCooldown(identifier: String, cooldownHours: Double) -> Bool {
        let key = prefix + identifier
        let lastFired = defaults.double(forKey: key)
        guard lastFired > 0 else { return false }
        let elapsed = Date().timeIntervalSince1970 - lastFired
        return elapsed < cooldownHours * 3600
    }

    func recordAlert(identifier: String) {
        let key = prefix + identifier
        defaults.set(Date().timeIntervalSince1970, forKey: key)
    }
}

/// Evaluates real-time health data and triggers critical/warning/spike/trend alerts.
///
/// A class (not a struct) so `evaluate` can set the per-evaluation
/// `suppressNonCritical` flag read by the send funnel. Only touched from the
/// MainActor housekeeping pass, so the whole type is pinned there: that flag is
/// set at the top of an evaluation and read by send calls further down it, which
/// is only sound while one executor owns the pass.
@MainActor
final class AlertEvaluator {

    private let cooldownManager: CooldownManager

    /// Set per evaluation when the kill switch or the morning summary window
    /// is active: non-critical alerts are muted but critical/life-safety ones
    /// still reach the notification manager (which never gates critical).
    private var suppressNonCritical = false

    /// Shared instance for production use, preserving the static call-site API
    static let shared = AlertEvaluator()

    init(cooldownManager: CooldownManager = CooldownManager()) {
        self.cooldownManager = cooldownManager
    }

    /// Minimum hours between repeated alerts for the same identifier
    private var cooldownHours: Double { RemoteConfigManager.shared.alertCooldownHours }

    // MARK: - Main Evaluation Entry Point

    /// Full evaluation: anomalies + heart rate spikes + trend reversals + improvements.
    /// Suppressed within 1 hour of the daily summary time to avoid duplicate morning alerts.
    func evaluate(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        previousTrends: [HealthMetric: TrendDirection],
        preferences: NotificationPreferences
    ) {
        // Hotfix kill switch — flip ON in Firebase Remote Config when threshold
        // tuning produces false-positive alert floods. Morning suppression —
        // skip real-time alerts within 1 hour of the daily summary since the
        // summary already includes the top anomaly info. NEITHER may drop
        // critical/life-safety alerts (a dangerous SpO2 reading must fire even
        // with the switch on), so instead of returning here the send funnel
        // mutes non-critical severities only.
        suppressNonCritical = RemoteConfigManager.shared.killAnomalyAlerts
            || (preferences.dailySummaryEnabled && isNearDailySummaryTime())

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

        // Trend reversals and improvement celebrations are never critical, so
        // they are skipped outright while non-critical alerts are muted. No
        // identifier exists yet at this point, so the family prefix stands in
        // for the batch and only enabled families are reported.
        if suppressNonCritical {
            if preferences.trendReversalAlertsEnabled {
                trackSuppressed(identifier: AppConstants.NotificationID.reversalPrefix, reason: "non_critical_muted")
            }
            if preferences.improvementAlertsEnabled {
                trackSuppressed(identifier: AppConstants.NotificationID.celebrationPrefix, reason: "non_critical_muted")
            }
            return
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

    // MARK: - Static convenience (preserves existing call sites)

    static func evaluate(
        anomalies: [AnomalyDetector.AnomalyResult],
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        timeSeries: [HealthMetric: MetricTimeSeries],
        previousTrends: [HealthMetric: TrendDirection],
        preferences: NotificationPreferences
    ) {
        shared.evaluate(anomalies: anomalies, trends: trends, timeSeries: timeSeries, previousTrends: previousTrends, preferences: preferences)
    }

    // MARK: - Anomaly Alerts

    private func evaluateAnomalies(
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

    private func evaluateHeartRateSpikes(
        timeSeries: [HealthMetric: MetricTimeSeries],
        spikeThreshold: Double,
        dropThreshold: Double,
        maxPerDay: Int
    ) {
        // Check resting heart rate for sustained elevation. Skip stale series so
        // an old dip (e.g. from an illness that already passed) can't fire a
        // fresh "seek care" alert days later when the watch finally syncs.
        if let rhrSeries = timeSeries[.restingHeartRate],
           let latestRHR = rhrSeries.latestValue,
           !rhrSeries.isStale(thresholdDays: 1) {
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
                    maxPerDay: maxPerDay,
                    severity: .warning
                )
            }
        }

        // Check heart rate for spikes above threshold. Stale series skipped for
        // the same reason as resting HR: a late backfill of an old reading must
        // not fire a fresh "seek care" alert about an episode already over.
        if let hrSeries = timeSeries[.heartRate],
           let latestHR = hrSeries.latestValue,
           !hrSeries.isStale(thresholdDays: 1) {
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
                        maxPerDay: maxPerDay,
                        severity: .warning
                    )
                } else if latestHR <= dropThreshold {
                    sendHeartRateAlert(
                        title: Copy.Notifications.lowHRTitle,
                        body: Copy.Notifications.lowHRBody(current: Int(latestHR), threshold: Int(dropThreshold)),
                        identifier: "healthpulse.spike.hr.low",
                        maxPerDay: maxPerDay,
                        severity: .warning
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
                    maxPerDay: maxPerDay,
                    severity: .warning
                )
            }
        }

        // Check blood oxygen for dangerous drops. Ignore implausible readings
        // (< 50%): the Apple Watch only reports SpO2 down to ~70%, so anything
        // lower is sensor noise or a unit glitch — never fire a scary medical
        // alert on it. This guards against firing on bad data of any kind.
        if let spo2Series = timeSeries[.bloodOxygen],
           let latestSpO2 = spo2Series.latestValue,
           latestSpO2 >= 50,
           !spo2Series.isStale(thresholdDays: 1) {
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
                // Direct dangerous SpO2 reading is life-safety equivalent to a
                // .seekCare triage, so it fires critical and bypasses the cap.
                sendHeartRateAlert(
                    title: Copy.Notifications.spo2CriticalTitle,
                    body: Copy.Notifications.spo2CriticalBody(value: String(format: "%.1f", latestSpO2)),
                    identifier: "healthpulse.spike.spo2.critical",
                    maxPerDay: maxPerDay,
                    severity: .critical,
                    bypassCap: true
                )
            } else if latestSpO2 < RemoteConfigManager.shared.spo2WarningThreshold {
                sendHeartRateAlert(
                    title: Copy.Notifications.spo2WarningTitle,
                    body: Copy.Notifications.spo2WarningBody(value: String(format: "%.1f", latestSpO2)),
                    identifier: "healthpulse.spike.spo2.warning",
                    maxPerDay: maxPerDay,
                    severity: .warning
                )
            }
        }

        // Check respiratory rate spikes. Stale series skipped: a five-day-old
        // reading of 31 syncing late would otherwise fire a critical, cap-
        // bypassing "contact a healthcare provider" push.
        if let rrSeries = timeSeries[.respiratoryRate],
           let latestRR = rrSeries.latestValue,
           !rrSeries.isStale(thresholdDays: 1) {
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
                    maxPerDay: maxPerDay,
                    severity: .warning
                )
            }
        }
    }

    // MARK: - Trend Reversal Alerts

    private func evaluateTrendReversals(
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
                    maxPerDay: maxPerDay,
                    severity: .info
                )
            } else if previousDirection == .improving && currentDirection == .declining {
                NotificationManager.shared.scheduleNotification(
                    title: Copy.Notifications.trendDecliningTitle(metric: metric.displayName),
                    body: Copy.Notifications.trendDecliningBody(metric: metric.displayName.lowercased()),
                    identifier: "healthpulse.reversal.\(metric.rawValue).declining",
                    maxPerDay: maxPerDay,
                    severity: .info
                )
            }
        }
    }

    // MARK: - Improvement Celebration

    private func evaluateImprovements(
        trends: [HealthMetric: TrendAnalyzer.TrendResult],
        maxPerDay: Int
    ) {
        let strongImprovements = trends.filter { _, trend in
            trend.direction == .improving && abs(trend.weekOverWeekChange) > 10
        }

        // Celebrate the most improved metric
        if let (metric, trend) = strongImprovements.max(by: { abs($0.value.weekOverWeekChange) < abs($1.value.weekOverWeekChange) }) {
            // `weekOverWeekChange` is the raw signed change and TrendAnalyzer
            // flips it only when classifying direction, so a lower-is-better
            // metric (resting heart rate, respiratory rate) improves by falling.
            // The word must follow the sign, not the magnitude.
            let change = trend.weekOverWeekChange
            let percent = String(format: "%.0f", abs(change))
            let title = change < 0
                ? Copy.Notifications.improvementTitleDown(metric: metric.displayName, percent: percent)
                : Copy.Notifications.improvementTitle(metric: metric.displayName, percent: percent)
            NotificationManager.shared.scheduleNotification(
                title: title,
                body: Copy.Notifications.improvementBody(metric: metric.displayName.lowercased()),
                identifier: "healthpulse.celebration.\(metric.rawValue)",
                maxPerDay: maxPerDay,
                severity: .info
            )
        }
    }

    // MARK: - Alert Senders

    private func sendCriticalAlert(anomaly: AnomalyDetector.AnomalyResult, maxPerDay: Int) {
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
        // Statistical anomaly already classified critical by AnomalyDetector.
        // .critical short-circuits the suppression gates; bypassCap stays false
        // so it still respects the daily budget (not clinical life-safety).
        sendAlert(
            title: Copy.Notifications.criticalMetric(anomaly.metric.displayName),
            body: body,
            identifier: "healthpulse.alert.\(anomaly.metric.rawValue).critical",
            maxPerDay: maxPerDay,
            severity: .critical
        )
    }

    private func sendWarningAlert(anomaly: AnomalyDetector.AnomalyResult, maxPerDay: Int) {
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
            maxPerDay: maxPerDay,
            severity: .warning
        )
    }

    private func sendSafetyTriageAlert(
        assessment: SafetyTriageAssessment,
        identifier: String,
        maxPerDay: Int,
        useHeartCap: Bool = false
    ) {
        guard assessment.level != .normal else { return }
        let mapping = AlertSeverityMapping.map(assessment.level)
        if useHeartCap {
            sendHeartRateAlert(
                title: assessment.alertTitle,
                body: assessment.alertBody,
                identifier: identifier,
                maxPerDay: maxPerDay,
                severity: mapping.severity,
                bypassCap: mapping.bypassCap
            )
        } else {
            sendAlert(
                title: assessment.alertTitle,
                body: assessment.alertBody,
                identifier: identifier,
                maxPerDay: maxPerDay,
                severity: mapping.severity,
                bypassCap: mapping.bypassCap
            )
        }
    }

    private func triageAssessment(for anomaly: AnomalyDetector.AnomalyResult) -> SafetyTriageAssessment {
        SafetyTriageEngine.assess(
            metric: anomaly.metric,
            currentValue: anomaly.currentValue,
            baselineValue: anomaly.baselineValue
        )
    }

    /// Mirrors the per-gate reporting NotificationManager does for its own
    /// gates. These two gates run BEFORE the manager is reached, so without this
    /// the cooldown dedupe (the largest attrition source in the alert funnel)
    /// and the kill switch drop alerts with nothing emitted at all.
    private func trackSuppressed(identifier: String, reason: String) {
        AppAnalytics.shared.trackNotificationSuppressed(
            type: NotificationManager.notificationType(identifier),
            identifier: identifier,
            reason: reason
        )
    }

    private func sendAlert(title: String, body: String, identifier: String, maxPerDay: Int, severity: Severity, bypassCap: Bool = false) {
        guard severity == .critical || !suppressNonCritical else {
            trackSuppressed(identifier: identifier, reason: "non_critical_muted")
            return
        }
        guard !cooldownManager.isOnCooldown(identifier: identifier, cooldownHours: cooldownHours) else {
            trackSuppressed(identifier: identifier, reason: "alert_cooldown")
            return
        }

        let scheduled = NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            maxPerDay: maxPerDay,
            severity: severity,
            bypassCap: bypassCap
        )
        // Cooldown only for a notification that actually exists; stamping a
        // suppressed schedule would dedupe alerts the user never saw.
        if scheduled {
            cooldownManager.recordAlert(identifier: identifier)
        }
    }

    private func sendHeartRateAlert(title: String, body: String, identifier: String, maxPerDay: Int, severity: Severity, bypassCap: Bool = false) {
        guard severity == .critical || !suppressNonCritical else {
            trackSuppressed(identifier: identifier, reason: "non_critical_muted")
            return
        }
        guard !cooldownManager.isOnCooldown(identifier: identifier, cooldownHours: cooldownHours) else {
            trackSuppressed(identifier: identifier, reason: "alert_cooldown")
            return
        }

        let scheduled = NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            maxPerDay: min(RemoteConfigManager.shared.heartAlertCap, maxPerDay),  // Heart alerts capped, but respect user's lower cap
            severity: severity,
            bypassCap: bypassCap
        )
        // Cooldown only for a notification that actually exists; stamping a
        // suppressed schedule would dedupe alerts the user never saw.
        if scheduled {
            cooldownManager.recordAlert(identifier: identifier)
        }
    }

    /// Returns true if the current time is within 1 hour of the daily summary
    /// time. Reads the wake anchor the summary is actually scheduled from, not a
    /// separate preference: the two drifted apart and the mute window sat on an
    /// hour no summary ever fired at.
    private func isNearDailySummaryTime() -> Bool {
        let cal = Date.cal
        let now = Date()
        let summaryTime = WakeUpTimeDetector.persistedWakeTime
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let nowMinutes = hour * 60 + minute
        let summaryMinutes = summaryTime.hour * 60 + summaryTime.minute
        let diff = abs(nowMinutes - summaryMinutes)
        return diff <= 60 || diff >= (24 * 60 - 60) // handle midnight wrap
    }

    private func hasSubdailyResolution(_ series: MetricTimeSeries) -> Bool {
        let calendar = Date.cal
        return series.sortedSamples.contains { sample in
            let components = calendar.dateComponents([.hour, .minute, .second], from: sample.date)
            return (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0 || (components.second ?? 0) != 0
        }
    }
}
