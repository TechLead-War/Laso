import Foundation
import SwiftUI

extension Copy {
    enum Live {

        /// SwiftUI Text variant of `lastSignalAgoText` so the relative-date `Date + style:`
        /// formatting (which only the SwiftUI Text initializer supports) is preserved.
        /// Splits the RC template on `%@` so operators can still customize the
        /// "Last signal …" phrasing without losing the auto-styled relative date.
        static func lastSignalAgoStyledText(_ date: Date) -> Text {
            let template = RemoteConfigManager.shared.copyString("copy_live_last_signal_ago_text", default: "Last signal %@ ago")
            let parts = template.components(separatedBy: "%@")
            let prefix = parts.first ?? "Last signal "
            let suffix = parts.count > 1 ? parts[1] : " ago"
            return Text(prefix) + Text(date, style: .relative) + Text(suffix)
        }


        // MARK: - Header

        static var title: String { RemoteConfigManager.shared.copyString("copy_live_live_title", default: "Live") }

        // MARK: - Activity Section

        static var activityRingsHeader: String { RemoteConfigManager.shared.copyString("copy_live_live_activity_rings_header", default: "Activity Rings") }
        static var noActivityYetTitle: String { RemoteConfigManager.shared.copyString("copy_live_live_no_activity_yet_title", default: "No activity yet") }
        static var noActivityYetBody: String { RemoteConfigManager.shared.copyString("copy_live_live_no_activity_yet_body", default: "Your rings will fill as you move throughout the day.") }

        // MARK: - Vitals

        static var bloodPressureLabel: String { RemoteConfigManager.shared.copyString("copy_live_live_blood_pressure_label", default: "Blood Pressure") }
        static var mmHgUnit: String { RemoteConfigManager.shared.copyString("copy_live_live_mm_hg_unit", default: "mmHg") }
        static var temperatureLabel: String { RemoteConfigManager.shared.copyString("copy_live_live_temperature_label", default: "Temperature") }
        static var lastKnownReadingsHeader: String { RemoteConfigManager.shared.copyString("copy_live_live_last_known_readings_header", default: "Last Known Readings") }

        // MARK: - Workout

        static var lastWorkoutHeader: String { RemoteConfigManager.shared.copyString("copy_live_live_last_workout_header", default: "Last Workout") }

        // MARK: - Lifted view literals
        static var activityRings: String { RemoteConfigManager.shared.copyString("copy_live_activity_rings", default: "Activity Rings") }
        static var noActivityYet: String { RemoteConfigManager.shared.copyString("copy_live_no_activity_yet", default: "No activity yet") }
        static var yourRingsWillFillAsYou: String { RemoteConfigManager.shared.copyString("copy_live_your_rings_will_fill_as_you", default: "Your rings will fill as you move throughout the day.") }
        static var bpm: String { RemoteConfigManager.shared.copyString("copy_live_bpm", default: "bpm") }
        static var syncing: String { RemoteConfigManager.shared.copyString("copy_live_syncing", default: "Syncing") }
        static var lastReading: String { RemoteConfigManager.shared.copyString("copy_live_last_reading", default: "Last Reading") }
        static var ago: String { RemoteConfigManager.shared.copyString("copy_live_ago", default: "ago") }
        static var x: String { RemoteConfigManager.shared.copyString("copy_live_x", default: "···") }
        static var live: String { RemoteConfigManager.shared.copyString("copy_live_live", default: "Live") }
        static var lastKnownReadings: String { RemoteConfigManager.shared.copyString("copy_live_last_known_readings", default: "Last Known Readings") }
        static var bloodPressure: String { RemoteConfigManager.shared.copyString("copy_live_blood_pressure", default: "Blood Pressure") }
        static var mmhg: String { RemoteConfigManager.shared.copyString("copy_live_mmhg", default: "mmHg") }
        static var temperature: String { RemoteConfigManager.shared.copyString("copy_live_temperature", default: "Temperature") }
        static var noData: String { RemoteConfigManager.shared.copyString("copy_live_no_data", default: "No data") }
        static var lastWorkout: String { RemoteConfigManager.shared.copyString("copy_live_last_workout", default: "Last Workout") }

        // MARK: - Lifted interpolated view literals
        static func activityRingsMoveOfCaloriesLabel(_ p0: Int, _ p1: Int, _ p2: Int, _ p3: Int, _ p4: Int, _ p5: Int, _ p6: Int, _ p7: Int, _ p8: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_activity_rings_move_of_calories_label", default: "Activity rings. Move: %d of %d calories, %d percent. Exercise: %d of %d minutes, %d percent. Stand: %d of %d hours, %d percent."), p0, p1, p2, p3, p4, p5, p6, p7, p8) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_x_text", default: "%d%%"), p0) }
        static func bloodPressureSysOverDia(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_blood_pressure_sys_over_dia", default: "%d/%d"), p0, p1) }
        static func xLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_x_label", default: "%@: %@"), p0, p1) }
        static func todayBpmText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_today_bpm_text", default: "Today: %d–%d bpm"), p0, p1) }
        static func beatsPerMinuteText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_beats_per_minute_text", default: "%d beats per minute"), p0) }
        static func opensDetailHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_opens_detail_hint", default: "Opens %@ detail"), p0) }
        static func minText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_min_text", default: "%d min"), p0) }
        static func kcalText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_kcal_text", default: "%d kcal"), p0) }
        static func lastSignalAgoText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_live_last_signal_ago_text", default: "Last signal %@ ago"), p0) }

        // MARK: - Live Activity: Wind Down
        //
        // Dynamic Island + lock-screen text for the wind-down activity. English
        // defaults are byte-identical to the prior Shared/WindDownActivityAttributes
        // literals so swapping the widget renderer to these keys changes nothing
        // visible. Stage phrases map 1:1 to WindDownStage.

        static var windDownHeader: String { RemoteConfigManager.shared.copyString("copy_live_la_wind_down_header", default: "Wind Down") }
        /// Label under the bedtime countdown. D5 renders it as "TO BED".
        static var windDownToBedLabel: String { RemoteConfigManager.shared.copyString("copy_live_la_wind_down_to_bed", default: "TO BED") }
        static var windDownStageApproaching: String { RemoteConfigManager.shared.copyString("copy_live_la_wind_down_stage_approaching", default: "Dim the lights") }
        static var windDownStageSoftening: String { RemoteConfigManager.shared.copyString("copy_live_la_wind_down_stage_softening", default: "Soften the pace") }
        static var windDownStageImminent: String { RemoteConfigManager.shared.copyString("copy_live_la_wind_down_stage_imminent", default: "Put the phone down") }
        static var windDownStageNow: String { RemoteConfigManager.shared.copyString("copy_live_la_wind_down_stage_now", default: "Ready for bed") }
        static var windDownStagePassed: String { RemoteConfigManager.shared.copyString("copy_live_la_wind_down_stage_passed", default: "Sleep well") }
        static var windDownHrvHint: String { RemoteConfigManager.shared.copyString("copy_live_la_wind_down_hrv_hint", default: "HRV suggests an early night") }
        /// VoiceOver label for the wind-down ring + countdown.
        static func windDownVoiceLabel(minutes: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_live_la_wind_down_voice_label", default: "Wind down. %d minutes to bedtime."), minutes)
        }

        // MARK: - Live Activity: Breathwork
        //
        // Phase + status text for the breathwork activity. Defaults are
        // byte-identical to Shared/BreathworkActivityAttributes literals.

        static var breathworkRelaxTitle: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_relax_title", default: "Relax") }
        static var breathworkFocusTitle: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_focus_title", default: "Focus") }
        static var breathworkCyclicSighingSubtitle: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_cyclic_sighing_subtitle", default: "Cyclic Sighing") }
        static var breathworkBoxBreathingSubtitle: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_box_breathing_subtitle", default: "Box Breathing") }
        static var breathworkPhaseBreatheIn: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_phase_breathe_in", default: "Breathe In") }
        static var breathworkPhaseHold: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_phase_hold", default: "Hold") }
        static var breathworkPhaseBreatheOut: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_phase_breathe_out", default: "Breathe Out") }
        static var breathworkPaused: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_paused", default: "Paused") }
        static var breathworkRemaining: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_remaining", default: "Remaining") }
        static var breathworkDone: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_done", default: "Done") }
        /// Pause glyph shown in the compact region.
        static var breathworkPauseGlyph: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_pause_glyph", default: "II") }
        static var breathworkCompletedGlyph: String { RemoteConfigManager.shared.copyString("copy_live_la_breathwork_completed_glyph", default: "OK") }
        /// VoiceOver label for the current breathing phase + time left.
        static func breathworkVoiceLabel(phase: String, remaining: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_live_la_breathwork_voice_label", default: "%@. %d seconds remaining."), phase, remaining)
        }

        // MARK: - Live Activity: Today Score
        //
        // Tint band words, time-of-day headlines, and action-button labels for
        // the today-score activity. Defaults are byte-identical to
        // Shared/TodayScoreActivityAttributes literals.

        static var todayScoreTintExcellent: String { RemoteConfigManager.shared.copyString("copy_live_la_today_tint_excellent", default: "Excellent") }
        static var todayScoreTintGood: String { RemoteConfigManager.shared.copyString("copy_live_la_today_tint_good", default: "Good") }
        static var todayScoreTintFair: String { RemoteConfigManager.shared.copyString("copy_live_la_today_tint_fair", default: "Fair") }
        static var todayScoreTintPoor: String { RemoteConfigManager.shared.copyString("copy_live_la_today_tint_poor", default: "Needs work") }
        static var todayScoreModeReadiness: String { RemoteConfigManager.shared.copyString("copy_live_la_today_mode_readiness", default: "Readiness") }
        static var todayScoreModeStrain: String { RemoteConfigManager.shared.copyString("copy_live_la_today_mode_strain", default: "Strain") }
        static var todayScoreModeTonight: String { RemoteConfigManager.shared.copyString("copy_live_la_today_mode_tonight", default: "Tonight") }
        static var todayScoreModeResting: String { RemoteConfigManager.shared.copyString("copy_live_la_today_mode_resting", default: "Resting") }
        static var todayScoreActionSetIntention: String { RemoteConfigManager.shared.copyString("copy_live_la_today_action_set_intention", default: "Set intention") }
        static var todayScoreActionBreathe: String { RemoteConfigManager.shared.copyString("copy_live_la_today_action_breathe", default: "Breathe 2 min") }
        static var todayScoreActionWindDown: String { RemoteConfigManager.shared.copyString("copy_live_la_today_action_wind_down", default: "Wind down") }
        /// Unit under the center score number (0-100 gauge).
        static var todayScoreUnit: String { RemoteConfigManager.shared.copyString("copy_live_la_today_score_unit", default: "score") }
        /// VoiceOver label for the today-score ring. `band` is the tint word.
        static func todayScoreVoiceLabel(score: Int, band: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_live_la_today_voice_label", default: "Today score %d out of 100. %@."), score, band)
        }
    }
}
