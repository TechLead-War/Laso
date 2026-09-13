import Foundation

/// Grades yesterday's two moves the morning after.
///
/// Pure: yesterday's log entry, the score result and last night's numbers all
/// arrive in `Input`, so the same rules can be checked without a store.
struct DailyVerdictBuilder {

    struct Input {
        var yesterday: DailyMoveLog.Entry?
        var dayResult: DailyActionResultStore.Result?
        var sleepDebtNow: Double?
        var lastNightSeconds: TimeInterval?
        var sleepOnset: WindDownOutcomeTracker.Outcome?
        var restDaysThisWeekBefore: Int?
        var restDaysThisWeekAfter: Int?
        var restDaysSinceLastRest: Int?
        /// Exercise minutes logged yesterday; nil until the caller has them,
        /// in which case the walk line falls back to the move's own title.
        var walkMinutes: Double? = nil
    }

    /// In bed this long after the target still counts: the target is a
    /// bedtime, not a stopwatch.
    private static let onTimeGraceMinutes = 15
    /// A rest day after one day off is a weekend; after two or more it is news.
    private static let firstRestWorthNamingDays = 2

    /// Nil when nothing was shown yesterday, or when neither move can be
    /// judged yet: the day needs a score result or a tick, the night needs a
    /// balance before and after or a sleep onset.
    static func make(_ input: Input) -> DailyBrief.Verdict? {
        guard let entry = input.yesterday else { return nil }
        var lines: [DailyBrief.Verdict.Line] = []
        var dayIsCounted = false

        if let day = entry.dayMove, input.dayResult != nil || day.doneAt != nil {
            dayIsCounted = dayCounted(input.dayResult, done: day.doneAt != nil)
            let title: String
            if day.source == "rest_walk", let minutes = input.walkMinutes {
                title = Copy.DailyBrief.Verdict.walkLine(Int(minutes))
            } else {
                title = day.title
            }
            var detail = ""
            // Only named when the count actually rose: "counted as a rest day,
            // 0 → 0" would claim a result the workout log does not show.
            if let before = input.restDaysThisWeekBefore, let after = input.restDaysThisWeekAfter, after > before {
                detail = Copy.DailyBrief.Verdict.walkDetail(before, after)
            }
            lines.append(DailyBrief.Verdict.Line(done: dayIsCounted, title: title, detail: detail))
        }

        if let night = entry.nightMove {
            // Only an onset measured against this night's own target says
            // anything about it; the tracker keeps the last night it evaluated.
            let onset = input.sleepOnset.flatMap { outcome -> Date? in
                guard let target = night.bedtimeTarget,
                      Date.cal.isDate(outcome.bedtime, inSameDayAs: target) else { return nil }
                return outcome.onset
            }
            let judgeable = (input.sleepDebtNow != nil && night.sleepDebtHoursAtShow != nil) || onset != nil
            if judgeable {
                let counted = nightCounted(
                    headedIn: night.doneAt, onset: onset, target: night.bedtimeTarget,
                    debtBefore: night.sleepDebtHoursAtShow, debtAfter: input.sleepDebtNow)
                let title: String
                if let inBedAt = night.doneAt ?? onset, let seconds = input.lastNightSeconds {
                    title = Copy.DailyBrief.Verdict.bedLine(
                        DailyBriefBuilder.timeText(inBedAt), (seconds / 3600).hoursAsClock)
                } else {
                    title = night.title
                }
                var detail = ""
                if let before = night.sleepDebtHoursAtShow, let after = input.sleepDebtNow {
                    detail = Copy.DailyBrief.Verdict.bedDetail(before.hoursAsClock, after.hoursAsClock)
                }
                lines.append(DailyBrief.Verdict.Line(done: counted, title: title, detail: detail))
            }
        }

        guard !lines.isEmpty else { return nil }

        let counted = lines.filter(\.done).count
        var headline: String
        if counted == 2 {
            headline = Copy.DailyBrief.Verdict.bothCounted
        } else if counted == 1 {
            headline = Copy.DailyBrief.Verdict.oneCounted
        } else {
            headline = Copy.DailyBrief.Verdict.neither
        }
        let restDayRecorded = (input.restDaysThisWeekAfter ?? 0) > (input.restDaysThisWeekBefore ?? 0)
        if dayIsCounted, restDayRecorded, let gap = input.restDaysSinceLastRest, gap >= firstRestWorthNamingDays {
            headline += " " + Copy.DailyBrief.Verdict.firstRestIn(gap)
        }

        return DailyBrief.Verdict(
            headline: headline,
            lines: lines,
            balanceBefore: entry.nightMove?.sleepDebtHoursAtShow,
            balanceAfter: input.sleepDebtNow
        )
    }

    /// The balance dropped by at least the sleep floor, or the person was in
    /// bed (by their own tap, else by measured onset) close to the target.
    static func nightCounted(headedIn: Date?, onset: Date?, target: Date?,
                             debtBefore: Double?, debtAfter: Double?) -> Bool {
        let floorHours = DailyBriefConfig.nightMoveFloorMinutes / 60
        if let before = debtBefore, let after = debtAfter {
            if before - after >= floorHours { return true }
            // On time but the balance still grew past the floor: going to bed at
            // the right minute did not help, so the verdict must not say it did.
            if after - before >= floorHours { return false }
        }
        guard let target, let inBedAt = headedIn ?? onset,
              let latest = Date.cal.date(byAdding: .minute, value: onTimeGraceMinutes, to: target) else {
            return false
        }
        return inBedAt <= latest
    }

    /// Done, and the score did not fall past the result card's own dead band.
    /// No result yet (no morning lock) still counts: the tick is the person's word.
    static func dayCounted(_ result: DailyActionResultStore.Result?, done: Bool) -> Bool {
        done && (result == nil || result?.direction != .down)
    }
}
