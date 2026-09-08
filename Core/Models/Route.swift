import Foundation

/// Type-safe navigation routes replacing string-based navigation.
enum Route: Hashable {
    case insightsDetail
    case weeklyReview
    case correlationsDetail
    case healthStateTimeline
    case vitalityDetail
    case strainDetail
    case stressMonitor
    case brainHealth
    case sleepCoach
    case cycleDetail
    case achievements
    case journalEntry
    case todaysAction
    case askYourData
    /// Opens the Daily Mirror camera directly. The streak widget links here so a
    /// tap on it starts a capture instead of landing on the check-in sheet.
    case mirrorCapture

    /// Maps a `--ui-test-initial-route=<id>` launch-arg value to a Route.
    /// Used only for App Store screenshot capture.
    static func fromUITestIdentifier(_ raw: String) -> Route? {
        switch raw {
        case "insightsDetail": return .insightsDetail
        case "weeklyReview": return .weeklyReview
        case "correlationsDetail": return .correlationsDetail
        case "healthStateTimeline": return .healthStateTimeline
        case "vitalityDetail": return .vitalityDetail
        case "strainDetail": return .strainDetail
        case "stressMonitor": return .stressMonitor
        case "brainHealth": return .brainHealth
        case "sleepCoach": return .sleepCoach
        case "cycleDetail": return .cycleDetail
        case "achievements": return .achievements
        case "journalEntry": return .journalEntry
        case "todaysAction": return .todaysAction
        case "askYourData": return .askYourData
        case "mirrorCapture": return .mirrorCapture
        default: return nil
        }
    }
}
