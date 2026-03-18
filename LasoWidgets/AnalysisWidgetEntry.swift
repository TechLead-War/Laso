import Foundation
import WidgetKit

struct AnalysisWidgetEntry: TimelineEntry {
    let date: Date
    let readiness: WidgetReadinessSnapshot
    let sleep: WidgetSleepSnapshot
    let action: WidgetActionSnapshot
    let intelligence: WidgetIntelligenceSnapshot
    let recoveryDebt: WidgetRecoveryDebtSnapshot
    let lastUpdate: Date

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
