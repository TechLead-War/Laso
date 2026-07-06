import Foundation
import UserNotifications

/// Manages scheduling and canceling local notifications
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let frequencyCap = FrequencyCapManager()
    private let fatigueTracker = NotificationFatigueTracker()

    /// Serializes the frequency-cap + same-day-competition accounting.
    /// Schedulers call `scheduleNotification` from the main actor AND from
    /// detached tasks; the underlying UserDefaults state is read-modify-write,
    /// so without this two concurrent schedules could both win a day or
    /// double-spend the cap.
    private let gateLock = NSLock()

    /// Data store for notification event tracking (set at app launch)
    var store: HealthDataStore?

    /// Cached authorization state, refreshed by `requestAuthorization` and
    /// `isCurrentlyAuthorized`. Lets `scheduleNotification` short-circuit a
    /// non-critical schedule synchronously instead of awaiting the OS each
    /// time. Defaults to `false`; the launch path MUST call
    /// `isCurrentlyAuthorized()` before the first non-critical schedule so a
    /// genuinely-authorized user is not wrongly suppressed at startup.
    private var cachedAuthorized = false

    /// iOS keeps at most 64 pending local notifications; the oldest are
    /// silently dropped past that. Warn before the cap so a runaway scheduler
    /// is caught in analytics rather than failing invisibly.
    /// SOURCE: UNUserNotificationCenter 64-pending-request limit.
    private static let pendingWarnThreshold = 56

    private init() {}

    /// `true` while non-critical notifications are suppressed because the
    /// user has dismissed-without-opening recent ones. Critical and daily
    /// summary notifications continue to schedule.
    var isInFatigueSuppressionWindow: Bool {
        fatigueTracker.isInFatigueSuppressionWindow
    }

    /// Hook for AppDelegate / scene lifecycle to signal an app open.
    /// Resets the dismiss-without-open streak if the open falls inside
    /// the response window after a non-critical notification fire.
    func recordAppOpen() {
        fatigueTracker.recordAppOpen()
    }

    /// Derive an analytics bucket from a notification identifier.
    ///
    /// Buckets are matched to the feature that emits each identifier. The three
    /// exact-match summary ids are checked before the prefixes because a prefix
    /// could otherwise shadow them. Prefixes resolve through the shared
    /// `AppConstants.NotificationID` constants so the identifier scheme has one
    /// source of truth.
    static func notificationType(_ identifier: String) -> String {
        let id = AppConstants.NotificationID.self

        if identifier == id.dailySummary { return "daily_summary" }
        if identifier == id.eveningSummary { return "evening_summary" }
        if identifier == id.windDown { return "wind_down" }
        if identifier == id.answerReady { return "answer_ready" }
        if identifier == id.repermission { return "repermission" }
        if identifier == id.nonTrialWelcome { return "non_trial_welcome" }
        if identifier == id.cancelledSave { return "cancelled_save" }
        if id.abandonmentAll.contains(identifier) { return "onboarding_abandonment" }
        if id.trialAll.contains(identifier) { return "trial" }

        if identifier.hasPrefix(id.triagePrefix) { return "safety_triage" }
        if identifier.hasPrefix(id.spikePrefix) { return "spike" }
        if identifier.hasPrefix(id.reversalPrefix) { return "trend_reversal" }
        if identifier.hasPrefix(id.celebrationPrefix) { return "celebration" }
        if identifier.hasPrefix(id.alertPrefix) { return "alert" }
        if identifier.hasPrefix(id.engagementPrefix) { return "engagement" }

        if identifier.hasPrefix(id.intelligencePrefix) { return "intelligence" }
        // No AppConstants prefix constant exists for these two yet; match the
        // raw identifier prefix until/unless constants are introduced.
        if identifier.hasPrefix("healthpulse.watch.") { return "watch_monitor" }
        if identifier.hasPrefix("healthpulse.weekly") { return "weekly_summary" }
        if identifier.hasPrefix("healthpulse.reengagement") { return "reengagement" }

        return "other"
    }

    /// Request notification authorization
    @discardableResult
    func requestAuthorization(source: String = "system") async -> Bool {
        await MainActor.run {
            AppAnalytics.shared.trackNotificationPermissionRequested(source: source)
        }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            cachedAuthorized = granted
            await MainActor.run {
                AppAnalytics.shared.updateNotificationProperties(enabled: granted)
                AppAnalytics.shared.trackNotificationPermissionResult(granted: granted, source: source)
            }
            return granted
        } catch {
            cachedAuthorized = false
            await MainActor.run {
                AppAnalytics.shared.updateNotificationProperties(enabled: false)
                AppAnalytics.shared.trackNotificationPermissionResult(granted: false, source: source)
            }
            #if DEBUG
            print("Notification authorization failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// `true` when the OS-level authorization status is `.notDetermined`,
    /// meaning we have never asked the user. Used by the launch fallback in
    /// `ContentView` to recover users who completed onboarding without going
    /// through the Apple Sign-In success branch (which is the only place the
    /// onboarding-time prompt fires).
    func shouldRequestAuthorizationOnLaunch() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .notDetermined
    }

    /// Check whether notifications are currently authorized without prompting the user.
    func isCurrentlyAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            cachedAuthorized = true
            await MainActor.run { AppAnalytics.shared.updateNotificationProperties(enabled: true) }
            return true
        case .notDetermined, .denied:
            cachedAuthorized = false
            await MainActor.run { AppAnalytics.shared.updateNotificationProperties(enabled: false) }
            return false
        @unknown default:
            cachedAuthorized = false
            await MainActor.run { AppAnalytics.shared.updateNotificationProperties(enabled: false) }
            return false
        }
    }

    /// Schedule a notification if within frequency cap and optimizer budget.
    /// The daily summary (repeating calendar trigger) is the only notification that bypasses the cap.
    /// All other notifications are hard-capped and optimized for priority and fatigue.
    ///
    /// Returns `true` only when the request was handed to the notification
    /// center. Callers that burn one-shot flags MUST check this so a gate
    /// suppression does not permanently consume the flag.
    @discardableResult
    func scheduleNotification(
        title: String,
        body: String,
        identifier: String,
        trigger: UNNotificationTrigger? = nil,
        maxPerDay: Int = 1,
        severity: Severity = .info,
        deviationPercent: Double = 0,
        metricInFocus: Bool = false,
        bypassCap: Bool = false,
        hookCategory: String? = nil,
        respectsQuietHours: Bool = true
    ) -> Bool {
        let isDailySummary = identifier == AppConstants.NotificationID.dailySummary
            || identifier == AppConstants.NotificationID.eveningSummary

        let notifType = Self.notificationType(identifier)

        // The trigger's true fire date drives the quiet-hours guard, the
        // fatigue open-response window, and all per-day accounting (cap and
        // same-day competition key on the day the notification FIRES, not the
        // day it was scheduled). A nil trigger fires immediately.
        var fireDate = fireDate(for: trigger)
        var effectiveTrigger = trigger

        // Authorization gate. A non-critical schedule is pointless if the user
        // has not granted permission; suppress it loudly so analytics show why.
        // Critical (life-safety) notifications are never gated by this flag.
        if !cachedAuthorized && severity != .critical {
            Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "not_authorized") }
            return false
        }

        // Kill switch. remotely disable all notifications except critical
        // health alerts. bypassCap only exempts from the frequency cap, never
        // from the kill switch.
        if RemoteConfigManager.shared.killNotifications && severity != .critical {
            Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "kill_switch") }
            return false
        }

        // Everything except daily summaries and bypassed notifications is capped and optimized
        if !isDailySummary && !bypassCap {
            // Priority filtering. skip low-priority unless critical
            let priority = NotificationOptimizer.priorityScore(
                severity: severity,
                deviationPercent: deviationPercent,
                metricInFocus: metricInFocus
            )
            let minPriority = RemoteConfigManager.shared.notificationMinPriorityScore
            if priority < minPriority && severity != .critical {
                Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "low_priority") }
                return false
            }

            // Fatigue suppression. after N consecutive dismiss-without-open
            // events on non-critical notifications, suppress non-critical
            // notifications for a cool-down window. Critical severity and
            // daily summaries bypass this layer (explicit opt-ins).
            fatigueTracker.evaluateDismissStreakLazy()
            if severity != .critical && fatigueTracker.isInFatigueSuppressionWindow {
                Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "fatigue_suppression") }
                return false
            }

            // Quiet-hours guard. A non-critical one-shot whose fire time lands
            // inside the do-not-disturb window is DEFERRED to the window's end
            // (e.g. 23:30 -> 07:00 next morning), not dropped. Repeating
            // triggers cannot be deferred without losing their repetition, so
            // they keep the old drop behavior. Schedulers whose timing is
            // deliberately bedtime-aware (wind-down) opt out entirely via
            // `respectsQuietHours: false`.
            if severity != .critical && respectsQuietHours && isWithinQuietHours(fireDate) {
                if trigger?.repeats == true {
                    Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "quiet_hours") }
                    return false
                }
                let deferred = quietHoursAdjusted(fireDate)
                var comps = Date.cal.dateComponents([.year, .month, .day, .hour, .minute], from: deferred)
                comps.calendar = Date.cal
                effectiveTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                fireDate = deferred
                AnalyticsBackend.provider.capture(event: "notification_deferred_quiet_hours", properties: [
                    "notification_id": identifier,
                    "type": notifType
                ])
            }

            // Same-fire-day competition + cap accounting, serialized under one
            // lock (schedulers call from more than one executor and the
            // UserDefaults-backed state is read-modify-write).
            let dynamicBudget = resolveDailyBudget(identifier: identifier, staticBudget: maxPerDay)
            guard reserveFireDaySlot(
                identifier: identifier,
                notifType: notifType,
                priority: priority,
                severity: severity,
                budget: dynamicBudget,
                fireDate: fireDate
            ) else {
                return false
            }
        }

        // Warn when pending notifications near the iOS cap; a runaway scheduler
        // would otherwise silently lose the oldest requests.
        Task { [weak self] in
            guard let self else { return }
            let pending = await self.pendingNotificationCount()
            if pending >= Self.pendingWarnThreshold {
                AnalyticsBackend.provider.captureError(
                    "pending notifications near iOS limit",
                    context: "notification_pending_cap",
                    metadata: ["pending": pending, "notification_id": identifier]
                )
            }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: effectiveTrigger
        )

        center.add(request) { [weak self] error in
            if let error {
                // The schedule failed to enqueue. Refund the reserved slot and
                // the committed best-candidate entry (only the capped path
                // wrote either) and report loudly so the failure is visible in
                // analytics rather than silently swallowed.
                if let self, !isDailySummary, !bypassCap {
                    self.gateLock.lock()
                    self.frequencyCap.releaseSlot(at: fireDate)
                    if severity != .critical {
                        self.fatigueTracker.clearBest(identifier: identifier, fireDate: fireDate)
                    }
                    self.gateLock.unlock()
                }
                AnalyticsBackend.provider.captureError(error, context: "notification_schedule", metadata: [
                    "notification_id": identifier,
                    "type": notifType
                ])
                Task { @MainActor in
                    AppAnalytics.shared.trackNotificationFailed(type: notifType, identifier: identifier, error: error.localizedDescription)
                }
            } else {
                if !isDailySummary {
                    // Record for the dismiss-without-open streak (critical is ignored
                    // inside the tracker). Daily summaries bypass both cap and streak.
                    // Stamp the true fire date so the open-response window measures
                    // from when the notification fires, not when it was scheduled.
                    self?.fatigueTracker.recordFired(identifier: identifier, severity: severity, firedAt: fireDate)
                }

                // Record the send event for optimizer tracking.
                // HealthDataStore is @MainActor. dispatch to main actor for the write.
                if let store = self?.store {
                    Task { @MainActor in
                        store.recordNotificationSent(id: identifier, type: notifType)
                    }
                }
                Task { @MainActor in
                    AppAnalytics.shared.trackNotificationScheduled(type: notifType, identifier: identifier, hookCategory: hookCategory)
                }
            }
        }
        return true
    }

    /// Same-fire-day competition and cap accounting under `gateLock`.
    /// Returns `true` when the notification won its fire day (or is critical)
    /// AND reserved a cap slot; the winner is committed as the day's best only
    /// after the reserve succeeds, so a candidate that fails the cap never
    /// poisons the stored best.
    ///
    /// Order matters: eviction of a still-pending lower-priority holder runs
    /// BEFORE the cap reserve so the freed slot is available to the winner —
    /// the reverse order dropped a higher-priority notification whenever its
    /// fire day was already full.
    private func reserveFireDaySlot(
        identifier: String,
        notifType: String,
        priority: Int,
        severity: Severity,
        budget: Int,
        fireDate: Date
    ) -> Bool {
        gateLock.lock()
        defer { gateLock.unlock() }

        if severity != .critical {
            switch fatigueTracker.peekSameDayPriority(identifier: identifier, priority: priority, fireDate: fireDate) {
            case .reject:
                Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "priority_pushed_down") }
                return false
            case .accept(let previous):
                // Evict only a still-PENDING previous holder: cancel it, refund
                // its exact slot, and forget its fired stamp so it cannot read
                // as dismissed. An already-delivered previous (fire time in the
                // past) is left alone — its slot was genuinely consumed and the
                // user really saw it.
                if let previous, previous.fireDate > Date() {
                    center.removePendingNotificationRequests(withIdentifiers: [previous.identifier])
                    frequencyCap.releaseSlot(at: previous.fireDate)
                    fatigueTracker.clearFired(identifier: previous.identifier)
                    let previousType = Self.notificationType(previous.identifier)
                    Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: previousType, identifier: previous.identifier, reason: "priority_pushed_down") }
                }
            }
        }

        guard frequencyCap.reserveSlot(maxPerDay: budget, fireDate: fireDate) else {
            Task { @MainActor in AppAnalytics.shared.trackNotificationSuppressed(type: notifType, identifier: identifier, reason: "frequency_cap") }
            return false
        }

        if severity != .critical {
            fatigueTracker.commitSameDayBest(identifier: identifier, priority: priority, fireDate: fireDate)
        }
        return true
    }

    /// Dynamic per-day budget from the optimizer's fatigue detection.
    /// HealthDataStore is @MainActor. use assumeIsolated when on main thread,
    /// otherwise fall back to the static per-call budget.
    private func resolveDailyBudget(identifier: String, staticBudget: Int) -> Int {
        if let store, Thread.isMainThread {
            return MainActor.assumeIsolated {
                NotificationOptimizer.dailyBudget(events: store.loadNotificationEvents(days: 7))
            }
        }
        // Breadcrumb: the dynamic budget could not be computed (no store
        // or off the main thread) so the static per-call budget is used.
        AnalyticsBackend.provider.capture(event: "notification_budget_fallback", properties: [
            "notification_id": identifier,
            "reason": store == nil ? "no_store" : "off_main_thread",
            "static_budget": staticBudget
        ])
        return staticBudget
    }

    /// Cancel a specific notification
    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    /// Get pending notification count
    func pendingNotificationCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.count
    }

    /// The date a trigger will fire, or now for an immediate (nil) trigger.
    /// Calendar and time-interval triggers both expose `nextTriggerDate()`.
    private func fireDate(for trigger: UNNotificationTrigger?) -> Date {
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate() ?? Date()
        }
        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return intervalTrigger.nextTriggerDate() ?? Date()
        }
        return Date()
    }

    /// The earliest delivery time at or after `date` that is outside quiet
    /// hours: `date` itself when already outside, otherwise the next
    /// occurrence of the window's end hour (e.g. 23:30 -> 07:00 next day,
    /// 02:00 -> 07:00 same day). Shared by the defer gate and by schedulers
    /// that build their own requests (re-engagement).
    func quietHoursAdjusted(_ date: Date) -> Date {
        guard isWithinQuietHours(date) else { return date }
        let endHour = RemoteConfigManager.shared.quietHoursEndHour
        var comps = Date.cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = endHour
        comps.minute = 0
        guard let sameDayEnd = Date.cal.date(from: comps) else { return date }
        if sameDayEnd > date { return sameDayEnd }
        return Date.cal.date(byAdding: .day, value: 1, to: sameDayEnd) ?? date
    }

    /// Whether `date`'s local hour falls inside the do-not-disturb window from
    /// Remote Config. Handles an overnight window (start > end) by wrapping.
    private func isWithinQuietHours(_ date: Date) -> Bool {
        let start = RemoteConfigManager.shared.quietHoursStartHour
        let end = RemoteConfigManager.shared.quietHoursEndHour
        let hour = Date.cal.component(.hour, from: date)
        if start <= end {
            return hour >= start && hour < end
        }
        // Overnight window, e.g. 22:00–07:00.
        return hour >= start || hour < end
    }
}
