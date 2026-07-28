import Foundation

/// How steady the user's wake time has been against their anchor.
enum WakeAnchorBand {
    case steady
    case close
    case variable
}

/// One night: how far the actual wake time landed from the anchor.
struct WakeDriftPoint: Identifiable, Equatable {
    /// The wake instant itself, so the detail label can show a real clock time.
    let date: Date
    /// Signed minutes from the anchor. Positive means the user woke later.
    let driftMinutes: Int

    var id: Date { date }
}

/// Readout for the wake-window section. Deliberately not a 0–100 score: a
/// composite would be an invented number with no stated method, which is what
/// this replaced. Minutes are a measurement the user can check against a clock.
struct WakeConsistency: Equatable {
    let medianAbsDriftMinutes: Int
    /// Nights that landed inside +/-`driftLooseMinutes` of the anchor.
    let nightsInWindow: Int
    let totalNights: Int
    /// Nil until `consistencyMinNights` nights are tracked. A band computed
    /// from four nights is a number pretending to be a finding.
    let band: WakeAnchorBand?
}

/// Turns overnight wake times into drift against a fixed anchor.
///
/// Pure: no HealthKit, no storage, no I/O.
///
/// Callers pass `HealthKitManager.SleepSessionBoundary.wakeTime`, not the date
/// on a stored sleep sample. Both are wake times, but the boundary is queried
/// live and already classified as an overnight session, so it avoids two real
/// defects in the stored form: a persisted sample's `date` is written once and
/// never corrected on re-sync, and its "longest session of the day" rule lets a
/// long afternoon nap stand in for the night's wake time.
enum WakeAnchorAnalyzer {

    private static let minutesPerDay = 24 * 60

    /// Signed drift per night, oldest first, at most one point per local day.
    ///
    /// - Parameter wakeTimes: overnight wake instants, any order.
    /// - Parameter anchor: the user's chosen wake time.
    /// - Parameter days: how far back to look.
    static func drift(
        from wakeTimes: [Date],
        anchor: (hour: Int, minute: Int),
        days: Int
    ) -> [WakeDriftPoint] {
        guard days > 0 else { return [] }
        let cutoff = Date().daysAgo(days)
        let anchorMinutes = anchor.hour * 60 + anchor.minute

        // One point per local day: a re-query can hand back two boundaries for
        // the same night, and the later wake is the corrected one.
        var latestPerDay: [Date: Date] = [:]
        for wake in wakeTimes where wake >= cutoff {
            let day = wake.startOfDay
            if let existing = latestPerDay[day], existing >= wake { continue }
            latestPerDay[day] = wake
        }

        return latestPerDay.values
            .map { WakeDriftPoint(date: $0, driftMinutes: signedDrift(of: $0, fromAnchorMinutes: anchorMinutes)) }
            .sorted { $0.date < $1.date }
    }

    /// Minutes from the anchor, wrapped to the nearer side of the clock so a
    /// 23:40 wake against an 06:00 anchor reads as −380, not +1060.
    private static func signedDrift(of wake: Date, fromAnchorMinutes anchorMinutes: Int) -> Int {
        let comps = Date.cal.dateComponents([.hour, .minute], from: wake)
        let wakeMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        var delta = wakeMinutes - anchorMinutes
        if delta > minutesPerDay / 2 { delta -= minutesPerDay }
        if delta < -minutesPerDay / 2 { delta += minutesPerDay }
        return delta
    }

    /// Consistency over the most recent `windowDays` of the supplied points.
    static func consistency(
        from points: [WakeDriftPoint],
        windowDays: Int
    ) -> WakeConsistency {
        let cutoff = Date().daysAgo(windowDays)
        let windowed = points.filter { $0.date >= cutoff }

        guard !windowed.isEmpty else {
            return WakeConsistency(
                medianAbsDriftMinutes: 0,
                nightsInWindow: 0,
                totalNights: 0,
                band: nil
            )
        }

        let loose = WakeAnchorConfig.driftLooseMinutes
        let absDrifts = windowed.map { Double(abs($0.driftMinutes)) }
        let median = Int(absDrifts.median.rounded())
        let inWindow = windowed.filter { abs($0.driftMinutes) <= loose }.count

        return WakeConsistency(
            medianAbsDriftMinutes: median,
            nightsInWindow: inWindow,
            totalNights: windowed.count,
            band: windowed.count >= WakeAnchorConfig.consistencyMinNights
                ? band(forMedianAbsDrift: median)
                : nil
        )
    }

    static func band(forMedianAbsDrift minutes: Int) -> WakeAnchorBand {
        if minutes <= WakeAnchorConfig.driftTightMinutes { return .steady }
        if minutes <= WakeAnchorConfig.driftLooseMinutes { return .close }
        return .variable
    }
}
