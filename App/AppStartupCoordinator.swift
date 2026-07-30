import AppIntents
import Foundation
import SwiftData

/// Owns post-launch startup work once SwiftUI has rendered.
@MainActor
final class AppStartupCoordinator {
    private let subscriptionManager: SubscriptionManager
    private let cloudBackupManager: CloudBackupManager
    private let notificationManager: NotificationManager
    private let watchMonitor: WatchMonitor
    private let persistenceManager: PersistenceManager

    init(
        subscriptionManager: SubscriptionManager,
        cloudBackupManager: CloudBackupManager,
        notificationManager: NotificationManager,
        watchMonitor: WatchMonitor,
        persistenceManager: PersistenceManager
    ) {
        self.subscriptionManager = subscriptionManager
        self.cloudBackupManager = cloudBackupManager
        self.notificationManager = notificationManager
        self.watchMonitor = watchMonitor
        self.persistenceManager = persistenceManager
    }

    func runInitialSetup(
        healthDataStore: HealthDataStore,
        healthKitManager: HealthKitManager
    ) async {
        async let subscriptionTask: Void = subscriptionManager.configure()

        if !healthDataStore.hasRestorableState {
            _ = await cloudBackupManager.restore(
                store: healthDataStore,
                persistence: persistenceManager
            )
        }

        _ = await subscriptionTask

        notificationManager.store = healthDataStore
        LasoShortcutsProvider.updateAppShortcutParameters()

        watchMonitor.configure(healthStore: healthKitManager.healthStore)
        watchMonitor.startMonitoring()

        // Weekly summary is a repeating calendar trigger re-armed by dashboard
        // housekeeping; cancelling it here on every launch left users with no
        // weekly notification until the next full refresh.
        pruneExpiredDataIfNeeded(in: healthDataStore)
    }

    private func pruneExpiredDataIfNeeded(in store: HealthDataStore) {
        guard let container = store.modelContainer else { return }

        let retentionContext = ModelContext(container)
        // Only invalidate when rows actually went away. Invalidating unconditionally
        // threw away a cache that nothing had made stale, and the next read paid for
        // a second full materialization of the whole sample table.
        if DataRetentionManager().pruneIfNeeded(context: retentionContext) > 0 {
            store.invalidateTimeSeriesCache()
        }
    }
}
