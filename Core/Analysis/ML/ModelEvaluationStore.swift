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

// MARK: - Evaluation Engine

/// Computes evaluation metrics for each ML component type.
/// All methods are pure functions. no state, no side effects.
enum ModelEvaluationEngine {

    // MARK: - Classification Metrics (PredictiveScorer)

    /// Full classification evaluation for binary predictions (e.g., PredictiveScorer's P(bad day)).
    struct ClassificationMetrics {
        let accuracy: Double
        let precision: Double
        let recall: Double
        let f1Score: Double
        let brierScore: Double              // Mean squared error of probability estimates
        let calibrationError: Double        // Expected Calibration Error (ECE) with 10 bins
        let sampleCount: Int
        let truePositiveRate: Double
        let falsePositiveRate: Double
    }

    /// Evaluate a binary classifier given predicted probabilities and actual outcomes.
    /// Returns nil if fewer than 10 predictions are provided.
    static func evaluateClassifier(
        predictions: [(probability: Double, actualOutcome: Bool)],
        threshold: Double = 0.5
    ) -> ClassificationMetrics? {
        guard predictions.count >= 10 else { return nil }

        var tp = 0, fp = 0, tn = 0, fn = 0
        var brierSum = 0.0

        for pred in predictions {
            let predicted = pred.probability >= threshold
            let actual = pred.actualOutcome
            let label = actual ? 1.0 : 0.0
            let diff = pred.probability - label
            brierSum += diff * diff

            if predicted && actual { tp += 1 }
            else if predicted && !actual { fp += 1 }
            else if !predicted && actual { fn += 1 }
            else { tn += 1 }
        }

        let n = Double(predictions.count)
        let accuracy = Double(tp + tn) / n

        let precision: Double
        if tp + fp > 0 {
            precision = Double(tp) / Double(tp + fp)
        } else {
            precision = 0
        }

        let recall: Double
        if tp + fn > 0 {
            recall = Double(tp) / Double(tp + fn)
        } else {
            recall = 0
        }

        let f1: Double
        if precision + recall > 0 {
            f1 = 2.0 * precision * recall / (precision + recall)
        } else {
            f1 = 0
        }

        let brierScore = brierSum / n

        let truePositiveRate = recall
        let falsePositiveRate: Double
        if fp + tn > 0 {
            falsePositiveRate = Double(fp) / Double(fp + tn)
        } else {
            falsePositiveRate = 0
        }

        // Expected Calibration Error
        let calibrationBins = calibrationCurve(predictions: predictions, bins: 10)
        let ece = computeECE(bins: calibrationBins, totalCount: predictions.count)

        return ClassificationMetrics(
            accuracy: accuracy,
            precision: precision,
            recall: recall,
            f1Score: f1,
            brierScore: brierScore,
            calibrationError: ece,
            sampleCount: predictions.count,
            truePositiveRate: truePositiveRate,
            falsePositiveRate: falsePositiveRate
        )
    }

    // MARK: - Forecast Metrics (TimeSeriesForecaster)

    /// Regression metrics for time-series forecast evaluation.
    struct ForecastMetrics {
        let metric: HealthMetric
        let mae: Double                     // Mean Absolute Error
        let mape: Double                    // Mean Absolute Percentage Error
        let rmse: Double                    // Root Mean Squared Error
        let coverageRate: Double            // Fraction of actuals within prediction interval
        let sampleCount: Int
    }

    /// Evaluate time-series forecasts by comparing predicted vs actual values.
    /// Groups by metric and returns one `ForecastMetrics` per metric with at least 5 data points.
    static func evaluateForecaster(
        predictions: [(predicted: Double, actual: Double, metric: HealthMetric)]
    ) -> [ForecastMetrics] {
        // Group by metric
        var grouped: [HealthMetric: [(predicted: Double, actual: Double)]] = [:]
        for pred in predictions {
            grouped[pred.metric, default: []].append((pred.predicted, pred.actual))
        }

        var results: [ForecastMetrics] = []

        for (metric, pairs) in grouped {
            guard pairs.count >= 5 else { continue }

            let n = Double(pairs.count)
            var sumAE = 0.0
            var sumSE = 0.0
            var sumAPE = 0.0
            var validAPECount = 0

            for pair in pairs {
                let error = pair.actual - pair.predicted
                sumAE += abs(error)
                sumSE += error * error

                if abs(pair.actual) > 1e-9 {
                    sumAPE += abs(error / pair.actual)
                    validAPECount += 1
                }
            }

            let mae = sumAE / n
            let rmse = (sumSE / n).squareRoot()
            let mape = validAPECount > 0 ? sumAPE / Double(validAPECount) : 0

            // Coverage: use simple +-1 RMSE as a proxy prediction interval
            // (actual coverage evaluation requires the CI from the forecaster)
            let coverageRate = 0.0 // Placeholder. populated when intervals are provided

            results.append(ForecastMetrics(
                metric: metric,
                mae: mae,
                mape: mape,
                rmse: rmse,
                coverageRate: coverageRate,
                sampleCount: pairs.count
            ))
        }

        return results
    }

    /// Evaluate forecasts with prediction intervals for coverage rate computation.
    static func evaluateForecasterWithIntervals(
        predictions: [(predicted: Double, actual: Double, intervalWidth: Double, metric: HealthMetric)]
    ) -> [ForecastMetrics] {
        var grouped: [HealthMetric: [(predicted: Double, actual: Double, intervalWidth: Double)]] = [:]
        for pred in predictions {
            grouped[pred.metric, default: []].append((pred.predicted, pred.actual, pred.intervalWidth))
        }

        var results: [ForecastMetrics] = []

        for (metric, pairs) in grouped {
            guard pairs.count >= 5 else { continue }

            let n = Double(pairs.count)
            var sumAE = 0.0
            var sumSE = 0.0
            var sumAPE = 0.0
            var validAPECount = 0
            var coveredCount = 0

            for pair in pairs {
                let error = pair.actual - pair.predicted
                sumAE += abs(error)
                sumSE += error * error

                if abs(pair.actual) > 1e-9 {
                    sumAPE += abs(error / pair.actual)
                    validAPECount += 1
                }

                // Check if actual falls within [predicted - halfWidth, predicted + halfWidth]
                let halfWidth = pair.intervalWidth / 2.0
                if pair.actual >= pair.predicted - halfWidth &&
                    pair.actual <= pair.predicted + halfWidth {
                    coveredCount += 1
                }
            }

            let mae = sumAE / n
            let rmse = (sumSE / n).squareRoot()
            let mape = validAPECount > 0 ? sumAPE / Double(validAPECount) : 0
            let coverageRate = Double(coveredCount) / n

            results.append(ForecastMetrics(
                metric: metric,
                mae: mae,
                mape: mape,
                rmse: rmse,
                coverageRate: coverageRate,
                sampleCount: pairs.count
            ))
        }

        return results
    }

    // MARK: - Cluster Metrics (HealthStateClassifier)

    /// Quality metrics for clustering output.
    struct ClusterMetrics {
        let silhouetteScore: Double         // -1 to 1, higher = better separation
        let numClusters: Int
        let averageClusterSize: Double
        let smallestClusterSize: Int
        let stabilityVsPrevious: Double     // 0 = identical, 1 = completely different
    }

    /// Evaluate clustering quality using silhouette score and cluster statistics.
    /// `previousAssignments` enables stability tracking across retrain cycles.
    static func evaluateClustering(
        assignments: [(vector: [Double], clusterLabel: Int)],
        centroids: [[Double]],
        previousAssignments: [(vector: [Double], clusterLabel: Int)]?
    ) -> ClusterMetrics? {
        let k = centroids.count
        guard k >= 2, assignments.count > k else { return nil }

        // Compute silhouette score (sampled for performance)
        let silhouette = computeSilhouetteScore(
            assignments: assignments, centroids: centroids
        )

        // Cluster sizes
        var clusterSizes = [Int](repeating: 0, count: k)
        for item in assignments {
            if item.clusterLabel < k {
                clusterSizes[item.clusterLabel] += 1
            }
        }
        let averageSize = Double(assignments.count) / Double(k)
        let smallestSize = clusterSizes.min() ?? 0

        // Stability vs previous assignments
        let stability: Double
        if let previous = previousAssignments, !previous.isEmpty {
            stability = computeClusterStability(
                current: assignments, previous: previous, k: k
            )
        } else {
            stability = 0 // No previous. perfectly stable by default
        }

        return ClusterMetrics(
            silhouetteScore: silhouette,
            numClusters: k,
            averageClusterSize: averageSize,
            smallestClusterSize: smallestSize,
            stabilityVsPrevious: stability
        )
    }

    /// Compute sampled silhouette score (max 150 points for performance).
    private static func computeSilhouetteScore(
        assignments: [(vector: [Double], clusterLabel: Int)],
        centroids: [[Double]]
    ) -> Double {
        let n = assignments.count
        let k = centroids.count
        guard n > k, k > 1 else { return 0 }

        // Sample for performance
        let sampleIndices: [Int]
        if n > 150 {
            sampleIndices = Array((0..<n).shuffled().prefix(150))
        } else {
            sampleIndices = Array(0..<n)
        }

        var totalSilhouette = 0.0
        var count = 0

        for i in sampleIndices {
            let cluster = assignments[i].clusterLabel
            let point = assignments[i].vector

            // a(i) = mean distance to same-cluster members
            var sameClusterDists: [Double] = []
            for j in 0..<n where assignments[j].clusterLabel == cluster && j != i {
                sameClusterDists.append(
                    AccelerateML.euclideanDistance(point, assignments[j].vector)
                )
            }
            guard !sameClusterDists.isEmpty else { continue }
            let a = sameClusterDists.mean

            // b(i) = min mean distance to any other cluster
            var minB = Double.infinity
            for c in 0..<k where c != cluster {
                let otherDists = (0..<n)
                    .filter { assignments[$0].clusterLabel == c }
                    .map { AccelerateML.euclideanDistance(point, assignments[$0].vector) }
                guard !otherDists.isEmpty else { continue }
                minB = Swift.min(minB, otherDists.mean)
            }

            guard minB.isFinite else { continue }
            let s = (minB - a) / Swift.max(a, minB)
            totalSilhouette += s
            count += 1
        }

        return count > 0 ? totalSilhouette / Double(count) : 0
    }

    /// Measure how much cluster assignments changed between retrains.
    /// Uses Normalized Mutual Information (NMI) approximation.
    /// Returns 0 for identical, 1 for completely different.
    private static func computeClusterStability(
        current: [(vector: [Double], clusterLabel: Int)],
        previous: [(vector: [Double], clusterLabel: Int)],
        k: Int
    ) -> Double {
        // Match current vectors to closest previous vectors and compare labels.
        // Since vectors may differ between retrains, match by position index
        // (both are chronologically ordered daily vectors).
        let n = Swift.min(current.count, previous.count)
        guard n > 0 else { return 1.0 }

        // Build a mapping from previous cluster labels to current labels
        // via the most common co-occurrence (Hungarian matching approximation).
        var cooccurrence = [[Int]](
            repeating: [Int](repeating: 0, count: k), count: k
        )

        for i in 0..<n {
            let prevLabel = previous[i].clusterLabel
            let currLabel = current[i].clusterLabel
            if prevLabel < k && currLabel < k {
                cooccurrence[prevLabel][currLabel] += 1
            }
        }

        // Greedy best-match: for each previous cluster, find the current cluster
        // with the most overlap.
        var matchedCount = 0
        var usedCurrent = Set<Int>()

        // Sort previous clusters by size (largest first) for greedy assignment
        let prevClusters = (0..<k).sorted { a, b in
            cooccurrence[a].reduce(0, +) > cooccurrence[b].reduce(0, +)
        }

        for prevCluster in prevClusters {
            var bestCurrent = -1
            var bestCount = 0
            for c in 0..<k where !usedCurrent.contains(c) {
                if cooccurrence[prevCluster][c] > bestCount {
                    bestCount = cooccurrence[prevCluster][c]
                    bestCurrent = c
                }
            }
            if bestCurrent >= 0 {
                matchedCount += bestCount
                usedCurrent.insert(bestCurrent)
            }
        }

        let agreementRate = Double(matchedCount) / Double(n)
        return 1.0 - agreementRate
    }

    // MARK: - Anomaly Detection Metrics (AdaptiveAnomalyDetector)

    /// Evaluation metrics for anomaly detection quality.
    struct AnomalyMetrics {
        let totalFlagged: Int
        let estimatedFalsePositiveRate: Double   // Anomalies that self-resolved within 1 day
        let persistentAnomalyRate: Double        // Anomalies that persisted 2+ days
        let averageSeverity: Double
    }

    /// Evaluate anomaly detector quality by checking whether flagged anomalies persist.
    /// An anomaly that disappears the next day without intervention is likely a false positive.
    static func evaluateAnomalyDetector(
        flaggedDates: [(date: Date, metric: HealthMetric, severity: Severity)],
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> AnomalyMetrics? {
        guard !flaggedDates.isEmpty else { return nil }

        let calendar = Date.cal
        var selfResolved = 0
        var persistent = 0
        var severitySum = 0.0

        for flagged in flaggedDates {
            let severityValue: Double
            switch flagged.severity {
            case .info: severityValue = 0.25
            case .warning: severityValue = 0.5
            case .critical: severityValue = 1.0
            }
            severitySum += severityValue

            // Check if the metric returned to baseline the next day
            guard let series = timeSeries[flagged.metric],
                  let baseline = baselines[flagged.metric] else {
                continue
            }

            let nextDay = calendar.date(byAdding: .day, value: 1, to: flagged.date) ?? flagged.date
            let nextDayStart = calendar.startOfDay(for: nextDay)
            let nextDayEnd = calendar.date(byAdding: .day, value: 1, to: nextDayStart) ?? nextDayStart

            // Find next-day value
            let nextDaySamples = series.samples.filter {
                $0.date >= nextDayStart && $0.date < nextDayEnd
            }

            guard let nextValue = nextDaySamples.first?.value else { continue }

            let deviation = abs(nextValue - baseline.mean) / Swift.max(baseline.standardDeviation, 1e-9)
            if deviation < 1.5 {
                // Returned to within 1.5 SD of baseline. likely false positive
                selfResolved += 1
            } else {
                persistent += 1
            }
        }

        let evaluated = selfResolved + persistent
        let fpRate = evaluated > 0 ? Double(selfResolved) / Double(evaluated) : 0
        let persistRate = evaluated > 0 ? Double(persistent) / Double(evaluated) : 0
        let avgSeverity = severitySum / Double(flaggedDates.count)

        return AnomalyMetrics(
            totalFlagged: flaggedDates.count,
            estimatedFalsePositiveRate: fpRate,
            persistentAnomalyRate: persistRate,
            averageSeverity: avgSeverity
        )
    }

    // MARK: - Calibration Curve

    /// A single bin in a calibration curve.
    struct CalibrationBin {
        let binCenter: Double               // e.g., 0.05, 0.15, ..., 0.95
        let predictedMean: Double           // Average predicted probability in this bin
        let observedFrequency: Double       // Actual positive rate in this bin
        let count: Int                      // Number of predictions in this bin
    }

    /// Compute a calibration curve with equal-width bins.
    /// Bins are [0, 0.1), [0.1, 0.2), ..., [0.9, 1.0].
    static func calibrationCurve(
        predictions: [(probability: Double, actualOutcome: Bool)],
        bins: Int = 10
    ) -> [CalibrationBin] {
        guard !predictions.isEmpty, bins > 0 else { return [] }

        let binWidth = 1.0 / Double(bins)
        var binPredictions: [[Double]] = Array(repeating: [], count: bins)
        var binOutcomes: [[Bool]] = Array(repeating: [], count: bins)

        for pred in predictions {
            let clamped = Swift.max(0, Swift.min(pred.probability, 1.0))
            var binIndex = Int(clamped / binWidth)
            // The value 1.0 should go into the last bin
            if binIndex >= bins { binIndex = bins - 1 }

            binPredictions[binIndex].append(clamped)
            binOutcomes[binIndex].append(pred.actualOutcome)
        }

        var result: [CalibrationBin] = []
        for i in 0..<bins {
            let center = (Double(i) + 0.5) * binWidth
            let count = binPredictions[i].count

            let predictedMean: Double
            let observedFrequency: Double

            if count > 0 {
                predictedMean = binPredictions[i].mean
                let positives = binOutcomes[i].filter { $0 }.count
                observedFrequency = Double(positives) / Double(count)
            } else {
                predictedMean = center
                observedFrequency = 0
            }

            result.append(CalibrationBin(
                binCenter: center,
                predictedMean: predictedMean,
                observedFrequency: observedFrequency,
                count: count
            ))
        }

        return result
    }

    /// Expected Calibration Error: weighted average of |predicted - observed| per bin.
    /// Weight = fraction of total predictions in that bin.
    private static func computeECE(bins: [CalibrationBin], totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }

        var ece = 0.0
        for bin in bins where bin.count > 0 {
            let weight = Double(bin.count) / Double(totalCount)
            ece += weight * abs(bin.predictedMean - bin.observedFrequency)
        }
        return ece
    }

    // MARK: - Persistence Helpers

    /// Convert classification metrics into an array of `StoredModelEvaluation` rows for persistence.
    static func persistableEntries(
        componentName: String,
        classification: ClassificationMetrics,
        windowDays: Int
    ) -> [StoredModelEvaluation] {
        let now = Date()
        let count = classification.sampleCount
        return [
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "accuracy", metricValue: classification.accuracy,
                                  sampleCount: count, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "precision", metricValue: classification.precision,
                                  sampleCount: count, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "recall", metricValue: classification.recall,
                                  sampleCount: count, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "f1_score", metricValue: classification.f1Score,
                                  sampleCount: count, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "brier_score", metricValue: classification.brierScore,
                                  sampleCount: count, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "calibration_error", metricValue: classification.calibrationError,
                                  sampleCount: count, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "false_positive_rate", metricValue: classification.falsePositiveRate,
                                  sampleCount: count, windowDays: windowDays),
        ]
    }

    /// Convert forecast metrics into persistable entries.
    static func persistableEntries(
        componentName: String,
        forecast: ForecastMetrics,
        windowDays: Int
    ) -> [StoredModelEvaluation] {
        let now = Date()
        let count = forecast.sampleCount
        let suffix = "_\(forecast.metric.rawValue)"
        return [
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "mae" + suffix, metricValue: forecast.mae,
                                  sampleCount: count, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "mape" + suffix, metricValue: forecast.mape,
                                  sampleCount: count, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "rmse" + suffix, metricValue: forecast.rmse,
                                  sampleCount: count, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "coverage" + suffix, metricValue: forecast.coverageRate,
                                  sampleCount: count, windowDays: windowDays),
        ]
    }

    /// Convert cluster metrics into persistable entries.
    static func persistableEntries(
        componentName: String,
        cluster: ClusterMetrics,
        sampleCount: Int,
        windowDays: Int
    ) -> [StoredModelEvaluation] {
        let now = Date()
        return [
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "silhouette", metricValue: cluster.silhouetteScore,
                                  sampleCount: sampleCount, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "num_clusters", metricValue: Double(cluster.numClusters),
                                  sampleCount: sampleCount, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "smallest_cluster", metricValue: Double(cluster.smallestClusterSize),
                                  sampleCount: sampleCount, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "stability", metricValue: cluster.stabilityVsPrevious,
                                  sampleCount: sampleCount, windowDays: windowDays),
        ]
    }

    /// Convert anomaly metrics into persistable entries.
    static func persistableEntries(
        componentName: String,
        anomaly: AnomalyMetrics,
        windowDays: Int
    ) -> [StoredModelEvaluation] {
        let now = Date()
        return [
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "false_positive_rate", metricValue: anomaly.estimatedFalsePositiveRate,
                                  sampleCount: anomaly.totalFlagged, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "persistent_anomaly_rate", metricValue: anomaly.persistentAnomalyRate,
                                  sampleCount: anomaly.totalFlagged, windowDays: windowDays),
            StoredModelEvaluation(componentName: componentName, evaluationDate: now,
                                  metricName: "average_severity", metricValue: anomaly.averageSeverity,
                                  sampleCount: anomaly.totalFlagged, windowDays: windowDays),
        ]
    }
}
