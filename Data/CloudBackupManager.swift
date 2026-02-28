import Foundation
import CloudKit
import Observation

/// Manages CloudKit Private Database backup and restore for computed health data.
/// Only backs up derived/computed data (scores, ML states, baselines, preferences) —
/// raw health samples stay in HealthKit.
@Observable
final class CloudBackupManager {
    static let shared = CloudBackupManager()

    enum BackupStatus: Equatable {
        case idle
        case backingUp
        case restoring
        case failed(String)
        case disabled
    }

    private(set) var backupStatus: BackupStatus = .idle
    private(set) var lastBackupDate: Date?

    private let container = CKContainer(identifier: "iCloud.com.lasohealth.app")
    private let recordID = CKRecord.ID(recordName: "HealthBackup-v1")
    private static let recordType = "HealthBackup"

    /// Minimum interval between automatic backups (6 hours)
    private static let backupThrottleInterval: TimeInterval = 6 * 60 * 60

    private init() {
        lastBackupDate = UserDefaults.standard.object(forKey: AppKeys.Backup.lastBackupDate) as? Date
    }

    // MARK: - Availability

    /// Check if CloudKit is available (user signed into iCloud)
    var isAvailable: Bool {
        get async {
            do {
                let status = try await container.accountStatus()
                return status == .available
            } catch {
                return false
            }
        }
    }

    // MARK: - Backup

    /// Backup if enough time has passed since the last backup (throttled to once per 6 hours)
    func backupIfNeeded(store: HealthDataStore, persistence: PersistenceManager) async {
        // Backup is enabled by default (nil = true). Only disabled if explicitly set to false.
        if UserDefaults.standard.object(forKey: AppKeys.Backup.backupEnabled) != nil,
           !UserDefaults.standard.bool(forKey: AppKeys.Backup.backupEnabled) {
            backupStatus = .disabled
            return
        }

        // Throttle: skip if last backup was within the interval
        if let last = lastBackupDate,
           Date().timeIntervalSince(last) < Self.backupThrottleInterval {
            return
        }

        await performBackup(store: store, persistence: persistence)
    }

    /// Force an immediate backup (no throttle)
    func forceBackup(store: HealthDataStore, persistence: PersistenceManager) async {
        await performBackup(store: store, persistence: persistence)
    }

    private func performBackup(store: HealthDataStore, persistence: PersistenceManager) async {
        guard await isAvailable else {
            backupStatus = .disabled
            return
        }

        backupStatus = .backingUp

        // Build payload from current on-device data
        let payload = buildPayload(store: store, persistence: persistence)

        guard let compressedData = payload.compressed() else {
            backupStatus = .failed("Compression failed")
            return
        }

        // Write compressed data to temp file for CKAsset
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("healthbackup_\(UUID().uuidString).json.lzfse")
        do {
            try compressedData.write(to: tempURL)
        } catch {
            backupStatus = .failed("Failed to write temp file")
            return
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Create or update the CKRecord
        let record: CKRecord
        do {
            record = try await container.privateCloudDatabase.record(for: recordID)
        } catch {
            // Record doesn't exist yet — create it
            record = CKRecord(recordType: Self.recordType, recordID: recordID)
        }

        record["version"] = BackupPayload.currentVersion as CKRecordValue
        record["payload"] = CKAsset(fileURL: tempURL)
        record["lastAnalysisDate"] = payload.createdAt as CKRecordValue
        record["overallScore"] = (payload.snapshots.last?.overallScore ?? 0) as CKRecordValue
        record["mlComponentCount"] = payload.mlStates.count as CKRecordValue
        record["snapshotCount"] = payload.snapshots.count as CKRecordValue

        do {
            try await container.privateCloudDatabase.save(record)
            let now = Date()
            lastBackupDate = now
            UserDefaults.standard.set(now, forKey: AppKeys.Backup.lastBackupDate)
            backupStatus = .idle
        } catch let error as CKError {
            backupStatus = .failed(Self.friendlyError(error))
        } catch {
            backupStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore

    /// Attempt to restore from CloudKit backup. Returns true if data was restored.
    func restore(store: HealthDataStore, persistence: PersistenceManager) async -> Bool {
        guard await isAvailable else { return false }

        backupStatus = .restoring

        let record: CKRecord
        do {
            record = try await container.privateCloudDatabase.record(for: recordID)
        } catch {
            // No backup found — first install or never backed up
            backupStatus = .idle
            return false
        }

        guard let asset = record["payload"] as? CKAsset,
              let fileURL = asset.fileURL,
              let compressedData = try? Data(contentsOf: fileURL),
              let payload = BackupPayload.decompress(from: compressedData) else {
            backupStatus = .failed("Failed to read backup data")
            return false
        }

        // Restore analysis snapshots
        for snapshot in payload.snapshots {
            store.insertRestoredSnapshot(
                date: snapshot.date,
                overallScore: snapshot.overallScore,
                categoryScoresJSON: snapshot.categoryScoresJSON,
                baselinesJSON: snapshot.baselinesJSON
            )
        }

        // Restore ML model states
        for ml in payload.mlStates {
            let state = MLModelState(
                componentName: ml.componentName,
                version: ml.version,
                parametersJSON: ml.parametersJSON,
                dataPointsUsed: ml.dataPointsUsed,
                lastTrainedDate: ml.lastTrainedDate
            )
            store.saveMLModelState(state)
        }

        // Restore sync metadata (so HealthKit sync is incremental, not full re-fetch)
        for (metricRaw, syncDate) in payload.syncDates {
            if let metric = HealthMetric(rawValue: metricRaw) {
                store.markSyncCompleted(for: metric, at: syncDate)
            }
        }

        // Restore baselines
        var baselines: [HealthMetric: UserBaseline] = [:]
        for (metricRaw, entry) in payload.baselines {
            if let metric = HealthMetric(rawValue: metricRaw) {
                baselines[metric] = UserBaseline(
                    metric: metric,
                    mean: entry.mean,
                    standardDeviation: entry.standardDeviation,
                    median: entry.median,
                    sampleCount: entry.sampleCount,
                    lastUpdated: entry.lastUpdated
                )
            }
        }
        if !baselines.isEmpty {
            persistence.saveBaselines(baselines)
        }

        // Restore health focuses
        if !payload.healthFocuses.isEmpty {
            let focuses = Set(payload.healthFocuses.compactMap { HealthFocus(rawValue: $0) })
            if !focuses.isEmpty {
                persistence.saveHealthFocuses(focuses)
            }
        }

        backupStatus = .idle
        return true
    }

    // MARK: - Build Payload

    private func buildPayload(store: HealthDataStore, persistence: PersistenceManager) -> BackupPayload {
        // Snapshots
        let snapshotData = store.loadAllAnalysisSnapshots()
        let snapshots = snapshotData.map {
            SnapshotEntry(
                date: $0.date,
                overallScore: $0.overallScore,
                categoryScoresJSON: $0.categoryScoresJSON,
                baselinesJSON: $0.baselinesJSON
            )
        }

        // ML states
        let mlStates = store.loadAllMLModelStates().map {
            MLStateEntry(
                componentName: $0.componentName,
                version: $0.version,
                parametersJSON: $0.parametersJSON,
                dataPointsUsed: $0.dataPointsUsed,
                lastTrainedDate: $0.lastTrainedDate
            )
        }

        // Baselines
        let loadedBaselines = persistence.loadBaselines()
        let baselines = Dictionary(uniqueKeysWithValues: loadedBaselines.map { metric, baseline in
            (metric.rawValue, BaselineEntry(
                mean: baseline.mean,
                standardDeviation: baseline.standardDeviation,
                median: baseline.median,
                sampleCount: baseline.sampleCount,
                lastUpdated: baseline.lastUpdated
            ))
        })

        // Health focuses
        let focuses = persistence.loadHealthFocuses().map(\.rawValue)

        // Scores
        let previousWeekScore = persistence.loadPreviousWeekScore()
        let scoreHistory = store.loadScoreHistory(days: 1)
        let currentScore = scoreHistory.last?.score

        // Sync dates
        let syncDateMap = store.allSyncDates()
        let syncDates = Dictionary(uniqueKeysWithValues: syncDateMap.map { ($0.key.rawValue, $0.value) })

        return BackupPayload(
            version: BackupPayload.currentVersion,
            createdAt: Date(),
            snapshots: snapshots,
            mlStates: mlStates,
            baselines: baselines,
            healthFocuses: focuses,
            previousWeekScore: previousWeekScore,
            currentScore: currentScore,
            syncDates: syncDates
        )
    }

    // MARK: - Error Helpers

    private static func friendlyError(_ error: CKError) -> String {
        switch error.code {
        case .quotaExceeded:
            return "iCloud storage full"
        case .networkUnavailable, .networkFailure:
            return "Network unavailable"
        case .serverResponseLost:
            return "Server connection lost"
        case .notAuthenticated:
            return "Not signed into iCloud"
        default:
            return "Backup failed: \(error.localizedDescription)"
        }
    }
}
