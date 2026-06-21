import Foundation

/// Persists the onboarding answers that `persistOnboardingProfile` used to
/// discard (symptoms) plus the pre-registered prediction,
/// so the cliffhanger payoff (answer-ready push) and the denied-branch
/// re-permission hook can restate the user's own words later. Static-func +
/// JSONEncoder pattern mirrors MorningCheckInManager.
enum OnboardingPredictionStore {

    /// Snapshot of the onboarding answers that were previously dropped. Raw
    /// string arrays keep this Core type free of onboarding module imports.
    struct CapturedAnswers: Codable {
        let symptomKeys: [String]
    }

    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    // MARK: - Prediction

    static func savePrediction(_ prediction: PreRegisteredPrediction) {
        guard let data = try? jsonEncoder.encode(prediction) else { return }
        UserDefaults.standard.set(data, forKey: AppKeys.Prediction.registered)
    }

    static func loadPrediction() -> PreRegisteredPrediction? {
        guard let data = UserDefaults.standard.data(forKey: AppKeys.Prediction.registered),
              let prediction = try? jsonDecoder.decode(PreRegisteredPrediction.self, from: data) else {
            return nil
        }
        return prediction
    }

    // MARK: - Captured answers

    static func saveAnswers(_ answers: CapturedAnswers) {
        guard let data = try? jsonEncoder.encode(answers) else { return }
        UserDefaults.standard.set(data, forKey: AppKeys.Prediction.capturedAnswers)
    }

    static func loadAnswers() -> CapturedAnswers? {
        guard let data = UserDefaults.standard.data(forKey: AppKeys.Prediction.capturedAnswers),
              let answers = try? jsonDecoder.decode(CapturedAnswers.self, from: data) else {
            return nil
        }
        return answers
    }
}
