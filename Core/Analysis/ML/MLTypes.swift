import Foundation

// MARK: - Daily Feature Vector

/// A standardized feature vector for a single day, containing raw and derived features for all available metrics
struct DailyFeatureVector {
    let date: Date
    /// Per-metric features keyed by FeatureKey (metric + feature type)
    var features: [FeatureKey: Double]
    /// Contextual features (day-of-week, month, weekend)
    var context: ContextFeatures

    /// Get all feature values as a sorted array (deterministic order for ML algorithms)
    func toArray(orderedKeys: [FeatureKey]) -> [Double] {
        orderedKeys.map { features[$0] ?? FeatureKey.missingSentinel }
    }

    /// Get raw value for a specific metric
    func rawValue(for metric: HealthMetric) -> Double? {
        features[FeatureKey(metric: metric, type: .raw)]
    }
}

// MARK: - Feature Key

/// Uniquely identifies a feature: metric + derived feature type
struct FeatureKey: Hashable, Codable {
    let metric: HealthMetric
    let type: FeatureType

    /// Sentinel value for missing data
    static let missingSentinel: Double = -999.0
}

/// Types of derived features computed from raw metric values
enum FeatureType: String, Hashable, Codable, CaseIterable {
    case raw            // Original z-score normalized value
    case roc            // Rate of change (day-over-day)
    case vol7           // 7-day rolling volatility (std dev)
    case lag1           // Value from 1 day ago
    case lag3           // Value from 3 days ago
    case lag7           // Value from 7 days ago
    case devBaseline    // Deviation from personal baseline

    // Multi-resolution features
    case acceleration   // 2nd derivative (rate of change of rate of change)
    case entropy        // Shannon entropy of recent distribution (7-day binned)
    case periodicityStr // Autocorrelation strength at dominant period
    case vol14          // 14-day rolling volatility
    case vol28          // 28-day rolling volatility
    case lag14          // Value from 14 days ago
    case lag28          // Value from 28 days ago
    case lag60          // Value from 60 days ago
    case weekdayOffset  // Deviation of weekday mean from overall mean
    case weekendOffset  // Deviation of weekend mean from overall mean
    case missingness    // Binary: 1.0 if data missing on this day, 0.0 otherwise
}

// MARK: - Context Features

/// Temporal and contextual features for a given day
struct ContextFeatures: Codable {
    /// Sin component of day-of-week (cyclical encoding, period = 7)
    let weekdaySin: Double
    /// Cos component of day-of-week (cyclical encoding, period = 7)
    let weekdayCos: Double
    /// Sin component of month (cyclical encoding, period = 12)
    let monthSin: Double
    /// Cos component of month (cyclical encoding, period = 12)
    let monthCos: Double
    /// Whether this day is a weekend (Saturday or Sunday)
    let isWeekend: Double // 1.0 or 0.0

    /// Create context features from a date
    static func from(date: Date) -> ContextFeatures {
        let calendar = Date.cal
        let weekday = Double(calendar.component(.weekday, from: date)) // 1=Sun, 7=Sat
        let month = Double(calendar.component(.month, from: date))     // 1-12

        let weekdayAngle = 2.0 * .pi * (weekday - 1.0) / 7.0
        let monthAngle = 2.0 * .pi * (month - 1.0) / 12.0

        let dayOfWeek = calendar.component(.weekday, from: date)
        let isWeekend = (dayOfWeek == 1 || dayOfWeek == 7) ? 1.0 : 0.0

        return ContextFeatures(
            weekdaySin: sin(weekdayAngle),
            weekdayCos: cos(weekdayAngle),
            monthSin: sin(monthAngle),
            monthCos: cos(monthAngle),
            isWeekend: isWeekend
        )
    }

    /// Convert to array for ML input
    var asArray: [Double] {
        [weekdaySin, weekdayCos, monthSin, monthCos, isWeekend]
    }
}

// MARK: - ML Prediction

/// A prediction from an ML component with explanation
struct MLPrediction {
    /// What is being predicted (e.g., "bad day tomorrow")
    let target: String
    /// Probability of the predicted outcome (0.0 - 1.0)
    let probability: Double
    /// Confidence in the prediction (0.0 - 1.0), scales with training data
    let confidence: Double
    /// Top contributing features with signed contributions
    let topFactors: [PredictionFactor]
    /// When this prediction was generated
    let generatedAt: Date

    /// Human-readable risk level
    var riskLevel: String {
        switch probability {
        case 0.7...: return Copy.Insights.riskLevelHigh
        case 0.5..<0.7: return Copy.Insights.riskLevelModerate
        case 0.3..<0.5: return Copy.Insights.riskLevelLow
        default: return Copy.Insights.riskLevelVeryLow
        }
    }
}

/// A factor contributing to an ML prediction
struct PredictionFactor {
    /// The metric involved
    let metric: HealthMetric
    /// Feature type (raw, rate-of-change, etc.)
    let featureType: FeatureType
    /// Signed contribution: positive = risk factor, negative = protective
    let contribution: Double
    /// Current feature value
    let currentValue: Double

    /// Whether this factor increases risk
    var isRiskFactor: Bool { contribution > 0 }
}

// MARK: - ML Model State

/// Serializable state for persisting learned ML model parameters
struct MLModelState: Codable {
    /// Which ML component this state belongs to
    let componentName: String
    /// Version for migration support
    let version: Int
    /// JSON-encoded model parameters
    let parametersJSON: Data
    /// Number of data points used in training
    let dataPointsUsed: Int
    /// When the model was last trained
    let lastTrainedDate: Date
}

// MARK: - Discovered Pattern

/// A periodic or structural pattern discovered in user's health data
struct DiscoveredPattern {
    /// The metric exhibiting the pattern
    let metric: HealthMetric
    /// Type of pattern
    let patternType: PatternType
    /// Period in days (e.g., 7 for weekly)
    let periodDays: Double
    /// Strength of the pattern (0.0 - 1.0)
    let strength: Double
    /// Human-readable description
    let description: String
    /// When this pattern was discovered
    let discoveredAt: Date
    /// Peak day of week (1=Sun, 7=Sat) for weekly patterns, nil otherwise
    let peakDayOfWeek: Int?
    /// Trough day of week (1=Sun, 7=Sat) for weekly patterns, nil otherwise
    let troughDayOfWeek: Int?
    /// Average peak value (raw)
    let peakMeanValue: Double?
    /// Average trough value (raw)
    let troughMeanValue: Double?

    enum PatternType: String, Codable {
        case weekly         // 7-day cycle
        case biweekly       // 14-day cycle
        case monthly        // ~28-30 day cycle
        case seasonal       // ~90 day cycle
        case custom         // Non-standard period
    }

    /// Human-readable name of peak day (e.g. "Wednesday")
    var peakDayName: String? {
        peakDayOfWeek.flatMap { Self.dayName($0) }
    }

    /// Human-readable name of trough day (e.g. "Monday")
    var troughDayName: String? {
        troughDayOfWeek.flatMap { Self.dayName($0) }
    }

    static func dayName(_ weekday: Int) -> String? {
        switch weekday {
        case 1: return Copy.Insights.daySunday
        case 2: return Copy.Insights.dayMonday
        case 3: return Copy.Insights.dayTuesday
        case 4: return Copy.Insights.dayWednesday
        case 5: return Copy.Insights.dayThursday
        case 6: return Copy.Insights.dayFriday
        case 7: return Copy.Insights.daySaturday
        default: return nil
        }
    }
}

// MARK: - Health State

/// A cluster-derived health state representing a distinct mode of operation
struct HealthState {
    /// Auto-generated label (e.g., "Recovery", "Peak Performance", "Stressed")
    let label: String
    /// Cluster centroid feature values
    let centroid: [Double]
    /// Dominant characteristics that define this state
    let characteristics: [StateCharacteristic]
    /// How many days the user has been in this state
    let daysInState: Int
    /// Probability of transitioning to each other state
    let transitionProbabilities: [String: Double]

    struct StateCharacteristic {
        let metric: HealthMetric
        let level: Level // high, normal, low
        let zScore: Double

        enum Level: String {
            case high, normal, low
        }
    }
}

// MARK: - ML Discovered Correlation

/// A correlation discovered by ML (broader than the hardcoded 35 pairs)
struct MLCorrelation {
    let metricA: HealthMetric
    let metricB: HealthMetric
    /// Pearson correlation coefficient
    let pearsonR: Double
    /// Mutual information (captures non-linear relationships)
    let mutualInformation: Double
    /// Whether metricA Granger-causes metricB
    let grangerCausal: Bool
    /// p-value for Granger test
    let grangerPValue: Double
    /// Partial correlation controlling for strongest confounder
    let partialCorrelation: Double?
    /// Confounder metric (if partial correlation was computed)
    let confounderMetric: HealthMetric?
    /// Stability of correlation over sliding 30-day windows (0.0 = volatile, 1.0 = stable)
    let stability: Double
    /// Number of paired observations
    let sampleCount: Int
    /// Cohen's f² effect size from the Granger test (0 if not computed)
    let grangerEffectSize: Double
    /// Optimal lag in days from BIC selection in the Granger test (0 if not computed)
    let grangerOptimalLag: Int
    /// Whether this correlation survived Benjamini-Hochberg FDR correction at α = 0.05
    var survivedFDR: Bool

    /// Whether this correlation is statistically significant
    var isSignificant: Bool {
        abs(pearsonR) >= 0.25 || mutualInformation > 0.1 || grangerCausal
    }

    /// Overall strength combining linear and non-linear measures
    var overallStrength: Double {
        max(abs(pearsonR), mutualInformation * 2.0)
    }
}

// MARK: - Model Version

/// Schema version for ML model persistence and migration
struct ModelVersion: Codable, Equatable {
    let componentName: String
    let modelVersion: Int
    let featureSchemaVersion: Int
    let calibrationVersion: Int
    let trainedAt: Date
    let dataPointsUsed: Int
}

// MARK: - Evaluation Event

/// Tracks a prediction alongside its realized outcome for evaluation
struct EvaluationEvent: Codable {
    let eventId: String
    let componentName: String
    let modelVersion: ModelVersion
    let predictedAt: Date
    let forecastHorizon: ForecastHorizon
    let prediction: PredictionRecord
    var outcome: OutcomeRecord?
    var isResolved: Bool { outcome != nil }

    struct PredictionRecord: Codable {
        let targetMetric: String
        let predictedValue: Double
        let predictedProbability: Double?
        let confidence: Double
        let intervalLower: Double?
        let intervalUpper: Double?
    }

    struct OutcomeRecord: Codable {
        let resolvedAt: Date
        let actualValue: Double
        let wasCorrect: Bool?
        let residual: Double
    }

    enum ForecastHorizon: String, Codable {
        case nextDay = "1d"
        case next3Days = "3d"
        case next7Days = "7d"
    }
}

// MARK: - Intervention Candidate

/// A candidate intervention the decision policy evaluates
struct InterventionCandidate {
    let id: String
    let targetMetric: HealthMetric
    let actionType: ActionType
    let source: InterventionSource

    /// Predicted downstream benefit if user follows this intervention
    let predictedUplift: Double
    /// Confidence in the uplift estimate (0-1)
    let upliftConfidence: Double
    /// Estimated effort cost for the user (0=trivial, 1=very hard)
    let effortCost: Double
    /// Expected time to observable benefit
    let timeToBenefit: TimeToBenefit
    /// Estimated probability user will actually follow through
    let adherenceLikelihood: Double
    /// How many times similar advice was shown recently
    let recentExposureCount: Int
    /// Historical effectiveness of this action type for this user
    let historicalEffectiveness: Double?

    /// Model evidence backing this intervention
    let evidence: InterventionEvidence

    enum ActionType: String, Codable {
        case sleepEarlier, sleepLater, extendSleep
        case reduceScreenTime, reduceEvening
        case activeRecovery, intensifyExercise, reduceExercise
        case shiftCaffeineTiming, reduceCaffeine
        case breathingSession, meditation
        case adjustMealTiming, hydration
        case increaseSteps, reduceSteps
        case napRecommendation
    }

    enum InterventionSource: String {
        case predictiveModel, causalDiscovery, circadianTiming
        case stateTransition, anomalyResponse, trendReversal
        case baselineRecovery, counterfactual
    }

    enum TimeToBenefit: Double {
        case immediate = 0.95    // Same day
        case nextDay = 0.85      // Tomorrow
        case twoDays = 0.70      // 2 days
        case threeDays = 0.60    // 3 days
        case oneWeek = 0.40      // ~7 days
        case twoWeeks = 0.25     // ~14 days
    }
}

/// Evidence backing an intervention recommendation
struct InterventionEvidence {
    /// Historical response: how this metric moved when user took similar action
    let historicalResponseMean: Double?
    let historicalResponseCount: Int
    /// Forecasted next-day score delta if action is taken
    let forecastedScoreDelta: Double?
    /// Uncertainty band around the forecast
    let uncertaintyBand: (lower: Double, upper: Double)?
    /// Which features contributed most to this recommendation
    let contributingFeatures: [PredictionFactor]
    /// Granger-causal evidence (if from causal discovery)
    let grangerPValue: Double?
    let grangerEffectSize: Double?
    let grangerOptimalLag: Int?
}

// MARK: - Policy Decision

/// Output of the DecisionPolicyEngine: ranked interventions with rationale
struct PolicyDecision {
    /// The primary recommended action
    let primaryAction: RankedIntervention
    /// Optional secondary supporting action
    let secondaryAction: RankedIntervention?
    /// All evaluated candidates, ranked by expected utility
    let allCandidates: [RankedIntervention]
    /// Why the primary action was chosen
    let rationale: String
    /// Decision confidence (aggregated across models)
    let decisionConfidence: Double
    /// When this decision was made
    let decidedAt: Date

    // MARK: - Prescriptive Language

    /// Bold single-sentence headline for the hero card
    /// e.g. "Push hard today -- your recovery is excellent" or "Take it easy -- prioritize sleep tonight"
    let prescriptiveHeadline: String
    /// Computed optimal bedtime based on strain + sleep debt (e.g. "10:30 PM")
    let targetSleepTime: String?
    /// Suggested exertion level for the day ("High intensity OK" / "Light activity only" / "Moderate effort recommended")
    let strainBudget: String?

    struct RankedIntervention {
        let candidate: InterventionCandidate
        /// Expected utility = uplift * confidence * adherence * novelty * (1 - effort_penalty)
        let expectedUtility: Double
        /// Novelty factor (1.0 = fresh, decays with repeated exposure)
        let noveltyFactor: Double
        /// Generated natural language
        let title: String
        let description: String
        let whyItMatters: String
        let expectedBenefit: String
    }
}

// MARK: - Interaction Feature

/// Cross-metric interaction term for capturing conditional relationships
struct InteractionFeature: Hashable, Codable {
    let metricA: HealthMetric
    let metricB: HealthMetric
    let interactionType: InteractionType

    enum InteractionType: String, Hashable, Codable {
        case product        // A * B (joint effect)
        case ratio          // A / B (relative measure)
        case conditionalHigh // A when B > 1σ
        case conditionalLow  // A when B < -1σ
    }

    var key: String {
        "\(metricA.rawValue)_x_\(metricB.rawValue)_\(interactionType.rawValue)"
    }
}

// MARK: - HMM Smoothed State

/// Health state with HMM-smoothed temporal coherence
struct SmoothedHealthState {
    let date: Date
    /// Hard state assignment from Viterbi
    let assignedState: HealthState
    /// Soft posterior probabilities for each state
    let statePosteriors: [String: Double]
    /// Smoothed transition probability (from forward-backward)
    let smoothedTransitionProb: [String: Double]
    /// Whether this is a state transition day
    let isTransitionDay: Bool
    /// Days since last state transition
    let daysSinceTransition: Int
}

// MARK: - Recommendation Feedback

/// Tracks user response to a recommendation for closed-loop learning
struct RecommendationFeedback: Codable {
    let recommendationId: String
    let actionType: String
    let targetMetric: String
    let shownAt: Date
    let resolvedAt: Date?

    /// Whether the user followed the recommendation (inferred from metric movement)
    let adherenceScore: Double?
    /// Metric delta after recommendation (positive = improvement)
    let metricDelta: Double?
    /// Overall score change
    let overallScoreDelta: Double?
    /// Number of times this type was shown in the past 7 days
    let exposureCount7d: Int

    /// Net uplift: adherence-weighted metric improvement
    var estimatedUplift: Double? {
        guard let adherence = adherenceScore, let delta = metricDelta else { return nil }
        return adherence * delta
    }
}
