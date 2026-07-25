import Foundation
import SwiftData

// MARK: - Journal Category

/// User-trackable behavioral categories for the journal feature
enum JournalCategory: String, CaseIterable, Identifiable, Codable {
    var id: String { rawValue }

    case caffeine
    case alcohol
    case stress
    case supplements
    case meditation
    case screenTime
    case mealTiming
    case water
    case mood

    var displayName: String {
        switch self {
        case .caffeine: return "Caffeine"
        case .alcohol: return "Alcohol"
        case .stress: return "Stress"
        case .supplements: return "Supplements"
        case .meditation: return "Meditation"
        case .screenTime: return "Screen Time"
        case .mealTiming: return "Meal Timing"
        case .water: return "Water"
        case .mood: return "Mood"
        }
    }

    var unit: String {
        switch self {
        case .caffeine: return "cups"
        case .alcohol: return "drinks"
        case .stress: return "/ 10"
        case .supplements: return "doses"
        case .meditation: return "min"
        case .screenTime: return "hrs"
        case .mealTiming: return "hrs before bed"
        case .water: return "glasses"
        case .mood: return "/ 10"
        }
    }

    var icon: String {
        switch self {
        case .caffeine: return "cup.and.saucer.fill"
        case .alcohol: return "wineglass.fill"
        case .stress: return "brain.head.profile"
        case .supplements: return "pills.fill"
        case .meditation: return "figure.mind.and.body"
        case .screenTime: return "iphone"
        case .mealTiming: return "fork.knife"
        case .water: return "drop.fill"
        case .mood: return "face.smiling.inverse"
        }
    }

    var valueRange: ClosedRange<Double> {
        switch self {
        case .caffeine: return 0...10
        case .alcohol: return 0...10
        case .stress: return 0...10
        case .supplements: return 0...5
        case .meditation: return 0...120
        case .screenTime: return 0...16
        case .mealTiming: return 0...8
        case .water: return 0...20
        case .mood: return 0...10
        }
    }

    /// Default step increment for the value input
    var step: Double {
        switch self {
        case .caffeine, .alcohol, .supplements, .water: return 1
        case .stress, .mood: return 1
        case .meditation: return 5
        case .screenTime: return 0.5
        case .mealTiming: return 0.5
        }
    }

    /// Whether this category works better with a slider (continuous) vs stepper (discrete)
    var usesStepper: Bool {
        switch self {
        case .caffeine, .alcohol, .supplements, .water: return true
        case .stress, .mood: return false  // slider for subjective ratings
        case .meditation, .screenTime, .mealTiming: return false
        }
    }
}

// MARK: - SwiftData Model

/// Stores a single behavioral journal entry on device
@Model
final class StoredJournalEntry {
    var id: UUID
    var date: Date
    var categoryRawValue: String
    var value: Double
    var notes: String?

    init(id: UUID = UUID(), date: Date, categoryRawValue: String, value: Double, notes: String? = nil) {
        self.id = id
        self.date = date
        self.categoryRawValue = categoryRawValue
        self.value = value
        self.notes = notes
    }
}

// MARK: - Journal Store

/// Write helper for journal entries, following HealthDataStore patterns
struct JournalStore {

    private let modelContext: ModelContext?

    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
    }

    // MARK: - Save

    /// Save a new journal entry
    func save(category: JournalCategory, value: Double, date: Date = Date(), notes: String? = nil) {
        let entry = StoredJournalEntry(
            date: Date.cal.startOfDay(for: date),
            categoryRawValue: category.rawValue,
            value: value,
            notes: notes
        )
        modelContext?.insert(entry)
        try? modelContext?.save()
        let categoryRaw = category.rawValue
        let hasNotes = notes != nil && !(notes?.isEmpty ?? true)
        Task { @MainActor in
            AppAnalytics.shared.trackJournalEntryCreated(
                category: categoryRaw,
                value: value,
                hasNotes: hasNotes
            )
        }
    }
}
