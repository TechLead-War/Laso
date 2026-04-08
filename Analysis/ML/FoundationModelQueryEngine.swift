import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Output Type

@available(iOS 26, *)
@Generable
struct GeneratedHealthAnswer {
    @Guide(description: "A natural language answer to the user's health question. Lead with a specific actionable recommendation ('You should...', 'Try...', 'Focus on...'), then briefly explain why using the data. Use plain English, not medical jargon. 2-3 sentences for simple questions, 4-5 for complex ones. Sound like a knowledgeable friend, not a medical report.")
    var answer: String

    @Guide(description: "2-3 follow-up questions the user might want to ask next, based on the answer.")
    var relatedQuestions: [String]

    @Guide(description: "Confidence in the answer from 0.3 (low, limited data) to 0.95 (high, strong data support).")
    var confidence: Double
}

// MARK: - Foundation Model Query Engine

/// On-device LLM-powered health query engine using Apple's Foundation Models framework.
/// Requires iOS 26+ with Apple Intelligence enabled.
/// Falls back to the existing rule-based engine on any failure.
@available(iOS 26, *)
final class FoundationModelQueryEngine: HealthQueryEngine, @unchecked Sendable {

    private let fallbackEngine: HealthDataQueryEngine

    init(fallback: HealthDataQueryEngine) {
        self.fallbackEngine = fallback
    }

    func query(
        question: String,
        context: HealthDataQueryEngine.QueryContext
    ) async throws -> HealthDataQueryEngine.QueryResult {
        do {
            return try await foundationModelQuery(question: question, context: context)
        } catch {
            // Silent fallback to the rule-based engine on any failure
            return fallbackEngine.query(question: question, context: context, matchingMode: .full)
        }
    }

    // MARK: - Core LLM Query

    private func foundationModelQuery(
        question: String,
        context: HealthDataQueryEngine.QueryContext
    ) async throws -> HealthDataQueryEngine.QueryResult {

        // Build tools with captured context (wrapped for Sendable)
        let tc = ToolContext(context)
        let tools: [any Tool] = [
            MetricDetailTool(tc: tc),
            TrendsTool(tc: tc),
            CorrelationsTool(tc: tc),
            ForecastTool(tc: tc),
            RiskReportTool(tc: tc),
            PatternsTool(tc: tc),
            CircadianTool(tc: tc),
            OptimizationTool(tc: tc),
            CausalTool(tc: tc),
            ScoreBreakdownTool(tc: tc),
        ]

        // Create session with instructions and tools
        let snapshot = ContextCompressor.buildHealthSnapshot(context: context)
        let session = LanguageModelSession(tools: tools) {
            """
            You are a friendly health coach embedded in a health tracking app called Laso.
            You have access to the user's Apple Health data through the tools provided.
            You sound like a knowledgeable friend — warm, direct, and practical.
            """

            """
            RULES:
            - ALWAYS lead with what the user should DO — a specific, actionable recommendation. Put the advice before the data.
            - Use plain English. Say "your resting heart rate" not "RHR". Say "recovery" not "parasympathetic tone". Avoid raw sigma values and statistical jargon in the answer.
            - Keep it concise: 2-3 sentences for simple questions, 4-5 for complex ones.
            - Ground your advice in the user's actual data. Use the tools to fetch specific metrics before answering.
            - NEVER diagnose medical conditions or prescribe medication.
            - If data is insufficient, say so honestly and suggest what to track.
            - Sound encouraging, not clinical. "Your sleep has been solid" not "Sleep duration is within normal parameters".
            - Use at most 2 tool calls to stay within context limits.
            """

            """
            CURRENT HEALTH SNAPSHOT:
            \(snapshot)
            """
        }

        // Generate structured response
        let response = try await session.respond(
            to: question,
            generating: GeneratedHealthAnswer.self
        )

        let generated = response.content

        // Extract data points from tool calls made during the session
        let dataPoints = extractDataPoints(from: context, question: question)

        return HealthDataQueryEngine.QueryResult(
            question: question,
            answer: generated.answer,
            dataPoints: dataPoints,
            confidence: max(0.3, min(0.95, generated.confidence)),
            relatedQuestions: Array(generated.relatedQuestions.prefix(3))
        )
    }

    // MARK: - Data Point Extraction

    /// Extracts relevant data points programmatically based on the question context.
    /// We don't rely on the LLM for exact numbers — we pull them from the data directly.
    private func extractDataPoints(
        from context: HealthDataQueryEngine.QueryContext,
        question: String
    ) -> [HealthDataQueryEngine.QueryResult.DataPoint] {
        let q = question.lowercased()
        var points: [HealthDataQueryEngine.QueryResult.DataPoint] = []

        // Find metrics mentioned in the question
        let mentionedMetrics = detectMentionedMetrics(in: q, context: context)

        for metric in mentionedMetrics.prefix(3) {
            if let series = context.timeSeries[metric], let latest = series.samples.last {
                points.append(.init(
                    label: "Latest",
                    value: latest.value,
                    unit: metric.unit,
                    date: latest.date
                ))
            }
            if let baseline = context.baselines[metric] {
                points.append(.init(
                    label: "Baseline",
                    value: baseline.mean,
                    unit: metric.unit,
                    date: nil
                ))
            }
        }

        // If no specific metrics detected, show score
        if points.isEmpty {
            points.append(.init(
                label: "Health Score",
                value: Double(context.overallScore),
                unit: "pts",
                date: nil
            ))
        }

        return Array(points.prefix(5))
    }

    /// Quick keyword-based metric detection for data point extraction.
    private func detectMentionedMetrics(
        in question: String,
        context: HealthDataQueryEngine.QueryContext
    ) -> [HealthMetric] {
        let keywordMap: [(String, HealthMetric)] = [
            ("hrv", .heartRateVariability),
            ("heart rate variability", .heartRateVariability),
            ("resting heart rate", .restingHeartRate),
            ("rhr", .restingHeartRate),
            ("heart rate", .heartRate),
            ("sleep", .sleepDuration),
            ("deep sleep", .sleepDeep),
            ("rem", .sleepREM),
            ("steps", .steps),
            ("vo2", .vo2Max),
            ("calories", .activeCalories),
            ("exercise", .exerciseMinutes),
            ("weight", .weight),
            ("blood oxygen", .bloodOxygen),
            ("respiratory", .respiratoryRate),
            ("blood pressure", .bloodPressureSystolic),
            ("walking", .walkingSpeed),
            ("mindful", .mindfulMinutes),
        ]

        var found: [HealthMetric] = []
        for (keyword, metric) in keywordMap {
            if question.contains(keyword) && context.timeSeries[metric] != nil {
                if !found.contains(metric) {
                    found.append(metric)
                }
            }
        }
        return found
    }
}

#endif
