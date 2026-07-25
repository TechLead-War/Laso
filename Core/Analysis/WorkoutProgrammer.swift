import Foundation

// MARK: - Workout Plan Types

struct WorkoutPlan {
    let title: String
    let summary: String
    let targetDuration: Int // minutes
    let estimatedCalories: Int
    let warmup: WorkoutBlock
    let mainBlocks: [WorkoutBlock]
    let cooldown: WorkoutBlock
    let zone: TrainingZone
    let cyclePhaseNote: String?
}

struct WorkoutBlock: Identifiable {
    let id = UUID()
    let name: String
    let duration: Int // minutes
    let exercises: [Exercise]
    let heartRateTarget: HeartRateTarget?
}

struct Exercise: Identifiable {
    let id = UUID()
    let name: String
    let instruction: String
    let icon: String
}

struct HeartRateTarget {
    let minBPM: Int
    let maxBPM: Int
    let label: String

    static func forZone(_ zone: Int, maxHR: Int) -> HeartRateTarget {
        let zones = WorkoutBandsConfig.hrZones
        let idx = max(0, min(zone - 1, zones.count - 1))
        let range = zones[idx]
        return HeartRateTarget(
            minBPM: Int(Double(maxHR) * range.lowerFraction),
            maxBPM: Int(Double(maxHR) * range.upperFraction),
            label: range.label
        )
    }
}

enum TrainingZone: String {
    case restoring = "Restoring"
    case maintaining = "Maintaining"
    case building = "Building"
    case overreaching = "Overreaching"

    var icon: String {
        switch self {
        case .restoring: return "leaf.fill"
        case .maintaining: return "figure.walk"
        case .building: return "figure.run"
        case .overreaching: return "bolt.fill"
        }
    }
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
        strainTarget: Double? = nil,
        healthSignals: HealthSignalFlags = .none,
        cyclePhase: CyclePhaseModifier? = nil,
        estimatedMaxHR: Int = WorkoutBandsConfig.defaultEstimatedMaxHR,
        lastWorkoutType: String? = nil,
        exerciseMinutesToday: Double = 0
    ) -> WorkoutPlan {
        generatePlan(
            recoveryScore: recoveryBand.recoveryScoreSeed,
            strainTarget: strainTarget,
            healthSignals: healthSignals,
            cyclePhase: cyclePhase,
            estimatedMaxHR: estimatedMaxHR,
            lastWorkoutType: lastWorkoutType,
            exerciseMinutesToday: exerciseMinutesToday
        )
    }

    /// Generate a workout plan based on the user's current recovery and health state.
    static func generatePlan(
        recoveryScore: Int,
        strainTarget: Double? = nil,
        healthSignals: HealthSignalFlags = .none,
        cyclePhase: CyclePhaseModifier? = nil,
        estimatedMaxHR: Int = WorkoutBandsConfig.defaultEstimatedMaxHR,
        lastWorkoutType: String? = nil,
        exerciseMinutesToday: Double = 0
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
        var cycleNote: String? = nil
        if let phase = cyclePhase {
            switch phase {
            case .menstrual:
                if zone.rawValue != TrainingZone.restoring.rawValue {
                    zone = min(zone, .maintaining)
                }
                cycleNote = "During your menstrual phase, we have adjusted intensity to favor low-impact movements. Listen to your body. Rest is productive."
            case .luteal:
                cycleNote = "Luteal phase detected. Volume reduced ~15%. Steady-state cardio preferred over high-intensity intervals."
            case .follicular, .ovulatory:
                break
            }
        }

        // Generate zone-specific plan
        switch zone {
        case .restoring:
            return buildRestoringPlan(maxHR: estimatedMaxHR, cycleNote: cycleNote)
        case .maintaining:
            return buildMaintainingPlan(maxHR: estimatedMaxHR, cycleNote: cycleNote)
        case .building:
            return buildBuildingPlan(maxHR: estimatedMaxHR, cycleNote: cycleNote)
        case .overreaching:
            return buildOverreachingPlan(maxHR: estimatedMaxHR, cycleNote: cycleNote)
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

    // MARK: - Plan Generators

    private static func buildRestoringPlan(maxHR: Int, cycleNote: String?) -> WorkoutPlan {
        let warmup = WorkoutBlock(
            name: "Gentle Warm-Up",
            duration: 5,
            exercises: [
                Exercise(name: "Light Walking", instruction: "Easy pace, focus on deep breathing", icon: "figure.walk"),
                Exercise(name: "Arm Circles", instruction: "10 forward, 10 backward. Slow and controlled", icon: "figure.arms.open"),
            ],
            heartRateTarget: HeartRateTarget.forZone(1, maxHR: maxHR)
        )

        let mainBlocks = [
            WorkoutBlock(
                name: "Gentle Movement",
                duration: 15,
                exercises: [
                    Exercise(name: "Easy Walk", instruction: "Comfortable pace on flat terrain", icon: "figure.walk"),
                    Exercise(name: "Gentle Yoga Flow", instruction: "Cat-cow, child's pose, downward dog. 30s each", icon: "figure.yoga"),
                ],
                heartRateTarget: HeartRateTarget.forZone(1, maxHR: maxHR)
            ),
            WorkoutBlock(
                name: "Mobility & Recovery",
                duration: 10,
                exercises: [
                    Exercise(name: "Foam Rolling", instruction: "Quads, hamstrings, calves. 60s each area", icon: "figure.roll"),
                    Exercise(name: "Hip Openers", instruction: "Pigeon pose, hip circles. 30s each side", icon: "figure.flexibility"),
                ],
                heartRateTarget: nil
            ),
        ]

        let cooldown = WorkoutBlock(
            name: "Cool Down",
            duration: 5,
            exercises: [
                Exercise(name: "Static Stretches", instruction: "Hold each stretch 30 seconds. Hamstrings, quads, shoulders", icon: "figure.cooldown"),
                Exercise(name: "Deep Breathing", instruction: "4-count inhale, 6-count exhale. 5 rounds", icon: "lungs.fill"),
            ],
            heartRateTarget: nil
        )

        return WorkoutPlan(
            title: "Restore & Recover",
            summary: "Your body needs rest. This gentle session focuses on mobility, light movement, and recovery.",
            targetDuration: 30,
            estimatedCalories: 80,
            warmup: warmup,
            mainBlocks: mainBlocks,
            cooldown: cooldown,
            zone: .restoring,
            cyclePhaseNote: cycleNote
        )
    }

    private static func buildMaintainingPlan(maxHR: Int, cycleNote: String?) -> WorkoutPlan {
        let warmup = WorkoutBlock(
            name: "Dynamic Warm-Up",
            duration: 5,
            exercises: [
                Exercise(name: "Brisk Walk", instruction: "Gradually increase pace over 3 minutes", icon: "figure.walk"),
                Exercise(name: "Leg Swings", instruction: "10 each leg, forward and lateral", icon: "figure.walk"),
            ],
            heartRateTarget: HeartRateTarget.forZone(2, maxHR: maxHR)
        )

        let mainBlocks = [
            WorkoutBlock(
                name: "Moderate Cardio",
                duration: 20,
                exercises: [
                    Exercise(name: "Moderate Run / Jog", instruction: "Conversational pace. You should be able to talk", icon: "figure.run"),
                ],
                heartRateTarget: HeartRateTarget.forZone(2, maxHR: maxHR)
            ),
            WorkoutBlock(
                name: "Bodyweight Circuit",
                duration: 15,
                exercises: [
                    Exercise(name: "Squats", instruction: "3 sets of 12, controlled tempo", icon: "figure.strengthtraining.traditional"),
                    Exercise(name: "Push-Ups", instruction: "3 sets of 10, modify as needed", icon: "figure.strengthtraining.traditional"),
                    Exercise(name: "Plank", instruction: "3 × 30 seconds, maintain neutral spine", icon: "figure.core.training"),
                ],
                heartRateTarget: HeartRateTarget.forZone(3, maxHR: maxHR)
            ),
        ]

        let cooldown = WorkoutBlock(
            name: "Cool Down",
            duration: 5,
            exercises: [
                Exercise(name: "Light Walk", instruction: "2 minutes easy pace to bring heart rate down", icon: "figure.walk"),
                Exercise(name: "Stretching", instruction: "Focus on worked muscle groups. 30s each", icon: "figure.cooldown"),
            ],
            heartRateTarget: nil
        )

        return WorkoutPlan(
            title: "Maintain & Move",
            summary: "Moderate effort to maintain your fitness base. Mix of cardio and bodyweight work.",
            targetDuration: 40,
            estimatedCalories: 250,
            warmup: warmup,
            mainBlocks: mainBlocks,
            cooldown: cooldown,
            zone: .maintaining,
            cyclePhaseNote: cycleNote
        )
    }

    private static func buildBuildingPlan(maxHR: Int, cycleNote: String?) -> WorkoutPlan {
        let warmup = WorkoutBlock(
            name: "Active Warm-Up",
            duration: 8,
            exercises: [
                Exercise(name: "Jog", instruction: "Easy jog building to moderate pace", icon: "figure.run"),
                Exercise(name: "Dynamic Stretches", instruction: "High knees, butt kicks, walking lunges. 30s each", icon: "figure.walk"),
            ],
            heartRateTarget: HeartRateTarget.forZone(2, maxHR: maxHR)
        )

        let mainBlocks = [
            WorkoutBlock(
                name: "Interval Training",
                duration: 20,
                exercises: [
                    Exercise(name: "HIIT Intervals", instruction: "30s hard effort / 90s recovery × 8 rounds", icon: "figure.run"),
                ],
                heartRateTarget: HeartRateTarget.forZone(4, maxHR: maxHR)
            ),
            WorkoutBlock(
                name: "Strength Work",
                duration: 20,
                exercises: [
                    Exercise(name: "Goblet Squats", instruction: "4 × 10, moderate weight, full depth", icon: "figure.strengthtraining.traditional"),
                    Exercise(name: "Dumbbell Rows", instruction: "3 × 12 each arm, squeeze at top", icon: "figure.strengthtraining.traditional"),
                    Exercise(name: "Overhead Press", instruction: "3 × 10, controlled negative", icon: "figure.strengthtraining.traditional"),
                    Exercise(name: "Dead Bugs", instruction: "3 × 10 each side, keep lower back flat", icon: "figure.core.training"),
                ],
                heartRateTarget: HeartRateTarget.forZone(3, maxHR: maxHR)
            ),
        ]

        let cooldown = WorkoutBlock(
            name: "Cool Down",
            duration: 7,
            exercises: [
                Exercise(name: "Easy Jog / Walk", instruction: "3 minutes gradual pace reduction", icon: "figure.walk"),
                Exercise(name: "Full-Body Stretch", instruction: "Hold each stretch 30-45s. Hips, shoulders, hamstrings", icon: "figure.cooldown"),
            ],
            heartRateTarget: nil
        )

        return WorkoutPlan(
            title: "Build & Push",
            summary: "Your recovery supports a challenging session. HIIT intervals plus strength work to drive adaptation.",
            targetDuration: 55,
            estimatedCalories: 450,
            warmup: warmup,
            mainBlocks: mainBlocks,
            cooldown: cooldown,
            zone: .building,
            cyclePhaseNote: cycleNote
        )
    }

    private static func buildOverreachingPlan(maxHR: Int, cycleNote: String?) -> WorkoutPlan {
        let warmup = WorkoutBlock(
            name: "Progressive Warm-Up",
            duration: 10,
            exercises: [
                Exercise(name: "Progressive Run", instruction: "Start easy, build to 70% effort over 5 minutes", icon: "figure.run"),
                Exercise(name: "Activation Drills", instruction: "A-skips, B-skips, bounding. 30m each × 2", icon: "figure.run"),
            ],
            heartRateTarget: HeartRateTarget.forZone(3, maxHR: maxHR)
        )

        let mainBlocks = [
            WorkoutBlock(
                name: "Sprint Intervals",
                duration: 15,
                exercises: [
                    Exercise(name: "Sprint Repeats", instruction: "20s all-out sprint / 40s walk × 10 rounds", icon: "figure.run"),
                ],
                heartRateTarget: HeartRateTarget.forZone(5, maxHR: maxHR)
            ),
            WorkoutBlock(
                name: "Heavy Compound Lifts",
                duration: 25,
                exercises: [
                    Exercise(name: "Barbell Squats", instruction: "5 × 5 at 80% 1RM, 2-3 min rest between sets", icon: "figure.strengthtraining.traditional"),
                    Exercise(name: "Bench Press", instruction: "5 × 5 at 80% 1RM", icon: "figure.strengthtraining.traditional"),
                    Exercise(name: "Barbell Rows", instruction: "4 × 8, controlled eccentric", icon: "figure.strengthtraining.traditional"),
                    Exercise(name: "Bulgarian Split Squats", instruction: "3 × 10 each leg, bodyweight or loaded", icon: "figure.strengthtraining.traditional"),
                ],
                heartRateTarget: HeartRateTarget.forZone(4, maxHR: maxHR)
            ),
        ]

        let cooldown = WorkoutBlock(
            name: "Active Recovery",
            duration: 10,
            exercises: [
                Exercise(name: "Easy Walk", instruction: "5 minutes very easy pace", icon: "figure.walk"),
                Exercise(name: "Extended Stretching", instruction: "Focus on major muscle groups. 45-60s each hold", icon: "figure.cooldown"),
            ],
            heartRateTarget: nil
        )

        return WorkoutPlan(
            title: "Peak Performance",
            summary: "You are fully recovered and primed. Max-effort sprints and heavy compounds to push your limits.",
            targetDuration: 60,
            estimatedCalories: 600,
            warmup: warmup,
            mainBlocks: mainBlocks,
            cooldown: cooldown,
            zone: .overreaching,
            cyclePhaseNote: cycleNote
        )
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

extension CyclePhaseModifier {
    var displayName: String {
        switch self {
        case .menstrual:
            return "Menstrual"
        case .follicular:
            return "Follicular"
        case .ovulatory:
            return "Ovulatory"
        case .luteal:
            return "Luteal"
        }
    }
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
