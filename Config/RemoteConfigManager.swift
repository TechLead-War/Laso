import Foundation
import Observation
import FirebaseRemoteConfig

/// Singleton wrapper around Firebase Remote Config.
/// Fetches remote values and exposes typed accessors.
/// Returns `nil` when a key has no remote or plist value, so callers fall back to hardcoded defaults.
@Observable
final class RemoteConfigManager {
    static let shared = RemoteConfigManager()

    private let remoteConfig = RemoteConfig.remoteConfig()

    /// Whether we've completed at least one fetch+activate cycle
    private(set) var isActivated = false

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600 // 1 hour
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(fromPlist: "RemoteConfigDefaults")
    }

    // MARK: - Fetch

    /// Fetches and activates remote config values.
    /// Safe to call from any context — logs errors but never throws.
    func fetchAndActivate() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            if status == .successFetchedFromRemote || status == .successUsingPreFetchedData {
                isActivated = true
            }
        } catch {
            print("[RemoteConfig] Fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Typed Accessors

    /// Returns the string value for a key, or `nil` if no remote/plist value exists.
    func string(forKey key: String) -> String? {
        let value = remoteConfig.configValue(forKey: key)
        guard value.source != .static else { return nil }
        return value.stringValue
    }

    /// Returns the integer value for a key, or `nil` if no remote/plist value exists.
    func int(forKey key: String) -> Int? {
        let value = remoteConfig.configValue(forKey: key)
        guard value.source != .static else { return nil }
        return value.numberValue.intValue
    }

    /// Returns the double value for a key, or `nil` if no remote/plist value exists.
    func double(forKey key: String) -> Double? {
        let value = remoteConfig.configValue(forKey: key)
        guard value.source != .static else { return nil }
        return value.numberValue.doubleValue
    }

    /// Returns the boolean value for a key, or `nil` if no remote/plist value exists.
    func bool(forKey key: String) -> Bool? {
        let value = remoteConfig.configValue(forKey: key)
        guard value.source != .static else { return nil }
        return value.boolValue
    }
}
