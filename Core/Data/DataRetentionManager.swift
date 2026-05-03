import Foundation
import SwiftData

/// Prunes expired data from SwiftData on app launch.
/// Runs at most once per calendar day to avoid redundant work.
final class DataRetentionManager {


    // MARK: - Prune

    /// Delete rows older than their retention window. Skips if already ran today.
    func pruneIfNeeded(context: ModelContext) {
        let defaults = UserDefaults.standard
        let today = Date.cal.startOfDay(for: Date())

        if let last = defaults.object(forKey: AppKeys.Retention.lastPruneDate) as? Date,
           Date.cal.isDate(last, inSameDayAs: today) {
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

        totalPruned += pruneStoredDailySample(olderThanDays: dailySampleDays, context: context)
        totalPruned += pruneStoredAnalysisSnapshot(olderThanDays: snapshotDays, context: context)
        totalPruned += pruneStoredDailyStrain(olderThanDays: strainDays, context: context)
        totalPruned += pruneStoredRecommendation(olderThanDays: recommendationDays, context: context)
        totalPruned += pruneStoredNotificationEvent(olderThanDays: notificationDays, context: context)
        totalPruned += pruneStoredAdherenceRecord(olderThanDays: adherenceDays, context: context)
        totalPruned += pruneStoredECGFeatures(olderThanDays: ecgDays, context: context)
        totalPruned += pruneStoredJournalEntry(olderThanDays: journalDays, context: context)
        totalPruned += pruneStoredModelEvaluation(olderThanDays: evaluationDays, context: context)

        if totalPruned > 0 {
            try? context.save()
            #if DEBUG
            print("[DataRetention] Pruned \(totalPruned) expired records")
            #endif
        }

        defaults.set(today, forKey: AppKeys.Retention.lastPruneDate)
    }

    // MARK: - Helpers

    private func cutoffDate(olderThanDays days: Int) -> Date? {
        guard days > 0 else { return nil }
        return Date.cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    private func deleteAll<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, context: ModelContext) -> Int {
        guard let items = try? context.fetch(descriptor), !items.isEmpty else { return 0 }
        for item in items {
            context.delete(item)
        }
        return items.count
    }

    private func pruneStoredDailySample(olderThanDays days: Int, context: ModelContext) -> Int {
        guard let cutoff = cutoffDate(olderThanDays: days) else { return 0 }
        let predicate = #Predicate<StoredDailySample> { $0.date < cutoff }
        return deleteAll(FetchDescriptor(predicate: predicate), context: context)
    }

    private func pruneStoredAnalysisSnapshot(olderThanDays days: Int, context: ModelContext) -> Int {
        guard let cutoff = cutoffDate(olderThanDays: days) else { return 0 }
        let predicate = #Predicate<StoredAnalysisSnapshot> { $0.date < cutoff }
        return deleteAll(FetchDescriptor(predicate: predicate), context: context)
    }

    private func pruneStoredDailyStrain(olderThanDays days: Int, context: ModelContext) -> Int {
        guard let cutoff = cutoffDate(olderThanDays: days) else { return 0 }
        let predicate = #Predicate<StoredDailyStrain> { $0.date < cutoff }
        return deleteAll(FetchDescriptor(predicate: predicate), context: context)
    }

    private func pruneStoredRecommendation(olderThanDays days: Int, context: ModelContext) -> Int {
        guard let cutoff = cutoffDate(olderThanDays: days) else { return 0 }
        let predicate = #Predicate<StoredRecommendation> { $0.shownDate < cutoff }
        return deleteAll(FetchDescriptor(predicate: predicate), context: context)
    }

    private func pruneStoredNotificationEvent(olderThanDays days: Int, context: ModelContext) -> Int {
        guard let cutoff = cutoffDate(olderThanDays: days) else { return 0 }
        let predicate = #Predicate<StoredNotificationEvent> { $0.sentDate < cutoff }
        return deleteAll(FetchDescriptor(predicate: predicate), context: context)
    }

    private func pruneStoredAdherenceRecord(olderThanDays days: Int, context: ModelContext) -> Int {
        guard let cutoff = cutoffDate(olderThanDays: days) else { return 0 }
        let predicate = #Predicate<StoredAdherenceRecord> { $0.givenDate < cutoff }
        return deleteAll(FetchDescriptor(predicate: predicate), context: context)
    }

    private func pruneStoredECGFeatures(olderThanDays days: Int, context: ModelContext) -> Int {
        guard let cutoff = cutoffDate(olderThanDays: days) else { return 0 }
        let predicate = #Predicate<StoredECGFeatures> { $0.ecgDate < cutoff }
        return deleteAll(FetchDescriptor(predicate: predicate), context: context)
    }

    private func pruneStoredJournalEntry(olderThanDays days: Int, context: ModelContext) -> Int {
        guard let cutoff = cutoffDate(olderThanDays: days) else { return 0 }
        let predicate = #Predicate<StoredJournalEntry> { $0.date < cutoff }
        return deleteAll(FetchDescriptor(predicate: predicate), context: context)
    }

    private func pruneStoredModelEvaluation(olderThanDays days: Int, context: ModelContext) -> Int {
        guard let cutoff = cutoffDate(olderThanDays: days) else { return 0 }
        let predicate = #Predicate<StoredModelEvaluation> { $0.evaluationDate < cutoff }
        return deleteAll(FetchDescriptor(predicate: predicate), context: context)
    }
}
