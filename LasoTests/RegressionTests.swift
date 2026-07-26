import Foundation
import Testing
@testable import Laso

/// One test per bug that reached a user, so the same one cannot come back.
///
/// Every case here is a real defect found by testing or auditing the app, not a
/// hypothetical. The comment on each says what the user actually saw.
struct RegressionTests {

    // MARK: - Vitality

    /// Every metric chip on the Vitality screen printed the same "12y", because
    /// the reference tables stop at age 20 and anything better clamped to it.
    @Test func metricBetterThanYoungestReferenceIsFlagged() {
        let table = [(age: 20, value: 60.0), (age: 40, value: 70.0)]

        let beyond = VitalityNorms.metricAge(value: 40, table: table, higherIsBetter: false)
        #expect(beyond.isBeyondYoungestReference,
                "a value better than the youngest row must be flagged, not printed as a real age")

        let onTheRow = VitalityNorms.metricAge(value: 60, table: table, higherIsBetter: false)
        #expect(!onTheRow.isBeyondYoungestReference,
                "a value sitting exactly on the youngest row is a real reading")

        let interior = VitalityNorms.metricAge(value: 65, table: table, higherIsBetter: false)
        #expect(!interior.isBeyondYoungestReference)
        #expect(interior.age > 20 && interior.age < 40, "an interior value interpolates")
    }

    // MARK: - Notifications

    /// The "good morning" summary fired at about 23:40 every night, because the
    /// wake detector resolved to the user's bedtime. This clamp is the backstop
    /// that stops any future detector bug reaching a scheduler.
    @Test func wakeTimeCannotScheduleANightPush() {
        let midnight = WakeUpTimeDetector.clamped(hour: 23, minute: 40, origin: "test")
        #expect(midnight.hour <= WakeUpTimeDetector.latestWakeHour)

        let dawn = WakeUpTimeDetector.clamped(hour: 2, minute: 0, origin: "test")
        #expect(dawn.hour >= WakeUpTimeDetector.earliestWakeHour)

        let real = WakeUpTimeDetector.clamped(hour: 7, minute: 15, origin: "test")
        #expect(real.hour == 7 && real.minute == 15, "a sane wake time passes through untouched")
    }

    // MARK: - Sample storage

    /// The dedupe key divided epoch seconds by 86400, a UTC bucket applied to
    /// local dates. In India the boundary fell at 05:30 local, so an early wake
    /// up silently overwrote the previous night.
    @Test func twoLocalDaysNeverShareABucket() {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 26
        components.hour = 5
        let sunday = Date.cal.date(from: components)!

        components.day = 27
        components.hour = 5
        let monday = Date.cal.date(from: components)!

        #expect(MetricSample.localDayBucket(for: sunday) != MetricSample.localDayBucket(for: monday),
                "an early morning reading on two different days must not collide")

        components.day = 26
        components.hour = 23
        let sundayNight = Date.cal.date(from: components)!
        #expect(MetricSample.localDayBucket(for: sunday) == MetricSample.localDayBucket(for: sundayNight),
                "morning and night of the same local day are one bucket")
    }

    // MARK: - Daily action

    /// Widget and watch showed a stale action, because the store returned an
    /// entry from an earlier day rather than nothing.
    @Test func yesterdaysActionIsNotOfferedAsTodays() {
        DailyActionStore.clear()
        defer { DailyActionStore.clear() }

        let yesterday = Date.cal.date(byAdding: .day, value: -1, to: Date())!
        DailyActionStore.save(title: "Walk", subtitle: "20 min", icon: "figure.walk", day: yesterday)
        #expect(DailyActionStore.today() == nil)

        DailyActionStore.save(title: "Walk", subtitle: "20 min", icon: "figure.walk")
        #expect(DailyActionStore.today()?.title == "Walk")
    }

    // MARK: - Watch link

    /// WatchConnectivity redelivers a queued transfer, and the journal writer
    /// always inserts, so one tap on the wrist was stored twice.
    @Test func aRedeliveredWristTapIsAppliedOnce() {
        let suite = UserDefaults(suiteName: "regression.\(UUID().uuidString)")!
        let ledger = AppliedCommandLedger(defaults: suite)
        let tap = UUID()

        #expect(ledger.claim(tap), "first delivery is applied")
        #expect(!ledger.claim(tap), "the redelivery is refused")
        #expect(ledger.claim(UUID()), "a different tap is unaffected")
    }

    /// The wrist presented an old payload as today's truth.
    @Test func anOldPayloadIsNotShownAsToday() {
        let today = WatchBridge.dayKey(for: Date())
        func payload(dayKey: String, age: TimeInterval) -> WatchPayload {
            WatchPayload(
                dayKey: dayKey, readinessScore: 72, readinessGrade: "B", dayType: "Maintain",
                actionHeadline: nil, actionDetail: nil, actionIcon: nil, actionDone: false,
                checkInAvailable: false, updatedAt: Date().addingTimeInterval(-age)
            )
        }

        #expect(!payload(dayKey: today, age: 0).isStale())
        #expect(payload(dayKey: today, age: WatchBridge.stalePayloadInterval + 1).isStale())

        let yesterday = WatchBridge.dayKey(for: Date().addingTimeInterval(-86_400))
        #expect(payload(dayKey: yesterday, age: 0).isStale(),
                "a payload for another day is stale however fresh it is")
    }
}
