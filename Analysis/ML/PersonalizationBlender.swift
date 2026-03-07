import Foundation

// MARK: - Population Priors

/// Hardcoded statistical priors from population health research.
/// Serves as a base model when personal data is insufficient, enabling
/// meaningful predictions from day one without requiring CoreML or
/// pre-trained models.
enum PopulationPriors {

    // MARK: - Metric Priors

    /// Population-level baseline statistics for a health metric.
    struct MetricPrior {
        let metric: HealthMetric
        /// Population mean value
        let populationMean: Double
        /// Population standard deviation
        let populationStdDev: Double
        /// Lower bound of healthy range
        let healthyRangeLow: Double
        /// Upper bound of healthy range
        let healthyRangeHigh: Double
        /// Expected day-to-day coefficient of variation (stdDev / mean)
        let typicalDailyVariation: Double
    }

    /// Population-level priors for common HealthKit metrics.
    /// Sources: AHA, AASM, WHO Physical Activity Guidelines, Apple Health aggregates.
    static let priors: [HealthMetric: MetricPrior] = {
        let list: [MetricPrior] = [
            // Heart & Cardio
            MetricPrior(metric: .heartRateVariability,
                        populationMean: 45, populationStdDev: 15,
                        healthyRangeLow: 20, healthyRangeHigh: 100,
                        typicalDailyVariation: 0.15),
            MetricPrior(metric: .restingHeartRate,
                        populationMean: 68, populationStdDev: 8,
                        healthyRangeLow: 50, healthyRangeHigh: 85,
                        typicalDailyVariation: 0.05),
            MetricPrior(metric: .heartRate,
                        populationMean: 75, populationStdDev: 10,
                        healthyRangeLow: 55, healthyRangeHigh: 100,
                        typicalDailyVariation: 0.08),
            MetricPrior(metric: .walkingHeartRateAverage,
                        populationMean: 100, populationStdDev: 12,
                        healthyRangeLow: 80, healthyRangeHigh: 130,
                        typicalDailyVariation: 0.06),
            MetricPrior(metric: .heartRateRecovery,
                        populationMean: 22, populationStdDev: 8,
                        healthyRangeLow: 12, healthyRangeHigh: 45,
                        typicalDailyVariation: 0.15),

            // Sleep
            MetricPrior(metric: .sleepDuration,
                        populationMean: 7.0, populationStdDev: 1.0,
                        healthyRangeLow: 6.0, healthyRangeHigh: 9.0,
                        typicalDailyVariation: 0.10),
            MetricPrior(metric: .sleepDeep,
                        populationMean: 1.26, populationStdDev: 0.35,
                        healthyRangeLow: 0.9, healthyRangeHigh: 1.75,
                        typicalDailyVariation: 0.20),
            MetricPrior(metric: .sleepREM,
                        populationMean: 1.58, populationStdDev: 0.42,
                        healthyRangeLow: 1.0, healthyRangeHigh: 2.25,
                        typicalDailyVariation: 0.18),
            MetricPrior(metric: .sleepCore,
                        populationMean: 3.5, populationStdDev: 0.7,
                        healthyRangeLow: 2.5, healthyRangeHigh: 5.0,
                        typicalDailyVariation: 0.12),
            MetricPrior(metric: .sleepAwake,
                        populationMean: 0.5, populationStdDev: 0.25,
                        healthyRangeLow: 0.0, healthyRangeHigh: 1.0,
                        typicalDailyVariation: 0.30),

            // Activity
            MetricPrior(metric: .steps,
                        populationMean: 7500, populationStdDev: 3000,
                        healthyRangeLow: 5000, healthyRangeHigh: 15000,
                        typicalDailyVariation: 0.25),
            MetricPrior(metric: .activeCalories,
                        populationMean: 400, populationStdDev: 200,
                        healthyRangeLow: 200, healthyRangeHigh: 800,
                        typicalDailyVariation: 0.30),
            MetricPrior(metric: .exerciseMinutes,
                        populationMean: 30, populationStdDev: 20,
                        healthyRangeLow: 20, healthyRangeHigh: 90,
                        typicalDailyVariation: 0.35),
            MetricPrior(metric: .standHours,
                        populationMean: 10, populationStdDev: 3,
                        healthyRangeLow: 6, healthyRangeHigh: 16,
                        typicalDailyVariation: 0.15),
            MetricPrior(metric: .distanceWalkingRunning,
                        populationMean: 5.5, populationStdDev: 2.5,
                        healthyRangeLow: 3.0, healthyRangeHigh: 12.0,
                        typicalDailyVariation: 0.28),
            MetricPrior(metric: .flightsClimbed,
                        populationMean: 5, populationStdDev: 4,
                        healthyRangeLow: 2, healthyRangeHigh: 15,
                        typicalDailyVariation: 0.35),

            // Body & Vitals
            MetricPrior(metric: .weight,
                        populationMean: 75, populationStdDev: 15,
                        healthyRangeLow: 50, healthyRangeHigh: 100,
                        typicalDailyVariation: 0.01),
            MetricPrior(metric: .bloodPressureSystolic,
                        populationMean: 120, populationStdDev: 12,
                        healthyRangeLow: 90, healthyRangeHigh: 140,
                        typicalDailyVariation: 0.05),
            MetricPrior(metric: .bloodPressureDiastolic,
                        populationMean: 78, populationStdDev: 8,
                        healthyRangeLow: 60, healthyRangeHigh: 90,
                        typicalDailyVariation: 0.05),
            MetricPrior(metric: .bodyTemperature,
                        populationMean: 36.6, populationStdDev: 0.3,
                        healthyRangeLow: 36.1, healthyRangeHigh: 37.2,
                        typicalDailyVariation: 0.005),
            MetricPrior(metric: .bloodGlucose,
                        populationMean: 95, populationStdDev: 12,
                        healthyRangeLow: 70, healthyRangeHigh: 120,
                        typicalDailyVariation: 0.10),

            // Respiratory
            MetricPrior(metric: .vo2Max,
                        populationMean: 38, populationStdDev: 8,
                        healthyRangeLow: 25, healthyRangeHigh: 55,
                        typicalDailyVariation: 0.03),
            MetricPrior(metric: .bloodOxygen,
                        populationMean: 97.5, populationStdDev: 1.2,
                        healthyRangeLow: 95, healthyRangeHigh: 100,
                        typicalDailyVariation: 0.01),
            MetricPrior(metric: .respiratoryRate,
                        populationMean: 15, populationStdDev: 2.5,
                        healthyRangeLow: 12, healthyRangeHigh: 20,
                        typicalDailyVariation: 0.06),

            // Mindfulness
            MetricPrior(metric: .mindfulMinutes,
                        populationMean: 10, populationStdDev: 10,
                        healthyRangeLow: 5, healthyRangeHigh: 30,
                        typicalDailyVariation: 0.40),

            // Mobility
            MetricPrior(metric: .walkingSpeed,
                        populationMean: 4.8, populationStdDev: 0.6,
                        healthyRangeLow: 3.5, healthyRangeHigh: 6.5,
                        typicalDailyVariation: 0.05),
            MetricPrior(metric: .walkingStepLength,
                        populationMean: 72, populationStdDev: 8,
                        healthyRangeLow: 55, healthyRangeHigh: 90,
                        typicalDailyVariation: 0.04),

            // Workouts
            MetricPrior(metric: .workoutDuration,
                        populationMean: 45, populationStdDev: 20,
                        healthyRangeLow: 20, healthyRangeHigh: 90,
                        typicalDailyVariation: 0.30),

            // Nutrition
            MetricPrior(metric: .waterIntake,
                        populationMean: 2000, populationStdDev: 600,
                        healthyRangeLow: 1500, healthyRangeHigh: 3500,
                        typicalDailyVariation: 0.20),
            MetricPrior(metric: .caffeineIntake,
                        populationMean: 200, populationStdDev: 100,
                        healthyRangeLow: 0, healthyRangeHigh: 400,
                        typicalDailyVariation: 0.25),
        ]
        var dict: [HealthMetric: MetricPrior] = [:]
        for prior in list { dict[prior.metric] = prior }
        return dict
    }()

    // MARK: - Correlation Priors

    /// A well-established physiological relationship between two metrics.
    struct CorrelationPrior {
        let metricA: HealthMetric
        let metricB: HealthMetric
        /// Expected Pearson r
        let expectedCorrelation: Double
        /// Direction: "positive" or "negative"
        let expectedDirection: String
        /// How well-established this relationship is (0-1)
        let confidence: Double
        /// Brief physiological explanation
        let mechanism: String
    }

    /// Known physiological correlations sourced from medical literature.
    static let correlationPriors: [CorrelationPrior] = [
        // HRV <-> Sleep
        CorrelationPrior(
            metricA: .heartRateVariability, metricB: .sleepDuration,
            expectedCorrelation: 0.30, expectedDirection: "positive", confidence: 0.80,
            mechanism: "Better sleep improves autonomic recovery and vagal tone"),
        CorrelationPrior(
            metricA: .heartRateVariability, metricB: .sleepDeep,
            expectedCorrelation: 0.35, expectedDirection: "positive", confidence: 0.75,
            mechanism: "Deep sleep is the primary window for parasympathetic restoration"),

        // HRV <-> RHR (strong inverse)
        CorrelationPrior(
            metricA: .heartRateVariability, metricB: .restingHeartRate,
            expectedCorrelation: -0.40, expectedDirection: "negative", confidence: 0.90,
            mechanism: "Higher vagal tone lowers resting heart rate and raises HRV"),

        // RHR <-> Exercise
        CorrelationPrior(
            metricA: .restingHeartRate, metricB: .exerciseMinutes,
            expectedCorrelation: -0.25, expectedDirection: "negative", confidence: 0.70,
            mechanism: "Regular exercise strengthens cardiac efficiency, lowering resting heart rate"),

        // Sleep <-> Next-day activity
        CorrelationPrior(
            metricA: .sleepDuration, metricB: .steps,
            expectedCorrelation: 0.20, expectedDirection: "positive", confidence: 0.60,
            mechanism: "Adequate sleep enables more physical activity the following day"),
        CorrelationPrior(
            metricA: .sleepDuration, metricB: .activeCalories,
            expectedCorrelation: 0.18, expectedDirection: "positive", confidence: 0.55,
            mechanism: "Well-rested individuals tend to expend more energy during the day"),

        // Activity <-> Sleep quality
        CorrelationPrior(
            metricA: .activeCalories, metricB: .sleepDeep,
            expectedCorrelation: 0.20, expectedDirection: "positive", confidence: 0.50,
            mechanism: "Physical activity promotes deeper, more restorative sleep"),
        CorrelationPrior(
            metricA: .exerciseMinutes, metricB: .sleepDuration,
            expectedCorrelation: 0.15, expectedDirection: "positive", confidence: 0.55,
            mechanism: "Regular exercise improves sleep onset and duration"),

        // VO2 Max <-> Activity
        CorrelationPrior(
            metricA: .vo2Max, metricB: .exerciseMinutes,
            expectedCorrelation: 0.35, expectedDirection: "positive", confidence: 0.80,
            mechanism: "Consistent exercise drives aerobic capacity improvements"),
        CorrelationPrior(
            metricA: .vo2Max, metricB: .restingHeartRate,
            expectedCorrelation: -0.30, expectedDirection: "negative", confidence: 0.75,
            mechanism: "Higher aerobic fitness correlates with lower resting heart rate"),

        // Steps <-> Active Calories (strongly correlated)
        CorrelationPrior(
            metricA: .steps, metricB: .activeCalories,
            expectedCorrelation: 0.70, expectedDirection: "positive", confidence: 0.95,
            mechanism: "Walking and movement directly contribute to energy expenditure"),

        // Blood Pressure <-> RHR
        CorrelationPrior(
            metricA: .bloodPressureSystolic, metricB: .restingHeartRate,
            expectedCorrelation: 0.20, expectedDirection: "positive", confidence: 0.60,
            mechanism: "Elevated resting heart rate often accompanies higher blood pressure"),

        // Mindfulness <-> HRV
        CorrelationPrior(
            metricA: .mindfulMinutes, metricB: .heartRateVariability,
            expectedCorrelation: 0.15, expectedDirection: "positive", confidence: 0.50,
            mechanism: "Mindfulness practice enhances parasympathetic activity"),

        // Weight <-> Steps (inverse)
        CorrelationPrior(
            metricA: .weight, metricB: .steps,
            expectedCorrelation: -0.15, expectedDirection: "negative", confidence: 0.45,
            mechanism: "Higher daily step counts are associated with weight management"),

        // Respiratory Rate <-> HRV
        CorrelationPrior(
            metricA: .respiratoryRate, metricB: .heartRateVariability,
            expectedCorrelation: -0.20, expectedDirection: "negative", confidence: 0.55,
            mechanism: "Slower respiratory rate reflects greater parasympathetic tone"),
    ]

    // MARK: - Prediction Priors

    /// Population-level logistic regression prior for bad-day prediction.
    struct PredictionPrior {
        /// Prior feature weights keyed by FeatureKey
        let featureWeights: [FeatureKey: Double]
        /// Intercept (bias) for the logistic model
        let intercept: Double
    }

    /// Default weights derived from population-level health risk factors.
    /// Positive weight = increases bad-day risk; negative = protective.
    static let predictionPrior: PredictionPrior = {
        var weights: [FeatureKey: Double] = [:]

        // Low HRV is a strong risk signal
        weights[FeatureKey(metric: .heartRateVariability, type: .raw)] = -0.50
        weights[FeatureKey(metric: .heartRateVariability, type: .roc)] = -0.20
        weights[FeatureKey(metric: .heartRateVariability, type: .vol7)] = 0.15

        // Elevated RHR signals stress / poor recovery
        weights[FeatureKey(metric: .restingHeartRate, type: .raw)] = 0.30
        weights[FeatureKey(metric: .restingHeartRate, type: .roc)] = 0.15

        // Insufficient sleep
        weights[FeatureKey(metric: .sleepDuration, type: .raw)] = -0.40
        weights[FeatureKey(metric: .sleepDuration, type: .devBaseline)] = -0.25
        weights[FeatureKey(metric: .sleepDeep, type: .raw)] = -0.20

        // Low activity can compound poor days
        weights[FeatureKey(metric: .steps, type: .raw)] = -0.10
        weights[FeatureKey(metric: .activeCalories, type: .raw)] = -0.10

        // High volatility across metrics is a risk amplifier
        weights[FeatureKey(metric: .heartRateVariability, type: .devBaseline)] = -0.20
        weights[FeatureKey(metric: .restingHeartRate, type: .devBaseline)] = 0.20

        // Exercise is protective
        weights[FeatureKey(metric: .exerciseMinutes, type: .raw)] = -0.15

        // Blood oxygen dips
        weights[FeatureKey(metric: .bloodOxygen, type: .raw)] = -0.10

        return PredictionPrior(featureWeights: weights, intercept: -0.30)
    }()
}

// MARK: - Personalization Blender

/// Blends population-level statistical priors with personalized model outputs
/// using confidence-weighted functions. Enables meaningful predictions from
/// day one and smoothly transitions to fully personalized models as user data
/// accumulates.
enum PersonalizationBlender {

    // MARK: - Prediction Blending

    /// Blend a personalized prediction with the population prior using a sigmoid ramp.
    ///
    /// At ~0 days:  ~5% personal, ~95% population.
    /// At ~30 days: ~50/50.
    /// At ~60 days: ~95% personal, ~5% population.
    ///
    /// - Parameters:
    ///   - personalPrediction: Output from the user's personal model (0-1).
    ///   - populationPrediction: Output from the population prior model (0-1).
    ///   - userDataDays: Number of days of user data available.
    ///   - personalModelAccuracy: Optional measured accuracy of the personal model.
    ///   - rampCenterDays: Day count at which blending is 50/50 (default 30).
    ///   - rampScale: Sigmoid steepness — smaller = sharper transition (default 8.0).
    /// - Returns: Blended prediction and the personal weight used.
    static func blendPrediction(
        personalPrediction: Double,
        populationPrediction: Double,
        userDataDays: Int,
        personalModelAccuracy: Double? = nil,
        rampCenterDays: Int = 30,
        rampScale: Double = 8.0
    ) -> (blended: Double, personalWeight: Double) {
        var personalWeight = sigmoidWeight(
            days: userDataDays,
            rampCenter: rampCenterDays,
            rampScale: rampScale
        )

        // Boost personal weight if we have measured accuracy data
        if let accuracy = personalModelAccuracy, accuracy > 0.5 {
            // Scale personal weight upward when accuracy is high.
            // accuracy of 0.5 = no boost; accuracy of 1.0 = up to 20% boost.
            let boost = (accuracy - 0.5) * 0.4
            personalWeight = min(1.0, personalWeight + boost * personalWeight)
        }

        let blended = personalWeight * personalPrediction
                    + (1.0 - personalWeight) * populationPrediction
        return (blended: clamp01(blended), personalWeight: personalWeight)
    }

    // MARK: - Baseline Blending

    /// Blend a personalized baseline with population priors.
    ///
    /// - When user has < 7 days: 100% population.
    /// - When user has 7-60 days: sigmoid blend.
    /// - When user has 60+ days: 100% personal.
    ///
    /// - Parameters:
    ///   - personalBaseline: User's computed baseline (nil if insufficient data).
    ///   - metric: The health metric to look up population priors.
    ///   - userDataDays: Number of days of user data.
    /// - Returns: Blended mean, standard deviation, and personal weight.
    static func blendBaseline(
        personalBaseline: UserBaseline?,
        metric: HealthMetric,
        userDataDays: Int
    ) -> (mean: Double, stdDev: Double, personalWeight: Double) {
        guard let prior = PopulationPriors.priors[metric] else {
            // No population prior — fall back to personal or zeros.
            if let personal = personalBaseline {
                return (mean: personal.mean, stdDev: personal.standardDeviation, personalWeight: 1.0)
            }
            return (mean: 0, stdDev: 1, personalWeight: 0)
        }

        // Below minimum threshold: pure population
        guard userDataDays >= 7, let personal = personalBaseline else {
            return (mean: prior.populationMean, stdDev: prior.populationStdDev, personalWeight: 0)
        }

        // Above full personalization threshold
        if userDataDays >= 60 {
            return (mean: personal.mean, stdDev: personal.standardDeviation, personalWeight: 1.0)
        }

        // Sigmoid blend in the 7-60 day window
        let w = sigmoidWeight(days: userDataDays, rampCenter: 30, rampScale: 8.0)

        let blendedMean = w * personal.mean + (1.0 - w) * prior.populationMean
        let blendedStdDev = w * personal.standardDeviation + (1.0 - w) * prior.populationStdDev

        return (mean: blendedMean, stdDev: blendedStdDev, personalWeight: w)
    }

    // MARK: - Cold-Start Prediction

    /// Generate a risk prediction when no personal model exists yet.
    ///
    /// Uses population priors plus whatever data the user has — even a single day —
    /// by computing z-scores relative to population baselines and applying the
    /// population prediction weights.
    ///
    /// - Parameters:
    ///   - availableData: Per-metric arrays of raw values (can be as few as 1 value).
    ///   - priors: The population priors type (default: `PopulationPriors.self`).
    /// - Returns: Risk score (0-1), confidence (0-1), and a human-readable explanation.
    static func coldStartPrediction(
        availableData: [HealthMetric: [Double]],
        priors: PopulationPriors.Type = PopulationPriors.self
    ) -> (riskScore: Double, confidence: Double, explanation: String) {
        guard !availableData.isEmpty else {
            return (
                riskScore: 0.5,
                confidence: 0.0,
                explanation: "No health data available yet. Track at least one day for initial insights."
            )
        }

        let predPrior = PopulationPriors.predictionPrior
        var logit = predPrior.intercept
        var matchedFeatures = 0
        var totalPriorFeatures = predPrior.featureWeights.count
        var riskFactors: [String] = []
        var protectiveFactors: [String] = []

        for (metric, values) in availableData {
            guard let metricPrior = PopulationPriors.priors[metric],
                  let latestValue = values.last else { continue }

            // Z-score relative to population
            let zScore: Double
            if metricPrior.populationStdDev > 0 {
                zScore = (latestValue - metricPrior.populationMean) / metricPrior.populationStdDev
            } else {
                zScore = 0
            }

            // Apply raw feature weight
            let rawKey = FeatureKey(metric: metric, type: .raw)
            if let weight = predPrior.featureWeights[rawKey] {
                let contribution = weight * zScore
                logit += contribution
                matchedFeatures += 1

                // Track top risk/protective factors for explanation
                if abs(contribution) > 0.1 {
                    let metricName = metric.displayName
                    if contribution > 0 {
                        riskFactors.append(metricName)
                    } else {
                        protectiveFactors.append(metricName)
                    }
                }
            }

            // Deviation-from-baseline weight (use population mean as baseline proxy)
            let devKey = FeatureKey(metric: metric, type: .devBaseline)
            if let weight = predPrior.featureWeights[devKey] {
                let devScore = zScore // Deviation from "baseline" is the z-score itself at cold start
                logit += weight * devScore
                matchedFeatures += 1
            }

            // Rate-of-change estimate from available data
            if values.count >= 2 {
                let rocKey = FeatureKey(metric: metric, type: .roc)
                if let weight = predPrior.featureWeights[rocKey] {
                    let prev = values[values.count - 2]
                    let rocRaw = latestValue - prev
                    let rocZScore: Double
                    if metricPrior.populationStdDev > 0 {
                        rocZScore = rocRaw / metricPrior.populationStdDev
                    } else {
                        rocZScore = 0
                    }
                    logit += weight * rocZScore
                    matchedFeatures += 1
                }
            }
        }

        let riskScore = AccelerateML.sigmoid(logit)

        // Confidence based on data coverage and volume
        let metricCoverage = Double(availableData.count) / Double(max(totalPriorFeatures, 1))
        let featureCoverage = Double(matchedFeatures) / Double(max(totalPriorFeatures, 1))
        let dayCount = availableData.values.map(\.count).max() ?? 0
        let dayFactor = min(Double(dayCount) / 7.0, 1.0) // Max out at 7 days for cold start
        let confidence = clamp01(min(metricCoverage, featureCoverage) * 0.6 + dayFactor * 0.4)

        let explanation = buildColdStartExplanation(
            riskScore: riskScore,
            confidence: confidence,
            metricCount: availableData.count,
            dayCount: dayCount,
            riskFactors: riskFactors,
            protectiveFactors: protectiveFactors
        )

        return (riskScore: riskScore, confidence: confidence, explanation: explanation)
    }

    // MARK: - Correlation Blending

    /// Blend a personally discovered correlation with population priors using
    /// Bayesian shrinkage toward the prior.
    ///
    /// Formula: `blended = (populationR * priorWeight + personalR * n) / (priorWeight + n)`
    /// where `priorWeight` scales with `populationConfidence`.
    ///
    /// With few personal samples the result stays near the population prior;
    /// with many samples it converges toward the personal observation.
    ///
    /// - Parameters:
    ///   - personalR: Pearson r observed in user data.
    ///   - personalN: Number of paired observations.
    ///   - populationR: Expected correlation from population research.
    ///   - populationConfidence: How well-established the population value is (0-1).
    /// - Returns: Blended Pearson r and the effective personal weight.
    static func blendCorrelation(
        personalR: Double,
        personalN: Int,
        populationR: Double,
        populationConfidence: Double
    ) -> (blendedR: Double, personalWeight: Double) {
        // Prior weight: higher confidence = stronger prior (range ~5-50 effective samples)
        let priorWeight = 5.0 + populationConfidence * 45.0
        let n = Double(personalN)

        let blendedR = (populationR * priorWeight + personalR * n) / (priorWeight + n)
        let personalWeight = n / (priorWeight + n)

        // Clamp correlation to valid range
        let clampedR = max(-1.0, min(1.0, blendedR))

        return (blendedR: clampedR, personalWeight: personalWeight)
    }

    /// Look up the population correlation prior for a metric pair, if one exists.
    /// Checks both orderings of (metricA, metricB).
    static func findCorrelationPrior(
        metricA: HealthMetric,
        metricB: HealthMetric
    ) -> PopulationPriors.CorrelationPrior? {
        PopulationPriors.correlationPriors.first { prior in
            (prior.metricA == metricA && prior.metricB == metricB) ||
            (prior.metricA == metricB && prior.metricB == metricA)
        }
    }

    // MARK: - Personalization Status

    /// Describes the current level of personalization for the user.
    struct PersonalizationStatus {
        let level: PersonalizationLevel
        /// 0-100 indicating how personalized insights are
        let percentPersonalized: Double
        /// Human-readable description
        let description: String
        /// Next milestone hint (nil when fully personalized)
        let nextMilestone: String?
    }

    /// Discrete personalization levels based on data accumulation.
    enum PersonalizationLevel: String {
        case population = "Population Averages"
        case emerging = "Learning Your Patterns"
        case blended = "Increasingly Personal"
        case personalized = "Highly Personalized"
        case fullyPersonal = "Fully Personalized"
    }

    /// Compute the personalization status for the current user.
    ///
    /// - Parameters:
    ///   - userDataDays: Total days of health data.
    ///   - metricsTracked: Number of distinct metrics being tracked.
    ///   - modelAccuracy: Optional personal model accuracy (if evaluated).
    /// - Returns: A `PersonalizationStatus` describing the current state.
    static func personalizationStatus(
        userDataDays: Int,
        metricsTracked: Int,
        modelAccuracy: Double? = nil
    ) -> PersonalizationStatus {
        let basePercent = sigmoidWeight(days: userDataDays, rampCenter: 30, rampScale: 8.0) * 100.0

        // Metric breadth bonus: tracking more metrics increases personalization quality.
        // Up to 10% bonus for tracking 10+ metrics.
        let metricBreadthBonus = min(Double(metricsTracked) / 10.0, 1.0) * 10.0

        // Accuracy bonus: if model accuracy is known and good, boost.
        let accuracyBonus: Double
        if let acc = modelAccuracy, acc > 0.6 {
            accuracyBonus = (acc - 0.6) * 25.0 // Up to 10% bonus at 1.0 accuracy
        } else {
            accuracyBonus = 0
        }

        let percent = min(100.0, basePercent + metricBreadthBonus + accuracyBonus)

        let level: PersonalizationLevel
        let description: String
        let nextMilestone: String?

        switch userDataDays {
        case ..<7:
            level = .population
            description = "Your insights use general health benchmarks while we learn your patterns."
            let remaining = 7 - userDataDays
            nextMilestone = "Track \(remaining) more day\(remaining == 1 ? "" : "s") to begin personalizing insights."

        case 7..<21:
            level = .emerging
            description = "Your insights are \(Int(percent))% personalized — we're learning your unique patterns."
            let remaining = 21 - userDataDays
            nextMilestone = "Track \(remaining) more day\(remaining == 1 ? "" : "s") for increasingly personal insights."

        case 21..<45:
            level = .blended
            description = "Your insights are \(Int(percent))% personalized to your body."
            let remaining = 45 - userDataDays
            nextMilestone = "Track \(remaining) more day\(remaining == 1 ? "" : "s") for highly personalized predictions."

        case 45..<60:
            level = .personalized
            description = "Your insights are \(Int(percent))% personalized — predictions are tailored to you."
            let remaining = 60 - userDataDays
            nextMilestone = "Track \(remaining) more day\(remaining == 1 ? "" : "s") for fully personalized insights."

        default:
            level = .fullyPersonal
            description = "Your insights are fully personalized to your body's unique patterns."
            nextMilestone = nil
        }

        return PersonalizationStatus(
            level: level,
            percentPersonalized: percent,
            description: description,
            nextMilestone: nextMilestone
        )
    }

    // MARK: - Population-Based Prediction

    /// Generate a population-based bad-day prediction using prior weights.
    /// Useful as the `populationPrediction` input to `blendPrediction`.
    ///
    /// - Parameter todayVector: Today's feature vector.
    /// - Returns: Probability of a bad day according to population priors.
    static func populationPrediction(from todayVector: DailyFeatureVector) -> Double {
        let prior = PopulationPriors.predictionPrior
        var logit = prior.intercept

        for (key, weight) in prior.featureWeights {
            if let value = todayVector.features[key], value != FeatureKey.missingSentinel {
                logit += weight * value
            }
        }

        return AccelerateML.sigmoid(logit)
    }

    // MARK: - Helpers

    /// Sigmoid blending weight: `1 / (1 + exp(-(days - center) / scale))`
    private static func sigmoidWeight(days: Int, rampCenter: Int, rampScale: Double) -> Double {
        1.0 / (1.0 + exp(-Double(days - rampCenter) / rampScale))
    }

    /// Clamp a value to [0, 1].
    private static func clamp01(_ value: Double) -> Double {
        max(0.0, min(1.0, value))
    }

    /// Build a human-readable explanation for cold-start predictions.
    private static func buildColdStartExplanation(
        riskScore: Double,
        confidence: Double,
        metricCount: Int,
        dayCount: Int,
        riskFactors: [String],
        protectiveFactors: [String]
    ) -> String {
        var parts: [String] = []

        // Risk summary
        let riskLabel: String
        switch riskScore {
        case 0.7...: riskLabel = "elevated risk"
        case 0.5..<0.7: riskLabel = "moderate risk"
        case 0.3..<0.5: riskLabel = "low risk"
        default: riskLabel = "very low risk"
        }

        parts.append(
            "Based on \(dayCount) day\(dayCount == 1 ? "" : "s") of data across "
            + "\(metricCount) metric\(metricCount == 1 ? "" : "s"), "
            + "population benchmarks suggest \(riskLabel) for a challenging day."
        )

        if !riskFactors.isEmpty {
            parts.append("Risk factors: \(riskFactors.joined(separator: ", ")).")
        }
        if !protectiveFactors.isEmpty {
            parts.append("Protective factors: \(protectiveFactors.joined(separator: ", ")).")
        }

        if confidence < 0.5 {
            parts.append("Confidence is low — more data will improve accuracy.")
        }

        return parts.joined(separator: " ")
    }
}
