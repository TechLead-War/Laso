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

    private init() {}

    // MARK: - Public API

    /// Encrypt and save data to UserDefaults
    func save(_ data: Data, forKey key: String) {
        guard let encryptionKey = getOrCreateKey(),
              let encrypted = encrypt(data, using: encryptionKey) else { return }
        defaults.set(encrypted, forKey: key)
    }

    /// Load and decrypt data from UserDefaults
    func load(forKey key: String) -> Data? {
        guard let encrypted = defaults.data(forKey: key),
              let encryptionKey = getOrCreateKey() else { return nil }
        return decrypt(encrypted, using: encryptionKey)
    }

    /// Remove a key
    func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    /// Migrate a key from plaintext UserDefaults to encrypted storage.
    /// Reads the existing plaintext value, encrypts it, and overwrites.
    func migrateIfNeeded(forKey key: String) {
        guard let plainData = defaults.data(forKey: key) else { return }
        // Check if data is already encrypted (AES-GCM combined has nonce+ciphertext+tag)
        // A simple heuristic: try to decrypt — if it works, it's already encrypted
        if let encryptionKey = getOrCreateKey(),
           let _ = decrypt(plainData, using: encryptionKey) {
            return // Already encrypted
        }
        // Not encrypted yet — encrypt and overwrite
        save(plainData, forKey: key)
    }

    // MARK: - Encryption

    private func encrypt(_ data: Data, using key: SymmetricKey) -> Data? {
        guard let sealedBox = try? AES.GCM.seal(data, using: key) else { return nil }
        return sealedBox.combined
    }

    private func decrypt(_ data: Data, using key: SymmetricKey) -> Data? {
        guard let sealedBox = try? AES.GCM.SealedBox(combined: data),
              let decrypted = try? AES.GCM.open(sealedBox, using: key) else { return nil }
        return decrypted
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
        resolveKey(account: keychainAccount, accessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, synchronizable: false)
    }

    private func loadKeyFromKeychain() -> Data? {
        loadFromKeychain(account: keychainAccount, synchronizable: false)
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
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if synchronizable { query[kSecAttrSynchronizable as String] = true }
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
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
