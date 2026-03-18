import Foundation
import WidgetKit

// MARK: - Widget Snapshot Types

struct WidgetReadinessSnapshot: Codable {
    let score: Int
    let grade: String
    let dayType: String
    let updatedAt: Date
}

struct WidgetSleepSnapshot: Codable {
    let hoursSlept: Double
    let deepMinutes: Double
    let remMinutes: Double
    let quality: String
    let updatedAt: Date
}

struct WidgetActionSnapshot: Codable {
    let headline: String
    let detail: String
    let icon: String
    let updatedAt: Date
}

struct WidgetIntelligenceSnapshot: Codable {
    let headline: String
    let severityRaw: Int
    let cardType: String
    let updatedAt: Date
}

struct WidgetRecoveryDebtSnapshot: Codable {
    let debtHours: Double
    let trend: String // "improving", "worsening", "stable"
    let detail: String
    let updatedAt: Date
}

// MARK: - Widget Data Store

/// Bridges main app data to the widget extension via App Group UserDefaults.
final class WidgetDataStore {
    static let shared = WidgetDataStore()

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults? = UserDefaults(suiteName: "group.com.lasohealth.com")) {
        self.userDefaults = userDefaults
    }

    // MARK: - Write (Main App)

    func saveReadiness(_ snapshot: WidgetReadinessSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.readiness)
    }

    func saveSleep(_ snapshot: WidgetSleepSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.sleep)
    }

    func saveAction(_ snapshot: WidgetActionSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.action)
    }

    func saveIntelligence(_ snapshot: WidgetIntelligenceSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.intelligence)
    }

    func saveRecoveryDebt(_ snapshot: WidgetRecoveryDebtSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.recoveryDebt)
    }

    func markLastUpdate() {
        userDefaults?.set(Date().timeIntervalSince1970, forKey: AppKeys.Widget.lastUpdate)
    }

    // MARK: - Read (Widget Extension)

    func loadReadiness() -> WidgetReadinessSnapshot? {
        load(forKey: AppKeys.Widget.readiness)
    }

    func loadSleep() -> WidgetSleepSnapshot? {
        load(forKey: AppKeys.Widget.sleep)
    }

    func loadAction() -> WidgetActionSnapshot? {
        load(forKey: AppKeys.Widget.action)
    }

    func loadIntelligence() -> WidgetIntelligenceSnapshot? {
        load(forKey: AppKeys.Widget.intelligence)
    }

    func loadRecoveryDebt() -> WidgetRecoveryDebtSnapshot? {
        load(forKey: AppKeys.Widget.recoveryDebt)
    }

    func lastUpdateDate() -> Date? {
        guard let ts = userDefaults?.double(forKey: AppKeys.Widget.lastUpdate), ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    // MARK: - Helpers

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        userDefaults?.set(data, forKey: key)
    }

    private func load<T: Decodable>(forKey key: String) -> T? {
        guard let data = userDefaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Write all widget snapshots and reload timelines.
    func writeAllSnapshots(
        readiness: WidgetReadinessSnapshot?,
        sleep: WidgetSleepSnapshot?,
        action: WidgetActionSnapshot?,
        intelligence: WidgetIntelligenceSnapshot?,
        recoveryDebt: WidgetRecoveryDebtSnapshot?
    ) {
        if let readiness { saveReadiness(readiness) }
        if let sleep { saveSleep(sleep) }
        if let action { saveAction(action) }
        if let intelligence { saveIntelligence(intelligence) }
        if let recoveryDebt { saveRecoveryDebt(recoveryDebt) }
        markLastUpdate()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
