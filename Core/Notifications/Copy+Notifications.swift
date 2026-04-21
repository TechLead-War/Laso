import Foundation

extension Copy {
    enum Notifications {

        // MARK: - Alert Titles

        static func criticalMetric(_ name: String) -> String { "\(name) Worth a Look" }
        static func warningMetric(_ name: String) -> String { "\(name) Worth Monitoring" }

        // MARK: - Metric Action Hints (internal helpers)

        /// Picks a short, concrete action phrase for an anomaly based on metric + direction.
        /// Stays short so it fits inside the 160-char body budget.
        static func anomalyAction(metric: String, isAbove: Bool) -> String {
            let key = metric.lowercased()
            // HRV must be checked before "heart rate", because "heart rate variability"
            // contains the substring "heart rate".
            if key.contains("hrv") || key.contains("variability") {
                return isAbove ? "Nice sign of recovery." : "Consider an early night."
            }
            if key.contains("heart rate") || key.contains("resting") {
                return isAbove ? "Try a few slow breaths." : "Sit down, sip some water."
            }
            if key.contains("oxygen") || key.contains("spo2") {
                return "Rest and check again soon."
            }
            if key.contains("breath") || key.contains("respiratory") {
                return isAbove ? "A few slow, deep breaths can help." : "Worth a look if it continues."
            }
            if key.contains("sleep") {
                return "Aim for a calmer wind-down tonight."
            }
            if key.contains("steps") || key.contains("activity") {
                return "A short walk can reset things."
            }
            return "Worth a look."
        }

        // MARK: - Heart Rate Alerts

        static let restingHRTitle = "Resting Heart Rate Higher Than Usual"
        static func restingHRElevated(current: Int, average: Int) -> String {
            let diff = current - average
            let pct = average > 0 ? Int(round(Double(diff) / Double(average) * 100)) : 0
            return "Your resting heart rate is \(current) bpm, \(pct)% above your \(average) bpm average. \u{2764}\u{FE0F} Rest up and check again later."
        }

        static let highHRTitle = "Heart Rate Above Your Usual"
        static func highHRBody(current: Int, threshold: Int) -> String {
            let diff = max(0, current - threshold)
            return "Your heart rate hit \(current) bpm, \(diff) bpm above your usual \(threshold) bpm ceiling. If you are not training, try a few slow breaths. \u{2764}\u{FE0F}"
        }

        static let lowHRTitle = "Heart Rate Below Your Usual"
        static func lowHRBody(current: Int, threshold: Int) -> String {
            let diff = max(0, threshold - current)
            return "Your heart rate dropped to \(current) bpm, \(diff) bpm below your usual \(threshold) bpm floor. If you feel dizzy, sit down and sip water. \u{2764}\u{FE0F}"
        }

        // MARK: - HRV

        static let hrvLowTitle = "HRV Running Low"
        static func hrvLowBody(current: Int, dropPercent: Int) -> String {
            "Because your HRV is \(current) ms, \(dropPercent)% below your recent average, you may feel stressed or worn down today. Take it easy and consider an early night. \u{1F634}"
        }

        // MARK: - Blood Oxygen

        static let spo2CriticalTitle = "Blood Oxygen Below Typical Range"
        static func spo2CriticalBody(value: String) -> String {
            "Your blood oxygen is \(value)%, below your usual range. Rest, breathe slowly, and check again in a few minutes. \u{1FAC1}"
        }

        static let spo2WarningTitle = "Blood Oxygen Worth Monitoring"
        static func spo2WarningBody(value: String) -> String {
            "Your blood oxygen reading is \(value)%, a touch lower than your typical range. Worth keeping an eye on. \u{1FAC1}"
        }

        // MARK: - Respiratory Rate

        static let respiratoryRateTitle = "Breathing Rate Higher Than Usual"
        static func respiratoryRateBody(current: String, average: String) -> String {
            "Your breathing rate is \(current) br/min, above your \(average) br/min average. A few slow, deep breaths can help reset it. \u{1FAC1}"
        }

        // MARK: - Anomaly Alerts

        static func anomalyBody(metric: String, deviation: String, direction: String, current: String, unit: String) -> String {
            let isAbove = direction.lowercased().contains("above")
            let action = anomalyAction(metric: metric, isAbove: isAbove)
            return "Because your \(metric) is \(deviation)% \(direction) your baseline (now \(current) \(unit)), it is worth a closer look. \(action)"
        }
        static func anomalyWarningBody(metric: String, deviation: String, direction: String) -> String {
            let isAbove = direction.lowercased().contains("above")
            let action = anomalyAction(metric: metric, isAbove: isAbove)
            return "Your \(metric) is \(deviation)% \(direction) your baseline. \(action)"
        }

        // MARK: - Trend Reversal

        static func trendRecoveringTitle(metric: String) -> String { "\(metric) Recovering" }
        static func trendRecoveringBody(metric: String) -> String {
            "Your \(metric) was declining, and now it is trending back up. Whatever you changed is working. \u{1F4C8}"
        }

        static func trendDecliningTitle(metric: String) -> String { "\(metric) Worth a Look" }
        static func trendDecliningBody(metric: String) -> String {
            "Your \(metric) was improving but has started slipping. Review your last few days of sleep, training, and stress. \u{1F4CA}"
        }

        // MARK: - Improvement Celebration

        static func improvementTitle(metric: String, percent: String) -> String {
            "\(metric) Up \(percent)%!"
        }
        static func improvementBody(metric: String) -> String {
            "Your \(metric) improved this week. Whatever you are doing, keep it going. \u{1F4AA}"
        }

        /// Optional richer body when the exact percent is available.
        static func improvementBody(metric: String, percent: String) -> String {
            "Your \(metric) is up \(percent)% this week. Whatever you are doing, keep it going. \u{1F4AA}"
        }

        // MARK: - Daily Summary

        static func dailySummaryTitle(score: Int, grade: String, suffix: String) -> String {
            "Health Score: \(score)/100 (\(grade))\(suffix)"
        }
        static func anomalyCallout(metric: String, direction: String, percent: String) -> String {
            "\(metric) \(direction) \(percent)%."
        }
        static func metricsNeedAttention(_ count: Int) -> String {
            "\(count) metric\(count == 1 ? "" : "s") worth a quick look."
        }
        static let allMetricsHealthy = "All metrics looking healthy!"
        static func actionPrefix(_ action: String) -> String { "Action: \(action)" }
        static func streakDays(_ days: Int) -> String { "\(days)-day streak!" }

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
                candidates.append((.curiosity, "Something shifted in your \(metric.lowercased()) overnight."))
            }
            if let delta = scoreDelta, abs(delta) >= 3 {
                candidates.append((.curiosity, "Your score moved overnight."))
            }
            if improvingDays >= 2 {
                candidates.append((.curiosity, "A pattern is forming in your data."))
            }

            // Loss-frame hooks
            if streakDays >= 3 {
                candidates.append((.lossFrame, "Your \(streakDays)-day streak expires tonight."))
            }
            if let delta = scoreDelta, delta <= -3 {
                candidates.append((.lossFrame, "You are losing ground from last week."))
            }
            if improvingDays == 0, let delta = scoreDelta, delta < 0 {
                candidates.append((.lossFrame, "Yesterday's gains are slipping."))
            }

            // Progress hooks (endowed progress)
            if improvingDays >= 3 {
                candidates.append((.progress, "\(improvingDays) days up. Keep the run going?"))
            }
            if streakDays > 0 && streakDays.isMultiple(of: 7) {
                candidates.append((.progress, "\(streakDays) days in. New milestone."))
            }
            if score >= 80 {
                candidates.append((.progress, "Score: \(score). You are in the top tier."))
            }

            // Personal record hooks
            if let metric = topAnomalyMetric, let pct = topAnomalyPercent, pct > 15 {
                candidates.append((.personalRecord, "Your \(metric.lowercased()) hit a new high."))
            }
            if score >= 90 {
                candidates.append((.personalRecord, "\(score). Your best score this month."))
            }
            if let delta = scoreDelta, delta >= 5 {
                candidates.append((.personalRecord, "Biggest jump in weeks: +\(delta) points."))
            }

            // Question hooks
            candidates.append((.question, "How did last night affect your body?"))
            if let metric = topAnomalyMetric {
                candidates.append((.question, "Why did your \(metric.lowercased()) change?"))
            }
            if score < 65 {
                candidates.append((.question, "What is pulling your score down?"))
            }

            // Filter out the last-used category
            let filtered = candidates.filter { $0.category.rawValue != lastCategory }
            let pool = filtered.isEmpty ? candidates : filtered

            // Pick the first match (data-driven priority order)
            if let chosen = pool.first {
                UserDefaults.standard.set(chosen.category.rawValue, forKey: AppKeys.Notifications.lastDailyHookCategory)
                return chosen.title
            }

            // Ultimate fallback
            UserDefaults.standard.set(HookCategory.curiosity.rawValue, forKey: AppKeys.Notifications.lastDailyHookCategory)
            return "Your morning health check is ready."
        }

        /// Body text. short, data-rich, complements the title.
        /// Structure: score + one specific data point + one concrete action + optional streak.
        static func dynamicDailySummaryBody(
            score: Int,
            categoryBreakdown: String,
            topInsightAction: String?,
            streakDays: Int,
            anomalyCount: Int,
            topAnomalyMetric: String?,
            dayOfWeek: Int
        ) -> String {
            var parts: [String] = []

            // Score context (always include, payoff for tapping)
            parts.append("Score: \(score)/100.")

            // Most notable data point
            if anomalyCount > 0, let metric = topAnomalyMetric {
                parts.append("\(metric) needs a look. \u{1F4CA}")
            } else {
                let variants = [
                    "All metrics steady.",
                    "No red flags today.",
                    "Numbers looking solid.",
                    "Everything in range.",
                    "Clean across the board.",
                    "Body data looks good.",
                    "Healthy readings overall.",
                ]
                parts.append(variants[dayOfWeek % variants.count])
            }

            // Action (first sentence only)
            if let action = topInsightAction {
                parts.append(action)
            }

            // Streak (compact, loss-frame when long)
            if streakDays >= 3 {
                parts.append("\(streakDays)-day streak on the line.")
            } else if streakDays > 1 {
                parts.append("\(streakDays)-day streak.")
            }

            return parts.joined(separator: " ")
        }

        // MARK: - Evening Summary

        static func eveningSummaryTitle(strainLevel: String) -> String {
            "Today's Recap: \(strainLevel) Day"
        }
        static func eveningSummaryBody(strainLevel: String, score: Int) -> String {
            let anchor = bedtimeAnchor(for: strainLevel)
            return "A \(strainLevel.lowercased()) strain day closed at \(score)/100. \(anchor) \u{1F319}"
        }

        /// Picks a gentle bedtime anchor based on strain. Keeps things numeric without needing per-user data.
        private static func bedtimeAnchor(for strainLevel: String) -> String {
            switch strainLevel.lowercased() {
            case "high", "very high", "hard":
                return "Aim for lights-out by 10:30 PM to recover well."
            case "moderate", "medium":
                return "Aim for lights-out by 10:45 PM tonight."
            default:
                return "Aim for lights-out by 11:00 PM to protect tomorrow's score."
            }
        }

        // MARK: - Evening Wind-Down

        /// Rotated title variants. keep at 3-4 so the user never gets the same title two nights in a row.
        static func windDownTitle() -> String {
            let variants = [
                "Time to wind down",
                "Your body is asking for rest",
                "Sleep window opening",
                "Ease into the night"
            ]
            let defaults = UserDefaults.standard
            let lastIndex = defaults.integer(forKey: AppKeys.Notifications.windDownVariantIndex)
            let nextIndex = (lastIndex + 1) % variants.count
            defaults.set(nextIndex, forKey: AppKeys.Notifications.windDownVariantIndex)
            return variants[nextIndex]
        }

        /// Body for the wind-down push. Always includes the specific bedtime as a hard number.
        /// `hrvHint` is an optional lead-in like "Your HRV suggests an early night" when data supports it.
        static func windDownBody(bedtimeDisplay: String, hrvHint: String?) -> String {
            if let hrvHint, !hrvHint.isEmpty {
                return "\(hrvHint) Aim for lights-out by \(bedtimeDisplay)."
            }
            let variants = [
                "Start dimming the lights. Aim for lights-out by \(bedtimeDisplay).",
                "Your predicted bedtime is \(bedtimeDisplay). Step away from screens and breathe.",
                "Wind down now to hit lights-out by \(bedtimeDisplay).",
                "Tonight's target bedtime is \(bedtimeDisplay). Give yourself the runway."
            ]
            // Reuse the rotation index (set by windDownTitle this same firing) so body stays in sync.
            let index = UserDefaults.standard.integer(forKey: AppKeys.Notifications.windDownVariantIndex)
            return variants[index % variants.count]
        }

        // MARK: - Weekly Summary

        static func weeklyReportTitle(score: Int, change: String) -> String {
            "Weekly Report: \(score)/100 (\(change))"
        }
        static func improvedCount(_ count: Int) -> String { "\(count) improved" }
        static func declinedCount(_ count: Int) -> String { "\(count) declined" }
        static let topMovers = "Top movers: "

        /// Rich one-liner highlighting top improver + top decliner with percentages.
        /// Caller passes already-formatted percent strings (e.g. "+12%" / "-8%").
        static func weeklyTopMoversHighlight(
            improver: (metric: String, changeText: String)?,
            decliner: (metric: String, changeText: String)?
        ) -> String? {
            switch (improver, decliner) {
            case let (imp?, dec?):
                return "\(imp.metric) leads at \(imp.changeText), while \(dec.metric) slipped \(dec.changeText). \u{1F4CA}"
            case let (imp?, nil):
                return "\(imp.metric) is your top climber at \(imp.changeText). \u{1F4AA}"
            case let (nil, dec?):
                return "\(dec.metric) slipped the most, down \(dec.changeText). Worth a closer look."
            default:
                return nil
            }
        }

        // MARK: - Reengagement

        static let healthSnapshot = "Your Health Snapshot Is Waiting"
        static func lastScoreBody(score: Int) -> String {
            "Your last score was \(score)/100. It has been 3 days, and your trends are shifting without you. \u{1F4CA}"
        }
        /// Richer reengagement body when a trend direction is known.
        static func lastScoreBody(score: Int, trendingMetric: String, direction: String) -> String {
            "Your last score was \(score)/100. It has been 3 days, and your \(trendingMetric.lowercased()) was \(direction.lowercased()). Catch the change before it slips. \u{1F4CA}"
        }
        static let insightsReady = "Your Health Insights Are Ready"
        static let insightsReadyBody = "It has been a few days since you checked in. Open Laso to see what your body did while you were away. \u{1F4CA}"

        /// Loss-framed, data-grounded body referencing the user's actual last HRV + trend direction.
        /// Rotated by days-inactive so a repeat lapser sees a fresh framing each time.
        static func lapsedLossFrameBody(score: Int, hrvMs: Int, trend: TrendDirection, daysInactive: Int) -> String {
            let trendWord: String
            switch trend {
            case .improving: trendWord = "heading up"
            case .declining: trendWord = "slipping"
            case .stable:    trendWord = "holding steady"
            }
            let variants = [
                "Your sleep trend was \(trendWord) before you left. Your last HRV was \(hrvMs) ms. Open Laso to see what changed.",
                "Last score: \(score). HRV was \(hrvMs) ms and \(trendWord). Come back and see if the trend held.",
                "Before you stepped away, your HRV trend was \(trendWord) (\(hrvMs) ms). Check where it is today."
            ]
            let index = max(0, daysInactive) % variants.count
            return variants[index]
        }

        /// Lighter loss-frame when only a score is available (no HRV snapshot yet).
        static func lapsedScoreOnlyBody(score: Int, daysInactive: Int) -> String {
            let variants = [
                "Your last health score was \(score)/100. Come back to see what shifted while you were away.",
                "You were at \(score)/100 when you last checked in. Open Laso to see where you stand today.",
                "Score \(score) was your last read. A lot can move in a few days. Take a look."
            ]
            let index = max(0, daysInactive) % variants.count
            return variants[index]
        }

        // MARK: - Engagement Sequence

        static func engagementDay1Title(name: String?) -> String {
            if let name, !name.isEmpty {
                return "Morning check-in, \(name)"
            }
            return "Your first morning check-in"
        }

        static let engagementDay1Body = "Open Laso now to log your morning heart rate and start your recovery baseline. \u{2764}\u{FE0F}"

        static func engagementDay2Title(score: Int) -> String {
            "Your recovery score is \(score)"
        }

        static func engagementDay2Body(insight: String) -> String {
            "\(insight) Tap to see the full breakdown and today's one-minute action. \u{1F4CA}"
        }

        static let engagementDay2Fallback = "Tap to reveal today's recovery score and your one-minute morning action. \u{1F4CA}"

        static let engagementDay3Title = "A sleep pattern is forming"

        static func engagementDay3Body(finding: String) -> String {
            "\(finding) Open Laso to see what changed and a small tonight-only tweak to try. \u{1F634}"
        }

        static let engagementDay3Fallback = "Your sleep is starting to tell a story. Open Laso for the early pattern and a one-step tonight tweak. \u{1F634}"

        static func engagementDay5Title(percent: Int) -> String {
            "Personalization is \(percent)% complete"
        }

        static func engagementDay5Body(daysRemaining: Int) -> String {
            if daysRemaining <= 0 {
                return "Your baseline is ready. Open Laso to see patterns built from your first month of data. \u{1F4CA}"
            }
            return "Check in for \(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") to lock in a stronger personal baseline. \u{1F3AF}"
        }

        // Softer Day 5 variant used when the user has not yet seen a second recovery score.
        // Avoids claiming personalization has advanced when we do not actually have the data yet.
        static let engagementDay5SoftTitle = "Your baseline is still forming"
        static let engagementDay5SoftBody  = "Each morning check in sharpens your recovery picture. Open Laso to take the next step."

        static func engagementDay7Title(patternCount: Int) -> String {
            "We have found \(patternCount) early signals"
        }

        static func engagementDay7BodyTrend(metric: String, direction: String) -> String {
            "Your \(metric) is \(direction). Open Laso before the trend slips past you. \u{1F4C8}"
        }

        static func engagementDay7BodyGeneric(count: Int) -> String {
            "\(count) early patterns are waiting in your data. Open Laso to review them before they fade. \u{1F4CA}"
        }

        // MARK: - Watch Monitor

        static let watchBatteryLow = "Watch Battery Low"
        static func watchBatteryBody(device: String, percent: Int) -> String {
            "Your \(device) battery is at \(percent)%. Charge it soon to avoid missing health data."
        }
        static func watchNotWornScheduled(device: String, wearToTrack: String) -> String {
            "\(device) has not recorded data for a while. \(wearToTrack)"
        }
        static func watchNotWornHours(device: String, hours: Int, minutes: Int, wearToTrack: String) -> String {
            "\(device) has not recorded data for \(hours)h \(minutes)m. \(wearToTrack)"
        }
        static func watchNotWornRecent(device: String, wearToTrack: String) -> String {
            "\(device) has not recorded data recently. \(wearToTrack)"
        }

        // MARK: - Permission Re-prompt

        static let repromptTitle = "Stay on top of your health"
        static let repromptBody = "Notifications are off. You are missing alerts about unusual heart rate, sleep changes, and your weekly progress."
        static let repromptAction = "Turn On in Settings"
        static let repromptDismiss = "Not Now"
    }
}
