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

        static let consistencyExcellent = "Your sleep schedule is very steady. This is great for your body clock."
        static let consistencyGood = "Pretty steady schedule. Try to keep weekends closer to your weekday timing."
        static let consistencyNeedsWork = "Your sleep timing jumps around. Even small improvements here can help you sleep better."
        static let consistencyIrregular = "Your sleep timing changes a lot. Waking up at the same time every day is the best place to start."

        // MARK: - Tips

        static let payingOffDebtTitle = "Restoring Balance"
        static let sleepTips = "Sleep Tips"

        // Debt tips
        static let tipAddSleepTitle = "Add 30-60 min per night"
        static let tipAddSleepDetail = "Going to bed a bit earlier works better than sleeping in late."
        static func tipBePatientDetail(days: Int) -> String {
            "Pay off debt gradually over \(days) days. Avoid marathon sleep sessions."
        }
        static let tipBePatientTitle = "Be patient"
        static let tipCutCaffeineTitle = "Caffeine timing"
        static let tipCutCaffeineDetail = "Caffeine stays in your body for hours. Stopping after 2 PM can help you sleep deeper."
        static let tipScreenCurfewTitle = "Screen wind down"
        static let tipScreenCurfewDetail = "Put screens away 45 minutes before bed. The bright light makes it harder for your brain to wind down."

        // General tips
        static let tipConsistentScheduleTitle = "Consistent schedule"
        static let tipConsistentScheduleDetail = "Going to bed and waking up at the same time, even on weekends, is one of the best things you can do for sleep."
        static let tipCoolBedroomTitle = "Cool bedroom"
        static let tipCoolBedroomDetail = "65 to 68\u{00B0}F (18 to 20\u{00B0}C) is the sweet spot. A cooler room helps you fall into deeper sleep."
        static let tipMorningSunlightTitle = "Morning sunlight"
        static let tipMorningSunlightDetail = "10 to 15 minutes of bright light within an hour of waking up helps set your body clock."
        static let tipExerciseTimingTitle = "Exercise timing"
        static let tipExerciseTimingDetail = "Regular exercise helps you sleep better. Try to finish hard workouts at least 3 hours before bed."
    }
}
