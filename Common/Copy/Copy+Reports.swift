import Foundation

extension Copy {
    enum Reports {

        // MARK: - Weekly Review

        enum WeeklyReview {
            static func keepingUp(currentTarget: String, nextTarget: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_keeping_up", default: "You are hitting your %@ steps/day target. Next week, we will bump it up to %@ steps/day."), currentTarget, nextTarget)
            }
            static func plateauing(currentTarget: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_plateauing", default: "You are close to your %@ steps/day target. Let us hold here this week and build the habit before pushing higher."), currentTarget)
            }
            static func struggling(currentTarget: String, nextTarget: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_struggling", default: "This week was tough at %@ steps/day. We will drop to %@ steps/day next week so it feels doable."), currentTarget, nextTarget)
            }
        }

        // MARK: - Weekly Review View

        enum WeeklyReviewView {
            static var title: String { RemoteConfigManager.shared.copyString("copy_reports_weekly_review_view_title", default: "Your Weekly Review") }
            static func score(_ score: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_view_score", default: "Score %d"), score) }
            static func coachTarget(_ steps: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_weekly_review_view_coach_target", default: "Coach target: %@ steps/day"), steps) }
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
            static func stepTarget(_ steps: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_reports_step_target", default: "Step target: %@ steps/day"), steps) }
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
