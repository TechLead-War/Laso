import Foundation
import Testing
@testable import Laso

/// One test per bug that reached a user, so the same one cannot come back.
///
/// Every case here is a real defect found by testing or auditing the app, not a
/// hypothetical. The comment on each says what the user actually saw.
struct RegressionTests {

    // MARK: - Vitality

    /// The 90-day age trend quoted a pace off two weeks of data, and the old
    /// formula divided a whole-year age step by a quarter of a year, so the
    /// number sat pinned at the 0.5 or 2.0 clamp instead of measuring anything.
    @Test func paceOfAgingNeedsRealHistoryAndTracksTheCalendar() {
        func history(days: Int, agePerDay: Double) -> [(date: Date, age: Double)] {
            let start = Date().addingTimeInterval(-Double(days) * 86_400)
            return (0..<days).map { day in
                (date: start.addingTimeInterval(Double(day) * 86_400),
                 age: 40 + agePerDay * Double(day))
            }
        }

        #expect(VitalityScorer.pace(from: history(days: 14, agePerDay: 0)) == nil,
                "two weeks is too short to fit a slope, so no pace may be shown")

        let flat = VitalityScorer.pace(from: history(days: 90, agePerDay: 0))
        #expect(flat != nil, "90 recorded days is enough to quote a pace")
        // A vitality age that never moves is aging slower than the calendar.
        #expect(abs((flat ?? 0) - 1.0) < 0.05, "a flat history must read as roughly on pace, got \(flat ?? -1)")

        // Half a year of vitality age added per calendar year reads above 1.
        let rising = VitalityScorer.pace(from: history(days: 90, agePerDay: 0.5 / 365.25))
        #expect((rising ?? 0) > 1.0, "a rising vitality age must read as a faster pace, got \(rising ?? -1)")
    }

    /// A usual range drawn off three days is noise, and a band of zero width
    /// would have marked every single reading as out of range.
    @Test func personalBandRefusesThinHistory() {
        #expect(PersonalBand.make(from: [10, 12, 11]) == nil, "three days cannot define a usual range")
        #expect(PersonalBand.make(from: Array(repeating: 20.0, count: 30)) == nil,
                "an unvarying history has no band to draw")

        let values = (0..<30).map { Double(20 + $0 % 5) }
        let band = PersonalBand.make(from: values)
        #expect(band != nil)
        #expect(band?.status(for: 22) == .usual)
        #expect(band?.status(for: 100) == .aboveUsual)
        #expect(band?.status(for: 0) == .belowUsual)
    }

    /// Every metric chip on the Vitality screen printed the same "12y", because
    /// the reference tables stop at age 20 and anything better clamped to it.
    @Test func metricBetterThanYoungestReferenceIsFlagged() {
        let table = [(age: 20, value: 60.0), (age: 40, value: 70.0)]

        let beyond = VitalityNorms.metricAge(value: 40, table: table, higherIsBetter: false)
        #expect(beyond.isBeyondYoungestReference,
                "a value better than the youngest row must be flagged, not printed as a real age")

        let onTheRow = VitalityNorms.metricAge(value: 60, table: table, higherIsBetter: false)
        #expect(!onTheRow.isBeyondYoungestReference,
                "a value sitting exactly on the youngest row is a real reading")

        let interior = VitalityNorms.metricAge(value: 65, table: table, higherIsBetter: false)
        #expect(!interior.isBeyondYoungestReference)
        #expect(interior.age > 20 && interior.age < 40, "an interior value interpolates")
    }

    // MARK: - Notifications

    /// The "good morning" summary fired at about 23:40 every night, because the
    /// wake detector resolved to the user's bedtime. This clamp is the backstop
    /// that stops any future detector bug reaching a scheduler.
    @Test func wakeTimeCannotScheduleANightPush() {
        let midnight = WakeUpTimeDetector.clamped(hour: 23, minute: 40, origin: "test")
        #expect(midnight.hour <= WakeUpTimeDetector.latestWakeHour)

        let dawn = WakeUpTimeDetector.clamped(hour: 2, minute: 0, origin: "test")
        #expect(dawn.hour >= WakeUpTimeDetector.earliestWakeHour)

        let real = WakeUpTimeDetector.clamped(hour: 7, minute: 15, origin: "test")
        #expect(real.hour == 7 && real.minute == 15, "a sane wake time passes through untouched")
    }

    // MARK: - Sample storage

    /// The dedupe key divided epoch seconds by 86400, a UTC bucket applied to
    /// local dates. In India the boundary fell at 05:30 local, so an early wake
    /// up silently overwrote the previous night.
    @Test func twoLocalDaysNeverShareABucket() {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 26
        components.hour = 5
        let sunday = Date.cal.date(from: components)!

        components.day = 27
        components.hour = 5
        let monday = Date.cal.date(from: components)!

        #expect(MetricSample.localDayBucket(for: sunday) != MetricSample.localDayBucket(for: monday),
                "an early morning reading on two different days must not collide")

        components.day = 26
        components.hour = 23
        let sundayNight = Date.cal.date(from: components)!
        #expect(MetricSample.localDayBucket(for: sunday) == MetricSample.localDayBucket(for: sundayNight),
                "morning and night of the same local day are one bucket")
    }

    // MARK: - Daily action

    /// Widget and watch showed a stale action, because the store returned an
    /// entry from an earlier day rather than nothing.
    @Test func yesterdaysActionIsNotOfferedAsTodays() {
        DailyActionStore.clear()
        defer { DailyActionStore.clear() }

        let yesterday = Date.cal.date(byAdding: .day, value: -1, to: Date())!
        DailyActionStore.save(title: "Walk", subtitle: "20 min", icon: "figure.walk", day: yesterday)
        #expect(DailyActionStore.today() == nil)

        DailyActionStore.save(title: "Walk", subtitle: "20 min", icon: "figure.walk")
        #expect(DailyActionStore.today()?.title == "Walk")
    }

    // MARK: - Watch link

    /// WatchConnectivity redelivers a queued transfer, and the journal writer
    /// always inserts, so one tap on the wrist was stored twice.
    @Test func aRedeliveredWristTapIsAppliedOnce() {
        let suite = UserDefaults(suiteName: "regression.\(UUID().uuidString)")!
        let ledger = AppliedCommandLedger(defaults: suite)
        let tap = UUID()

        #expect(ledger.claim(tap), "first delivery is applied")
        #expect(!ledger.claim(tap), "the redelivery is refused")
        #expect(ledger.claim(UUID()), "a different tap is unaffected")
    }

    /// The wrist presented an old payload as today's truth.
    @Test func anOldPayloadIsNotShownAsToday() {
        let today = WatchBridge.dayKey(for: Date())
        func payload(dayKey: String, age: TimeInterval) -> WatchPayload {
            WatchPayload(
                dayKey: dayKey, readinessScore: 72, readinessGrade: "B", dayType: "Maintain",
                actionHeadline: nil, actionDetail: nil, actionIcon: nil, actionDone: false,
                checkInAvailable: false, updatedAt: Date().addingTimeInterval(-age)
            )
        }

        #expect(!payload(dayKey: today, age: 0).isStale())
        #expect(payload(dayKey: today, age: WatchBridge.stalePayloadInterval + 1).isStale())

        let yesterday = WatchBridge.dayKey(for: Date().addingTimeInterval(-86_400))
        #expect(payload(dayKey: yesterday, age: 0).isStale(),
                "a payload for another day is stale however fresh it is")
    }

    // MARK: - Next Up card

    /// The card announced "Recovery numbers are well above your usual" over a
    /// sentence saying stand hours were 91% below baseline, because the headline
    /// came from the recovery state bucket and the body from a metric reason.
    @Test func nextUpHeadlineIsTheActionNotTheRecoveryState() {
        let action = DashboardSmartActionAdvisor().recommend(
            live: Self.emptyLive,
            analysis: DashboardSmartActionAdvisor.AnalysisSnapshot(
                policyDecision: Self.decision(actionType: .increaseSteps),
                restingHeartRateBaselineMean: nil,
                userFocuses: [],
                topInsights: []
            )
        )

        #expect(action.source == "policy_engine")
        #expect(action.title == Copy.Home.SmartAction.doIncreaseSteps,
                "the headline must be the thing to do, so Mark done has something to mark")
        #expect(!Copy.Policy.excellentHeadlines.contains(action.title),
                "a recovery state sentence must never be the action headline again")
    }

    /// The same week-over-week percentage was printed twice inside one four
    /// sentence paragraph, because the reason stacked baseline, trend and source
    /// text together.
    @Test func nextUpReasonStatesOneFactOnce() {
        let baseline = UserBaseline(metric: .steps, mean: 1.1, standardDeviation: 0.3,
                                    median: 1.1, sampleCount: 30, lastUpdated: Date())
        let reason = DecisionPolicyEngine().generateLanguage(
            for: Self.candidate(actionType: .increaseSteps),
            baselines: [.steps: baseline],
            trends: [:],
            timeSeries: [:]
        ).description

        #expect(!reason.isEmpty)
        #expect(reason.filter { $0 == "." }.count <= 1, "the card reason is one sentence")
        #expect(!reason.contains("week-over-week"),
                "trend detail belongs on the detail screen, not stacked onto the card")
    }

    /// An injured user with strong recovery numbers was told to push harder,
    /// because nothing in the app knew about the injury.
    @Test func aRestContextOverridesEveryBodySignal() {
        let action = DashboardSmartActionAdvisor().recommend(
            live: DashboardSmartActionAdvisor.LiveSnapshot(
                hour: 9, stressLevel: 10, readinessScore: 95, hasSleepData: true,
                sleepHours: 8.5, deepSleepMinutes: 95, exerciseMinutes: 0, exerciseGoal: 30,
                latestRestingHeartRate: 52
            ),
            analysis: DashboardSmartActionAdvisor.AnalysisSnapshot(
                policyDecision: Self.decision(actionType: .intensifyExercise),
                restingHeartRateBaselineMean: 54,
                userFocuses: [.fitness],
                topInsights: [],
                restContext: .injured
            )
        )

        #expect(action.source == "life_context")
        #expect(action.title == Copy.Home.contextRestTitle,
                "a rest context must win over a 95 readiness score and a fitness focus")
    }

    /// The first build switched a context off after a fixed number of days per
    /// context, which is a claim about how long an injury lasts that this app
    /// cannot make. Only the user ends it now, and we ask rather than assume.
    @Test func aRestContextEndsOnlyWhenTheUserSaysSo() {
        let suite = UserDefaults(suiteName: "regression.\(UUID().uuidString)")!
        let store = LifeContextStore(defaults: suite)

        store.toggle(.injured)
        #expect(store.requiresRest, "turning it on applies it")

        let muchLater = Date().addingTimeInterval(90 * 86_400)
        #expect(store.needingConfirmation(now: muchLater).contains(.injured),
                "a context we have not heard about must ask, not expire")
        #expect(store.requiresRest, "no amount of time switches it off by itself")

        store.confirm(.injured, now: muchLater)
        #expect(store.needingConfirmation(now: muchLater).isEmpty, "confirming resets the reminder")

        store.toggle(.injured)
        #expect(!store.requiresRest, "only the user ends it")
    }

    private static let emptyLive = DashboardSmartActionAdvisor.LiveSnapshot(
        hour: 13, stressLevel: nil, readinessScore: nil, hasSleepData: false,
        sleepHours: 0, deepSleepMinutes: 0, exerciseMinutes: 0, exerciseGoal: 30,
        latestRestingHeartRate: nil
    )

    private static func candidate(actionType: InterventionCandidate.ActionType) -> InterventionCandidate {
        InterventionCandidate(
            id: "test", targetMetric: .steps, actionType: actionType, source: .trendReversal,
            predictedUplift: 0.4, upliftConfidence: 0.8, effortCost: 0.2,
            timeToBenefit: .nextDay, adherenceLikelihood: 0.7, historicalEffectiveness: nil,
            evidence: InterventionEvidence(
                historicalResponseMean: nil, historicalResponseCount: 0,
                forecastedScoreDelta: nil, uncertaintyBand: nil,
                contributingFeatures: [], grangerPValue: nil,
                grangerEffectSize: nil, grangerOptimalLag: nil
            )
        )
    }

    // MARK: - Readiness

    /// Home printed a big "96 Ready" from a single signal, reading exactly as
    /// confidently as a day built on all five. The model already holds a reading
    /// back toward the middle when signals are missing; it just never said so.
    @Test func aThinReadingReportsHowMuchWasHeldBack() {
        let baseline = ReadinessScorer.BaselineStats(mean: 50, median: 50,
                                                     standardDeviation: 8, sampleCount: 30)
        let now = Date()

        // One signal, and an extreme one, which is the case that produced 96.
        var thin = ReadinessScorer.Input()
        thin.now = now
        thin.hrv = 95
        thin.hrvTimestamp = now
        thin.hrvBaseline = baseline

        // The same day with every signal reporting.
        var full = thin
        full.restingHeartRate = 48
        full.restingHeartRateTimestamp = now
        full.restingHeartRateBaseline = ReadinessScorer.BaselineStats(
            mean: 55, median: 55, standardDeviation: 4, sampleCount: 30)
        full.sleepDuration = 8 * 3600
        full.deepSleep = 90 * 60
        full.remSleep = 100 * 60
        full.hasSleepStageBreakdown = true
        full.workoutTimestamp = now
        full.workoutDurationMinutes = 45
        full.workoutCalories = 400

        guard let thinResult = ReadinessScorer.assess(thin),
              let fullResult = ReadinessScorer.assess(full) else {
            Issue.record("the scorer returned nothing for a reading it accepted")
            return
        }

        #expect(thinResult.confidence < fullResult.confidence,
                "fewer signals must report lower confidence")
        #expect(thinResult.uncertainty > fullResult.uncertainty,
                "a thin day must report more held back than a complete one")
        #expect(fullResult.uncertainty >= 0)

        // The range has to describe missing signals, not yesterday's number.
        // Measuring it against the smoothed score folded in the EMA lag, so a
        // complete day after a big swing printed a range with nothing missing.
        var lagging = full
        lagging.previousSmoothedScore = 20
        guard let laggingResult = ReadinessScorer.assess(lagging) else {
            Issue.record("the scorer returned nothing for a reading it accepted")
            return
        }
        #expect(laggingResult.uncertainty == fullResult.uncertainty,
                "yesterday's score must not widen today's range")
    }

    // MARK: - Share card

    /// The old rings card printed whatever the day gave it, so an ordinary day
    /// published "vitality age 44" with a near-empty ring and an amber recovery
    /// score onto the user's own photo. Every template is now hard-gated: a
    /// number that does not read as a win produces no card at all.
    @Test func shareTemplatesNeverCarryANumberThatLooksBad() {
        /// The rings card and the everyday cards show the day as it is and are
        /// opt-in by design, so the gates here are about which *wins* get
        /// offered on top of them.
        func wins(_ templates: [ShareTemplate]) -> [ShareTemplate.Kind] {
            let everyday: Set<ShareTemplate.Kind> = [.rings, .recovery, .sleep, .bodyAge]
            return templates.map(\.kind).filter { !everyday.contains($0) }
        }

        let olderBody = ShareTemplateBuilder.build(
            vitalityAge: 44, realAge: 38, recovery: nil, masterStreak: 0,
            actionResult: nil, lastNightSleepSeconds: nil, allTimeBestSleepHours: nil
        )
        #expect(wins(olderBody).isEmpty, "a body reading older than the user must never be a win card")

        let warmUpGap = ShareTemplateBuilder.build(
            vitalityAge: 37, realAge: 38, recovery: nil, masterStreak: 0,
            actionResult: nil, lastNightSleepSeconds: nil, allTimeBestSleepHours: nil
        )
        #expect(wins(warmUpGap).isEmpty, "a 1 year gap is inside the model's warm-up, not a win")

        let shortStreak = ShareTemplateBuilder.build(
            vitalityAge: nil, realAge: nil, recovery: nil,
            masterStreak: ShareTemplateGates.minMasterStreak - 1,
            actionResult: nil, lastNightSleepSeconds: nil, allTimeBestSleepHours: nil
        )
        #expect(shortStreak.isEmpty, "a streak under the floor is not worth posting")

        // The everyday cards must not smuggle back the thing the gates exist to
        // prevent: a body reading older than the user is still never offered.
        #expect(!olderBody.map(\.kind).contains(.bodyAge),
                "a body age older than the real age is not an everyday card either")

        let shortOfRecord = ShareTemplateBuilder.build(
            vitalityAge: nil, realAge: nil, recovery: nil, masterStreak: 0,
            actionResult: nil, lastNightSleepSeconds: 7.0 * 3600, allTimeBestSleepHours: 8.2
        )
        #expect(wins(shortOfRecord).isEmpty, "a normal night is not a personal best")

        // If the sleep series ever switches from hours to seconds upstream, the
        // win card must vanish rather than print "8194:12 best sleep yet".
        let unitMismatch = ShareTemplateBuilder.build(
            vitalityAge: nil, realAge: nil, recovery: nil, masterStreak: 0,
            actionResult: nil, lastNightSleepSeconds: 29_520, allTimeBestSleepHours: 29_520
        )
        #expect(wins(unitMismatch).isEmpty, "an implausible sleep value must not reach a win card")

        let nothingAtAll = ShareTemplateBuilder.build(
            vitalityAge: nil, realAge: nil, recovery: nil, masterStreak: 0,
            actionResult: nil, lastNightSleepSeconds: nil, allTimeBestSleepHours: nil
        )
        #expect(nothingAtAll.isEmpty, "with no data at all there is no card to offer, not even rings")
    }

    /// The picker is only useful if a real win actually reaches it, and the
    /// referral caption must follow the picked card rather than always claiming
    /// an age win.
    @Test func shareTemplatesCarryEarnedWins() {
        let earned = ShareTemplateBuilder.build(
            vitalityAge: 31, realAge: 38, recovery: 82, masterStreak: 23,
            actionResult: nil, lastNightSleepSeconds: 8.2 * 3600, allTimeBestSleepHours: 8.2
        )
        #expect(earned.map(\.kind) == [.younger, .streak, .bestSleep,
                                       .recovery, .sleep, .bodyAge, .rings],
                "earned wins first, then the everyday cards, rings offered last")

        #expect(earned[0].captionYears == 7, "the age card drives the years-younger invite caption")
        #expect(earned[1].captionYears == nil, "the streak card must not send an age claim with it")

        #expect(earned[2].chip == "8:12", "8.2 hours reads as 8:12, not 8:2 or 8:20")
        #expect(earned.last?.content == .rings(vitalityAge: 31, realAge: 38,
                                               recovery: 82, sleepSeconds: 8.2 * 3600),
                "the rings card still carries all three of the day's numbers")
    }

    /// Every card was gated on an achievement, so an ordinary day left the tray
    /// with a single option and the picker had nothing to pick between.
    @Test func anOrdinaryDayStillOffersAChoice() {
        let ordinary = ShareTemplateBuilder.build(
            // A 1 year gap sits inside the model's warm-up, so no win qualifies.
            vitalityAge: 37, realAge: 38, recovery: 64, masterStreak: 1,
            actionResult: nil, lastNightSleepSeconds: 7.1 * 3600, allTimeBestSleepHours: 8.4
        )

        #expect(ordinary.map(\.kind) == [.recovery, .sleep, .bodyAge, .rings],
                "no win qualifies here, so the three everyday cards carry the tray")
        #expect(ordinary.allSatisfy { $0.captionYears == nil },
                "an everyday card must not send an age claim with the invite")
    }






    // MARK: - Share milestone

    /// The share offer is attached to a moment, so it must fire once per
    /// milestone and never again. A fresh install that syncs a year of history
    /// crosses every milestone at once and must still see only one prompt.
    @Test func aStreakMilestoneIsOfferedOnce() {
        let defaults = UserDefaults.standard
        let key = "healthpulse.streakMilestoneCelebrated"
        let saved = defaults.object(forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.removeObject(forKey: key)

        #expect(StreakMilestoneStore.pending(streak: 6) == nil, "below the floor there is nothing to offer")

        #expect(StreakMilestoneStore.pending(streak: 7) == 7)
        StreakMilestoneStore.markCelebrated(7)
        #expect(StreakMilestoneStore.pending(streak: 7) == nil, "the same milestone must never fire twice")
        #expect(StreakMilestoneStore.pending(streak: 13) == nil, "days between milestones offer nothing")
        #expect(StreakMilestoneStore.pending(streak: 14) == 14, "the next milestone still fires")

        // A year of history synced on day one crosses every milestone at once.
        defaults.removeObject(forKey: key)
        #expect(StreakMilestoneStore.pending(streak: 365) == 100, "only the highest one crossed")
        StreakMilestoneStore.markCelebrated(100)
        #expect(StreakMilestoneStore.pending(streak: 365) == nil, "marking the highest retires the lower ones")
    }

    /// Switching a context off used to delete it, so the month calendar could
    /// never say why a past week was bad. The finished stretch has to survive.
    @Test func aFinishedContextStillMarksTheDaysItCovered() {
        let suite = UserDefaults(suiteName: "regression.\(UUID().uuidString)")!
        let store = LifeContextStore(defaults: suite)

        let start = Date().addingTimeInterval(-10 * 86_400)
        let end = Date().addingTimeInterval(-4 * 86_400)
        let middle = Date().addingTimeInterval(-7 * 86_400)
        let before = Date().addingTimeInterval(-12 * 86_400)
        let after = Date().addingTimeInterval(-2 * 86_400)

        store.toggle(.injured, now: start)
        store.toggle(.injured, now: end)

        #expect(!store.isActive(.injured), "the user ended it, so it is not on today")
        #expect(store.contexts(on: middle).contains(.injured), "a day inside the stretch keeps its mark")
        #expect(store.contexts(on: start).contains(.injured), "the first day is inside the stretch")
        #expect(store.contexts(on: end).contains(.injured), "the last day is inside the stretch")
        #expect(!store.contexts(on: before).contains(.injured), "days before it are untouched")
        #expect(!store.contexts(on: after).contains(.injured), "days after it are untouched")

        // Reading it back from storage must not lose the history.
        let reloaded = LifeContextStore(defaults: suite)
        #expect(reloaded.contexts(on: middle).contains(.injured), "history survives a relaunch")
    }

    /// An open stretch has no end, so every day from its start onward carries
    /// the mark. Without this, a context switched on today would mark nothing.
    @Test func anOpenContextMarksEveryDaySinceItStarted() {
        let suite = UserDefaults(suiteName: "regression.\(UUID().uuidString)")!
        let store = LifeContextStore(defaults: suite)

        let start = Date().addingTimeInterval(-3 * 86_400)
        store.toggle(.travelling, now: start)

        #expect(store.contexts(on: start).contains(.travelling))
        #expect(store.contexts(on: Date()).contains(.travelling), "still on means today is marked too")
        #expect(!store.contexts(on: start.addingTimeInterval(-86_400)).contains(.travelling),
                "the day before it started is not marked")
    }

    /// The day sheet printed "0 hrs below usual" under a sleep row. The 3%
    /// floor let a fraction-of-an-hour gap through, and it then rounded to
    /// zero, so the line claimed a difference and quoted none.
    @MainActor
    @Test func aGapThatRoundsAwayReadsAsAtUsual() {
        let atUsual = Copy.Home.whyValueAtUsual

        #expect(DashboardViewModel.gapToUsual(current: 6.2, baseline: 6.5, unit: "hrs") == atUsual,
                "a gap under half an hour has no whole number to quote")
        #expect(DashboardViewModel.gapToUsual(current: 5.4, baseline: 6.5, unit: "hrs") != atUsual,
                "a real hour of missing sleep must still be named")
        #expect(DashboardViewModel.gapToUsual(current: 43, baseline: 43, unit: "ms") == atUsual)
        #expect(DashboardViewModel.gapToUsual(current: 30, baseline: 43, unit: "ms") != atUsual)
    }


    // MARK: - Readiness bands

    /// The same score used to be graded by four different tables: the ring
    /// painted amber at 55, the sentence under it said "lower than usual", and
    /// the explainer one tap away said "decent recovery". A user who checked
    /// twice got two answers. Every grader now reads `DS.recoveryTier`, and
    /// `readinessSummary` switches on `RecoveryState` so it has no table of its
    /// own left to drift.
    @Test func oneScoreIsGradedByOneTable() {
        for score in 0...100 {
            let ring = DashboardViewModel.RecoveryState(score: score)
            let expected: DashboardViewModel.RecoveryState = switch DS.recoveryTier(for: score) {
            case .optimal: .green
            case .fair:    .yellow
            case .poor:    .red
            }
            #expect(ring == expected, "the ring and DS.scoreColor disagree at \(score)")
        }

        // The explainer sheet prints its own ranges, so they must name the same
        // numbers the grader uses or the sheet lies about the bands.
        #expect(Copy.Home.RecoveryInfo.fullyRecoveredRange.contains("\(DS.optimalFloor)"),
                "the sheet must print the floor it is actually graded by")
        #expect(Copy.Home.RecoveryInfo.lowRange.contains("\(DS.fairFloor)"))
        #expect(Copy.Home.RecoveryInfo.moderateRange.contains("\(DS.fairFloor)"))
    }


    // MARK: - Sleep bank

    /// A night the watch did not record was stored as a zero deficit, which on
    /// a chart draws as a night slept exactly to target. The bank has to know
    /// the difference between "you met it" and "we have nothing".
    @MainActor
    @Test func aNightWithNoSleepRecordedIsNotDrawnAsMet() {
        let today = Date.cal.startOfDay(for: Date())
        // 13 nights of 6 hours against a 7.5 hour floor, and one gap.
        let samples: [MetricSample] = (0..<14).compactMap { offset in
            guard offset != 5 else { return nil }
            guard let day = Date.cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return MetricSample(date: day, value: 6.0)
        }

        let tracker = SleepDebtTracker()
        tracker.compute(from: HealthDataStore(),
                        sleepSeries: MetricTimeSeries(metric: .sleepDuration, samples: samples))

        let debt = try? #require(tracker.currentDebt)
        #expect(tracker.isReady)
        #expect(debt?.dailyDeficits.count == 14, "every night in the window gets a slot")
        #expect(debt?.nightsRecorded == 13, "the missing night must not count as recorded")

        let gap = Date.cal.date(byAdding: .day, value: -5, to: today)
        let missing = debt?.dailyDeficits.first { $0.date == gap }
        #expect(missing?.hasData == false, "a night with no sample is flagged, not drawn as met")
        #expect(missing?.deficit == 0, "and it still adds no invented debt")
    }

    /// The payback line is arithmetic on the balance, so it has to round up:
    /// telling someone 2 nights clears a debt that 2 nights leaves open is the
    /// kind of small lie that costs trust in every other number.
    @Test func paybackNightsAlwaysCoverTheWholeBalance() {
        let extra = SleepDebtTracker.paybackExtraMinutes / 60

        #expect(SleepDebtTracker.nightsToClear(debtHours: 0) == 0, "nothing owed needs no nights")
        #expect(SleepDebtTracker.nightsToClear(debtHours: extra) == 1, "an exact night is one night")
        #expect(SleepDebtTracker.nightsToClear(debtHours: extra + 0.01) == 2, "any remainder needs another night")
        #expect(SleepDebtTracker.nightsToClear(debtHours: 3.0) == 4)
    }

    /// Anyone who sleeps under the 7.5 hour floor carries a standing balance, so
    /// a rule that fired on size alone made "get to bed early" the daily action
    /// every single day, which is not an action.
    @Test func theSleepActionOnlyTakesOverWhenTheBalanceIsGrowing() {
        let advisor = DashboardSmartActionAdvisor()
        func snapshot(debt: Double, growing: Bool) -> DashboardSmartActionAdvisor.AnalysisSnapshot {
            DashboardSmartActionAdvisor.AnalysisSnapshot(
                policyDecision: nil, restingHeartRateBaselineMean: nil, userFocuses: [],
                topInsights: [], restContext: nil, sleepDebtHours: debt, sleepDebtIsGrowing: growing
            )
        }

        let standing = advisor.recommend(live: Self.emptyLive, analysis: snapshot(debt: 9, growing: false))
        #expect(standing.source != "sleep_bank", "a balance that is simply always there is not today's news")

        let growing = advisor.recommend(live: Self.emptyLive, analysis: snapshot(debt: 9, growing: true))
        #expect(growing.source == "sleep_bank", "a balance getting worse outranks the model")
        #expect(!growing.subtitle.contains("12"), "a 12 night count reads as a sentence, not a plan")

        let small = advisor.recommend(live: Self.emptyLive, analysis: snapshot(debt: 0.5, growing: true))
        #expect(small.source != "sleep_bank", "half an hour is not worth taking over the day for")
    }

    // MARK: - Dashboard

    /// One refresh called `updateCachedProperties` four to five times, and every
    /// call rewrote ~25 observable properties. Most of those types are not
    /// Equatable, so Observation could not suppress the identical write and both
    /// Home and Explore rebuilt in full each time — including on the "no new data"
    /// early-out, where a refresh that found nothing still repainted both screens.
    /// The gate must hold when nothing moved, and every input that changes what is
    /// published must still get through it.
    ///
    /// Driven through the fingerprint the gate compares rather than through
    /// `DashboardViewModel` itself: constructing one needs HealthKit, a live
    /// SwiftData store and the analysis engine, none of which a unit test can raise.
    @Test func theDashboardOnlyRepublishesWhenAnInputMoved() {
        let today = Date.cal.startOfDay(for: Date())
        let insightIDs = [UUID(), UUID()]

        func fingerprint(
            expensiveInputsHash: Int = 4242,
            focuses: Set<HealthFocus> = [.sleep],
            generation: Int = 7,
            day: Date = today,
            objectIDs: [UUID] = insightIDs,
            counts: [Int] = [71, 64, 3]
        ) -> Int {
            DashboardViewModel.cachePublishFingerprint(
                expensiveInputsHash: expensiveInputsHash,
                focuses: focuses,
                scoreHistoryGeneration: generation,
                today: day,
                objectIDs: objectIDs,
                counts: counts
            )
        }

        let unchanged = fingerprint()
        #expect(fingerprint() == unchanged, "a refresh that found nothing must not republish")

        #expect(fingerprint(expensiveInputsHash: 4243) != unchanged, "new samples must republish")
        #expect(fingerprint(focuses: [.sleep, .recovery]) != unchanged,
                "a changed focus area must republish")
        #expect(fingerprint(generation: 8) != unchanged,
                "a newly stored day's score must republish")
        #expect(fingerprint(day: today.addingTimeInterval(86_400)) != unchanged,
                "crossing midnight must republish, since yesterday and weekly are anchored to today")
        #expect(fingerprint(objectIDs: [UUID(), UUID()]) != unchanged,
                "an insight list rebuilt by a deferred phase must republish, even at the same length")
        #expect(fingerprint(counts: [70, 64, 3]) != unchanged,
                "a changed category score must republish")
    }

    /// A duration of 5.999 hours printed as "5h 60m" once minutes were rounded.
    @Test func aDurationNeverPrintsSixtyMinutes() {
        #expect((5.999).hoursAsClock == (6.0).hoursAsClock, "rounding up must carry into the hour")
        #expect((0.75).hoursAsClock == Copy.Common.durationMinutes(45), "under an hour drops the leading zero")
        #expect((7.5).hoursAsClock == Copy.Common.durationHoursMinutes(7, 30))
    }

    private static func decision(actionType: InterventionCandidate.ActionType) -> PolicyDecision {
        let ranked = PolicyDecision.RankedIntervention(
            candidate: candidate(actionType: actionType),
            expectedUtility: 0.6, noveltyFactor: 1.0,
            description: "Your steps are 0.1 hrs, 91% below your usual 1.1 hrs.",
            whyItMatters: "why", expectedBenefit: "benefit"
        )
        return PolicyDecision(
            primaryAction: ranked, secondaryAction: nil, allCandidates: [ranked],
            rationale: "test", decisionConfidence: 0.9, decidedAt: Date(),
            prescriptiveHeadline: Copy.Policy.excellentHeadlines[0],
            targetSleepTime: nil, strainBudget: nil
        )
    }
}
