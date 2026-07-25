import Foundation

#if DEBUG
/// Premium showcase mock data, a thriving post-purchase user profile used to
/// render the App Store screenshots. Only consumed when both
/// `--ui-test-mode` and `--ui-test-premium-showcase` launch flags are passed.
/// DEBUG-only: never compiled into Release builds (App Store distribution).
struct PremiumShowcaseDataProvider {

    static func generateAllTimeSeries(days: Int = 90) -> [HealthMetric: MetricTimeSeries] {
        var result: [HealthMetric: MetricTimeSeries] = [:]
        for metric in HealthMetric.allCases {
            result[metric] = generateTimeSeries(for: metric, days: days)
        }
        return result
    }

    static func generateTimeSeries(for metric: HealthMetric, days: Int = 90) -> MetricTimeSeries {
        let samples = (0..<days).compactMap { dayOffset -> MetricSample? in
            let date = Date().daysAgo(days - dayOffset)
            let value = generateValue(for: metric, dayIndex: dayOffset, totalDays: days)
            guard value > 0 else { return nil }
            return MetricSample(date: date, value: value)
        }
        return MetricTimeSeries(metric: metric, samples: samples)
    }

    private static func generateValue(for metric: HealthMetric, dayIndex: Int, totalDays: Int) -> Double {
        let progress = Double(dayIndex) / Double(totalDays)
        let noise = Double.random(in: -0.02...0.02)

        switch metric {
        case .heartRate:
            return 68 + sin(progress * .pi * 4) * 3 + noise * 68
        case .restingHeartRate:
            return 56 - progress * 2 + noise * 56
        case .heartRateVariability:
            return 58 + progress * 8 + noise * 58
        case .walkingHeartRateAverage:
            return 92 + sin(progress * .pi * 2) * 2 + noise * 92
        case .heartRateRecovery:
            return 32 + progress * 4 + noise * 32
        case .atrialFibrillationBurden:
            return 0.05 + abs(noise) * 0.05
        case .peripheralPerfusionIndex:
            return 3.2 + noise * 0.3
        case .bloodOxygen:
            return 98 + abs(noise)
        case .sleepDuration:
            return 7.6 + sin(progress * .pi * 6) * 0.25 + noise * 0.5
        case .sleepREM:
            return 1.9 + noise * 0.2
        case .sleepDeep:
            return 1.6 + noise * 0.2
        case .sleepCore:
            return 3.8 + noise * 0.3
        case .sleepAwake:
            return 0.18 + abs(noise) * 0.08
        case .steps:
            let base = 11500.0 + progress * 800
            let weekend = dayIndex % 7 >= 5 ? -1200.0 : 0
            return base + weekend + noise * 1500
        case .activeCalories:
            return 580 + progress * 40 + noise * 80
        case .basalCalories:
            return 1680 + noise * 30
        case .exerciseMinutes:
            return 52 + progress * 8 + noise * 15
        case .standHours:
            return 12 + abs(noise) * 1
        case .distanceWalkingRunning:
            return 7.8 + progress * 0.4 + noise * 1.5
        case .flightsClimbed:
            return 14 + abs(noise) * 4
        case .distanceCycling:
            return dayIndex % 3 == 0 ? 18 + noise * 4 : 0
        case .distanceSwimming:
            return dayIndex % 4 == 0 ? 1.8 + noise * 0.3 : 0
        case .swimmingStrokeCount:
            return dayIndex % 4 == 0 ? 1100 + noise * 150 : 0
        case .appleMoveTime:
            return 60 + progress * 10 + noise * 12
        case .walkingSpeed:
            return 5.6 + noise * 0.2
        case .walkingStepLength:
            return 76 + noise * 2
        case .walkingAsymmetry:
            return 4 + abs(noise) * 1.5
        case .walkingDoubleSupportPercentage:
            return 24 + abs(noise) * 1.5
        case .stairAscentSpeed:
            return 1.4 + noise * 0.1
        case .stairDescentSpeed:
            return 1.3 + noise * 0.1
        case .sixMinuteWalkTestDistance:
            return 580 + progress * 25 + noise * 25
        case .weight:
            return 76 - progress * 1.2 + noise * 0.3
        case .bmi:
            return 23.2 - progress * 0.2 + noise * 0.1
        case .bodyFatPercentage:
            return 16 - progress * 0.5 + noise * 0.3
        case .bloodPressureSystolic:
            return 116 + noise * 3
        case .bloodPressureDiastolic:
            return 72 + noise * 2
        case .respiratoryRate:
            return 14 + noise * 1
        case .bodyTemperature:
            return 36.6 + noise * 0.2
        case .appleSleepingWristTemperature:
            return noise * 0.15
        case .leanBodyMass:
            return 64 + progress * 1.5 + noise * 0.4
        case .waistCircumference:
            return 80 - progress * 1 + noise * 0.4
        case .vo2Max:
            return 48 + progress * 3 + noise * 48
        case .peakExpiratoryFlowRate:
            return 540 + noise * 25
        case .forcedVitalCapacity:
            return 4.6 + noise * 0.2
        case .mindfulMinutes:
            return 18 + progress * 6 + noise * 6
        case .timeInDaylight:
            return 75 + sin(progress * .pi * 2) * 12 + noise * 12
        case .electrodermalActivity:
            return 4 + noise * 1
        case .workoutCount:
            return dayIndex % 7 == 6 ? 0 : 1
        case .waterIntake:
            return 2600 + sin(progress * .pi * 2) * 250 + noise * 400
        case .bloodGlucose:
            return 88 + sin(progress * .pi * 3) * 6 + noise * 10
        case .workoutDuration:
            return dayIndex % 7 == 6 ? 0 : 48 + noise * 12
        default:
            return 0
        }
    }

    static func generateBaselines() -> [HealthMetric: UserBaseline] {
        var baselines: [HealthMetric: UserBaseline] = [:]
        for metric in HealthMetric.allCases {
            let series = generateTimeSeries(for: metric, days: 60)
            let values = series.values
            guard !values.isEmpty else { continue }
            baselines[metric] = UserBaseline(
                metric: metric,
                mean: values.mean,
                standardDeviation: values.standardDeviation,
                median: values.median,
                sampleCount: values.count
            )
        }
        return baselines
    }

    static func generateSampleInsights() -> [Insight] {
        [
            Insight(
                metric: .heartRateVariability,
                title: "HRV Trending Up",
                summary: "Your heart rate variability has climbed 14% over the past 30 days. Autonomic recovery is strong.",
                recommendation: "Keep your current routine. Sleep, mindfulness, and consistent training are paying off.",
                severity: .info,
                trend: .improving,
                baselineValue: 54,
                deviationPercent: 14.8
            ),
            Insight(
                metric: .sleepDuration,
                title: "12-Day Sleep Streak",
                summary: "You've slept 7.5+ hours for 12 consecutive nights. Your debt is fully cleared.",
                recommendation: "Hold your bedtime anchor. Consistency is the single biggest driver of recovery.",
                severity: .info,
                trend: .improving,
                baselineValue: 4,
                deviationPercent: 200
            ),
            Insight(
                metric: .vo2Max,
                title: "Cardiovascular Fitness Peak",
                summary: "Your VO2 Max is 50, top decile for your age group, up 8% in 90 days.",
                recommendation: "Add one tempo session per week to push toward elite range.",
                severity: .info,
                trend: .improving,
                baselineValue: 46,
                deviationPercent: 8.7
            ),
            Insight(
                metric: .restingHeartRate,
                title: "Resting Heart Rate at New Low",
                summary: "RHR is 54 bpm, down 6 bpm from your 90-day baseline. Cardiac efficiency is high.",
                recommendation: "Excellent. Continue prioritizing zone 2 work and recovery sleep.",
                severity: .info,
                trend: .improving,
                baselineValue: 60,
                deviationPercent: -10
            ),
            Insight(
                metric: .steps,
                title: "Activity Goal Cleared",
                summary: "You averaged 11,800 steps a day this week, 38% above your target.",
                recommendation: "Hold this baseline. Weekly distance correlates with longer healthspan.",
                severity: .info,
                trend: .improving,
                baselineValue: 8500,
                deviationPercent: 38.8
            ),
            Insight(
                metric: .sleepDuration,
                title: "Sleep to Next-Day HRV",
                summary: "When you sleep 7.5+ hours, your next-day HRV is 22% higher. Correlation r=0.71.",
                recommendation: "Your sleep is the biggest lever for your recovery. Protect it.",
                severity: .info,
                trend: .stable,
                baselineValue: 0,
                deviationPercent: 71,
                category: .correlation,
            ),
            Insight(
                metric: .heartRateVariability,
                title: "Post-Workout Recovery: 1.2 Days",
                summary: "Your HRV returns to baseline in 1.2 days after workouts. Excellent recovery rate.",
                recommendation: "Your conditioning supports a higher training load if you want to push.",
                severity: .info,
                trend: .improving,
                baselineValue: 2.0,
                deviationPercent: -40,
                category: .recovery,
            ),
            Insight(
                metric: .workoutDuration,
                title: "8-Week Training Streak",
                summary: "You've trained 5+ days a week for 8 consecutive weeks. You're in the top 5% of users.",
                recommendation: "Add a deload week every 4 to 6 weeks to lock in adaptation.",
                severity: .info,
                trend: .improving,
                baselineValue: 3,
                deviationPercent: 166,
                category: .workoutEffectiveness,
            ),
            Insight(
                metric: .steps,
                title: "14-Day 10K+ Steps Streak",
                summary: "You've cleared 10,000 steps for 14 days running. Personal best.",
                recommendation: "Keep going. 21 days locks in the habit loop.",
                severity: .info,
                trend: .improving,
                baselineValue: 6,
                deviationPercent: 133,
                category: .personalRecord,
            ),
            Insight(
                metric: .mindfulMinutes,
                title: "Mindfulness Habit Locked",
                summary: "18 minutes a day for 4 straight weeks. Your stress markers reflect it.",
                recommendation: "Consider extending one weekly session to 30 minutes for deeper benefits.",
                severity: .info,
                trend: .improving,
                baselineValue: 8,
                deviationPercent: 125,
                category: .personalRecord,
            ),
        ]
    }

    static func generateSampleRisks() -> [HealthRisk] {
        [
            HealthRisk(
                riskType: .cardiac,
                level: 12,
                factors: [
                    RiskFactor(metric: .restingHeartRate, contribution: 5, status: .optimal, currentValue: 54, optimalRange: "40 to 80 bpm", explanation: "RHR is 54 bpm, well within optimal range."),
                    RiskFactor(metric: .heartRateVariability, contribution: 5, status: .optimal, currentValue: 62, optimalRange: "20 to 100 ms", explanation: "HRV is 62 ms, strong and trending up."),
                    RiskFactor(metric: .bloodPressureSystolic, contribution: 5, status: .optimal, currentValue: 116, optimalRange: "90 to 130 mmHg", explanation: "Systolic BP is 116 mmHg, healthy."),
                    RiskFactor(metric: .bloodPressureDiastolic, contribution: 5, status: .optimal, currentValue: 72, optimalRange: "60 to 85 mmHg", explanation: "Diastolic BP is 72 mmHg, healthy."),
                    RiskFactor(metric: .heartRateRecovery, contribution: 5, status: .optimal, currentValue: 34, optimalRange: "12 to 50 bpm", explanation: "HR recovery is 34 bpm, excellent."),
                    RiskFactor(metric: .atrialFibrillationBurden, contribution: 5, status: .optimal, currentValue: 0.05, optimalRange: "0 to 1 %", explanation: "AFib burden is 0.05%, normal."),
                ],
                focusAreas: [
                    FocusArea(title: "Maintain Your Edge", description: "Your cardiac markers are in elite territory. Keep zone 2 work and one tempo session per week.", impact: .low, metric: .heartRateVariability, targetDescription: "Target: HRV 60+ ms")
                ]
            ),
            HealthRisk(
                riskType: .sleepDeficit,
                level: 8,
                factors: [
                    RiskFactor(metric: .sleepDuration, contribution: 5, status: .optimal, currentValue: 7.6, optimalRange: "6 to 9 hrs", explanation: "Sleep duration is 7.6 hrs, on target."),
                    RiskFactor(metric: .sleepDeep, contribution: 5, status: .optimal, currentValue: 1.6, optimalRange: "0.8 to 2 hrs", explanation: "Deep sleep is 1.6 hrs, healthy."),
                    RiskFactor(metric: .sleepREM, contribution: 5, status: .optimal, currentValue: 1.9, optimalRange: "0.8 to 2.5 hrs", explanation: "REM sleep is 1.9 hrs, optimal."),
                    RiskFactor(metric: .sleepAwake, contribution: 5, status: .optimal, currentValue: 0.2, optimalRange: "0 to 1 hrs", explanation: "Awake time is 12 min, low."),
                    RiskFactor(metric: .sleepCore, contribution: 5, status: .optimal, currentValue: 3.8, optimalRange: "2 to 5 hrs", explanation: "Core sleep is 3.8 hrs, healthy."),
                ],
                focusAreas: [
                    FocusArea(title: "Protect Your Bedtime Anchor", description: "You've held a consistent bedtime for 12 nights. Keep the same wake time on weekends.", impact: .low, metric: .sleepDuration, targetDescription: "Target: 7 to 9 hours")
                ]
            ),
            HealthRisk(
                riskType: .stress,
                level: 14,
                factors: [
                    RiskFactor(metric: .heartRateVariability, contribution: 5, status: .optimal, currentValue: 62, optimalRange: "20 to 100 ms", explanation: "HRV is 62 ms, low stress load."),
                    RiskFactor(metric: .restingHeartRate, contribution: 5, status: .optimal, currentValue: 54, optimalRange: "40 to 80 bpm", explanation: "RHR low, stress signature absent."),
                    RiskFactor(metric: .sleepDuration, contribution: 5, status: .optimal, currentValue: 7.6, optimalRange: "6 to 9 hrs", explanation: "Recovery sleep on target."),
                    RiskFactor(metric: .mindfulMinutes, contribution: 5, status: .optimal, currentValue: 18, optimalRange: "5 to 60 min", explanation: "18 min of mindfulness daily."),
                    RiskFactor(metric: .respiratoryRate, contribution: 5, status: .optimal, currentValue: 14, optimalRange: "12 to 20 br/min", explanation: "Respiratory rate is 14, normal."),
                ],
                focusAreas: [
                    FocusArea(title: "Lock In the Habit", description: "Your mindfulness practice is doing the work. Consider extending one session per week.", impact: .low, metric: .mindfulMinutes, targetDescription: "Target: 15+ min daily")
                ]
            ),
            HealthRisk(
                riskType: .metabolic,
                level: 10,
                factors: [
                    RiskFactor(metric: .bmi, contribution: 5, status: .optimal, currentValue: 23.0, optimalRange: "18.5 to 25", explanation: "BMI is 23.0, healthy range."),
                    RiskFactor(metric: .bodyFatPercentage, contribution: 5, status: .optimal, currentValue: 15.5, optimalRange: "8 to 30 %", explanation: "Body fat is 15.5%, healthy."),
                    RiskFactor(metric: .steps, contribution: 5, status: .optimal, currentValue: 11800, optimalRange: "5000 to 15000 steps", explanation: "11.8k steps a day, well above target."),
                    RiskFactor(metric: .activeCalories, contribution: 5, status: .optimal, currentValue: 600, optimalRange: "200 to 800 kcal", explanation: "Active calories at 600, strong."),
                    RiskFactor(metric: .weight, contribution: 5, status: .optimal, currentValue: 75, optimalRange: "45 to 130 kg", explanation: "Weight is 75 kg, stable."),
                ],
                focusAreas: [
                    FocusArea(title: "Maintain Movement Volume", description: "Your daily volume is in elite territory. Hold this baseline.", impact: .low, metric: .steps, targetDescription: "Target: 10,000+ steps")
                ]
            ),
        ]
    }

    static func generateSampleScores() -> (overall: HealthScore, categories: [HealthScore]) {
        let heart = HealthScore(category: .heart, score: 91, breakdown: [
            ScoreComponent(metric: .restingHeartRate, points: 8, reason: "RHR at 90-day low"),
            ScoreComponent(metric: .heartRateVariability, points: 12, reason: "HRV climbing"),
        ])
        let sleep = HealthScore(category: .sleep, score: 92, breakdown: [
            ScoreComponent(metric: .sleepDuration, points: 10, reason: "7.6h average"),
            ScoreComponent(metric: .sleepDeep, points: 8, reason: "Deep sleep on target"),
        ])
        let activity = HealthScore(category: .activity, score: 94, breakdown: [
            ScoreComponent(metric: .steps, points: 15, reason: "11.8k daily"),
            ScoreComponent(metric: .exerciseMinutes, points: 8, reason: "52 min daily"),
        ])
        let body = HealthScore(category: .body, score: 95, breakdown: [
            ScoreComponent(metric: .weight, points: 5, reason: "Stable, on target"),
        ])
        let respiratory = HealthScore(category: .respiratory, score: 93, breakdown: [
            ScoreComponent(metric: .vo2Max, points: 12, reason: "Top decile"),
            ScoreComponent(metric: .bloodOxygen, points: 5, reason: "Optimal"),
        ])
        let mindfulness = HealthScore(category: .mindfulness, score: 86, breakdown: [
            ScoreComponent(metric: .mindfulMinutes, points: 10, reason: "18 min daily"),
            ScoreComponent(metric: .timeInDaylight, points: 5, reason: "75 min outdoor"),
        ])
        let mobility = HealthScore(category: .mobility, score: 94, breakdown: [
            ScoreComponent(metric: .walkingSpeed, points: 5, reason: "5.6 km/h"),
            ScoreComponent(metric: .sixMinuteWalkTestDistance, points: 8, reason: "580m, high"),
        ])

        let categories = [heart, sleep, activity, body, respiratory, mindfulness, mobility]
        let overallScore = categories.map(\.score).reduce(0, +) / categories.count
        let overall = HealthScore(score: overallScore)

        return (overall, categories)
    }
}
#endif
