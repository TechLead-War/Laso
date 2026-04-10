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
        static let focusSubtitle = "Pick your areas. Those insights get prioritized first."

        // MARK: - Connect Health (personalized)

        static func personalizedConnectSubtitle(age: Int?) -> String {
            guard let age else { return connectHealthDescription }
            switch age {
            case ..<25:
                return "Starting early means a lifetime of knowing what is normal for your body."
            case 25..<35:
                return "At your age, heart and recovery patterns can tell you a lot about how you are doing."
            case 35..<45:
                return "At your age, keeping an eye on heart health and recovery trends is really valuable."
            case 45..<55:
                return "At your age, tracking heart, sleep, and mobility data shows you important changes."
            default:
                return "Your health data will be compared to what is typical for your age."
            }
        }

        // MARK: - Focus Confirmation

        static let focusConfirmationTitle = "Here is what we will focus on"

        static func focusConfirmationItems(for focuses: Set<HealthFocus>) -> [(icon: String, text: String)] {
            let effective = focuses.isEmpty ? Set(HealthFocus.allCases) : focuses
            var items: [(String, String)] = []
            if effective.contains(.sleep) {
                items.append(("moon.fill", "Sleep stages, timing, and overnight recovery tracked nightly"))
            }
            if effective.contains(.fitness) {
                items.append(("figure.run", "Steps, exercise, calories, and workout effectiveness analyzed daily"))
            }
            if effective.contains(.heartHealth) {
                items.append(("heart.fill", "Resting heart rate, HRV, and cardio fitness monitored continuously"))
            }
            if effective.contains(.weightBody) {
                items.append(("scalemass.fill", "Weight trends, body composition, and vitals tracked over time"))
            }
            if effective.contains(.recovery) {
                items.append(("bolt.heart.fill", "Recovery scoring built from your heart rate and sleep patterns"))
            }
            return items
        }

        // MARK: - Calibration

        static let calibratingTitle = "Calibrating Your Baseline"
        static let calibrationComplete = "Calibration Complete"
        static let calibrationIncomplete = "Calibration Incomplete"
        static let calibratingMessage = "We are building your personal baseline from your Apple Health data. This only happens once."
        static let calibrationSuccessMessage = "Your baseline is ready. From now on, your insights are personalized to you."
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

        // MARK: - Personalized Completion

        static let yourHealthDecoded = "Your Health, Decoded"
        static func dataSpanSubtitle(_ span: String) -> String {
            "\(span) of health history analyzed"
        }
        static let noDataYetMessage = "No health data available yet. Laso will start building your baseline as data arrives."

        // MARK: - Notifications

        static let enableNotifications = "Stay in the Loop"
        static let notificationDescription = "Laso can send you a morning health briefing, alert you when something unusual happens with your body, and share weekly progress updates."
        static let enableNotificationsButton = "Turn On Notifications"

        // MARK: - Siri

        static let worksWithSiri = "Works with Siri"
        static let siriTip = "Try saying \"Hey Siri, what's my health score in Laso\""
    }
}
