import Foundation
import Observation

/// Auto-discovers the live App Store version using Apple's public iTunes Lookup API.
/// No Firebase key, no manual App Store ID. Everything self-resolves from the bundle ID.
/// Endpoint: https://itunes.apple.com/lookup?bundleId=<bundleID>
@Observable
@MainActor
final class AppStoreVersionChecker {

    static let shared = AppStoreVersionChecker()

    private(set) var latestVersion: String?
    private(set) var appStoreID: String?
    private(set) var lastCheckedAt: Date?
    private(set) var isChecking: Bool = false

    private init() {}

    var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    /// True only when the API returned a version strictly higher than the running build.
    /// Stays false while offline, pre-publication, or before the first check completes.
    var isUpdateAvailable: Bool {
        guard let latest = latestVersion, !latest.isEmpty else { return false }
        return Self.isVersion(currentAppVersion, olderThan: latest)
    }

    /// Fetch the App Store metadata. Safe to call repeatedly; silently no-ops on failure.
    /// Throttled to once per week to avoid unnecessary network calls — App Store releases are rare
    /// and a week-stale "Update available" signal is perfectly acceptable.
    func check() async {
        if let last = lastCheckedAt, Date().timeIntervalSince(last) < 604_800 { return }
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let bundleID = AppSecrets.App.bundleID
        guard var components = URLComponents(string: "https://itunes.apple.com/lookup") else { return }
        components.queryItems = [URLQueryItem(name: "bundleId", value: bundleID)]
        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let decoded = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let entry = decoded.results.first else {
                // App not yet published on the App Store. Leave state as-is; row stays hidden.
                lastCheckedAt = Date()
                return
            }
            latestVersion = entry.version
            appStoreID = String(entry.trackId)
            lastCheckedAt = Date()
        } catch {
            // Offline, timeout, or decode failure. Leave previous state; row just won't show.
        }
    }

    /// Opens the App Store product page using the trackId we learned from the API.
    /// Returns false if the checker has not yet resolved an App Store ID (pre-publication or never checked).
    @discardableResult
    func openAppStoreForUpdate(using open: (URL) -> Void) -> Bool {
        guard let id = appStoreID, !id.isEmpty,
              let url = URL(string: "itms-apps://apps.apple.com/app/id\(id)") else {
            return false
        }
        open(url)
        return true
    }

    /// Component-wise numeric compare. Correctly treats "2.10" > "2.9" and handles mixed depth ("2.1" vs "2.1.1").
    private static func isVersion(_ lhs: String, olderThan rhs: String) -> Bool {
        let lhsParts = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let rhsParts = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhsParts.count, rhsParts.count)
        for i in 0..<count {
            let l = i < lhsParts.count ? lhsParts[i] : 0
            let r = i < rhsParts.count ? rhsParts[i] : 0
            if l < r { return true }
            if l > r { return false }
        }
        return false
    }

    private struct LookupResponse: Decodable {
        let results: [Entry]
        struct Entry: Decodable {
            let version: String
            let trackId: Int
        }
    }
}
