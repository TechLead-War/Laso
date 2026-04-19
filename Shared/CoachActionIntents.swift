import Foundation
import AppIntents

/// Shared App Group bridge. Widget-side intents write a pending action key here,
/// the main app reads and consumes it on next scene activation to route the user.
///
/// `source` records which Live Activity surface originated the tap (e.g. "today_score"
/// vs "wind_down") so analytics can attribute tap-through + PMF funnels per surface.
enum CoachActionBridge {
    static let appGroupID = "group.com.lasohealth.fit"
    static let pendingActionKey = "coach.pendingAction"
    static let pendingSourceKey = "coach.pendingAction.source"
    static let pendingTimestampKey = "coach.pendingAction.ts"
    /// Anything older than this is ignored (user probably launched the app manually).
    static let pendingActionTTL: TimeInterval = 60

    struct Pending {
        let kind: CoachActionKind
        /// Originating surface — e.g. "today_score", "wind_down". `nil` for legacy callers.
        let source: String?
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func markPending(_ kind: CoachActionKind, source: String) {
        defaults?.set(kind.rawValue, forKey: pendingActionKey)
        defaults?.set(source, forKey: pendingSourceKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: pendingTimestampKey)
    }

    /// App-side: read and clear any recent pending action. Returns nil if none or expired.
    static func consumePending() -> Pending? {
        guard let raw = defaults?.string(forKey: pendingActionKey),
              let kind = CoachActionKind(rawValue: raw),
              let ts = defaults?.object(forKey: pendingTimestampKey) as? Double,
              Date().timeIntervalSince1970 - ts < pendingActionTTL else {
            return nil
        }
        let source = defaults?.string(forKey: pendingSourceKey)
        defaults?.removeObject(forKey: pendingActionKey)
        defaults?.removeObject(forKey: pendingSourceKey)
        defaults?.removeObject(forKey: pendingTimestampKey)
        return Pending(kind: kind, source: source)
    }
}

@available(iOS 17.0, *)
struct CoachSetIntentionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Set today's intention"
    static var description = IntentDescription("Open Laso and capture your focus for the day.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.setIntention, source: "today_score")
        return .result()
    }
}

@available(iOS 17.0, *)
struct CoachBreatheIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start a 2-minute breathwork reset"
    static var description = IntentDescription("Open Laso and start a quick breathing session.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.breathe, source: "today_score")
        return .result()
    }
}

@available(iOS 17.0, *)
struct CoachWindDownIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start wind-down routine"
    static var description = IntentDescription("Open Laso and begin the evening wind-down flow.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.windDown, source: "today_score")
        return .result()
    }
}

/// Dedicated intent for the Wind-Down Live Activity's "Breathe 2 min" button.
/// Attributes tap-through to the wind-down surface so PMF funnels can separate
/// wind-down engagement from the daily TodayScore surface.
@available(iOS 17.0, *)
struct WindDownBreatheIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Start a 2-minute wind-down breath"
    static var description = IntentDescription("Open Laso and begin a short breath session from tonight's wind-down.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.breathe, source: "wind_down")
        return .result()
    }
}
