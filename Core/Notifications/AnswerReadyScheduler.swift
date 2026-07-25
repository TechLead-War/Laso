import Foundation
import UserNotifications

/// Journey 4: the cliffhanger payoff.
///
/// During onboarding a user with too little data lands on the cliffhanger
/// screen, where a still-inconclusive prediction is persisted. This scheduler
/// re-runs the verdict engine against the live health store on each background
/// refresh; the first time the prediction matures from inconclusive to a real
/// verdict (confirmed or refuted) it fires the strongest push. A one-shot flag
/// stops it ever firing twice.
///
/// `HealthDataStore` is `@MainActor`, so `checkAndFire` is too. The caller
/// already runs inside the background MainActor block.
@MainActor
enum AnswerReadyScheduler {

    /// Evaluate the stored prediction against live data and fire once if it has
    /// matured. Cheap no-op when there is no stored prediction, the answer push
    /// already fired, or the prediction is still inconclusive.
    static func checkAndFire(store: HealthDataStore?) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: AppKeys.Prediction.answerReadyFired) else { return }
        guard let store else { return }
        guard let prediction = OnboardingPredictionStore.loadPrediction() else { return }

        let history = liveHistory(store: store)
        let verdict = PredictionVerdictEngine.evaluate(prediction: prediction, history: history)

        // Only a matured verdict is news. Inconclusive means the answer is still
        // not ready, so we wait for a later refresh.
        guard verdict.zone != .inconclusive else { return }

        // Await the real authorization state instead of trusting the launch-time
        // cache (cold at first render), and burn the one-shot flag only after
        // the schedule actually passed every gate — a suppressed attempt stays
        // retryable on the next refresh.
        Task {
            guard await NotificationManager.shared.isCurrentlyAuthorized() else { return }
            let scheduled = NotificationManager.shared.scheduleNotification(
                title: Copy.Notifications.answerReadyTitle(phrase: prediction.userPhrase),
                body: Copy.Notifications.answerReadyBody(phrase: prediction.userPhrase),
                identifier: AppConstants.NotificationID.answerReady,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false),
                severity: .info,
                metricInFocus: true
            )
            if scheduled {
                defaults.set(true, forKey: AppKeys.Prediction.answerReadyFired)
            }
        }
    }

    /// Build the engine's `[PredictionMetric: [MetricSample]]` history from the
    /// live store. Only the predicted metric and the two side-discovery metrics
    /// are loaded, matching what `evaluate` reads.
    ///
    /// The live store keeps `.sleepDuration` in HOURS, but the engine's sleep
    /// floor and banding are defined in MINUTES (the onboarding snapshot already
    /// feeds it minutes). Convert here so the verdict is computed in the same
    /// unit regardless of source; skipping this would shrink a real one-hour
    /// effect to 1.0 and never confirm.
    private static func liveHistory(store: HealthDataStore) -> [PredictionMetric: [MetricSample]] {
        var history: [PredictionMetric: [MetricSample]] = [:]
        for metric in PredictionMetric.allCases {
            guard let series = store.loadTimeSeries(for: metric.healthMetric) else { continue }
            if metric == .sleepDuration {
                history[metric] = series.samples.map {
                    MetricSample(date: $0.date, value: $0.value * 60.0)
                }
            } else {
                history[metric] = series.samples
            }
        }
        return history
    }
}

private extension PredictionMetric {
    /// The store-side `HealthMetric` whose raw daily samples feed this
    /// prediction. Raw values are identical across the two enums, but the map is
    /// explicit so a future rename in either enum fails loudly here rather than
    /// silently reading the wrong series.
    var healthMetric: HealthMetric {
        switch self {
        case .sleepDuration: return .sleepDuration
        case .heartRateVariability: return .heartRateVariability
        case .restingHeartRate: return .restingHeartRate
        }
    }
}
