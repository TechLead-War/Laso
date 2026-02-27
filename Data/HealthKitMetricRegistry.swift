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
    }

    static func config(for metric: HealthMetric) -> MetricConfig {
        switch metric {
        case .heartRate:
            return MetricConfig(
                sampleType: HKQuantityType(.heartRate),
                quantityType: HKQuantityType(.heartRate),
                unit: HKUnit.count().unitDivided(by: .minute()),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .restingHeartRate:
            return MetricConfig(
                sampleType: HKQuantityType(.restingHeartRate),
                quantityType: HKQuantityType(.restingHeartRate),
                unit: HKUnit.count().unitDivided(by: .minute()),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .heartRateVariability:
            return MetricConfig(
                sampleType: HKQuantityType(.heartRateVariabilitySDNN),
                quantityType: HKQuantityType(.heartRateVariabilitySDNN),
                unit: HKUnit.secondUnit(with: .milli),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .walkingHeartRateAverage:
            return MetricConfig(
                sampleType: HKQuantityType(.walkingHeartRateAverage),
                quantityType: HKQuantityType(.walkingHeartRateAverage),
                unit: HKUnit.count().unitDivided(by: .minute()),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .heartRateRecovery:
            return MetricConfig(
                sampleType: HKQuantityType(.heartRateRecoveryOneMinute),
                quantityType: HKQuantityType(.heartRateRecoveryOneMinute),
                unit: HKUnit.count().unitDivided(by: .minute()),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .atrialFibrillationBurden:
            return MetricConfig(
                sampleType: HKQuantityType(.atrialFibrillationBurden),
                quantityType: HKQuantityType(.atrialFibrillationBurden),
                unit: .percent(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .peripheralPerfusionIndex:
            return MetricConfig(
                sampleType: HKQuantityType(.peripheralPerfusionIndex),
                quantityType: HKQuantityType(.peripheralPerfusionIndex),
                unit: .percent(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .bloodOxygen:
            return MetricConfig(
                sampleType: HKQuantityType(.oxygenSaturation),
                quantityType: HKQuantityType(.oxygenSaturation),
                unit: .percent(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake:
            return MetricConfig(
                sampleType: HKCategoryType(.sleepAnalysis),
                quantityType: nil,
                unit: .hour(),
                strategy: .categorySample,
                statisticsOption: .cumulativeSum
            )
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
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .walkingStepLength:
            return MetricConfig(
                sampleType: HKQuantityType(.walkingStepLength),
                quantityType: HKQuantityType(.walkingStepLength),
                unit: .meterUnit(with: .centi),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .walkingAsymmetry:
            return MetricConfig(
                sampleType: HKQuantityType(.walkingAsymmetryPercentage),
                quantityType: HKQuantityType(.walkingAsymmetryPercentage),
                unit: .percent(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .walkingDoubleSupportPercentage:
            return MetricConfig(
                sampleType: HKQuantityType(.walkingDoubleSupportPercentage),
                quantityType: HKQuantityType(.walkingDoubleSupportPercentage),
                unit: .percent(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .stairAscentSpeed:
            return MetricConfig(
                sampleType: HKQuantityType(.stairAscentSpeed),
                quantityType: HKQuantityType(.stairAscentSpeed),
                unit: HKUnit.meter().unitDivided(by: .second()),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .stairDescentSpeed:
            return MetricConfig(
                sampleType: HKQuantityType(.stairDescentSpeed),
                quantityType: HKQuantityType(.stairDescentSpeed),
                unit: HKUnit.meter().unitDivided(by: .second()),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .sixMinuteWalkTestDistance:
            return MetricConfig(
                sampleType: HKQuantityType(.sixMinuteWalkTestDistance),
                quantityType: HKQuantityType(.sixMinuteWalkTestDistance),
                unit: .meter(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .weight:
            return MetricConfig(
                sampleType: HKQuantityType(.bodyMass),
                quantityType: HKQuantityType(.bodyMass),
                unit: .gramUnit(with: .kilo),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .bmi:
            return MetricConfig(
                sampleType: HKQuantityType(.bodyMassIndex),
                quantityType: HKQuantityType(.bodyMassIndex),
                unit: .count(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .bodyFatPercentage:
            return MetricConfig(
                sampleType: HKQuantityType(.bodyFatPercentage),
                quantityType: HKQuantityType(.bodyFatPercentage),
                unit: .percent(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
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
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .bodyTemperature:
            return MetricConfig(
                sampleType: HKQuantityType(.bodyTemperature),
                quantityType: HKQuantityType(.bodyTemperature),
                unit: .degreeCelsius(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .appleSleepingWristTemperature:
            return MetricConfig(
                sampleType: HKQuantityType(.appleSleepingWristTemperature),
                quantityType: HKQuantityType(.appleSleepingWristTemperature),
                unit: .degreeCelsius(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .leanBodyMass:
            return MetricConfig(
                sampleType: HKQuantityType(.leanBodyMass),
                quantityType: HKQuantityType(.leanBodyMass),
                unit: .gramUnit(with: .kilo),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .waistCircumference:
            return MetricConfig(
                sampleType: HKQuantityType(.waistCircumference),
                quantityType: HKQuantityType(.waistCircumference),
                unit: .meterUnit(with: .centi),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .vo2Max:
            return MetricConfig(
                sampleType: HKQuantityType(.vo2Max),
                quantityType: HKQuantityType(.vo2Max),
                unit: HKUnit(from: "mL/kg*min"),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .peakExpiratoryFlowRate:
            return MetricConfig(
                sampleType: HKQuantityType(.peakExpiratoryFlowRate),
                quantityType: HKQuantityType(.peakExpiratoryFlowRate),
                unit: HKUnit.liter().unitDivided(by: .minute()),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .forcedVitalCapacity:
            return MetricConfig(
                sampleType: HKQuantityType(.forcedVitalCapacity),
                quantityType: HKQuantityType(.forcedVitalCapacity),
                unit: .liter(),
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
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
                strategy: .quantitySample,
                statisticsOption: .discreteAverage
            )
        case .workoutCount, .workoutDuration:
            return MetricConfig(
                sampleType: HKWorkoutType.workoutType(),
                quantityType: nil,
                unit: metric == .workoutCount ? .count() : .minute(),
                strategy: .workoutQuery,
                statisticsOption: .cumulativeSum
            )
        }
    }

    /// All HKSampleTypes needed for HealthKit authorization
    static var allSampleTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        for metric in HealthMetric.allCases {
            if let sampleType = config(for: metric).sampleType {
                types.insert(sampleType)
            }
        }
        return types
    }
}
