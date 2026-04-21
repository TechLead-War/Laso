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
        default: return AppColour.stateDefault
        }
    }

    /// State distribution for a given month: [label: day count]
    func stateDistribution(for month: Date) -> [String: Int] {
        let calendar = Calendar.current
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

    /// Current streak: how many consecutive days in the current state
    var currentStreak: (state: String, days: Int)? {
        guard let current = currentState else { return nil }
        return (state: current.label, days: current.daysInState)
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
        let calendar = Calendar.current
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
            days.append(CalendarDay(date: nil, dayNumber: 0, stateLabel: nil))
        }

        // Actual days
        for day in monthRange {
            guard let date = calendar.date(bySetting: .day, value: day, of: monthStart) else { continue }
            let dateStart = calendar.startOfDay(for: date)
            days.append(CalendarDay(
                date: dateStart,
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
                currentWeek.append(CalendarDay(date: nil, dayNumber: 0, stateLabel: nil))
            }
            weeks.append(currentWeek)
        }

        return weeks
    }

    struct CalendarDay: Identifiable {
        let id = UUID()
        let date: Date?
        let dayNumber: Int
        let stateLabel: String?
    }
}
