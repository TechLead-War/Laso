import Foundation
import HealthKit

struct LiveSleepSummary: Equatable {
    /// Asleep-stage time only. This is what the readiness scorer is allowed to
    /// see, so it must never absorb the in-bed stand-in below.
    var totalDuration: TimeInterval = 0
    var deepSleep: TimeInterval = 0
    var remSleep: TimeInterval = 0
    var coreSleep: TimeInterval = 0
    var awakeTime: TimeInterval = 0
    /// Time in bed, kept apart from `totalDuration`. A source that writes nothing
    /// but `.inBed` (an iPhone bedtime schedule, some third-party trackers) gives
    /// no other signal, so the tile falls back to this, but scoring never does.
    var inBedDuration: TimeInterval = 0

    /// What the sleep tile shows: real asleep time when any source recorded a
    /// stage, and time in bed only when nothing did.
    var displayDuration: TimeInterval { totalDuration > 0 ? totalDuration : inBedDuration }
}

struct LiveSleepSummaryBuilder {
    /// Hour on the previous day the query window opens at. Noon, not 18:00: the
    /// consumer queries with `.strictStartDate`, which drops a sample whose start
    /// falls outside the window instead of clipping it, so an early bedtime and a
    /// day sleeper's main block were being lost whole.
    let lookbackHour: Int

    /// Blocks separated by more than this are counted as different sleeps.
    let sessionGap: TimeInterval

    init(lookbackHour: Int = 12, sessionGap: TimeInterval = HealthKitManager.sleepSessionGapThreshold) {
        self.lookbackHour = lookbackHour
        self.sessionGap = sessionGap
    }

    /// Window covering every sleep block that could be the most recent one, on any
    /// schedule. It is deliberately wider than a night: `summarize` keeps only the
    /// latest wake day out of it, so extra naps in range cost nothing.
    func queryWindow(
        containing now: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> DateInterval? {
        // The window hangs off "yesterday", so the day boundary has to be the
        // user's own zone rather than whatever zone a caller's calendar carried.
        var dayCalendar = calendar
        dayCalendar.timeZone = timeZone

        let startOfToday = dayCalendar.startOfDay(for: now)
        guard let yesterday = dayCalendar.date(byAdding: .day, value: -1, to: startOfToday),
              let windowStart = dayCalendar.date(
                bySettingHour: lookbackHour,
                minute: 0,
                second: 0,
                of: yesterday
              ),
              windowStart < now else {
            return nil
        }

        return DateInterval(start: windowStart, end: now)
    }

    /// Last night's sleep: every block that ended on the most recent wake day.
    ///
    /// Grouped and unioned exactly the way the stored pipeline does it, so the
    /// tile and the persisted series never disagree. Two details carry that:
    /// a night the watch left a gap in arrives as two blocks that share a wake
    /// day and must be added, not picked between; and two writers recording the
    /// same night must count a shared minute once, not twice.
    func summarize(samples: [HKCategorySample], calendar: Calendar = .current) -> LiveSleepSummary {
        let sessions = sessions(from: samples)
        guard let wakeDay = sessions.map({ calendar.startOfDay(for: $0.end) }).max() else {
            return LiveSleepSummary()
        }
        let tonight = sessions.filter { calendar.startOfDay(for: $0.end) == wakeDay }
        return summarize(sessions: tonight)
    }

    // MARK: - Sessions

    private struct Session {
        var end: Date
        var samples: [HKCategorySample]
    }

    /// Sessions are cut on asleep stages alone, matching the stored pipeline. An
    /// `.inBed` sample often spans the whole night on its own, so letting it join
    /// the grouping would weld two genuinely separate sleeps into one.
    private func sessions(from samples: [HKCategorySample]) -> [Session] {
        let ordered = samples.sorted { $0.startDate < $1.startDate }
        let asleep = ordered.filter { Self.isAsleepStage($0) }

        // Nothing but in-bed samples: the whole window is one session, otherwise
        // the only cohort this fallback exists for would get no session at all.
        guard !asleep.isEmpty else {
            guard let end = ordered.map(\.endDate).max() else { return [] }
            return [Session(end: end, samples: ordered)]
        }

        var sessions: [Session] = []
        for sample in asleep {
            if var last = sessions.last, sample.startDate.timeIntervalSince(last.end) <= sessionGap {
                if sample.endDate > last.end { last.end = sample.endDate }
                last.samples.append(sample)
                sessions[sessions.count - 1] = last
            } else {
                sessions.append(Session(end: sample.endDate, samples: [sample]))
            }
        }

        // Awake and in-bed samples ride along with the session they touch, so a
        // 23:00 awake stretch lands on the night it belongs to rather than being
        // dropped or counted against the previous day.
        for sample in ordered where !Self.isAsleepStage(sample) {
            let index = sessions.firstIndex {
                sample.endDate >= $0.samples[0].startDate.addingTimeInterval(-sessionGap)
                    && sample.startDate <= $0.end.addingTimeInterval(sessionGap)
            }
            if let index { sessions[index].samples.append(sample) }
        }

        return sessions
    }

    private func summarize(sessions: [Session]) -> LiveSleepSummary {
        var spans: [HKCategoryValueSleepAnalysis: [(start: Date, end: Date)]] = [:]
        for sample in sessions.flatMap(\.samples) {
            guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  sample.endDate > sample.startDate else { continue }
            spans[value, default: []].append((sample.startDate, sample.endDate))
        }

        var summary = LiveSleepSummary()
        summary.deepSleep = Self.unionDuration(spans[.asleepDeep] ?? [])
        summary.remSleep = Self.unionDuration(spans[.asleepREM] ?? [])
        summary.coreSleep = Self.unionDuration(spans[.asleepCore] ?? [])
        summary.awakeTime = Self.unionDuration(spans[.awake] ?? [])
        summary.inBedDuration = Self.unionDuration(spans[.inBed] ?? [])

        // Unioned across stages, not summed per stage: a night carrying both a
        // staged source and an unspecified one overlaps, and adding the stage
        // totals would count those minutes twice.
        let asleepSpans = Self.asleepStageValues.flatMap { spans[$0] ?? [] }
        summary.totalDuration = Self.unionDuration(asleepSpans)

        return summary
    }

    private static let asleepStageValues: [HKCategoryValueSleepAnalysis] = [
        .asleepDeep, .asleepREM, .asleepCore, .asleepUnspecified,
    ]

    private static func isAsleepStage(_ sample: HKCategorySample) -> Bool {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
        return asleepStageValues.contains(value)
    }

    /// Seconds covered by these spans, counting a minute two sources both
    /// recorded once. Mirrors the stored pipeline's union, which exists because
    /// summing raw durations doubled every shared minute.
    private static func unionDuration(_ spans: [(start: Date, end: Date)]) -> TimeInterval {
        var total: TimeInterval = 0
        var open: (start: Date, end: Date)?
        for span in spans.sorted(by: { $0.start < $1.start }) where span.end > span.start {
            if var current = open, span.start <= current.end {
                if span.end > current.end { current.end = span.end }
                open = current
            } else {
                if let current = open { total += current.end.timeIntervalSince(current.start) }
                open = span
            }
        }
        if let current = open { total += current.end.timeIntervalSince(current.start) }
        return total
    }
}
