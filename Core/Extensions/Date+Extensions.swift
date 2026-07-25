import Foundation

extension Date {
    /// Process-wide cached calendar. `Calendar.current` allocates a new copy on
    /// every access; this single static is reused everywhere `Calendar` math is
    /// needed so we never re-allocate on hot paths.
    static let cal: Calendar = Calendar.current

    enum FormatterCache {
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

    /// Returns a thread-cached `DateFormatter` configured with the given format string.
    /// Reuses one formatter per `(thread, format)` pair so callers never allocate per use.
    static func formatter(format: String) -> DateFormatter {
        FormatterCache.formatter(key: "Laso.Date.format.\(format)") { formatter in
            formatter.dateFormat = format
        }
    }

    /// Returns the shared ISO-8601 formatter (thread-cached).
    static var iso8601Formatter: ISO8601DateFormatter {
        let key = "Laso.Date.iso8601"
        let dictionary = Thread.current.threadDictionary
        if let cached = dictionary[key] as? ISO8601DateFormatter {
            return cached
        }
        let formatter = ISO8601DateFormatter()
        dictionary[key] = formatter
        return formatter
    }

    private static var shortDateFormatter: DateFormatter {
        FormatterCache.formatter(key: "Laso.Date.short") { formatter in
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        }
    }

    /// Start of the current day
    var startOfDay: Date {
        Self.cal.startOfDay(for: self)
    }

    /// Date N days ago from this date
    func daysAgo(_ days: Int) -> Date {
        Self.cal.date(byAdding: .day, value: -days, to: self) ?? self
    }

    /// Formatted string for display
    var shortDateString: String {
        Self.shortDateFormatter.string(from: self)
    }

    /// Number of days between two dates
    func daysBetween(_ other: Date) -> Int {
        let components = Self.cal.dateComponents([.day], from: self.startOfDay, to: other.startOfDay)
        return abs(components.day ?? 0)
    }

    /// Day of week as Int (1 = Sunday, 2 = Monday, ... 7 = Saturday)
    var dayOfWeek: Int {
        Self.cal.component(.weekday, from: self)
    }
}
