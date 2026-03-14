import Foundation

/// Central registry for all InsightAnalyzer conformances.
/// New analyzers register themselves here instead of being hardcoded in AnalysisEngine.
/// This satisfies Open/Closed: add an analyzer by appending to the registry, not editing engine code.
enum AnalyzerRegistry {

    /// Lightweight analyzers that run immediately after core analysis (Phase 2A).
    static let essential: [any InsightAnalyzer.Type] = [
        InsightGenerator.self,
        RecoveryAnalyzer.self,
        WorkoutEffectivenessAnalyzer.self,
        SleepPerformanceAnalyzer.self,
        WeeklyPatternAnalyzer.self,
        PersonalRecordAnalyzer.self,
        CyclePhaseAnalyzer.self,
        MultiMetricClusterAnalyzer.self,
        ClinicalIntelligence.self,
        IllnessEarlyWarning.self,
    ]

    /// Expensive analyzers that run with TTL caching (Phase 2B).
    static let heavy: [any InsightAnalyzer.Type] = [
        CorrelationAnalyzer.self,
        HistoricalAnalyzer.self,
        CognitiveEnergyAnalyzer.self,
        CrossMetricAnomalyDetector.self,
        NutritionCorrelationAnalyzer.self,
        CausalChainEngine.self,
    ]

    static func runAll(_ analyzers: [any InsightAnalyzer.Type], context: AnalysisContext) -> [Insight] {
        analyzers.flatMap { $0.generateInsights(context: context) }
    }
}
