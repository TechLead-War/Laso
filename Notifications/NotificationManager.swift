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
        if identifier == "healthpulse.eveningSummary" { return "evening_summary" }
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
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { AppAnalytics.shared.updateNotificationProperties(enabled: granted) }
            return granted
        } catch {
            await MainActor.run { AppAnalytics.shared.updateNotificationProperties(enabled: false) }
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
            await MainActor.run { AppAnalytics.shared.updateNotificationProperties(enabled: true) }
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            await MainActor.run { AppAnalytics.shared.updateNotificationProperties(enabled: false) }
            return false
        @unknown default:
            await MainActor.run { AppAnalytics.shared.updateNotificationProperties(enabled: false) }
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
        metricInFocus: Bool = false,
        bypassCap: Bool = false,
        hookCategory: String? = nil
    ) {
        let isDailySummary = identifier == "healthpulse.dailySummary"
            || identifier == "healthpulse.eveningSummary"

        let notifType = Self.notificationType(identifier)

        // Kill switch. remotely disable all non-critical notifications
        if RemoteConfigManager.shared.killNotifications && severity != .critical && !bypassCap {
            Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "kill_switch") }
            return
        }

        // Everything except daily summaries and bypassed notifications is capped and optimized
        if !isDailySummary && !bypassCap {
            // Priority filtering. skip low-priority unless critical
            let priority = NotificationOptimizer.priorityScore(
                severity: severity,
                deviationPercent: deviationPercent,
                metricInFocus: metricInFocus
            )
            let minPriority = RemoteConfigManager.shared.notificationMinPriorityScore
            if priority < minPriority && severity != .critical {
                Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "low_priority") }
                return
            }

            // Dynamic budget based on fatigue detection.
            // HealthDataStore is @MainActor. use assumeIsolated when on main thread,
            // otherwise fall back to the static maxPerDay budget.
            let dynamicBudget: Int
            if let store, Thread.isMainThread {
                let events = MainActor.assumeIsolated { store.loadNotificationEvents(days: 7) }
                dynamicBudget = NotificationOptimizer.dailyBudget(events: events)
            } else {
                dynamicBudget = maxPerDay
            }

            guard frequencyCap.canSendNotification(maxPerDay: dynamicBudget) else {
                Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "frequency_cap") }
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
            } else {
                if !isDailySummary {
                    self?.frequencyCap.recordNotification()
                }

                // Record the send event for optimizer tracking.
                // HealthDataStore is @MainActor. dispatch to main actor for the write.
                if let store = self?.store {
                    Task { @MainActor in
                        store.recordNotificationSent(id: identifier, type: notifType)
                    }
                }
                Task { @MainActor in
                    AppAnalytics.shared.trackNotificationScheduled(type: notifType, identifier: identifier, hookCategory: hookCategory)
                }
            }
        }
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
