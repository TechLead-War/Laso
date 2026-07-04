import Foundation
import CryptoKit
import Security

/// Encrypts and decrypts Data using AES-GCM with a Keychain-stored key.
/// All sensitive health data should be stored/loaded through this class.
final class EncryptedStore {
    static let shared = EncryptedStore()

    private let keychainAccount = AppSecrets.Keychain.encryptionKeyAccount
    private let syncKeychainAccount = AppSecrets.Keychain.syncKeyAccount
    private let defaults = UserDefaults.standard

    /// Both flags live in UserDefaults so they ride device backups alongside the
    /// ciphertext blobs, while the local key is ThisDeviceOnly in the Keychain.
    /// After a restore/transfer the flag arrives without the key — that mismatch
    /// is how key loss is detected so orphaned blobs can be purged in one pass
    /// instead of failing on every read forever.
    private let keyProvisionedFlag = "laso.encryptedStore.keyProvisioned"
    private let managedKeysKey = "laso.encryptedStore.managedKeys"

    /// Serializes key resolution and registry writes: save/load run concurrently
    /// (MainActor paths plus detached analysis saves), and an unserialized
    /// restore-day mint could double-purge or mint two competing keys.
    private let keyLock = NSLock()

    private init() {}

    // MARK: - Public API

    /// Encrypt and save data to UserDefaults
    func save(_ data: Data, forKey key: String) {
        guard let encryptionKey = getOrCreateKey(),
              let encrypted = encrypt(data, using: encryptionKey) else { return }
        defaults.set(encrypted, forKey: key)
        trackManagedKey(key)
    }

    /// Load and decrypt data from UserDefaults
    func load(forKey key: String) -> Data? {
        guard let encrypted = defaults.data(forKey: key),
              let encryptionKey = getOrCreateKey() else { return nil }
        guard let plain = decrypt(encrypted, using: encryptionKey) else {
            // AES-GCM failures are permanent (wrong key after a restore, or a
            // corrupt blob): keeping the blob means every future read fails
            // again. Drop it so each bad blob errors once, then reads as missing.
            defaults.removeObject(forKey: key)
            return nil
        }
        return plain
    }

    /// Remove a key
    func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    /// Migrate a key from plaintext UserDefaults to encrypted storage.
    /// Reads the existing plaintext value, encrypts it, and overwrites.
    func migrateIfNeeded(forKey key: String) {
        // Resolve the key BEFORE reading the value: on a restored device this
        // purges orphaned ciphertext first, which would otherwise fail the
        // decrypt probe below, be mistaken for plaintext, and get re-encrypted
        // under the new key — silently destroying the value.
        guard let encryptionKey = getOrCreateKey() else { return }
        guard let plainData = defaults.data(forKey: key) else { return }
        // A value that decrypts is already encrypted; the probe is expected to
        // fail on plaintext, so it must not report decryption_open_failed.
        if decrypt(plainData, using: encryptionKey, reportFailure: false) != nil {
            return
        }
        save(plainData, forKey: key)
    }

    // MARK: - Encryption

    private func encrypt(_ data: Data, using key: SymmetricKey) -> Data? {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            AnalyticsBackend.provider.captureError(error, context: "encryption_seal_failed")
            return nil
        }
    }

    private func decrypt(_ data: Data, using key: SymmetricKey, reportFailure: Bool = true) -> Data? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            if reportFailure {
                AnalyticsBackend.provider.captureError(error, context: "decryption_open_failed")
            }
            return nil
        }
    }

    // MARK: - iCloud Sync Key (for E2E encrypted CloudKit backup)

    /// Whether a sync key exists in the Keychain (may still be syncing via iCloud Keychain)
    var hasSyncKey: Bool {
        loadSyncKeyFromKeychain() != nil
    }

    func getOrCreateSyncKey() -> SymmetricKey? {
        resolveKey(account: syncKeychainAccount, accessible: kSecAttrAccessibleAfterFirstUnlock, synchronizable: true)
    }

    /// Encrypt data using the iCloud-synced key (for CloudKit backup payloads)
    func encryptForCloud(_ data: Data) -> Data? {
        guard let key = getOrCreateSyncKey() else { return nil }
        return encrypt(data, using: key)
    }

    /// Decrypt data using the iCloud-synced key (for CloudKit backup payloads)
    func decryptFromCloud(_ data: Data) -> Data? {
        guard let keyData = loadSyncKeyFromKeychain() else { return nil }
        let key = SymmetricKey(data: keyData)
        return decrypt(data, using: key)
    }

    // MARK: - Keychain Key Management

    private func getOrCreateKey() -> SymmetricKey? {
        keyLock.lock()
        defer { keyLock.unlock() }

        var status: OSStatus = errSecSuccess
        if let data = loadFromKeychain(account: keychainAccount, synchronizable: false, status: &status) {
            if !defaults.bool(forKey: keyProvisionedFlag) {
                defaults.set(true, forKey: keyProvisionedFlag)
            }
            return SymmetricKey(data: data)
        }
        // Transient unavailability (e.g. keychain still sealed before the first
        // unlock after reboot) is not key loss: never mint or purge on it.
        guard status == errSecItemNotFound else { return nil }
        if defaults.bool(forKey: keyProvisionedFlag) {
            // Clear the flag before purging so a failed mint below cannot
            // re-trigger the purge (and its analytics event) on every call.
            defaults.set(false, forKey: keyProvisionedFlag)
            purgeOrphanedBlobs()
        }
        guard let key = resolveKey(account: keychainAccount, accessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, synchronizable: false) else { return nil }
        defaults.set(true, forKey: keyProvisionedFlag)
        return key
    }

    /// A provisioned flag without a Keychain key means a restore/transfer lost
    /// the ThisDeviceOnly key: every blob written on the old device is
    /// permanently unreadable. Remove them all and report ONE event instead of
    /// letting each read fail with decryption_open_failed forever.
    private func purgeOrphanedBlobs() {
        let keys = defaults.stringArray(forKey: managedKeysKey) ?? []
        for key in keys { defaults.removeObject(forKey: key) }
        defaults.removeObject(forKey: managedKeysKey)
        AnalyticsBackend.provider.captureError(
            "Encryption key lost in device restore or transfer, purged unreadable blobs",
            context: "encryption_key_lost_after_restore",
            metadata: ["purged_count": keys.count]
        )
    }

    private func trackManagedKey(_ key: String) {
        keyLock.lock()
        defer { keyLock.unlock() }
        var keys = defaults.stringArray(forKey: managedKeysKey) ?? []
        guard !keys.contains(key) else { return }
        keys.append(key)
        defaults.set(keys, forKey: managedKeysKey)
    }

    private func loadSyncKeyFromKeychain() -> Data? {
        loadFromKeychain(account: syncKeychainAccount, synchronizable: true)
    }

    private func resolveKey(account: String, accessible: CFString, synchronizable: Bool) -> SymmetricKey? {
        if let data = loadFromKeychain(account: account, synchronizable: synchronizable) {
            return SymmetricKey(data: data)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        return upsertKeychain(account: account, data: keyData, accessible: accessible, synchronizable: synchronizable) ? newKey : nil
    }

    private func loadFromKeychain(account: String, synchronizable: Bool) -> Data? {
        var status: OSStatus = errSecSuccess
        return loadFromKeychain(account: account, synchronizable: synchronizable, status: &status)
    }

    private func loadFromKeychain(account: String, synchronizable: Bool, status: inout OSStatus) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if synchronizable { query[kSecAttrSynchronizable as String] = true }
        var result: AnyObject?
        status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func upsertKeychain(account: String, data: Data, accessible: CFString, synchronizable: Bool) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible
        ]
        if synchronizable { query[kSecAttrSynchronizable as String] = true }

        var status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            var searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account
            ]
            if synchronizable { searchQuery[kSecAttrSynchronizable as String] = true }
            status = SecItemUpdate(searchQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
        return status == errSecSuccess
    }
}
