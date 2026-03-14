import Foundation
import HealthKit
import XCTest
@testable import Laso

final class LiveSleepSummaryBuilderTests: XCTestCase {
    func testQueryWindowSpansYesterdayEveningToTodayNoon() {
        let builder = LiveSleepSummaryBuilder()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 14,
            hour: 9,
            minute: 30
        ))!

        let window = builder.queryWindow(containing: now, calendar: calendar)

        XCTAssertEqual(window?.start, calendar.date(from: DateComponents(year: 2026, month: 3, day: 13, hour: 18)))
        XCTAssertEqual(window?.end, calendar.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 12)))
    }

    func testSummarizeSeparatesSleepStagesAndAwakeTime() {
        let builder = LiveSleepSummaryBuilder()
        let type = HKCategoryType(.sleepAnalysis)
        let start = Date(timeIntervalSinceReferenceDate: 0)

        let samples = [
            sample(type: type, value: .asleepDeep, start: start, duration: 60 * 60),
            sample(type: type, value: .asleepREM, start: start.addingTimeInterval(60 * 60), duration: 30 * 60),
            sample(type: type, value: .asleepCore, start: start.addingTimeInterval(90 * 60), duration: 2 * 60 * 60),
            sample(type: type, value: .awake, start: start.addingTimeInterval(210 * 60), duration: 15 * 60),
            sample(type: type, value: .asleepUnspecified, start: start.addingTimeInterval(225 * 60), duration: 45 * 60),
            sample(type: type, value: .inBed, start: start.addingTimeInterval(270 * 60), duration: 20 * 60)
        ]

        let summary = builder.summarize(samples: samples)

        XCTAssertEqual(summary.deepSleep, 60 * 60, accuracy: 0.001)
        XCTAssertEqual(summary.remSleep, 30 * 60, accuracy: 0.001)
        XCTAssertEqual(summary.coreSleep, 2 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(summary.awakeTime, 15 * 60, accuracy: 0.001)
        XCTAssertEqual(summary.totalDuration, 16_500, accuracy: 0.001)
    }

    func testSummarizeReturnsZeroForEmptyInput() {
        let builder = LiveSleepSummaryBuilder()
        let summary = builder.summarize(samples: [])

        XCTAssertEqual(summary, LiveSleepSummary())
    }

    private func sample(
        type: HKCategoryType,
        value: HKCategoryValueSleepAnalysis,
        start: Date,
        duration: TimeInterval
    ) -> HKCategorySample {
        HKCategorySample(
            type: type,
            value: value.rawValue,
            start: start,
            end: start.addingTimeInterval(duration)
        )
    }
}
