import Foundation
import SwiftData

// MARK: - SwiftData Model for Persisted Evaluations

/// Stores a single evaluation metric for an ML component at a point in time.
/// Multiple rows per component per evaluation (one per metric name).
@Model
final class StoredModelEvaluation {
    var componentName: String
    var evaluationDate: Date
    var metricName: String        // "accuracy", "mae", "calibration_error", "silhouette", "false_positive_rate"
    var metricValue: Double
    var sampleCount: Int
    var windowDays: Int           // Evaluation window (e.g., 7, 30, 90 days)

    init(componentName: String, evaluationDate: Date, metricName: String,
         metricValue: Double, sampleCount: Int, windowDays: Int) {
        self.componentName = componentName
        self.evaluationDate = evaluationDate
        self.metricName = metricName
        self.metricValue = metricValue
        self.sampleCount = sampleCount
        self.windowDays = windowDays
    }
}
