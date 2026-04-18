import Foundation

extension Copy {
    enum Home {

        // MARK: - Loading

        static let analyzingHealthData = "Analyzing your health data..."

        // MARK: - Empty State

        static let connectHealthData = "Connect Your Health Data"
        static let connectHealthDescription = "Laso reads from Apple Health. Most third-party wearables need their companion app with Apple Health sharing enabled."
        static let worksWith = "Works with"
        static let syncsAutomatically = "Syncs automatically"
        static func viaApp(_ name: String) -> String { "Via \(name) app" }
        static let howToConnect = "How to connect"
        static let connectStep1 = "Open the Settings app on your iPhone"
        static let connectStep2 = "Tap Health \u{2192} Data Access & Devices"
        static let connectStep3 = "Enable your wearable's companion app"
        static let connectStep4 = "Come back here. Data appears automatically."
        static let manageDevices = "Manage Devices"
        static let refresh = "Refresh"

        // MARK: - Error

        static let unableToLoadData = "Unable to Load Data"
        static let tryAgain = "Try Again"

        // MARK: - First Launch Sync

        static let syncingHealthData = "Syncing your past year of health data"
        static func analyzingDataPoints(_ count: Int) -> String { "Analyzing \(count) data points" }
        static let analyzingYourData = "Analyzing your data"
        static let discoveringPatterns = "Discovering patterns"
        static let ready = "Ready"
        static let thisOnlyHappensOnce = "This only happens once"

        // MARK: - Primary Action

        static let todaysAction = "Today's Action"
        static let bodyIntelligence = "Body Intelligence"

        // MARK: - Watch This

        static let earlyWarning = "Watch This"
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
        static let greenDayPushHard = "Green Day. Push Hard."
        static let yellowDayMaintain = "Yellow Day. Maintain."
        static let redDayRecover = "Red Day. Recover."

        // Simple strain guidance
        static let greenStrainGuidance = "High-intensity training recommended. Your body is ready for a challenge."
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

            // Personalized "What does it mean?" based on score level
            static let whatDoesItMean = "What does it mean?"

            static func whatDoesItMeanBody(score: Int, weakestCategory: String?) -> String {
                let levelExplanation: String
                switch score {
                case 80...100:
                    levelExplanation = "Your metrics are steady or improving across the board compared to your personal baseline. Everything looks well-balanced."
                case 60..<80:
                    levelExplanation = "Most of your metrics are on track, but a few areas have shifted slightly from your baseline."
                case 40..<60:
                    levelExplanation = "Several metrics have shifted from your personal baseline. This is worth paying attention to."
                default:
                    levelExplanation = "Multiple metrics are off from your personal baseline. Check your insights for specific areas to focus on."
                }
                let categoryHint: String
                if let weakest = weakestCategory {
                    categoryHint = " \(weakest) is the area pulling your score down the most right now."
                } else {
                    categoryHint = ""
                }
                return "\(levelExplanation)\(categoryHint) This is for informational purposes only. Think of it as a daily check in with your body."
            }

            static let scoreLevels = "Score levels"

            // Score level ranges
            static let excellentRange = "80\u{2013}100"
            static let excellentLabel = "Excellent"
            static let excellentDescription = "Everything looks great. Keep doing what you are doing."
            static let goodRange = "60\u{2013}79"
            static let goodLabel = "Good"
            static let goodDescription = "Most things are on track with minor areas to watch."
            static let fairRange = "40\u{2013}59"
            static let fairLabel = "Fair"
            static let fairDescription = "A few metrics have shifted. Worth paying attention to."
            static let needsAttentionRange = "Below 40"
            static let needsAttentionLabel = "Room to Grow"
            static let needsAttentionDescription = "Several things are off from your norm. Check your insights."

            // Categories
            static let howItsCalculated = "How it\u{2019}s calculated"
            static let howItsCalculatedBody = "Your Health Score is a weighted average across four categories. Categories with more data and more variability carry greater weight. Each metric is scored against your personal baseline, and deviations and trends move the score up or down."
            static let heartCardioName = "Heart & Cardio"
            static let heartCardioDetail = "Resting heart rate, HRV, and cardio fitness"
            static let sleepName = "Sleep"
            static let sleepDetail = "Duration, consistency, and sleep stages"
            static let activityName = "Activity"
            static let activityDetail = "Steps, workouts, and energy burned"
            static let bodyVitalsName = "Body & Vitals"
            static let bodyVitalsDetail = "Weight, body fat, blood oxygen, and more"

            // Refresh timing
            static let whenItUpdatesTitle = "When does it update?"
            static let whenItUpdatesBody = "Your Health Score refreshes each time you open the app or pull to refresh. It uses the latest data from Apple Health, so changes in your metrics show up within minutes. Trends and baseline shifts typically take 1\u{2013}3 days to reflect in the score."

            // Baseline callout
            static let baselineCallout = "This score compares you to yourself, not world averages. As we learn your patterns, it becomes more accurate."

            static let gotIt = "Got It"
        }

        // MARK: - Action Proof

        enum ActionProof {
            /// Card proof line shown on the home card below the subtitle
            static func followedAdviceImproved(count: Int, metric: String) -> String {
                "The last \(count) times you followed this advice, your \(metric) improved"
            }

            /// Proof line for recovery staying green after pushing hard
            static func recoveryStayedGreen(goodCount: Int, totalCount: Int) -> String {
                "When you were in this state before and pushed hard, recovery stayed green \(goodCount) out of \(totalCount) times"
            }

            /// General proof line referencing personal history timeframe
            static func basedOnHistory(days: Int) -> String {
                "Based on your personal history over \(days) days"
            }

            /// Short proof line for the home card when we have a win rate
            static func thingsWentWell(count: Int) -> String {
                "The last \(count) times you were in this state and followed this advice, things went well"
            }

            /// Detail view section title
            static let whatHappenedBefore = "What happened before"

            /// Detail: no history yet
            static let notEnoughHistory = "We are still learning your patterns. After a few more days of data, this section will show how past recommendations worked out for you."

            /// Detail: summary of positive outcomes
            static func pastOutcomeSummary(improved: Int, total: Int, metric: String) -> String {
                "Out of \(total) similar recommendations, \(improved) led to measurable improvement in your \(metric)"
            }

            /// Detail: timeframe context
            static func trackingWindow(days: Int) -> String {
                "Based on your data from the last \(days) days"
            }
        }

        // MARK: - Recovery Hero Why Lines

        enum RecoveryHero {
            static func whyLineGreen(topFactor: String, secondFactor: String) -> String {
                "\(topFactor) and \(secondFactor)"
            }
            static func whyLineYellow(topFactor: String) -> String {
                "\(topFactor), keeping recovery moderate"
            }
            static func whyLineRed(topFactor: String, secondFactor: String) -> String {
                "\(topFactor) and \(secondFactor)"
            }

            // Factor descriptions (positive)
            static let hrvBounced = "HRV bounced back"
            static let hrvHigh = "HRV is above your usual"
            static let rhrLow = "resting heart rate is low"
            static let rhrDropped = "resting heart rate dropped back down"
            static let sleepSolid = "solid night of sleep"
            static let sleepGreat = "sleep was long and restorative"
            static let sleepGood = "decent sleep duration"

            // Factor descriptions (negative)
            static let hrvLow = "HRV has not recovered yet"
            static let hrvBelow = "HRV is below your usual"
            static let rhrElevated = "resting heart rate is higher than your usual"
            static let rhrHigh = "resting heart rate is still high"
            static let sleepShort = "sleep was short"
            static let sleepPoor = "sleep quality was low"
            static let recentHardWorkout = "still recovering from a hard workout"
        }

        // MARK: - Greeting

        enum Greeting {
            static let goodMorning = "Good Morning"
            static let goodAfternoon = "Good Afternoon"
            static let goodEvening = "Good Evening"
            static let goodNight = "Good Night"

            static func streakBadge(_ days: Int) -> String { "\(days) days" }
            static func streakMilestone(_ days: Int) -> String { "\(days) day streak!" }

            // Morning
            static let morningGreen = "Your body is recovered and ready. Great day to push hard."
            static let morningYellow = "Recovery is moderate. Steady effort today, nothing extreme."
            static let morningRed = "Your body needs rest. Go easy and prioritize sleep tonight."

            // Afternoon
            static let afternoonGreen = "Still looking strong. Good time for a workout if you have not done one yet."
            static let afternoonYellow = "Holding steady. Keep the pace moderate this afternoon."
            static let afternoonRed = "Recovery is still low. Light movement and hydration are your best bet."

            // Evening
            static let eveningGreen = "Solid day. Wind down and protect your sleep tonight."
            static let eveningYellow = "Decent day overall. An early bedtime would help recovery."
            static let eveningRed = "Tough day for your body. Get to bed early tonight."

            // Night
            static let nightGreen = "Good day. Rest well tonight and you will wake up strong."
            static let nightYellow = "Your body could use a solid night. Try to get to sleep soon."
            static let nightRed = "Your body is running low. Sleep is the most important thing right now."
        }

        // MARK: - Morning Check-In

        enum MorningCheckIn {
            static let greeting = "Good Morning"
            static let subtitle = "How are you feeling today?"
        }

        // MARK: - Ask Your Data

        enum AskYourData {
            static let title = "Ask Your Data"
            static let placeholder = "Ask anything about your health..."
            static let tryAsking = "Try asking"
            static let related = "Related questions"

            static func confidence(_ percent: Int) -> String {
                "\(percent)% confidence"
            }

            static let suggestedQuestions: [String] = [
                "How is my sleep this week?",
                "What affects my HRV the most?",
                "Am I getting enough deep sleep?",
                "How does exercise affect my recovery?",
                "What is my resting heart rate trend?",
                "How consistent is my sleep schedule?"
            ]
        }

        // MARK: - Recovery Info

        enum RecoveryInfo {
            static let title = "How Recovery Works"
            static let description = "Your Recovery score (0\u{2013}100) tells you how recovered your body is, based on overnight data measured while you sleep."

            // Score levels
            static let scoreLevels = "Score levels"
            static let fullyRecoveredRange = "80\u{2013}100"
            static let fullyRecoveredLabel = "Fully Recovered"
            static let fullyRecoveredDescription = "Your body is well-rested. Great day for a hard workout."
            static let moderateRange = "50\u{2013}79"
            static let moderateLabel = "Moderate"
            static let moderateDescription = "Decent recovery. Moderate intensity is ideal."
            static let lowRange = "Below 50"
            static let lowLabel = "Low Recovery"
            static let lowDescription = "Your body needs rest. Prioritize easy movement and sleep."

            // How it's calculated
            static let howItsCalculated = "How it\u{2019}s calculated"
            static let howItsCalculatedBody = "Recovery is a weighted score from signals measured while you sleep. Each signal is compared to your personal baseline. The further you deviate, the more it affects the score."
            static let hrvName = "Heart Rate Variability"
            static let hrvWeight = "40% weight"
            static let hrvDetail = "Higher HRV means better recovery and lower stress. Compared to your personal baseline."
            static let restingHRName = "Resting Heart Rate"
            static let restingHRWeight = "35% weight"
            static let restingHRDetail = "Lower resting HR means your heart is recovering well. Compared to your baseline."
            static let sleepDurationName = "Sleep Duration"
            static let sleepDurationWeight = "15% weight"
            static let sleepDurationDetail = "7.5 hours is optimal. Too little or too much reduces the score."
            static let sleepQualityName = "Sleep Quality"
            static let sleepQualityWeight = "6% weight"
            static let sleepQualityDetail = "Deep and REM sleep stages contribute to recovery quality."
            static let workoutRecoveryName = "Recent Workout"
            static let workoutRecoveryWeight = "4% weight"
            static let workoutRecoveryDetail = "Hard workouts lower recovery temporarily. The effect fades over 18\u{2013}36 hours."

            // Device requirement
            static func wearRequirement(deviceName: String?) -> String {
                if let deviceName {
                    return "Wear your \(deviceName) overnight so it can measure HRV and resting heart rate while you sleep."
                }
                return "Wear your Apple Watch overnight so it can measure HRV and resting heart rate while you sleep."
            }

            // Refresh timing
            static let whenItUpdatesTitle = "When does it update?"
            static let whenItUpdatesBody = "Your Recovery score recalculates each morning using overnight data. It typically takes 1\u{2013}3 days of consistent overnight wear before changes in your routine show up in the score."
        }

        // MARK: - HealthKit Reprompt

        enum HealthKitReprompt {
            static let title = "Laso needs access to your health data"
            static let body = "It looks like health data sharing is turned off. Open Settings and enable the categories you want Laso to track, like heart rate, sleep, and activity."
            static let action = "Open Settings"
            static let dismiss = "Not Now"
        }
    }
}
