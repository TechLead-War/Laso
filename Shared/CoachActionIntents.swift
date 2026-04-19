import Foundation
import AppIntents

/// Shared App Group bridge. Widget-side intents write a pending action key here,
/// the main app reads and consumes it on next scene activation to route the user.
enum CoachActionBridge {
    static let appGroupID = "group.com.lasohealth.fit"
    static let pendingActionKey = "coach.pendingAction"
    static let pendingTimestampKey = "coach.pendingAction.ts"
    /// Anything older than this is ignored (user probably launched the app manually).
    static let pendingActionTTL: TimeInterval = 60

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func markPending(_ kind: CoachActionKind) {
        defaults?.set(kind.rawValue, forKey: pendingActionKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: pendingTimestampKey)
    }

    /// App-side: read and clear any recent pending action. Returns nil if none or expired.
    static func consumePending() -> CoachActionKind? {
        guard let raw = defaults?.string(forKey: pendingActionKey),
              let kind = CoachActionKind(rawValue: raw),
              let ts = defaults?.object(forKey: pendingTimestampKey) as? Double,
              Date().timeIntervalSince1970 - ts < pendingActionTTL else {
            return nil
        }
        defaults?.removeObject(forKey: pendingActionKey)
        defaults?.removeObject(forKey: pendingTimestampKey)
        return kind
    }
}

@available(iOS 17.0, *)
struct CoachSetIntentionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Set today's intention"
    static var description = IntentDescription("Open Laso and capture your focus for the day.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.setIntention)
        return .result()
    }
}

@available(iOS 17.0, *)
struct CoachBreatheIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start a 2-minute breathwork reset"
    static var description = IntentDescription("Open Laso and start a quick breathing session.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.breathe)
        return .result()
    }
}

@available(iOS 17.0, *)
struct CoachWindDownIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start wind-down routine"
    static var description = IntentDescription("Open Laso and begin the evening wind-down flow.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.windDown)
        return .result()
    }
}
