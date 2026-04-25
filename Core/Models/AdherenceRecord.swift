import Foundation
import SwiftData

// MARK: - Direction

/// Direction of recommended metric change
enum TargetDirection: String, Codable {
    case increase
    case decrease
    case maintain
}

// MARK: - SwiftData Model

/// Tracks whether advice was followed and what the outcome was.
@Model
final class StoredAdherenceRecord {
    /// Pass 12 BE perf: cached current calendar. `isReadyForEvaluation` is
    /// evaluated for every adherence record on each evaluation sweep.
    /// `@Model` ignores `static` members for SwiftData persistence so this
    /// is safe.
    private static let cal: Calendar = Calendar.current

    @Attribute(.unique) var id: String
    var insightCategoryRaw: String
    var insightTitle: String
    var recommendation: String
    var targetMetricRaw: String
    var targetDirectionRaw: String
    var severityRaw: String
    var givenDate: Date
    var adherenceScore: Double?     // 0-1: did metric move in advised direction?
    var outcomeScore: Double?       // 0-1: did overall score improve?
    var metricDelta: Double?        // actual change in target metric
    var measuredDate: Date?         // when the outcome was evaluated

    init(
        id: String = UUID().uuidString,
        insightCategory: InsightCategory,
        insightTitle: String,
        recommendation: String,
        targetMetric: HealthMetric,
        targetDirection: TargetDirection,
        severity: Severity,
        givenDate: Date
    ) {
        self.id = id
        self.insightCategoryRaw = insightCategory.rawValue
        self.insightTitle = insightTitle
        self.recommendation = recommendation
        self.targetMetricRaw = targetMetric.rawValue
        self.targetDirectionRaw = targetDirection.rawValue
        self.severityRaw = severity.rawValue
        self.givenDate = givenDate
    }

    // MARK: - Typed Accessors

    var insightCategory: InsightCategory? {
        InsightCategory(rawValue: insightCategoryRaw)
    }

    var targetMetric: HealthMetric? {
        HealthMetric(rawValue: targetMetricRaw)
    }

    var targetDirection: TargetDirection? {
        TargetDirection(rawValue: targetDirectionRaw)
    }

    var severity: Severity? {
        Severity(rawValue: severityRaw)
    }

    /// Whether this record has been evaluated
    var isEvaluated: Bool {
        adherenceScore != nil && outcomeScore != nil
    }

    /// Whether this record is ready for evaluation (1-3 days old, not yet evaluated)
    var isReadyForEvaluation: Bool {
        guard !isEvaluated else { return false }
        let daysSinceGiven = Self.cal.dateComponents([.day], from: givenDate, to: Date()).day ?? 0
        return daysSinceGiven >= 1 && daysSinceGiven <= 3
    }
}
