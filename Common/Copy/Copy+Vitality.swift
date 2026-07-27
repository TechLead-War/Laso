import Foundation

extension Copy {
    enum Vitality {

        // MARK: - Navigation

        static var title: String { RemoteConfigManager.shared.copyString("copy_vitality_vitality_title", default: "Vitality Age") }

        // MARK: - Hero

        static var vitalityAgeLabel: String { RemoteConfigManager.shared.copyString("copy_vitality_vitality_vitality_age_label", default: "VITALITY AGE") }
        static func actualAge(_ age: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_vitality_actual_age", default: "Actual age %d"), age) }
        static func paceOverDays(days: Int, label: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_pace_over_days", default: "%dd %@"), days, label) }
        static var buildingProfile: String { RemoteConfigManager.shared.copyString("copy_vitality_vitality_building_profile", default: "Building your profile") }
        static func yearsYounger(_ years: Int) -> String {
            Copy.plural(years,
                   one: RemoteConfigManager.shared.copyString("copy_vitality_vitality_year_younger_one", default: "%d year younger"),
                   many: RemoteConfigManager.shared.copyString("copy_vitality_vitality_years_younger", default: "%d years younger"))
        }
        static func yearsOlder(_ years: Int) -> String {
            Copy.plural(years,
                   one: RemoteConfigManager.shared.copyString("copy_vitality_vitality_year_older_one", default: "%d year older"),
                   many: RemoteConfigManager.shared.copyString("copy_vitality_vitality_years_older", default: "%d years older"))
        }
        static var onTrack: String { RemoteConfigManager.shared.copyString("copy_vitality_vitality_on_track", default: "On track") }

        // MARK: - Narratives

        static var buildingProfileNarrative: String { RemoteConfigManager.shared.copyString("copy_vitality_vitality_building_profile_narrative", default: "We are building your profile. For now, your vitality age matches your real age.") }
        static func earlyYoungerNarrative(delta: Int) -> String {
            Copy.plural(delta,
                   one: RemoteConfigManager.shared.copyString("copy_vitality_vitality_early_younger_narrative_one", default: "Early estimate: your body looks about %d year younger. This gets more accurate with more data."),
                   many: RemoteConfigManager.shared.copyString("copy_vitality_vitality_early_younger_narrative", default: "Early estimate: your body looks about %d years younger. This gets more accurate with more data."))
        }
        static func earlyOlderNarrative(delta: Int) -> String {
            Copy.plural(delta,
                   one: RemoteConfigManager.shared.copyString("copy_vitality_vitality_early_older_narrative_one", default: "Early estimate: your body looks about %d year older. This gets more accurate with more data."),
                   many: RemoteConfigManager.shared.copyString("copy_vitality_vitality_early_older_narrative", default: "Early estimate: your body looks about %d years older. This gets more accurate with more data."))
        }
        static var earlyAlignedNarrative: String { RemoteConfigManager.shared.copyString("copy_vitality_early_aligned_narrative", default: "Early estimate: your vitality age matches your real age.") }
        static func personalYoungerNarrative(delta: Int) -> String {
            Copy.plural(delta,
                   one: RemoteConfigManager.shared.copyString("copy_vitality_vitality_personal_younger_narrative_one", default: "Your body is performing about %d year younger than your actual age."),
                   many: RemoteConfigManager.shared.copyString("copy_vitality_vitality_personal_younger_narrative", default: "Your body is performing about %d years younger than your actual age."))
        }
        static func personalOlderNarrative(delta: Int) -> String {
            Copy.plural(delta,
                   one: RemoteConfigManager.shared.copyString("copy_vitality_vitality_personal_older_narrative_one", default: "Your numbers suggest about %d year above your actual age. The tips below can help close the gap."),
                   many: RemoteConfigManager.shared.copyString("copy_vitality_vitality_personal_older_narrative", default: "Your numbers suggest about %d years above your actual age. The tips below can help close the gap."))
        }
        static var personalAlignedNarrative: String { RemoteConfigManager.shared.copyString("copy_vitality_personal_aligned_narrative", default: "Your vitality age matches your real age. Keep doing what you are doing to stay on track.") }

        // MARK: - Pace

        static var normalOrSlower: String { RemoteConfigManager.shared.copyString("copy_vitality_normal_or_slower", default: "Normal or slower") }
        static var agingTooQuickly: String { RemoteConfigManager.shared.copyString("copy_vitality_aging_too_quickly", default: "Speeding up") }
        static var agingVeryFast: String { RemoteConfigManager.shared.copyString("copy_vitality_aging_very_fast", default: "Could use some care") }

        // MARK: - Delta Labels

        static func metricYounger(_ years: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_metric_younger", default: "%dy younger"), years) }
        static func metricOlder(_ years: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_metric_older", default: "+%dy older"), years) }
        /// Shown when the value beats the youngest row in the reference table.
        /// We cannot say how many years younger, so we do not print a number.
        static var metricTopOfRange: String { RemoteConfigManager.shared.copyString("copy_vitality_metric_top_of_range", default: "Top of range") }

        // MARK: - Sections

        static var topImprovements: String { RemoteConfigManager.shared.copyString("copy_vitality_top_improvements", default: "Top Improvements") }
        static var metricContributions: String { RemoteConfigManager.shared.copyString("copy_vitality_metric_contributions", default: "Metric Contributions") }
        static var howThisWorks: String { RemoteConfigManager.shared.copyString("copy_vitality_how_this_works", default: "How this works") }
        static var methodology: String { RemoteConfigManager.shared.copyString("copy_vitality_methodology", default: "Vitality Age compares your health numbers to what is typical for your age and turns that into one number. This is for wellness and information only.") }
        static func ageLabel(_ age: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_age_label", default: "Age %d"), age) }
        static func metricSubtitle(current: String, expected: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_metric_subtitle", default: "%@ now, typical %@"), current, expected) }

        // MARK: - Data Maturity

        static var buildingProfileDescription: String { RemoteConfigManager.shared.copyString("copy_vitality_building_profile_description", default: "Your vitality age matches your real age while we learn what is normal for you. Keep wearing your device.") }
        static var earlyEstimateDescription: String { RemoteConfigManager.shared.copyString("copy_vitality_early_estimate_description", default: "Early estimate. Gets more accurate each day as we learn your patterns.") }
        static var profileProgressTitle: String { RemoteConfigManager.shared.copyString("copy_vitality_profile_progress_title", default: "Profile progress") }
        static func dataProgress(days: Int, target: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_data_progress", default: "%d of %d days"), days, target) }

        // MARK: - Trend

        /// Titled with the days actually recorded, never a window we did not fill.
        static func trendTitle(days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_trend_title", default: "Last %d days"), days) }
        static func changeOverDays(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_change_over_days", default: "%dd change"), days) }
        static var pace: String { RemoteConfigManager.shared.copyString("copy_vitality_pace", default: "Pace") }
        static var current: String { RemoteConfigManager.shared.copyString("copy_vitality_current", default: "Current") }
        static var paceBuilding: String { RemoteConfigManager.shared.copyString("copy_vitality_pace_building", default: "Building") }
        static func paceNeedsDays(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_pace_needs_days", default: "Pace needs %d days of history"), days) }
        static var paceImproving: String { RemoteConfigManager.shared.copyString("copy_vitality_pace_improving", default: "Improving") }
        static var paceStable: String { RemoteConfigManager.shared.copyString("copy_vitality_pace_stable", default: "Stable") }
        static var paceDeclining: String { RemoteConfigManager.shared.copyString("copy_vitality_pace_declining", default: "Declining") }

        // MARK: - Improvement Suggestions

        static var improveVO2Max: String { RemoteConfigManager.shared.copyString("copy_vitality_improve_vo2_max", default: "Try running, cycling, or swimming 2 to 3 times a week to build your cardio fitness.") }
        static var improveRHR: String { RemoteConfigManager.shared.copyString("copy_vitality_improve_rhr", default: "Regular exercise and less stress can bring your resting heart rate down over time.") }
        static var improveHRV: String { RemoteConfigManager.shared.copyString("copy_vitality_improve_hrv", default: "Better sleep, deep breathing, and regular exercise all help your heart recover better.") }
        static var improveSleep: String { RemoteConfigManager.shared.copyString("copy_vitality_improve_sleep", default: "Aim for 7 to 9 hours of sleep on a regular schedule. Cut screens and caffeine before bed.") }
        static var improveWalkingSpeed: String { RemoteConfigManager.shared.copyString("copy_vitality_improve_walking_speed", default: "Walking speed shows your overall fitness. Regular walks, strength work, and balance exercises can help.") }
        static var improveSteps: String { RemoteConfigManager.shared.copyString("copy_vitality_improve_steps", default: "Move more during the day. Take walking meetings, use stairs, and add a daily walk.") }
        static var improveExercise: String { RemoteConfigManager.shared.copyString("copy_vitality_improve_exercise", default: "Work up to 150 or more minutes of exercise per week doing things you enjoy.") }
        static var improveBodyComp: String { RemoteConfigManager.shared.copyString("copy_vitality_improve_body_comp", default: "Focus on eating well and staying active. Small steady changes make the biggest difference over time.") }
        static var improveDefault: String { RemoteConfigManager.shared.copyString("copy_vitality_improve_default", default: "Keep tracking this and look for patterns in your data.") }

        // MARK: - Chart Accessibility (VitalityTrendSection)

        static func chartAccessibilityLabel(dayCount: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_vitality_vitality_chart_accessibility_label", default: "Vitality age trend over last %d days"), dayCount)
        }

        // MARK: - Lifted view literals
        static var yrs: String { RemoteConfigManager.shared.copyString("copy_vitality_yrs", default: "yrs") }

        // MARK: - Lifted interpolated view literals
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_x_text", default: "%d"), p0) }
        static func xText2(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_x_text2", default: "%d"), p0) }
        static func yText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_vitality_y_text", default: "+%dy"), p0) }
    }
}
