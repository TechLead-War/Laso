import Foundation

/// Evaluates intelligence briefing cards and schedules notifications for warning/critical findings.
/// Mirrors AlertEvaluator pattern: static struct, cooldown via AppKeys, delegates to NotificationManager.
struct IntelligenceAlertEvaluator {

    private static var cooldownHours: Double { RemoteConfigManager.shared.alertCooldownHours }

    private static func isOnCooldown(identifier: String) -> Bool {
        let key = AppKeys.Notifications.alertCooldownPrefix + identifier
        let lastFired = UserDefaults.standard.double(forKey: key)
        guard lastFired > 0 else { return false }
        let elapsed = Date().timeIntervalSince1970 - lastFired
        return elapsed < cooldownHours * 3600
    }

    private static func recordAlert(identifier: String) {
        let key = AppKeys.Notifications.alertCooldownPrefix + identifier
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
    }

    /// Mirrors the per-gate reporting NotificationManager does for its own gates.
    /// The gates below run BEFORE the manager is reached, so without this the
    /// kill switch, the preference mutes and the cooldown dedupe drop briefings
    /// with nothing emitted at all. Hops to the main actor because AppAnalytics
    /// is isolated there and this type is not.
    private static func trackSuppressed(identifier: String, reason: String) {
        let type = NotificationManager.notificationType(identifier)
        Task { @MainActor in
            AppAnalytics.shared.trackNotificationSuppressed(type: type, identifier: identifier, reason: reason)
        }
    }

    // MARK: - Evaluation

    /// Evaluate intelligence cards and schedule a notification for the highest-priority warning/critical card.
    static func evaluate(cards: [IntelligenceCard], preferences: NotificationPreferences) {
        // Filter to warning/critical only, take the highest priority card
        let actionableCards = cards.filter { $0.severity >= .warning }
        guard let topCard = actionableCards.max(by: { $0.priority < $1.priority }) else { return }

        // Built above the gates so every suppressed card is reported against the
        // same identifier a scheduled one would have carried.
        let identifier = "\(AppConstants.NotificationID.intelligencePrefix)\(topCard.type.rawValue)"

        guard RemoteConfigManager.shared.intelligenceNotificationsEnabled else {
            trackSuppressed(identifier: identifier, reason: "kill_switch")
            return
        }
        guard preferences.criticalAlertsEnabled || preferences.warningAlertsEnabled else {
            trackSuppressed(identifier: identifier, reason: "non_critical_muted")
            return
        }

        // Check preference for the specific severity level
        switch topCard.severity {
        case .critical:
            guard preferences.criticalAlertsEnabled else {
                trackSuppressed(identifier: identifier, reason: "non_critical_muted")
                return
            }
        case .warning:
            guard preferences.warningAlertsEnabled else {
                trackSuppressed(identifier: identifier, reason: "non_critical_muted")
                return
            }
        default:
            return
        }

        guard !isOnCooldown(identifier: identifier) else {
            trackSuppressed(identifier: identifier, reason: "alert_cooldown")
            return
        }

        // Map CardSeverity to Severity
        let severity: Severity = topCard.severity == .critical ? .critical : .warning

        let scheduled = NotificationManager.shared.scheduleNotification(
            title: topCard.label,
            body: topCard.headline,
            identifier: identifier,
            maxPerDay: 1,
            severity: severity
        )
        // Cooldown only for a notification that actually exists; stamping a
        // suppressed schedule would dedupe briefings the user never saw.
        if scheduled {
            recordAlert(identifier: identifier)
        }
    }
}
