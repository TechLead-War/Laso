package com.lasohealth.android.navigation

import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric

sealed class AppRoute(val route: String) {
    // Detail screens
    data object Settings : AppRoute("settings")
    data object ScoreGuide : AppRoute("scoreGuide")
    data object InsightsDetail : AppRoute("insightsDetail")
    data object WeeklyReview : AppRoute("weeklyReview")
    data object Achievements : AppRoute("achievements")
    data object ConnectedDevices : AppRoute("connectedDevices")
    data object Paywall : AppRoute("paywall")

    // Feature screens
    data object VitalityDetail : AppRoute("vitalityDetail")
    data object StrainDetail : AppRoute("strainDetail")
    data object StressMonitor : AppRoute("stressMonitor")
    data object BrainHealth : AppRoute("brainHealth")
    data object SleepCoach : AppRoute("sleepCoach")
    data object CycleDetail : AppRoute("cycleDetail")
    data object HealthStateTimeline : AppRoute("healthStateTimeline")
    data object CorrelationsDetail : AppRoute("correlationsDetail")

    // Parameterized routes
    data object MetricDetail : AppRoute("metricDetail/{metricId}") {
        fun createRoute(metric: HealthMetric): String = "metricDetail/${metric.name}"
    }
    data object CategoryDetail : AppRoute("categoryDetail/{categoryId}") {
        fun createRoute(category: HealthCategory): String = "categoryDetail/${category.name}"
    }
    data object DeviceDetail : AppRoute("deviceDetail/{deviceId}") {
        fun createRoute(deviceId: String): String = "deviceDetail/$deviceId"
    }
}
