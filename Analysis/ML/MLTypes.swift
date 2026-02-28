import Foundation

// MARK: - Daily Feature Vector

/// A standardized feature vector for a single day, containing raw and derived features for all available metrics
struct DailyFeatureVector {
    let date: Date
    /// Per-metric features keyed by FeatureKey (metric + feature type)
    var features: [FeatureKey: Double]
    /// Contextual features (day-of-week, month, weekend)
    var context: ContextFeatures

    /// Number of metrics with data on this day
    var metricCount: Int {
        Set(features.keys.map(\.metric)).count
    }

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
        let calendar = Calendar.current
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
        case 0.7...: return "High"
        case 0.5..<0.7: return "Moderate"
        case 0.3..<0.5: return "Low"
        default: return "Very Low"
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

    /// Decode parameters as a specific type
    func decodeParameters<T: Decodable>(_ type: T.Type) -> T? {
        try? JSONDecoder().decode(type, from: parametersJSON)
    }

    /// Create a model state with encodable parameters
    static func create<T: Encodable>(
        componentName: String,
        version: Int,
        parameters: T,
        dataPointsUsed: Int
    ) -> MLModelState? {
        guard let json = try? JSONEncoder().encode(parameters) else { return nil }
        return MLModelState(
            componentName: componentName,
            version: version,
            parametersJSON: json,
            dataPointsUsed: dataPointsUsed,
            lastTrainedDate: Date()
        )
    }
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

    enum PatternType: String, Codable {
        case weekly         // 7-day cycle
        case biweekly       // 14-day cycle
        case monthly        // ~28-30 day cycle
        case seasonal       // ~90 day cycle
        case custom         // Non-standard period
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

    /// Whether this correlation is statistically significant
    var isSignificant: Bool {
        abs(pearsonR) >= 0.25 || mutualInformation > 0.1 || grangerCausal
    }

    /// Overall strength combining linear and non-linear measures
    var overallStrength: Double {
        max(abs(pearsonR), mutualInformation * 2.0)
    }
}
