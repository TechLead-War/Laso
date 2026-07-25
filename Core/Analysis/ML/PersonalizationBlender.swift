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
    ///   - rampCenterDays: Day count at which blending is 50/50 (default 14).
    ///   - rampScale: Sigmoid steepness. smaller = sharper transition (default 5.0).
    /// - Returns: Blended prediction and the personal weight used.
    static func blendPrediction(
        personalPrediction: Double,
        populationPrediction: Double,
        userDataDays: Int,
        personalModelAccuracy: Double? = nil,
        rampCenterDays: Int = 14,
        rampScale: Double = 5.0
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

    // MARK: - Cold-Start Prediction

    /// Generate a risk prediction when no personal model exists yet.
    ///
    /// Uses population priors plus whatever data the user has. even a single day —
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
        let totalPriorFeatures = predPrior.featureWeights.count
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
            parts.append("Confidence is low. more data will improve accuracy.")
        }

        return parts.joined(separator: " ")
    }
}
