import Foundation

#if DEBUG
/// Provides realistic mock data for SwiftUI previews and simulator testing.
/// DEBUG-only: never compiled into Release builds (App Store distribution).
struct SampleDataProvider {

    /// Generate sample time series data for all metrics
    static func generateAllTimeSeries(days: Int = 90) -> [HealthMetric: MetricTimeSeries] {
        var result: [HealthMetric: MetricTimeSeries] = [:]
        for metric in HealthMetric.allCases {
            result[metric] = generateTimeSeries(for: metric, days: days)
        }
        return result
    }

    /// Generate a realistic time series for a specific metric
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
        let noise = Double.random(in: -0.05...0.05)

        switch metric {
        case .heartRate:
            return 72 + sin(progress * .pi * 4) * 5 + noise * 72
        case .restingHeartRate:
            // Slight improvement trend
            return 65 - progress * 3 + noise * 65
        case .heartRateVariability:
            return 42 + progress * 5 + noise * 42
        case .walkingHeartRateAverage:
            return 98 + sin(progress * .pi * 2) * 3 + noise * 98
        case .heartRateRecovery:
            return 25 + progress * 3 + noise * 25
        case .atrialFibrillationBurden:
            return 0.3 + noise * 0.2
        case .peripheralPerfusionIndex:
            return 2.5 + noise * 1.0
        case .bloodOxygen:
            return 97 + noise * 2
        case .sleepDuration:
            return 7.2 + sin(progress * .pi * 6) * 0.8 + noise * 2
        case .sleepREM:
            return 1.5 + noise * 0.5
        case .sleepDeep:
            return 1.2 + noise * 0.4
        case .sleepCore:
            return 3.5 + noise * 0.8
        case .sleepAwake:
            return 0.5 + abs(noise) * 0.3
        case .steps:
            let base = 8500.0 + progress * 1000
            let weekend = dayIndex % 7 >= 5 ? -2000.0 : 0
            return base + weekend + noise * 2000
        case .activeCalories:
            return 450 + progress * 50 + noise * 100
        case .basalCalories:
            return 1650 + noise * 50
        case .exerciseMinutes:
            return 35 + progress * 10 + noise * 20
        case .standHours:
            return 10 + noise * 3
        case .distanceWalkingRunning:
            return 5.5 + progress * 0.5 + noise * 2
        case .flightsClimbed:
            return 8 + noise * 5
        case .distanceCycling:
            return dayIndex % 3 == 0 ? 12 + noise * 5 : 0
        case .distanceSwimming:
            return dayIndex % 4 == 0 ? 1.5 + noise * 0.5 : 0
        case .swimmingStrokeCount:
            return dayIndex % 4 == 0 ? 800 + noise * 200 : 0
        case .appleMoveTime:
            return 45 + progress * 10 + noise * 15
        case .walkingSpeed:
            return 5.2 + noise * 0.3
        case .walkingStepLength:
            return 72 + noise * 3
        case .walkingAsymmetry:
            return 8 + noise * 3
        case .walkingDoubleSupportPercentage:
            return 28 + noise * 3
        case .stairAscentSpeed:
            return 1.2 + noise * 0.2
        case .stairDescentSpeed:
            return 1.1 + noise * 0.2
        case .sixMinuteWalkTestDistance:
            return 520 + progress * 20 + noise * 30
        case .weight:
            return 78 - progress * 2 + noise * 0.5
        case .bmi:
            return 24.5 - progress * 0.5 + noise * 0.2
        case .bodyFatPercentage:
            return 18 - progress * 1 + noise * 0.5
        case .bloodPressureSystolic:
            return 122 + noise * 5
        case .bloodPressureDiastolic:
            return 78 + noise * 3
        case .respiratoryRate:
            return 15 + noise * 2
        case .bodyTemperature:
            return 36.6 + noise * 0.3
        case .appleSleepingWristTemperature:
            return 0.1 + noise * 0.3
        case .leanBodyMass:
            return 62 + progress * 1 + noise * 0.5
        case .waistCircumference:
            return 85 - progress * 1 + noise * 0.5
        case .vo2Max:
            return 38 + progress * 2 + noise * 38
        case .peakExpiratoryFlowRate:
            return 480 + noise * 30
        case .forcedVitalCapacity:
            return 4.2 + noise * 0.3
        case .mindfulMinutes:
            return 15 + progress * 5 + noise * 8
        case .timeInDaylight:
            return 45 + sin(progress * .pi * 2) * 15 + noise * 15
        case .electrodermalActivity:
            return 5 + noise * 2
        case .workoutCount:
            return dayIndex % 2 == 0 ? 1 : 0
        case .waterIntake:
            return 2200 + sin(progress * .pi * 2) * 300 + noise * 500
        case .bloodGlucose:
            return 95 + sin(progress * .pi * 3) * 10 + noise * 15
        case .workoutDuration:
            return dayIndex % 2 == 0 ? 45 + noise * 15 : 0
        default:
            return 0
        }
    }

    // MARK: - Sample Baselines

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

    // MARK: - Sample Insights

    static func generateSampleInsights() -> [Insight] {
        var insights: [Insight] = [
            Insight(
                metric: .restingHeartRate,
                title: "Resting Heart Rate Elevated",
                summary: "Your resting heart rate has been 8% above your baseline for the past 3 days.",
                recommendation: "Consider reducing caffeine intake and ensuring 7-8 hours of sleep. If this persists, you may want to speak with a healthcare provider.",
                severity: .warning,
                trend: .declining,
                baselineValue: 65,
                deviationPercent: 7.7
            ),
            Insight(
                metric: .vo2Max,
                title: "VO2 Max Improving",
                summary: "Your cardiovascular fitness has improved 5% over the past 30 days.",
                recommendation: "Keep up your current exercise routine! Consider adding interval training for further gains.",
                severity: .info,
                trend: .improving,
                baselineValue: 38,
                deviationPercent: 5.3
            ),
            Insight(
                metric: .sleepDuration,
                title: "Sleep Duration Below Target",
                summary: "You averaged 6.2 hours of sleep this week, 14% below your baseline of 7.2 hours.",
                recommendation: "Set a consistent bedtime 30 minutes earlier. Avoid screens 1 hour before bed.",
                severity: .warning,
                trend: .declining,
                baselineValue: 7.2,
                deviationPercent: -13.9
            ),
            Insight(
                metric: .steps,
                title: "Step Count Trending Up",
                summary: "Your daily steps increased 12% this week compared to last week.",
                recommendation: "Great progress! Try to maintain 10,000+ steps daily for optimal cardiovascular health.",
                severity: .info,
                trend: .improving,
                baselineValue: 8500,
                deviationPercent: 11.8
            ),
            Insight(
                metric: .heartRateVariability,
                title: "HRV Declining",
                summary: "Your heart rate variability dropped 15% this week, indicating increased stress or fatigue.",
                recommendation: "Prioritize recovery: try meditation, gentle yoga, or a rest day. Ensure adequate hydration.",
                severity: .critical,
                trend: .declining,
                baselineValue: 42,
                deviationPercent: -16.7
            ),
        ]
        insights.append(contentsOf: generateSampleAdvancedInsights())
        return insights
    }

    /// Sample insights for the 6 new insight categories
    static func generateSampleAdvancedInsights() -> [Insight] {
        [
            Insight(
                metric: .sleepDuration,
                title: "Sleep Duration → Next-Day HRV",
                summary: "When your sleep duration is above average, your heart rate variability is 22% higher.",
                recommendation: "Pay attention to your sleep duration. it has a positive correlation with your HRV.",
                severity: .info,
                trend: .stable,
                baselineValue: 0,
                deviationPercent: 45,
                category: .correlation,
            ),
            Insight(
                metric: .heartRateVariability,
                title: "Post-Workout HRV Recovery",
                summary: "Your HRV takes an average of 1.8 days to return to baseline after workouts.",
                recommendation: "Your recovery is strong. your body bounces back quickly after workouts.",
                severity: .info,
                trend: .improving,
                baselineValue: 2.0,
                deviationPercent: -10,
                category: .recovery,
            ),
            Insight(
                metric: .workoutDuration,
                title: "Workout Consistency",
                summary: "75% of the last 4 weeks had 3+ workout days. You're averaging 3.5 workouts per week.",
                recommendation: "Excellent consistency! Maintain this routine for long-term fitness gains.",
                severity: .info,
                trend: .improving,
                baselineValue: 75,
                deviationPercent: 0,
                category: .workoutEffectiveness,
            ),
            Insight(
                metric: .sleepDuration,
                title: "Sleep Drives Active Calories",
                summary: "On 7+ hour sleep nights, your next-day active calories are 34% higher (520 vs 388 kcal).",
                recommendation: "Prioritize 7+ hours of sleep to maximize your active calories.",
                severity: .warning,
                trend: .stable,
                baselineValue: 388,
                deviationPercent: 34,
                category: .sleepPerformance,
            ),
            Insight(
                metric: .steps,
                title: "Weakest Day: Sunday",
                summary: "Sunday is your least active day with 5,200 avg steps. 38% below your daily average. Wednesday is your strongest (9,100 steps).",
                recommendation: "Schedule a walk or light activity on Sundays to close the gap.",
                severity: .warning,
                trend: .stable,
                baselineValue: 8400,
                deviationPercent: -38,
                category: .weeklyPattern,
            ),
            Insight(
                metric: .steps,
                title: "5-Day 8K+ Steps Streak",
                summary: "You've hit 8k+ steps for 5 consecutive days. Keep the streak alive!",
                recommendation: "You're building momentum. aim for 7 days to lock in the habit.",
                severity: .info,
                trend: .improving,
                baselineValue: 3,
                deviationPercent: 66.7,
                category: .personalRecord,
            ),
        ]
    }

    // MARK: - Sample Health Risks

    static func generateSampleRisks() -> [HealthRisk] {
        [
            HealthRisk(
                riskType: .cardiac,
                level: 42,
                factors: [
                    RiskFactor(metric: .restingHeartRate, contribution: 35, status: .borderline, currentValue: 72, optimalRange: "40–80 bpm", explanation: "Resting heart rate is 72 bpm, trending upward."),
                    RiskFactor(metric: .heartRateVariability, contribution: 55, status: .concerning, currentValue: 28, optimalRange: "20–100 ms", explanation: "HRV is 28 ms, below optimal and declining."),
                    RiskFactor(metric: .bloodPressureSystolic, contribution: 40, status: .borderline, currentValue: 128, optimalRange: "90–130 mmHg", explanation: "Systolic BP is 128 mmHg, near upper limit."),
                    RiskFactor(metric: .bloodPressureDiastolic, contribution: 15, status: .optimal, currentValue: 78, optimalRange: "60–85 mmHg", explanation: "Diastolic BP is 78 mmHg, within healthy range."),
                    RiskFactor(metric: .heartRateRecovery, contribution: 30, status: .borderline, currentValue: 15, optimalRange: "12–50 bpm", explanation: "HR recovery is 15 bpm, near lower limit."),
                    RiskFactor(metric: .atrialFibrillationBurden, contribution: 5, status: .optimal, currentValue: 0.2, optimalRange: "0–1 %", explanation: "AFib burden is 0.2%, within normal range."),
                ],
                focusAreas: [
                    FocusArea(title: "Improve Heart Rate Variability", description: "HRV reflects autonomic nervous system health. Prioritize sleep quality, practice box breathing (4-4-4-4), and include recovery days.", impact: .high, metric: .heartRateVariability, targetDescription: "Target: 40+ ms (SDNN)"),
                    FocusArea(title: "Manage Blood Pressure", description: "Reduce sodium to <2,300mg/day, exercise 150 min/week, maintain healthy weight.", impact: .medium, metric: .bloodPressureSystolic, targetDescription: "Target: <120/80 mmHg"),
                    FocusArea(title: "Improve Heart Rate Recovery", description: "Better recovery indicates stronger cardiac fitness. Increase cardio frequency.", impact: .medium, metric: .heartRateRecovery, targetDescription: "Target: >12 bpm drop in 1 min"),
                ]
            ),
            HealthRisk(
                riskType: .sleepDeficit,
                level: 38,
                factors: [
                    RiskFactor(metric: .sleepDuration, contribution: 45, status: .concerning, currentValue: 6.1, optimalRange: "6–9 hrs", explanation: "Sleep duration is 6.1 hrs, below recommended."),
                    RiskFactor(metric: .sleepDeep, contribution: 35, status: .borderline, currentValue: 0.9, optimalRange: "0.8–2 hrs", explanation: "Deep sleep is 0.9 hrs, near lower limit."),
                    RiskFactor(metric: .sleepREM, contribution: 25, status: .borderline, currentValue: 1.0, optimalRange: "0.8–2.5 hrs", explanation: "REM sleep is 1.0 hrs, could be better."),
                    RiskFactor(metric: .sleepAwake, contribution: 40, status: .concerning, currentValue: 1.2, optimalRange: "0–1 hrs", explanation: "Awake time is 1.2 hrs, above normal."),
                    RiskFactor(metric: .sleepCore, contribution: 10, status: .optimal, currentValue: 3.5, optimalRange: "2–5 hrs", explanation: "Core sleep is 3.5 hrs, within healthy range."),
                ],
                focusAreas: [
                    FocusArea(title: "Increase Sleep Duration", description: "Set a fixed bedtime 8 hours before your alarm. No screens 1 hour before bed.", impact: .high, metric: .sleepDuration, targetDescription: "Target: 7–9 hours"),
                    FocusArea(title: "Reduce Nighttime Waking", description: "Limit fluids 2 hours before bed, avoid caffeine after noon, use white noise.", impact: .high, metric: .sleepAwake, targetDescription: "Target: <30 min per night"),
                ]
            ),
            HealthRisk(
                riskType: .stress,
                level: 52,
                factors: [
                    RiskFactor(metric: .heartRateVariability, contribution: 55, status: .concerning, currentValue: 28, optimalRange: "20–100 ms", explanation: "HRV is 28 ms, indicating high stress load."),
                    RiskFactor(metric: .restingHeartRate, contribution: 30, status: .borderline, currentValue: 72, optimalRange: "40–80 bpm", explanation: "Elevated RHR correlates with stress."),
                    RiskFactor(metric: .sleepDuration, contribution: 40, status: .concerning, currentValue: 6.1, optimalRange: "6–9 hrs", explanation: "Insufficient sleep amplifies stress response."),
                    RiskFactor(metric: .mindfulMinutes, contribution: 50, status: .concerning, currentValue: 3, optimalRange: "5–60 min", explanation: "Only 3 min of mindfulness this week."),
                    RiskFactor(metric: .electrodermalActivity, contribution: 0, status: .unmeasured, currentValue: 0, optimalRange: "0.01–20 μS", explanation: "No recent data available."),
                    RiskFactor(metric: .respiratoryRate, contribution: 15, status: .optimal, currentValue: 15, optimalRange: "12–20 br/min", explanation: "Respiratory rate is 15 br/min, normal."),
                ],
                focusAreas: [
                    FocusArea(title: "Build Mindfulness Practice", description: "Even 5 minutes of daily mindfulness reduces cortisol levels. Morning sessions have the most impact.", impact: .high, metric: .mindfulMinutes, targetDescription: "Target: 10–20 min daily"),
                    FocusArea(title: "Prioritize Recovery Sleep", description: "Sleep is the #1 stress recovery tool. Set a non-negotiable bedtime.", impact: .high, metric: .sleepDuration, targetDescription: "Target: 7–8 hours consistently"),
                    FocusArea(title: "Reduce Chronic Stress", description: "HRV is the most reliable stress biomarker. Try box breathing before bed and time in nature.", impact: .medium, metric: .heartRateVariability, targetDescription: "Target: HRV trending upward"),
                ]
            ),
            HealthRisk(
                riskType: .metabolic,
                level: 18,
                factors: [
                    RiskFactor(metric: .bmi, contribution: 10, status: .optimal, currentValue: 23.5, optimalRange: "18.5–25", explanation: "BMI is 23.5, within healthy range."),
                    RiskFactor(metric: .bodyFatPercentage, contribution: 15, status: .optimal, currentValue: 17, optimalRange: "8–30 %", explanation: "Body fat is 17%, healthy range."),
                    RiskFactor(metric: .steps, contribution: 20, status: .borderline, currentValue: 6500, optimalRange: "5000–15000 steps", explanation: "Steps averaging 6,500, could be higher."),
                    RiskFactor(metric: .activeCalories, contribution: 10, status: .optimal, currentValue: 420, optimalRange: "200–800 kcal", explanation: "Active calories are 420 kcal, good."),
                    RiskFactor(metric: .waistCircumference, contribution: 0, status: .unmeasured, currentValue: 0, optimalRange: "60–102 cm", explanation: "No recent data available."),
                    RiskFactor(metric: .weight, contribution: 10, status: .optimal, currentValue: 74, optimalRange: "45–130 kg", explanation: "Weight is 74 kg, stable."),
                ],
                focusAreas: [
                    FocusArea(title: "Increase Daily Movement", description: "Start with 2,000 more steps than current average. Take walking meetings and post-meal walks.", impact: .medium, metric: .steps, targetDescription: "Target: 8,000–10,000 steps/day"),
                ]
            ),
        ]
    }

    // MARK: - Sample Health Scores

    static func generateSampleScores() -> (overall: HealthScore, categories: [HealthScore]) {
        let heart = HealthScore(category: .heart, score: 78, breakdown: [
            ScoreComponent(metric: .restingHeartRate, points: -10, reason: "Elevated above baseline"),
            ScoreComponent(metric: .heartRateVariability, points: -15, reason: "Declining trend"),
        ])
        let sleep = HealthScore(category: .sleep, score: 68, breakdown: [
            ScoreComponent(metric: .sleepDuration, points: -20, reason: "Below 7 hours average"),
            ScoreComponent(metric: .sleepDeep, points: -10, reason: "Below target"),
        ])
        let activity = HealthScore(category: .activity, score: 88, breakdown: [
            ScoreComponent(metric: .steps, points: 5, reason: "Improving trend"),
            ScoreComponent(metric: .exerciseMinutes, points: -5, reason: "Slightly below target"),
        ])
        let body = HealthScore(category: .body, score: 92, breakdown: [
            ScoreComponent(metric: .weight, points: 5, reason: "Trending toward goal"),
        ])
        let respiratory = HealthScore(category: .respiratory, score: 85, breakdown: [
            ScoreComponent(metric: .vo2Max, points: 5, reason: "Improving trend"),
            ScoreComponent(metric: .bloodOxygen, points: 0, reason: "Within normal range"),
        ])
        let mindfulness = HealthScore(category: .mindfulness, score: 72, breakdown: [
            ScoreComponent(metric: .mindfulMinutes, points: -10, reason: "Below daily target"),
            ScoreComponent(metric: .timeInDaylight, points: -5, reason: "Limited outdoor time"),
        ])
        let mobility = HealthScore(category: .mobility, score: 90, breakdown: [
            ScoreComponent(metric: .walkingSpeed, points: 0, reason: "Stable and healthy"),
            ScoreComponent(metric: .sixMinuteWalkTestDistance, points: 5, reason: "Improving"),
        ])

        let categories = [heart, sleep, activity, body, respiratory, mindfulness, mobility]
        let overallScore = categories.map(\.score).reduce(0, +) / categories.count
        let overall = HealthScore(score: overallScore)

        return (overall, categories)
    }
}
#endif
