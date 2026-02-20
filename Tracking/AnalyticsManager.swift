import Foundation
import Observation

/// Tracks user events locally and flushes to Firebase Analytics for cross-user reporting.
@Observable
final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private let defaults = UserDefaults.standard
    private let eventsKey = "laso.analytics.events"
    private let sessionCountKey = "laso.analytics.sessionCount"
    private let firstOpenKey = "laso.analytics.firstOpen"
    private let lastFeedbackKey = "laso.analytics.lastFeedback"

    /// Current session ID
    private(set) var currentSessionId: String = UUID().uuidString

    /// Session start time
    private var sessionStartTime: Date = Date()

    /// Total session count (persisted)
    var sessionCount: Int {
        defaults.integer(forKey: sessionCountKey)
    }

    private init() {}

    // MARK: - Track Events

    func track(_ event: AnalyticsEvent) {
        let stored = StoredEvent(event: event, sessionId: currentSessionId)
        var events = loadEvents()
        events.append(stored)

        // Trim to max
        if events.count > FeatureConfig.maxLocalAnalyticsEvents {
            events = Array(events.suffix(FeatureConfig.maxLocalAnalyticsEvents))
        }

        saveEvents(events)

        // Flush to Firebase Analytics
        FirebaseAnalyticsService.shared.track(name: event.name, properties: event.properties)
    }

    // MARK: - Session Management

    func startSession() {
        currentSessionId = UUID().uuidString
        sessionStartTime = Date()
        defaults.set(sessionCount + 1, forKey: sessionCountKey)

        if defaults.object(forKey: firstOpenKey) == nil {
            defaults.set(Date().timeIntervalSince1970, forKey: firstOpenKey)
        }

        track(.sessionStarted)
    }

    func endSession() {
        let duration = Int(Date().timeIntervalSince(sessionStartTime))
        track(.sessionEnded(durationSeconds: duration))
    }

    // MARK: - Business Metrics

    /// All stored events
    func allEvents() -> [StoredEvent] {
        loadEvents()
    }

    /// Events in the last N days
    func events(lastDays days: Int) -> [StoredEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return loadEvents().filter { $0.timestamp >= cutoff }
    }

    /// Unique sessions in the last N days
    func uniqueSessions(lastDays days: Int) -> Int {
        Set(events(lastDays: days).map(\.sessionId)).count
    }

    /// Average session duration in seconds (last N days)
    func averageSessionDuration(lastDays days: Int) -> Int {
        let sessionEvents = events(lastDays: days).filter {
            if case .sessionEnded = $0.event { return true }
            return false
        }
        let durations: [Int] = sessionEvents.compactMap {
            if case .sessionEnded(let d) = $0.event { return d }
            return nil
        }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / durations.count
    }

    /// Most viewed screens (last N days)
    func topScreens(lastDays days: Int, limit: Int = 10) -> [(screen: String, count: Int)] {
        let screenEvents = events(lastDays: days).compactMap { stored -> String? in
            if case .screenView(let screen) = stored.event { return screen }
            return nil
        }
        return counted(screenEvents).prefix(limit).map { $0 }
    }

    /// Most used features (last N days)
    func topFeatures(lastDays days: Int, limit: Int = 10) -> [(feature: String, count: Int)] {
        let featureEvents = events(lastDays: days).compactMap { stored -> String? in
            if case .featureUsed(let f) = stored.event { return f }
            return nil
        }
        return counted(featureEvents).prefix(limit).map { $0 }
    }

    /// Most viewed metrics (last N days)
    func topMetrics(lastDays days: Int, limit: Int = 10) -> [(metric: String, count: Int)] {
        let metricEvents = events(lastDays: days).compactMap { stored -> String? in
            if case .metricViewed(let m, _) = stored.event { return m }
            return nil
        }
        return counted(metricEvents).prefix(limit).map { $0 }
    }

    /// Paywall conversion rate (views → subscriptions, last N days)
    func paywallConversionRate(lastDays days: Int) -> Double {
        let recentEvents = events(lastDays: days)
        let views = recentEvents.filter {
            if case .paywallViewed = $0.event { return true }
            return false
        }.count
        let conversions = recentEvents.filter {
            if case .subscriptionStarted = $0.event { return true }
            return false
        }.count
        guard views > 0 else { return 0 }
        return Double(conversions) / Double(views)
    }

    /// Features that users hit the paywall on most (demand signals)
    func topGatedFeatures(lastDays days: Int) -> [(feature: String, count: Int)] {
        let gated = events(lastDays: days).compactMap { stored -> String? in
            if case .featureGated(let f) = stored.event { return f }
            return nil
        }
        return counted(gated)
    }

    /// Feedback submissions
    func feedbackEntries() -> [StoredEvent] {
        loadEvents().filter {
            if case .feedbackSubmitted = $0.event { return true }
            return false
        }
    }

    // MARK: - A/B Test Metrics

    /// Conversion rate per bucket (last N days)
    func abTestConversionRates(lastDays days: Int) -> [String: (paywallViews: Int, conversions: Int, rate: Double)] {
        let recentEvents = events(lastDays: days)

        // Find each user's bucket from ab_test_assigned events
        let bucketAssignments = recentEvents.compactMap { stored -> String? in
            if case .abTestAssigned(_, let bucket) = stored.event { return bucket }
            return nil
        }
        let bucket = bucketAssignments.last ?? ABTestManager.shared.bucket.rawValue

        let views = recentEvents.filter {
            if case .paywallViewed = $0.event { return true }
            return false
        }.count

        let conversions = recentEvents.filter {
            if case .subscriptionStarted = $0.event { return true }
            return false
        }.count

        let rate = views > 0 ? Double(conversions) / Double(views) : 0

        return [bucket: (paywallViews: views, conversions: conversions, rate: rate)]
    }

    /// Session count per bucket
    func abTestEngagement(lastDays days: Int) -> (bucket: String, sessions: Int, avgDuration: Int) {
        let bucket = ABTestManager.shared.bucket.rawValue
        return (
            bucket: bucket,
            sessions: uniqueSessions(lastDays: days),
            avgDuration: averageSessionDuration(lastDays: days)
        )
    }

    // MARK: - Feedback Timing

    /// Whether to show the feedback prompt — at least 5 days between prompts
    var shouldShowFeedbackPrompt: Bool {
        guard sessionCount >= FeatureConfig.feedbackPromptAfterSessions else { return false }

        // Cooldown since last feedback interaction
        let lastFeedback = defaults.double(forKey: lastFeedbackKey)
        if lastFeedback > 0 {
            let daysSince = Date().timeIntervalSince1970 - lastFeedback
            let cooldown = Double(FeatureConfig.feedbackCooldownDays) * 86400
            if daysSince < cooldown { return false }
        }

        // On first prompt (no lastFeedback), check install age via first open date
        if lastFeedback == 0 {
            let firstOpen = defaults.double(forKey: firstOpenKey)
            if firstOpen > 0 {
                let daysSinceInstall = (Date().timeIntervalSince1970 - firstOpen) / 86400
                if daysSinceInstall < Double(FeatureConfig.feedbackCooldownDays) { return false }
            }
        }

        return true
    }

    /// Record that feedback was shown or submitted
    func recordFeedbackInteraction() {
        defaults.set(Date().timeIntervalSince1970, forKey: lastFeedbackKey)
    }

    // MARK: - Persistence

    private func loadEvents() -> [StoredEvent] {
        guard let data = defaults.data(forKey: eventsKey),
              let events = try? JSONDecoder().decode([StoredEvent].self, from: data) else {
            return []
        }
        return events
    }

    private func saveEvents(_ events: [StoredEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: eventsKey)
        }
    }

    /// Count occurrences and sort descending
    private func counted(_ items: [String]) -> [(String, Int)] {
        var counts: [String: Int] = [:]
        for item in items { counts[item, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }
    }
}
