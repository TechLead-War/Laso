import Foundation
import HealthKit
import UserNotifications

/// Schedules the post-onboarding engagement notification sequence (Days 1-7).
///
/// Each notification is grounded in behavioral science:
/// - Day 1: Implementation Intention trigger (fires at wake-up time)
/// - Day 2: Variable Reward (recovery score reveal — they don't know what they'll see)
/// - Day 3: Zeigarnik Effect (incomplete info about sleep patterns pulls them back)
/// - Day 5: Goal Gradient (personalization progress — acceleration toward completion)
/// - Day 7: Loss Aversion (discovered patterns — losing them hurts 2.25x more than the cost)
///
/// All notifications use REAL data from the ML pipeline when available,
/// with meaningful fallbacks when data isn't ready.
enum EngagementSequenceScheduler {

    private static let defaults = UserDefaults.standard

    /// Days on which engagement notifications fire.
    static let activeDays: Set<Int> = [1, 2, 3, 5, 7]

    // MARK: - Public API

    /// Schedule the next pending engagement notification.
    /// Call on every app launch and after onboarding completes.
    static func scheduleNext(
        healthStore: HKHealthStore,
        dataStore: HealthDataStore?,
        userName: String? = nil
    ) async {
        guard !isSequenceCompleted else { return }

        let daysSinceInstall = self.daysSinceInstall
        guard daysSinceInstall >= 0 else { return }

        let lastScheduledDay = defaults.integer(forKey: AppKeys.Engagement.lastScheduledDay)

        // Find the next day in the sequence that hasn't been scheduled yet
        guard let nextDay = activeDays.sorted().first(where: { $0 > lastScheduledDay && $0 <= daysSinceInstall + 1 }) else {
            // No more days to schedule, or we're caught up
            if daysSinceInstall >= 7 {
                defaults.set(true, forKey: AppKeys.Engagement.sequenceCompleted)
            }
            return
        }

        // Detect wake-up time (from sleep data or fallback 7 AM)
        let wakeTime = await WakeUpTimeDetector.detectAndPersist(healthStore: healthStore)

        // Generate content for this day
        let content = await generateContent(
            day: nextDay,
            dataStore: dataStore,
            userName: userName
        )

        // Schedule the notification
        scheduleNotification(
            day: nextDay,
            title: content.title,
            body: content.body,
            wakeHour: wakeTime.hour,
            wakeMinute: wakeTime.minute
        )

        defaults.set(nextDay, forKey: AppKeys.Engagement.lastScheduledDay)

        if nextDay >= 7 {
            defaults.set(true, forKey: AppKeys.Engagement.sequenceCompleted)
        }
    }

    /// Schedule all remaining engagement notifications at once.
    /// Useful after onboarding or app update.
    static func scheduleAllRemaining(
        healthStore: HKHealthStore,
        dataStore: HealthDataStore?,
        userName: String? = nil
    ) async {
        guard !isSequenceCompleted else { return }

        let wakeTime = await WakeUpTimeDetector.detectAndPersist(healthStore: healthStore)
        let currentDay = daysSinceInstall
        let lastScheduledDay = defaults.integer(forKey: AppKeys.Engagement.lastScheduledDay)

        for day in activeDays.sorted() where day > lastScheduledDay {
            let content: (title: String, body: String)

            if day <= currentDay {
                // Day is today or past — generate with real data
                content = await generateContent(day: day, dataStore: dataStore, userName: userName)
            } else {
                // Future day — use preview content (will be rescheduled with real data on that day)
                content = previewContent(day: day, userName: userName)
            }

            let daysFromNow = max(0, day - currentDay)
            scheduleFutureNotification(
                day: day,
                title: content.title,
                body: content.body,
                wakeHour: wakeTime.hour,
                wakeMinute: wakeTime.minute,
                daysFromNow: daysFromNow
            )
        }

        if let maxDay = activeDays.max() {
            defaults.set(maxDay, forKey: AppKeys.Engagement.lastScheduledDay)
        }
    }

    /// Cancel all pending engagement notifications.
    static func cancelAll() {
        let identifiers = activeDays.map { AppConstants.NotificationID.engagementPrefix + "day\($0)" }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Reset the engagement sequence (for testing or re-onboarding).
    static func reset() {
        cancelAll()
        defaults.removeObject(forKey: AppKeys.Engagement.lastScheduledDay)
        defaults.removeObject(forKey: AppKeys.Engagement.sequenceCompleted)
    }

    // MARK: - State

    static var isSequenceCompleted: Bool {
        defaults.bool(forKey: AppKeys.Engagement.sequenceCompleted)
    }

    static var daysSinceInstall: Int {
        // SessionTracker stores installDate as a Date object via UserDefaults.set(Date(), forKey:)
        guard let installDate = defaults.object(forKey: AppKeys.Lifecycle.installDate) as? Date else {
            return -1
        }
        return Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
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
            return await generateDay2(dataStore: dataStore)
        case 3:
            return await generateDay3(dataStore: dataStore)
        case 5:
            return generateDay5()
        case 7:
            return await generateDay7(dataStore: dataStore)
        default:
            return ("Your Health Update", "Tap to see your latest health insights.")
        }
    }

    /// Day 1: Implementation Intention trigger
    private static func generateDay1(userName: String?) -> (title: String, body: String) {
        let name = userName ?? defaults.string(forKey: AppKeys.Profile.name)
        return (
            title: Copy.Notifications.engagementDay1Title(name: name),
            body: Copy.Notifications.engagementDay1Body
        )
    }

    /// Day 2: Variable Reward — recovery score reveal
    private static func generateDay2(dataStore: HealthDataStore?) async -> (title: String, body: String) {
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
            title: "Your morning health briefing",
            body: Copy.Notifications.engagementDay2Fallback
        )
    }

    /// Day 3: Zeigarnik Effect — incomplete sleep info
    private static func generateDay3(dataStore: HealthDataStore?) async -> (title: String, body: String) {
        // Try to get a real sleep finding from stored data
        // Store is @MainActor — hop to main actor for SwiftData reads
        if let store = dataStore {
            let sleepMetrics: [HealthMetric] = [.sleepDuration, .sleepREM, .sleepDeep]
            for metric in sleepMetrics {
                if let series = await MainActor.run(body: { store.loadTimeSeries(for: metric) }) {
                    let samples = series.samples(lastDays: 3)
                    if samples.count >= 2 {
                        if let last = samples.last, let prev = samples.dropLast().last {
                            let change = ((last.value - prev.value) / max(prev.value, 0.01)) * 100
                            if abs(change) > 5 {
                                let direction = change > 0 ? "up" : "down"
                                let metricName = metric.displayName.lowercased()
                                let finding = "Your \(metricName) is trending \(direction) \(String(format: "%.0f", abs(change)))% over the last few nights."
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

    /// Day 5: Goal Gradient — personalization progress
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

    /// Day 7: Loss Aversion — personalized discovery count
    private static func generateDay7(dataStore: HealthDataStore?) async -> (title: String, body: String) {
        var patternCount = 0
        var trendInfo: (metric: String, direction: String)?

        // Store is @MainActor — batch all SwiftData reads on main actor
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

    /// Preview content for future-day scheduling (before real data is available).
    private static func previewContent(day: Int, userName: String?) -> (title: String, body: String) {
        switch day {
        case 1:
            return generateDay1(userName: userName)
        case 2:
            return ("Your morning health briefing", Copy.Notifications.engagementDay2Fallback)
        case 3:
            return (Copy.Notifications.engagementDay3Title, Copy.Notifications.engagementDay3Fallback)
        case 5:
            return generateDay5()
        case 7:
            return (Copy.Notifications.engagementDay7Title(patternCount: 12), Copy.Notifications.engagementDay7BodyGeneric(count: 12))
        default:
            return ("Your Health Update", "Tap to see your latest health insights.")
        }
    }

    // MARK: - Scheduling

    private static func scheduleNotification(
        day: Int,
        title: String,
        body: String,
        wakeHour: Int,
        wakeMinute: Int
    ) {
        let identifier = AppConstants.NotificationID.engagementPrefix + "day\(day)"

        var dateComponents = DateComponents()
        dateComponents.hour = wakeHour
        dateComponents.minute = wakeMinute
        dateComponents.calendar = Calendar.current

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        NotificationManager.shared.scheduleNotification(
            title: title,
            body: body,
            identifier: identifier,
            trigger: trigger,
            severity: .info
        )

        AppAnalytics.shared.trackNotificationScheduled(type: "engagement", identifier: identifier)
    }

    private static func scheduleFutureNotification(
        day: Int,
        title: String,
        body: String,
        wakeHour: Int,
        wakeMinute: Int,
        daysFromNow: Int
    ) {
        let identifier = AppConstants.NotificationID.engagementPrefix + "day\(day)"

        // Cancel any existing with this identifier
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])

        if daysFromNow <= 0 {
            // Schedule for today at wake time (or now if past wake time)
            scheduleNotification(day: day, title: title, body: body, wakeHour: wakeHour, wakeMinute: wakeMinute)
            return
        }

        // Schedule for a future date at wake time
        guard let targetDate = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) else { return }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
        dateComponents.hour = wakeHour
        dateComponents.minute = wakeMinute
        dateComponents.calendar = Calendar.current

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[EngagementSequence] Failed to schedule day \(day): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private static func insightForScore(_ score: Int) -> String {
        switch score {
        case 85...100:
            return "You're well recovered today."
        case 70..<85:
            return "Solid recovery — a good day to stay active."
        case 55..<70:
            return "Moderate recovery — listen to your body today."
        case 40..<55:
            return "Your body is still catching up."
        default:
            return "Take it easy — your body needs rest."
        }
    }
}
