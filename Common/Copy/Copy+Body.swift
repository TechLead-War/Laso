import Foundation

extension Copy {
    /// Every string on the Body tab. Defaults are the approved reference
    /// strings from `LASO_DIRECTION_PROPOSAL.html`.
    enum Body {

        static var title: String { RemoteConfigManager.shared.copyString("copy_body_title", default: "Body") }
        static var subtitle: String { RemoteConfigManager.shared.copyString("copy_body_subtitle", default: "Every signal against your usual") }

        // MARK: - Heart rate now

        static func heartRateNow(_ bpm: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_body_heart_rate_now", default: "Heart rate %d"), bpm)
        }
        /// Stands in for the number until the first sample arrives, and names the card for VoiceOver.
        static var heartRateNowTitle: String { RemoteConfigManager.shared.copyString("copy_body_heart_rate_now_title", default: "Heart rate now") }
        static var calm: String { RemoteConfigManager.shared.copyString("copy_body_calm", default: "calm") }
        static var elevated: String { RemoteConfigManager.shared.copyString("copy_body_elevated", default: "elevated") }
        static var watchOn: String { RemoteConfigManager.shared.copyString("copy_body_watch_on", default: "watch on") }
        static var watchOff: String { RemoteConfigManager.shared.copyString("copy_body_watch_off", default: "watch not on") }

        // MARK: - Sections and footer

        static var sectionOff: String { RemoteConfigManager.shared.copyString("copy_body_section_off", default: "Off your usual") }
        static var sectionUsual: String { RemoteConfigManager.shared.copyString("copy_body_section_usual", default: "At your usual") }
        static var nothingOff: String { RemoteConfigManager.shared.copyString("copy_body_nothing_off", default: "Nothing off your usual today") }
        static var notSyncedPrefix: String { RemoteConfigManager.shared.copyString("copy_body_not_synced_prefix", default: "Not synced yet today:") }
        /// Sits between the missing-signal list and the Open Health link.
        static var notSyncedJoin: String { RemoteConfigManager.shared.copyString("copy_body_not_synced_join", default: " · ") }
        static var openHealth: String { RemoteConfigManager.shared.copyString("copy_body_open_health", default: "Open Health") }
        static var healthStates: String { RemoteConfigManager.shared.copyString("copy_body_health_states", default: "Health states") }
        static var lastNightSleep: String { RemoteConfigManager.shared.copyString("copy_body_last_night_sleep", default: "last night's sleep") }
        static var morningHeartRate: String { RemoteConfigManager.shared.copyString("copy_body_morning_heart_rate", default: "morning heart rate") }
        static var listSeparator: String { RemoteConfigManager.shared.copyString("copy_body_list_separator", default: ", ") }

        // MARK: - Row values

        /// %@ is the rest days per week, e.g. "1" or "1.5".
        static func restPerWeek(_ perWeek: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_body_rest_per_week", default: "%@ a week"), perWeek)
        }
        /// %@ is the six day strain average, e.g. "14.3".
        static func strainAvg(_ avg: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_body_strain_avg", default: "%@ avg"), avg)
        }

        enum Row {
            static var sleepBalance: String { RemoteConfigManager.shared.copyString("copy_body_row_sleep_balance", default: "Sleep balance") }
            static var bounceBack: String { RemoteConfigManager.shared.copyString("copy_body_row_bounce_back", default: "Heart rate bounce-back") }
            static var restDays: String { RemoteConfigManager.shared.copyString("copy_body_row_rest_days", default: "Rest days") }
            static var hrv: String { RemoteConfigManager.shared.copyString("copy_body_row_hrv", default: "Heart rate variability") }
            static var restingHR: String { RemoteConfigManager.shared.copyString("copy_body_row_resting_hr", default: "Resting heart rate") }
            static var vo2Max: String { RemoteConfigManager.shared.copyString("copy_body_row_vo2_max", default: "VO2 max") }
            static var strainRecent: String { RemoteConfigManager.shared.copyString("copy_body_row_strain_recent", default: "Strain, last 6 days") }
            static var stressNow: String { RemoteConfigManager.shared.copyString("copy_body_row_stress_now", default: "Stress now") }
            static var mindful: String { RemoteConfigManager.shared.copyString("copy_body_row_mindful", default: "Mindful minutes") }
            static var steps: String { RemoteConfigManager.shared.copyString("copy_body_row_steps", default: "Steps") }
            static var cycle: String { RemoteConfigManager.shared.copyString("copy_body_row_cycle", default: "Cycle") }
        }

        enum Status {
            static func behindNights(_ nights: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_body_status_behind_nights", default: "Behind · %d nights to clear"), nights)
            }
            static var bounceBackBelow: String { RemoteConfigManager.shared.copyString("copy_body_status_bounce_back_below", default: "Below usual · earliest under-recovery sign") }
            static func restBelow(_ need: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_body_status_rest_below", default: "Below the %d a week your load needs"), need)
            }
            static var topOfRange: String { RemoteConfigManager.shared.copyString("copy_body_status_top_of_range", default: "Top of your range") }
            static var usual: String { RemoteConfigManager.shared.copyString("copy_body_status_usual", default: "Usual") }
            /// %1$d years younger, %2$d the person's real age.
            static func yearsYounger(_ years: Int, _ age: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_body_status_years_younger", default: "%d years younger than %d"), years, age)
            }
            static func strainAbove(_ low: Int, _ high: Int, _ days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_body_status_strain_above", default: "High, above your %d to %d target on %d of 6"), low, high, days)
            }
            static var strainInRange: String { RemoteConfigManager.shared.copyString("copy_body_status_strain_in_range", default: "Inside your target") }
            /// %@ is the usual daily total with unit, e.g. "8000 steps".
            static func stepsOnPace(_ goal: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_body_status_steps_on_pace", default: "On pace for your usual %@"), goal)
            }
        }
    }
}
