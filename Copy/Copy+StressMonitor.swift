import Foundation

extension Copy {
    enum StressMonitor {

        // MARK: - Hero

        static let ofScale = "of 3.0"

        // MARK: - Drivers

        static let whatsDrivingStress = "What Is Driving Your Stress"
        static let hrvDeviation = "Heart Rate Variability"
        static let hrElevation = "Heart Rate"

        // MARK: - History

        static let sevenDayStress = "7 Day Stress"
        static let notEnoughData = "Not enough data yet"

        // MARK: - Tips

        static let reduceStress = "Reduce Stress"
        static let startBreathingExercise = "Start Breathing Exercise"
        static let primaryTip = "Try This First"
        static let moreTips = "More Ideas"
        static let moreTipsHint = "Other ways to settle your nervous system."

        // MARK: - Week Delta

        static func weekDeltaImproved(_ thisWeek: String, _ lastWeek: String, _ percent: Int) -> String {
            "Your stress eased \(percent)% this week. You are at \(thisWeek), down from \(lastWeek) last week."
        }
        static func weekDeltaIncreased(_ thisWeek: String, _ lastWeek: String, _ percent: Int) -> String {
            "Your stress rose \(percent)% this week. You are at \(thisWeek), up from \(lastWeek) last week."
        }
        static func weekDeltaSteady(_ thisWeek: String) -> String {
            "Your stress is steady at \(thisWeek) this week, close to last week."
        }
        static let weekSummaryTitle = "This Week"
    }

    enum Breathwork {

        // MARK: - Protocol Descriptions

        static let cyclicSighingDescription = "Double inhale, long exhale. A simple way to calm down fast."
        static let boxBreathingDescription = "Equal timed breathing to help you focus and stay steady."

        // MARK: - Session

        static let sessionInProgress = "Your breathing session is still in progress."
        static let chooseYourPractice = "Choose Your Practice"
        static let selectTechnique = "Pick a breathing technique to begin"
        static let beginSession = "Begin Session"
        static let sessionComplete = "Session Complete"
        static let howDoYouFeel = "How do you feel?"
    }
}
