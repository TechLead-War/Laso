import Foundation
import Observation

/// Holds the deep-link target requested by a remote-push tap until the scene is
/// ready to navigate. The scene observes `pendingRoute`, appends it to the
/// correct tab path, then calls `consumePending()` to clear it.
///
/// Push payloads carry a `route` string (matching a `Route` raw identifier).
/// Routing reuses `Route.fromUITestIdentifier` so there is a single string→Route
/// map; no duplicate switch lives here. The widget `laso://` deep-link path goes
/// through the scene's `onOpenURL` handler directly, not this router.
@MainActor
@Observable
final class NotificationRouter {
    static let shared = NotificationRouter()

    private(set) var pendingRoute: Route?

    private init() {}

    /// Parse a remote-push `userInfo` payload and stage its route for navigation.
    /// An unmappable route is reported as `push_route_unresolved` so routing gaps
    /// are visible in analytics rather than failing silently. Not a suppression:
    /// this runs from `didReceive`, so the push was already delivered and opened.
    func handle(userInfo: [AnyHashable: Any]) {
        guard let routeString = userInfo["route"] as? String else { return }

        guard let route = Route.fromUITestIdentifier(routeString) else {
            AppAnalytics.shared.trackPushRouteUnresolved(route: routeString)
            return
        }

        pendingRoute = route
    }

    /// Return the staged route and clear it so it is navigated to only once.
    /// Mirrors `CoachActionBridge.consumePending()`.
    func consumePending() -> Route? {
        defer { pendingRoute = nil }
        return pendingRoute
    }
}
