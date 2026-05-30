import Foundation

extension Copy {
    enum Strain {

        // MARK: - Navigation

        static var title: String { RemoteConfigManager.shared.copyString("copy_strain_strain_title", default: "Strain") }

        // MARK: - Hero

        static var of21: String { RemoteConfigManager.shared.copyString("copy_strain_strain_of21", default: "of 21") }
        static var heroExplainer: String { RemoteConfigManager.shared.copyString("copy_strain_strain_hero_explainer", default: "How much physical effort your body handled today") }
        static var contextLow: String { RemoteConfigManager.shared.copyString("copy_strain_strain_context_low", default: "Light day for your body. Safe to add some activity if you feel up to it.") }
        static var contextLight: String { RemoteConfigManager.shared.copyString("copy_strain_strain_context_light", default: "Easy effort so far. You have room to push a bit more today.") }
        static var contextModerate: String { RemoteConfigManager.shared.copyString("copy_strain_strain_context_moderate", default: "Solid workload for your recovery. Keep this rhythm going.") }
        static var contextHigh: String { RemoteConfigManager.shared.copyString("copy_strain_strain_context_high", default: "Hard day on the body. Make sure to eat well, drink water, and get enough sleep tonight.") }
        static var contextPeak: String { RemoteConfigManager.shared.copyString("copy_strain_strain_context_peak", default: "You pushed near your limit. Plan an easier day tomorrow.") }
        static var contextAllOut: String { RemoteConfigManager.shared.copyString("copy_strain_strain_context_all_out", default: "Maximum effort today. Real recovery is the priority now.") }

        // MARK: - Balance

        static var strainBalance: String { RemoteConfigManager.shared.copyString("copy_strain_strain_strain_balance", default: "Strain Balance") }
        static var underTraining: String { RemoteConfigManager.shared.copyString("copy_strain_strain_under_training", default: "Under-Training") }
        static var optimal: String { RemoteConfigManager.shared.copyString("copy_strain_strain_optimal", default: "Best") }
        static var overreaching: String { RemoteConfigManager.shared.copyString("copy_strain_strain_overreaching", default: "Peak") }

        static var underTrainingDescription: String { RemoteConfigManager.shared.copyString("copy_strain_strain_under_training_description", default: "Your strain is below your target. Try adding more activity to stay on track.") }
        static var optimalDescription: String { RemoteConfigManager.shared.copyString("copy_strain_strain_optimal_description", default: "You are training in your best range for your current recovery. Nice work.") }
        static var overreachingDescription: String { RemoteConfigManager.shared.copyString("copy_strain_strain_overreaching_description", default: "You are pushing harder than your body can recover from. Rest and go lighter.") }

        // MARK: - Coach Zone Display Names

        static var zoneRestoring: String { RemoteConfigManager.shared.copyString("copy_strain_strain_zone_restoring", default: "Recovery Focus") }
        static var zoneMaintaining: String { RemoteConfigManager.shared.copyString("copy_strain_strain_zone_maintaining", default: "Maintain Fitness") }
        static var zoneBuilding: String { RemoteConfigManager.shared.copyString("copy_strain_strain_zone_building", default: "Progressive Overload") }
        static var zoneOverreaching: String { RemoteConfigManager.shared.copyString("copy_strain_strain_zone_overreaching", default: "Functional Overreach") }

        // MARK: - Strain Balance Display Names (Coach)

        static var balanceUnderTraining: String { RemoteConfigManager.shared.copyString("copy_strain_strain_balance_under_training", default: "Under-Training") }
        static var balanceOptimal: String { RemoteConfigManager.shared.copyString("copy_strain_strain_balance_optimal", default: "Optimal Load") }
        static var balanceOverreaching: String { RemoteConfigManager.shared.copyString("copy_strain_strain_balance_overreaching", default: "Over-Reaching") }

        // MARK: - Coach Guidance

        static var coachLimitedData: String { RemoteConfigManager.shared.copyString("copy_strain_strain_coach_limited_data", default: "Limited data \u{2014} this target is estimated. Keep logging for more accurate recommendations.") }
        static func coachRedRecovery(target: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_strain_strain_coach_red_recovery", default: "Your body needs recovery. Focus on gentle movement like walking or stretching. Aim to keep strain under %@."), target)
        }
        static func coachConsecutiveHigh(days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_strain_strain_coach_consecutive_high", default: "You've pushed hard %d days in a row. Take it easy today to avoid overtraining."), days)
        }
        static var coachActiveRecovery: String { RemoteConfigManager.shared.copyString("copy_strain_coach_active_recovery", default: "Active recovery day. Light activity to promote blood flow without adding fatigue.") }
        static func coachMaintaining(remaining: String, target: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_strain_strain_coach_maintaining", default: "Moderate training day. You have %@ strain remaining to hit your target of %@."), remaining, target)
        }
        static var coachMaintainHit: String { RemoteConfigManager.shared.copyString("copy_strain_coach_maintain_hit", default: "You've reached your maintenance target. Additional strain is fine but keep intensity controlled.") }
        static func coachBuilding(target: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_strain_strain_coach_building", default: "Your body is ready for a challenge. Push toward a strain of %@ with a hard workout."), target)
        }
        static func coachBuildingHit(upper: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_strain_strain_coach_building_hit", default: "Great work \u{2014} you've hit your building target. You can keep going up to %@."), upper)
        }
        static var coachOverreaching: String { RemoteConfigManager.shared.copyString("copy_strain_coach_overreaching", default: "Functional overreach zone. Push to your limit today, then plan recovery tomorrow.") }

        // MARK: - Coach

        static var strainCoach: String { RemoteConfigManager.shared.copyString("copy_strain_strain_coach", default: "Strain Coach") }
        static var targetStrain: String { RemoteConfigManager.shared.copyString("copy_strain_target_strain", default: "Target Strain") }
        static var recommendedZone: String { RemoteConfigManager.shared.copyString("copy_strain_recommended_zone", default: "Recommended Zone") }

        // MARK: - HR Zones

        static var heartRateZones: String { RemoteConfigManager.shared.copyString("copy_strain_heart_rate_zones", default: "Heart Rate Zones") }
        static var activeRecovery: String { RemoteConfigManager.shared.copyString("copy_strain_active_recovery", default: "Active Recovery") }
        static var fatBurn: String { RemoteConfigManager.shared.copyString("copy_strain_fat_burn", default: "Fat Burn") }
        static var aerobic: String { RemoteConfigManager.shared.copyString("copy_strain_aerobic", default: "Aerobic") }
        static var threshold: String { RemoteConfigManager.shared.copyString("copy_strain_threshold", default: "Threshold") }
        static var anaerobic: String { RemoteConfigManager.shared.copyString("copy_strain_anaerobic", default: "Anaerobic") }
        static func zoneDefault(_ zone: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_zone_default", default: "Zone %d"), zone) }
        static func percentOfTotal(_ pct: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_percent_of_total", default: "%d%% of total time"), pct) }

        // MARK: - Scale

        static var scaleSuffix: String { RemoteConfigManager.shared.copyString("copy_strain_scale_suffix", default: "/ 21") }
        static var strainScaleLegend: String { RemoteConfigManager.shared.copyString("copy_strain_strain_scale_legend", default: "Strain Scale") }
        static func targetZoneLabel(_ low: String, _ high: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_strain_strain_target_zone_label", default: "Target zone: %@ to %@ / 21"), low, high)
        }

        // MARK: - History

        static var sevenDayHistory: String { RemoteConfigManager.shared.copyString("copy_strain_seven_day_history", default: "7-Day History") }
        static var sevenDayAverage: String { RemoteConfigManager.shared.copyString("copy_strain_seven_day_average", default: "7-Day Average:") }

        // MARK: - Simplified Drivers

        static var todaySnapshot: String { RemoteConfigManager.shared.copyString("copy_strain_today_snapshot", default: "Today's Snapshot") }
        static var inTarget: String { RemoteConfigManager.shared.copyString("copy_strain_in_target", default: "In Target") }
        static var belowTarget: String { RemoteConfigManager.shared.copyString("copy_strain_below_target", default: "Below Target") }
        static var aboveTarget: String { RemoteConfigManager.shared.copyString("copy_strain_above_target", default: "Above Target") }
        static func targetRange(_ low: String, _ high: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_target_range", default: "Aim for %@ to %@"), low, high) }
        static func currentStrainVsTarget(_ current: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_current_strain_vs_target", default: "You are at %@ right now"), current) }
        static var learnMore: String { RemoteConfigManager.shared.copyString("copy_strain_learn_more", default: "Learn More") }
        static var learnMoreHint: String { RemoteConfigManager.shared.copyString("copy_strain_learn_more_hint", default: "See your heart rate zones and detailed coaching.") }

        // MARK: - Disclaimer

        static var strainDisclaimer: String { RemoteConfigManager.shared.copyString("copy_strain_strain_disclaimer", default: "Strain is based on your heart rate during activity. It is not a medical measurement. Talk to a qualified professional before making big changes to your exercise routine.") }

        // MARK: - Today's Workout

        static var todaysWorkout: String { RemoteConfigManager.shared.copyString("copy_strain_todays_workout", default: "Today's Workout") }
        static var tapToViewWorkout: String { RemoteConfigManager.shared.copyString("copy_strain_tap_to_view_workout", default: "Tap to view warm-up, blocks, and cooldown") }
        static var cycleAdjustmentTitle: String { RemoteConfigManager.shared.copyString("copy_strain_cycle_adjustment_title", default: "Cycle Adjustment") }
        static var cyclePhaseTitle: String { RemoteConfigManager.shared.copyString("copy_strain_cycle_phase_title", default: "Cycle Phase") }
        static func cyclePhaseDetail(_ phase: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_strain_strain_cycle_phase_detail", default: "Current phase: %@. Training stays in line with your recovery for today."), phase)
        }
        static var warmUpTitle: String { RemoteConfigManager.shared.copyString("copy_strain_warm_up_title", default: "Warm-Up") }
        static var cooldownTitle: String { RemoteConfigManager.shared.copyString("copy_strain_cooldown_title", default: "Cooldown") }
        static func mainBlockTitle(_ index: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_main_block_title", default: "Main Block %d"), index) }
        static var done: String { RemoteConfigManager.shared.copyString("copy_strain_done", default: "Done") }
        static var recoveryLabel: String { RemoteConfigManager.shared.copyString("copy_strain_recovery_label", default: "Recovery") }
        static var durationLabel: String { RemoteConfigManager.shared.copyString("copy_strain_duration_label", default: "Duration") }
        static var caloriesLabel: String { RemoteConfigManager.shared.copyString("copy_strain_calories_label", default: "Cal") }
        static var redRecovery: String { RemoteConfigManager.shared.copyString("copy_strain_red_recovery", default: "Red recovery") }
        static var yellowRecovery: String { RemoteConfigManager.shared.copyString("copy_strain_yellow_recovery", default: "Yellow recovery") }
        static var greenRecovery: String { RemoteConfigManager.shared.copyString("copy_strain_green_recovery", default: "Green recovery") }
        static func workoutHeartRateTarget(label: String, minBPM: Int, maxBPM: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_strain_strain_workout_heart_rate_target", default: "Target: %@ \u{2022} %d-%d bpm"), label, minBPM, maxBPM)
        }
        static func minutesShort(_ minutes: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_minutes_short", default: "%d min"), minutes) }

        // MARK: - Strain Detail

        static func zoneShort(_ zone: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_zone_short", default: "Z%d"), zone) }
        static var noWorkoutData: String { RemoteConfigManager.shared.copyString("copy_strain_no_workout_data", default: "No workout data yet") }
        static var logWorkoutHint: String { RemoteConfigManager.shared.copyString("copy_strain_log_workout_hint", default: "Log a workout in Apple Health or wear your watch during exercise. Your strain score will appear here once activity is recorded.") }

        // MARK: - Strain Levels

        static var strainLevelLow: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_low", default: "Low") }
        static var strainLevelLight: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_light", default: "Light") }
        static var strainLevelModerate: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_moderate", default: "Moderate") }
        static var strainLevelHigh: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_high", default: "High") }
        static var strainLevelPeak: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_peak", default: "Peak") }
        static var strainLevelAllOut: String { RemoteConfigManager.shared.copyString("copy_strain_strain_level_all_out", default: "All Out") }

        // MARK: - Lifted interpolated view literals
        static func strainOverTheLastDaysText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_strain_over_the_last_days_text", default: "Strain over the last %d days"), p0) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_x_text", default: "%d"), p0) }
        static func minText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_strain_min_text", default: "%d min"), p0) }
    }
}
