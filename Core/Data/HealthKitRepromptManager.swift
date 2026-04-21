import Foundation

/// Detects when the user authorized HealthKit but toggled off all individual
/// data categories, leaving the app with no usable data.
///
/// Apple marks authorization as granted even when every category is turned off,
/// so `isAuthorized` alone cannot detect this. We check whether `timeSeries`
/// is empty after the initial load completes.
///
/// - First detection: records the date
/// - After 1 day: `shouldShowReprompt` returns true (once per 14 days)
/// - Clears records automatically if data eventually appears
enum HealthKitRepromptManager {

    private static let defaults = UserDefaults.standard

    /// Call after the dashboard finishes its initial load.
    /// Returns `true` if the re-prompt banner should be shown.
    ///
    /// - Parameters:
    ///   - isAuthorized: Whether HealthKit authorization was granted
    ///   - timeSeriesCount: Number of metrics with data in `timeSeries`
    static func checkEmptyData(isAuthorized: Bool, timeSeriesCount: Int) -> Bool {
        guard isAuthorized else { return false }

        if timeSeriesCount > 0 {
            // Data is present, clear any previous detection
            clearDetectionRecord()
            return false
        }

        // Authorized but no data, record detection
        recordDetectionIfNeeded()
        return shouldShowReprompt()
    }

    /// Call when the re-prompt banner is displayed to the user.
    static func recordRepromptShown() {
        defaults.set(Date().timeIntervalSince1970, forKey: AppKeys.HealthKit.repromptLastShownDate)
        Task { @MainActor in
            AppAnalytics.shared.trackBlockTap(
                title: "HealthKit Reprompt Shown",
                type: .dataSyncEvent,
                screen: .home,
                metadata: ["source": "healthkit_reprompt", "event": "reprompt_shown"]
            )
        }
    }

    // MARK: - Internal

    private static func recordDetectionIfNeeded() {
        let existing = defaults.double(forKey: AppKeys.HealthKit.emptyDataDetectedDate)
        if existing == 0 {
            defaults.set(Date().timeIntervalSince1970, forKey: AppKeys.HealthKit.emptyDataDetectedDate)
        }
    }

    private static func clearDetectionRecord() {
        defaults.removeObject(forKey: AppKeys.HealthKit.emptyDataDetectedDate)
        defaults.removeObject(forKey: AppKeys.HealthKit.repromptLastShownDate)
    }

    private static func shouldShowReprompt() -> Bool {
        let detectedTimestamp = defaults.double(forKey: AppKeys.HealthKit.emptyDataDetectedDate)
        guard detectedTimestamp > 0 else { return false }

        let now = Date().timeIntervalSince1970
        let daysSinceDetection = (now - detectedTimestamp) / 86400

        // Wait at least 1 day after detection
        guard daysSinceDetection >= 1 else { return false }

        // Don't show more than once per 14 days
        let lastShown = defaults.double(forKey: AppKeys.HealthKit.repromptLastShownDate)
        if lastShown > 0 {
            let daysSinceLastShown = (now - lastShown) / 86400
            guard daysSinceLastShown >= 14 else { return false }
        }

        return true
    }
}
