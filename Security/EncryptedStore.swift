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

    /// Get or create the iCloud-synced AES-256 key for CloudKit encryption.
    /// Stored with kSecAttrSynchronizable so iCloud Keychain replicates it across devices.
    func getOrCreateSyncKey() -> SymmetricKey? {
        if let existingKeyData = loadSyncKeyFromKeychain() {
            return SymmetricKey(data: existingKeyData)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        if saveSyncKeyToKeychain(keyData) {
            return newKey
        }
        return nil
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

    private func loadSyncKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: syncKeychainAccount,
            kSecAttrSynchronizable as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func saveSyncKeyToKeychain(_ keyData: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: syncKeychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true
        ]
        var status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: syncKeychainAccount,
                kSecAttrSynchronizable as String: true
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: keyData
            ]
            status = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
        }

        return status == errSecSuccess
    }

    // MARK: - Keychain Key Management (device-local)

    private func getOrCreateKey() -> SymmetricKey? {
        if let existingKeyData = loadKeyFromKeychain() {
            return SymmetricKey(data: existingKeyData)
        }
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        if saveKeyToKeychain(keyData) {
            return newKey
        }
        return nil
    }

    private func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func saveKeyToKeychain(_ keyData: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemAdd(query as CFDictionary, nil)

        // Handle duplicate: update the existing key instead
        if status == errSecDuplicateItem {
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: keychainAccount
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: keyData
            ]
            status = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)
        }

        return status == errSecSuccess
    }
}
