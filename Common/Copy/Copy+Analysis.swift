import Foundation

extension Copy {
    enum Analysis {

        // MARK: - Clinical Intelligence

        enum Clinical {
            static var bloodPressureTrendingUp: String { RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_blood_pressure_trending_up", default: "Blood Pressure Trending Up") }
            static var elevatedPulsePressure: String { RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_elevated_pulse_pressure", default: "Pulse Pressure is Higher Than Usual") }
            static var bloodGlucoseTrendingUp: String { RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_blood_glucose_trending_up", default: "Blood Glucose Trending Up") }
            static var abnormalRespiratoryRate: String { RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_abnormal_respiratory_rate", default: "Unusual Breathing Rate") }
            static var medicalDisclaimer: String { RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_medical_disclaimer", default: "This is for your information only and is not medical advice.") }

            // BP recommendations
            static var bpRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_bp_recommendation", default: "Try eating less salt, moving more, and keeping stress in check.") }
            static var pulsePressureRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_pulse_pressure_recommendation", default: "A wider gap between your blood pressure numbers can mean your heart is working harder than usual. Try some gentle movement and easy breathing today.") }
            static var glucoseRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_glucose_recommendation", default: "Cut back on sugar and white bread. Eat more fiber. Stay active.") }
            static var respiratoryRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_respiratory_recommendation", default: "If your breathing rate stays unusual for a few days, it is worth checking in on this.") }

            // Projection templates
            static func projectedToReach(label: String, days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_projected_to_reach", default: "At this rate, this could reach %@ levels in about %d days."), label, days)
            }
            static func projectedToReachRange(label: String, days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_projected_to_reach_range", default: "At this rate, this could reach the %@ range in about %d days."), label, days)
            }

            // BP summary templates
            static func bpTrendingSummary(slopePerMonth: String, dayCount: Int, stage: String, nextStageInfo: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_bp_trending_summary", default: "Your top blood pressure number has been rising %@ mmHg per month over the past %d days. Right now: %@. %@"), slopePerMonth, dayCount, stage, nextStageInfo)
            }
            static func pulsePressureSummary(pulsePressure: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_pulse_pressure_summary", default: "The gap between your blood pressure numbers (%d mmHg) is wider than the usual 40 to 60 mmHg. Based on your patterns, this is worth a look."), pulsePressure)
            }
            static func glucoseTrendingSummary(slopePerMonth: String, latest: String, stage: String, nextInfo: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_glucose_trending_summary", default: "Your fasting blood sugar has been rising %@ mg/dL per month. Now: %@ mg/dL (%@). %@"), slopePerMonth, latest, stage, nextInfo)
            }
            static func respiratorySummary(rate: String, stage: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_clinical_respiratory_summary", default: "Your breathing rate (%@ br/min) falls in the %@ range. Most people sit between 12 and 20 breaths per minute."), rate, stage)
            }
        }

        // MARK: - Recovery Analyzer

        enum Recovery {
            static var postWorkoutHRVRecovery: String { RemoteConfigManager.shared.copyString("copy_analysis_recovery_post_workout_hrv_recovery", default: "Recovery After Workout") }
            static var restDayDeficit: String { RemoteConfigManager.shared.copyString("copy_analysis_recovery_rest_day_deficit", default: "Not Enough Rest Days") }
            static var overtrainingWarning: String { RemoteConfigManager.shared.copyString("copy_analysis_recovery_overtraining_warning", default: "You May Be Overdoing It") }
            static var earlyOvertrainingSignal: String { RemoteConfigManager.shared.copyString("copy_analysis_recovery_early_overtraining_signal", default: "Early Signs of Overdoing It") }
        }

        // MARK: - Workout Effectiveness

        enum Workout {
            static var workoutConsistency: String { RemoteConfigManager.shared.copyString("copy_analysis_workout_workout_consistency", default: "Workout Consistency") }
            static var vo2MaxResponse: String { RemoteConfigManager.shared.copyString("copy_analysis_workout_vo2_max_response", default: "VO2 Max Response") }
            static var calorieEfficiency: String { RemoteConfigManager.shared.copyString("copy_analysis_workout_calorie_efficiency", default: "Calorie Efficiency") }
        }

        // MARK: - Sleep Performance

        enum Sleep {
            static func sleepDrives(_ metricName: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_sleep_drives", default: "Sleep Drives %@"), metricName) }
            static var sleepQualityToActivity: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_sleep_quality_to_activity", default: "Sleep Quality \u{2192} Activity") }
            static var sleepConsistency: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_sleep_consistency", default: "Sleep Consistency") }
        }

        // MARK: - Weekly Pattern

        enum WeeklyPattern {
            static func weakestDay(_ dayName: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_weakest_day", default: "Weakest Day: %@"), dayName) }
            static func weekdayVsWeekend(_ metricName: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_weekday_vs_weekend", default: "%@: Weekday vs Weekend"), metricName) }
            static func metricConsistency(_ metricName: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_metric_consistency", default: "%@ Consistency"), metricName) }
        }

        // MARK: - Cycle Phase

        enum CyclePhase {
            static func title(_ phaseName: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_title", default: "Cycle Phase Analyzer: %@"), phaseName) }
            static var scaleIntensityNote: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_scale_intensity_note", default: "Your body is reacting more than usual right now. Take it easier for the next 2 days and see how you feel.") }
            static var keepLoggingNote: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_keep_logging_note", default: "Keep logging every day so we can better learn what is normal for you.") }

            static var menstrualBaseline: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_menstrual_baseline", default: "Lower energy and up-and-down recovery can be normal during your period.") }
            static var follicularBaseline: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_follicular_baseline", default: "Energy and how ready you feel to train often pick up through the follicular phase.") }
            static var ovulatoryBaseline: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_ovulatory_baseline", default: "Many people feel their most ready around ovulation.") }
            static var lutealBaseline: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_luteal_baseline", default: "Slightly lower energy in the luteal phase is common and usually expected.") }

            static var menstrualRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_menstrual_recommendation", default: "Put recovery first: lighter training, drink plenty of water, and keep your sleep steady.") }
            static var follicularRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_follicular_recommendation", default: "Use this phase to push a bit harder in training and take on focus-heavy tasks while your energy is climbing.") }
            static var ovulatoryRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_ovulatory_recommendation", default: "Do your key workouts now, then protect your sleep and water to keep recovery steady.") }
            static var lutealRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_phase_luteal_recommendation", default: "Plan slightly easier sessions, go to bed a little earlier, and stick to steady routines.") }

            static func phaseSummary(phase: String, day: Int, cycleLength: Int, expectation: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_cycle_phase_phase_summary", default: "You are in your %@ phase (day %d of ~%d). %@"), phase, day, cycleLength, expectation)
            }
            static func metricDirectionFragment(label: String, direction: String, percent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_cycle_phase_metric_direction_fragment", default: "%@ %@ %@%%"), label, direction, percent)
            }
        }

        // MARK: - Weekly Pattern Extras

        enum WeeklyPatternStrings {
            static var unknownDay: String { RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_strings_unknown_day", default: "Unknown") }
            static var restingHRLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_strings_resting_hr_label", default: "Resting HR") }
            static var sleepQualityLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_strings_sleep_quality_label", default: "Sleep quality") }
            static var activityLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_strings_activity_label", default: "Activity") }
        }

        // MARK: - Personal Records

        enum PersonalRecord {
            // Milestone labels
            static var tenKStepDay: String { RemoteConfigManager.shared.copyString("copy_analysis_personal_record_ten_k_step_day", default: "10K Step Day") }
            static var eightKPlusSteps: String { RemoteConfigManager.shared.copyString("copy_analysis_personal_record_eight_k_plus_steps", default: "8K+ Steps") }
            static var thirtyPlusMinExercise: String { RemoteConfigManager.shared.copyString("copy_analysis_personal_record_thirty_plus_min_exercise", default: "30+ Min Exercise") }
            static var hrvAbove50ms: String { RemoteConfigManager.shared.copyString("copy_analysis_personal_record_hrv_above50ms", default: "Heart Recovery Above 50ms") }
            static var eightHourSleepNight: String { RemoteConfigManager.shared.copyString("copy_analysis_personal_record_eight_hour_sleep_night", default: "8-Hour Sleep Night") }
            static var sevenPlusHrSleep: String { RemoteConfigManager.shared.copyString("copy_analysis_personal_record_seven_plus_hr_sleep", default: "7+ Hr Sleep") }
            static var tenPlusStandHours: String { RemoteConfigManager.shared.copyString("copy_analysis_personal_record_ten_plus_stand_hours", default: "10+ Stand Hours") }

            // Title templates
            static func newPR(windowLabel: String, metricName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_personal_record_new_pr", default: "New %@ PR: %@"), windowLabel, metricName)
            }
            static func streakTitle(days: Int, label: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_personal_record_streak_title", default: "%d-Day %@ Streak"), days, label)
            }
            static func milestoneTitle(_ label: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_analysis_personal_record_milestone_title", default: "Milestone: %@"), label)
            }

            // Summary templates
            static func streakSummary(label: String, days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_streak_summary", default: "You have hit %@ for %d consecutive days."), label.lowercased(), days)
            }
            static func milestoneSummary(_ label: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_milestone_summary", default: "You achieved %@ for the first time this week."), label.lowercased())
            }
            static func milestoneRecommendation(_ label: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_milestone_recommendation", default: "First recorded instance of %@ in your data."), label.lowercased())
            }
        }

        // MARK: - Score Trajectory

        enum ScoreTrajectory {
            static var healthScoreTrendingUp: String { RemoteConfigManager.shared.copyString("copy_analysis_score_trajectory_health_score_trending_up", default: "Health Score Trending Up") }
            static var healthScoreDeclining: String { RemoteConfigManager.shared.copyString("copy_analysis_score_trajectory_health_score_declining", default: "Health Score Declining") }
            static var improvementAccelerating: String { RemoteConfigManager.shared.copyString("copy_analysis_score_trajectory_improvement_accelerating", default: "Getting Better Faster") }
            static var declineAccelerating: String { RemoteConfigManager.shared.copyString("copy_analysis_score_trajectory_decline_accelerating", default: "Getting Worse Faster") }
            static var consistentlyStrongHealth: String { RemoteConfigManager.shared.copyString("copy_analysis_score_trajectory_consistently_strong_health", default: "Staying Strong") }
            static var extendedLowScorePeriod: String { RemoteConfigManager.shared.copyString("copy_analysis_score_trajectory_extended_low_score_period", default: "Low Score for a While") }

            // Momentum summaries
            static var gainsPickingUpSpeed: String { RemoteConfigManager.shared.copyString("copy_analysis_score_trajectory_gains_picking_up_speed", default: "You are improving faster this week than last.") }
            static var droppingFaster: String { RemoteConfigManager.shared.copyString("copy_analysis_score_trajectory_dropping_faster", default: "Your score is dropping faster this week. A few areas need a look.") }
        }

        // MARK: - Baseline Drift

        enum BaselineDrift {
            static func title(metricName: String, period: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_baseline_drift_title", default: "%@ Usual Level Shifted Over %@"), metricName, period)
            }
        }

        // MARK: - Multi-Metric Cluster

        enum MultiMetricCluster {
            static func categoryDeclining(_ categoryName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_category_declining", default: "%@: Several Numbers Dropping"), categoryName)
            }
            static var widespreadHealthDecline: String { RemoteConfigManager.shared.copyString("copy_analysis_widespread_health_decline", default: "Widespread Health Decline") }

            static var directionAbove: String { RemoteConfigManager.shared.copyString("copy_analysis_direction_above", default: "above") }
            static var directionBelow: String { RemoteConfigManager.shared.copyString("copy_analysis_direction_below", default: "below") }

            static func metricDetail(name: String, formatted: String, unit: String, dev: String, dir: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_metric_detail", default: "%@: %@ %@ (%@%% %@ usual)"), name, formatted, unit, dev, dir)
            }
            static func metricDeviation(name: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_metric_deviation", default: "%@ (%@%% off usual)"), name, dev)
            }
            static func clusterSummary(count: Int, categoryName: String, details: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_cluster_summary", default: "%d metrics declining together in %@: %@."), count, categoryName, details)
            }
            static func crossCategorySummary(total: Int, categoryCount: Int, names: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_cross_category_summary", default: "%d metrics across %d categories are declining: %@."), total, categoryCount, names)
            }
            static func crossCategoryRecommendation(total: Int, categoryCount: Int, names: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_cross_category_recommendation", default: "%d metrics declining across %d categories: %@."), total, categoryCount, names)
            }

            static func heartCluster(count: Int, names: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_heart_cluster", default: "Several heart numbers are dropping at once. %d numbers affected: %@. On average %@%% below usual."), count, names, dev)
            }
            static func sleepCluster(count: Int, names: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_sleep_cluster", default: "Sleep is getting worse across %d areas. %@. On average %@%% below usual."), count, names, dev)
            }
            static func activityCluster(count: Int, names: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_activity_cluster", default: "Activity is dropping across %d numbers. %@. On average %@%% below usual."), count, names, dev)
            }
            static func bodyCluster(count: Int, names: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_body_cluster", default: "Body numbers are shifting. %d numbers affected: %@. On average %@%% off usual."), count, names, dev)
            }
            static func respiratoryCluster(count: Int, names: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_respiratory_cluster", default: "Breathing numbers are higher than usual. %d numbers affected: %@. On average %@%% off usual."), count, names, dev)
            }
            static func mindfulnessCluster(count: Int, names: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_mindfulness_cluster", default: "Mindfulness numbers are dropping. %d numbers affected: %@. On average %@%% below usual."), count, names, dev)
            }
            static func mobilityCluster(count: Int, names: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_mobility_cluster", default: "Movement numbers are dropping across %d signs. %@. On average %@%% below usual."), count, names, dev)
            }
            static func nutritionCluster(count: Int, names: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_nutrition_cluster", default: "Nutrition numbers have shifted from usual. %d numbers affected: %@. On average %@%% off usual."), count, names, dev)
            }
            static func hearingCluster(count: Int, names: String, dev: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_cluster_hearing_cluster", default: "Hearing numbers have changed. %d numbers affected: %@. On average %@%% off usual."), count, names, dev)
            }
        }

        // MARK: - Cross-Metric Anomaly Narratives

        enum CrossMetricNarratives {
            static func extremelyRare(metrics: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cross_metric_narratives_extremely_rare", default: "This mix of numbers (%@) is very rare for you. Think about what was different yesterday. Travel, meal timing, late workouts, or stress can often set this off. If this keeps up for 2 or more days, it may be worth talking to a doctor."), metrics)
            }
            static func brokenRelationship(metricA: String, metricB: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cross_metric_narratives_broken_relationship", default: "The usual link between your %@ and %@ has broken down. Look at what was different yesterday. Travel, diet changes, late exercise, or extra stress are common causes. See if it goes back to normal within 48 hours."), metricA, metricB)
            }
            static func unusualMultiCategory(categoryCount: Int, metrics: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cross_metric_narratives_unusual_multi_category", default: "Unusual pattern across %d areas (%@). Look at what was different yesterday. Travel, diet, late exercise, or stress are the most common causes. If you feel fine, this may be a one-off."), categoryCount, metrics)
            }
            static func unusualCombination(metrics: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cross_metric_narratives_unusual_combination", default: "Unusual mix in %@. Look at what was different yesterday. Travel, diet, late exercise, or stress are common causes."), metrics)
            }
            static func unusualMild(metrics: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cross_metric_narratives_unusual_mild", default: "Unusual but mild pattern in %@. Nothing to do right now. Just watch whether it comes back over the next 3 days to see if it is a one-off or a real trend."), metrics)
            }
        }

        // MARK: - Cognitive Energy

        enum CognitiveEnergy {
            static var lowCognitiveReadiness: String { RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_low_cognitive_readiness", default: "Low Cognitive Energy") }
            static var strongCognitiveReadiness: String { RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_strong_cognitive_readiness", default: "Strong Cognitive Energy") }
            static var sleepDebtAccumulating: String { RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_sleep_debt_accumulating", default: "Sleep Balance Declining") }
            static var mentalFatiguePatternDetected: String { RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_mental_fatigue_pattern_detected", default: "Signs of Mental Fatigue") }
            static var lowPhysicalEnergy: String { RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_low_physical_energy", default: "Low Physical Energy") }
            static var recoveryDayNeeded: String { RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_recovery_day_needed", default: "Recovery Day Needed") }
            static var daylightSleepCognitionChain: String { RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_daylight_sleep_cognition_chain", default: "Sunlight, Sleep, and Focus") }

            // Cognitive energy narratives
            static func cognitiveReadinessLow(score: Int, componentText: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_cognitive_readiness_low", default: "Your mental energy is at %d out of 100%@. You may feel less sharp and think slower today."), score, componentText)
            }
            static func cognitiveReadinessStrong(score: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_cognitive_readiness_strong", default: "Your mental energy is strong at %d out of 100. Your heart, sleep, and recovery numbers are all better than usual."), score)
            }
            static var brainPrimedForWork: String { RemoteConfigManager.shared.copyString("copy_analysis_brain_primed_for_work", default: "Great day for hard thinking. Use this energy for your toughest tasks.") }

            // Recovery day
            static var recoveryDayRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_recovery_day_recommendation", default: "Take a real rest day tomorrow. Just light walking, no hard exercise. Your body usually bounces back within 2 days of taking it easy.") }

            // Component fragments
            static func downFromBaseline(percent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_down_from_baseline", default: "down %@%% from usual"), percent)
            }
            static func belowBaseline(percent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_below_baseline", default: "%@%% below usual"), percent)
            }
            static func hoursBelowBaseline(hours: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_hours_below_baseline", default: "%@ hrs below your usual"), hours)
            }

            // Cognitive readiness narratives (analyzer)
            static func cognitiveLowSummary(score: Int, componentText: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_cognitive_low_summary", default: "Your mental energy is at %d/100%@. Fixing these can help you think sharper and faster."), score, componentText)
            }
            static func cognitiveLowRecommendation(topComponent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_cognitive_low_recommendation", default: "Try sleeping 45 minutes longer tonight. Your %@ is the biggest thing weighing on you right now. Just one night of 8 or more hours usually helps your heart recovery and deep sleep the next day."), topComponent)
            }
            static func cognitiveStrongSummary(score: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_cognitive_strong_summary", default: "Your mental energy is strong at %d/100. How rested your heart is, your sleep quality, and your recovery signs are all better than usual."), score)
            }

            // Sleep debt
            static func sleepDebtSummary(debt: String, avg: String, baseline: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_sleep_debt_summary", default: "You have built up %@ hours of sleep debt this week (averaging %@ hrs vs your usual %@ hrs). Short sleep can affect how alert and clear-headed you feel each day."), debt, avg, baseline)
            }
            static func sleepDebtRecommendation(catchUpNights: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_sleep_debt_recommendation", default: "An extra hour each night for %d nights can help clear this. Setting a bedtime alarm 45 minutes before you want to sleep is a good start."), catchUpNights)
            }

            // Mental fatigue
            static func mentalFatigueSummary(parts: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_mental_fatigue_summary", default: "Your %@ over the past week. This combination often goes with mental tiredness, slower thinking, and trouble focusing."), parts)
            }
            static func mentalFatigueRecommendation(actions: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_mental_fatigue_recommendation", default: "Three actions ranked by impact: %@."), actions)
            }

            // Low physical energy
            static func lowPhysicalSummary(signalText: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_low_physical_summary", default: "Your physical energy signs are low: %@. You are probably feeling tired and heavy."), signalText)
            }

            // Recovery needed
            static func recoveryNeededSummary(consecutiveHighDays: Int, signalText: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cognitive_energy_recovery_needed_summary", default: "You have been very active for %d days straight and your recovery signs are strained. %@. Without rest, both your sharpness and your performance drop."), consecutiveHighDays, signalText)
            }

            // Daylight chain
            static func daylightChainSummary(daylightChange: String, deepDeclining: Bool, deepChange: String) -> String {
                let stage = deepDeclining
                    ? RemoteConfigManager.shared.copyString("copy_analysis_daylight_stage_deep", default: "deep sleep")
                    : RemoteConfigManager.shared.copyString("copy_analysis_daylight_stage_duration", default: "sleep duration")
                return String(format: RemoteConfigManager.shared.copyString("copy_analysis_daylight_chain_summary", default: "Your daylight dropped %@%% and %@ dropped %@%% in the same window. These are linked. Sunlight sets your body clock, which shapes how you sleep and how clearly you think the next day."), daylightChange, stage, deepChange)
            }
            static func daylightChainRecommendation(effectNote: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_daylight_chain_recommendation", default: "Get 20 or more minutes of outdoor light before noon tomorrow.%@ This one change affects when you sleep, how much deep sleep you get, and how sharp you feel the next day."), effectNote)
            }
        }

        // MARK: - Strain Signals

        enum StrainSignals {
            static var significantStrain: String { RemoteConfigManager.shared.copyString("copy_analysis_strain_signals_significant_strain", default: "Your Body is Under Stress") }
            static var multipleMetricStrain: String { RemoteConfigManager.shared.copyString("copy_analysis_strain_signals_multiple_metric_strain", default: "Several Numbers Show Your Body is Stressed") }
            static var earlyPhysiologicalStrain: String { RemoteConfigManager.shared.copyString("copy_analysis_strain_signals_early_physiological_strain", default: "Early Signs Your Body is Stressed") }
            static var multiMetricPattern: String { RemoteConfigManager.shared.copyString("copy_analysis_strain_signals_multi_metric_pattern", default: "Several health numbers shifted at the same time. Your body may be under extra stress.") }
            static var multipleMetricsShifted: String { RemoteConfigManager.shared.copyString("copy_analysis_strain_signals_multiple_metrics_shifted", default: "Several numbers moved away from your usual at the same time.") }
            static var consistentWithPhysiologicalStrain: String { RemoteConfigManager.shared.copyString("copy_analysis_strain_signals_consistent_with_physiological_strain", default: "The pattern across your numbers suggests your body is under extra stress.") }
            static var cardiacMetricsStrain: String { RemoteConfigManager.shared.copyString("copy_analysis_strain_signals_cardiac_metrics_strain", default: "Your heart numbers suggest your body is stressed.") }
            static var activityNotReturned: String { RemoteConfigManager.shared.copyString("copy_analysis_strain_signals_activity_not_returned", default: "Your activity numbers have not gone back to your usual yet.") }
        }

        // MARK: - Health Data Query Engine

        enum HealthDataQuery {
            // Question templates
            static func qHowTrending(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_how_trending", default: "How is my %@ trending?"), metric) }
            static func qCompare(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_compare", default: "Compare my %@"), metric) }
            static func qDoesAffect(_ a: String, _ b: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_does_affect", default: "Does %@ affect %@?"), a, b) }
            static func qWhatWillBe(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_what_will_be", default: "What will my %@ be?"), metric) }
            static func qWhatWillBeWhen(_ metric: String, when: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_what_will_be_when", default: "What will my %@ be %@?"), metric, when) }
            static var qAnythingUnusual: String { RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_anything_unusual", default: "Anything unusual?") }
            static func qWhatWasLabel(_ label: String, _ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_what_was_label", default: "What was my %@ %@?"), label, metric) }
            static func qHowIsMetric(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_how_is_metric", default: "How is my %@?"), metric) }
            static var qHowIsBodyDoing: String { RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_how_is_body_doing", default: "How is my body doing?") }
            static var qWhatStateIsBody: String { RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_what_state_is_body", default: "What state is my body in?") }
            static var qAmIAtRisk: String { RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_am_i_at_risk", default: "Am I at risk?") }
            static var qHowGreatDay: String { RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_how_great_day", default: "How do I have a great day?") }
            static var qHowImprove: String { RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_how_improve", default: "How do I improve?") }
            static var qWhatAffects: String { RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_what_affects", default: "What affects my ") }
            static var qPredictForTomorrow: String { RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_predict_for_tomorrow", default: "Predict my ") }
            static var qDoIHavePatterns: String { RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_q_do_i_have_patterns", default: "Do I have any ") }

            // Related questions
            static func relatedAffects(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_related_affects", default: "What affects my %@?"), metric) }
            static func relatedPredict(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_related_predict", default: "Predict my %@ for tomorrow"), metric) }
            static func relatedPatterns(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_related_patterns", default: "Do I have any %@ patterns?"), metric) }

            // Trending answer
            static func trendingAnswer(action: String, metric: String, direction: String, period: String, avg: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_trending_answer", default: "%@ Your %@ is %@ over %@, averaging %@."), action, metric, direction, period, avg)
            }

            // Comparison
            static var comparisonRoughlySame: String { RemoteConfigManager.shared.copyString("copy_analysis_comparison_roughly_same", default: "roughly the same") }
            static var comparisonLookingBetter: String { RemoteConfigManager.shared.copyString("copy_analysis_comparison_looking_better", default: "looking better") }
            static var comparisonABitLower: String { RemoteConfigManager.shared.copyString("copy_analysis_comparison_a_bit_lower", default: "a bit lower") }
            static var comparisonKeepUp: String { RemoteConfigManager.shared.copyString("copy_analysis_comparison_keep_up", default: "Keep up whatever you changed. It's working.") }
            static var comparisonHoldingSteady: String { RemoteConfigManager.shared.copyString("copy_analysis_comparison_holding_steady", default: "You're holding steady, which is a good sign.") }
            static func comparisonGetBack(period: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_comparison_get_back", default: "Try to get back to your %@ routine. Your body did better then."), period)
            }
            static func comparisonAnswer(action: String, metric: String, periodA: String, verdict: String, periodB: String, avgA: String, avgB: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_comparison_answer", default: "%@ Your %@ %@ is %@ compared to %@ (%@ vs %@)."), action, metric, periodA, verdict, periodB, avgA, avgB)
            }

            // Correlation
            static var strengthStrong: String { RemoteConfigManager.shared.copyString("copy_analysis_strength_strong", default: "strong") }
            static var strengthModerate: String { RemoteConfigManager.shared.copyString("copy_analysis_strength_moderate", default: "moderate") }
            static var strengthMild: String { RemoteConfigManager.shared.copyString("copy_analysis_strength_mild", default: "mild") }
            static var strengthVeryWeak: String { RemoteConfigManager.shared.copyString("copy_analysis_strength_very_weak", default: "very weak") }
            static var directionMoveTogether: String { RemoteConfigManager.shared.copyString("copy_analysis_direction_move_together", default: "move together") }
            static var directionMoveOpposite: String { RemoteConfigManager.shared.copyString("copy_analysis_direction_move_opposite", default: "move in opposite directions") }
            static var lagNextDay: String { RemoteConfigManager.shared.copyString("copy_analysis_lag_next_day", default: "the next day") }
            static func lagDaysLater(_ days: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_lag_days_later", default: "%d days later"), days) }
            static func correlationCausal(metricA: String, metricB: String, lag: String, strength: String, direction: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_correlation_causal", default: "Pay attention to your %@. When it changes, your %@ tends to follow %@. There's a %@ link between the two, and they %@."), metricA, metricB, lag, strength, direction)
            }
            static func correlationActionable(actionable: String, other: String, strength: String, direction: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_correlation_actionable", default: "Yes, improving your %@ is likely to help your %@ too. There's a %@ connection and they %@."), actionable, other, strength, direction)
            }
            static func correlationNoLink(metricA: String, metricB: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_correlation_no_link", default: "I haven't found a clear statistical connection between your %@ and %@ so far. They appear to move independently based on the data I have."), metricA, metricB)
            }

            // Forecast
            static func forecastNoModel(metric: String, avg: String, latest: String, when: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_forecast_no_model", default: "I don't have a full forecasting model for %@ yet, but based on your recent trend (averaging %@ over the past week, latest at %@), you can expect it to stay in a similar range %@."), metric, avg, latest, when)
            }
            static func forecastNeedMore(metric: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_forecast_need_more", default: "I need a bit more %@ data to make a prediction. Once I have a couple of weeks of history, I'll be able to forecast ahead for you."), metric)
            }
            static func forecastAnswer(action: String, metric: String, value: String, when: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_forecast_answer", default: "%@ I'm expecting your %@ to be around %@ %@, based on your patterns."), action, metric, value, when)
            }

            // Anomaly
            static var anomalyAllNormal: String { RemoteConfigManager.shared.copyString("copy_analysis_anomaly_all_normal", default: "Everything looks within your normal ranges right now. No spikes, no dips. your body is humming along as expected.") }
            static func anomalyAnswer(action: String, metric: String, value: String, dir: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_anomaly_answer", default: "%@ Your %@ at %@ is noticeably %@ than your usual."), action, metric, value, dir)
            }

            // Personal records
            static var prBestSuffix: String { RemoteConfigManager.shared.copyString("copy_analysis_pr_best_suffix", default: "That's a solid benchmark to work toward again.") }
            static var prWorstSuffix: String { RemoteConfigManager.shared.copyString("copy_analysis_pr_worst_suffix", default: "Everyone has off days. what matters is the overall trajectory.") }
            static func prAnswer(label: String, metric: String, value: String, dateStr: String, suffix: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_pr_answer", default: "Your %@ %@ on record was %@, recorded on %@. %@"), label, metric, value, dateStr, suffix)
            }

            // Metric status
            static func statusKeepDoing(metric: String, latest: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_status_keep_doing", default: "Keep doing what you're doing. Your %@ is above your usual at %@. Whatever your routine is right now, it's working."), metric, latest)
            }
            static func statusEaseUp(metric: String, latest: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_status_ease_up", default: "Try to ease up a bit today. Your %@ is running high at %@, above your usual."), metric, latest)
            }
            static func statusDipped(metric: String, latest: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_status_dipped", default: "Your %@ has dipped to %@, below your usual level. Focus on recovery. Sleep, hydration, and lighter activity can help bring it back up."), metric, latest)
            }
            static func statusBelowGood(metric: String, latest: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_status_below_good", default: "Nice, your %@ is at %@, below your usual, which is a good sign. Keep it up."), metric, latest)
            }
            static func statusOnBaseline(metric: String, latest: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_status_on_baseline", default: "Your %@ is right where it should be at %@. Steady and consistent. That's what you want to see."), metric, latest)
            }
            static func statusLearning(metric: String, latest: String, avg: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_status_learning", default: "Your %@ is at %@ with a 7-day average of %@. As I learn your patterns, I'll be able to give you more personalized advice."), metric, latest, avg)
            }

            // Body state
            static var bodyNoData: String { RemoteConfigManager.shared.copyString("copy_analysis_body_no_data", default: "No health data available yet. Once you connect your Apple Watch or allow Health access, I'll be able to tell you how your body is doing.") }
            static func bodySnapshot(summary: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_body_snapshot", default: "Here's a snapshot of your body right now. %@ As I gather more history, I'll be able to classify your body's overall state automatically."), summary)
            }
            static func bodyStateAnswer(conclusion: String, label: String, traits: String, durationNote: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_body_state_answer", default: "%@ Your body is in a \"%@\" state right now, where %@.%@"), conclusion, label, traits, durationNote)
            }

            // Risk
            static func riskOutsideRange(metric: String, value: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_risk_outside_range", default: "Based on your recent readings, your %@ at %@ is outside your usual range. Worth keeping an eye on. As I build a longer history, I'll be able to run deeper risk assessments."), metric, value)
            }
            static var riskNothingConcerning: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_nothing_concerning", default: "Based on the data I have, nothing looks concerning right now. All your recent readings are within your normal ranges. I'll keep monitoring and alert you if anything changes.") }
            static var riskAllHealthy: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_all_healthy", default: "No significant health risks detected. your fatigue, burnout, overtraining, sleep, immune, and activity signals all look healthy.") }
            static var riskCritical: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_critical", default: "at a critical level") }
            static var riskHigh: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_high", default: "higher than usual") }
            static var riskWatching: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_watching", default: "worth watching") }
            static func riskAnswer(recommendation: String, name: String, level: String, explanation: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_risk_answer", default: "%@ Your %@ is %@. %@"), recommendation, name, level, explanation)
            }

            // Improvement
            static func greatDayFocusOn(_ gaps: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_great_day_focus_on", default: "Focus on your %@ today. That's your biggest opportunity to improve. "), gaps)
            }
            static var greatDayCloseToIdeal: String { RemoteConfigManager.shared.copyString("copy_analysis_great_day_close_to_ideal", default: "You're close to your ideal day. Keep your current routine going. ") }
            static func improveBiggestImpact(_ levers: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_improve_biggest_impact", default: "The metrics with the biggest impact on your score are: %@. Small improvements here will move the needle the most."), levers)
            }
            static func improveMostRoom(_ tips: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_improve_most_room", default: "Here's where you have the most room to improve right now: %@. Focus on bringing these back to your usual and you should feel the difference."), tips)
            }
            static var improveAllOnBaseline: String { RemoteConfigManager.shared.copyString("copy_analysis_improve_all_on_baseline", default: "Your key numbers are all close to your usual right now, which is a great sign. Keep up the consistency, and as I learn more about what drives your best days, I'll give you more targeted advice.") }

            // Data point labels
            static var labelAverage: String { RemoteConfigManager.shared.copyString("copy_analysis_label_average", default: "Average") }
            static var labelChange: String { RemoteConfigManager.shared.copyString("copy_analysis_label_change", default: "Change") }
            static var labelLatest: String { RemoteConfigManager.shared.copyString("copy_analysis_label_latest", default: "Latest") }
            static var labelCorrelation: String { RemoteConfigManager.shared.copyString("copy_analysis_label_correlation", default: "Correlation") }
            static var labelStability: String { RemoteConfigManager.shared.copyString("copy_analysis_label_stability", default: "Stability") }

            // Pattern Q
            static var qAnyPatterns: String { RemoteConfigManager.shared.copyString("copy_analysis_q_any_patterns", default: "Any patterns?") }
            static var qAnyPatternsInData: String { RemoteConfigManager.shared.copyString("copy_analysis_q_any_patterns_in_data", default: "Any patterns in my data?") }
            static func patternEmerging(target: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_pattern_emerging", default: "I'm seeing some emerging patterns in your %@, but they're not strong enough to be definitive yet."), target)
            }
            static func patternCycleHint(type: String, dayName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_pattern_cycle_hint", default: " There's a hint of a %@ cycle, with a mild peak on %@s."), type, dayName)
            }
            static func patternNoneFound(target: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_pattern_none_found", default: "No recurring patterns detected in %@ at this time. This can actually be a good sign. it means your body is responding consistently. I'll keep looking for weekly and monthly rhythms."), target)
            }
            static func patternPeakTrough(peakDay: String, metric: String, troughDay: String, type: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_pattern_peak_trough", default: "Plan your toughest activities for %@s when your %@ peaks, and take it easier on %@s when it dips. Your %@ follows a clear %@ cycle."), peakDay, metric, troughDay, metric, type)
            }
            static func patternCycleAdvice(metric: String, type: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_pattern_cycle_advice", default: "Your %@ follows a clear %@ cycle. Use that rhythm to your advantage by scheduling harder days around your peaks."), metric, type)
            }
            static var yourMetrics: String { RemoteConfigManager.shared.copyString("copy_analysis_your_metrics", default: "your metrics") }

            // Circadian
            static var buildingCircadianProfile: String { RemoteConfigManager.shared.copyString("copy_analysis_building_circadian_profile", default: "I'm still learning your full body clock.") }
            static func circadianRecentSleep(avg: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_circadian_recent_sleep", default: " Based on your recent sleep (%@ average), aim to be consistent with your bedtime."), avg)
            }
            static func circadianAvgSteps(steps: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_circadian_avg_steps", default: " You're averaging %d steps. a morning or afternoon walk is generally a great time to move."), steps)
            }
            static var circadianGeneralAdvice: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_general_advice", default: " In the meantime, a good general rule: exercise in the morning or early afternoon, wind down 1-2 hours before bed, and keep your sleep schedule consistent.") }
            static var qWhenWorkOut: String { RemoteConfigManager.shared.copyString("copy_analysis_q_when_work_out", default: "When should I work out?") }
            static var qBodyClock: String { RemoteConfigManager.shared.copyString("copy_analysis_q_body_clock", default: "What's my body clock like?") }
            static func circadianBestWindows(lines: String, chronotype: String, peak: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_circadian_best_windows", default: "Here are your best windows based on your body clock: %@. You're a %@, with peak energy around %@."), lines, chronotype, peak)
            }
            static func circadianChronotype(chronotype: String, peak: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_circadian_chronotype", default: "You're a %@. Your peak energy is around %@, so schedule your hardest workout or deep work then."), chronotype, peak)
            }
            static func circadianRecoveryPeak(hour: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_circadian_recovery_peak", default: " Your recovery peaks around %@, which is a good time for lighter activity."), hour)
            }

            // Highlight summary
            static func highlightHigh(label: String, value: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_highlight_high", default: "%@ is a bit high at %@"), label, value)
            }
            static func highlightLow(label: String, value: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_highlight_low", default: "%@ is on the low side at %@"), label, value)
            }
            static func highlightNormal(label: String, value: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_highlight_normal", default: "%@ is normal at %@"), label, value)
            }
            static func highlightDefault(label: String, value: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_highlight_default", default: "%@ is at %@"), label, value)
            }
            static func metricsTrackingNormal(count: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_metrics_tracking_normal", default: "I'm tracking %d metrics. Everything I see looks within expected ranges."), count)
            }

            // Risk fallback
            static func riskRoughDay(percent: Int, summary: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_risk_rough_day", default: "Based on your recent data, there's a %d%% chance tomorrow could be a rough day. %@"), percent, summary)
            }
            static func riskLowDay(percent: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_risk_low_day", default: "Looking ahead, your risk of a bad day tomorrow is low (%d%%). You're in a good position."), percent)
            }

            // Optimization tail
            static func optimizationAimFor(targetList: String, score: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_data_query_optimization_aim_for", default: "Your data says to aim for: %@. Hit those targets and you're looking at a score of %d."), targetList, score)
            }

            // Related question constants
            static var rqHowAmIDoingOverall: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_how_am_i_doing_overall", default: "How am I doing overall?") }
            static var rqAmIAtRiskForAnything: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_am_i_at_risk_for_anything", default: "Am I at risk for anything?") }
            static var rqWhatDataDoIHave: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_what_data_do_i_have", default: "What data do I have?") }
            static var rqHowIsMyHRVTrending: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_how_is_my_hrv_trending", default: "How is my heart recovery trending?") }
            static var rqHowIsMySleepTrending: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_how_is_my_sleep_trending", default: "How is my sleep trending?") }
            static var rqWhatStateIsMyBody: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_what_state_is_my_body", default: "What state is my body in?") }
            static var rqWhatShouldIDoToday: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_what_should_i_do_today", default: "What should I do today?") }
            static var rqAnythingUnusualInData: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_anything_unusual_in_data", default: "Anything unusual in my data?") }
            static var rqDoIHaveAnyPatterns: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_do_i_have_any_patterns", default: "Do I have any patterns?") }
            static var rqWhatShouldIFocusOn: String { RemoteConfigManager.shared.copyString("copy_analysis_rq_what_should_i_focus_on", default: "What should I focus on?") }
            static func rqAnythingUnusualInMetric(_ metric: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_analysis_rq_anything_unusual_in_metric", default: "Anything unusual in my %@?"), metric) }
        }

        // MARK: - Rules Engine Helpers

        enum RulesEngine {
            static func projection(days: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_projection", default: " Based on current trends, this may approach warning level within ~%d days."), days)
            }
            static func rootCause(metric: String, percent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_root_cause", default: " This appears connected to your %@ shifting %@%%."), metric, percent)
            }
            static func historicalPercentile(label: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_historical_percentile", default: "in the %@ of your history"), label)
            }
            static func historicalSeasonal(percent: String, direction: String, month: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_historical_seasonal", default: "%@%% %@ your typical %@"), percent, direction, month)
            }
            static func historicalYoY(percent: String, direction: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_historical_yo_y", default: "%@%% %@ than this time last year"), percent, direction)
            }
            static func historicalIntro(parts: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_historical_intro", default: " Historically: %@."), parts)
            }
            static func correlationAction(factor: String, metric: String, percent: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_correlation_action", default: " Your data shows that improving %@ raises your %@ by ~%@%%."), factor, metric, percent)
            }
            static func topLever(factor: String, percent: String, metric: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_top_lever", default: "Your #1 lever: improve %@ (%@%% impact on %@)."), factor, percent, metric)
            }

            // Cardio
            static func rhrAboveBaseline(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_rhr_above_baseline", default: "%@Your resting heart rate is %@above your usual."), valStr, devStr)
            }
            static var rhrCheckChanges: String { RemoteConfigManager.shared.copyString("copy_analysis_rhr_check_changes", default: " Check for recent changes in sleep, stress, or caffeine intake.") }
            static func rhrTrendingDown(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_rhr_trending_down", default: "%@Your resting heart rate is trending down from your recent average."), valStr)
            }
            static func rhrConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_rhr_consistent", default: "%@Your resting heart rate is in line with your 30-day average."), valStr)
            }
            static func hrvDownBaseline(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_hrv_down_baseline", default: "%@Your heart recovery is down %@from your usual."), valStr, devStr)
            }
            static var hrvCheckChanges: String { RemoteConfigManager.shared.copyString("copy_analysis_hrv_check_changes", default: " Check recent changes in sleep or recovery patterns.") }
            static func hrvConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_hrv_consistent", default: "%@Your heart recovery is in line with your 30-day average."), valStr)
            }
            static func vo2Improving(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_vo2_improving", default: "%@Your VO2 Max is up %@from your usual. Your heart and lung fitness is improving."), valStr, devStr)
            }
            static func vo2Flat(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_vo2_flat", default: "%@VO2 Max has been flat or declining %@compared to your usual."), valStr, devStr)
            }
            static func bloodOxygenCritical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_blood_oxygen_critical", default: "%@Blood oxygen is very low, below the 90%% emergency mark. This needs attention right away. If you feel short of breath, confused, have bluish lips or fingertips, or chest pain, get emergency care. Take the reading again to be sure, and if it stays below 90%%, contact a doctor urgently."), valStr)
            }
            static func bloodOxygenDropped(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_blood_oxygen_dropped", default: "%@Blood oxygen has dropped %@below your typical level."), valStr, devStr)
            }
            static func bloodOxygenTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_blood_oxygen_typical", default: "%@Blood oxygen is tracking at your typical level."), valStr)
            }
            static func afibElevated(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_afib_elevated", default: "%@Irregular heartbeat activity is %@higher than your usual."), valStr, devStr)
            }
            static func afibTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_afib_typical", default: "%@Irregular heartbeat activity is at your usual level."), valStr)
            }
            static func perfusionElevated(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_perfusion_elevated", default: "%@Your blood flow reading is %@outside your usual range."), valStr, devStr)
            }
            static func perfusionTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_perfusion_typical", default: "%@Your blood flow is at your usual level."), valStr)
            }

            // Sleep
            static func sleepDurationBelow(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_sleep_duration_below", default: "%@Sleep duration is %@below your usual."), valStr, devStr)
            }
            static func sleepDurationConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_sleep_duration_consistent", default: "%@Sleep duration is consistent with your usual."), valStr)
            }
            static func sleepStage(valStr: String, stage: String, devStr: String, direction: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_sleep_stage", default: "%@%@ sleep is %@%@ your usual."), valStr, stage, devStr, direction)
            }
            static func sleepCoreTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_sleep_core_typical", default: "%@Core sleep is tracking at your typical level."), valStr)
            }
            static func sleepAwakeAbove(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_sleep_awake_above", default: "%@Nighttime wake time is %@above your typical level."), valStr, devStr)
            }
            static func sleepAwakeTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_sleep_awake_typical", default: "%@Nighttime awake periods are tracking at your typical level."), valStr)
            }

            // Activity
            static func stepsDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_steps_down", default: "%@Step count is down %@from your usual."), valStr, devStr)
            }
            static func stepsUp(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_steps_up", default: "%@Step count is up %@from your usual."), valStr, devStr)
            }
            static func stepsConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_steps_consistent", default: "%@Step count is consistent with your usual."), valStr)
            }
            static func activeCaloriesDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_active_calories_down", default: "%@Active calorie burn is down %@from your usual."), valStr, devStr)
            }
            static func activeCaloriesAbove(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_active_calories_above", default: "%@Active calorie burn is tracking above your usual."), valStr)
            }
            static func exerciseDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_exercise_down", default: "%@Exercise time has dropped %@from your recent average."), valStr, devStr)
            }
            static func exerciseConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_exercise_consistent", default: "%@Exercise time is consistent with your recent average."), valStr)
            }
            static func cyclingDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_cycling_down", default: "%@Cycling distance is down %@from your usual."), valStr, devStr)
            }
            static func cyclingConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_cycling_consistent", default: "%@Cycling distance is consistent with your usual."), valStr)
            }
            static func swimmingDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_swimming_down", default: "%@Swimming activity has declined %@from your usual."), valStr, devStr)
            }
            static func swimmingConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_swimming_consistent", default: "%@Swimming activity is consistent with your usual."), valStr)
            }
            static func moveTimeDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_move_time_down", default: "%@Move time is down %@from your usual."), valStr, devStr)
            }
            static func moveTimeConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_move_time_consistent", default: "%@Move time is consistent with your usual."), valStr)
            }
            static func walkingSpeedDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_walking_speed_down", default: "%@Walking speed is down %@from your usual."), valStr, devStr)
            }
            static func walkingSpeedConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_walking_speed_consistent", default: "%@Walking speed is consistent with your usual."), valStr)
            }
            static func stepLengthDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_step_length_down", default: "%@Step length has shortened %@from your usual."), valStr, devStr)
            }
            static func stepLengthConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_step_length_consistent", default: "%@Step length is consistent with your usual."), valStr)
            }
            static func walkingAsymmetryElevated(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_walking_asymmetry_elevated", default: "%@Your walking is %@more uneven than usual."), valStr, devStr)
            }
            static func walkingSymmetryConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_walking_symmetry_consistent", default: "%@Walking symmetry is consistent with your usual."), valStr)
            }
            static func doubleSupportElevated(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_double_support_elevated", default: "%@The time both feet spend on the ground is %@higher than usual."), valStr, devStr)
            }
            static func doubleSupportTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_double_support_typical", default: "%@The time both feet spend on the ground is at your usual level."), valStr)
            }
            static func stairSpeedDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_stair_speed_down", default: "%@Stair speed is down %@from your usual."), valStr, devStr)
            }
            static func stairSpeedConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_stair_speed_consistent", default: "%@Stair speed is consistent with your usual."), valStr)
            }
            static func sixMinuteWalkDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_six_minute_walk_down", default: "%@Six-minute walk distance is down %@from your usual."), valStr, devStr)
            }
            static func sixMinuteWalkConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_six_minute_walk_consistent", default: "%@Six-minute walk distance is consistent with your usual."), valStr)
            }

            // Body & vitals
            static func bodyCompTrendingUp(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_body_comp_trending_up", default: "%@Trending up %@from your usual."), valStr, devStr)
            }
            static func bodyCompConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_body_comp_consistent", default: "%@Body composition is consistent with your recent trend."), valStr)
            }
            static func leanMassDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_lean_mass_down", default: "%@Lean body mass is down %@from your usual."), valStr, devStr)
            }
            static func leanMassConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_lean_mass_consistent", default: "%@Lean body mass is consistent with your usual."), valStr)
            }
            static func waistAbove(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_waist_above", default: "%@Waist circumference is %@above your usual."), valStr, devStr)
            }
            static func waistConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_waist_consistent", default: "%@Waist circumference is consistent with your usual."), valStr)
            }
            static func wristTempDeviated(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_wrist_temp_deviated", default: "%@Your wrist temperature is %@off your usual range."), valStr, devStr)
            }
            static func wristTempTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_wrist_temp_typical", default: "%@Sleeping wrist temperature is tracking at your typical level."), valStr)
            }
            static func bpAbove(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_bp_above", default: "%@Blood pressure is %@above your usual."), valStr, devStr)
            }
            static func bpConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_bp_consistent", default: "%@Blood pressure is consistent with your usual."), valStr)
            }
            static func respiratoryElevated(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_respiratory_elevated", default: "%@Your breathing rate is %@higher than usual."), valStr, devStr)
            }
            static func respiratoryTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_respiratory_typical", default: "%@Your breathing rate is at your usual level."), valStr)
            }
            static func peakFlowDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_peak_flow_down", default: "%@Peak flow rate has dropped %@below your usual."), valStr, devStr)
            }
            static func peakFlowTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_peak_flow_typical", default: "%@Peak expiratory flow rate is tracking at your typical level."), valStr)
            }
            static func forcedVitalDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_forced_vital_down", default: "%@Forced vital capacity is down %@from your usual."), valStr, devStr)
            }
            static func lungCapacityTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_lung_capacity_typical", default: "%@Lung capacity is tracking at your typical level."), valStr)
            }
            static func bodyTempOutside(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_body_temp_outside", default: "%@Body temperature is %@outside your typical range."), valStr, devStr)
            }
            static func bodyTempTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_body_temp_typical", default: "%@Body temperature is tracking at your typical level."), valStr)
            }
            static func mindfulnessDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_mindfulness_down", default: "%@Mindfulness time has dropped %@from your usual."), valStr, devStr)
            }
            static func mindfulnessConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_mindfulness_consistent", default: "%@Mindfulness time is consistent with your usual."), valStr)
            }
            static func daylightDown(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_daylight_down", default: "%@Daylight exposure is down %@from your usual."), valStr, devStr)
            }
            static func daylightConsistent(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_daylight_consistent", default: "%@Daylight exposure is consistent with your usual."), valStr)
            }
            static func edaElevated(valStr: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_eda_elevated", default: "%@Your skin stress signal is %@higher than your usual."), valStr, devStr)
            }
            static func edaTypical(valStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_eda_typical", default: "%@Your skin stress signal is at your usual level."), valStr)
            }

            // Default
            static func defaultDeclining(valStr: String, metricName: String, devStr: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_default_declining", default: "%@%@ is declining %@from your usual."), valStr, metricName, devStr)
            }
            static func defaultTypical(valStr: String, metricName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_rules_engine_default_typical", default: "%@%@ is tracking at your typical level."), valStr, metricName)
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
                "Improve Your Heart Recovery",
                "Better sleep, slow breathing (4 in, 4 hold, 4 out, 4 hold), and recovery days between hard workouts can help.",
                "Aim for steady, higher readings over time"
            )
            static let supportBP: Recommendation = (
                "Support Blood Pressure",
                "Try eating less salty and processed food, moving more through the week, keeping a healthy weight, and going easy on alcohol.",
                "Aim for steady readings in your usual range"
            )
            static let improveHRR: Recommendation = (
                "Improve Your Heart Rate Bounce-Back",
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
                "Target: 7 to 9 hours"
            )
            static let boostDeepSleep: Recommendation = (
                "Boost Deep Sleep",
                "Exercise earlier in the day (not within 3 hours of bedtime), avoid alcohol which breaks up deep sleep, and keep your bedroom cool.",
                "Target: 1 to 2 hours per night"
            )
            static let improveREM: Recommendation = (
                "Improve REM Sleep",
                "REM sleep helps your memory and mood. A steady sleep schedule and skipping sleep aids can raise how much REM you get.",
                "Target: 1.5 to 2 hours per night"
            )
            static let reduceWaking: Recommendation = (
                "Reduce Nighttime Waking",
                "Limit fluids 2 hours before bed, avoid caffeine after noon, use white noise, and keep the room dark. Address any sleep apnea concerns.",
                "Target: <30 min per night"
            )

            // Overtraining
            static let allowRecovery: Recommendation = (
                "Allow Recovery Time",
                "When your heart recovery is low but you keep training hard, your body is not getting enough rest. Take 1-2 rest days, put sleep first, and ease your workout effort by 20%.",
                "Target: heart recovery back to your usual"
            )
            static let watchElevatedRHR: Recommendation = (
                "Watch for a Rising Resting Heart Rate",
                "A rising resting heart rate even though you train regularly is a classic sign of overdoing it. Do less this week and check your resting heart rate each morning before you get up.",
                "Target: within 5 beats per minute of your usual"
            )
            static let balanceLoad: Recommendation = (
                "Balance Training Load",
                "More isn't always better. Follow the 80/20 rule: 80% easy, 20% hard. Include at least 2 rest days per week.",
                "Target: 150 to 300 min/week with rest days"
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
                "Focus on changes you can keep up: eat less processed food, more protein and vegetables, and mix cardio with strength training.",
                "Target: BMI 18.5 to 25"
            )
            static let reduceBodyFat: Recommendation = (
                "Reduce Body Fat",
                "Mix strength training 3x a week with 150+ min of cardio a week. Get plenty of protein (0.8g per lb of bodyweight) and sleep for fat loss.",
                "Target: 10 to 20% (men) / 18 to 28% (women)"
            )
            static let reduceWaist: Recommendation = (
                "Reduce Waist Circumference",
                "Belly fat is a key warning sign for your health. Daily walks, core exercises, and less sugar have the biggest impact.",
                "Target: <94 cm (men) / <80 cm (women)"
            )
            static let increaseMovement: Recommendation = (
                "Increase Daily Movement",
                "A low step count is strongly linked to health risks. Start with 2,000 more steps than your current average. Try walking meetings and walks after meals.",
                "Target: 8,000 to 10,000 steps/day"
            )

            // Stress
            static let reduceChronicStress: Recommendation = (
                "Reduce Chronic Stress",
                "Your heart recovery is the most reliable stress signal. Try 10 minutes of meditation daily, slow box breathing before bed, and time in nature.",
                "Target: heart recovery rising week over week"
            )
            static let prioritizeRecoverySleep: Recommendation = (
                "Prioritize Recovery Sleep",
                "Sleep is the #1 stress recovery tool. Set a bedtime you will not skip. Remove work apps from your phone after 9 PM.",
                "Target: 7 to 8 hours consistently"
            )
            static let buildMindfulness: Recommendation = (
                "Build Mindfulness Practice",
                "Even 5 minutes of daily mindfulness lowers your stress hormones. Use a guided app to start. Morning sessions help the most.",
                "Target: 10 to 20 min daily"
            )
            static let manageSympathetic: Recommendation = (
                "Calm Your Stress Response",
                "A higher skin stress signal means your body is stuck in fight-or-flight mode. Try relaxing your muscles one group at a time, and cut back on stimulants like caffeine.",
                "Target: back to your usual"
            )

            // Mobility
            static let maintainWalkingSpeed: Recommendation = (
                "Maintain Walking Speed",
                "Walking speed is a key vitality indicator. Include brisk walking intervals (2 min fast, 2 min normal) in daily walks.",
                "Target: >1.0 m/s (3.6 km/h)"
            )
            static let correctGaitAsymmetry: Recommendation = (
                "Even Out Your Walking",
                "Unevenness above 10% between your left and right steps can point to muscle imbalance or joint issues. Single-leg exercises and stretching can help. See a physical therapist if it keeps up.",
                "Target: under 10% unevenness"
            )
            static let buildFunctionalEndurance: Recommendation = (
                "Build Everyday Stamina",
                "How far you can walk in 6 minutes shows your everyday stamina. Daily walks that get a little longer will build this steadily.",
                "Target: >500 meters"
            )
            static let improveBalance: Recommendation = (
                "Improve Balance",
                "Spending a lot of time with both feet on the ground points to balance trouble. Practice single-leg stands, heel-to-toe walking, and tai chi or yoga.",
                "Target: 20 to 30%"
            )

            // Default
            static func improveMetric(_ metricName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_risk_focus_improve_metric", default: "Improve %@"), metricName)
            }
            static func bringIntoOptimalRange(_ metricLower: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_risk_focus_bring_into_optimal_range", default: "Focus on bringing %@ into the optimal range through consistent healthy habits."), metricLower)
            }
            static func targetRange(_ range: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_risk_focus_target_range", default: "Target: %@"), range)
            }
        }

        // MARK: - Health Risk Engine Explanations

        enum HealthRiskEngine {
            static var noRecentDataExplanation: String { RemoteConfigManager.shared.copyString("copy_analysis_health_risk_engine_no_recent_data_explanation", default: "No recent data available. Keep Apple Health syncing to track this metric.") }

            static func withinHealthyRange(metricName: String, formatted: String, unit: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_risk_engine_within_healthy_range", default: "%@ is %@ %@, within the healthy range."), metricName, formatted, unit)
            }
            static func metricValuePrefix(metricName: String, formatted: String, unit: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_risk_engine_metric_value_prefix", default: "%@ is %@ %@"), metricName, formatted, unit)
            }
            static var belowOptimalRange: String { RemoteConfigManager.shared.copyString("copy_analysis_below_optimal_range", default: "below the optimal range") }
            static var aboveOptimalRange: String { RemoteConfigManager.shared.copyString("copy_analysis_above_optimal_range", default: "above the optimal range") }

            static var directionDecreasing: String { RemoteConfigManager.shared.copyString("copy_analysis_direction_decreasing", default: "decreasing") }
            static var directionRising: String { RemoteConfigManager.shared.copyString("copy_analysis_direction_rising", default: "rising") }
            static var directionIncreasing: String { RemoteConfigManager.shared.copyString("copy_analysis_direction_increasing", default: "increasing") }

            static func andDirection(_ direction: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_risk_engine_and_direction", default: "and %@"), direction)
            }
            static func whileTrending(_ direction: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_health_risk_engine_while_trending", default: "while trending %@"), direction)
            }
        }

        // MARK: - Health Risk Grades

        enum RiskGrades {
            static var low: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_grade_low", default: "Looks good") }
            static var moderate: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_grade_moderate", default: "Mostly steady") }
            static var elevated: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_grade_elevated", default: "Worth a look") }
            static var high: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_grade_high", default: "Needs attention") }
            static var veryHigh: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_grade_very_high", default: "Talk to a doctor") }
        }

        // MARK: - Health Risk Detail

        enum RiskDetail {
            static var whatToFocusOn: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_detail_what_to_focus_on", default: "What to Focus On") }
            static var contributingFactors: String { RemoteConfigManager.shared.copyString("copy_analysis_risk_detail_contributing_factors", default: "Contributing Factors") }
            static func optimalRange(_ range: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_risk_detail_optimal_range", default: "Best: %@"), range)
            }
            static func metricsMeasured(measured: Int, total: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_risk_detail_metrics_measured", default: "%d of %d metrics measured"), measured, total)
            }
            static var disclaimer: String { RemoteConfigManager.shared.copyString("copy_analysis_disclaimer", default: "These scores are based on patterns in your health data and published wellness ranges. They are not medical advice and should not replace guidance from a qualified professional.") }
        }

        // MARK: - Correlation

        enum Correlation {
            static var strong: String { RemoteConfigManager.shared.copyString("copy_analysis_correlation_strong", default: "Strong") }
            static var moderate: String { RemoteConfigManager.shared.copyString("copy_analysis_correlation_moderate", default: "Moderate") }
            static var mild: String { RemoteConfigManager.shared.copyString("copy_analysis_correlation_mild", default: "Mild") }
        }

        // MARK: - Nutrition Correlation

        enum NutritionCorrelation {
            static func affects(nutrition: String, outcome: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_nutrition_correlation_affects", default: "%@ Affects %@"), nutrition, outcome)
            }
            static func monitorToOptimize(nutrition: String, outcome: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_nutrition_correlation_monitor_to_optimize", default: "Watch your %@ intake to improve %@."), nutrition, outcome)
            }
        }

        // MARK: - Cross-Metric Anomaly

        enum CrossMetricAnomaly {
            static func unusualPattern(metricA: String, metricB: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_cross_metric_anomaly_unusual_pattern", default: "%@ & %@ Unusual Pattern"), metricA, metricB)
            }
            static var unusualMultiMetricPattern: String { RemoteConfigManager.shared.copyString("copy_analysis_unusual_multi_metric_pattern", default: "Unusual Pattern Across Multiple Numbers") }
            static var rareMetricCombination: String { RemoteConfigManager.shared.copyString("copy_analysis_rare_metric_combination", default: "Unusual Combination") }
            static var unusualCombinationDetected: String { RemoteConfigManager.shared.copyString("copy_analysis_unusual_combination_detected", default: "An unusual mix of health numbers was found.") }
        }

        // MARK: - Causal Chain

        enum CausalChain {
            static func singleCauseTitle(cause: String, affected: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_causal_chain_single_cause_title", default: "%@ May Be Affecting Your %@"), cause, affected)
            }
            static func chainTitle(affected: String, rootCause: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_causal_chain_chain_title", default: "Why Your %@ Changed: %@ Connection"), affected, rootCause)
            }
        }

        // MARK: - Research Analyzers

        enum Research {

            // MARK: HRR Fitness

            enum HRRFitness {
                static var belowClinicalTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_below_clinical_title", default: "Heart Rate Bounce-Back Below Healthy Level") }
                static var excellentTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_excellent_title", default: "Great Heart Rate Bounce-Back") }
                static var decliningTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_declining_title", default: "Heart Rate Bounce-Back Slowing") }
                static func improvingTitle(months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_improving_title", default: "Heart Rate Bounce-Back Improving Over %d Months"), months)
                }

                static func belowClinicalSummary(currentHRR: String, threshold: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_below_clinical_summary", default: "Your heart rate drops %@ bpm in the minute after exercise, below the healthy mark of %d bpm. That means your body is slow to switch into rest-and-recover mode."), currentHRR, threshold)
                }
                static func belowClinicalRecommendation(threshold: Int, currentHRR: String, sampleCount: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_below_clinical_recommendation", default: "A heart rate drop under %d bpm one minute after exercise is linked with lower overall fitness in large studies. Your average of %@ bpm across %d readings suggests your body is slow to shift into rest-and-recover mode."), threshold, currentHRR, sampleCount)
                }

                static func excellentSummary(currentHRR: String, goodThreshold: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_excellent_summary", default: "Your heart rate drops %@ bpm after exercise, well above the %d bpm mark for a healthy body. This shows your body switches into rest-and-recover mode fast."), currentHRR, goodThreshold)
                }
                static func excellentRecommendation(currentHRR: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_excellent_recommendation", default: "A drop of %@ bpm puts you in the top range. Research links this kind of fast recovery after exercise to better heart fitness and a healthier rest-and-recover system."), currentHRR)
                }

                static func improvingSummary(change: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_improving_summary", default: "Your heart rate bounce-back has improved by %@ bpm over the past %d months. Research shows the more you exercise, the more this improves."), change, months)
                }
                static func improvingRecommendation(change: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_improving_recommendation", default: "A %@ bpm gain over %d months is real progress in how fast your body recovers. Studies show as little as 6 months of steady exercise can bring this kind of change."), change, months)
                }

                static func decliningSummary(change: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_declining_summary", default: "Your heart rate bounce-back has gotten worse by %@ bpm over %d months. A falling trend suggests your body is slower to recover."), change, months)
                }
                static func decliningRecommendation(start: String, current: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_hrr_fitness_declining_recommendation", default: "Your bounce-back dropped from %@ to %@ bpm over %d months. This can come from training less, more stress, or a health issue. Regular cardio is the best way to bring it back up."), start, current, months)
                }
            }

            // MARK: Sleep Regularity

            enum SleepRegularity {
                static var irregularTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_regularity_irregular_title", default: "Irregular Sleep Pattern Detected") }
                static var needsAttentionTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_regularity_needs_attention_title", default: "Sleep Regularity Needs Attention") }
                static var excellentTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_regularity_excellent_title", default: "Excellent Sleep Regularity") }
                static func socialJetLagTitle(minutes: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_sleep_regularity_social_jet_lag_title", default: "Weekend Sleep Shift: %@ Minutes"), minutes)
                }

                static func irregularSummary(sri: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_sleep_regularity_irregular_summary", default: "Your sleep is scored %@/100 for how steady it is, which lands in the irregular range. Research shows how steady your sleep is matters more for long-term health than how long you sleep."), sri)
                }
                static func irregularRecommendation(sri: String, samples: Int, socialJetLag: Double, jetLagMinutes: String) -> String {
                    let jetLagSuffix = socialJetLag > 60
                        ? String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_sleep_regularity_jet_lag_suffix", default: " Your weekend sleep shift of %@ min is also on the high side."), jetLagMinutes)
                        : ""
                    let body = String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_sleep_regularity_irregular_recommendation", default: "Across 5 large studies, people with irregular sleep (a steadiness score under 60) may think less clearly and feel worse over time, no matter how many hours they sleep. Your score of %@ over %d nights shows your sleep changes a lot from night to night."), sri, samples)
                    return body + jetLagSuffix
                }

                static func needsAttentionSummary(sri: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_needs_attention_summary", default: "Your sleep steadiness score is %@/100, okay but with room to improve. Going to bed and waking at steady times matters more than how long you sleep for long-term health."), sri)
                }
                static func needsAttentionRecommendation(sri: String, samples: Int, socialJetLag: Double, jetLagMinutes: String) -> String {
                    let jetLagSuffix = socialJetLag > 45
                        ? String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_sleep_regularity_jet_lag_reduce", default: " Cutting your %@-min weekend sleep shift would help most."), jetLagMinutes)
                        : ""
                    let body = String(format: RemoteConfigManager.shared.copyString("copy_analysis_research_needs_attention_recommendation", default: "Your steadiness score of %@ across %d nights is in the middle range. Research links every 10-point gain in this score to real gains in heart and body health."), sri, samples)
                    return body + jetLagSuffix
                }

                static func excellentSummary(sri: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_excellent_summary", default: "Your sleep steadiness score is %@/100. Your sleep times and length are very steady. That on its own helps your long-term health."), sri)
                }
                static func excellentRecommendation(sri: String, samples: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_excellent_recommendation", default: "A score of %@ across %d nights puts you in the steadiest group. Research shows this level of steady sleep goes with clearer thinking and much better overall health over time."), sri, samples)
                }

                static func socialJetLagSummary(minutes: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_social_jet_lag_summary", default: "Your sleep time shifts by %@ minutes on weekends compared to weekdays. That is like crossing a time zone every week. It is linked to worse body health no matter how long you sleep."), minutes)
                }
                static func socialJetLagRecommendation(minutes: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_social_jet_lag_recommendation", default: "A weekend sleep shift over 60 min is linked to worse body health and more body stress, even in adults who sleep enough. Your %@-min shift means your body clock is well out of sync on weekends."), minutes)
                }
            }

            // MARK: Inflammation Risk

            enum InflammationRisk {
                static var bodyStressSignalTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_inflammation_risk_body_stress_signal_title", default: "Body Stress Signal") }
                static var elevatedBodyStressTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_inflammation_risk_elevated_body_stress_title", default: "Higher Body Stress") }
                static var strongRecoveryToneTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_inflammation_risk_strong_recovery_tone_title", default: "Strong Recovery") }

                static func bodyStressSummary(dropPercent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_inflammation_risk_body_stress_summary", default: "Your heart recovery has dropped %@%% below usual while your wrist is warmer than usual. Together, these hint your body may be under more stress."), dropPercent)
                }
                static func bodyStressRecommendation(currentHRV: String, baseline: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_inflammation_risk_body_stress_recommendation", default: "Low heart recovery plus a warmer body is a well-proven early sign that your body is working harder than usual to recover. In studies, this often shows up 1 to 3 days before you feel off. Your heart recovery now: %@ ms vs your usual %@ ms."), currentHRV, baseline)
                }

                static func elevatedBodyStressSummary(consecutiveDeclines: Int, dropPercent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_inflammation_risk_elevated_body_stress_summary", default: "Your heart recovery has been dropping for %d readings in a row, now %@%% below your usual. A steady drop like this hints your body may be under more stress."), consecutiveDeclines, dropPercent)
                }
                static func elevatedBodyStressRecommendation(currentHRV: String, baseline: String, days: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_inflammation_risk_elevated_body_stress_recommendation", default: "Research shows a long dip in heart recovery (without training harder) means your body is recovering less well. In wearable studies, this often showed up days before people felt run down. Heart recovery: %@ ms vs your usual %@ ms over %d days."), currentHRV, baseline, days)
                }

                static func strongRecoverySummary(abovePercent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_inflammation_risk_strong_recovery_summary", default: "Your heart recovery is %@%% above usual, a sign your body is deep in rest-and-recover mode. Research links this to better recovery and resilience."), abovePercent)
                }
                static func strongRecoveryRecommendation(currentHRV: String, baseline: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_inflammation_risk_strong_recovery_recommendation", default: "A heart recovery of %@ ms (vs your usual %@ ms) shows your body is firmly in rest-and-recover mode. When this is high, your body is recovering well."), currentHRV, baseline)
                }
            }

            // MARK: Mobility Decline

            enum MobilityDecline {
                static var walkingSpeedLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_walking_speed_label", default: "walking speed") }
                static var stepLengthLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_step_length_label", default: "step length") }
                static var doubleSupportLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_double_support_label", default: "time with both feet down") }
                static var asymmetryLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_asymmetry_label", default: "uneven walking") }
                static var stairAscentLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_stair_ascent_label", default: "stair climbing speed") }
                static var stairDescentLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_stair_descent_label", default: "stair descent speed") }
                static var steadinessLabel: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_steadiness_label", default: "walking steadiness") }

                static var multiMetricDeclineTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_multi_metric_decline_title", default: "Several Movement Signs Dropping") }
                static var walkingSpeedDecliningTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_walking_speed_declining_title", default: "Walking Speed Declining") }
                static var asymmetryIncreasingTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_asymmetry_increasing_title", default: "Walking Getting More Uneven") }
                static var mobilityStableTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_mobility_stable_title", default: "Your Movement Is Steady") }

                static func multiMetricSummary(declining: Int, total: Int, metricList: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_multi_metric_summary", default: "%d of %d movement signs are dropping over the past 6 months: %@. Several walking measures slipping at once is worth a look."), declining, total, metricList)
                }
                static var multiMetricRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_multi_metric_recommendation", default: "Research shows walking speed, step length, and even steps dropping together can be an early sign of changes in your overall health. These shifts often show up long before you notice them in daily life.") }

                static func walkingSpeedSummary(percent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_walking_speed_summary", default: "Your walking speed has dropped %@%% over the past 6 months. Walking speed is called the 'sixth vital sign' because it is one of the strongest signs of how well your body works and how long you live."), percent)
                }
                static func walkingSpeedRecommendation(percent: String, samples: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_walking_speed_recommendation", default: "In large studies, every 0.1 m/s that walking speed drops is linked to worse overall health. Your %@%% drop across %d readings is worth keeping an eye on."), percent, samples)
                }

                static func asymmetrySummary(percent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_asymmetry_summary", default: "Your walking has gotten %@%% more uneven over 6 months. A growing left-right difference in your steps is an early sign of changes in how you move."), percent)
                }
                static func asymmetryRecommendation(percent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_asymmetry_recommendation", default: "More uneven walking, meaning a bigger difference between your left and right steps, can point to changes in balance, joint comfort, or how well you move. A %@%% rise is worth a look."), percent)
                }

                static func mobilityStableSummary(total: Int, improvingList: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_mobility_stable_summary", default: "All %d movement signs are steady or improving over the past 6 months. That points to strong, healthy movement.%@"), total, improvingList)
                }
                static func mobilityStableImprovingFragment(items: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_mobility_stable_improving_fragment", default: " Improving: %@."), items)
                }
                static func mobilityStableRecommendation(total: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_mobility_decline_mobility_stable_recommendation", default: "Steady or improving walking measures across %d areas (walking speed, step length, evenness, steadiness) point to strong, healthy movement. Research shows these are among the best signs of a long, healthy life."), total)
                }
            }

            // MARK: Biological Age

            enum BiologicalAge {
                static var cardioFitnessComponent: String { RemoteConfigManager.shared.copyString("copy_analysis_biological_age_cardio_fitness_component", default: "Cardio Fitness") }
                static var restingHeartRateComponent: String { RemoteConfigManager.shared.copyString("copy_analysis_biological_age_resting_heart_rate_component", default: "Resting Heart Rate") }
                static var activityRhythmComponent: String { RemoteConfigManager.shared.copyString("copy_analysis_biological_age_activity_rhythm_component", default: "Activity Rhythm") }
                static var mobilityComponent: String { RemoteConfigManager.shared.copyString("copy_analysis_biological_age_mobility_component", default: "Mobility") }
                static var autonomicComponent: String { RemoteConfigManager.shared.copyString("copy_analysis_biological_age_autonomic_component", default: "Rest-and-Recover System") }

                static func fitnessAgeTitle(years: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_biological_age_fitness_age_title", default: "Fitness Age Estimate: ~%@"), years)
                }
                static var imbalanceTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_imbalance_title", default: "Some Body Systems Age Faster") }

                static func componentBreakdownEntry(component: String, years: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_biological_age_component_breakdown_entry", default: "%@: ~%@ yrs"), component, years)
                }

                static func fitnessAgeSummary(componentCount: Int, years: String, strongest: String, oldest: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_biological_age_fitness_age_summary", default: "Based on %d body signals, your body works like someone around %@ years old. Strongest area: %@. Most room to improve: %@."), componentCount, years, strongest, oldest)
                }
                static func fitnessAgeRecommendation(breakdown: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_biological_age_fitness_age_recommendation", default: "Breakdown. %@. Each part is compared to typical results from large studies. Your VO2 Max on its own (one of the best signs of overall fitness) points to a matching fitness age."), breakdown)
                }

                static func imbalanceSummary(spread: String, youngestComponent: String, youngestAge: String, oldestComponent: String, oldestAge: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_biological_age_imbalance_summary", default: "There's a %@-year gap between your youngest system (%@: ~%@) and your oldest (%@: ~%@). This gap is worth working on."), spread, youngestComponent, youngestAge, oldestComponent, oldestAge)
                }
                static func imbalanceRecommendation(oldestComponent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_biological_age_imbalance_recommendation", default: "A big gap between these parts means one system is aging faster than the rest. Working on your %@ could bring your overall fitness age down a lot."), oldestComponent)
                }
            }

            // MARK: Wellbeing Trend

            enum WellbeingTrend {
                static var sleepRegularitySignal: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_sleep_regularity_signal", default: "Sleep Regularity") }
                static var activityLevelSignal: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_activity_level_signal", default: "Activity Level") }
                static var daylightSignal: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_daylight_signal", default: "Daylight") }
                static var mindfulnessSignal: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_mindfulness_signal", default: "Mindfulness") }
                static var autonomicToneSignal: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_autonomic_tone_signal", default: "Rest-and-Recover State") }

                static var sleepVeryRegular: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_sleep_very_regular", default: "sleep is very regular") }
                static var sleepModeratelyRegular: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_sleep_moderately_regular", default: "sleep regularity is moderate") }
                static var sleepVariesSignificantly: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_sleep_varies_significantly", default: "sleep timing varies significantly") }
                static var sleepHighlyIrregular: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_sleep_highly_irregular", default: "sleep is highly irregular") }

                static var activityIncreased: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_activity_increased", default: "activity increased this week") }
                static var activityStable: String { RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_activity_stable", default: "activity level is stable") }
                static func activityDropped(percent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_activity_dropped", default: "activity dropped %@%% this week"), percent)
                }

                static func goodDaylight(minutes: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_good_daylight", default: "good daylight exposure (%@ min/day)"), minutes)
                }
                static var moderateDaylight: String { RemoteConfigManager.shared.copyString("copy_analysis_moderate_daylight", default: "moderate daylight exposure") }
                static func lowDaylight(minutes: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_low_daylight", default: "low daylight exposure (%@ min/day)"), minutes)
                }
                static var veryLowDaylight: String { RemoteConfigManager.shared.copyString("copy_analysis_very_low_daylight", default: "very low daylight exposure") }

                static var mindfulnessConsistent: String { RemoteConfigManager.shared.copyString("copy_analysis_mindfulness_consistent", default: "consistent mindfulness practice") }
                static var mindfulnessSome: String { RemoteConfigManager.shared.copyString("copy_analysis_mindfulness_some", default: "some mindfulness activity") }
                static var mindfulnessMinimal: String { RemoteConfigManager.shared.copyString("copy_analysis_mindfulness_minimal", default: "hardly any mindfulness") }

                static var autonomicStrong: String { RemoteConfigManager.shared.copyString("copy_analysis_autonomic_strong", default: "your rest-and-recover state is strong") }
                static var autonomicNormal: String { RemoteConfigManager.shared.copyString("copy_analysis_autonomic_normal", default: "your rest-and-recover state is normal") }
                static var autonomicBelowBaseline: String { RemoteConfigManager.shared.copyString("copy_analysis_autonomic_below_baseline", default: "heart recovery below usual (body under stress)") }
                static var autonomicSuppressed: String { RemoteConfigManager.shared.copyString("copy_analysis_autonomic_suppressed", default: "heart recovery is well down") }

                static var patternShiftTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_pattern_shift_title", default: "Your Wellbeing Pattern Is Shifting") }
                static var mildPatternChangeTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_mild_pattern_change_title", default: "Mild Wellbeing Pattern Change") }
                static var strongIndicatorsTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_strong_indicators_title", default: "Strong Wellbeing Signs") }

                static func patternShiftSummary(concerningCount: Int, total: Int, concerns: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_pattern_shift_summary", default: "%d of %d daily habits are moving in ways often tied to a dip in mood: %@."), concerningCount, total, concerns)
                }
                static func patternShiftRecommendation(score: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_pattern_shift_recommendation", default: "Research shows that changes in sleep steadiness, activity, daylight, and your rest-and-recover state, all at once, can predict mood shifts well. This is just an observation, not a diagnosis, but it is worth noting. Score: %@/100."), score)
                }

                static func mildSummary(concerns: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_trend_mild_summary", default: "Two daily habits are shifting: %@. Not a strong signal yet, but worth watching."), concerns)
                }
                static var mildRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_mild_recommendation", default: "Research shows changes in just one or two habits are common and often pass. If they keep up for another week and things get worse, they matter more.") }

                static func strongSummary(total: Int, includeMindfulness: Bool) -> String {
                    let mindfulText = includeMindfulness
                        ? RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_strong_mindful_fragment", default: ", mindfulness")
                        : ""
                    return String(format: RemoteConfigManager.shared.copyString("copy_analysis_wellbeing_strong_summary", default: "Your habits across %d signs, sleep steadiness, activity, daylight%@, line up with good mental wellbeing."), total, mindfulText)
                }
                static var strongRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_strong_recommendation", default: "Research shows that steady sleep, regular activity, enough daylight, and a strong rest-and-recover state together protect your mental health. Your current habits show all of these.") }
            }

            // MARK: Circadian Disruption

            enum CircadianDisruption {
                static var amplitudeComponent: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_amplitude_component", default: "how active vs still you are") }
                static var regularityComponent: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_regularity_component", default: "how steady your daily rhythm is") }
                static var restActivityComponent: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_rest_activity_component", default: "gap between active and rest times") }
                static var sleepTimingComponent: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_sleep_timing_component", default: "sleep timing") }

                static var disruptedTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_disrupted_title", default: "Body Clock Out of Sync") }
                static var needsImprovementTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_needs_improvement_title", default: "Body Clock: Room to Improve") }
                static var strongRhythmTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_strong_rhythm_title", default: "Strong Body Clock") }

                static func disruptedSummary(score: String, weakest: String, weakestScore: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_disrupted_summary", default: "Your body clock health score is %@/100, which points to a big disruption in your daily rhythm. Weakest area: %@ (%@/100)."), score, weakest, weakestScore)
                }
                static var disruptedRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_disrupted_recommendation", default: "Research shows a disrupted body clock is linked to worse body health, heart health, mood, and long-term health. Your day lacks the strong rhythm (active by day, quiet at night) of a healthy body clock. How strong this day-night rhythm is on wearables lines up closely with your fitness age.") }

                static func needsImprovementSummary(score: String, weakest: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_needs_improvement_summary", default: "Your body clock health score is %@/100. Your daily rhythm is there but could be stronger. Focus area: %@."), score, weakest)
                }
                static func needsImprovementRecommendation(score: String, weakest: String, weakestScore: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_needs_improvement_recommendation", default: "A body clock score of %@ means your 24-hour rhythm is partly in sync. Strengthening your %@ (now %@/100) would help the most. Morning light every day and steady sleep times work best."), score, weakest, weakestScore)
                }

                static func strongRhythmSummary(score: String, strongest: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_strong_rhythm_summary", default: "Your body clock health score is %@/100. Your daily rhythm is strong and steady, with a clear gap between active and rest times. Strongest area: %@."), score, strongest)
                }
                static func strongRhythmRecommendation(score: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_disruption_strong_rhythm_recommendation", default: "A body clock score of %@ shows a well-tuned inner clock. Research shows a strong body clock on its own supports body health, clear thinking, and long-term health, and goes with a younger fitness age."), score)
                }
            }

            // MARK: Sleep Coherence

            enum SleepCoherence {
                static var outOfSyncTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_coherence_out_of_sync_title", default: "Sleep Systems Out of Sync") }
                static var strongCoherenceTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_coherence_strong_coherence_title", default: "Your Sleep Systems Are In Sync") }
                static var decliningCoherenceTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_coherence_declining_coherence_title", default: "Sleep Systems Falling Out of Sync") }

                static func outOfSyncSummary(incoherent: Int, total: Int, score: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_coherence_out_of_sync_summary", default: "Your body's systems aren't fully lining up during sleep. On %d of %d recent nights, your heart rate and heart recovery didn't follow the usual sleep-stage patterns. Sync score: %@/100."), incoherent, total, score)
                }
                static func outOfSyncRecommendation(score: String, severityLabel: String, total: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_coherence_out_of_sync_recommendation", default: "Research shows that when your body is out of sync during sleep, meaning your heart stays 'awake' while your brain sleeps, it is linked to worse overall health. Your sync score of %@ points to %@ mismatch across %d nights."), score, severityLabel, total)
                }

                static func strongCoherenceSummary(score: String, total: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_coherence_strong_coherence_summary", default: "Your body's systems sync well during sleep. Your heart rate drops as it should, your heart recovery rises, and your sleep stages look healthy. Sync score: %@/100 across %d nights."), score, total)
                }
                static func strongCoherenceRecommendation(score: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_coherence_strong_coherence_recommendation", default: "A sync score of %@ means your heart and nervous system line up well during sleep. Research links good sleep sync to better health in many areas."), score)
                }

                static func decliningSummary(prior: String, recent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_coherence_declining_summary", default: "Your sleep sync dropped from %@ to %@ over the past two weeks. Your heart and nervous system are less in step during sleep than before."), prior, recent)
                }
                static func decliningRecommendation(drop: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_coherence_declining_recommendation", default: "A %@-point drop in sleep sync over 2 weeks can come from more stress, an off schedule, or your body working harder to recover. This often shows up before you start feeling off."), drop)
                }

                static var severitySignificant: String { RemoteConfigManager.shared.copyString("copy_analysis_severity_significant", default: "significant") }
                static var severityModerate: String { RemoteConfigManager.shared.copyString("copy_analysis_severity_moderate", default: "moderate") }
            }

            // MARK: Temperature Compound

            enum TemperatureCompound {
                static func bodyTempElevatedTitle(nights: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_temperature_compound_body_temp_elevated_title", default: "Body Warmer Than Usual for %d Nights"), nights)
                }
                static var nighttimeAboveBaselineTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_nighttime_above_baseline_title", default: "Nighttime Temperature Above Usual") }
                static var cyclePatternTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_cycle_pattern_title", default: "Temperature Follows a Cycle") }
                static var highVariabilityTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_high_variability_title", default: "Temperature Jumps Around a Lot") }

                static func compoundSummary(deviation: String, nights: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_temperature_compound_compound_summary", default: "Your wrist runs %@°C warmer than your 30-day usual while you sleep, %d nights in a row. Together with low heart recovery, this can be an early sign your body is fighting something."), deviation, nights)
                }
                static func compoundRecommendation(deviation: String, baseline: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_temperature_compound_compound_recommendation", default: "A steady rise in nighttime temperature (%@°C vs your usual %@°C) along with low heart recovery is the kind of body signal seen when your immune system kicks in. Together they often show up 1 to 3 days before symptoms."), deviation, baseline)
                }

                static func tempOnlySummary(deviation: String, nights: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_temperature_compound_temp_only_summary", default: "Your wrist has run %@°C warmer than usual while you sleep for %d nights. A steady rise can come from body changes, stress, or an early shift before you feel anything."), deviation, nights)
                }
                static func tempOnlyRecommendation(recent: String, baseline: String, sd: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_temperature_compound_temp_only_recommendation", default: "Your nighttime temperature: %@°C vs your 30-day usual of %@°C (\u{00B1}%@). Research shows a wrist change over 0.3°C that lasts several nights can point to body changes, hormone shifts, or an early immune response."), recent, baseline, sd)
                }

                static func cyclePatternSummary(amplitude: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_temperature_compound_cycle_pattern_summary", default: "Your wrist temperature rises and falls in a repeating cycle of %@°C, which fits your hormone cycle. Research shows wrist temperature tracks ovulation 82-93%% of the time."), amplitude)
                }
                static func cyclePatternRecommendation(amplitude: String, baseline: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_temperature_compound_cycle_pattern_recommendation", default: "The %@°C rise and fall around your usual of %@°C follows the two-part pattern set by your hormones. After ovulation, temperature usually rises 0.2 to 0.5°C above the level earlier in your cycle."), amplitude, baseline)
                }

                static func highVariabilitySummary(sd: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_temperature_compound_high_variability_summary", default: "Your nighttime wrist temperature jumps around a lot from night to night (\u{00B1}%@°C). Big swings like this are linked to an off body clock and body health."), sd)
                }
                static func highVariabilityRecommendation(cvPercent: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_temperature_compound_high_variability_recommendation", default: "How much your temperature swings: %@%%. Research links big nighttime temperature swings to an off body clock, poor sleep, and worse body health. Steady temperatures point to a stronger body clock."), cvPercent)
                }
            }

            // MARK: Cardio Respiratory Age

            enum CardioRespiratoryAge {
                static func cardioFitnessAgeTitle(age: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_cardio_fitness_age_title", default: "Cardio Fitness Age: ~%@"), age)
                }
                static func vo2ImprovingTitle(change: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_vo2_improving_title", default: "VO2 Max Improving: +%@ Over %d Months"), change, months)
                }
                static func vo2DecliningTitle(change: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_vo2_declining_title", default: "VO2 Max Declining: %@ Over %d Months"), change, months)
                }
                static var belowThresholdTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_below_threshold_title", default: "VO2 Max Below Healthy Level") }

                static func cardioFitnessAgeSummary(vo2: String, age: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_cardio_fitness_age_summary", default: "Your VO2 Max of %@ mL/kg/min is average for someone around age %@. VO2 Max is one of the most important signs of long-term fitness and overall health."), vo2, age)
                }
                static func cardioFitnessAgeRecommendation(vo2: String, percentile: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_cardio_fitness_age_recommendation", default: "At %@ mL/kg/min, your heart and lung fitness is higher than about %@ out of 100 middle-aged adults. Every small step up (about 3.5 mL/kg/min) brings real health benefits."), vo2, percentile)
                }

                static func vo2ImprovingSummary(change: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_vo2_improving_summary", default: "Your heart and lung fitness has improved by %@ mL/kg/min over %d months. That is a real gain based on large health studies."), change, months)
                }
                static func vo2ImprovingRecommendation(change: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_vo2_improving_recommendation", default: "A %@ mL/kg/min gain in VO2 Max is real progress. It makes your fitness age younger and goes with better long-term health."), change)
                }

                static func vo2DecliningSummary(absChange: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_vo2_declining_summary", default: "Your heart and lung fitness has dropped by %@ mL/kg/min over %d months. Since VO2 Max is a key fitness sign, this is worth turning around."), absChange, months)
                }
                static func vo2DecliningRecommendation(absChange: String, perMonth: String, months: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_vo2_declining_recommendation", default: "A %@ mL/kg/min drop makes your fitness age older. Losing %@ mL/kg/min per month is faster than normal aging (about 1 to 2 mL/kg/min every 10 years). Doing cardio more often or a bit harder can help turn it around."), absChange, perMonth)
                }

                static func belowThresholdSummary(vo2: String, threshold: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_below_threshold_summary", default: "Your VO2 Max of %@ mL/kg/min is below %d, a level linked to lower fitness at any age."), vo2, threshold)
                }
                static func belowThresholdRecommendation(threshold: Int) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_cardio_respiratory_age_below_threshold_recommendation", default: "A VO2 Max below %d mL/kg/min puts you in the lowest fitness group at any age. Large studies keep showing this level matters for overall health. Even small gains from here can make a real difference."), threshold)
                }
            }

            // MARK: RHR Trajectory

            enum RHRTrajectory {
                static var risingTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_rhr_trajectory_rising_title", default: "Resting Heart Rate Rising") }
                static var improvingTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_rhr_trajectory_improving_title", default: "Resting Heart Rate Improving") }

                static func risingSummary(change: String, windowLabel: String, startRHR: String, currentRHR: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_rhr_trajectory_rising_summary", default: "Your resting heart rate has risen by %@ bpm over the past %@, from %@ to %@ bpm, even though you have not slowed down your activity."), change, windowLabel, startRHR, currentRHR)
                }
                static func risingRecommendation(change: String, windowLabel: String, includeMedicalNote: Bool) -> String {
                    let suffix = includeMedicalNote
                        ? RemoteConfigManager.shared.copyString("copy_analysis_rhr_trajectory_rising_doctor_suffix", default: " Consider discussing this trend with your doctor.")
                        : ""
                    return String(format: RemoteConfigManager.shared.copyString("copy_analysis_rhr_trajectory_rising_recommendation", default: "Large studies show a rising resting heart rate is an important long-term fitness sign. A %@ bpm rise over %@ while staying just as active is worth paying attention to.%@"), change, windowLabel, suffix)
                }

                static func improvingSummary(change: String, windowLabel: String, startRHR: String, currentRHR: String) -> String {
                    String(format: RemoteConfigManager.shared.copyString("copy_analysis_improving_summary", default: "Your resting heart rate has dropped %@ bpm over the past %@, from %@ to %@ bpm. That is a good sign for your heart fitness."), change, windowLabel, startRHR, currentRHR)
                }
                static var improvingRecommendation: String { RemoteConfigManager.shared.copyString("copy_analysis_improving_recommendation", default: "A falling resting heart rate means your heart is working more efficiently. A lower resting heart rate over time goes with better overall fitness and health in large studies.") }
            }
        }

        // MARK: - Historical

        enum Historical {
            static func yearOverYear(metric: String, change: String, comparison: String, month: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_historical_year_over_year", default: "%@ %@%% %@ Than Last %@"), metric, change, comparison, month)
            }
            static func nearAllTime(metric: String, extreme: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_historical_near_all_time", default: "%@ Near All-Time %@"), metric, extreme)
            }
            static func seasonalComparison(metric: String, comparison: String, month: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_historical_seasonal_comparison", default: "%@ %@ %@ Average"), metric, comparison, month)
            }
            static func longTermTrajectory(metric: String, direction: String, change: String, period: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_historical_long_term_trajectory", default: "%@ %@ %@%% Over %@"), metric, direction, change, period)
            }
            static func rarityTitle(metric: String, months: Int, extreme: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_historical_rarity_title", default: "%@ at %d-Month %@"), metric, months, extreme)
            }

            // Recommendations
            static var betterShapeLongTerm: String { RemoteConfigManager.shared.copyString("copy_analysis_better_shape_long_term", default: "You are in better shape this year. Things are heading in the right direction.") }
            static var exceptionalPersonalBest: String { RemoteConfigManager.shared.copyString("copy_analysis_exceptional_personal_best", default: "This is your best ever. Whatever you are doing, keep it up.") }
            static var rareLevelMayWarrantAttention: String { RemoteConfigManager.shared.copyString("copy_analysis_rare_level_may_warrant_attention", default: "This is rare for you. If it stays this way for more than a few days, it is worth a closer look.") }
            static var outperformingSeasonalNorm: String { RemoteConfigManager.shared.copyString("copy_analysis_outperforming_seasonal_norm", default: "You are doing better than usual for this time of year. That is solid progress.") }
            static var longTermImprovementReliable: String { RemoteConfigManager.shared.copyString("copy_analysis_long_term_improvement_reliable", default: "Your long-term trend is positive. A few bad days do not erase months of good progress.") }
            static var sustainedDeclineStructural: String { RemoteConfigManager.shared.copyString("copy_analysis_sustained_decline_structural", default: "This has been going down for a while. If it continues, it is worth a closer look.") }
            static var unusualValuesMonitor: String { RemoteConfigManager.shared.copyString("copy_analysis_unusual_values_monitor", default: "One bad day does not mean much. If this lasts a few days, take a closer look.") }
        }

        // MARK: - Circadian Analyzer (lifted from CircadianHealthAnalyzer.swift)

        enum Circadian {
            static func alignmentTitle(level: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_alignment_title", default: "Your body clock is %@"), level)
            }
            static var levelExcellent: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_level_excellent", default: "excellent") }
            static var levelGood: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_level_good", default: "good") }
            static var levelStrong: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_level_strong", default: "strong") }
            static var levelModerate: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_level_moderate", default: "moderate") }
            static var levelDisrupted: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_level_disrupted", default: "disrupted") }
            static var alignmentRecDisrupted: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_alignment_rec_disrupted", default: "Strengthen your body clock by keeping steady sleep and wake times and getting morning daylight.") }
            static var alignmentRecAligned: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_alignment_rec_aligned", default: "Your body clock is well in sync. Keep up your steady daily routine.") }
            static func socialJetLagTitle(hours: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_social_jet_lag_title", default: "Weekend sleep shift: %@h"), hours)
            }
            static func socialJetLagSummary(hours: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_social_jet_lag_summary", default: "Your sleep time shifts %@ hours on weekends compared to weekdays."), hours)
            }
            static var socialJetLagRec: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_social_jet_lag_rec", default: "Try keeping weekend wake times within 1 hour of weekdays to keep your body clock steady.") }
            static var irregularPatternTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_irregular_pattern_title", default: "Irregular sleep pattern detected") }
            static func irregularPatternSummary(sri: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_irregular_pattern_summary", default: "Your sleep steadiness score is %d/100."), sri)
            }
            static var irregularPatternRec: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_irregular_pattern_rec", default: "Aim for steady bed and wake times. Irregular sleep is linked to body and mood problems.") }
            static var fragmentedRhythmTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_fragmented_rhythm_title", default: "Your activity is scattered through the day") }
            static func fragmentedRhythmSummary(iv: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_fragmented_rhythm_summary", default: "Your daily activity is spread out in scattered bursts (score: %@)."), iv)
            }
            static var fragmentedRhythmRec: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_fragmented_rhythm_rec", default: "Being active in steadier stretches during the day supports a healthier body clock.") }
            static var strongRhythmTitle: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_strong_rhythm_title", default: "Your daily rhythm is strong and consistent") }
            static func strongRhythmSummary(stabilityPct: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_circadian_strong_rhythm_summary", default: "Your day-to-day routine is very steady (%d%%) with strong active periods."), stabilityPct)
            }
            static var strongRhythmRec: String { RemoteConfigManager.shared.copyString("copy_analysis_circadian_strong_rhythm_rec", default: "This pattern goes with better body health and steadier mood. Keep it up.") }
        }

        // MARK: - Sleep Performance Analyzer (lifted from SleepPerformanceAnalyzer.swift)

        enum SleepPerformance {
            static func goodSleepBoostSummary(metricName: String, percent: String, avgGood: String, avgPoor: String, unit: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_perf_good_sleep_boost_summary", default: "Good sleep (7+ hrs) lifts your next-day %@ by %@%%, averaging %@ %@ vs %@ on shorter nights."), metricName, percent, avgGood, unit, avgPoor)
            }
            static func goodSleepBoostRec(percent: String, metricName: String, avgGood: String, unit: String, avgPoor: String, totalNights: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_perf_good_sleep_boost_rec", default: "Your data shows a %@%% difference in next-day %@ between 7+ hr sleep nights (%@ %@) and <6 hr nights (%@ %@) across %d measured nights."), percent, metricName, avgGood, unit, avgPoor, unit, totalNights)
            }
            static func qualitySleepCaloriesSummary(diff: String, comparator: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_perf_quality_sleep_calories_summary", default: "High-quality sleep nights (>30%% deep+REM) lead to %@%% %@ active calories the next day."), diff, comparator)
            }
            static func qualitySleepCaloriesRec(diff: String, direction: String, avgHigh: String, avgLow: String, totalNights: Int) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_sleep_perf_quality_sleep_calories_rec", default: "Nights with >30%% deep+REM correlate with %@%% %@ next-day active calories (%@ vs %@ kcal) across %d measured nights."), diff, direction, avgHigh, avgLow, totalNights)
            }
            static var directionMore: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_perf_direction_more", default: "more") }
            static var directionFewer: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_perf_direction_fewer", default: "fewer") }
            static var directionHigher: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_perf_direction_higher", default: "higher") }
            static var directionLower: String { RemoteConfigManager.shared.copyString("copy_analysis_sleep_perf_direction_lower", default: "lower") }
        }

        // MARK: - Weekly Pattern Analyzer (lifted from WeeklyPatternAnalyzer.swift)

        enum WeeklyPatternAnalyzer {
            static func weakestDayTitle(name: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_weakest_day_title", default: "Weakest Day: %@"), name)
            }
            static func weakestDaySummary(weakestName: String, weakestAvg: String, deficit: String, strongestName: String, strongestAvg: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_weakest_day_summary", default: "%@ is your least active day with %@ avg. %@%% below your daily average. %@ is your strongest (%@)."), weakestName, weakestAvg, deficit, strongestName, strongestAvg)
            }
            static func weakestDayRec(weakestName: String, weakestAvg: String, deficit: String, overallAvg: String, strongestName: String, strongestAvg: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_weakest_day_rec", default: "%@ averages %@. %@%% below your daily mean of %@. Your strongest day is %@ at %@."), weakestName, weakestAvg, deficit, overallAvg, strongestName, strongestAvg)
            }
            static func weekdayWeekendTitle(metricName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_weekday_weekend_title", default: "%@: Weekday vs Weekend"), metricName)
            }
            static func weekdayWeekendSummary(label: String, gap: String, moreActive: String, weekdayAvg: String, weekendAvg: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_weekday_weekend_summary", default: "Your %@ is %@%% higher on %@. Weekday avg: %@, weekend avg: %@."), label, gap, moreActive, weekdayAvg, weekendAvg)
            }
            static var moreActiveWeekdays: String { RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_more_active_weekdays", default: "weekdays") }
            static var moreActiveWeekends: String { RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_more_active_weekends", default: "weekends") }
            static func weekdayWeekendRecBig(label: String, weekendAvg: String, weekdayAvg: String, gap: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_weekday_weekend_rec_big", default: "Weekend %@ averages %@ vs %@ on weekdays. A %@%% gap."), label, weekendAvg, weekdayAvg, gap)
            }
            static func weekdayWeekendRecSmall(weekdayAvg: String, weekendAvg: String, gap: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_weekday_weekend_rec_small", default: "Weekday avg: %@, weekend avg: %@. %@%% difference."), weekdayAvg, weekendAvg, gap)
            }
            static func consistencyTitle(metricName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_consistency_title", default: "%@ Consistency"), metricName)
            }
            static func cyclePhaseTitle(phaseName: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_weekly_pattern_cycle_phase_title", default: "Cycle Phase Analyzer: %@"), phaseName)
            }
        }

        // MARK: - Workout Effectiveness Analyzer (lifted from WorkoutEffectivenessAnalyzer.swift)

        enum WorkoutEffectiveness {
            static func consistencySummary(consistencyPct: Int, weeklyAvg: String, breakdown: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_workout_effectiveness_consistency_summary", default: "%d%% of the last 4 weeks had 3+ workout days (avg %@/week). Breakdown: %@."), consistencyPct, weeklyAvg, breakdown)
            }
            static func vo2MaxChangeSummary(direction: String, change: String, olderAvg: String, recentAvg: String, unit: String, weeklyProgression: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_workout_effectiveness_vo2_max_change_summary", default: "Your VO2 Max %@ %@%% over the last 30 days (%@ → %@ %@).%@"), direction, change, olderAvg, recentAvg, unit, weeklyProgression)
            }
            static func efficiencySummary(efficiency7d: String, efficiency30d: String, sign: String, change: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_workout_effectiveness_efficiency_summary", default: "You are burning %@ kcal/min this week vs %@ kcal/min over 30 days (%@%@%%)."), efficiency7d, efficiency30d, sign, change)
            }
            static func consistencyRecHigh(consistencyPct: Int, weeklyAvg: String, breakdown: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_workout_effectiveness_consistency_rec_high", default: "%d%% of weeks hit 3+ sessions at %@ avg/week. Breakdown: %@."), consistencyPct, weeklyAvg, breakdown)
            }
            static func consistencyRecLow(weeklyAvg: String, weeksWithTarget: Int, breakdown: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_workout_effectiveness_consistency_rec_low", default: "Your weekly average is %@ sessions. %d of the last 4 weeks reached 3+ workout days. Breakdown: %@."), weeklyAvg, weeksWithTarget, breakdown)
            }
            static var directionImproved: String { RemoteConfigManager.shared.copyString("copy_analysis_workout_effectiveness_dir_improved", default: "improved") }
            static var directionDecreased: String { RemoteConfigManager.shared.copyString("copy_analysis_workout_effectiveness_dir_decreased", default: "decreased") }
        }

        // MARK: - Clinical Intelligence (lifted from ClinicalIntelligence.swift)

        enum ClinicalSentences {
            static func systolicTrendSummary(slopePerMonth: String, recentDays: Int, currentStage: String, nextStageInfo: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_clinical_systolic_trend_summary", default: "Your top blood pressure number has risen %@ mmHg per month over the past %d days. Right now it is in the %@ range. You can still turn this around with everyday habits. %@"), slopePerMonth, recentDays, currentStage, nextStageInfo)
            }
            static func glucoseTrendSummary(slopePerMonth: String, latest: String, currentStage: String, nextInfo: String) -> String {
                String(format: RemoteConfigManager.shared.copyString("copy_analysis_clinical_glucose_trend_summary", default: "Your fasting blood sugar has been rising %@ mg/dL per month. Now: %@ mg/dL (%@). %@"), slopePerMonth, latest, currentStage, nextInfo)
            }
        }
    }
}
