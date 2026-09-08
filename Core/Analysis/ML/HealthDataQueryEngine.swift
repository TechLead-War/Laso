import Foundation
import NaturalLanguage

// MARK: - Health Data Query Engine

/// Natural language query engine for personal health data.
/// Transforms user questions into structured queries over the full ML
/// pipeline. Uses Apple's on-device NaturalLanguage framework for semantic
/// intent matching via NLEmbedding — no external API calls required.
final class HealthDataQueryEngine {

    // MARK: - Types

    /// Bundles all ML pipeline data needed to answer questions.
    struct QueryContext {
        let timeSeries: [HealthMetric: MetricTimeSeries]
        let baselines: [HealthMetric: UserBaseline]
        let trends: [HealthMetric: TrendAnalyzer.TrendResult]
        let correlations: [MLCorrelation]
        let forecasts: [HealthMetric: TimeSeriesForecaster.MultiHorizonForecast]
        let healthSignalReport: PredictiveHealthSignals.HealthSignalReport?
        let currentHealthState: HealthState?
        let discoveredPatterns: [DiscoveredPattern]
        let circadianProfile: CircadianAnalyzer.CircadianProfile?
        let timingRecommendations: [CircadianAnalyzer.TimingRecommendation]
        let optimalProfile: PersonalOptimizer.OptimalProfile?
        let idealDay: PersonalOptimizer.IdealDay?
        let scoreSensitivities: [PersonalOptimizer.SensitivityResult]
        let tomorrowRiskPrediction: MLPrediction?
        let compoundInsights: [CompoundInsightEngine.CompoundInsight]
        let temporalSequences: [TemporalSequenceMiner.TemporalSequence]
        /// Nil until something has been scored. Every sentence that quotes it is
        /// skipped in that case: a health assistant reading out "your health
        /// score is 0" to a user with no measurements is the worst stand-in of
        /// the lot.
        let overallScore: Int?
    }

    enum QueryIntent {
        case trend(metric: HealthMetric, period: QueryPeriod)
        case comparison(metric: HealthMetric, periodA: QueryPeriod, periodB: QueryPeriod)
        case correlation(metricA: HealthMetric, metricB: HealthMetric)
        case forecast(metric: HealthMetric, horizon: Int)
        case anomaly(metric: HealthMetric?)
        /// `period` is nil when the question named no window, which is the only
        /// case where scanning the whole stored history is the right answer.
        case bestWorst(metric: HealthMetric, seeking: BestWorst, period: QueryPeriod?)
        case status(metric: HealthMetric?)
        case healthState
        case risk
        case optimization
        case pattern(metric: HealthMetric?)
        case circadian
        case whyScore
        case causal(metric: HealthMetric)
        case general

        enum BestWorst { case best, worst }
    }

    /// Intermediate category for semantic matching (no associated values)
    private enum IntentCategory: String, CaseIterable {
        case trend, comparison, correlation, forecast, anomaly, bestWorst, status
        case healthState, risk, optimization, pattern, circadian, whyScore, causal
        case general
    }

    enum QueryPeriod: String {
        case today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth, last7Days, last30Days, last90Days

        var days: Int {
            switch self {
            case .today: return 1
            case .yesterday: return 1
            case .thisWeek, .lastWeek, .last7Days: return 7
            case .thisMonth, .lastMonth, .last30Days: return 30
            case .last90Days: return 90
            }
        }

        /// How many whole days back the window ends. Without this a past period
        /// carried only a length, so "last week" resolved to the same window as
        /// "this week" and the answer printed this week's numbers under the words
        /// "last week".
        var offset: Int {
            switch self {
            case .today, .thisWeek, .thisMonth, .last7Days, .last30Days, .last90Days: return 0
            case .yesterday: return 1
            case .lastWeek: return 7
            case .lastMonth: return 30
            }
        }

        /// The window a comparison names when the user gives only one side.
        /// "better than last month" means this month against last month, not
        /// against the default week.
        var comparisonCounterpart: QueryPeriod {
            switch self {
            case .today: return .yesterday
            case .yesterday: return .today
            case .thisWeek, .last7Days: return .lastWeek
            case .lastWeek: return .thisWeek
            case .thisMonth, .last30Days, .last90Days: return .lastMonth
            case .lastMonth: return .thisMonth
            }
        }

        var displayName: String {
            switch self {
            case .today: return "today"
            case .yesterday: return "yesterday"
            case .thisWeek: return "this week"
            case .lastWeek: return "last week"
            case .thisMonth: return "this month"
            case .lastMonth: return "last month"
            case .last7Days: return "the past week"
            case .last30Days: return "the past month"
            case .last90Days: return "the past 3 months"
            }
        }
    }

    struct QueryResult {
        let answer: String
        let dataPoints: [DataPoint]
        let confidence: Double
        let relatedQuestions: [String]

        struct DataPoint {
            let label: String
            let value: Double
            let unit: String
        }
    }

    // MARK: - Properties

    /// Apple's sentence embedding, loaded straight rather than through
    /// `NLEmbeddingAnalyzer`, whose bag-of-words fallback returns distances on a
    /// 0...1 scale that cannot be compared against the cosine cut-offs below.
    /// When the model is missing the semantic path is skipped entirely instead
    /// of matching everything.
    /// `static` so the one-time load is Swift's thread-safe global initialisation.
    /// The engine is a single shared instance queried off the main actor, where an
    /// instance-level `lazy var` would be an unsynchronised race.
    private static let sentenceEmbedding: NLEmbedding? = NLEmbedding.sentenceEmbedding(for: .english)
    private let semanticCacheLock = NSLock()
    private var semanticIntentCache: [String: IntentCategory] = [:]
    private var semanticMissCache = Set<String>()

    // MARK: - Metric Vocabulary

    private static let metricVocabulary: [String: HealthMetric] = [
        // Heart
        "heart rate": .heartRate, "hr": .heartRate, "pulse": .heartRate, "bpm": .heartRate,
        "resting heart rate": .restingHeartRate, "rhr": .restingHeartRate, "resting hr": .restingHeartRate, "resting pulse": .restingHeartRate,
        "hrv": .heartRateVariability, "heart rate variability": .heartRateVariability, "variability": .heartRateVariability,
        // The app calls HRV "heart calm signal" on screen and ships suggested
        // questions using that name, so the parser has to understand it too.
        // "recovery" is deliberately absent: that word is the app's name for the
        // readiness score on Home, not for HRV, so mapping it here answered a
        // question about one number with another.
        "heart calm signal": .heartRateVariability, "heart calm": .heartRateVariability,
        "calm signal": .heartRateVariability,
        "heart rate recovery": .heartRateRecovery, "hr recovery": .heartRateRecovery,
        "afib": .atrialFibrillationBurden, "atrial fibrillation": .atrialFibrillationBurden,
        // Sleep
        "sleep": .sleepDuration, "sleep duration": .sleepDuration, "hours slept": .sleepDuration, "time asleep": .sleepDuration,
        "deep sleep": .sleepDeep, "rem": .sleepREM, "rem sleep": .sleepREM, "core sleep": .sleepCore,
        "breathing disturbances": .sleepBreathingDisturbances, "sleep apnea": .sleepBreathingDisturbances,
        // Activity
        "steps": .steps, "step": .steps, "step count": .steps,
        "calories": .activeCalories, "active calories": .activeCalories, "active energy": .activeCalories,
        "basal calories": .basalCalories, "resting energy": .basalCalories,
        "exercise": .exerciseMinutes, "exercise minutes": .exerciseMinutes, "workout": .exerciseMinutes, "workouts": .exerciseMinutes,
        "workout duration": .workoutDuration, "training time": .workoutDuration,
        "stand hours": .standHours, "standing": .standHours, "stand time": .standHours,
        "distance": .distanceWalkingRunning, "walking distance": .distanceWalkingRunning, "running distance": .distanceWalkingRunning,
        "cycling distance": .distanceCycling, "cycling": .distanceCycling, "biking": .distanceCycling,
        "swimming distance": .distanceSwimming, "swimming": .distanceSwimming,
        "flights climbed": .flightsClimbed, "stairs": .flightsClimbed, "flights": .flightsClimbed,
        // Body
        "weight": .weight, "body weight": .weight,
        "bmi": .bmi, "body mass index": .bmi,
        "body fat": .bodyFatPercentage, "fat percentage": .bodyFatPercentage,
        "lean mass": .leanBodyMass, "lean body mass": .leanBodyMass, "muscle mass": .leanBodyMass,
        "waist": .waistCircumference, "waist circumference": .waistCircumference,
        "blood pressure": .bloodPressureSystolic, "systolic": .bloodPressureSystolic, "diastolic": .bloodPressureDiastolic,
        "body temperature": .bodyTemperature, "temperature": .bodyTemperature, "temp": .bodyTemperature,
        "wrist temperature": .appleSleepingWristTemperature, "wrist temp": .appleSleepingWristTemperature, "sleeping temperature": .appleSleepingWristTemperature,
        // Respiratory
        "blood oxygen": .bloodOxygen, "spo2": .bloodOxygen, "oxygen saturation": .bloodOxygen, "oxygen": .bloodOxygen,
        "vo2 max": .vo2Max, "vo2": .vo2Max, "aerobic fitness": .vo2Max, "cardio fitness": .vo2Max,
        "respiratory rate": .respiratoryRate, "breathing rate": .respiratoryRate, "breaths per minute": .respiratoryRate,
        // Mindfulness
        "mindfulness": .mindfulMinutes, "meditation": .mindfulMinutes, "mindful minutes": .mindfulMinutes,
        "daylight": .timeInDaylight, "sunlight": .timeInDaylight, "time in daylight": .timeInDaylight, "sun exposure": .timeInDaylight,
        // Mobility
        "walking speed": .walkingSpeed, "pace": .walkingSpeed, "gait speed": .walkingSpeed,
        "step length": .walkingStepLength, "stride length": .walkingStepLength,
        "walking asymmetry": .walkingAsymmetry, "gait asymmetry": .walkingAsymmetry,
        "walking steadiness": .walkingSteadiness, "steadiness": .walkingSteadiness, "balance": .walkingSteadiness,
        "six minute walk": .sixMinuteWalkTestDistance, "6 minute walk": .sixMinuteWalkTestDistance,
        // Nutrition
        "water": .waterIntake, "water intake": .waterIntake, "hydration": .waterIntake,
        "caffeine": .caffeineIntake, "coffee": .caffeineIntake,
        "protein": .proteinIntake, "protein intake": .proteinIntake,
        "fiber": .fiberIntake, "fibre": .fiberIntake,
        "sugar": .sugarIntake, "sugar intake": .sugarIntake,
        "sodium": .sodiumIntake, "salt": .sodiumIntake,
        "carbs": .carbohydrateIntake, "carbohydrates": .carbohydrateIntake,
        "dietary fat": .fatIntake,
        "diet calories": .totalCaloriesIntake, "food calories": .totalCaloriesIntake,
        // Metabolic
        "blood glucose": .bloodGlucose, "glucose": .bloodGlucose, "blood sugar": .bloodGlucose,
        // Hearing
        "headphone audio": .headphoneAudioExposure, "headphone volume": .headphoneAudioExposure,
    ]

    private static let periodVocabulary: [String: QueryPeriod] = [
        "today": .today, "yesterday": .yesterday,
        "this week": .thisWeek, "last week": .lastWeek,
        "this month": .thisMonth, "last month": .lastMonth,
        "past week": .last7Days, "last 7 days": .last7Days, "7 days": .last7Days, "recent week": .last7Days,
        "past month": .last30Days, "last 30 days": .last30Days, "30 days": .last30Days, "recent month": .last30Days,
        "last 3 months": .last90Days, "past 3 months": .last90Days, "90 days": .last90Days, "past quarter": .last90Days,
    ]

    // MARK: - Semantic Exemplars

    /// Canonical questions for semantic matching when keyword detection is ambiguous.
    private static let intentExemplars: [IntentCategory: [String]] = [
        .trend: [
            "how is my heart rate trending", "is my hrv going up or down",
            "what direction is my sleep heading", "am i improving over time",
            "show me the trend", "has my weight been changing",
        ],
        .risk: [
            "am i at risk for anything", "any health warnings",
            "should i be worried about anything", "are there any red flags",
            "is anything concerning in my data", "health risks",
        ],
        .healthState: [
            "what state is my body in", "how is my body doing overall",
            "am i recovered", "what is my current health state",
            "how am i doing right now", "overall body status",
        ],
        .optimization: [
            "how do i improve my score", "what should i do today",
            "how to have a great day", "optimize my health",
            "what does my ideal day look like", "tips for better recovery",
        ],
        .pattern: [
            "do i have any patterns", "weekly cycles in my data",
            "when does my heart rate peak", "any recurring rhythms",
            "day of week patterns", "seasonal trends",
        ],
        .circadian: [
            "when should i work out", "best time to exercise",
            "what is my chronotype", "my body clock",
            "optimal time for sleep", "when am i most alert",
        ],
        .whyScore: [
            "why is my score low", "what is affecting my score",
            "explain my recovery score", "score breakdown",
            "why did my score drop", "what drives my score",
        ],
        .causal: [
            "what causes my hrv to drop", "why does my sleep suffer",
            "what drives my heart rate up", "root cause analysis",
            "what influences my recovery", "what leads to bad days",
        ],
        .forecast: [
            "predict my heart rate", "what will my hrv be tomorrow",
            "forecast my sleep", "what should i expect next week",
        ],
        .comparison: [
            "compare this week to last week", "am i better than last month",
            "this month versus last month", "how does today compare",
        ],
        .anomaly: [
            "anything unusual in my data", "any weird readings",
            "anomalies or spikes", "something seems off",
        ],
        .correlation: [
            "does sleep affect my heart rate", "relationship between exercise and hrv",
            "connection between caffeine and sleep", "are these metrics linked",
        ],
    ]

    private static let semanticCorpus: [(category: IntentCategory, exemplar: String)] = IntentCategory.allCases.flatMap { category in
        (intentExemplars[category] ?? []).map { (category: category, exemplar: $0) }
    }

    /// Cosine distance above which a question is treated as unrelated to every
    /// exemplar. Measured against Apple's sentence embedding using the exemplars
    /// below: real health questions that reach this path top out at 0.796, and
    /// off-topic ones ("what is the capital of france", "how do i fix a python
    /// import error") start at 0.812. 0.80 sits in that gap. The old 1.2 was
    /// above every observed distance, so it accepted everything.
    private static let semanticMaxDistance = 0.80
    /// How far the winning category must beat the runner-up. A question that sits
    /// between two categories has no clear intent, and picking the argmin anyway
    /// is what made small rewordings flip the answer. Kept low because a reject
    /// is cheap here: this path runs only after keyword matching failed, and a
    /// rejected question still falls through to a status answer when it named a
    /// metric, or to an honest "I did not understand" when it did not.
    private static let semanticMinMargin = 0.03

    // MARK: - Query Processing

    /// Primary entry point. uses full ML pipeline context.
    /// Named `answer` rather than `query` so it does not collide with the async
    /// `HealthQueryEngine.query`, which would resolve to itself from an async
    /// context and recurse.
    func answer(question: String, context: QueryContext) -> QueryResult {
        let normalized = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle conversational inputs before parsing health intent
        if let conversational = handleConversational(normalized, ctx: context) {
            return conversational
        }

        let intent = parseIntent(normalized)

        switch intent {
        case .trend(let metric, let period):
            return answerTrend(metric: metric, period: period, ctx: context)
        case .comparison(let metric, let periodA, let periodB):
            return answerComparison(metric: metric, periodA: periodA, periodB: periodB, ctx: context)
        case .correlation(let metricA, let metricB):
            return answerCorrelation(metricA: metricA, metricB: metricB, ctx: context)
        case .forecast(let metric, let horizon):
            return answerForecast(metric: metric, horizon: horizon, ctx: context)
        case .anomaly(let metric):
            return answerAnomaly(metric: metric, ctx: context)
        case .bestWorst(let metric, let seeking, let period):
            return answerBestWorst(metric: metric, seeking: seeking, period: period, ctx: context)
        case .status(let metric):
            return answerStatus(metric: metric, ctx: context)
        case .healthState:
            return answerHealthState(ctx: context)
        case .risk:
            return answerRisk(ctx: context)
        case .optimization:
            return answerOptimization(ctx: context)
        case .pattern(let metric):
            return answerPattern(metric: metric, ctx: context)
        case .circadian:
            return answerCircadian(ctx: context)
        case .whyScore:
            return answerWhyScore(ctx: context)
        case .causal(let metric):
            return answerCausal(metric: metric, ctx: context)
        case .general:
            return answerNotUnderstood(ctx: context)
        }
    }

    // MARK: - Intent Parsing

    private func parseIntent(_ question: String) -> QueryIntent {
        let detectedMetrics = detectMetrics(in: question)
        let detectedPeriods = detectPeriods(in: question)
        let primaryMetric = detectedMetrics.first

        // Try keyword matching first
        if let keywordResult = keywordIntent(question, metrics: detectedMetrics, periods: detectedPeriods) {
            return keywordResult
        }

        // Semantic matching fallback via NLEmbedding
        if let category = semanticIntentMatch(question) {
            return resolveCategory(category, question: question, metrics: detectedMetrics, periods: detectedPeriods)
        }

        // Default: status if we found a metric, general otherwise
        if let metric = primaryMetric {
            return .status(metric: metric)
        }
        return .general
    }

    /// Every list is matched on whole words. The old raw `contains` let "most"
    /// fire inside "almost" and "improve" fire inside "improved", so ordinary
    /// questions were answered by the personal-record and optimization branches.
    /// Inflections are spelled out for the same reason.
    private enum Patterns {
        static let healthState = ["state", "body doing", "body status", "recovered", "health state", "doing overall", "what data"]
        static let risk = ["risk", "risks", "warning", "warnings", "worried", "danger", "concern", "concerning", "red flag", "red flags", "careful"]
        static let optimization = ["optimize", "optimise", "improve", "ideal day", "best day", "tip", "tips", "should i do", "better score", "great day", "focus on"]
        static let pattern = ["pattern", "patterns", "cycle", "cycles", "rhythm", "rhythms", "recurring", "routine", "consistent", "consistency"]
        static let circadian = ["body clock", "chronotype", "best time", "when should", "optimal time", "when to"]
        static let whyScore = ["why is my score", "score low", "score drop", "score dropped", "score breakdown", "explain my score", "affecting my score", "driving my score"]
        static let causal = ["cause", "causes", "causing", "why does", "what drives", "root cause", "what leads to", "what makes my", "affects my", "affecting my", "influences"]
        static let correlation = ["affect", "affects", "affecting", "impact", "impacts", "correlated", "correlation", "related", "relationship", "connected", "connection", "influence", "influences", "linked"]
        static let forecast = ["predict", "prediction", "forecast", "will my", "expect", "next week", "next month", "tomorrow", "future"]
        static let trend = ["trend", "trending", "changing", "improving", "improved", "declining", "declined", "getting", "heading", "direction", "going up", "going down"]
        static let comparison = ["compare", "compared", "comparison", "versus", "vs", "better than", "worse than", "different", "difference"]
        static let anomaly = ["unusual", "abnormal", "anomaly", "anomalies", "weird", "strange", "spike", "spikes", "something off"]
        /// "Am I getting enough deep sleep?" asks whether a value is where it
        /// should be, which is what the status answer reports. Without this the
        /// word "getting" sent it to the trend branch instead.
        static let sufficiency = ["enough", "normal", "healthy"]
        static let best = ["best", "highest", "most", "peak", "record", "personal best"]
        static let worst = ["worst", "lowest", "least", "minimum"]
    }

    private func keywordIntent(_ question: String, metrics: [HealthMetric], periods: [QueryPeriod]) -> QueryIntent? {
        let primaryMetric = metrics.first
        let primaryPeriod = periods.first ?? .last7Days

        if Self.matches(question, Patterns.whyScore) {
            return .whyScore
        }
        if Self.matches(question, Patterns.healthState) {
            return .healthState
        }
        if Self.matches(question, Patterns.risk) {
            return .risk
        }
        if Self.matches(question, Patterns.circadian) {
            return .circadian
        }
        if Self.matches(question, Patterns.pattern) {
            return .pattern(metric: primaryMetric)
        }

        // Correlation (needs two metrics)
        if metrics.count >= 2 && Self.matches(question, Patterns.correlation) {
            return .correlation(metricA: metrics[0], metricB: metrics[1])
        }

        // Causal (one metric + causal keyword)
        if Self.matches(question, Patterns.causal), let metric = primaryMetric {
            return .causal(metric: metric)
        }

        // Forecast
        if Self.matches(question, Patterns.forecast), let metric = primaryMetric {
            let horizon = question.contains("week") ? 7 : question.contains("3 day") ? 3 : 1
            return .forecast(metric: metric, horizon: horizon)
        }

        // Comparison before trend: "getting better than last month" names two
        // windows and must not be answered as a one-window trend.
        if Self.matches(question, Patterns.comparison), let metric = primaryMetric {
            let (periodA, periodB) = Self.comparisonPeriods(from: periods)
            return .comparison(metric: metric, periodA: periodA, periodB: periodB)
        }

        if Self.matches(question, Patterns.sufficiency), let metric = primaryMetric {
            return .status(metric: metric)
        }

        // Trend
        if Self.matches(question, Patterns.trend), let metric = primaryMetric {
            return .trend(metric: metric, period: primaryPeriod)
        }

        // Anomaly before best/worst: "a weird peak in my hrv" is about the odd
        // reading, not about the personal record.
        if Self.matches(question, Patterns.anomaly) {
            return .anomaly(metric: primaryMetric)
        }

        // Best/Worst
        if let metric = primaryMetric {
            if Self.matches(question, Patterns.best) {
                return .bestWorst(metric: metric, seeking: .best, period: periods.first)
            }
            if Self.matches(question, Patterns.worst) {
                return .bestWorst(metric: metric, seeking: .worst, period: periods.first)
            }
        }

        // Optimization last: it needs no metric, so an earlier position let
        // "improve" swallow questions that named one.
        if Self.matches(question, Patterns.optimization) {
            return .optimization
        }

        return nil // No keyword match. fall through to semantic
    }

    /// A comparison needs two windows. When the user names only one, pair it with
    /// the window on the other side of now, and always put the more recent window
    /// first so the verdict reads in the direction the sentence claims.
    private static func comparisonPeriods(from periods: [QueryPeriod]) -> (QueryPeriod, QueryPeriod) {
        let named = periods.first ?? .thisWeek
        let other = periods.count > 1 ? periods[1] : named.comparisonCounterpart
        return named.offset <= other.offset ? (named, other) : (other, named)
    }

    /// Sentence-embedding semantic match for ambiguous queries.
    private func semanticIntentMatch(_ question: String) -> IntentCategory? {
        let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 8 else { return nil }

        semanticCacheLock.lock()
        if let cached = semanticIntentCache[normalized] {
            semanticCacheLock.unlock()
            return cached
        }
        if semanticMissCache.contains(normalized) {
            semanticCacheLock.unlock()
            return nil
        }
        semanticCacheLock.unlock()

        let match = nearestCategory(to: normalized)

        semanticCacheLock.lock()
        if semanticIntentCache.count + semanticMissCache.count > 256 {
            semanticIntentCache.removeAll(keepingCapacity: true)
            semanticMissCache.removeAll(keepingCapacity: true)
        }
        if let match {
            semanticIntentCache[normalized] = match
        } else {
            semanticMissCache.insert(normalized)
        }
        semanticCacheLock.unlock()

        return match
    }

    /// Nearest exemplar category, or nil when the question is not close enough to
    /// any of them.
    ///
    /// `NLEmbedding` cosine distance runs 0...2 and ordinary English sentences
    /// rarely pass ~1.1 against each other, so the old `< 1.2` cut accepted every
    /// question and force-routed unrelated ones to whichever exemplar happened to
    /// be nearest. Both gates below have to hold: an absolute cut, and a gap to
    /// the runner-up category so a question sitting between two categories is
    /// refused instead of decided by a rounding error.
    private func nearestCategory(to question: String) -> IntentCategory? {
        guard let embedding = Self.sentenceEmbedding else { return nil }

        var bestByCategory: [IntentCategory: Double] = [:]
        for (category, exemplar) in Self.semanticCorpus {
            let distance = embedding.distance(between: question, and: exemplar)
            if distance < bestByCategory[category, default: .infinity] {
                bestByCategory[category] = distance
            }
        }

        // Sorted with the category name as tiebreak: Dictionary order is seeded
        // per process, so without it the same question could route differently
        // between launches.
        let ranked = bestByCategory.sorted {
            $0.value != $1.value ? $0.value < $1.value : $0.key.rawValue < $1.key.rawValue
        }
        guard let best = ranked.first, best.value <= Self.semanticMaxDistance else { return nil }
        let runnerUp = ranked.dropFirst().first?.value ?? .infinity
        guard runnerUp - best.value >= Self.semanticMinMargin else { return nil }
        return best.key
    }

    /// Convert a category (from semantic match) into a full QueryIntent with extracted params.
    private func resolveCategory(_ category: IntentCategory, question: String, metrics: [HealthMetric], periods: [QueryPeriod]) -> QueryIntent {
        let metric = metrics.first
        let period = periods.first ?? .last7Days

        switch category {
        case .trend:
            return metric.map { .trend(metric: $0, period: period) } ?? .general
        case .comparison:
            let (a, b) = Self.comparisonPeriods(from: periods)
            return metric.map { .comparison(metric: $0, periodA: a, periodB: b) } ?? .general
        case .correlation:
            return metrics.count >= 2 ? .correlation(metricA: metrics[0], metricB: metrics[1]) : .general
        case .forecast:
            return metric.map { .forecast(metric: $0, horizon: 1) } ?? .general
        case .anomaly:
            return .anomaly(metric: metric)
        case .bestWorst:
            // Read the direction from the question. Hardcoding .best answered a
            // "worst day" question with the user's personal record.
            let seeking: QueryIntent.BestWorst = Self.matches(question, Patterns.worst) ? .worst : .best
            return metric.map { .bestWorst(metric: $0, seeking: seeking, period: periods.first) } ?? .general
        case .status:
            return .status(metric: metric)
        case .healthState:
            return .healthState
        case .risk:
            return .risk
        case .optimization:
            return .optimization
        case .pattern:
            return .pattern(metric: metric)
        case .circadian:
            return .circadian
        case .whyScore:
            return .whyScore
        case .causal:
            return metric.map { .causal(metric: $0) } ?? .general
        case .general:
            return .general
        }
    }

    // MARK: - Metric & Period Detection

    /// Longest term first so a phrase claims its span before a shorter term can
    /// match inside it, with the term itself as the tiebreak: Dictionary order is
    /// seeded per process, so two equal-length terms would otherwise win against
    /// each other differently on every launch.
    private static func rankedVocabulary<T>(_ vocabulary: [String: T]) -> [(term: String, value: T)] {
        vocabulary
            .sorted { $0.key.count != $1.key.count ? $0.key.count > $1.key.count : $0.key < $1.key }
            .map { (term: $0.key, value: $0.value) }
    }

    private static let rankedMetricVocabulary = rankedVocabulary(metricVocabulary)
    private static let rankedPeriodVocabulary = rankedVocabulary(periodVocabulary)

    /// Word-bounded search. A raw substring search let short terms fire inside
    /// longer words: "hr" matched "hrs" and "three", "rem" matched "remember",
    /// "temp" matched "attempt", each silently switching the answer to a metric
    /// the user never named.
    private static func wordRange(of term: String, in text: String) -> Range<String.Index>? {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: term) + "\\b"
        return text.range(of: pattern, options: [.regularExpression])
    }

    private static func matches(_ text: String, _ patterns: [String]) -> Bool {
        patterns.contains { wordRange(of: $0, in: text) != nil }
    }

    /// Collects vocabulary hits in the order they appear, keeping only the first
    /// term to claim any given span. Without the span check "resting heart rate"
    /// also yielded "heart rate", so a two-metric question was answered about the
    /// long phrase and its own sub-phrase while the metric the user actually
    /// named was dropped.
    private static func detect<T: Equatable>(_ vocabulary: [(term: String, value: T)], in text: String) -> [T] {
        let lower = text.lowercased()
        var found: [(value: T, position: Int)] = []
        var claimed: [Range<String.Index>] = []

        for (term, value) in vocabulary {
            guard let range = wordRange(of: term, in: lower) else { continue }
            guard !claimed.contains(where: { $0.overlaps(range) }) else { continue }
            claimed.append(range)
            guard !found.contains(where: { $0.value == value }) else { continue }
            found.append((value: value, position: lower.distance(from: lower.startIndex, to: range.lowerBound)))
        }

        return found.sorted { $0.position < $1.position }.map(\.value)
    }

    private func detectMetrics(in text: String) -> [HealthMetric] {
        Self.detect(Self.rankedMetricVocabulary, in: text)
    }

    /// One vocabulary for both engines. The LLM path had its own 18-entry
    /// substring map that knew nothing about most metrics and double-fired on
    /// overlapping phrases, so the numbers under an answer came from a different
    /// reading of the question than the answer itself.
    func metrics(in question: String) -> [HealthMetric] {
        detectMetrics(in: question)
    }

    private func detectPeriods(in text: String) -> [QueryPeriod] {
        Self.detect(Self.rankedPeriodVocabulary, in: text)
    }

    // MARK: - Answer Generators (Original, Improved)

    private func answerTrend(metric: HealthMetric, period: QueryPeriod, ctx: QueryContext) -> QueryResult {
        guard let series = ctx.timeSeries[metric] else {
            return noDataResult(for: metric)
        }

        let recent = recentSamples(from: series, days: period.days, offset: period.offset)
        guard recent.count >= 2 else { return noDataResult(for: metric) }

        let values = recent.map(\.value)
        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let pctChange = firstAvg != 0 ? ((secondAvg - firstAvg) / firstAvg) * 100 : 0
        let avg = values.reduce(0, +) / Double(values.count)

        let direction: String
        let sentiment: Sentiment
        if abs(pctChange) < 2 {
            direction = "holding steady"
            sentiment = .neutral
        } else if pctChange > 0 {
            direction = metric.higherIsBetter ? "on an upward trend" : "creeping up"
            sentiment = metric.higherIsBetter ? .positive : .negative
        } else {
            direction = metric.higherIsBetter ? "dipping down" : "coming down"
            sentiment = metric.higherIsBetter ? .negative : .positive
        }

        let actionAdvice = trendActionAdvice(metric: metric, pctChange: pctChange, sentiment: sentiment)
        let answer = Copy.Analysis.HealthDataQuery.trendingAnswer(action: actionAdvice, metric: metric.displayName, direction: direction, period: period.displayName, avg: metric.formatWithUnit(avg))

        return QueryResult(
            answer: answer,
            dataPoints: [
                .init(label: Copy.Analysis.HealthDataQuery.labelAverage, value: avg, unit: metric.unit),
                .init(label: Copy.Analysis.HealthDataQuery.labelChange, value: pctChange, unit: "%"),
                .init(label: Copy.Analysis.HealthDataQuery.labelLatest, value: values.last ?? 0, unit: metric.unit),
            ],
            confidence: min(1.0, Double(recent.count) / 14.0),
            relatedQuestions: [
                Copy.Analysis.HealthDataQuery.relatedAffects(metric.displayName),
                Copy.Analysis.HealthDataQuery.relatedPredict(metric.displayName),
                Copy.Analysis.HealthDataQuery.relatedPatterns(metric.displayName),
            ]
        )
    }

    private func answerComparison(metric: HealthMetric, periodA: QueryPeriod, periodB: QueryPeriod, ctx: QueryContext) -> QueryResult {
        guard let series = ctx.timeSeries[metric] else {
            return noDataResult(for: metric)
        }

        // Each window comes from its own period, so the label the sentence prints
        // always names the window the number came from. The old fixed
        // recent-then-previous pairing printed the wrong label whenever the user
        // named the older window first.
        let samplesA = recentSamples(from: series, days: periodA.days, offset: periodA.offset)
        let samplesB = recentSamples(from: series, days: periodB.days, offset: periodB.offset)
        guard !samplesA.isEmpty, !samplesB.isEmpty else { return noDataResult(for: metric) }

        let avgA = samplesA.valueMean
        let avgB = samplesB.valueMean
        let pctDiff = avgB != 0 ? ((avgA - avgB) / avgB) * 100 : 0

        let better = (pctDiff > 0 && metric.higherIsBetter) || (pctDiff < 0 && !metric.higherIsBetter)
        let verdict: String
        if abs(pctDiff) < 3 {
            verdict = Copy.Analysis.HealthDataQuery.comparisonRoughlySame
        } else {
            verdict = better ? Copy.Analysis.HealthDataQuery.comparisonLookingBetter : Copy.Analysis.HealthDataQuery.comparisonABitLower
        }

        let comparisonAction = better
            ? Copy.Analysis.HealthDataQuery.comparisonKeepUp
            : (abs(pctDiff) < 3 ? Copy.Analysis.HealthDataQuery.comparisonHoldingSteady : Copy.Analysis.HealthDataQuery.comparisonGetBack(period: periodB.displayName))
        let answer = Copy.Analysis.HealthDataQuery.comparisonAnswer(action: comparisonAction, metric: metric.displayName, periodA: periodA.displayName, verdict: verdict, periodB: periodB.displayName, avgA: metric.formatWithUnit(avgA), avgB: metric.formatWithUnit(avgB))

        return QueryResult(
            answer: answer,
            dataPoints: [
                .init(label: periodA.displayName.capitalized, value: avgA, unit: metric.unit),
                .init(label: periodB.displayName.capitalized, value: avgB, unit: metric.unit),
            ],
            confidence: 0.85,
            relatedQuestions: [
                Copy.Analysis.HealthDataQuery.qHowTrending(metric.displayName),
                Copy.Analysis.HealthDataQuery.relatedAffects(metric.displayName),
            ]
        )
    }

    private func answerCorrelation(metricA: HealthMetric, metricB: HealthMetric, ctx: QueryContext) -> QueryResult {
        let match = ctx.correlations.first {
            ($0.metricA == metricA && $0.metricB == metricB) ||
            ($0.metricA == metricB && $0.metricB == metricA)
        }

        if let corr = match {
            let strength = abs(corr.pearsonR) >= 0.7 ? Copy.Analysis.HealthDataQuery.strengthStrong
                : abs(corr.pearsonR) >= 0.4 ? Copy.Analysis.HealthDataQuery.strengthModerate
                : abs(corr.pearsonR) >= 0.2 ? Copy.Analysis.HealthDataQuery.strengthMild
                : Copy.Analysis.HealthDataQuery.strengthVeryWeak
            let direction = corr.pearsonR > 0 ? Copy.Analysis.HealthDataQuery.directionMoveTogether : Copy.Analysis.HealthDataQuery.directionMoveOpposite

            var answer: String
            if corr.grangerCausal {
                let lagText = corr.grangerOptimalLag == 1 ? Copy.Analysis.HealthDataQuery.lagNextDay : Copy.Analysis.HealthDataQuery.lagDaysLater(corr.grangerOptimalLag)
                answer = Copy.Analysis.HealthDataQuery.correlationCausal(metricA: corr.metricA.displayName, metricB: corr.metricB.displayName, lag: lagText, strength: strength, direction: direction)
            } else {
                let actionableMetric = metricA.higherIsBetter == metricB.higherIsBetter ? metricA : metricB
                let otherMetric = actionableMetric == metricA ? metricB : metricA
                answer = Copy.Analysis.HealthDataQuery.correlationActionable(actionable: actionableMetric.displayName, other: otherMetric.displayName, strength: strength, direction: direction)
            }

            return QueryResult(
                answer: answer,
                dataPoints: [
                    .init(label: Copy.Analysis.HealthDataQuery.labelCorrelation, value: corr.pearsonR, unit: "r"),
                    .init(label: Copy.Analysis.HealthDataQuery.labelStability, value: corr.stability, unit: ""),
                ],
                confidence: corr.stability,
                relatedQuestions: [
                    Copy.Analysis.HealthDataQuery.qHowTrending(metricA.displayName),
                    "What else affects my \(metricB.displayName)?",
                ]
            )
        }

        // Provide current values even when no correlation is found
        var dataPoints: [QueryResult.DataPoint] = []
        if let seriesA = ctx.timeSeries[metricA], let latestA = seriesA.samples.last {
            dataPoints.append(.init(label: metricA.displayName, value: latestA.value, unit: metricA.unit))
        }
        if let seriesB = ctx.timeSeries[metricB], let latestB = seriesB.samples.last {
            dataPoints.append(.init(label: metricB.displayName, value: latestB.value, unit: metricB.unit))
        }
        return QueryResult(
            answer: Copy.Analysis.HealthDataQuery.correlationNoLink(metricA: metricA.displayName, metricB: metricB.displayName),
            dataPoints: dataPoints,
            confidence: 0.5,
            relatedQuestions: [
                Copy.Analysis.HealthDataQuery.qHowTrending(metricA.displayName),
                Copy.Analysis.HealthDataQuery.qHowTrending(metricB.displayName),
            ]
        )
    }

    private func answerForecast(metric: HealthMetric, horizon: Int, ctx: QueryContext) -> QueryResult {
        guard let forecast = ctx.forecasts[metric],
              let result = forecast.horizons.first(where: { $0.horizon == horizon }) ?? forecast.horizons.first else {
            // Graceful fallback: use recent trend to give a rough projection
            if let series = ctx.timeSeries[metric] {
                let recent = recentSamples(from: series, days: 7)
                if recent.count >= 2 {
                    let avg = recent.valueMean
                    let latest = recent.last?.value ?? avg
                    let when = horizon == 1 ? "tomorrow" : "in \(horizon) days"
                    return QueryResult(
                        answer: Copy.Analysis.HealthDataQuery.forecastNoModel(metric: metric.displayName, avg: metric.formatWithUnit(avg), latest: metric.formatWithUnit(latest), when: when),
                        dataPoints: [
                            .init(label: "7-day avg", value: avg, unit: metric.unit),
                            .init(label: Copy.Analysis.HealthDataQuery.labelLatest, value: latest, unit: metric.unit),
                        ],
                        confidence: 0.4,
                        relatedQuestions: [Copy.Analysis.HealthDataQuery.qHowTrending(metric.displayName)]
                    )
                }
            }
            return QueryResult(
                answer: Copy.Analysis.HealthDataQuery.forecastNeedMore(metric: metric.displayName),
                dataPoints: [],
                confidence: 0.3,
                relatedQuestions: [Copy.Analysis.HealthDataQuery.qHowTrending(metric.displayName)]
            )
        }

        let when = horizon == 1 ? "tomorrow" : "in \(horizon) days"
        let forecastAction = forecastActionAdvice(metric: metric, predicted: result.value, context: ctx)
        let answer = Copy.Analysis.HealthDataQuery.forecastAnswer(action: forecastAction, metric: metric.displayName, value: metric.formatWithUnit(result.value), when: when)

        return QueryResult(
            answer: answer,
            dataPoints: [
                .init(label: "Predicted", value: result.value, unit: metric.unit),
                .init(label: "Low end", value: result.ciLower, unit: metric.unit),
                .init(label: "High end", value: result.ciUpper, unit: metric.unit),
            ],
            confidence: max(0.3, 1.0 - result.ciWidth / max(1, result.value)),
            relatedQuestions: [
                Copy.Analysis.HealthDataQuery.qHowTrending(metric.displayName),
                Copy.Analysis.HealthDataQuery.relatedAffects(metric.displayName),
            ]
        )
    }

    private func answerAnomaly(metric: HealthMetric?, ctx: QueryContext) -> QueryResult {
        // Every metric, in a fixed order. `keys.prefix(15)` took an arbitrary
        // slice of an unordered Dictionary, so the same data surfaced a different
        // anomaly, or none at all, on every launch. The cap belongs after the
        // deviation sort below, not before the scan.
        let metricsToCheck: [HealthMetric] = metric.map { [$0] }
            ?? ctx.timeSeries.keys.sorted { $0.rawValue < $1.rawValue }

        var anomalies: [(metric: HealthMetric, deviation: Double, value: Double)] = []
        for m in metricsToCheck {
            guard let series = ctx.timeSeries[m], let latest = series.samples.last,
                  let baseline = ctx.baselines[m] else { continue }
            let dev = abs(deviation(of: latest.value, from: baseline))
            if dev > 2.0 { anomalies.append((m, dev, latest.value)) }
        }

        if anomalies.isEmpty {
            return QueryResult(
                answer: Copy.Analysis.HealthDataQuery.anomalyAllNormal,
                dataPoints: [],
                confidence: 0.7,
                relatedQuestions: [Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall, Copy.Analysis.HealthDataQuery.rqAmIAtRiskForAnything]
            )
        }

        anomalies.sort { $0.deviation > $1.deviation }
        let top = anomalies[0]
        let dir = (ctx.baselines[top.metric].map { top.value > $0.mean } ?? true) ? "higher" : "lower"
        let anomalyAction = anomalyActionAdvice(metric: top.metric, isHigh: dir == "higher")
        var answer = Copy.Analysis.HealthDataQuery.anomalyAnswer(action: anomalyAction, metric: top.metric.displayName, value: top.metric.formatWithUnit(top.value), dir: dir)
        if anomalies.count > 1 {
            let others = anomalies.dropFirst().prefix(2).map { $0.metric.displayName }.joined(separator: " and ")
            answer += " Your \(others) \(anomalies.count > 2 ? "are" : "is") also outside the usual range."
        }

        return QueryResult(
            answer: answer,
            dataPoints: anomalies.prefix(3).map {
                .init(label: $0.metric.displayName, value: $0.value, unit: $0.metric.unit)
            },
            confidence: 0.8,
            relatedQuestions: anomalies.prefix(2).map { "What's happening with my \($0.metric.displayName)?" }
        )
    }

    private func answerBestWorst(metric: HealthMetric, seeking: QueryIntent.BestWorst, period: QueryPeriod?, ctx: QueryContext) -> QueryResult {
        guard let series = ctx.timeSeries[metric], !series.samples.isEmpty else {
            return noDataResult(for: metric)
        }

        // "My best step day this week" used to return the all-time record, which
        // can be months old, because the parsed window was thrown away. History
        // is scanned only when the question named no window at all.
        let scope = period.map { recentSamples(from: series, days: $0.days, offset: $0.offset) } ?? series.samples
        guard !scope.isEmpty else { return noDataResult(for: metric) }

        let sorted = scope.sorted { $0.value < $1.value }
        guard let first = sorted.first, let last = sorted.last else {
            return noDataResult(for: metric)
        }
        let target = seeking == .best
            ? (metric.higherIsBetter ? last : first)
            : (metric.higherIsBetter ? first : last)

        let dateStr = DateFormatter.localizedString(from: target.date, dateStyle: .medium, timeStyle: .none)
        let label = seeking == .best ? "best" : "worst"

        let suffix = seeking == .best ? Copy.Analysis.HealthDataQuery.prBestSuffix : Copy.Analysis.HealthDataQuery.prWorstSuffix
        let answer = Copy.Analysis.HealthDataQuery.prAnswer(label: label, metric: metric.displayName, value: metric.formatWithUnit(target.value), dateStr: dateStr, suffix: suffix)

        return QueryResult(
            answer: answer,
            dataPoints: [.init(label: label.capitalized, value: target.value, unit: metric.unit)],
            confidence: 0.95,
            relatedQuestions: [
                Copy.Analysis.HealthDataQuery.qHowTrending(metric.displayName),
                Copy.Analysis.HealthDataQuery.qWhatWasLabel(seeking == .best ? "worst" : "best", metric.displayName),
            ]
        )
    }

    private func answerStatus(metric: HealthMetric?, ctx: QueryContext) -> QueryResult {
        guard let m = metric else { return answerNotUnderstood(ctx: ctx) }
        guard let series = ctx.timeSeries[m] else { return noDataResult(for: m) }

        let recent = recentSamples(from: series, days: 7)
        guard !recent.isEmpty else { return noDataResult(for: m) }

        let avg = recent.valueMean
        let latest = recent.last?.value ?? avg

        var answer: String

        if let baseline = ctx.baselines[m] {
            // Judged on the same reading the sentence prints. Judging the 7-day
            // mean while printing the latest sample produced answers like "your
            // HRV has dipped to 71 ms" when 71 ms was above baseline.
            let dev = deviation(of: latest, from: baseline)
            let latestStr = m.formatWithUnit(latest)
            if dev > 1 {
                answer = m.higherIsBetter
                    ? Copy.Analysis.HealthDataQuery.statusKeepDoing(metric: m.displayName, latest: latestStr)
                    : Copy.Analysis.HealthDataQuery.statusEaseUp(metric: m.displayName, latest: latestStr)
            } else if dev < -1 {
                answer = m.higherIsBetter
                    ? Copy.Analysis.HealthDataQuery.statusDipped(metric: m.displayName, latest: latestStr)
                    : Copy.Analysis.HealthDataQuery.statusBelowGood(metric: m.displayName, latest: latestStr)
            } else {
                answer = Copy.Analysis.HealthDataQuery.statusOnBaseline(metric: m.displayName, latest: latestStr)
            }
        } else {
            answer = Copy.Analysis.HealthDataQuery.statusLearning(metric: m.displayName, latest: m.formatWithUnit(latest), avg: m.formatWithUnit(avg))
        }

        return QueryResult(
            answer: answer,
            dataPoints: [
                .init(label: "Current", value: latest, unit: m.unit),
                .init(label: "7-day avg", value: avg, unit: m.unit),
            ],
            confidence: 0.85,
            relatedQuestions: [
                Copy.Analysis.HealthDataQuery.qHowTrending(m.displayName),
                Copy.Analysis.HealthDataQuery.relatedAffects(m.displayName),
                Copy.Analysis.HealthDataQuery.relatedPredict(m.displayName),
            ]
        )
    }

    // MARK: - Answer Generators (New. ML Pipeline)

    private func answerHealthState(ctx: QueryContext) -> QueryResult {
        guard let state = ctx.currentHealthState else {
            // Graceful fallback: summarize whatever time series data we have
            let activeMetrics = ctx.timeSeries.filter { !$0.value.samples.isEmpty }
            let metricCount = activeMetrics.count
            if metricCount == 0 {
                return QueryResult(
                    answer: Copy.Analysis.HealthDataQuery.bodyNoData,
                    dataPoints: [],
                    confidence: 0.3,
                    relatedQuestions: [Copy.Analysis.HealthDataQuery.rqWhatDataDoIHave]
                )
            }
            // Build a basic summary from available baselines and latest values
            var highlights: [String] = []
            var dataPoints: [QueryResult.DataPoint] = []
            let keyMetrics: [HealthMetric] = [.restingHeartRate, .heartRateVariability, .sleepDuration, .steps, .activeCalories]
            for metric in keyMetrics {
                guard let series = ctx.timeSeries[metric], let latest = series.samples.last else { continue }
                let label = metric.displayName
                if let baseline = ctx.baselines[metric] {
                    let dev = deviation(of: latest.value, from: baseline)
                    let valueStr = metric.formatWithUnit(latest.value)
                    if dev > 1 {
                        highlights.append(Copy.Analysis.HealthDataQuery.highlightHigh(label: label, value: valueStr))
                    } else if dev < -1 {
                        highlights.append(Copy.Analysis.HealthDataQuery.highlightLow(label: label, value: valueStr))
                    } else {
                        highlights.append(Copy.Analysis.HealthDataQuery.highlightNormal(label: label, value: valueStr))
                    }
                } else {
                    highlights.append(Copy.Analysis.HealthDataQuery.highlightDefault(label: label, value: metric.formatWithUnit(latest.value)))
                }
                dataPoints.append(.init(label: label, value: latest.value, unit: metric.unit))
                if dataPoints.count >= 4 { break }
            }
            let summary = highlights.isEmpty
                ? Copy.Analysis.HealthDataQuery.metricsTrackingNormal(count: metricCount)
                : highlights.joined(separator: ". ") + "."
            let answer = Copy.Analysis.HealthDataQuery.bodySnapshot(summary: summary)
            return QueryResult(
                answer: answer,
                dataPoints: dataPoints,
                confidence: 0.5,
                relatedQuestions: [Copy.Analysis.HealthDataQuery.rqAmIAtRiskForAnything, Copy.Analysis.HealthDataQuery.rqHowIsMyHRVTrending, Copy.Analysis.HealthDataQuery.rqHowIsMySleepTrending]
            )
        }

        let topTraits = state.characteristics.prefix(4)
        let traitDescriptions = topTraits.map { trait -> String in
            switch trait.level {
            case .high: return "\(trait.metric.displayName) is elevated"
            case .low: return "\(trait.metric.displayName) is on the low side"
            case .normal: return "\(trait.metric.displayName) is right where it should be"
            }
        }

        let durationNote = state.daysInState > 1
            ? " You've been in this state for \(state.daysInState) days."
            : ""

        let traitList = traitDescriptions.joined(separator: ", ")
        let answer = Copy.Analysis.HealthDataQuery.bodyStateAnswer(conclusion: healthStateConclusion(state: state), label: state.label, traits: traitList, durationNote: durationNote)

        let dataPoints: [QueryResult.DataPoint] = topTraits.map {
            .init(label: $0.metric.displayName, value: $0.zScore, unit: "z")
        }

        return QueryResult(
            answer: answer,
            dataPoints: dataPoints,
            confidence: 0.8,
            relatedQuestions: [
                "Am I at risk for anything?",
                "What should I do today?",
                "How is my HRV trending?",
            ]
        )
    }

    private func answerRisk(ctx: QueryContext) -> QueryResult {
        guard let report = ctx.healthSignalReport else {
            if let risk = ctx.tomorrowRiskPrediction {
                let pct = Int(risk.probability * 100)
                let answer = pct > 50
                    ? Copy.Analysis.HealthDataQuery.riskRoughDay(percent: pct, summary: riskFactorSummary(risk.topFactors))
                    : Copy.Analysis.HealthDataQuery.riskLowDay(percent: pct)
                return QueryResult(
                    answer: answer,
                    dataPoints: [.init(label: "Tomorrow risk", value: risk.probability * 100, unit: "%")],
                    confidence: risk.confidence,
                    relatedQuestions: [Copy.Analysis.HealthDataQuery.rqWhatStateIsMyBody, Copy.Analysis.HealthDataQuery.rqWhatShouldIDoToday]
                )
            }
            // Graceful fallback: check baselines for any outlier metrics
            var warnings: [(metric: HealthMetric, deviation: Double, value: Double)] = []
            for (metric, series) in ctx.timeSeries {
                guard let latest = series.samples.last, let baseline = ctx.baselines[metric] else { continue }
                let dev = deviation(of: latest.value, from: baseline)
                let isBad = (dev < -1.5 && metric.higherIsBetter) || (dev > 1.5 && !metric.higherIsBetter)
                if isBad { warnings.append((metric, abs(dev), latest.value)) }
            }
            if !warnings.isEmpty {
                warnings.sort { $0.deviation > $1.deviation }
                let top = warnings[0]
                let answer = Copy.Analysis.HealthDataQuery.riskOutsideRange(metric: top.metric.displayName, value: top.metric.formatWithUnit(top.value))
                return QueryResult(
                    answer: answer,
                    dataPoints: warnings.prefix(3).map {
                        .init(label: $0.metric.displayName, value: $0.value, unit: $0.metric.unit)
                    },
                    confidence: 0.5,
                    relatedQuestions: [Copy.Analysis.HealthDataQuery.qHowTrending(top.metric.displayName), Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall]
                )
            }
            return QueryResult(
                answer: Copy.Analysis.HealthDataQuery.riskNothingConcerning,
                dataPoints: [],
                confidence: 0.5,
                relatedQuestions: [Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall, Copy.Analysis.HealthDataQuery.rqAnythingUnusualInData]
            )
        }

        // Collect all signals and sort by severity
        let signals: [(name: String, risk: PredictiveHealthSignals.RiskLevel, score: Double, explanation: String, recommendation: String)] = [
            (report.fatigueScore.signalName, report.fatigueScore.riskLevel, report.fatigueScore.score, report.fatigueScore.explanation, report.fatigueScore.recommendation),
            (report.burnoutRisk.signalName, report.burnoutRisk.riskLevel, report.burnoutRisk.score, report.burnoutRisk.explanation, report.burnoutRisk.recommendation),
            (report.overtrainingRisk.signalName, report.overtrainingRisk.riskLevel, report.overtrainingRisk.score, report.overtrainingRisk.explanation, report.overtrainingRisk.recommendation),
            (report.insomniaRisk.signalName, report.insomniaRisk.riskLevel, report.insomniaRisk.score, report.insomniaRisk.explanation, report.insomniaRisk.recommendation),
            (report.immuneRisk.signalName, report.immuneRisk.riskLevel, report.immuneRisk.score, report.immuneRisk.explanation, report.immuneRisk.recommendation),
            (report.inactivityAlert.signalName, report.inactivityAlert.riskLevel, report.inactivityAlert.score, report.inactivityAlert.explanation, report.inactivityAlert.recommendation),
        ]

        let elevated = signals.filter { $0.risk >= .moderate }.sorted { $0.score > $1.score }

        if elevated.isEmpty {
            var answer = Copy.Analysis.HealthDataQuery.riskAllHealthy
            if let risk = ctx.tomorrowRiskPrediction, risk.probability < 0.3 {
                answer += " Tomorrow is looking good too."
            }
            return QueryResult(
                answer: answer,
                dataPoints: [],
                confidence: 0.85,
                relatedQuestions: [Copy.Analysis.HealthDataQuery.rqWhatStateIsMyBody, Copy.Analysis.HealthDataQuery.rqHowIsMyHRVTrending]
            )
        }

        let top = elevated[0]
        let level = top.risk == .critical ? Copy.Analysis.HealthDataQuery.riskCritical
            : top.risk == .high ? Copy.Analysis.HealthDataQuery.riskHigh
            : Copy.Analysis.HealthDataQuery.riskWatching
        var answer = Copy.Analysis.HealthDataQuery.riskAnswer(recommendation: top.recommendation, name: top.name.lowercased(), level: level, explanation: top.explanation)
        if elevated.count > 1 {
            let others = elevated.dropFirst().prefix(2).map { $0.name.lowercased() }.joined(separator: " and ")
            answer += " Also keep an eye on your \(others)."
        }

        return QueryResult(
            answer: answer,
            dataPoints: elevated.prefix(3).map {
                .init(label: $0.name, value: $0.score * 100, unit: "%")
            },
            confidence: 0.85,
            relatedQuestions: [
                "What should I do today?",
                "What state is my body in?",
                "How is my sleep trending?",
            ]
        )
    }

    private func answerOptimization(ctx: QueryContext) -> QueryResult {
        // Try ideal day first
        if let ideal = ctx.idealDay, !ideal.targets.isEmpty {
            let topTargets = ideal.targets.prefix(4)
            let targetLines = topTargets.map { target -> String in
                "\(target.metric.displayName): aim for \(target.metric.formatWithUnit(target.targetValue))"
            }
            let targetList = targetLines.joined(separator: "; ")

            var answer: String

            // Add gap info from optimal profile. Lead with what to focus on.
            if let profile = ctx.optimalProfile {
                let unmet = profile.conditions.filter { !$0.isCurrentlyMet }.prefix(2)
                if !unmet.isEmpty {
                    let gaps = unmet.map { $0.metric.displayName }.joined(separator: " and ")
                    answer = Copy.Analysis.HealthDataQuery.greatDayFocusOn(gaps)
                } else {
                    answer = Copy.Analysis.HealthDataQuery.greatDayCloseToIdeal
                }
            } else {
                answer = ""
            }
            answer += Copy.Analysis.HealthDataQuery.optimizationAimFor(targetList: targetList, score: Int(ideal.predictedScore))

            return QueryResult(
                answer: answer,
                dataPoints: topTargets.map {
                    .init(label: $0.metric.displayName, value: $0.targetValue, unit: $0.metric.unit)
                },
                confidence: ideal.confidence,
                relatedQuestions: [
                    "What state is my body in?",
                    "Why is my score what it is?",
                    "Am I at risk for anything?",
                ]
            )
        }

        // Fallback to sensitivities
        if !ctx.scoreSensitivities.isEmpty {
            let top = ctx.scoreSensitivities.sorted { abs($0.slope) > abs($1.slope) }.prefix(3)
            let levers = top.map { "\($0.metric.displayName) (\($0.description))" }.joined(separator: "; ")

            return QueryResult(
                answer: Copy.Analysis.HealthDataQuery.improveBiggestImpact(levers),
                dataPoints: top.map { .init(label: $0.metric.displayName, value: $0.slope, unit: "pts/σ") },
                confidence: 0.7,
                relatedQuestions: top.map { "How is my \($0.metric.displayName) trending?" }
            )
        }

        // Graceful fallback: use baselines and trends to suggest improvements
        var suggestions: [(metric: HealthMetric, tip: String, value: Double)] = []
        let improvableMetrics: [HealthMetric] = [.heartRateVariability, .sleepDuration, .steps, .exerciseMinutes, .activeCalories]
        for metric in improvableMetrics {
            guard let series = ctx.timeSeries[metric], let latest = series.samples.last,
                  let baseline = ctx.baselines[metric] else { continue }
            let dev = deviation(of: latest.value, from: baseline)
            let isBelowOptimal = (dev < -0.5 && metric.higherIsBetter) || (dev > 0.5 && !metric.higherIsBetter)
            if isBelowOptimal {
                suggestions.append((metric, "\(metric.displayName) is below your usual level", latest.value))
            }
        }
        if !suggestions.isEmpty {
            let topSuggestions = suggestions.prefix(3)
            let tips = topSuggestions.map { $0.tip }.joined(separator: "; ")
            return QueryResult(
                answer: Copy.Analysis.HealthDataQuery.improveMostRoom(tips),
                dataPoints: topSuggestions.map {
                    .init(label: $0.metric.displayName, value: $0.value, unit: $0.metric.unit)
                },
                confidence: 0.5,
                relatedQuestions: topSuggestions.map { "How is my \($0.metric.displayName) trending?" }
            )
        }
        return QueryResult(
            answer: Copy.Analysis.HealthDataQuery.improveAllOnBaseline,
            dataPoints: [],
            confidence: 0.5,
            relatedQuestions: [Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall, Copy.Analysis.HealthDataQuery.rqAmIAtRiskForAnything, Copy.Analysis.HealthDataQuery.rqDoIHaveAnyPatterns]
        )
    }

    private func answerPattern(metric: HealthMetric?, ctx: QueryContext) -> QueryResult {
        let patterns: [DiscoveredPattern]
        if let m = metric {
            patterns = ctx.discoveredPatterns.filter { $0.metric == m }
        } else {
            patterns = ctx.discoveredPatterns
        }

        let strong = patterns.filter { $0.strength > 0.3 }.sorted { $0.strength > $1.strength }

        guard let top = strong.first else {
            // Show weaker patterns if any exist, otherwise give helpful fallback
            let weaker = patterns.sorted { $0.strength > $1.strength }
            if let weakTop = weaker.first {
                let target = metric?.displayName ?? weakTop.metric.displayName
                var answer = Copy.Analysis.HealthDataQuery.patternEmerging(target: target)
                if let peakDay = weakTop.peakDayOfWeek {
                    answer += Copy.Analysis.HealthDataQuery.patternCycleHint(type: weakTop.patternType.rawValue, dayName: weekdayName(peakDay))
                }
                return QueryResult(
                    answer: answer,
                    dataPoints: weaker.prefix(2).map {
                        .init(label: $0.metric.displayName, value: $0.strength * 100, unit: "% strength")
                    },
                    confidence: 0.4,
                    relatedQuestions: [Copy.Analysis.HealthDataQuery.qHowTrending(weakTop.metric.displayName), Copy.Analysis.HealthDataQuery.rqAnythingUnusualInData]
                )
            }
            let target = metric?.displayName ?? Copy.Analysis.HealthDataQuery.yourMetrics
            return QueryResult(
                answer: Copy.Analysis.HealthDataQuery.patternNoneFound(target: target),
                dataPoints: [],
                confidence: 0.4,
                relatedQuestions: [Copy.Analysis.HealthDataQuery.rqHowIsMyHRVTrending, Copy.Analysis.HealthDataQuery.rqAnythingUnusualInData]
            )
        }

        var answer: String
        if let peakDay = top.peakDayOfWeek, let troughDay = top.troughDayOfWeek {
            answer = Copy.Analysis.HealthDataQuery.patternPeakTrough(peakDay: weekdayName(peakDay), metric: top.metric.displayName, troughDay: weekdayName(troughDay), type: top.patternType.rawValue)
        } else {
            answer = Copy.Analysis.HealthDataQuery.patternCycleAdvice(metric: top.metric.displayName, type: top.patternType.rawValue)
        }
        if let peakVal = top.peakMeanValue, let troughVal = top.troughMeanValue {
            answer += " The swing is about \(top.metric.formatWithUnit(peakVal - troughVal)) between highs and lows."
        }

        if strong.count > 1 {
            let others = strong.dropFirst().prefix(2).map { "\($0.metric.displayName) (\($0.patternType.rawValue))" }.joined(separator: ", ")
            answer += " I also see patterns in \(others)."
        }

        return QueryResult(
            answer: answer,
            dataPoints: strong.prefix(3).map {
                .init(label: $0.metric.displayName, value: $0.strength * 100, unit: "% strength")
            },
            confidence: Double(top.strength),
            relatedQuestions: [
                "How is my \(top.metric.displayName) trending?",
                "Does sleep affect my \(top.metric.displayName)?",
            ]
        )
    }

    private func answerCircadian(ctx: QueryContext) -> QueryResult {
        guard let profile = ctx.circadianProfile else {
            // Graceful fallback: use available sleep and activity data for basic timing insights
            var answer = Copy.Analysis.HealthDataQuery.buildingCircadianProfile
            var dataPoints: [QueryResult.DataPoint] = []

            if let sleepSeries = ctx.timeSeries[.sleepDuration] {
                let recent = recentSamples(from: sleepSeries, days: 7)
                if !recent.isEmpty {
                    let avgSleep = recent.valueMean
                    answer += Copy.Analysis.HealthDataQuery.circadianRecentSleep(avg: HealthMetric.sleepDuration.formatWithUnit(avgSleep))
                    dataPoints.append(.init(label: "Avg sleep", value: avgSleep / 3600, unit: "hrs"))
                }
            }
            if let stepsSeries = ctx.timeSeries[.steps] {
                let recent = recentSamples(from: stepsSeries, days: 7)
                if !recent.isEmpty {
                    let avgSteps = recent.valueMean
                    answer += Copy.Analysis.HealthDataQuery.circadianAvgSteps(steps: Int(avgSteps))
                    dataPoints.append(.init(label: "Avg steps", value: avgSteps, unit: "steps"))
                }
            }
            if answer == Copy.Analysis.HealthDataQuery.buildingCircadianProfile {
                answer += Copy.Analysis.HealthDataQuery.circadianGeneralAdvice
            }
            return QueryResult(
                answer: answer,
                dataPoints: dataPoints,
                confidence: 0.4,
                relatedQuestions: [Copy.Analysis.HealthDataQuery.rqHowIsMySleepTrending, Copy.Analysis.HealthDataQuery.rqDoIHaveAnyPatterns]
            )
        }

        let chronotype = profile.chronotype.rawValue
        var answer: String

        if !ctx.timingRecommendations.isEmpty {
            let recs = ctx.timingRecommendations.prefix(3)
            let timingLines = recs.map { rec -> String in
                "\(rec.activity.rawValue): \(formatHour(Double(rec.optimalWindowStart)))-\(formatHour(Double(rec.optimalWindowEnd)))"
            }
            answer = Copy.Analysis.HealthDataQuery.circadianBestWindows(lines: timingLines.joined(separator: "; "), chronotype: chronotype, peak: formatHour(profile.activityAcrophaseHour))
        } else {
            answer = Copy.Analysis.HealthDataQuery.circadianChronotype(chronotype: chronotype, peak: formatHour(profile.activityAcrophaseHour))
        }

        if let hrvPeak = profile.hrvAcrophaseHour {
            answer += Copy.Analysis.HealthDataQuery.circadianRecoveryPeak(hour: formatHour(hrvPeak))
        }

        return QueryResult(
            answer: answer,
            dataPoints: [
                .init(label: "Activity peak", value: profile.activityAcrophaseHour, unit: "hr"),
                .init(label: "HR nadir", value: profile.hrNadirHour, unit: "hr"),
            ],
            confidence: profile.confidence,
            relatedQuestions: [
                "Do I have any weekly patterns?",
                "How is my sleep trending?",
                "What should I do today?",
            ]
        )
    }

    private func answerWhyScore(ctx: QueryContext) -> QueryResult {
        guard let score = ctx.overallScore else {
            return QueryResult(
                answer: Copy.Home.AskYourData.noScoreYet,
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: [
                    Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall,
                    Copy.Analysis.HealthDataQuery.rqAmIAtRiskForAnything
                ]
            )
        }
        let sentiment: Sentiment = score > 75 ? .positive : score >= 50 ? .neutral : .negative

        // Use score sensitivities to explain
        if !ctx.scoreSensitivities.isEmpty {
            let sorted = ctx.scoreSensitivities.sorted { abs($0.slope) > abs($1.slope) }
            let topDrivers = sorted.prefix(3)

            // Check which drivers are currently dragging or boosting
            var dragging: [String] = []
            var boosting: [String] = []

            for driver in topDrivers {
                if let baseline = ctx.baselines[driver.metric],
                   let series = ctx.timeSeries[driver.metric],
                   let latest = series.samples.last {
                    let dev = deviation(of: latest.value, from: baseline)
                    let isBad = (dev < -0.5 && driver.metric.higherIsBetter) || (dev > 0.5 && !driver.metric.higherIsBetter)
                    if isBad {
                        dragging.append(driver.metric.displayName)
                    } else if (dev > 0.5 && driver.metric.higherIsBetter) || (dev < -0.5 && !driver.metric.higherIsBetter) {
                        boosting.append(driver.metric.displayName)
                    }
                }
            }

            var answer: String
            if !dragging.isEmpty {
                answer = "Work on improving your \(dragging.joined(separator: " and ")). That's what's holding your score back the most. "
            } else if !boosting.isEmpty {
                answer = "Keep up what you're doing with your \(boosting.joined(separator: " and ")). That's carrying your score right now. "
            } else {
                answer = "Stay consistent. All your key metrics are near baseline, so small improvements anywhere will help. "
            }
            answer += "Your score is \(score). \(conclusion(sentiment))"

            return QueryResult(
                answer: answer,
                dataPoints: topDrivers.map {
                    .init(label: $0.metric.displayName, value: $0.slope, unit: "pts/σ")
                },
                confidence: 0.8,
                relatedQuestions: [
                    "How do I improve my score?",
                    dragging.first.map { "How is my \($0) trending?" } ?? "Am I at risk for anything?",
                    "What state is my body in?",
                ]
            )
        }

        // Fallback: use available baselines to provide some context
        var noteworthy: [(metric: HealthMetric, direction: String, value: Double)] = []
        let keyMetrics: [HealthMetric] = [.heartRateVariability, .restingHeartRate, .sleepDuration, .steps, .activeCalories, .exerciseMinutes]
        for metric in keyMetrics {
            guard let series = ctx.timeSeries[metric], let latest = series.samples.last,
                  let baseline = ctx.baselines[metric] else { continue }
            let dev = deviation(of: latest.value, from: baseline)
            if abs(dev) > 0.8 {
                let isBad = (dev < 0 && metric.higherIsBetter) || (dev > 0 && !metric.higherIsBetter)
                noteworthy.append((metric, isBad ? "below optimal" : "looking good", latest.value))
            }
        }
        var answer = "Your score is \(score). \(conclusion(sentiment))"
        if !noteworthy.isEmpty {
            let details = noteworthy.prefix(3).map { "\($0.metric.displayName) is \($0.direction)" }.joined(separator: ", ")
            answer += " Looking at your key metrics: \(details)."
        }
        return QueryResult(
            answer: answer,
            dataPoints: noteworthy.prefix(3).map {
                .init(label: $0.metric.displayName, value: $0.value, unit: $0.metric.unit)
            },
            confidence: 0.5,
            relatedQuestions: [Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall, Copy.Analysis.HealthDataQuery.rqAmIAtRiskForAnything]
        )
    }

    private func answerCausal(metric: HealthMetric, ctx: QueryContext) -> QueryResult {
        // Find Granger-causal relationships targeting this metric
        let causalRelations = ctx.correlations.filter {
            $0.grangerCausal && ($0.metricB == metric || $0.metricA == metric)
        }.sorted { abs($0.grangerEffectSize) > abs($1.grangerEffectSize) }

        if !causalRelations.isEmpty {
            let topCauses = causalRelations.prefix(3)
            let topDriver = topCauses.first.map { $0.metricA == metric ? $0.metricB : $0.metricA }
            let topDirection = topCauses.first.map { $0.pearsonR > 0 ? "improving" : "lowering" } ?? "changing"
            var answer = topDriver.map { "Focus on your \($0.displayName). It's the biggest lever for \(topDirection) your \(metric.displayName). " } ?? ""
            for cause in topCauses {
                let driver = cause.metricA == metric ? cause.metricB : cause.metricA
                let lagText = cause.grangerOptimalLag == 1 ? "the next day" : "\(cause.grangerOptimalLag) days later"
                let direction = cause.pearsonR > 0 ? "higher" : "lower"
                answer += "When your \(driver.displayName) goes up, your \(metric.displayName) tends to go \(direction) \(lagText). "
            }

            // Check temporal sequences for richer chains
            let relevantSequences = ctx.temporalSequences.filter {
                $0.steps.contains { $0.metric == metric }
            }.prefix(1)

            if let seq = relevantSequences.first {
                answer += " \(seq.description)"
            }

            return QueryResult(
                answer: answer,
                dataPoints: topCauses.map {
                    let driver = $0.metricA == metric ? $0.metricB : $0.metricA
                    return .init(label: driver.displayName, value: $0.grangerEffectSize, unit: "effect")
                },
                confidence: 0.8,
                relatedQuestions: [
                    "How is my \(metric.displayName) trending?",
                    topCauses.first.map {
                        let d = $0.metricA == metric ? $0.metricB : $0.metricA
                        return "How is my \(d.displayName) doing?"
                    } ?? "Do I have any patterns?",
                ]
            )
        }

        // Fallback: use correlations (non-causal)
        let correlated = ctx.correlations.filter {
            ($0.metricA == metric || $0.metricB == metric) && abs($0.pearsonR) > 0.3
        }.sorted { abs($0.pearsonR) > abs($1.pearsonR) }

        if let top = correlated.first {
            let other = top.metricA == metric ? top.metricB : top.metricA
            let answer = "I haven't established clear causal links for your \(metric.displayName) yet, but it's correlated with your \(other.displayName) (r=\(String(format: "%.2f", top.pearsonR))). As I gather more data, I'll be able to tell you what actually drives the changes. not just what moves alongside them."
            return QueryResult(
                answer: answer,
                dataPoints: [.init(label: other.displayName, value: top.pearsonR, unit: "r")],
                confidence: 0.6,
                relatedQuestions: [
                    "Does \(other.displayName) affect \(metric.displayName)?",
                    "How is my \(metric.displayName) trending?",
                ]
            )
        }

        // Graceful fallback: provide the data we do have
        if let series = ctx.timeSeries[metric], !series.samples.isEmpty {
            let recent = recentSamples(from: series, days: 7)
            let avg: Double? = recent.isEmpty ? nil : recent.valueMean
            var answer = "I haven't mapped out the causal drivers for your \(metric.displayName) yet."
            if let avg = avg {
                answer += " Your recent average is \(metric.formatWithUnit(avg)). As I gather more history, I'll identify what specifically makes it go up or down."
            }
            return QueryResult(
                answer: answer,
                dataPoints: avg.map { [QueryResult.DataPoint(label: "Recent avg", value: $0, unit: metric.unit)] } ?? [],
                confidence: 0.4,
                relatedQuestions: [Copy.Analysis.HealthDataQuery.qHowTrending(metric.displayName), Copy.Analysis.HealthDataQuery.rqAnythingUnusualInMetric(metric.displayName)]
            )
        }
        return QueryResult(
            answer: "I don't have \(metric.displayName) data yet. Once it starts coming in, I'll be able to analyze what drives it.",
            dataPoints: [],
            confidence: 0.3,
            relatedQuestions: [Copy.Analysis.HealthDataQuery.rqWhatDataDoIHave]
        )
    }

    // MARK: - General (Enhanced)

    // MARK: - Conversational Handling

    private static let greetings: Set<String> = [
        "hi", "hey", "hello", "hola", "yo", "sup", "hii", "hiii",
        "good morning", "good afternoon", "good evening", "gm",
        "what's up", "whats up", "howdy",
    ]

    private static let thanks: Set<String> = [
        "thanks", "thank you", "thx", "ty", "thank u", "cheers", "appreciated",
    ]

    private static let farewells: Set<String> = [
        "bye", "goodbye", "see you", "later", "cya", "take care",
    ]

    /// A pleasantry is the whole message, or the whole message plus punctuation.
    /// Matching a bare prefix sent "typical sleep for me?" to the thanks reply
    /// ("ty") and "later today should i train?" to the farewell reply ("later"),
    /// so a real health question got a canned goodbye.
    private static func isPleasantry(_ words: String, in set: Set<String>) -> Bool {
        set.contains(words) || set.contains { words.hasPrefix($0) && words.count < $0.count + 3 }
    }

    private func handleConversational(_ question: String, ctx: QueryContext) -> QueryResult? {
        let words = question.components(separatedBy: .whitespaces).joined(separator: " ")

        // Greetings
        if Self.isPleasantry(words, in: Self.greetings) {
            let scorePhrase: String
            if let score = ctx.overallScore {
                switch score {
                case 85...100: scorePhrase = "You're doing great. your health score is \(score)."
                case 70..<85: scorePhrase = "Your health score is \(score), looking solid."
                case 50..<70: scorePhrase = "Your health score is \(score). some room to improve."
                default: scorePhrase = "Your health score is \(score). let's work on that."
                }
            } else {
                // Nothing scored means no score sentence at all. The tracking
                // note below carries what the assistant can honestly say.
                scorePhrase = ""
            }

            let metricCount = ctx.timeSeries.filter { !$0.value.samples.isEmpty }.count
            let trackingNote = metricCount > 0
                ? "I'm keeping an eye on \(metricCount) metrics for you."
                : "Connect a device so I can start tracking your health."

            let opening = ["Hey!", scorePhrase, trackingNote]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            return QueryResult(
                answer: "\(opening) Ask me anything. like \"How's my sleep?\" or \"Am I at risk for anything?\"",
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: [
                    Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall,
                    Copy.Analysis.HealthDataQuery.rqWhatShouldIFocusOn,
                    Copy.Analysis.HealthDataQuery.rqAmIAtRiskForAnything,
                ]
            )
        }

        // Thanks
        if Self.isPleasantry(words, in: Self.thanks) {
            return QueryResult(
                answer: "Happy to help! I'm here whenever you want to check in on your health.",
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: [
                    Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall,
                    Copy.Analysis.HealthDataQuery.rqAnythingUnusualInData,
                    Copy.Analysis.HealthDataQuery.rqDoIHaveAnyPatterns,
                ]
            )
        }

        // Farewells
        if Self.isPleasantry(words, in: Self.farewells) {
            return QueryResult(
                answer: "Take care! I'll keep watching your data in the background.",
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: []
            )
        }

        return nil
    }

    /// The engine did not recognise the question.
    ///
    /// This used to answer with whichever compound insight, trend mover or
    /// correlation ranked highest, which is how an unrelated "interesting
    /// discovery" ended up presented as the answer to a question the parser
    /// never understood. Saying so plainly and offering questions that do
    /// resolve is the honest response.
    private func answerNotUnderstood(ctx: QueryContext) -> QueryResult {
        let metricCount = ctx.timeSeries.filter { !$0.value.samples.isEmpty }.count
        guard metricCount > 0 else {
            return QueryResult(
                answer: Copy.Analysis.HealthDataQuery.notUnderstoodNoData,
                dataPoints: [],
                confidence: 0.0,
                relatedQuestions: []
            )
        }

        return QueryResult(
            answer: Copy.Analysis.HealthDataQuery.notUnderstood,
            dataPoints: [],
            confidence: 0.0,
            relatedQuestions: [
                Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall,
                Copy.Analysis.HealthDataQuery.rqAmIAtRiskForAnything,
                Copy.Analysis.HealthDataQuery.rqWhatShouldIDoToday,
            ]
        )
    }

    // MARK: - Response Composition

    private enum Sentiment { case positive, neutral, negative }

    private func conclusion(_ sentiment: Sentiment) -> String {
        switch sentiment {
        case .positive: return "Keep doing what you're doing."
        case .neutral: return "Keep an eye on this over the next few days."
        case .negative: return "Small adjustments now can make a real difference."
        }
    }

    private func trendActionAdvice(metric: HealthMetric, pctChange: Double, sentiment: Sentiment) -> String {
        if abs(pctChange) < 2 {
            return "Your routine is working. Keep it consistent."
        }
        switch (metric, sentiment) {
        case (.heartRateVariability, .negative):
            return "Try getting to bed 30 minutes earlier tonight. Your recovery needs a boost."
        case (.heartRateVariability, .positive):
            return "Whatever you've been doing for recovery, keep it up. It's paying off."
        case (.restingHeartRate, .negative):
            return "Take it easy today and focus on hydration. Your heart rate is trending the wrong way."
        case (.restingHeartRate, .positive):
            return "Great progress. Your heart is getting more efficient."
        case (.sleepDuration, .negative), (.sleepDeep, .negative), (.sleepREM, .negative):
            return "Prioritize your wind-down routine tonight. Dim lights and put screens away an hour before bed."
        case (.sleepDuration, .positive), (.sleepDeep, .positive), (.sleepREM, .positive):
            return "Your sleep is heading in the right direction. Stick with your current bedtime routine."
        case (.steps, .negative), (.activeCalories, .negative), (.exerciseMinutes, .negative):
            return "Try adding a short walk or movement break today to get things back on track."
        case (.steps, .positive), (.activeCalories, .positive), (.exerciseMinutes, .positive):
            return "You're moving more. Keep building on that momentum."
        case (.weight, .negative):
            return "Small daily choices add up. Focus on whole foods and staying active."
        case (.weight, .positive):
            return "You're making progress. Stay consistent with what's working."
        case (_, .positive):
            return "Keep doing what you're doing. Your \(metric.displayName) is heading in a great direction."
        case (_, .negative):
            return "Pay extra attention to your \(metric.displayName) this week and see if a routine change helps."
        case (_, .neutral):
            return "Steady and consistent. Your \(metric.displayName) is holding its ground."
        }
    }

    private func forecastActionAdvice(metric: HealthMetric, predicted: Double, context: QueryContext) -> String {
        guard let baseline = context.baselines[metric] else {
            return "Here's what to expect."
        }
        let dev = deviation(of: predicted, from: baseline)
        let isBad = (dev < -0.5 && metric.higherIsBetter) || (dev > 0.5 && !metric.higherIsBetter)
        if isBad {
            switch metric {
            case .heartRateVariability:
                return "Your recovery might be lower than usual. Plan for lighter activity and an earlier bedtime."
            case .sleepDuration, .sleepDeep, .sleepREM:
                return "Your sleep may dip. Try to protect your bedtime tonight."
            case .restingHeartRate:
                return "Your heart rate may run high. Take it easy and stay hydrated."
            default:
                return "Your \(metric.displayName) may be below its best. Plan accordingly."
            }
        } else {
            return "Looking good ahead. Your \(metric.displayName) should be in a solid range."
        }
    }

    private func anomalyActionAdvice(metric: HealthMetric, isHigh: Bool) -> String {
        switch (metric, isHigh) {
        case (.heartRate, true), (.restingHeartRate, true):
            return "Take it easy and hydrate well today. Something is pushing your heart rate up."
        case (.heartRateVariability, false):
            return "Prioritize rest and recovery today. Your body is showing signs of extra stress."
        case (.sleepDuration, false), (.sleepDeep, false), (.sleepREM, false):
            return "Make tonight's sleep a priority. Get to bed early and keep your room cool and dark."
        case (.steps, false), (.activeCalories, false), (.exerciseMinutes, false):
            return "Try to get some movement in today, even a short walk would help."
        case (.bloodOxygen, false):
            return "Keep an eye on this and get some fresh air. Your blood oxygen is lower than usual."
        case (.weight, true):
            return "This could be water retention or a temporary spike. Stay consistent with your routine."
        case (.respiratoryRate, true):
            return "Your breathing rate is elevated. Take some deep breaths and see if you can ease any tension."
        default:
            if isHigh && !metric.higherIsBetter {
                return "Keep an eye on this and consider what might have changed in your routine."
            } else if !isHigh && metric.higherIsBetter {
                return "Focus on recovery today. Your body could use some extra care."
            } else {
                return "This is outside your norm. Pay attention to how you're feeling."
            }
        }
    }

    private func healthStateConclusion(state: HealthState) -> String {
        let label = state.label.lowercased()
        if label.contains("recovery") || label.contains("resting") {
            return "Take it easy today. Your body is in repair mode, so stick to lighter activity and rest up."
        }
        if label.contains("peak") || label.contains("performance") || label.contains("active") {
            return "Go for it today. You're ready for a strong workout or big effort."
        }
        if label.contains("stress") || label.contains("fatigue") {
            return "Prioritize sleep and take it easy. Your body is under extra stress right now."
        }
        return "Listen to how you're feeling today and adjust your plans accordingly."
    }

    private func riskFactorSummary(_ factors: [PredictionFactor]) -> String {
        let riskFactors = factors.filter { $0.isRiskFactor }.prefix(2)
        if riskFactors.isEmpty { return "" }
        let names = riskFactors.map { $0.metric.displayName }.joined(separator: " and ")
        return "The main drivers are your \(names)."
    }

    // MARK: - Helpers

    /// How many standard deviations `value` sits from its baseline mean.
    ///
    /// The baseline's own SD is the whole scale, with no floor added on top. Any
    /// floor silences the metrics whose natural SD is under one unit: a fixed 1
    /// buried body temperature (°C), SpO2, sleep (hrs) and walking speed, and a
    /// floor set as a fraction of the mean buried them harder still, because 5% of
    /// a 36.8 °C mean is a 1.8 °C floor that no real fever clears.
    private func deviation(of value: Double, from baseline: UserBaseline) -> Double {
        // A zero SD means every baseline day held the same value, so there is no
        // scale to measure against: report no deviation rather than dividing by
        // zero and tripping every threshold below with an infinity.
        guard baseline.standardDeviation > 0 else { return 0 }
        return (value - baseline.mean) / baseline.standardDeviation
    }

    /// Samples inside a window of `days` whole calendar days, ending `offset` days
    /// before today.
    ///
    /// Anchored to midnight rather than to the current instant, so "today" is a
    /// calendar day instead of a rolling 24 hours that pulls in last night and
    /// shifts as the clock advances. `Date.cal` carries the device time zone.
    private func recentSamples(from series: MetricTimeSeries, days: Int, offset: Int = 0) -> [MetricSample] {
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())
        guard let endExclusive = calendar.date(byAdding: .day, value: 1 - offset, to: today),
              let start = calendar.date(byAdding: .day, value: -days, to: endExclusive) else {
            return []
        }
        return series.samples.filter { $0.date >= start && $0.date < endExclusive }
            .sorted { $0.date < $1.date }
    }


    private func noDataResult(for metric: HealthMetric) -> QueryResult {
        QueryResult(
            answer: "I don't have \(metric.displayName) data available right now. This metric may need a compatible device (like Apple Watch) or manual entry in the Health app. Try asking about a different metric.",
            dataPoints: [],
            confidence: 0.3,
            relatedQuestions: [Copy.Analysis.HealthDataQuery.rqHowAmIDoingOverall, Copy.Analysis.HealthDataQuery.rqWhatShouldIFocusOn]
        )
    }

    private func weekdayName(_ day: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return (day >= 1 && day <= 7) ? names[day - 1] : "day \(day)"
    }

    private func formatHour(_ hour: Double) -> String {
        let h = Int(hour) % 24
        let m = Int((hour - Double(Int(hour))) * 60)
        let period = h >= 12 ? "PM" : "AM"
        let displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return m == 0 ? "\(displayH) \(period)" : "\(displayH):\(String(format: "%02d", m)) \(period)"
    }
}
