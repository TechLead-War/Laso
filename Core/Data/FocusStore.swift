import Foundation
import Observation

/// One three-week focus at a time, plus the ones already finished.
///
/// A focus starts from the day's top driver and tracks up to three numbers
/// from day 1 to today, so the Progress tab can say whether the thing the
/// person worked on actually moved. Stored as JSON in UserDefaults like
/// `LifeContextStore`: no SwiftData model, because adding one changes the
/// schema version and wipes the on-device database.
@Observable
final class FocusStore {

    enum KPIKind: String, Codable, CaseIterable {
        case restDaysPerWeek, sleepBalanceHours, hrrPercentOffUsual, vo2Max, hrvMs,
             restingHR, deepSleepMinutes, steps, stressScore

        /// Sleep balance is negative when behind, so climbing toward zero is
        /// the improvement. Bounce-back is stored as percent under usual, so
        /// smaller is better there.
        var higherIsBetter: Bool {
            switch self {
            case .hrrPercentOffUsual, .restingHR, .stressScore:
                return false
            case .restDaysPerWeek, .sleepBalanceHours, .vo2Max, .hrvMs, .deepSleepMinutes, .steps:
                return true
            }
        }

        /// Smallest move that counts as a change. Below it the outcome reads
        /// "no change" rather than claiming a swing the person cannot feel.
        ///
        /// HEURISTIC — unvalidated except where noted. Sleep and resting HR
        /// reuse the insight engine's floors so one screen cannot call a gap
        /// real that another calls noise; the rest are product guesses.
        var floor: Double {
            switch self {
            case .restDaysPerWeek:    return 0.5
            case .sleepBalanceHours:  return DailyBriefConfig.nightMoveFloorMinutes / 60
            case .hrrPercentOffUsual: return 2
            case .vo2Max:             return 0.5
            case .hrvMs:              return 3
            case .restingHR:          return InsightConfig.GroupDifference.rhrFloorBpm
            case .deepSleepMinutes:   return 10
            case .steps:              return 500
            case .stressScore:        return 10
            }
        }

        var label: String { Copy.DailyBrief.KPI.label(for: self) }

        func format(_ value: Double) -> String {
            let whole = Int(value.rounded())
            switch self {
            case .restDaysPerWeek, .vo2Max: return String(format: "%.1f", value)
            case .sleepBalanceHours:
                let clock = abs(value).hoursAsClock
                return value < 0 ? Copy.DailyBrief.KPI.behind(clock) : clock
            case .hrrPercentOffUsual: return Copy.DailyBrief.KPI.percent(whole)
            case .hrvMs:              return Copy.DailyBrief.KPI.milliseconds(whole)
            case .restingHR:          return Copy.DailyBrief.KPI.bpm(whole)
            case .deepSleepMinutes:   return Copy.DailyBrief.KPI.minutes(whole)
            case .steps:              return whole.formatted()
            case .stressScore:        return String(whole)
            }
        }
    }

    struct KPISnapshot: Codable, Equatable {
        let kind: KPIKind
        var day1: Double
        var latest: Double
        var latestAt: Date
    }

    enum Outcome: String, Codable { case improved, held, noChange }

    struct FocusRecord: Codable, Identifiable, Equatable {
        let id: UUID
        let driver: DriverKind
        var startedAt: Date
        var endedAt: Date?
        var outcome: Outcome?
        var kpis: [KPISnapshot]
        /// First day the driver was seen back inside the usual range, cleared the
        /// moment it is off again. Optional so records written before it decode.
        var atUsualSince: Date? = nil

        var isActive: Bool { endedAt == nil }

        /// 1-based day of the focus, clamped so a late expiry never prints day 22.
        func dayIndex(now: Date) -> Int {
            let elapsed = Date.cal.dateComponents(
                [.day],
                from: Date.cal.startOfDay(for: startedAt),
                to: Date.cal.startOfDay(for: now)
            ).day ?? 0
            return min(DailyBriefConfig.focusDays, max(1, elapsed + 1))
        }
    }

    private static let storageKey = AppKeys.Data.focusRecords

    private let defaults: UserDefaults

    /// Bumped on every write so the brief can compare one number instead of
    /// diffing records.
    private(set) var revision = 0
    private(set) var active: FocusRecord?
    /// Newest first, bounded to `DailyBriefConfig.pastFocusRetention`.
    private(set) var past: [FocusRecord] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = Self.load(from: defaults)
        active = stored.first { $0.isActive }
        past = stored.filter { !$0.isActive }
    }

    /// No-op while one is running: a focus is a three-week commitment, not a
    /// thing that flips with the day's top driver.
    func start(driver: DriverKind, kpis: [KPISnapshot], now: Date = Date()) {
        guard active == nil else { return }
        active = FocusRecord(id: UUID(), driver: driver, startedAt: now, endedAt: nil, outcome: nil, kpis: kpis)
        persist()
    }

    /// Writes and bumps `revision` only when a tracked value actually moved,
    /// so a refresh that lands the same numbers does not republish the brief.
    @discardableResult
    func updateLatest(_ values: [KPIKind: Double], now: Date = Date()) -> Bool {
        guard var record = active else { return false }
        var changed = false
        for index in record.kpis.indices {
            guard let value = values[record.kpis[index].kind], value != record.kpis[index].latest else { continue }
            record.kpis[index].latest = value
            record.kpis[index].latestAt = now
            changed = true
        }
        guard changed else { return false }
        active = record
        persist()
        return true
    }

    /// Records whether today's reading still has the driver off usual, and
    /// closes the focus once it has been back at usual for
    /// `DailyBriefConfig.focusEarlyCloseDays` days in a row. The driver clearing
    /// is what the focus was for, so that close counts as worked. Returns
    /// whether it closed.
    @discardableResult
    func noteDriver(isOff: Bool, now: Date = Date()) -> Bool {
        guard var record = active else { return false }
        if isOff {
            guard record.atUsualSince != nil else { return false }
            record.atUsualSince = nil
            active = record
            persist()
            return false
        }
        guard let since = record.atUsualSince else {
            record.atUsualSince = now
            active = record
            persist()
            return false
        }
        let days = Date.cal.dateComponents(
            [.day], from: Date.cal.startOfDay(for: since), to: Date.cal.startOfDay(for: now)
        ).day ?? 0
        guard days >= DailyBriefConfig.focusEarlyCloseDays else { return false }
        close(outcome: .improved, now: now)
        return true
    }

    func close(outcome: Outcome, now: Date = Date()) {
        guard var record = active else { return }
        record.endedAt = now
        record.outcome = outcome
        active = nil
        past.insert(record, at: 0)
        past = Array(past.prefix(DailyBriefConfig.pastFocusRetention))
        persist()
    }

    func expireIfNeeded(now: Date = Date()) {
        guard let record = active,
              let endsAt = Date.cal.date(byAdding: .day, value: DailyBriefConfig.focusDays, to: record.startedAt),
              now >= endsAt else { return }
        close(outcome: Self.outcome(for: record), now: now)
    }

    /// Graded on the primary KPI alone: improved when it moved past its floor
    /// the right way, no change when it stayed inside the floor, held otherwise.
    static func outcome(for record: FocusRecord) -> Outcome {
        guard let primary = record.kpis.first else { return .noChange }
        let delta = primary.latest - primary.day1
        guard abs(delta) >= primary.kind.floor else { return .noChange }
        let gained = primary.kind.higherIsBetter ? delta : -delta
        return gained > 0 ? .improved : .held
    }

    private func persist() {
        revision &+= 1
        let records = (active.map { [$0] } ?? []) + past
        guard let data = try? JSONEncoder().encode(records) else {
            AnalyticsBackend.provider.captureError(
                "Failed to encode focus records",
                context: "focus_store_encode")
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [FocusRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([FocusRecord].self, from: data) else { return [] }
        return records
    }
}
