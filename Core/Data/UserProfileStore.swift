import Foundation
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - Gender

enum Gender: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case male
    case female
    case other
    case preferNotToSay

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

// MARK: - User Profile

struct UserProfile: Codable {
    var name: String
    var email: String
    var gender: Gender
    var dateOfBirth: Date
    var healthFocuses: [String]
    var deviceId: String
    var createdAt: Date
    var updatedAt: Date
    var appVersion: String
    var region: String

    /// Age in years derived from dateOfBirth
    var ageFromDateOfBirth: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    /// Age bracket for demographics grouping
    var ageBracket: String {
        let age = ageFromDateOfBirth
        switch age {
        case ..<18:  return "Under 18"
        case 18...24: return "18-24"
        case 25...34: return "25-34"
        case 35...44: return "35-44"
        case 45...54: return "45-54"
        case 55...64: return "55-64"
        default:      return "65+"
        }
    }
}

// MARK: - User Profile Store

final class UserProfileStore {

    static let shared = UserProfileStore()

    private let defaults = UserDefaults.standard
    private let encryptedStore = EncryptedStore.shared
    private let localKey = "healthpulse.userProfile"
    private let collectionName = "user_profiles"

    private init() {}

    // MARK: - Device & Environment

    private var currentDeviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    private var currentRegion: String {
        Locale.current.region?.identifier ?? "unknown"
    }

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // MARK: - Local Persistence

    /// Save profile to encrypted local cache
    func saveLocal(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        encryptedStore.save(data, forKey: localKey)
        persistProfileFields(profile)
    }

    /// Persist individual profile fields for quick access across the app.
    /// Sensitive PII (name, email, dateOfBirth) is encrypted via EncryptedStore.
    /// Non-sensitive flags (gender, profileCompleted, deviceId) remain in plain UserDefaults.
    func persistProfileFields(_ profile: UserProfile) {
        if !profile.name.isEmpty,
           let nameData = profile.name.data(using: .utf8) {
            encryptedStore.save(nameData, forKey: AppKeys.Profile.name)
        }
        if !profile.email.isEmpty,
           let emailData = profile.email.data(using: .utf8) {
            encryptedStore.save(emailData, forKey: AppKeys.Profile.email)
        }
        let dobInterval = profile.dateOfBirth.timeIntervalSince1970
        var dobValue = dobInterval
        let dobData = Swift.withUnsafeBytes(of: &dobValue) { Data($0) }
        encryptedStore.save(dobData, forKey: AppKeys.Profile.dateOfBirth)
        defaults.set(profile.gender.rawValue, forKey: AppKeys.Profile.gender)
        defaults.set(true, forKey: AppKeys.Profile.profileCompleted)
        defaults.set(profile.deviceId, forKey: AppKeys.Profile.deviceId)
    }

    /// Persist a device ID for quick access
    func persistDeviceId(_ deviceId: String) {
        defaults.set(deviceId, forKey: AppKeys.Profile.deviceId)
    }

    /// Load cached profile from encrypted local store
    func loadLocal() -> UserProfile? {
        guard let data = encryptedStore.load(forKey: localKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    // MARK: - Encrypted Field Accessors

    /// Decrypt and return the stored user name, or nil if absent.
    /// Use this instead of reading AppKeys.Profile.name from UserDefaults directly.
    func storedName() -> String? {
        guard let data = encryptedStore.load(forKey: AppKeys.Profile.name) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decrypt and return the stored email, or nil if absent.
    func storedEmail() -> String? {
        guard let data = encryptedStore.load(forKey: AppKeys.Profile.email) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decrypt and return the stored date of birth, or nil if absent.
    func storedDateOfBirth() -> Date? {
        guard let data = encryptedStore.load(forKey: AppKeys.Profile.dateOfBirth),
              data.count == MemoryLayout<TimeInterval>.size else { return nil }
        let interval = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return Date(timeIntervalSince1970: interval)
    }

    // MARK: - Save to Firestore

    /// Save profile to Firestore and cache locally.
    /// Document ID is the Firebase Auth UID so subscription / profile state is
    /// Apple-ID-bound (cross-device, survives reinstall after Sign In with Apple
    /// links the anonymous account). `deviceId` stays in the body for analytics.
    func save(_ profile: UserProfile) {
        // Always cache locally first
        saveLocal(profile)

        // Prepare Firestore document data. anonymized only (no PII: name, email, DOB excluded)
        // firebaseUid binds ownership; the doc ID equals firebaseUid so the
        // record is keyed by Apple ID (post-link) rather than device.
        #if canImport(FirebaseAuth)
        let firebaseUid = Auth.auth().currentUser?.uid ?? ""
        #else
        let firebaseUid = ""
        #endif

        // Without a Firebase UID we cannot satisfy the security rules.
        // Skip the write rather than write to a deviceId-keyed orphan doc.
        guard !firebaseUid.isEmpty else {
            #if DEBUG
            print("[UserProfileStore] Skipping Firestore write — no Firebase Auth UID yet.")
            #endif
            return
        }

        let data: [String: Any] = [
            "gender": profile.gender.rawValue,
            "ageBracket": profile.ageBracket,
            "healthFocuses": profile.healthFocuses,
            "deviceId": profile.deviceId,
            "createdAt": profile.createdAt.timeIntervalSince1970,
            "updatedAt": profile.updatedAt.timeIntervalSince1970,
            "appVersion": profile.appVersion,
            "region": profile.region,
            "firebaseUid": firebaseUid
        ]

#if canImport(FirebaseFirestore)
        Firestore.firestore()
            .collection(collectionName)
            .document(firebaseUid)
            .setData(data, merge: true) { error in
                if let error {
                    #if DEBUG
                    print("[UserProfileStore] Firestore write failed: \(error.localizedDescription)")
                    #endif
                }
            }
#else
        _ = data
#endif
    }

    // MARK: - Convenience

    /// Create a new profile with auto-populated device, region, and version fields
    func makeProfile(
        name: String,
        email: String,
        gender: Gender,
        dateOfBirth: Date,
        healthFocuses: [String]
    ) -> UserProfile {
        let now = Date()
        let existingProfile = loadLocal()

        return UserProfile(
            name: name,
            email: email,
            gender: gender,
            dateOfBirth: dateOfBirth,
            healthFocuses: healthFocuses,
            deviceId: currentDeviceId,
            createdAt: existingProfile?.createdAt ?? now,
            updatedAt: now,
            appVersion: currentAppVersion,
            region: currentRegion
        )
    }
}
