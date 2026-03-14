package com.lasohealth.android.core.data

import com.lasohealth.android.core.model.HealthMetric
import com.lasohealth.android.core.model.PlatformStatus

data class HealthPlatformSnapshot(
    val sourceName: String,
    val availableMetrics: Set<HealthMetric>,
    val lastSyncLabel: String,
)

interface AndroidHealthGateway {
    suspend fun latestSnapshot(): HealthPlatformSnapshot
    suspend fun platformStatus(): PlatformStatus
}

class StubAndroidHealthGateway : AndroidHealthGateway {
    override suspend fun latestSnapshot(): HealthPlatformSnapshot {
        return HealthPlatformSnapshot(
            sourceName = "Health Connect",
            availableMetrics = setOf(
                HealthMetric.HEART_RATE,
                HealthMetric.RESTING_HEART_RATE,
                HealthMetric.HEART_RATE_VARIABILITY,
                HealthMetric.SLEEP_DURATION,
                HealthMetric.STEPS,
                HealthMetric.ACTIVE_CALORIES,
                HealthMetric.BLOOD_OXYGEN,
            ),
            lastSyncLabel = "Sample sync",
        )
    }

    override suspend fun platformStatus(): PlatformStatus {
        return PlatformStatus(
            sourceName = "Health Connect",
            notes = listOf(
                "Android should read shared health data through Health Connect instead of Apple Health.",
                "Apple Watch streaming, Siri/App Intents, and some HealthKit-only metrics need Android equivalents or feature cuts.",
                "Firebase, analytics, subscriptions, and notifications still need platform-native wiring.",
            ),
        )
    }
}
