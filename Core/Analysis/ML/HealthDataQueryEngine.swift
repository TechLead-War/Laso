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
        let overallScore: Int
    }

    enum QueryIntent {
        case trend(metric: HealthMetric, period: QueryPeriod)
        case comparison(metric: HealthMetric, periodA: QueryPeriod, periodB: QueryPeriod)
        case correlation(metricA: HealthMetric, metricB: HealthMetric)
        case forecast(metric: HealthMetric, horizon: Int)
        case anomaly(metric: HealthMetric?)
        case bestWorst(metric: HealthMetric, seeking: BestWorst)
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

    enum MatchingMode {
        case full
        case keywordOnly
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

    private let nlAnalyzer = NLEmbeddingAnalyzer()
    private let semanticCacheLock = NSLock()
    private var semanticIntentCache: [String: IntentCategory] = [:]
    private var semanticMissCache = Set<String>()

    // MARK: - Metric Vocabulary

    private static let metricVocabulary: [String: HealthMetric] = [
        // Heart
        "heart rate": .heartRate, "hr": .heartRate, "pulse": .heartRate, "bpm": .heartRate,
        "resting heart rate": .restingHeartRate, "rhr": .restingHeartRate, "resting hr": .restingHeartRate, "resting pulse": .restingHeartRate,
        "hrv": .heartRateVariability, "heart rate variability": .heartRateVariability, "variability": .heartRateVariability,
        "heart rate recovery": .heartRateRecovery, "hr recovery": .heartRateRecovery,
        "afib": .atrialFibrillationBurden, "atrial fibrillation": .atrialFibrillationBurden,
        // Sleep
        "sleep": .sleepDuration, "sleep duration": .sleepDuration, "hours slept": .sleepDuration, "time asleep": .sleepDuration,
        "deep sleep": .sleepDeep, "rem": .sleepREM, "rem sleep": .sleepREM, "core sleep": .sleepCore,
        "breathing disturbances": .sleepBreathingDisturbances, "sleep apnea": .sleepBreathingDisturbances,
        // Activity
        "steps": .steps, "step count": .steps,
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

    // MARK: - Query Processing

    /// Primary entry point. uses full ML pipeline context.
    func query(question: String, context: QueryContext, matchingMode: MatchingMode = .full) -> QueryResult {
        let normalized = question.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle conversational inputs before parsing health intent
        if let conversational = handleConversational(normalized, ctx: context) {
            return conversational
        }

        let intent = parseIntent(normalized, matchingMode: matchingMode)

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
        case .bestWorst(let metric, let seeking):
            return answerBestWorst(metric: metric, seeking: seeking, ctx: context)
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
            return answerGeneral(ctx: context)
        }
    }

    // MARK: - Intent Parsing

    private func parseIntent(_ question: String, matchingMode: MatchingMode) -> QueryIntent {
        let detectedMetrics = detectMetrics(in: question)
        let detectedPeriods = detectPeriods(in: question)
        let primaryMetric = detectedMetrics.first

        // Try keyword matching first
        if let keywordResult = keywordIntent(question, metrics: detectedMetrics, periods: detectedPeriods) {
            return keywordResult
        }

        // Semantic matching fallback via NLEmbedding
        if matchingMode == .full, let category = semanticIntentMatch(question) {
            return resolveCategory(category, metrics: detectedMetrics, periods: detectedPeriods)
        }

        // Default: status if we found a metric, general otherwise
        if let metric = primaryMetric {
            return .status(metric: metric)
        }
        return .general
    }

    private func keywordIntent(_ question: String, metrics: [HealthMetric], periods: [QueryPeriod]) -> QueryIntent? {
        let primaryMetric = metrics.first
        let primaryPeriod = periods.first ?? .last7Days

        let healthStatePatterns = ["state", "body doing", "body status", "recovered", "health state"]
        let riskPatterns = ["risk", "warning", "worried", "danger", "concern", "red flag", "careful"]
        let optimizationPatterns = ["optimize", "improve", "ideal day", "best day", "tip", "should i do", "better score", "great day"]
        let patternPatterns = ["pattern", "cycle", "rhythm", "recurring", "weekly pattern", "routine"]
        let circadianPatterns = ["body clock", "chronotype", "best time", "when should", "optimal time", "when to"]
        let whyScorePatterns = ["why is my score", "score low", "score drop", "score breakdown", "explain my score", "affecting my score", "what's driving my score"]
        let causalPatterns = ["cause", "why does", "what drives", "root cause", "what leads to", "what makes my"]
        let correlationPatterns = ["affect", "impact", "correlat", "relat", "connect", "influence", "relationship", "linked"]
        let forecastPatterns = ["predict", "forecast", "will my", "expect", "next", "tomorrow", "future"]
        let trendPatterns = ["trend", "going", "changing", "improv", "declin", "getting", "heading", "direction"]
        let comparisonPatterns = ["compar", "versus", "vs", "better than", "worse than", "differ"]
        let anomalyPatterns = ["unusual", "abnormal", "anomal", "weird", "strange", "spike", "something off"]
        let bestPatterns = ["best", "highest", "most", "peak", "record", "personal best"]
        let worstPatterns = ["worst", "lowest", "least", "minimum"]

        // New intents first (higher priority for specific questions)
        if whyScorePatterns.contains(where: { question.contains($0) }) {
            return .whyScore
        }
        if healthStatePatterns.contains(where: { question.contains($0) }) {
            return .healthState
        }
        if riskPatterns.contains(where: { question.contains($0) }) {
            return .risk
        }
        if optimizationPatterns.contains(where: { question.contains($0) }) {
            return .optimization
        }
        if circadianPatterns.contains(where: { question.contains($0) }) {
            return .circadian
        }
        if patternPatterns.contains(where: { question.contains($0) }) {
            return .pattern(metric: primaryMetric)
        }

        // Correlation (needs two metrics)
        if metrics.count >= 2 && correlationPatterns.contains(where: { question.contains($0) }) {
            return .correlation(metricA: metrics[0], metricB: metrics[1])
        }

        // Causal (one metric + causal keyword)
        if causalPatterns.contains(where: { question.contains($0) }), let metric = primaryMetric {
            return .causal(metric: metric)
        }

        // Forecast
        if forecastPatterns.contains(where: { question.contains($0) }), let metric = primaryMetric {
            let horizon = question.contains("week") ? 7 : question.contains("3 day") ? 3 : 1
            return .forecast(metric: metric, horizon: horizon)
        }

        // Best/Worst
        if let metric = primaryMetric {
            if bestPatterns.contains(where: { question.contains($0) }) {
                return .bestWorst(metric: metric, seeking: .best)
            }
            if worstPatterns.contains(where: { question.contains($0) }) {
                return .bestWorst(metric: metric, seeking: .worst)
            }
        }

        // Anomaly
        if anomalyPatterns.contains(where: { question.contains($0) }) {
            return .anomaly(metric: primaryMetric)
        }

        // Trend
        if trendPatterns.contains(where: { question.contains($0) }), let metric = primaryMetric {
            return .trend(metric: metric, period: primaryPeriod)
        }

        // Comparison
        if comparisonPatterns.contains(where: { question.contains($0) }), let metric = primaryMetric {
            let periodA = periods.count > 0 ? periods[0] : .thisWeek
            let periodB = periods.count > 1 ? periods[1] : .lastWeek
            return .comparison(metric: metric, periodA: periodA, periodB: periodB)
        }

        return nil // No keyword match. fall through to semantic
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

        var bestCategory: IntentCategory?
        var bestDistance = Double.infinity

        for (category, exemplar) in Self.semanticCorpus {
            let dist = nlAnalyzer.computeSemanticDistance(sentenceA: normalized, sentenceB: exemplar)
            if dist < bestDistance {
                bestDistance = dist
                bestCategory = category
            }
        }

        let match = bestDistance < 1.2 ? bestCategory : nil

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

    /// Convert a category (from semantic match) into a full QueryIntent with extracted params.
    private func resolveCategory(_ category: IntentCategory, metrics: [HealthMetric], periods: [QueryPeriod]) -> QueryIntent {
        let metric = metrics.first
        let period = periods.first ?? .last7Days

        switch category {
        case .trend:
            return metric.map { .trend(metric: $0, period: period) } ?? .general
        case .comparison:
            let a = periods.count > 0 ? periods[0] : .thisWeek
            let b = periods.count > 1 ? periods[1] : .lastWeek
            return metric.map { .comparison(metric: $0, periodA: a, periodB: b) } ?? .general
        case .correlation:
            return metrics.count >= 2 ? .correlation(metricA: metrics[0], metricB: metrics[1]) : .general
        case .forecast:
            return metric.map { .forecast(metric: $0, horizon: 1) } ?? .general
        case .anomaly:
            return .anomaly(metric: metric)
        case .bestWorst:
            return metric.map { .bestWorst(metric: $0, seeking: .best) } ?? .general
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

    private func detectMetrics(in text: String) -> [HealthMetric] {
        let lower = text.lowercased()
        var found: [(metric: HealthMetric, position: Int)] = []

        // Sort vocabulary by term length descending to match longer phrases first
        let sortedVocab = Self.metricVocabulary.sorted { $0.key.count > $1.key.count }

        for (term, metric) in sortedVocab {
            if let range = lower.range(of: term) {
                let position = lower.distance(from: lower.startIndex, to: range.lowerBound)
                if !found.contains(where: { $0.metric == metric }) {
                    found.append((metric: metric, position: position))
                }
            }
        }

        return found.sorted { $0.position < $1.position }.map(\.metric)
    }

    private func detectPeriods(in text: String) -> [QueryPeriod] {
        let lower = text.lowercased()
        var found: [(period: QueryPeriod, position: Int)] = []

        for (term, period) in Self.periodVocabulary {
            if let range = lower.range(of: term) {
                let position = lower.distance(from: lower.startIndex, to: range.lowerBound)
                found.append((period: period, position: position))
            }
        }

        return found.sorted { $0.position < $1.position }.map(\.period)
    }

    // MARK: - Answer Generators (Original, Improved)

    private func answerTrend(metric: HealthMetric, period: QueryPeriod, ctx: QueryContext) -> QueryResult {
        guard let series = ctx.timeSeries[metric] else {
            return noDataResult(for: metric)
        }

        let recent = recentSamples(from: series, days: period.days)
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

        let samplesA = recentSamples(from: series, days: periodA.days)
        let samplesB = recentSamples(from: series, days: periodB.days, offset: periodA.days)
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
        let metricsToCheck: [HealthMetric] = metric.map { [$0] } ?? Array(ctx.timeSeries.keys.prefix(15))

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

    private func answerBestWorst(metric: HealthMetric, seeking: QueryIntent.BestWorst, ctx: QueryContext) -> QueryResult {
        guard let series = ctx.timeSeries[metric], !series.samples.isEmpty else {
            return noDataResult(for: metric)
        }

        let sorted = series.samples.sorted { $0.value < $1.value }
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
        guard let m = metric, let series = ctx.timeSeries[m] else {
            return answerGeneral(ctx: ctx)
        }

        let recent = recentSamples(from: series, days: 7)
        guard !recent.isEmpty else { return noDataResult(for: m) }

        let avg = recent.valueMean
        let latest = recent.last?.value ?? avg

        var answer: String

        if let baseline = ctx.baselines[m] {
            let dev = deviation(of: avg, from: baseline)
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
        let score = ctx.overallScore
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

    private func handleConversational(_ question: String, ctx: QueryContext) -> QueryResult? {
        let words = question.components(separatedBy: .whitespaces).joined(separator: " ")

        // Greetings
        if Self.greetings.contains(words) || Self.greetings.contains(where: { words.hasPrefix($0) && words.count < $0.count + 3 }) {
            let scorePhrase: String
            switch ctx.overallScore {
            case 85...100: scorePhrase = "You're doing great. your health score is \(ctx.overallScore)."
            case 70..<85: scorePhrase = "Your health score is \(ctx.overallScore), looking solid."
            case 50..<70: scorePhrase = "Your health score is \(ctx.overallScore). some room to improve."
            default: scorePhrase = "Your health score is \(ctx.overallScore). let's work on that."
            }

            let metricCount = ctx.timeSeries.filter { !$0.value.samples.isEmpty }.count
            let trackingNote = metricCount > 0
                ? "I'm keeping an eye on \(metricCount) metrics for you."
                : "Connect a device so I can start tracking your health."

            return QueryResult(
                answer: "Hey! \(scorePhrase) \(trackingNote) Ask me anything. like \"How's my sleep?\" or \"Am I at risk for anything?\"",
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: [
                    "How am I doing overall?",
                    "What should I focus on?",
                    "Any health risks?",
                ]
            )
        }

        // Thanks
        if Self.thanks.contains(words) || Self.thanks.contains(where: { words.hasPrefix($0) }) {
            return QueryResult(
                answer: "Happy to help! I'm here whenever you want to check in on your health.",
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: [
                    "How am I doing overall?",
                    "What's my best metric?",
                    "Any patterns in my data?",
                ]
            )
        }

        // Farewells
        if Self.farewells.contains(words) || Self.farewells.contains(where: { words.hasPrefix($0) }) {
            return QueryResult(
                answer: "Take care! I'll keep watching your data in the background.",
                dataPoints: [],
                confidence: 1.0,
                relatedQuestions: []
            )
        }

        return nil
    }

    private func answerGeneral(ctx: QueryContext) -> QueryResult {
        // 1. Surface compound insights first (richest, most synthesized)
        if let topInsight = ctx.compoundInsights.sorted(by: { $0.surpriseScore > $1.surpriseScore }).first,
           topInsight.surpriseScore > 0.3 {
            return QueryResult(
                answer: topInsight.narrative + (topInsight.isActionable ? " " + topInsight.recommendation : ""),
                dataPoints: topInsight.involvedMetrics.prefix(3).compactMap { metric in
                    guard let series = ctx.timeSeries[metric],
                          let latest = series.samples.last else { return nil }
                    return QueryResult.DataPoint(label: metric.displayName, value: latest.value, unit: metric.unit)
                },
                confidence: topInsight.confidence,
                relatedQuestions: [
                    "Am I at risk for anything?",
                    "What state is my body in?",
                    topInsight.involvedMetrics.first.map { "How is my \($0.displayName) trending?" } ?? "What should I do today?",
                ]
            )
        }

        // 2. Health signal warnings
        if let report = ctx.healthSignalReport {
            let signals: [(String, PredictiveHealthSignals.RiskLevel, String)] = [
                (report.fatigueScore.signalName, report.fatigueScore.riskLevel, report.fatigueScore.explanation),
                (report.burnoutRisk.signalName, report.burnoutRisk.riskLevel, report.burnoutRisk.explanation),
                (report.overtrainingRisk.signalName, report.overtrainingRisk.riskLevel, report.overtrainingRisk.explanation),
                (report.insomniaRisk.signalName, report.insomniaRisk.riskLevel, report.insomniaRisk.explanation),
                (report.immuneRisk.signalName, report.immuneRisk.riskLevel, report.immuneRisk.explanation),
                (report.inactivityAlert.signalName, report.inactivityAlert.riskLevel, report.inactivityAlert.explanation),
            ]
            if let warning = signals.filter({ $0.1 >= .high }).first {
                return QueryResult(
                    answer: "Something worth your attention: \(warning.2)",
                    dataPoints: [],
                    confidence: 0.8,
                    relatedQuestions: [Copy.Analysis.HealthDataQuery.rqAmIAtRiskForAnything, Copy.Analysis.HealthDataQuery.rqWhatShouldIDoToday]
                )
            }
        }

        // 3. Biggest trend mover
        let sortedTrends = ctx.trends.sorted { abs($0.value.weekOverWeekChange) > abs($1.value.weekOverWeekChange) }
        if let top = sortedTrends.first, abs(top.value.weekOverWeekChange) > 5 {
            let dir = top.value.weekOverWeekChange > 0 ? "up" : "down"
            let answer = "Here's what stands out: your \(top.key.displayName) is moving \(dir) \(String(format: "%.0f%%", abs(top.value.weekOverWeekChange))) week over week. That's the biggest shift in your data right now."
            return QueryResult(
                answer: answer,
                dataPoints: [.init(label: "Change", value: top.value.weekOverWeekChange, unit: "%")],
                confidence: 0.7,
                relatedQuestions: [
                    "How is my \(top.key.displayName) trending?",
                    "What affects my \(top.key.displayName)?",
                ]
            )
        }

        // 4. Strongest correlation discovery
        if let topCorr = ctx.correlations.sorted(by: { abs($0.pearsonR) > abs($1.pearsonR) }).first,
           abs(topCorr.pearsonR) > 0.4 {
            let dir = topCorr.pearsonR > 0 ? "move together" : "move in opposite directions"
            return QueryResult(
                answer: "Interesting discovery: your \(topCorr.metricA.displayName) and \(topCorr.metricB.displayName) \(dir) (r=\(String(format: "%.2f", topCorr.pearsonR))). This is one of the strongest connections in your data.",
                dataPoints: [.init(label: "Correlation", value: topCorr.pearsonR, unit: "r")],
                confidence: 0.7,
                relatedQuestions: [
                    "Does \(topCorr.metricA.displayName) affect \(topCorr.metricB.displayName)?",
                    "How is my \(topCorr.metricA.displayName) doing?",
                ]
            )
        }

        // 5. True fallback
        let metricCount = ctx.timeSeries.filter { !$0.value.samples.isEmpty }.count
        if metricCount == 0 {
            return QueryResult(
                answer: "No health data yet. Once you connect your Apple Watch or allow Health access, I'll start learning about your body and can answer questions like \"How is my HRV trending?\" or \"Am I at risk for anything?\"",
                dataPoints: [],
                confidence: 0.3,
                relatedQuestions: []
            )
        }

        return QueryResult(
            answer: "I'm tracking \(metricCount) metrics and everything looks within normal ranges right now. Try asking about a specific metric, or ask me things like \"Am I at risk?\" or \"What should I do today?\" to dig deeper.",
            dataPoints: [],
            confidence: 0.6,
            relatedQuestions: [
                "Am I at risk for anything?",
                "What state is my body in?",
                "Do I have any patterns?",
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

    /// Smallest spread a baseline may claim, as a fraction of its own mean.
    /// Same 5% relative floor `ReadinessScorer.makeBaseline` applies.
    private static let minimumRelativeSD: Double = 0.05

    /// How many standard deviations `value` sits from its baseline mean.
    ///
    /// The floor is relative, not an absolute one unit: body temperature (°C),
    /// SpO2 (%), sleep (hrs) and walking speed (km/h) all have a natural SD well
    /// under 1, so a fixed floor of 1 made their deviation permanently smaller
    /// than every threshold here and those metrics could never be reported.
    private func deviation(of value: Double, from baseline: UserBaseline) -> Double {
        let spread = max(baseline.standardDeviation, abs(baseline.mean) * Self.minimumRelativeSD)
        // A zero mean with zero spread means every recorded day was zero; there is
        // no scale to measure a deviation against, so report none rather than a
        // divide-by-zero infinity that would trip every threshold below.
        guard spread > 0 else { return 0 }
        return (value - baseline.mean) / spread
    }

    private func recentSamples(from series: MetricTimeSeries, days: Int, offset: Int = 0) -> [MetricSample] {
        let calendar = Date.cal
        let endDate = calendar.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        return series.samples.filter { $0.date >= startDate && $0.date <= endDate }
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
