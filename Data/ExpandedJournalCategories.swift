import Foundation
import SwiftUI

// MARK: - Behavior Input Type

/// Defines how a behavior value is captured in the UI
enum BehaviorInputType: Equatable {
    /// Simple toggle. logged or not (value: 0 or 1)
    case yesNo
    /// Numeric quantity with a unit, valid range, and step increment
    case quantity(unit: String, range: ClosedRange<Double>, step: Double)
    /// Subjective rating from 1 to maxValue
    case rating(maxValue: Int)
}

// MARK: - Journal Behavior Group

/// Top-level groupings for the expanded behavior catalog
enum JournalBehaviorGroup: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }

    case lifestyle
    case nutrition
    case recovery
    case exercise
    case mentalHealth
    case sleep
    case supplements

    var displayName: String {
        switch self {
        case .lifestyle:     return "Lifestyle"
        case .nutrition:     return "Nutrition"
        case .recovery:      return "Recovery"
        case .exercise:      return "Exercise"
        case .mentalHealth:  return "Mental Health"
        case .sleep:         return "Sleep"
        case .supplements:   return "Supplements"
        }
    }

    var icon: String {
        switch self {
        case .lifestyle:     return "house.fill"
        case .nutrition:     return "carrot.fill"
        case .recovery:      return "heart.circle.fill"
        case .exercise:      return "figure.run"
        case .mentalHealth:  return "brain.head.profile"
        case .sleep:         return "moon.fill"
        case .supplements:   return "pills.fill"
        }
    }

    var color: Color {
        switch self {
        case .lifestyle:     return .blue
        case .nutrition:     return .green
        case .recovery:      return .purple
        case .exercise:      return .orange
        case .mentalHealth:  return .teal
        case .sleep:         return .indigo
        case .supplements:   return .pink
        }
    }
}

// MARK: - Journal Behavior

/// Expanded behavior catalog. 55 trackable behaviors organized by group.
/// Coexists with the legacy `JournalCategory` enum in JournalStore.swift.
enum JournalBehavior: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }

    // MARK: Lifestyle (12)
    case caffeine
    case alcohol
    case smoking
    case marijuana
    case socialTime
    case workHours
    case commute
    case screenTime
    case reading
    case outdoorTime
    case coldShower
    case hotBath

    // MARK: Nutrition (11)
    case mealTiming
    case fastingHours
    case water
    case proteinRich
    case vegetableServings
    case processedFood
    case sugar
    case dairyFree
    case glutenFree
    case mealPrepped
    case lateNightEating

    // MARK: Recovery (12)
    case meditation
    case breathwork
    case stretching
    case yoga
    case massage
    case sauna
    case iceBath
    case foamRolling
    case nap
    case activeRecovery
    case compression
    case epsomBath

    // MARK: Exercise (7)
    case morningWorkout
    case eveningWorkout
    case cardio
    case strengthTraining
    case hiit
    case walkingOnly
    case restDay

    // MARK: Mental Health (7)
    case stress
    case mood
    case anxiety
    case gratitude
    case journaling
    case therapy
    case socialMedia

    // MARK: Sleep (8)
    case blueLightBlocking
    case magnesiumBeforeBed
    case sleepMask
    case whiteNoise
    case consistentBedtime
    case noPhoneInBed
    case coolRoom
    case heavyMealBeforeBed

    // MARK: Supplements (12)
    case vitaminD
    case omega3
    case magnesium
    case creatine
    case probiotics
    case melatonin
    case zinc
    case ironSupplement
    case multivitamin
    case ashwagandha
    case turmeric
    case collagen

    // MARK: - Display Name

    var displayName: String {
        switch self {
        // Lifestyle
        case .caffeine:            return "Caffeine"
        case .alcohol:             return "Alcohol"
        case .smoking:             return "Smoking"
        case .marijuana:           return "Marijuana"
        case .socialTime:          return "Social Time"
        case .workHours:           return "Work Hours"
        case .commute:             return "Commute"
        case .screenTime:          return "Screen Time"
        case .reading:             return "Reading"
        case .outdoorTime:         return "Outdoor Time"
        case .coldShower:          return "Cold Shower"
        case .hotBath:             return "Hot Bath"
        // Nutrition
        case .mealTiming:          return "Meal Timing"
        case .fastingHours:        return "Fasting Hours"
        case .water:               return "Water"
        case .proteinRich:         return "Protein-Rich Meals"
        case .vegetableServings:   return "Vegetable Servings"
        case .processedFood:       return "Processed Food"
        case .sugar:               return "Added Sugar"
        case .dairyFree:           return "Dairy-Free Day"
        case .glutenFree:          return "Gluten-Free Day"
        case .mealPrepped:         return "Meal Prepped"
        case .lateNightEating:     return "Late-Night Eating"
        // Recovery
        case .meditation:          return "Meditation"
        case .breathwork:          return "Breathwork"
        case .stretching:          return "Stretching"
        case .yoga:                return "Yoga"
        case .massage:             return "Massage"
        case .sauna:               return "Sauna"
        case .iceBath:             return "Ice Bath"
        case .foamRolling:         return "Foam Rolling"
        case .nap:                 return "Nap"
        case .activeRecovery:      return "Active Recovery"
        case .compression:         return "Compression"
        case .epsomBath:           return "Epsom Salt Bath"
        // Exercise
        case .morningWorkout:      return "Morning Workout"
        case .eveningWorkout:      return "Evening Workout"
        case .cardio:              return "Cardio"
        case .strengthTraining:    return "Strength Training"
        case .hiit:                return "HIIT"
        case .walkingOnly:         return "Walking Only"
        case .restDay:             return "Rest Day"
        // Mental Health
        case .stress:              return "Stress"
        case .mood:                return "Mood"
        case .anxiety:             return "Anxiety"
        case .gratitude:           return "Gratitude"
        case .journaling:          return "Journaling"
        case .therapy:             return "Therapy"
        case .socialMedia:         return "Social Media"
        // Sleep
        case .blueLightBlocking:   return "Blue Light Blocking"
        case .magnesiumBeforeBed:  return "Magnesium Before Bed"
        case .sleepMask:           return "Sleep Mask"
        case .whiteNoise:          return "White Noise"
        case .consistentBedtime:   return "Consistent Bedtime"
        case .noPhoneInBed:        return "No Phone in Bed"
        case .coolRoom:            return "Cool Room"
        case .heavyMealBeforeBed:  return "Heavy Meal Before Bed"
        // Supplements
        case .vitaminD:            return "Vitamin D"
        case .omega3:              return "Omega-3"
        case .magnesium:           return "Magnesium"
        case .creatine:            return "Creatine"
        case .probiotics:          return "Probiotics"
        case .melatonin:           return "Melatonin"
        case .zinc:                return "Zinc"
        case .ironSupplement:      return "Iron"
        case .multivitamin:        return "Multivitamin"
        case .ashwagandha:         return "Ashwagandha"
        case .turmeric:            return "Turmeric"
        case .collagen:            return "Collagen"
        }
    }

    // MARK: - Icon (SF Symbol)

    var icon: String {
        switch self {
        // Lifestyle
        case .caffeine:            return "cup.and.saucer.fill"
        case .alcohol:             return "wineglass.fill"
        case .smoking:             return "smoke.fill"
        case .marijuana:           return "leaf.fill"
        case .socialTime:          return "person.2.fill"
        case .workHours:           return "briefcase.fill"
        case .commute:             return "car.fill"
        case .screenTime:          return "iphone"
        case .reading:             return "book.fill"
        case .outdoorTime:         return "sun.max.fill"
        case .coldShower:          return "snowflake"
        case .hotBath:             return "bathtub.fill"
        // Nutrition
        case .mealTiming:          return "fork.knife"
        case .fastingHours:        return "clock.fill"
        case .water:               return "drop.fill"
        case .proteinRich:         return "fish.fill"
        case .vegetableServings:   return "carrot.fill"
        case .processedFood:       return "takeoutbag.and.cup.and.straw.fill"
        case .sugar:               return "cube.fill"
        case .dairyFree:           return "checkmark.circle.fill"
        case .glutenFree:          return "checkmark.circle.fill"
        case .mealPrepped:         return "refrigerator.fill"
        case .lateNightEating:     return "moon.haze.fill"
        // Recovery
        case .meditation:          return "figure.mind.and.body"
        case .breathwork:          return "wind"
        case .stretching:          return "figure.flexibility"
        case .yoga:                return "figure.yoga"
        case .massage:             return "hand.raised.fill"
        case .sauna:               return "thermometer.sun.fill"
        case .iceBath:             return "snowflake.circle.fill"
        case .foamRolling:         return "figure.roll"
        case .nap:                 return "powersleep"
        case .activeRecovery:      return "figure.walk"
        case .compression:         return "bandage.fill"
        case .epsomBath:           return "bathtub.fill"
        // Exercise
        case .morningWorkout:      return "sunrise.fill"
        case .eveningWorkout:      return "sunset.fill"
        case .cardio:              return "figure.run"
        case .strengthTraining:    return "dumbbell.fill"
        case .hiit:                return "bolt.fill"
        case .walkingOnly:         return "figure.walk"
        case .restDay:             return "bed.double.fill"
        // Mental Health
        case .stress:              return "brain.head.profile"
        case .mood:                return "face.smiling.inverse"
        case .anxiety:             return "waveform.path.ecg"
        case .gratitude:           return "heart.fill"
        case .journaling:          return "pencil.and.list.clipboard"
        case .therapy:             return "bubble.left.and.bubble.right.fill"
        case .socialMedia:         return "rectangle.stack.fill"
        // Sleep
        case .blueLightBlocking:   return "eyeglasses"
        case .magnesiumBeforeBed:  return "pills.fill"
        case .sleepMask:           return "eye.slash.fill"
        case .whiteNoise:          return "speaker.wave.2.fill"
        case .consistentBedtime:   return "clock.badge.checkmark.fill"
        case .noPhoneInBed:        return "iphone.slash"
        case .coolRoom:            return "thermometer.snowflake"
        case .heavyMealBeforeBed:  return "fork.knife.circle.fill"
        // Supplements
        case .vitaminD:            return "sun.min.fill"
        case .omega3:              return "drop.halffull"
        case .magnesium:           return "pill.fill"
        case .creatine:            return "flask.fill"
        case .probiotics:          return "microbe.fill"
        case .melatonin:           return "moon.stars.fill"
        case .zinc:                return "pill.fill"
        case .ironSupplement:      return "pill.fill"
        case .multivitamin:        return "pills.fill"
        case .ashwagandha:         return "leaf.circle.fill"
        case .turmeric:            return "leaf.circle.fill"
        case .collagen:            return "drop.circle.fill"
        }
    }

    // MARK: - Group

    var group: JournalBehaviorGroup {
        switch self {
        // Lifestyle
        case .caffeine, .alcohol, .smoking, .marijuana,
             .socialTime, .workHours, .commute, .screenTime,
             .reading, .outdoorTime, .coldShower, .hotBath:
            return .lifestyle
        // Nutrition
        case .mealTiming, .fastingHours, .water, .proteinRich,
             .vegetableServings, .processedFood, .sugar,
             .dairyFree, .glutenFree, .mealPrepped, .lateNightEating:
            return .nutrition
        // Recovery
        case .meditation, .breathwork, .stretching, .yoga,
             .massage, .sauna, .iceBath, .foamRolling,
             .nap, .activeRecovery, .compression, .epsomBath:
            return .recovery
        // Exercise
        case .morningWorkout, .eveningWorkout, .cardio,
             .strengthTraining, .hiit, .walkingOnly, .restDay:
            return .exercise
        // Mental Health
        case .stress, .mood, .anxiety, .gratitude,
             .journaling, .therapy, .socialMedia:
            return .mentalHealth
        // Sleep
        case .blueLightBlocking, .magnesiumBeforeBed, .sleepMask,
             .whiteNoise, .consistentBedtime, .noPhoneInBed,
             .coolRoom, .heavyMealBeforeBed:
            return .sleep
        // Supplements
        case .vitaminD, .omega3, .magnesium, .creatine,
             .probiotics, .melatonin, .zinc, .ironSupplement,
             .multivitamin, .ashwagandha, .turmeric, .collagen:
            return .supplements
        }
    }

    // MARK: - Input Type

    var inputType: BehaviorInputType {
        switch self {
        // Lifestyle
        case .caffeine:            return .quantity(unit: "cups", range: 0...10, step: 1)
        case .alcohol:             return .quantity(unit: "drinks", range: 0...10, step: 1)
        case .smoking:             return .quantity(unit: "cigarettes", range: 0...40, step: 1)
        case .marijuana:           return .yesNo
        case .socialTime:          return .quantity(unit: "hrs", range: 0...12, step: 0.5)
        case .workHours:           return .quantity(unit: "hrs", range: 0...16, step: 0.5)
        case .commute:             return .quantity(unit: "min", range: 0...180, step: 5)
        case .screenTime:          return .quantity(unit: "hrs", range: 0...16, step: 0.5)
        case .reading:             return .quantity(unit: "min", range: 0...180, step: 5)
        case .outdoorTime:         return .quantity(unit: "hrs", range: 0...12, step: 0.5)
        case .coldShower:          return .yesNo
        case .hotBath:             return .yesNo
        // Nutrition
        case .mealTiming:          return .quantity(unit: "hrs before bed", range: 0...8, step: 0.5)
        case .fastingHours:        return .quantity(unit: "hrs", range: 0...24, step: 1)
        case .water:               return .quantity(unit: "glasses", range: 0...20, step: 1)
        case .proteinRich:         return .quantity(unit: "meals", range: 0...6, step: 1)
        case .vegetableServings:   return .quantity(unit: "servings", range: 0...10, step: 1)
        case .processedFood:       return .quantity(unit: "servings", range: 0...10, step: 1)
        case .sugar:               return .quantity(unit: "servings", range: 0...10, step: 1)
        case .dairyFree:           return .yesNo
        case .glutenFree:          return .yesNo
        case .mealPrepped:         return .yesNo
        case .lateNightEating:     return .yesNo
        // Recovery
        case .meditation:          return .quantity(unit: "min", range: 0...120, step: 5)
        case .breathwork:          return .quantity(unit: "min", range: 0...60, step: 5)
        case .stretching:          return .quantity(unit: "min", range: 0...60, step: 5)
        case .yoga:                return .quantity(unit: "min", range: 0...120, step: 5)
        case .massage:             return .quantity(unit: "min", range: 0...120, step: 5)
        case .sauna:               return .quantity(unit: "min", range: 0...60, step: 5)
        case .iceBath:             return .quantity(unit: "min", range: 0...20, step: 1)
        case .foamRolling:         return .quantity(unit: "min", range: 0...60, step: 5)
        case .nap:                 return .quantity(unit: "min", range: 0...120, step: 5)
        case .activeRecovery:      return .quantity(unit: "min", range: 0...120, step: 5)
        case .compression:         return .yesNo
        case .epsomBath:           return .yesNo
        // Exercise
        case .morningWorkout:      return .yesNo
        case .eveningWorkout:      return .yesNo
        case .cardio:              return .quantity(unit: "min", range: 0...180, step: 5)
        case .strengthTraining:    return .quantity(unit: "min", range: 0...180, step: 5)
        case .hiit:                return .quantity(unit: "min", range: 0...60, step: 5)
        case .walkingOnly:         return .yesNo
        case .restDay:             return .yesNo
        // Mental Health
        case .stress:              return .rating(maxValue: 10)
        case .mood:                return .rating(maxValue: 10)
        case .anxiety:             return .rating(maxValue: 10)
        case .gratitude:           return .yesNo
        case .journaling:          return .yesNo
        case .therapy:             return .yesNo
        case .socialMedia:         return .quantity(unit: "hrs", range: 0...12, step: 0.5)
        // Sleep
        case .blueLightBlocking:   return .yesNo
        case .magnesiumBeforeBed:  return .yesNo
        case .sleepMask:           return .yesNo
        case .whiteNoise:          return .yesNo
        case .consistentBedtime:   return .yesNo
        case .noPhoneInBed:        return .yesNo
        case .coolRoom:            return .yesNo
        case .heavyMealBeforeBed:  return .yesNo
        // Supplements. all yes/no (took it or didn't)
        case .vitaminD:            return .yesNo
        case .omega3:              return .yesNo
        case .magnesium:           return .yesNo
        case .creatine:            return .yesNo
        case .probiotics:          return .yesNo
        case .melatonin:           return .yesNo
        case .zinc:                return .yesNo
        case .ironSupplement:      return .yesNo
        case .multivitamin:        return .yesNo
        case .ashwagandha:         return .yesNo
        case .turmeric:            return .yesNo
        case .collagen:            return .yesNo
        }
    }

    // MARK: - Default Value

    var defaultValue: Double {
        switch inputType {
        case .yesNo:
            return 0
        case .quantity(_, let range, _):
            return range.lowerBound
        case .rating(let maxValue):
            return Double(maxValue) / 2.0
        }
    }

    // MARK: - Legacy Mapping

    /// Maps to the corresponding `JournalCategory` case for backward compatibility.
    /// Returns nil for behaviors that have no legacy equivalent.
    var legacyCategory: JournalCategory? {
        switch self {
        case .caffeine:    return .caffeine
        case .alcohol:     return .alcohol
        case .stress:      return .stress
        case .meditation:  return .meditation
        case .screenTime:  return .screenTime
        case .mealTiming:  return .mealTiming
        case .water:       return .water
        case .mood:        return .mood
        default:           return nil
        }
    }

    // MARK: - Helpers

    /// All behaviors belonging to a given group
    static func behaviors(in group: JournalBehaviorGroup) -> [JournalBehavior] {
        allCases.filter { $0.group == group }
    }

    /// Create a `JournalBehavior` from a legacy `JournalCategory`, if one exists
    static func from(legacy category: JournalCategory) -> JournalBehavior? {
        switch category {
        case .caffeine:    return .caffeine
        case .alcohol:     return .alcohol
        case .stress:      return .stress
        case .supplements: return nil // legacy "supplements" is generic; no single expanded equivalent
        case .meditation:  return .meditation
        case .screenTime:  return .screenTime
        case .mealTiming:  return .mealTiming
        case .water:       return .water
        case .mood:        return .mood
        }
    }
}
