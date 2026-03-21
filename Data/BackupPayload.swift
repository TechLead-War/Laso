import Foundation

/// Single Codable struct combining all computed health data for CloudKit backup.
/// Raw health samples are NOT included. HealthKit handles those system-wide.
struct BackupPayload: Codable {
    /// Schema version for future migration
    let version: Int
    /// When this backup was created
    let createdAt: Date

    // MARK: - Analysis Snapshots (score history. most valuable)

    let snapshots: [SnapshotEntry]

    // MARK: - ML Model States (expensive to retrain)

    let mlStates: [MLStateEntry]

    // MARK: - Baselines (recomputable but saves time)

    let baselines: [String: BaselineEntry]  // keyed by metric rawValue

    // MARK: - User Preferences

    let healthFocuses: [String]  // HealthFocus rawValues
    let previousWeekScore: Int?
    let currentScore: Int?

    // MARK: - v2 Fields

    let notificationPreferences: NotificationPreferences?
    let progressiveCoachState: ProgressiveCoachState?

    // MARK: - Sync Metadata (avoids full HealthKit re-fetch)

    let syncDates: [String: Date]  // metric rawValue → last sync date

    /// Current schema version
    static let currentVersion = 2
}

// MARK: - Nested Entry Types

struct SnapshotEntry: Codable {
    let date: Date
    let overallScore: Int
    let categoryScoresJSON: Data
    let baselinesJSON: Data
}

struct MLStateEntry: Codable {
    let componentName: String
    let version: Int
    let parametersJSON: Data
    let dataPointsUsed: Int
    let lastTrainedDate: Date
}

struct BaselineEntry: Codable {
    let mean: Double
    let standardDeviation: Double
    let median: Double
    let sampleCount: Int
    let lastUpdated: Date
}

// MARK: - Compression & Encryption

extension BackupPayload {
    /// Encode to JSON and compress with LZFSE
    func compressed() -> Data? {
        guard let json = try? JSONEncoder().encode(self) else { return nil }
        return try? (json as NSData).compressed(using: .lzfse) as Data
    }

    /// Decompress LZFSE data and decode from JSON
    static func decompress(from data: Data) -> BackupPayload? {
        guard let decompressed = try? (data as NSData).decompressed(using: .lzfse) as Data else { return nil }
        return try? JSONDecoder().decode(BackupPayload.self, from: decompressed)
    }

    /// Encode to JSON, compress with LZFSE, then AES-GCM encrypt with iCloud-synced key
    func compressedAndEncrypted() -> Data? {
        guard let lzfse = compressed() else { return nil }
        return EncryptedStore.shared.encryptForCloud(lzfse)
    }

    /// Try AES-GCM decrypt then LZFSE decompress; fall back to plain decompress for v1 backups
    static func decryptAndDecompress(from data: Data) -> BackupPayload? {
        // Try encrypted path first (v2)
        if let decrypted = EncryptedStore.shared.decryptFromCloud(data),
           let payload = decompress(from: decrypted) {
            return payload
        }
        // Fallback: unencrypted v1 backup
        return decompress(from: data)
    }
}
