import Foundation
import HealthKit
import Testing
@testable import Laso

/// One test per bug reported on a user-facing surface, so none of them can come
/// back quietly. It started with Ask, Vitals and the Daily Mirror ("Ask your
/// data gives wrong or random answers", "Vitals only shows 2 metrics, it should
/// be about 5 including sleep", "the photo capture is not discoverable") and has
/// taken every later report of the same kind since.
struct AskVitalsMirrorRegressionTests {

    // MARK: - Fixtures

    /// A context carrying nothing but the series handed in. Every ML field is
    /// empty on purpose: these tests are about routing and arithmetic, and a
    /// populated insight would let an answer look right for the wrong reason.
    private func context(
        series: [HealthMetric: MetricTimeSeries] = [:],
        baselines: [HealthMetric: UserBaseline] = [:],
        overallScore: Int? = 72
    ) -> HealthDataQueryEngine.QueryContext {
        HealthDataQueryEngine.QueryContext(
            timeSeries: series,
            baselines: baselines,
            trends: [:],
            correlations: [],
            forecasts: [:],
            healthSignalReport: nil,
            currentHealthState: nil,
            discoveredPatterns: [],
            circadianProfile: nil,
            timingRecommendations: [],
            optimalProfile: nil,
            idealDay: nil,
            scoreSensitivities: [],
            tomorrowRiskPrediction: nil,
            compoundInsights: [],
            temporalSequences: [],
            overallScore: overallScore
        )
    }

    /// Daily samples ending today, oldest first. `valueForDaysAgo` lets a test
    /// give this week and last week different numbers.
    private func series(
        _ metric: HealthMetric,
        days: Int,
        valueForDaysAgo: (Int) -> Double
    ) -> MetricTimeSeries {
        let noon = Date.cal.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let samples = (0..<days).reversed().map { daysAgo in
            MetricSample(
                date: noon.addingTimeInterval(-Double(daysAgo) * 86_400),
                value: valueForDaysAgo(daysAgo)
            )
        }
        return MetricTimeSeries(metric: metric, samples: samples)
    }

    // MARK: - Ask: metric detection

    /// "Does my resting heart rate affect my sleep" was answered as the
    /// correlation between resting heart rate and heart rate, because "heart
    /// rate" matched inside "resting heart rate" and pushed the metric the user
    /// actually named out of the pair.
    @Test func aMetricPhraseNeverAlsoMatchesItsOwnSubPhrase() {
        let engine = HealthDataQueryEngine()

        let restingAndSleep = engine.metrics(in: "does my resting heart rate affect my sleep")
        #expect(restingAndSleep.prefix(2) == [.restingHeartRate, .sleepDuration],
                "the pair must be the two metrics named, not a phrase and its own substring")
        #expect(!restingAndSleep.contains(.heartRate),
                "\"heart rate\" sits inside \"resting heart rate\" and is not a second metric")

        let deepAndHRV = engine.metrics(in: "does deep sleep affect my hrv")
        #expect(deepAndHRV.prefix(2) == [.sleepDeep, .heartRateVariability])
        #expect(!deepAndHRV.contains(.sleepDuration),
                "\"sleep\" sits inside \"deep sleep\"")

        let glucoseAndSleep = engine.metrics(in: "does blood sugar affect my sleep")
        #expect(glucoseAndSleep.prefix(2) == [.bloodGlucose, .sleepDuration])
        #expect(!glucoseAndSleep.contains(.sugarIntake),
                "\"sugar\" sits inside \"blood sugar\"")
    }

    /// Two-letter vocabulary keys fired inside ordinary words: "hr" matched
    /// inside "three" and "hrs", "rem" inside "remember". A question about the
    /// last three days was answered as a heart rate reading.
    @Test func shortMetricTermsDoNotFireInsideLongerWords() {
        let engine = HealthDataQueryEngine()

        #expect(!engine.metrics(in: "how was my sleep in the last three days").contains(.heartRate),
                "\"three\" contains \"hr\" but names no metric")
        #expect(engine.metrics(in: "how many hrs of sleep did i get") == [.sleepDuration],
                "\"hrs\" is a unit here, not a heart rate")
        #expect(!engine.metrics(in: "remember to check my sleep").contains(.sleepREM),
                "\"remember\" contains \"rem\" but does not ask about REM sleep")
    }


    // MARK: - Ask: determinism

    /// "Is anything unusual?" scanned an arbitrary 15 metrics taken from an
    /// unordered Dictionary, and Swift seeds Dictionary hashing per process, so
    /// the same data flagged a different anomaly on every launch. Within one
    /// process the giveaway is that two identical calls disagree.
    @Test func theSameQuestionOnTheSameDataAnswersTheSameWayTwice() {
        let engine = HealthDataQueryEngine()
        var series: [HealthMetric: MetricTimeSeries] = [:]
        var baselines: [HealthMetric: UserBaseline] = [:]

        // More populated metrics than the old 15-metric slice, so a truncating
        // scan has something to truncate.
        let metrics: [HealthMetric] = [
            .steps, .restingHeartRate, .heartRateVariability, .sleepDuration,
            .sleepDeep, .sleepREM, .activeCalories, .exerciseMinutes,
            .bloodOxygen, .respiratoryRate, .vo2Max, .weight, .standHours,
            .distanceWalkingRunning, .flightsClimbed, .mindfulMinutes,
            .walkingSpeed, .bodyTemperature,
        ]
        for (index, metric) in metrics.enumerated() {
            series[metric] = self.series(metric, days: 30) { _ in Double(50 + index) }
            baselines[metric] = UserBaseline(
                metric: metric,
                mean: Double(50 + index),
                standardDeviation: 1,
                median: Double(50 + index),
                sampleCount: 30,
                lastUpdated: Date()
            )
        }
        let ctx = context(series: series, baselines: baselines)

        for question in ["is anything unusual in my data", "how am i doing overall", "am i at risk for anything"] {
            let first = engine.answer(question: question, context: ctx)
            let second = engine.answer(question: question, context: ctx)
            #expect(first.answer == second.answer, "\(question) answered two different ways")
        }
    }

    // MARK: - Ask: periods

    /// "How was my sleep last week?" was computed from this week's data and
    /// still labelled "last week", because QueryPeriod carried a length but no
    /// offset, so every past window ended at today.
    @Test func lastWeekReadsLastWeekNotThisWeek() {
        let engine = HealthDataQueryEngine()
        // A clean step: the last 7 days average 5 h, the 7 before that 8 h.
        let sleep = series(.sleepDuration, days: 21) { daysAgo in daysAgo < 7 ? 5 : 8 }
        let ctx = context(series: [.sleepDuration: sleep])

        let thisWeek = engine.answer(question: "how is my sleep trending this week", context: ctx)
        let lastWeek = engine.answer(question: "how was my sleep trending last week", context: ctx)

        #expect(thisWeek.answer != lastWeek.answer,
                "two different windows over data that differs must not produce one answer")
        #expect(lastWeek.answer.localizedCaseInsensitiveContains("last week"),
                "the answer names the window it was asked about")
    }

    // MARK: - Ask: conversational hijack

    /// A real health question whose text merely starts with "ty" or "later" was
    /// swallowed by the thanks and farewell prefix match and answered with a
    /// pleasantry at full confidence, never reaching the intent parser.
    @Test func aHealthQuestionIsNotAnsweredWithAPleasantry() {
        let engine = HealthDataQueryEngine()
        let sleep = series(.sleepDuration, days: 21) { _ in 7 }
        let ctx = context(series: [.sleepDuration: sleep])

        let pleasantries = ["Happy to help", "Take care", "I'm here whenever"]
        for question in ["typical sleep for me", "later today should i train", "type 2 diabetes risk"] {
            let answer = engine.answer(question: question, context: ctx).answer
            for pleasantry in pleasantries {
                #expect(!answer.localizedCaseInsensitiveContains(pleasantry),
                        "\"\(question)\" was answered with a pleasantry: \(answer)")
            }
        }

        // A bare thanks still gets the short human reply it should.
        #expect(engine.answer(question: "thanks", context: ctx).answer
            .localizedCaseInsensitiveContains("Happy to help"))
    }

    // MARK: - Ask: out of scope

    /// The semantic gate was set above every distance the embedding model
    /// produces, so an unrelated question was force-routed to whichever health
    /// exemplar happened to be nearest and came back as a confident health
    /// answer. Off-topic questions must be refused instead.
    @Test func anOffTopicQuestionIsRefusedRatherThanAnswered() {
        let engine = HealthDataQueryEngine()
        let steps = series(.steps, days: 30) { _ in 9000 }
        let ctx = context(series: [.steps: steps])

        // Wording of the refusal is Remote Config backed, so the assertion is on
        // the confidence the engine reports, which is zero only on that path.
        for question in ["what is the capital of france", "write a poem about cats", "who won the world cup"] {
            let result = engine.answer(question: question, context: ctx)
            #expect(result.confidence == 0,
                    "\"\(question)\" came back as a health answer: \(result.answer)")
        }

        // The gate must not have swung so far that real questions are refused.
        for question in ["am i at risk for anything", "what state is my body in", "do i have any weekly patterns"] {
            #expect(engine.answer(question: question, context: ctx).confidence > 0,
                    "\"\(question)\" is a health question and must be answered")
        }
    }

    // MARK: - Ask: units

    /// Sleep hours were divided by 3600 a second time before being shown, so
    /// every sleep value the assistant quoted read "0.0h". Weight stored in
    /// kilograms was labelled lbs and body temperature stored in Celsius was
    /// labelled Fahrenheit.
    @Test func askQuotesEveryMetricInTheUnitItIsStoredIn() {
        // The registry is the source of truth for what ingest actually writes.
        #expect(HealthKitMetricRegistry.config(for: .sleepDuration).unit == .hour())
        #expect(HealthKitMetricRegistry.config(for: .weight).unit == .gramUnit(with: .kilo))
        #expect(HealthKitMetricRegistry.config(for: .bodyTemperature).unit == .degreeCelsius())

        // 7.2 stored hours must read as about 7 hours, never 0.0.
        let sleep = HealthMetric.sleepDuration.formatWithUnit(7.2)
        #expect(sleep.contains("7"), "sleep rendered as \(sleep)")
        #expect(!sleep.hasPrefix("0"), "sleep was divided by 3600 twice: \(sleep)")

        #expect(!HealthMetric.weight.formatWithUnit(72).localizedCaseInsensitiveContains("lb"),
                "weight is stored in kilograms")
        #expect(!HealthMetric.bodyTemperature.formatWithUnit(36.6).contains("F"),
                "body temperature is stored in Celsius")
    }

    // MARK: - Vitals: sleep totals

    private func sleepSample(
        _ value: HKCategoryValueSleepAnalysis,
        from start: Date,
        minutes: Double
    ) -> HKCategorySample {
        HKCategorySample(
            type: HKCategoryType(.sleepAnalysis),
            value: value.rawValue,
            start: start,
            end: start.addingTimeInterval(minutes * 60)
        )
    }

    /// A night the watch left a gap in arrives as two asleep blocks. The live
    /// tile picked the longer block and threw the other away, so a real 7 hour
    /// night was shown as 4.
    @Test func aNightSplitByAWristOffGapCountsBothBlocks() {
        let builder = LiveSleepSummaryBuilder()
        let bedtime = Date.cal.startOfDay(for: Date()).addingTimeInterval(-2 * 3600)

        let firstBlock = sleepSample(.asleepCore, from: bedtime, minutes: 240)
        // Two hours later than the first block ends, which is past the 90 minute
        // session gap, so these are two sessions on one wake day.
        let secondBlock = sleepSample(
            .asleepCore,
            from: bedtime.addingTimeInterval(240 * 60 + 2 * 3600),
            minutes: 180
        )

        let summary = builder.summarize(samples: [firstBlock, secondBlock])
        #expect(abs(summary.totalDuration - 7 * 3600) < 60,
                "both blocks belong to the same night, got \(summary.totalDuration / 3600) h")
    }

    /// Two sleep sources writing the same night doubled it, because raw sample
    /// durations were added instead of the covered spans being unioned.
    @Test func twoSourcesRecordingOneNightDoNotDoubleIt() {
        let builder = LiveSleepSummaryBuilder()
        let bedtime = Date.cal.startOfDay(for: Date()).addingTimeInterval(-3 * 3600)

        let watch = sleepSample(.asleepCore, from: bedtime, minutes: 420)
        let phone = sleepSample(.asleepCore, from: bedtime, minutes: 420)

        let summary = builder.summarize(samples: [watch, phone])
        #expect(abs(summary.totalDuration - 7 * 3600) < 60,
                "one shared night, got \(summary.totalDuration / 3600) h")
    }

    /// A source that writes only in-bed samples gave the tile nothing, so an
    /// iPhone-only user had no sleep tile at all. In-bed now stands in for the
    /// tile, but it must never reach the readiness scorer as if it were sleep.
    @Test func inBedStandsInForTheTileButNeverForTheScore() {
        let builder = LiveSleepSummaryBuilder()
        let bedtime = Date.cal.startOfDay(for: Date()).addingTimeInterval(-3 * 3600)

        let inBedOnly = builder.summarize(samples: [
            sleepSample(.inBed, from: bedtime, minutes: 450),
            // A second writer covering the same window must not double it.
            sleepSample(.inBed, from: bedtime, minutes: 450),
        ])
        #expect(inBedOnly.totalDuration == 0, "in bed is not asleep and must not be scored")
        #expect(abs(inBedOnly.inBedDuration - 7.5 * 3600) < 60)
        #expect(abs(inBedOnly.displayDuration - 7.5 * 3600) < 60, "the tile still has a number to show")

        // Once a real stage exists, the stage wins and in-bed stops standing in.
        let staged = builder.summarize(samples: [
            sleepSample(.inBed, from: bedtime, minutes: 450),
            sleepSample(.asleepCore, from: bedtime.addingTimeInterval(600), minutes: 400),
        ])
        #expect(abs(staged.totalDuration - 400 * 60) < 60)
        #expect(abs(staged.displayDuration - 400 * 60) < 60,
                "asleep time is what the tile shows whenever a source recorded it")
    }

    /// The live tile and the stored series cut a night in the same place only
    /// while they share one gap threshold. They drifted apart once the builder
    /// carried its own copy.
    @Test func theLiveTileAndTheStoredSeriesShareOneSessionGap() {
        #expect(LiveSleepSummaryBuilder().sessionGap == HealthKitManager.sleepSessionGapThreshold)
    }

    // MARK: - Vitals: honest scores

    /// Relaxing Brain Health so an iPhone-only user could get a tile let it
    /// publish a score where four of the five subscales were the neutral
    /// constant, so every such user read the same middling number as a finding.
    @MainActor
    @Test func brainHealthWithNothingMeasuredPublishesNoScore() {
        let scorer = BrainHealthScorer()
        let noon = Date.cal.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        // Sleep duration alone: the anchor, and nothing else.
        let duration = MetricTimeSeries(
            metric: .sleepDuration,
            samples: (0..<14).reversed().map {
                MetricSample(date: noon.addingTimeInterval(-Double($0) * 86_400), value: 7)
            }
        )

        scorer.compute(from: HealthDataStore(), timeSeries: [.sleepDuration: duration])
        #expect(scorer.currentScore == nil,
                "a score carried by the neutral default is not a measurement")
    }

    // MARK: - Daily Mirror

    /// The streak widget said "Start your mirror" but had no deep link, and once
    /// it got one it landed on the check-in sheet rather than the camera.
    @Test func theCaptureRouteSurvivesItsDeepLinkString() {
        #expect(Route.fromUITestIdentifier("mirrorCapture") == .mirrorCapture)
        #expect(Route.fromUITestIdentifier("journalEntry") == .journalEntry,
                "the older route still resolves, so existing links keep working")
        #expect(Route.fromUITestIdentifier("notARoute") == nil)
    }

    // MARK: - Readiness cadence

    /// Readiness used to be a morning anchor minus a one-way drain from the
    /// day's active calories, so a workout the app itself recommended pushed the
    /// number down and could talk the user into resting. It is a daily figure
    /// now: the day's effort belongs to Strain.
    @MainActor
    @Test func readinessHoldsItsMorningValueAllDay() {
        let defaults = UserDefaults(suiteName: "readiness.cadence.test")!
        defaults.removePersistentDomain(forName: "readiness.cadence.test")
        let store = ReadinessStore(userDefaults: defaults)

        store.saveMorningLock(78, for: Date())
        let viewModel = LiveViewModel(healthKitManager: HealthKitManager(), readinessStore: store)

        // A hard day's worth of active calories. Under the old model this drained
        // the anchor by the calorie total divided by 50, capped at 60 points.
        viewModel.activity.todayActiveCalories = 900
        viewModel.vitals.heartRateTimestamp = Date()
        viewModel.computeReadinessScore()

        #expect(viewModel.recovery.readinessScore == 78,
                "Readiness moved with the day's activity, got \(String(describing: viewModel.recovery.readinessScore))")

        // Every surface reads one of these three, so they must agree.
        #expect(store.loadDisplayedScore(for: Date()) == 78)
        #expect(store.loadCachedScore() == 78)

        defaults.removePersistentDomain(forName: "readiness.cadence.test")
    }
}
