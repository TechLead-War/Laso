import Foundation

// MARK: - Service Protocols
// Abstractions for dependency injection and testability.

protocol EncryptionService {
    func save(_ data: Data, forKey key: String)
    func load(forKey key: String) -> Data?
    func remove(forKey key: String)
    func migrateIfNeeded(forKey key: String)
    func encryptForCloud(_ data: Data) -> Data?
    func decryptFromCloud(_ data: Data) -> Data?
}

protocol ConfigService {
    func isFeatureEnabled(_ feature: RemoteConfigManager.FeatureKey, for tier: String) -> Bool
    var homeRefreshIntervalSeconds: Int { get }
    var killSwitchEnabled: Bool { get }
    var killLiveTab: Bool { get }
    var killMLPipeline: Bool { get }
}

protocol PersistenceService {
    func saveBaselines(_ baselines: [HealthMetric: UserBaseline])
    func loadBaselines() -> [HealthMetric: UserBaseline]
    func savePreferences(_ preferences: NotificationPreferences)
    func loadPreferences() -> NotificationPreferences
    func saveLastAnalysisDate(_ date: Date)
    func loadLastAnalysisDate() -> Date?
    func recordWeeklyScore(_ score: Int)
    func loadPreviousWeekScore() -> Int?
    func saveHealthFocuses(_ focuses: Set<HealthFocus>)
    func loadHealthFocuses() -> Set<HealthFocus>
}

protocol CloudBackupService {
    func backupIfNeeded(store: HealthDataStore, persistence: PersistenceManager) async
}

protocol NotificationAuthorizationService {
    func requestAuthorizationIfNeeded() async -> Bool
}

protocol AnalyticsTrackingService {
    func trackAnalysisCompleted(
        score: Int,
        insightsCount: Int,
        anomaliesCount: Int,
        risksCount: Int,
        correlationsCount: Int,
        illnessWarningsCount: Int,
        metricsAnalyzed: Int
    )
    func trackWeeklyScoreChange(newScore: Int, previousScore: Int?, delta: Int)
    func trackValueDelivered(newInsightsCount: Int, scoreChanged: Bool, newAnomalies: Int, newCorrelations: Int)
}

protocol SessionTrackingService {
    var streakDays: Int { get }
}

// MARK: - Conformances

extension EncryptedStore: EncryptionService {}
extension PersistenceManager: PersistenceService {}
extension CloudBackupManager: CloudBackupService {}
extension NotificationManager: NotificationAuthorizationService {}
extension AppAnalytics: AnalyticsTrackingService {}
extension SessionTracker: SessionTrackingService {}
