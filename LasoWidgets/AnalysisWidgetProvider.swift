import Foundation
import WidgetKit

struct AnalysisWidgetProvider: TimelineProvider {
    private let store = WidgetDataStore.shared

    func placeholder(in context: Context) -> AnalysisWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (AnalysisWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AnalysisWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadEntry() -> AnalysisWidgetEntry {
        let placeholder = AnalysisWidgetEntry.placeholder
        return AnalysisWidgetEntry(
            date: Date(),
            readiness: store.loadReadiness() ?? placeholder.readiness,
            sleep: store.loadSleep() ?? placeholder.sleep,
            action: store.loadAction() ?? placeholder.action,
            intelligence: store.loadIntelligence() ?? placeholder.intelligence,
            recoveryDebt: store.loadRecoveryDebt() ?? placeholder.recoveryDebt,
            lastUpdate: store.lastUpdateDate() ?? Date()
        )
    }
}
