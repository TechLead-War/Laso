import Foundation

final class MLCalibrationManager {

    func calibratePrediction(
        prediction: MLPrediction,
        todayVector: DailyFeatureVector,
        vectors: [DailyFeatureVector],
        evaluationSummaries: [String: ComponentEvaluation],
        conformalCalibrator: ConformalCalibrator,
        mlEvaluator: MLEvaluator
    ) -> MLPrediction {
        let populationPrediction = PersonalizationBlender.populationPrediction(
            from: todayVector
        )
        let (blendedProb, _) = PersonalizationBlender.blendPrediction(
            personalPrediction: prediction.probability,
            populationPrediction: populationPrediction,
            userDataDays: vectors.count
        )

        // PredictiveScorer now internally applies Platt calibration during predict(),
        // so blendedProb is already calibrated. Only apply temperature scaling if
        // evaluation data shows persistent miscalibration (ECE > 0.10).
        var calibratedProb = blendedProb
        if let eval = evaluationSummaries["PredictiveScorer"],
           let ece = eval.ece, ece > 0.10,
           eval.sampleCount >= 20 {
            let logit = log(max(blendedProb, 1e-10) / max(1 - blendedProb, 1e-10))
            let tempT = conformalCalibrator.temperatureScale(
                logits: [logit], labels: [blendedProb > 0.5 ? 1.0 : 0.0]
            )
            calibratedProb = conformalCalibrator.calibrateWithTemperature(logit: logit, T: tempT)
        }

        let calibrated = MLPrediction(
            target: prediction.target,
            probability: calibratedProb,
            confidence: prediction.confidence,
            topFactors: prediction.topFactors
        )

        // Record evaluation event for this prediction
        let version = ModelVersion(
            componentName: "PredictiveScorer",
            modelVersion: 2,
            featureSchemaVersion: 2,
            calibrationVersion: 1,
            trainedAt: Date(),
            dataPointsUsed: vectors.count
        )
        _ = mlEvaluator.recordPrediction(
            componentName: "PredictiveScorer",
            modelVersion: version,
            horizon: .nextDay,
            targetMetric: "overallScore",
            predictedValue: calibratedProb,
            probability: calibratedProb,
            confidence: prediction.confidence
        )

        return calibrated
    }
}
