import Foundation
import Testing
@testable import Laso

/// One test per bug that reached a user, so the same one cannot come back.
///
/// Every case here is a real defect found by testing or auditing the app, not a
/// hypothetical. The comment on each says what the user actually saw.
struct RegressionTests {

    // MARK: - Vitality

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
