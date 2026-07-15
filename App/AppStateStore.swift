import Foundation
import Observation
#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseCore
#endif

/// Typed access to lightweight app state persisted in UserDefaults.
/// Keeps onboarding and first-run flags out of views and view models.
///
/// iCloud Key-Value sync is gated on the Firebase user being non-anonymous
/// (i.e. they have signed in with Apple). Anonymous device sessions stay
/// purely local so a fresh install of an unsigned-in app can never inherit
/// onboarding state from a different account on the same device's iCloud.
@Observable
final class AppStateStore {
    private let userDefaults: UserDefaults
    private let cloudStore: NSUbiquitousKeyValueStore?

    private enum Key {
        static let onboardingCompleted = AppKeys.App.onboardingCompleted
        static let hasSeenDiscovery = AppKeys.App.hasSeenDiscovery
        static let pendingCalibrationHydration = AppKeys.App.pendingCalibrationHydration
        static let hasSeenScoreGuide = AppKeys.App.hasSeenScoreGuide
        static let cycleTrackingEnabled = AppKeys.Cycle.trackingEnabled
        static let disclaimerAcknowledged = AppKeys.App.disclaimerAcknowledged
        static let paywallDeclined = AppKeys.App.paywallDeclined
    }

    private(set) var onboardingCompleted: Bool
    private(set) var hasSeenDiscovery: Bool
    private(set) var pendingCalibrationHydration: Bool
    private(set) var hasSeenScoreGuide: Bool
    private(set) var cycleTrackingEnabled: Bool
    private(set) var disclaimerAcknowledged: Bool
    private(set) var paywallDeclined: Bool

    init(
        userDefaults: UserDefaults = .standard,
        cloudStore: NSUbiquitousKeyValueStore? = .default
    ) {
        self.userDefaults = userDefaults
        self.cloudStore = cloudStore

        if let localValue = userDefaults.object(forKey: Key.onboardingCompleted) as? Bool {
            onboardingCompleted = localValue
        } else if Self.isAuthenticatedUser,
                  let cloudValue = cloudStore?.object(forKey: Key.onboardingCompleted) as? Bool {
            onboardingCompleted = cloudValue
            userDefaults.set(cloudValue, forKey: Key.onboardingCompleted)
        } else {
            onboardingCompleted = false
        }

        hasSeenDiscovery = userDefaults.bool(forKey: Key.hasSeenDiscovery)
        pendingCalibrationHydration = userDefaults.bool(forKey: Key.pendingCalibrationHydration)
        hasSeenScoreGuide = userDefaults.bool(forKey: Key.hasSeenScoreGuide)
        cycleTrackingEnabled = userDefaults.bool(forKey: Key.cycleTrackingEnabled)
        disclaimerAcknowledged = userDefaults.bool(forKey: Key.disclaimerAcknowledged)
        paywallDeclined = userDefaults.bool(forKey: Key.paywallDeclined)
    }

    private static var isAuthenticatedUser: Bool {
        #if canImport(FirebaseAuth)
        guard FirebaseApp.app() != nil,
              let user = Auth.auth().currentUser else { return false }
        return !user.isAnonymous
        #else
        return false
        #endif
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

    func markScoreGuideSeen() {
        hasSeenScoreGuide = true
        persist(true, forKey: Key.hasSeenScoreGuide)
    }

    func setCycleTrackingEnabled(_ enabled: Bool) {
        cycleTrackingEnabled = enabled
        persist(enabled, forKey: Key.cycleTrackingEnabled)
    }

    func markDisclaimerAcknowledged() {
        disclaimerAcknowledged = true
        persist(true, forKey: Key.disclaimerAcknowledged)
    }

    /// Declining is a device decision, so it stays out of iCloud sync.
    func markPaywallDeclined() {
        paywallDeclined = true
        persist(true, forKey: Key.paywallDeclined)
    }

    private func persist(_ value: Bool, forKey key: String, syncToCloud: Bool = false) {
        userDefaults.set(value, forKey: key)
        guard syncToCloud, Self.isAuthenticatedUser else { return }
        cloudStore?.set(value, forKey: key)
    }
}
