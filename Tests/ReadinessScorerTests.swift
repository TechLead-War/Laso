import XCTest
@testable import Laso

final class ReadinessScorerTests: XCTestCase {
    func testAssessReturnsNilWithoutSignals() {
        XCTAssertNil(ReadinessScorer.assess(.init()))
    }

    func testAssessProducesAboveNeutralScoreForStrongFreshSignals() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let input = ReadinessScorer.Input(
            now: now,
            hrv: 78,
            hrvTimestamp: now,
            restingHeartRate: 47,
            restingHeartRateTimestamp: now,
            sleepDuration: 8 * 3600,
            deepSleep: 100 * 60,
            remSleep: 110 * 60,
            hasSleepStageBreakdown: true
        )

        let assessment = ReadinessScorer.assess(input)

        XCTAssertNotNil(assessment)
        XCTAssertGreaterThan(assessment?.score ?? 0, 60)
        XCTAssertGreaterThan(assessment?.confidence ?? 0, 60)
    }

    func testAssessAppliesSmoothingFromPreviousScore() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let input = ReadinessScorer.Input(
            now: now,
            hrv: 82,
            hrvTimestamp: now,
            restingHeartRate: 45,
            restingHeartRateTimestamp: now,
            sleepDuration: 8 * 3600,
            previousSmoothedScore: 40
        )

        let assessment = ReadinessScorer.assess(input)

        XCTAssertNotNil(assessment)
        XCTAssertGreaterThan(assessment?.score ?? 0, 40)
        XCTAssertLessThan(assessment?.score ?? 100, 90)
    }

    func testMakeBaselineRejectsTooFewSamples() {
        XCTAssertNil(ReadinessScorer.makeBaseline(values: [50, 51, 52], minimumSD: 2.0))
    }

    func testStressHelpersShareTheSameThresholds() {
        let level = ReadinessScorer.stressLevel(hrv: 30, restingHeartRate: 78)

        XCTAssertEqual(level, 84)
        XCTAssertEqual(ReadinessScorer.stressLabel(for: level), "Very High")
        XCTAssertEqual(ReadinessScorer.stressColorName(for: level), "red")
    }
}
