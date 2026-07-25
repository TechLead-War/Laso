import Foundation

/// Discovers correlations between user-logged journal behaviors and next-day health outcomes.
/// Pairs journal entries with health metrics (HRV, resting HR, sleep quality) using Pearson correlation
/// and generates personalized, data-backed insight strings.
struct JournalCorrelationAnalyzer {

    // MARK: - Types

    /// A discovered correlation between a journal behavior and a health outcome
    struct JournalCorrelation: Identifiable {
        let id = UUID()
        let category: JournalCategory
        let healthMetric: HealthMetric
        let correlation: Double          // Pearson r
        let insight: String              // Human-readable insight
        let sampleCount: Int
        let effectPercent: Double         // Percent difference between high/low groups

        var strengthLabel: String {
            let absR = abs(correlation)
            if absR >= 0.6 { return Copy.Journal.correlationStrong }
            if absR >= 0.4 { return Copy.Journal.correlationModerate }
            return Copy.Journal.correlationMild
        }

        var confidenceLevel: ConfidenceLevel {
            let absR = abs(correlation)
            if sampleCount >= 30 && absR >= 0.4 { return .high }
            if sampleCount >= 20 && absR >= 0.3 { return .medium }
            return .emerging
        }
    }

    enum ConfidenceLevel: String {
        case high = "High Confidence"
        case medium = "Confidence Growing"
        case emerging = "Emerging Pattern"

        var icon: String {
            switch self {
            case .high: return "checkmark.seal.fill"
            case .medium: return "chart.line.uptrend.xyaxis"
            case .emerging: return "sparkles"
            }
        }
    }
}
