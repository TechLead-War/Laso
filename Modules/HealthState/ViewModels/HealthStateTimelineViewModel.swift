import Foundation
import Observation
import SwiftUI

/// ViewModel for the Health State Timeline visualization.
/// Surfaces HealthStateClassifier data: state history, transitions, distribution.
@MainActor @Observable
final class HealthStateTimelineViewModel {

    // MARK: - State

    let mlOrchestrator: MLOrchestrator

    init(mlOrchestrator: MLOrchestrator) {
        self.mlOrchestrator = mlOrchestrator
    }

    // MARK: - Data Access

    /// Full state history (date + label) sorted chronologically
    var stateHistory: [(date: Date, label: String)] {
        mlOrchestrator.stateHistory
    }

    /// All identified health states with characteristics
    var states: [HealthState] {
        mlOrchestrator.healthStates
    }

    /// Current health state
    var currentState: HealthState? {
        mlOrchestrator.currentHealthState
    }

    /// Transition matrix
    var transitionMatrix: [String: [String: Double]] {
        mlOrchestrator.stateTransitionMatrix
    }

    // MARK: - Computed

    /// Color for a given state label
    func color(for label: String) -> Color {
        switch label {
        case "Recovery": return AppColour.stateRecovery
        case "Peak Performance": return AppColour.statePeakPerformance
        case "Stressed": return AppColour.stateStressed
        case "Under-Slept": return AppColour.stateUnderSlept
        case "Active": return AppColour.stateActive
        case "Fatigued": return AppColour.stateFatigued
        case "Resting": return AppColour.stateResting
        case "Recovering": return AppColour.stateRecovery
        case "Strained": return AppColour.stateStressed
        case "Low Energy": return AppColour.stateFatigued
        case "Restful": return AppColour.stateResting
        case "Balanced": return AppColour.stateDefault
        default: return AppColour.stateDefault
        }
    }

    /// One-line plain-English explainer for a state label. Shown in the
    /// hero card and State Guide so users learn what each state means.
    func description(for label: String) -> String {
        switch label {
        case "Recovery":
            return "Body is rebuilding well — strong heart variability and deep sleep."
        case "Peak Performance":
            return "Energy is high and recovery is strong — a good day to push."
        case "Stressed":
            return "Body is under load — low recovery and elevated heart rate."
        case "Under-Slept":
            return "Sleep is short — focus on rest tonight."
        case "Active":
            return "Daily activity is high — keep watching recovery."
        case "Fatigued":
            return "Recovery is low — your body is asking for lighter days."
        case "Resting":
            return "Body is taking it easy — low activity, longer sleep."
        case "Recovering":
            return "Heart variability is improving — body is bouncing back."
        case "Strained":
            return "Resting heart rate is elevated — ease the load today."
        case "Low Energy":
            return "Movement and steps are below your baseline."
        case "Restful":
            return "Sleep is longer than usual — body is winding down."
        case "Balanced":
            return "All signals near your baseline — no notable changes."
        default:
            return "A pattern in your recent days that does not match the common states."
        }
    }

    /// State distribution for a given month: [label: day count]
    func stateDistribution(for month: Date) -> [String: Int] {
        let calendar = Date.cal
        let monthComponents = calendar.dateComponents([.year, .month], from: month)
        var distribution: [String: Int] = [:]

        for entry in stateHistory {
            let entryComponents = calendar.dateComponents([.year, .month], from: entry.date)
            if entryComponents.year == monthComponents.year && entryComponents.month == monthComponents.month {
                distribution[entry.label, default: 0] += 1
            }
        }

        return distribution
    }

    /// Average transition time from one state to another (in days)
    func averageTransitionTime(from: String, to: String) -> Double? {
        var durations: [Int] = []
        var currentLabel: String?
        var daysInCurrent = 0

        for entry in stateHistory {
            if entry.label == currentLabel {
                daysInCurrent += 1
            } else {
                if currentLabel == from && entry.label == to {
                    durations.append(daysInCurrent)
                }
                currentLabel = entry.label
                daysInCurrent = 1
            }
        }

        guard !durations.isEmpty else { return nil }
        return Double(durations.reduce(0, +)) / Double(durations.count)
    }

    /// Unique state labels in order of frequency (most common first)
    var uniqueStateLabels: [String] {
        var counts: [String: Int] = [:]
        for entry in stateHistory {
            counts[entry.label, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    /// Common transitions (sorted by probability)
    var commonTransitions: [(from: String, to: String, probability: Double, avgDays: Double?)] {
        var transitions: [(from: String, to: String, probability: Double, avgDays: Double?)] = []

        for (fromState, destinations) in transitionMatrix {
            for (toState, probability) in destinations where fromState != toState {
                let avgDays = averageTransitionTime(from: fromState, to: toState)
                transitions.append((from: fromState, to: toState, probability: probability, avgDays: avgDays))
            }
        }

        return transitions.sorted { $0.probability > $1.probability }
    }

    /// Days in the selected month with state data, grouped by week rows for a calendar grid
    func calendarDays(for month: Date) -> [[CalendarDay]] {
        let calendar = Date.cal
        let monthComponents = calendar.dateComponents([.year, .month], from: month)
        guard let monthStart = calendar.date(from: monthComponents),
              let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }

        // Build lookup
        var stateLookup: [Date: String] = [:]
        for entry in stateHistory {
            stateLookup[calendar.startOfDay(for: entry.date)] = entry.label
        }

        // First weekday offset (1=Sunday)
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offset = firstWeekday - 1

        var days: [CalendarDay] = []

        // Leading empty days
        for _ in 0..<offset {
            days.append(CalendarDay(dayNumber: 0, stateLabel: nil))
        }

        // Actual days
        for day in monthRange {
            guard let date = calendar.date(bySetting: .day, value: day, of: monthStart) else { continue }
            let dateStart = calendar.startOfDay(for: date)
            days.append(CalendarDay(
                dayNumber: day,
                stateLabel: stateLookup[dateStart]
            ))
        }

        // Group into weeks of 7
        var weeks: [[CalendarDay]] = []
        var currentWeek: [CalendarDay] = []
        for day in days {
            currentWeek.append(day)
            if currentWeek.count == 7 {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }
        if !currentWeek.isEmpty {
            // Pad trailing
            while currentWeek.count < 7 {
                currentWeek.append(CalendarDay(dayNumber: 0, stateLabel: nil))
            }
            weeks.append(currentWeek)
        }

        return weeks
    }

    struct CalendarDay: Identifiable {
        let id = UUID()
        let dayNumber: Int
        let stateLabel: String?
    }
}
