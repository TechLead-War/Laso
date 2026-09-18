import Foundation
import SwiftUI

extension Copy {
    enum Live {

        /// SwiftUI Text variant of the "Last signal … ago" caption so the relative-date
        /// `Date + style:` formatting (which only the SwiftUI Text initializer supports) is preserved.
        /// Splits the RC template on `%@` so operators can still customize the
        /// "Last signal …" phrasing without losing the auto-styled relative date.
        static func lastSignalAgoStyledText(_ date: Date) -> Text {
            let template = RemoteConfigManager.shared.copyString("copy_live_last_signal_ago_text", default: "Last signal %@ ago")
            let parts = template.components(separatedBy: "%@")
            let prefix = parts.first ?? "Last signal "
            let suffix = parts.count > 1 ? parts[1] : " ago"
            return Text(prefix) + Text(date, style: .relative) + Text(suffix)
        }

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
    }
}
