import Foundation
import XCTest
@testable import Laso

final class DashboardDerivedStateBuilderTests: XCTestCase {
    func testScoreChangeFromLastWeekUsesLatestEntryBeforeWeekBoundary() {
        let builder = DashboardDerivedStateBuilder()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 12))!

        let history: [DashboardDerivedStateBuilder.ScoreHistoryEntry] = [
            (calendar.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 9))!, 68),
            (calendar.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 18))!, 71),
            (calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 8))!, 75),
            (calendar.date(from: DateComponents(year: 2026, month: 3, day: 13, hour: 20))!, 82)
        ]

        let delta = builder.scoreChangeFromLastWeek(
            currentScore: 82,
            history: history,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(delta, 11)
    }

    func testScoreChangeFromYesterdayUsesOnlyYesterdayWindow() {
        let builder = DashboardDerivedStateBuilder()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 10))!

        let history: [DashboardDerivedStateBuilder.ScoreHistoryEntry] = [
            (calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 22))!, 70),
            (calendar.date(from: DateComponents(year: 2026, month: 3, day: 13, hour: 8))!, 72),
            (calendar.date(from: DateComponents(year: 2026, month: 3, day: 13, hour: 19))!, 74),
            (calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 8))!, 79)
        ]

        let delta = builder.scoreChangeFromYesterday(
            currentScore: 79,
            history: history,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(delta, 5)
    }

    func testTrendsSummaryCountsDirectionsAndPrioritizesFocusedMovers() {
        let builder = DashboardDerivedStateBuilder()

        let summary = builder.trendsSummary(
            trends: [
                .init(metric: .steps, direction: .improving, weekOverWeekChange: 10),
                .init(metric: .sleepDuration, direction: .improving, weekOverWeekChange: 5),
                .init(metric: .restingHeartRate, direction: .declining, weekOverWeekChange: -8),
                .init(metric: .sleepREM, direction: .stable, weekOverWeekChange: 1)
            ],
            focusCategories: [.sleep]
        )

        XCTAssertEqual(summary.improving, 2)
        XCTAssertEqual(summary.stable, 1)
        XCTAssertEqual(summary.declining, 1)
        XCTAssertEqual(summary.topMovers.map(\.metric), [.sleepDuration, .steps, .restingHeartRate])
    }

    func testTopCorrelationsPrioritizeFocusRelevantPairsBeforeAbsoluteStrength() {
        let builder = DashboardDerivedStateBuilder()

        let correlations = [
            makeCorrelation(metricA: .steps, metricB: .activeCalories, correlation: 0.92),
            makeCorrelation(metricA: .sleepDuration, metricB: .heartRateVariability, correlation: 0.55),
            makeCorrelation(metricA: .sleepREM, metricB: .restingHeartRate, correlation: -0.40)
        ]

        let ranked = builder.topCorrelations(from: correlations, focusCategories: [.sleep])

        XCTAssertEqual(ranked.map(\.metricA), [.sleepDuration, .sleepREM, .steps])
    }

    private func makeCorrelation(
        metricA: HealthMetric,
        metricB: HealthMetric,
        correlation: Double
    ) -> HealthCorrelation {
        HealthCorrelation(
            metricA: metricA,
            metricB: metricB,
            correlation: correlation,
            sampleCount: 20,
            strengthLabel: "Strong",
            causeLabel: metricA.displayName,
            effectLabel: metricB.displayName,
            effectSummary: "Test summary",
            isPositive: correlation >= 0,
            dayOffset: 0
        )
    }
}
