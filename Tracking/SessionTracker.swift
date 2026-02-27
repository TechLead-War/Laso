import Foundation

/// Manages session lifecycle, navigation depth, screen transitions, daily streak,
/// activation milestones, retention signals, and habit/churn detection.
final class SessionTracker {
    static let shared = SessionTracker()

    private let defaults = UserDefaults.standard

    // MARK: - Session State

    private(set) var sessionId = UUID().uuidString
    private var sessionStartDate = Date()
    private(set) var screensVisited: Set<String> = []
    private(set) var maxDepth: Int = 0
    private(set) var currentDepth: Int = 0
    var currentTab: String = "home"
    private var lastScreen: String?

    // MARK: - Streak State

    private(set) var streakDays: Int = 0
    /// Previous streak before it was broken (populated on streak reset).
    private(set) var previousStreakBeforeBreak: Int?

    // MARK: - Lifecycle State

    private(set) var totalSessions: Int = 0
    private(set) var daysSinceInstall: Int = 0
    private(set) var isFirstSession: Bool = false
    private(set) var completedMilestones: Set<String> = []
    private(set) var coreActionsThisSession: [String] = []
    private(set) var lifetimeCoreActions: Int = 0

    // MARK: - Retention State

    private(set) var retentionMilestones: Set<String> = []
    private(set) var streakMilestonesReached: Set<String> = []

    private enum Key {
        static let lastActiveDate = AppKeys.Session.lastActiveDate
        static let streakDays = AppKeys.Session.streakDays
        static let longestStreak = AppKeys.Session.longestStreak
        static let installDate = AppKeys.Lifecycle.installDate
        static let totalSessions = AppKeys.Session.totalSessions
        static let completedMilestones = AppKeys.Session.milestones
        static let lastSessionDate = AppKeys.Session.lastSessionDate
        static let firstValueTimeSec = AppKeys.Session.firstValueTimeSec
        static let retentionMilestones = AppKeys.Session.retentionMilestones
        static let streakMilestones = AppKeys.Session.streakMilestones
        static let lifetimeCoreActions = AppKeys.Session.lifetimeCoreActions
        static let lastInactivityAlert = AppKeys.Session.lastInactivityAlert
    }

    private init() {
        loadStreak()
        loadLifecycleState()
    }

    // MARK: - Session Lifecycle

    func startSession() {
        sessionId = UUID().uuidString
        sessionStartDate = Date()
        screensVisited = []
        maxDepth = 0
        currentDepth = 0
        lastScreen = nil
        coreActionsThisSession = []
        previousStreakBeforeBreak = nil
        updateStreak()
        updateLifecycleOnStart()
    }

    func endSession() -> (durationSec: Int, screensVisited: Int, maxDepth: Int) {
        let duration = Int(Date().timeIntervalSince(sessionStartDate))
        defaults.set(Date(), forKey: Key.lastSessionDate)
        return (duration, screensVisited.count, maxDepth)
    }

    /// Seconds since this session started.
    var sessionElapsedSeconds: Int {
        Int(Date().timeIntervalSince(sessionStartDate))
    }

    // MARK: - Screen Tracking

    /// Records a screen view and returns the previous screen name.
    func recordScreenView(_ screen: String) -> String? {
        let previousScreen = lastScreen
        screensVisited.insert(screen)
        lastScreen = screen
        return previousScreen
    }

    func updateDepth(_ depth: Int) {
        currentDepth = depth
        maxDepth = max(maxDepth, depth)
    }

    // MARK: - Streak

    var isLongestStreak: Bool {
        streakDays >= defaults.integer(forKey: Key.longestStreak)
    }

    var longestStreak: Int {
        defaults.integer(forKey: Key.longestStreak)
    }

    private func loadStreak() {
        streakDays = defaults.integer(forKey: Key.streakDays)
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = defaults.object(forKey: Key.lastActiveDate) as? Date {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 1 {
                streakDays += 1
            } else if daysDiff > 1 {
                // Streak broken — record the previous streak for analytics
                previousStreakBeforeBreak = defaults.integer(forKey: Key.streakDays)
                streakDays = 1
            }
            // daysDiff == 0 → same day, no change
        } else {
            streakDays = 1
        }

        defaults.set(today, forKey: Key.lastActiveDate)
        defaults.set(streakDays, forKey: Key.streakDays)

        let longest = defaults.integer(forKey: Key.longestStreak)
        if streakDays > longest {
            defaults.set(streakDays, forKey: Key.longestStreak)
        }
    }

    /// Check and record streak milestones (7, 14, 30, 60, 100).
    /// Returns the milestone value if newly reached, nil otherwise.
    func checkStreakMilestone() -> Int? {
        if streakMilestonesReached.isEmpty,
           let stored = defaults.stringArray(forKey: Key.streakMilestones) {
            streakMilestonesReached = Set(stored)
        }

        let milestones = [7, 14, 30, 60, 100]
        for m in milestones {
            let key = "streak_\(m)"
            if streakDays >= m && !streakMilestonesReached.contains(key) {
                streakMilestonesReached.insert(key)
                defaults.set(Array(streakMilestonesReached), forKey: Key.streakMilestones)
                return m
            }
        }
        return nil
    }

    // MARK: - Retention Milestones

    /// Check and record retention day milestones (day 1, 2, 3, 7, 14, 30).
    /// Returns the milestone day if newly reached, nil otherwise.
    func checkRetentionMilestone() -> Int? {
        if retentionMilestones.isEmpty,
           let stored = defaults.stringArray(forKey: Key.retentionMilestones) {
            retentionMilestones = Set(stored)
        }

        let milestones = [1, 2, 3, 7, 14, 30]
        for day in milestones {
            let key = "day_\(day)"
            if daysSinceInstall >= day && !retentionMilestones.contains(key) {
                retentionMilestones.insert(key)
                defaults.set(Array(retentionMilestones), forKey: Key.retentionMilestones)
                return day
            }
        }
        return nil
    }

    // MARK: - Inactivity Detection

    /// Returns days since last session, but only if it crosses a threshold (3, 7).
    /// Returns nil if no notable inactivity or already alerted for this gap.
    func checkInactivityPeriod() -> Int? {
        guard let daysSince = daysSinceLastSession, daysSince >= 3 else { return nil }

        let lastAlertedGap = defaults.integer(forKey: Key.lastInactivityAlert)

        // Alert at 3 and 7 day thresholds (only once per threshold)
        if daysSince >= 7 && lastAlertedGap < 7 {
            defaults.set(7, forKey: Key.lastInactivityAlert)
            return 7
        } else if daysSince >= 3 && lastAlertedGap < 3 {
            defaults.set(3, forKey: Key.lastInactivityAlert)
            return 3
        }
        return nil
    }

    /// Reset inactivity tracking when user becomes active again.
    func clearInactivityState() {
        defaults.set(0, forKey: Key.lastInactivityAlert)
    }

    // MARK: - Lifecycle / Activation / Retention

    private func loadLifecycleState() {
        totalSessions = defaults.integer(forKey: Key.totalSessions)
        lifetimeCoreActions = defaults.integer(forKey: Key.lifetimeCoreActions)
        if let milestones = defaults.stringArray(forKey: Key.completedMilestones) {
            completedMilestones = Set(milestones)
        }

        // Set install date on first launch
        if defaults.object(forKey: Key.installDate) == nil {
            defaults.set(Date(), forKey: Key.installDate)
        }

        let installDate = defaults.object(forKey: Key.installDate) as? Date ?? Date()
        daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
    }

    private func updateLifecycleOnStart() {
        totalSessions += 1
        isFirstSession = totalSessions == 1
        defaults.set(totalSessions, forKey: Key.totalSessions)
    }

    /// Days since last session (for return session tracking). Returns nil for first session.
    var daysSinceLastSession: Int? {
        guard let lastDate = defaults.object(forKey: Key.lastSessionDate) as? Date else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }

    /// Record an activation milestone. Returns true if this is the FIRST time it's recorded.
    func recordMilestone(_ milestone: String) -> Bool {
        if completedMilestones.contains(milestone) { return false }
        completedMilestones.insert(milestone)
        defaults.set(Array(completedMilestones), forKey: Key.completedMilestones)
        return true
    }

    /// Record a core action in this session (for session quality scoring).
    /// Also increments lifetime core actions.
    func recordCoreAction(_ action: String) {
        if !coreActionsThisSession.contains(action) {
            coreActionsThisSession.append(action)
        }
        lifetimeCoreActions += 1
        defaults.set(lifetimeCoreActions, forKey: Key.lifetimeCoreActions)
    }

    /// Record time-to-first-value (only once, on first meaningful data load).
    func recordFirstValueTime() {
        guard defaults.integer(forKey: Key.firstValueTimeSec) == 0 else { return }
        let elapsed = sessionElapsedSeconds
        defaults.set(elapsed, forKey: Key.firstValueTimeSec)
    }

    var firstValueTimeSec: Int {
        defaults.integer(forKey: Key.firstValueTimeSec)
    }

    var installDate: Date {
        defaults.object(forKey: Key.installDate) as? Date ?? Date()
    }

    /// Whether the user meets activation criteria: 3+ milestones within first 7 days.
    var isActivated: Bool {
        completedMilestones.count >= 3
    }
}
