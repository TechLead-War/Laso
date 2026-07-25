import Foundation
import WidgetKit

struct AnalysisWidgetProvider: TimelineProvider {
    private let store = WidgetDataStore.shared

    func placeholder(in context: Context) -> AnalysisWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (AnalysisWidgetEntry) -> Void) {
        // The gallery is the one place sample numbers belong. Everywhere else the
        // user must see their own data or nothing.
        completion(context.isPreview ? .placeholder : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AnalysisWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadEntry() -> AnalysisWidgetEntry {
        AnalysisWidgetEntry(
            date: Date(),
            readiness: fromToday(store.loadReadiness()) { $0.updatedAt },
            sleep: fromToday(store.loadSleep()) { $0.updatedAt },
            action: fromToday(store.loadAction()) { $0.updatedAt },
            intelligence: fromToday(store.loadIntelligence()) { $0.updatedAt },
            recoveryDebt: fromToday(store.loadRecoveryDebt()) { $0.updatedAt },
            lastUpdate: fromToday(store.lastUpdateDate()) { $0 }
        )
    }

    /// Drops anything the app did not write today.
    ///
    /// The watch complication ages its payload out after an hour because the phone
    /// pushes to the wrist on a fixed cycle. The widget store is only rewritten
    /// when a value actually changes, so a real morning score can sit untouched all
    /// day; the honest cut-off here is the calendar day it describes.
    private func fromToday<T>(_ snapshot: T?, updatedAt: (T) -> Date) -> T? {
        guard let snapshot, Calendar.current.isDateInToday(updatedAt(snapshot)) else { return nil }
        return snapshot
    }
}
