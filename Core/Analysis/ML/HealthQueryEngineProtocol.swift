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
    /// Intent matching does not change with device temperature. Dropping
    /// semantic matching while throttled meant the same question was answered
    /// one way on a cool phone and another way on a warm one, with nothing about
    /// the question having changed. The semantic pass is a handful of cached
    /// sentence-embedding distances and is not what heats the device.
    func query(
        question: String,
        context: QueryContext
    ) async throws -> QueryResult {
        answer(question: question, context: context)
    }
}
