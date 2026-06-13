import Foundation

/// Builds the pre-registered prediction from the user's onboarding answers,
/// BEFORE any health data is read. Lives in Core (not the onboarding module)
/// so the verdict engine and the persistence store never depend on UI types.
/// Keys are raw strings (OnbV2Symptom.rawValue / OnbV2Goal.rawValue), matching
/// PreRegisteredPrediction's String fields and the InsightConfig mapping table.
enum PredictionBuilder {

    /// Returns the claim to test, or nil when neither the symptom nor the goal
    /// maps to a testable metric (caller routes such users down a non-verdict
    /// branch). `phrase` is the user's own words, restated verbatim in copy.
    static func makePrediction(
        symptomKey: String?,
        symptomPhrase: String?,
        goalKey: String?,
        goalPhrase: String?
    ) -> PreRegisteredPrediction? {
        // Symptom is the felt complaint the user most wants explained, so it
        // wins over the goal when it maps to a metric.
        if let symptomKey,
           let metric = InsightConfig.PredictionMapping.symptomToMetric[symptomKey] {
            return PreRegisteredPrediction(
                metric: metric,
                direction: metric.worseDirection,
                userGoalKey: goalKey,
                userSymptomKey: symptomKey,
                userPhrase: symptomPhrase ?? goalPhrase ?? ""
            )
        }

        if let goalKey,
           let metric = InsightConfig.PredictionMapping.goalToMetric[goalKey] {
            return PreRegisteredPrediction(
                metric: metric,
                direction: metric.worseDirection,
                userGoalKey: goalKey,
                userSymptomKey: symptomKey,
                userPhrase: goalPhrase ?? symptomPhrase ?? ""
            )
        }

        return nil
    }
}
