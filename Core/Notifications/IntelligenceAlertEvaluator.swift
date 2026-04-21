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

    // MARK: - Evaluation

    /// Evaluate intelligence cards and schedule a notification for the highest-priority warning/critical card.
    static func evaluate(cards: [IntelligenceCard], preferences: NotificationPreferences) {
        guard RemoteConfigManager.shared.intelligenceNotificationsEnabled else { return }
        guard preferences.criticalAlertsEnabled || preferences.warningAlertsEnabled else { return }

        // Filter to warning/critical only, take the highest priority card
        let actionableCards = cards.filter { $0.severity >= .warning }
        guard let topCard = actionableCards.max(by: { $0.priority < $1.priority }) else { return }

        // Check preference for the specific severity level
        switch topCard.severity {
        case .critical:
            guard preferences.criticalAlertsEnabled else { return }
        case .warning:
            guard preferences.warningAlertsEnabled else { return }
        default:
            return
        }

        let identifier = "healthpulse.intelligence.\(topCard.type.rawValue)"
        guard !isOnCooldown(identifier: identifier) else { return }

        // Map CardSeverity to Severity
        let severity: Severity = topCard.severity == .critical ? .critical : .warning

        NotificationManager.shared.scheduleNotification(
            title: topCard.label,
            body: topCard.headline,
            identifier: identifier,
            maxPerDay: 1,
            severity: severity
        )
        recordAlert(identifier: identifier)
    }
}
