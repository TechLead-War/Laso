import Foundation

/// Tracks notification fatigue signals and resolves same-day priority
/// competition between eligible non-critical notifications.
///
/// Two layers are managed here:
///
/// 1. Dismiss-without-open streak:
///    When a non-critical notification fires and the user does not open the
///    app within `AppConstants.NotificationFatigue.openResponseWindow`, we
///    treat it (lazily, at the next schedule attempt) as a dismiss. After
///    `dismissStreakThreshold` consecutive dismisses, all non-critical
///    notifications are suppressed for `suppressionDuration`.
///
/// 2. Same-day priority resolution:
///    When two eligible non-critical notifications will FIRE on the same
///    calendar day, only the higher-priority one fires. The lower one is
///    dropped and reported via analytics with `reason: "priority_pushed_down"`.
///
/// Persistence lives in `UserDefaults.standard` under the keys defined in
/// `AppKeys.Notifications`. All access is main-thread safe; UserDefaults is
/// itself thread-safe for scalar reads/writes.
struct NotificationFatigueTracker {

    // MARK: Dependencies

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    // MARK: Fatigue suppression window

    /// `true` when non-critical notifications should currently be skipped
    /// because the user has dismissed-without-opening the threshold number
    /// of recent non-critical notifications.
    var isInFatigueSuppressionWindow: Bool {
        guard let until = suppressionUntil else { return false }
        return until > Date()
    }

    /// Lazily materialize a dismiss event if the last fired non-critical
    /// notification is now older than the open-response window and no app
    /// open was recorded inside that window. Safe to call repeatedly; each
    /// unique fired identifier is counted at most once.
    ///
    /// Returns the updated suppression-window flag so callers can short-circuit.
    @discardableResult
    func evaluateDismissStreakLazy(now: Date = Date()) -> Bool {
        // `lastNonCriticalFiredId` is required so we don't count a fire we've
        // already consumed. Its value itself isn't needed downstream — only
        // the presence signal.
        guard
            let firedAt = lastNonCriticalFiredAt,
            lastNonCriticalFiredId != nil
        else { return isInFatigueSuppressionWindow }

        let window = AppConstants.NotificationFatigue.openResponseWindow
        let elapsed = now.timeIntervalSince(firedAt)
        guard elapsed >= window else { return isInFatigueSuppressionWindow }

        // If the user opened the app inside the response window, the fire
        // was "responded to": reset the streak and consume the fire.
        if let opened = lastAppOpenedAt,
           opened >= firedAt,
           opened.timeIntervalSince(firedAt) <= window {
            setStreak(0)
            clearLastFired()
            return isInFatigueSuppressionWindow
        }

        // Otherwise, count one dismiss and consume the fire so we don't
        // double-count on the next call.
        let newStreak = currentStreak + 1
        setStreak(newStreak)
        clearLastFired()

        if newStreak >= AppConstants.NotificationFatigue.dismissStreakThreshold {
            let until = now.addingTimeInterval(AppConstants.NotificationFatigue.suppressionDuration)
            defaults.set(until.timeIntervalSince1970, forKey: AppKeys.Notifications.fatigueSuppressionUntil)
            // Reset streak so a new streak can build after the window ends.
            setStreak(0)
        }

        return isInFatigueSuppressionWindow
    }

    /// Record that a notification was just fired. Critical notifications do
    /// not contribute to the dismiss streak.
    ///
    /// `firedAt` is the trigger's true fire date (not the schedule time) so the
    /// open-response window measures from when the notification actually fires.
    func recordFired(identifier: String, severity: Severity, firedAt: Date = Date()) {
        guard severity != .critical else { return }
        defaults.set(firedAt.timeIntervalSince1970, forKey: AppKeys.Notifications.lastNonCriticalFiredAt)
        defaults.set(identifier, forKey: AppKeys.Notifications.lastNonCriticalFiredId)
    }

    /// Record that the user opened the app. If the open falls inside the
    /// response window after the last fired non-critical notification, the
    /// streak resets immediately (successful response).
    func recordAppOpen(now: Date = Date()) {
        defaults.set(now.timeIntervalSince1970, forKey: AppKeys.Notifications.lastAppOpenedAt)

        guard let firedAt = lastNonCriticalFiredAt else { return }
        let window = AppConstants.NotificationFatigue.openResponseWindow
        if now.timeIntervalSince(firedAt) <= window {
            setStreak(0)
            clearLastFired()
        }
    }

    // MARK: Same-day priority resolution

    /// Result of asking "is this candidate the best eligible non-critical
    /// notification firing that day?"
    enum SameDayDecision {
        /// Candidate is a new best — schedule it. If `previous` is set, that
        /// notification currently holds the day; a still-pending one should be
        /// cancelled and reported as `"priority_pushed_down"` (its fire date
        /// tells the caller whether it is pending or already delivered).
        case accept(previous: (identifier: String, fireDate: Date)?)
        /// Candidate loses to a higher-priority notification already holding
        /// the day. Caller should drop it and report `"priority_pushed_down"`.
        case reject
    }

    /// Pure read: decide whether `identifier` would win its fire day. Writes
    /// nothing — the caller commits the winner with `commitSameDayBest` only
    /// after the remaining gates (frequency cap) also pass, so a candidate
    /// that later fails a gate never poisons the day's stored best.
    /// Competition is per fire day: two notifications firing on different
    /// days never compete, even when scheduled in the same session.
    /// Only call for non-critical, non-daily-summary, non-bypass notifications.
    func peekSameDayPriority(
        identifier: String,
        priority: Int,
        fireDate: Date = Date()
    ) -> SameDayDecision {
        let bestByDay = loadBestByDay(now: Date())

        guard let stored = bestByDay[dayKey(for: fireDate)],
              let parsed = Self.parseBest(stored)
        else {
            return .accept(previous: nil)
        }

        if priority > parsed.priority {
            return .accept(previous: parsed.identifier == identifier
                ? nil
                : (parsed.identifier, parsed.fireDate))
        }

        // Same identifier re-scheduled at same/lower priority — treat as a
        // benign re-schedule (accept without replacement marker).
        if parsed.identifier == identifier {
            return .accept(previous: nil)
        }

        return .reject
    }

    /// Persist `identifier` as its fire day's best candidate. The stored fire
    /// date lets a later eviction refund the exact frequency-cap entry and
    /// distinguish a pending previous from an already-delivered one.
    func commitSameDayBest(identifier: String, priority: Int, fireDate: Date) {
        var bestByDay = loadBestByDay(now: Date())
        let key = dayKey(for: fireDate)
        // A same-identifier benign re-schedule at lower priority must not
        // lower the stored bar for other candidates.
        if let stored = bestByDay[key], let parsed = Self.parseBest(stored),
           parsed.identifier != identifier, parsed.priority >= priority {
            return
        }
        bestByDay[key] = "\(priority)|\(fireDate.timeIntervalSinceReferenceDate)|\(identifier)"
        saveBestByDay(bestByDay)
    }

    /// Roll back a committed best candidate whose schedule failed to enqueue,
    /// so it does not keep rejecting lower-priority notifications for a fire
    /// day it will never occupy. Only clears when the entry still belongs to
    /// `identifier`.
    func clearBest(identifier: String, fireDate: Date) {
        var bestByDay = loadBestByDay(now: Date())
        let key = dayKey(for: fireDate)
        guard let stored = bestByDay[key], let parsed = Self.parseBest(stored),
              parsed.identifier == identifier else { return }
        bestByDay.removeValue(forKey: key)
        saveBestByDay(bestByDay)
    }

    /// Forget the last-fired stamp when it belongs to `identifier`. Called when
    /// a pending request is evicted before delivery so a notification the user
    /// never saw cannot later be counted as dismissed-without-open.
    func clearFired(identifier: String) {
        guard lastNonCriticalFiredId == identifier else { return }
        clearLastFired()
    }

    // MARK: - Private: persisted getters/setters

    private var lastNonCriticalFiredAt: Date? {
        let ts = defaults.double(forKey: AppKeys.Notifications.lastNonCriticalFiredAt)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    private var lastNonCriticalFiredId: String? {
        defaults.string(forKey: AppKeys.Notifications.lastNonCriticalFiredId)
    }

    private var lastAppOpenedAt: Date? {
        let ts = defaults.double(forKey: AppKeys.Notifications.lastAppOpenedAt)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    private var currentStreak: Int {
        defaults.integer(forKey: AppKeys.Notifications.dismissWithoutOpenStreak)
    }

    private var suppressionUntil: Date? {
        let ts = defaults.double(forKey: AppKeys.Notifications.fatigueSuppressionUntil)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    private func setStreak(_ value: Int) {
        defaults.set(value, forKey: AppKeys.Notifications.dismissWithoutOpenStreak)
    }

    private func clearLastFired() {
        defaults.removeObject(forKey: AppKeys.Notifications.lastNonCriticalFiredAt)
        defaults.removeObject(forKey: AppKeys.Notifications.lastNonCriticalFiredId)
    }

    /// Per-fire-day best candidates: `[dayKey: "priority|identifier"]`.
    /// Past days are pruned on load (the zero-padded key format sorts
    /// lexicographically). A legacy single-string value under the same key
    /// fails the dictionary read and is treated as empty — a one-time reset.
    private func loadBestByDay(now: Date) -> [String: String] {
        let stored = defaults.dictionary(forKey: AppKeys.Notifications.sameDayBestCandidate) as? [String: String] ?? [:]
        let todayKey = dayKey(for: now)
        return stored.filter { $0.key >= todayKey }
    }

    private func saveBestByDay(_ bestByDay: [String: String]) {
        defaults.set(bestByDay, forKey: AppKeys.Notifications.sameDayBestCandidate)
    }

    private func dayKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Entry format: `"priority|fireEpoch|identifier"` (epoch = seconds since
    /// reference date). Identifiers contain no `|`. A legacy 2-field entry
    /// fails the parse and is treated as absent — a one-time reset.
    private static func parseBest(_ raw: String) -> (priority: Int, fireDate: Date, identifier: String)? {
        let parts = raw.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        guard let priority = Int(parts[0]), let epoch = Double(parts[1]) else { return nil }
        return (priority, Date(timeIntervalSinceReferenceDate: epoch), String(parts[2]))
    }
}
