import Foundation

/// Manages session lifecycle, navigation depth, screen transitions, and daily streak.
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

    private enum Key {
        static let lastActiveDate = "laso.session.last_active_date"
        static let streakDays = "laso.session.streak_days"
        static let longestStreak = "laso.session.longest_streak"
    }

    private init() {
        loadStreak()
    }

    // MARK: - Session Lifecycle

    func startSession() {
        sessionId = UUID().uuidString
        sessionStartDate = Date()
        screensVisited = []
        maxDepth = 0
        currentDepth = 0
        lastScreen = nil
        updateStreak()
    }

    func endSession() -> (durationSec: Int, screensVisited: Int, maxDepth: Int) {
        let duration = Int(Date().timeIntervalSince(sessionStartDate))
        return (duration, screensVisited.count, maxDepth)
    }

    // MARK: - Screen Tracking

    /// Records a screen view and returns the previous screen name (for nav_transition).
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
}
