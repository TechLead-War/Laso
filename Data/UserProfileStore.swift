import Foundation
import UIKit

#if canImport(FirebaseFirestore)
import FirebaseFirestore
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

    /// Save profile to UserDefaults as local cache
    func saveLocal(_ profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: localKey)
    }

    /// Load cached profile from UserDefaults
    func loadLocal() -> UserProfile? {
        guard let data = defaults.data(forKey: localKey) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    // MARK: - Save to Firestore

    /// Save profile to Firestore and cache locally.
    /// Uses deviceId as the Firestore document ID for upsert behavior.
    func save(_ profile: UserProfile) {
        // Always cache locally first
        saveLocal(profile)

        // Prepare Firestore document data. anonymized only (no PII: name, email, DOB excluded)
        let data: [String: Any] = [
            "gender": profile.gender.rawValue,
            "ageBracket": profile.ageBracket,
            "healthFocuses": profile.healthFocuses,
            "deviceId": profile.deviceId,
            "createdAt": profile.createdAt.timeIntervalSince1970,
            "updatedAt": profile.updatedAt.timeIntervalSince1970,
            "appVersion": profile.appVersion,
            "region": profile.region
        ]

#if canImport(FirebaseFirestore)
        Firestore.firestore()
            .collection(collectionName)
            .document(profile.deviceId)
            .setData(data, merge: true) { error in
                if let error {
                    print("[UserProfileStore] Firestore write failed: \(error.localizedDescription)")
                }
            }
#else
        print("[UserProfileStore] Would write to Firestore: \(data)")
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
