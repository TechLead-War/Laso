import Foundation

/// Every user-visible string on the watch.
///
/// Deliberately plain Swift rather than `Common/Copy`: each Copy accessor resolves
/// through Firebase Remote Config, and no watch target links Firebase. A file under
/// `Common/Copy` would also be scraped into the admin dashboard as a remotely
/// editable key that the watch could never read.
///
/// Values are kept byte identical to the phone's English defaults so the same label
/// never reads differently on the two screens.
enum WatchStrings {

    enum Home {
        static let readinessLabel = "Readiness"
        static let todaysAction = "Today's Action"
        static let markDone = "Mark done"
        static let markedDone = "Done"
        static let noAction = "No action yet. Open Laso on your iPhone."
        static let stale = "Open Laso on your iPhone to refresh."
        static let notPaired = "Open Laso on your iPhone to connect."
    }

    enum CheckIn {
        static let greeting = "Good Morning"
        static let subtitle = "How are you feeling today?"
        static let done = "Done"
        static let sleepQuality = "Sleep quality"
        static let energyLevel = "Energy level"
        static let soreness = "Body soreness"
        static let saved = "Saved"
    }

    enum Journal {
        static let title = "Log"
        static let saved = "Logged"
    }

    /// What the wrist says when a write did not land. Every refusal has a line here:
    /// a write the phone threw away must never look the same as one it stored.
    enum Write {
        static func message(for rejection: WatchCommandRejection) -> String {
            switch rejection {
            case .earlierDay:
                return "That was for an earlier day, so it was not saved. Tap again for today."
            case .notStored:
                return "Your iPhone could not save that. Open Laso on your iPhone."
            case .notDelivered:
                return "That did not reach your iPhone. Try again."
            }
        }
    }

    enum Complication {
        static let name = "Readiness"
        static let description = "Your readiness score at a glance."
    }

    /// Emoji scales for the check-in, in the same order as the phone's five point
    /// scale so a 3 on the wrist means exactly what a 3 means in the app.
    enum CheckInScale {
        static let sleepQuality = ["😫", "😕", "😐", "😊", "😴"]
        static let energyLevel = ["🪫", "😮‍💨", "😐", "💪", "⚡"]
        static let soreness = ["😵", "😣", "😐", "👌", "🤸"]
    }
}

/// The journal categories offered as one tap quick logs on the wrist.
///
/// `rawValue` must match a `JournalCategory` case exactly, or the phone stores a row
/// the daily summary cannot read. `WatchQuickTag.validate()` is the runnable check
/// for that and runs on the phone at session start, where `JournalCategory` exists.
struct WatchQuickTag: Identifiable, Equatable {

    let rawValue: String
    let label: String
    let systemImage: String

    /// Journal values are per entry amounts, so a one tap log records one unit.
    /// The wrist has no room for a stepper, and the phone screen remains the place
    /// to enter an exact number.
    let value: Double

    var id: String { rawValue }

    static let all: [WatchQuickTag] = [
        WatchQuickTag(rawValue: "caffeine", label: "Caffeine", systemImage: "cup.and.saucer.fill", value: 1),
        WatchQuickTag(rawValue: "water", label: "Water", systemImage: "drop.fill", value: 1),
        WatchQuickTag(rawValue: "alcohol", label: "Alcohol", systemImage: "wineglass.fill", value: 1),
        WatchQuickTag(rawValue: "supplements", label: "Supplements", systemImage: "pills.fill", value: 1)
    ]
}
