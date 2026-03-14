import Foundation

extension Copy {
    enum Analysis {

        // MARK: - Clinical Intelligence

        enum Clinical {
            static let bloodPressureTrendingUp = "Blood Pressure Trending Up"
            static let elevatedPulsePressure = "Elevated Pulse Pressure"
            static let bloodGlucoseTrendingUp = "Blood Glucose Trending Up"
            static let abnormalRespiratoryRate = "Abnormal Respiratory Rate"
            static let medicalDisclaimer = "This is informational only \u{2014} consult your healthcare provider for clinical decisions."

            // BP recommendations
            static let bpRecommendation = "Consider reducing sodium intake, increasing aerobic exercise, and monitoring stress levels."
            static let pulsePressureRecommendation = "Wide pulse pressure can be an independent cardiovascular risk factor."
            static let glucoseRecommendation = "Focus on reducing refined carbohydrates, increasing fiber intake, and maintaining regular physical activity."
            static let respiratoryRecommendation = "If your respiratory rate stays outside normal range, consider speaking with a healthcare provider."

            // Projection templates
            static func projectedToReach(label: String, days: Int) -> String {
                "At this rate, you could reach \(label) territory in ~\(days) days."
            }
            static func projectedToReachRange(label: String, days: Int) -> String {
                "Projected to reach \(label) range in ~\(days) days."
            }

            // BP summary templates
            static func bpTrendingSummary(slopePerMonth: String, dayCount: Int, stage: String, nextStageInfo: String) -> String {
                "Your systolic BP has been rising \(slopePerMonth) mmHg/month over the past \(dayCount) days. Current stage: \(stage). \(nextStageInfo)"
            }
            static func pulsePressureSummary(pulsePressure: Int) -> String {
                "Your pulse pressure (\(pulsePressure) mmHg) is above the normal range of 40-60 mmHg, which may indicate arterial stiffness."
            }
            static func glucoseTrendingSummary(slopePerMonth: String, latest: String, stage: String, nextInfo: String) -> String {
                "Your fasting glucose has been rising \(slopePerMonth) mg/dL per month. Current: \(latest) mg/dL (\(stage)). \(nextInfo)"
            }
            static func respiratorySummary(rate: String, stage: String) -> String {
                "Your respiratory rate (\(rate) br/min) is classified as \(stage). Normal range is 12-20 breaths per minute."
            }
        }

        // MARK: - Recovery Analyzer

        enum Recovery {
            static let postWorkoutHRVRecovery = "Post-Workout HRV Recovery"
            static let restDayDeficit = "Rest Day Deficit"
            static let overtrainingWarning = "Overtraining Warning"
            static let earlyOvertrainingSignal = "Early Overtraining Signal"
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
            static let scaleIntensityNote = " Your current shift is stronger than your norm, so scale intensity for 48 hours and monitor how you feel."
            static let keepLoggingNote = " Keep logging daily so the phase model can keep adapting to your own baseline."
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
                "You've hit \(label.lowercased()) for \(days) consecutive days."
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
            static let improvementAccelerating = "Improvement Accelerating"
            static let declineAccelerating = "Decline Accelerating"
            static let consistentlyStrongHealth = "Consistently Strong Health"
            static let extendedLowScorePeriod = "Extended Low Score Period"

            // Momentum summaries
            static let gainsPickingUpSpeed = "Your health gains are picking up speed. This week's improvement was stronger than last week's."
            static let droppingFaster = "Your health score is dropping faster this week than last. Multiple areas may need attention."
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
            static let lowCognitiveReadiness = "Low Cognitive Readiness"
            static let strongCognitiveReadiness = "Strong Cognitive Readiness"
            static let sleepDebtAccumulating = "Sleep Debt Accumulating"
            static let mentalFatiguePatternDetected = "Mental Fatigue Pattern Detected"
            static let lowPhysicalEnergy = "Low Physical Energy"
            static let recoveryDayNeeded = "Recovery Day Needed"
            static let daylightSleepCognitionChain = "Daylight-Sleep-Cognition Chain"

            // Cognitive readiness narratives
            static func cognitiveReadinessLow(score: Int, componentText: String) -> String {
                "Your cognitive readiness is at \(score)/100\(componentText). Together these predict reduced mental clarity and slower processing."
            }
            static func cognitiveReadinessStrong(score: Int) -> String {
                "Your cognitive readiness is strong at \(score)/100. HRV, sleep quality, and recovery markers are all above baseline."
            }
            static let brainPrimedForWork = "Your brain is primed for demanding work today. Take advantage of this high-readiness state for complex tasks."

            // Recovery day
            static let recoveryDayRecommendation = "Take a genuine rest day tomorrow. Light walking only, no intense exercise. Your patterns show HRV typically rebounds within 48 hrs of reduced intensity."
        }

        // MARK: - Illness Early Warning

        enum IllnessWarning {
            static let significantStrain = "Body Showing Signs of Significant Strain"
            static let multipleMetricStrain = "Multiple Metrics Suggest Physical Strain"
            static let earlyPhysiologicalStrain = "Early Signs of Physiological Strain"
            static let multiMetricPattern = "This multi-metric pattern \u{2014} where several physiological markers shift unfavorably at the same time \u{2014} may reflect increased physiological strain."
            static let multipleMetricsShifted = "Multiple metrics shifted from baseline simultaneously."
            static let consistentWithPhysiologicalStrain = "Your multi-metric pattern suggests your body is under increased physiological strain."
            static let cardiacMetricsStrain = "Your cardiac metrics indicate autonomic strain."
            static let activityNotReturned = "Your activity metrics haven't returned to baseline yet."
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
            static let unusualMultiMetricPattern = "Unusual Multi-Metric Pattern Detected"
            static let rareMetricCombination = "Rare Metric Combination"
            static let unusualCombinationDetected = "Unusual combination of metric values detected."
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
            static let betterShapeLongTerm = "You're in better shape this year. Your long-term trajectory is positive."
            static let exceptionalPersonalBest = "This is exceptional \u{2014} you're at a personal best level. Whatever you're doing, it's working across your entire history."
            static let rareLevelMayWarrantAttention = "This level is rare in your history. It may warrant attention if it persists beyond a few days."
            static let outperformingSeasonalNorm = "You're outperforming your seasonal norm. This suggests genuine improvement beyond seasonal patterns."
            static let longTermImprovementReliable = "This long-term improvement is the most reliable signal. Short-term dips don't erase months of positive change."
            static let sustainedDeclineStructural = "A sustained decline suggests something structural has changed. Consider consulting a healthcare provider if this trend continues."
            static let unusualValuesMonitor = "Unusual values that persist for days are more meaningful than single-day spikes. Monitor over the next few days."
        }
    }
}
