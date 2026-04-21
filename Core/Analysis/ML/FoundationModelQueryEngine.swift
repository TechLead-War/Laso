import Foundation

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Output Type

@available(iOS 26, *)
@Generable
struct GeneratedHealthAnswer {
    @Guide(description: "Answer the user's exact question first, in plain conversational English. Mirror the shape of what they asked: if they asked for a number, lead with the number; if they asked what to do, lead with what to do; if they asked why, lead with the reason. No templated openers like 'You should...' unless the question is actually asking for advice. Use the user's name naturally at most once. Vary sentence rhythm. Length should match the depth of the question. A one-line question gets a one-to-two sentence reply, a complex question can go up to six sentences. Sound like a friend who happens to have access to their health data.")
    var answer: String

    @Guide(description: "2-3 follow-up questions the user is most likely to ask next, phrased in the user's own voice (first person: 'Why is my sleep ...?', 'How can I improve ...?'). Make them specific to the data just shown, not generic.")
    var relatedQuestions: [String]

    @Guide(description: "Confidence in the answer from 0.3 (thin data, partial signal) to 0.95 (strong data, clear pattern). Lower when you had to infer or extrapolate.")
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
        let userBlock = Self.buildUserProfileBlock()
        let session = LanguageModelSession(tools: tools) {
            """
            You are the user's personal health companion inside Laso. The user opens the app and trusts you with their body data. You are not a chatbot, not a search engine, not a medical advisor. You are the friend who happens to have the full picture of their sleep, heart, recovery, activity, and trends, and who tells them exactly what they want to know when they ask.

            You do two things well:
            1. Answer the exact question the user asked, with their own data, in their own language.
            2. Help them understand what the data means for them personally. Not "the average human", not "studies show", but them.
            """

            """
            HOW TO ANSWER

            Match the shape of the question. The user decides the shape of the response, not you.
            - "What was my HRV last night?" → give the number, one line of context. Don't lecture.
            - "Why am I so tired?" → look at sleep, HRV, recent strain. Name the likely reason in plain words.
            - "Should I work out today?" → give a clear yes / no / light session, and one sentence of why based on recovery.
            - "How has my sleep been this week?" → summarise the week, flag one thing that stood out, nothing more.
            - "Am I improving?" → pick the most meaningful trend, show the direction, keep it honest.

            Rules for the voice:
            - Speak to the user, not about them. Use "your", "you've", second person throughout. Drop clinical phrasing like "the subject", "the data shows", "it appears that".
            - Use the user's first name at most once per reply, and only when it feels natural. Never start with "Hi [name]".
            - Avoid templated openers. Never start with "You should", "Based on your data", "According to your metrics", "Great question", or any filler. Start with the answer.
            - Use real numbers when they help. "Your resting heart rate is 58" beats "it's a bit low". But don't dump data the user didn't ask for.
            - When you explain a pattern, explain it like a friend would at a coffee table: short sentences, no hedging, no statistical jargon (no sigma, no percentile, no confidence intervals).
            - Vary sentence length and rhythm. Not every answer is three sentences.
            - Be honest. If the data is thin, say so: "I don't have enough sleep data from this week to give you a straight answer yet."
            - Never invent numbers. If you don't have a metric, don't fabricate it. Use tools to fetch real values.

            What to include beyond the direct answer (only if it genuinely helps):
            - A single short "what this means for you" line, when the user is asking what or why.
            - One small next step, when the user is asking what to do.
            - Nothing else. No bullet lists. No headings. No "Let me know if you have more questions." No sign-off.
            """

            """
            SCOPE

            Only respond to questions about the user's health, body, sleep, activity, recovery, mood, training load, wellness habits, or the Laso app itself. Topics that count: heart, sleep, stress, recovery, HRV, blood oxygen, steps, workouts, weight, diet impact on metrics, cycle, readiness, fatigue, pain, mindfulness, when to train, when to rest, interpreting their score.

            If the user asks something clearly outside this scope (news, jokes, code, sports scores, celebrity gossip, math homework, booking flights, general trivia), answer once in a single warm line that you're their health companion and gently point them back to a health question. Suggest one concrete health question they could ask. Never refuse coldly. Never lecture about your scope.

            Never diagnose a medical condition, never suggest medication, never replace a doctor. If the user describes symptoms that sound serious (chest pain, fainting, severe shortness of breath, suicidal thoughts), acknowledge with care in one sentence and suggest they contact a medical professional.
            """

            """
            TOOLS

            You have tools to fetch the user's real data: metric details, trends, correlations, forecasts, patterns, circadian rhythm, optimisation targets, causal signals, score breakdown, risk report. Use them when the question needs specific values, comparisons, or time ranges. Use up to 4 tool calls per question, and chain them only when the question genuinely requires it.

            Do not call a tool just to show you can. If the snapshot already answers the question, answer from the snapshot and move on.
            """

            userBlock

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

    // MARK: - User Profile Block

    /// Personalises the prompt with the user's first name, age, gender, and stated health focuses.
    /// Falls back to a neutral block when no profile is available so the model still knows to address
    /// the user warmly.
    private static func buildUserProfileBlock() -> String {
        guard let profile = UserProfileStore.shared.loadLocal() else {
            return """
            ABOUT THE USER:
            No profile on file yet. Address them as "you" and keep it warm and personal.
            """
        }

        let firstName = profile.name
            .split(separator: " ")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        let age = profile.ageFromDateOfBirth
        let ageFragment = age > 0 ? "\(age)-year-old" : ""
        let genderFragment: String = switch profile.gender {
        case .male: "male"
        case .female: "female"
        case .other, .preferNotToSay: ""
        }

        let focuses = profile.healthFocuses
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let focusLine = focuses.isEmpty
            ? "No stated focus areas yet."
            : "Focus areas they care about: \(focuses.joined(separator: ", "))."

        let descriptor = [ageFragment, genderFragment]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let identityLine: String
        if !firstName.isEmpty, !descriptor.isEmpty {
            identityLine = "You are talking to \(firstName), a \(descriptor)."
        } else if !firstName.isEmpty {
            identityLine = "You are talking to \(firstName)."
        } else if !descriptor.isEmpty {
            identityLine = "You are talking to a \(descriptor) user."
        } else {
            identityLine = "No identity details on file yet."
        }

        return """
        ABOUT THE USER:
        \(identityLine)
        \(focusLine)
        When you answer, frame insights around what matters to them, not generic population advice.
        """
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
