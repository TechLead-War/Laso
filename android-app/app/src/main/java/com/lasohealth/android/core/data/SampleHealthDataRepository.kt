package com.lasohealth.android.core.data

import com.lasohealth.android.core.model.AchievementUi
import com.lasohealth.android.core.model.AchievementsUiState
import com.lasohealth.android.core.model.ActionCardUi
import com.lasohealth.android.core.model.ActivityUi
import com.lasohealth.android.core.model.AlertSeverity
import com.lasohealth.android.core.model.AlertUi
import com.lasohealth.android.core.model.AttentionUi
import com.lasohealth.android.core.model.BodyInsightUi
import com.lasohealth.android.core.model.BrainHealthUiState
import com.lasohealth.android.core.model.CategoryDetailUiState
import com.lasohealth.android.core.model.CategoryMetricRow
import com.lasohealth.android.core.model.CategoryScoreUi
import com.lasohealth.android.core.model.CoachTargetUi
import com.lasohealth.android.core.model.ConnectedDevicesUiState
import com.lasohealth.android.core.model.CorrelationUi
import com.lasohealth.android.core.model.CycleDetailUiState
import com.lasohealth.android.core.model.DeviceDetailUiState
import com.lasohealth.android.core.model.DeviceUi
import com.lasohealth.android.core.model.ExploreUiState
import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric
import com.lasohealth.android.core.model.HealthStateEntryUi
import com.lasohealth.android.core.model.HealthStateTimelineUiState
import com.lasohealth.android.core.model.HomeUiState
import com.lasohealth.android.core.model.InsightUi
import com.lasohealth.android.core.model.LiveUiState
import com.lasohealth.android.core.model.MetricChangeUi
import com.lasohealth.android.core.model.MetricContributionUi
import com.lasohealth.android.core.model.MetricDetailUiState
import com.lasohealth.android.core.model.MetricTileUi
import com.lasohealth.android.core.model.PhaseDurationUi
import com.lasohealth.android.core.model.PlatformStatus
import com.lasohealth.android.core.model.SettingsUiState
import com.lasohealth.android.core.model.SleepCoachUiState
import com.lasohealth.android.core.model.SleepDayUi
import com.lasohealth.android.core.model.StrainDetailUiState
import com.lasohealth.android.core.model.StreakUi
import com.lasohealth.android.core.model.StreaksUi
import com.lasohealth.android.core.model.StressMonitorUiState
import com.lasohealth.android.core.model.TrendMetricUi
import com.lasohealth.android.core.model.VitalityDetailUiState
import com.lasohealth.android.core.model.WeeklyReviewDetailUiState
import com.lasohealth.android.core.model.WeeklyReviewUi
import com.lasohealth.android.core.model.WorkoutUi
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
                    detail = "Resting heart rate has risen 8 bpm over 3 days. Consider a lighter training day if this continues.",
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
            trendMetrics = listOf(
                TrendMetricUi(HealthMetric.SLEEP_DURATION, "Sleep duration is up 6% versus last week."),
                TrendMetricUi(HealthMetric.HEART_RATE_VARIABILITY, "HRV improved 8% and is trending upward."),
                TrendMetricUi(HealthMetric.RESTING_HEART_RATE, "Resting HR is down 4 bpm over the last 30 days."),
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
                    "Activity", "Readiness",
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
            contributions = listOf(
                MetricContributionUi(
                    name = "Resting Heart Rate",
                    value = "62 bpm",
                    impact = "Strong positive",
                ),
                MetricContributionUi(
                    name = "VO2 Max",
                    value = "42.5 mL/kg/min",
                    impact = "Above average",
                ),
                MetricContributionUi(
                    name = "Sleep Quality",
                    value = "7h 24m avg",
                    impact = "Positive",
                ),
                MetricContributionUi(
                    name = "Body Composition",
                    value = "18.4% body fat",
                    impact = "Healthy range",
                ),
                MetricContributionUi(
                    name = "HRV",
                    value = "48 ms",
                    impact = "Moderate",
                ),
                MetricContributionUi(
                    name = "Activity Level",
                    value = "9,240 steps/day",
                    impact = "Above target",
                ),
            ),
            historicalComparison = "Your vitality age has improved by 2 years over the past 6 months, driven primarily by improvements in cardiovascular fitness and sleep consistency.",
        )
    }

    override fun strainDetailState(): StrainDetailUiState {
        return StrainDetailUiState(
            strainScore = 6.2,
            strainLevel = "Moderate",
            targetMin = 5.0,
            targetMax = 8.0,
            zoneMinutes = 41,
            weeklyHistory = listOf(4.8f, 7.2f, 5.5f, 6.9f, 3.2f, 8.1f, 6.2f),
            balanceLabel = "Well balanced",
            guidance = "You're within your optimal strain zone for today. Your recovery supports another moderate session tomorrow, but consider a lighter day if your resting HR stays elevated.",
        )
    }

    override fun stressMonitorState(): StressMonitorUiState {
        return StressMonitorUiState(
            stressScore = 28,
            stressLevel = "Low",
            hrvDeviation = "-3% from baseline",
            hrElevation = "+2 bpm above resting",
            weeklyScores = listOf(32, 41, 28, 35, 22, 38, 28),
            weeklyAverage = 32,
            previousWeekAverage = 36,
        )
    }

    override fun brainHealthState(): BrainHealthUiState {
        return BrainHealthUiState(
            score = 76,
            grade = "B+",
            stateLabel = "Cognitive readiness is good",
            weeklyHistory = listOf(72, 68, 74, 78, 71, 80, 76),
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

    private fun timeOfDayGreeting(): String {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            hour < 12 -> "Good Morning"
            hour < 17 -> "Good Afternoon"
            else -> "Good Evening"
        }
    }
}
