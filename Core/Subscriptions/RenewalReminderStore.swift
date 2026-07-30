import Foundation

/// Decides whether today's first launch should surface the pre renewal reminder.
///
/// The reminder repeats on the first launch of every day inside the window and
/// stops on its own: once the period rolls over, the new renewal date is further
/// out than the window, so `reminder(for:)` returns nil without any extra flag to
/// clear. Nothing here needs resetting when the user renews.
@MainActor
enum RenewalReminderStore {

    /// What the sheet needs to draw itself, resolved from live subscription state.
    struct Reminder: Equatable {
        let renewalDate: Date
        /// Days from today to the renewal, floored at 0 so a same-day renewal
        /// reads as "today" rather than a negative count.
        let daysRemaining: Int
        /// True when the user will be charged automatically and the useful action
        /// is cancelling; false when access will lapse unless they renew.
        let willAutoRenew: Bool
    }

    private static var defaults: UserDefaults { .standard }

    /// The reminder to show right now, or nil when there is nothing to say.
    ///
    /// Returns nil when the feature is off, when the user is not on a renewing
    /// period, when the renewal is further out than the window, or when today's
    /// reminder has already been shown. `willAutoRenew` being nil means StoreKit
    /// could not tell us which way the charge will go, and the app stays quiet
    /// rather than warn about the wrong outcome.
    static func reminder(for manager: SubscriptionManager, now: Date = Date()) -> Reminder? {
        guard RemoteConfigManager.shared.renewalReminderEnabled,
              let renewalDate = manager.renewalDate,
              let willAutoRenew = manager.willAutoRenew,
              renewalDate > now,
              !shownToday(now: now) else { return nil }

        // Whole calendar days, so "3 days before" means the same thing regardless
        // of the clock time the user happens to open the app.
        let days = Date.cal.dateComponents(
            [.day],
            from: Date.cal.startOfDay(for: now),
            to: Date.cal.startOfDay(for: renewalDate)
        ).day ?? 0

        guard days <= RemoteConfigManager.shared.renewalReminderDaysBefore else { return nil }

        return Reminder(
            renewalDate: renewalDate,
            daysRemaining: max(0, days),
            willAutoRenew: willAutoRenew
        )
    }

    static func markShownToday(now: Date = Date()) {
        defaults.set(now, forKey: AppKeys.Billing.renewalReminderShownDate)
    }

    private static func shownToday(now: Date) -> Bool {
        guard let last = defaults.object(forKey: AppKeys.Billing.renewalReminderShownDate) as? Date else {
            return false
        }
        return Date.cal.isDate(last, inSameDayAs: now)
    }
}
