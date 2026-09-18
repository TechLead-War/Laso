import Foundation
import SwiftData

enum HealthDataContainerFactory {
    /// Creates a ModelContainer with progressive fallback and logs each failure.
    static func makeModelContainer(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) -> ModelContainer? {
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let storeDir = appSupportDir.appendingPathComponent("HealthData", isDirectory: true)
        try? fileManager.createDirectory(at: storeDir, withIntermediateDirectories: true)
        try? (storeDir as NSURL).setResourceValue(
            URLFileProtection.completeUntilFirstUserAuthentication,
            forKey: .fileProtectionKey
        )

        let dbURL = storeDir.appendingPathComponent("health.store")
        let allModels: [any PersistentModel.Type] = [
            StoredDailySample.self, StoredSyncMetadata.self,
            StoredAnalysisSnapshot.self, StoredDailyStrain.self, StoredMLModelState.self,
            StoredRecommendation.self, StoredNotificationEvent.self,
            StoredAdherenceRecord.self, StoredECGFeatures.self,
            StoredModelEvaluation.self, StoredJournalEntry.self
        ]

        let schemaVersionKey = AppConstants.Schema.versionKey
        let currentSchemaVersion = allModels.count
        let storedSchemaVersion = userDefaults.integer(forKey: schemaVersionKey)
        if storedSchemaVersion != 0 && storedSchemaVersion != currentSchemaVersion {
            AnalyticsBackend.provider.captureError("Schema changed (\(storedSchemaVersion) -> \(currentSchemaVersion)), deleting DB", context: "model_container_init")
            removeDatabaseArtifacts(at: dbURL, fileManager: fileManager)
        }

        do {
            let config = ModelConfiguration(url: dbURL)
            let container = try ModelContainer(for: Schema(allModels), configurations: [config])
            userDefaults.set(currentSchemaVersion, forKey: schemaVersionKey)
            return container
        } catch {
            AnalyticsBackend.provider.captureError(error, context: "model_container_step1_disk")
        }

        removeDatabaseArtifacts(at: dbURL, fileManager: fileManager)
        do {
            let config = ModelConfiguration(url: dbURL)
            let container = try ModelContainer(for: Schema(allModels), configurations: [config])
            userDefaults.set(currentSchemaVersion, forKey: schemaVersionKey)
            return container
        } catch {
            AnalyticsBackend.provider.captureError(error, context: "model_container_step2_clean_disk")
        }

        let fallbackSets: [[any PersistentModel.Type]] = [
            allModels,
            [StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredDailyStrain.self, StoredRecommendation.self, StoredNotificationEvent.self],
            [StoredDailySample.self, StoredSyncMetadata.self, StoredDailyStrain.self],
            [StoredDailySample.self, StoredDailyStrain.self]
        ]

        for (index, models) in fallbackSets.enumerated() {
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(for: Schema(models), configurations: [config])
            } catch {
                AnalyticsBackend.provider.captureError(error, context: "model_container_step\(index + 3)_memory", metadata: ["model_count": models.count])
            }
        }

        do {
            return try ModelContainer(for: StoredDailySample.self, StoredDailyStrain.self)
        } catch {
            AnalyticsBackend.provider.captureError(error, context: "model_container_all_failed")
            return nil
        }
    }

    private static func removeDatabaseArtifacts(at url: URL, fileManager: FileManager) {
        for suffix in ["", "-wal", "-shm"] {
            try? fileManager.removeItem(atPath: url.path + suffix)
        }
    }
}
