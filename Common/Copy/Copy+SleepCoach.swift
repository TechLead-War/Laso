import Foundation

extension Copy {
    enum SleepCoach {

        // MARK: - Navigation

        static var title: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_sleep_coach_title", default: "Sleep Coach") }

        // MARK: - Hero

        static var tonight: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_sleep_coach_tonight", default: "tonight") }
        static func recommendedSleep(level: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_sleep_coach_sleep_coach_recommended_sleep", default: "Recommended sleep for %@ performance"), level)
        }

        // MARK: - Performance Level

        static var performanceLevel: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_performance_level", default: "Performance Level") }
        static var performanceLabel: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_performance_label", default: "Performance") }

        // MARK: - Schedule

        static var bedtime: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_bedtime", default: "Bedtime") }
        static var wakeUp: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_wake_up", default: "Wake Up") }

        // MARK: - Sleep Debt

        static var sleepDebt: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_sleep_debt", default: "Sleep Balance") }
        static var currentDebt: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_current_debt", default: "Current Balance") }
        static func daysToPayOff(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_sleep_coach_days_to_pay_off", default: "%d days to recover"), days) }

        // Debt levels
        static var debtClear: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_debt_clear", default: "Clear") }
        static var debtLow: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_debt_low", default: "Low") }
        static var debtModerate: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_debt_moderate", default: "Moderate") }
        static var debtHigh: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_debt_high", default: "High") }

        // Debt trends
        static var tracking: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tracking", default: "Tracking") }
        static var payingOff: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_paying_off", default: "Paying off") }
        static var accumulating: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_accumulating", default: "Accumulating") }
        static var stable: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_stable", default: "Stable") }

        // MARK: - History

        static var fourteenDayHistory: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_fourteen_day_history", default: "14-Day History") }

        // MARK: - Consistency

        static var consistency: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_consistency", default: "Consistency") }
        static var excellent: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_excellent", default: "Excellent") }
        static var good: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_good", default: "Good") }
        static var needsWork: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_needs_work", default: "Building") }
        static var irregular: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_irregular", default: "Irregular") }

        static var consistencyExcellent: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_consistency_excellent", default: "Your sleep schedule is very steady. Great for your body clock.") }
        static var consistencyGood: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_consistency_good", default: "Pretty steady schedule. Try to keep weekends closer to your weekday timing.") }
        static var consistencyNeedsWork: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_consistency_needs_work", default: "Your sleep timing jumps around. Even small steps here can help you sleep better.") }
        static var consistencyIrregular: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_consistency_irregular", default: "Your sleep timing changes a lot. Waking up at the same time every day is the best place to start.") }

        // MARK: - Tips

        static var payingOffDebtTitle: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_paying_off_debt_title", default: "Restoring Balance") }
        static var sleepTips: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_sleep_tips", default: "Sleep Tips") }

        // Debt tips
        static var tipAddSleepTitle: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_add_sleep_title", default: "Add 30-60 min per night") }
        static var tipAddSleepDetail: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_add_sleep_detail", default: "Going to bed a bit earlier works better than sleeping in late.") }
        static func tipBePatientDetail(days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_sleep_coach_sleep_coach_tip_be_patient_detail", default: "Pay off debt gradually over %d days. Avoid marathon sleep sessions."), days)
        }
        static var tipBePatientTitle: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_be_patient_title", default: "Be patient") }
        static var tipCutCaffeineTitle: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_cut_caffeine_title", default: "Caffeine timing") }
        static var tipCutCaffeineDetail: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_cut_caffeine_detail", default: "Caffeine stays in your body for hours. Stopping after 2 PM can help you sleep deeper.") }
        static var tipScreenCurfewTitle: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_screen_curfew_title", default: "Screen wind down") }
        static var tipScreenCurfewDetail: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_screen_curfew_detail", default: "Put screens away 45 minutes before bed. Bright light makes it harder for your brain to wind down.") }

        // General tips
        static var tipConsistentScheduleTitle: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_consistent_schedule_title", default: "Consistent schedule") }
        static var tipConsistentScheduleDetail: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_consistent_schedule_detail", default: "Going to bed and waking up at the same time, even on weekends, is one of the best things you can do for sleep.") }
        static var tipCoolBedroomTitle: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_cool_bedroom_title", default: "Cool bedroom") }
        static var tipCoolBedroomDetail: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_cool_bedroom_detail", default: "65 to 68\u{00B0}F (18 to 20\u{00B0}C) is the sweet spot. A cooler room helps you fall into deeper sleep.") }
        static var tipMorningSunlightTitle: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_morning_sunlight_title", default: "Morning sunlight") }
        static var tipMorningSunlightDetail: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_morning_sunlight_detail", default: "10 to 15 minutes of bright light within an hour of waking up helps set your body clock.") }
        static var tipExerciseTimingTitle: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_exercise_timing_title", default: "Exercise timing") }
        static var tipExerciseTimingDetail: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_tip_exercise_timing_detail", default: "Regular exercise helps you sleep better. Try to finish hard workouts at least 3 hours before bed.") }

        // MARK: - Stages

        static var stageDeep: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_stage_deep", default: "Deep") }
        static var stageRem: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_stage_rem", default: "REM") }
        static var stageCore: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_stage_core", default: "Core") }
        static var stageAwake: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_stage_awake", default: "Awake") }
        static var stageDataUnavailable: String { RemoteConfigManager.shared.copyString("copy_sleep_coach_stage_data_unavailable", default: "Stage data not available for this night") }

        // MARK: - Tips Disclosure

        static func showMoreTips(_ count: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_sleep_coach_show_more_tips", default: "Show %d more tips"), count) }

        // MARK: - Lifted interpolated view literals
        static func sleepInBedLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_sleepcoach_sleep_in_bed_label", default: "%@ sleep: %@ in bed"), p0, p1) }
        static func mNapText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_sleepcoach_m_nap_text", default: "+%dm nap"), p0) }
        static func daytimeNapMinutesCountedInLabel(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_sleepcoach_daytime_nap_minutes_counted_in_label", default: "Daytime nap %d minutes, counted in sleep balance"), p0) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_sleepcoach_x_text", default: "%d"), p0) }
    }
}
