import Foundation

extension Copy {
    enum Explore {

        // MARK: - Navigation

        static var title: String { RemoteConfigManager.shared.copyString("copy_explore_explore_title", default: "Biology") }

        // MARK: - Score Hero

        static var healthScore: String { RemoteConfigManager.shared.copyString("copy_explore_explore_health_score", default: "Weekly Health Score") }
        static var healthScoreSubtitle: String { RemoteConfigManager.shared.copyString("copy_explore_explore_health_score_subtitle", default: "Updated each morning. Recent days count more.") }

        // MARK: - Score Guide overrides (Weekly variant)
        // Reuses the shared ScoreGuideSheet, but the four sentences below
        // describe the EWMA weekly behaviour instead of the live daily score.
        enum ScoreGuide {
            static var title: String { RemoteConfigManager.shared.copyString("copy_explore_explore_score_guide_title", default: "This is your Weekly Health Score") }
            static var description: String { RemoteConfigManager.shared.copyString("copy_explore_explore_score_guide_description", default: "A single number from 0 to 100 that shows how your body has been doing across the past two weeks, weighted toward your most recent days.") }
            static var howItsCalculatedBody: String { RemoteConfigManager.shared.copyString("copy_explore_explore_score_guide_how_its_calculated_body", default: "Your Weekly Health Score is a smoothed average of your daily scores from the past two weeks. Recent days count for more, and today is not included until the day is finished.") }
            static var whenItUpdatesBody: String { RemoteConfigManager.shared.copyString("copy_explore_explore_score_guide_when_it_updates_body", default: "Your Weekly Health Score refreshes each morning when yesterday is added to the average. It does not change during the day, even when new data syncs from Apple Health.") }
        }
        static func ptsThisWeek(_ delta: Int) -> String {
            let sign = delta > 0 ? "+" : ""
            return String(format: RemoteConfigManager.shared.copyString("copy_explore_pts_this_week", default: "%@%d pts this week"), sign, delta)
        }
        static func focusToImprove(_ category: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_explore_focus_to_improve", default: "%@ has the most room to grow"), category) }

        // Score labels
        static var excellentShape: String { RemoteConfigManager.shared.copyString("copy_explore_explore_excellent_shape", default: "Strong momentum") }
        static var lookingGood: String { RemoteConfigManager.shared.copyString("copy_explore_explore_looking_good", default: "Solid progress") }
        static var roomToImprove: String { RemoteConfigManager.shared.copyString("copy_explore_explore_room_to_improve", default: "Building up") }
        static var needsAttention: String { RemoteConfigManager.shared.copyString("copy_explore_explore_needs_attention", default: "Getting started") }

        // MARK: - Month Calendar
        //
        // The only place a person can see whether anything is actually getting
        // better. Every day the app scored is one cell, so the habit is visible.

        static var monthTitle: String { RemoteConfigManager.shared.copyString("copy_explore_month_title", default: "Your month") }
        static var monthTapHint: String { RemoteConfigManager.shared.copyString("copy_explore_month_tap_hint", default: "Tap a day") }
        static var monthToday: String { RemoteConfigManager.shared.copyString("copy_explore_month_today", default: "Today") }
        static var monthNoScore: String { RemoteConfigManager.shared.copyString("copy_explore_month_no_score", default: "No score for this day") }
        static func monthDayScore(_ score: Int, _ state: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_explore_month_day_score", default: "%1$d, %2$@"), score, state)
        }
        static var monthStreakLabel: String { RemoteConfigManager.shared.copyString("copy_explore_month_streak_label", default: "Days scored in a row") }
        static func monthStreakDays(_ days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_explore_month_streak_days", default: "%d days"), days)
        }
        static var monthStreakBest: String { RemoteConfigManager.shared.copyString("copy_explore_month_streak_best", default: "Keep it going") }
        static func monthScoredDays(_ scored: Int, _ total: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_explore_month_scored_days", default: "%1$d of %2$d days scored this month"), scored, total)
        }

        // MARK: - Data Summary

        static var metrics: String { RemoteConfigManager.shared.copyString("copy_explore_explore_metrics", default: "Metrics") }
        static var dataPoints: String { RemoteConfigManager.shared.copyString("copy_explore_explore_data_points", default: "Data Points") }
        static var day: String { RemoteConfigManager.shared.copyString("copy_explore_explore_day", default: "Day") }
        static var days: String { RemoteConfigManager.shared.copyString("copy_explore_explore_days", default: "Days") }
        static var insights: String { RemoteConfigManager.shared.copyString("copy_explore_explore_insights", default: "Insights") }

        // MARK: - Empty State

        static var yourHealthScore: String { RemoteConfigManager.shared.copyString("copy_explore_explore_your_health_score", default: "Your Health Score") }
        static var almostThere: String { RemoteConfigManager.shared.copyString("copy_explore_explore_almost_there", default: "Almost there...") }
        static var noDataYet: String { RemoteConfigManager.shared.copyString("copy_explore_explore_no_data_yet", default: "No data yet") }
        static var almostThereBody: String { RemoteConfigManager.shared.copyString("copy_explore_explore_almost_there_body", default: "A few more days of tracking and your score will be ready.") }
        static var noDataYetBody: String { RemoteConfigManager.shared.copyString("copy_explore_explore_no_data_yet_body", default: "Open the Health app and allow access to see your analysis.") }
        static var emptyStateSyncing: String { RemoteConfigManager.shared.copyString("copy_explore_explore_empty_state_syncing", default: "Syncing your first insights") }
        static var emptyStateSyncingBody: String { RemoteConfigManager.shared.copyString("copy_explore_explore_empty_state_syncing_body", default: "Apple Health is already connected. Explore will populate after the next batch of imported samples is analyzed.") }
        static var emptyStateConnectButton: String { RemoteConfigManager.shared.copyString("copy_explore_explore_empty_state_connect_button", default: "Connect Apple Health") }

        // MARK: - Areas to Focus

        static var needsAttentionHeader: String { RemoteConfigManager.shared.copyString("copy_explore_explore_needs_attention_header", default: "Areas to Focus") }

        // MARK: - Correlations

        static var connections: String { RemoteConfigManager.shared.copyString("copy_explore_explore_connections", default: "Connections") }
        static var seeAll: String { RemoteConfigManager.shared.copyString("copy_explore_explore_see_all", default: "See all") }

        // MARK: - Categories

        static var categories: String { RemoteConfigManager.shared.copyString("copy_explore_explore_categories", default: "Categories") }
        static var onTrack: String { RemoteConfigManager.shared.copyString("copy_explore_explore_on_track", default: "On track") }
        static var doingWell: String { RemoteConfigManager.shared.copyString("copy_explore_explore_doing_well", default: "Doing well") }
        static var needsWork: String { RemoteConfigManager.shared.copyString("copy_explore_explore_needs_work", default: "Opportunity") }
        static func insightCount(_ count: Int) -> String {
            let unit = count == 1
                ? RemoteConfigManager.shared.copyString("copy_explore_insight_count_singular", default: "insight")
                : RemoteConfigManager.shared.copyString("copy_explore_insight_count_plural", default: "insights")
            return String(format: RemoteConfigManager.shared.copyString("copy_explore_insight_count", default: "%d %@"), count, unit)
        }

        // MARK: - Why this week (declining metrics + their causal explanation)

        static var decliningTrends: String { RemoteConfigManager.shared.copyString("copy_explore_explore_declining_trends", default: "Why this week") }
        static var whyExplainerSubtitle: String { RemoteConfigManager.shared.copyString("copy_explore_explore_why_explainer_subtitle", default: "What changed and why, in plain English.") }
        static var whyTapToExplain: String { RemoteConfigManager.shared.copyString("copy_explore_explore_why_tap_to_explain", default: "Tap to see why") }

        // MARK: - Your Trends

        static var yourTrends: String { RemoteConfigManager.shared.copyString("copy_explore_explore_your_trends", default: "Your Trends") }
        static var trendPeriod: String { RemoteConfigManager.shared.copyString("copy_explore_explore_trend_period", default: "Trend period") }

        // MARK: - Health States

        static var healthStates: String { RemoteConfigManager.shared.copyString("copy_explore_explore_health_states", default: "Health States") }
        static var seeHealthStatePatterns: String { RemoteConfigManager.shared.copyString("copy_explore_explore_see_health_state_patterns", default: "See your health state patterns") }
        static func healthStateDuration(label: String, days: Int) -> String {
            let unit = days == 1
                ? RemoteConfigManager.shared.copyString("copy_explore_health_state_duration_day_singular", default: "day")
                : RemoteConfigManager.shared.copyString("copy_explore_health_state_duration_day_plural", default: "days")
            return String(format: RemoteConfigManager.shared.copyString("copy_explore_health_state_duration", default: "%@ for %d %@"), label, days, unit)
        }

        // MARK: - Strongest Category Pill

        static func strongest(_ category: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_strongest", default: "Strongest: %@"), category) }

        // MARK: - Pro Upsell

        static var pro: String { RemoteConfigManager.shared.copyString("copy_explore_pro", default: "PRO") }
        static var discoverHiddenConnections: String { RemoteConfigManager.shared.copyString("copy_explore_discover_hidden_connections", default: "Find hidden links between your health metrics.") }

        // MARK: - Declining Trends Section

        static func openMetric(_ name: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_open_metric", default: "Open %@"), name) }
        static func confidencePercent(_ percent: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_confidence_percent", default: "%d%% confidence"), percent) }

        // MARK: - Lifted view literals
        static var opensTheHealthStatesTimelineHint: String { RemoteConfigManager.shared.copyString("copy_explore_opens_the_health_states_timeline_hint", default: "Opens the health states timeline") }
        static var x: String { RemoteConfigManager.shared.copyString("copy_explore_x", default: "--") }
        static var opensMetricDetailsHint: String { RemoteConfigManager.shared.copyString("copy_explore_opens_metric_details_hint", default: "Opens metric details") }
        static var healthScoreInfoLabel: String { RemoteConfigManager.shared.copyString("copy_explore_health_score_info_label", default: "Health score info") }
        static var opensAnExplanationOfHowYourHint: String { RemoteConfigManager.shared.copyString("copy_explore_opens_an_explanation_of_how_your_hint", default: "Opens an explanation of how your health score is calculated") }
        static var x7d: String { RemoteConfigManager.shared.copyString("copy_explore_x7d", default: "7D") }
        static var x30d: String { RemoteConfigManager.shared.copyString("copy_explore_x30d", default: "30D") }
        static var x90d: String { RemoteConfigManager.shared.copyString("copy_explore_x90d", default: "90D") }
        static var trendTimeframeLabel: String { RemoteConfigManager.shared.copyString("copy_explore_trend_timeframe_label", default: "Trend timeframe") }
        static var switchesBetween7Day30DayHint: String { RemoteConfigManager.shared.copyString("copy_explore_switches_between7_day30_day_hint", default: "Switches between 7-day, 30-day, and 90-day views") }
        static var opensDetailedMetricHistoryHint: String { RemoteConfigManager.shared.copyString("copy_explore_opens_detailed_metric_history_hint", default: "Opens detailed metric history") }
        static var seeAllCausalExplanationsLabel: String { RemoteConfigManager.shared.copyString("copy_explore_see_all_causal_explanations_label", default: "See all causal explanations") }
        static var opensTheFullHealthIntelligenceViewHint: String { RemoteConfigManager.shared.copyString("copy_explore_opens_the_full_health_intelligence_view_hint", default: "Opens the full health intelligence view") }

        // MARK: - Lifted interpolated view literals
        static func categoryLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_category_label", default: "%@ category"), p0) }
        static func opensTheCategoryDetailHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_opens_the_category_detail_hint", default: "Opens the %@ category detail"), p0) }
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_x_text", default: "%d"), p0) }
        static func needsAttentionLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_needs_attention_label", default: "%@, needs attention"), p0) }
        static func impactValue(_ p0: Int, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_impact_value", default: "Impact %d. %@"), p0, p1) }
        static func xText2(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_x_text2", default: "%d"), p0) }
        static func scoreValue(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_score_value", default: "Score %d"), p0) }
        static func daysValue(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_days_value", default: "%d days"), p0) }
        static func trendLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_trend_label", default: "%@ trend"), p0) }
        static func decliningTrendLabel(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_declining_trend_label", default: "%@ declining trend, %@"), p0, p1) }
        static func opensDetailViewHint(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_explore_opens_detail_view_hint", default: "Opens %@ detail view"), p0) }
    }
}
