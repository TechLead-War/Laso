import Foundation

/// Score-bucket ladders shared by notification copy, analytics segmentation,
/// and engagement scheduling. All thresholds are heuristic.
///
/// HEURISTIC — unvalidated, needs product / clinical review.
enum ScoreBucketsConfig {

    // MARK: - Engagement Insight Ladder (used by EngagementSequenceScheduler.insightForScore)

    /// Lower bound (inclusive) of the "well recovered" engagement band.
    static let engagementWellRecoveredFloor = 85
    /// Lower bound (inclusive) of the "looking good" engagement band. Same floor
    /// the recovery ring turns green at, so a push never calls a green day moderate.
    static let engagementLookingGoodFloor = DS.optimalFloor
    /// Lower bound (inclusive) of the "moderate" engagement band. Same floor the
    /// recovery ring turns amber at.
    static let engagementModerateFloor = DS.fairFloor
    /// Lower bound (inclusive) of the "needs attention" engagement band.
    static let engagementNeedsAttentionFloor = 40
}
