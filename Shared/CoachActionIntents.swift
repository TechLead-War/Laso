import Foundation
import AppIntents
#if canImport(ActivityKit)
import ActivityKit
#endif

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
    /// Epoch of the "I'm heading in" tap on the wind-down activity. Kept apart
    /// from the pending action: it does not open the app and must outlive the night.
    static let headedInKey = "coach.headedIn.ts"

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

    static func markHeadedIn(at date: Date) {
        defaults?.set(date.timeIntervalSince1970, forKey: headedInKey)
    }

    /// App-side: read and clear the heading-in tap. `maxAge` has to cover a
    /// whole night, since the app is usually opened the next morning, yet stay
    /// short of a day so a tap cannot be credited to the following evening.
    static func consumeHeadedIn(maxAge: TimeInterval = 20 * 3600) -> Date? {
        guard let ts = defaults?.object(forKey: headedInKey) as? Double else { return nil }
        defaults?.removeObject(forKey: headedInKey)
        guard Date().timeIntervalSince1970 - ts <= maxAge else { return nil }
        return Date(timeIntervalSince1970: ts)
    }
}

@available(iOS 17.0, *)
struct CoachSetIntentionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Set today's intention"
    static let description = IntentDescription("Open Laso and capture your focus for the day.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.setIntention, source: "today_score")
        return .result()
    }
}

@available(iOS 17.0, *)
struct CoachBreatheIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start a 2-minute breathwork reset"
    static let description = IntentDescription("Open Laso and start a quick breathing session.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.breathe, source: "today_score")
        return .result()
    }
}

@available(iOS 17.0, *)
struct CoachWindDownIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start wind-down routine"
    static let description = IntentDescription("Open Laso and begin the evening wind-down flow.")
    static let openAppWhenRun: Bool = true

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
    static let title: LocalizedStringResource = "Start a 2-minute wind-down breath"
    static let description = IntentDescription("Open Laso and begin a short breath session from tonight's wind-down.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        CoachActionBridge.markPending(.breathe, source: "wind_down")
        return .result()
    }
}

/// "I'm heading in" on the Wind-Down Live Activity. The one intent here that
/// keeps the app closed: the person is putting the phone down, so the tap is
/// stamped onto the activity in place and the app reads it on its next launch.
@available(iOS 17.0, *)
struct WindDownHeadingInIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "I'm heading in"
    static let description = IntentDescription("Log that you are heading to bed from tonight's wind-down.")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let now = Date()
        CoachActionBridge.markHeadedIn(at: now)
        #if canImport(ActivityKit)
        if let activity = Activity<WindDownActivityAttributes>.activities.first {
            var state = activity.content.state
            state.headedInAt = now
            await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
        }
        #endif
        return .result()
    }
}
