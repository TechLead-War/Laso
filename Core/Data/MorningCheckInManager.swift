import Foundation

/// Manages check-in persistence and determines when to show the prompt.
final class MorningCheckInManager {

    private static let storageKey = "laso.morning_checkin.history"
    private static let lastCheckInKey = "laso.morning_checkin.last_date"
    private static let dismissedDateKey = "laso.morning_checkin.dismissed_date"
    private static let maxHistoryDays = 90

    // Performance Pass 2 hot-path caches: avoid per-call allocations on every
    // HomeView render and every check-in save.
    private static let cal: Calendar = Calendar.current
    private static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()
    private static let jsonEncoder: JSONEncoder = JSONEncoder()
    private static let jsonDecoder: JSONDecoder = JSONDecoder()

    /// Whether to show the morning check-in today
    static func shouldShowCheckIn() -> Bool {
        let hour = cal.component(.hour, from: Date())

        // Only show between 5 AM and 11 AM
        guard hour >= 5 && hour < 11 else { return false }

        // Check if already completed today
        if let lastDateStr = UserDefaults.standard.string(forKey: lastCheckInKey),
           let lastDate = iso8601.date(from: lastDateStr) {
            if cal.isDateInToday(lastDate) {
                return false
            }
        }

        // Check if user explicitly dismissed today
        if let dismissedStr = UserDefaults.standard.string(forKey: dismissedDateKey),
           let dismissedDate = iso8601.date(from: dismissedStr) {
            if cal.isDateInToday(dismissedDate) {
                return false
            }
        }

        return true
    }

    /// Persist today's dismissal so the prompt does not return later in the day
    static func markDismissedToday() {
        let dateStr = iso8601.string(from: Date())
        UserDefaults.standard.set(dateStr, forKey: dismissedDateKey)
    }

    /// Save a completed check-in
    static func save(_ checkIn: MorningCheckIn) {
        var history = loadHistory()
        history.append(checkIn)

        // Prune to last 90 days
        let cutoff = cal.date(byAdding: .day, value: -maxHistoryDays, to: Date()) ?? Date()
        history = history.filter { $0.date > cutoff }

        if let data = try? jsonEncoder.encode(history) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }

        let dateStr = iso8601.string(from: checkIn.date)
        UserDefaults.standard.set(dateStr, forKey: lastCheckInKey)
    }

    /// Load recent check-in history
    static func loadHistory() -> [MorningCheckIn] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let history = try? jsonDecoder.decode([MorningCheckIn].self, from: data) else {
            return []
        }
        return history
    }

    /// Get today's check-in if completed
    static func todaysCheckIn() -> MorningCheckIn? {
        return loadHistory().first { cal.isDateInToday($0.date) }
    }

    /// Get average composite score over last N days
    static func recentAverageScore(days: Int = 7) -> Double? {
        let cutoff = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recent = loadHistory().filter { $0.date > cutoff }
        guard !recent.isEmpty else { return nil }
        return recent.map(\.compositeScore).reduce(0, +) / Double(recent.count)
    }
}
