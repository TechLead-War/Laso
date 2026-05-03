import Foundation

/// Score-bucket ladders shared by notification copy, analytics segmentation,
/// and engagement scheduling. All thresholds are heuristic.
///
/// HEURISTIC — unvalidated, needs product / clinical review.
enum ScoreBucketsConfig {

    // MARK: - Engagement Insight Ladder (used by EngagementSequenceScheduler.insightForScore)

    /// Lower bound (inclusive) of the "well recovered" engagement band.
    static let engagementWellRecoveredFloor = 85
    /// Lower bound (inclusive) of the "looking good" engagement band.
    static let engagementLookingGoodFloor = 70
    /// Lower bound (inclusive) of the "moderate" engagement band.
    static let engagementModerateFloor = 55
    /// Lower bound (inclusive) of the "needs attention" engagement band.
    static let engagementNeedsAttentionFloor = 40

    // MARK: - Health Status Tag (analytics)

    /// Lower bound (inclusive) of the "healthy" tag.
    static let healthyTagFloor = 75
    /// Lower bound (inclusive) of the "watching" tag (also upper-exclusive for "at risk").
    static let watchingTagFloor = 50
}
