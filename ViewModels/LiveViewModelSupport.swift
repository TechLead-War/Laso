import Foundation
import HealthKit
import Observation
import SwiftUI

extension LiveViewModel {
    enum HeartRateZone: String {
        case rest = "Rest"
        case warmUp = "Warm Up"
        case fatBurn = "Fat Burn"
        case cardio = "Cardio"
        case peak = "Peak"
        case extreme = "Extreme"

        var color: Color {
            switch self {
            case .rest: return .gray
            case .warmUp: return .blue
            case .fatBurn: return .green
            case .cardio: return .yellow
            case .peak: return .orange
            case .extreme: return .red
            }
        }

        var index: Int {
            switch self {
            case .rest: return 0
            case .warmUp: return 1
            case .fatBurn: return 2
            case .cardio: return 3
            case .peak: return 4
            case .extreme: return 5
            }
        }
    }

    enum VitalStatus: Equatable {
        case normal, elevated, low, critical, unknown

        var label: String {
            switch self {
            case .normal: return "Normal"
            case .elevated: return "Elevated"
            case .low: return "Low"
            case .critical: return "Critical"
            case .unknown: return "No Data"
            }
        }

        var color: Color {
            switch self {
            case .normal: return .green
            case .elevated: return .orange
            case .low: return .yellow
            case .critical: return .red
            case .unknown: return .gray
            }
        }
    }

    /// Real-time vitals. HR, SpO2, respiratory rate, blood pressure, body temperature
    @Observable
    final class VitalsData {
        // Heart rate
        var currentHeartRate: Double?
        var heartRateTimestamp: Date?
        var recentHeartRates: [HeartRatePoint] = []
        var heartRateMin30: Double?
        var heartRateMax30: Double?
        var heartRateAvg30: Double?
        var todayHeartRateMin: Double?
        var todayHeartRateMax: Double?

        // Blood oxygen
        var currentBloodOxygen: Double?
        var bloodOxygenTimestamp: Date?

        // Respiratory rate
        var currentRespiratoryRate: Double?
        var respiratoryRateTimestamp: Date?
        var respiratoryRateUnavailable = false

        // Wrist temperature
        var currentWristTemperature: Double?
        var wristTemperatureTimestamp: Date?

        // Blood pressure
        var latestSystolic: Double?
        var latestDiastolic: Double?
        var bloodPressureTimestamp: Date?

        // Body temperature
        var latestBodyTemp: Double?
        var bodyTempTimestamp: Date?

        private static let freshnessThreshold: TimeInterval = 30 * 60

        var heartRateStatus: LiveViewModel.VitalStatus {
            guard let hr = currentHeartRate else { return .unknown }
            if hr > 120 { return .elevated }
            if hr < 45 { return .low }
            return .normal
        }

        var bloodOxygenStatus: LiveViewModel.VitalStatus {
            guard let spo2 = currentBloodOxygen else { return .unknown }
            if spo2 < 92 { return .critical }
            if spo2 < 95 { return .low }
            return .normal
        }

        var respiratoryRateStatus: LiveViewModel.VitalStatus {
            guard let rr = currentRespiratoryRate else { return .unknown }
            if rr > 24 { return .elevated }
            if rr < 10 { return .low }
            return .normal
        }

        var bloodPressureStatus: LiveViewModel.VitalStatus {
            guard let sys = latestSystolic else { return .unknown }
            if sys >= 140 { return .critical }
            if sys >= 130 { return .elevated }
            if sys < 90 { return .low }
            return .normal
        }

        var isHeartRateFresh: Bool {
            guard let ts = heartRateTimestamp else { return false }
            return Date().timeIntervalSince(ts) < Self.freshnessThreshold
        }

        var isBloodOxygenFresh: Bool {
            guard let ts = bloodOxygenTimestamp else { return false }
            return Date().timeIntervalSince(ts) < Self.freshnessThreshold
        }

        var isRespiratoryRateFresh: Bool {
            guard let ts = respiratoryRateTimestamp else { return false }
            return Date().timeIntervalSince(ts) < Self.freshnessThreshold
        }

        var hasAnyData: Bool {
            currentHeartRate != nil || currentBloodOxygen != nil || currentRespiratoryRate != nil
        }

        var hasFreshData: Bool {
            isHeartRateFresh || isBloodOxygenFresh || isRespiratoryRateFresh
        }

        var hasRecentData: Bool {
            let twoHours: TimeInterval = 2 * 3600
            let now = Date()
            if let ts = heartRateTimestamp, now.timeIntervalSince(ts) < twoHours { return true }
            if let ts = bloodOxygenTimestamp, now.timeIntervalSince(ts) < twoHours { return true }
            if let ts = respiratoryRateTimestamp, now.timeIntervalSince(ts) < twoHours { return true }
            return false
        }

        var isStale: Bool { hasAnyData && !hasRecentData }
        var isAging: Bool { hasAnyData && !hasFreshData && hasRecentData }

        var mostRecentTimestamp: Date? {
            [heartRateTimestamp, bloodOxygenTimestamp, respiratoryRateTimestamp]
                .compactMap { $0 }
                .max()
        }
    }

    /// Last night's sleep data
    @Observable
    final class SleepData {
        var lastNightSleepDuration: TimeInterval = 0
        var lastNightDeepSleep: TimeInterval = 0
        var lastNightREMSleep: TimeInterval = 0
        var lastNightCoreSleep: TimeInterval = 0
        var lastNightAwakeTime: TimeInterval = 0

        var hasSleepData: Bool { lastNightSleepDuration > 0 }

        var hasSleepStageBreakdown: Bool {
            lastNightDeepSleep > 0 || lastNightREMSleep > 0 || lastNightCoreSleep > 0
        }

        var sleepQualityLabel: String {
            let hours = lastNightSleepDuration / 3600
            if hours >= 7.5 { return "Great" }
            if hours >= 6.5 { return "Good" }
            if hours >= 5.5 { return "Fair" }
            return "Poor"
        }

        func apply(summary: LiveSleepSummary) {
            lastNightSleepDuration = summary.totalDuration
            lastNightDeepSleep = summary.deepSleep
            lastNightREMSleep = summary.remSleep
            lastNightCoreSleep = summary.coreSleep
            lastNightAwakeTime = summary.awakeTime
        }
    }

    /// Today's cumulative activity and goals
    @Observable
    final class ActivityData {
        var todaySteps: Double = 0
        var todayActiveCalories: Double = 0
        var todayExerciseMinutes: Double = 0
        var todayStandHours: Double = 0
        var todayDistance: Double = 0
        var todayFlightsClimbed: Double = 0
        var todayMindfulMinutes: Double = 0

        var moveGoal: Double = 500
        var exerciseGoal: Double = 30
        var standGoal: Double = 12

        var moveProgress: Double { min(todayActiveCalories / moveGoal, 1.0) }
        var exerciseProgress: Double { min(todayExerciseMinutes / exerciseGoal, 1.0) }
        var standProgress: Double { min(todayStandHours / standGoal, 1.0) }

        var hasAnyData: Bool {
            todaySteps > 0 || todayActiveCalories > 0 || todayExerciseMinutes > 0
        }
    }

    /// Recovery metrics. RHR, HRV, readiness score, stress
    @Observable
    final class RecoveryData {
        var latestRestingHeartRate: Double?
        var latestRestingHeartRateTimestamp: Date?
        var latestHRV: Double?
        var latestHRVTimestamp: Date?
        var latestHeartRateRecovery: Double?
        var readinessScore: Int?
        var readinessConfidence: Int?

        init(readinessStore: ReadinessStore) {
            if let cachedScore = readinessStore.loadCachedScore() {
                readinessScore = cachedScore
            }
        }

        var isReadinessDataFresh: Bool {
            let fortyEightHours: TimeInterval = 48 * 3600
            let now = Date()
            let rhrFresh = latestRestingHeartRateTimestamp.map { now.timeIntervalSince($0) < fortyEightHours } ?? false
            let hrvFresh = latestHRVTimestamp.map { now.timeIntervalSince($0) < fortyEightHours } ?? false
            return rhrFresh || hrvFresh
        }

        var stressLevel: Int? {
            ReadinessScorer.stressLevel(hrv: latestHRV, restingHeartRate: latestRestingHeartRate)
        }

        var stressLabel: String {
            ReadinessScorer.stressLabel(for: stressLevel)
        }

        var stressColor: String {
            ReadinessScorer.stressColorName(for: stressLevel)
        }
    }

    /// Most recent workout info
    @Observable
    final class WorkoutData {
        var lastWorkoutType: String?
        var lastWorkoutDuration: Double?
        var lastWorkoutCalories: Double?
        var lastWorkoutTimestamp: Date?
    }
}

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength"
        case .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .dance: return "Dance"
        case .coreTraining: return "Core"
        case .pilates: return "Pilates"
        case .crossTraining: return "Cross Training"
        case .mixedCardio: return "Mixed Cardio"
        case .stairClimbing: return "Stair Climbing"
        default: return "Workout"
        }
    }

    var systemImageName: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .walking: return "figure.walk"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .yoga: return "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "dumbbell.fill"
        case .highIntensityIntervalTraining: return "bolt.heart.fill"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rower"
        case .dance: return "figure.dance"
        case .stairClimbing: return "figure.stairs"
        default: return "figure.mixed.cardio"
        }
    }
}
