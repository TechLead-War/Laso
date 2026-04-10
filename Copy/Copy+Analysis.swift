import Foundation

extension Copy {
    enum Analysis {

        // MARK: - Clinical Intelligence

        enum Clinical {
            static let bloodPressureTrendingUp = "Blood Pressure Trending Up"
            static let elevatedPulsePressure = "Pulse Pressure is High"
            static let bloodGlucoseTrendingUp = "Blood Glucose Trending Up"
            static let abnormalRespiratoryRate = "Unusual Breathing Rate"
            static let medicalDisclaimer = "This is for informational purposes only and is not medical advice. This is for informational purposes only."

            // BP recommendations
            static let bpRecommendation = "Try eating less salt, moving more, and keeping stress in check."
            static let pulsePressureRecommendation = "A wider gap between your blood pressure numbers can sometimes indicate your cardiovascular system is working harder than usual."
            static let glucoseRecommendation = "Cut back on sugar and white bread. Eat more fiber. Stay active."
            static let respiratoryRecommendation = "If your breathing rate stays unusual for a few days, consider checking in on this."

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
                "Your pulse pressure (\(pulsePressure) mmHg) is above the typical range of 40-60 mmHg, which is sometimes associated with arterial stiffness."
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
            static let scaleIntensityNote = " Your body is reacting more than usual right now. Take it easier for the next 2 days and see how you feel."
            static let keepLoggingNote = " Keep logging every day so we can better learn what is normal for you."
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
        }

        // MARK: - Illness Early Warning

        enum IllnessWarning {
            static let significantStrain = "Your Body is Under Stress"
            static let multipleMetricStrain = "Several Numbers Show Your Body is Stressed"
            static let earlyPhysiologicalStrain = "Early Signs Your Body is Stressed"
            static let multiMetricPattern = "Several health numbers shifted at the same time. Your body may be under extra stress."
            static let multipleMetricsShifted = "Several numbers moved away from your usual at the same time."
            static let consistentWithPhysiologicalStrain = "The pattern across your numbers suggests your body is under extra stress."
            static let cardiacMetricsStrain = "Your heart numbers show your body is stressed."
            static let activityNotReturned = "Your activity numbers have not gone back to normal yet."
        }

        // MARK: - Health Risk Detail

        enum RiskDetail {
            static let whatToFocusOn = "What to Focus On"
            static let contributingFactors = "Contributing Factors"
            static func optimalRange(_ range: String) -> String {
                "Optimal: \(range)"
            }
            static func metricsMeasured(measured: Int, total: Int) -> String {
                "\(measured) of \(total) metrics measured"
            }
            static let disclaimer = "These scores are based on patterns in your health data and published wellness ranges. They are not medical diagnoses and should not replace professional medical advice. These scores are for informational purposes only and should not replace professional guidance."
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
                "Monitor your \(nutrition) intake to optimize \(outcome)."
            }
        }

        // MARK: - Cross-Metric Anomaly

        enum CrossMetricAnomaly {
            static func unusualPattern(metricA: String, metricB: String) -> String {
                "\(metricA) & \(metricB) Unusual Pattern"
            }
            static let unusualMultiMetricPattern = "Unusual Pattern Across Multiple Numbers"
            static let rareMetricCombination = "Unusual Combination"
            static let unusualCombinationDetected = "An unusual combination of health numbers was found."
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
            static let rareLevelMayWarrantAttention = "This is rare for you. If it stays like this for more than a few days, it is worth looking into."
            static let outperformingSeasonalNorm = "You are doing better than usual for this time of year. That is real progress."
            static let longTermImprovementReliable = "Your long term trend is positive. A few bad days do not erase months of good progress."
            static let sustainedDeclineStructural = "This has been going down for a while. If it keeps up, it is worth paying closer attention to."
            static let unusualValuesMonitor = "One bad day does not mean much. If this lasts a few days, pay closer attention."
        }
    }
}
