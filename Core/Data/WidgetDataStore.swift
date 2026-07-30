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

private extension WidgetReadinessSnapshot {
    func matchesContent(of other: Self) -> Bool {
        score == other.score && grade == other.grade && dayType == other.dayType
    }
}

private extension WidgetSleepSnapshot {
    func matchesContent(of other: Self) -> Bool {
        hoursSlept == other.hoursSlept &&
        deepMinutes == other.deepMinutes &&
        remMinutes == other.remMinutes &&
        quality == other.quality
    }
}

private extension WidgetActionSnapshot {
    func matchesContent(of other: Self) -> Bool {
        headline == other.headline && detail == other.detail && icon == other.icon
    }
}

private extension WidgetIntelligenceSnapshot {
    func matchesContent(of other: Self) -> Bool {
        headline == other.headline && severityRaw == other.severityRaw && cardType == other.cardType
    }
}

private extension WidgetRecoveryDebtSnapshot {
    func matchesContent(of other: Self) -> Bool {
        debtHours == other.debtHours && trend == other.trend && detail == other.detail
    }
}

// MARK: - Widget Data Store

/// Bridges main app data to the widget extension via App Group UserDefaults.
final class WidgetDataStore {
    static let shared = WidgetDataStore()

    private let suiteName: String
    private let userDefaults: UserDefaults?

    // A full snapshot write runs `save`/`load` up to ten times in one pass, so
    // the coders are shared instead of allocated per call.
    private static let jsonEncoder = JSONEncoder()
    private static let jsonDecoder = JSONDecoder()

    init(suiteName: String = "group.com.lasohealth.fit") {
        self.suiteName = suiteName
        self.userDefaults = UserDefaults(suiteName: suiteName)
    }

    // MARK: - Write (Main App)

    func saveReadiness(_ snapshot: WidgetReadinessSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.readiness)
    }

    @discardableResult
    func saveReadinessIfChanged(_ snapshot: WidgetReadinessSnapshot) -> Bool {
        if let current = loadReadiness(), current.matchesContent(of: snapshot) {
            return false
        }
        saveReadiness(snapshot)
        return true
    }

    func saveSleep(_ snapshot: WidgetSleepSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.sleep)
    }

    @discardableResult
    func saveSleepIfChanged(_ snapshot: WidgetSleepSnapshot) -> Bool {
        if let current = loadSleep(), current.matchesContent(of: snapshot) {
            return false
        }
        saveSleep(snapshot)
        return true
    }

    func saveAction(_ snapshot: WidgetActionSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.action)
    }

    @discardableResult
    func saveActionIfChanged(_ snapshot: WidgetActionSnapshot) -> Bool {
        if let current = loadAction(), current.matchesContent(of: snapshot) {
            return false
        }
        saveAction(snapshot)
        return true
    }

    func saveIntelligence(_ snapshot: WidgetIntelligenceSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.intelligence)
    }

    @discardableResult
    func saveIntelligenceIfChanged(_ snapshot: WidgetIntelligenceSnapshot) -> Bool {
        if let current = loadIntelligence(), current.matchesContent(of: snapshot) {
            return false
        }
        saveIntelligence(snapshot)
        return true
    }

    func saveRecoveryDebt(_ snapshot: WidgetRecoveryDebtSnapshot) {
        save(snapshot, forKey: AppKeys.Widget.recoveryDebt)
    }

    @discardableResult
    func saveRecoveryDebtIfChanged(_ snapshot: WidgetRecoveryDebtSnapshot) -> Bool {
        if let current = loadRecoveryDebt(), current.matchesContent(of: snapshot) {
            return false
        }
        saveRecoveryDebt(snapshot)
        return true
    }

    func markLastUpdate() {
        userDefaults?.set(Date().timeIntervalSince1970, forKey: AppKeys.Widget.lastUpdate)
    }

    // MARK: - Account Wipe

    /// Erase the whole App Group after the user deletes their data.
    /// The widget runs in its own process and renders straight from this suite,
    /// so keys left behind keep a deleted user's score, sleep and coaching line
    /// on the home and lock screen until something writes again. Clearing the
    /// domain rather than named keys also drops the pending coach action that
    /// CoachActionBridge writes into the same suite.
    func clearAll() {
        guard let userDefaults else {
            // Nil only when the App Group entitlement is missing. Nothing could
            // have been written either, but a wipe must never fail quietly.
            assertionFailure("App Group \(suiteName) unavailable during account wipe")
            return
        }
        userDefaults.removePersistentDomain(forName: suiteName)
        WidgetCenter.shared.reloadAllTimelines()
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
        guard let data = try? Self.jsonEncoder.encode(value) else { return }
        userDefaults?.set(data, forKey: key)
    }

    private func load<T: Decodable>(forKey key: String) -> T? {
        guard let data = userDefaults?.data(forKey: key) else { return nil }
        return try? Self.jsonDecoder.decode(T.self, from: data)
    }

    /// Write all widget snapshots and reload timelines only if user-visible content changed.
    @discardableResult
    func writeAllSnapshots(
        readiness: WidgetReadinessSnapshot?,
        sleep: WidgetSleepSnapshot?,
        action: WidgetActionSnapshot?,
        intelligence: WidgetIntelligenceSnapshot?,
        recoveryDebt: WidgetRecoveryDebtSnapshot?
    ) -> Int {
        var changedSnapshots = 0

        if let readiness, saveReadinessIfChanged(readiness) { changedSnapshots += 1 }
        if let sleep, saveSleepIfChanged(sleep) { changedSnapshots += 1 }
        if let action, saveActionIfChanged(action) { changedSnapshots += 1 }
        if let intelligence, saveIntelligenceIfChanged(intelligence) { changedSnapshots += 1 }
        if let recoveryDebt, saveRecoveryDebtIfChanged(recoveryDebt) { changedSnapshots += 1 }

        if changedSnapshots > 0 {
            markLastUpdate()
            WidgetCenter.shared.reloadAllTimelines()
        }

        return changedSnapshots
    }
}
