import Foundation

// MARK: - Morning Check-In Model

/// The check-in card this file was named for was deleted (KEEP-KILL): its
/// readiness adjustment was written and read nowhere, so answering changed no
/// pixel, and the derived-score properties went with it. The model itself
/// stays because the watch check-in path (PhoneWatchSession ->
/// MorningCheckInManager) still records these values; that path's fate is a
/// separate KEEP-KILL decision. When it is resolved, this type belongs next
/// to MorningCheckInManager in Core/Data.
struct MorningCheckIn: Codable {
    let date: Date
    /// 1 (terrible) to 5 (great)
    let sleepQuality: Int
    /// 1 (exhausted) to 5 (energized)
    let energyLevel: Int
    /// 1 (very sore) to 5 (no soreness)
    let soreness: Int
}
