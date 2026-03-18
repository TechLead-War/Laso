import Foundation
import NaturalLanguage

/// Core LLM/Semantic Insight Generation Framework
/// Converts structured mathematical output (ARIMA, CoreML) into expressive, contextualized Natural Language variations.
final class LLMInsightGenerator {
    
    private let semanticAnalyzer = NLEmbeddingAnalyzer()
    
    // MARK: - Prompt Context Dictionary
    
    struct InsightContext {
        var baseTopic: String
        var primaryMetric: HealthMetric
        var trendChange: Double
        var riskScore: Double
        var relatedMetrics: [HealthMetric]
        var causalLag: Int?
        var severity: CompoundInsightEngine.CompoundInsight.InsightSeverity
    }
    
    // MARK: - Natural Language Synthesis
    
    /// Constructs a fully realized paragraph from raw statistical triggers.
    func synthesizeParagraph(context: InsightContext) -> String {
        let sentiment = determineSentiment(for: context)
        
        // 1. Contextualize the Opening
        var narrative = constructOpening(context: context, sentiment: sentiment)
        narrative += " "
        
        // 2. Weave in the quantitative evidence
        narrative += constructEvidence(context: context, sentiment: sentiment)
        
        // 3. Add causal links if they exist
        if let lag = context.causalLag, !context.relatedMetrics.isEmpty {
            narrative += " "
            narrative += constructCausal(lag: lag, metric: context.relatedMetrics[0], sentiment: sentiment)
        }
        
        // 4. Conclude with a dynamic NLP summation
        let conclusion = constructConclusion(sentiment: sentiment)
        narrative += " \(conclusion)"
        
        return narrative
    }
    
    // MARK: - Language Generation Helpers
    
    private func determineSentiment(for context: InsightContext) -> NLEmbeddingAnalyzer.SentimentTier {
        if context.riskScore > 0.6 || context.severity == .urgent { return .negative }
        if context.riskScore < 0.3 && context.trendChange > 5.0 { return .positive }
        return .neutral
    }
    
    private func constructOpening(context: InsightContext, sentiment: NLEmbeddingAnalyzer.SentimentTier) -> String {
        let topic = semanticAnalyzer.contextualizeWord(context.baseTopic, targetSentiment: sentiment)
        let metrics = context.relatedMetrics.map { $0.displayName }.joined(separator: " and ")
        
        switch sentiment {
        case .positive:
            return "Your \(topic) is displaying a robust upward trajectory across \(metrics)."
        case .neutral:
            return "We are observing a noticeable shift in your \(topic), specifically concerning \(metrics)."
        case .negative:
            return "Warning: Your \(topic) is exhibiting a marked decline involving \(metrics)."
        }
    }
    
    private func constructEvidence(context: InsightContext, sentiment: NLEmbeddingAnalyzer.SentimentTier) -> String {
        let metricName = context.primaryMetric.displayName
        let formattedChange = String(format: "%.1f%%", abs(context.trendChange))
        let direction = context.trendChange > 0 ? "upward" : "downward"
        
        let shiftDesc = semanticAnalyzer.contextualizeWord("shift", targetSentiment: sentiment)
        
        return "\(metricName) has experienced a \(formattedChange) \(direction) \(shiftDesc)."
    }
    
    private func constructCausal(lag: Int, metric: HealthMetric, sentiment: NLEmbeddingAnalyzer.SentimentTier) -> String {
        let causeWord = semanticAnalyzer.contextualizeWord("influences", targetSentiment: sentiment)
        return "Historically, this \(causeWord) your \(metric.displayName) within \(lag) day\(lag == 1 ? "" : "s")."
    }
    
    private func constructConclusion(sentiment: NLEmbeddingAnalyzer.SentimentTier) -> String {
        switch sentiment {
        case .positive:
            return "Maintain this momentum to preserve peak performance."
        case .neutral:
            return "Keep an eye on these metrics over the coming days."
        case .negative:
            return "Consider scaling back intensity today to allow your body to recover."
        }
    }
}
