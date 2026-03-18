import Foundation
import HealthKit

/// All health metrics tracked by Laso from Apple Watch / HealthKit
enum HealthMetric: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }

    // MARK: - Heart & Cardio
    case heartRate
    case restingHeartRate
    case heartRateVariability // SDNN
    case walkingHeartRateAverage
    case heartRateRecovery
    case atrialFibrillationBurden
    case peripheralPerfusionIndex

    // MARK: - Sleep
    case sleepDuration
    case sleepREM
    case sleepDeep
    case sleepCore
    case sleepAwake
    case sleepBreathingDisturbances

    // MARK: - Activity
    case steps
    case activeCalories
    case basalCalories
    case exerciseMinutes
    case standHours
    case distanceWalkingRunning
    case flightsClimbed
    case distanceCycling
    case distanceSwimming
    case swimmingStrokeCount
    case appleMoveTime
    case runningPower
    case runningGroundContactTime
    case runningVerticalOscillation
    case runningStrideLength
    case underwaterDepth
    case waterTemperature

    // MARK: - Body & Vitals
    case weight
    case bmi
    case bodyFatPercentage
    case bloodPressureSystolic
    case bloodPressureDiastolic
    case bodyTemperature
    case appleSleepingWristTemperature
    case leanBodyMass
    case waistCircumference

    // MARK: - Respiratory
    case vo2Max
    case bloodOxygen
    case respiratoryRate
    case peakExpiratoryFlowRate
    case forcedVitalCapacity
    case forcedExpiratoryVolume1

    // MARK: - Mindfulness
    case mindfulMinutes
    case timeInDaylight
    case electrodermalActivity

    // MARK: - Mobility
    case walkingSpeed
    case walkingStepLength
    case walkingAsymmetry
    case walkingDoubleSupportPercentage
    case stairAscentSpeed
    case stairDescentSpeed
    case sixMinuteWalkTestDistance
    case walkingSteadiness
    case numberOfTimesFallen

    // MARK: - Nutrition
    case waterIntake
    case caffeineIntake
    case proteinIntake
    case fiberIntake
    case sugarIntake
    case sodiumIntake
    case totalCaloriesIntake
    case carbohydrateIntake
    case fatIntake

    // MARK: - Metabolic
    case bloodGlucose
    case insulinDelivery

    // MARK: - Workouts
    case workoutCount
    case workoutDuration

    // MARK: - Hearing
    case headphoneAudioExposure
    case environmentalAudioExposure

    var displayName: String {
        switch self {
        case .heartRate: return "Heart Rate"
        case .restingHeartRate: return "Resting Heart Rate"
        case .heartRateVariability: return "Heart Rate Variability"
        case .walkingHeartRateAverage: return "Walking HR Average"
        case .heartRateRecovery: return "HR Recovery"
        case .atrialFibrillationBurden: return "AFib Burden"
        case .peripheralPerfusionIndex: return "Perfusion Index"
        case .sleepDuration: return "Sleep Duration"
        case .sleepREM: return "REM Sleep"
        case .sleepDeep: return "Deep Sleep"
        case .sleepCore: return "Core Sleep"
        case .sleepAwake: return "Awake Time"
        case .sleepBreathingDisturbances: return "Breathing Disturbances"
        case .steps: return "Steps"
        case .activeCalories: return "Active Calories"
        case .basalCalories: return "Basal Calories"
        case .exerciseMinutes: return "Exercise Minutes"
        case .standHours: return "Stand Hours"
        case .distanceWalkingRunning: return "Distance"
        case .flightsClimbed: return "Flights Climbed"
        case .distanceCycling: return "Cycling Distance"
        case .distanceSwimming: return "Swimming Distance"
        case .swimmingStrokeCount: return "Swimming Strokes"
        case .appleMoveTime: return "Move Time"
        case .runningPower: return "Running Power"
        case .runningGroundContactTime: return "Ground Contact Time"
        case .runningVerticalOscillation: return "Vertical Oscillation"
        case .runningStrideLength: return "Running Stride"
        case .underwaterDepth: return "Dive Depth"
        case .waterTemperature: return "Water Temperature"
        case .weight: return "Weight"
        case .bmi: return "BMI"
        case .bodyFatPercentage: return "Body Fat %"
        case .bloodPressureSystolic: return "Systolic BP"
        case .bloodPressureDiastolic: return "Diastolic BP"
        case .bodyTemperature: return "Body Temperature"
        case .appleSleepingWristTemperature: return "Wrist Temperature"
        case .leanBodyMass: return "Lean Body Mass"
        case .waistCircumference: return "Waist Circumference"
        case .vo2Max: return "VO2 Max"
        case .bloodOxygen: return "Blood Oxygen"
        case .respiratoryRate: return "Respiratory Rate"
        case .peakExpiratoryFlowRate: return "Peak Flow Rate"
        case .forcedVitalCapacity: return "Forced Vital Capacity"
        case .forcedExpiratoryVolume1: return "FEV1"
        case .mindfulMinutes: return "Mindful Minutes"
        case .timeInDaylight: return "Time in Daylight"
        case .electrodermalActivity: return "Electrodermal Activity"
        case .walkingSpeed: return "Walking Speed"
        case .walkingStepLength: return "Step Length"
        case .walkingAsymmetry: return "Walking Asymmetry"
        case .walkingDoubleSupportPercentage: return "Double Support %"
        case .stairAscentSpeed: return "Stair Ascent Speed"
        case .stairDescentSpeed: return "Stair Descent Speed"
        case .sixMinuteWalkTestDistance: return "6-Min Walk Distance"
        case .walkingSteadiness: return "Walking Steadiness"
        case .numberOfTimesFallen: return "Falls Detected"
        case .waterIntake: return "Water Intake"
        case .caffeineIntake: return "Caffeine"
        case .proteinIntake: return "Protein"
        case .fiberIntake: return "Fiber"
        case .sugarIntake: return "Sugar"
        case .sodiumIntake: return "Sodium"
        case .totalCaloriesIntake: return "Calories (Diet)"
        case .carbohydrateIntake: return "Carbs"
        case .fatIntake: return "Fat"
        case .bloodGlucose: return "Blood Glucose"
        case .insulinDelivery: return "Insulin Delivery"
        case .workoutCount: return "Workout Count"
        case .workoutDuration: return "Workout Duration"
        case .headphoneAudioExposure: return "Headphone Audio"
        case .environmentalAudioExposure: return "Environmental Sound"
        }
    }

    var unit: String {
        switch self {
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .heartRateRecovery:
            return "bpm"
        case .heartRateVariability: return "ms"
        case .atrialFibrillationBurden: return "%"
        case .peripheralPerfusionIndex: return "%"
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake:
            return "hrs"
        case .sleepBreathingDisturbances: return "events/hr"
        case .steps: return "steps"
        case .activeCalories, .basalCalories: return "kcal"
        case .exerciseMinutes: return "min"
        case .standHours: return "hrs"
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming: return "km"
        case .flightsClimbed: return "flights"
        case .swimmingStrokeCount: return "strokes"
        case .appleMoveTime: return "min"
        case .runningPower: return "W"
        case .runningGroundContactTime: return "ms"
        case .runningVerticalOscillation: return "cm"
        case .runningStrideLength: return "m"
        case .underwaterDepth: return "m"
        case .waterTemperature: return "°C"
        case .weight, .leanBodyMass: return "kg"
        case .bmi: return ""
        case .bodyFatPercentage: return "%"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "mmHg"
        case .bodyTemperature: return "°C"
        case .appleSleepingWristTemperature: return "°C"
        case .waistCircumference: return "cm"
        case .vo2Max: return "mL/kg/min"
        case .bloodOxygen: return "%"
        case .respiratoryRate: return "br/min"
        case .peakExpiratoryFlowRate: return "L/min"
        case .forcedVitalCapacity: return "L"
        case .forcedExpiratoryVolume1: return "L"
        case .mindfulMinutes: return "min"
        case .timeInDaylight: return "min"
        case .electrodermalActivity: return "μS"
        case .walkingSpeed: return "km/h"
        case .walkingStepLength: return "cm"
        case .walkingAsymmetry: return "%"
        case .walkingDoubleSupportPercentage: return "%"
        case .stairAscentSpeed, .stairDescentSpeed: return "m/s"
        case .sixMinuteWalkTestDistance: return "m"
        case .walkingSteadiness: return "%"
        case .numberOfTimesFallen: return ""
        case .waterIntake: return "mL"
        case .caffeineIntake: return "mg"
        case .proteinIntake: return "g"
        case .fiberIntake: return "g"
        case .sugarIntake: return "g"
        case .sodiumIntake: return "mg"
        case .totalCaloriesIntake: return "kcal"
        case .carbohydrateIntake: return "g"
        case .fatIntake: return "g"
        case .bloodGlucose: return "mg/dL"
        case .insulinDelivery: return "IU"
        case .workoutCount: return ""
        case .workoutDuration: return "min"
        case .headphoneAudioExposure: return "dB"
        case .environmentalAudioExposure: return "dB"
        }
    }

    var category: HealthCategory {
        switch self {
        case .heartRate, .restingHeartRate, .heartRateVariability,
             .walkingHeartRateAverage, .heartRateRecovery,
             .atrialFibrillationBurden, .peripheralPerfusionIndex:
            return .heart
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake,
             .sleepBreathingDisturbances:
            return .sleep
        case .steps, .activeCalories, .basalCalories, .exerciseMinutes, .standHours,
             .distanceWalkingRunning, .flightsClimbed,
             .distanceCycling, .distanceSwimming, .swimmingStrokeCount, .appleMoveTime,
             .runningPower, .runningGroundContactTime, .runningVerticalOscillation,
             .runningStrideLength, .underwaterDepth, .waterTemperature:
            return .activity
        case .weight, .bmi, .bodyFatPercentage, .bloodPressureSystolic,
             .bloodPressureDiastolic, .bodyTemperature,
             .appleSleepingWristTemperature, .leanBodyMass, .waistCircumference,
             .bloodGlucose, .insulinDelivery:
            return .body
        case .waterIntake, .caffeineIntake, .proteinIntake, .fiberIntake,
             .sugarIntake, .sodiumIntake, .totalCaloriesIntake,
             .carbohydrateIntake, .fatIntake:
            return .nutrition
        case .vo2Max, .bloodOxygen, .respiratoryRate,
             .peakExpiratoryFlowRate, .forcedVitalCapacity, .forcedExpiratoryVolume1:
            return .respiratory
        case .mindfulMinutes, .timeInDaylight, .electrodermalActivity:
            return .mindfulness
        case .walkingSpeed, .walkingStepLength, .walkingAsymmetry,
             .walkingDoubleSupportPercentage, .stairAscentSpeed, .stairDescentSpeed,
             .sixMinuteWalkTestDistance, .walkingSteadiness, .numberOfTimesFallen:
            return .mobility
        case .workoutCount, .workoutDuration:
            return .activity
        case .headphoneAudioExposure, .environmentalAudioExposure:
            return .hearing
        }
    }

    /// Whether a higher value is better for this metric
    var higherIsBetter: Bool {
        switch self {
        case .heartRateVariability, .vo2Max, .steps, .activeCalories, .exerciseMinutes,
             .standHours, .distanceWalkingRunning, .flightsClimbed, .walkingSpeed,
             .walkingStepLength, .sleepDuration, .sleepREM, .sleepDeep,
             .bloodOxygen, .heartRateRecovery, .workoutCount, .workoutDuration,
             .distanceCycling, .distanceSwimming, .swimmingStrokeCount, .appleMoveTime,
             .leanBodyMass, .peakExpiratoryFlowRate, .forcedVitalCapacity,
             .mindfulMinutes, .timeInDaylight, .waterIntake,
             .stairAscentSpeed, .stairDescentSpeed, .sixMinuteWalkTestDistance,
             .proteinIntake, .fiberIntake,
             .runningPower, .runningStrideLength,
             .forcedExpiratoryVolume1, .walkingSteadiness, .underwaterDepth:
            return true
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage,
             .sleepAwake, .walkingAsymmetry, .bmi, .bodyFatPercentage,
             .bloodPressureSystolic, .bloodPressureDiastolic, .respiratoryRate,
             .bodyTemperature, .basalCalories, .sleepCore,
             .atrialFibrillationBurden, .walkingDoubleSupportPercentage,
             .electrodermalActivity, .peripheralPerfusionIndex,
             .appleSleepingWristTemperature, .waistCircumference,
             .bloodGlucose,
             .sugarIntake, .sodiumIntake, .caffeineIntake,
             .totalCaloriesIntake, .carbohydrateIntake, .fatIntake,
             .sleepBreathingDisturbances,
             .runningGroundContactTime, .runningVerticalOscillation,
             .numberOfTimesFallen, .insulinDelivery,
             .headphoneAudioExposure, .environmentalAudioExposure,
             .waterTemperature:
            return false
        case .weight:
            return false // context-dependent, default to false
        }
    }

    /// Formats a value according to this metric's natural precision
    func formatValue(_ value: Double) -> String {
        switch self {
        case .steps, .activeCalories, .basalCalories, .flightsClimbed, .waterIntake,
             .caffeineIntake, .sodiumIntake, .totalCaloriesIntake,
             .runningPower, .runningGroundContactTime, .numberOfTimesFallen,
             .headphoneAudioExposure, .environmentalAudioExposure:
            return String(format: "%.0f", value)
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage, .heartRateRecovery,
             .bloodPressureSystolic, .bloodPressureDiastolic, .bloodGlucose,
             .proteinIntake, .fiberIntake, .sugarIntake, .carbohydrateIntake, .fatIntake:
            return String(format: "%.0f", value)
        default:
            return String(format: "%.1f", value)
        }
    }

    /// Formats a value with its unit appended (e.g. "72 bpm", "7.5 hrs")
    func formatWithUnit(_ value: Double) -> String {
        let formatted = formatValue(value)
        let u = unit
        return u.isEmpty ? formatted : "\(formatted) \(u)"
    }

    var systemImageName: String {
        switch self {
        case .heartRate, .restingHeartRate, .heartRateVariability, .heartRateRecovery,
             .walkingHeartRateAverage:
            return "heart.fill"
        case .atrialFibrillationBurden: return "waveform.path.ecg.rectangle"
        case .peripheralPerfusionIndex: return "hand.raised.fill"
        case .vo2Max: return "lungs.fill"
        case .bloodOxygen: return "drop.fill"
        case .respiratoryRate: return "wind"
        case .peakExpiratoryFlowRate: return "gauge.with.dots.needle.33percent"
        case .forcedVitalCapacity: return "chart.bar.fill"
        case .forcedExpiratoryVolume1: return "lungs.fill"
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake:
            return "bed.double.fill"
        case .sleepBreathingDisturbances: return "nose"
        case .steps, .distanceWalkingRunning:
            return "figure.walk"
        case .activeCalories, .basalCalories: return "flame.fill"
        case .exerciseMinutes: return "figure.run"
        case .standHours: return "figure.stand"
        case .flightsClimbed: return "figure.stairs"
        case .distanceCycling: return "figure.outdoor.cycle"
        case .distanceSwimming, .swimmingStrokeCount: return "figure.pool.swim"
        case .appleMoveTime: return "figure.walk.motion"
        case .runningPower: return "bolt.fill"
        case .runningGroundContactTime: return "shoe.fill"
        case .runningVerticalOscillation: return "arrow.up.arrow.down"
        case .runningStrideLength: return "ruler"
        case .underwaterDepth: return "water.waves"
        case .waterTemperature: return "thermometer.variable.and.figure"
        case .weight, .bmi, .bodyFatPercentage: return "scalemass.fill"
        case .bloodPressureSystolic, .bloodPressureDiastolic: return "waveform.path.ecg"
        case .bodyTemperature: return "thermometer.medium"
        case .appleSleepingWristTemperature: return "thermometer.low"
        case .leanBodyMass: return "figure.strengthtraining.traditional"
        case .waistCircumference: return "ruler"
        case .mindfulMinutes: return "brain.head.profile"
        case .timeInDaylight: return "sun.max.fill"
        case .electrodermalActivity: return "hand.point.up.braille.fill"
        case .walkingSpeed, .walkingStepLength, .walkingAsymmetry:
            return "figure.walk"
        case .walkingDoubleSupportPercentage: return "figure.walk.arrival"
        case .stairAscentSpeed: return "figure.stairs"
        case .stairDescentSpeed: return "figure.stairs"
        case .sixMinuteWalkTestDistance: return "figure.walk.diamond.fill"
        case .walkingSteadiness: return "figure.fall"
        case .numberOfTimesFallen: return "figure.fall"
        case .waterIntake: return "drop.fill"
        case .caffeineIntake: return "cup.and.saucer.fill"
        case .proteinIntake: return "fork.knife"
        case .fiberIntake: return "leaf.fill"
        case .sugarIntake: return "cube.fill"
        case .sodiumIntake: return "drop.triangle.fill"
        case .totalCaloriesIntake: return "flame.fill"
        case .carbohydrateIntake: return "chart.pie.fill"
        case .fatIntake: return "drop.halffull"
        case .bloodGlucose: return "drop.fill"
        case .insulinDelivery: return "syringe.fill"
        case .workoutCount, .workoutDuration: return "dumbbell.fill"
        case .headphoneAudioExposure: return "headphones"
        case .environmentalAudioExposure: return "ear.badge.waveform"
        }
    }
}
