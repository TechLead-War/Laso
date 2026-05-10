import Foundation

/// Computes the user's recent typical bedtime from sleep history.
/// Used to make wind-down and evening notifications time-personal instead
/// of using a fixed 10:30/10:45/11:00 PM string.
struct BedtimeChronotype {
    /// Returns a display string like "10:42 PM" if at least 7 days of recent
    /// sleep starts are available, otherwise nil. Caller falls back to default.
    /// 7 days is the minimum sample for a stable median that survives a single
    /// late night without skewing the chronotype anchor.
    static func recentMedianBedtime(sleepStarts: [Date], calendar: Calendar = Date.cal) -> String? {
        guard sleepStarts.count >= 7 else { return nil }
        let minutes: [Int] = sleepStarts.map { date in
            let comps = calendar.dateComponents([.hour, .minute], from: date)
            // Treat hours after noon as "tonight" (e.g. 22:30 = 1350 min).
            // Hours before noon roll over (e.g. 1:15 AM = 1500 + 75 = 1575)
            // so a 12:30 AM bedtime sorts after 11:00 PM.
            let hour = comps.hour ?? 0
            let minute = comps.minute ?? 0
            return hour < 12 ? (hour + 24) * 60 + minute : hour * 60 + minute
        }.sorted()
        let median = minutes[minutes.count / 2]
        let hour24 = (median / 60) % 24
        let minute = median % 60
        let hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24)
        let suffix = hour24 >= 12 ? "PM" : "AM"
        return String(format: "%d:%02d %@", hour12, minute, suffix)
    }
}
