import Foundation

/// Enforces maximum notification frequency per day
final class FrequencyCapManager {
    private let defaults = UserDefaults.standard
    private let key = "healthpulse.notificationLog"

    /// Record that a notification was sent
    func recordNotification() {
        var log = loadLog()
        log.append(Date())
        // Keep only today's entries
        log = log.filter { Calendar.current.isDateInToday($0) }
        saveLog(log)
    }

    /// Check if we can send another notification today
    func canSendNotification(maxPerDay: Int = 5) -> Bool {
        let log = loadLog().filter { Calendar.current.isDateInToday($0) }
        return log.count < maxPerDay
    }

    /// Number of notifications sent today
    func notificationsSentToday() -> Int {
        loadLog().filter { Calendar.current.isDateInToday($0) }.count
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
