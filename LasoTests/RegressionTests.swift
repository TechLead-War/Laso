import Foundation
import SwiftData
import SwiftUI
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

    /// Steps and Exercise both printed a confident "Age 80, +55y older" for two
    /// completely different values, because anything worse than the oldest row
    /// clamped to it and the clamp was not flagged.
    @Test func metricWorseThanOldestReferenceIsFlagged() {
        // Higher is better: the oldest row holds the smallest value.
        let stepsLike = [(age: 20, value: 10000.0), (age: 80, value: 4500.0)]
        let farBelow = VitalityNorms.metricAge(value: 2488, table: stepsLike, higherIsBetter: true)
        #expect(farBelow.age == 80)
        #expect(farBelow.isBelowOldestReference,
                "a value worse than the oldest row is a ceiling, not a reading")
        #expect(!farBelow.isBeyondYoungestReference)

        // Lower is better: the oldest row holds the largest value.
        let rhrLike = [(age: 20, value: 63.0), (age: 80, value: 76.0)]
        let farAbove = VitalityNorms.metricAge(value: 120, table: rhrLike, higherIsBetter: false)
        #expect(farAbove.age == 80)
        #expect(farAbove.isBelowOldestReference)

        // Sitting exactly on the oldest row is still a real reading.
        #expect(!VitalityNorms.metricAge(value: 4500, table: stepsLike, higherIsBetter: true).isBelowOldestReference)
    }

    /// The metric gauge ran off a ±60% band around the population median, so a
    /// metric 54 years old sat further right than one 16 years old, and the bar
    /// disagreed with the age printed next to it.
    @Test func metricGaugeFollowsTheAgeScale() {
        func component(age: Int) -> VitalityComponent {
            VitalityComponent(
                metric: "test", metricAge: age, currentValue: 1, unit: "",
                populationMedian: 1, isBeyondYoungestReference: false,
                isBelowOldestReference: false, healthMetric: nil
            )
        }

        let young = vitalityMetricGaugePosition(component(age: 25))
        let middle = vitalityMetricGaugePosition(component(age: 50))
        let old = vitalityMetricGaugePosition(component(age: 79))

        #expect(young > middle && middle > old,
                "a younger metric age must always sit further along the bar")
        #expect(vitalityMetricGaugePosition(component(age: 20)) == 1.0)
        #expect(vitalityMetricGaugePosition(component(age: 80)) == 0.0)
        #expect(vitalityMetricGaugePosition(component(age: 95)) == 0.0, "past the table the bar pins, it does not wrap")
    }

    /// Every step and calorie average was dragged down by however much of today
    /// had not happened yet, so the daily score sagged each morning and
    /// "recovered" by bedtime.
    @Test func todaysPartialDayIsExcludedFromStatistics() {
        let today = Date.cal.startOfDay(for: Date()).addingTimeInterval(3600)
        let yesterday = today.addingTimeInterval(-86_400)
        let dayBefore = today.addingTimeInterval(-2 * 86_400)

        let steps = MetricTimeSeries(metric: .steps, samples: [
            MetricSample(date: dayBefore, value: 10000),
            MetricSample(date: yesterday, value: 10000),
            MetricSample(date: today, value: 1000)   // barely into the day
        ])
        let completed = steps.completedDaySamples(lastDays: 7)
        #expect(completed.count == 2, "today must not count as a finished day for steps")
        #expect(completed.mean(of: \.value) == 10000)
        #expect(steps.samples(lastDays: 7).count == 3, "the raw window still has today for live views")

        // Resting heart rate does not build up over the day, so today stays in.
        let rhr = MetricTimeSeries(metric: .restingHeartRate, samples: [
            MetricSample(date: yesterday, value: 60),
            MetricSample(date: today, value: 62)
        ])
        #expect(rhr.completedDaySamples(lastDays: 7).count == 2)

        // A night's sleep is already finished when it lands on a day.
        #expect(!HealthMetric.sleepDuration.accumulatesDuringDay)
    }

    /// A 63% fall in light sleep was listed under "This Week's Wins" while the
    /// same night's drop in REM was listed as a concern.
    @Test func lessLightSleepIsNotAWin() {
        #expect(HealthMetric.sleepCore.higherIsBetter,
                "light sleep is counted in hours, so less of it tracks less total sleep")
    }

    /// The mobility age thresholds were written in m/s while walking speed is
    /// stored in km/h, so every real reading cleared the top anchor and the
    /// component always returned the youngest bracket.
    @Test func walkingSpeedAgeAnchorsMatchTheStoredUnit() {
        // A brisk 5.2 km/h walk is fast; a 3.0 km/h shuffle is not. If the
        // anchors were still in m/s both would land on the same young age.
        #expect(BiologicalAgeConfig.walkingSpeedYoungAnchor > 4.0,
                "anchors must be km/h to match HealthKitMetricRegistry")
        #expect(BiologicalAgeConfig.walkingSpeedSlowAnchor > 3.0)
        #expect(BiologicalAgeConfig.walkingSpeedYoungAnchor > BiologicalAgeConfig.walkingSpeedMidAnchor)
        #expect(BiologicalAgeConfig.walkingSpeedMidAnchor > BiologicalAgeConfig.walkingSpeedSlowAnchor)
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

    // MARK: - Wake anchor

    /// A user-set wake time outranks detection, and it has to outrank it in
    /// `detectAndPersist` too. That function only routed through
    /// `persistedWakeTime` on its TTL-hit branch, so a TTL-expired refresh
    /// would re-detect, overwrite the stored keys, and silently revert the
    /// anchor for every scheduler reading them.
    @Test func userAnchorOutranksDetection() {
        let defaults = UserDefaults.standard
        let previous = WakeUpTimeDetector.userAnchor
        defer { WakeUpTimeDetector.userAnchor = previous }

        defaults.set(9, forKey: AppKeys.Engagement.detectedWakeHour)
        defaults.set(30, forKey: AppKeys.Engagement.detectedWakeMinute)
        defaults.set("detected", forKey: AppKeys.Engagement.wakeTimeSource)

        WakeUpTimeDetector.userAnchor = (hour: 6, minute: 30)
        #expect(WakeUpTimeDetector.persistedWakeTime == (hour: 6, minute: 30),
                "the anchor wins over a detected wake time")

        WakeUpTimeDetector.userAnchor = nil
        #expect(WakeUpTimeDetector.persistedWakeTime == (hour: 9, minute: 30),
                "clearing the anchor falls back to detection, not to the 7:00 default")
    }

    /// An anchor outside 5-11 would make the morning reminder a repeating
    /// trigger inside quiet hours, which `NotificationManager` drops rather
    /// than defers. The setter clamps so that can never be stored.
    @Test func userAnchorCannotBeStoredOutsideTheDeliverableBand() {
        let previous = WakeUpTimeDetector.userAnchor
        defer { WakeUpTimeDetector.userAnchor = previous }

        WakeUpTimeDetector.userAnchor = (hour: 3, minute: 15)
        #expect(WakeUpTimeDetector.userAnchor?.hour == WakeUpTimeDetector.earliestWakeHour)

        WakeUpTimeDetector.userAnchor = (hour: 14, minute: 0)
        #expect(WakeUpTimeDetector.userAnchor?.hour == WakeUpTimeDetector.latestWakeHour)
    }

    /// Drift is signed minutes around the anchor, and it has to take the nearer
    /// side of the clock. Measured naively, a 23:40 wake against an 06:00
    /// anchor reads as +1060 minutes late instead of 380 minutes early, which
    /// renders as a full-height "late" mark on the wrong side of the line.
    @Test func wakeDriftWrapsToTheNearerSideOfTheClock() {
        func wake(_ hour: Int, _ minute: Int, daysAgo: Int) -> Date {
            var comps = Date.cal.dateComponents(
                [.year, .month, .day],
                from: Date().addingTimeInterval(-Double(daysAgo) * 86_400)
            )
            comps.hour = hour
            comps.minute = minute
            return Date.cal.date(from: comps) ?? Date()
        }

        let points = WakeAnchorAnalyzer.drift(
            from: [wake(23, 40, daysAgo: 1), wake(6, 20, daysAgo: 2), wake(5, 45, daysAgo: 3)],
            anchor: (hour: 6, minute: 0),
            days: 30
        )

        #expect(points.count == 3)
        let drifts = points.map(\.driftMinutes).sorted()
        #expect(drifts == [-380, -15, 20], "late-night wake reads as early, not as +1060")
    }

    /// A band label off four nights is a number pretending to be a finding, so
    /// it stays nil until the minimum is met.
    @Test func wakeConsistencyWithholdsItsBandUntilEnoughNights() {
        func point(_ driftMinutes: Int, daysAgo: Int) -> WakeDriftPoint {
            WakeDriftPoint(
                date: Date().addingTimeInterval(-Double(daysAgo) * 86_400),
                driftMinutes: driftMinutes
            )
        }

        let sparse = (1...3).map { point(5, daysAgo: $0) }
        #expect(WakeAnchorAnalyzer.consistency(from: sparse, windowDays: 28).band == nil)

        let enough = (1...WakeAnchorConfig.consistencyMinNights).map { point(5, daysAgo: $0) }
        let result = WakeAnchorAnalyzer.consistency(from: enough, windowDays: 28)
        #expect(result.band == .steady)
        #expect(result.medianAbsDriftMinutes == 5)
        #expect(result.nightsInWindow == result.totalNights)
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
                checkInAvailable: false, updatedAt: Date().addingTimeInterval(-age),
                schemaVersion: WatchBridge.schemaVersion, bodyStressElevated: nil,
                restingHeartRateBaseline: nil, hrvBaselineFloor: nil, hoursSinceHardDay: nil,
                exerciseCeilingMinutes: nil, bedtimeTarget: nil, nightsOfHistory: nil
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

    /// Sleep Coach shows nothing but "Building your sleep profile" while
    /// `SleepNeedCalculator.currentNeed` is nil, and only the launch prewarm can
    /// fill it before the first HealthKit refresh lands seconds later. Sleep was
    /// the one engine the prewarm skipped, so opening the screen off a cold
    /// launch showed the empty state to users with years of nights on disk.
    @MainActor
    @Test func launchPrewarmFillsSleepNeedFromDisk() throws {
        let modelContainer = try ModelContainer(
            for: StoredDailySample.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = HealthDataStore(modelContainer: modelContainer)

        let today = Date.cal.startOfDay(for: Date())
        let nights: [MetricSample] = (0..<30).compactMap { offset in
            guard let day = Date.cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return MetricSample(date: day, value: 7.0)
        }
        store.saveSamples(nights, for: .sleepDuration)

        // The encrypted profile is the only working age source, and the prewarm
        // skips every age-dependent engine without one.
        let previousProfile = UserProfileStore.shared.loadLocal()
        defer { if let previousProfile { UserProfileStore.shared.saveLocal(previousProfile) } }
        let dob = Date.cal.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        UserProfileStore.shared.saveLocal(
            UserProfileStore.shared.makeProfile(
                name: "Prewarm Test",
                email: "prewarm@example.com",
                gender: .male,
                dateOfBirth: dob,
                healthFocuses: ["Sleep"]
            )
        )

        // Construction alone must be enough: the prewarm runs in init, which is
        // the only thing that has happened by the time Home's sleep tile is
        // tappable.
        let viewModel = DashboardViewModel(
            healthKitManager: HealthKitManager(),
            analysisEngine: AnalysisEngine(),
            store: store,
            housekeepingService: DashboardHousekeepingService(
                persistenceManager: PersistenceManager(),
                analytics: AppAnalytics.shared,
                sessionTracker: SessionTracker.shared
            )
        )

        #expect(viewModel.sleepNeedCalculator.currentNeed != nil,
                "Sleep Coach would open on its empty state despite 30 nights on disk")
        #expect(viewModel.sleepDebtTracker.currentDebt != nil,
                "Sleep Coach would open with an empty 14-day history")
    }

    /// Sleep need used to sit inside the `if let age` gate that Strain and
    /// Vitality need, so a profile without a date of birth left Sleep Coach on
    /// "Building your sleep profile" forever, no matter how many nights were on
    /// disk. Age only shifts the target by 15 minutes at the extremes.
    @MainActor
    @Test func sleepNeedIsComputedWithoutADateOfBirth() throws {
        let modelContainer = try ModelContainer(
            for: StoredDailySample.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = HealthDataStore(modelContainer: modelContainer)

        let today = Date.cal.startOfDay(for: Date())
        let nights: [MetricSample] = (0..<30).compactMap { offset in
            guard let day = Date.cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return MetricSample(date: day, value: 7.0)
        }
        store.saveSamples(nights, for: .sleepDuration)

        // Key literal mirrors UserProfileStore's private `localKey`; there is no
        // public way to clear the profile, and this test is only meaningful with
        // no age available from any source.
        let previousProfile = UserProfileStore.shared.loadLocal()
        defer { if let previousProfile { UserProfileStore.shared.saveLocal(previousProfile) } }
        EncryptedStore.shared.remove(forKey: "healthpulse.userProfile")
        #expect(UserProfileStore.shared.loadLocal() == nil, "the ageless case is what this test covers")

        let viewModel = DashboardViewModel(
            healthKitManager: HealthKitManager(),
            analysisEngine: AnalysisEngine(),
            store: store,
            housekeepingService: DashboardHousekeepingService(
                persistenceManager: PersistenceManager(),
                analytics: AppAnalytics.shared,
                sessionTracker: SessionTracker.shared
            )
        )

        #expect(viewModel.sleepNeedCalculator.currentNeed != nil,
                "Sleep Coach stays on its empty state whenever this is nil")
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


    // MARK: - Onboarding

    /// Connecting Apple Health left users on a black scan screen with no way
    /// out. `OnboardingHealthSnapshot.load()` fans out to fourteen concurrent
    /// HealthKit queries and awaits every one, and `routeAfterScan` awaited that
    /// with no deadline, so a single query that never called back stranded the
    /// whole flow. The wait is now bounded.
    @Test func onboardingNeverWaitsForeverOnHealthKit() async {
        let neverFinishes = Task<Void, Never> {
            // Far longer than any real HealthKit query, standing in for one that
            // never calls back.
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        }
        defer { neverFinishes.cancel() }

        let start = ContinuousClock.now
        await OnboardingV2View.finish(neverFinishes, within: 300_000_000)
        let waited = ContinuousClock.now - start

        #expect(waited < .seconds(3), "a hung HealthKit query must not hold onboarding")

        // A task that does finish must still be awaited, not cut short.
        let quick = Task<Void, Never> { try? await Task.sleep(nanoseconds: 50_000_000) }
        await OnboardingV2View.finish(quick, within: 5_000_000_000)
        #expect(quick.isCancelled == false)
    }


    // MARK: - Biology calendar

    /// The month calendar is the most expensive draw in the app (88 ms to
    /// rasterize), and the tab rebuilds for reasons that have nothing to do with
    /// it, which repainted it mid-scroll. It now compares its own inputs so
    /// SwiftUI can skip it. The comparison must notice a life-context change:
    /// a context covers a whole date range, so ending one rewrites past cells
    /// without moving a single score. Comparing scores alone would leave the
    /// calendar showing contexts the user already turned off.
    @MainActor @Test func theCalendarRedrawsWhenAContextChangesButNoScoreDid() {
        let day = Date.cal.startOfDay(for: Date())
        let scores = [day: 72]
        let detail: (Date) -> DashboardViewModel.DayDetail = { d in
            DashboardViewModel.DayDetail(date: d, score: 72, contexts: [], signals: [], missing: [])
        }

        let noContext = ExploreMonthCalendarSection(
            scoresByDay: scores, contextsByDay: [:], detailForDay: detail)
        let sameAgain = ExploreMonthCalendarSection(
            scoresByDay: scores, contextsByDay: [:], detailForDay: detail)
        #expect(noContext == sameAgain, "identical inputs must skip the redraw")

        let injured = ExploreMonthCalendarSection(
            scoresByDay: scores, contextsByDay: [day: [.injured]], detailForDay: detail)
        #expect(noContext != injured,
                "a context change with identical scores must still force a redraw")

        let scoreMoved = ExploreMonthCalendarSection(
            scoresByDay: [day: 73], contextsByDay: [:], detailForDay: detail)
        #expect(noContext != scoreMoved, "a score change must force a redraw")
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

// MARK: - TEMPORARY perf harness (delete before shipping)


@MainActor
enum EF {

    static let today = Date.cal.startOfDay(for: Date())

    static func samples(_ n: Int, base: Double) -> [MetricSample] {
        (0..<n).map { i in
            MetricSample(
                date: today.addingTimeInterval(Double(i - n) * 86_400),
                value: base + Double((i * 7) % 17) - 8
            )
        }
    }

    static let trendMetrics: [TrendMetricItem] = {
        let metrics: [HealthMetric] = [
            .heartRateVariability, .restingHeartRate, .sleepDuration,
            .steps, .vo2Max, .activeCalories, .sleepDeep, .sleepREM
        ]
        return metrics.enumerated().map { index, metric in
            TrendMetricItem(
                metric: metric,
                trend: TrendAnalyzer.TrendResult(
                    direction: index % 3 == 0 ? .improving : (index % 3 == 1 ? .declining : .stable),
                    weekOverWeekChange: Double(index) * 2.3 - 5,
                    movingAverage7d: 50, movingAverage30d: 48, movingAverage90d: 47,
                    inflection: .steady
                ),
                sparklineSamples: samples(90, base: 50 + Double(index))
            )
        }
    }()

    static let categories: [(category: HealthCategory, score: Int?)] =
        HealthCategory.allCases.enumerated().map { i, c in
            (category: c, score: i == 8 ? nil : 40 + i * 6)
        }

    static let insightCounts: [HealthCategory: Int] = {
        var d: [HealthCategory: Int] = [:]
        for (i, c) in HealthCategory.allCases.enumerated() { d[c] = i % 3 }
        return d
    }()

    static let explanation = HealthScorer.ScoreExplanation(
        categoryContributions: HealthCategory.allCases.enumerated().map {
            HealthScorer.CategoryContribution(category: $1, score: 30 + $0 * 5, weightedContribution: Double($0))
        },
        topFactors: [
            HealthScorer.ScoreFactor(metric: .heartRateVariability, impact: -8, reason: "HRV dropped 15% versus your usual range this week", isPositive: false),
            HealthScorer.ScoreFactor(metric: .sleepDeep, impact: -6, reason: "Deep sleep is down 22 minutes a night on average", isPositive: false),
            HealthScorer.ScoreFactor(metric: .restingHeartRate, impact: -4, reason: "Resting heart rate is up 4 bpm from your baseline", isPositive: false),
            HealthScorer.ScoreFactor(metric: .steps, impact: 5, reason: "Steps are up", isPositive: true)
        ]
    )

    static let highlights: [DashboardViewModel.HistoricalHighlight] = [
        .init(metric: .heartRateVariability, type: .weekOverWeek, title: "HRV down 15% this week", recommendation: "Prioritise an early night for the next two days", isPositive: false, significance: 0.8),
        .init(metric: .sleepDeep, type: .allTimeExtreme, title: "Lowest deep sleep in 90 days", recommendation: "Keep the room cooler and cut screens after 10pm", isPositive: false, significance: 0.7),
        .init(metric: .restingHeartRate, type: .longTermTrajectory, title: "Resting heart rate climbing since March", recommendation: "Add two easy aerobic sessions a week", isPositive: false, significance: 0.6)
    ]

    static let chains: [CausalChain] = [
        CausalChain(
            links: [
                ChainLink(causeMetric: .steps, effectMetric: .sleepDeep, correlation: 0.52, lagDays: 1, causeDeviation: -12, effectDeviation: -8),
                ChainLink(causeMetric: .sleepDeep, effectMetric: .heartRateVariability, correlation: 0.61, lagDays: 1, causeDeviation: -8, effectDeviation: -15)
            ],
            affectedMetric: .heartRateVariability,
            confidence: 0.74,
            narrative: "Lower step counts last week fed a drop in deep sleep, and the two nights after each of those pushed your HRV down with it."
        )
    ]

    static let cards: [IntelligenceCard] = (0..<4).map { i in
        IntelligenceCard(
            type: .predictiveRisk,
            icon: "exclamationmark.triangle.fill",
            label: "Heads up",
            headline: "Your HRV has been dropping since Friday and the pattern matches a run of short deep sleep.",
            detail: "This is mainly your resting heart rate. Extra sleep tonight is the lever that moved it last time.",
            severity: i == 0 ? .critical : .notable,
            confidence: 0.8,
            priority: 0.9,
            accentColor: i == 0 ? .red : .blue
        )
    }

    static let forecasts: [MetricForecast] = [
        MetricForecast(metric: .heartRateVariability, predictedValue: 52, lowerBound: 42, upperBound: 62, currentValue: 48, confidence: 0.85),
        MetricForecast(metric: .sleepDuration, predictedValue: 27000, lowerBound: 24000, upperBound: 30000, currentValue: 25200, confidence: 0.78),
        MetricForecast(metric: .restingHeartRate, predictedValue: 58, lowerBound: 55, upperBound: 61, currentValue: 60, confidence: 0.82)
    ]

    static let scoresByDay: [Date: Int] = {
        var d: [Date: Int] = [:]
        for i in 0..<366 {
            guard let day = Date.cal.date(byAdding: .day, value: -i, to: today) else { continue }
            d[day] = 45 + (i * 13) % 50
        }
        return d
    }()

    static let dayDetail: (Date) -> DashboardViewModel.DayDetail = { _ in
        fatalError("not rendered in these measurements")
    }
}

@MainActor
func rasterMedian(_ label: String, _ view: some View, height: CGFloat = 900) {
    let host = UIHostingController(rootView: AnyView(view.frame(width: 393)))
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: height))
    window.rootViewController = host
    window.makeKeyAndVisible()
    host.view.frame = window.bounds
    host.view.setNeedsLayout(); host.view.layoutIfNeeded()
    var samples: [Double] = []
    let r = UIGraphicsImageRenderer(bounds: window.bounds)
    for _ in 0..<11 {
        let t0 = CFAbsoluteTimeGetCurrent()
        _ = r.image { ctx in host.view.layer.render(in: ctx.cgContext) }
        samples.append((CFAbsoluteTimeGetCurrent() - t0) * 1000)
    }
    samples.sort()
    print(String(format: "MEASURE: %@ raster %.2f ms (median of 11)", label, samples[5]))
}

// MARK: - Section views under test

@MainActor
enum EV {
    static var scoreHero: some View {
        ExploreScoreHeroSection(
            overallScore: 72,
            scoreChangeFromLastWeek: -3,
            weakestCategory: (category: .sleep, score: 44),
            onScoreInfoTapped: {}
        ).padding(.horizontal)
    }

    static var dataSummary: some View {
        ExploreDataSummarySection(metricsTracked: 18, totalDataPoints: 42_318, daysOfData: 214, insightCount: 7)
            .padding(.horizontal)
    }

    static var yourTrends: some View {
        ExploreYourTrendsSection(
            trendMetrics: EF.trendMetrics,
            trendTimeframe: .constant(30),
            onMetricTapped: { _ in }
        )
    }

    static var briefing: some View {
        TodayBriefingView(cards: EF.cards)
    }

    static var forecast: some View {
        PersonalHealthForecastCard(forecasts: EF.forecasts, onTapMetric: { _ in })
    }

    static var categoriesSection: some View {
        ExploreCategoriesSection(
            categories: EF.categories,
            insightCountProvider: { EF.insightCounts[$0] ?? 0 },
            onCategoryTapped: { _, _ in }
        ).padding(.horizontal)
    }

    static var needsAttention: some View {
        ExploreNeedsAttentionSection(
            scoreExplanation: EF.explanation,
            onFactorTapped: { _ in },
            onWeakCategoryTapped: { _ in }
        ).padding(.horizontal)
    }

    static var declining: some View {
        ExploreDecliningTrendsSection(
            decliningHighlights: EF.highlights,
            causalChains: EF.chains,
            onHighlightTapped: { _ in },
            onSeeAllIntelligenceTapped: {}
        )
    }

    static var calendar: some View {
        ExploreMonthCalendarSection(
            scoresByDay: EF.scoresByDay,
            contextsByDay: [:],
            detailForDay: EF.dayDetail
        ).padding(.horizontal)
    }

    /// Same order, spacing and paddings as ExploreView's LazyVStack.
    @ViewBuilder
    static func tab(includeCalendar: Bool) -> some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                scoreHero
                dataSummary
                if includeCalendar { calendar }
                yourTrends
                briefing
                forecast
                categoriesSection
                needsAttention
                declining
            }
            .padding(.bottom, DS.space4)
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
    }
}

struct ExplorePerfTemp {

    @MainActor @Test func measureSections() {
        rasterMedian("scoreHero", EV.scoreHero, height: 200)
        rasterMedian("dataSummary", EV.dataSummary, height: 100)
        rasterMedian("yourTrends", EV.yourTrends, height: 900)
        rasterMedian("briefing", EV.briefing, height: 260)
        rasterMedian("forecast", EV.forecast, height: 220)
        rasterMedian("categories", EV.categoriesSection, height: 700)
        rasterMedian("needsAttention", EV.needsAttention, height: 320)
        rasterMedian("declining", EV.declining, height: 500)
        rasterMedian("calendar", EV.calendar, height: 520)
    }

    @MainActor @Test func measureWholeTab() {
        rasterMedian("TAB with calendar", EV.tab(includeCalendar: true))
        rasterMedian("TAB without calendar", EV.tab(includeCalendar: false))
    }
}
