import Foundation

/// Enforces maximum notification frequency per day
final class FrequencyCapManager {
    private let defaults = UserDefaults.standard
    private let key = AppKeys.Notifications.notificationLog


    /// Record that a notification was sent
    func recordNotification() {
        var log = loadLog()
        log.append(Date())
        // Keep only today's entries
        log = log.filter { Date.cal.isDateInToday($0) }
        saveLog(log)
    }

    /// Check if we can send another notification today, respecting both daily cap and minimum spacing.
    func canSendNotification(maxPerDay: Int = 2, minimumSpacingHours: Double = 4) -> Bool {
        let todayLog = loadLog().filter { Date.cal.isDateInToday($0) }
        guard todayLog.count < maxPerDay else { return false }
        // Enforce minimum spacing between consecutive notifications
        if let lastSent = todayLog.max() {
            let hoursSinceLast = Date().timeIntervalSince(lastSent) / 3600
            if hoursSinceLast < minimumSpacingHours { return false }
        }
        return true
    }

    /// Number of notifications sent today
    func notificationsSentToday() -> Int {
        loadLog().filter { Date.cal.isDateInToday($0) }.count
    }

    /// Reset the daily counter (called at midnight)
    func resetDailyCount() {
        saveLog([])
    }

    private func loadLog() -> [Date] {
        guard let data = defaults.data(forKey: key),
              let dates = try? JSONDecoder().decode([Date].self, from: data) else {
            return []
        }
        return dates
    }

    private func saveLog(_ log: [Date]) {
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: key)
        }
    }
}
