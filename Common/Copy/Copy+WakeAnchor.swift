import Foundation

extension Copy {
    enum WakeAnchor {

        // MARK: - Section

        static var sectionTitle: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_section_title", default: "Your wake window") }
        static var everyDay: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_every_day", default: "every day") }
        static var setAction: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_set_action", default: "Set") }
        static var changeAction: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_change_action", default: "Change") }

        // MARK: - Bands

        static var bandSteady: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_band_steady", default: "Steady") }
        static var bandClose: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_band_close", default: "Close") }
        static var bandVariable: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_band_variable", default: "Variable") }

        // MARK: - Readout

        /// "varied by 11 min over 28 nights"
        static func variedBy(driftMinutes: String, nights: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_wake_anchor_varied_by", default: "varied by %@ over %@"), driftMinutes, nights)
        }

        /// "min" is the same word either way, so no plural pair here.
        static func minutes(_ count: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_wake_anchor_minutes", default: "%d min"), count)
        }

        /// Format strings for `Copy.plural`, which applies `String(format:)`
        /// itself. Returning a pre-formatted string here would double-format.
        static var nightsOneFormat: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_nights_one", default: "%d night") }
        static var nightsManyFormat: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_nights_many", default: "%d nights") }

        /// "Your wake time landed within 30 minutes of your anchor on 24 of 28 nights."
        static func landedWithin(minutes: Int, hits: Int, total: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_wake_anchor_landed_within", default: "Your wake time landed within %d minutes of your anchor on %d of %d nights."), minutes, hits, total)
        }

        /// Shown until enough nights are tracked to earn a band label.
        static func nightsTracked(_ tracked: Int, of needed: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_wake_anchor_nights_tracked", default: "%d of %d nights tracked"), tracked, needed)
        }

        /// Population evidence, attributed, and kept separate from the user's
        /// own numbers. Never phrased as a prediction about this person.
        static var evidenceNote: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_evidence_note", default: "In a study of 60,977 adults, the steadiest fifth woke within about an hour of the same time each day.") }

        // MARK: - Empty state

        static var emptyTitle: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_empty_title", default: "Set one wake time") }
        static var emptyMessage: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_empty_message", default: "Keeping the same wake time is the steadiest thing you can do for your sleep. We move your bedtime instead.") }
        static var emptyCTA: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_empty_cta", default: "Choose a time") }

        // MARK: - Onboarding ask

        static var onboardingEyebrow: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_eyebrow", default: "ONE THING TO KEEP") }

        /// "You usually wake around 7:00 AM."
        static func onboardingUsually(_ time: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_usually", default: "You usually wake around %@."), time)
        }

        static var onboardingBody: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_body", default: "Keep this as your wake time and we move your bedtime instead. Steady mornings do more for sleep than any single early night.") }

        static var onboardingConfirm: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_confirm", default: "Keep this wake time") }
        static var onboardingKept: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_onboarding_kept", default: "Wake time set. You can change it any time in Sleep Coach.") }

        // MARK: - Setter sheet

        static var setterTitle: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_setter_title", default: "Wake time") }
        static var setterFooter: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_setter_footer", default: "We remind you at this time and move your bedtime instead when you need more sleep. This is a reminder, not an alarm.") }
        static var setterConfirm: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_setter_confirm", default: "Set wake time") }

        /// "Bedtime target 10:45 PM"
        static func setterBedtimePreview(_ bedtime: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_wake_anchor_setter_bedtime_preview", default: "Bedtime target %@"), bedtime)
        }

        /// Explains the picker's bounds without exposing the reason (an anchor
        /// outside 5 to 11 gets its reminder dropped by quiet hours).
        static var setterRangeNote: String { RemoteConfigManager.shared.copyString("copy_wake_anchor_setter_range_note", default: "Pick a time between 5:00 AM and 11:00 AM.") }
    }
}
