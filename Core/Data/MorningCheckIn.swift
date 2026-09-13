import Foundation

/// One morning check-in from the watch. Recorded by `MorningCheckInManager`
/// through `PhoneWatchSession`; the phone card that once showed it is gone.
struct MorningCheckIn: Codable {
    let date: Date
    /// 1 (terrible) to 5 (great)
    let sleepQuality: Int
    /// 1 (exhausted) to 5 (energized)
    let energyLevel: Int
    /// 1 (very sore) to 5 (no soreness)
    let soreness: Int
}
