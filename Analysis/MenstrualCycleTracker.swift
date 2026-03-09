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
            case .menstrual:  return "Menstrual"
            case .follicular: return "Follicular"
            case .ovulation:  return "Ovulation"
            case .luteal:     return "Luteal"
            }
        }

        var color: Color {
            switch self {
            case .menstrual:  return .red
            case .follicular: return .pink
            case .ovulation:  return .orange
            case .luteal:     return .purple
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
            case .menstrual:
                return "Energy and recovery capacity are typically at their lowest. The body is shedding the uterine lining, and iron levels may dip. Fatigue and mild discomfort are common."
            case .follicular:
                return "Rising estrogen boosts energy, mood, and recovery speed. This phase favors learning new skills and building strength as the body ramps toward peak performance."
            case .ovulation:
                return "Peak estrogen and a surge in luteinizing hormone drive the highest energy and performance potential of the cycle. Reaction time and power output tend to peak."
            case .luteal:
                return "Progesterone rises while estrogen declines. Core temperature increases slightly, recovery slows, and energy gradually tapers toward the end of the phase."
            }
        }

        /// Inclusive day range within a standard 28-day cycle (1-indexed).
        var dayRange: ClosedRange<Int> {
            switch self {
            case .menstrual:  return 1...5
            case .follicular: return 6...13
            case .ovulation:  return 12...16
            case .luteal:     return 17...28
            }
        }

        var exerciseRecommendation: String {
            switch self {
            case .menstrual:
                return "Favor light movement — walking, gentle yoga, or stretching. Avoid heavy lifts or high-impact sessions if energy is low."
            case .follicular:
                return "Great time to push intensity. Try heavy strength training, HIIT, or learning new movement patterns. Recovery is fast."
            case .ovulation:
                return "Peak performance window. Go for PRs, high-intensity intervals, or competitive efforts. Stay mindful of joint laxity from elevated relaxin."
            case .luteal:
                return "Moderate steady-state cardio and maintenance-level strength work. Reduce volume in the late luteal phase as fatigue builds."
            }
        }

        var sleepImpact: String {
            switch self {
            case .menstrual:
                return "Sleep may be disrupted by cramps or discomfort in the first days. Prioritize earlier bedtimes and a cool sleep environment."
            case .follicular:
                return "Sleep quality typically improves as estrogen rises. This is often the easiest phase for consistent, restorative sleep."
            case .ovulation:
                return "Sleep remains generally good, though some experience lighter sleep around the LH surge. Maintain consistent sleep timing."
            case .luteal:
                return "Rising progesterone raises core temperature, which can reduce deep sleep. Expect more fragmented sleep in the late luteal phase."
            }
        }

        var nutritionTip: String {
            switch self {
            case .menstrual:
                return "Focus on iron-rich foods (red meat, spinach, lentils) to offset menstrual losses. Anti-inflammatory foods like fatty fish and ginger can ease discomfort."
            case .follicular:
                return "Support rising estrogen with cruciferous vegetables and lean protein. Carbohydrate tolerance is higher — a good window for complex carbs around workouts."
            case .ovulation:
                return "Maintain balanced macros with emphasis on antioxidants and fiber. Hydration is important as energy expenditure peaks."
            case .luteal:
                return "Cravings for carbs and fats are common due to increased caloric needs (~100-300 kcal/day more). Choose whole grains, magnesium-rich foods, and healthy fats."
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
    var isReady: Bool { currentCycle != nil }
    var isApplicable: Bool = true

    /// How the current phase affects recovery expectations.
    var phaseImpactOnRecovery: String {
        guard let phase = currentCycle?.currentPhase else {
            return "No cycle data available to assess recovery impact."
        }
        switch phase {
        case .menstrual:
            return "Recovery is slower during menstruation. Allow extra rest between intense sessions and monitor HRV for readiness."
        case .follicular:
            return "Recovery is at its fastest. The body adapts well to training stimulus — shorter rest periods are feasible."
        case .ovulation:
            return "Recovery remains strong but joint laxity may increase injury risk. Warm up thoroughly and prioritize form."
        case .luteal:
            return "Recovery slows as progesterone rises and core temperature climbs. Expect longer HRV recovery and higher resting heart rate."
        }
    }

    /// Phase-specific training guidance.
    var phaseExerciseGuidance: String {
        currentCycle?.currentPhase.exerciseRecommendation
            ?? "Track at least one menstrual period to receive phase-specific training advice."
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

        // Group bleeding days into distinct periods (gap > 20 days = new cycle).
        let cycleStarts = identifyCycleStarts(from: bleedingDays)
        guard !cycleStarts.isEmpty else {
            currentCycle = nil
            cycleHistory = []
            return
        }

        // Build cycle history from consecutive starts.
        let calendar = Calendar.current
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
        let lastStart = cycleStarts.last!
        let daysSinceLastStart = calendar.dateComponents([.day], from: lastStart, to: Date()).day ?? 0
        let dayInCycle = daysSinceLastStart + 1 // 1-indexed

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
    }

    // MARK: - Visibility

    /// Whether menstrual cycle UI should be shown for this user.
    /// Returns true for female users or when gender is unknown (nil).
    func shouldShow(gender: String?) -> Bool {
        guard let gender = gender?.lowercased() else { return true }
        return gender != "male"
    }

    // MARK: - Helpers

    /// Determine the cycle phase for a given day within a cycle of the specified length.
    func phaseForDay(_ day: Int, cycleLength: Int) -> CyclePhase {
        // Scale phase boundaries proportionally when cycle length differs from 28.
        let scale = Double(cycleLength) / 28.0

        let menstrualEnd   = Int(round(5.0 * scale))
        let follicularEnd  = Int(round(13.0 * scale))
        let ovulationEnd   = Int(round(16.0 * scale))

        switch day {
        case 1...menstrualEnd:
            return .menstrual
        case (menstrualEnd + 1)...follicularEnd:
            return .follicular
        case (follicularEnd + 1)...ovulationEnd:
            return .ovulation
        default:
            return .luteal
        }
    }

    /// Estimate the start date of the next period.
    func estimateNextPeriod(lastStart: Date, averageLength: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: averageLength, to: lastStart) ?? lastStart
    }

    // MARK: - Private

    /// Identify cycle start dates from sorted bleeding days.
    /// A gap of more than 20 days between bleeding days marks a new cycle.
    private func identifyCycleStarts(from sortedBleedingDays: [Date]) -> [Date] {
        guard let first = sortedBleedingDays.first else { return [] }
        var starts: [Date] = [first]
        let calendar = Calendar.current

        for day in sortedBleedingDays.dropFirst() {
            guard let lastStart = starts.last else { continue }
            let gap = calendar.dateComponents([.day], from: lastStart, to: day).day ?? 0
            if gap > 20 {
                starts.append(day)
            }
        }
        return starts
    }

    /// Compute how far through the current phase the user is (0 = start, 1 = end).
    private func computePhaseProgress(dayInCycle: Int, phase: CyclePhase, cycleLength: Int) -> Double {
        let scale = Double(cycleLength) / 28.0

        let phaseStart: Int
        let phaseEnd: Int

        switch phase {
        case .menstrual:
            phaseStart = 1
            phaseEnd = Int(round(5.0 * scale))
        case .follicular:
            phaseStart = Int(round(5.0 * scale)) + 1
            phaseEnd = Int(round(13.0 * scale))
        case .ovulation:
            phaseStart = Int(round(13.0 * scale)) + 1
            phaseEnd = Int(round(16.0 * scale))
        case .luteal:
            phaseStart = Int(round(16.0 * scale)) + 1
            phaseEnd = cycleLength
        }

        let phaseDuration = max(phaseEnd - phaseStart + 1, 1)
        let dayWithinPhase = dayInCycle - phaseStart
        return min(max(Double(dayWithinPhase) / Double(phaseDuration), 0.0), 1.0)
    }
}
