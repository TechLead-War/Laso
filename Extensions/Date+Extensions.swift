import Foundation

extension Date {
    private enum FormatterCache {
        static func formatter(key: String, configure: (DateFormatter) -> Void) -> DateFormatter {
            let dictionary = Thread.current.threadDictionary
            if let cached = dictionary[key] as? DateFormatter {
                return cached
            }

            let formatter = DateFormatter()
            configure(formatter)
            dictionary[key] = formatter
            return formatter
        }
    }

    private static var shortDateFormatter: DateFormatter {
        FormatterCache.formatter(key: "HealthPulse.Date.short") { formatter in
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        }
    }

    private static var mediumDateFormatter: DateFormatter {
        FormatterCache.formatter(key: "HealthPulse.Date.medium") { formatter in
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
    }

    private static var shortTimeFormatter: DateFormatter {
        FormatterCache.formatter(key: "HealthPulse.Date.time.short") { formatter in
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        }
    }

    private static var weekdayNameFormatter: DateFormatter {
        FormatterCache.formatter(key: "HealthPulse.Date.weekdayName") { formatter in
            formatter.dateFormat = "EEEE"
        }
    }

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
        Self.shortDateFormatter.string(from: self)
    }

    var mediumDateString: String {
        Self.mediumDateFormatter.string(from: self)
    }

    var timeString: String {
        Self.shortTimeFormatter.string(from: self)
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
        Self.weekdayNameFormatter.string(from: self)
    }
}
