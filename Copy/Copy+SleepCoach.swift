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

        static let sleepDebt = "Sleep Debt"
        static let currentDebt = "Current Debt"
        static func daysToPayOff(_ days: Int) -> String { "\(days) days to pay off" }

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
        static let needsWork = "Needs Work"
        static let irregular = "Irregular"

        static let consistencyExcellent = "Your sleep schedule is very consistent. This helps maintain a strong circadian rhythm."
        static let consistencyGood = "Fairly consistent schedule. Try to reduce variability on weekends for better results."
        static let consistencyNeedsWork = "Your sleep timing varies quite a bit. More consistency could improve sleep quality."
        static let consistencyIrregular = "Highly variable sleep schedule. Your body struggles to establish a rhythm. Try fixing your wake time first."

        // MARK: - Tips

        static let payingOffDebtTitle = "Paying Off Debt"
        static let sleepTips = "Sleep Tips"

        // Debt tips
        static let tipAddSleepTitle = "Add 30-60 min per night"
        static let tipAddSleepDetail = "Go to bed slightly earlier rather than sleeping in late to preserve your rhythm."
        static func tipBePatientDetail(days: Int) -> String {
            "Pay off debt gradually over \(days) days. Avoid marathon sleep sessions."
        }
        static let tipBePatientTitle = "Be patient"
        static let tipCutCaffeineTitle = "Cut caffeine after 2 PM"
        static let tipCutCaffeineDetail = "Caffeine has a 6-hour half-life and can reduce deep sleep even if you fall asleep fine."
        static let tipScreenCurfewTitle = "Screen curfew"
        static let tipScreenCurfewDetail = "Stop screens 45 minutes before bed. Blue light suppresses melatonin production."

        // General tips
        static let tipConsistentScheduleTitle = "Keep a consistent schedule"
        static let tipConsistentScheduleDetail = "Go to bed and wake up at the same time daily, even on weekends."
        static let tipCoolBedroomTitle = "Cool your bedroom"
        static let tipCoolBedroomDetail = "Optimal sleep temperature is 65-68\u{00B0}F (18-20\u{00B0}C). Your body needs to cool down to sleep."
        static let tipMorningSunlightTitle = "Morning sunlight"
        static let tipMorningSunlightDetail = "Get 10-15 minutes of bright light within an hour of waking to anchor your circadian rhythm."
        static let tipExerciseTimingTitle = "Exercise timing"
        static let tipExerciseTimingDetail = "Regular exercise improves sleep quality, but finish vigorous workouts 3+ hours before bed."
    }
}
