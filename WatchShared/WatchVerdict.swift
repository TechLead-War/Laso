import Foundation

/// The word the wrist shows, and the rule that chose it.
///
/// Lives in `WatchShared` rather than in `LasoWatch` on purpose: this file is pure
/// Swift with no HealthKit and no SwiftUI, so it compiles into the iPhone app as well
/// and `LasoTests` can exercise every rung. The watch app and the complication both
/// call `WatchVerdict.evaluate`, so the face and the app can never disagree about
/// today's word.
///
/// The design rule the ladder enforces: **a word only reaches the headline if the user
/// could not already know it.** Stand, drink, walk and move prompts are deliberately
/// absent — watchOS already ships stand reminders and Activity rings, and the wrist has
/// one line to spend.
enum WatchWord: String, Codable, CaseIterable {

    // Orders. Rare, and each one rests on something the wearer cannot feel or count.
    case rest
    case breathe
    case sleep
    case train

    // States. Most days. A fact measured against this wearer's own baseline, never a
    // command.
    case recovering
    case warm
    case steady
}

/// Where a word sits on the three-band recovery scale, so colour and word always agree.
enum WatchBand: String, Codable {
    case optimal
    case fair
    case poor

    /// Mirrors `DesignSystem.recoveryTier`. The floors are duplicated here because no
    /// watch target links `Common/`, and `WatchVerdictTests.bandFloorsMatchTheApp`
    /// fails the build if the two ever drift apart.
    static func of(score: Int) -> WatchBand {
        if score >= optimalFloor { return .optimal }
        if score >= fairFloor { return .fair }
        return .poor
    }

    static let optimalFloor = 67
    static let fairFloor = 45
}

// MARK: - Thresholds

/// Every number the ladder compares against, named and sourced in one place.
///
/// HEURISTIC — unvalidated, same standing as the phone's scorer configs. These are
/// product thresholds, not clinical ones, and none of them may be inlined at a call
/// site.
enum WatchVerdictThresholds {

    /// Heart rate this far above resting, while the wearer is still, is the point at
    /// which a person is measurably activated but usually cannot feel it. Matches the
    /// elevated-HR framing the phone's stress copy already uses.
    static let breatheHeartRateOverResting: Double = 20

    /// Steps in the last ten minutes below this counts as "sitting still". Above it the
    /// raised heart rate is explained by movement and needs no comment.
    static let breatheStillStepCeiling: Int = 50

    /// Any exercise minute earned in the last ten minutes means the wearer is working
    /// out, whatever the step count says, and a raised heart rate needs no comment.
    static let breatheExerciseCeiling: Int = 0

    /// A heart rate sample older than this cannot be called "right now".
    static let liveHeartRateMaxAgeMinutes: Double = 5

    /// How close to the bedtime target the wind-down word appears, and how long it
    /// stays up after it. Matches `WindDownScheduler.leadMinutes` on the phone.
    static let sleepLeadMinutes: Double = 60
    static let sleepTrailMinutes: Double = 90

    /// A hard day still explains a suppressed HRV for about this long. Beyond it the
    /// suppression needs a different explanation, so the word falls through to `warm`
    /// or `steady` rather than blaming a workout the body has finished paying for.
    static let recoveringWindowHours: Double = 72

    /// Resting heart rate this far above the wearer's own baseline is worth naming.
    /// Below it the difference is inside normal night-to-night noise.
    static let warmRestingHeartRateDelta: Double = 2

    /// A payload older than this cannot carry `train`, the one word that is expensive
    /// when wrong. Every other word tolerates being stale, which is what lets the
    /// design survive the roughly four complication refreshes an hour watchOS allows.
    static let trainMaxPayloadAgeMinutes: Double = 60

    /// Below this fraction of today's ceiling there is enough room left for the session
    /// `train` is proposing.
    static let trainUnspentFraction: Double = 0.5

    /// Nights of history before a personal range exists. Named so the cold-start screen
    /// and the ladder can never disagree about when the wrist starts making claims.
    static let baselineNightsRequired: Int = 7
}

// MARK: - Input

/// Everything the ladder reads. Assembled by the watch app from two sources: values it
/// measured itself through HealthKit, and the phone's cached payload.
///
/// Split deliberately. Anything the wrist can measure is never nil on a worn watch, so
/// the ladder always produces a word even with the phone switched off. Anything that
/// needs 30 to 90 days of history is optional, and the rules that use it are skipped
/// when it is missing rather than guessed at.
struct WatchVerdictInput {

    // Measured on the wrist.
    var restingHeartRate: Double?
    var heartRate: Double?
    var heartRateAgeMinutes: Double?
    var heartRateVariability: Double?
    var stepsLastTenMinutes: Int

    /// Exercise minutes earned in the last ten minutes. The only workout signal the wrist
    /// can read without an `HKWorkoutSession`, and it catches the low-step cases (bike,
    /// rower, weights) that a step count alone reports as sitting still.
    var exerciseMinutesLastTenMinutes: Int

    var exerciseMinutesToday: Int
    var nightsOfHistory: Int

    // From the phone. Nil when it has never synced or the value is not computable yet.
    var readinessScore: Int?
    var payloadAgeMinutes: Double?
    var bodyStressElevated: Bool?
    var restingHeartRateBaseline: Double?
    var hrvBaselineFloor: Double?
    var hoursSinceHardDay: Double?
    var exerciseCeilingMinutes: Int?
    var minutesToBedtime: Double?

    /// The wrist measured nothing: read access refused, or no history on this watch.
    var isHealthAccessDenied: Bool = false

    /// True when not one sensor value came back. The measured rungs cannot run, but a
    /// phone score still can.
    var hasNoMeasurements: Bool {
        restingHeartRate == nil && heartRate == nil && heartRateVariability == nil
    }

    /// The phone has a score for today and it is recent enough to reason from.
    var isPhoneAware: Bool {
        readinessScore != nil && band != nil
    }

    var band: WatchBand? {
        readinessScore.map(WatchBand.of(score:))
    }

    /// True before the wrist has enough nights to claim a personal range.
    var isColdStart: Bool {
        nightsOfHistory < WatchVerdictThresholds.baselineNightsRequired
    }
}

// MARK: - Output

/// The word, why it was chosen, and how much movement is left in today's ceiling.
struct WatchVerdict: Equatable {

    let word: WatchWord

    /// Which rung fired, 1 through 7. Carried so the reason line, the analytics event
    /// and the unit tests all name the same rule.
    let rule: Int

    /// The line under the word. A fact, never an instruction.
    let reason: String

    /// Minutes of movement left before today's ceiling, or nil when no ceiling is known.
    /// This is the only value on the screen that moves through the day.
    let headroomMinutes: Int?

    var band: WatchBand?

    /// Nil when the phone has never sent a ceiling.
    ///
    /// The line is then dropped from every surface rather than replaced with a stand-in.
    /// Two options were rejected: falling back to the plain Move goal, which would
    /// quietly turn a recovery-aware number into a copy of the Activity ring, and asking
    /// the wearer to open their iPhone, which is the failure this whole design deletes.
    var headroomLine: String? {
        guard let headroomMinutes else { return nil }
        return headroomMinutes > 0
            ? WatchStrings.Verdict.room(minutes: headroomMinutes)
            : WatchStrings.Verdict.ceilingReached
    }
}

// MARK: - The ladder

extension WatchVerdict {

    /// First match wins. Rungs 1 to 4 are orders and every one of them rests on
    /// something the wearer cannot work out alone. Rungs 5 to 7 are states.
    ///
    /// Returns nil only when the wrist has measured nothing AND the phone has sent
    /// nothing. That is the single state in the design with no word, and it is genuinely
    /// empty: there is no fact of any kind to report.
    ///
    /// Sensors off but a phone score present is not that state. The score is still true,
    /// so the ladder runs and the phone-derived rungs answer — a watch with Health
    /// switched off should still be able to tell you to rest.
    static func evaluate(_ i: WatchVerdictInput, now: Date = Date()) -> WatchVerdict? {
        guard !i.isHealthAccessDenied || i.isPhoneAware else { return nil }

        typealias t = WatchVerdictThresholds
        let headroom = headroom(i)
        let band = i.band

        func made(_ word: WatchWord, _ rule: Int, _ reason: String) -> WatchVerdict {
            WatchVerdict(word: word, rule: rule, reason: reason, headroomMinutes: headroom, band: band)
        }

        // 1 — the phone has seen something in 30 to 90 days of history that today's
        // numbers alone do not show.
        if !i.isColdStart, i.isPhoneAware, band == .poor || i.bodyStressElevated == true {
            return made(.rest, 1, restReason(i))
        }

        // 2 — activated while sitting still. Measured entirely on the wrist, and the one
        // thing here a person genuinely cannot feel.
        if let hr = i.heartRate, let resting = i.restingHeartRate,
           let age = i.heartRateAgeMinutes, age <= t.liveHeartRateMaxAgeMinutes,
           i.exerciseMinutesLastTenMinutes <= t.breatheExerciseCeiling,
           i.stepsLastTenMinutes < t.breatheStillStepCeiling,
           hr - resting >= t.breatheHeartRateOverResting {
            return made(.breathe, 2, WatchStrings.Verdict.breathe(over: Int((hr - resting).rounded())))
        }

        // 3 — bedtime derived from sleep need and accumulated debt, neither of which the
        // wearer is tracking in their head.
        if let toBed = i.minutesToBedtime,
           toBed <= t.sleepLeadMinutes, toBed > -t.sleepTrailMinutes {
            return made(.sleep, 3, WatchStrings.Verdict.sleep(minutes: Int(toBed.rounded())))
        }

        // 4 — the only expensive word. Needs a fresh payload as well as a good one:
        // training a body that needed rest costs real recovery, so this rung alone
        // refuses to run on stale data.
        if !i.isColdStart, i.isPhoneAware, band == .optimal,
           i.bodyStressElevated != true,
           let age = i.payloadAgeMinutes, age <= t.trainMaxPayloadAgeMinutes,
           let ceiling = i.exerciseCeilingMinutes,
           Double(i.exerciseMinutesToday) < t.trainUnspentFraction * Double(ceiling) {
            return made(.train, 4, WatchStrings.Verdict.train)
        }

        // 4.5 — the phone has a score but this wrist measured nothing, so every rung
        // below needs a value that does not exist. Answer from the band rather than
        // falling through to rung 7, whose "everything in your range" would be a claim
        // about measurements that were never taken.
        if i.hasNoMeasurements, let band, !i.isColdStart {
            return made(band == .optimal ? .steady : .recovering, 45, WatchStrings.Verdict.phoneOnly)
        }

        // 5 — a suppressed HRV with a known cause. Naming the cause is the whole point:
        // "recovering" explains the number, "warm" only reports it.
        if !i.isColdStart, i.isPhoneAware,
           let hours = i.hoursSinceHardDay, hours <= t.recoveringWindowHours,
           let hrv = i.heartRateVariability, let floor = i.hrvBaselineFloor, hrv < floor {
            return made(.recovering, 5, WatchStrings.Verdict.recovering(days: Int((hours / 24).rounded())))
        }

        // 6 — resting heart rate above this wearer's own baseline. Meaningless without
        // the baseline, which is exactly why the phone sends it.
        if !i.isColdStart, i.isPhoneAware,
           let resting = i.restingHeartRate, let baseline = i.restingHeartRateBaseline,
           resting - baseline >= t.warmRestingHeartRateDelta {
            return made(.warm, 6, WatchStrings.Verdict.warm(over: Int((resting - baseline).rounded())))
        }

        // 7 — the floor. The wrist is never left without a word, which is what makes
        // "open Laso on your iPhone" unreachable.
        //
        // Three different reasons, because "everything in your range" is a claim about a
        // range. Saying it without one would be the black-box failure this design exists
        // to avoid.
        let reason: String
        if i.isColdStart {
            reason = WatchStrings.Verdict.learning(nights: i.nightsOfHistory)
        } else if i.isPhoneAware {
            reason = WatchStrings.Verdict.steady
        } else {
            reason = WatchStrings.State.noPhoneYet
        }
        return made(.steady, 7, reason)
    }

    /// Movement left before today's ceiling.
    ///
    /// The ceiling comes from the phone's strain coach, never from a formula invented on
    /// the wrist: how much movement is wise today depends on 60 days of load history the
    /// watch's roughly seven day HealthKit window cannot see. With no ceiling the wrist
    /// says nothing about room rather than substituting the plain Move goal, which would
    /// silently turn a recovery-aware number into an Activity ring copy.
    private static func headroom(_ i: WatchVerdictInput) -> Int? {
        guard let ceiling = i.exerciseCeilingMinutes else { return nil }
        return max(0, ceiling - i.exerciseMinutesToday)
    }

    private static func restReason(_ i: WatchVerdictInput) -> String {
        if let resting = i.restingHeartRate, let baseline = i.restingHeartRateBaseline,
           resting - baseline >= WatchVerdictThresholds.warmRestingHeartRateDelta {
            return WatchStrings.Verdict.warm(over: Int((resting - baseline).rounded()))
        }
        return WatchStrings.Verdict.rest
    }
}
