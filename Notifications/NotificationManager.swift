import Foundation
import UserNotifications

/// Manages scheduling and canceling local notifications
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let frequencyCap = FrequencyCapManager()

    private init() {}

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

    /// Schedule a notification if within frequency cap
    func scheduleNotification(
        title: String,
        body: String,
        identifier: String,
        trigger: UNNotificationTrigger? = nil,
        maxPerDay: Int = 5
    ) {
        // Repeating summaries should not consume the daily cap at scheduling time.
        let countsTowardDailyCap = (trigger == nil)
        if countsTowardDailyCap {
            guard frequencyCap.canSendNotification(maxPerDay: maxPerDay) else {
                print("Notification frequency cap reached for today")
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
            } else if countsTowardDailyCap {
                self?.frequencyCap.recordNotification()
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
