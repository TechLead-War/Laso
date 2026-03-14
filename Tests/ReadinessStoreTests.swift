import XCTest
@testable import Laso

final class ReadinessStoreTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ReadinessStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveAndLoadCachedSnapshotRoundTripsValues() {
        let store = ReadinessStore(userDefaults: userDefaults)
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        store.saveCachedScore(82, at: timestamp)

        XCTAssertEqual(
            store.loadCachedSnapshot(),
            ReadinessCacheSnapshot(score: 82, timestamp: timestamp)
        )
    }

    func testClearRemovesCachedScore() {
        let store = ReadinessStore(userDefaults: userDefaults)
        store.saveCachedScore(74)

        store.clear()

        XCTAssertNil(store.loadCachedSnapshot())
        XCTAssertNil(store.loadCachedScore())
    }
}
