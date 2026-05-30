import Foundation
import Observation
import FirebaseCore
import FirebaseFirestore
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Source of truth for live, admin-edited overrides of every `Copy.*` string.
///
/// Resolution order at read time (see `RemoteConfigManager.copyString`):
///   1. `CopyOverridesStore.shared.value(forKey:)`  — if non-nil, wins
///   2. Firebase Remote Config value (if non-empty)
///   3. The English literal baked into the Swift source
///
/// Storage layout in Firestore:
///   document: `copy_overrides/strings`
///     - field: `<rc_key>: String`  → string override
///     - field: `<rc_key>: [String]` → array override (stored natively, JSON
///       fallback used only when the SDK collapses to legacy types)
///
/// Why a single doc instead of one doc per key:
///   * one snapshot listener, one network round trip on launch
///   * Firestore allows up to 1 MiB per doc and ~20 000 fields; today we have
///     ~1500 keys at < 200 bytes each, comfortably under the limit
///   * cheaper writes — operators edit one field at a time but pay for one doc
///
/// The store deliberately tolerates Firebase being absent (unit tests, UI
/// tests, offline launch): every accessor returns nil/empty in that case and
/// downstream resolution falls back to the next layer.
@Observable
final class CopyOverridesStore {

    static let shared = CopyOverridesStore()

    /// Bumped each time the snapshot listener delivers a fresh payload so
    /// SwiftUI views that read through `RemoteConfigManager.copyString` while
    /// observing this object automatically re-render. The actual override
    /// payload lives in `overrides` (kept private to enforce the read path).
    private(set) var lastUpdated: Date?
    private(set) var loadError: String?

    private var overrides: [String: Any] = [:]
    private var listener: ListenerRegistration?
    private var hasFirebase: Bool { FirebaseApp.app() != nil }

    // MARK: - Lifecycle

    private init() {}

    /// Attach a snapshot listener. Safe to call multiple times — duplicate
    /// listeners are torn down before re-attaching so we never multi-fire.
    func start() {
        guard hasFirebase else { return }
        listener?.remove()
        let ref = Firestore.firestore().collection("copy_overrides").document("strings")
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                self.loadError = error.localizedDescription
                return
            }
            self.overrides = snapshot?.data() ?? [:]
            self.loadError = nil
            self.lastUpdated = Date()
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Reads

    /// Returns the override string for `key`, or nil when no override is set.
    /// An empty string counts as "no override" so operators can never blank the
    /// UI accidentally from the dashboard.
    func string(forKey key: String) -> String? {
        _ = lastUpdated // observation dependency
        if let value = overrides[key] as? String, !value.isEmpty {
            return value
        }
        return nil
    }

    /// Returns the override `[String]` for `key`, or nil. Accepts both a native
    /// Firestore array and a JSON-encoded fallback string so manual edits in
    /// the Firebase console work either way.
    func stringArray(forKey key: String) -> [String]? {
        _ = lastUpdated
        if let value = overrides[key] as? [String], !value.isEmpty {
            return value
        }
        if let raw = overrides[key] as? String,
           !raw.isEmpty,
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        return nil
    }

    /// Snapshot of every key currently overridden, sorted alphabetically.
    /// Used by the admin dashboard to show the live set.
    func allOverrides() -> [(key: String, value: String)] {
        _ = lastUpdated
        var out: [(key: String, value: String)] = []
        for (key, raw) in overrides {
            if let s = raw as? String {
                out.append((key, s))
            } else if let arr = raw as? [String] {
                out.append((key, arr.joined(separator: " | ")))
            }
        }
        return out.sorted { $0.key < $1.key }
    }

    // MARK: - Writes (admin only — gated server-side by Firestore rules)

    /// Write a single string override. Resolves on success or surfaces the
    /// Firestore error. Non-admin callers will be rejected server-side by the
    /// security rules even if the client UI is bypassed.
    func setString(_ value: String, forKey key: String) async throws {
        guard hasFirebase else { throw OverrideError.firebaseUnavailable }
        let ref = Firestore.firestore().collection("copy_overrides").document("strings")
        try await ref.setData([key: value], merge: true)
    }

    /// Clear an override so the key falls back to the RC value / baked-in
    /// default. Firestore deletes the field via `FieldValue.delete()`.
    func clearString(forKey key: String) async throws {
        guard hasFirebase else { throw OverrideError.firebaseUnavailable }
        let ref = Firestore.firestore().collection("copy_overrides").document("strings")
        try await ref.updateData([key: FieldValue.delete()])
    }

    enum OverrideError: Error, LocalizedError {
        case firebaseUnavailable

        var errorDescription: String? {
            switch self {
            case .firebaseUnavailable:
                return "Firebase is not configured in this build."
            }
        }
    }
}
