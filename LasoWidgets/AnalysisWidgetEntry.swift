import Foundation
import WidgetKit

/// One rendered state of the analysis widget.
///
/// Every snapshot is optional because the widget can be on the home screen before
/// the first sync, or right after the user deletes their data. Nothing here is
/// ever filled in with sample values: an empty field means the app has written
/// nothing real, and the view says so instead of showing a number.
struct AnalysisWidgetEntry: TimelineEntry {
    let date: Date
    let readiness: WidgetReadinessSnapshot?
    let sleep: WidgetSleepSnapshot?
    let action: WidgetActionSnapshot?
    let intelligence: WidgetIntelligenceSnapshot?
    let recoveryDebt: WidgetRecoveryDebtSnapshot?
    let lastUpdate: Date?

    /// Sample data for the widget gallery only. `AnalysisWidgetProvider` returns
    /// it from `placeholder(in:)` and from a preview snapshot, and never from a
    /// timeline entry, so these numbers can never be read as the user's own.
    static let placeholder = AnalysisWidgetEntry(
        date: Date(),
        readiness: WidgetReadinessSnapshot(
            score: 82,
            grade: "A-",
            dayType: "Build",
            updatedAt: Date()
        ),
        sleep: WidgetSleepSnapshot(
            hoursSlept: 7.6,
            deepMinutes: 88,
            remMinutes: 92,
            quality: "Good",
            updatedAt: Date()
        ),
        action: WidgetActionSnapshot(
            headline: "Train with intent",
            detail: "Green recovery supports a building session today.",
            icon: "figure.run",
            updatedAt: Date()
        ),
        intelligence: WidgetIntelligenceSnapshot(
            headline: "HRV is back above baseline",
            severityRaw: 2,
            cardType: "trend",
            updatedAt: Date()
        ),
        recoveryDebt: WidgetRecoveryDebtSnapshot(
            debtHours: 0.4,
            trend: "stable",
            detail: "Fully recovered",
            updatedAt: Date()
        ),
        lastUpdate: Date()
    )
}
