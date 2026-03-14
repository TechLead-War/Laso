import Foundation
import Observation

/// Typed access to lightweight app state persisted in UserDefaults.
/// Keeps onboarding and first-run flags out of views and view models.
@Observable
final class AppStateStore {
    private let userDefaults: UserDefaults
    private let cloudStore: NSUbiquitousKeyValueStore?

    private enum Key {
        static let onboardingCompleted = AppKeys.App.onboardingCompleted
        static let hasSeenDiscovery = AppKeys.App.hasSeenDiscovery
        static let pendingCalibrationHydration = AppKeys.App.pendingCalibrationHydration
    }

    private(set) var onboardingCompleted: Bool
    private(set) var hasSeenDiscovery: Bool
    private(set) var pendingCalibrationHydration: Bool

    init(
        userDefaults: UserDefaults = .standard,
        cloudStore: NSUbiquitousKeyValueStore? = .default
    ) {
        self.userDefaults = userDefaults
        self.cloudStore = cloudStore

        if let localValue = userDefaults.object(forKey: Key.onboardingCompleted) as? Bool {
            onboardingCompleted = localValue
        } else if let cloudValue = cloudStore?.object(forKey: Key.onboardingCompleted) as? Bool {
            onboardingCompleted = cloudValue
            userDefaults.set(cloudValue, forKey: Key.onboardingCompleted)
        } else {
            onboardingCompleted = false
        }

        hasSeenDiscovery = userDefaults.bool(forKey: Key.hasSeenDiscovery)
        pendingCalibrationHydration = userDefaults.bool(forKey: Key.pendingCalibrationHydration)
    }

    func markOnboardingCompleted() {
        setOnboardingCompleted(true)
    }

    func setOnboardingCompleted(_ isCompleted: Bool) {
        onboardingCompleted = isCompleted
        persist(isCompleted, forKey: Key.onboardingCompleted, syncToCloud: true)
    }

    func markDiscoverySeen() {
        setHasSeenDiscovery(true)
    }

    func setHasSeenDiscovery(_ hasSeen: Bool) {
        hasSeenDiscovery = hasSeen
        persist(hasSeen, forKey: Key.hasSeenDiscovery)
    }

    func setPendingCalibrationHydration(_ isPending: Bool) {
        pendingCalibrationHydration = isPending
        persist(isPending, forKey: Key.pendingCalibrationHydration)
    }

    private func persist(_ value: Bool, forKey key: String, syncToCloud: Bool = false) {
        userDefaults.set(value, forKey: key)
        guard syncToCloud else { return }
        cloudStore?.set(value, forKey: key)
    }
}
