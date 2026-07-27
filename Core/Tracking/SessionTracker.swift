import Foundation

/// Manages session lifecycle, navigation depth, screen transitions, daily streak,
/// activation milestones, retention signals, and habit/churn detection.
@MainActor
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

    // MARK: - Idle Guard & Active Time

    /// A foreground return more than this many seconds after the last activity
    /// starts a brand-new session. Below it, the same session resumes so a quick
    /// app-switch does not inflate DAU. Industry-standard 30-minute window.
    private static let idleTimeoutSec: TimeInterval = 30 * 60

    /// Wall-clock time of the last foreground activity (set on every foreground
    /// return and on background). Drives the 30-minute idle decision.
    private var lastActivityDate = Date()

    /// Accumulated foreground-active seconds for the current session, excluding
    /// time spent backgrounded/idle. `active_sec` on session_ended reads this.
    private var accumulatedActiveSec: TimeInterval = 0
    /// When the current active span started (foreground). nil while backgrounded.
    private var activeSpanStart: Date?
    /// True between a session_started and its session_ended, including while the
    /// app is backgrounded. Distinguishes "resume the open session" from "no
    /// session yet" when deciding whether the idle window applies.
    private var sessionIsOpen = false

    /// Reason a session ended. Under the resume model a background is not an end,
    /// so only two terminal reasons exist: the idle window elapsed, or the app was
    /// killed and the end is reconciled on next launch.
    enum EndReason: String {
        case idleTimeout = "idle_timeout"
        case appTerminated = "app_terminated"
    }

    // MARK: - Session Source

    enum SessionSource: String {
        case organic
        case notification
        case widget
        /// laso:// links produced by the three Live Activity widgets. Kept
        /// distinct from `widget` so the home-screen widget bucket is not
        /// silently made up of Live Activity opens.
        case liveActivity = "live_activity"
    }

    /// Set this BEFORE calling startSession() to tag the session source.
    var pendingSessionSource: SessionSource = .organic

    /// Source of the current session.
    private(set) var currentSessionSource: SessionSource = .organic

    // MARK: - Stickiness

    /// Number of unique days the user was active in the current calendar week.
    private(set) var weeklyActiveDays: Int = 0

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
        static let restCreditsRemaining = AppKeys.Session.restCreditsRemaining
        static let lastRestCreditGrantDate = AppKeys.Session.lastRestCreditGrantDate
        static let openSession = AppKeys.Session.openSession
        /// Separate from `firstValueTimeSec` because a first value recorded in the
        /// same second as session start stores 0, which is indistinguishable from
        /// "never recorded" and would leave the one-shot open forever.
        static let firstValueRecorded = "laso.session.first_value_recorded"
        static let liveActivitySessions = "laso.session.live_activity_sessions"
    }

    // MARK: - Rest-Day Credits

    /// Max credits a user can bank at any time.
    private static let restCreditMax = 2
    /// How often a new credit is granted (days).
    private static let restCreditGrantIntervalDays = 30

    /// Current rest credits available. Spending one forgives exactly one missed day
    /// without breaking the streak. Follows Gentler Streak / Duolingo's streak-freeze
    /// pattern — published to reduce `at_risk` bucket churn by ~21%.
    var restCreditsRemaining: Int {
        defaults.integer(forKey: Key.restCreditsRemaining)
    }

    /// Refill monthly if interval has passed. Called in `startSession`.
    private func maybeGrantRestCredit() {
        let calendar = Date.cal
        let last = defaults.object(forKey: Key.lastRestCreditGrantDate) as? Date
        if let last {
            let days = calendar.dateComponents([.day], from: last, to: Date()).day ?? 0
            guard days >= Self.restCreditGrantIntervalDays else { return }
        }
        // First-ever grant OR interval elapsed.
        let current = defaults.integer(forKey: Key.restCreditsRemaining)
        guard current < Self.restCreditMax else {
            // Already at cap — just reset the grant clock so we don't keep re-checking.
            defaults.set(Date(), forKey: Key.lastRestCreditGrantDate)
            return
        }
        defaults.set(current + 1, forKey: Key.restCreditsRemaining)
        defaults.set(Date(), forKey: Key.lastRestCreditGrantDate)
        didGrantCreditThisSession = true
    }

    /// Spend one credit. Returns true on success, false if balance was zero.
    @discardableResult
    private func spendRestCredit() -> Bool {
        let current = defaults.integer(forKey: Key.restCreditsRemaining)
        guard current > 0 else { return false }
        defaults.set(current - 1, forKey: Key.restCreditsRemaining)
        didSpendCreditThisSession = true
        return true
    }

    /// Session-scoped flags read by AppAnalytics on startSession to emit events once.
    private(set) var didGrantCreditThisSession = false
    private(set) var didSpendCreditThisSession = false

    private init() {
        loadStreak()
        loadLifecycleState()
    }

    // MARK: - Session Lifecycle

    /// Final, immutable stats for a session that has ended. Built when a new
    /// session displaces an idle-timed-out one (same process) or when the next
    /// launch reconciles a session the OS killed while backgrounded.
    struct EndedStats {
        let sessionId: String
        let sessionNumber: Int
        let sessionSource: String
        let durationSec: Int
        let activeSec: Int
        let screensVisited: Int
        let maxDepth: Int
        let coreActionsCount: Int
        let reason: String
    }

    /// Runs once per process: the first foreground reconciles a session that was
    /// still open when the app was last backgrounded/killed.
    private var didReconcilePersistedSession = false

    /// Foreground entry point. `isNew == true` means a brand-new session was minted
    /// (the caller fires `session_started` + per-session work); false means the
    /// previous session resumed within the 30-minute idle window. `priorEnd` is set
    /// when minting a new session displaced a still-open one that idle-timed-out in
    /// this same process — the caller must emit its `session_ended` first so the
    /// started/ended pair stays balanced.
    @discardableResult
    func startSession() -> (isNew: Bool, priorEnd: EndedStats?) {
        let now = Date()
        let priorActivity = lastActivityDate
        let idleFor = now.timeIntervalSince(priorActivity)

        // Recomputed every foreground: the singleton is built once per process and
        // a process kept alive across midnight would otherwise evaluate retention
        // milestones against the day it launched on.
        refreshDaysSinceInstall()

        // Resume: still inside the idle window and a session is already open. The
        // background closed the active span; reopen it without resetting state so a
        // quick app-switch stays ONE session (no session_started/session_ended).
        if idleFor < Self.idleTimeoutSec && sessionIsOpen {
            lastActivityDate = now
            if activeSpanStart == nil { activeSpanStart = now }
            // A notification/widget tap that landed while already foregrounded (or
            // inside the idle window) is consumed by THIS session. Leaving the tag
            // armed would stamp the next genuinely-new session with it.
            pendingSessionSource = .organic
            persistOpenSession(now: now)
            return (false, nil)
        }

        // A new session begins. If a prior session is still open (it idle-timed-out
        // while this process stayed alive), close and report it first. Its span was
        // already closed on background; close defensively at the last activity time.
        var priorEnd: EndedStats? = nil
        if sessionIsOpen {
            if let spanStart = activeSpanStart {
                accumulatedActiveSec += priorActivity.timeIntervalSince(spanStart)
                activeSpanStart = nil
            }
            // totalSessions / currentSessionSource still hold the ENDING session's
            // values here — the reset + increment below run only after this capture.
            priorEnd = EndedStats(
                sessionId: sessionId,
                sessionNumber: totalSessions,
                sessionSource: currentSessionSource.rawValue,
                durationSec: max(Int(priorActivity.timeIntervalSince(sessionStartDate)), 0),
                activeSec: max(Int(accumulatedActiveSec.rounded()), 0),
                screensVisited: screensVisited.count,
                maxDepth: maxDepth,
                coreActionsCount: coreActionsThisSession.count,
                reason: EndReason.idleTimeout.rawValue
            )
        }

        lastActivityDate = now
        sessionId = UUID().uuidString
        sessionStartDate = now
        screensVisited = []
        maxDepth = 0
        currentDepth = 0
        lastScreen = nil
        coreActionsThisSession = []
        previousStreakBeforeBreak = nil
        didGrantCreditThisSession = false
        didSpendCreditThisSession = false
        accumulatedActiveSec = 0
        activeSpanStart = now
        sessionIsOpen = true
        currentSessionSource = pendingSessionSource
        pendingSessionSource = .organic // reset for next session
        maybeGrantRestCredit()
        updateStreak()
        updateStickiness()
        updateSessionSourceCounts()
        updateLifecycleOnStart()
        persistOpenSession(now: now)
        return (true, priorEnd)
    }

    /// Called when the app enters the background. Closes the active foreground span
    /// into `accumulatedActiveSec` and snapshots the open session to disk, but does
    /// NOT emit `session_ended` and does NOT clear `sessionIsOpen`: under the resume
    /// model a brief background is still the same session. The end is emitted on the
    /// next foreground (idle timeout) or next launch (after a kill).
    func closeActiveSpanForBackground() {
        let now = Date()
        if let spanStart = activeSpanStart {
            accumulatedActiveSec += now.timeIntervalSince(spanStart)
            activeSpanStart = nil
        }
        lastActivityDate = now
        defaults.set(now, forKey: Key.lastSessionDate)
        persistOpenSession(now: now)
    }

    /// First foreground of a process: if a session was still open when the app was
    /// last backgrounded/killed, build its final stats so the caller can emit the
    /// deferred `session_ended`. Returns nil when there is nothing to reconcile.
    func reconcilePersistedSession(now: Date = Date()) -> EndedStats? {
        guard !didReconcilePersistedSession else { return nil }
        didReconcilePersistedSession = true
        guard let d = defaults.dictionary(forKey: Key.openSession) else { return nil }
        // Clear unconditionally once read: a malformed snapshot (missing/typed-wrong
        // keys) must not survive to be re-read on a later launch.
        clearPersistedOpenSession()
        guard let id = d["id"] as? String,
              let start = d["start"] as? Date,
              let last = d["last"] as? Date else { return nil }
        // Duration is measured to the last recorded activity (the background time),
        // never to "now", so a multi-hour killed gap is not counted as session time.
        let reason: EndReason = now.timeIntervalSince(last) >= Self.idleTimeoutSec ? .idleTimeout : .appTerminated
        return EndedStats(
            sessionId: id,
            sessionNumber: d["number"] as? Int ?? 0,
            sessionSource: d["source"] as? String ?? SessionSource.organic.rawValue,
            durationSec: max(Int(last.timeIntervalSince(start)), 0),
            activeSec: max(Int((d["active"] as? Double ?? 0).rounded()), 0),
            screensVisited: d["screens"] as? Int ?? 0,
            maxDepth: d["depth"] as? Int ?? 0,
            coreActionsCount: d["actions"] as? Int ?? 0,
            reason: reason.rawValue
        )
    }

    /// Snapshot the open session so its end survives an OS kill. Updated on start,
    /// resume, and background; cleared when the `session_ended` is emitted.
    private func persistOpenSession(now: Date) {
        guard sessionIsOpen else { return }
        defaults.set([
            "id": sessionId,
            "number": totalSessions,
            "source": currentSessionSource.rawValue,
            "start": sessionStartDate,
            "last": now,
            "active": accumulatedActiveSec,
            "screens": screensVisited.count,
            "depth": maxDepth,
            "actions": coreActionsThisSession.count
        ] as [String: Any], forKey: Key.openSession)
    }

    private func clearPersistedOpenSession() {
        defaults.removeObject(forKey: Key.openSession)
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

    var currentScreen: String? {
        lastScreen
    }

    func updateDepth(_ depth: Int) {
        currentDepth = depth
        maxDepth = max(maxDepth, depth)
    }

    // MARK: - Streak

    var longestStreak: Int {
        defaults.integer(forKey: Key.longestStreak)
    }

    private func loadStreak() {
        streakDays = defaults.integer(forKey: Key.streakDays)
    }

    private func updateStreak() {
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())

        if let lastDate = defaults.object(forKey: Key.lastActiveDate) as? Date {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 1 {
                streakDays += 1
            } else if daysDiff == 2 {
                // User missed exactly one day — try to forgive with a rest credit.
                // This matches the Gentler Streak / Duolingo "streak freeze" pattern.
                // If no credit is available, the streak breaks as before.
                if spendRestCredit() {
                    streakDays += 1
                } else {
                    previousStreakBeforeBreak = defaults.integer(forKey: Key.streakDays)
                    streakDays = 1
                }
            } else if daysDiff > 2 {
                // Too many days missed — rest credit cannot save a multi-day gap.
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
    /// Returns the milestone day ONLY when today is exactly that day since install.
    /// Every earlier milestone the user skipped is consumed silently in the same
    /// pass: returning the oldest unconsumed one instead (one per session) made a
    /// user who first returned on day 30 emit day=1, then day=2, then day=3 —
    /// which turned D1/D7/D30 into "opened the app an Nth time".
    func checkRetentionMilestone() -> Int? {
        if retentionMilestones.isEmpty,
           let stored = defaults.stringArray(forKey: Key.retentionMilestones) {
            retentionMilestones = Set(stored)
        }

        var reachedToday: Int?
        var changed = false
        for day in [1, 2, 3, 7, 14, 30] where daysSinceInstall >= day {
            let key = "day_\(day)"
            guard !retentionMilestones.contains(key) else { continue }
            retentionMilestones.insert(key)
            changed = true
            if day == daysSinceInstall { reachedToday = day }
        }
        if changed {
            defaults.set(Array(retentionMilestones), forKey: Key.retentionMilestones)
        }
        return reachedToday
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

        refreshDaysSinceInstall()
    }

    private func refreshDaysSinceInstall() {
        let installDate = defaults.object(forKey: Key.installDate) as? Date ?? Date()
        daysSinceInstall = Date.cal.dateComponents([.day], from: installDate, to: Date()).day ?? 0
    }

    private func updateLifecycleOnStart() {
        totalSessions += 1
        isFirstSession = totalSessions == 1
        defaults.set(totalSessions, forKey: Key.totalSessions)
    }

    /// Days since last session (for return session tracking). Returns nil for first session.
    var daysSinceLastSession: Int? {
        guard let lastDate = defaults.object(forKey: Key.lastSessionDate) as? Date else { return nil }
        return Date.cal.dateComponents([.day], from: lastDate, to: Date()).day
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
    /// Returns true ONLY on the first recording, so the caller emits
    /// `time_to_first_value` exactly once instead of re-emitting the session-1
    /// value on every later sync.
    @discardableResult
    func recordFirstValueTime() -> Bool {
        if defaults.bool(forKey: Key.firstValueRecorded) { return false }
        // Installs that recorded a TTFV before this flag existed: adopt the stored
        // value rather than overwriting it with the current session's elapsed,
        // which would ship one bogus time_to_first_value on the upgrade.
        if defaults.integer(forKey: Key.firstValueTimeSec) > 0 {
            defaults.set(true, forKey: Key.firstValueRecorded)
            return false
        }
        defaults.set(true, forKey: Key.firstValueRecorded)
        defaults.set(sessionElapsedSeconds, forKey: Key.firstValueTimeSec)
        return true
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

    // MARK: - Stickiness (Weekly Active Days)

    /// Tracks unique active days in the current ISO calendar week.
    /// Resets when a new week begins.
    private func updateStickiness() {
        let calendar = Date.cal
        let today = calendar.startOfDay(for: Date())
        let currentWeek = calendar.component(.weekOfYear, from: today)
        let currentYear = calendar.component(.yearForWeekOfYear, from: today)

        // Load stored data: [year, week, day1Timestamp, day2Timestamp, ...]
        var storedDays = defaults.array(forKey: AppKeys.Session.weeklyActiveDaysData) as? [Double] ?? []

        let storedYear = storedDays.count >= 2 ? Int(storedDays[0]) : 0
        let storedWeek = storedDays.count >= 2 ? Int(storedDays[1]) : 0

        if storedYear != currentYear || storedWeek != currentWeek {
            // New week. reset
            storedDays = [Double(currentYear), Double(currentWeek), today.timeIntervalSince1970]
        } else {
            // Same week. add today if not already present
            let existingDays = storedDays.dropFirst(2).map { Date(timeIntervalSince1970: $0) }
            let alreadyRecorded = existingDays.contains { calendar.isDate($0, inSameDayAs: today) }
            if !alreadyRecorded {
                storedDays.append(today.timeIntervalSince1970)
            }
        }

        weeklyActiveDays = storedDays.count - 2 // subtract year + week entries
        defaults.set(storedDays, forKey: AppKeys.Session.weeklyActiveDaysData)
        defaults.set(weeklyActiveDays, forKey: AppKeys.Session.weeklyActiveDays)
    }

    // MARK: - Session Source Counts (for organic %)

    var organicSessionCount: Int {
        defaults.integer(forKey: AppKeys.Session.organicSessions)
    }

    var notificationSessionCount: Int {
        defaults.integer(forKey: AppKeys.Session.notifSessions)
    }

    var widgetSessionCount: Int {
        defaults.integer(forKey: AppKeys.Session.widgetSessions)
    }

    var liveActivitySessionCount: Int {
        defaults.integer(forKey: Key.liveActivitySessions)
    }

    /// Percentage of sessions that were organic (0-100).
    var organicSessionPercent: Int {
        let total = organicSessionCount + notificationSessionCount
            + widgetSessionCount + liveActivitySessionCount
        guard total > 0 else { return 100 }
        return (organicSessionCount * 100) / total
    }

    private func updateSessionSourceCounts() {
        switch currentSessionSource {
        case .organic:
            defaults.set(organicSessionCount + 1, forKey: AppKeys.Session.organicSessions)
        case .notification:
            defaults.set(notificationSessionCount + 1, forKey: AppKeys.Session.notifSessions)
        case .widget:
            defaults.set(widgetSessionCount + 1, forKey: AppKeys.Session.widgetSessions)
        case .liveActivity:
            defaults.set(liveActivitySessionCount + 1, forKey: Key.liveActivitySessions)
        }
    }
}
