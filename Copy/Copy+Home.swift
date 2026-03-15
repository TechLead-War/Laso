import Foundation

extension Copy {
    enum Home {

        // MARK: - Loading

        static let analyzingHealthData = "Analyzing your health data..."

        // MARK: - Empty State

        static let connectHealthData = "Connect Your Health Data"
        static let connectHealthDescription = "Laso reads from Apple Health, which syncs with your wearable automatically. No extra setup needed."
        static let worksWith = "Works with"
        static let syncsAutomatically = "Syncs automatically"
        static func viaApp(_ name: String) -> String { "Via \(name) app" }
        static let howToConnect = "How to connect"
        static let connectStep1 = "Open the Settings app on your iPhone"
        static let connectStep2 = "Tap Health \u{2192} Data Access & Devices"
        static let connectStep3 = "Enable your wearable's companion app"
        static let connectStep4 = "Come back here \u{2014} data appears automatically"
        static let manageDevices = "Manage Devices"
        static let refresh = "Refresh"

        // MARK: - Error

        static let unableToLoadData = "Unable to Load Data"
        static let tryAgain = "Try Again"

        // MARK: - First Launch Sync

        static let syncingHealthData = "Syncing your last 1 year of health data"
        static func analyzingDataPoints(_ count: Int) -> String { "Analyzing \(count) data points" }
        static let analyzingYourData = "Analyzing your data"
        static let discoveringPatterns = "Discovering patterns"
        static let ready = "Ready"
        static let thisOnlyHappensOnce = "This only happens once"

        // MARK: - Primary Action

        static let todaysAction = "Today's Action"

        // MARK: - Early Warning

        static let earlyWarning = "Early Warning"
        static let severityHigh = "High"
        static let severityModerate = "Moderate"
        static let severityLow = "Low"

        // MARK: - Health Risks

        static let healthRisks = "Areas to Watch"

        // MARK: - Trends

        static let trends = "Trends"

        // MARK: - Journal

        static let howWasToday = "How was today?"
        static let journalSubtitle = "A quick check-in helps track patterns over time"

        // MARK: - Recovery Labels

        static let fullyRecovered = "Fully Recovered"
        static let wellRecovered = "Well Recovered"
        static let moderate = "Moderate"
        static let fatigued = "Fatigued"
        static let strained = "Strained"

        // MARK: - Recovery State (DashboardViewModel)

        static let moderateRecovery = "Moderate Recovery"
        static let lowRecovery = "Low Recovery"

        // Day type labels
        static let greenDayPushHard = "Green Day \u{2014} Push Hard"
        static let yellowDayMaintain = "Yellow Day \u{2014} Maintain"
        static let redDayRecover = "Red Day \u{2014} Recover"

        // Simple strain guidance
        static let greenStrainGuidance = "High intensity training recommended. Your body is ready for a challenge."
        static let yellowStrainGuidance = "Moderate activity is ideal. Focus on technique over intensity."
        static let redStrainGuidance = "Prioritize rest and gentle movement. Your body needs recovery time."

        // Contextual strain guidance (recovery state × activity trend)
        static let greenImproving = "Recovery is high and activity is already trending up. Push hard, but avoid a major jump in strain."
        static let greenDeclining = "Recovery is high while recent activity has trended down. Add a hard session to rebuild strain."
        static let greenStable = "Recovery is high. Push hard today with a challenging workout."
        static let greenNone = "Recovery is high. Push hard today."
        static let yellowImproving = "Recovery is moderate and activity is trending up. Maintain strain and keep intensity controlled."
        static let yellowDeclining = "Recovery is moderate with activity easing off. Maintain with a steady, moderate session."
        static let yellowStable = "Recovery is moderate. Maintain your usual training load today."
        static let yellowNone = "Recovery is moderate. Maintain a moderate strain today."
        static let redImproving = "Recovery is low after rising activity. Take a recovery day with light movement only."
        static let redDeclining = "Recovery is low. Keep strain very low and prioritize sleep, hydration, and mobility."
        static let redStable = "Recovery is low. Recover today with easy walking or stretching only."
        static let redNone = "Recovery is low. Prioritize recovery and avoid hard training."

        // MARK: - Score Guide

        enum ScoreGuide {
            static let healthScore = "Health Score"
            static let title = "This is your Health Score"
            static let description = "A single number from 0 to 100 that reflects how your body is doing right now, based on your own data."
            static let whatDoesItMean = "What does it mean?"
            static let whatDoesItMeanBody = "Your score rises when your metrics are steady or improving compared to your personal baseline. It drops when something changes. This isn\u{2019}t a medical diagnosis \u{2014} think of it as a daily check-in with your body."
            static let scoreLevels = "Score levels"

            // Score level ranges
            static let excellentRange = "80\u{2013}100"
            static let excellentLabel = "Excellent"
            static let excellentDescription = "Everything looks great \u{2014} keep doing what you\u{2019}re doing."
            static let goodRange = "60\u{2013}79"
            static let goodLabel = "Good"
            static let goodDescription = "Most things are on track with minor areas to watch."
            static let fairRange = "40\u{2013}59"
            static let fairLabel = "Fair"
            static let fairDescription = "A few metrics have shifted \u{2014} worth paying attention."
            static let needsAttentionRange = "Below 40"
            static let needsAttentionLabel = "Room to Grow"
            static let needsAttentionDescription = "Several things are off from your norm \u{2014} check your insights."

            // Categories
            static let howItsCalculated = "How it\u{2019}s calculated"
            static let heartCardioName = "Heart & Cardio"
            static let heartCardioDetail = "Resting heart rate, HRV, and cardio fitness"
            static let sleepName = "Sleep"
            static let sleepDetail = "Duration, consistency, and sleep stages"
            static let activityName = "Activity"
            static let activityDetail = "Steps, workouts, and energy burned"
            static let bodyVitalsName = "Body & Vitals"
            static let bodyVitalsDetail = "Weight, body fat, blood oxygen, and more"

            // Recovery
            static let recoveryAndReadiness = "Recovery"
            static func readinessDescription(deviceName: String?) -> String {
                if let deviceName {
                    return "Your Recovery score (0\u{2013}100) tells you how recovered your body is. It\u{2019}s calculated from two signals your \(deviceName) measures while you sleep:"
                }
                return "Your Recovery score (0\u{2013}100) tells you how recovered your body is. It\u{2019}s calculated from HRV and resting heart rate samples that Apple Health collects overnight:"
            }
            static let hrvName = "Heart Rate Variability (HRV)"
            static let hrvDetail = "Higher HRV means better recovery and lower stress."
            static let restingHRName = "Resting Heart Rate"
            static let restingHRDetail = "Lower resting HR means your heart is recovering well."

            // Baseline callout
            static let baselineCallout = "This score compares you to yourself \u{2014} not world averages. As we learn your patterns, it becomes more accurate."

            static let gotIt = "Got It"
        }

        // MARK: - Recovery Info

        enum RecoveryInfo {
            static let title = "How Recovery Works"
            static let description = "Your Recovery score (0\u{2013}100) tells you how recovered your body is, based on two signals measured while you sleep."
            static let hrvName = "Heart Rate Variability"
            static let hrvDetail = "Higher HRV means better recovery and lower stress."
            static let restingHRName = "Resting Heart Rate"
            static let restingHRDetail = "Lower resting HR means your heart is recovering well."
        }
    }
}
