import Foundation

/// Tunables for the daily brief: how many drivers to show, when a focus ends,
/// and the floors a signal has to clear before it is named as a driver.
///
/// HEURISTIC — unvalidated. The driver thresholds (sleep balance, bounce-back,
/// strain days) are product guesses, not clinical cut-offs. Every one lives in
/// Firebase Remote Config (`RC.dailyBrief*` in `RemoteConfigSchema.swift`) so
/// it can be tuned without a release; the bundled defaults are what ships.
enum DailyBriefConfig {

    private static var rc: RemoteConfigManager { .shared }

    // MARK: - Focus

    /// Length of one focus. Three weeks is long enough for a rest-day or
    /// bedtime change to show in the numbers and short enough to finish.
    static var focusDays: Int { rc.dailyBriefFocusDays }
    /// A focus closes early once its driver has been back at usual this long.
    static var focusEarlyCloseDays: Int { rc.dailyBriefFocusEarlyCloseDays }
    /// Finished focuses kept for the Progress list.
    static var pastFocusRetention: Int { rc.dailyBriefPastFocusRetention }

    // MARK: - Drivers

    static var driverCount: Int { rc.dailyBriefDriverCount }
    /// Sleep debt at or above this names sleep balance as a driver.
    static var sleepBalanceDriverHours: Double { rc.dailyBriefSleepBalanceDriverHours }
    /// Heart rate recovery this far under its baseline names bounce-back as a driver.
    static var hrrOffUsualPercent: Double { rc.dailyBriefHrrOffUsualPercent }
    /// Days of the last six above the strain target that name strain as a driver.
    static var strainHighDaysOfSix: Int { rc.dailyBriefStrainHighDaysOfSix }

    // MARK: - Status

    static var readinessWindowDays: Int { rc.dailyBriefReadinessWindowDays }
    static var readinessBandDays: Int { rc.dailyBriefReadinessBandDays }
    /// Week-over-week readiness moves inside this many points read as flat.
    static var trajectoryDeadBand: Double { rc.dailyBriefTrajectoryDeadBand }

    // MARK: - Moves

    static var dayReminderHour: Int { rc.dailyBriefDayReminderHour }
    static var moveLogRetentionDays: Int { rc.dailyBriefMoveLogRetentionDays }

    /// Not remote: the smallest sleep change worth claiming is the one the
    /// insight engine already uses, so a night cannot count here and be noise there.
    static var nightMoveFloorMinutes: Double { InsightConfig.GroupDifference.sleepFloorMinutes }
}
