import Foundation
import Observation
import os

/// Manages all ML component lifecycle, sequential execution, incremental training, and periodic retraining.
@Observable
final class MLOrchestrator {

    private let logger = Logger(subsystem: "com.healthpulse.ml", category: "MLOrchestrator")

    // MARK: - ML Components

    let featureEngine = FeatureEngine()
    let forecaster = TimeSeriesForecaster()
    let anomalyDetector = AdaptiveAnomalyDetector()
    let patternMiner = PatternMiner()
    let correlationDiscovery = CorrelationDiscovery()
    let stateClassifier = HealthStateClassifier()
    let predictiveScorer = PredictiveScorer()
    let adherenceTracker = AdherenceTracker()
    let circadianAnalyzer = CircadianAnalyzer()

    // MARK: - State

    /// Whether ML analysis has been run at least once
    var hasRunOnce = false
    /// Whether ML is currently running
    var isRunning = false
    /// Last full retrain date
    var lastFullRetrain: Date?

    // MARK: - Results (for AnalysisEngine to consume)

    /// ML-powered anomalies (from forecaster + isolation forest)
    var mlAnomalies: [TimeSeriesForecaster.ForecastAnomaly] = []
    /// Adaptive anomaly results
    var adaptiveAnomalies: [AdaptiveAnomalyDetector.AdaptiveAnomaly] = []
    /// Discovered patterns
    var discoveredPatterns: [DiscoveredPattern] = []
    /// ML-discovered correlations
    var mlCorrelations: [MLCorrelation] = []
    /// Current health state
    var currentHealthState: HealthState?
    /// Tomorrow risk prediction
    var tomorrowRiskPrediction: MLPrediction?

    // MARK: - Cached Feature Vectors

    private let vectorLock = NSLock()
    private var _cachedVectors: [DailyFeatureVector] = []
    private var cachedVectors: [DailyFeatureVector] {
        get { vectorLock.withLock { _cachedVectors } }
        set { vectorLock.withLock { _cachedVectors = newValue } }
    }

    /// Latest feature vector (for simulation engine)
    var latestVector: DailyFeatureVector? { cachedVectors.last }

    /// Full state history from classifier (for Health State Timeline)
    var stateHistory: [(date: Date, label: String)] {
        stateClassifier.isReady ? stateClassifier.stateHistory : []
    }

    /// Transition matrix from classifier (for Health State Timeline)
    var stateTransitionMatrix: [String: [String: Double]] {
        stateClassifier.isReady ? stateClassifier.transitionMatrix : [:]
    }

    /// All identified health states from classifier
    var healthStates: [HealthState] {
        stateClassifier.isReady ? stateClassifier.states : []
    }

    /// Circadian profile (chronotype, peak times)
    var circadianProfile: CircadianAnalyzer.CircadianProfile? { circadianAnalyzer.profile }

    /// Timing recommendations from circadian analysis
    var timingRecommendations: [CircadianAnalyzer.TimingRecommendation] { circadianAnalyzer.recommendations }

    /// Whether circadian analysis should run
    var needsCircadianAnalysis: Bool { circadianAnalyzer.needsAnalysis }

    // MARK: - Run ML Analysis

    /// Run all ML components that are ready. Called from AnalysisEngine after rule-based analysis.
    /// Components run sequentially (one at a time) to avoid CPU spikes, ordered by priority.
    /// Thermal state is checked before starting and between each component.
    func runMLAnalysis(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        scoreHistory: [(date: Date, score: Int)],
        anomalyCounts: [Date: Int]
    ) async {
        // Bail out entirely if device is critically overheated
        if ProcessInfo.processInfo.thermalState == .critical {
            logger.warning("Skipping ML analysis: device thermal state is critical")
            return
        }

        isRunning = true
        defer {
            isRunning = false
            hasRunOnce = true
        }

        // Step 0: Build feature vectors (required by most components)
        let vectors = featureEngine.buildFeatureVectors(
            timeSeries: timeSeries,
            baselines: baselines
        )
        cachedVectors = vectors
        let orderedKeys = featureEngine.orderedKeys

        guard !vectors.isEmpty else { return }

        let totalDays = vectors.count

        // Run components sequentially in priority order to avoid CPU spikes.
        // Between each component, yield briefly and check thermal state.
        // Priority order:
        //   1. FeatureEngine (already ran above — vectors built)
        //   2. TimeSeriesForecaster (anomaly detection)
        //   3. PredictiveScorer (tomorrow prediction)
        //   4. CorrelationDiscovery
        //   5. HealthStateClassifier
        //   6. PatternMiner
        //   7. AdaptiveAnomalyDetector

        // --- 1. TimeSeriesForecaster (21+ days) ---
        if totalDays >= TimeSeriesForecaster.minimumDays {
            if forecaster.needsRetrain || !forecaster.isReady {
                logger.debug("Running TimeSeriesForecaster")
                forecaster.fit(timeSeries: timeSeries)
            }
        }

        try? await Task.sleep(for: .milliseconds(200))
        if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            logger.warning("Stopping ML analysis after TimeSeriesForecaster: thermal state serious or above")
            collectResults(timeSeries: timeSeries, vectors: vectors)
            return
        }

        // --- 2. PredictiveScorer (30+ days) ---
        if totalDays >= PredictiveScorer.minimumDays {
            logger.debug("Running PredictiveScorer")
            predictiveScorer.train(
                vectors: vectors,
                orderedKeys: orderedKeys,
                scoreHistory: scoreHistory,
                anomalyCounts: anomalyCounts
            )
        }

        try? await Task.sleep(for: .milliseconds(200))
        if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            logger.warning("Stopping ML analysis after PredictiveScorer: thermal state serious or above")
            collectResults(timeSeries: timeSeries, vectors: vectors)
            return
        }

        // --- 3. CorrelationDiscovery (30+ days) ---
        if totalDays >= CorrelationDiscovery.minimumDays {
            if correlationDiscovery.needsRetrain || !correlationDiscovery.isReady {
                logger.debug("Running CorrelationDiscovery")
                correlationDiscovery.discover(timeSeries: timeSeries)
            }
        }

        try? await Task.sleep(for: .milliseconds(200))
        if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            logger.warning("Stopping ML analysis after CorrelationDiscovery: thermal state serious or above")
            collectResults(timeSeries: timeSeries, vectors: vectors)
            return
        }

        // --- 4. HealthStateClassifier (60+ days) ---
        if totalDays >= HealthStateClassifier.minimumDays {
            if stateClassifier.needsRetrain || !stateClassifier.isReady {
                logger.debug("Running HealthStateClassifier")
                stateClassifier.train(vectors: vectors, orderedKeys: orderedKeys)
            }
        }

        try? await Task.sleep(for: .milliseconds(200))
        if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            logger.warning("Stopping ML analysis after HealthStateClassifier: thermal state serious or above")
            collectResults(timeSeries: timeSeries, vectors: vectors)
            return
        }

        // --- 5. PatternMiner (60+ days) ---
        if totalDays >= PatternMiner.minimumDays {
            logger.debug("Running PatternMiner")
            patternMiner.mine(timeSeries: timeSeries)
        }

        try? await Task.sleep(for: .milliseconds(200))
        if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            logger.warning("Stopping ML analysis after PatternMiner: thermal state serious or above")
            collectResults(timeSeries: timeSeries, vectors: vectors)
            return
        }

        // --- 6. AdaptiveAnomalyDetector (60+ days) ---
        if totalDays >= AdaptiveAnomalyDetector.minimumDays {
            if anomalyDetector.needsRetrain || !anomalyDetector.isReady {
                logger.debug("Running AdaptiveAnomalyDetector")
                anomalyDetector.train(vectors: vectors, orderedKeys: orderedKeys)
            }
        }

        // Collect results from all components that ran
        collectResults(timeSeries: timeSeries, vectors: vectors)
    }

    // MARK: - Incremental Training

    /// Lightweight daily update without full retrain
    func trainIncremental(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
        todayScore: Int,
        todayAnomalyCount: Int
    ) {
        // Update feature engine
        for (metric, series) in timeSeries {
            if let latest = series.sortedSamples.last {
                featureEngine.updateIncremental(metric: metric, newValue: latest.value)
            }
        }

        // Update forecaster with latest values
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        for (metric, series) in timeSeries {
            if let latest = series.sortedSamples.last {
                forecaster.update(metric: metric, newValue: latest.value, dayOfWeek: weekday)
            }
        }

        // Update predictive scorer
        if let todayVector = cachedVectors.last {
            let wasBadDay = predictiveScorer.determineBadDay(
                todayScore: todayScore,
                tomorrowScore: nil,
                anomalyCount: todayAnomalyCount
            )
            predictiveScorer.trainIncremental(
                todayVector: todayVector,
                wasBadDay: wasBadDay
            )
        }
    }

    // MARK: - Full Retrain

    /// Full retrain of all components (expensive, every 30 days)
    var needsFullRetrain: Bool {
        guard let lastRetrain = lastFullRetrain else { return hasRunOnce }
        return Date().timeIntervalSince(lastRetrain) > 30 * 24 * 3600
    }

    func markFullRetrainComplete() {
        lastFullRetrain = Date()
    }

    // MARK: - Circadian Analysis (separate pipeline, runs weekly)

    /// Run circadian analysis using hourly data. Called separately from the main ML pipeline.
    func runCircadianAnalysis(hourlyData: [HealthMetric: [[Double]]]) {
        guard !hourlyData.isEmpty else { return }
        circadianAnalyzer.analyze(hourlyData: hourlyData)
    }

    // MARK: - Result Collection

    private func collectResults(
        timeSeries: [HealthMetric: MetricTimeSeries],
        vectors: [DailyFeatureVector]
    ) {
        // Forecast anomalies
        if forecaster.isReady {
            mlAnomalies = forecaster.detectAnomalies(timeSeries: timeSeries)
        }

        // Adaptive anomalies (score recent days)
        if anomalyDetector.isReady {
            adaptiveAnomalies = anomalyDetector.scoreRecent(vectors: vectors, days: 7)
        }

        // Patterns
        if patternMiner.isReady {
            discoveredPatterns = patternMiner.patterns
        }

        // Correlations
        if correlationDiscovery.isReady {
            mlCorrelations = correlationDiscovery.correlations
        }

        // Health state
        if stateClassifier.isReady {
            currentHealthState = stateClassifier.currentState
        }

        // Tomorrow prediction
        if predictiveScorer.isReady, let todayVector = vectors.last {
            tomorrowRiskPrediction = predictiveScorer.predict(todayVector: todayVector)
        }
    }

    // MARK: - Insight Generation

    /// Convert ML results into Insight objects for the insights pipeline
    func generateInsights() -> [Insight] {
        var insights: [Insight] = []

        // Pattern insights
        for pattern in discoveredPatterns.prefix(3) {
            insights.append(Insight(
                metric: pattern.metric,
                title: "Discovered \(pattern.patternType.rawValue) Pattern",
                summary: pattern.description,
                recommendation: recommendationForPattern(pattern),
                severity: .info,
                trend: .stable,
                currentValue: 0,
                baselineValue: 0,
                deviationPercent: 0,
                category: .mlPattern,
                context: InsightContext(
                    confidenceLevel: pattern.strength,
                    dataPointCount: cachedVectors.count
                )
            ))
        }

        // Health state insight
        if let state = currentHealthState {
            let severity: Severity = state.label == "Stressed" ? .warning : .info
            let trend: TrendDirection = state.label == "Recovery" ? .improving :
                                        state.label == "Stressed" ? .declining : .stable

            insights.append(Insight(
                metric: .heartRateVariability,
                title: "Current State: \(state.label)",
                summary: "You've been in a \"\(state.label)\" state for \(state.daysInState) day\(state.daysInState == 1 ? "" : "s"). " +
                         describeStateCharacteristics(state),
                recommendation: recommendationForState(state),
                severity: severity,
                trend: trend,
                currentValue: 0,
                baselineValue: 0,
                deviationPercent: 0,
                category: .mlState,
                context: InsightContext(
                    confidenceLevel: 0.7,
                    dataPointCount: cachedVectors.count
                )
            ))
        }

        // Tomorrow prediction insight
        if let prediction = tomorrowRiskPrediction, prediction.confidence >= 0.3 {
            let severity: Severity = prediction.probability > 0.6 ? .warning : .info
            let topRisk = prediction.topFactors.first { $0.isRiskFactor }
            let topProtective = prediction.topFactors.first { !$0.isRiskFactor }

            var summary = "Tomorrow risk: \(prediction.riskLevel) (\(Int(prediction.probability * 100))% probability)."
            if let risk = topRisk {
                summary += " Top risk factor: \(risk.metric.displayName) (\(risk.featureType.rawValue))."
            }
            if let protective = topProtective {
                summary += " Protective: \(protective.metric.displayName)."
            }

            insights.append(Insight(
                metric: topRisk?.metric ?? .heartRateVariability,
                title: "Tomorrow Outlook: \(prediction.riskLevel) Risk",
                summary: summary,
                recommendation: recommendationForPrediction(prediction),
                severity: severity,
                trend: prediction.probability > 0.5 ? .declining : .improving,
                currentValue: prediction.probability,
                baselineValue: 0.3,
                deviationPercent: (prediction.probability - 0.3) / 0.3 * 100,
                category: .mlPrediction,
                context: InsightContext(
                    confidenceLevel: prediction.confidence,
                    dataPointCount: cachedVectors.count
                )
            ))
        }

        // Circadian insights
        if circadianAnalyzer.isReady {
            insights.append(contentsOf: circadianAnalyzer.generateInsights())
        }

        // ML correlation insights (novel discoveries not in the hardcoded 35)
        for corr in mlCorrelations.prefix(3) where corr.grangerCausal {
            insights.append(Insight(
                metric: corr.metricA,
                title: "\(corr.metricA.displayName) Influences \(corr.metricB.displayName)",
                summary: "ML discovered that \(corr.metricA.displayName) has a causal influence on \(corr.metricB.displayName) " +
                         "(Granger p=\(String(format: "%.3f", corr.grangerPValue)), stability: \(Int(corr.stability * 100))%).",
                recommendation: "Monitor your \(corr.metricA.displayName) as it appears to predict changes in \(corr.metricB.displayName).",
                severity: .info,
                trend: .stable,
                currentValue: corr.pearsonR,
                baselineValue: 0,
                deviationPercent: abs(corr.pearsonR) * 100,
                category: .correlation,
                relatedMetrics: [corr.metricB],
                context: InsightContext(
                    confidenceLevel: corr.stability,
                    dataPointCount: corr.sampleCount
                )
            ))
        }

        return insights
    }

    // MARK: - Recommendation Helpers

    private func recommendationForPattern(_ pattern: DiscoveredPattern) -> String {
        switch pattern.patternType {
        case .weekly:
            return "Your \(pattern.metric.displayName) follows a weekly rhythm. Plan demanding activities on your peak days and recovery on your low days."
        case .biweekly:
            return "A 2-week cycle suggests your body may respond to training load accumulation. Consider a deload every 2 weeks."
        case .monthly:
            return "This monthly pattern may relate to hormonal or lifestyle cycles. Track what changes around the cycle peak and trough."
        case .seasonal:
            return "Seasonal patterns are common. Adjust your targets and expectations based on the time of year."
        case .custom:
            return "This unusual pattern is unique to you. Observe what activities or habits align with this \(Int(pattern.periodDays))-day cycle."
        }
    }

    private func describeStateCharacteristics(_ state: HealthState) -> String {
        let notable = state.characteristics.filter { $0.level != .normal }
        guard !notable.isEmpty else { return "All metrics within normal range." }

        let descriptions = notable.prefix(3).map { char in
            "\(char.level.rawValue) \(char.metric.displayName)"
        }
        return "Characterized by: " + descriptions.joined(separator: ", ") + "."
    }

    private func recommendationForState(_ state: HealthState) -> String {
        switch state.label {
        case "Recovery":
            return "You're in a recovery state. This is a good time for light activity and building habits."
        case "Peak Performance":
            return "You're performing well. Take advantage of this state for challenging workouts or demanding days."
        case "Stressed":
            return "Your body shows signs of stress. Prioritize sleep, reduce intensity, and consider mindfulness practices."
        case "Under-Slept":
            return "Sleep deficit detected. Aim for an extra 30-60 minutes tonight and avoid intense exercise."
        case "Active":
            return "High activity detected. Ensure adequate recovery between sessions to prevent overtraining."
        case "Fatigued":
            return "Fatigue signals detected. Consider a rest day or low-intensity active recovery."
        default:
            return "Monitor how you feel and adjust your activity level based on your energy."
        }
    }

    private func recommendationForPrediction(_ prediction: MLPrediction) -> String {
        if prediction.probability > 0.6 {
            let riskFactors = prediction.topFactors.filter { $0.isRiskFactor }.prefix(2)
            let factors = riskFactors.map { "\($0.metric.displayName)" }.joined(separator: " and ")
            return "Higher risk predicted. Focus on \(factors.isEmpty ? "recovery" : "improving " + factors) today to reduce tomorrow's risk."
        } else if prediction.probability > 0.4 {
            return "Moderate risk. Maintain your current routine and prioritize consistent sleep tonight."
        } else {
            return "Low risk predicted. You're on track for a good day tomorrow."
        }
    }
}
