import Foundation
import HealthKit

/// All health metrics tracked by HealthPulse from Apple Watch / HealthKit
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

    // MARK: - Workouts
    case workoutCount
    case workoutDuration

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
        case .workoutCount: return "Workout Count"
        case .workoutDuration: return "Workout Duration"
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
        case .steps: return "steps"
        case .activeCalories, .basalCalories: return "kcal"
        case .exerciseMinutes: return "min"
        case .standHours: return "hrs"
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming: return "km"
        case .flightsClimbed: return "flights"
        case .swimmingStrokeCount: return "strokes"
        case .appleMoveTime: return "min"
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
        case .mindfulMinutes: return "min"
        case .timeInDaylight: return "min"
        case .electrodermalActivity: return "μS"
        case .walkingSpeed: return "km/h"
        case .walkingStepLength: return "cm"
        case .walkingAsymmetry: return "%"
        case .walkingDoubleSupportPercentage: return "%"
        case .stairAscentSpeed, .stairDescentSpeed: return "m/s"
        case .sixMinuteWalkTestDistance: return "m"
        case .workoutCount: return ""
        case .workoutDuration: return "min"
        }
    }

    var category: HealthCategory {
        switch self {
        case .heartRate, .restingHeartRate, .heartRateVariability,
             .walkingHeartRateAverage, .heartRateRecovery,
             .atrialFibrillationBurden, .peripheralPerfusionIndex:
            return .heart
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake:
            return .sleep
        case .steps, .activeCalories, .basalCalories, .exerciseMinutes, .standHours,
             .distanceWalkingRunning, .flightsClimbed,
             .distanceCycling, .distanceSwimming, .swimmingStrokeCount, .appleMoveTime:
            return .activity
        case .weight, .bmi, .bodyFatPercentage, .bloodPressureSystolic,
             .bloodPressureDiastolic, .bodyTemperature,
             .appleSleepingWristTemperature, .leanBodyMass, .waistCircumference:
            return .body
        case .vo2Max, .bloodOxygen, .respiratoryRate,
             .peakExpiratoryFlowRate, .forcedVitalCapacity:
            return .respiratory
        case .mindfulMinutes, .timeInDaylight, .electrodermalActivity:
            return .mindfulness
        case .walkingSpeed, .walkingStepLength, .walkingAsymmetry,
             .walkingDoubleSupportPercentage, .stairAscentSpeed, .stairDescentSpeed,
             .sixMinuteWalkTestDistance:
            return .mobility
        case .workoutCount, .workoutDuration:
            return .activity
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
             .mindfulMinutes, .timeInDaylight,
             .stairAscentSpeed, .stairDescentSpeed, .sixMinuteWalkTestDistance:
            return true
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage,
             .sleepAwake, .walkingAsymmetry, .bmi, .bodyFatPercentage,
             .bloodPressureSystolic, .bloodPressureDiastolic, .respiratoryRate,
             .bodyTemperature, .basalCalories, .sleepCore,
             .atrialFibrillationBurden, .walkingDoubleSupportPercentage,
             .electrodermalActivity, .peripheralPerfusionIndex,
             .appleSleepingWristTemperature, .waistCircumference:
            return false
        case .weight:
            return false // context-dependent, default to false
        }
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
        case .sleepDuration, .sleepREM, .sleepDeep, .sleepCore, .sleepAwake:
            return "bed.double.fill"
        case .steps, .distanceWalkingRunning:
            return "figure.walk"
        case .activeCalories, .basalCalories: return "flame.fill"
        case .exerciseMinutes: return "figure.run"
        case .standHours: return "figure.stand"
        case .flightsClimbed: return "figure.stairs"
        case .distanceCycling: return "figure.outdoor.cycle"
        case .distanceSwimming, .swimmingStrokeCount: return "figure.pool.swim"
        case .appleMoveTime: return "figure.walk.motion"
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
        case .workoutCount, .workoutDuration: return "dumbbell.fill"
        }
    }
}
