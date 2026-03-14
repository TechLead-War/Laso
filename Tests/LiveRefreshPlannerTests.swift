import XCTest
@testable import Laso

final class LiveRefreshPlannerTests: XCTestCase {
    func testTieredRefreshFetchesAllTiersWhenNoHistoryExists() {
        let planner = LiveRefreshPlanner(mediumInterval: 300, slowInterval: 600)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let decision = planner.decisionForTieredRefresh(now: now, state: .init())

        XCTAssertEqual(
            decision,
            .init(shouldFetchFast: true, shouldFetchMedium: true, shouldFetchSlow: true)
        )
    }

    func testTieredRefreshSkipsMediumAndSlowWhenRecentlyFetched() {
        let planner = LiveRefreshPlanner(mediumInterval: 300, slowInterval: 600)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let state = LiveRefreshPlanner.State(
            lastMediumFetch: now.addingTimeInterval(-60),
            lastSlowFetch: now.addingTimeInterval(-120)
        )

        let decision = planner.decisionForTieredRefresh(now: now, state: state)

        XCTAssertEqual(
            decision,
            .init(shouldFetchFast: true, shouldFetchMedium: false, shouldFetchSlow: false)
        )
    }

    func testDeferredStreamingRefreshNeverRequestsFastTier() {
        let planner = LiveRefreshPlanner(mediumInterval: 300, slowInterval: 600)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let decision = planner.decisionForDeferredStreamingRefresh(now: now, state: .init())

        XCTAssertEqual(
            decision,
            .init(shouldFetchFast: false, shouldFetchMedium: true, shouldFetchSlow: true)
        )
    }

    func testApplyAndMarkFullRefreshUpdateStoredTimestamps() {
        let planner = LiveRefreshPlanner(mediumInterval: 300, slowInterval: 600)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = LiveRefreshPlanner.State()

        planner.apply(
            .init(shouldFetchFast: true, shouldFetchMedium: true, shouldFetchSlow: false),
            at: now,
            state: &state
        )

        XCTAssertEqual(state.lastMediumFetch, now)
        XCTAssertNil(state.lastSlowFetch)

        planner.markFullRefresh(at: now.addingTimeInterval(10), state: &state)

        XCTAssertEqual(state.lastMediumFetch, now.addingTimeInterval(10))
        XCTAssertEqual(state.lastSlowFetch, now.addingTimeInterval(10))
    }
}
