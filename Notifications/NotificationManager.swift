import Foundation
import UserNotifications

/// Manages scheduling and canceling local notifications
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let frequencyCap = FrequencyCapManager()

    /// Data store for notification event tracking (set at app launch)
    var store: HealthDataStore?

    private init() {}

    /// Derive a notification type string from its identifier
    static func notificationType(_ identifier: String) -> String {
        if identifier == "healthpulse.dailySummary" { return "daily_summary" }
        if identifier.hasPrefix("healthpulse.alert.") { return "alert" }
        if identifier.hasPrefix("healthpulse.trend.") { return "trend_reversal" }
        if identifier.hasPrefix("healthpulse.improvement.") { return "improvement" }
        if identifier.hasPrefix("healthpulse.watch.") { return "watch_monitor" }
        if identifier.hasPrefix("healthpulse.weekly") { return "weekly_summary" }
        if identifier.hasPrefix("healthpulse.reengagement") { return "reengagement" }
        return "other"
    }

    /// Request notification authorization
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Request authorization only if status is not determined yet.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Schedule a notification if within frequency cap and optimizer budget.
    /// The daily summary (repeating calendar trigger) is the only notification that bypasses the cap.
    /// All other notifications are hard-capped and optimized for priority and fatigue.
    func scheduleNotification(
        title: String,
        body: String,
        identifier: String,
        trigger: UNNotificationTrigger? = nil,
        maxPerDay: Int = 1,
        severity: Severity = .info,
        deviationPercent: Double = 0,
        metricInFocus: Bool = false
    ) {
        let isDailySummary = identifier == "healthpulse.dailySummary"

        // Everything except the daily summary is capped and optimized
        if !isDailySummary {
            // Priority filtering — skip low-priority unless critical
            let priority = NotificationOptimizer.priorityScore(
                severity: severity,
                deviationPercent: deviationPercent,
                metricInFocus: metricInFocus
            )
            let minPriority = RemoteConfigManager.shared.notificationMinPriorityScore
            if priority < minPriority && severity != .critical {
                return
            }

            // Dynamic budget based on fatigue detection
            let dynamicBudget: Int
            if let store {
                let events = store.loadNotificationEvents(days: 7)
                dynamicBudget = NotificationOptimizer.dailyBudget(events: events)
            } else {
                dynamicBudget = maxPerDay
            }

            guard frequencyCap.canSendNotification(maxPerDay: dynamicBudget) else {
                print("Notification frequency cap reached for today — suppressing: \(identifier)")
                return
            }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        center.add(request) { [weak self] error in
            if let error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else if !isDailySummary {
                self?.frequencyCap.recordNotification()
            }
        }

        // Record the send event for optimizer tracking
        let notifType = Self.notificationType(identifier)
        store?.recordNotificationSent(id: identifier, type: notifType)
    }

    /// Cancel a specific notification
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    /// Get pending notification count
    func pendingNotificationCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.count
    }
}
