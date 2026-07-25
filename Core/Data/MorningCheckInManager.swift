import Foundation

/// Manages check-in persistence and determines when to show the prompt.
final class MorningCheckInManager {

    private static let storageKey = "laso.morning_checkin.history"
    private static let lastCheckInKey = "laso.morning_checkin.last_date"
    private static let dismissedDateKey = "laso.morning_checkin.dismissed_date"
    private static let maxHistoryDays = 90

    // Hot-path caches: avoid per-call allocations on every
    // HomeView render and every check-in save.
    private static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()
    private static let jsonEncoder: JSONEncoder = JSONEncoder()
    private static let jsonDecoder: JSONDecoder = JSONDecoder()

    /// Whether to show the morning check-in today
    static func shouldShowCheckIn() -> Bool {
        let hour = Date.cal.component(.hour, from: Date())

        // Only show between 5 AM and 11 AM
        guard hour >= 5 && hour < 11 else { return false }

        // Check if already completed today
        if let lastDateStr = UserDefaults.standard.string(forKey: lastCheckInKey),
           let lastDate = iso8601.date(from: lastDateStr) {
            if Date.cal.isDateInToday(lastDate) {
                return false
            }
        }

        // Check if user explicitly dismissed today
        if let dismissedStr = UserDefaults.standard.string(forKey: dismissedDateKey),
           let dismissedDate = iso8601.date(from: dismissedStr) {
            if Date.cal.isDateInToday(dismissedDate) {
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

    /// Record a completed check-in from any surface, phone or wrist.
    ///
    /// Both entry points go through here so the first-check-in event can never fire
    /// twice and the history file has a single writer.
    @MainActor
    static func record(_ checkIn: MorningCheckIn) {
        save(checkIn)
        AppAnalytics.shared.trackCoreAction(.completedMorningCheckIn, screen: .home)

        // First-ever check-in is the denied branch's value moment; fire once via
        // a one-shot flag so history pruning can never replay it.
        if !UserDefaults.standard.bool(forKey: AppKeys.Prediction.firstCheckInLogged) {
            UserDefaults.standard.set(true, forKey: AppKeys.Prediction.firstCheckInLogged)
            AppAnalytics.shared.trackFirstCheckInDone()
        }
    }

    /// Save a completed check-in.
    ///
    /// Main actor bound because the save is a read, append, write over a shared
    /// array using shared mutable formatters: two concurrent writers would lose an
    /// entry or corrupt the stored history.
    @MainActor
    static func save(_ checkIn: MorningCheckIn) {
        var history = loadHistory()
        history.append(checkIn)

        // Prune to last 90 days
        let cutoff = Date.cal.date(byAdding: .day, value: -maxHistoryDays, to: Date()) ?? Date()
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
        return loadHistory().first { Date.cal.isDateInToday($0.date) }
    }
}
