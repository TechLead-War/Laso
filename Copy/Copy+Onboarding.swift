import Foundation

extension Copy {
    enum Onboarding {

        // MARK: - Welcome

        static let tagline = "Your health, understood."

        // MARK: - Value Proposition

        static let whatYouGet = "What You Get"
        static let bulletPersonalized = "Personalized to your body"
        static let bulletPrivate = "Private and on-device"
        static let bulletActionable = "Actionable daily guidance"

        // MARK: - Connect Health

        static let connectAppleHealth = "Connect Apple Health"
        static let connectHealthDescription = "Laso reads your health data to build\npersonalized insights and track your progress."
        static let connectHealthData = "Connect Health Data"
        static let healthKitUnavailable = "HealthKit is not available on this device."
        static let continueAnyway = "Continue Anyway"

        // Permission labels
        static let permissionHeartRate = "Heart Rate"
        static let permissionSteps = "Steps"
        static let permissionSleepAnalysis = "Sleep Analysis"
        static let permissionHRV = "Heart Rate Variability"
        static let permissionBloodOxygen = "Blood Oxygen"
        static let permissionWorkouts = "Workouts"
        static let permissionBodyMeasurements = "Body Measurements"

        // MARK: - Cycle Opt-In

        static let enableCycleTracking = "Enable Cycle Tracking?"
        static let cycleOptInDescription = "Use menstrual flow data from Apple Health for cycle-aware insights and recommendations."

        // MARK: - Focus Selection

        static let whatMatters = "What matters most to you?"
        static let focusSubtitle = "Pick your areas — those insights get prioritized first."

        // MARK: - Calibration

        static let calibratingTitle = "Calibrating Your Baseline"
        static let calibrationComplete = "Calibration Complete"
        static let calibrationIncomplete = "Calibration Incomplete"
        static let calibratingMessage = "Your baseline is being built from historical Apple Health data. This happens only once."
        static let calibrationSuccessMessage = "Your historical baseline is ready. You will now start with personalized insights instead of generic ones."
        static let enterLaso = "Start Your Journey"
        static let retryCalibration = "Retry Calibration"

        // Calibration stats
        static let liveCalibrationStats = "Live Calibration Stats"
        static let stageLabel = "Stage"
        static let metricsScanned = "Metrics Scanned"
        static let dataPointsFound = "Data Points Found"
        static let oldestData = "Oldest Data"
        static let currentlyProcessing = "Currently Processing"
        static let elapsed = "Elapsed"
        static let analyzingPatterns = "Analyzing Patterns"

        // MARK: - Siri

        static let worksWithSiri = "Works with Siri"
        static let siriTip = "Try saying \"Hey Siri, what's my health score in Laso\""
    }
}
