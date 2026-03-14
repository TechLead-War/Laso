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

interface HealthDataRepository {
    fun homeState(): HomeUiState
    fun liveState(): LiveUiState
    fun exploreState(): ExploreUiState
    fun platformStatus(): PlatformStatus

    // Detail screen states
    fun metricDetailState(metric: HealthMetric): MetricDetailUiState
    fun categoryDetailState(category: HealthCategory): CategoryDetailUiState
    fun weeklyReviewDetailState(): WeeklyReviewDetailUiState
    fun achievementsState(): AchievementsUiState
    fun connectedDevicesState(): ConnectedDevicesUiState
    fun deviceDetailState(deviceId: String): DeviceDetailUiState
    fun vitalityDetailState(): VitalityDetailUiState
    fun strainDetailState(): StrainDetailUiState
    fun stressMonitorState(): StressMonitorUiState
    fun brainHealthState(): BrainHealthUiState
    fun sleepCoachState(): SleepCoachUiState
    fun cycleDetailState(): CycleDetailUiState
    fun healthStateTimelineState(): HealthStateTimelineUiState
    fun settingsState(): SettingsUiState

    // New screen states (matching iOS parity)
    fun annualReportState(): AnnualReportUiState
    fun monthlyReviewState(): MonthlyReviewUiState
    fun performanceProfileState(): PerformanceProfileUiState
}
