package com.lasohealth.android.core.analysis.analyzers

import com.lasohealth.android.core.analysis.AnalysisContext
import com.lasohealth.android.core.analysis.AnalysisInsight
import com.lasohealth.android.core.analysis.DailySample
import com.lasohealth.android.core.analysis.InsightAnalyzer
import com.lasohealth.android.core.analysis.InsightDirective
import com.lasohealth.android.core.analysis.InsightPriority
import com.lasohealth.android.core.analysis.MetricBaseline
import com.lasohealth.android.core.analysis.MetricTrend
import com.lasohealth.android.core.analysis.TrendDirection
import com.lasohealth.android.core.model.HealthMetric
import java.util.UUID
import kotlin.math.abs

/**
 * Clinical-grade health insight analyzer.
 *
 * Monitors vitals against established medical thresholds:
 *   - Blood pressure trajectory using AHA/ACC 2017 classification
 *   - Resting heart rate ranges (bradycardia < 50, tachycardia > 100)
 *   - Blood oxygen saturation (< 95% concern, < 90% critical)
 *   - Respiratory rate abnormalities (< 12 or > 20 br/min)
 *   - Blood glucose trajectory (ADA classification)
 *
 * Carries higher priority due to clinical significance and uses SEEK_MEDICAL
 * directive when thresholds are crossed. Ported from iOS ClinicalIntelligence.swift.
 */
class ClinicalIntelligence : InsightAnalyzer {

    override val name: String = "ClinicalIntelligence"

    override suspend fun generateInsights(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        insights += analyzeBloodPressure(context)
        analyzeRestingHeartRate(context)?.let { insights += it }
        analyzeBloodOxygen(context)?.let { insights += it }
        analyzeRespiratoryRate(context)?.let { insights += it }
        analyzeGlucose(context)?.let { insights += it }

        return insights
    }

    // ----- Blood Pressure -----

    private fun analyzeBloodPressure(context: AnalysisContext): List<AnalysisInsight> {
        val insights = mutableListOf<AnalysisInsight>()

        val sysSamples = context.timeSeries[HealthMetric.BLOOD_PRESSURE_SYSTOLIC] ?: return emptyList()
        if (sysSamples.size < 14) return emptyList()

        val sorted = sysSamples.sortedBy { it.date }
        val latestSys = sorted.last().value

        val diaSamples = context.timeSeries[HealthMetric.BLOOD_PRESSURE_DIASTOLIC]
        val latestDia = diaSamples?.maxByOrNull { it.date }?.value ?: 80.0

        val currentStage = classifyBP(latestSys, latestDia)

        // 90-day linear regression for systolic
        val recent90 = sorted.takeLast(90)
        if (recent90.size < 14) return emptyList()

        val sysSlope = linearRegressionSlope(recent90)
        val slopePerMonth = sysSlope * 30

        // Trending upward significantly
        if (slopePerMonth > 0.5) {
            val priority = if (slopePerMonth > 2.0) InsightPriority.HIGH else InsightPriority.MEDIUM
            val daysToNext = projectDaysToNextThreshold(latestSys, sysSlope, SYSTOLIC_THRESHOLDS)
            val nextStageInfo = daysToNext?.let {
                "At this rate, you could reach ${it.second} territory in ~${it.first} days."
            } ?: ""

            val baselineValue = context.baselines[HealthMetric.BLOOD_PRESSURE_SYSTOLIC]?.mean ?: latestSys

            insights += AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Blood Pressure Trending Up",
                detail = "Your systolic trend shows a rise of ${String.format("%.1f", slopePerMonth)} mmHg/month " +
                    "over the past ${recent90.size} days. Currently in the ${currentStage.label} range. $nextStageInfo " +
                    MEDICAL_DISCLAIMER,
                metric = HealthMetric.BLOOD_PRESSURE_SYSTOLIC,
                priority = priority,
                directive = InsightDirective.SEEK_MEDICAL,
                confidence = minOf(recent90.size / 90.0, 1.0),
            )
        }

        // Pulse pressure
        if (sorted.size >= 30 && diaSamples != null && diaSamples.size >= 30) {
            val pulsePressure = latestSys - latestDia
            if (pulsePressure > 60) {
                insights += AnalysisInsight(
                    id = UUID.randomUUID().toString(),
                    title = "Elevated Pulse Pressure",
                    detail = "Your pulse pressure (${pulsePressure.toInt()} mmHg) is above the normal range of 40-60 mmHg, " +
                        "which may indicate arterial stiffness. $MEDICAL_DISCLAIMER",
                    metric = HealthMetric.BLOOD_PRESSURE_SYSTOLIC,
                    priority = InsightPriority.HIGH,
                    directive = InsightDirective.SEEK_MEDICAL,
                    confidence = 0.8,
                )
            }
        }

        return insights
    }

    // ----- Resting Heart Rate -----

    private fun analyzeRestingHeartRate(context: AnalysisContext): AnalysisInsight? {
        val rhrSamples = context.timeSeries[HealthMetric.RESTING_HEART_RATE] ?: return null
        if (rhrSamples.size < 7) return null

        val recent = rhrSamples.sortedBy { it.date }.takeLast(7)
        val avgRHR = recent.map { it.value }.average()
        val baseline = context.baselines[HealthMetric.RESTING_HEART_RATE]

        return when {
            avgRHR < 50 -> AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Low Resting Heart Rate",
                detail = "Your resting heart rate is averaging ${String.format("%.0f", avgRHR)} bpm over the past week, " +
                    "which is below the typical range. While common in highly trained athletes, sustained bradycardia " +
                    "can warrant clinical attention. $MEDICAL_DISCLAIMER",
                metric = HealthMetric.RESTING_HEART_RATE,
                priority = InsightPriority.HIGH,
                directive = InsightDirective.SEEK_MEDICAL,
                confidence = minOf(recent.size / 7.0, 1.0),
            )
            avgRHR > 100 -> AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Elevated Resting Heart Rate",
                detail = "Your resting heart rate is averaging ${String.format("%.0f", avgRHR)} bpm over the past week, " +
                    "which is above the normal range of 60-100 bpm. Sustained tachycardia may indicate underlying conditions. " +
                    MEDICAL_DISCLAIMER,
                metric = HealthMetric.RESTING_HEART_RATE,
                priority = InsightPriority.CRITICAL,
                directive = InsightDirective.SEEK_MEDICAL,
                confidence = minOf(recent.size / 7.0, 1.0),
            )
            avgRHR > 90 -> AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Resting Heart Rate Elevated",
                detail = "Your resting heart rate is averaging ${String.format("%.0f", avgRHR)} bpm over the past week, " +
                    "trending toward the upper end of normal (60-100 bpm). " +
                    "Baseline: ${baseline?.let { String.format("%.0f", it.mean) } ?: "N/A"} bpm.",
                metric = HealthMetric.RESTING_HEART_RATE,
                priority = InsightPriority.MEDIUM,
                directive = InsightDirective.INFORMATIONAL,
                confidence = minOf(recent.size / 7.0, 1.0),
            )
            else -> null
        }
    }

    // ----- Blood Oxygen -----

    private fun analyzeBloodOxygen(context: AnalysisContext): AnalysisInsight? {
        val spo2Samples = context.timeSeries[HealthMetric.BLOOD_OXYGEN] ?: return null
        if (spo2Samples.size < 3) return null

        val recent = spo2Samples.sortedBy { it.date }.takeLast(7)
        val avgSpO2 = recent.map { it.value }.average()
        val baseline = context.baselines[HealthMetric.BLOOD_OXYGEN]

        return when {
            avgSpO2 < 90 -> AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Blood Oxygen Critically Low",
                detail = "Your blood oxygen saturation is averaging ${String.format("%.1f", avgSpO2)}% recently, " +
                    "which is significantly below the normal range of 95-100%. " +
                    "This level requires immediate medical attention. $MEDICAL_DISCLAIMER",
                metric = HealthMetric.BLOOD_OXYGEN,
                priority = InsightPriority.CRITICAL,
                directive = InsightDirective.SEEK_MEDICAL,
                confidence = minOf(recent.size / 3.0, 1.0),
            )
            avgSpO2 < 95 -> AnalysisInsight(
                id = UUID.randomUUID().toString(),
                title = "Blood Oxygen Below Normal",
                detail = "Your blood oxygen saturation is averaging ${String.format("%.1f", avgSpO2)}% recently, " +
                    "which is below the normal range of 95-100%. " +
                    "Baseline: ${baseline?.let { String.format("%.1f", it.mean) } ?: "N/A"}%. $MEDICAL_DISCLAIMER",
                metric = HealthMetric.BLOOD_OXYGEN,
                priority = InsightPriority.HIGH,
                directive = InsightDirective.SEEK_MEDICAL,
                confidence = minOf(recent.size / 3.0, 1.0),
            )
            else -> null
        }
    }

    // ----- Respiratory Rate -----

    private fun analyzeRespiratoryRate(context: AnalysisContext): AnalysisInsight? {
        val rrSamples = context.timeSeries[HealthMetric.RESPIRATORY_RATE] ?: return null
        if (rrSamples.size < 7) return null

        val sorted = rrSamples.sortedBy { it.date }
        val latest = sorted.last().value
        val stage = classifyRespiratoryRate(latest)
        if (stage == RespiratoryStage.NORMAL) return null

        val baseline = context.baselines[HealthMetric.RESPIRATORY_RATE]
        val recent30 = sorted.takeLast(30)
        val slope = if (recent30.size >= 7) linearRegressionSlope(recent30) else 0.0
        val trendDir = if (slope > 0) TrendDirection.RISING else TrendDirection.STABLE

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Abnormal Respiratory Rate",
            detail = "Your respiratory rate (${String.format("%.1f", latest)} br/min) is classified as ${stage.label}. " +
                "Normal range is 12-20 breaths per minute. $MEDICAL_DISCLAIMER",
            metric = HealthMetric.RESPIRATORY_RATE,
            priority = if (stage == RespiratoryStage.SEVERE) InsightPriority.CRITICAL else InsightPriority.HIGH,
            directive = InsightDirective.SEEK_MEDICAL,
            confidence = minOf(recent30.size / 30.0, 1.0),
        )
    }

    // ----- Blood Glucose -----

    private fun analyzeGlucose(context: AnalysisContext): AnalysisInsight? {
        val glucoseSamples = context.timeSeries[HealthMetric.BLOOD_GLUCOSE] ?: return null
        if (glucoseSamples.size < 14) return null

        val sorted = glucoseSamples.sortedBy { it.date }
        val latest = sorted.last().value
        val currentStage = classifyGlucose(latest)

        val recent90 = sorted.takeLast(90)
        if (recent90.size < 14) return null

        val slope = linearRegressionSlope(recent90)
        val slopePerMonth = slope * 30
        if (slopePerMonth <= 0.3) return null

        val daysToNext = projectDaysToNextThreshold(latest, slope, GLUCOSE_THRESHOLDS)
        val nextInfo = daysToNext?.let { "Projected to reach ${it.second} range in ~${it.first} days." } ?: ""

        val priority = if (currentStage >= GlucoseStage.PREDIABETIC || slopePerMonth > 1.5) {
            InsightPriority.HIGH
        } else {
            InsightPriority.MEDIUM
        }

        val baselineValue = context.baselines[HealthMetric.BLOOD_GLUCOSE]?.mean ?: latest

        return AnalysisInsight(
            id = UUID.randomUUID().toString(),
            title = "Blood Glucose Trending Up",
            detail = "Your fasting glucose has been rising ${String.format("%.1f", slopePerMonth)} mg/dL per month. " +
                "Current: ${String.format("%.0f", latest)} mg/dL (${currentStage.label}). $nextInfo $MEDICAL_DISCLAIMER",
            metric = HealthMetric.BLOOD_GLUCOSE,
            priority = priority,
            directive = InsightDirective.SEEK_MEDICAL,
            confidence = minOf(recent90.size / 90.0, 1.0),
        )
    }

    // ----- Clinical Classifications -----

    private enum class BPStage(val label: String, val order: Int) {
        NORMAL("Normal", 0),
        ELEVATED("Elevated", 1),
        HYPERTENSION_S1("Above Range", 2),
        HYPERTENSION_S2("High", 3),
        CRISIS("Very High", 4),
    }

    private fun classifyBP(systolic: Double, diastolic: Double): BPStage = when {
        systolic > 180 || diastolic > 120 -> BPStage.CRISIS
        systolic >= 140 || diastolic >= 90 -> BPStage.HYPERTENSION_S2
        systolic >= 130 || diastolic >= 80 -> BPStage.HYPERTENSION_S1
        systolic >= 120 && diastolic < 80 -> BPStage.ELEVATED
        else -> BPStage.NORMAL
    }

    private enum class GlucoseStage(val label: String, val order: Int) : Comparable<GlucoseStage> {
        NORMAL("Normal", 0),
        PREDIABETIC("Above Range", 1),
        DIABETIC("High", 2),
    }

    private fun classifyGlucose(value: Double): GlucoseStage = when {
        value >= 126 -> GlucoseStage.DIABETIC
        value >= 100 -> GlucoseStage.PREDIABETIC
        else -> GlucoseStage.NORMAL
    }

    private enum class RespiratoryStage(val label: String) {
        BRADYPNEA("Below Range"),
        NORMAL("Normal"),
        TACHYPNEA("Above Range"),
        SEVERE("Well Above Range"),
    }

    private fun classifyRespiratoryRate(value: Double): RespiratoryStage = when {
        value > 25 -> RespiratoryStage.SEVERE
        value > 20 -> RespiratoryStage.TACHYPNEA
        value < 12 -> RespiratoryStage.BRADYPNEA
        else -> RespiratoryStage.NORMAL
    }

    // ----- Math Helpers -----

    /**
     * Simple linear regression slope (value per day).
     */
    private fun linearRegressionSlope(samples: List<DailySample>): Double {
        if (samples.size < 2) return 0.0

        val n = samples.size.toDouble()
        val firstDate = samples.first().date
        val xs = samples.map { (it.date - firstDate).toDouble() / DAY_MS.toDouble() }
        val ys = samples.map { it.value }

        val sumX = xs.sum()
        val sumY = ys.sum()
        val sumXY = xs.zip(ys).sumOf { (x, y) -> x * y }
        val sumX2 = xs.sumOf { it * it }

        val denominator = n * sumX2 - sumX * sumX
        if (denominator == 0.0) return 0.0

        return (n * sumXY - sumX * sumY) / denominator
    }

    /**
     * Project how many days until the next clinical threshold is reached.
     */
    private fun projectDaysToNextThreshold(
        currentValue: Double,
        slopePerDay: Double,
        thresholds: List<Pair<Double, String>>,
    ): Pair<Int, String>? {
        if (slopePerDay <= 0) return null

        for ((threshold, label) in thresholds) {
            if (currentValue < threshold) {
                val days = ((threshold - currentValue) / slopePerDay).toInt()
                if (days in 1..364) {
                    return days to label
                }
            }
        }
        return null
    }

    companion object {
        private const val DAY_MS = 86_400_000L

        private const val MEDICAL_DISCLAIMER =
            "This is not a medical diagnosis. Consult your healthcare provider for clinical evaluation."

        private val SYSTOLIC_THRESHOLDS = listOf(
            120.0 to "Elevated",
            130.0 to "Above Range",
            140.0 to "High",
            180.0 to "Very High",
        )

        private val GLUCOSE_THRESHOLDS = listOf(
            100.0 to "Above Range",
            126.0 to "High",
        )
    }
}
