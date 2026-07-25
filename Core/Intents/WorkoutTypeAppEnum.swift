import AppIntents
import HealthKit

/// App-level enum for workout types exposed to Siri and Shortcuts
enum WorkoutTypeAppEnum: String, AppEnum {
    case running
    case walking
    case cycling
    case swimming
    case yoga
    case hiit
    case strengthTraining
    case hiking
    case rowing
    case elliptical
    case dance
    case cooldown

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Workout Type"
    }

    static var caseDisplayRepresentations: [WorkoutTypeAppEnum: DisplayRepresentation] {
        [
            .running: "Running",
            .walking: "Walking",
            .cycling: "Cycling",
            .swimming: "Swimming",
            .yoga: "Yoga",
            .hiit: "HIIT",
            .strengthTraining: "Strength Training",
            .hiking: "Hiking",
            .rowing: "Rowing",
            .elliptical: "Elliptical",
            .dance: "Dance",
            .cooldown: "Cooldown"
        ]
    }

    var hkActivityType: HKWorkoutActivityType {
        switch self {
        case .running: return .running
        case .walking: return .walking
        case .cycling: return .cycling
        case .swimming: return .swimming
        case .yoga: return .yoga
        case .hiit: return .highIntensityIntervalTraining
        case .strengthTraining: return .traditionalStrengthTraining
        case .hiking: return .hiking
        case .rowing: return .rowing
        case .elliptical: return .elliptical
        case .dance: return .cardioDance
        case .cooldown: return .cooldown
        }
    }

    var systemImageName: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.mind.and.body"
        case .hiit: return "bolt.heart.fill"
        case .strengthTraining: return "figure.strengthtraining.traditional"
        case .hiking: return "figure.hiking"
        case .rowing: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .dance: return "figure.dance"
        case .cooldown: return "figure.cooldown"
        }
    }
}

/// App-level enum for metric categories exposed to Siri and Shortcuts
enum HealthCategoryAppEnum: String, AppEnum {
    case heart
    case sleep
    case activity
    case body
    case respiratory
    case mindfulness
    case mobility

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Health Category"
    }

    static var caseDisplayRepresentations: [HealthCategoryAppEnum: DisplayRepresentation] {
        [
            .heart: "Heart & Cardio",
            .sleep: "Sleep",
            .activity: "Activity",
            .body: "Body & Vitals",
            .respiratory: "Respiratory",
            .mindfulness: "Mindfulness",
            .mobility: "Mobility"
        ]
    }
}
