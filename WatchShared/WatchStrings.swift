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
        static let markDone = "Mark done"
        static let markedDone = "Done"
    }

    enum CheckIn {
        static let greeting = "Good Morning"
        static let subtitle = "How are you feeling today?"
        static let done = "Done"
        static let sleepQuality = "Sleep quality"
        static let energyLevel = "Energy level"
        static let soreness = "Body soreness"
    }

    enum Journal {
        static let title = "Log"
    }

    /// What the wrist says when a write did not land. Every refusal has a line here:
    /// a write the phone threw away must never look the same as one it stored.
    enum Write {
        static func message(for rejection: WatchCommandRejection) -> String {
            switch rejection {
            case .earlierDay:
                return "That was for an earlier day, so it was not saved. Tap again for today."
            case .notStored:
                return "Your iPhone could not save that."
            case .notDelivered:
                return "That did not reach your iPhone. Try again."
            }
        }
    }

    /// The word on the wrist, and the fact under it.
    ///
    /// Every reason line states something measured. None of them is an instruction:
    /// telling someone to walk or stand is a job watchOS already does, and the wrist has
    /// one line to spend.
    enum Verdict {
        static func word(_ word: WatchWord) -> String {
            switch word {
            case .rest:       return "Rest"
            case .breathe:    return "Breathe"
            case .sleep:      return "Sleep"
            case .train:      return "Train"
            case .recovering: return "Recovering"
            case .warm:       return "Warm"
            case .steady:     return "Steady"
            }
        }

        static let rest = "Your body is under strain"
        static let train = "Recovered and unspent"
        static let steady = "Everything in your range"

        static func breathe(over: Int) -> String { "Heart rate \(over) above resting" }
        static func warm(over: Int) -> String { "Resting HR \(over) above normal" }

        static func recovering(days: Int) -> String {
            days <= 1 ? "A day after your hard day" : "\(days) days after your hard day"
        }

        static func sleep(minutes: Int) -> String {
            minutes > 0 ? "Wind down, bed in \(minutes) min" : "Past your bedtime target"
        }

        static func room(minutes: Int) -> String { "Room for \(minutes) more min" }
        static let ceilingReached = "You have spent today's room"

        static func learning(nights: Int) -> String {
            "\(nights) of \(WatchVerdictThresholds.baselineNightsRequired) nights"
        }

        /// Shown when the only thing the wrist knows came over from the phone, because
        /// its own sensors returned nothing. Names the source so the wearer is never told
        /// something is "in your range" when nothing was measured.
        static let phoneOnly = "From your iPhone score"

        static let liveNow = "Measured here"
        static let fromPhone = "from iPhone"
        static let yourUsual = "your usual"

        static func freshMinutes(_ minutes: Int) -> String { "\(minutes) min ago" }
    }

    /// What each screen says when it cannot show its normal content. None of these
    /// sends the user to their phone: on a worn watch the sensor path always has
    /// something true to say.
    enum State {
        /// HealthKit never reports a read denial, so this screen cannot tell "you tapped
        /// Don't Allow" apart from "this watch has no history yet". It says what is true
        /// of both and gives the one action that fixes either, instead of asserting a
        /// cause it cannot know.
        static let healthOffTitle = "No readings"
        static let healthOffDetail = "Wear your watch, or check"
        static let healthOffHint = "Settings › Privacy › Health"
        /// The reason line when the phone has never synced. It reports what the wrist
        /// actually measured and says nothing about a phone: an instruction to go and
        /// open the iPhone app is the exact failure this design was built to delete.
        static let noPhoneYet = "Nothing unusual right now"
    }

    enum Why {
        static let title = "Readiness"
        static let hrv = "HRV"
        static let restingHeartRate = "Resting HR"
        static let exercise = "Exercise"
        static let noScore = "No score yet"
    }

    enum Next {
        static let title = "Today"
        static let exercise = "Exercise"
        static let steps = "Steps"
        static let ceiling = "Room"
    }

    enum Complication {
        static let verdictName = "Today's word"
        static let verdictDescription = "What your body is doing, and how much room you have left."
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
