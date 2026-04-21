import Foundation

/// Manages check-in persistence and determines when to show the prompt.
final class MorningCheckInManager {

    private static let storageKey = "laso.morning_checkin.history"
    private static let lastCheckInKey = "laso.morning_checkin.last_date"
    private static let dismissedDateKey = "laso.morning_checkin.dismissed_date"
    private static let maxHistoryDays = 90

    /// Whether to show the morning check-in today
    static func shouldShowCheckIn() -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        // Only show between 5 AM and 11 AM
        guard hour >= 5 && hour < 11 else { return false }

        // Check if already completed today
        if let lastDateStr = UserDefaults.standard.string(forKey: lastCheckInKey),
           let lastDate = ISO8601DateFormatter().date(from: lastDateStr) {
            if calendar.isDateInToday(lastDate) {
                return false
            }
        }

        // Check if user explicitly dismissed today
        if let dismissedStr = UserDefaults.standard.string(forKey: dismissedDateKey),
           let dismissedDate = ISO8601DateFormatter().date(from: dismissedStr) {
            if calendar.isDateInToday(dismissedDate) {
                return false
            }
        }

        return true
    }

    /// Persist today's dismissal so the prompt does not return later in the day
    static func markDismissedToday() {
        let dateStr = ISO8601DateFormatter().string(from: Date())
        UserDefaults.standard.set(dateStr, forKey: dismissedDateKey)
    }

    /// Save a completed check-in
    static func save(_ checkIn: MorningCheckIn) {
        var history = loadHistory()
        history.append(checkIn)

        // Prune to last 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxHistoryDays, to: Date()) ?? Date()
        history = history.filter { $0.date > cutoff }

        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }

        let dateStr = ISO8601DateFormatter().string(from: checkIn.date)
        UserDefaults.standard.set(dateStr, forKey: lastCheckInKey)
    }

    /// Load recent check-in history
    static func loadHistory() -> [MorningCheckIn] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let history = try? JSONDecoder().decode([MorningCheckIn].self, from: data) else {
            return []
        }
        return history
    }

    /// Get today's check-in if completed
    static func todaysCheckIn() -> MorningCheckIn? {
        let calendar = Calendar.current
        return loadHistory().first { calendar.isDateInToday($0.date) }
    }

    /// Get average composite score over last N days
    static func recentAverageScore(days: Int = 7) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recent = loadHistory().filter { $0.date > cutoff }
        guard !recent.isEmpty else { return nil }
        return recent.map(\.compositeScore).reduce(0, +) / Double(recent.count)
    }
}
