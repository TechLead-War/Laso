import Foundation
import SwiftUI

extension Copy {
    enum Home {

        // MARK: - Last Refresh Footer

        static func updatedAgo(_ date: Date) -> Text {
            Text("Updated \(date, style: .relative) ago")
        }
        /// Plain-string variant for `accessibilityLabel(_:)`, which rejects styled `Text`.
        static func lastUpdatedAgo(_ date: Date) -> String {
            "Last updated \(Self.relativeFormatter.localizedString(for: date, relativeTo: Date()))"
        }
        static let pullToRefresh: Text = Text("Pull to refresh")
        static let notSyncedYetAccessibility = "Health data not synced yet. Pull down to refresh."

        private static let relativeFormatter: RelativeDateTimeFormatter = {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .full
            return f
        }()

        // MARK: - Loading

        static let analyzingHealthData = "Analyzing your health data..."

        // MARK: - Empty State

        static let connectHealthData = "Connect Your Health Data"
        static let connectHealthDescription = "Laso reads from Apple Health. Most other wearables need their apps to share data with Apple Health."
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

        // MARK: - Connection Status (Home empty state)

        enum ConnectionStatus {
            // Titles
            static let titleWaiting = "Waiting for your first watch data"
            static func titleReceiving(_ deviceName: String) -> String { "\(deviceName) is sending data" }
            static let titleStale = "Your watch has not synced recently"

            // Descriptions
            static let descriptionWaiting = "Apple Health is connected. No wearable has shared data yet. If you use a watch, open its app and turn on Apple Health sharing."
            static func descriptionReceiving(deviceName: String, sourceName: String) -> String {
                "\(deviceName) is syncing through \(sourceName). Your dashboard will update as new data comes in."
            }
            static func descriptionStale(deviceName: String, lastSync: String, sourceName: String) -> String {
                "\(deviceName) last shared data \(lastSync). Open \(sourceName) and run a sync so Laso can catch up."
            }

            // Badge labels
            static let badgeWaiting = "Waiting"
            static let badgeConnected = "Connected"
            static let badgeStale = "Stale"
        }

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

        static let earlyWarning = "Worth Noticing"
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

        // MARK: - Section & Card Labels

        static let focusAreasTitle = "Your Focus Areas"
        static let fromYourData = "From Your Data"
        static let whyThisToday = "Why this, today"
        static let nextWeekTarget = "Next week target"
        static let askYourData = "Ask your data"
        static let seeSleepTips = "See sleep tips \u{2192}"
        static let wearAppleWatchForRecovery = "Wear Apple Watch for recovery data"
        static let tapToUnderstandScore = "Tap to understand your score"

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
        static let greenStrainGuidance = "High effort training is a great pick. Your body is ready for a challenge."
        static let yellowStrainGuidance = "Moderate activity is best. Focus on form over intensity."
        static let redStrainGuidance = "Focus on rest and gentle movement. Your body needs recovery time."

        // Contextual strain guidance (recovery state × activity trend)
        static let greenImproving = "Recovery is high and activity is already trending up. Push hard, but avoid a big jump in strain."
        static let greenDeclining = "Recovery is high while recent activity has trended down. Add a hard session to rebuild strain."
        static let greenStable = "Recovery is high. Push hard today with a challenging workout."
        static let greenNone = "Recovery is high. Push hard today."
        static let yellowImproving = "Recovery is moderate and activity is trending up. Keep strain steady and intensity in check."
        static let yellowDeclining = "Recovery is moderate with activity easing off. Stick with a steady, moderate session."
        static let yellowStable = "Recovery is moderate. Keep your usual training load today."
        static let yellowNone = "Recovery is moderate. Aim for a moderate strain today."
        static let redImproving = "Recovery is low after rising activity. Take a recovery day with light movement only."
        static let redDeclining = "Recovery is low. Keep strain very low and focus on sleep, water, and easy movement."
        static let redStable = "Recovery is low. Recover today with easy walking or stretching only."
        static let redNone = "Recovery is low. Focus on recovery and avoid hard training."

        // MARK: - Score Guide

        enum ScoreGuide {
            static let healthScore = "Health Score"
            static let title = "This is your Health Score"
            static let description = "A single number from 0 to 100 that shows how your body is doing right now, based on your own data."

            // Personalized "What does it mean?" based on score level
            static let whatDoesItMean = "What does it mean?"

            static func whatDoesItMeanBody(score: Int, weakestCategory: String?) -> String {
                let levelExplanation: String
                switch score {
                case 80...100:
                    levelExplanation = "Your numbers are steady or getting better compared to your usual. Everything looks well balanced."
                case 60..<80:
                    levelExplanation = "Most of your numbers are on track, but a few areas have shifted a bit from your usual."
                case 40..<60:
                    levelExplanation = "Several numbers have shifted from your usual. This is worth paying attention to."
                default:
                    levelExplanation = "Several numbers are off from your usual. Check your insights for areas to focus on."
                }
                let categoryHint: String
                if let weakest = weakestCategory {
                    categoryHint = " \(weakest) is the area pulling your score down the most right now."
                } else {
                    categoryHint = ""
                }
                return "\(levelExplanation)\(categoryHint) This is for information only. Think of it as a daily check in with your body."
            }

            static let scoreLevels = "Score levels"

            // Score level ranges
            static let excellentRange = "80 to 100"
            static let excellentLabel = "Excellent"
            static let excellentDescription = "Everything looks great. Keep doing what you are doing."
            static let goodRange = "60 to 79"
            static let goodLabel = "Good"
            static let goodDescription = "Most things are on track with small areas to watch."
            static let fairRange = "40 to 59"
            static let fairLabel = "Fair"
            static let fairDescription = "A few numbers have shifted. Worth paying attention to."
            static let needsAttentionRange = "Below 40"
            static let needsAttentionLabel = "Room to Grow"
            static let needsAttentionDescription = "Several things are off from your usual. Check your insights."

            // Categories
            static let howItsCalculated = "How it\u{2019}s calculated"
            static let howItsCalculatedBody = "Your Health Score is a weighted average across four areas. Areas with more data and more change carry more weight. Each number is scored against your usual, and changes and trends move the score up or down."
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
            static let whenItUpdatesBody = "Your Health Score refreshes each time you open the app or pull to refresh. It uses the latest data from Apple Health, so changes in your numbers show up within minutes. Trends and shifts in your usual take about 1 to 3 days to show up in the score."

            // Baseline callout
            static let baselineCallout = "This score compares you to yourself, not other people. As we learn your patterns, it gets more accurate."

            static let gotIt = "Got It"
        }

        // MARK: - Action Proof

        enum ActionProof {
            /// Card proof line shown on the home card below the subtitle
            static func followedAdviceImproved(count: Int, metric: String) -> String {
                "The last \(count) times you followed this advice, your \(metric) got better"
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
            static let notEnoughHistory = "We are still learning your patterns. After a few more days of data, this section will show how past tips worked out for you."

            /// Detail: summary of positive outcomes
            static func pastOutcomeSummary(improved: Int, total: Int, metric: String) -> String {
                "Out of \(total) similar tips, \(improved) led to a real improvement in your \(metric)"
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
            static let rhrElevated = "resting heart rate is higher than usual"
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
            static let afternoonRed = "Recovery is still low. Light movement and water are your best bet."

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
            static let done = "Done"
        }

        // MARK: - Ask Your Data

        enum AskYourData {
            static let title = "Ask Your Data"
            static let placeholder = "Ask anything about your health..."
            static let tryAsking = "Try asking"
            static let related = "Related questions"

            // Concierge-style home card
            static let caption = "CONCIERGE"
            static let conciergePrompts: [String] = [
                "Ask me how to spend today well.",
                "How is my HRV trending?",
                "What is affecting my sleep this week?",
                "Am I getting enough deep sleep?",
                "How does exercise shift my recovery?",
                "What changed in my body last week?",
                "How consistent is my sleep schedule?"
            ]

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
            static let description = "Your Recovery score (0 to 100) shows how rested your body is, based on overnight data while you sleep."

            // Score levels
            static let scoreLevels = "Score levels"
            static let fullyRecoveredRange = "80 to 100"
            static let fullyRecoveredLabel = "Fully Recovered"
            static let fullyRecoveredDescription = "Your body is well rested. Great day for a hard workout."
            static let moderateRange = "50 to 79"
            static let moderateLabel = "Moderate"
            static let moderateDescription = "Decent recovery. Moderate effort is best today."
            static let lowRange = "Below 50"
            static let lowLabel = "Low Recovery"
            static let lowDescription = "Your body needs rest. Focus on easy movement and sleep."

            // How it's calculated
            static let howItsCalculated = "How it\u{2019}s calculated"
            static let howItsCalculatedBody = "Recovery is a weighted score from signals measured while you sleep. Each signal is compared to your usual. The further off it is, the more it affects the score."
            static let hrvName = "Heart Rate Variability"
            static let hrvWeight = "40% weight"
            static let hrvDetail = "Higher HRV means better recovery and lower stress. Compared to your usual."
            static let restingHRName = "Resting Heart Rate"
            static let restingHRWeight = "35% weight"
            static let restingHRDetail = "Lower resting HR means your heart is recovering well. Compared to your usual."
            static let sleepDurationName = "Sleep Duration"
            static let sleepDurationWeight = "15% weight"
            static let sleepDurationDetail = "7.5 hours is best. Too little or too much lowers the score."
            static let sleepQualityName = "Sleep Quality"
            static let sleepQualityWeight = "6% weight"
            static let sleepQualityDetail = "Deep and REM sleep stages help your recovery quality."
            static let workoutRecoveryName = "Recent Workout"
            static let workoutRecoveryWeight = "4% weight"
            static let workoutRecoveryDetail = "Hard workouts lower recovery for a short time. The effect fades over 18 to 36 hours."

            // Device requirement
            static func wearRequirement(deviceName: String?) -> String {
                if let deviceName {
                    return "Wear your \(deviceName) overnight so it can measure HRV and resting heart rate while you sleep."
                }
                return "Wear your Apple Watch overnight so it can measure HRV and resting heart rate while you sleep."
            }

            // Refresh timing
            static let whenItUpdatesTitle = "When does it update?"
            static let whenItUpdatesBody = "Your Recovery score updates each morning using overnight data. It usually takes 1 to 3 days of overnight wear before changes in your routine show up in the score."
        }

        // MARK: - Cycle Phase Card

        enum CyclePhase {
            static func dayOfCycle(day: Int, total: Int) -> String { "Day \(day) of \(total)" }
        }

        // MARK: - Strain Card

        enum StrainCard {
            static func zoneLabel(_ zone: Int) -> String { "Z\(zone)" }
        }

        // MARK: - Cards

        enum Cards {
            // Daily narrative
            static let forYouToday = "FOR YOU TODAY"
            static let readingTodaysSignals = "Reading today's signals…"

            // Personal health forecast
            static let yourForecast = "YOUR FORECAST"
            static let nextSevenDays = "Next 7 days"

            // Sleep coach card
            static let tonightsGoal = "Tonight's Goal"
            static func bedBy(_ time: String) -> String { "Bed by \(time)" }

            // Strain card
            static let todaysStrain = "Today's Strain"

            // Sleep card
            static let lastNightsSleep = "Last Night's Sleep"

            // Stress card
            static let stressLevel = "Stress Level"

            // Recovery hero
            static let rightNow = "Right now"
            static let vsLastWeek = "vs last week"

            // Today briefing
            static let generatedByLasoIntelligence = "Generated by Laso intelligence"

            // Correlations section
            static let seeAll = "See all"
        }

        // MARK: - Smart Action Recommendations

        enum SmartAction {
            // Default fallback
            static let defaultTitle = "Get moving for 15 minutes"
            static let defaultSubtitle = "A short walk boosts mood, energy, and sleep quality tonight"
            static let defaultRationale = "No specific signals today. A walk is the simplest, highest payoff activity for overall health."

            // Live data: high stress
            static let highStressTitle = "Your stress is higher than usual right now"
            static let highStressSubtitle = "Box breathing (4-4-4-4) for 5 min can bring it down. Your body is asking for a reset."
            static func highStressRationale(_ stress: Int) -> String {
                "Your live stress reading is \(stress)%, which is above your comfortable range."
            }

            // Live data: low sleep
            static let lowSleepTitle = "Go easy today"
            static func lowSleepSubtitle(_ formattedSleep: String) -> String {
                "Only \(formattedSleep) of sleep. Skip intense workouts. Your body needs to save energy."
            }
            static let lowSleepRationale = "You got much less sleep than your body needs. Hard effort today would add to the shortfall."

            // Live data: low readiness
            static let lowReadinessTitle = "Recovery day. Your body needs it"
            static func lowReadinessSubtitle(_ readiness: Int) -> String {
                "Readiness is \(readiness)%. Stretching or yoga only"
            }
            static let lowReadinessRationale = "A few signals (HRV, resting HR, sleep) suggest your body has not recovered from recent strain."

            // Activity progress: goal reached
            static let exerciseGoalTitle = "Exercise goal reached!"
            static func exerciseGoalSubtitle(_ minutes: Int) -> String {
                "\(minutes) min today. Stay active and drink water"
            }
            static let exerciseGoalRationale = "You have already hit your daily exercise goal."

            // Activity progress: minutes to go (good readiness)
            static func minutesToGoTitle(_ remaining: Int) -> String {
                "You have \(remaining) min to go"
            }
            static let minutesToGoSubtitle = "Recovery is strong. A run or workout would be great"
            static let minutesToGoRationale = "Your body is well recovered and ready for effort. Closing the exercise gap today would build momentum."

            // Late hour wind-down
            static let windDownTitle = "Wind down for sleep"
            static let windDownSubtitle = "Dim screens and skip caffeine for better rest tonight"
            static let windDownRationale = "It is late evening. Less blue light and caffeine now directly improves your sleep quality tonight."

            // Focus: deep sleep
            static let deepSleepTitle = "Boost your deep sleep"
            static func deepSleepSubtitle(_ minutes: Int) -> String {
                "Only \(minutes) min of deep sleep. Try cutting caffeine after 2 PM"
            }
            static let deepSleepRationale = "Deep sleep is when your body repairs muscle, locks in memory, and balances hormones. You are getting less than the 45-minute mark."

            // Focus: bedtime
            static let earlyBedTitle = "Get to bed 30 min earlier"
            static func earlyBedSubtitle(_ formattedSleep: String) -> String {
                "\(formattedSleep) last night. Aim for 7+ hours"
            }
            static let earlyBedRationale = "Sleep is your top focus area and you are falling short. Even 30 more minutes makes a real difference."

            // Focus: fitness gap
            static func fitnessGapTitle(_ remaining: Int) -> String {
                "You're \(remaining) min from your goal"
            }
            static let fitnessGapSubtitle = "A brisk walk or quick workout would close the gap"
            static func fitnessGapRationale(_ remaining: Int) -> String {
                "Fitness is your focus area and you have \(remaining) minutes left to hit today's goal."
            }

            // Focus: resting HR up
            static let restingHRUpTitle = "Your resting HR is trending up"
            static let restingHRUpSubtitle = "Try 10 min of meditation or deep breathing to bring it down"
            static func restingHRUpRationale(currentRHR: Int, baselineRHR: Int) -> String {
                "Your resting heart rate is \(currentRHR) bpm, above your usual of \(baselineRHR) bpm. This could hint at incomplete recovery or higher stress."
            }

            // Focus: recovery
            static let focusRecoveryTitle = "Focus on recovery today"
            static func focusRecoverySubtitle(_ readiness: Int) -> String {
                "Readiness is \(readiness)%. Light stretching and water will help"
            }
            static let focusRecoveryRationale = "Recovery is your focus area and your readiness score suggests your body has not fully bounced back yet."

            // Insight-driven titles
            static func insightEaseOff(_ metric: String) -> String { "Ease off. \(metric) needs attention" }
            static func insightPushHarder(_ metric: String) -> String { "Push harder. \(metric) is ready" }
            static let insightSleepBetter = "Improve your sleep tonight"
            static func insightWorthChecking(_ metric: String) -> String { "\(metric). Worth checking" }
            static func insightKeepItUp(_ metric: String) -> String { "Keep it up. \(metric) is solid" }
        }

        // MARK: - Today's Action Detail

        enum TodaysActionDetail {
            static let doToday = "Do Today"
            static let whatsOffToday = "What's off today"
            static let whatsLeadingToWhat = "What's leading to what"
            static let yourCoachsNotes = "Your coach's notes"
            static let todaysWorkout = "Today's Workout"
            static let baseline = "baseline"
        }

        // MARK: - Weekly Review Section Headers

        enum WeeklyReviewSections {
            static let navigationTitle = "Weekly Review"
            static let progressiveCoach = "Progressive Coach"
            static let nextWeek = "Next Week"
            static let keyDiscovery = "Key Discovery"
        }

        // MARK: - HealthKit Reprompt

        enum HealthKitReprompt {
            static let title = "Laso needs access to your health data"
            static let body = "It looks like health data sharing is turned off. Open Settings and turn on the categories you want Laso to track, like heart rate, sleep, and activity."
            static let action = "Open Settings"
            static let dismiss = "Not Now"
        }
    }
}
