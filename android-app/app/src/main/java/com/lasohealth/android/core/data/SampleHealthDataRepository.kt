package com.lasohealth.android.core.data

import com.lasohealth.android.core.model.AchievementUi
import com.lasohealth.android.core.model.AchievementsUiState
import com.lasohealth.android.core.model.ActionCardUi
import com.lasohealth.android.core.model.ActivityUi
import com.lasohealth.android.core.model.AlertSeverity
import com.lasohealth.android.core.model.AlertUi
import com.lasohealth.android.core.model.AnnualReportUiState
import com.lasohealth.android.core.model.AttentionUi
import com.lasohealth.android.core.model.BodyInsightUi
import com.lasohealth.android.core.model.BrainFactorUi
import com.lasohealth.android.core.model.BrainHealthUiState
import com.lasohealth.android.core.model.CategoryDetailUiState
import com.lasohealth.android.core.model.CategoryMetricRow
import com.lasohealth.android.core.model.CategoryMonthUi
import com.lasohealth.android.core.model.CategoryPerformanceUi
import com.lasohealth.android.core.model.CategoryScoreUi
import com.lasohealth.android.core.model.CoachTargetUi
import com.lasohealth.android.core.model.ConnectedDevicesUiState
import com.lasohealth.android.core.model.CorrelationUi
import com.lasohealth.android.core.model.CycleDetailUiState
import com.lasohealth.android.core.model.DayHighlightUi
import com.lasohealth.android.core.model.DecliningTrendUi
import com.lasohealth.android.core.model.DeviceDetailUiState
import com.lasohealth.android.core.model.DeviceUi
import com.lasohealth.android.core.model.DiscoveryUi
import com.lasohealth.android.core.model.ExploreUiState
import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric
import com.lasohealth.android.core.model.HealthRiskDetailUiState
import com.lasohealth.android.core.model.HealthStateEntryUi
import com.lasohealth.android.core.model.HealthStateTimelineUiState
import com.lasohealth.android.core.model.HomeUiState
import com.lasohealth.android.core.model.InsightUi
import com.lasohealth.android.core.model.LiveUiState
import com.lasohealth.android.core.model.MetricChangeMonthUi
import com.lasohealth.android.core.model.MetricChangeUi
import com.lasohealth.android.core.model.MetricContributionUi
import com.lasohealth.android.core.model.MetricDetailUiState
import com.lasohealth.android.core.model.MetricTileUi
import com.lasohealth.android.core.model.MilestoneUi
import com.lasohealth.android.core.model.MonthlyReviewUiState
import com.lasohealth.android.core.model.PerformanceProfileUiState
import com.lasohealth.android.core.model.PersonalRecordUi
import com.lasohealth.android.core.model.PhaseDurationUi
import com.lasohealth.android.core.model.PlatformStatus
import com.lasohealth.android.core.model.RecommendationUi
import com.lasohealth.android.core.model.RiskFactorUi
import com.lasohealth.android.core.model.RiskFocusAreaUi
import com.lasohealth.android.core.model.SettingsUiState
import com.lasohealth.android.core.model.SleepCoachUiState
import com.lasohealth.android.core.model.SleepDayUi
import com.lasohealth.android.core.model.StrainDetailUiState
import com.lasohealth.android.core.model.StreakUi
import com.lasohealth.android.core.model.StreaksUi
import com.lasohealth.android.core.model.StressMonitorUiState
import com.lasohealth.android.core.model.TodayWorkoutUiState
import com.lasohealth.android.core.analysis.TrendDirection
import com.lasohealth.android.core.model.TrendMetricUi
import com.lasohealth.android.core.model.VitalityDetailUiState
import com.lasohealth.android.core.model.VitalityImprovementUi
import com.lasohealth.android.core.model.WeeklyReviewDetailUiState
import com.lasohealth.android.core.model.WeeklyReviewUi
import com.lasohealth.android.core.model.WorkoutBlockUi
import com.lasohealth.android.core.model.HeartRateEntry
import com.lasohealth.android.core.model.WorkoutUi
import com.lasohealth.android.core.model.ActivationProgressUi
import com.lasohealth.android.core.model.IntelligenceCardUi
import com.lasohealth.android.core.model.IntelligenceAccent
import com.lasohealth.android.core.model.IntelligenceSeverity
import com.lasohealth.android.core.model.MetricForecastUi
import com.lasohealth.android.core.model.ForecastDirection
import java.util.Calendar

class SampleHealthDataRepository : HealthDataRepository {
    override fun homeState(): HomeUiState {
        val greeting = timeOfDayGreeting()
        return HomeUiState(
            greeting = greeting,
            score = 82,
            dailyScore = 78,
            recoveryLabel = "Fully Recovered",
            recoveryStateLabel = "Fully Recovered",
            dayType = "Green Day \u2014 Push Hard",
            dayClassification = "Green Day \u2014 Push Hard",
            scoreDelta = 5,
            streakDays = 12,
            level = "Silver",
            totalDaysTracked = 47,
            progressToNextLevel = 0.62f,
            lastUpdated = "Updated 5 minutes ago",
            primaryAction = ActionCardUi(
                title = "Morning Zone 2 Run",
                detail = "Your recovery supports moderate training today. A 30-minute zone 2 session would build aerobic base.",
                cta = "View Details",
                iconEmoji = "\uD83C\uDFC3",
            ),
            alerts = listOf(
                AlertUi(
                    title = "Elevated Resting HR",
                    detail = "Your resting heart rate is 8 bpm above your 30-day baseline",
                    severity = AlertSeverity.MODERATE,
                ),
            ),
            metrics = listOf(
                MetricTileUi(
                    metric = HealthMetric.HEART_RATE_VARIABILITY,
                    value = "84",
                    trend = "\u2191 3",
                    label = "Vitality",
                ),
                MetricTileUi(
                    metric = HealthMetric.SLEEP_DURATION,
                    value = "7h 12m",
                    trend = "\u2191 0.4h",
                    label = "Sleep",
                ),
                MetricTileUi(
                    metric = HealthMetric.ACTIVE_CALORIES,
                    value = "6.2",
                    trend = "",
                    label = "Strain",
                ),
                MetricTileUi(
                    metric = HealthMetric.HEART_RATE_VARIABILITY,
                    value = "76",
                    trend = "\u2193 2",
                    label = "Brain",
                ),
                MetricTileUi(
                    metric = HealthMetric.RESTING_HEART_RATE,
                    value = "Low",
                    trend = "",
                    label = "Stress",
                ),
                MetricTileUi(
                    metric = HealthMetric.HEART_RATE_VARIABILITY,
                    value = "48ms",
                    trend = "\u2191 5",
                    label = "HRV",
                ),
            ),
            insights = listOf(
                InsightUi(
                    title = "HRV trending above baseline",
                    detail = "Your heart rate variability has been consistently above your 30-day average for the past 4 nights, signaling strong recovery.",
                    metric = HealthMetric.HEART_RATE_VARIABILITY,
                ),
                InsightUi(
                    title = "Sleep consistency improving",
                    detail = "Your sleep midpoint has stayed within a 20-minute window all week, supporting better circadian alignment.",
                    metric = HealthMetric.SLEEP_DURATION,
                ),
                InsightUi(
                    title = "Resting HR creeping up",
                    detail = "Resting heart rate has risen 8 bpm over 3 days. Try a lighter training day if this continues.",
                    metric = HealthMetric.RESTING_HEART_RATE,
                ),
            ),
            weeklyReview = WeeklyReviewUi(
                title = "Weekly Review",
                detail = "You logged 4 workouts, improved sleep consistency by 15%, and maintained your score above 75 for 5 of 7 days.",
                highlight = "Best day: Tuesday, score 86",
            ),
            illnessWarning = null,
            bodyInsight = BodyInsightUi(
                title = "Sleep Duration \u2192 Recovery",
                narrative = "Your sleep improvements over the past week are directly driving your recovery gains.",
                isChain = true,
            ),
            correlations = listOf(
                CorrelationUi(
                    title = "Late caffeine vs deep sleep",
                    summary = "Higher caffeine after 3 PM strongly lines up with lower deep sleep.",
                    metricA = HealthMetric.CAFFEINE_INTAKE,
                    metricB = HealthMetric.SLEEP_DEEP,
                ),
                CorrelationUi(
                    title = "Training load vs readiness",
                    summary = "Back-to-back hard sessions reduce next-day readiness more than longer workouts do.",
                    metricA = HealthMetric.ACTIVE_CALORIES,
                    metricB = HealthMetric.HEART_RATE_VARIABILITY,
                ),
            ),
            activityStreak = 12,
            sleepStreak = 5,
            recoveryStreak = 8,
            recoveryWhyLine = "Your HRV bounced back overnight and resting heart rate is low. Sleep was solid at 7h 12m.",
            activationProgress = ActivationProgressUi(
                currentDay = 5,
                progressFraction = 0.62f,
                progressDescription = "Day 5 of 8 \u2014 Building your baseline",
                isComplete = false,
                latestMilestone = null,
            ),
            showMorningCheckIn = true,
            intelligenceBriefing = listOf(
                IntelligenceCardUi(
                    id = "1",
                    label = "Heads Up",
                    headline = "Your HRV has been dropping since Friday. The last time this happened, you had less deep sleep for 3 nights in a row.",
                    detail = "Getting extra sleep tonight could help based on your history.",
                    confidencePercent = 87,
                    severity = IntelligenceSeverity.WARNING,
                    accentColor = IntelligenceAccent.ORANGE,
                ),
                IntelligenceCardUi(
                    id = "2",
                    label = "Something Changed",
                    headline = "Your deep sleep has been lower since last Tuesday, shifting by 45 min.",
                    detail = "Your resting heart rate changed around the same time.",
                    confidencePercent = 74,
                    severity = IntelligenceSeverity.NOTABLE,
                    accentColor = IntelligenceAccent.PURPLE,
                ),
                IntelligenceCardUi(
                    id = "3",
                    label = "Why This Is Happening",
                    headline = "Your weekend activity pushes down your Monday recovery about 2 days later.",
                    detail = "This connection has been consistent in your data (strength: 0.64).",
                    confidencePercent = 81,
                    severity = IntelligenceSeverity.INFO,
                    accentColor = IntelligenceAccent.BLUE,
                ),
            ),
            healthForecasts = listOf(
                MetricForecastUi(
                    metric = HealthMetric.HEART_RATE_VARIABILITY,
                    predictedValueFormatted = "52ms",
                    rangeDescription = "Expected: 42ms \u2013 62ms",
                    directionIcon = ForecastDirection.UP,
                    isFavorable = true,
                    confidencePercent = 85,
                ),
                MetricForecastUi(
                    metric = HealthMetric.SLEEP_DURATION,
                    predictedValueFormatted = "7.5h",
                    rangeDescription = "Expected: 6.7h \u2013 8.3h",
                    directionIcon = ForecastDirection.UP,
                    isFavorable = true,
                    confidencePercent = 78,
                ),
                MetricForecastUi(
                    metric = HealthMetric.RESTING_HEART_RATE,
                    predictedValueFormatted = "58 bpm",
                    rangeDescription = "Expected: 55 \u2013 61 bpm",
                    directionIcon = ForecastDirection.DOWN,
                    isFavorable = true,
                    confidencePercent = 82,
                ),
            ),
        )
    }

    override fun liveState(): LiveUiState {
        return LiveUiState(
            isStreaming = true,
            freshnessLabel = "Fresh",
            currentHeartRate = 118,
            heartRateZoneLabel = "Cardio",
            heartRateZonePercent = 0.62f,
            readinessScore = 81,
            bloodOxygen = 98,
            respiratoryRate = 14.2,
            heartRateVariability = 70,
            stressLabel = "Low strain",
            activity = ActivityUi(
                steps = 8430,
                activeCalories = 586,
                exerciseMinutes = 41,
                standHours = 10,
                moveGoal = 600,
                exerciseGoal = 30,
                standGoal = 12,
                moveProgress = 0.98f,
                exerciseProgress = 1.37f,
                standProgress = 0.83f,
                distance = 6.2,
                flightsClimbed = 8,
            ),
            workout = WorkoutUi(
                title = "Tempo Run",
                durationMinutes = 38,
                strainLabel = "Moderate-high strain",
                suggestion = "You're in a productive zone. Hold effort here instead of chasing a spike.",
            ),
            lastUpdatedLabel = "Updated 22 sec ago",
            heartRateMin = 92,
            heartRateAvg = 118,
            heartRateMax = 142,
            todayHeartRateMin = 58,
            todayHeartRateMax = 156,
            hasFreshData = true,
            isAging = false,
            recentHeartRates = listOf(
                HeartRateEntry(30, 72), HeartRateEntry(27, 75), HeartRateEntry(24, 78),
                HeartRateEntry(21, 82), HeartRateEntry(18, 95), HeartRateEntry(15, 110),
                HeartRateEntry(12, 125), HeartRateEntry(9, 132), HeartRateEntry(6, 128),
                HeartRateEntry(3, 122), HeartRateEntry(1, 118),
            ),
            systolic = 122,
            diastolic = 78,
            bodyTemperature = 36.6,
            bloodPressureStatus = "Normal",
        )
    }

    override fun exploreState(): ExploreUiState {
        return ExploreUiState(
            overallScore = 79,
            scoreChangeFromLastWeek = 4,
            weakestCategory = HealthCategory.SLEEP,
            metricsTracked = 26,
            totalDataPoints = 18294,
            daysOfData = 47,
            insightCount = 14,
            trendMetrics = listOf(
                TrendMetricUi(
                    HealthMetric.SLEEP_DURATION,
                    "Sleep duration is up 6% versus last week.",
                    sparklineValues = listOf(0.4f, 0.45f, 0.5f, 0.48f, 0.55f, 0.6f, 0.58f, 0.65f, 0.7f, 0.68f, 0.75f, 0.72f),
                    direction = TrendDirection.RISING,
                ),
                TrendMetricUi(
                    HealthMetric.HEART_RATE_VARIABILITY,
                    "HRV improved 8% and is trending upward.",
                    sparklineValues = listOf(0.3f, 0.35f, 0.32f, 0.4f, 0.45f, 0.5f, 0.55f, 0.6f, 0.58f, 0.65f, 0.7f, 0.75f),
                    direction = TrendDirection.RISING,
                ),
                TrendMetricUi(
                    HealthMetric.RESTING_HEART_RATE,
                    "Resting HR is down 4 bpm over the last 30 days.",
                    sparklineValues = listOf(0.8f, 0.78f, 0.75f, 0.77f, 0.7f, 0.72f, 0.68f, 0.65f, 0.63f, 0.6f, 0.58f, 0.55f),
                    direction = TrendDirection.FALLING,
                ),
            ),
            categoryScores = listOf(
                CategoryScoreUi(HealthCategory.HEART, 85),
                CategoryScoreUi(HealthCategory.SLEEP, 74),
                CategoryScoreUi(HealthCategory.ACTIVITY, 82),
                CategoryScoreUi(HealthCategory.BODY, 78),
                CategoryScoreUi(HealthCategory.RESPIRATORY, 80),
                CategoryScoreUi(HealthCategory.MINDFULNESS, 68),
                CategoryScoreUi(HealthCategory.MOBILITY, 76),
            ),
            needsAttention = listOf(
                AttentionUi(HealthMetric.SLEEP_AWAKE, "Awake time is trending higher than your baseline.", impact = -12),
                AttentionUi(HealthMetric.WATER_INTAKE, "Hydration dropped below your 14-day average.", impact = -8),
                AttentionUi(HealthMetric.MINDFUL_MINUTES, "Mindfulness sessions are down this week.", impact = -5),
            ),
            correlations = listOf(
                CorrelationUi(
                    title = "Late caffeine vs deep sleep",
                    summary = "Higher caffeine after 3 PM strongly lines up with lower deep sleep.",
                    metricA = HealthMetric.CAFFEINE_INTAKE,
                    metricB = HealthMetric.SLEEP_DEEP,
                ),
                CorrelationUi(
                    title = "Training load vs readiness",
                    summary = "Back-to-back hard sessions reduce next-day readiness more than longer workouts do.",
                    metricA = HealthMetric.ACTIVE_CALORIES,
                    metricB = HealthMetric.HEART_RATE_VARIABILITY,
                ),
            ),
            decliningTrends = listOf(
                DecliningTrendUi(
                    metric = HealthMetric.SLEEP_DEEP,
                    title = "Deep sleep dropped 18% over the last 14 days",
                    recommendation = "Try winding down earlier and limiting screens before bed.",
                    typeLabel = "14-day decline",
                ),
            ),
            currentHealthState = "Recovering",
            healthStateDays = 3,
            strongestCategory = HealthCategory.HEART,
        )
    }

    override fun platformStatus(): PlatformStatus {
        return PlatformStatus(
            sourceName = "Health Connect",
            notes = listOf(
                "The Android shell is ready for a Health Connect-backed repository.",
                "Streaming and score logic still use sample data until the Android data layer is implemented.",
                "Apple-specific features need Android-native replacements rather than direct translation.",
            ),
        )
    }

    override fun metricDetailState(metric: HealthMetric): MetricDetailUiState {
        return MetricDetailUiState(
            metric = metric,
            currentValue = "72",
            unit = "bpm",
            baselineValue = "68",
            statusLabel = "Above average",
            average = "70",
            min = "58",
            max = "142",
            monthOverMonthChange = "+3%",
            scoreContribution = 18,
            categoryImpact = "Moderate positive impact on Heart & Cardio score",
            historicalFacts = listOf(
                "Your current value is in the 65th percentile of your all-time readings.",
                "This metric has been steadily improving over the past 3 months.",
                "Your best recorded value was 52 bpm on January 14th.",
            ),
            relatedInsights = listOf(
                InsightUi(
                    "Resting HR trending lower",
                    "A downward trend in resting heart rate often signals improved cardiovascular fitness.",
                    metric,
                ),
            ),
            chartValues = listOf(
                68f, 70f, 65f, 72f, 71f, 69f, 74f, 73f, 70f, 68f,
                66f, 71f, 75f, 72f, 70f, 69f, 67f, 73f, 76f, 74f,
                71f, 69f, 72f, 75f, 73f, 70f, 68f, 71f, 74f, 72f,
            ),
            weekOverWeekBadge = "+3% vs last week",
            dataSource = "Health Connect",
            actionRecommendation = "Your resting HR is slightly elevated. Consider extra recovery today.",
        )
    }

    override fun categoryDetailState(category: HealthCategory): CategoryDetailUiState {
        val metrics = when (category) {
            HealthCategory.HEART -> listOf(
                CategoryMetricRow(HealthMetric.RESTING_HEART_RATE, "62 bpm", "Below average"),
                CategoryMetricRow(HealthMetric.HEART_RATE_VARIABILITY, "48 ms", "Above average"),
                CategoryMetricRow(HealthMetric.WALKING_HEART_RATE_AVERAGE, "104 bpm", "Normal"),
                CategoryMetricRow(HealthMetric.HEART_RATE_RECOVERY, "32 bpm", "Good"),
            )
            HealthCategory.SLEEP -> listOf(
                CategoryMetricRow(HealthMetric.SLEEP_DURATION, "7h 24m", "On target"),
                CategoryMetricRow(HealthMetric.SLEEP_DEEP, "1h 42m", "Above average"),
                CategoryMetricRow(HealthMetric.SLEEP_REM, "1h 56m", "Normal"),
                CategoryMetricRow(HealthMetric.SLEEP_AWAKE, "28m", "Below average"),
            )
            HealthCategory.ACTIVITY -> listOf(
                CategoryMetricRow(HealthMetric.STEPS, "9,240", "On target"),
                CategoryMetricRow(HealthMetric.ACTIVE_CALORIES, "586 kcal", "Above average"),
                CategoryMetricRow(HealthMetric.EXERCISE_MINUTES, "41 min", "On target"),
                CategoryMetricRow(HealthMetric.STAND_HOURS, "10 hrs", "Good"),
            )
            HealthCategory.BODY -> listOf(
                CategoryMetricRow(HealthMetric.WEIGHT, "74.2 kg", "Stable"),
                CategoryMetricRow(HealthMetric.BODY_FAT_PERCENTAGE, "18.4%", "Healthy"),
                CategoryMetricRow(HealthMetric.BMI, "23.1", "Normal"),
                CategoryMetricRow(HealthMetric.BODY_TEMPERATURE, "36.6 C", "Normal"),
            )
            HealthCategory.RESPIRATORY -> listOf(
                CategoryMetricRow(HealthMetric.VO2_MAX, "42.5 mL/kg/min", "Above average"),
                CategoryMetricRow(HealthMetric.BLOOD_OXYGEN, "98%", "Normal"),
                CategoryMetricRow(HealthMetric.RESPIRATORY_RATE, "14 br/min", "Normal"),
            )
            HealthCategory.MINDFULNESS -> listOf(
                CategoryMetricRow(HealthMetric.MINDFUL_MINUTES, "12 min", "Below target"),
                CategoryMetricRow(HealthMetric.TIME_IN_DAYLIGHT, "45 min", "Moderate"),
            )
            HealthCategory.MOBILITY -> listOf(
                CategoryMetricRow(HealthMetric.WALKING_SPEED, "5.2 km/h", "Normal"),
                CategoryMetricRow(HealthMetric.WALKING_STEP_LENGTH, "72 cm", "Normal"),
                CategoryMetricRow(HealthMetric.WALKING_STEADINESS, "92%", "Good"),
            )
            else -> listOf(
                CategoryMetricRow(HealthMetric.WATER_INTAKE, "2,100 mL", "Below target"),
            )
        }

        val score = when (category) {
            HealthCategory.HEART -> 85
            HealthCategory.SLEEP -> 74
            HealthCategory.ACTIVITY -> 82
            HealthCategory.BODY -> 78
            HealthCategory.RESPIRATORY -> 80
            HealthCategory.MINDFULNESS -> 68
            HealthCategory.MOBILITY -> 76
            else -> 72
        }

        return CategoryDetailUiState(
            category = category,
            score = score,
            scoreContribution = "Contributes ${score / 7} points to your overall Health Score.",
            historicalHighlights = listOf(
                "Your ${category.shortName} score has improved 6% over the past month.",
                "Best week was February 10\u201316 with a score of ${score + 8}.",
                "You've maintained an above-average score for 3 consecutive weeks.",
            ),
            insights = listOf(
                InsightUi(
                    "${category.shortName} trending well",
                    "Your ${category.shortName.lowercase()} metrics show consistent improvement over the past 2 weeks.",
                    metrics.first().metric,
                ),
            ),
            metrics = metrics,
        )
    }

    override fun weeklyReviewDetailState(): WeeklyReviewDetailUiState {
        return WeeklyReviewDetailUiState(
            score = 82,
            scoreDeltaFromLastWeek = 4,
            avgHeartRate = 62,
            avgSleep = "7h 24m",
            avgSteps = 9240,
            alertCount = 2,
            trendDirection = "Up",
            winCount = 3,
            bestMetric = MetricChangeUi("Sleep Duration", "+12%"),
            worstMetric = MetricChangeUi("Step Count", "-8%"),
            wins = listOf(
                MetricChangeUi("Sleep Duration", "+12%", "Sleep consistency is paying off."),
                MetricChangeUi("HRV", "+8%", "Recovery capacity is improving."),
                MetricChangeUi("Resting HR", "-4%", "Heart efficiency trending better."),
            ),
            watchOuts = listOf(
                MetricChangeUi("Step Count", "-8%", "Try adding a 10-minute walk after lunch."),
                MetricChangeUi("Active Calories", "-5%"),
            ),
            topInsight = InsightUi(
                "Sleep drives recovery",
                "Your improved sleep this week is the primary driver behind your recovery gains.",
                HealthMetric.SLEEP_DURATION,
            ),
            coachTarget = CoachTargetUi(
                currentTarget = "8,500 steps",
                currentAverage = "9,240 steps",
                adherenceLabel = "Exceeding",
                nextWeekTarget = "9,000 steps",
                nextWeekDelta = "+500",
                coachingMessage = "Great progress. Pushing your target slightly to keep building.",
            ),
            nextWeekMessage = "Strong momentum heading into next week. Keep building on your wins and maintain consistency.",
        )
    }

    override fun achievementsState(): AchievementsUiState {
        return AchievementsUiState(
            levelName = "Silver",
            levelEmoji = "\uD83E\uDD48",
            progressToNext = 0.62f,
            totalDaysTracked = 47,
            totalAchievements = 24,
            unlockedAchievements = 11,
            longestStreak = 14,
            streaks = StreaksUi(
                activity = StreakUi(current = 12, best = 14),
                sleep = StreakUi(current = 8, best = 21),
                recovery = StreakUi(current = 5, best = 9),
                checkIn = StreakUi(current = 47, best = 47),
                master = StreakUi(current = 3, best = 7),
            ),
            achievements = listOf(
                AchievementUi(
                    title = "First Steps",
                    description = "Complete your first day of tracking.",
                    emoji = "\uD83D\uDC63",
                    isUnlocked = true,
                    unlockDate = "Jan 28, 2026",
                    category = "Milestone",
                ),
                AchievementUi(
                    title = "Week Warrior",
                    description = "Track your health for 7 consecutive days.",
                    emoji = "\uD83D\uDCAA",
                    isUnlocked = true,
                    unlockDate = "Feb 3, 2026",
                    category = "Streak",
                ),
                AchievementUi(
                    title = "Sleep Champion",
                    description = "Hit your sleep target 5 nights in a row.",
                    emoji = "\uD83C\uDFC6",
                    isUnlocked = true,
                    unlockDate = "Feb 12, 2026",
                    category = "Sleep",
                ),
                AchievementUi(
                    title = "Heart Whisperer",
                    description = "Maintain a resting HR below 60 bpm for 7 days.",
                    emoji = "\u2764\uFE0F",
                    isUnlocked = true,
                    unlockDate = "Feb 18, 2026",
                    category = "Heart",
                ),
                AchievementUi(
                    title = "Step Master",
                    description = "Reach 10,000 steps in a single day.",
                    emoji = "\uD83D\uDEB6",
                    isUnlocked = true,
                    unlockDate = "Feb 5, 2026",
                    category = "Activity",
                ),
                AchievementUi(
                    title = "Recovery Pro",
                    description = "Score above 85 for 3 consecutive days.",
                    emoji = "\uD83C\uDF1F",
                    isUnlocked = true,
                    unlockDate = "Mar 1, 2026",
                    category = "Recovery",
                ),
                AchievementUi(
                    title = "Data Scientist",
                    description = "Track 30 consecutive days of health data.",
                    emoji = "\uD83D\uDD2C",
                    isUnlocked = true,
                    unlockDate = "Feb 26, 2026",
                    category = "Milestone",
                ),
                AchievementUi(
                    title = "Mindful Moment",
                    description = "Log 10 minutes of mindfulness in a day.",
                    emoji = "\uD83E\uDDD8",
                    isUnlocked = true,
                    unlockDate = "Feb 14, 2026",
                    category = "Mindfulness",
                ),
                AchievementUi(
                    title = "Zen Master",
                    description = "Maintain low stress for 5 consecutive days.",
                    emoji = "\u2603\uFE0F",
                    isUnlocked = true,
                    unlockDate = "Mar 5, 2026",
                    category = "Mindfulness",
                ),
                AchievementUi(
                    title = "Iron Legs",
                    description = "Walk over 50 km in a single week.",
                    emoji = "\uD83E\uDDBF",
                    isUnlocked = true,
                    unlockDate = "Mar 8, 2026",
                    category = "Activity",
                ),
                AchievementUi(
                    title = "Early Bird",
                    description = "Wake before 6 AM for 7 consecutive days.",
                    emoji = "\uD83D\uDC26",
                    isUnlocked = true,
                    unlockDate = "Mar 10, 2026",
                    category = "Sleep",
                ),
                AchievementUi(
                    title = "Gold Standard",
                    description = "Reach Gold level.",
                    emoji = "\uD83E\uDD47",
                    isUnlocked = false,
                    category = "Milestone",
                ),
                AchievementUi(
                    title = "Century Club",
                    description = "Track 100 consecutive days.",
                    emoji = "\uD83D\uDCAF",
                    isUnlocked = false,
                    category = "Milestone",
                ),
                AchievementUi(
                    title = "Marathon Month",
                    description = "Walk or run 200 km in a single month.",
                    emoji = "\uD83C\uDFC5",
                    isUnlocked = false,
                    category = "Activity",
                ),
            ),
        )
    }

    override fun connectedDevicesState(): ConnectedDevicesUiState {
        return ConnectedDevicesUiState(
            headline = "Your Health Sources",
            detail = "Health Connect syncs data from your devices and apps into a unified view.",
            connectedCount = 3,
            coveragePercent = 78,
            lastSync = "5 minutes ago",
            activeSources = listOf(
                DeviceUi(
                    id = "health_connect",
                    name = "Health Connect",
                    emoji = "\uD83D\uDCF1",
                    statusLabel = "Connected",
                    metricsCount = 22,
                    isActive = true,
                ),
                DeviceUi(
                    id = "pixel_watch",
                    name = "Pixel Watch 3",
                    emoji = "\u231A",
                    statusLabel = "Syncing",
                    metricsCount = 14,
                    isActive = true,
                ),
                DeviceUi(
                    id = "withings_scale",
                    name = "Withings Body+",
                    emoji = "\u2696\uFE0F",
                    statusLabel = "Connected",
                    metricsCount = 5,
                    isActive = true,
                ),
            ),
            inactiveSources = listOf(
                DeviceUi(
                    id = "oura_ring",
                    name = "Oura Ring Gen 3",
                    emoji = "\uD83D\uDC8D",
                    statusLabel = "Not synced in 3 days",
                    metricsCount = 8,
                    isActive = false,
                ),
            ),
            availableSources = listOf(
                DeviceUi(
                    id = "samsung_health",
                    name = "Samsung Health",
                    emoji = "\uD83D\uDCCA",
                    statusLabel = "Available",
                    metricsCount = 18,
                    isActive = false,
                ),
                DeviceUi(
                    id = "fitbit",
                    name = "Fitbit",
                    emoji = "\u2328\uFE0F",
                    statusLabel = "Available",
                    metricsCount = 12,
                    isActive = false,
                ),
            ),
        )
    }

    override fun deviceDetailState(deviceId: String): DeviceDetailUiState {
        return when (deviceId) {
            "pixel_watch" -> DeviceDetailUiState(
                id = "pixel_watch",
                name = "Pixel Watch 3",
                emoji = "\u231A",
                statusLabel = "Syncing",
                metricsProvided = listOf(
                    "Heart Rate", "Heart Rate Variability", "Blood Oxygen",
                    "Steps", "Active Calories", "Exercise Minutes",
                    "Sleep Duration", "Sleep Stages", "Respiratory Rate",
                    "Stress", "Skin Temperature", "ECG",
                    "Body Composition", "Elevation Gained",
                ),
                lastSync = "22 seconds ago",
                troubleshooting = null,
            )
            "withings_scale" -> DeviceDetailUiState(
                id = "withings_scale",
                name = "Withings Body+",
                emoji = "\u2696\uFE0F",
                statusLabel = "Connected",
                metricsProvided = listOf(
                    "Weight", "BMI", "Body Fat %", "Lean Body Mass", "Body Water",
                ),
                lastSync = "6 hours ago",
                troubleshooting = null,
            )
            "oura_ring" -> DeviceDetailUiState(
                id = "oura_ring",
                name = "Oura Ring Gen 3",
                emoji = "\uD83D\uDC8D",
                statusLabel = "Not synced in 3 days",
                metricsProvided = listOf(
                    "Heart Rate", "HRV", "Blood Oxygen",
                    "Sleep Duration", "Sleep Stages", "Body Temperature",
                    "Activity", "Recovery",
                ),
                lastSync = "3 days ago",
                troubleshooting = "Try opening the Oura app and syncing manually. Make sure Health Connect permissions are enabled in the Oura app settings.",
            )
            else -> DeviceDetailUiState(
                id = deviceId,
                name = "Health Connect",
                emoji = "\uD83D\uDCF1",
                statusLabel = "Connected",
                metricsProvided = listOf(
                    "Heart Rate", "Steps", "Active Calories",
                    "Sleep Duration", "Blood Oxygen", "Weight",
                    "Respiratory Rate", "Exercise Minutes", "Distance",
                    "Floors Climbed", "Body Temperature", "Blood Glucose",
                    "Hydration", "Nutrition", "Menstrual Cycle",
                    "Mindfulness", "Walking Speed", "Cycling Distance",
                    "VO2 Max", "Resting Heart Rate", "HRV",
                    "Basal Metabolic Rate",
                ),
                lastSync = "5 minutes ago",
                troubleshooting = null,
            )
        }
    }

    override fun vitalityDetailState(): VitalityDetailUiState {
        return VitalityDetailUiState(
            vitalityAge = 28,
            biologicalAge = 32,
            delta = -4,
            score = 84,
            trendDirection = "Improving",
            paceLabel = "Healthy",
            heroNarrative = "You\u2019re aging slower than your calendar age. Your cardiovascular fitness and sleep quality are the strongest contributors.",
            contributions = listOf(
                MetricContributionUi(
                    name = "Resting Heart Rate",
                    value = "62 bpm",
                    impact = "Strong positive",
                    metricAge = 24,
                    delta = -8,
                    gaugePosition = 0.82f,
                    subtitle = "Well below age norm",
                    metric = HealthMetric.RESTING_HEART_RATE,
                ),
                MetricContributionUi(
                    name = "VO2 Max",
                    value = "42.5 mL/kg/min",
                    impact = "Above average",
                    metricAge = 26,
                    delta = -6,
                    gaugePosition = 0.74f,
                    subtitle = "Top 30th percentile",
                    metric = HealthMetric.VO2_MAX,
                ),
                MetricContributionUi(
                    name = "Sleep Quality",
                    value = "7h 24m avg",
                    impact = "Positive",
                    metricAge = 29,
                    delta = -3,
                    gaugePosition = 0.68f,
                    subtitle = "Consistent duration",
                    metric = HealthMetric.SLEEP_DURATION,
                ),
                MetricContributionUi(
                    name = "Body Composition",
                    value = "18.4% body fat",
                    impact = "Healthy range",
                    metricAge = 30,
                    delta = -2,
                    gaugePosition = 0.62f,
                    subtitle = "Within healthy range",
                    metric = HealthMetric.BODY_FAT_PERCENTAGE,
                ),
                MetricContributionUi(
                    name = "HRV",
                    value = "48 ms",
                    impact = "Moderate",
                    metricAge = 33,
                    delta = 1,
                    gaugePosition = 0.45f,
                    subtitle = "Slightly below norm",
                    metric = HealthMetric.HEART_RATE_VARIABILITY,
                ),
                MetricContributionUi(
                    name = "Activity Level",
                    value = "9,240 steps/day",
                    impact = "Above target",
                    metricAge = 27,
                    delta = -5,
                    gaugePosition = 0.76f,
                    subtitle = "Exceeds daily target",
                    metric = HealthMetric.STEPS,
                ),
            ),
            improvements = listOf(
                VitalityImprovementUi(
                    metricName = "HRV",
                    impactYears = 3,
                    description = "Improving HRV through stress management and sleep consistency could reduce your vitality age by up to 3 years.",
                ),
                VitalityImprovementUi(
                    metricName = "VO2 Max",
                    impactYears = 2,
                    description = "Adding 2 more cardio sessions per week could improve your cardiovascular age further.",
                ),
            ),
            trendHistory = listOf(33f, 32f, 31f, 31f, 30f, 30f, 29f, 29f, 28f, 28f, 28f, 28f),
            historicalComparison = "Your vitality age has improved by 2 years over the past 6 months, driven primarily by improvements in cardiovascular fitness and sleep consistency.",
        )
    }

    override fun strainDetailState(): StrainDetailUiState {
        return StrainDetailUiState(
            strainScore = 14.2,
            strainLevel = "High",
            targetMin = 10.0,
            targetMax = 16.0,
            zoneMinutes = mapOf(1 to 45.0, 2 to 30.0, 3 to 22.0, 4 to 15.0, 5 to 8.0),
            weeklyHistory = listOf(8.5f, 12.3f, 15.8f, 5.2f, 11.0f, 18.9f, 14.2f),
            balanceLabel = "Optimal",
            guidance = "Your recovery supports moderate-to-high strain today. Focus on sustained aerobic work in Zone 2-3 for optimal cardiovascular benefit without overreaching.",
            trainingZone = "Zone 2-3 (Aerobic Base)",
            strainBalance = "Optimal",
        )
    }

    override fun stressMonitorState(): StressMonitorUiState {
        return StressMonitorUiState(
            stressScore = 1.2,
            stressLevel = "Mild",
            hrvDeviation = 0.35,
            hrElevation = 0.22,
            weeklyScores = listOf(0.8, 1.1, 1.5, 1.2, 0.9, 0.6, 1.2),
            weeklyAverage = 1.04,
            previousWeekAverage = 1.32,
        )
    }

    override fun brainHealthState(): BrainHealthUiState {
        return BrainHealthUiState(
            score = 78,
            grade = "B+",
            stateLabel = "Focused",
            headline = "Good recovery signals from last night",
            weeklyHistory = listOf(72, 68, 75, 80, 77, 82, 78),
            cognitiveReadiness = 82,
            memoryRecovery = 71,
            stressCognitionLoad = 75,
            neurovascularFitness = 80,
            circadianAlignment = 68,
            confidence = 0.85f,
            trend = "improving",
            topFactors = listOf(
                BrainFactorUi("REM Sleep", "12% above baseline", isPositive = true),
                BrainFactorUi("HRV", "Trending up this week", isPositive = true),
                BrainFactorUi("Sleep Regularity", "Inconsistent bedtimes", isPositive = false),
            ),
            contributingFactors = listOf(
                MetricContributionUi(
                    name = "Sleep Quality",
                    value = "7h 24m, 1h 42m deep",
                    impact = "Strong positive",
                ),
                MetricContributionUi(
                    name = "HRV Balance",
                    value = "48 ms RMSSD",
                    impact = "Moderate positive",
                ),
                MetricContributionUi(
                    name = "Stress Load",
                    value = "Low (28/100)",
                    impact = "Positive",
                ),
                MetricContributionUi(
                    name = "Physical Activity",
                    value = "41 min exercise",
                    impact = "Moderate positive",
                ),
                MetricContributionUi(
                    name = "Time in Daylight",
                    value = "45 min",
                    impact = "Below optimal",
                ),
            ),
        )
    }

    override fun sleepCoachState(): SleepCoachUiState {
        return SleepCoachUiState(
            baseHoursNeeded = 7.5,
            recommendedBedtime = "10:30 PM",
            recommendedWakeTime = "6:00 AM",
            sleepDebt = 1.2,
            consistencyScore = 82,
            dailyHistory = listOf(
                SleepDayUi(day = "Mon", actual = 7.2, target = 7.5),
                SleepDayUi(day = "Tue", actual = 7.8, target = 7.5),
                SleepDayUi(day = "Wed", actual = 6.5, target = 7.5),
                SleepDayUi(day = "Thu", actual = 7.4, target = 7.5),
                SleepDayUi(day = "Fri", actual = 8.1, target = 7.5),
                SleepDayUi(day = "Sat", actual = 8.5, target = 7.5),
                SleepDayUi(day = "Sun", actual = 7.0, target = 7.5),
            ),
        )
    }

    override fun cycleDetailState(): CycleDetailUiState {
        return CycleDetailUiState(
            currentPhase = "Follicular",
            dayInCycle = 8,
            cycleLength = 28,
            daysUntilPeriod = 20,
            phaseColor = "#4A90D9",
            phaseProgress = 0.29f,
            phaseDurations = listOf(
                PhaseDurationUi(name = "Menstrual", days = 5, color = "#E74C3C"),
                PhaseDurationUi(name = "Follicular", days = 9, color = "#4A90D9"),
                PhaseDurationUi(name = "Ovulation", days = 3, color = "#2ECC71"),
                PhaseDurationUi(name = "Luteal", days = 11, color = "#F39C12"),
            ),
            cycleHistory = listOf(28, 27, 29, 28, 30, 28, 27),
            nextPeriodEstimate = "April 3, 2026",
        )
    }

    override fun healthStateTimelineState(): HealthStateTimelineUiState {
        return HealthStateTimelineUiState(
            currentState = "Recovered",
            stateDuration = "3 days",
            states = listOf(
                HealthStateEntryUi(
                    label = "Recovered",
                    startDate = "Mar 12",
                    duration = "3 days",
                    color = "#2ECC71",
                ),
                HealthStateEntryUi(
                    label = "Strained",
                    startDate = "Mar 10",
                    duration = "2 days",
                    color = "#F39C12",
                ),
                HealthStateEntryUi(
                    label = "Recovered",
                    startDate = "Mar 5",
                    duration = "5 days",
                    color = "#2ECC71",
                ),
                HealthStateEntryUi(
                    label = "Under-recovered",
                    startDate = "Mar 3",
                    duration = "2 days",
                    color = "#E74C3C",
                ),
                HealthStateEntryUi(
                    label = "Recovered",
                    startDate = "Feb 25",
                    duration = "6 days",
                    color = "#2ECC71",
                ),
                HealthStateEntryUi(
                    label = "Peak",
                    startDate = "Feb 22",
                    duration = "3 days",
                    color = "#3498DB",
                ),
                HealthStateEntryUi(
                    label = "Strained",
                    startDate = "Feb 19",
                    duration = "3 days",
                    color = "#F39C12",
                ),
            ),
        )
    }

    override fun settingsState(): SettingsUiState {
        return SettingsUiState(
            connectedDeviceCount = 3,
            dailySummaryEnabled = true,
            weeklySummaryEnabled = true,
            hrAlertsEnabled = true,
            highHrThreshold = 120,
            lowHrThreshold = 45,
            criticalAlertsEnabled = true,
            warningAlertsEnabled = true,
            trendReversalEnabled = false,
            celebrationsEnabled = true,
            maxAlertsPerDay = 8,
            storedSamplesCount = 18294,
            dataHistorySpan = "47 days",
            metricsTrackedCount = 26,
            isPro = false,
        )
    }

    override fun annualReportState(): AnnualReportUiState {
        return AnnualReportUiState(
            year = 2025,
            monthlyScores = listOf(72, 74, 76, 78, 75, 80, 82, 79, 81, 83, 80, 82),
            averageScore = 79,
            totalDaysTracked = 312,
            insightsGenerated = 1847,
            achievementsUnlocked = 24,
            longestStreak = 47,
            categoryPerformance = listOf(
                CategoryPerformanceUi("Heart", "\u2764\uFE0F", 85, "Improving"),
                CategoryPerformanceUi("Activity", "\uD83C\uDFC3", 82, "Stable"),
                CategoryPerformanceUi("Respiratory", "\uD83C\uDF2C\uFE0F", 80, "Improving"),
                CategoryPerformanceUi("Body", "\uD83E\uDDB4", 78, "Stable"),
                CategoryPerformanceUi("Mobility", "\uD83E\uDDBF", 76, "Improving"),
                CategoryPerformanceUi("Sleep", "\uD83C\uDF19", 74, "Declining"),
                CategoryPerformanceUi("Mindfulness", "\uD83E\uDDD8", 68, "Stable"),
            ),
            milestones = listOf(
                MilestoneUi("First Steps", "\uD83D\uDC63", "Jan 28"),
                MilestoneUi("Week Warrior", "\uD83D\uDCAA", "Feb 3"),
                MilestoneUi("Sleep Champion", "\uD83C\uDFC6", "Feb 12"),
                MilestoneUi("Data Scientist", "\uD83D\uDD2C", "Feb 26"),
                MilestoneUi("Iron Legs", "\uD83E\uDDBF", "Mar 8"),
            ),
            topDiscoveries = listOf(
                DiscoveryUi("Late caffeine reduces deep sleep by 23% on average.", "Mar 15"),
                DiscoveryUi("Zone 2 training improves next-day HRV more than HIIT.", "Apr 22"),
                DiscoveryUi("Consistent bedtime boosts recovery score by 12 points.", "Jun 8"),
                DiscoveryUi("Walking 8,000+ steps correlates with lower resting HR.", "Aug 14"),
                DiscoveryUi("Mindfulness sessions reduce stress markers for 48 hours.", "Oct 3"),
            ),
            recommendations = listOf(
                RecommendationUi(
                    "Focus on Sleep Consistency",
                    "Your sleep score dipped in Q4. Focus on a consistent bedtime to reverse the trend.",
                    "\uD83C\uDF19",
                ),
                RecommendationUi(
                    "Add More Zone 2 Training",
                    "Your cardiovascular gains plateau when training stays in Zone 4-5. Add 2 Zone 2 sessions per week.",
                    "\uD83C\uDFC3",
                ),
                RecommendationUi(
                    "Build a Mindfulness Habit",
                    "Your mindfulness score has room to grow. Even 5 minutes daily shows measurable stress reduction.",
                    "\uD83E\uDDD8",
                ),
            ),
        )
    }

    override fun monthlyReviewState(): MonthlyReviewUiState {
        return MonthlyReviewUiState(
            monthName = "February",
            year = 2026,
            overallScore = 79,
            scoreChangeFromPreviousMonth = 3,
            dailyScores = listOf(
                76, 78, 80, 82, 79, 74, 77, 81, 83, 85,
                82, 80, 78, 75, 79, 82, 84, 86, 83, 80,
                78, 76, 79, 81, 83, 80, 78, 77,
            ),
            bestDay = DayHighlightUi("Feb 18", 86, "Perfect sleep, morning workout, low stress all day."),
            worstDay = DayHighlightUi("Feb 6", 74, "Short sleep, elevated resting HR, skipped exercise."),
            categoryBreakdown = listOf(
                CategoryMonthUi("Heart", 84, "Improving", listOf(82, 83, 84, 85, 84, 83, 85)),
                CategoryMonthUi("Sleep", 76, "Stable", listOf(74, 76, 78, 75, 77, 76, 76)),
                CategoryMonthUi("Activity", 81, "Improving", listOf(79, 80, 82, 83, 81, 80, 82)),
                CategoryMonthUi("Body", 77, "Stable", listOf(77, 77, 78, 77, 76, 77, 78)),
            ),
            topChangedMetrics = listOf(
                MetricChangeMonthUi("HRV", "+12%", "Up"),
                MetricChangeMonthUi("Sleep Duration", "+8%", "Up"),
                MetricChangeMonthUi("Resting HR", "-5%", "Down"),
                MetricChangeMonthUi("Step Count", "-3%", "Down"),
                MetricChangeMonthUi("VO2 Max", "+2%", "Up"),
            ),
            topInsights = listOf(
                "Your sleep consistency improved significantly in the second half of the month.",
                "HRV gains are the strongest driver of your score improvement.",
                "Consider adding back a midweek walk to reverse the step count dip.",
            ),
        )
    }

    override fun performanceProfileState(): PerformanceProfileUiState {
        return PerformanceProfileUiState(
            overallScore = 82,
            personalRecords = listOf(
                PersonalRecordUi("Best HRV", "68 ms", "Mar 2, 2026", "\uD83D\uDC9A"),
                PersonalRecordUi("Lowest RHR", "54 bpm", "Feb 18, 2026", "\u2764\uFE0F"),
                PersonalRecordUi("Best Sleep Score", "94", "Feb 22, 2026", "\uD83C\uDF19"),
                PersonalRecordUi("Highest VO2 Max", "44.2 mL/kg/min", "Mar 5, 2026", "\uD83C\uDF2C\uFE0F"),
                PersonalRecordUi("Most Steps", "18,432", "Jan 31, 2026", "\uD83D\uDEB6"),
                PersonalRecordUi("Longest Streak", "47 days", "Mar 14, 2026", "\uD83D\uDD25"),
            ),
            totalWorkouts = 68,
            avgWeeklyStrain = "6.4",
            recoveryDays = 24,
            activeDaysPerWeek = 5.2f,
            performanceTrend = "Improving",
        )
    }

    override fun healthRiskDetailState(riskId: String): HealthRiskDetailUiState {
        return HealthRiskDetailUiState(
            riskName = "Cardiovascular Risk",
            riskScore = 34,
            riskGrade = "Medium",
            description = "Your cardiovascular risk profile shows some areas that could benefit from attention. Elevated resting heart rate and reduced HRV are the primary contributors.",
            focusAreas = listOf(
                RiskFocusAreaUi(
                    title = "Improve Resting Heart Rate",
                    impact = "High",
                    description = "Consistent aerobic exercise and stress management can lower your resting heart rate over time.",
                ),
                RiskFocusAreaUi(
                    title = "Increase HRV Through Recovery",
                    impact = "High",
                    description = "Focus on sleep quality and add recovery days between intense workouts to boost HRV.",
                ),
                RiskFocusAreaUi(
                    title = "Monitor Blood Pressure",
                    impact = "Medium",
                    description = "Regular blood pressure checks can help catch early trends before they become concerning.",
                ),
            ),
            contributingFactors = listOf(
                RiskFactorUi(
                    metricName = "Resting Heart Rate",
                    currentValue = "72 bpm",
                    status = "warning",
                    optimalRange = "50\u201365 bpm",
                    riskContribution = 0.45f,
                ),
                RiskFactorUi(
                    metricName = "Heart Rate Variability",
                    currentValue = "38 ms",
                    status = "warning",
                    optimalRange = "50\u201380 ms",
                    riskContribution = 0.35f,
                ),
                RiskFactorUi(
                    metricName = "Blood Oxygen",
                    currentValue = "97%",
                    status = "ok",
                    optimalRange = "95\u2013100%",
                    riskContribution = 0.05f,
                ),
                RiskFactorUi(
                    metricName = "VO2 Max",
                    currentValue = "42.5 mL/kg/min",
                    status = "ok",
                    optimalRange = "40\u201355 mL/kg/min",
                    riskContribution = 0.08f,
                ),
                RiskFactorUi(
                    metricName = "Blood Pressure",
                    currentValue = "128/82 mmHg",
                    status = "warning",
                    optimalRange = "< 120/80 mmHg",
                    riskContribution = 0.30f,
                ),
                RiskFactorUi(
                    metricName = "Respiratory Rate",
                    currentValue = "14 br/min",
                    status = "ok",
                    optimalRange = "12\u201320 br/min",
                    riskContribution = 0.03f,
                ),
            ),
        )
    }

    override fun todayWorkoutState(): TodayWorkoutUiState {
        return TodayWorkoutUiState(
            title = "Zone 2 Aerobic Builder",
            summary = "Moderate-intensity session focused on building aerobic base while staying within your recovery capacity.",
            targetZone = "Zone 2-3",
            targetDuration = 45,
            targetCalories = 320,
            recoveryBand = "Green recovery",
            blocks = listOf(
                WorkoutBlockUi(
                    name = "Warm-Up",
                    duration = 8,
                    targetHeartRateZone = 1,
                    targetBpm = "100-120 bpm",
                    exercises = listOf(
                        "Light jogging or brisk walking",
                        "Dynamic stretches (leg swings, arm circles)",
                        "Gradually increase pace over 3 minutes",
                    ),
                ),
                WorkoutBlockUi(
                    name = "Main Block 1",
                    duration = 15,
                    targetHeartRateZone = 2,
                    targetBpm = "120-140 bpm",
                    exercises = listOf(
                        "Steady-state running at conversational pace",
                        "Focus on nasal breathing where possible",
                        "Keep cadence around 170 steps per minute",
                    ),
                ),
                WorkoutBlockUi(
                    name = "Main Block 2",
                    duration = 12,
                    targetHeartRateZone = 3,
                    targetBpm = "140-155 bpm",
                    exercises = listOf(
                        "Tempo run at moderate effort",
                        "2 min hard, 1 min easy (repeat 4 times)",
                        "Maintain form and breathing rhythm",
                    ),
                ),
                WorkoutBlockUi(
                    name = "Cooldown",
                    duration = 10,
                    targetHeartRateZone = 1,
                    targetBpm = "90-110 bpm",
                    exercises = listOf(
                        "Slow jog transitioning to walk",
                        "Static stretches: quads, hamstrings, calves",
                        "Deep breathing for 2 minutes",
                    ),
                ),
            ),
        )
    }

    private fun timeOfDayGreeting(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            hour < 12 -> "Good Morning"
            hour < 17 -> "Good Afternoon"
            else -> "Good Evening"
        }
    }
}
