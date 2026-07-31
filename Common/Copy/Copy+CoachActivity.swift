import Foundation

extension Copy {
    /// Insight sentences the Today's Score Live Activity carries in its
    /// ContentState. Resolved app-side in `TodayScoreLiveActivityManager` before
    /// the push, so Remote Config works even though the widget target has no
    /// Firebase: the widget only renders the finished string.
    enum CoachActivity {

        // MARK: - Readiness phrases (morning act, by score band)

        static var strongRecovery: String { RemoteConfigManager.shared.copyString("copy_coach_activity_strong_recovery", default: "Strong recovery") }
        static var solidBase: String { RemoteConfigManager.shared.copyString("copy_coach_activity_solid_base", default: "Solid base") }
        static var moderateRecovery: String { RemoteConfigManager.shared.copyString("copy_coach_activity_moderate_recovery", default: "Moderate recovery") }
        static var goGentle: String { RemoteConfigManager.shared.copyString("copy_coach_activity_go_gentle", default: "Go gentle today") }

        // MARK: - Morning act

        /// `%1$d` HRV in ms, `%2$@` the readiness phrase above.
        static func morningWithHRV(hrvMs: Int, phrase: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_coach_activity_morning_hrv", default: "HRV %1$d ms. %2$@."), hrvMs, phrase)
        }

        /// `%@` is the readiness phrase.
        static func morningNoHRV(phrase: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_coach_activity_morning_no_hrv", default: "%@. Set the tone for today."), phrase)
        }

        // MARK: - Day act

        static var dayLight: String { RemoteConfigManager.shared.copyString("copy_coach_activity_day_light", default: "Light load so far. Small movement helps.") }
        static var daySteady: String { RemoteConfigManager.shared.copyString("copy_coach_activity_day_steady", default: "Steady strain. One short reset keeps you sharp.") }
        static var dayHigh: String { RemoteConfigManager.shared.copyString("copy_coach_activity_day_high", default: "High strain today. A 2 minute reset will help.") }

        // MARK: - Evening act

        /// `%@` is the recommended bedtime, already formatted as a local time.
        static func eveningBedtime(time: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_coach_activity_evening_bedtime", default: "In bed by %@ sets up tomorrow."), time)
        }

        /// `%@` is the weakest pillar's display name.
        static func eveningWeakest(pillar: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_coach_activity_evening_weakest", default: "Weakest today: %@. Wind down supports tomorrow."), pillar)
        }

        static var eveningGeneric: String { RemoteConfigManager.shared.copyString("copy_coach_activity_evening_generic", default: "Wind down now to set up a strong tomorrow.") }

        // MARK: - Night act

        /// `%d` is the resting heart rate in bpm.
        static func nightRestingHR(bpm: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_coach_activity_night_rhr", default: "Resting heart rate %d. Resume at sunrise."), bpm)
        }

        static var nightGeneric: String { RemoteConfigManager.shared.copyString("copy_coach_activity_night_generic", default: "Sleep in progress. Resume at sunrise.") }

        // MARK: - Guardian alerts

        /// `%1$d` current resting HR, `%2$d` the 7 day average.
        static func alertRestingHR(current: Int, baseline: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_coach_activity_alert_rhr", default: "Resting heart rate %1$d is above your usual %2$d. Two slow minutes can help."), current, baseline)
        }

        static var alertSleepDebt: String { RemoteConfigManager.shared.copyString("copy_coach_activity_alert_sleep_debt", default: "An earlier night tonight starts paying it back.") }
    }
}
