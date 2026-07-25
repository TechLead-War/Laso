import Foundation

/// Persists today's one action so surfaces outside the Home view can read it.
///
/// `DashboardViewModel.refresh` clears the in-memory action cache immediately
/// before it writes widget snapshots, so a snapshot built from that cache is
/// empty or a day old. Writing the action down when it is computed is what lets
/// the widget, the watch and the phone show the same text.
enum DailyActionStore {

    struct Entry: Codable, Equatable {
        let day: Date
        let title: String
        let subtitle: String
        let icon: String
    }

    private static let key = AppKeys.Data.cachedDailyAction
    private static let defaults = UserDefaults.standard

    static func save(title: String, subtitle: String, icon: String, day: Date = Date()) {
        let entry = Entry(
            day: Date.cal.startOfDay(for: day),
            title: title,
            subtitle: subtitle,
            icon: icon
        )
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: key)
    }

    /// Today's action, or nil when nothing has been computed today. A stored entry
    /// from an earlier day is never returned: yesterday's action on today's wrist
    /// is worse than no action at all.
    static func today() -> Entry? {
        guard let data = defaults.data(forKey: key),
              let entry = try? JSONDecoder().decode(Entry.self, from: data),
              Date.cal.isDateInToday(entry.day) else { return nil }
        return entry
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }
}
