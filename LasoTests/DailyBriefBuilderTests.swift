import Foundation
import Testing
@testable import Laso

/// The rules the Today tab is built on, pinned so a refactor of the engines
/// cannot quietly change what the person is told.
@MainActor
struct DailyBriefBuilderTests {

    // MARK: - Drivers

    /// The reference morning: 4 rest days in 28, a 2h 20m balance that is not
    /// growing, and bounce-back 6% under usual. The ranking table scores them
    /// 4.0, 3.17 and 2.7, so rest leads, then sleep, then bounce-back.
    @Test func driversRankRestSleepAndBounceBackInThatOrder() {
        let drivers = DailyBriefBuilder.rankDrivers(Self.referenceMorning(), limit: 3)

        #expect(drivers.map(\.kind) == [.restDays, .sleepBalance, .heartRateBounceBack])
        #expect(drivers.map(\.valueText) == [
            Copy.DailyBrief.Driver.restDaysValue(4, 28),
            (2.0 + 20.0 / 60.0).hoursAsClock,
            Copy.DailyBrief.Driver.hrrValue(6)
        ])
        #expect(drivers[0].sentence == Copy.DailyBrief.Driver.restDaysSentence(24, 4, 2))
        #expect(drivers[1].sentence == Copy.DailyBrief.Driver.sleepBalanceSentence(
            SleepDebtTracker.nightsToClear(debtHours: 2.0 + 20.0 / 60.0)))
        #expect(drivers.filter { $0.tone == .poor }.map(\.kind) == [.restDays],
                "a score of four or more reads red")
    }

    /// An anomaly on a metric a named driver already explains, or a second
    /// anomaly on the same metric, must not make a second row.
    @Test func aDriverIsNeverListedTwiceForOneMetric() {
        var s = Self.referenceMorning()
        s.anomalies = [
            Self.anomaly(.workoutDuration, z: 2.0),
            Self.anomaly(.restingHeartRate, z: 1.8),
            Self.anomaly(.restingHeartRate, z: 2.9, severity: .critical),
            Self.anomaly(.heartRateRecovery, z: 2.2),
            Self.anomaly(.steps, z: 0.4, severity: .info)
        ]
        let drivers = DailyBriefBuilder.rankDrivers(s, limit: 10)

        let metrics = drivers.map(\.kind.metric)
        #expect(Set(metrics).count == metrics.count, "one metric, one row: \(drivers.map(\.kind.id))")
        #expect(drivers.map(\.kind).contains(.restDays))
        #expect(!drivers.map(\.kind).contains(.anomaly(.workoutDuration)),
                "rest days already explain the workout signal")
        #expect(!drivers.map(\.kind).contains(.anomaly(.heartRateRecovery)),
                "bounce-back already explains heart rate recovery")
        #expect(drivers.filter { $0.kind == .anomaly(.restingHeartRate) }.count == 1)
        #expect(!drivers.map(\.kind).contains(.anomaly(.steps)), "an info-level wobble is not a driver")
    }

    // MARK: - Status

    /// The chip must grade the score through `DS.recoveryTier`, the app's one
    /// readiness table, so the chip can never disagree with the ring.
    @Test func theStatusChipComesFromOneReadinessTable() {
        for score in 0...100 {
            var s = Self.referenceMorning()
            s.readiness = score
            let chip = DailyBriefBuilder.status(s, topDrivers: []).chips.first
            let expected: DailyBrief.Tone
            switch DS.recoveryTier(for: score) {
            case .optimal: expected = .good
            case .fair: expected = .fair
            case .poor: expected = .poor
            }
            #expect(chip?.tone == expected, "score \(score)")
        }
    }

    /// A thin history gives the learning copy and nothing that needs a usual.
    @Test func aThinHistoryGivesStatusOnly() {
        var s = Self.referenceMorning()
        s.readinessHistory = Array(s.readinessHistory.suffix(3))
        s.focus = FocusStore.FocusRecord(
            id: UUID(), driver: .restDays, startedAt: s.now, endedAt: nil, outcome: nil,
            kpis: [FocusStore.KPISnapshot(kind: .restDaysPerWeek, day1: 1, latest: 1, latestAt: s.now)])

        let brief = DailyBriefBuilder().build(s)

        #expect(brief.drivers.isEmpty)
        #expect(brief.focus == nil)
        #expect(brief.status.headline == Copy.DailyBrief.Status.learning)
        #expect(brief.status.sentence == Copy.DailyBrief.Status.learningSentence(4))
        #expect(brief.status.chips.count == 1, "the readiness chip still shows; the driver chip does not")
    }

    // MARK: - Moves

    /// The day move comes from the advisor with `daytimeOnly`, so a growing
    /// sleep balance and a bedtime policy action must both fall through to a
    /// daytime rung. The default keeps the sleep action winning on Home.
    @Test func theDayMoveIsNeverABedtime() {
        let advisor = DashboardSmartActionAdvisor()
        let live = DashboardSmartActionAdvisor.LiveSnapshot(
            hour: 21, stressLevel: nil, readinessScore: 70, hasSleepData: true,
            sleepHours: 5, deepSleepMinutes: 30, exerciseMinutes: 10, exerciseGoal: 30,
            latestRestingHeartRate: nil)
        let analysis = DashboardSmartActionAdvisor.AnalysisSnapshot(
            policyDecision: Self.decision(actionType: .sleepEarlier),
            restingHeartRateBaselineMean: nil, userFocuses: [.sleep], topInsights: [],
            restContext: nil, sleepDebtHours: 9, sleepDebtIsGrowing: true)

        let day = advisor.recommend(live: live, analysis: analysis, daytimeOnly: true)
        #expect(!DashboardSmartActionAdvisor.eveningAnchoredIcons.contains(day.icon),
                "\(day.source) / \(day.icon) is an evening action")
        #expect(day.source != "sleep_bank" && day.source != "policy_engine")

        let home = advisor.recommend(live: live, analysis: analysis)
        #expect(home.source == "sleep_bank", "the default chain is untouched")

        var s = Self.referenceMorning()
        s.advisor = day
        let move = DailyBriefBuilder.dayMove(s, drivers: DailyBriefBuilder.rankDrivers(s, limit: 3))
        #expect(!DashboardSmartActionAdvisor.eveningAnchoredIcons.contains(move.icon))
    }

    /// No computed bedtime, no night move: the app never invents one. With one,
    /// the reminder names the wind-down time and "in bed now" only opens near it.
    @Test func theNightMoveNeedsABedtime() {
        var s = Self.referenceMorning()
        s.sleepNeed = nil
        #expect(DailyBriefBuilder.nightMove(s) == nil)

        let bedtime = Date.cal.date(bySettingHour: 22, minute: 30, second: 0, of: s.now)!
        let wake = Date.cal.date(byAdding: .hour, value: 8, to: bedtime)!
        s.sleepNeed = SleepNeed(recommendedBedtime: bedtime, recommendedWakeTime: wake)

        s.now = Date.cal.date(byAdding: .hour, value: -3, to: bedtime)!
        let afternoon = DailyBriefBuilder.nightMove(s)
        #expect(afternoon?.title == Copy.DailyBrief.Night.title(DailyBriefBuilder.timeText(bedtime)))
        #expect(afternoon?.bedtime == bedtime)
        #expect(afternoon?.canMarkDoneNow == false, "three hours early is not in bed")
        let reminderAt = Date.cal.date(byAdding: .minute, value: -60, to: bedtime)!
        #expect(afternoon?.reminderLabel == Copy.DailyBrief.Night.remindAt(DailyBriefBuilder.timeText(reminderAt)))
        #expect(afternoon?.reason == Copy.DailyBrief.Night.paysBack(
            Copy.DailyBrief.KPI.minutes(Int(SleepDebtTracker.paybackExtraMinutes)),
            of: (2.0 + 20.0 / 60.0).hoursAsClock,
            wake: DailyBriefBuilder.timeText(wake)))

        s.now = Date.cal.date(byAdding: .minute, value: -30, to: bedtime)!
        #expect(DailyBriefBuilder.nightMove(s)?.canMarkDoneNow == true)

        s.nightDoneYesterday = true
        let second = DailyBriefBuilder.nightMove(s)
        #expect(second?.title == Copy.DailyBrief.Night.titleAgain(DailyBriefBuilder.timeText(bedtime)))
        #expect(second?.reason == Copy.DailyBrief.Night.twoNights)
    }

    // MARK: - Verdict

    /// The verdict grades the day move by the same ±2 dead band as the result
    /// card, so the two can never disagree about whether the score moved.
    @Test func theDayVerdictKeepsTheTwoPointDeadBand() {
        func result(delta: Int) -> DailyActionResultStore.Result {
            DailyActionResultStore.Result(
                record: DailyActionResultStore.Record(
                    doneDate: Date(), actionTitle: "walk", actionIcon: "figure.walk", morningLockOnDoneDay: 80),
                todayMorningLock: 80 + delta)
        }

        #expect(DailyVerdictBuilder.dayCounted(result(delta: -1), done: true), "one point down is noise")
        #expect(!DailyVerdictBuilder.dayCounted(result(delta: -DailyActionResultStore.deadBand), done: true),
                "the dead band edge is a real drop")
        #expect(DailyVerdictBuilder.dayCounted(result(delta: 5), done: true))
        #expect(DailyVerdictBuilder.dayCounted(nil, done: true), "no lock yet: the tick is the person's word")
        #expect(!DailyVerdictBuilder.dayCounted(result(delta: 5), done: false), "not done cannot count")
    }

    /// A night counts when the balance dropped by at least the sleep floor, or
    /// the person was in bed (own tap first, else measured onset) within 15
    /// minutes of the target.
    @Test func theNightVerdictNeedsTwentyMinutesOrAnOnTimeBedtime() {
        let target = Date.cal.date(bySettingHour: 22, minute: 30, second: 0, of: Date())!
        let floorHours = DailyBriefConfig.nightMoveFloorMinutes / 60

        #expect(DailyVerdictBuilder.nightCounted(
            headedIn: nil, onset: nil, target: target, debtBefore: 2.5, debtAfter: 2.5 - floorHours))
        #expect(!DailyVerdictBuilder.nightCounted(
            headedIn: nil, onset: nil, target: target, debtBefore: 2.5, debtAfter: 2.5 - floorHours / 2),
            "ten minutes is inside the floor")

        let tenLate = Date.cal.date(byAdding: .minute, value: 10, to: target)!
        let twentyLate = Date.cal.date(byAdding: .minute, value: 20, to: target)!
        #expect(DailyVerdictBuilder.nightCounted(
            headedIn: tenLate, onset: nil, target: target, debtBefore: nil, debtAfter: nil))
        #expect(!DailyVerdictBuilder.nightCounted(
            headedIn: twentyLate, onset: nil, target: target, debtBefore: nil, debtAfter: nil))
        #expect(DailyVerdictBuilder.nightCounted(
            headedIn: nil, onset: tenLate, target: target, debtBefore: nil, debtAfter: nil),
            "measured onset stands in when there was no tap")
        #expect(!DailyVerdictBuilder.nightCounted(
            headedIn: twentyLate, onset: tenLate, target: target, debtBefore: nil, debtAfter: nil),
            "the person's own tap outranks the sensor")

        // End to end: yesterday showed both moves, the walk was done and the
        // score held, the night was late but the balance dropped.
        let yesterday = Date.cal.date(byAdding: .day, value: -1, to: Date())!
        let entry = DailyMoveLog.Entry(
            day: Date.cal.startOfDay(for: yesterday),
            dayMove: DailyMoveLog.Move(
                title: Copy.DailyBrief.Day.walkTitle, icon: "figure.walk", source: "rest_walk",
                shownAt: yesterday, doneAt: yesterday, bedtimeTarget: nil, sleepDebtHoursAtShow: nil),
            nightMove: DailyMoveLog.Move(
                title: "bed", icon: "bed.double.fill", source: "sleep_need",
                shownAt: yesterday, doneAt: twentyLate, bedtimeTarget: target, sleepDebtHoursAtShow: 2.5))
        let verdict = DailyVerdictBuilder.make(DailyVerdictBuilder.Input(
            yesterday: entry, dayResult: nil,
            sleepDebtNow: 1.5, lastNightSeconds: 7.5 * 3600, sleepOnset: nil,
            restDaysThisWeekBefore: 1, restDaysThisWeekAfter: 2, restDaysSinceLastRest: 9,
            walkMinutes: 32))

        #expect(verdict?.headline == Copy.DailyBrief.Verdict.bothCounted + " " + Copy.DailyBrief.Verdict.firstRestIn(9))
        #expect(verdict?.lines.map(\.done) == [true, true])
        #expect(verdict?.lines.first?.title == Copy.DailyBrief.Verdict.walkLine(32))
        #expect(verdict?.lines.first?.detail == Copy.DailyBrief.Verdict.walkDetail(1, 2))
        #expect(verdict?.lines.last?.detail == Copy.DailyBrief.Verdict.bedDetail(2.5.hoursAsClock, 1.5.hoursAsClock))
        #expect(verdict?.balanceBefore == 2.5 && verdict?.balanceAfter == 1.5)

        #expect(DailyVerdictBuilder.make(DailyVerdictBuilder.Input(
            yesterday: nil, dayResult: nil, sleepDebtNow: nil,
            lastNightSeconds: nil, sleepOnset: nil, restDaysThisWeekBefore: nil, restDaysThisWeekAfter: nil,
            restDaysSinceLastRest: nil)) == nil, "nothing shown, nothing to grade")
    }

    // MARK: - Fixtures

    /// The approved reference morning: readiness 96 over a fortnight in the
    /// 70s and 80s, 4 rest days in 28, 2h 20m behind, bounce-back 6% under.
    /// Being in bed on time does not make a night count when the balance still
    /// grew past the floor; the verdict would otherwise praise a worse night.
    @Test func anOnTimeNightThatGrewTheBalanceDoesNotCount() {
        let target = Date.cal.date(bySettingHour: 22, minute: 30, second: 0, of: Date())!
        let onTime = Date.cal.date(byAdding: .minute, value: -6, to: target)!
        let floorHours = DailyBriefConfig.nightMoveFloorMinutes / 60
        #expect(!DailyVerdictBuilder.nightCounted(
            headedIn: onTime, onset: nil, target: target, debtBefore: 2.33, debtAfter: 2.33 + floorHours))
        #expect(DailyVerdictBuilder.nightCounted(
            headedIn: onTime, onset: nil, target: target, debtBefore: 2.33, debtAfter: 2.33 + floorHours / 2),
            "a change inside the floor leaves the on-time rule in charge")
    }

    /// The engine can hand back a morning bedtime when no wake anchor exists.
    @Test func aDaytimeBedtimeIsNeverOffered() {
        func at(_ hour: Int) -> Date { Date.cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date())! }
        #expect(DailyBriefBuilder.isPlausibleBedtime(at(22)))
        #expect(DailyBriefBuilder.isPlausibleBedtime(at(1)))
        #expect(!DailyBriefBuilder.isPlausibleBedtime(at(9)))
        #expect(!DailyBriefBuilder.isPlausibleBedtime(at(15)))
    }

    /// A focus number that moved the wrong way is not drawn as progress.
    @Test func aFocusNumberThatFellIsNotMarkedImproved() {
        let record = FocusStore.FocusRecord(
            id: UUID(), driver: .restDays, startedAt: Date().addingTimeInterval(-5 * 86_400), endedAt: nil, outcome: nil,
            kpis: [
                .init(kind: .vo2Max, day1: 50.3, latest: 38.7, latestAt: Date()),
                .init(kind: .restingHR, day1: 58, latest: 54, latestAt: Date())
            ])
        let cells = DailyBriefBuilder.focusView(record, now: Date()).kpis
        #expect(cells[0].improved == false, "VO2 max falling is worse")
        #expect(cells[1].improved == true, "resting heart rate falling is better")
    }

    private static func referenceMorning() -> DailyBriefBuilder.Snapshot {
        let now = Date.cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let history: [(date: Date, score: Int)] = (0..<14).map { offset in
            (date: Date.cal.date(byAdding: .day, value: offset - 14, to: now)!, score: 72 + offset)
        }
        let hrrBaseline = UserBaseline(metric: .heartRateRecovery, mean: 30, standardDeviation: 2,
                                       median: 30, sampleCount: 30, lastUpdated: now)
        return DailyBriefBuilder.Snapshot(
            now: now, readiness: 96, readinessHistory: history, trajectory: nil,
            anomalies: [],
            restDeficit: RecoveryAnalyzer.RestDeficit(restDays28: 4, workoutDays28: 24, highIntensity28: 10, recommendedPerWeek: 2),
            sleepDebt: SleepDebtTracker.SleepDebtInfo(totalDebtHours: 2.0 + 20.0 / 60.0, dailyDeficits: []),
            sleepDebtTrend: .stable,
            hrr: (current: 28.2, baseline: hrrBaseline),
            strainLast6: [], strainTarget: nil, baselines: [.heartRateRecovery: hrrBaseline], latest: [:],
            stressLevel: 20,
            advisor: DashboardSmartActionAdvisor.Recommendation(icon: "figure.walk", title: "walk", subtitle: "why"),
            exerciseMinutes: 0, exerciseGoal: 30, sleepNeed: nil, restContext: nil,
            dayDone: false, nightDone: false, nightDoneYesterday: false,
            dayReminderFire: nil, nightReminderFire: nil, focus: nil, verdict: nil
        )
    }

    private static func anomaly(_ metric: HealthMetric, z: Double, severity: Severity = .warning) -> AnomalyDetector.AnomalyResult {
        AnomalyDetector.AnomalyResult(
            metric: metric, severity: severity, deviationPercent: z * 10, zScore: z,
            currentValue: 60, baselineValue: 50, isAboveBaseline: true, outsideNormalRange: true)
    }

    private static func decision(actionType: InterventionCandidate.ActionType) -> PolicyDecision {
        let candidate = InterventionCandidate(
            id: "test", targetMetric: .sleepDuration, actionType: actionType, source: .trendReversal,
            predictedUplift: 0.4, upliftConfidence: 0.8, effortCost: 0.2,
            timeToBenefit: .nextDay, adherenceLikelihood: 0.7, historicalEffectiveness: nil,
            evidence: InterventionEvidence(
                historicalResponseMean: nil, historicalResponseCount: 0,
                forecastedScoreDelta: nil, uncertaintyBand: nil,
                contributingFeatures: [], grangerPValue: nil,
                grangerEffectSize: nil, grangerOptimalLag: nil))
        let ranked = PolicyDecision.RankedIntervention(
            candidate: candidate, expectedUtility: 0.6, noveltyFactor: 1.0,
            description: "desc", whyItMatters: "why", expectedBenefit: "benefit")
        return PolicyDecision(
            primaryAction: ranked, secondaryAction: nil, allCandidates: [ranked],
            rationale: "test", decisionConfidence: 0.9, decidedAt: Date(),
            prescriptiveHeadline: "")
    }
}
