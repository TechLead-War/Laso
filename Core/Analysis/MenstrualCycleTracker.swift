import Foundation
import SwiftUI
import HealthKit
import Observation

/// Tracks menstrual cycle phases from HealthKit flow data and provides
/// phase-aware guidance for recovery, exercise, sleep, and nutrition.
@Observable
final class MenstrualCycleTracker {

    // MARK: - CyclePhase

    enum CyclePhase: String, CaseIterable, Codable, Sendable {
        case menstrual
        case follicular
        case ovulation
        case luteal

        var displayName: String {
            switch self {
            case .menstrual:  return Copy.CycleTracking.trackerMenstrualDisplay
            case .follicular: return Copy.CycleTracking.trackerFollicularDisplay
            case .ovulation:  return Copy.CycleTracking.trackerOvulationDisplay
            case .luteal:     return Copy.CycleTracking.trackerLutealDisplay
            }
        }

        var color: Color {
            switch self {
            case .menstrual:  return AppColour.danger
            case .follicular: return AppColour.success
            case .ovulation:  return AppColour.warning
            case .luteal:     return AppColour.categoryStress
            }
        }

        var icon: String {
            switch self {
            case .menstrual:  return "drop.fill"
            case .follicular: return "arrow.up.circle.fill"
            case .ovulation:  return "sparkle"
            case .luteal:     return "moon.fill"
            }
        }

        var description: String {
            switch self {
            case .menstrual:  return Copy.CycleTracking.trackerMenstrualDescription
            case .follicular: return Copy.CycleTracking.trackerFollicularDescription
            case .ovulation:  return Copy.CycleTracking.trackerOvulationDescription
            case .luteal:     return Copy.CycleTracking.trackerLutealDescription
            }
        }

        /// Inclusive day range within a standard 28-day cycle (1-indexed).
        /// Must match `phaseRanges(cycleLength: 28)`; ovulation and luteal overlap
        /// by design and `phaseForDay` gives ovulation precedence.
        var dayRange: ClosedRange<Int> {
            switch self {
            case .menstrual:  return 1...5
            case .follicular: return 6...11
            case .ovulation:  return 12...16
            case .luteal:     return 15...28
            }
        }

        var exerciseRecommendation: String {
            switch self {
            case .menstrual:  return Copy.CycleTracking.trackerMenstrualExercise
            case .follicular: return Copy.CycleTracking.trackerFollicularExercise
            case .ovulation:  return Copy.CycleTracking.trackerOvulationExercise
            case .luteal:     return Copy.CycleTracking.trackerLutealExercise
            }
        }

        var sleepImpact: String {
            switch self {
            case .menstrual:  return Copy.CycleTracking.trackerMenstrualSleep
            case .follicular: return Copy.CycleTracking.trackerFollicularSleep
            case .ovulation:  return Copy.CycleTracking.trackerOvulationSleep
            case .luteal:     return Copy.CycleTracking.trackerLutealSleep
            }
        }

        var nutritionTip: String {
            switch self {
            case .menstrual:  return Copy.CycleTracking.trackerMenstrualNutrition
            case .follicular: return Copy.CycleTracking.trackerFollicularNutrition
            case .ovulation:  return Copy.CycleTracking.trackerOvulationNutrition
            case .luteal:     return Copy.CycleTracking.trackerLutealNutrition
            }
        }
    }

    // MARK: - CycleInfo

    struct CycleInfo {
        let currentPhase: CyclePhase
        let dayInCycle: Int
        let cycleLength: Int
        let lastPeriodStart: Date?
        let nextPeriodEstimate: Date?
        let daysUntilNextPeriod: Int?
        /// Progress through the current phase (0 = phase start, 1 = phase end).
        let phaseProgress: Double
    }

    // MARK: - Published State

    var currentCycle: CycleInfo?
    var cycleHistory: [(startDate: Date, length: Int)] = []
    var isApplicable: Bool = true

    // MARK: - Snapshot Persistence

    /// UserDefaults key for the last successfully computed cycle snapshot.
    /// Restored in `init()` so the first render after launch shows the most
    /// recent known cycle phase instead of a blank tile while the async
    /// HealthKit fetch is in flight.
    private static let snapshotKey = "MenstrualCycleTracker.snapshot.v1"

    /// Maximum age of a snapshot before it is considered stale and discarded.
    /// Cycle phase changes daily, so anything older than ~1.5 days is unsafe to show.
    private static let snapshotMaxAge: TimeInterval = 36 * 60 * 60

    // Hot-path caches: the cycle compute path runs every
    // dashboard refresh and walks a year of bleeding samples in a tight loop.
    private static let jsonEncoder: JSONEncoder = JSONEncoder()
    private static let jsonDecoder: JSONDecoder = JSONDecoder()

    private struct Snapshot: Codable {
        var currentPhase: String
        var dayInCycle: Int
        var cycleLength: Int
        var lastPeriodStart: Date?
        var nextPeriodEstimate: Date?
        var daysUntilNextPeriod: Int?
        var phaseProgress: Double
        var savedAt: Date
    }

    init() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
            let snap = try? Self.jsonDecoder.decode(Snapshot.self, from: data)
        else { return }
        // Discard stale snapshots: cycle phase moves daily, so showing
        // a week-old phase would mislead the user.
        guard Date().timeIntervalSince(snap.savedAt) <= Self.snapshotMaxAge else { return }
        guard let phase = CyclePhase(rawValue: snap.currentPhase) else { return }
        currentCycle = CycleInfo(
            currentPhase: phase,
            dayInCycle: snap.dayInCycle,
            cycleLength: snap.cycleLength,
            lastPeriodStart: snap.lastPeriodStart,
            nextPeriodEstimate: snap.nextPeriodEstimate,
            daysUntilNextPeriod: snap.daysUntilNextPeriod,
            phaseProgress: snap.phaseProgress
        )
    }

    private func saveSnapshot() {
        // Only persist a real, non-degraded cycle. Saving nil/placeholder state
        // would just paint an empty tile on the next launch and bury the last
        // known good snapshot.
        guard let cycle = currentCycle else { return }
        let snap = Snapshot(
            currentPhase: cycle.currentPhase.rawValue,
            dayInCycle: cycle.dayInCycle,
            cycleLength: cycle.cycleLength,
            lastPeriodStart: cycle.lastPeriodStart,
            nextPeriodEstimate: cycle.nextPeriodEstimate,
            daysUntilNextPeriod: cycle.daysUntilNextPeriod,
            phaseProgress: cycle.phaseProgress,
            savedAt: Date()
        )
        if let data = try? Self.jsonEncoder.encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    // MARK: - Compute

    /// Analyze menstrual flow data from HealthKit and populate cycle state.
    func compute(from healthKitManager: HealthKitManager) async {
        let flowSamples = await healthKitManager.fetchMenstrualFlowSamples(days: 730)

        let bleedingDays = flowSamples
            .filter { $0.isBleedingDay }
            .map { $0.day }
            .sorted()

        guard !bleedingDays.isEmpty else {
            currentCycle = nil
            cycleHistory = []
            return
        }

        // Group bleeding days into distinct periods (gap >= 18 days = new cycle).
        let cycleStarts = identifyCycleStarts(from: bleedingDays)
        guard !cycleStarts.isEmpty else {
            currentCycle = nil
            cycleHistory = []
            return
        }

        // Build cycle history from consecutive starts.
        let calendar = Date.cal
        var history: [(startDate: Date, length: Int)] = []
        for i in 0..<(cycleStarts.count - 1) {
            let length = calendar.dateComponents([.day], from: cycleStarts[i], to: cycleStarts[i + 1]).day ?? 28
            if (18...45).contains(length) {
                history.append((startDate: cycleStarts[i], length: length))
            }
        }
        cycleHistory = Array(history.suffix(6))

        // Average cycle length from last 3-6 completed cycles.
        let recentLengths = cycleHistory.suffix(6).map(\.length)
        let averageLength: Int
        if recentLengths.isEmpty {
            averageLength = 28
        } else {
            averageLength = Int(round(Double(recentLengths.reduce(0, +)) / Double(recentLengths.count)))
        }

        // Determine current day in cycle.
        guard let lastStart = cycleStarts.last else {
            currentCycle = nil
            cycleHistory = []
            return
        }
        let daysSinceLastStart = calendar.dateComponents([.day], from: lastStart, to: Date()).day ?? 0
        // Clamp to 1: a future-dated period log would otherwise yield 0/negative,
        // fall through phaseForDay's switch, and silently land in .luteal.
        let dayInCycle = max(1, daysSinceLastStart + 1) // 1-indexed

        let phase = phaseForDay(dayInCycle, cycleLength: averageLength)
        let nextPeriod = estimateNextPeriod(lastStart: lastStart, averageLength: averageLength)
        let daysUntilNext = calendar.dateComponents([.day], from: Date().startOfDay, to: nextPeriod).day

        // Phase progress: how far through the current phase (0-1).
        let progress = computePhaseProgress(dayInCycle: dayInCycle, phase: phase, cycleLength: averageLength)

        currentCycle = CycleInfo(
            currentPhase: phase,
            dayInCycle: dayInCycle,
            cycleLength: averageLength,
            lastPeriodStart: lastStart,
            nextPeriodEstimate: nextPeriod,
            daysUntilNextPeriod: daysUntilNext,
            phaseProgress: progress
        )
        saveSnapshot()
    }

    // MARK: - Helpers

    /// Determine the cycle phase for a given day within a cycle of the specified length.
    func phaseForDay(_ day: Int, cycleLength: Int) -> CyclePhase {
        let ranges = Self.phaseRanges(cycleLength: cycleLength)

        switch day {
        case ranges.menstrual:
            return .menstrual
        case ranges.follicular:
            return .follicular
        case ranges.ovulation:
            return .ovulation
        default:
            return .luteal
        }
    }

    /// Estimate the start date of the next period.
    func estimateNextPeriod(lastStart: Date, averageLength: Int) -> Date {
        Date.cal.date(byAdding: .day, value: averageLength, to: lastStart) ?? lastStart
    }

    // MARK: - Private

    /// Identify cycle start dates from sorted bleeding days.
    /// A gap of 18 or more days between bleeding days marks a new cycle.
    /// Threshold is 18 to align with the cycleHistory accepted range (18...45);
    /// a higher threshold (e.g. >20) would silently drop valid 19-20 day cycles.
    private func identifyCycleStarts(from sortedBleedingDays: [Date]) -> [Date] {
        guard let first = sortedBleedingDays.first else { return [] }
        var starts: [Date] = [first]
        let calendar = Date.cal

        for day in sortedBleedingDays.dropFirst() {
            guard let lastStart = starts.last else { continue }
            let gap = calendar.dateComponents([.day], from: lastStart, to: day).day ?? 0
            if gap >= 18 {
                starts.append(day)
            }
        }
        return starts
    }

    /// The luteal phase is ~14 days regardless of cycle length; cycle-length variation
    /// lives in the follicular phase (Fehring et al. 2006; Bull et al. 2019, npj Digital Medicine).
    private static let lutealLengthDays = 14

    /// Ovulation window is the ovulation day plus/minus this many days.
    private static let ovulationHalfWidthDays = 2

    /// Menstrual bleeding is days 1...5 and does not scale with cycle length.
    private static let menstrualEndDay = 5

    /// Phase day ranges for a cycle of the given length, counted back from the
    /// next period: ovulation on day (length - 14), luteal the 14 days after it.
    /// Ovulation and luteal overlap by design; `phaseForDay` gives ovulation precedence.
    private static func phaseRanges(cycleLength: Int) -> (
        menstrual: ClosedRange<Int>, follicular: ClosedRange<Int>,
        ovulation: ClosedRange<Int>, luteal: ClosedRange<Int>
    ) {
        let ovulationDay = cycleLength - lutealLengthDays
        // Cycles under 23 days cannot hold a 5-day period, a follicular day, the
        // ovulation window and a 14-day luteal phase. Luteal is the biologically fixed
        // one, so the period shrinks first (never below day 1) and only an 18-day cycle
        // also loses the front of the ovulation window. Follicular always keeps day
        // (menstrualEnd + 1), so the window opens on day 3 at the earliest.
        let ovulationStart = max(ovulationDay - ovulationHalfWidthDays, 3)
        let menstrualEnd = min(menstrualEndDay, ovulationStart - 2)
        precondition(ovulationStart <= ovulationDay,
                     "cycleLength \(cycleLength) is too short for a \(lutealLengthDays)-day luteal phase; compute() only accepts 18+")

        return (
            menstrual: 1...menstrualEnd,
            follicular: (menstrualEnd + 1)...(ovulationStart - 1),
            ovulation: ovulationStart...(ovulationDay + ovulationHalfWidthDays),
            luteal: (ovulationDay + 1)...cycleLength
        )
    }

    /// Compute how far through the current phase the user is (0 = start, 1 = end).
    private func computePhaseProgress(dayInCycle: Int, phase: CyclePhase, cycleLength: Int) -> Double {
        let ranges = Self.phaseRanges(cycleLength: cycleLength)

        let range: ClosedRange<Int>
        switch phase {
        case .menstrual:  range = ranges.menstrual
        case .follicular: range = ranges.follicular
        case .ovulation:  range = ranges.ovulation
        case .luteal:     range = ranges.luteal
        }

        let dayWithinPhase = dayInCycle - range.lowerBound
        return min(max(Double(dayWithinPhase) / Double(range.count), 0.0), 1.0)
    }
}
