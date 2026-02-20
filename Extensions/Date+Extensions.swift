import Foundation

extension Date {
    /// Start of the current day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// End of the current day
    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? self
    }

    /// Date N days ago from this date
    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }

    /// Date N weeks ago from this date
    func weeksAgo(_ weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: self) ?? self
    }

    /// Start of week containing this date
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    /// Formatted string for display
    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var mediumDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    /// Date range from N days ago to now
    static func rangeFromNow(days: Int) -> (start: Date, end: Date) {
        let end = Date()
        let start = end.daysAgo(days)
        return (start, end)
    }

    /// Number of days between two dates
    func daysBetween(_ other: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self.startOfDay, to: other.startOfDay)
        return abs(components.day ?? 0)
    }

    /// Day of week as Int (1 = Sunday, 2 = Monday, ... 7 = Saturday)
    var dayOfWeek: Int {
        Calendar.current.component(.weekday, from: self)
    }

    /// Day of week as localized name (e.g. "Monday")
    var dayOfWeekName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }
}
