import Foundation

extension Copy {
    enum Reports {

        // MARK: - Annual Report

        static func yearInReview(_ year: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_reports_year_in_review", default: "%d Year in Review"), year) }
        static var shareAnnualReport: String { RemoteConfigManager.shared.copyString("copy_reports_reports_share_annual_report", default: "Share annual report") }
        static var annualScore: String { RemoteConfigManager.shared.copyString("copy_reports_reports_annual_score", default: "Annual Score") }

        // MARK: - Hero

        static func streakDayRecord(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_reports_streak_day_record", default: "%d-day streak record"), days) }
        static var jan: String { RemoteConfigManager.shared.copyString("copy_reports_reports_jan", default: "Jan") }
        static var dec: String { RemoteConfigManager.shared.copyString("copy_reports_reports_dec", default: "Dec") }
        static func yearsYounger(_ years: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_reports_years_younger", default: "%dy younger"), years) }
        static func yearsOlder(_ years: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_reports_years_older", default: "%dy older"), years) }

        // MARK: - Stats

        static var annualStats: String { RemoteConfigManager.shared.copyString("copy_reports_reports_annual_stats", default: "Annual Stats") }
        static var activeDays: String { RemoteConfigManager.shared.copyString("copy_reports_reports_active_days", default: "Active Days") }
        static var exerciseHours: String { RemoteConfigManager.shared.copyString("copy_reports_reports_exercise_hours", default: "Exercise Hours") }
        static var exerciseHrs: String { RemoteConfigManager.shared.copyString("copy_reports_reports_exercise_hrs", default: "Exercise Hrs") }
        static var distanceKm: String { RemoteConfigManager.shared.copyString("copy_reports_reports_distance_km", default: "Distance (km)") }
        static var avgStepsPerDay: String { RemoteConfigManager.shared.copyString("copy_reports_reports_avg_steps_per_day", default: "Avg Steps/Day") }
        static var avgSleep: String { RemoteConfigManager.shared.copyString("copy_reports_reports_avg_sleep", default: "Avg Sleep") }
        static var sevenPlusHourNights: String { RemoteConfigManager.shared.copyString("copy_reports_reports_seven_plus_hour_nights", default: "7+ Hour Nights") }

        // MARK: - Score Journey

        static var scoreJourney: String { RemoteConfigManager.shared.copyString("copy_reports_reports_score_journey", default: "Score Journey") }
        static var monthlyAverages: String { RemoteConfigManager.shared.copyString("copy_reports_reports_monthly_averages", default: "Monthly Averages") }
        static var bestMonth: String { RemoteConfigManager.shared.copyString("copy_reports_reports_best_month", default: "Best Month") }
        static var worstMonth: String { RemoteConfigManager.shared.copyString("copy_reports_reports_worst_month", default: "Lowest Month") }
        static var yearOverYear: String { RemoteConfigManager.shared.copyString("copy_reports_reports_year_over_year", default: "Year over Year") }
        static func yearOverYearDetail(prevYear: Int, prevScore: Int, curYear: Int, curScore: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_reports_reports_year_over_year_detail", default: "%d avg: %d \u{2192} %d avg: %d"), prevYear, prevScore, curYear, curScore)
        }

        // MARK: - Discoveries

        static var topDiscoveries: String { RemoteConfigManager.shared.copyString("copy_reports_top_discoveries", default: "Top Discoveries") }

        // MARK: - Milestones

        static var milestonesAndRecords: String { RemoteConfigManager.shared.copyString("copy_reports_milestones_and_records", default: "Milestones & Records") }
        static var bestStreak: String { RemoteConfigManager.shared.copyString("copy_reports_best_streak", default: "Best Streak") }

        // MARK: - Looking Ahead

        static func lookingAhead(_ year: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_looking_ahead", default: "Looking Ahead to %d"), year) }
        static var biggestOpportunities: String { RemoteConfigManager.shared.copyString("copy_reports_biggest_opportunities", default: "Biggest Opportunities") }
        static func averageScoreMessage(score: Int, message: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_reports_reports_average_score_message", default: "Average score: %d. %@"), score, message)
        }
        static var suggestedFocusAreas: String { RemoteConfigManager.shared.copyString("copy_reports_suggested_focus_areas", default: "Suggested Focus Areas") }
        static func heresTo(_ year: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_heres_to", default: "Here\u{2019}s to a healthier %d"), year) }

        // Opportunity messages
        static var keepUpGreatWork: String { RemoteConfigManager.shared.copyString("copy_reports_keep_up_great_work", default: "keep up the great work") }
        static var smallImprovements: String { RemoteConfigManager.shared.copyString("copy_reports_small_improvements", default: "small improvements can make a big difference") }
        static var significantRoom: String { RemoteConfigManager.shared.copyString("copy_reports_significant_room", default: "lots of room to grow") }
        static var priorityArea: String { RemoteConfigManager.shared.copyString("copy_reports_priority_area", default: "a priority area for next year") }

        // MARK: - Category Section

        static var categorySummary: String { RemoteConfigManager.shared.copyString("copy_reports_category_summary", default: "Category Summary") }
        static var mostImproved: String { RemoteConfigManager.shared.copyString("copy_reports_most_improved", default: "Most Improved") }
        static func mostImprovedDetail(_ category: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_reports_reports_most_improved_detail", default: "%@ improved the most this year"), category)
        }

        // MARK: - Monthly Review

        static func deltaFromLastMonth(_ delta: Int) -> String {
            let sign = delta >= 0 ? "+" : ""
            return String(format: RemoteConfigManager.shared.copyString("copy_reports_delta_from_last_month", default: "%@%d from last month"), sign, delta)
        }
        static var firstMonthNoComparison: String { RemoteConfigManager.shared.copyString("copy_reports_first_month_no_comparison", default: "First month. No comparison yet.") }
        static var notEnoughData: String { RemoteConfigManager.shared.copyString("copy_reports_not_enough_data", default: "Not enough data") }
        static var categoryPerformance: String { RemoteConfigManager.shared.copyString("copy_reports_category_performance", default: "Category Performance") }
        static var behaviorCorrelations: String { RemoteConfigManager.shared.copyString("copy_reports_behavior_correlations", default: "Behavior Correlations") }
        static var helpedRecovery: String { RemoteConfigManager.shared.copyString("copy_reports_helped_recovery", default: "Helped Recovery") }
        static var hurtRecovery: String { RemoteConfigManager.shared.copyString("copy_reports_hurt_recovery", default: "Hurt Recovery") }

        // MARK: - Share Card

        static var trackHealthWithLaso: String { RemoteConfigManager.shared.copyString("copy_reports_track_health_with_laso", default: "Track your health with Laso") }

        // MARK: - Weekly Review

        enum WeeklyReview {
            static func keepingUp(currentTarget: String, nextTarget: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_keeping_up", default: "You are hitting your %@/day target. Next week, we will bump it up to %@/day."), currentTarget, nextTarget)
            }
            static func plateauing(currentTarget: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_plateauing", default: "You are close to your %@/day target. Let us hold here this week and build the habit before pushing higher."), currentTarget)
            }
            static func struggling(currentTarget: String, nextTarget: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_struggling", default: "This week was tough at %@/day. We will drop to %@/day next week so it feels doable."), currentTarget, nextTarget)
            }
        }

        // MARK: - Weekly Review View

        enum WeeklyReviewView {
            static var title: String { RemoteConfigManager.shared.copyString("copy_reports_weekly_review_view_title", default: "Your Weekly Review") }
            static func score(_ score: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_view_score", default: "Score %d"), score) }
            static func coachTarget(_ steps: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_view_coach_target", default: "Coach target: %@/day"), steps) }
            static var keepSyncing: String { RemoteConfigManager.shared.copyString("copy_reports_weekly_review_view_keep_syncing", default: "Keep syncing health data for a few days and check back.") }
            static var firstWeekNoComparison: String { RemoteConfigManager.shared.copyString("copy_reports_weekly_review_view_first_week_no_comparison", default: "First week. No comparison yet.") }
            static func consistencyPayingOff(_ category: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_view_consistency_paying_off", default: "Your steady work on %@ is paying off. Keep it going next week."), category)
            }
            static var stableWeek: String { RemoteConfigManager.shared.copyString("copy_reports_stable_week", default: "A stable week across the board.") }
            static var noMajorChanges: String { RemoteConfigManager.shared.copyString("copy_reports_no_major_changes", default: "No major changes. Consistency is a strength.") }
            static var currentTarget: String { RemoteConfigManager.shared.copyString("copy_reports_current_target", default: "Current target") }
            static var currentAverage: String { RemoteConfigManager.shared.copyString("copy_reports_current_average", default: "Current average") }
            static var status: String { RemoteConfigManager.shared.copyString("copy_reports_status", default: "Status") }
            static var nextWeekTarget: String { RemoteConfigManager.shared.copyString("copy_reports_next_week_target", default: "Next week target") }
            static func stepTarget(_ steps: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_step_target", default: "Step target: %@/day"), steps) }
            static var poweredByModel: String { RemoteConfigManager.shared.copyString("copy_reports_powered_by_model", default: "Built from your own health data") }

            // Section header labels
            static var highlightsLabel: String { RemoteConfigManager.shared.copyString("copy_reports_highlights_label", default: "Highlights") }
            static var weeksWinsLabel: String { RemoteConfigManager.shared.copyString("copy_reports_weeks_wins_label", default: "This Week's Wins") }
            static var keyDiscoveryLabel: String { RemoteConfigManager.shared.copyString("copy_reports_key_discovery_label", default: "Key Discovery") }
            static var watchOutLabel: String { RemoteConfigManager.shared.copyString("copy_reports_watch_out_label", default: "Watch Out") }
            static var progressiveCoachLabel: String { RemoteConfigManager.shared.copyString("copy_reports_progressive_coach_label", default: "Progressive Coach") }
            static var nextWeekLabel: String { RemoteConfigManager.shared.copyString("copy_reports_next_week_label", default: "Next Week") }
        }
    }
}
