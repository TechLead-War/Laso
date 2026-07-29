import Foundation
import SwiftUI
import Testing
@testable import Laso

/// The wrist's word-picking ladder.
///
/// These run in the iOS test target because `WatchVerdict`, `WatchBand` and `WatchTheme`
/// live in `WatchShared`, which compiles into the iPhone app as well as the two watch
/// targets. That is the whole reason the ladder is pure Swift with no HealthKit import.
struct WatchVerdictTests {

    // MARK: - Fixtures

    /// Alex on a plain Tuesday: everything measured, nothing unusual, phone in sync.
    /// Each test moves exactly one field so the rung under test is the only thing that
    /// can have fired.
    private func input(
        restingHeartRate: Double? = 55,
        heartRate: Double? = 68,
        heartRateAgeMinutes: Double? = 1,
        hrv: Double? = 60,
        stepsLastTenMinutes: Int = 10,
        exerciseLastTenMinutes: Int = 0,
        exerciseMinutes: Int = 12,
        nights: Int = 60,
        score: Int? = 62,
        payloadAgeMinutes: Double? = 5,
        bodyStress: Bool? = false,
        rhrBaseline: Double? = 55,
        hrvFloor: Double? = 47,
        hoursSinceHardDay: Double? = nil,
        ceiling: Int? = 30,
        minutesToBedtime: Double? = 500,
        denied: Bool = false
    ) -> WatchVerdictInput {
        WatchVerdictInput(
            restingHeartRate: restingHeartRate,
            heartRate: heartRate,
            heartRateAgeMinutes: heartRateAgeMinutes,
            heartRateVariability: hrv,
            stepsLastTenMinutes: stepsLastTenMinutes,
            exerciseMinutesLastTenMinutes: exerciseLastTenMinutes,
            exerciseMinutesToday: exerciseMinutes,
            nightsOfHistory: nights,
            readinessScore: score,
            payloadAgeMinutes: payloadAgeMinutes,
            bodyStressElevated: bodyStress,
            restingHeartRateBaseline: rhrBaseline,
            hrvBaselineFloor: hrvFloor,
            hoursSinceHardDay: hoursSinceHardDay,
            exerciseCeilingMinutes: ceiling,
            minutesToBedtime: minutesToBedtime,
            isHealthAccessDenied: denied
        )
    }

    // MARK: - Drift guards

    /// The watch targets cannot link `Common/`, so the recovery floors are written twice.
    /// This is the check that stops them drifting: a score may never be amber on the
    /// phone and green on the wrist.
    @Test func bandFloorsMatchTheApp() {
        #expect(WatchBand.optimalFloor == DS.optimalFloor)
        #expect(WatchBand.fairFloor == DS.fairFloor)
    }

    /// The watch renders the bundled palette, and it cannot do anything else.
    ///
    /// `AppColour.remote(_:light:dark:)` resolves score colours through Remote Config on
    /// the phone and falls back to the bundled pair under `#if WIDGET_EXTENSION`. No
    /// watch target links Firebase, so the wrist is permanently on the bundled pair —
    /// exactly like the iOS widget.
    ///
    /// The consequence, stated so nobody rediscovers it in a review: **publishing a
    /// score colour override moves the phone and leaves the widget and the watch
    /// behind.** That divergence is a property of the remote-config design, not of this
    /// file. What this test guards is narrower and still worth guarding: that
    /// `WatchTheme` carries the same bundled literals `AppColour` declares, so an edit
    /// to one is caught if it is not made to the other.
    @Test func bandColoursMatchTheBundledPalette() {
        func rgb(_ color: Color) -> [Int] {
            let dark = UITraitCollection(userInterfaceStyle: .dark)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).resolvedColor(with: dark).getRed(&r, green: &g, blue: &b, alpha: &a)
            return [r, g, b].map { Int(($0 * 255).rounded()) }
        }
        // The dark literals in Common/Theme/AppColour.swift.
        #expect(rgb(WatchTheme.optimal) == [51, 196, 141])
        #expect(rgb(WatchTheme.fair) == [227, 180, 90])
        #expect(rgb(WatchTheme.poor) == [224, 92, 100])
    }

    // MARK: - The floor

    /// The property the whole redesign rests on: on a worn watch there is always a word,
    /// so no screen ever has to fall back to telling someone to go open their iPhone.
    @Test func alwaysProducesAWordUnlessHealthAccessIsOff() {
        #expect(WatchVerdict.evaluate(input()) != nil)

        // Phone never seen, nothing measured but steps.
        let bare = input(
            restingHeartRate: nil, heartRate: nil, heartRateAgeMinutes: nil, hrv: nil,
            score: nil, payloadAgeMinutes: nil, bodyStress: nil,
            rhrBaseline: nil, hrvFloor: nil, ceiling: nil, minutesToBedtime: nil
        )
        #expect(WatchVerdict.evaluate(bare)?.word == .steady)

        // Health off but the phone has a score: still answers. The score is true whether
        // or not this watch can read its own sensors.
        #expect(WatchVerdict.evaluate(input(denied: true)) != nil)

        // Health off AND no phone score: the one genuinely empty state.
        #expect(WatchVerdict.evaluate(input(score: nil, denied: true)) == nil,
                "nothing measured and nothing sent is the only state with no word")
    }

    /// With no phone the wrist must not claim a personal range it does not have.
    @Test func withoutThePhoneItDoesNotClaimARange() {
        let bare = input(score: nil, payloadAgeMinutes: nil, bodyStress: nil,
                         rhrBaseline: nil, hrvFloor: nil, ceiling: nil, minutesToBedtime: nil)
        let verdict = WatchVerdict.evaluate(bare)
        #expect(verdict?.reason == WatchStrings.State.noPhoneYet)
        #expect(verdict?.headroomMinutes == nil, "no ceiling means no claim about room")
    }

    // MARK: - Rung order

    @Test func restOutranksEverything() {
        // Poor band and a suppressed HRV after a hard day: rungs 1 and 5 both qualify.
        let verdict = WatchVerdict.evaluate(input(hrv: 30, score: 30, hoursSinceHardDay: 24))
        #expect(verdict?.word == .rest)
        #expect(verdict?.rule == 1)
    }

    @Test func restAlsoFiresOnTheBodyStressFlagAloneAtAGoodScore() {
        let verdict = WatchVerdict.evaluate(input(score: 80, bodyStress: true))
        #expect(verdict?.word == .rest)
    }

    @Test func breatheNeedsAFreshSampleAndAStillWearer() {
        // 88 against a resting 55 is +33, well over the threshold.
        #expect(WatchVerdict.evaluate(input(heartRate: 88))?.word == .breathe)

        #expect(WatchVerdict.evaluate(input(heartRate: 88, stepsLastTenMinutes: 900))?.word != .breathe,
                "walking explains the raised rate, so there is nothing to point out")
        #expect(WatchVerdict.evaluate(input(heartRate: 88, stepsLastTenMinutes: 60))?.word != .breathe,
                "just over the stillness ceiling still counts as moving")
        #expect(WatchVerdict.evaluate(input(heartRate: 88, heartRateAgeMinutes: 45))?.word != .breathe,
                "a 45 minute old sample is not 'right now'")
        // A bike or rowing session earns exercise minutes with almost no steps, which is
        // exactly the case a step count alone reports as sitting still.
        #expect(WatchVerdict.evaluate(input(heartRate: 88, exerciseLastTenMinutes: 3))?.word != .breathe)
    }

    @Test func sleepFiresInsideTheWindDownWindowOnly() {
        #expect(WatchVerdict.evaluate(input(minutesToBedtime: 45))?.word == .sleep)
        #expect(WatchVerdict.evaluate(input(minutesToBedtime: 200))?.word != .sleep)
        #expect(WatchVerdict.evaluate(input(minutesToBedtime: -200))?.word != .sleep,
                "hours past bedtime the reminder is noise, not help")
    }

    /// The one expensive word. Training a body that needed rest costs real recovery, so
    /// this rung alone refuses to run on a stale payload.
    @Test func trainRequiresAFreshPayload() {
        let fresh = input(exerciseMinutes: 0, score: 80, payloadAgeMinutes: 5)
        #expect(WatchVerdict.evaluate(fresh)?.word == .train)

        let stale = input(exerciseMinutes: 0, score: 80, payloadAgeMinutes: 240)
        #expect(WatchVerdict.evaluate(stale)?.word != .train,
                "a four hour old payload may not start a hard session")

        let spent = input(exerciseMinutes: 25, score: 80, payloadAgeMinutes: 5)
        #expect(WatchVerdict.evaluate(spent)?.word != .train,
                "most of the ceiling is already spent, so there is no session to propose")
    }

    /// Every other word tolerates being stale. That asymmetry is what lets the design
    /// live inside the roughly four complication refreshes an hour watchOS allows.
    @Test func staleDataStillProducesEveryOtherWord() {
        let stale = input(heartRate: 88, payloadAgeMinutes: 600)
        #expect(WatchVerdict.evaluate(stale)?.word == .breathe)
    }

    @Test func recoveringNamesTheCauseAndWarmOnlyReportsIt() {
        // Suppressed HRV inside the window after a hard day: the cause is known.
        let recovering = WatchVerdict.evaluate(input(hrv: 40, hoursSinceHardDay: 48))
        #expect(recovering?.word == .recovering)
        #expect(recovering?.reason.contains("2") == true, "it should say how long ago")

        // Same suppressed HRV, no hard day to blame, resting rate up: report, don't blame.
        let warm = WatchVerdict.evaluate(input(restingHeartRate: 60, hrv: 40, hoursSinceHardDay: nil))
        #expect(warm?.word == .warm)

        // Hard day too long ago to still explain it.
        let old = WatchVerdict.evaluate(input(restingHeartRate: 55, hrv: 40, hoursSinceHardDay: 200))
        #expect(old?.word == .steady)
    }

    @Test func warmNeedsTheBaselineNotJustTheNumber() {
        #expect(WatchVerdict.evaluate(input(restingHeartRate: 62))?.word == .warm)
        #expect(WatchVerdict.evaluate(input(restingHeartRate: 62, rhrBaseline: nil))?.word == .steady,
                "62 bpm means nothing without this wearer's own normal")
    }

    // MARK: - Cold start

    /// Below the required nights the wrist names the cold start instead of inventing a
    /// verdict. Every phone-derived rung is off, but the live path still works.
    @Test func coldStartMakesNoClaims() {
        let cold = input(restingHeartRate: 70, hrv: 20, nights: 3, score: 30, hoursSinceHardDay: 24)
        let verdict = WatchVerdict.evaluate(cold)
        #expect(verdict?.word == .steady)
        #expect(verdict?.rule == 7)
        #expect(verdict?.reason == WatchStrings.Verdict.learning(nights: 3))

        // The measured rung is not gated on history, because it needs none.
        let coldButActivated = input(heartRate: 88, nights: 3)
        #expect(WatchVerdict.evaluate(coldButActivated)?.word == .breathe)
    }

    // MARK: - Headroom

    @Test func headroomCountsDownAndNeverGoesNegative() {
        #expect(WatchVerdict.evaluate(input(exerciseMinutes: 12, ceiling: 30))?.headroomMinutes == 18)
        #expect(WatchVerdict.evaluate(input(exerciseMinutes: 37, ceiling: 30))?.headroomMinutes == 0)
    }

    /// Without a ceiling from the phone the wrist says nothing about room. Substituting
    /// the plain Move goal would quietly turn a recovery-aware number into a copy of the
    /// Activity ring, which is the one thing this design must not become.
    @Test func noCeilingMeansNoHeadroomClaim() {
        let verdict = WatchVerdict.evaluate(input(ceiling: nil))
        #expect(verdict?.headroomMinutes == nil)
        #expect(verdict?.headroomLine == nil, "the line is dropped, never replaced by a stand-in")
    }

    /// Sensors empty but the phone has a score. The wrist must still answer, and must not
    /// claim anything is "in your range" when nothing was measured.
    @Test func aPhoneScoreAloneStillProducesAWord() {
        let sensorsOff = input(restingHeartRate: nil, heartRate: nil, heartRateAgeMinutes: nil,
                               hrv: nil, denied: true)
        let verdict = WatchVerdict.evaluate(sensorsOff)
        #expect(verdict?.word == .recovering, "a fair band with nothing measured is not 'steady'")
        #expect(verdict?.reason == WatchStrings.Verdict.phoneOnly)
        #expect(verdict?.rule == 45)

        // Poor band still outranks it: a rest call is the whole point of the phone link.
        let poor = input(restingHeartRate: nil, heartRate: nil, heartRateAgeMinutes: nil,
                         hrv: nil, score: 30, denied: true)
        #expect(WatchVerdict.evaluate(poor)?.word == .rest)

        // Nothing measured and nothing from the phone is the one genuinely empty state.
        let nothing = input(restingHeartRate: nil, heartRate: nil, heartRateAgeMinutes: nil,
                            hrv: nil, score: nil, denied: true)
        #expect(WatchVerdict.evaluate(nothing) == nil)
    }

    // MARK: - The cached word the watch face renders

    /// The face must not blank because the app has not run for an hour. Only `train` is
    /// freshness-gated in this design; a `--` complication is what the redesign removed.
    @Test func theCachedWordSurvivesAgeingButNotMidnight() {
        func cached(dayKey: String?, ageHours: Double) -> CachedWatchVerdict {
            CachedWatchVerdict(
                word: .recovering, reason: "2 days after your hard day", headroomMinutes: 18,
                band: .fair, computedAt: Date().addingTimeInterval(-ageHours * 3600),
                dayKey: dayKey, ceilingMinutes: 30
            )
        }
        let today = WatchBridge.dayKey(for: Date())
        #expect(!cached(dayKey: today, ageHours: 6).isForAnotherDay(),
                "six hours old is still today's word")
        let yesterday = WatchBridge.dayKey(for: Date().addingTimeInterval(-86_400))
        #expect(cached(dayKey: yesterday, ageHours: 1).isForAnotherDay(),
                "yesterday's word must leave the face however recently it was computed")
    }

    /// The gauge reads headroom and ceiling from one cached computation, so it can never
    /// pair values captured at different moments and run backwards.
    @Test func theGaugeFractionIsAlwaysInRange() {
        func fraction(headroom: Int?, ceiling: Int?) -> Double? {
            CachedWatchVerdict(
                word: .steady, reason: "", headroomMinutes: headroom, band: nil,
                computedAt: Date(), dayKey: nil, ceilingMinutes: ceiling
            ).spentFraction
        }
        #expect(fraction(headroom: 18, ceiling: 30) == 0.4)
        #expect(fraction(headroom: 0, ceiling: 30) == 1)
        #expect(fraction(headroom: 40, ceiling: 30) == 0, "never negative")
        #expect(fraction(headroom: 5, ceiling: nil) == nil, "no ceiling, no gauge")
        #expect(fraction(headroom: 5, ceiling: 0) == nil, "no division by zero")
    }

    // MARK: - Wire compatibility

    /// A watch on an older build must survive a schema 2 payload, and a schema 1 payload
    /// must still decode here. Getting this wrong blanks the wrist on any staged rollout.
    @Test func schemaOnePayloadStillDecodes() throws {
        let json = """
        {"dayKey":"2026-07-29","readinessScore":62,"readinessGrade":"C","dayType":"Building",
         "actionDone":false,"checkInAvailable":false,"updatedAt":774000000}
        """
        let payload = try JSONDecoder().decode(WatchPayload.self, from: Data(json.utf8))
        #expect(payload.version == 1)
        #expect(payload.readinessScore == 62)
        #expect(payload.exerciseCeilingMinutes == nil, "schema 2 fields are absent, not defaulted")
    }

    @Test func schemaTwoRoundTrips() throws {
        let sent = WatchPayload(
            dayKey: "2026-07-29", readinessScore: 62, readinessGrade: "C", dayType: "Building",
            actionHeadline: nil, actionDetail: nil, actionIcon: nil, actionDone: false,
            checkInAvailable: false, updatedAt: Date(timeIntervalSince1970: 774_000_000),
            bodyStressElevated: false, restingHeartRateBaseline: 55, hrvBaselineFloor: 47,
            hoursSinceHardDay: 48, exerciseCeilingMinutes: 30, nightsOfHistory: 60
        )
        let decoded = try JSONDecoder().decode(WatchPayload.self, from: JSONEncoder().encode(sent))
        #expect(decoded == sent)
        #expect(decoded.version == 2)
    }
}
