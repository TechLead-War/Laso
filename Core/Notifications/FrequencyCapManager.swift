import Foundation

/// Enforces maximum notification frequency per day
final class FrequencyCapManager {
    private let defaults = UserDefaults.standard
    private let key = AppKeys.Notifications.notificationLog

    /// Atomically check the daily cap and, if there is room, immediately
    /// record a slot. Returns `true` only when a slot was reserved.
    ///
    /// This replaces the previous check-then-record split (canSendNotification
    /// followed by an async recordNotification in the center.add callback),
    /// which left a TOCTOU window where two near-simultaneous schedules could
    /// both pass the check before either recorded, overshooting the cap.
    func reserveSlot(maxPerDay: Int, minimumSpacingHours: Double = 4) -> Bool {
        var log = todayLog()
        guard canSend(log: log, maxPerDay: maxPerDay, minimumSpacingHours: minimumSpacingHours) else {
            return false
        }
        log.append(Date())
        saveLog(log)
        return true
    }

    /// Roll back the most recently reserved slot for today. Called in the
    /// center.add error branch to refund a schedule that failed to enqueue.
    ///
    /// Pops the latest-today entry rather than a specific identifier because
    /// the log only stores fire timestamps; this is safe because main-path
    /// scheduling is serial, so the latest entry is the one we just reserved.
    func releaseSlot() {
        var log = todayLog()
        guard let latest = log.max() else { return }
        if let index = log.firstIndex(of: latest) {
            log.remove(at: index)
            saveLog(log)
        }
    }

    /// Number of notifications sent today
    func notificationsSentToday() -> Int {
        todayLog().count
    }

    /// Reset the daily counter (called at midnight)
    func resetDailyCount() {
        saveLog([])
    }

    /// Read-only predicate: is there room under the daily cap and minimum
    /// spacing given the provided today-log? Used only by `reserveSlot`.
    private func canSend(log: [Date], maxPerDay: Int, minimumSpacingHours: Double) -> Bool {
        guard log.count < maxPerDay else { return false }
        if let lastSent = log.max() {
            let hoursSinceLast = Date().timeIntervalSince(lastSent) / 3600
            if hoursSinceLast < minimumSpacingHours { return false }
        }
        return true
    }

    /// Today's fire timestamps, dropping any stale entries from prior days.
    private func todayLog() -> [Date] {
        loadLog().filter { Date.cal.isDateInToday($0) }
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
