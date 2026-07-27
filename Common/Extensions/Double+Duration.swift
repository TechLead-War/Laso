import Foundation

extension Double {
    /// A number of hours written the way a person reads a clock: "7h 30m", or
    /// "45m" when it is under an hour. One implementation so a duration cannot
    /// print two different ways on two screens.
    var hoursAsClock: String {
        let clamped = Swift.max(0, self)
        let hours = Int(clamped)
        let minutes = Swift.max(0, Int(((clamped - Double(hours)) * 60).rounded()))
        // 59.7 minutes rounds to 60, which would read as "6h 60m".
        if minutes == 60 { return Copy.Common.durationHoursMinutes(hours + 1, 0) }
        if hours == 0 { return Copy.Common.durationMinutes(minutes) }
        return Copy.Common.durationHoursMinutes(hours, minutes)
    }
}
