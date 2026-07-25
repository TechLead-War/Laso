import Foundation

extension Copy {
    enum Achievements {

        // MARK: - User Levels

        static var newcomer: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_newcomer", default: "Newcomer") }
        static var explorer: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_explorer", default: "Explorer") }
        static var committed: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_committed", default: "Committed") }
        static var dedicated: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_dedicated", default: "Dedicated") }
        static var champion: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_champion", default: "Champion") }
        static var legend: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_legend", default: "Legend") }

        // MARK: - Milestone Achievements

        static var firstGreenDayTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_first_green_day_title", default: "First Green Day") }
        static var firstGreenDayDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_first_green_day_description", default: "Hit your first health score above 75") }
        static var firstWeekTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_first_week_title", default: "First Week") }
        static var firstWeekDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_first_week_description", default: "Track your health for 7 consecutive days") }
        static var dataScholarTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_data_scholar_title", default: "Data Scholar") }
        static var dataScholarDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_data_scholar_description", default: "Reach 60 or more days of health data") }
        static var centurionTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_centurion_title", default: "Centurion") }
        static var centurionDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_centurion_description", default: "100 days of health tracking") }
        static var halfYearHeroTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_half_year_hero_title", default: "Half Year Hero") }
        static var halfYearHeroDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_half_year_hero_description", default: "Track your health for 180 days") }
        static var yearOneTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_year_one_title", default: "Year One") }
        static var yearOneDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_year_one_description", default: "A full year of health tracking. Legendary.") }

        // MARK: - Streak Achievements

        static var weekWarriorTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_week_warrior_title", default: "Week Warrior") }
        static var weekWarriorDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_week_warrior_description", default: "7 day activity streak (10K steps or 30 min exercise daily)") }
        static var ironWillTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_iron_will_title", default: "Iron Will") }
        static var ironWillDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_iron_will_description", default: "30 day activity streak. Unstoppable.") }
        static var hundredDayHammerTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_hundred_day_hammer_title", default: "Hundred Day Hammer") }
        static var hundredDayHammerDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_hundred_day_hammer_description", default: "100 day activity streak. Relentless.") }
        static var sleepChampionTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_sleep_champion_title", default: "Sleep Champion") }
        static var sleepChampionDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_sleep_champion_description", default: "7 consecutive nights with 8+ hours of sleep") }
        static var dreamMachineTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_dream_machine_title", default: "Dream Machine") }
        static var dreamMachineDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_dream_machine_description", default: "30 day sleep streak. Consistent 7+ hour nights.") }
        static var recoveryProTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_recovery_pro_title", default: "Recovery Pro") }
        static var recoveryProDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_recovery_pro_description", default: "7 consecutive green recovery days") }
        static var zenMasterTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_zen_master_title", default: "Zen Master") }
        static var zenMasterDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_zen_master_description", default: "30 day recovery streak. Peak balance.") }
        static var perfectWeekTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_perfect_week_title", default: "Perfect Week") }
        static var perfectWeekDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_perfect_week_description", default: "All 7 days in a week with green recovery scores") }
        static var tripleThreatTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_triple_threat_title", default: "Triple Threat") }
        static var tripleThreatDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_triple_threat_description", default: "7 day master streak. Activity, sleep, and recovery all green.") }
        static var absoluteLegendTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_absolute_legend_title", default: "Absolute Legend") }
        static var absoluteLegendDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_absolute_legend_description", default: "30 day master streak. Perfection across all pillars.") }

        // MARK: - Record Achievements

        static var marathonMonthTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_marathon_month_title", default: "Marathon Month") }
        static var marathonMonthDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_marathon_month_description", default: "Total monthly steps exceed 300,000") }
        static var peakPerformerTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_peak_performer_title", default: "Peak Performer") }
        static var peakPerformerDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_peak_performer_description", default: "Reach a health score of 95 or higher") }
        static var stepKingTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_step_king_title", default: "Step Legend") }
        static var stepKingDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_step_king_description", default: "Hit 20,000 steps in a single day") }

        // MARK: - Consistency Achievements

        static var nightOwlReformedTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_night_owl_reformed_title", default: "Night Owl Reformed") }
        static var nightOwlReformedDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_night_owl_reformed_description", default: "Improve sleep consistency. 14 days averaging 7+ hours after previously averaging under 6.5.") }
        static var steadyHandTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_steady_hand_title", default: "Steady Hand") }
        static var steadyHandDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_steady_hand_description", default: "Keep your health score within 10 points for 14 consecutive days") }
        static var dailyDevoteeTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_daily_devotee_title", default: "Daily Devotee") }
        static var dailyDevoteeDescription: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_daily_devotee_description", default: "14 day check-in streak. Health is a daily practice.") }

        // MARK: - Section Headers

        static var highestLevelAchieved: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_highest_level_achieved", default: "Highest level achieved") }
        static var activeStreaks: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_active_streaks", default: "Active Streaks") }
        static var achievementsTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_achievements_achievements_title", default: "Achievements") }

        // MARK: - Lifted view literals
        static var yourProgressNavTitle: String { RemoteConfigManager.shared.copyString("copy_achievements_your_progress_nav_title", default: "Your Progress") }
        static var days: String { RemoteConfigManager.shared.copyString("copy_achievements_days", default: "days") }

        // MARK: - Lifted interpolated view literals
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_achievements_x_text", default: "%d%%"), p0) }
        static func daysTrackedText(_ p0: Int) -> String {
            p0 == 1
                ? RemoteConfigManager.shared.copyString("copy_achievements_days_tracked_text_singular", default: "1 day tracked")
                : String(format: RemoteConfigManager.shared.copyString("copy_achievements_days_tracked_text", default: "%d days tracked"), p0)
        }
        static func daysToText(_ p0: Int, _ p1: String) -> String {
            p0 == 1
                ? String(format: RemoteConfigManager.shared.copyString("copy_achievements_days_to_text_singular", default: "1 day to %@"), p1)
                : String(format: RemoteConfigManager.shared.copyString("copy_achievements_days_to_text", default: "%d days to %@"), p0, p1)
        }
        static func xText2(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_achievements_x_text2", default: "%d"), p0) }
        static func xText3(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_achievements_x_text3", default: "%d"), p0) }
        static func countOfText(_ p0: Int, _ p1: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_achievements_count_of_text", default: "%d of %d"), p0, p1) }
    }
}
