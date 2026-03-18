import Foundation

// MARK: - Activation Sequence Manager

/// Manages the first-8-days progressive activation experience.
/// Based on retention research (npj Digital Medicine 2023): 67.6% retention
/// when users see personalized feedback loops, versus 6% industry average.
/// RevenueCat 2025: health apps demonstrating personal value within trial
/// convert at 68%+ vs 40% median.
///
/// Progression:
/// - Day 1: First baseline established, basic stats visible
/// - Day 2: First day-over-day comparison unlocked
/// - Day 3: First trend direction visible (3-day minimum)
/// - Day 4: First pattern hint (weekday vs weekend)
/// - Day 5: First correlation discovered
/// - Day 6: First anomaly detection active
/// - Day 7: First prediction generated
/// - Day 8: Full readiness score + all features unlocked
final class ActivationSequenceManager {

    // MARK: - Types

    struct ActivationState: Codable {
        var currentDay: Int  // 1-8+
        var milestonesCompleted: Set<Milestone>
        var installDate: Date
        var lastMilestoneDate: Date?

        var isComplete: Bool { currentDay > 8 }
        var progressFraction: Double { min(1.0, Double(currentDay - 1) / 7.0) }
    }

    enum Milestone: String, Codable, CaseIterable {
        case firstBaseline       // Day 1
        case firstComparison     // Day 2
        case firstTrend          // Day 3
        case firstPattern        // Day 4
        case firstCorrelation    // Day 5
        case firstAnomaly        // Day 6
        case firstPrediction     // Day 7
        case fullUnlock          // Day 8
        case firstWeekComplete   // Day 8+

        var day: Int {
            switch self {
            case .firstBaseline: return 1
            case .firstComparison: return 2
            case .firstTrend: return 3
            case .firstPattern: return 4
            case .firstCorrelation: return 5
            case .firstAnomaly: return 6
            case .firstPrediction: return 7
            case .fullUnlock, .firstWeekComplete: return 8
            }
        }

        var icon: String {
            switch self {
            case .firstBaseline: return "chart.bar"
            case .firstComparison: return "arrow.left.arrow.right"
            case .firstTrend: return "chart.line.uptrend.xyaxis"
            case .firstPattern: return "repeat"
            case .firstCorrelation: return "link"
            case .firstAnomaly: return "exclamationmark.triangle"
            case .firstPrediction: return "sparkles"
            case .fullUnlock: return "checkmark.seal.fill"
            case .firstWeekComplete: return "star.fill"
            }
        }

        var title: String {
            switch self {
            case .firstBaseline: return "Baseline Established"
            case .firstComparison: return "First Comparison"
            case .firstTrend: return "Trend Detected"
            case .firstPattern: return "Pattern Found"
            case .firstCorrelation: return "Correlation Discovered"
            case .firstAnomaly: return "Anomaly Detection Active"
            case .firstPrediction: return "First Prediction"
            case .fullUnlock: return "Full Intelligence Unlocked"
            case .firstWeekComplete: return "First Week Complete"
            }
        }

        var detail: String {
            switch self {
            case .firstBaseline:
                return "Your personal baselines are set. We now know what's normal for you."
            case .firstComparison:
                return "Comparing today vs yesterday. Your body tells a story day by day."
            case .firstTrend:
                return "3 days of data reveals your first trend direction."
            case .firstPattern:
                return "We can now see weekday vs weekend differences in your data."
            case .firstCorrelation:
                return "Found a link between two of your metrics. Your body is an interconnected system."
            case .firstAnomaly:
                return "Anomaly detection is live. We'll flag anything unusual."
            case .firstPrediction:
                return "Your first health prediction is ready. We can now anticipate what's coming."
            case .fullUnlock:
                return "All intelligence features are active. Your personal health AI is fully calibrated."
            case .firstWeekComplete:
                return "One week of data — your insights will keep getting sharper over time."
            }
        }
    }

    struct MilestoneEvent {
        let milestone: Milestone
        let unlockedAt: Date
        let dataPointCount: Int
    }

    // MARK: - Storage

    private static let stateKey = "laso.activation.state"

    // MARK: - State Management

    /// Load or initialize activation state
    static func loadState() -> ActivationState {
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let state = try? JSONDecoder().decode(ActivationState.self, from: data) {
            // Update currentDay based on actual days since install
            var updated = state
            updated.currentDay = daysSinceInstall(state.installDate) + 1
            return updated
        }

        // First launch — initialize
        let installDate = installDateFromDefaults() ?? Date()
        let state = ActivationState(
            currentDay: 1,
            milestonesCompleted: [],
            installDate: installDate,
            lastMilestoneDate: nil
        )
        save(state)
        return state
    }

    /// Check and advance milestones based on current data
    static func checkMilestones(
        state: inout ActivationState,
        metricsAvailable: Int,
        hasBaselines: Bool,
        hasTrends: Bool,
        hasCorrelations: Bool,
        hasAnomalyDetection: Bool,
        hasPredictions: Bool
    ) -> [MilestoneEvent] {
        var newMilestones: [MilestoneEvent] = []
        let now = Date()

        // Day 1: First baseline
        if hasBaselines && !state.milestonesCompleted.contains(.firstBaseline) {
            state.milestonesCompleted.insert(.firstBaseline)
            newMilestones.append(MilestoneEvent(milestone: .firstBaseline, unlockedAt: now, dataPointCount: metricsAvailable))
        }

        // Day 2: First comparison (need 2+ days)
        if state.currentDay >= 2 && metricsAvailable > 0 && !state.milestonesCompleted.contains(.firstComparison) {
            state.milestonesCompleted.insert(.firstComparison)
            newMilestones.append(MilestoneEvent(milestone: .firstComparison, unlockedAt: now, dataPointCount: metricsAvailable))
        }

        // Day 3: First trend
        if state.currentDay >= 3 && hasTrends && !state.milestonesCompleted.contains(.firstTrend) {
            state.milestonesCompleted.insert(.firstTrend)
            newMilestones.append(MilestoneEvent(milestone: .firstTrend, unlockedAt: now, dataPointCount: metricsAvailable))
        }

        // Day 4: First pattern
        if state.currentDay >= 4 && metricsAvailable >= 3 && !state.milestonesCompleted.contains(.firstPattern) {
            state.milestonesCompleted.insert(.firstPattern)
            newMilestones.append(MilestoneEvent(milestone: .firstPattern, unlockedAt: now, dataPointCount: metricsAvailable))
        }

        // Day 5: First correlation
        if state.currentDay >= 5 && hasCorrelations && !state.milestonesCompleted.contains(.firstCorrelation) {
            state.milestonesCompleted.insert(.firstCorrelation)
            newMilestones.append(MilestoneEvent(milestone: .firstCorrelation, unlockedAt: now, dataPointCount: metricsAvailable))
        }

        // Day 6: First anomaly
        if state.currentDay >= 6 && hasAnomalyDetection && !state.milestonesCompleted.contains(.firstAnomaly) {
            state.milestonesCompleted.insert(.firstAnomaly)
            newMilestones.append(MilestoneEvent(milestone: .firstAnomaly, unlockedAt: now, dataPointCount: metricsAvailable))
        }

        // Day 7: First prediction
        if state.currentDay >= 7 && hasPredictions && !state.milestonesCompleted.contains(.firstPrediction) {
            state.milestonesCompleted.insert(.firstPrediction)
            newMilestones.append(MilestoneEvent(milestone: .firstPrediction, unlockedAt: now, dataPointCount: metricsAvailable))
        }

        // Day 8: Full unlock
        if state.currentDay >= 8 && !state.milestonesCompleted.contains(.fullUnlock) {
            state.milestonesCompleted.insert(.fullUnlock)
            state.milestonesCompleted.insert(.firstWeekComplete)
            newMilestones.append(MilestoneEvent(milestone: .fullUnlock, unlockedAt: now, dataPointCount: metricsAvailable))
        }

        if !newMilestones.isEmpty {
            state.lastMilestoneDate = now
            save(state)
        }

        return newMilestones
    }

    /// Get the next upcoming milestone
    static func nextMilestone(state: ActivationState) -> Milestone? {
        guard !state.isComplete else { return nil }
        return Milestone.allCases.first { !state.milestonesCompleted.contains($0) }
    }

    /// Get progress description for current day
    static func progressDescription(state: ActivationState) -> String {
        guard !state.isComplete else { return "Fully calibrated" }

        let day = min(state.currentDay, 8)
        let nextMilestone = nextMilestone(state: state)
        let milestoneName = nextMilestone?.title ?? "Full calibration"
        let daysLeft = max(0, 8 - state.currentDay)

        if daysLeft == 0 {
            return "Almost there — \(milestoneName) unlocking soon"
        }
        return "Day \(day) of 8 — \(milestoneName) in \(daysLeft) day\(daysLeft == 1 ? "" : "s")"
    }

    // MARK: - Private Helpers

    private static func save(_ state: ActivationState) {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    private static func daysSinceInstall(_ installDate: Date) -> Int {
        let calendar = Calendar.current
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: installDate), to: calendar.startOfDay(for: Date())).day ?? 0)
    }

    private static func installDateFromDefaults() -> Date? {
        // Try the unified install date key first
        if let dateStr = UserDefaults.standard.string(forKey: "laso.install_date"),
           let date = ISO8601DateFormatter().date(from: dateStr) {
            return date
        }
        if let timeInterval = UserDefaults.standard.object(forKey: "laso.install_date") as? Double, timeInterval > 0 {
            return Date(timeIntervalSince1970: timeInterval)
        }
        return nil
    }
}
