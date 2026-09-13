import Foundation

// MARK: - Workout Plan Types

struct WorkoutPlan {
    let targetDuration: Int // minutes
}

enum TrainingZone: String {
    case restoring = "Restoring"
    case maintaining = "Maintaining"
    case building = "Building"
    case overreaching = "Overreaching"
}

enum WorkoutRecoveryBand: String, CaseIterable {
    case red
    case yellow
    case green

    init(score: Int) {
        if score > WorkoutBandsConfig.greenBandScoreFloor {
            self = .green
        } else if score >= WorkoutBandsConfig.yellowBandScoreFloor {
            self = .yellow
        } else {
            self = .red
        }
    }

    var recoveryScoreSeed: Int {
        switch self {
        case .red:
            return WorkoutBandsConfig.redBandSeed
        case .yellow:
            return WorkoutBandsConfig.yellowBandSeed
        case .green:
            return WorkoutBandsConfig.greenBandSeed
        }
    }
}

// MARK: - Workout Programmer

/// Generates readiness-aware workout plans based on recovery state, health signals, and cycle phase.
struct WorkoutProgrammer {

    static func generatePlan(
        recoveryBand: WorkoutRecoveryBand,
        healthSignals: HealthSignalFlags = .none,
        cyclePhase: CyclePhaseModifier? = nil
    ) -> WorkoutPlan {
        generatePlan(
            recoveryScore: recoveryBand.recoveryScoreSeed,
            healthSignals: healthSignals,
            cyclePhase: cyclePhase
        )
    }

    /// Generate a workout plan based on the user's current recovery and health state.
    static func generatePlan(
        recoveryScore: Int,
        healthSignals: HealthSignalFlags = .none,
        cyclePhase: CyclePhaseModifier? = nil
    ) -> WorkoutPlan {
        // Determine base zone from recovery score
        var zone = zoneForRecovery(recoveryScore)

        // Apply health signal modifiers
        if healthSignals.contains(.burnout) {
            zone = .restoring
        } else if healthSignals.contains(.fatigue) || healthSignals.contains(.overtraining) {
            zone = downgradeZone(zone)
        }

        // Apply sleep debt modifier
        if healthSignals.contains(.sleepDebt) {
            zone = downgradeZone(zone)
        }

        // Apply cycle phase modifiers
        if cyclePhase == .menstrual, zone != .restoring {
            zone = min(zone, .maintaining)
        }

        // Generate zone-specific plan
        switch zone {
        case .restoring:
            return WorkoutPlan(targetDuration: 30)
        case .maintaining:
            return WorkoutPlan(targetDuration: 40)
        case .building:
            return WorkoutPlan(targetDuration: 55)
        case .overreaching:
            return WorkoutPlan(targetDuration: 60)
        }
    }

    // MARK: - Zone Selection

    private static func zoneForRecovery(_ score: Int) -> TrainingZone {
        switch score {
        case 0..<WorkoutBandsConfig.zoneRestoringScoreCeiling: return .restoring
        case WorkoutBandsConfig.zoneRestoringScoreCeiling..<WorkoutBandsConfig.zoneMaintainingScoreCeiling: return .maintaining
        case WorkoutBandsConfig.zoneMaintainingScoreCeiling..<WorkoutBandsConfig.zoneBuildingScoreCeiling: return .building
        default: return .overreaching
        }
    }

    private static func downgradeZone(_ zone: TrainingZone) -> TrainingZone {
        switch zone {
        case .overreaching: return .building
        case .building: return .maintaining
        case .maintaining: return .restoring
        case .restoring: return .restoring
        }
    }

    private static func min(_ a: TrainingZone, _ b: TrainingZone) -> TrainingZone {
        let order: [TrainingZone] = [.restoring, .maintaining, .building, .overreaching]
        let aIdx = order.firstIndex(of: a) ?? 0
        let bIdx = order.firstIndex(of: b) ?? 0
        return order[Swift.min(aIdx, bIdx)]
    }
}

// MARK: - Health Signal Flags

struct HealthSignalFlags: OptionSet {
    let rawValue: Int

    static let none         = HealthSignalFlags([])
    static let fatigue      = HealthSignalFlags(rawValue: 1 << 0)
    static let overtraining = HealthSignalFlags(rawValue: 1 << 1)
    static let burnout      = HealthSignalFlags(rawValue: 1 << 2)
    static let sleepDebt    = HealthSignalFlags(rawValue: 1 << 3)
}

// MARK: - Cycle Phase Modifier

enum CyclePhaseModifier: String {
    case menstrual
    case follicular
    case ovulatory
    case luteal
}

extension MenstrualCycleTracker.CyclePhase {
    var workoutModifier: CyclePhaseModifier {
        switch self {
        case .menstrual:
            return .menstrual
        case .follicular:
            return .follicular
        case .ovulation:
            return .ovulatory
        case .luteal:
            return .luteal
        }
    }
}
