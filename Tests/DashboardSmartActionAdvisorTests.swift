import XCTest
@testable import Laso

final class DashboardSmartActionAdvisorTests: XCTestCase {
    private let advisor = DashboardSmartActionAdvisor()

    func testHighStressOverridesOtherRecommendations() {
        let recommendation = advisor.recommend(
            live: .init(
                hour: 10,
                stressLevel: 72,
                readinessScore: 85,
                hasSleepData: true,
                sleepHours: 8,
                deepSleepMinutes: 90,
                exerciseMinutes: 0,
                exerciseGoal: 30,
                latestRestingHeartRate: 50
            ),
            analysis: .init(
                policyDecision: nil,
                restingHeartRateBaselineMean: 52,
                userFocuses: [.fitness]
            )
        )

        XCTAssertEqual(
            recommendation,
            .init(
                icon: "wind",
                title: "Take 5 min to breathe",
                subtitle: "Stress is elevated — box breathing (4-4-4-4) can lower it fast"
            )
        )
    }

    func testSleepFocusUsesDeepSleepRecommendation() {
        let recommendation = advisor.recommend(
            live: .init(
                hour: 9,
                stressLevel: 30,
                readinessScore: 55,
                hasSleepData: true,
                sleepHours: 7.4,
                deepSleepMinutes: 30,
                exerciseMinutes: 10,
                exerciseGoal: 30,
                latestRestingHeartRate: 54
            ),
            analysis: .init(
                policyDecision: nil,
                restingHeartRateBaselineMean: 52,
                userFocuses: [.sleep]
            )
        )

        XCTAssertEqual(
            recommendation,
            .init(
                icon: "moon.zzz.fill",
                title: "Boost your deep sleep",
                subtitle: "Only 30 min of deep sleep — try cutting caffeine after 2 PM"
            )
        )
    }

    func testRecoveryFocusUsesRecoverySpecificGuidance() {
        let recommendation = advisor.recommend(
            live: .init(
                hour: 11,
                stressLevel: 20,
                readinessScore: 55,
                hasSleepData: true,
                sleepHours: 7.8,
                deepSleepMinutes: 80,
                exerciseMinutes: 10,
                exerciseGoal: 30,
                latestRestingHeartRate: 53
            ),
            analysis: .init(
                policyDecision: nil,
                restingHeartRateBaselineMean: 52,
                userFocuses: [.recovery]
            )
        )

        XCTAssertEqual(
            recommendation,
            .init(
                icon: "figure.mind.and.body",
                title: "Focus on recovery today",
                subtitle: "Readiness is 55% — light stretching and hydration will help"
            )
        )
    }

    func testExerciseGoalReachedWinsWhenNoHigherPrioritySignalExists() {
        let recommendation = advisor.recommend(
            live: .init(
                hour: 14,
                stressLevel: 25,
                readinessScore: 50,
                hasSleepData: false,
                sleepHours: 0,
                deepSleepMinutes: 0,
                exerciseMinutes: 35,
                exerciseGoal: 30,
                latestRestingHeartRate: nil
            ),
            analysis: .init(
                policyDecision: nil,
                restingHeartRateBaselineMean: nil,
                userFocuses: []
            )
        )

        XCTAssertEqual(
            recommendation,
            .init(
                icon: "checkmark.seal.fill",
                title: "Exercise goal reached!",
                subtitle: "35 min today — stay active and hydrate"
            )
        )
    }
}
