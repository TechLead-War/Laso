package com.lasohealth.android.core.ml

import com.lasohealth.android.core.model.HealthMetric

// ---------------------------------------------------------------------------
// Core ML types for the on-device health intelligence pipeline.
// Ported from iOS MLTypes.swift, adapted to Kotlin/Android conventions.
// ---------------------------------------------------------------------------

// -- Feature Types ----------------------------------------------------------

/**
 * Types of derived features computed from raw metric time series.
 *
 * Each metric produces one value per [FeatureType] per day, giving the
 * [FeatureEngine] an 18-dimensional feature vector per metric.
 */
enum class FeatureType {
    RAW,                 // z-score normalised value
    RATE_OF_CHANGE,      // day-over-day delta
    VOLATILITY_7,        // 7-day rolling std dev
    VOLATILITY_14,       // 14-day rolling std dev
    VOLATILITY_28,       // 28-day rolling std dev
    LAG_1,               // value from 1 day ago
    LAG_3,               // value from 3 days ago
    LAG_7,               // value from 7 days ago
    LAG_14,              // value from 14 days ago
    LAG_28,              // value from 28 days ago
    LAG_60,              // value from 60 days ago
    DEVIATION_BASELINE,  // deviation from personal baseline
    ACCELERATION,        // 2nd derivative (rate of change of rate of change)
    ENTROPY,             // Shannon entropy of recent 7-day binned distribution
    PERIODICITY_STRENGTH,// max |autocorrelation| at dominant period
    WEEKDAY_OFFSET,      // deviation of weekday mean from overall mean
    WEEKEND_OFFSET,      // deviation of weekend mean from overall mean
    MISSINGNESS,         // 1.0 if data missing on this day, 0.0 otherwise
}

/**
 * Uniquely identifies a single feature: a [HealthMetric] paired with a derived [FeatureType].
 */
data class FeatureKey(
    val metric: HealthMetric,
    val type: FeatureType,
) {
    companion object {
        /** Sentinel value used for missing / uncomputable features. */
        const val MISSING_SENTINEL: Double = -999.0
    }
}

// -- Daily Feature Vector ---------------------------------------------------

/**
 * A standardised feature vector for a single calendar day.
 *
 * @property date  Epoch milliseconds (start of day, UTC).
 * @property features  Per-(metric, feature-type) values.
 * @property context   Temporal context features for the day.
 */
data class DailyFeatureVector(
    val date: Long,
    val features: Map<FeatureKey, Double>,
    val context: ContextFeatures,
) {
    /** Number of distinct metrics that have data on this day. */
    val metricCount: Int
        get() = features.keys.map { it.metric }.toSet().size

    /** Project the map onto a deterministic array using [orderedKeys]. */
    fun toArray(orderedKeys: List<FeatureKey>): DoubleArray =
        DoubleArray(orderedKeys.size) { i ->
            features[orderedKeys[i]] ?: FeatureKey.MISSING_SENTINEL
        }

    /** Convenience: raw z-score for a specific metric. */
    fun rawValue(metric: HealthMetric): Double? =
        features[FeatureKey(metric, FeatureType.RAW)]
            ?.takeIf { it != FeatureKey.MISSING_SENTINEL }
}

// -- Context Features -------------------------------------------------------

/**
 * Cyclical temporal context for a single day (weekday, month, weekend).
 *
 * Encoded as sin/cos pairs so that ML models perceive Monday and Sunday as
 * neighbours rather than distant integers.
 */
data class ContextFeatures(
    val weekdaySin: Double,
    val weekdayCos: Double,
    val monthSin: Double,
    val monthCos: Double,
    val isWeekend: Double, // 1.0 or 0.0
) {
    /** Flat array representation for ML input layers. */
    fun toArray(): DoubleArray =
        doubleArrayOf(weekdaySin, weekdayCos, monthSin, monthCos, isWeekend)

    companion object {
        /**
         * Build context features from an epoch-millis date.
         *
         * Uses [java.util.Calendar] so the result matches the device locale for
         * weekday numbering (1 = Sunday, 7 = Saturday).
         */
        fun from(epochMillis: Long): ContextFeatures {
            val cal = java.util.Calendar.getInstance().apply { timeInMillis = epochMillis }
            val weekday = cal.get(java.util.Calendar.DAY_OF_WEEK).toDouble() // 1=Sun..7=Sat
            val month = (cal.get(java.util.Calendar.MONTH) + 1).toDouble()   // 1..12

            val weekdayAngle = 2.0 * Math.PI * (weekday - 1.0) / 7.0
            val monthAngle = 2.0 * Math.PI * (month - 1.0) / 12.0

            val dow = cal.get(java.util.Calendar.DAY_OF_WEEK)
            val weekend = if (dow == java.util.Calendar.SUNDAY || dow == java.util.Calendar.SATURDAY) 1.0 else 0.0

            return ContextFeatures(
                weekdaySin = kotlin.math.sin(weekdayAngle),
                weekdayCos = kotlin.math.cos(weekdayAngle),
                monthSin = kotlin.math.sin(monthAngle),
                monthCos = kotlin.math.cos(monthAngle),
                isWeekend = weekend,
            )
        }
    }
}

// -- ML Prediction ----------------------------------------------------------

/**
 * A point prediction from an ML component.
 *
 * @property metric          The health metric being predicted.
 * @property predictedValue  Predicted raw value.
 * @property confidence      Model confidence in [0, 1].
 * @property horizon         Forecast horizon in days ahead.
 * @property timestamp       When the prediction was generated (epoch ms).
 */
data class MLPrediction(
    val metric: HealthMetric,
    val predictedValue: Double,
    val confidence: Double,
    val horizon: Int,
    val timestamp: Long = System.currentTimeMillis(),
) {
    /** Human-readable risk level derived from the predicted probability. */
    val riskLevel: String
        get() = when {
            predictedValue >= 0.7 -> "High"
            predictedValue >= 0.5 -> "Moderate"
            predictedValue >= 0.3 -> "Low"
            else -> "Very Low"
        }
}

// -- Multi-Horizon Forecast -------------------------------------------------

/**
 * Forecasts at multiple horizons (e.g. 1-day, 3-day, 7-day) for a single metric.
 *
 * @property metric    The target metric.
 * @property forecasts Keyed by horizon (days ahead) to the corresponding prediction.
 */
data class MultiHorizonForecast(
    val metric: HealthMetric,
    val forecasts: Map<Int, MLPrediction>,
)

// -- ML Model State ---------------------------------------------------------

/**
 * Serialisable snapshot of learned model parameters for persistence.
 */
data class MLModelState(
    val componentName: String,
    val version: Int,
    val isReady: Boolean,
    val lastTrainedAt: Long,
    val sampleCount: Int,
    val parametersJson: String? = null,
)

// -- Discovered Pattern -----------------------------------------------------

/**
 * A periodic or structural pattern discovered in the user's health data.
 */
data class DiscoveredPattern(
    val metric: HealthMetric,
    val patternType: PatternType,
    val periodDays: Int,
    val strength: Double,
    val description: String,
    val discoveredAt: Long = System.currentTimeMillis(),
    val peakDayOfWeek: Int? = null,   // 1=Sun..7=Sat
    val troughDayOfWeek: Int? = null,
) {
    /** Human-readable peak day name. */
    val peakDayName: String? get() = peakDayOfWeek?.let { dayName(it) }

    /** Human-readable trough day name. */
    val troughDayName: String? get() = troughDayOfWeek?.let { dayName(it) }
}

enum class PatternType {
    WEEKLY,
    BIWEEKLY,
    MONTHLY,
    SEASONAL,
    CUSTOM,
}

// -- Health State -----------------------------------------------------------

/**
 * A cluster-derived health state representing a distinct mode of operation
 * (e.g. "Recovery", "Peak Performance", "Stressed").
 */
data class HealthState(
    val label: String,
    val metrics: Map<HealthMetric, Double>,
    val probability: Double,
    val characteristics: List<StateCharacteristic> = emptyList(),
    val transitionProbabilities: Map<String, Double> = emptyMap(),
)

data class StateCharacteristic(
    val metric: HealthMetric,
    val level: CharacteristicLevel,
    val zScore: Double,
)

enum class CharacteristicLevel { HIGH, NORMAL, LOW }

// -- Smoothed Health State --------------------------------------------------

/**
 * Health state with HMM-smoothed temporal coherence.
 */
data class SmoothedHealthState(
    val state: HealthState,
    val confidence: Double,
    val transitionProbability: Double,
    val date: Long = System.currentTimeMillis(),
    val isTransitionDay: Boolean = false,
    val daysSinceTransition: Int = 0,
)

// -- ML Correlation ---------------------------------------------------------

/**
 * A discovered correlation between two health metrics.
 */
data class MLCorrelation(
    val metricA: HealthMetric,
    val metricB: HealthMetric,
    val coefficient: Double,
    val pValue: Double,
    val lagDays: Int,
    val isGrangerCausal: Boolean = false,
    val sampleCount: Int = 0,
    val stability: Double = 1.0,
    var survivedFDR: Boolean = true,
) {
    /** Whether this correlation is statistically significant. */
    val isSignificant: Boolean
        get() = kotlin.math.abs(coefficient) >= 0.25 || isGrangerCausal

    /** Combined strength measure. */
    val overallStrength: Double
        get() = kotlin.math.abs(coefficient)
}

// -- Personalization Stage --------------------------------------------------

/**
 * Cold-start personalization stages based on data maturity.
 */
enum class PersonalizationStage(val minDays: Int) {
    POPULATION(0),
    EMERGING(3),
    BLENDED(14),
    PERSONALIZED(21),
    FULLY_PERSONAL(30);

    companion object {
        /** Determine the stage from the number of days of available data. */
        fun from(dayCount: Int): PersonalizationStage = entries
            .sortedByDescending { it.minDays }
            .first { dayCount >= it.minDays }
    }
}

// -- Policy Decision --------------------------------------------------------

/**
 * Output of the decision policy engine: the primary recommended action.
 */
data class PolicyDecision(
    val action: String,
    val detail: String,
    val confidence: Double,
    val metric: HealthMetric?,
    val iconEmoji: String,
    val decidedAt: Long = System.currentTimeMillis(),
)

// -- Predictive Signal ------------------------------------------------------

/**
 * Type of predictive health signal the pipeline can detect.
 */
enum class SignalType {
    FATIGUE,
    BURNOUT,
    OVERTRAINING,
    INSOMNIA,
    IMMUNE_DIP,
    INACTIVITY,
}

/**
 * A predictive health signal with estimated probability and horizon.
 */
data class PredictiveSignal(
    val type: SignalType,
    val probability: Double,
    val timeHorizon: Int,
    val description: String,
)

// -- Helpers ----------------------------------------------------------------

private fun dayName(weekday: Int): String? = when (weekday) {
    1 -> "Sunday"
    2 -> "Monday"
    3 -> "Tuesday"
    4 -> "Wednesday"
    5 -> "Thursday"
    6 -> "Friday"
    7 -> "Saturday"
    else -> null
}
