import Foundation
import HealthKit

/// Maps each HealthMetric to its corresponding HKSampleType and query strategy
struct HealthKitMetricRegistry {

    enum QueryStrategy {
        case quantitySample        // Individual samples (heart rate, blood oxygen)
        case statisticsDaily       // Daily aggregated stat (steps, calories)
        case categorySample        // Category samples (sleep stages, mindful sessions)
        case workoutQuery          // HKWorkout queries
    }

    struct MetricConfig {
        let sampleType: HKSampleType?
        let quantityType: HKQuantityType?
        let unit: HKUnit
        let strategy: QueryStrategy
        let statisticsOption: HKStatisticsOptions
        /// Multiplier applied to the raw HealthKit value after unit conversion.
        /// Oxygen saturation reads as a 0–1 fraction via HKUnit.percent(); ×100
        /// puts it on the 0–100 scale the rest of the app (thresholds, normal
        /// ranges, display, alerts) expects. Defaults to 1 for every other metric.
        var valueScale: Double = 1.0
    }

    static func config(for metric: HealthMetric) -> MetricConfig {
        switch metric {
        case .heartRate, .restingHeartRate, .heartRateVariability, .walkingHeartRateAverage,
             .heartRateRecovery, .atrialFibrillationBurden, .peripheralPerfusionIndex, .bloodOxygen:
            return cardioConfig(for: metric)
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake, .sleepBreathingDisturbances:
            return sleepConfig(for: metric)
        case .steps, .activeCalories, .basalCalories, .exerciseMinutes, .standHours,
             .distanceWalkingRunning, .flightsClimbed, .distanceCycling, .distanceSwimming,
             .swimmingStrokeCount, .appleMoveTime, .walkingSpeed, .walkingStepLength,
             .walkingAsymmetry, .walkingDoubleSupportPercentage, .stairAscentSpeed,
             .stairDescentSpeed, .sixMinuteWalkTestDistance, .walkingSteadiness,
             .numberOfTimesFallen, .runningPower, .runningGroundContactTime,
             .runningVerticalOscillation, .runningStrideLength:
            return activityConfig(for: metric)
        case .weight, .bmi, .bodyFatPercentage, .bloodPressureSystolic, .bloodPressureDiastolic,
             .respiratoryRate, .bodyTemperature, .appleSleepingWristTemperature, .leanBodyMass,
             .waistCircumference, .vo2Max, .peakExpiratoryFlowRate, .forcedVitalCapacity,
             .forcedExpiratoryVolume1:
            return bodyAndVitalsConfig(for: metric)
        case .mindfulMinutes, .timeInDaylight, .electrodermalActivity, .waterIntake,
             .caffeineIntake, .proteinIntake, .fiberIntake, .sugarIntake, .sodiumIntake,
             .totalCaloriesIntake, .carbohydrateIntake, .fatIntake, .bloodGlucose,
             .insulinDelivery:
            return mindfulnessAndNutritionConfig(for: metric)
        case .workoutCount, .workoutDuration, .headphoneAudioExposure,
             .environmentalAudioExposure, .underwaterDepth, .waterTemperature:
            return miscConfig(for: metric)
        }
    }

    // MARK: - Cardio

    private static func cardioConfig(for metric: HealthMetric) -> MetricConfig {
        switch metric {
        case .heartRate:
            return MetricConfig(
                sampleType: HKQuantityType(.heartRate),
                quantityType: HKQuantityType(.heartRate),
                unit: HKUnit.count().unitDivided(by: .minute()),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .restingHeartRate:
            return MetricConfig(
                sampleType: HKQuantityType(.restingHeartRate),
                quantityType: HKQuantityType(.restingHeartRate),
                unit: HKUnit.count().unitDivided(by: .minute()),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .heartRateVariability:
            return MetricConfig(
                sampleType: HKQuantityType(.heartRateVariabilitySDNN),
                quantityType: HKQuantityType(.heartRateVariabilitySDNN),
                unit: HKUnit.secondUnit(with: .milli),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .walkingHeartRateAverage:
            return MetricConfig(
                sampleType: HKQuantityType(.walkingHeartRateAverage),
                quantityType: HKQuantityType(.walkingHeartRateAverage),
                unit: HKUnit.count().unitDivided(by: .minute()),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .heartRateRecovery:
            return MetricConfig(
                sampleType: HKQuantityType(.heartRateRecoveryOneMinute),
                quantityType: HKQuantityType(.heartRateRecoveryOneMinute),
                unit: HKUnit.count().unitDivided(by: .minute()),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .atrialFibrillationBurden:
            return MetricConfig(
                sampleType: HKQuantityType(.atrialFibrillationBurden),
                quantityType: HKQuantityType(.atrialFibrillationBurden),
                unit: .percent(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .peripheralPerfusionIndex:
            return MetricConfig(
                sampleType: HKQuantityType(.peripheralPerfusionIndex),
                quantityType: HKQuantityType(.peripheralPerfusionIndex),
                unit: .percent(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage,
                valueScale: 100  // HealthKit gives this as 0–1; app scores/shows 0–100 (range 0.5–5)
            )
        case .bloodOxygen:
            return MetricConfig(
                sampleType: HKQuantityType(.oxygenSaturation),
                quantityType: HKQuantityType(.oxygenSaturation),
                unit: .percent(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage,
                valueScale: 100  // HealthKit gives SpO2 as 0–1; app expects 0–100
            )
        default:
            preconditionFailure("cardioConfig called with non-cardio metric: \(metric)")
        }
    }

    // MARK: - Sleep

    private static func sleepConfig(for metric: HealthMetric) -> MetricConfig {
        switch metric {
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake:
            return MetricConfig(
                sampleType: HKCategoryType(.sleepAnalysis),
                quantityType: nil,
                unit: .hour(),
                strategy: .categorySample,
                statisticsOption: .cumulativeSum
            )
        case .sleepBreathingDisturbances:
            if #available(iOS 18.0, *) {
                return MetricConfig(
                    sampleType: HKQuantityType(.appleSleepingBreathingDisturbances),
                    quantityType: HKQuantityType(.appleSleepingBreathingDisturbances),
                    unit: HKUnit.count().unitDivided(by: .hour()),
                    strategy: .quantitySample,
                    statisticsOption: .discreteAverage
                )
            } else {
                return MetricConfig(
                    sampleType: nil,
                    quantityType: nil,
                    unit: HKUnit.count().unitDivided(by: .hour()),
                    strategy: .quantitySample,
                    statisticsOption: .discreteAverage
                )
            }
        default:
            preconditionFailure("sleepConfig called with non-sleep metric: \(metric)")
        }
    }

    // MARK: - Activity / Mobility / Running

    private static func activityConfig(for metric: HealthMetric) -> MetricConfig {
        switch metric {
        case .steps:
            return MetricConfig(
                sampleType: HKQuantityType(.stepCount),
                quantityType: HKQuantityType(.stepCount),
                unit: .count(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .activeCalories:
            return MetricConfig(
                sampleType: HKQuantityType(.activeEnergyBurned),
                quantityType: HKQuantityType(.activeEnergyBurned),
                unit: .kilocalorie(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .basalCalories:
            return MetricConfig(
                sampleType: HKQuantityType(.basalEnergyBurned),
                quantityType: HKQuantityType(.basalEnergyBurned),
                unit: .kilocalorie(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .exerciseMinutes:
            return MetricConfig(
                sampleType: HKQuantityType(.appleExerciseTime),
                quantityType: HKQuantityType(.appleExerciseTime),
                unit: .minute(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .standHours:
            return MetricConfig(
                sampleType: HKQuantityType(.appleStandTime),
                quantityType: HKQuantityType(.appleStandTime),
                unit: .hour(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .distanceWalkingRunning:
            return MetricConfig(
                sampleType: HKQuantityType(.distanceWalkingRunning),
                quantityType: HKQuantityType(.distanceWalkingRunning),
                unit: .meterUnit(with: .kilo),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .flightsClimbed:
            return MetricConfig(
                sampleType: HKQuantityType(.flightsClimbed),
                quantityType: HKQuantityType(.flightsClimbed),
                unit: .count(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .distanceCycling:
            return MetricConfig(
                sampleType: HKQuantityType(.distanceCycling),
                quantityType: HKQuantityType(.distanceCycling),
                unit: .meterUnit(with: .kilo),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .distanceSwimming:
            return MetricConfig(
                sampleType: HKQuantityType(.distanceSwimming),
                quantityType: HKQuantityType(.distanceSwimming),
                unit: .meterUnit(with: .kilo),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .swimmingStrokeCount:
            return MetricConfig(
                sampleType: HKQuantityType(.swimmingStrokeCount),
                quantityType: HKQuantityType(.swimmingStrokeCount),
                unit: .count(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .appleMoveTime:
            return MetricConfig(
                sampleType: HKQuantityType(.appleMoveTime),
                quantityType: HKQuantityType(.appleMoveTime),
                unit: .minute(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .walkingSpeed:
            return MetricConfig(
                sampleType: HKQuantityType(.walkingSpeed),
                quantityType: HKQuantityType(.walkingSpeed),
                unit: HKUnit.meterUnit(with: .kilo).unitDivided(by: .hour()),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .walkingStepLength:
            return MetricConfig(
                sampleType: HKQuantityType(.walkingStepLength),
                quantityType: HKQuantityType(.walkingStepLength),
                unit: .meterUnit(with: .centi),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .walkingAsymmetry:
            return MetricConfig(
                sampleType: HKQuantityType(.walkingAsymmetryPercentage),
                quantityType: HKQuantityType(.walkingAsymmetryPercentage),
                unit: .percent(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage,
                valueScale: 100  // HealthKit gives this as 0–1; app scores/shows 0–100 (range 0–10)
            )
        case .walkingDoubleSupportPercentage:
            return MetricConfig(
                sampleType: HKQuantityType(.walkingDoubleSupportPercentage),
                quantityType: HKQuantityType(.walkingDoubleSupportPercentage),
                unit: .percent(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage,
                valueScale: 100  // HealthKit gives this as 0–1; app scores/shows 0–100 (range 20–40)
            )
        case .stairAscentSpeed:
            return MetricConfig(
                sampleType: HKQuantityType(.stairAscentSpeed),
                quantityType: HKQuantityType(.stairAscentSpeed),
                unit: HKUnit.meter().unitDivided(by: .second()),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .stairDescentSpeed:
            return MetricConfig(
                sampleType: HKQuantityType(.stairDescentSpeed),
                quantityType: HKQuantityType(.stairDescentSpeed),
                unit: HKUnit.meter().unitDivided(by: .second()),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .sixMinuteWalkTestDistance:
            return MetricConfig(
                sampleType: HKQuantityType(.sixMinuteWalkTestDistance),
                quantityType: HKQuantityType(.sixMinuteWalkTestDistance),
                unit: .meter(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .walkingSteadiness:
            return MetricConfig(
                sampleType: HKQuantityType(.appleWalkingSteadiness),
                quantityType: HKQuantityType(.appleWalkingSteadiness),
                unit: .percent(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage,
                valueScale: 100  // HealthKit gives this as 0–1; app scores/shows 0–100 (range 50–100)
            )
        case .numberOfTimesFallen:
            return MetricConfig(
                sampleType: HKQuantityType(.numberOfTimesFallen),
                quantityType: HKQuantityType(.numberOfTimesFallen),
                unit: .count(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .runningPower:
            return MetricConfig(
                sampleType: HKQuantityType(.runningPower),
                quantityType: HKQuantityType(.runningPower),
                unit: .watt(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .runningGroundContactTime:
            return MetricConfig(
                sampleType: HKQuantityType(.runningGroundContactTime),
                quantityType: HKQuantityType(.runningGroundContactTime),
                unit: .secondUnit(with: .milli),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .runningVerticalOscillation:
            return MetricConfig(
                sampleType: HKQuantityType(.runningVerticalOscillation),
                quantityType: HKQuantityType(.runningVerticalOscillation),
                unit: .meterUnit(with: .centi),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .runningStrideLength:
            return MetricConfig(
                sampleType: HKQuantityType(.runningStrideLength),
                quantityType: HKQuantityType(.runningStrideLength),
                unit: .meter(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        default:
            preconditionFailure("activityConfig called with non-activity metric: \(metric)")
        }
    }

    // MARK: - Body / Vitals / Respiratory

    private static func bodyAndVitalsConfig(for metric: HealthMetric) -> MetricConfig {
        switch metric {
        case .weight:
            return MetricConfig(
                sampleType: HKQuantityType(.bodyMass),
                quantityType: HKQuantityType(.bodyMass),
                unit: .gramUnit(with: .kilo),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .bmi:
            return MetricConfig(
                sampleType: HKQuantityType(.bodyMassIndex),
                quantityType: HKQuantityType(.bodyMassIndex),
                unit: .count(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .bodyFatPercentage:
            return MetricConfig(
                sampleType: HKQuantityType(.bodyFatPercentage),
                quantityType: HKQuantityType(.bodyFatPercentage),
                unit: .percent(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage,
                valueScale: 100  // HealthKit gives this as 0–1; app scores/shows 0–100 (range 8–30)
            )
        case .bloodPressureSystolic:
            return MetricConfig(
                sampleType: HKQuantityType(.bloodPressureSystolic),
                quantityType: HKQuantityType(.bloodPressureSystolic),
                unit: .millimeterOfMercury(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .bloodPressureDiastolic:
            return MetricConfig(
                sampleType: HKQuantityType(.bloodPressureDiastolic),
                quantityType: HKQuantityType(.bloodPressureDiastolic),
                unit: .millimeterOfMercury(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .respiratoryRate:
            return MetricConfig(
                sampleType: HKQuantityType(.respiratoryRate),
                quantityType: HKQuantityType(.respiratoryRate),
                unit: HKUnit.count().unitDivided(by: .minute()),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .bodyTemperature:
            return MetricConfig(
                sampleType: HKQuantityType(.bodyTemperature),
                quantityType: HKQuantityType(.bodyTemperature),
                unit: .degreeCelsius(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .appleSleepingWristTemperature:
            return MetricConfig(
                sampleType: HKQuantityType(.appleSleepingWristTemperature),
                quantityType: HKQuantityType(.appleSleepingWristTemperature),
                unit: .degreeCelsius(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .leanBodyMass:
            return MetricConfig(
                sampleType: HKQuantityType(.leanBodyMass),
                quantityType: HKQuantityType(.leanBodyMass),
                unit: .gramUnit(with: .kilo),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .waistCircumference:
            return MetricConfig(
                sampleType: HKQuantityType(.waistCircumference),
                quantityType: HKQuantityType(.waistCircumference),
                unit: .meterUnit(with: .centi),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .vo2Max:
            return MetricConfig(
                sampleType: HKQuantityType(.vo2Max),
                quantityType: HKQuantityType(.vo2Max),
                unit: HKUnit(from: "mL/kg*min"),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .peakExpiratoryFlowRate:
            return MetricConfig(
                sampleType: HKQuantityType(.peakExpiratoryFlowRate),
                quantityType: HKQuantityType(.peakExpiratoryFlowRate),
                unit: HKUnit.liter().unitDivided(by: .minute()),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .forcedVitalCapacity:
            return MetricConfig(
                sampleType: HKQuantityType(.forcedVitalCapacity),
                quantityType: HKQuantityType(.forcedVitalCapacity),
                unit: .liter(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .forcedExpiratoryVolume1:
            return MetricConfig(
                sampleType: HKQuantityType(.forcedExpiratoryVolume1),
                quantityType: HKQuantityType(.forcedExpiratoryVolume1),
                unit: .liter(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        default:
            preconditionFailure("bodyAndVitalsConfig called with non-body metric: \(metric)")
        }
    }

    // MARK: - Mindfulness / Nutrition / Metabolic

    private static func mindfulnessAndNutritionConfig(for metric: HealthMetric) -> MetricConfig {
        switch metric {
        case .mindfulMinutes:
            return MetricConfig(
                sampleType: HKCategoryType(.mindfulSession),
                quantityType: nil,
                unit: .minute(),
                strategy: .categorySample,
                statisticsOption: .cumulativeSum
            )
        case .timeInDaylight:
            return MetricConfig(
                sampleType: HKQuantityType(.timeInDaylight),
                quantityType: HKQuantityType(.timeInDaylight),
                unit: .minute(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .electrodermalActivity:
            return MetricConfig(
                sampleType: HKQuantityType(.electrodermalActivity),
                quantityType: HKQuantityType(.electrodermalActivity),
                unit: HKUnit(from: "mcS"),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .waterIntake:
            return MetricConfig(
                sampleType: HKQuantityType(.dietaryWater),
                quantityType: HKQuantityType(.dietaryWater),
                unit: HKUnit.literUnit(with: .milli),  // app scores/shows water in mL (range 1500–4000)
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .caffeineIntake:
            return MetricConfig(
                sampleType: HKQuantityType(.dietaryCaffeine),
                quantityType: HKQuantityType(.dietaryCaffeine),
                unit: .gramUnit(with: .milli),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .proteinIntake:
            return MetricConfig(
                sampleType: HKQuantityType(.dietaryProtein),
                quantityType: HKQuantityType(.dietaryProtein),
                unit: .gram(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .fiberIntake:
            return MetricConfig(
                sampleType: HKQuantityType(.dietaryFiber),
                quantityType: HKQuantityType(.dietaryFiber),
                unit: .gram(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .sugarIntake:
            return MetricConfig(
                sampleType: HKQuantityType(.dietarySugar),
                quantityType: HKQuantityType(.dietarySugar),
                unit: .gram(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .sodiumIntake:
            return MetricConfig(
                sampleType: HKQuantityType(.dietarySodium),
                quantityType: HKQuantityType(.dietarySodium),
                unit: .gramUnit(with: .milli),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .totalCaloriesIntake:
            return MetricConfig(
                sampleType: HKQuantityType(.dietaryEnergyConsumed),
                quantityType: HKQuantityType(.dietaryEnergyConsumed),
                unit: .kilocalorie(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .carbohydrateIntake:
            return MetricConfig(
                sampleType: HKQuantityType(.dietaryCarbohydrates),
                quantityType: HKQuantityType(.dietaryCarbohydrates),
                unit: .gram(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .fatIntake:
            return MetricConfig(
                sampleType: HKQuantityType(.dietaryFatTotal),
                quantityType: HKQuantityType(.dietaryFatTotal),
                unit: .gram(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        case .bloodGlucose:
            return MetricConfig(
                sampleType: HKQuantityType(.bloodGlucose),
                quantityType: HKQuantityType(.bloodGlucose),
                unit: HKUnit(from: "mg/dL"),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .insulinDelivery:
            return MetricConfig(
                sampleType: HKQuantityType(.insulinDelivery),
                quantityType: HKQuantityType(.insulinDelivery),
                unit: .internationalUnit(),
                strategy: .statisticsDaily,
                statisticsOption: .cumulativeSum
            )
        default:
            preconditionFailure("mindfulnessAndNutritionConfig called with non-nutrition metric: \(metric)")
        }
    }

    // MARK: - Misc (workouts, hearing, water sports)

    private static func miscConfig(for metric: HealthMetric) -> MetricConfig {
        switch metric {
        case .workoutCount, .workoutDuration:
            return MetricConfig(
                sampleType: HKWorkoutType.workoutType(),
                quantityType: nil,
                unit: metric == .workoutCount ? .count() : .minute(),
                strategy: .workoutQuery,
                statisticsOption: .cumulativeSum
            )

        // MARK: - Hearing
        case .headphoneAudioExposure:
            return MetricConfig(
                sampleType: HKQuantityType(.headphoneAudioExposure),
                quantityType: HKQuantityType(.headphoneAudioExposure),
                unit: .decibelAWeightedSoundPressureLevel(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )
        case .environmentalAudioExposure:
            return MetricConfig(
                sampleType: HKQuantityType(.environmentalAudioExposure),
                quantityType: HKQuantityType(.environmentalAudioExposure),
                unit: .decibelAWeightedSoundPressureLevel(),
                strategy: .statisticsDaily,
                statisticsOption: .discreteAverage
            )

        // MARK: - Water Sports
        case .underwaterDepth:
            return MetricConfig(
                sampleType: HKQuantityType(.underwaterDepth),
                quantityType: HKQuantityType(.underwaterDepth),
                unit: .meter(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .waterTemperature:
            return MetricConfig(
                sampleType: HKQuantityType(.waterTemperature),
                quantityType: HKQuantityType(.waterTemperature),
                unit: .degreeCelsius(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        default:
            preconditionFailure("miscConfig called with non-misc metric: \(metric)")
        }
    }
}
