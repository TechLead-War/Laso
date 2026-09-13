import Foundation
import Testing
@testable import Laso

/// The stores behind the daily brief: the three-week focus, the move log, the
/// rest-day maths every brief surface shares, and the schema pin.
struct DailyBriefStoreTests {

    private static func throwawaySuite() -> (UserDefaults, String) {
        let name = "dailybrief.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    /// A focus is a three-week commitment: a second start is ignored, a refresh
    /// that lands the same numbers writes nothing, and day 21 is the last day
    /// before it closes itself with a grade.
    @Test func aFocusStartsClosesAndExpiresOnDayTwentyOne() {
        let (suite, name) = Self.throwawaySuite()
        defer { suite.removePersistentDomain(forName: name) }
        let store = FocusStore(defaults: suite)
        let start = Date()
        let kpis = [
            FocusStore.KPISnapshot(kind: .restDaysPerWeek, day1: 1.0, latest: 1.0, latestAt: start),
            FocusStore.KPISnapshot(kind: .sleepBalanceHours, day1: -2.33, latest: -2.33, latestAt: start)
        ]

        store.start(driver: .restDays, kpis: kpis, now: start)
        #expect(store.active?.driver == .restDays)
        #expect(store.active?.dayIndex(now: start) == 1)
        let afterStart = store.revision

        store.start(driver: .sleepBalance, kpis: [], now: start)
        #expect(store.active?.driver == .restDays, "a second start while one is running is ignored")
        #expect(store.revision == afterStart)

        #expect(!store.updateLatest([.restDaysPerWeek: 1.0], now: start), "the same value is not a change")
        #expect(store.revision == afterStart)
        #expect(store.updateLatest([.restDaysPerWeek: 2.0], now: start))
        #expect(store.revision == afterStart + 1)

        let day21 = Date.cal.date(byAdding: .day, value: 20, to: start)!
        store.expireIfNeeded(now: day21)
        #expect(store.active != nil, "day 21 is still inside the focus")
        #expect(store.active?.dayIndex(now: day21) == 21)

        let dayAfter = Date.cal.date(byAdding: .day, value: 21, to: start)!
        store.expireIfNeeded(now: dayAfter)
        #expect(store.active == nil, "three full weeks closes it")
        #expect(store.past.first?.outcome == .improved, "1.0 to 2.0 rest days clears the floor")
        #expect(store.past.first?.endedAt == dayAfter)
        #expect(store.past.first?.dayIndex(now: dayAfter) == 21, "a closed focus never prints day 22")

        let reloaded = FocusStore(defaults: suite)
        #expect(reloaded.active == nil)
        #expect(reloaded.past == store.past, "history survives a relaunch")

        for _ in 0..<(DailyBriefConfig.pastFocusRetention + 3) {
            store.start(driver: .stressHigh, kpis: [], now: start)
            store.close(outcome: .noChange, now: start)
        }
        #expect(store.past.count == DailyBriefConfig.pastFocusRetention, "past focuses are bounded")
    }

    /// A night move done at 00:10 belongs to the evening it was shown on, a
    /// done move keeps its tick and its text, and old days fall out of the log.
    /// A focus ends early, as worked, once its driver has stayed at usual for the
    /// configured run of days. One off day in the middle restarts the count.
    @Test func aFocusClosesEarlyOnceItsDriverStaysAtUsual() {
        let (defaults, suite) = Self.throwawaySuite()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FocusStore(defaults: defaults)
        let start = Date.cal.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
        func day(_ n: Int) -> Date { Date.cal.date(byAdding: .day, value: n, to: start)! }
        store.start(driver: .sleepBalance,
                    kpis: [.init(kind: .sleepBalanceHours, day1: -3, latest: -3, latestAt: start)], now: start)

        store.noteDriver(isOff: false, now: day(1))
        store.noteDriver(isOff: false, now: day(3))
        store.noteDriver(isOff: true, now: day(4))
        #expect(store.active?.atUsualSince == nil, "an off day restarts the run")

        store.noteDriver(isOff: false, now: day(5))
        let early = DailyBriefConfig.focusEarlyCloseDays
        #expect(!store.noteDriver(isOff: false, now: day(5 + early - 1)), "one day short of the run keeps it open")
        #expect(store.noteDriver(isOff: false, now: day(5 + early)))
        #expect(store.active == nil)
        #expect(store.past.first?.outcome == .improved, "the driver clearing is what the focus was for")
    }

    @MainActor
    @Test func theMoveLogIsKeyedByCalendarDay() {
        let (suite, name) = Self.throwawaySuite()
        let previous = DailyMoveLog.defaults
        DailyMoveLog.defaults = suite
        defer {
            DailyMoveLog.defaults = previous
            suite.removePersistentDomain(forName: name)
        }

        let evening = Date.cal.date(bySettingHour: 23, minute: 50, second: 0, of: Date())!
        let afterMidnight = Date.cal.date(byAdding: .minute, value: 20, to: evening)!
        let night = DailyMoveLog.Move(title: "In bed by 22:30", icon: "moon.fill", source: "advisor",
                                      shownAt: evening, doneAt: nil, bedtimeTarget: nil, sleepDebtHoursAtShow: 2.33)

        DailyMoveLog.recordShown(day: evening, dayMove: nil, nightMove: night)
        let afterShow = DailyMoveLog.revision
        #expect(DailyMoveLog.markDone(.night, at: afterMidnight, day: evening))
        #expect(DailyMoveLog.revision == afterShow + 1)
        #expect(DailyMoveLog.entry(for: afterMidnight) == nil, "00:10 is the next calendar day")
        #expect(DailyMoveLog.isDone(.night, on: evening))
        #expect(DailyMoveLog.entry(for: evening)?.nightMove?.doneAt == afterMidnight)
        #expect(DailyMoveLog.yesterday(relativeTo: afterMidnight)?.day == Date.cal.startOfDay(for: evening))
        #expect(!DailyMoveLog.markDone(.night, at: afterMidnight, day: evening), "a second tap is refused")
        #expect(!DailyMoveLog.markDone(.day, at: afterMidnight, day: evening), "no day move was shown")
        #expect(DailyMoveLog.revision == afterShow + 1, "refused taps write nothing")

        var reshown = night
        reshown.title = "Lights out"
        reshown.shownAt = afterMidnight
        DailyMoveLog.recordShown(day: evening, dayMove: nil, nightMove: reshown)
        let done = DailyMoveLog.entry(for: evening)?.nightMove
        #expect(done?.doneAt == afterMidnight, "re-showing never clears the tick")
        #expect(done?.shownAt == evening, "the first sighting stands")
        #expect(done?.title == night.title, "a done move keeps the text the person acted on")

        let walk = DailyMoveLog.Move(title: "Walk 20 min", icon: "figure.walk", source: "advisor",
                                     shownAt: evening, doneAt: nil, bedtimeTarget: nil, sleepDebtHoursAtShow: nil)
        DailyMoveLog.recordShown(day: evening, dayMove: walk, nightMove: nil)
        var longer = walk
        longer.title = "Walk 30 min"
        longer.shownAt = afterMidnight
        DailyMoveLog.recordShown(day: evening, dayMove: longer, nightMove: nil)
        let pending = DailyMoveLog.entry(for: evening)?.dayMove
        #expect(pending?.title == "Walk 30 min", "an undone move follows the advisor's newer text")
        #expect(pending?.shownAt == evening)
        #expect(DailyMoveLog.entry(for: evening)?.nightMove == done, "the other move is untouched")

        let stale = Date.cal.date(byAdding: .day, value: -(DailyBriefConfig.moveLogRetentionDays + 1), to: Date())!
        DailyMoveLog.recordShown(day: stale, dayMove: walk, nightMove: nil)
        #expect(DailyMoveLog.entry(for: stale) == nil, "days past retention are dropped")
        #expect(DailyMoveLog.entry(for: evening) != nil)

        DailyMoveLog.clear()
        #expect(DailyMoveLog.loadHistory().isEmpty)
    }

    /// Adding a SwiftData model changes the schema version and wipes every
    /// user's database on launch. New records go to UserDefaults instead.
    @Test func theSchemaVersionDidNotMove() {
        #expect(HealthDataContainerFactory.allModels.count == 11)
    }

    /// The rest-day insight, the brief's driver and the focus KPI all read one
    /// rest-day definition; this pins the maths and the text to each other.
    @Test func restDeficitMatchesTheInsightMaths() {
        let today = Date.cal.startOfDay(for: Date())
        func series(workoutOn: (Int) -> Bool) -> MetricTimeSeries {
            MetricTimeSeries(metric: .workoutDuration, samples: (0..<28).map { back in
                MetricSample(date: Date.cal.date(byAdding: .day, value: -back, to: today)!,
                             value: workoutOn(back) ? 45 : 0)
            })
        }

        let heavy: [HealthMetric: MetricTimeSeries] = [.workoutDuration: series { $0 % 7 != 0 }]
        let deficit = RecoveryAnalyzer.restDeficit(timeSeries: heavy, baselines: [:])
        #expect(deficit?.restDays28 == 4)
        #expect(deficit?.workoutDays28 == 24)
        #expect(deficit?.highIntensity28 == 0, "no calorie baseline means no session is graded high")
        #expect(deficit?.recommendedPerWeek == 2)
        #expect(deficit?.restPerWeek == 1.0)

        let insight = RecoveryAnalyzer.generateInsights(timeSeries: heavy, baselines: [:], trends: [:])
            .first { $0.title == Copy.Analysis.Recovery.restDayDeficit }
        #expect(insight?.summary.contains("24 workout days, 4 rest days") == true)
        #expect(insight?.baselineValue == 2)

        let balanced: [HealthMetric: MetricTimeSeries] = [.workoutDuration: series { $0 % 2 == 0 }]
        #expect(RecoveryAnalyzer.restDeficit(timeSeries: balanced, baselines: [:]) == nil,
                "enough rest is not a deficit")
    }
}
