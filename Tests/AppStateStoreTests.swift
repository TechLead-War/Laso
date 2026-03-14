import XCTest
@testable import Laso

final class AppStateStoreTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppStateStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMarkOnboardingCompletedPersistsValue() {
        let store = AppStateStore(userDefaults: userDefaults, cloudStore: nil)

        store.markOnboardingCompleted()

        XCTAssertTrue(store.onboardingCompleted)
        XCTAssertTrue(userDefaults.bool(forKey: AppKeys.App.onboardingCompleted))
    }

    func testMarkDiscoverySeenPersistsValue() {
        let store = AppStateStore(userDefaults: userDefaults, cloudStore: nil)

        store.markDiscoverySeen()

        XCTAssertTrue(store.hasSeenDiscovery)
        XCTAssertTrue(userDefaults.bool(forKey: AppKeys.App.hasSeenDiscovery))
    }

    func testPendingCalibrationHydrationPersistsValue() {
        let store = AppStateStore(userDefaults: userDefaults, cloudStore: nil)

        store.setPendingCalibrationHydration(true)

        XCTAssertTrue(store.pendingCalibrationHydration)
        XCTAssertTrue(userDefaults.bool(forKey: AppKeys.App.pendingCalibrationHydration))
    }
}
