package com.lasohealth.android.core.data

import com.lasohealth.android.core.model.AchievementsUiState
import com.lasohealth.android.core.model.AnnualReportUiState
import com.lasohealth.android.core.model.BrainHealthUiState
import com.lasohealth.android.core.model.CategoryDetailUiState
import com.lasohealth.android.core.model.ConnectedDevicesUiState
import com.lasohealth.android.core.model.CycleDetailUiState
import com.lasohealth.android.core.model.DeviceDetailUiState
import com.lasohealth.android.core.model.ExploreUiState
import com.lasohealth.android.core.model.HealthCategory
import com.lasohealth.android.core.model.HealthMetric
import com.lasohealth.android.core.model.HealthStateTimelineUiState
import com.lasohealth.android.core.model.HomeUiState
import com.lasohealth.android.core.model.LiveUiState
import com.lasohealth.android.core.model.MetricDetailUiState
import com.lasohealth.android.core.model.MonthlyReviewUiState
import com.lasohealth.android.core.model.PerformanceProfileUiState
import com.lasohealth.android.core.model.PlatformStatus
import com.lasohealth.android.core.model.SettingsUiState
import com.lasohealth.android.core.model.SleepCoachUiState
import com.lasohealth.android.core.model.StrainDetailUiState
import com.lasohealth.android.core.model.StressMonitorUiState
import com.lasohealth.android.core.model.VitalityDetailUiState
import com.lasohealth.android.core.model.WeeklyReviewDetailUiState

/**
 * Production repository backed by Health Connect (androidx.health.connect).
 *
 * TODO: Implement each method by reading real user data from Health Connect.
 *  - Request permissions via HealthConnectClient.getOrCreate(context)
 *  - Map Health Connect record types to the UI state models
 *  - Add incremental sync similar to iOS HealthKitManager.loadAndSync()
 *
 * This stub exists so release builds fail fast rather than silently serving
 * fake sample data to real users.
 */
class HealthConnectRepository : HealthDataRepository {

    override fun homeState(): HomeUiState =
        TODO("Wire Health Connect: read heart rate, steps, sleep, etc.")

    override fun liveState(): LiveUiState =
        TODO("Wire Health Connect: stream real-time vitals")

    override fun exploreState(): ExploreUiState =
        TODO("Wire Health Connect: aggregate explore dashboard data")

    override fun platformStatus(): PlatformStatus =
        PlatformStatus(
            sourceName = "Health Connect",
            notes = listOf(
                "Health Connect integration is not yet implemented.",
                "All repository methods must be wired to real Health Connect queries.",
            ),
        )

    override fun metricDetailState(metric: HealthMetric): MetricDetailUiState =
        TODO("Wire Health Connect: read historical data for $metric")

    override fun categoryDetailState(category: HealthCategory): CategoryDetailUiState =
        TODO("Wire Health Connect: aggregate category data for $category")

    override fun weeklyReviewDetailState(): WeeklyReviewDetailUiState =
        TODO("Wire Health Connect: compute weekly review from real data")

    override fun achievementsState(): AchievementsUiState =
        TODO("Wire Health Connect: derive achievements from real data")

    override fun connectedDevicesState(): ConnectedDevicesUiState =
        TODO("Wire Health Connect: enumerate connected data sources")

    override fun deviceDetailState(deviceId: String): DeviceDetailUiState =
        TODO("Wire Health Connect: read device detail for $deviceId")

    override fun vitalityDetailState(): VitalityDetailUiState =
        TODO("Wire Health Connect: compute vitality score from real data")

    override fun strainDetailState(): StrainDetailUiState =
        TODO("Wire Health Connect: compute strain from exercise records")

    override fun stressMonitorState(): StressMonitorUiState =
        TODO("Wire Health Connect: derive stress metrics from HRV data")

    override fun brainHealthState(): BrainHealthUiState =
        TODO("Wire Health Connect: compute brain health indicators")

    override fun sleepCoachState(): SleepCoachUiState =
        TODO("Wire Health Connect: read sleep sessions for coaching")

    override fun cycleDetailState(): CycleDetailUiState =
        TODO("Wire Health Connect: read menstrual cycle records")

    override fun healthStateTimelineState(): HealthStateTimelineUiState =
        TODO("Wire Health Connect: build health state timeline from real data")

    override fun settingsState(): SettingsUiState =
        TODO("Wire Health Connect: populate settings with real sync status")

    override fun annualReportState(): AnnualReportUiState =
        TODO("Wire Health Connect: generate annual report from real data")

    override fun monthlyReviewState(): MonthlyReviewUiState =
        TODO("Wire Health Connect: generate monthly review from real data")

    override fun performanceProfileState(): PerformanceProfileUiState =
        TODO("Wire Health Connect: build performance profile from real data")
}
