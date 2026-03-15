import Foundation

extension Copy {
    enum SleepCoach {

        // MARK: - Navigation

        static let title = "Sleep Coach"

        // MARK: - Hero

        static let tonight = "tonight"
        static func recommendedSleep(level: String) -> String {
            "Recommended sleep for \(level) performance"
        }

        // MARK: - Performance Level

        static let performanceLevel = "Performance Level"
        static let performanceLabel = "Performance"

        // MARK: - Schedule

        static let bedtime = "Bedtime"
        static let wakeUp = "Wake Up"

        // MARK: - Sleep Debt

        static let sleepDebt = "Sleep Balance"
        static let currentDebt = "Current Balance"
        static func daysToPayOff(_ days: Int) -> String { "\(days) days to recover" }

        // Debt levels
        static let debtClear = "Clear"
        static let debtLow = "Low"
        static let debtModerate = "Moderate"
        static let debtHigh = "High"

        // Debt trends
        static let tracking = "Tracking"
        static let payingOff = "Paying off"
        static let accumulating = "Accumulating"
        static let stable = "Stable"

        // MARK: - History

        static let fourteenDayHistory = "14-Day History"
        static let notEnoughDataYet = "Not enough data yet"

        // MARK: - Consistency

        static let consistency = "Consistency"
        static let excellent = "Excellent"
        static let good = "Good"
        static let needsWork = "Building"
        static let irregular = "Irregular"

        static let consistencyExcellent = "Your sleep schedule is very consistent. This helps maintain a strong circadian rhythm."
        static let consistencyGood = "Fairly consistent schedule. Try to reduce variability on weekends for better results."
        static let consistencyNeedsWork = "Your sleep timing varies quite a bit. Even small improvements in consistency can boost sleep quality."
        static let consistencyIrregular = "Highly variable sleep schedule. Anchoring a consistent wake time is often the most effective first step."

        // MARK: - Tips

        static let payingOffDebtTitle = "Restoring Balance"
        static let sleepTips = "Sleep Tips"

        // Debt tips
        static let tipAddSleepTitle = "Add 30-60 min per night"
        static let tipAddSleepDetail = "Going to bed slightly earlier preserves your rhythm better than sleeping in late."
        static func tipBePatientDetail(days: Int) -> String {
            "Pay off debt gradually over \(days) days. Avoid marathon sleep sessions."
        }
        static let tipBePatientTitle = "Be patient"
        static let tipCutCaffeineTitle = "Caffeine timing"
        static let tipCutCaffeineDetail = "Caffeine has a 6-hour half-life. Limiting it after 2 PM can protect your deep sleep."
        static let tipScreenCurfewTitle = "Screen wind-down"
        static let tipScreenCurfewDetail = "Winding down screens 45 min before bed helps — blue light suppresses melatonin production."

        // General tips
        static let tipConsistentScheduleTitle = "Consistent schedule"
        static let tipConsistentScheduleDetail = "A steady bed and wake time — even on weekends — is one of the strongest sleep levers."
        static let tipCoolBedroomTitle = "Cool bedroom"
        static let tipCoolBedroomDetail = "65-68\u{00B0}F (18-20\u{00B0}C) is the sweet spot. A cooler room helps your body drop into deeper sleep."
        static let tipMorningSunlightTitle = "Morning sunlight"
        static let tipMorningSunlightDetail = "10-15 minutes of bright light within an hour of waking anchors your circadian rhythm."
        static let tipExerciseTimingTitle = "Exercise timing"
        static let tipExerciseTimingDetail = "Regular exercise improves sleep quality. Finishing vigorous workouts 3+ hours before bed tends to work best."
    }
}
