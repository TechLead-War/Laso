import Foundation
import HealthKit
import UserNotifications

/// Schedules the post-onboarding engagement notification sequence (Days 1 to 7).
///
/// ──────────────────────────────────────────────────────────────────────
///  Model: ACTIVATION GATED  (Headspace pattern, not calendar drip)
/// ──────────────────────────────────────────────────────────────────────
///
/// Each day is grounded in behavioral science AND in whether the user has
/// hit the required activation moment. A day only fires once its gate is
/// satisfied. If the gate is not satisfied, the day is delayed until a
/// bounded fallback window (to avoid silently dropping users).
///
/// - Day 1: Implementation Intention (calendar, wake up anchor). No gate.
/// - Day 2: Variable Reward (recovery score reveal).
///          Gate: `firstRecoveryScoreSeen`. Fallback: Day 4 hard send.
/// - Day 3: Zeigarnik Effect (sleep pattern tease).
///          Gate: at least one app open in the past 48h.
/// - Day 5: Goal Gradient (personalization progress).
///          Gate: `secondRecoveryScoreSeen`. Fallback: soft copy variant
///          that does not claim personalization has advanced.
/// - Day 7: Loss Aversion (discovered patterns). Always fires, this is
///          the lapsing user nudge.
///
/// When a user goes dark for 48+h, the sequence is paused and the
/// `ReengagementScheduler` track takes over. Paused sequences resume on
/// the next app launch.
///
/// Gate decisions are logged via `AppAnalytics.trackNotificationSuppressed`
/// with reason `"gated_waiting_for_activation"` so they are visible in
/// downstream funnels.
enum EngagementSequenceScheduler {

    // Immutable reference. `start` runs from background refresh while
    // `markActivation` runs from the view layer, so this really is touched from
    // two executors, and UserDefaults serialises each of those accesses itself.
    nonisolated(unsafe) private static let defaults = UserDefaults.standard


    /// Days on which engagement notifications fire. Preserved for backward compat.
    static let activeDays: Set<Int> = [1, 2, 3, 5, 7]

    /// Hard fallback: if Day 2's activation gate never fires, send Day 2 by
    /// this many days after install regardless.
    private static let day2FallbackDay: Int = 4

    /// Inactivity threshold for the Day 3+ gate. Users darker than this
    /// are routed to the re engagement track.
    private static let inactivityPauseSeconds: TimeInterval = 48 * 3600

    // MARK: - Activation moments

    /// Activation signals that the view layer emits into the scheduler.
    enum Activation {
        case firstRecoveryScore
        case secondRecoveryScore
    }

    /// Call from the view / view model when the user hits an activation moment.
    /// Idempotent. Safe to call on every appearance, only the first transition is recorded.
    static func markActivation(_ moment: Activation) {
        switch moment {
        case .firstRecoveryScore:
            guard !defaults.bool(forKey: AppKeys.Engagement.firstRecoveryScoreSeen) else { return }
            defaults.set(true, forKey: AppKeys.Engagement.firstRecoveryScoreSeen)
        case .secondRecoveryScore:
            guard !defaults.bool(forKey: AppKeys.Engagement.secondRecoveryScoreSeen) else { return }
            // Require the first one to be set before the second, keeps the order clean.
            guard defaults.bool(forKey: AppKeys.Engagement.firstRecoveryScoreSeen) else {
                defaults.set(true, forKey: AppKeys.Engagement.firstRecoveryScoreSeen)
                return
            }
            defaults.set(true, forKey: AppKeys.Engagement.secondRecoveryScoreSeen)
        }
    }

    // MARK: - Public API

    /// The single entry point for the engagement drip. Called at onboarding
    /// completion and from background refresh. Wraps the per-launch gated engine
    /// so callers never reach `scheduleNext` directly and the drip stays routed
    /// through the capped/tracked NotificationManager.
    static func start(
        healthStore: HKHealthStore,
        dataStore: HealthDataStore?,
        userName: String?
    ) async {
        await scheduleNext(healthStore: healthStore, dataStore: dataStore, userName: userName)
    }

    /// Schedule the next pending engagement notification, honoring activation
    /// gates. Reached only through `start()` so the drip stays single-entry.
    private static func scheduleNext(
        healthStore: HKHealthStore,
        dataStore: HealthDataStore?,
        userName: String? = nil
    ) async {
        guard !isSequenceCompleted else { return }

        let daysSinceInstall = self.daysSinceInstall
        guard daysSinceInstall >= 0 else { return }

        // Inactivity check. If the user has gone dark, mark the sequence paused
        // and let the re engagement track take over. Resume on next launch
        // (this method is called on each app open, so "return" naturally resumes).
        if isUserInactive48h {
            if !isSequencePaused {
                defaults.set(true, forKey: AppKeys.Engagement.sequencePaused)
                logGate(day: lastScheduledDay + 1, reason: "sequence_paused_user_inactive_48h")
            }
            return
        } else if isSequencePaused {
            // User is back. Clear the pause flag and continue.
            defaults.set(false, forKey: AppKeys.Engagement.sequencePaused)
        }

        let lastScheduledDay = self.lastScheduledDay

        // Find the next day in the sequence that hasn't been scheduled yet.
        guard let nextDay = activeDays.sorted().first(where: { $0 > lastScheduledDay && $0 <= daysSinceInstall + 1 }) else {
            if daysSinceInstall >= 7 {
                defaults.set(true, forKey: AppKeys.Engagement.sequenceCompleted)
            }
            return
        }

        // Evaluate the activation gate for this day.
        let decision = gateDecision(forDay: nextDay, daysSinceInstall: daysSinceInstall)

        switch decision {
        case .schedule(let softCopy):
            // Detect wake up time (from sleep data or fallback 7 AM)
            let wakeTime = await WakeUpTimeDetector.detectAndPersist(healthStore: healthStore)

            let content: (title: String, body: String)
            if softCopy, nextDay == 5 {
                content = softDay5Content()
            } else {
                content = await generateContent(
                    day: nextDay,
                    dataStore: dataStore,
                    userName: userName
                )
            }

            let scheduled = scheduleNotification(
                day: nextDay,
                title: content.title,
                body: content.body,
                wakeHour: wakeTime.hour,
                wakeMinute: wakeTime.minute
            )

            // Advance only when the notification actually passed the manager's
            // gates. A suppressed schedule (cold auth cache, fatigue window,
            // lost same-day competition) leaves the day pending so the next
            // launch retries it instead of silently consuming the drip.
            guard scheduled else { return }

            defaults.set(nextDay, forKey: AppKeys.Engagement.lastScheduledDay)

            if nextDay >= 7 {
                defaults.set(true, forKey: AppKeys.Engagement.sequenceCompleted)
            }

        case .delay(let reason):
            // Do not advance lastScheduledDay. We will re evaluate on the next
            // app launch. The gate itself is the resume signal.
            logGate(day: nextDay, reason: reason)
            return

        case .skip(let reason):
            // Advance past this day without sending. Used when a day's window
            // has fully passed and we do not want to send it late.
            logGate(day: nextDay, reason: reason)
            defaults.set(nextDay, forKey: AppKeys.Engagement.lastScheduledDay)
            if nextDay >= 7 {
                defaults.set(true, forKey: AppKeys.Engagement.sequenceCompleted)
            }
        }
    }

    // MARK: - State

    static var isSequenceCompleted: Bool {
        defaults.bool(forKey: AppKeys.Engagement.sequenceCompleted)
    }

    static var isSequencePaused: Bool {
        defaults.bool(forKey: AppKeys.Engagement.sequencePaused)
    }

    static var daysSinceInstall: Int {
        // SessionTracker stores installDate as a Date object via UserDefaults.set(Date(), forKey:)
        guard let installDate = defaults.object(forKey: AppKeys.Lifecycle.installDate) as? Date else {
            return -1
        }
        return Date.cal.dateComponents([.day], from: installDate, to: Date()).day ?? 0
    }

    private static var lastScheduledDay: Int {
        defaults.integer(forKey: AppKeys.Engagement.lastScheduledDay)
    }

    /// True when the user has not opened the app in the last 48 hours.
    /// Uses `SessionTracker`'s last active date, which is the single source of
    /// truth for app presence. Treats "no record yet" as active (post onboarding).
    private static var isUserInactive48h: Bool {
        guard let last = defaults.object(forKey: AppKeys.Session.lastActiveDate) as? Date else {
            return false
        }
        return Date().timeIntervalSince(last) > inactivityPauseSeconds
    }

    // MARK: - Gate Decision

    private enum GateDecision {
        case schedule(softCopy: Bool)
        case delay(reason: String)
        case skip(reason: String)
    }

    /// Evaluate whether a given day can be scheduled right now.
    /// Returns `.schedule(softCopy:)` when green lit, `.delay` when the gate
    /// is waiting on activation, and `.skip` when the day is past its window.
    private static func gateDecision(forDay day: Int, daysSinceInstall: Int) -> GateDecision {
        switch day {
        case 1:
            // Pure calendar anchor. No gate.
            return .schedule(softCopy: false)

        case 2:
            // Gate: user has seen their first recovery score.
            if defaults.bool(forKey: AppKeys.Engagement.firstRecoveryScoreSeen) {
                return .schedule(softCopy: false)
            }
            // Hard fallback: send anyway after Day 4 so we do not silently drop users.
            if daysSinceInstall >= day2FallbackDay {
                return .schedule(softCopy: false)
            }
            return .delay(reason: "gated_waiting_for_activation")

        case 3:
            // Gate: at least one app open in the past 48h. The pause path in
            // `scheduleNext` already short circuits when inactive, so by the
            // time we get here the user is active. Extra belt and suspenders
            // in case call sites evolve.
            if isUserInactive48h {
                return .delay(reason: "gated_waiting_for_activation")
            }
            return .schedule(softCopy: false)

        case 5:
            // Gate: second recovery score seen. Otherwise use a softer copy.
            if defaults.bool(forKey: AppKeys.Engagement.secondRecoveryScoreSeen) {
                return .schedule(softCopy: false)
            }
            return .schedule(softCopy: true)

        case 7:
            // Always fires. This is the lapsing user nudge.
            return .schedule(softCopy: false)

        default:
            return .skip(reason: "unknown_day")
        }
    }

    private static func logGate(day: Int, reason: String) {
        let identifier = AppConstants.NotificationID.engagementPrefix + "day\(day)"
        Task { @MainActor in
            AppAnalytics.shared.trackNotificationSuppressed(
                type: NotificationManager.notificationType(identifier),
                identifier: identifier,
                reason: reason
            )
        }
    }

    // MARK: - Content Generation

    private static func generateContent(
        day: Int,
        dataStore: HealthDataStore?,
        userName: String?
    ) async -> (title: String, body: String) {
        switch day {
        case 1:
            return generateDay1(userName: userName)
        case 2:
            return await generateDay2()
        case 3:
            return await generateDay3(dataStore: dataStore)
        case 5:
            return generateDay5()
        case 7:
            return await generateDay7(dataStore: dataStore)
        default:
            return (Copy.Notifications.engagementDefaultTitle, Copy.Notifications.engagementDefaultBody)
        }
    }

    /// Day 1: Implementation Intention trigger
    private static func generateDay1(userName: String?) -> (title: String, body: String) {
        let name = userName ?? UserProfileStore.shared.storedName()
        return (
            title: Copy.Notifications.engagementDay1Title(name: name),
            body: Copy.Notifications.engagementDay1Body
        )
    }

    /// Day 2: Variable Reward. recovery score reveal
    private static func generateDay2() async -> (title: String, body: String) {
        let score = defaults.integer(forKey: AppKeys.Readiness.cachedScore)

        if score > 0 {
            let insight = insightForScore(score)
            return (
                title: Copy.Notifications.engagementDay2Title(score: score),
                body: Copy.Notifications.engagementDay2Body(insight: insight)
            )
        }

        // Try overall health score as fallback
        let healthScore = defaults.integer(forKey: AppKeys.Data.currentScore)
        if healthScore > 0 {
            let insight = insightForScore(healthScore)
            return (
                title: Copy.Notifications.engagementDay2Title(score: healthScore),
                body: Copy.Notifications.engagementDay2Body(insight: insight)
            )
        }

        return (
            title: Copy.Notifications.engagementDay2FallbackTitle,
            body: Copy.Notifications.engagementDay2Fallback
        )
    }

    /// Day 3: Zeigarnik Effect. incomplete sleep info
    private static func generateDay3(dataStore: HealthDataStore?) async -> (title: String, body: String) {
        // Try to get a real sleep finding from stored data
        // Store is @MainActor. hop to main actor for SwiftData reads
        if let store = dataStore {
            let sleepMetrics: [HealthMetric] = [.sleepDuration, .sleepREM, .sleepDeep]
            for metric in sleepMetrics {
                if let series = await MainActor.run(body: { store.loadTimeSeries(for: metric) }) {
                    let samples = series.samples(lastDays: 3)
                    if samples.count >= 2 {
                        if let last = samples.last, let prev = samples.dropLast().last {
                            let change = ((last.value - prev.value) / max(prev.value, 0.01)) * 100
                            if abs(change) > 5 {
                                let direction = change > 0 ? Copy.Notifications.trendWordUp : Copy.Notifications.trendWordDown
                                let metricName = metric.displayName.lowercased()
                                let finding = Copy.Notifications.engagementDay3Finding(metric: metricName, direction: direction, percent: Int(abs(change).rounded()))
                                return (
                                    title: Copy.Notifications.engagementDay3Title,
                                    body: Copy.Notifications.engagementDay3Body(finding: finding)
                                )
                            }
                        }
                    }
                }
            }
        }

        return (
            title: Copy.Notifications.engagementDay3Title,
            body: Copy.Notifications.engagementDay3Fallback
        )
    }

    /// Day 5: Goal Gradient. personalization progress
    private static func generateDay5() -> (title: String, body: String) {
        let days = daysSinceInstall
        let percent: Int
        let daysRemaining: Int

        switch days {
        case 0...2:
            percent = 20
            daysRemaining = 28
        case 3...13:
            percent = 40
            daysRemaining = max(1, 21 - days)
        case 14...20:
            percent = 60
            daysRemaining = max(1, 30 - days)
        case 21...29:
            percent = 80
            daysRemaining = max(1, 30 - days)
        default:
            percent = 100
            daysRemaining = 0
        }

        return (
            title: Copy.Notifications.engagementDay5Title(percent: percent),
            body: Copy.Notifications.engagementDay5Body(daysRemaining: daysRemaining)
        )
    }

    /// Soft Day 5 variant. Used when the second recovery score has not been seen yet,
    /// so we do not claim personalization is X% complete when it really is not.
    private static func softDay5Content() -> (title: String, body: String) {
        return (
            title: Copy.Notifications.engagementDay5SoftTitle,
            body: Copy.Notifications.engagementDay5SoftBody
        )
    }

    /// Day 7: Loss Aversion. personalized discovery count
    private static func generateDay7(dataStore: HealthDataStore?) async -> (title: String, body: String) {
        var patternCount = 0
        var trendInfo: (metric: String, direction: String)?

        // Store is @MainActor. batch all SwiftData reads on main actor
        if let store = dataStore {
            let storeData = await MainActor.run { () -> (scoreCount: Int, metricSeries: [(HealthMetric, MetricTimeSeries)]) in
                let scoreHistory = store.loadScoreHistory(days: 7)
                var series: [(HealthMetric, MetricTimeSeries)] = []
                for metric in HealthMetric.allCases {
                    if let s = store.loadTimeSeries(for: metric) {
                        series.append((metric, s))
                    }
                }
                return (scoreCount: scoreHistory.count, metricSeries: series)
            }

            patternCount += storeData.scoreCount

            for (metric, series) in storeData.metricSeries {
                let samples = series.samples(lastDays: 7)
                if samples.count >= 3 {
                    patternCount += 1

                    if let first = samples.first, let last = samples.last {
                        let change = ((last.value - first.value) / max(first.value, 0.01)) * 100
                        if abs(change) > 10, trendInfo == nil {
                            trendInfo = (
                                metric: metric.displayName.lowercased(),
                                direction: change > 0 ? "improving" : "declining"
                            )
                        }
                    }
                }
            }
        }

        // Ensure minimum count for meaningful message
        patternCount = max(patternCount, 5)

        if let trend = trendInfo {
            return (
                title: Copy.Notifications.engagementDay7Title(patternCount: patternCount),
                body: Copy.Notifications.engagementDay7BodyTrend(metric: trend.metric, direction: trend.direction)
            )
        } else {
            return (
                title: Copy.Notifications.engagementDay7Title(patternCount: patternCount),
                body: Copy.Notifications.engagementDay7BodyGeneric(count: patternCount)
            )
        }
    }

    // MARK: - Scheduling

    private static func scheduleNotification(
        day: Int,
        title: String,
        body: String,
        wakeHour: Int,
        wakeMinute: Int
    ) -> Bool {
        let identifier = AppConstants.NotificationID.engagementPrefix + "day\(day)"

        var dateComponents = DateComponents()
        dateComponents.hour = wakeHour
        dateComponents.minute = wakeMinute
        dateComponents.calendar = Date.cal

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        // NotificationManager.scheduleNotification already emits
        // trackNotificationScheduled on success, so we do not double-count here.
        return NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            trigger: trigger,
            severity: .info
        )
    }

    // MARK: - Helpers

    private static func insightForScore(_ score: Int) -> String {
        if score >= ScoreBucketsConfig.engagementWellRecoveredFloor {
            return Copy.Notifications.insightWellRecovered
        }
        if score >= ScoreBucketsConfig.engagementLookingGoodFloor {
            return Copy.Notifications.insightLookingGood
        }
        if score >= ScoreBucketsConfig.engagementModerateFloor {
            return Copy.Notifications.insightModerate
        }
        if score >= ScoreBucketsConfig.engagementNeedsAttentionFloor {
            return Copy.Notifications.insightNeedsAttention
        }
        return Copy.Notifications.insightRest
    }
}
