import Foundation

/// Enforces maximum notification frequency per day
final class FrequencyCapManager {
    private let defaults = UserDefaults.standard
    private let key = AppKeys.Notifications.notificationLog

    /// One reserved delivery slot, tagged with the notification that owns it.
    /// The identifier is what lets a cancelled or evicted request refund its
    /// OWN slot: refunding "the nearest entry that day" would either hand back
    /// a slot the caller never reserved or silently leave a phantom entry
    /// holding the day's budget.
    private struct Reservation: Codable {
        let id: String
        let fireDate: Date
    }

    /// Atomically check the cap for the day the notification will FIRE and,
    /// if there is room, immediately record a slot. Returns `true` only when
    /// a slot was reserved.
    ///
    /// The log stores FIRE timestamps, not schedule timestamps: the daily cap
    /// and the minimum spacing are enforced per delivery day. A launch batch
    /// that schedules reminders firing 2h, 24h, and 72h out therefore reserves
    /// three independent days instead of collapsing to one.
    ///
    /// A re-schedule of the same identifier on the same day REPLACES its own
    /// reservation: iOS replaces the pending request with the same identifier,
    /// so keeping both entries would have the notification compete with itself
    /// on spacing and lose.
    ///
    /// The atomic reserve replaces the previous check-then-record split, which
    /// left a TOCTOU window where two near-simultaneous schedules could both
    /// pass the check before either recorded, overshooting the cap.
    func reserveSlot(identifier: String, maxPerDay: Int, fireDate: Date = Date(), minimumSpacingHours: Double = 4) -> Bool {
        var log = prunedLog()
        log.removeAll { $0.id == identifier && Date.cal.isDate($0.fireDate, inSameDayAs: fireDate) }
        let sameDay = log.filter { Date.cal.isDate($0.fireDate, inSameDayAs: fireDate) }
        guard sameDay.count < maxPerDay else { return false }
        // Spacing is between deliveries on the same day; entries on other days
        // are irrelevant to when this one lands.
        let tooClose = sameDay.contains { abs(fireDate.timeIntervalSince($0.fireDate)) / 3600 < minimumSpacingHours }
        guard !tooClose else { return false }
        log.append(Reservation(id: identifier, fireDate: fireDate))
        saveLog(log)
        return true
    }

    /// Roll back the slot reserved by `identifier`, returning the fire date it
    /// held. Called when a schedule fails to enqueue, when a pending request is
    /// evicted by a higher-priority same-day winner, and when a scheduler
    /// cancels its own pending notification.
    ///
    /// Returns nil when the identifier holds no reservation (a bypassCap or
    /// daily-summary notification, or one already refunded), so callers can
    /// skip the rest of their rollback instead of guessing.
    @discardableResult
    func releaseSlot(identifier: String) -> Date? {
        var log = prunedLog()
        guard let index = log.firstIndex(where: { $0.id == identifier }) else { return nil }
        let fireDate = log[index].fireDate
        log.remove(at: index)
        saveLog(log)
        return fireDate
    }

    /// The stored fire timestamps with past days dropped. Future-dated
    /// entries are kept: they hold slots for the days pending notifications
    /// will fire on.
    private func prunedLog() -> [Reservation] {
        let startOfToday = Date.cal.startOfDay(for: Date())
        return loadLog().filter { $0.fireDate >= startOfToday }
    }

    private func loadLog() -> [Reservation] {
        guard let data = defaults.data(forKey: key) else { return [] }
        if let entries = try? JSONDecoder().decode([Reservation].self, from: data) {
            return entries
        }
        // Builds before the identifier was stored wrote a bare [Date]. Keep
        // those slots so an upgrade does not hand every user a free extra
        // notification today; they carry no identifier, so they can only expire
        // rather than be refunded, which is the safe direction.
        if let dates = try? JSONDecoder().decode([Date].self, from: data) {
            return dates.map { Reservation(id: "", fireDate: $0) }
        }
        return []
    }

    private func saveLog(_ log: [Reservation]) {
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: key)
        }
    }
}
