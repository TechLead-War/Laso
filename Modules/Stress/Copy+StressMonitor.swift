import Foundation

extension Copy {
    enum StressMonitor {

        // MARK: - Navigation

        static let title = "Stress Monitor"

        // MARK: - Level Display Names

        static let levelHigh = "High"
        static let levelElevated = "Raised"
        static let levelMild = "Mild"
        static let levelCalm = "Calm"

        // MARK: - Hero

        static let heroExplainer = "How much pressure your body is under right now"
        static let contextLow = "Your body feels relaxed. Good time to focus on work or training."
        static let contextMild = "Some tension is building. A few slow breaths can help reset it."
        static let contextModerate = "Your body is showing real strain. Slow down before adding more load."
        static let contextHigh = "Stress is high. Step back, breathe, and rest well tonight."
        static let contextDefault = "Tracking your stress signals throughout the day."

        // MARK: - Scale

        static let scaleLow = "Low"
        static let scaleHigh = "High"
        static let scaleAndDirection = "out of 3  ·  Lower is better"
        static let scaleSuffix = "/ 3"

        // MARK: - Drivers

        static let whatsDrivingStress = "What Is Driving Your Stress"
        static let hrvDeviation = "Heart Rate Variability"
        static let hrElevation = "Heart Rate"

        // MARK: - History

        static let sevenDayStress = "7-Day Stress"

        // MARK: - Tips

        static let reduceStress = "Reduce Stress"
        static let startBreathingExercise = "Start Breathing Exercise"
        static let primaryTip = "Try This First"
        static let moreTips = "More Ideas"
        static let moreTipsHint = "Other ways to help your body settle."

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

        // MARK: - Tips

        static let tipsHigh = [
            "Your body is asking for rest. Lighter activity may help you more right now.",
            "Box breathing can help: inhale 4s, hold 4s, exhale 4s, hold 4s.",
            "A quieter, screen-free space may help your body settle.",
            "Many people find that 8+ hours of sleep tonight helps them feel more resilient tomorrow."
        ]
        static let tipsModerate = [
            "Consider a walk or gentle stretching.",
            "Limiting caffeine and stimulants for the next few hours may help.",
            "Try progressive muscle relaxation.",
            "Shorten your to-do list and focus on essentials."
        ]
        static let tipsMild = [
            "Try a 5-minute breathing exercise.",
            "Step outside for fresh air if possible.",
            "A short walk can help your body reset."
        ]
        static let tipsLow = [
            "Your body is calm. Great time for challenging work.",
            "Maintain this state with regular sleep and hydration.",
            "Consider a creative or deep-focus task right now."
        ]
        static let tipsDefault = [
            "Monitor your stress throughout the day.",
            "Regular breaks can help manage stress levels."
        ]

        // MARK: - Accessibility

        static let startBreathingA11y = "Start breathing exercise"
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

        // MARK: - Stop Confirmation (Pass 8 Q)

        static let endSessionTitle = "End Session?"
        static let endSessionConfirm = "End"
        static let continueSession = "Continue"
        static let done = "Done"
    }
}
