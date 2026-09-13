import Foundation

/// Type-safe navigation routes replacing string-based navigation.
enum Route: Hashable {
    case insightsDetail
    case correlationsDetail
    case healthStateTimeline
    case vitalityDetail
    case cycleDetail
    case achievements
    case journalEntry
    case askYourData
    /// Opens the Daily Mirror camera directly. The streak widget links here so a
    /// tap on it starts a capture instead of landing on the check-in sheet.
    case mirrorCapture
    /// One driver's detail screen. Every ranked driver on the brief opens here.
    case driverDetail(DriverKind)
    /// Selects a tab instead of pushing a screen, so widget URLs, pushes and
    /// screenshot launches land on Body or Progress through the one switch.
    case tab(AppTab)

    private static let driverDetailPrefix = "driverDetail."

    /// Maps a `--ui-test-initial-route=<id>` launch-arg value to a Route.
    /// Used only for App Store screenshot capture. `driverDetail.<DriverKind id>`
    /// opens one driver; bare `driverDetail` opens rest days.
    static func fromUITestIdentifier(_ raw: String) -> Route? {
        switch raw {
        case "insightsDetail": return .insightsDetail
        case "correlationsDetail": return .correlationsDetail
        case "healthStateTimeline": return .healthStateTimeline
        case "vitalityDetail": return .vitalityDetail
        case "cycleDetail": return .cycleDetail
        case "achievements": return .achievements
        case "journalEntry": return .journalEntry
        case "askYourData": return .askYourData
        // Retired screens. Widgets, Live Activities and push payloads already in
        // the wild still send these ids, so each lands on what replaced it.
        case "todaysAction": return .tab(.home)
        case "weeklyReview": return .tab(.progress)
        case "sleepCoach": return .driverDetail(.sleepBalance)
        case "strainDetail": return .driverDetail(.strainHigh)
        case "stressMonitor": return .driverDetail(.stressHigh)
        case "brainHealth": return .tab(.body)
        case "mirrorCapture": return .mirrorCapture
        case "driverDetail": return .driverDetail(.restDays)
        case "body": return .tab(.body)
        case "progress": return .tab(.progress)
        case "today": return .tab(.home)
        default:
            guard raw.hasPrefix(driverDetailPrefix),
                  let kind = DriverKind.fromIdentifier(String(raw.dropFirst(driverDetailPrefix.count))) else {
                return nil
            }
            return .driverDetail(kind)
        }
    }
}
