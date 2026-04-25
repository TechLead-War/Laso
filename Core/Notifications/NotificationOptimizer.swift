import Foundation

/// Optimizes notification timing, priority, and frequency based on user engagement data
enum NotificationOptimizer {

    /// Pass 12 BE perf: cached current calendar. `isFatigued` and `openRate`
    /// are evaluated whenever a new notification is scheduled.
    private static let cal: Calendar = Calendar.current

    /// Find the hour with the best open rate (min 3 samples per hour, min 14 total events)
    static func optimalHour(events: [StoredNotificationEvent], defaultHour: Int = 8) -> Int {
        guard events.count >= 14 else { return defaultHour }

        var sentByHour: [Int: Int] = [:]
        var openedByHour: [Int: Int] = [:]

        for event in events {
            sentByHour[event.hourSent, default: 0] += 1
            if event.openedDate != nil {
                openedByHour[event.hourSent, default: 0] += 1
            }
        }

        var bestHour = defaultHour
        var bestRate: Double = -1

        for (hour, sentCount) in sentByHour where sentCount >= 3 {
            let openedCount = openedByHour[hour, default: 0]
            let rate = Double(openedCount) / Double(sentCount)
            if rate > bestRate {
                bestRate = rate
                bestHour = hour
            }
        }

        return bestHour
    }

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
        let sevenDaysAgo = Self.cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentEvents = events.filter { $0.sentDate >= sevenDaysAgo }
        guard recentEvents.count >= 5 else { return false }
        let opened = recentEvents.filter { $0.openedDate != nil }.count
        let rate = Double(opened) / Double(recentEvents.count)
        return rate < fatigueThreshold
    }

    /// Dynamic daily notification budget, reduced when fatigued
    static func dailyBudget(events: [StoredNotificationEvent]) -> Int {
        let baseBudget = RemoteConfigManager.shared.notificationDailyBudget
        if isFatigued(events: events) {
            return max(1, baseBudget - 1)
        }
        return baseBudget
    }

    /// Aggregate open rate for analytics
    static func openRate(events: [StoredNotificationEvent], days: Int) -> Double? {
        let cutoff = Self.cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recent = events.filter { $0.sentDate >= cutoff }
        guard !recent.isEmpty else { return nil }
        let opened = recent.filter { $0.openedDate != nil }.count
        return Double(opened) / Double(recent.count)
    }
}
