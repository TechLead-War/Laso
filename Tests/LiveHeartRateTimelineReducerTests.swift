import XCTest
@testable import Laso

final class LiveHeartRateTimelineReducerTests: XCTestCase {
    func testReduceKeepsLatestValuePerBucket() {
        let reducer = LiveHeartRateTimelineReducer(bucketSize: 10, retentionWindow: 120, maxPoints: 10)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let incoming: [HeartRatePoint] = [
            (date: base, value: 60),
            (date: base.addingTimeInterval(5), value: 62),
            (date: base.addingTimeInterval(10), value: 64)
        ]

        let update = reducer.reduce(
            existing: [],
            incoming: incoming,
            latestSample: incoming[2],
            now: base.addingTimeInterval(15)
        )

        XCTAssertEqual(update.merged.count, 2)
        XCTAssertEqual(update.merged[0].date, base)
        XCTAssertEqual(update.merged[0].value, 62)
        XCTAssertEqual(update.merged[1].date, base.addingTimeInterval(10))
        XCTAssertEqual(update.merged[1].value, 64)
        XCTAssertEqual(update.latestValue, 64)
    }

    func testReduceTrimsOldPointsAndCapsMaximumCount() {
        let reducer = LiveHeartRateTimelineReducer(bucketSize: 10, retentionWindow: 25, maxPoints: 2)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let existing: [HeartRatePoint] = [
            (date: base, value: 60),
            (date: base.addingTimeInterval(10), value: 61),
            (date: base.addingTimeInterval(20), value: 62)
        ]
        let incoming: [HeartRatePoint] = [
            (date: base.addingTimeInterval(30), value: 63),
            (date: base.addingTimeInterval(40), value: 64)
        ]

        let update = reducer.reduce(
            existing: existing,
            incoming: incoming,
            latestSample: incoming[1],
            now: base.addingTimeInterval(40)
        )

        XCTAssertEqual(update.merged.count, 2)
        XCTAssertEqual(update.merged[0].date, base.addingTimeInterval(30))
        XCTAssertEqual(update.merged[1].date, base.addingTimeInterval(40))
    }

    func testSessionStatsReturnsExpectedValues() {
        let reducer = LiveHeartRateTimelineReducer()
        let points: [HeartRatePoint] = [
            (date: .distantPast, value: 58),
            (date: .distantPast.addingTimeInterval(10), value: 74),
            (date: .distantPast.addingTimeInterval(20), value: 68)
        ]

        let stats = reducer.sessionStats(for: points)

        XCTAssertEqual(stats.minimum, 58)
        XCTAssertEqual(stats.maximum, 74)
        XCTAssertEqual(stats.average, 200.0 / 3.0)
    }
}
