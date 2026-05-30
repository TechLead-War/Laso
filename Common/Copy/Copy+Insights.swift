import Foundation

extension Copy {
    enum Insights {

        // MARK: - Summary Templates

        static func decliningSummary(metricLower: String, deviation: String, direction: String, baseline: String, unit: String, current: String, inflectionNote: String, projectionNote: String, causalHint: String, historyNote: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_declining_summary", default: "Your %@ is %@%% %@ your baseline (%@ %@). Current: %@ %@.%@%@%@%@"), metricLower, deviation, direction, baseline, unit, current, unit, inflectionNote, projectionNote, causalHint, historyNote)
        }
        static func improvingSummary(metricLower: String, deviation: String, current: String, unit: String, inflectionNote: String, causalHint: String, historyNote: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_improving_summary", default: "Your %@ has improved %@%% from your baseline. Current: %@ %@.%@%@%@"), metricLower, deviation, current, unit, inflectionNote, causalHint, historyNote)
        }
        static func stableSummary(metricLower: String, deviation: String, direction: String, baseline: String, unit: String, causalHint: String, historyNote: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_stable_summary", default: "Your %@ is %@%% %@ your baseline (%@ %@).%@%@"), metricLower, deviation, direction, baseline, unit, causalHint, historyNote)
        }
        static func projectionWarning(days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_projection_warning", default: " At the current rate, this could reach warning level in about %d days."), days)
        }
        static func priorityToday(actionProtocol: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_priority_today", default: "Priority today: %@."), actionProtocol)
        }

        // MARK: - Compound Insight Engine Titles

        static var healthBuildingMomentum: String { RemoteConfigManager.shared.copyString("copy_insights_health_building_momentum", default: "Your Health Is Building Momentum") }
        static var multipleMetricsDecliningTogether: String { RemoteConfigManager.shared.copyString("copy_insights_multiple_metrics_declining_together", default: "Multiple Metrics Declining Together") }
        static func newHealthPhase(_ label: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_new_health_phase", default: "New Health Phase: %@"), label) }
        static func troughProblem(_ name: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_trough_problem", default: "Your %@ Problem"), name) }
        static func categoriesLinked(_ a: String, _ b: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_categories_linked", default: "Your %@ and %@ Are Linked"), a, b) }
        static var mostResponsiveMetric: String { RemoteConfigManager.shared.copyString("copy_insights_most_responsive_metric", default: "Your Most Responsive Metric") }
        static var warningSignsConverging: String { RemoteConfigManager.shared.copyString("copy_insights_warning_signs_converging", default: "Warning Signs Converging") }
        static func tomorrowsRisk(_ percent: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_tomorrows_risk", default: "Tomorrow's Risk: %d%%"), percent) }
        static func biggestOpportunity(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_biggest_opportunity", default: "Biggest Opportunity: %@"), metric) }
        static var yourBestDayFormula: String { RemoteConfigManager.shared.copyString("copy_insights_your_best_day_formula", default: "Your Best-Day Formula") }
        static var recoveryUnderway: String { RemoteConfigManager.shared.copyString("copy_insights_recovery_underway", default: "Recovery Underway") }
        static var normalAcrossMetrics: String { RemoteConfigManager.shared.copyString("copy_insights_normal_across_metrics", default: "This state is characterized by normal levels across metrics.") }
        static func characterizedBy(_ descriptions: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_characterized_by", default: "Characterized by %@."), descriptions) }

        // MARK: - ML Risk Levels

        static var riskLevelHigh: String { RemoteConfigManager.shared.copyString("copy_insights_risk_level_high", default: "High") }
        static var riskLevelModerate: String { RemoteConfigManager.shared.copyString("copy_insights_risk_level_moderate", default: "Moderate") }
        static var riskLevelLow: String { RemoteConfigManager.shared.copyString("copy_insights_risk_level_low", default: "Low") }
        static var riskLevelVeryLow: String { RemoteConfigManager.shared.copyString("copy_insights_risk_level_very_low", default: "Very Low") }

        // MARK: - Today Intelligence

        static func highestInDays(days: Int, topPercent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_highest_in_days", default: "Highest in %d days (top %d%%)"), days, topPercent)
        }
        static func lowestInDays(days: Int, bottomPercent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_lowest_in_days", default: "Lowest in %d days (bottom %d%%)"), days, bottomPercent)
        }

        // MARK: - Day Names

        static var daySunday: String { RemoteConfigManager.shared.copyString("copy_insights_day_sunday", default: "Sunday") }
        static var dayMonday: String { RemoteConfigManager.shared.copyString("copy_insights_day_monday", default: "Monday") }
        static var dayTuesday: String { RemoteConfigManager.shared.copyString("copy_insights_day_tuesday", default: "Tuesday") }
        static var dayWednesday: String { RemoteConfigManager.shared.copyString("copy_insights_day_wednesday", default: "Wednesday") }
        static var dayThursday: String { RemoteConfigManager.shared.copyString("copy_insights_day_thursday", default: "Thursday") }
        static var dayFriday: String { RemoteConfigManager.shared.copyString("copy_insights_day_friday", default: "Friday") }
        static var daySaturday: String { RemoteConfigManager.shared.copyString("copy_insights_day_saturday", default: "Saturday") }

        // MARK: - ML Compound / Aggregator Title Templates

        static func discoveredPattern(_ patternType: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_discovered_pattern", default: "Discovered %@ Pattern"), patternType)
        }
        static func currentState(_ label: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_current_state", default: "Current State: %@"), label)
        }
        static func tomorrowOutlook(_ riskLevel: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_tomorrow_outlook", default: "Tomorrow Outlook: %@ Risk"), riskLevel)
        }
        static func activeWarning(_ predictedEvent: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_active_warning", default: "Active Warning: %@"), predictedEvent)
        }
        static var sequenceInProgress: String { RemoteConfigManager.shared.copyString("copy_insights_sequence_in_progress", default: "Sequence In Progress") }
        static func optimizationGap(_ percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_optimization_gap", default: "Optimization: %d%% Gap to Your Best"), percent)
        }
        static var yourIdealDayBlueprint: String { RemoteConfigManager.shared.copyString("copy_insights_your_ideal_day_blueprint", default: "Your Ideal Day Blueprint") }

        // MARK: - Inflection Notes

        static var accelerating: String { RemoteConfigManager.shared.copyString("copy_insights_accelerating", default: " The rate of change is speeding up.") }
        static var decelerating: String { RemoteConfigManager.shared.copyString("copy_insights_decelerating", default: " The drop is slowing down. A recovery may be starting.") }
        static var reversing: String { RemoteConfigManager.shared.copyString("copy_insights_reversing", default: " The trend has just turned around.") }

        // MARK: - Inflection Suffixes (for titles)

        static var andAccelerating: String { RemoteConfigManager.shared.copyString("copy_insights_and_accelerating", default: " & Accelerating") }
        static var slowing: String { RemoteConfigManager.shared.copyString("copy_insights_slowing", default: " (Slowing)") }
        static var dashReversing: String { RemoteConfigManager.shared.copyString("copy_insights_dash_reversing", default: " (Reversing)") }
        static var andGainingMomentum: String { RemoteConfigManager.shared.copyString("copy_insights_and_gaining_momentum", default: " & Gaining Momentum") }

        // MARK: - Title Patterns

        static func criticallyLow(_ metric: String, suffix: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_critically_low", default: "%@ Running Low%@"), metric, suffix)
        }
        static func needsAttention(_ metric: String, prefix: String, suffix: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_needs_attention", default: "%@ %@Worth a Look%@"), metric, prefix, suffix)
        }
        static func declining(_ metric: String, prefix: String, suffix: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_declining", default: "%@ %@Declining%@"), metric, prefix, suffix)
        }
        static func improving(_ metric: String, prefix: String, momentum: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_improving", default: "%@ %@Improving%@"), metric, prefix, momentum)
        }
        static func outsideSafeRange(_ metric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_outside_safe_range", default: "%@ Outside Your Usual Range"), metric)
        }
        static func elevated(_ metric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_elevated", default: "%@ Higher Than Usual"), metric)
        }
        static func stable(_ metric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_stable", default: "%@ Stable"), metric)
        }

        // MARK: - Follow-Up Sentences

        static var recheckIn48Hours: String { RemoteConfigManager.shared.copyString("copy_insights_recheck_in48_hours", default: "Follow up: Check again in 48 hours to make sure this is steadying before it reaches warning range.") }
        static var reviewIn3Days: String { RemoteConfigManager.shared.copyString("copy_insights_review_in3_days", default: "Follow up: Review this trend again in 3 days to confirm the direction has gotten better.") }

        // MARK: - Lead Time Labels

        static var sameDaySignal: String { RemoteConfigManager.shared.copyString("copy_insights_same_day_signal", default: "same-day signal") }
        static var nextDaySignal: String { RemoteConfigManager.shared.copyString("copy_insights_next_day_signal", default: "next-day signal") }
        static func dayLeadSignal(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_day_lead_signal", default: "%d-day lead signal"), days) }

        // MARK: - Evidence Labels

        static var evidenceHigh: String { RemoteConfigManager.shared.copyString("copy_insights_evidence_high", default: "high") }
        static var evidenceMedium: String { RemoteConfigManager.shared.copyString("copy_insights_evidence_medium", default: "medium") }
        static var evidenceEarly: String { RemoteConfigManager.shared.copyString("copy_insights_evidence_early", default: "early") }

        // MARK: - Projection

        static func projectedWarning(days: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_projected_warning", default: " At this rate, this could reach warning level in about %d days."), days)
        }

        // MARK: - Historical Context

        static func yoyChange(direction: String, percent: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_yoy_change", default: "%@ %@%% vs this time last year"), direction, percent)
        }
        static func percentileLabel(label: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_percentile_label", default: "in the %@ of your history"), label)
        }
        static func seasonalDeviation(direction: String, month: String, percent: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_seasonal_deviation", default: "%@ your usual %@ by %@%%"), direction, month, percent)
        }

        // MARK: - Causal Hints
        //
        // Generic guidance shown alongside per-metric insights. Earlier copies
        // led with "Based on your history…" which falsely implied the hint
        // was personalized from each user's data — it isn't, it's general
        // population guidance. Reworded as "Heads up:" / "Worth knowing:" to
        // stay honest while still being useful.

        static var causalHintHRV: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_hrv", default: "Heads up: this level often follows nights with less than 6 hours of sleep.") }
        static var causalHintRHR: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_rhr", default: "Heads up: a higher resting heart rate often follows times of less sleep or high stress. Try for an earlier bedtime tonight.") }
        static var causalHintBloodOxygen: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_blood_oxygen", default: "Worth knowing: lower blood oxygen often goes with broken sleep patterns.") }
        static var causalHintSleepDuration: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_sleep_duration", default: "Worth knowing: shorter sleep often follows days with low activity or late workouts.") }
        static var causalHintSleepDeep: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_sleep_deep", default: "Worth knowing: drops in deep sleep often go with higher stress or shifting bedtimes.") }
        static var causalHintVO2Max: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_vo2_max", default: "Worth knowing: VO2 Max changes tend to follow shifts in workout routine over 2 to 4 weeks.") }
        static var causalHintActiveCalories: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_active_calories", default: "Worth knowing: lower calorie burn often follows fewer steps and workout minutes.") }
        static var causalHintExercise: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_exercise", default: "Worth knowing: dips in exercise often line up with broken sleep patterns.") }
        static var causalHintBodyTemp: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_body_temp", default: "Worth knowing: changes in temperature often go with shifts in sleep length and HRV.") }
        static var causalHintRespiratoryRate: String { RemoteConfigManager.shared.copyString("copy_insights_causal_hint_respiratory_rate", default: "Worth knowing: breathing rate changes often track with sleep quality and stress levels.") }

        // MARK: - Action Protocol Strings

        static func sleepMetricsOff(dev: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_sleep_metrics_off", default: "Your sleep numbers are %d%% off your usual"), dev)
        }
        static func activityDeviation(dev: Int, direction: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_activity_deviation", default: "Your activity is %d%% %@ your recent average"), dev, direction)
        }
        static func hrvTrending(direction: String, dev: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_hrv_trending", default: "Your HRV is trending %@, %d%% from your usual"), direction, dev)
        }
        static func rhrShifted(dev: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_rhr_shifted", default: "Your resting heart rate shifted %d%% from your usual"), dev)
        }
        static func mindfulnessDeviation(dev: Int, direction: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_mindfulness_deviation", default: "Your mindfulness time is %d%% %@ your average"), dev, direction)
        }
        static func daylightDeviation(dev: Int, direction: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_daylight_deviation", default: "Your daylight time is %d%% %@ your average"), dev, direction)
        }
        static var bpOutsideRange: String { RemoteConfigManager.shared.copyString("copy_insights_bp_outside_range", default: "Your blood pressure reading is outside your usual range") }
        static var recheckSingleReading: String { RemoteConfigManager.shared.copyString("copy_insights_recheck_single_reading", default: "Check again to confirm, since single readings can vary") }
        static var readingOutsideRange: String { RemoteConfigManager.shared.copyString("copy_insights_reading_outside_range", default: "this reading is outside your usual range. Keep an eye on it.") }
        static var recheckMetricTrend: String { RemoteConfigManager.shared.copyString("copy_insights_recheck_metric_trend", default: "Check this again to confirm the trend") }
        static func bodyMetricsShifted(dev: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_body_metrics_shifted", default: "Your body numbers shifted %d%% from your usual"), dev)
        }
        static func vo2MaxTrending(direction: String, dev: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_vo2_max_trending", default: "Your VO2 max is trending %@, %d%% from your usual"), direction, dev)
        }
        static func mobilityMetricsOff(dev: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_mobility_metrics_off", default: "Your mobility numbers are %d%% off your usual"), dev)
        }
        static func genericMetricDeviation(metricName: String, dev: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_generic_metric_deviation", default: "Your %@ is %d%% from your usual"), metricName, dev)
        }

        // MARK: - Correlations

        enum Correlations {
            static var keyDiscoveries: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_key_discoveries", default: "Key Discoveries") }
            static var whyThingsChanged: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_why_things_changed", default: "Why Things Changed") }
            static var howMuchMatters: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_how_much_matters", default: "How Much It Matters") }
            static var allConnections: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_all_connections", default: "All Connections") }
            static var buildingIntelligence: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_building_intelligence", default: "Still building your insight profile.") }
            static var keepWearingDevice: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_keep_wearing_device", default: "Keep wearing your device and syncing daily so we can find patterns in your data.") }

            // MARK: - Detail / Cards

            static var navigationTitle: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_navigation_title", default: "Health Intelligence") }
            static var actionableBadge: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_actionable_badge", default: "Actionable") }
            static var evidenceLabel: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_evidence_label", default: "Evidence") }
            static var sameDay: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_same_day", default: "Same day") }
            static var nextDay: String { RemoteConfigManager.shared.copyString("copy_insights_correlations_next_day", default: "Next day") }
            static func correlationSummary(strength: String, dayLabel: String, effectPercent: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_correlations_correlation_summary", default: "%@ \u{00B7} %@ \u{00B7} %d%% effect"), strength, dayLabel, effectPercent)
            }
        }

        // MARK: - Insights Detail

        enum Detail {
            static var navigationTitle: String { RemoteConfigManager.shared.copyString("copy_insights_detail_navigation_title", default: "Insights") }
            static var emptyTitle: String { RemoteConfigManager.shared.copyString("copy_insights_detail_empty_title", default: "No insights yet") }
            static var emptyMessageAll: String { RemoteConfigManager.shared.copyString("copy_insights_detail_empty_message_all", default: "More data will open up deeper insights over time.") }
            static func emptyMessageFiltered(_ filter: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_detail_empty_message_filtered", default: "No %@ insights right now."), filter)
            }
        }

        // MARK: - Metric Detail

        enum MetricDetail {
            static func expandedRangeNotice(_ days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_metric_detail_expanded_range_notice", default: "Expanded to %d days to show available data"), days)
            }

            static var noDataYet: String { RemoteConfigManager.shared.copyString("copy_insights_no_data_yet", default: "No Data Yet") }

            static func noDataDescription(_ metricName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_metric_detail_no_data_description", default: "We do not have enough %@ data to show charts yet. Keep wearing your device and syncing daily."), metricName)
            }

            static var insights: String { RemoteConfigManager.shared.copyString("copy_insights_insights", default: "Insights") }
            static var outsideNormalRange: String { RemoteConfigManager.shared.copyString("copy_insights_outside_normal_range", default: "Outside Range") }

            static func baselineDeviation(_ deviation: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_metric_detail_baseline_deviation", default: "%@ from your usual"), deviation)
            }

            static var trend: String { RemoteConfigManager.shared.copyString("copy_insights_trend", default: "Trend") }
            static var forecast: String { RemoteConfigManager.shared.copyString("copy_insights_forecast", default: "Forecast") }
            static var periodAvg: String { RemoteConfigManager.shared.copyString("copy_insights_period_avg", default: "Period Avg") }
            static var outsideRange: String { RemoteConfigManager.shared.copyString("copy_insights_outside_range", default: "Outside Range") }
            static var withinRange: String { RemoteConfigManager.shared.copyString("copy_insights_within_range", default: "Within Range") }
            static var thisMonthVsLastMonth: String { RemoteConfigManager.shared.copyString("copy_insights_this_month_vs_last_month", default: "This Month vs Last Month") }
            static var scoreImpact: String { RemoteConfigManager.shared.copyString("copy_insights_score_impact", default: "Score Impact") }
            static var historicalContext: String { RemoteConfigManager.shared.copyString("copy_insights_historical_context", default: "Historical Context") }

            static func dataPointsSummary(_ count: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_metric_detail_data_points_summary", default: "Based on %d data points"), count)
            }
        }

        // MARK: - InsightCard Context Lines

        enum InsightCard {
            /// "Because" line showing the root cause metric and its deviation
            static func linkedToMetric(_ metricName: String, deviationPercent: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_insight_card_linked_to_metric", default: "May be linked to your %@ being %d%% off"), metricName, deviationPercent)
            }

            /// Fallback when we have a root cause metric but no deviation value
            static func connectedToMetric(_ metricName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_insight_card_connected_to_metric", default: "May be connected to your %@"), metricName)
            }

            /// Data basis line showing how many days of data back the finding
            static func basedOnDays(_ count: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_insight_card_based_on_days", default: "Based on %d days of your data"), count)
            }

            /// Confidence qualifier when we have a confidence level but no day count
            static func confidenceQualifier(_ level: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_insights_insights_insight_card_confidence_qualifier", default: "%@ confidence from your history"), level)
            }
        }

        // MARK: - Lifted interpolated view literals
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_x_text", default: "%d"), p0) }
        static func xText2(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_x_text2", default: "+%d"), p0) }
        static func stepChainText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_step_chain_text", default: "%d-step chain"), p0) }
        static func xText3(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_x_text3", default: "%d"), p0) }
        static func causalChainAffectingLabel(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_causal_chain_affecting_label", default: "Causal chain affecting %@"), p0) }
        static func daysText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_days_text", default: "%d days"), p0) }
        static func affectsLabel(_ p0: String, _ p1: String, _ p2: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_affects_label", default: "%@: %@ affects %@"), p0, p1, p2) }
        static func xText4(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_x_text4", default: "%@ → %@"), p0, p1) }
        static func xText5(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_insights_x_text5", default: "%d%%"), p0) }
    }
}
