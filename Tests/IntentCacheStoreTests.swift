import XCTest
@testable import Laso

final class IntentCacheStoreTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "IntentCacheStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveAndLoadHealthSummaryRoundTripsValues() {
        let store = IntentCacheStore(userDefaults: userDefaults)
        store.saveHealthSummary(score: 82, grade: "A", summary: "Areas to watch: Sleep 71.")

        let snapshot = store.loadHealthSummary()

        XCTAssertEqual(snapshot, IntentCacheSnapshot(score: 82, grade: "A", summary: "Areas to watch: Sleep 71."))
    }

    func testLoadHealthSummaryReturnsNilWithoutScore() {
        let store = IntentCacheStore(userDefaults: userDefaults)

        XCTAssertNil(store.loadHealthSummary())
    }

    func testLoadTrendsSummaryIgnoresEmptyString() {
        let store = IntentCacheStore(userDefaults: userDefaults)
        userDefaults.set("", forKey: AppKeys.Intent.summary)

        XCTAssertNil(store.loadTrendsSummary())
    }
}
