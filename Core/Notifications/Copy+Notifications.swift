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
            clip("\(name) Worth a Look", max: titleMax)
        }
        static func warningMetric(_ name: String) -> String {
            clip("\(name) Worth Monitoring", max: titleMax)
        }

        // MARK: - Heart Rate Alerts

        static let restingHRTitle = clip("Resting Heart Rate Higher Than Usual", max: titleMax)
        static func restingHRElevated(current: Int, average: Int) -> String {
            let diff = current - average
            let pct = average > 0 ? Int(round(Double(diff) / Double(average) * 100)) : 0
            return clip("Resting HR \(current) bpm, \(pct)% above your \(average) avg. Rest and recheck. \u{2764}\u{FE0F}", max: bodyMax)
        }

        static let highHRTitle = clip("Heart Rate Above Your Usual", max: titleMax)
        static func highHRBody(current: Int, threshold: Int) -> String {
            let diff = max(0, current - threshold)
            return clip("HR hit \(current) bpm, \(diff) above your usual \(threshold). Try a 60-second box breath. \u{2764}\u{FE0F}", max: bodyMax)
        }

        static let lowHRTitle = clip("Heart Rate Below Your Usual", max: titleMax)
        static func lowHRBody(current: Int, threshold: Int) -> String {
            let diff = max(0, threshold - current)
            return clip("HR dropped to \(current) bpm, \(diff) below your usual \(threshold). Sit and sip water. \u{2764}\u{FE0F}", max: bodyMax)
        }

        // MARK: - HRV

        static let hrvLowTitle = clip("HRV Running Low", max: titleMax)
        static func hrvLowBody(current: Int, dropPercent: Int) -> String {
            clip("HRV \(current) ms, \(dropPercent)% below recent average. Take it easy and aim for an early night. \u{1F634}", max: bodyMax)
        }

        // MARK: - Blood Oxygen

        static let spo2CriticalTitle = clip("Blood Oxygen Below Typical Range", max: titleMax)
        static func spo2CriticalBody(value: String) -> String {
            clip("Blood oxygen \(value)%, below your usual range. Rest 5 minutes, then recheck. \u{1FAC1}", max: bodyMax)
        }

        static let spo2WarningTitle = clip("Blood Oxygen Worth Monitoring", max: titleMax)
        static func spo2WarningBody(value: String) -> String {
            clip("Blood oxygen \(value)%, a touch below your typical range. Recheck in 10 min. \u{1FAC1}", max: bodyMax)
        }

        // MARK: - Respiratory Rate

        static let respiratoryRateTitle = clip("Breathing Rate Higher Than Usual", max: titleMax)
        static func respiratoryRateBody(current: String, average: String) -> String {
            clip("Breathing \(current) br/min, above your \(average) avg. Slow, deep breaths can reset it. \u{1FAC1}", max: bodyMax)
        }

        // MARK: - Anomaly Alerts

        /// Body shape: metric + magnitude + direction + value, then a single
        /// concrete tail from `MetricCue`. The old version concatenated a
        /// generic "Worth a closer look" prefix on top of the cue, which
        /// produced duplicated filler tails. One specific action only.
        static func anomalyBody(metric: String, deviation: String, direction: String, current: String, unit: String) -> String {
            let isAbove = direction.lowercased().contains("above")
            let cue = MetricCue.from(rawMetric: metric)
            return clip("Your \(metric) is \(deviation)% \(direction) usual (\(current) \(unit)). \(cue.tail(isAbove: isAbove))", max: bodyMax)
        }
        static func anomalyWarningBody(metric: String, deviation: String, direction: String) -> String {
            let isAbove = direction.lowercased().contains("above")
            let cue = MetricCue.from(rawMetric: metric)
            return clip("Your \(metric) is \(deviation)% \(direction) usual. \(cue.tail(isAbove: isAbove))", max: bodyMax)
        }

        // MARK: - Trend Reversal

        static func trendRecoveringTitle(metric: String) -> String { clip("\(metric) Recovering", max: titleMax) }
        static func trendRecoveringBody(metric: String) -> String {
            clip("\(metric) was declining, now trending back up. Whatever you changed is working. \u{1F4C8}", max: bodyMax)
        }

        static func trendDecliningTitle(metric: String) -> String { clip("\(metric) Worth a Look", max: titleMax) }
        static func trendDecliningBody(metric: String) -> String {
            clip("\(metric) was improving but is starting to slip. Review recent sleep and stress. \u{1F4CA}", max: bodyMax)
        }

        // MARK: - Improvement Celebration

        static func improvementTitle(metric: String, percent: String) -> String {
            clip("\(metric) Up \(percent)%!", max: titleMax)
        }
        static func improvementBody(metric: String) -> String {
            clip("Your \(metric) got better this week. Keep it going. \u{1F4AA}", max: bodyMax)
        }

        /// Optional richer body when the exact percent is available.
        static func improvementBody(metric: String, percent: String) -> String {
            clip("\(metric) is up \(percent)% this week. Keep it going. \u{1F4AA}", max: bodyMax)
        }

        // MARK: - Daily Summary

        static func dailySummaryTitle(score: Int, grade: String, suffix: String) -> String {
            clip("Health Score: \(score)/100 (\(grade))\(suffix)", max: titleMax)
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
            // Concrete deadline ("11:59 PM tonight") outperforms vague "tonight" in
            // Customer.io 2026 urgency tests because users can mentally schedule it.
            if streakDays >= 3 {
                candidates.append((.lossFrame, "Your \(streakDays)-day streak ends at 11:59 PM tonight."))
            }
            if let delta = scoreDelta, delta <= -3 {
                candidates.append((.lossFrame, "You are losing ground from last week."))
            }
            // Only fire the "slipping" loss frame when we have a concrete delta to cite.
            // Vague "Yesterday's gains are slipping" without data tested as filler.
            if improvingDays == 0, let delta = scoreDelta, delta < 0 {
                candidates.append((.lossFrame, "Down \(abs(delta)) since yesterday — easy to claw back."))
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
                return clip(chosen.title, max: titleMax)
            }

            // Ultimate fallback
            UserDefaults.standard.set(HookCategory.curiosity.rawValue, forKey: AppKeys.Notifications.lastDailyHookCategory)
            return clip("Your morning health check is ready.", max: titleMax)
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
                    "Numbers looking strong.",
                    "Everything in range.",
                    "Looking good across the board.",
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

            return clip(parts.joined(separator: " "), max: bodyMax)
        }

        // MARK: - Evening Summary

        static func eveningSummaryTitle(strainLevel: String) -> String {
            clip("Today's Recap: \(strainLevel) Day", max: titleMax)
        }

        /// `chronotypeBedtime` is the user's recent median bedtime, computed
        /// upstream by `BedtimeChronotype`. Optional so existing callers that
        /// have not been wired through still compile and fall back to the
        /// "10:45 PM" default inside `bedtimeAnchor`.
        static func eveningSummaryBody(strainLevel: String, score: Int, chronotypeBedtime: String? = nil) -> String {
            let anchor = bedtimeAnchor(strainLevel: strainLevel, chronotypeBedtime: chronotypeBedtime)
            return clip("\(strainLevel.lowercased()) day ended at \(score)/100. \(anchor) \u{1F319}", max: bodyMax)
        }

        /// Compute a strain-adjusted bedtime display from the user's chronotype.
        /// `chronotypeBedtime` is the user's recent median bedtime, passed in
        /// by the scheduler. Hard days shift earlier by 15 min, easy days
        /// keep the chronotype anchor unchanged.
        private static func bedtimeAnchor(strainLevel: String, chronotypeBedtime: String?) -> String {
            let base = chronotypeBedtime ?? "10:45 PM"
            switch strainLevel.lowercased() {
            case "high", "very high", "hard":
                return "Lights out 15 min earlier than usual (around \(base))."
            case "moderate", "medium":
                return "Lights out around \(base) tonight."
            default:
                return "Lights out by \(base) to protect tomorrow."
            }
        }

        // MARK: - Evening Wind-Down

        /// Rotated title variants. keep at 3-4 so the user never gets the same title two nights in a row.
        static func windDownTitle() -> String {
            let variants = [
                "Time to wind down",
                "Your body is ready for rest",
                "Sleep window is opening",
                "Ease into the night"
            ]
            let defaults = UserDefaults.standard
            let lastIndex = defaults.integer(forKey: AppKeys.Notifications.windDownVariantIndex)
            let nextIndex = (lastIndex + 1) % variants.count
            defaults.set(nextIndex, forKey: AppKeys.Notifications.windDownVariantIndex)
            return clip(variants[nextIndex], max: titleMax)
        }

        /// Body for the wind-down push. Always includes the specific bedtime as a hard number.
        /// `hrvHint` is an optional lead-in like "Your HRV suggests an early night" when data supports it.
        /// `chronotypeBedtime` reserved for future scheduler wiring; the
        /// caller-supplied `bedtimeDisplay` already carries the resolved time.
        static func windDownBody(bedtimeDisplay: String, hrvHint: String?, chronotypeBedtime: String? = nil) -> String {
            if let hrvHint, !hrvHint.isEmpty {
                return clip("\(hrvHint) Lights out by \(bedtimeDisplay).", max: bodyMax)
            }
            let variants = [
                "Dim the lights. Lights out by \(bedtimeDisplay).",
                "Suggested bedtime is \(bedtimeDisplay). Step away from screens.",
                "Wind down now to hit lights out by \(bedtimeDisplay).",
                "Tonight's target bedtime is \(bedtimeDisplay)."
            ]
            // Reuse the rotation index (set by windDownTitle this same firing) so body stays in sync.
            let index = UserDefaults.standard.integer(forKey: AppKeys.Notifications.windDownVariantIndex)
            return clip(variants[index % variants.count], max: bodyMax)
        }

        // MARK: - Weekly Summary

        static func weeklyReportTitle(score: Int, change: String) -> String {
            clip("Weekly Report: \(score)/100 (\(change))", max: titleMax)
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
                return clip("\(imp.metric) leads at \(imp.changeText), while \(dec.metric) slipped to \(dec.changeText). \u{1F4CA}", max: bodyMax)
            case let (imp?, nil):
                return clip("\(imp.metric) is your top climber at \(imp.changeText). \u{1F4AA}", max: bodyMax)
            case let (nil, dec?):
                return clip("\(dec.metric) slipped the most, down \(dec.changeText). See what changed.", max: bodyMax)
            default:
                return nil
            }
        }

        // MARK: - Reengagement

        static let healthSnapshot = clip("Your Health Snapshot Is Waiting", max: titleMax)
        static func lastScoreBody(score: Int) -> String {
            clip("Last score \(score)/100. 3 days on, your trends have moved. View the dip. \u{1F4CA}", max: bodyMax)
        }
        /// Richer reengagement body when a trend direction is known.
        static func lastScoreBody(score: Int, trendingMetric: String, direction: String) -> String {
            clip("Last score \(score)/100. \(trendingMetric.lowercased()) was \(direction.lowercased()). Catch the change. \u{1F4CA}", max: bodyMax)
        }
        static let insightsReady = clip("Your Health Insights Are Ready", max: titleMax)
        static let insightsReadyBody = clip("It has been a few days. See what your body did while you were gone. \u{1F4CA}", max: bodyMax)

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
                "Sleep trend was \(trendWord). Last HRV \(hrvMs) ms. View the dip.",
                "Last score \(score). HRV \(hrvMs) ms, \(trendWord). Catch the change.",
                "HRV trend was \(trendWord) at \(hrvMs) ms. See where it stands today."
            ]
            let index = max(0, daysInactive) % variants.count
            return clip(variants[index], max: bodyMax)
        }

        /// Lighter loss-frame when only a score is available (no HRV snapshot yet).
        static func lapsedScoreOnlyBody(score: Int, daysInactive: Int) -> String {
            let variants = [
                "Last health score \(score)/100. See what changed while you were gone.",
                "You were at \(score)/100 last check-in. View where you stand today.",
                "Score \(score) was your last reading. Catch the change."
            ]
            let index = max(0, daysInactive) % variants.count
            return clip(variants[index], max: bodyMax)
        }

        // MARK: - Engagement Sequence

        static func engagementDay1Title(name: String?) -> String {
            if let name, !name.isEmpty {
                return clip("Morning check-in, \(name)", max: titleMax)
            }
            return clip("Your first morning check-in", max: titleMax)
        }

        static let engagementDay1Body = clip("Log your morning heart rate to start your recovery baseline. Check today's number. \u{2764}\u{FE0F}", max: bodyMax)

        static func engagementDay2Title(score: Int) -> String {
            clip("Your recovery score is \(score)", max: titleMax)
        }

        static func engagementDay2Body(insight: String) -> String {
            clip("\(insight) See what changed and today's one-minute action. \u{1F4CA}", max: bodyMax)
        }

        static let engagementDay2Fallback = clip("See today's recovery score and your one-minute morning action. \u{1F4CA}", max: bodyMax)

        static let engagementDay3Title = clip("A sleep pattern is forming", max: titleMax)

        static func engagementDay3Body(finding: String) -> String {
            clip("\(finding) See what changed and a small tweak to try tonight. \u{1F634}", max: bodyMax)
        }

        static let engagementDay3Fallback = clip("Your sleep is starting to tell a story. See the early pattern and a small tweak. \u{1F634}", max: bodyMax)

        static func engagementDay5Title(percent: Int) -> String {
            clip("Personalization is \(percent)% complete", max: titleMax)
        }

        static func engagementDay5Body(daysRemaining: Int) -> String {
            if daysRemaining <= 0 {
                return clip("Your baseline is ready. See patterns built from your first month of data. \u{1F4CA}", max: bodyMax)
            }
            return clip("Check in for \(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") to build a stronger baseline. \u{1F3AF}", max: bodyMax)
        }

        // Softer Day 5 variant used when the user has not yet seen a second recovery score.
        // Avoids claiming personalization has advanced when we do not actually have the data yet.
        static let engagementDay5SoftTitle = clip("Your baseline is still forming", max: titleMax)
        static let engagementDay5SoftBody  = clip("Each morning check-in makes your recovery picture clearer. Check today's number.", max: bodyMax)

        static func engagementDay7Title(patternCount: Int) -> String {
            clip("We have found \(patternCount) early signals", max: titleMax)
        }

        static func engagementDay7BodyTrend(metric: String, direction: String) -> String {
            clip("Your \(metric) is \(direction). Read the 30-sec note before the trend slips. \u{1F4C8}", max: bodyMax)
        }

        static func engagementDay7BodyGeneric(count: Int) -> String {
            clip("\(count) early patterns waiting in your data. Read the 30-sec note before they fade. \u{1F4CA}", max: bodyMax)
        }

        // MARK: - Watch Monitor

        static let watchBatteryLow = clip("Watch Battery Low", max: titleMax)
        static func watchBatteryBody(device: String, percent: Int) -> String {
            clip("\(device) battery at \(percent)%. Charge it soon to avoid missing health data.", max: bodyMax)
        }
        static func watchNotWornScheduled(device: String, wearToTrack: String) -> String {
            clip("\(device) has not recorded data for a while. \(wearToTrack)", max: bodyMax)
        }
        static func watchNotWornHours(device: String, hours: Int, minutes: Int, wearToTrack: String) -> String {
            clip("\(device) has not recorded data for \(hours)h \(minutes)m. \(wearToTrack)", max: bodyMax)
        }
        static func watchNotWornRecent(device: String, wearToTrack: String) -> String {
            clip("\(device) has not recorded data recently. \(wearToTrack)", max: bodyMax)
        }

        // MARK: - Permission Re-prompt

        static let repromptTitle = clip("Stay on top of your health", max: titleMax)
        static let repromptBody = clip("Notifications are off. You are missing alerts on heart rate, sleep, and weekly progress.", max: bodyMax)
        static let repromptAction = "Turn On in Settings"
        static let repromptDismiss = "Not Now"
    }
}
