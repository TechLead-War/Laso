import Foundation

/// Bands and windows for the wake anchor.
///
/// SOURCE: Windred, Drummond, Cain et al., "Sleep regularity is a stronger
/// predictor of mortality risk than sleep duration", SLEEP 47(1) 2024
/// (N=60,977 UK Biobank, 1,859 deaths). The most-regular quintile — all-cause
/// mortality HR 0.70 (0.59–0.83) — went to sleep and woke inside roughly
/// 1-hour windows, versus about 3-hour windows in the least regular. That
/// 1-hour window is where `driftLooseMinutes` comes from: +/-30 minutes around
/// a fixed anchor keeps a user inside the observed behaviour of the best
/// outcome group.
///
/// NOT a tested threshold. No study randomises a +/-15 or +/-30 minute drift;
/// this is inference from observational cohort behaviour, so the bands are
/// descriptive labels, never a claim about this user's risk.
///
/// The anchor itself is bounded by `WakeUpTimeDetector.earliestWakeHour` /
/// `latestWakeHour` (5–11), not by anything here — that band is load-bearing
/// for notification delivery, not for sleep science.
enum WakeAnchorConfig {

    private static var rc: RemoteConfigManager { .shared }

    /// True → hide the whole wake-window section.
    static var isKilled: Bool { rc.killWakeAnchor }

    /// Median absolute drift at or below this reads as "steady".
    static var driftTightMinutes: Int { rc.wakeAnchorDriftTightMinutes }

    /// Half-width of the band drawn behind the drift strip, and the cutoff
    /// between "close" and "variable".
    static var driftLooseMinutes: Int { rc.wakeAnchorDriftLooseMinutes }

    /// Window the headline consistency readout is computed over.
    static var consistencyWindowDays: Int { rc.wakeAnchorConsistencyWindowDays }

    /// Below this many tracked nights we show counts, never a band label. A
    /// band computed from four nights is a number pretending to be a finding.
    static var consistencyMinNights: Int { rc.wakeAnchorConsistencyMinNights }

    /// Longest window the strip will render.
    static var historyWindowDays: Int { rc.wakeAnchorHistoryWindowDays }
}
