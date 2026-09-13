import Foundation
import Testing
@testable import Laso

/// The sorting rules behind the Body tab, pinned so a refactor of the engines
/// cannot quietly move a signal between "off" and "at your usual".
@MainActor
struct BodyRowsBuilderTests {

    /// The reference morning: a 2h 20m balance, bounce-back 6% under usual and
    /// 4 rest days in 28. All three are off, in the tab's fixed order, and each
    /// opens its own driver.
    @Test func offUsualRowsComeFirstAndCarryTheirDriverRoute() {
        let rows = BodyRowsBuilder.build(Self.referenceMorning())

        let expectedRoutes: [Route?] = [
            .driverDetail(.sleepBalance), .driverDetail(.heartRateBounceBack), .driverDetail(.restDays)
        ]
        #expect(rows.off.map(\.id) == ["sleepBalance", "heartRateBounceBack", "restDays"])
        #expect(rows.off.map(\.route) == expectedRoutes)
        #expect(rows.off[0].status == Copy.Body.Status.behindNights(SleepDebtTracker.nightsToClear(debtHours: 2.0 + 20.0 / 60.0)))
        #expect(rows.off[1].valueText == Copy.DailyBrief.Driver.hrrValue(6))
        #expect(rows.off[1].tone == .poor, "bounce-back is the earliest under-recovery sign, so it reads red")
        #expect(rows.off[2].status == Copy.Body.Status.restBelow(2))
        #expect(rows.usual.isEmpty)
    }

    /// A reading with no history behind it is not a finding: it sits at usual
    /// with nothing to draw, rather than being judged against a population table.
    @Test func aMetricWithoutABaselineLandsAtUsualWithNoBand() {
        var s = Self.referenceMorning()
        s.latest[.heartRateVariability] = 65

        let rows = BodyRowsBuilder.build(s)
        let hrv = rows.usual.first { $0.id == "hrv" }

        #expect(!rows.off.contains { $0.id == "hrv" })
        #expect(hrv?.band == nil)
        #expect(hrv?.status == Copy.Body.Status.usual)
        #expect(hrv?.metric == .heartRateVariability, "no driver explains HRV, so the row opens the metric")
    }

    private static func referenceMorning() -> BodyRowsBuilder.Snapshot {
        let now = Date.cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let hrrBaseline = UserBaseline(metric: .heartRateRecovery, mean: 30, standardDeviation: 2,
                                       median: 30, sampleCount: 30, lastUpdated: now)
        return BodyRowsBuilder.Snapshot(
            now: now,
            baselines: [.heartRateRecovery: hrrBaseline],
            latest: [:],
            sleepDebtHours: 2.0 + 20.0 / 60.0,
            restDeficit: RecoveryAnalyzer.RestDeficit(restDays28: 4, workoutDays28: 24, highIntensity28: 10, recommendedPerWeek: 2),
            hrr: (current: 28.2, baseline: hrrBaseline),
            strainLast6: [], strainTarget: nil, stressLevel: nil,
            vitalityAge: 0, chronologicalAge: 0, cycle: nil,
            heartRateNow: nil, isHeartRateCalm: true, isWearingWatch: true,
            notSynced: []
        )
    }
}
