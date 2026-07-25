import Foundation

// MARK: - Service Protocols
// Abstractions for dependency injection and testability.

protocol CloudBackupService {
    func backupIfNeeded(store: HealthDataStore, persistence: PersistenceManager) async
}

protocol NotificationAuthorizationService {
    func isCurrentlyAuthorized() async -> Bool
}

@MainActor protocol AnalyticsTrackingService {
    func trackAnalysisCompleted(
        score: Int,
        insightsCount: Int,
        anomaliesCount: Int,
        risksCount: Int,
        correlationsCount: Int,
        illnessWarningsCount: Int,
        metricsAnalyzed: Int
    )
    func trackWeeklyScoreChange(newScore: Int, delta: Int)
    func trackValueDelivered(newInsightsCount: Int, scoreChanged: Bool, newAnomalies: Int, newCorrelations: Int)
}

@MainActor protocol SessionTrackingService {
    var streakDays: Int { get }
}

// MARK: - Conformances

extension CloudBackupManager: CloudBackupService {}
extension NotificationManager: NotificationAuthorizationService {}
extension AppAnalytics: AnalyticsTrackingService {}
extension SessionTracker: SessionTrackingService {}
