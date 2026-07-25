import Foundation

extension Copy {
    enum Notifications {

        // MARK: - Length Budgets

        /// Airship 2026 health & fitness benchmark: titles over 50 chars get
        /// truncated by iOS notification UI. OneSignal 2026 confirms <=50.
        private static let titleMax = 50
        /// Airship 2026: bodies under 100 chars receive ~11x the click-through
        /// of bodies over 300. 90 leaves headroom for emoji + iOS truncation.
        private static let bodyMax  = 90

        /// Hard cap a string at `max` chars, breaking at the last space if possible.
        /// Used to enforce title and body budgets per Airship 2026 health & fitness
        /// optimum (under-100-char bodies get ~11x the click rate).
        static func clip(_ s: String, max: Int) -> String {
            if s.count <= max { return s }
            let cutoff = s.index(s.startIndex, offsetBy: max - 1)
            let head = s[..<cutoff]
            if let lastSpace = head.lastIndex(of: " ") {
                return String(head[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines) + "."
            }
            return String(head) + "."
        }

        // MARK: - Alert Titles

        static func criticalMetric(_ name: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_critical_metric", default: "Check your %@"), name), max: titleMax)
        }
        static func warningMetric(_ name: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_warning_metric", default: "Keep an eye on %@"), name), max: titleMax)
        }

        // MARK: - Heart Rate Alerts

        static var restingHRTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_resting_h_r_title", default: "Your resting heart rate is up"), max: titleMax) }
        static func restingHRElevated(current: Int, average: Int) -> String {
            let diff = current - average
            let pct = average > 0 ? Int(round(Double(diff) / Double(average) * 100)) : 0
            return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_resting_h_r_elevated", default: "Your resting heart rate is %d, about %d%% above your usual %d. Rest and check again."), current, pct, average), max: bodyMax)
        }

        static var highHRTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_high_h_r_title", default: "Your heart rate is high right now"), max: titleMax) }
        static func highHRBody(current: Int, threshold: Int) -> String {
            let diff = max(0, current - threshold)
            return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_high_h_r_body", default: "Your heart rate is %d, about %d above your usual %d. Breathe slowly for a minute."), current, diff, threshold), max: bodyMax)
        }

        static var lowHRTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_low_h_r_title", default: "Your heart rate is low right now"), max: titleMax) }
        static func lowHRBody(current: Int, threshold: Int) -> String {
            let diff = max(0, threshold - current)
            return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_low_h_r_body", default: "Your heart rate dropped to %d, about %d below your usual %d. Sit down and sip water."), current, diff, threshold), max: bodyMax)
        }

        // MARK: - HRV

        static var hrvLowTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_hrv_low_title", default: "Your body needs more rest"), max: titleMax) }
        static func hrvLowBody(current: Int, dropPercent: Int) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_hrv_low_body", default: "Your recovery is %d, about %d%% below usual. Take it easy and sleep early tonight."), current, dropPercent), max: bodyMax)
        }

        // MARK: - Blood Oxygen

        static var spo2CriticalTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_spo2_critical_title", default: "Your blood oxygen looks low"), max: titleMax) }
        static func spo2CriticalBody(value: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_spo2_critical_body", default: "Your blood oxygen is %@%%, lower than usual. Rest for five minutes, then check again."), value), max: bodyMax)
        }

        static var spo2WarningTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_spo2_warning_title", default: "Keep an eye on your blood oxygen"), max: titleMax) }
        static func spo2WarningBody(value: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_spo2_warning_body", default: "Your blood oxygen is %@%%, a little low. Check again in ten minutes."), value), max: bodyMax)
        }

        // MARK: - Respiratory Rate

        static var respiratoryRateTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_respiratory_rate_title", default: "Your breathing is faster than usual"), max: titleMax) }
        static func respiratoryRateBody(current: String, average: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_respiratory_rate_body", default: "You are breathing %@ times a minute, above your usual %@. Slow, deep breaths can help."), current, average), max: bodyMax)
        }

        // MARK: - Metric Cue Tails
        //
        // Action-led closing sentences appended to anomaly bodies, resolved by
        // `MetricCue.tail(isAbove:)`. One key per metric/direction pair.

        static var cueHRVAbove: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_hrv_above", default: "Your body is recovering well.") }
        static var cueHRVBelow: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_hrv_below", default: "Try to sleep early tonight.") }
        static var cueHeartRateAbove: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_heart_rate_above", default: "Breathe slowly for a minute.") }
        static var cueHeartRateBelow: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_heart_rate_below", default: "Sit down, sip water, and check again in ten minutes.") }
        static var cueBloodOxygen: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_blood_oxygen", default: "Rest for five minutes, then check again.") }
        static var cueRespiratoryAbove: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_respiratory_above", default: "Slow, deep breaths can help.") }
        static var cueRespiratoryBelow: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_respiratory_below", default: "Check again if it stays low.") }
        static var cueSleep: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_sleep", default: "Wind down calmly tonight.") }
        static var cueActivity: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_activity", default: "A short walk will help.") }
        static var cueOther: String { RemoteConfigManager.shared.copyString("copy_notifications_cue_other", default: "Take a look when you can.") }

        // MARK: - Anomaly Alerts

        /// Body shape: metric + magnitude + direction + value, then a single
        /// concrete tail from `MetricCue`. The old version concatenated a
        /// generic "Worth a closer look" prefix on top of the cue, which
        /// produced duplicated filler tails. One specific action only.
        static func anomalyBody(metric: String, deviation: String, direction: String, current: String, unit: String) -> String {
            let isAbove = direction.lowercased().contains("above")
            let cue = MetricCue.from(rawMetric: metric)
            return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_anomaly_body", default: "Your %@ is %@%% %@ usual (%@ %@). %@"), metric, deviation, direction, current, unit, cue.tail(isAbove: isAbove)), max: bodyMax)
        }
        static func anomalyWarningBody(metric: String, deviation: String, direction: String) -> String {
            let isAbove = direction.lowercased().contains("above")
            let cue = MetricCue.from(rawMetric: metric)
            return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_anomaly_warning_body", default: "Your %@ is %@%% %@ usual. %@"), metric, deviation, direction, cue.tail(isAbove: isAbove)), max: bodyMax)
        }

        // MARK: - Trend Reversal

        static func trendRecoveringTitle(metric: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_trend_recovering_title", default: "Your %@ is bouncing back"), metric), max: titleMax)
        }
        static func trendRecoveringBody(metric: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_trend_recovering_body", default: "Your %@ was dropping and is now going back up. Whatever you changed is working."), metric), max: bodyMax)
        }

        static func trendDecliningTitle(metric: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_trend_declining_title", default: "Keep an eye on your %@"), metric), max: titleMax)
        }
        static func trendDecliningBody(metric: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_trend_declining_body", default: "Your %@ was getting better but is slipping a little. Check your sleep and stress."), metric), max: bodyMax)
        }

        // MARK: - Improvement Celebration

        static func improvementTitle(metric: String, percent: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_improvement_title", default: "Your %@ is up %@%%"), metric, percent), max: titleMax)
        }
        static func improvementBody(metric: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_improvement_body", default: "Your %@ got better this week. Keep it going."), metric), max: bodyMax)
        }

        // MARK: - Daily Summary

        /// One-glance score line for the notification subtitle slot, e.g.
        /// "Recovery 82 (+5)". The title carries the hook, the subtitle the number.
        static func summaryScoreSubtitle(score: Int, delta: Int?) -> String {
            if let delta, delta != 0 {
                let signed = delta > 0 ? "+\(delta)" : "\(delta)"
                return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_summary_score_subtitle_delta", default: "Recovery %d (%@)"), score, signed), max: titleMax)
            }
            return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_summary_score_subtitle", default: "Recovery %d"), score), max: titleMax)
        }

        // MARK: - Dynamic Daily Summary (Psychology-Driven)

        /// Psychological hook categories. never repeat the same category two days in a row.
        enum HookCategory: String, CaseIterable {
            case curiosity      // Zeigarnik effect. open loop, must tap to resolve
            case lossFrame      // Loss aversion. what you are about to lose
            case progress       // Endowed progress + goal gradient
            case personalRecord // Self-reference effect. your personal data
            case question       // Direct question. triggers inner dialogue
        }

        /// Picks a title using the best available psychological hook.
        /// Rotates categories so the user never sees the same style twice in a row.
        static func dynamicDailySummaryTitle(
            score: Int,
            scoreDelta: Int?,
            streakDays: Int,
            topAnomalyMetric: String?,
            topAnomalyPercent: Double?,
            improvingDays: Int
        ) -> String {
            let lastCategory = UserDefaults.standard.string(forKey: AppKeys.Notifications.lastDailyHookCategory)

            // Build candidate hooks ranked by data strength, skip last-used category
            var candidates: [(category: HookCategory, title: String)] = []

            // Curiosity hooks (Zeigarnik)
            if let metric = topAnomalyMetric, let pct = topAnomalyPercent, abs(pct) >= 10 {
                candidates.append((.curiosity, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_curiosity_metric", default: "Your %@ changed overnight."), metric.lowercased())))
            }
            if let delta = scoreDelta, abs(delta) >= 3 {
                candidates.append((.curiosity, RemoteConfigManager.shared.copyString("copy_notifications_hook_curiosity_score", default: "Your score changed overnight.")))
            }
            if improvingDays >= 2 {
                candidates.append((.curiosity, RemoteConfigManager.shared.copyString("copy_notifications_hook_curiosity_pattern", default: "A pattern is showing up in your data.")))
            }

            // Loss-frame hooks
            // Concrete deadline ("11:59 PM tonight") outperforms vague "tonight" in
            // Customer.io 2026 urgency tests because users can mentally schedule it.
            if streakDays >= 3 {
                candidates.append((.lossFrame, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_loss_streak", default: "You are on a %d day roll. Keep it going tonight?"), streakDays)))
            }
            if let delta = scoreDelta, delta <= -3 {
                candidates.append((.lossFrame, RemoteConfigManager.shared.copyString("copy_notifications_hook_loss_ground", default: "A little below last week. Easy to pick back up.")))
            }
            // Only fire the "slipping" loss frame when we have a concrete delta to cite.
            // Vague "Yesterday's gains are slipping" without data tested as filler.
            if improvingDays == 0, let delta = scoreDelta, delta < 0 {
                candidates.append((.lossFrame, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_loss_delta", default: "A bit below yesterday, by %d. A small step gets it back."), abs(delta))))
            }

            // Progress hooks (endowed progress)
            if improvingDays >= 3 {
                candidates.append((.progress, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_progress_days_up", default: "%d days up. Keep it going?"), improvingDays)))
            }
            if streakDays > 0 && streakDays.isMultiple(of: 7) {
                candidates.append((.progress, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_progress_milestone", default: "%d days in. Nice work."), streakDays)))
            }
            if score >= 80 {
                candidates.append((.progress, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_progress_top_tier", default: "Your score is %d. That is really good."), score)))
            }

            // Personal record hooks
            if let metric = topAnomalyMetric, let pct = topAnomalyPercent, pct > 15 {
                candidates.append((.personalRecord, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_record_metric_high", default: "Your %@ hit a new high."), metric.lowercased())))
            }
            if score >= 90 {
                candidates.append((.personalRecord, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_record_best_score", default: "%d. Your best score this month."), score)))
            }
            if let delta = scoreDelta, delta >= 5 {
                candidates.append((.personalRecord, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_record_biggest_jump", default: "Your biggest jump in weeks: up %d."), delta)))
            }

            // Question hooks
            candidates.append((.question, RemoteConfigManager.shared.copyString("copy_notifications_hook_question_last_night", default: "How did last night affect your body?")))
            if let metric = topAnomalyMetric {
                candidates.append((.question, String(format: RemoteConfigManager.shared.copyString("copy_notifications_hook_question_metric_change", default: "Why did your %@ change?"), metric.lowercased())))
            }
            if score < 65 {
                candidates.append((.question, RemoteConfigManager.shared.copyString("copy_notifications_hook_question_score_down", default: "What is pulling your score down?")))
            }

            // Filter out the last-used category
            let filtered = candidates.filter { $0.category.rawValue != lastCategory }
            let pool = filtered.isEmpty ? candidates : filtered

            // Pick the first match (data-driven priority order)
            if let chosen = pool.first {
                UserDefaults.standard.set(chosen.category.rawValue, forKey: AppKeys.Notifications.lastDailyHookCategory)
                return clip(chosen.title, max: titleMax)
            }

            // Ultimate fallback
            UserDefaults.standard.set(HookCategory.curiosity.rawValue, forKey: AppKeys.Notifications.lastDailyHookCategory)
            return clip(RemoteConfigManager.shared.copyString("copy_notifications_hook_fallback", default: "Your morning health check is ready."), max: titleMax)
        }

        /// Body text. short, data-rich, complements the title.
        /// Structure: score + one specific data point + one concrete action + optional streak.
        static func dynamicDailySummaryBody(
            score: Int,
            topInsightAction: String?,
            streakDays: Int,
            anomalyCount: Int,
            topAnomalyMetric: String?,
            dayOfWeek: Int
        ) -> String {
            var parts: [String] = []

            // Score context (always include, payoff for tapping)
            parts.append(String(format: RemoteConfigManager.shared.copyString("copy_notifications_daily_body_score", default: "Your score is %d out of 100."), score))

            // Most notable data point
            if anomalyCount > 0, let metric = topAnomalyMetric {
                parts.append(String(format: RemoteConfigManager.shared.copyString("copy_notifications_daily_body_anomaly", default: "Your %@ needs a look."), metric))
            } else {
                let variants = RemoteConfigManager.shared.copyArray(
                    "copy_notifications_daily_body_steady_variants",
                    default: [
                        "Everything is steady.",
                        "Nothing to worry about today.",
                        "Your numbers look strong.",
                        "Everything is in range.",
                        "Looking good all around.",
                        "Your body data looks good.",
                        "Healthy readings overall.",
                    ]
                )
                if !variants.isEmpty {
                    parts.append(variants[dayOfWeek % variants.count])
                }
            }

            // Next step (first sentence only). Every daily push ends in an
            // action: when no insight produced one, point at the in-app step
            // instead of leaving a dead-end notification.
            if let action = topInsightAction {
                parts.append(String(format: RemoteConfigManager.shared.copyString("copy_notifications_daily_body_next_step", default: "Next step: %@"), action))
            } else {
                parts.append(RemoteConfigManager.shared.copyString("copy_notifications_daily_body_next_step_fallback", default: "Your next step is ready in the app."))
            }

            // Streak (compact, loss-frame when long)
            if streakDays >= 3 {
                parts.append(String(format: RemoteConfigManager.shared.copyString("copy_notifications_daily_body_streak_risk", default: "Your %d day streak is going strong."), streakDays))
            } else if streakDays > 1 {
                parts.append(String(format: RemoteConfigManager.shared.copyString("copy_notifications_daily_body_streak", default: "%d day streak."), streakDays))
            }

            return clip(parts.joined(separator: " "), max: bodyMax)
        }

        // MARK: - Evening Summary

        static func eveningSummaryTitle(strainLevel: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_evening_summary_title", default: "Today's recap: a %@ day"), strainLevel), max: titleMax)
        }

        /// `chronotypeBedtime` is the user's recent median bedtime. Optional so
        /// callers that have not been wired through still compile and fall back
        /// to the "10:45 PM" default inside `bedtimeAnchor`.
        static func eveningSummaryBody(strainLevel: String, score: Int, chronotypeBedtime: String? = nil) -> String {
            let anchor = bedtimeAnchor(strainLevel: strainLevel, chronotypeBedtime: chronotypeBedtime)
            return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_evening_summary_body", default: "Your %@ day ended at %d out of 100. %@"), strainLevel.lowercased(), score, anchor), max: bodyMax)
        }

        /// Compute a strain-adjusted bedtime display from the user's chronotype.
        /// `chronotypeBedtime` is the user's recent median bedtime, passed in
        /// by the scheduler. Hard days shift earlier by 15 min, easy days
        /// keep the chronotype anchor unchanged.
        private static func bedtimeAnchor(strainLevel: String, chronotypeBedtime: String?) -> String {
            let base = chronotypeBedtime ?? RemoteConfigManager.shared.copyString("copy_notifications_bedtime_anchor_default_time", default: "10:45 PM")
            switch strainLevel.lowercased() {
            case "high", "very high", "hard":
                return String(format: RemoteConfigManager.shared.copyString("copy_notifications_bedtime_anchor_hard", default: "Try to sleep 15 minutes earlier than usual (around %@)."), base)
            case "moderate", "medium":
                return String(format: RemoteConfigManager.shared.copyString("copy_notifications_bedtime_anchor_moderate", default: "Try to sleep around %@ tonight."), base)
            default:
                return String(format: RemoteConfigManager.shared.copyString("copy_notifications_bedtime_anchor_easy", default: "Sleep by %@ to feel good tomorrow."), base)
            }
        }

        // MARK: - Evening Wind-Down

        /// Rotated title variants. keep at 3-4 so the user never gets the same title two nights in a row.
        /// One-off reminder the user set from the Next Up action card. %@ is the
        /// action, e.g. "Wind down 30 minutes earlier tonight".
        static var actionReminderTitle: String { RemoteConfigManager.shared.copyString("copy_notifications_action_reminder_title", default: "Time for your one thing") }
        static func actionReminderBody(_ action: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_notifications_action_reminder_body", default: "%@"), action) }

        static func windDownTitle() -> String {
            let variants = RemoteConfigManager.shared.copyArray(
                "copy_notifications_wind_down_title_variants",
                default: [
                    "Time to wind down",
                    "Your body is ready for rest",
                    "Time to start heading to bed",
                    "Ease into the night"
                ]
            )
            guard !variants.isEmpty else { return "" }
            let defaults = UserDefaults.standard
            let lastIndex = defaults.integer(forKey: AppKeys.Notifications.windDownVariantIndex)
            let nextIndex = (lastIndex + 1) % variants.count
            defaults.set(nextIndex, forKey: AppKeys.Notifications.windDownVariantIndex)
            return clip(variants[nextIndex], max: titleMax)
        }

        /// HRV lead-in for the wind-down body, shown only when the last HRV reading is low.
        static func windDownHRVHint(ms: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_notifications_wind_down_hrv_hint", default: "Your recovery is low (%d), so an early night will help."), ms)
        }

        /// Body for the wind-down push. Always includes the specific bedtime as a hard number.
        /// `hrvHint` is an optional lead-in like "Your HRV suggests an early night" when data supports it.
        static func windDownBody(bedtimeDisplay: String, hrvHint: String?) -> String {
            if let hrvHint, !hrvHint.isEmpty {
                return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_wind_down_body_with_hint", default: "%@ Try to sleep by %@."), hrvHint, bedtimeDisplay), max: bodyMax)
            }
            let templates = RemoteConfigManager.shared.copyArray(
                "copy_notifications_wind_down_body_variants",
                default: [
                    "Dim the lights and aim to sleep by %@.",
                    "Try to sleep by %@. Put screens away.",
                    "Start winding down to sleep by %@.",
                    "Aim to be asleep by %@ tonight."
                ]
            )
            guard !templates.isEmpty else { return "" }
            // Reuse the rotation index (set by windDownTitle this same firing) so body stays in sync.
            let index = UserDefaults.standard.integer(forKey: AppKeys.Notifications.windDownVariantIndex)
            let template = templates[index % templates.count]
            return clip(String(format: template, bedtimeDisplay), max: bodyMax)
        }

        // MARK: - Weekly Summary

        static func weeklyReportTitle(score: Int, change: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_weekly_report_title", default: "Your week: %d out of 100 (%@)"), score, change), max: titleMax)
        }
        static func improvedCount(_ count: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_notifications_improved_count", default: "%d improved"), count) }
        static func declinedCount(_ count: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_notifications_declined_count", default: "%d declined"), count) }
        static var topMovers: String { RemoteConfigManager.shared.copyString("copy_notifications_top_movers", default: "Biggest changes: ") }

        // MARK: - Reengagement

        static var healthSnapshot: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_health_snapshot", default: "Your health update is waiting"), max: titleMax) }
        static var insightsReady: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_insights_ready", default: "Your health insights are ready"), max: titleMax) }
        static var insightsReadyBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_insights_ready_body", default: "It has been a few days. See what your body did while you were away."), max: bodyMax) }

        /// Loss-framed, data-grounded body referencing the user's actual last HRV + trend direction.
        /// Rotated by days-inactive so a repeat lapser sees a fresh framing each time.
        static func lapsedLossFrameBody(score: Int, hrvMs: Int, trend: TrendDirection, daysInactive: Int) -> String {
            let trendWord: String
            switch trend {
            case .improving: trendWord = RemoteConfigManager.shared.copyString("copy_notifications_lapsed_trend_improving", default: "heading up")
            case .declining: trendWord = RemoteConfigManager.shared.copyString("copy_notifications_lapsed_trend_declining", default: "slipping")
            case .stable:    trendWord = RemoteConfigManager.shared.copyString("copy_notifications_lapsed_trend_stable", default: "holding steady")
            }
            let templates = RemoteConfigManager.shared.copyArray(
                "copy_notifications_lapsed_loss_frame_variants",
                default: [
                    "Your sleep trend was %@. Your last recovery was %d. See what changed.",
                    "Your last score was %d. Recovery %d, %@. See what is new.",
                    "Your recovery was %@ at %d. See where it is today."
                ]
            )
            guard !templates.isEmpty else { return "" }
            let index = max(0, daysInactive) % templates.count
            let template = templates[index]
            // Variant 0 expects (trendWord, hrvMs); variant 1 expects (score, hrvMs, trendWord);
            // variant 2 expects (trendWord, hrvMs). Each variant pulls a fixed argument order
            // so operators editing in RC must match these placeholders to keep the meaning.
            let body: String
            switch index {
            case 0: body = String(format: template, trendWord, hrvMs)
            case 1: body = String(format: template, score, hrvMs, trendWord)
            default: body = String(format: template, trendWord, hrvMs)
            }
            return clip(body, max: bodyMax)
        }

        /// Lighter loss-frame when only a score is available (no HRV snapshot yet).
        static func lapsedScoreOnlyBody(score: Int, daysInactive: Int) -> String {
            let templates = RemoteConfigManager.shared.copyArray(
                "copy_notifications_lapsed_score_only_variants",
                default: [
                    "Your last score was %d out of 100. See what changed while you were away.",
                    "You were at %d out of 100 last time. See where you stand today.",
                    "Your last reading was %d. See what changed."
                ]
            )
            guard !templates.isEmpty else { return "" }
            let index = max(0, daysInactive) % templates.count
            return clip(String(format: templates[index], score), max: bodyMax)
        }

        // MARK: - Engagement Sequence

        static func engagementDay1Title(name: String?) -> String {
            if let name, !name.isEmpty {
                return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day1_title_named", default: "Morning check-in, %@"), name), max: titleMax)
            }
            return clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_day1_title", default: "Your first morning check-in"), max: titleMax)
        }

        static var engagementDay1Body: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_day1_body", default: "Log your morning heart rate so we learn what is normal for you. Check today's number."), max: bodyMax) }

        static func engagementDay2Title(score: Int) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day2_title", default: "Your recovery score is %d"), score), max: titleMax)
        }

        static func engagementDay2Body(insight: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day2_body", default: "%@ See what changed and today's quick action."), insight), max: bodyMax)
        }

        static var engagementDay2Fallback: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_day2_fallback", default: "See today's recovery score and your quick morning action."), max: bodyMax) }

        static var engagementDay2FallbackTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_day2_fallback_title", default: "Your morning health update"), max: titleMax) }

        static var engagementDay3Title: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_day3_title", default: "A sleep pattern is forming"), max: titleMax) }

        static func engagementDay3Body(finding: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day3_body", default: "%@ See what changed and one small thing to try tonight."), finding), max: bodyMax)
        }

        static var engagementDay3Fallback: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_day3_fallback", default: "Your sleep is starting to show a pattern. See it and one small thing to try."), max: bodyMax) }

        /// Interpolated sleep finding used inside `engagementDay3Body`. `direction` is a
        /// trend word from `trendWordUp`/`trendWordDown`, `percent` is a whole number.
        static func engagementDay3Finding(metric: String, direction: String, percent: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day3_finding", default: "Your %@ has been going %@ %d%% over the last few nights."), metric, direction, percent)
        }

        static var trendWordUp: String { RemoteConfigManager.shared.copyString("copy_notifications_trend_word_up", default: "up") }
        static var trendWordDown: String { RemoteConfigManager.shared.copyString("copy_notifications_trend_word_down", default: "down") }

        static func engagementDay5Title(percent: Int) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day5_title", default: "Your setup is %d%% done"), percent), max: titleMax)
        }

        static func engagementDay5Body(daysRemaining: Int) -> String {
            if daysRemaining <= 0 {
                return clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_day5_body", default: "We now know your normal. See patterns built from your first month of data."), max: bodyMax)
            }
            let dayUnit = daysRemaining == 1
                ? RemoteConfigManager.shared.copyString("copy_notifications_day_singular", default: "day")
                : RemoteConfigManager.shared.copyString("copy_notifications_day_plural", default: "days")
            return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day5_body_remaining", default: "Check in for %d more %@ so we learn your normal even better."), daysRemaining, dayUnit), max: bodyMax)
        }

        // Softer Day 5 variant used when the user has not yet seen a second recovery score.
        // Avoids claiming personalization has advanced when we do not actually have the data yet.
        static var engagementDay5SoftTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_day5_soft_title", default: "We are still learning your normal"), max: titleMax) }
        static var engagementDay5SoftBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_day5_soft_body", default: "Each morning check-in makes your recovery picture clearer. Check today's number."), max: bodyMax) }

        // MARK: - Engagement Default + Recovery Insights
        //
        // Used by EngagementSequenceScheduler for the unknown-day fallback and
        // the score-bucketed insight sentence interpolated into Day 2 bodies.

        static var engagementDefaultTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_default_title", default: "Your health update"), max: titleMax) }
        static var engagementDefaultBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_engagement_default_body", default: "Tap to see your latest health insights."), max: bodyMax) }

        static var insightWellRecovered: String { RemoteConfigManager.shared.copyString("copy_notifications_insight_well_recovered", default: "You are well rested today.") }
        static var insightLookingGood: String { RemoteConfigManager.shared.copyString("copy_notifications_insight_looking_good", default: "Good recovery. A nice day to stay active.") }
        static var insightModerate: String { RemoteConfigManager.shared.copyString("copy_notifications_insight_moderate", default: "Okay recovery. Listen to your body today.") }
        static var insightNeedsAttention: String { RemoteConfigManager.shared.copyString("copy_notifications_insight_needs_attention", default: "Your body is still catching up.") }
        static var insightRest: String { RemoteConfigManager.shared.copyString("copy_notifications_insight_rest", default: "Take it easy. Your body needs rest.") }

        static func engagementDay7Title(patternCount: Int) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day7_title", default: "We found %d early signs"), patternCount), max: titleMax)
        }

        static func engagementDay7BodyTrend(metric: String, direction: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day7_body_trend", default: "Your %@ is %@. Read the quick note before it changes."), metric, direction), max: bodyMax)
        }

        static func engagementDay7BodyGeneric(count: Int) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_engagement_day7_body_generic", default: "%d early patterns in your data. Read the quick note before they fade."), count), max: bodyMax)
        }

        // MARK: - Watch Monitor

        static func watchNotWornScheduled(device: String, wearToTrack: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_watch_not_worn_scheduled", default: "Your %@ has not recorded data in a while. %@"), device, wearToTrack), max: bodyMax)
        }

        // MARK: - Permission Re-prompt

        static var repromptTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_reprompt_title", default: "Stay on top of your health"), max: titleMax) }
        static var repromptBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_reprompt_body", default: "Notifications are off. You are missing updates on heart rate, sleep, and weekly progress."), max: bodyMax) }
        static var repromptAction: String { RemoteConfigManager.shared.copyString("copy_notifications_reprompt_action", default: "Turn On in Settings") }
        static var repromptDismiss: String { RemoteConfigManager.shared.copyString("copy_notifications_reprompt_dismiss", default: "Not Now") }

        // MARK: - Clinical Triage
        //
        // Single source of the three triage level words + the four decorated
        // templates. Severity.swift resolves through these so the level word
        // is one key, not duplicated across displayName/notificationPrefix.

        static var triageLevelNormal: String { RemoteConfigManager.shared.copyString("copy_notifications_triage_level_normal", default: "Normal") }
        static var triageLevelMonitor: String { RemoteConfigManager.shared.copyString("copy_notifications_triage_level_monitor", default: "Keep watching") }
        static var triageLevelSeekCare: String { RemoteConfigManager.shared.copyString("copy_notifications_triage_level_seek_care", default: "Worth a check") }

        static func triageAlertTitle(prefix: String, metric: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_notifications_triage_alert_title", default: "%@: %@"), prefix, metric)
        }
        static func triageAlertBody(reason: String, action: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_notifications_triage_alert_body", default: "%@ %@"), reason, action)
        }
        static func triageSummaryNote(level: String, action: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_notifications_triage_summary_note", default: "%@. %@"), level, action)
        }
        static func triageRecommendationDecorated(level: String, action: String, recommendation: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_notifications_triage_recommendation_decorated", default: "%@. %@ %@"), level, action, recommendation)
        }

        // MARK: - Onboarding Abandonment (Journey 1)
        //
        // Three reminders if the user drops out mid-onboarding. Copy restates
        // the progress already made and the answer still waiting. No guilt.

        static var abandonment2hTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_abandonment_2h_title", default: "You are almost set up"), max: titleMax) }
        static var abandonment2hBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_abandonment_2h_body", default: "You are one step away. Pick up where you left off and see what your body is telling you."), max: bodyMax) }

        static var abandonment24hTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_abandonment_24h_title", default: "Your first pattern is waiting"), max: titleMax) }
        static var abandonment24hBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_abandonment_24h_body", default: "Finish setting up and we will start checking the thing you asked about."), max: bodyMax) }

        static var abandonment72hTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_abandonment_72h_title", default: "Still here when you are ready"), max: titleMax) }
        static var abandonment72hBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_abandonment_72h_body", default: "It takes a minute to finish. Then we watch for the pattern you came here to understand."), max: bodyMax) }

        // MARK: - Trial Lifecycle (Journey 2 + 3)
        //
        // Day-1 getting started, day-3 insight nudge, and a reminder the day
        // before renewal. Timing is derived from the live StoreKit trial length
        // by the scheduler, never hardcoded here.

        static var trialGettingStartedTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_trial_getting_started_title", default: "Your first morning check-in"), max: titleMax) }
        static var trialGettingStartedBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_trial_getting_started_body", default: "Log how you feel this morning. It is the fastest way to start building your pattern."), max: bodyMax) }

        static var trialInsightNudgeTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_trial_insight_nudge_title", default: "A pattern is forming"), max: titleMax) }
        static var trialInsightNudgeBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_trial_insight_nudge_body", default: "A few days in, your data is starting to show a pattern. Open the app to see it."), max: bodyMax) }

        /// Scored variants, used when a recovery score is already cached so the
        /// nudge cites the user's own number instead of a generic line.
        static func trialGettingStartedBodyScored(score: Int) -> String { clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_trial_getting_started_body_scored", default: "Your recovery is %d this morning. Log how you feel and see if your body agrees."), score), max: bodyMax) }
        static func trialInsightNudgeBodyScored(score: Int) -> String { clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_trial_insight_nudge_body_scored", default: "Your recovery is %d and a pattern is showing up. Open the app to see what your data says."), score), max: bodyMax) }

        /// `daysLeft` is computed from the live trial end date by the scheduler.
        static func trialRenewalTitle(daysLeft: Int) -> String {
            if daysLeft <= 1 {
                return clip(RemoteConfigManager.shared.copyString("copy_notifications_trial_renewal_title_last", default: "Your trial ends tomorrow"), max: titleMax)
            }
            return clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_trial_renewal_title", default: "%d days left in your trial"), daysLeft), max: titleMax)
        }
        static var trialRenewalBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_trial_renewal_body", default: "Stay on to keep your weekly insights. You can manage your plan anytime in settings."), max: bodyMax) }

        /// Win-back after the trial expires (Journey 3). References the user's
        /// own tracked focus so the nudge is about their question, not a generic
        /// pitch. `focus` is the focus-area label supplied by the scheduler.
        static func trialWinbackTitle(focus: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_trial_winback_title", default: "Your %@ answer is still here"), focus), max: titleMax)
        }
        static func trialWinbackBody(focus: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_trial_winback_body", default: "Come back to see what your %@ data showed while you were away."), focus), max: bodyMax)
        }
        /// Win-back when no specific focus is stored.
        static var trialWinbackGenericTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_trial_winback_generic_title", default: "Your insights are still here"), max: titleMax) }
        static var trialWinbackGenericBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_trial_winback_generic_body", default: "Come back to see what your body data showed while you were away."), max: bodyMax) }

        // MARK: - Non-Trial Activation Welcome
        //
        // One push to a user who goes straight to a paid plan without a free
        // trial. Confirms the choice and points at first value, no countdown.

        static var nonTrialWelcomeTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_non_trial_welcome_title", default: "You are all set"), max: titleMax) }
        static var nonTrialWelcomeBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_non_trial_welcome_body", default: "Your plan is active. Log your first morning check in to start building your pattern."), max: bodyMax) }

        // MARK: - Cancelled But Active Save
        //
        // One push to a subscriber who turned off auto-renew but still has time
        // left. References the user's own focus so it is about what they lose.

        static func cancelledSaveTitle(focus: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_cancelled_save_title", default: "Keep your %@ insights"), focus), max: titleMax)
        }
        static func cancelledSaveBody(focus: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_cancelled_save_body", default: "Your plan ends soon. Turn renewal back on to keep tracking your %@ without a break."), focus), max: bodyMax)
        }
        static var cancelledSaveGenericTitle: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_cancelled_save_generic_title", default: "Keep your insights going"), max: titleMax) }
        static var cancelledSaveGenericBody: String { clip(RemoteConfigManager.shared.copyString("copy_notifications_cancelled_save_generic_body", default: "Your plan ends soon. Turn renewal back on to keep tracking without a break."), max: bodyMax) }

        // MARK: - Answer Ready (Journey 4)
        //
        // The cliffhanger payoff. Fires once when an inconclusive prediction
        // matures to a real verdict. Strongest, most specific push.

        /// `phrase` is the user's own goal or symptom words from onboarding.
        static func answerReadyTitle(phrase: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_answer_ready_title", default: "Your answer is ready"), phrase), max: titleMax)
        }
        static func answerReadyBody(phrase: String) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_answer_ready_body", default: "We have enough data on your %@ now. Open the app to see what it shows."), phrase), max: bodyMax)
        }

        // MARK: - Denied-Branch Re-permission (Journey 5)
        //
        // After 3 morning check-ins on the journal-first branch, one push that
        // restates the user's OWN logged words and offers to check the data.
        // Never an invented hypothesis.

        /// `phrase` and `count` come from the user's logged check-ins; the copy
        /// quotes their words verbatim, e.g. "waking up tired" + 3.
        static func repermissionTitle(count: Int) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_repermission_title", default: "%d mornings logged"), count), max: titleMax)
        }
        static func repermissionBody(phrase: String, count: Int) -> String {
            clip(String(format: RemoteConfigManager.shared.copyString("copy_notifications_repermission_body", default: "You logged %@ %d mornings. Want to see if your health data explains it?"), phrase, count), max: bodyMax)
        }
    }
}
