import Foundation
import UIKit
import Observation

/// Manages A/B test bucket assignment for the monetization experiment.
///
/// **Experiment: Monetization Strategy**
/// - Bucket A ("trial"):    30-day free trial → hard paywall (must pay to use app)
/// - Bucket B ("freemium"): Free tier forever + paid Pro features (current model)
///
/// Assignment is deterministic based on device identifierForVendor so a user
/// always lands in the same bucket across sessions. Persisted in UserDefaults
/// as a safety net in case the vendor ID changes (e.g., reinstall).
@Observable
final class ABTestManager {
    static let shared = ABTestManager()

    // MARK: - Bucket Definition

    enum MonetizationBucket: String, Codable {
        case trial     // Bucket A: 30-day free trial → hard paywall
        case freemium  // Bucket B: free tier + paid features
    }

    // MARK: - Keys

    private let bucketKey = "laso.abtest.monetization_bucket"
    private let installDateKey = "laso.abtest.install_date"
    private let defaults = UserDefaults.standard

    // MARK: - Configuration

    /// Trial duration in days for Bucket A
    static let trialDurationDays = 30

    // MARK: - Public Properties

    /// The user's assigned bucket
    private(set) var bucket: MonetizationBucket = .freemium

    /// When the app was first installed (for trial calculation)
    private(set) var installDate: Date = Date()

    // MARK: - Init

    private init() {
        loadOrAssign()
    }

    // MARK: - Trial State (Bucket A only)

    /// Days remaining in trial (Bucket A only, 0 if expired or Bucket B)
    var trialDaysRemaining: Int {
        guard bucket == .trial else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        return max(Self.trialDurationDays - elapsed, 0)
    }

    /// Whether the trial has expired (Bucket A only)
    var isTrialExpired: Bool {
        bucket == .trial && trialDaysRemaining <= 0
    }

    /// Whether the user is currently in an active trial
    var isInActiveTrial: Bool {
        bucket == .trial && trialDaysRemaining > 0
    }

    /// Fraction of trial elapsed (0.0 to 1.0)
    var trialProgress: Double {
        guard bucket == .trial else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        return min(Double(elapsed) / Double(Self.trialDurationDays), 1.0)
    }

    // MARK: - Assignment Logic

    private func loadOrAssign() {
        // 1. Check if already assigned
        if let savedBucket = defaults.string(forKey: bucketKey),
           let parsed = MonetizationBucket(rawValue: savedBucket) {
            bucket = parsed
            installDate = loadInstallDate()
            return
        }

        // 2. First launch — assign deterministically
        bucket = assignBucket()
        installDate = Date()

        // 3. Persist
        defaults.set(bucket.rawValue, forKey: bucketKey)
        defaults.set(installDate.timeIntervalSince1970, forKey: installDateKey)

        // 4. Track assignment
        AnalyticsManager.shared.track(
            .abTestAssigned(experiment: "monetization_v1", bucket: bucket.rawValue)
        )
    }

    /// Deterministic 50/50 split based on device identifierForVendor
    private func assignBucket() -> MonetizationBucket {
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        // Simple hash: sum of ASCII values mod 2
        let hash = id.utf8.reduce(0) { ($0 &+ Int($1)) }
        return hash % 2 == 0 ? .trial : .freemium
    }

    private func loadInstallDate() -> Date {
        let ts = defaults.double(forKey: installDateKey)
        guard ts > 0 else { return Date() }
        return Date(timeIntervalSince1970: ts)
    }

    // MARK: - Debug / Admin

    /// Force a specific bucket (for testing only)
    func overrideBucket(_ newBucket: MonetizationBucket) {
        bucket = newBucket
        defaults.set(bucket.rawValue, forKey: bucketKey)
    }

    /// Reset to re-assign on next init (for testing only)
    func reset() {
        defaults.removeObject(forKey: bucketKey)
        defaults.removeObject(forKey: installDateKey)
    }

    /// Human-readable status string (for debug/admin views)
    var statusDescription: String {
        switch bucket {
        case .trial:
            if isTrialExpired {
                return "Bucket A (Trial) — Expired"
            } else {
                return "Bucket A (Trial) — \(trialDaysRemaining) days left"
            }
        case .freemium:
            return "Bucket B (Freemium)"
        }
    }
}
