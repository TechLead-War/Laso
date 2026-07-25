import Foundation

/// Optimizes notification timing, priority, and frequency based on user engagement data
enum NotificationOptimizer {

    /// Compute a priority score (0-100) for a notification
    static func priorityScore(
        severity: Severity,
        deviationPercent: Double = 0,
        isRecent: Bool = false,
        metricInFocus: Bool = false
    ) -> Int {
        var score = 0

        switch severity {
        case .critical: score += 50
        case .warning: score += 30
        case .info: score += 10
        }

        // Deviation magnitude: up to 20 points
        let devMagnitude = min(abs(deviationPercent), 100)
        score += Int(devMagnitude / 5) // max 20

        if isRecent { score += 10 }
        if metricInFocus { score += 15 }

        return min(score, 100)
    }

    /// Check if the user is experiencing notification fatigue (low open rate over 7 days)
    static func isFatigued(events: [StoredNotificationEvent], threshold: Double? = nil) -> Bool {
        let fatigueThreshold = threshold ?? RemoteConfigManager.shared.notificationFatigueThreshold
        let sevenDaysAgo = Date.cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentEvents = events.filter { $0.sentDate >= sevenDaysAgo }
        guard recentEvents.count >= 5 else { return false }
        let opened = recentEvents.filter { $0.openedDate != nil }.count
        let rate = Double(opened) / Double(recentEvents.count)
        return rate < fatigueThreshold
    }

    /// Dynamic daily notification budget, reduced when fatigued. Floored at 1
    /// on both paths so a zero or negative remote value cannot silently kill
    /// every capped notification app-wide (the kill switch is the sanctioned
    /// off button, not the budget).
    static func dailyBudget(events: [StoredNotificationEvent]) -> Int {
        let baseBudget = RemoteConfigManager.shared.notificationDailyBudget
        if isFatigued(events: events) {
            return max(1, baseBudget - 1)
        }
        return max(1, baseBudget)
    }
}
