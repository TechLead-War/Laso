import Foundation

/// Enforces maximum notification frequency per day
final class FrequencyCapManager {
    private let defaults = UserDefaults.standard
    private let key = AppKeys.Notifications.notificationLog

    /// Atomically check the cap for the day the notification will FIRE and,
    /// if there is room, immediately record a slot. Returns `true` only when
    /// a slot was reserved.
    ///
    /// The log stores FIRE timestamps, not schedule timestamps: the daily cap
    /// and the minimum spacing are enforced per delivery day. A launch batch
    /// that schedules reminders firing 2h, 24h, and 72h out therefore reserves
    /// three independent days instead of collapsing to one.
    ///
    /// The atomic reserve replaces the previous check-then-record split, which
    /// left a TOCTOU window where two near-simultaneous schedules could both
    /// pass the check before either recorded, overshooting the cap.
    func reserveSlot(maxPerDay: Int, fireDate: Date = Date(), minimumSpacingHours: Double = 4) -> Bool {
        var log = prunedLog()
        let sameDay = log.filter { Date.cal.isDate($0, inSameDayAs: fireDate) }
        guard sameDay.count < maxPerDay else { return false }
        // Spacing is between deliveries on the same day; entries on other days
        // are irrelevant to when this one lands.
        let tooClose = sameDay.contains { abs(fireDate.timeIntervalSince($0)) / 3600 < minimumSpacingHours }
        guard !tooClose else { return false }
        log.append(fireDate)
        saveLog(log)
        return true
    }

    /// Roll back one reserved slot on `fireDate`'s day. Called when a schedule
    /// fails to enqueue, when the same-day competition rejects a candidate
    /// after its reserve, or when an already-pending request is evicted.
    ///
    /// Pops the latest entry on that day rather than a specific identifier
    /// because the log only stores fire timestamps; main-path scheduling is
    /// serial, so the latest entry on the day is the one to refund.
    func releaseSlot(on fireDate: Date = Date()) {
        var log = prunedLog()
        guard let latest = log.filter({ Date.cal.isDate($0, inSameDayAs: fireDate) }).max() else { return }
        if let index = log.firstIndex(of: latest) {
            log.remove(at: index)
            saveLog(log)
        }
    }

    /// Number of notifications reserved for today
    func notificationsSentToday() -> Int {
        prunedLog().filter { Date.cal.isDateInToday($0) }.count
    }

    /// Reset the daily counter (called at midnight)
    func resetDailyCount() {
        saveLog([])
    }

    /// The stored fire timestamps with past days dropped. Future-dated
    /// entries are kept: they hold slots for the days pending notifications
    /// will fire on.
    private func prunedLog() -> [Date] {
        let startOfToday = Date.cal.startOfDay(for: Date())
        return loadLog().filter { $0 >= startOfToday }
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
