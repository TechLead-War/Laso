import Foundation

// MARK: - Protocol Abstraction

/// Unified interface for health data query engines.
/// The existing `HealthDataQueryEngine` (rule-based) and the new `FoundationModelQueryEngine`
/// (on-device LLM, iOS 26+) both conform to this protocol, enabling runtime routing.
protocol HealthQueryEngine: Sendable {
    func query(
        question: String,
        context: HealthDataQueryEngine.QueryContext
    ) async throws -> HealthDataQueryEngine.QueryResult
}

// MARK: - Legacy Engine Conformance

/// Wraps the existing synchronous `HealthDataQueryEngine` in the async protocol.
/// The original class is NOT modified — this extension adds conformance externally.
extension HealthDataQueryEngine: @unchecked Sendable {}

extension HealthDataQueryEngine: HealthQueryEngine {
    func query(
        question: String,
        context: QueryContext
    ) async throws -> QueryResult {
        let matchingMode: MatchingMode = ThermalManager.shared.shouldThrottle ? .keywordOnly : .full
        return query(question: question, context: context, matchingMode: matchingMode)
    }
}
