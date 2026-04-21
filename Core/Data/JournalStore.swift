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

    var category: JournalCategory? {
        JournalCategory(rawValue: categoryRawValue)
    }
}

// MARK: - Journal Store

/// Query helpers for journal entries, following HealthDataStore patterns
struct JournalStore {

    private let modelContext: ModelContext?

    init(modelContext: ModelContext?) {
        self.modelContext = modelContext
    }

    // MARK: - Save

    /// Save a new journal entry
    func save(category: JournalCategory, value: Double, date: Date = Date(), notes: String? = nil) {
        let entry = StoredJournalEntry(
            date: Calendar.current.startOfDay(for: date),
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

    // MARK: - Query: Entries for Date

    /// Load all journal entries for a specific day
    func entries(for date: Date) -> [StoredJournalEntry] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = #Predicate<StoredJournalEntry> { $0.date >= start && $0.date < end }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    // MARK: - Query: Entries for Category in Date Range

    /// Load entries for a specific category within a date range
    func entries(for category: JournalCategory, from startDate: Date, to endDate: Date) -> [StoredJournalEntry] {
        let rawValue = category.rawValue
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)

        let predicate = #Predicate<StoredJournalEntry> {
            $0.categoryRawValue == rawValue && $0.date >= start && $0.date <= end
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    // MARK: - Query: All Entries in Date Range

    /// Load all journal entries within a date range
    func allEntries(from startDate: Date, to endDate: Date) -> [StoredJournalEntry] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)

        let predicate = #Predicate<StoredJournalEntry> { $0.date >= start && $0.date <= end }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    // MARK: - Query: Daily Summary

    /// Summary of all categories logged on a given date
    func dailySummary(for date: Date) -> [JournalCategory: Double] {
        let dayEntries = entries(for: date)
        var summary: [JournalCategory: Double] = [:]
        for entry in dayEntries {
            guard let cat = entry.category else { continue }
            summary[cat, default: 0] += entry.value
        }
        return summary
    }

    // MARK: - Query: Date-indexed values for a category

    /// Build a date-to-value lookup for a category (used by correlation analysis)
    func dateIndexedValues(for category: JournalCategory, days: Int) -> [Date: Double] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -days, to: end) else { return [:] }

        let entries = entries(for: category, from: start, to: end)
        var lookup: [Date: Double] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            lookup[day, default: 0] += entry.value
        }
        return lookup
    }

    // MARK: - Stats

    /// Total number of journal entries stored
    var totalEntries: Int {
        (try? modelContext?.fetchCount(FetchDescriptor<StoredJournalEntry>())) ?? 0
    }

    /// Number of unique days with at least one journal entry
    func daysLogged(since startDate: Date) -> Int {
        let predicate = #Predicate<StoredJournalEntry> { $0.date >= startDate }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let entries = try? modelContext?.fetch(descriptor) else { return 0 }

        let calendar = Calendar.current
        let uniqueDays = Set(entries.map { calendar.startOfDay(for: $0.date) })
        return uniqueDays.count
    }

    // MARK: - Delete

    /// Delete a specific journal entry
    func delete(_ entry: StoredJournalEntry) {
        let category = entry.category?.rawValue ?? "unknown"
        modelContext?.delete(entry)
        try? modelContext?.save()
        Task { @MainActor in
            AppAnalytics.shared.trackJournalEntryDeleted(category: category)
        }
    }
}
