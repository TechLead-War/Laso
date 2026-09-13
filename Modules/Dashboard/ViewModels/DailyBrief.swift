import Foundation

/// A reading against the person's own usual range, ready to draw.
struct UsualBand: Equatable {
    let low: Double
    let high: Double
    let value: Double
    let rangeText: String
}

/// Everything the Today tab shows, built once per refresh by `DailyBriefBuilder`.
/// Equatable so the dashboard can skip a republish when nothing on screen moved.
struct DailyBrief: Equatable {

    enum Tone { case good, fair, poor, neutral }

    struct Chip: Equatable {
        let text: String
        let tone: Tone
    }

    enum Trajectory { case improving, holding, slipping }

    struct Status: Equatable {
        let chips: [Chip]
        let headline: String
        let sentence: String
        let readiness: Int?
        let sparkline: [TrendSparkPoint]
        let band: PersonalBand?
    }

    struct Driver: Identifiable, Equatable {
        var id: DriverKind { kind }
        let kind: DriverKind
        let title: String
        let valueText: String
        let sentence: String
        let tone: Tone
        let band: UsualBand?
    }

    struct Move: Equatable {
        let kind: DailyMoveLog.MoveKind
        let title: String
        let reason: String
        let icon: String
        let source: String
        let isDone: Bool
        let reminderLabel: String
        let reminderFire: Date?
        let bedtime: Date?
        let canMarkDoneNow: Bool
    }

    struct FocusView: Equatable {
        struct KPICell: Equatable {
            let value: String
            let to: String?
            /// Whether the move is the good direction for this number. A falling
            /// VO2 max must not be drawn in the same green as a rising one.
            let improved: Bool
            let label: String
        }

        let record: FocusStore.FocusRecord
        let title: String
        let weekLabel: String
        let kpis: [KPICell]
        let dayIndex: Int
        let totalDays: Int
        let driverLine: String?
    }

    struct Verdict: Equatable {
        struct Line: Equatable {
            let done: Bool
            let title: String
            let detail: String
        }

        let headline: String
        let lines: [Line]
        let balanceBefore: Double?
        let balanceAfter: Double?
    }

    let status: Status
    let drivers: [Driver]
    let dayMove: Move
    let nightMove: Move?
    let focus: FocusView?
    let verdict: Verdict?
    let footer: String
}

// Explicit because synthesis only works in the declaring file.
extension TrendSparkPoint: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.date == rhs.date && lhs.value == rhs.value }
}

extension PersonalBand: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.low == rhs.low && lhs.high == rhs.high }
}
