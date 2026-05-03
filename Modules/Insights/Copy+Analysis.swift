import Foundation

extension Copy {
    enum Analysis {

        // MARK: - Clinical Intelligence

        enum Clinical {
            static let bloodPressureTrendingUp = "Blood Pressure Trending Up"
            static let elevatedPulsePressure = "Pulse Pressure is Higher Than Usual"
            static let bloodGlucoseTrendingUp = "Blood Glucose Trending Up"
            static let abnormalRespiratoryRate = "Unusual Breathing Rate"
            static let medicalDisclaimer = "This is for your information only and is not medical advice."

            // BP recommendations
            static let bpRecommendation = "Try eating less salt, moving more, and keeping stress in check."
            static let pulsePressureRecommendation = "A wider gap between your blood pressure numbers can mean your heart is working harder than usual. Try some gentle movement and easy breathing today."
            static let glucoseRecommendation = "Cut back on sugar and white bread. Eat more fiber. Stay active."
            static let respiratoryRecommendation = "If your breathing rate stays unusual for a few days, it is worth checking in on this."

            // Projection templates
            static func projectedToReach(label: String, days: Int) -> String {
                "At this rate, this could reach \(label) levels in about \(days) days."
            }
            static func projectedToReachRange(label: String, days: Int) -> String {
                "At this rate, this could reach the \(label) range in about \(days) days."
            }

            // BP summary templates
            static func bpTrendingSummary(slopePerMonth: String, dayCount: Int, stage: String, nextStageInfo: String) -> String {
                "Your systolic BP has been rising \(slopePerMonth) mmHg/month over the past \(dayCount) days. Current stage: \(stage). \(nextStageInfo)"
            }
            static func pulsePressureSummary(pulsePressure: Int) -> String {
                "Your pulse pressure (\(pulsePressure) mmHg) is above the typical range of 40 to 60 mmHg. Based on your patterns, this is worth a look."
            }
            static func glucoseTrendingSummary(slopePerMonth: String, latest: String, stage: String, nextInfo: String) -> String {
                "Your fasting glucose has been rising \(slopePerMonth) mg/dL per month. Current: \(latest) mg/dL (\(stage)). \(nextInfo)"
            }
            static func respiratorySummary(rate: String, stage: String) -> String {
                "Your respiratory rate (\(rate) br/min) falls in the \(stage) range. The typical range is 12-20 breaths per minute."
            }
        }

        // MARK: - Recovery Analyzer

        enum Recovery {
            static let postWorkoutHRVRecovery = "Recovery After Workout"
            static let restDayDeficit = "Not Enough Rest Days"
            static let overtrainingWarning = "You May Be Overdoing It"
            static let earlyOvertrainingSignal = "Early Signs of Overdoing It"
        }

        // MARK: - Workout Effectiveness

        enum Workout {
            static let workoutConsistency = "Workout Consistency"
            static let vo2MaxResponse = "VO2 Max Response"
            static let calorieEfficiency = "Calorie Efficiency"
        }

        // MARK: - Sleep Performance

        enum Sleep {
            static func sleepDrives(_ metricName: String) -> String { "Sleep Drives \(metricName)" }
            static let sleepQualityToActivity = "Sleep Quality \u{2192} Activity"
            static let sleepConsistency = "Sleep Consistency"
        }

        // MARK: - Weekly Pattern

        enum WeeklyPattern {
            static func weakestDay(_ dayName: String) -> String { "Weakest Day: \(dayName)" }
            static func weekdayVsWeekend(_ metricName: String) -> String { "\(metricName): Weekday vs Weekend" }
            static func metricConsistency(_ metricName: String) -> String { "\(metricName) Consistency" }
        }

        // MARK: - Cycle Phase

        enum CyclePhase {
            static func title(_ phaseName: String) -> String { "Cycle Phase Analyzer: \(phaseName)" }
            static let scaleIntensityNote = "Your body is reacting more than usual right now. Take it easier for the next 2 days and see how you feel."
            static let keepLoggingNote = "Keep logging every day so we can better learn what is normal for you."

            static let menstrualBaseline = "Lower energy and recovery variability can be normal during menstruation."
            static let follicularBaseline = "Energy and training readiness often improve through the follicular phase."
            static let ovulatoryBaseline = "Many people experience peak readiness around ovulation."
            static let lutealBaseline = "Slightly lower energy in the luteal phase is common and usually expected."

            static let menstrualRecommendation = "Prioritize recovery-first days: lighter training, hydration, and consistent sleep."
            static let follicularRecommendation = "Use this phase for progressive overload and higher-focus tasks while readiness is trending up."
            static let ovulatoryRecommendation = "Schedule your key workouts here, then protect sleep and hydration to stabilize recovery."
            static let lutealRecommendation = "Plan slightly lower-intensity sessions, lock in an earlier bedtime, and favor steady routines."

            static func phaseSummary(phase: String, day: Int, cycleLength: Int, expectation: String) -> String {
                "You are in your \(phase) phase (day \(day) of ~\(cycleLength)). \(expectation)"
            }
            static func metricDirectionFragment(label: String, direction: String, percent: String) -> String {
                "\(label) \(direction) \(percent)%"
            }
        }

        // MARK: - Weekly Pattern Extras

        enum WeeklyPatternStrings {
            static let unknownDay = "Unknown"
            static let restingHRLabel = "Resting HR"
            static let sleepQualityLabel = "Sleep quality"
            static let activityLabel = "Activity"
        }

        // MARK: - Personal Records

        enum PersonalRecord {
            // Milestone labels
            static let tenKStepDay = "10K Step Day"
            static let eightKPlusSteps = "8K+ Steps"
            static let thirtyPlusMinExercise = "30+ Min Exercise"
            static let hrvAbove50ms = "HRV Above 50ms"
            static let eightHourSleepNight = "8-Hour Sleep Night"
            static let sevenPlusHrSleep = "7+ Hr Sleep"
            static let tenPlusStandHours = "10+ Stand Hours"

            // Title templates
            static func newPR(windowLabel: String, metricName: String) -> String {
                "New \(windowLabel) PR: \(metricName)"
            }
            static func streakTitle(days: Int, label: String) -> String {
                "\(days)-Day \(label) Streak"
            }
            static func milestoneTitle(_ label: String) -> String {
                "Milestone: \(label)"
            }

            // Summary templates
            static func streakSummary(label: String, days: Int) -> String {
                "You have hit \(label.lowercased()) for \(days) consecutive days."
            }
            static func milestoneSummary(_ label: String) -> String {
                "You achieved \(label.lowercased()) for the first time this week."
            }
            static func milestoneRecommendation(_ label: String) -> String {
                "First recorded instance of \(label.lowercased()) in your data."
            }
        }

        // MARK: - Score Trajectory

        enum ScoreTrajectory {
            static let healthScoreTrendingUp = "Health Score Trending Up"
            static let healthScoreDeclining = "Health Score Declining"
            static let improvementAccelerating = "Getting Better Faster"
            static let declineAccelerating = "Getting Worse Faster"
            static let consistentlyStrongHealth = "Staying Strong"
            static let extendedLowScorePeriod = "Low Score for a While"

            // Momentum summaries
            static let gainsPickingUpSpeed = "You are improving faster this week than last."
            static let droppingFaster = "Your score is dropping faster this week. A few areas need a look."
        }

        // MARK: - Baseline Drift

        enum BaselineDrift {
            static func title(metricName: String, period: String) -> String {
                "\(metricName) Baseline Shifted Over \(period)"
            }
        }

        // MARK: - Multi-Metric Cluster

        enum MultiMetricCluster {
            static func categoryDeclining(_ categoryName: String) -> String {
                "\(categoryName): Multiple Metrics Declining"
            }
            static let widespreadHealthDecline = "Widespread Health Decline"

            static let directionAbove = "above"
            static let directionBelow = "below"

            static func metricDetail(name: String, formatted: String, unit: String, dev: String, dir: String) -> String {
                "\(name): \(formatted) \(unit) (\(dev)% \(dir) baseline)"
            }
            static func metricDeviation(name: String, dev: String) -> String {
                "\(name) (\(dev)% deviation)"
            }
            static func clusterSummary(count: Int, categoryName: String, details: String) -> String {
                "\(count) metrics declining together in \(categoryName): \(details)."
            }
            static func crossCategorySummary(total: Int, categoryCount: Int, names: String) -> String {
                "\(total) metrics across \(categoryCount) categories are declining: \(names)."
            }
            static func crossCategoryRecommendation(total: Int, categoryCount: Int, names: String) -> String {
                "\(total) metrics declining across \(categoryCount) categories: \(names)."
            }

            static func heartCluster(count: Int, names: String, dev: String) -> String {
                "Multiple heart metrics declining simultaneously \u{2014} \(count) metrics affected: \(names). Avg \(dev)% below baseline."
            }
            static func sleepCluster(count: Int, names: String, dev: String) -> String {
                "Sleep deteriorating across \(count) dimensions \u{2014} \(names). Avg \(dev)% below baseline."
            }
            static func activityCluster(count: Int, names: String, dev: String) -> String {
                "Activity declining across \(count) metrics \u{2014} \(names). Avg \(dev)% below baseline."
            }
            static func bodyCluster(count: Int, names: String, dev: String) -> String {
                "Body composition metrics shifting \u{2014} \(count) metrics affected: \(names). Avg \(dev)% from baseline."
            }
            static func respiratoryCluster(count: Int, names: String, dev: String) -> String {
                "Respiratory metrics elevated \u{2014} \(count) metrics affected: \(names). Avg \(dev)% from baseline."
            }
            static func mindfulnessCluster(count: Int, names: String, dev: String) -> String {
                "Mindfulness metrics declining \u{2014} \(count) metrics affected: \(names). Avg \(dev)% below baseline."
            }
            static func mobilityCluster(count: Int, names: String, dev: String) -> String {
                "Mobility metrics declining across \(count) indicators \u{2014} \(names). Avg \(dev)% below baseline."
            }
            static func nutritionCluster(count: Int, names: String, dev: String) -> String {
                "Nutrition metrics shifted from baseline \u{2014} \(count) metrics affected: \(names). Avg \(dev)% from baseline."
            }
            static func hearingCluster(count: Int, names: String, dev: String) -> String {
                "Hearing metrics changed \u{2014} \(count) metrics affected: \(names). Avg \(dev)% from baseline."
            }
        }

        // MARK: - Cross-Metric Anomaly Narratives

        enum CrossMetricNarratives {
            static func extremelyRare(metrics: String) -> String {
                "This combination of metric values (\(metrics)) is extremely rare for you. Worth exploring what was different yesterday \u{2014} travel, diet timing, late workouts, or stress shifts often trigger this. If this pattern shows up for 2+ days, it may be worth discussing with a healthcare provider."
            }
            static func brokenRelationship(metricA: String, metricB: String) -> String {
                "The usual relationship between your \(metricA) and \(metricB) has broken down. Review what was different yesterday \u{2014} travel, diet changes, late exercise, or unusual stress are common triggers. Track whether this normalizes within 48 hours."
            }
            static func unusualMultiCategory(categoryCount: Int, metrics: String) -> String {
                "Unusual pattern across \(categoryCount) categories (\(metrics)). Review what was different yesterday \u{2014} travel, diet, late exercise, or stress changes are the most common triggers. If you feel fine, this may be a one-off."
            }
            static func unusualCombination(metrics: String) -> String {
                "Unusual combination in \(metrics). Review what was different yesterday \u{2014} travel, diet, late exercise, or stress changes are common triggers."
            }
            static func unusualMild(metrics: String) -> String {
                "Unusual but mild pattern in \(metrics). No immediate action needed \u{2014} track whether this recurs over the next 3 days to determine if it's a one-off or emerging trend."
            }
        }

        // MARK: - Cognitive Energy

        enum CognitiveEnergy {
            static let lowCognitiveReadiness = "Low Cognitive Energy"
            static let strongCognitiveReadiness = "Strong Cognitive Energy"
            static let sleepDebtAccumulating = "Sleep Balance Declining"
            static let mentalFatiguePatternDetected = "Signs of Mental Fatigue"
            static let lowPhysicalEnergy = "Low Physical Energy"
            static let recoveryDayNeeded = "Recovery Day Needed"
            static let daylightSleepCognitionChain = "Sunlight, Sleep, and Focus"

            // Cognitive energy narratives
            static func cognitiveReadinessLow(score: Int, componentText: String) -> String {
                "Your mental energy is at \(score) out of 100\(componentText). You may feel less sharp and think slower today."
            }
            static func cognitiveReadinessStrong(score: Int) -> String {
                "Your mental energy is strong at \(score) out of 100. Your heart, sleep, and recovery numbers are all better than usual."
            }
            static let brainPrimedForWork = "Great day for hard thinking. Use this energy for your toughest tasks."

            // Recovery day
            static let recoveryDayRecommendation = "Take a real rest day tomorrow. Just light walking, no hard exercise. Your body usually bounces back within 2 days of taking it easy."

            // Component fragments
            static func downFromBaseline(percent: String) -> String {
                "down \(percent)% from baseline"
            }
            static func belowBaseline(percent: String) -> String {
                "\(percent)% below baseline"
            }
            static func hoursBelowBaseline(hours: String) -> String {
                "\(hours) hrs below your baseline"
            }

            // Cognitive readiness narratives (analyzer)
            static func cognitiveLowSummary(score: Int, componentText: String) -> String {
                "Your cognitive energy is at \(score)/100\(componentText). Addressing these factors can sharpen mental clarity and processing speed."
            }
            static func cognitiveLowRecommendation(topComponent: String) -> String {
                "Consider extending tonight's sleep by 45 min. Your \(topComponent) is the biggest factor right now. A single night of 8+ hr sleep typically improves next-day HRV and deep sleep."
            }
            static func cognitiveStrongSummary(score: Int) -> String {
                "Your cognitive energy is strong at \(score)/100. HRV, sleep quality, and recovery markers are all above baseline."
            }

            // Sleep debt
            static func sleepDebtSummary(debt: String, avg: String, baseline: String) -> String {
                "You have built up \(debt) hours of sleep debt this week (averaging \(avg) hrs vs your \(baseline) hr baseline). Short sleep can affect how alert and clear-headed you feel each day."
            }
            static func sleepDebtRecommendation(catchUpNights: Int) -> String {
                "An extra hour per night for \(catchUpNights) nights can help clear this deficit. Setting a bedtime alarm 45 min before your target sleep time is a good starting point."
            }

            // Mental fatigue
            static func mentalFatigueSummary(parts: String) -> String {
                "Your \(parts) over the past week \u{2014} this combination is strongly associated with mental fatigue, slower processing, and difficulty concentrating."
            }
            static func mentalFatigueRecommendation(actions: String) -> String {
                "Three actions ranked by impact: \(actions)."
            }

            // Low physical energy
            static func lowPhysicalSummary(signalText: String) -> String {
                "Your physical energy indicators are low: \(signalText). You're likely feeling fatigued and heavy."
            }

            // Recovery needed
            static func recoveryNeededSummary(consecutiveHighDays: Int, signalText: String) -> String {
                "You've been highly active for \(consecutiveHighDays) days straight and your recovery markers are strained \u{2014} \(signalText). Without recovery, both mental sharpness and physical performance decline."
            }

            // Daylight chain
            static func daylightChainSummary(daylightChange: String, deepDeclining: Bool, deepChange: String) -> String {
                "Your daylight exposure dropped \(daylightChange)% and \(deepDeclining ? "deep sleep" : "sleep duration") declined \(deepChange)% in the same window. These are connected \u{2014} natural light sets your circadian clock, which drives sleep architecture and next-day cognitive clarity."
            }
            static func daylightChainRecommendation(effectNote: String) -> String {
                "Get 20+ min of outdoor light before noon tomorrow.\(effectNote) This single change impacts your sleep timing, deep sleep percentage, and next-day mental sharpness."
            }
        }

        // MARK: - Strain Signals

        enum StrainSignals {
            static let significantStrain = "Your Body is Under Stress"
            static let multipleMetricStrain = "Several Numbers Show Your Body is Stressed"
            static let earlyPhysiologicalStrain = "Early Signs Your Body is Stressed"
            static let multiMetricPattern = "Several health numbers shifted at the same time. Your body may be under extra stress."
            static let multipleMetricsShifted = "Several numbers moved away from your usual at the same time."
            static let consistentWithPhysiologicalStrain = "The pattern across your numbers suggests your body is under extra stress."
            static let cardiacMetricsStrain = "Your heart numbers suggest your body is stressed."
            static let activityNotReturned = "Your activity numbers have not gone back to your usual yet."
        }

        // MARK: - Health Data Query Engine

        enum HealthDataQuery {
            // Question templates
            static func qHowTrending(_ metric: String) -> String { "How is my \(metric) trending?" }
            static func qCompare(_ metric: String) -> String { "Compare my \(metric)" }
            static func qDoesAffect(_ a: String, _ b: String) -> String { "Does \(a) affect \(b)?" }
            static func qWhatWillBe(_ metric: String) -> String { "What will my \(metric) be?" }
            static func qWhatWillBeWhen(_ metric: String, when: String) -> String { "What will my \(metric) be \(when)?" }
            static let qAnythingUnusual = "Anything unusual?"
            static func qWhatWasLabel(_ label: String, _ metric: String) -> String { "What was my \(label) \(metric)?" }
            static func qHowIsMetric(_ metric: String) -> String { "How is my \(metric)?" }
            static let qHowIsBodyDoing = "How is my body doing?"
            static let qWhatStateIsBody = "What state is my body in?"
            static let qAmIAtRisk = "Am I at risk?"
            static let qHowGreatDay = "How do I have a great day?"
            static let qHowImprove = "How do I improve?"
            static let qWhatAffects = "What affects my "
            static let qPredictForTomorrow = "Predict my "
            static let qDoIHavePatterns = "Do I have any "

            // Related questions
            static func relatedAffects(_ metric: String) -> String { "What affects my \(metric)?" }
            static func relatedPredict(_ metric: String) -> String { "Predict my \(metric) for tomorrow" }
            static func relatedPatterns(_ metric: String) -> String { "Do I have any \(metric) patterns?" }

            // Trending answer
            static func trendingAnswer(action: String, metric: String, direction: String, period: String, avg: String) -> String {
                "\(action) Your \(metric) is \(direction) over \(period), averaging \(avg)."
            }

            // Comparison
            static let comparisonRoughlySame = "roughly the same"
            static let comparisonLookingBetter = "looking better"
            static let comparisonABitLower = "a bit lower"
            static let comparisonKeepUp = "Keep up whatever you changed. It's working."
            static let comparisonHoldingSteady = "You're holding steady, which is a good sign."
            static func comparisonGetBack(period: String) -> String {
                "Try to get back to your \(period) routine. Your body did better then."
            }
            static func comparisonAnswer(action: String, metric: String, periodA: String, verdict: String, periodB: String, avgA: String, avgB: String) -> String {
                "\(action) Your \(metric) \(periodA) is \(verdict) compared to \(periodB) (\(avgA) vs \(avgB))."
            }

            // Correlation
            static let strengthStrong = "strong"
            static let strengthModerate = "moderate"
            static let strengthMild = "mild"
            static let strengthVeryWeak = "very weak"
            static let directionMoveTogether = "move together"
            static let directionMoveOpposite = "move in opposite directions"
            static let lagNextDay = "the next day"
            static func lagDaysLater(_ days: Int) -> String { "\(days) days later" }
            static func correlationCausal(metricA: String, metricB: String, lag: String, strength: String, direction: String) -> String {
                "Pay attention to your \(metricA). When it changes, your \(metricB) tends to follow \(lag). There's a \(strength) link between the two, and they \(direction)."
            }
            static func correlationActionable(actionable: String, other: String, strength: String, direction: String) -> String {
                "Yes, improving your \(actionable) is likely to help your \(other) too. There's a \(strength) connection and they \(direction)."
            }
            static func correlationNoLink(metricA: String, metricB: String) -> String {
                "I haven't found a clear statistical connection between your \(metricA) and \(metricB) so far. They appear to move independently based on the data I have."
            }

            // Forecast
            static func forecastNoModel(metric: String, avg: String, latest: String, when: String) -> String {
                "I don't have a full forecasting model for \(metric) yet, but based on your recent trend (averaging \(avg) over the past week, latest at \(latest)), you can expect it to stay in a similar range \(when)."
            }
            static func forecastNeedMore(metric: String) -> String {
                "I need a bit more \(metric) data to make a prediction. Once I have a couple of weeks of history, I'll be able to forecast ahead for you."
            }
            static func forecastAnswer(action: String, metric: String, value: String, when: String) -> String {
                "\(action) I'm expecting your \(metric) to be around \(value) \(when), based on your patterns."
            }

            // Anomaly
            static let anomalyAllNormal = "Everything looks within your normal ranges right now. No spikes, no dips. your body is humming along as expected."
            static func anomalyAnswer(action: String, metric: String, value: String, dir: String) -> String {
                "\(action) Your \(metric) at \(value) is noticeably \(dir) than your usual."
            }

            // Personal records
            static let prBestSuffix = "That's a solid benchmark to work toward again."
            static let prWorstSuffix = "Everyone has off days. what matters is the overall trajectory."
            static func prAnswer(label: String, metric: String, value: String, dateStr: String, suffix: String) -> String {
                "Your \(label) \(metric) on record was \(value), recorded on \(dateStr). \(suffix)"
            }

            // Metric status
            static func statusKeepDoing(metric: String, latest: String) -> String {
                "Keep doing what you're doing. Your \(metric) is above your personal baseline at \(latest). Whatever your routine is right now, it's working."
            }
            static func statusEaseUp(metric: String, latest: String) -> String {
                "Try to ease up a bit today. Your \(metric) is running high at \(latest), above your usual baseline."
            }
            static func statusDipped(metric: String, latest: String) -> String {
                "Your \(metric) has dipped to \(latest), below your usual level. Focus on recovery. Sleep, hydration, and lighter activity can help bring it back up."
            }
            static func statusBelowGood(metric: String, latest: String) -> String {
                "Nice, your \(metric) is at \(latest), below your baseline, which is a good sign. Keep it up."
            }
            static func statusOnBaseline(metric: String, latest: String) -> String {
                "Your \(metric) is right where it should be at \(latest). Steady and consistent. That's what you want to see."
            }
            static func statusLearning(metric: String, latest: String, avg: String) -> String {
                "Your \(metric) is at \(latest) with a 7-day average of \(avg). As I learn your patterns, I'll be able to give you more personalized advice."
            }

            // Body state
            static let bodyNoData = "No health data available yet. Once you connect your Apple Watch or allow Health access, I'll be able to tell you how your body is doing."
            static func bodySnapshot(summary: String) -> String {
                "Here's a snapshot of your body right now. \(summary) As I gather more history, I'll be able to classify your body's overall state automatically."
            }
            static func bodyStateAnswer(conclusion: String, label: String, traits: String, durationNote: String) -> String {
                "\(conclusion) Your body is in a \"\(label)\" state right now, where \(traits).\(durationNote)"
            }

            // Risk
            static func riskOutsideRange(metric: String, value: String) -> String {
                "Based on your recent readings, your \(metric) at \(value) is outside your usual range. Worth keeping an eye on. As I build a longer history, I'll be able to run deeper risk assessments."
            }
            static let riskNothingConcerning = "Based on the data I have, nothing looks concerning right now. All your recent readings are within your normal ranges. I'll keep monitoring and alert you if anything changes."
            static let riskAllHealthy = "No significant health risks detected. your fatigue, burnout, overtraining, sleep, immune, and activity signals all look healthy."
            static let riskCritical = "at a critical level"
            static let riskHigh = "elevated"
            static let riskWatching = "worth watching"
            static func riskAnswer(recommendation: String, name: String, level: String, explanation: String) -> String {
                "\(recommendation) Your \(name) is \(level). \(explanation)"
            }

            // Improvement
            static func greatDayFocusOn(_ gaps: String) -> String {
                "Focus on your \(gaps) today. That's your biggest opportunity to improve. "
            }
            static let greatDayCloseToIdeal = "You're close to your ideal day. Keep your current routine going. "
            static func improveBiggestImpact(_ levers: String) -> String {
                "The metrics with the biggest impact on your score are: \(levers). Small improvements here will move the needle the most."
            }
            static func improveMostRoom(_ tips: String) -> String {
                "Here's where you have the most room to improve right now: \(tips). Focus on bringing these back to your baseline and you should feel the difference."
            }
            static let improveAllOnBaseline = "Your key metrics are all close to your personal baselines right now, which is a great sign. Keep up the consistency, and as I learn more about what drives your best days, I'll give you more targeted advice."

            // Data point labels
            static let labelAverage = "Average"
            static let labelChange = "Change"
            static let labelLatest = "Latest"
            static let labelCorrelation = "Correlation"
            static let labelStability = "Stability"

            // Pattern Q
            static let qAnyPatterns = "Any patterns?"
            static let qAnyPatternsInData = "Any patterns in my data?"
            static func patternEmerging(target: String) -> String {
                "I'm seeing some emerging patterns in your \(target), but they're not strong enough to be definitive yet."
            }
            static func patternCycleHint(type: String, dayName: String) -> String {
                " There's a hint of a \(type) cycle, with a mild peak on \(dayName)s."
            }
            static func patternNoneFound(target: String) -> String {
                "No recurring patterns detected in \(target) at this time. This can actually be a good sign. it means your body is responding consistently. I'll keep looking for weekly and monthly rhythms."
            }
            static func patternPeakTrough(peakDay: String, metric: String, troughDay: String, type: String) -> String {
                "Plan your toughest activities for \(peakDay)s when your \(metric) peaks, and take it easier on \(troughDay)s when it dips. Your \(metric) follows a clear \(type) cycle."
            }
            static func patternCycleAdvice(metric: String, type: String) -> String {
                "Your \(metric) follows a clear \(type) cycle. Use that rhythm to your advantage by scheduling harder days around your peaks."
            }
            static let yourMetrics = "your metrics"

            // Circadian
            static let buildingCircadianProfile = "I'm still building your full circadian profile."
            static func circadianRecentSleep(avg: String) -> String {
                " Based on your recent sleep (\(avg) average), aim to be consistent with your bedtime."
            }
            static func circadianAvgSteps(steps: Int) -> String {
                " You're averaging \(steps) steps. a morning or afternoon walk is generally a great time to move."
            }
            static let circadianGeneralAdvice = " In the meantime, a good general rule: exercise in the morning or early afternoon, wind down 1-2 hours before bed, and keep your sleep schedule consistent."
            static let qWhenWorkOut = "When should I work out?"
            static let qBodyClock = "What's my body clock like?"
            static func circadianBestWindows(lines: String, chronotype: String, peak: String) -> String {
                "Here are your best windows based on your body clock: \(lines). You're a \(chronotype), with peak energy around \(peak)."
            }
            static func circadianChronotype(chronotype: String, peak: String) -> String {
                "You're a \(chronotype). Your peak energy is around \(peak), so schedule your hardest workout or deep work then."
            }
            static func circadianRecoveryPeak(hour: String) -> String {
                " Your recovery peaks around \(hour), which is a good time for lighter activity."
            }

            // Highlight summary
            static func highlightHigh(label: String, value: String) -> String {
                "\(label) is a bit high at \(value)"
            }
            static func highlightLow(label: String, value: String) -> String {
                "\(label) is on the low side at \(value)"
            }
            static func highlightNormal(label: String, value: String) -> String {
                "\(label) is normal at \(value)"
            }
            static func highlightDefault(label: String, value: String) -> String {
                "\(label) is at \(value)"
            }
            static func metricsTrackingNormal(count: Int) -> String {
                "I'm tracking \(count) metrics. Everything I see looks within expected ranges."
            }

            // Risk fallback
            static func riskRoughDay(percent: Int, summary: String) -> String {
                "Based on your recent data, there's a \(percent)% chance tomorrow could be a rough day. \(summary)"
            }
            static func riskLowDay(percent: Int) -> String {
                "Looking ahead, your risk of a bad day tomorrow is low (\(percent)%). You're in a good position."
            }

            // Optimization tail
            static func optimizationAimFor(targetList: String, score: Int) -> String {
                "Your data says to aim for: \(targetList). Hit those targets and you're looking at a score of \(score)."
            }

            // Related question constants
            static let rqHowAmIDoingOverall = "How am I doing overall?"
            static let rqAmIAtRiskForAnything = "Am I at risk for anything?"
            static let rqWhatDataDoIHave = "What data do I have?"
            static let rqHowIsMyHRVTrending = "How is my HRV trending?"
            static let rqHowIsMySleepTrending = "How is my sleep trending?"
            static let rqWhatStateIsMyBody = "What state is my body in?"
            static let rqWhatShouldIDoToday = "What should I do today?"
            static let rqAnythingUnusualInData = "Anything unusual in my data?"
            static let rqDoIHaveAnyPatterns = "Do I have any patterns?"
            static let rqWhatShouldIFocusOn = "What should I focus on?"
            static func rqAnythingUnusualInMetric(_ metric: String) -> String { "Anything unusual in my \(metric)?" }
        }

        // MARK: - Rules Engine Helpers

        enum RulesEngine {
            static func projection(days: Int) -> String {
                " Based on current trends, this may approach warning level within ~\(days) days."
            }
            static func rootCause(metric: String, percent: String) -> String {
                " This appears connected to your \(metric) shifting \(percent)%."
            }
            static func historicalPercentile(label: String) -> String {
                "in the \(label) of your history"
            }
            static func historicalSeasonal(percent: String, direction: String, month: String) -> String {
                "\(percent)% \(direction) your typical \(month)"
            }
            static func historicalYoY(percent: String, direction: String) -> String {
                "\(percent)% \(direction) than this time last year"
            }
            static func historicalIntro(parts: String) -> String {
                " Historically: \(parts)."
            }
            static func correlationAction(factor: String, metric: String, percent: String) -> String {
                " Your data shows that improving \(factor) raises your \(metric) by ~\(percent)%."
            }
            static func topLever(factor: String, percent: String, metric: String) -> String {
                "Your #1 lever: improve \(factor) (\(percent)% impact on \(metric))."
            }

            // Cardio
            static func rhrAboveBaseline(valStr: String, devStr: String) -> String {
                "\(valStr)Your resting HR is \(devStr)above your baseline."
            }
            static let rhrCheckChanges = " Check for recent changes in sleep, stress, or caffeine intake."
            static func rhrTrendingDown(valStr: String) -> String {
                "\(valStr)Resting HR is trending down from your recent average."
            }
            static func rhrConsistent(valStr: String) -> String {
                "\(valStr)Resting HR is consistent with your 30-day average."
            }
            static func hrvDownBaseline(valStr: String, devStr: String) -> String {
                "\(valStr)HRV is down \(devStr)from your baseline."
            }
            static let hrvCheckChanges = " Check recent changes in sleep or recovery patterns."
            static func hrvConsistent(valStr: String) -> String {
                "\(valStr)HRV is consistent with your 30-day average."
            }
            static func vo2Improving(valStr: String, devStr: String) -> String {
                "\(valStr)VO2 Max is up \(devStr)from your baseline \u{2014} your cardiovascular fitness is improving."
            }
            static func vo2Flat(valStr: String, devStr: String) -> String {
                "\(valStr)VO2 Max has been flat or declining \(devStr)compared to your baseline."
            }
            static func bloodOxygenCritical(valStr: String) -> String {
                "\(valStr)Blood oxygen is critically low, below the 90% emergency threshold. This level of hypoxemia requires immediate attention. If you experience shortness of breath, confusion, bluish lips or fingertips, or chest pain, seek emergency medical care. Retake the reading to confirm, and if it remains below 90%, contact a healthcare provider urgently."
            }
            static func bloodOxygenDropped(valStr: String, devStr: String) -> String {
                "\(valStr)Blood oxygen has dropped \(devStr)below your typical level."
            }
            static func bloodOxygenTypical(valStr: String) -> String {
                "\(valStr)Blood oxygen is tracking at your typical level."
            }
            static func afibElevated(valStr: String, devStr: String) -> String {
                "\(valStr)AFib burden is elevated \(devStr)compared to your baseline."
            }
            static func afibTypical(valStr: String) -> String {
                "\(valStr)AFib burden is tracking at your typical level."
            }
            static func perfusionElevated(valStr: String, devStr: String) -> String {
                "\(valStr)Perfusion index is \(devStr)outside your typical range."
            }
            static func perfusionTypical(valStr: String) -> String {
                "\(valStr)Peripheral perfusion is tracking at your typical level."
            }

            // Sleep
            static func sleepDurationBelow(valStr: String, devStr: String) -> String {
                "\(valStr)Sleep duration is \(devStr)below your baseline."
            }
            static func sleepDurationConsistent(valStr: String) -> String {
                "\(valStr)Sleep duration is consistent with your baseline."
            }
            static func sleepStage(valStr: String, stage: String, devStr: String, direction: String) -> String {
                "\(valStr)\(stage) sleep is \(devStr)\(direction) your baseline."
            }
            static func sleepCoreTypical(valStr: String) -> String {
                "\(valStr)Core sleep is tracking at your typical level."
            }
            static func sleepAwakeAbove(valStr: String, devStr: String) -> String {
                "\(valStr)Nighttime wake time is \(devStr)above your typical level."
            }
            static func sleepAwakeTypical(valStr: String) -> String {
                "\(valStr)Nighttime awake periods are tracking at your typical level."
            }

            // Activity
            static func stepsDown(valStr: String, devStr: String) -> String {
                "\(valStr)Step count is down \(devStr)from your baseline."
            }
            static func stepsUp(valStr: String, devStr: String) -> String {
                "\(valStr)Step count is up \(devStr)from your baseline."
            }
            static func stepsConsistent(valStr: String) -> String {
                "\(valStr)Step count is consistent with your baseline."
            }
            static func activeCaloriesDown(valStr: String, devStr: String) -> String {
                "\(valStr)Active calorie burn is down \(devStr)from your baseline."
            }
            static func activeCaloriesAbove(valStr: String) -> String {
                "\(valStr)Active calorie burn is tracking above your baseline."
            }
            static func exerciseDown(valStr: String, devStr: String) -> String {
                "\(valStr)Exercise time has dropped \(devStr)from your recent average."
            }
            static func exerciseConsistent(valStr: String) -> String {
                "\(valStr)Exercise time is consistent with your recent average."
            }
            static func cyclingDown(valStr: String, devStr: String) -> String {
                "\(valStr)Cycling distance is down \(devStr)from your baseline."
            }
            static func cyclingConsistent(valStr: String) -> String {
                "\(valStr)Cycling distance is consistent with your baseline."
            }
            static func swimmingDown(valStr: String, devStr: String) -> String {
                "\(valStr)Swimming activity has declined \(devStr)from your baseline."
            }
            static func swimmingConsistent(valStr: String) -> String {
                "\(valStr)Swimming activity is consistent with your baseline."
            }
            static func moveTimeDown(valStr: String, devStr: String) -> String {
                "\(valStr)Move time is down \(devStr)from your baseline."
            }
            static func moveTimeConsistent(valStr: String) -> String {
                "\(valStr)Move time is consistent with your baseline."
            }
            static func walkingSpeedDown(valStr: String, devStr: String) -> String {
                "\(valStr)Walking speed is down \(devStr)from your baseline."
            }
            static func walkingSpeedConsistent(valStr: String) -> String {
                "\(valStr)Walking speed is consistent with your baseline."
            }
            static func stepLengthDown(valStr: String, devStr: String) -> String {
                "\(valStr)Step length has shortened \(devStr)from your baseline."
            }
            static func stepLengthConsistent(valStr: String) -> String {
                "\(valStr)Step length is consistent with your baseline."
            }
            static func walkingAsymmetryElevated(valStr: String, devStr: String) -> String {
                "\(valStr)Walking asymmetry is elevated \(devStr)above your typical level."
            }
            static func walkingSymmetryConsistent(valStr: String) -> String {
                "\(valStr)Walking symmetry is consistent with your baseline."
            }
            static func doubleSupportElevated(valStr: String, devStr: String) -> String {
                "\(valStr)Double support time is elevated \(devStr)above your typical level."
            }
            static func doubleSupportTypical(valStr: String) -> String {
                "\(valStr)Double support percentage is tracking at your typical level."
            }
            static func stairSpeedDown(valStr: String, devStr: String) -> String {
                "\(valStr)Stair speed is down \(devStr)from your baseline."
            }
            static func stairSpeedConsistent(valStr: String) -> String {
                "\(valStr)Stair speed is consistent with your baseline."
            }
            static func sixMinuteWalkDown(valStr: String, devStr: String) -> String {
                "\(valStr)Six-minute walk distance is down \(devStr)from your baseline."
            }
            static func sixMinuteWalkConsistent(valStr: String) -> String {
                "\(valStr)Six-minute walk distance is consistent with your baseline."
            }

            // Body & vitals
            static func bodyCompTrendingUp(valStr: String, devStr: String) -> String {
                "\(valStr)Trending up \(devStr)from your baseline."
            }
            static func bodyCompConsistent(valStr: String) -> String {
                "\(valStr)Body composition is consistent with your recent trend."
            }
            static func leanMassDown(valStr: String, devStr: String) -> String {
                "\(valStr)Lean body mass is down \(devStr)from your baseline."
            }
            static func leanMassConsistent(valStr: String) -> String {
                "\(valStr)Lean body mass is consistent with your baseline."
            }
            static func waistAbove(valStr: String, devStr: String) -> String {
                "\(valStr)Waist circumference is \(devStr)above your baseline."
            }
            static func waistConsistent(valStr: String) -> String {
                "\(valStr)Waist circumference is consistent with your baseline."
            }
            static func wristTempDeviated(valStr: String, devStr: String) -> String {
                "\(valStr)Wrist temperature has deviated \(devStr)from your typical range."
            }
            static func wristTempTypical(valStr: String) -> String {
                "\(valStr)Sleeping wrist temperature is tracking at your typical level."
            }
            static func bpAbove(valStr: String, devStr: String) -> String {
                "\(valStr)Blood pressure is \(devStr)above your baseline."
            }
            static func bpConsistent(valStr: String) -> String {
                "\(valStr)Blood pressure is consistent with your baseline."
            }
            static func respiratoryElevated(valStr: String, devStr: String) -> String {
                "\(valStr)Respiratory rate is elevated \(devStr)above your baseline."
            }
            static func respiratoryTypical(valStr: String) -> String {
                "\(valStr)Respiratory rate is tracking at your typical level."
            }
            static func peakFlowDown(valStr: String, devStr: String) -> String {
                "\(valStr)Peak flow rate has dropped \(devStr)below your baseline."
            }
            static func peakFlowTypical(valStr: String) -> String {
                "\(valStr)Peak expiratory flow rate is tracking at your typical level."
            }
            static func forcedVitalDown(valStr: String, devStr: String) -> String {
                "\(valStr)Forced vital capacity is down \(devStr)from your baseline."
            }
            static func lungCapacityTypical(valStr: String) -> String {
                "\(valStr)Lung capacity is tracking at your typical level."
            }
            static func bodyTempOutside(valStr: String, devStr: String) -> String {
                "\(valStr)Body temperature is \(devStr)outside your typical range."
            }
            static func bodyTempTypical(valStr: String) -> String {
                "\(valStr)Body temperature is tracking at your typical level."
            }
            static func mindfulnessDown(valStr: String, devStr: String) -> String {
                "\(valStr)Mindfulness time has dropped \(devStr)from your baseline."
            }
            static func mindfulnessConsistent(valStr: String) -> String {
                "\(valStr)Mindfulness time is consistent with your baseline."
            }
            static func daylightDown(valStr: String, devStr: String) -> String {
                "\(valStr)Daylight exposure is down \(devStr)from your baseline."
            }
            static func daylightConsistent(valStr: String) -> String {
                "\(valStr)Daylight exposure is consistent with your baseline."
            }
            static func edaElevated(valStr: String, devStr: String) -> String {
                "\(valStr)Electrodermal activity is elevated \(devStr)above your baseline."
            }
            static func edaTypical(valStr: String) -> String {
                "\(valStr)Electrodermal activity is tracking at your typical level."
            }

            // Default
            static func defaultDeclining(valStr: String, metricName: String, devStr: String) -> String {
                "\(valStr)\(metricName) is declining \(devStr)from your baseline."
            }
            static func defaultTypical(valStr: String, metricName: String) -> String {
                "\(valStr)\(metricName) is tracking at your typical level."
            }
        }

        // MARK: - Health Risk Focus Recommendations

        enum HealthRiskFocus {
            typealias Recommendation = (title: String, description: String, target: String)

            // Cardiac
            static let lowerRHR: Recommendation = (
                "Lower Resting Heart Rate",
                "Regular brisk walking or cycling for about 30 min a day can help your resting heart rate ease over weeks. Try cutting back on caffeine and managing stress.",
                "Aim for steady, lower readings over time"
            )
            static let improveHRV: Recommendation = (
                "Improve Heart Rate Variability",
                "Better sleep, slow breathing (4 in, 4 hold, 4 out, 4 hold), and recovery days between hard workouts can help.",
                "Aim for steady, higher readings over time"
            )
            static let supportBP: Recommendation = (
                "Support Blood Pressure",
                "Try eating less salty and processed food, moving more through the week, keeping a healthy weight, and going easy on alcohol.",
                "Aim for steady readings in your usual range"
            )
            static let improveHRR: Recommendation = (
                "Improve Heart Rate Recovery",
                "Faster recovery often follows regular cardio. Try adding short cool-down walks at the end of workouts.",
                "Aim for a quicker drop after exercise over time"
            )
            static let aboutAFib: Recommendation = (
                "About Heart Rhythm Notifications",
                "Heart rhythm detection requires Apple Watch ECG. Laso shows the data only and does not interpret it for you. Talk to a qualified professional about anything you notice.",
                ""
            )

            // Sleep
            static let increaseSleepDuration: Recommendation = (
                "Increase Sleep Duration",
                "Set a fixed bedtime 8 hours before your alarm. No screens 1 hour before bed. Keep your bedroom cool (65-68°F) and dark.",
                "Target: 7\u{2013}9 hours"
            )
            static let boostDeepSleep: Recommendation = (
                "Boost Deep Sleep",
                "Exercise earlier in the day (not within 3 hours of bedtime), avoid alcohol which fragments deep sleep, and maintain a cool bedroom.",
                "Target: 1\u{2013}2 hours per night"
            )
            static let improveREM: Recommendation = (
                "Improve REM Sleep",
                "REM sleep is essential for memory and emotional processing. Consistent sleep schedule and avoiding sleep aids can increase REM proportion.",
                "Target: 1.5\u{2013}2 hours per night"
            )
            static let reduceWaking: Recommendation = (
                "Reduce Nighttime Waking",
                "Limit fluids 2 hours before bed, avoid caffeine after noon, use white noise, and keep the room dark. Address any sleep apnea concerns.",
                "Target: <30 min per night"
            )

            // Overtraining
            static let allowRecovery: Recommendation = (
                "Allow Recovery Time",
                "Low HRV with high training load signals insufficient recovery. Take 1-2 rest days, prioritize sleep, and reduce workout intensity by 20%.",
                "Target: HRV returning to baseline"
            )
            static let watchElevatedRHR: Recommendation = (
                "Watch for Elevated RHR",
                "A rising RHR despite regular training is a classic overtraining sign. Reduce volume this week and monitor RHR each morning before getting up.",
                "Target: Within 5 bpm of personal baseline"
            )
            static let balanceLoad: Recommendation = (
                "Balance Training Load",
                "More isn't always better. Follow the 80/20 rule: 80% easy, 20% hard. Include at least 2 rest days per week.",
                "Target: 150\u{2013}300 min/week with rest days"
            )

            // Respiratory
            static let trackBloodOxygen: Recommendation = (
                "Track Blood Oxygen",
                "Try slow, deep breathing through the day, and sleep with your head slightly raised if readings dip at night. If a reading looks unusually low, take another reading and reach out to a qualified professional if it stays low.",
                "Aim for steady readings in your usual range"
            )
            static let buildCardio: Recommendation = (
                "Build Cardiovascular Fitness",
                "VO2 Max reflects how well your heart, lungs, and muscles use oxygen during exercise. Try adding 3 to 4 easy-pace cardio sessions a week for 30+ minutes.",
                "Aim for steady improvement over weeks"
            )
            static let steadyBreathing: Recommendation = (
                "Steady Your Breathing Rate",
                "A higher than usual breathing rate can follow stress or feeling unwell. Try slow belly breathing: 4 seconds in, 6 seconds out, for 5 minutes daily.",
                "Aim for steady readings in your usual range"
            )

            // Metabolic
            static let optimizeBodyComp: Recommendation = (
                "Optimize Body Composition",
                "Focus on sustainable changes: reduce processed foods, increase protein and vegetables, combine cardio with resistance training.",
                "Target: BMI 18.5\u{2013}25"
            )
            static let reduceBodyFat: Recommendation = (
                "Reduce Body Fat",
                "Combine resistance training 3x/week with 150+ min cardio/week. Prioritize protein (0.8g/lb bodyweight) and sleep for fat loss.",
                "Target: 10\u{2013}20% (men) / 18\u{2013}28% (women)"
            )
            static let reduceWaist: Recommendation = (
                "Reduce Waist Circumference",
                "Abdominal fat is a key metabolic risk indicator. Daily walks, core exercises, and reduced sugar intake have the biggest impact.",
                "Target: <94 cm (men) / <80 cm (women)"
            )
            static let increaseMovement: Recommendation = (
                "Increase Daily Movement",
                "Low step count is strongly linked to metabolic risk. Start with 2,000 more steps than current average. Take walking meetings and post-meal walks.",
                "Target: 8,000\u{2013}10,000 steps/day"
            )

            // Stress
            static let reduceChronicStress: Recommendation = (
                "Reduce Chronic Stress",
                "HRV is the most reliable stress biomarker. Try 10 minutes of meditation daily, box breathing before bed, and time in nature.",
                "Target: HRV trending upward week over week"
            )
            static let prioritizeRecoverySleep: Recommendation = (
                "Prioritize Recovery Sleep",
                "Sleep is the #1 stress recovery tool. Set a non-negotiable bedtime. Remove work apps from your phone after 9 PM.",
                "Target: 7\u{2013}8 hours consistently"
            )
            static let buildMindfulness: Recommendation = (
                "Build Mindfulness Practice",
                "Even 5 minutes of daily mindfulness reduces cortisol levels. Use a guided app to start. Morning sessions have the most impact.",
                "Target: 10\u{2013}20 min daily"
            )
            static let manageSympathetic: Recommendation = (
                "Manage Sympathetic Activation",
                "Elevated EDA reflects sympathetic nervous system arousal. Practice progressive muscle relaxation and reduce stimulant intake.",
                "Target: Return to personal baseline"
            )

            // Mobility
            static let maintainWalkingSpeed: Recommendation = (
                "Maintain Walking Speed",
                "Walking speed is a key vitality indicator. Include brisk walking intervals (2 min fast, 2 min normal) in daily walks.",
                "Target: >1.0 m/s (3.6 km/h)"
            )
            static let correctGaitAsymmetry: Recommendation = (
                "Correct Gait Asymmetry",
                "Asymmetry above 10% may indicate muscle imbalance or joint issues. Single-leg exercises and stretching can help. See a PT if persistent.",
                "Target: <10% asymmetry"
            )
            static let buildFunctionalEndurance: Recommendation = (
                "Build Functional Endurance",
                "The 6-minute walk distance reflects overall functional capacity. Daily walks of increasing duration will improve this steadily.",
                "Target: >500 meters"
            )
            static let improveBalance: Recommendation = (
                "Improve Balance",
                "High double support time indicates balance challenges. Practice single-leg stands, heel-to-toe walking, and tai chi or yoga.",
                "Target: 20\u{2013}30%"
            )

            // Default
            static func improveMetric(_ metricName: String) -> String {
                "Improve \(metricName)"
            }
            static func bringIntoOptimalRange(_ metricLower: String) -> String {
                "Focus on bringing \(metricLower) into the optimal range through consistent healthy habits."
            }
            static func targetRange(_ range: String) -> String {
                "Target: \(range)"
            }
        }

        // MARK: - Health Risk Engine Explanations

        enum HealthRiskEngine {
            static let noRecentDataExplanation = "No recent data available. Keep Apple Health syncing to track this metric."

            static func withinHealthyRange(metricName: String, formatted: String, unit: String) -> String {
                "\(metricName) is \(formatted) \(unit), within the healthy range."
            }
            static func metricValuePrefix(metricName: String, formatted: String, unit: String) -> String {
                "\(metricName) is \(formatted) \(unit)"
            }
            static let belowOptimalRange = "below the optimal range"
            static let aboveOptimalRange = "above the optimal range"

            static let directionDecreasing = "decreasing"
            static let directionRising = "rising"
            static let directionIncreasing = "increasing"

            static func andDirection(_ direction: String) -> String {
                "and \(direction)"
            }
            static func whileTrending(_ direction: String) -> String {
                "while trending \(direction)"
            }
        }

        // MARK: - Health Risk Detail

        enum RiskDetail {
            static let whatToFocusOn = "What to Focus On"
            static let contributingFactors = "Contributing Factors"
            static func optimalRange(_ range: String) -> String {
                "Best: \(range)"
            }
            static func metricsMeasured(measured: Int, total: Int) -> String {
                "\(measured) of \(total) metrics measured"
            }
            static let disclaimer = "These scores are based on patterns in your health data and published wellness ranges. They are not medical advice and should not replace guidance from a qualified professional."
        }

        // MARK: - Correlation

        enum Correlation {
            static let strong = "Strong"
            static let moderate = "Moderate"
            static let mild = "Mild"
        }

        // MARK: - Nutrition Correlation

        enum NutritionCorrelation {
            static func affects(nutrition: String, outcome: String) -> String {
                "\(nutrition) Affects \(outcome)"
            }
            static func monitorToOptimize(nutrition: String, outcome: String) -> String {
                "Watch your \(nutrition) intake to improve \(outcome)."
            }
        }

        // MARK: - Cross-Metric Anomaly

        enum CrossMetricAnomaly {
            static func unusualPattern(metricA: String, metricB: String) -> String {
                "\(metricA) & \(metricB) Unusual Pattern"
            }
            static let unusualMultiMetricPattern = "Unusual Pattern Across Multiple Numbers"
            static let rareMetricCombination = "Unusual Combination"
            static let unusualCombinationDetected = "An unusual mix of health numbers was found."
        }

        // MARK: - Causal Chain

        enum CausalChain {
            static func singleCauseTitle(cause: String, affected: String) -> String {
                "\(cause) May Be Affecting Your \(affected)"
            }
            static func chainTitle(affected: String, rootCause: String) -> String {
                "Why Your \(affected) Changed: \(rootCause) Connection"
            }
        }

        // MARK: - Research Analyzers

        enum Research {

            // MARK: HRR Fitness

            enum HRRFitness {
                static let belowClinicalTitle = "Heart Rate Recovery Below Clinical Threshold"
                static let excellentTitle = "Excellent Heart Rate Recovery"
                static let decliningTitle = "Heart Recovery Declining"
                static func improvingTitle(months: Int) -> String {
                    "Heart Recovery Improving Over \(months) Months"
                }

                static func belowClinicalSummary(currentHRR: String, threshold: Int) -> String {
                    "Your heart rate recovery is \(currentHRR) bpm. below the clinical threshold of \(threshold) bpm. This indicates reduced parasympathetic reactivation after exercise."
                }
                static func belowClinicalRecommendation(threshold: Int, currentHRR: String, sampleCount: Int) -> String {
                    "A heart rate recovery <\(threshold) bpm at 1 minute post-exercise is associated with reduced overall fitness in large population studies. Your average HRR of \(currentHRR) bpm across \(sampleCount) measurements suggests blunted autonomic recovery."
                }

                static func excellentSummary(currentHRR: String, goodThreshold: Int) -> String {
                    "Your heart rate drops \(currentHRR) bpm after exercise. well above the \(goodThreshold) bpm threshold for good autonomic function. This indicates strong parasympathetic tone."
                }
                static func excellentRecommendation(currentHRR: String) -> String {
                    "An HRR of \(currentHRR) bpm places you in the excellent range. Research shows this level of post-exercise recovery is associated with better heart fitness and superior autonomic nervous system health."
                }

                static func improvingSummary(change: String, months: Int) -> String {
                    "Your heart rate recovery has improved by \(change) bpm over the past \(months) months. Research shows HRR improves dose-dependently with regular exercise training."
                }
                static func improvingRecommendation(change: String, months: Int) -> String {
                    "A \(change) bpm improvement in HRR over \(months) months reflects measurable gains in autonomic fitness. Studies show as few as 6 months of consistent exercise produces this kind of parasympathetic adaptation."
                }

                static func decliningSummary(change: String, months: Int) -> String {
                    "Your heart rate recovery has worsened by \(change) bpm over \(months) months. A declining HRR trajectory suggests reduced autonomic fitness."
                }
                static func decliningRecommendation(start: String, current: String, months: Int) -> String {
                    "HRR dropped from \(start) to \(current) bpm over \(months) months. This may reflect detraining, increased stress, or an underlying condition. Regular aerobic exercise is the strongest intervention for improving HRR."
                }
            }

            // MARK: Sleep Regularity

            enum SleepRegularity {
                static let irregularTitle = "Irregular Sleep Pattern Detected"
                static let needsAttentionTitle = "Sleep Regularity Needs Attention"
                static let excellentTitle = "Excellent Sleep Regularity"
                static func socialJetLagTitle(minutes: String) -> String {
                    "Social Jet Lag: \(minutes) Minutes"
                }

                static func irregularSummary(sri: String) -> String {
                    "Your Sleep Regularity Index is \(sri)/100. placing you in the irregular category. Research shows this is a stronger predictor of long-term wellness than sleep duration alone."
                }
                static func irregularRecommendation(sri: String, samples: Int, socialJetLag: Double, jetLagMinutes: String) -> String {
                    let jetLagSuffix = socialJetLag > 60 ? " Social jet lag of \(jetLagMinutes) min is also elevated." : ""
                    return "Across 5 large cohorts, irregular sleepers (SRI <60) may experience reduced cognitive performance and overall wellness over time, independent of how many hours they sleep. Your SRI of \(sri) over \(samples) measured nights suggests significant night-to-night variability.\(jetLagSuffix)"
                }

                static func needsAttentionSummary(sri: String) -> String {
                    "Your Sleep Regularity Index is \(sri)/100. moderate but room for improvement. Consistent sleep timing matters more than duration for long-term health."
                }
                static func needsAttentionRecommendation(sri: String, samples: Int, socialJetLag: Double, jetLagMinutes: String) -> String {
                    let jetLagSuffix = socialJetLag > 45 ? " Reducing your \(jetLagMinutes)-min social jet lag would help most." : ""
                    return "Your SRI of \(sri) across \(samples) nights falls in the moderate range. Research links each 10-point SRI improvement to measurable gains in heart and metabolic wellness.\(jetLagSuffix)"
                }

                static func excellentSummary(sri: String) -> String {
                    "Your Sleep Regularity Index is \(sri)/100. your sleep timing and duration are highly consistent. This is independently supportive of long-term wellness."
                }
                static func excellentRecommendation(sri: String, samples: Int) -> String {
                    "An SRI of \(sri) across \(samples) nights places you in the most regular category. Research shows this level of sleep consistency is associated with better cognitive performance and substantially better overall wellness over time."
                }

                static func socialJetLagSummary(minutes: String) -> String {
                    "Your weekend sleep timing shifts by \(minutes) minutes compared to weekdays. equivalent to crossing a time zone every week. This is linked to reduced metabolic wellness independent of sleep duration."
                }
                static func socialJetLagRecommendation(minutes: String) -> String {
                    "Social jet lag >60 min is associated with reduced metabolic wellness and increased body stress in adults with otherwise normal sleep duration. Your \(minutes)-min shift suggests significant circadian misalignment on weekends."
                }
            }

            // MARK: Inflammation Risk

            enum InflammationRisk {
                static let bodyStressSignalTitle = "Body Stress Signal"
                static let elevatedBodyStressTitle = "Elevated Body Stress"
                static let strongRecoveryToneTitle = "Strong Recovery Tone"

                static func bodyStressSummary(dropPercent: String) -> String {
                    "Your HRV has dropped \(dropPercent)% below baseline while wrist temperature is elevated. a compound pattern suggesting your body may be under increased stress."
                }
                static func bodyStressRecommendation(currentHRV: String, baseline: String) -> String {
                    "The combination of suppressed HRV (autonomic stress) and elevated body temperature is a well-validated early signal that your body is working harder than usual to recover. In research studies, this pattern often appears 1 to 3 days before you feel off. Current HRV: \(currentHRV) ms vs baseline \(baseline) ms."
                }

                static func elevatedBodyStressSummary(consecutiveDeclines: Int, dropPercent: String) -> String {
                    "Your HRV has been declining for \(consecutiveDeclines) consecutive measurement windows. currently \(dropPercent)% below your personal baseline. This sustained drop pattern suggests your body may be under increased stress."
                }
                static func elevatedBodyStressRecommendation(currentHRV: String, baseline: String, days: Int) -> String {
                    "Research shows sustained HRV suppression (without increased exercise load) reflects reduced recovery capacity. In wearable studies, this pattern often appeared days before people felt run down. HRV: \(currentHRV) ms vs baseline \(baseline) ms over \(days) days."
                }

                static func strongRecoverySummary(abovePercent: String) -> String {
                    "Your HRV is \(abovePercent)% above baseline. indicating strong vagal tone. Research links elevated parasympathetic activity to better overall recovery and resilience."
                }
                static func strongRecoveryRecommendation(currentHRV: String, baseline: String) -> String {
                    "An HRV of \(currentHRV) ms (vs baseline \(baseline) ms) reflects robust parasympathetic dominance. When vagal tone is high, your body is in a strong recovery state."
                }
            }

            // MARK: Mobility Decline

            enum MobilityDecline {
                static let walkingSpeedLabel = "walking speed"
                static let stepLengthLabel = "step length"
                static let doubleSupportLabel = "double support time"
                static let asymmetryLabel = "gait asymmetry"
                static let stairAscentLabel = "stair climbing speed"
                static let stairDescentLabel = "stair descent speed"
                static let steadinessLabel = "walking steadiness"

                static let multiMetricDeclineTitle = "Multi-Metric Mobility Decline"
                static let walkingSpeedDecliningTitle = "Walking Speed Declining"
                static let asymmetryIncreasingTitle = "Gait Asymmetry Increasing"
                static let mobilityStableTitle = "Mobility Profile Stable"

                static func multiMetricSummary(declining: Int, total: Int, metricList: String) -> String {
                    "\(declining) of \(total) mobility metrics are declining over the past 6 months: \(metricList). Concurrent deterioration across multiple gait parameters warrants attention."
                }
                static let multiMetricRecommendation = "Research shows simultaneous decline in walking speed, step length, and gait symmetry can be an early indicator of shifts in overall wellness. Changes in mobility patterns are often detectable well before they become noticeable in daily life."

                static func walkingSpeedSummary(percent: String) -> String {
                    "Your walking speed has decreased \(percent)% over the past 6 months. Walking speed is called the 'sixth vital sign'. it's one of the strongest predictors of functional health and longevity."
                }
                static func walkingSpeedRecommendation(percent: String, samples: Int) -> String {
                    "In population studies, each 0.1 m/s decrease in walking speed is associated with reduced overall wellness. Your \(percent)% decline across \(samples) measurements is worth monitoring."
                }

                static func asymmetrySummary(percent: String) -> String {
                    "Your walking asymmetry has increased \(percent)% over 6 months. Growing left-right imbalance in gait is an early indicator of changes in movement quality."
                }
                static func asymmetryRecommendation(percent: String) -> String {
                    "Increasing gait asymmetry. the difference between left and right step patterns. can reflect changes in balance, joint comfort, or overall movement quality. A \(percent)% increase warrants attention."
                }

                static func mobilityStableSummary(total: Int, improvingList: String) -> String {
                    "All \(total) tracked mobility metrics are stable or improving over the past 6 months. This indicates strong functional movement quality.\(improvingList)"
                }
                static func mobilityStableImprovingFragment(items: String) -> String {
                    " Improving: \(items)."
                }
                static func mobilityStableRecommendation(total: Int) -> String {
                    "Stable or improving gait metrics across \(total) parameters (walking speed, step length, symmetry, steadiness) reflect strong functional health. Research shows these are among the best predictors of healthspan and longevity."
                }
            }

            // MARK: Biological Age

            enum BiologicalAge {
                static let cardioFitnessComponent = "Cardio Fitness"
                static let restingHeartRateComponent = "Resting Heart Rate"
                static let activityRhythmComponent = "Activity Rhythm"
                static let mobilityComponent = "Mobility"
                static let autonomicComponent = "Autonomic Nervous System"

                static func fitnessAgeTitle(years: String) -> String {
                    "Fitness Age Estimate: ~\(years)"
                }
                static let imbalanceTitle = "Age Component Imbalance"

                static func componentBreakdownEntry(component: String, years: String) -> String {
                    "\(component): ~\(years) yrs"
                }

                static func fitnessAgeSummary(componentCount: Int, years: String, strongest: String, oldest: String) -> String {
                    "Based on \(componentCount) physiological markers, your body performs like someone around \(years) years old. Strongest area: \(strongest). Area with most room: \(oldest)."
                }
                static func fitnessAgeRecommendation(breakdown: String) -> String {
                    "Breakdown. \(breakdown). Each component is mapped to population norms from large-scale studies. VO2max alone (one of the most meaningful indicators of your overall fitness) suggests a fitness age equivalent."
                }

                static func imbalanceSummary(spread: String, youngestComponent: String, youngestAge: String, oldestComponent: String, oldestAge: String) -> String {
                    "There's a \(spread)-year gap between your youngest system (\(youngestComponent): ~\(youngestAge)) and oldest (\(oldestComponent): ~\(oldestAge)). This imbalance is worth addressing."
                }
                static func imbalanceRecommendation(oldestComponent: String) -> String {
                    "A large spread between fitness age components suggests one system is aging faster than others. Focusing on your \(oldestComponent) could bring your overall fitness age down significantly."
                }
            }

            // MARK: Wellbeing Trend

            enum WellbeingTrend {
                static let sleepRegularitySignal = "Sleep Regularity"
                static let activityLevelSignal = "Activity Level"
                static let daylightSignal = "Daylight"
                static let mindfulnessSignal = "Mindfulness"
                static let autonomicToneSignal = "Autonomic Tone"

                static let sleepVeryRegular = "sleep is very regular"
                static let sleepModeratelyRegular = "sleep regularity is moderate"
                static let sleepVariesSignificantly = "sleep timing varies significantly"
                static let sleepHighlyIrregular = "sleep is highly irregular"

                static let activityIncreased = "activity increased this week"
                static let activityStable = "activity level is stable"
                static func activityDropped(percent: String) -> String {
                    "activity dropped \(percent)% this week"
                }

                static func goodDaylight(minutes: String) -> String {
                    "good daylight exposure (\(minutes) min/day)"
                }
                static let moderateDaylight = "moderate daylight exposure"
                static func lowDaylight(minutes: String) -> String {
                    "low daylight exposure (\(minutes) min/day)"
                }
                static let veryLowDaylight = "very low daylight exposure"

                static let mindfulnessConsistent = "consistent mindfulness practice"
                static let mindfulnessSome = "some mindfulness activity"
                static let mindfulnessMinimal = "minimal mindfulness engagement"

                static let autonomicStrong = "autonomic tone is strong"
                static let autonomicNormal = "autonomic tone is normal"
                static let autonomicBelowBaseline = "HRV below baseline (autonomic stress)"
                static let autonomicSuppressed = "HRV significantly suppressed"

                static let patternShiftTitle = "Wellbeing Pattern Shift Detected"
                static let mildPatternChangeTitle = "Mild Wellbeing Pattern Change"
                static let strongIndicatorsTitle = "Strong Wellbeing Indicators"

                static func patternShiftSummary(concerningCount: Int, total: Int, concerns: String) -> String {
                    "\(concerningCount) of \(total) behavioral indicators are trending in directions associated with mood decline: \(concerns)."
                }
                static func patternShiftRecommendation(score: String) -> String {
                    "Research on digital phenotyping shows that simultaneous changes in sleep regularity, physical activity, daylight exposure, and autonomic tone predict mood shifts with high accuracy. These patterns are observational. not diagnostic. but are worth noting. Score: \(score)/100."
                }

                static func mildSummary(concerns: String) -> String {
                    "Two behavioral indicators are shifting: \(concerns). Not yet a strong signal, but worth monitoring."
                }
                static let mildRecommendation = "Research shows that isolated changes in one or two behavioral markers are common and often transient. If these patterns persist for another week alongside further deterioration, they become more meaningful."

                static func strongSummary(total: Int, includeMindfulness: Bool) -> String {
                    let mindfulText = includeMindfulness ? ", mindfulness" : ""
                    return "Your behavioral pattern across \(total) indicators. sleep regularity, activity, daylight exposure\(mindfulText). is consistent with positive mental wellbeing."
                }
                static let strongRecommendation = "Research on digital phenotyping shows that consistent sleep, regular activity, adequate daylight exposure, and strong autonomic tone are collectively protective for mental health. Your current patterns reflect all of these."
            }

            // MARK: Circadian Disruption

            enum CircadianDisruption {
                static let amplitudeComponent = "activity amplitude"
                static let regularityComponent = "rhythm regularity"
                static let restActivityComponent = "rest-activity contrast"
                static let sleepTimingComponent = "sleep timing"

                static let disruptedTitle = "Circadian Rhythm Disrupted"
                static let needsImprovementTitle = "Circadian Rhythm: Room for Improvement"
                static let strongRhythmTitle = "Strong Circadian Rhythm"

                static func disruptedSummary(score: String, weakest: String, weakestScore: String) -> String {
                    "Your circadian health score is \(score)/100. indicating significant disruption in your daily biological rhythm. Weakest area: \(weakest) (\(weakestScore)/100)."
                }
                static let disruptedRecommendation = "Research shows circadian disruption is linked to reduced metabolic health, heart wellness, mood, and long-term wellness. Your activity patterns lack the strong daily rhythm (high daytime activity, low nighttime activity) associated with healthy circadian function. Circadian rhythm amplitude measured from wearables strongly correlates with overall fitness age."

                static func needsImprovementSummary(score: String, weakest: String) -> String {
                    "Your circadian health score is \(score)/100. Your daily rhythm is present but could be stronger. Focus area: \(weakest)."
                }
                static func needsImprovementRecommendation(score: String, weakest: String, weakestScore: String) -> String {
                    "A circadian score of \(score) suggests your body's 24-hour rhythm is moderately aligned. Strengthening your \(weakest) (currently \(weakestScore)/100) would have the most impact. Regular light exposure in the morning and consistent sleep timing are the most effective interventions."
                }

                static func strongRhythmSummary(score: String, strongest: String) -> String {
                    "Your circadian health score is \(score)/100. Your daily biological rhythm shows strong amplitude, good regularity, and clear rest-activity contrast. Strongest area: \(strongest)."
                }
                static func strongRhythmRecommendation(score: String) -> String {
                    "A circadian score of \(score) reflects a well-entrained biological clock. Research shows strong circadian rhythmicity is independently supportive of metabolic health, cognitive performance, and long-term wellness. correlating with a younger fitness age."
                }
            }

            // MARK: Sleep Coherence

            enum SleepCoherence {
                static let outOfSyncTitle = "Sleep Systems Out of Sync"
                static let strongCoherenceTitle = "Strong Sleep Coherence"
                static let decliningCoherenceTitle = "Sleep Coherence Declining"

                static func outOfSyncSummary(incoherent: Int, total: Int, score: String) -> String {
                    "Your body's systems aren't fully aligning during sleep. On \(incoherent) of \(total) recent nights, your heart rate and HRV didn't follow expected sleep-stage patterns. coherence score: \(score)/100."
                }
                static func outOfSyncRecommendation(score: String, severityLabel: String, total: Int) -> String {
                    "Research shows that physiological incoherence during sleep. when your heart stays 'awake' while your brain sleeps. is associated with reduced overall wellness. Your coherence score of \(score) suggests \(severityLabel) desynchronization across \(total) measured nights."
                }

                static func strongCoherenceSummary(score: String, total: Int) -> String {
                    "Your body's systems sync well during sleep. heart rate drops appropriately, HRV rises, and sleep architecture looks healthy. Coherence score: \(score)/100 across \(total) nights."
                }
                static func strongCoherenceRecommendation(score: String) -> String {
                    "A coherence score of \(score) means your heart and nervous system are well-aligned during sleep. Research links high sleep coherence to better overall wellness across many dimensions of health."
                }

                static func decliningSummary(prior: String, recent: String) -> String {
                    "Your sleep coherence dropped from \(prior) to \(recent) over the past two weeks. Your heart and nervous system are less synchronized during sleep than before."
                }
                static func decliningRecommendation(drop: String) -> String {
                    "A \(drop)-point drop in sleep coherence over 2 weeks may reflect increased stress, an irregular schedule, or your body working harder to recover. This pattern often appears before you start feeling off."
                }

                static let severitySignificant = "significant"
                static let severityModerate = "moderate"
            }

            // MARK: Temperature Compound

            enum TemperatureCompound {
                static func bodyTempElevatedTitle(nights: Int) -> String {
                    "Body Temperature Elevated \(nights) Nights"
                }
                static let nighttimeAboveBaselineTitle = "Nighttime Temperature Above Baseline"
                static let cyclePatternTitle = "Temperature Cycle Pattern Detected"
                static let highVariabilityTitle = "High Temperature Variability"

                static func compoundSummary(deviation: String, nights: Int) -> String {
                    "Your sleeping wrist temperature is \(deviation)°C above your 30-day baseline for \(nights) consecutive nights. Combined with suppressed HRV, this compound pattern is associated with early immune response."
                }
                static func compoundRecommendation(deviation: String, baseline: String) -> String {
                    "Sustained nighttime temperature elevation (\(deviation)°C vs baseline \(baseline)°C) alongside low HRV reflects the autonomic and thermoregulatory signatures of immune activation. This compound signal typically precedes symptom onset by 1-3 days."
                }

                static func tempOnlySummary(deviation: String, nights: Int) -> String {
                    "Your sleeping wrist temperature has been \(deviation)°C above your personal baseline for \(nights) nights. Sustained elevation can reflect metabolic shifts, stress, or early subclinical changes."
                }
                static func tempOnlyRecommendation(recent: String, baseline: String, sd: String) -> String {
                    "Your nighttime temperature: \(recent)°C vs 30-day baseline of \(baseline)°C (\u{00B1}\(sd)). Research shows wrist temperature deviations >0.3°C sustained over multiple nights may indicate metabolic changes, hormonal shifts, or early immune responses."
                }

                static func cyclePatternSummary(amplitude: String) -> String {
                    "Your wrist temperature shows a recurring cyclical pattern with \(amplitude)°C amplitude. consistent with hormonal cycle influence. Research shows wrist temperature tracks ovulation with 82-93% accuracy."
                }
                static func cyclePatternRecommendation(amplitude: String, baseline: String) -> String {
                    "The cyclical temperature variation of \(amplitude)°C around your baseline of \(baseline)°C reflects the biphasic pattern driven by progesterone. Post-ovulation temperatures typically rise 0.2-0.5°C above the follicular phase baseline."
                }

                static func highVariabilitySummary(sd: String) -> String {
                    "Your nighttime wrist temperature varies significantly night to night (\u{00B1}\(sd)°C). High thermoregulatory variability is associated with disrupted circadian rhythm and metabolic health."
                }
                static func highVariabilityRecommendation(cvPercent: String) -> String {
                    "Temperature coefficient of variation: \(cvPercent)%. Research links elevated nighttime temperature variability to circadian disruption, poor sleep quality, and reduced metabolic wellness. Stable temperatures reflect stronger circadian entrainment."
                }
            }

            // MARK: Cardio Respiratory Age

            enum CardioRespiratoryAge {
                static func cardioFitnessAgeTitle(age: String) -> String {
                    "Cardio Fitness Age: ~\(age)"
                }
                static func vo2ImprovingTitle(change: String, months: Int) -> String {
                    "VO2max Improving: +\(change) Over \(months) Months"
                }
                static func vo2DecliningTitle(change: String, months: Int) -> String {
                    "VO2max Declining: \(change) Over \(months) Months"
                }
                static let belowThresholdTitle = "VO2max Below Typical Threshold"

                static func cardioFitnessAgeSummary(vo2: String, age: String) -> String {
                    "Your VO2max of \(vo2) mL/kg/min is average for someone around age \(age). VO2max is one of the most important indicators of long-term fitness and overall wellness."
                }
                static func cardioFitnessAgeRecommendation(vo2: String, percentile: String) -> String {
                    "At \(vo2) mL/kg/min, your cardiorespiratory fitness places you approximately at the \(percentile)th percentile for a middle-aged adult. Each 1 MET (~3.5 mL/kg/min) improvement is associated with meaningful health benefits."
                }

                static func vo2ImprovingSummary(change: String, months: Int) -> String {
                    "Your cardiorespiratory fitness has improved by \(change) mL/kg/min over \(months) months. This is a meaningful fitness gain based on population wellness studies."
                }
                static func vo2ImprovingRecommendation(change: String, months: Int) -> String {
                    "A \(change) mL/kg/min VO2max improvement represents real progress. This shifts your fitness age younger and is associated with better long-term wellness outcomes."
                }

                static func vo2DecliningSummary(absChange: String, months: Int) -> String {
                    "Your cardiorespiratory fitness has dropped by \(absChange) mL/kg/min over \(months) months. Since VO2max is a key fitness indicator, this trend is worth reversing."
                }
                static func vo2DecliningRecommendation(absChange: String, perMonth: String, months: Int) -> String {
                    "A \(absChange) mL/kg/min decline shifts your fitness age older. The decline rate of \(perMonth) mL/kg/min per month is faster than typical aging (~1 to 2 mL/kg/min per decade). Increasing aerobic exercise frequency or intensity can help reverse this."
                }

                static func belowThresholdSummary(vo2: String, threshold: Int) -> String {
                    "Your VO2max of \(vo2) mL/kg/min is below \(threshold). a threshold associated with reduced fitness capacity across all age groups."
                }
                static func belowThresholdRecommendation(threshold: Int) -> String {
                    "A VO2max below \(threshold) mL/kg/min places you in the lowest fitness category regardless of age. Population studies consistently show this threshold as an important point for overall wellness. Even modest improvements from this baseline can make a meaningful difference."
                }
            }

            // MARK: RHR Trajectory

            enum RHRTrajectory {
                static let risingTitle = "Resting Heart Rate Rising"
                static let improvingTitle = "Heart Rate Trajectory Improving"

                static func risingSummary(change: String, windowLabel: String, startRHR: String, currentRHR: String) -> String {
                    "Your resting heart rate has increased by \(change) bpm over the past \(windowLabel). from \(startRHR) to \(currentRHR) bpm. without a decline in your activity levels."
                }
                static func risingRecommendation(change: String, windowLabel: String, includeMedicalNote: Bool) -> String {
                    let suffix = includeMedicalNote ? " Consider discussing this trend with your doctor." : ""
                    return "Population studies show a rising resting heart rate is an important long-term fitness indicator. A \(change) bpm rise over \(windowLabel) while maintaining activity is worth paying attention to.\(suffix)"
                }

                static func improvingSummary(change: String, windowLabel: String, startRHR: String, currentRHR: String) -> String {
                    "Your resting heart rate has dropped \(change) bpm over the past \(windowLabel). from \(startRHR) to \(currentRHR) bpm. This is a positive trend for your heart fitness."
                }
                static let improvingRecommendation = "A declining RHR trajectory reflects improved cardiovascular efficiency. A lower resting heart rate over time is associated with better overall fitness and wellness in population studies."
            }
        }

        // MARK: - Historical

        enum Historical {
            static func yearOverYear(metric: String, change: String, comparison: String, month: String) -> String {
                "\(metric) \(change)% \(comparison) Than Last \(month)"
            }
            static func nearAllTime(metric: String, extreme: String) -> String {
                "\(metric) Near All-Time \(extreme)"
            }
            static func seasonalComparison(metric: String, comparison: String, month: String) -> String {
                "\(metric) \(comparison) \(month) Average"
            }
            static func longTermTrajectory(metric: String, direction: String, change: String, period: String) -> String {
                "\(metric) \(direction) \(change)% Over \(period)"
            }
            static func rarityTitle(metric: String, months: Int, extreme: String) -> String {
                "\(metric) at \(months)-Month \(extreme)"
            }

            // Recommendations
            static let betterShapeLongTerm = "You are in better shape this year. Things are heading in the right direction."
            static let exceptionalPersonalBest = "This is your best ever. Whatever you are doing, keep it up."
            static let rareLevelMayWarrantAttention = "This is rare for you. If it stays this way for more than a few days, it is worth a closer look."
            static let outperformingSeasonalNorm = "You are doing better than usual for this time of year. That is solid progress."
            static let longTermImprovementReliable = "Your long-term trend is positive. A few bad days do not erase months of good progress."
            static let sustainedDeclineStructural = "This has been going down for a while. If it continues, it is worth a closer look."
            static let unusualValuesMonitor = "One bad day does not mean much. If this lasts a few days, take a closer look."
        }
    }
}
