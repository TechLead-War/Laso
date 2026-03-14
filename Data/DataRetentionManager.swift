import Foundation
import SwiftData

/// Prunes expired data from SwiftData on app launch.
/// Runs at most once per calendar day to avoid redundant work.
final class DataRetentionManager {

    // MARK: - Prune

    /// Delete rows older than their retention window. Skips if already ran today.
    func pruneIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())

        if let last = defaults.object(forKey: AppKeys.Retention.lastPruneDate) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) {
            return
        }

        let rc = RemoteConfigManager.shared

        let dailySampleDays   = rc.retentionDailySampleDays
        let snapshotDays      = rc.retentionAnalysisSnapshotDays
        let strainDays        = rc.retentionDailyStrainDays
        let recommendationDays = rc.retentionRecommendationDays
        let notificationDays  = rc.retentionNotificationEventDays
        let adherenceDays     = rc.retentionAdherenceRecordDays
        let ecgDays           = rc.retentionECGFeaturesDays
        let journalDays       = rc.retentionJournalEntryDays
        let evaluationDays    = rc.retentionModelEvaluationDays

        var totalPruned = 0

        totalPruned += pruneModel(StoredDailySample.self, dateKeyPath: \.date, olderThanDays: dailySampleDays, context: context)
        totalPruned += pruneModel(StoredAnalysisSnapshot.self, dateKeyPath: \.date, olderThanDays: snapshotDays, context: context)
        totalPruned += pruneModel(StoredDailyStrain.self, dateKeyPath: \.date, olderThanDays: strainDays, context: context)
        totalPruned += pruneModel(StoredRecommendation.self, dateKeyPath: \.shownDate, olderThanDays: recommendationDays, context: context)
        totalPruned += pruneModel(StoredNotificationEvent.self, dateKeyPath: \.sentDate, olderThanDays: notificationDays, context: context)
        totalPruned += pruneModel(StoredAdherenceRecord.self, dateKeyPath: \.givenDate, olderThanDays: adherenceDays, context: context)
        totalPruned += pruneModel(StoredECGFeatures.self, dateKeyPath: \.ecgDate, olderThanDays: ecgDays, context: context)
        totalPruned += pruneModel(StoredJournalEntry.self, dateKeyPath: \.date, olderThanDays: journalDays, context: context)
        totalPruned += pruneModel(StoredModelEvaluation.self, dateKeyPath: \.evaluationDate, olderThanDays: evaluationDays, context: context)

        if totalPruned > 0 {
            try? context.save()
            print("[DataRetention] Pruned \(totalPruned) expired records")
        }

        defaults.set(today, forKey: AppKeys.Retention.lastPruneDate)
    }

    // MARK: - Helpers

    /// Fetch-and-delete rows older than `olderThanDays`. Returns count deleted.
    private func pruneModel<T: PersistentModel>(
        _ type: T.Type,
        dateKeyPath: KeyPath<T, Date>,
        olderThanDays days: Int,
        context: ModelContext
    ) -> Int {
        guard days > 0 else { return 0 }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        // SwiftData doesn't support KeyPath-based predicates generically,
        // so we fetch all and filter in memory. The retention window is long
        // enough that the expired set is small relative to total rows.
        let descriptor = FetchDescriptor<T>()
        guard let all = try? context.fetch(descriptor) else { return 0 }

        var count = 0
        for item in all {
            if item[keyPath: dateKeyPath] < cutoff {
                context.delete(item)
                count += 1
            }
        }
        return count
    }
}
