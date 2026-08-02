import Foundation
import Observation

/// Decides when the Mirror Moment sheet (the once-a-day capture prompt on the
/// first home open) may appear, and remembers how the user answered.
///
/// Every rule here is deliberate and sourced in the Mirror Moment brief:
/// - One impression per calendar day, never re-shown after a dismissal. Once
///   daily is both the peak-compliance band (EMA meta-analysis) and the
///   clinically safe self-viewing dose (PLOS One body checking experiment).
/// - Three straight dismissals silence the sheet for a week; the home toolbar
///   shows a passive dot instead. Users who keep declining include exactly the
///   people the body image literature says must never be pressured.
/// - A lapsed user (no capture for two weeks) is only re-invited on a fresh
///   start day: Monday or the 1st (Dai, Milkman & Riis 2014).
/// - Daily titles rotate because repeating yesterday's message measurably
///   wears out (Duolingo KDD 2020).
@MainActor
@Observable
final class MirrorMomentManager {

    static let shared = MirrorMomentManager()

    /// Dismissals in a row before the sheet goes quiet.
    static let dismissalsBeforeQuiet = 3
    /// How long the quiet period lasts.
    static let quietDays = 7
    /// No capture for this many days means the user has lapsed.
    static let lapsedAfterDays = 14

    private let defaults = UserDefaults.standard
    private let store = MirrorPhotoStore.shared

    /// Bumped on every state change so views observing this manager refresh.
    private(set) var revision = 0

    private init() {}

    // MARK: - The one question Home asks

    /// True when the sheet should be presented right now. Calling this does NOT
    /// stamp anything; call `markShown()` when the sheet actually appears.
    func shouldShow(cameraAvailable: Bool, now: Date = .now) -> Bool {
        if UITestMode.forceMirrorMoment { return true }
        guard cameraAvailable else { return false }
        guard !optedOut else { return false }
        guard !store.hasPhoto(on: now) else { return false }

        let todayKey = MirrorPhotoStore.dayKey(for: now)
        guard defaults.string(forKey: AppKeys.Mirror.momentLastShownDay) != todayKey else { return false }

        if let quietUntil = quietUntil, quietUntil > now { return false }

        // Lapsed users are recoverable at the next landmark, not the next
        // nag. New users (no captures yet) are not lapsed.
        if let lastCapture = store.allDays.last,
           lastCapture.daysBetween(now) >= Self.lapsedAfterDays,
           !isFreshStartDay(now) {
            return false
        }
        return true
    }

    /// Stamp today as shown, so the sheet can never appear twice in one day
    /// (and never again in this session after a swipe-down).
    func markShown(now: Date = .now) {
        defaults.set(MirrorPhotoStore.dayKey(for: now), forKey: AppKeys.Mirror.momentLastShownDay)
        store.syncWidgetSnapshot()
        revision += 1
    }

    // MARK: - Outcomes

    var needsFirstRun: Bool {
        !defaults.bool(forKey: AppKeys.Mirror.momentFirstRunSeen)
    }

    func recordCommit() {
        defaults.set(true, forKey: AppKeys.Mirror.momentFirstRunSeen)
        resetDismissals()
        revision += 1
    }

    /// Any dismissal: "Not today", "Maybe later", or a swipe-down. Also
    /// stamps the dismissal's own day: a sheet shown at 23:58 and declined at
    /// 00:01 must not reappear on the next foreground minutes later.
    func recordDismissal(now: Date = .now) {
        defaults.set(MirrorPhotoStore.dayKey(for: now), forKey: AppKeys.Mirror.momentLastShownDay)
        defaults.set(true, forKey: AppKeys.Mirror.momentFirstRunSeen)
        let streak = defaults.integer(forKey: AppKeys.Mirror.momentDismissStreak) + 1
        if streak >= Self.dismissalsBeforeQuiet {
            let until = Date.cal.date(byAdding: .day, value: Self.quietDays, to: now) ?? now
            defaults.set(until.timeIntervalSince1970, forKey: AppKeys.Mirror.momentQuietUntil)
            defaults.set(0, forKey: AppKeys.Mirror.momentDismissStreak)
        } else {
            defaults.set(streak, forKey: AppKeys.Mirror.momentDismissStreak)
        }
        revision += 1
    }

    /// A capture from any entry point ends the quiet period and the dismissal
    /// count: the user is engaged again. Also drops today's pending reminder,
    /// which has nothing left to remind about.
    func recordCaptured() {
        defaults.set(true, forKey: AppKeys.Mirror.momentFirstRunSeen)
        resetDismissals()
        MirrorReminderScheduler.refreshIfEnabled()
        revision += 1
    }

    var optedOut: Bool {
        get { defaults.bool(forKey: AppKeys.Mirror.momentOptedOut) }
        set {
            defaults.set(newValue, forKey: AppKeys.Mirror.momentOptedOut)
            revision += 1
        }
    }

    /// During a quiet period the sheet stays away and the home toolbar camera
    /// wears a small dot instead, until today is captured.
    func showsQuietBadge(now: Date = .now) -> Bool {
        guard !optedOut, let quietUntil = quietUntil, quietUntil > now else { return false }
        return !store.hasPhoto(on: now)
    }

    // MARK: - Sheet content

    /// Today's rotating title. Picked once per day and then stable, so the
    /// sheet does not change words mid-session.
    func dailyTitle(now: Date = .now) -> String {
        let titles = Copy.Mirror.momentTitles
        let todayKey = MirrorPhotoStore.dayKey(for: now)
        if defaults.string(forKey: AppKeys.Mirror.momentCopyVariantDay) == todayKey {
            let index = defaults.integer(forKey: AppKeys.Mirror.momentCopyVariant)
            return titles[index % titles.count]
        }
        let next = (defaults.integer(forKey: AppKeys.Mirror.momentCopyVariant) + 1) % titles.count
        defaults.set(next, forKey: AppKeys.Mirror.momentCopyVariant)
        defaults.set(todayKey, forKey: AppKeys.Mirror.momentCopyVariantDay)
        return titles[next]
    }

    /// The eyebrow metric. While a streak lives it is the hero; after a break
    /// the streak number is never shown as zero.
    func eyebrow(now: Date = .now) -> String {
        let streak = store.currentStreak
        return streak > 0 ? Copy.Mirror.momentEyebrowDay(streak + 1) : Copy.Mirror.momentEyebrow
    }

    /// The line under the title after a break: an intact number, restart
    /// framing, never "streak: 0".
    func brokenStreakLine() -> String? {
        guard store.currentStreak == 0, store.capturesThisMonth > 0 else { return nil }
        return Copy.Mirror.momentMetricMonth(store.capturesThisMonth)
    }

    // MARK: - Private

    private var quietUntil: Date? {
        let ts = defaults.double(forKey: AppKeys.Mirror.momentQuietUntil)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    private func resetDismissals() {
        defaults.set(0, forKey: AppKeys.Mirror.momentDismissStreak)
        defaults.set(0.0, forKey: AppKeys.Mirror.momentQuietUntil)
    }

    /// Monday or the first of the month (which also covers New Year).
    private func isFreshStartDay(_ date: Date) -> Bool {
        date.dayOfWeek == 2 || Date.cal.component(.day, from: date) == 1
    }
}
