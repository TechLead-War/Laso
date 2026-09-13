import Foundation
import Testing
@testable import Laso

struct DailyBriefPlumbingTests {

    /// Widgets, Live Activities, push payloads and screenshot rows already in the
    /// wild carry these ids. Every one must still land somewhere real after the
    /// screens behind them were retired.
    @Test func everyOldRouteStillResolves() {
        let legacy: [String: Route] = [
            "todaysAction": .tab(.home),
            "weeklyReview": .tab(.progress),
            "sleepCoach": .driverDetail(.sleepBalance),
            "strainDetail": .driverDetail(.strainHigh),
            "stressMonitor": .driverDetail(.stressHigh),
            "brainHealth": .tab(.body),
            "vitalityDetail": .vitalityDetail,
            "mirrorCapture": .mirrorCapture,
            "insightsDetail": .insightsDetail,
            "driverDetail": .driverDetail(.restDays),
            "driverDetail.sleepBalance": .driverDetail(.sleepBalance),
            "body": .tab(.body),
            "progress": .tab(.progress),
            "today": .tab(.home)
        ]
        for (id, expected) in legacy {
            #expect(Route.fromUITestIdentifier(id) == expected, "\(id) no longer resolves to \(expected)")
        }
        #expect(Route.fromUITestIdentifier("driverDetail.notADriver") == nil)
    }

    /// The brief republishes only when one of its inputs moved. A focus or a
    /// ticked move changes nothing the analysis hash can see, so both revisions
    /// have to be part of the fingerprint or Today keeps showing the old state.
    @Test func theBriefFingerprintMovesWithFocusAndMoveLog() {
        let day = Date.cal.startOfDay(for: Date())
        func print(focus: Int = 1, moves: Int = 1, readiness: Int? = 72) -> Int {
            DashboardViewModel.briefFingerprint(
                day: day, cacheHash: 42, focusRevision: focus, contextRevision: 1,
                moveLogRevision: moves, verdictDismissRevision: 0, readiness: readiness,
                sleepSeconds: 25_200, stress: 30, exerciseMinutes: 20, hour: 9,
                dayReminderFire: nil, nightReminderFire: nil
            )
        }
        let base = print()
        #expect(print() == base, "identical inputs must not republish")
        #expect(print(focus: 2) != base, "a started or closed focus must republish")
        #expect(print(moves: 2) != base, "a ticked move must republish")
        #expect(print(readiness: 73) != base, "a readiness change must republish")
    }
}
