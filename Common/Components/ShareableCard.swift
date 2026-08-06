import SwiftUI
import PhotosUI

/// Card type for shareable content
enum ShareCardType {
    case score(score: Int, scoreChange: Int?, streakDays: Int)
    case template(ShareTemplate, photo: UIImage?)
}

// MARK: - Share Templates

/// One card the user can pick from the share tray.
///
/// The four win templates are gated: each is only built when its number reads
/// as a win, so the picker cannot hand someone a number they would not post.
/// `rings` is the exception and is deliberate: it shows the day as it is, so it
/// is offered last and never sits in front of a real win.
struct ShareTemplate: Identifiable, Equatable {
    enum Kind: String {
        case younger, streak, proof, bestSleep
        /// A cause, an effect and the days behind them, from the user's own
        /// correlations. Leads the tray because it is the only card whose claim
        /// months of tracking could produce and one good morning could not.
        case receipt
        /// An already-earned achievement, carrying the date it was earned.
        case badge
        /// Everyday cards. No win required, only the reading. They exist because
        /// gating every card on an achievement left an ordinary day with one
        /// option in the tray, which is not a choice.
        case recovery, sleep, bodyAge
        case rings
        /// Daily Mirror then-vs-now pair. The only card carrying the user's own
        /// face, so it appears in the tray only when picked deliberately.
        case mirror
    }

    /// What the card draws. The gated wins are a single headline; `rings` keeps
    /// the original three stat rings.
    enum Content: Equatable {
        case headline(accent: String, plain: String, sub: String)
        case rings(vitalityAge: Int?, realAge: Int?, recovery: Int?, sleepSeconds: Double?)
        /// The photos themselves are loaded from `MirrorPhotoStore` at render
        /// time; carrying only the days keeps this value type Equatable and
        /// keeps photo bytes out of the template tray.
        case mirrorPair(firstDay: Date, firstScore: Int?, latestDay: Date, latestScore: Int?)
        /// SF Symbol plus the achievement's own title and description. The date
        /// is carried, never re-derived, so the card cannot claim today for
        /// something earned last month.
        case badge(icon: String, title: String, detail: String, earnedOn: Date)
    }

    let kind: Kind
    /// Value shown on the tray chip.
    let chip: String
    let content: Content
    /// Years younger, set only on `.younger`. Drives the referral caption so a
    /// user who picks the streak card does not send an age claim with it.
    let captionYears: Int?

    var id: String { kind.rawValue }

    var chipLabel: String {
        switch kind {
        case .younger:   return Copy.Common.shareChipYounger
        case .streak:    return Copy.Common.shareChipStreak
        case .receipt:   return Copy.Common.shareChipReceipt
        case .badge:     return Copy.Common.shareChipBadge
        case .proof:     return Copy.Common.shareChipProof
        case .bestSleep: return Copy.Common.shareChipBestSleep
        case .recovery:  return Copy.Common.shareChipRecovery
        case .sleep:     return Copy.Common.shareChipSleep
        case .bodyAge:   return Copy.Common.shareChipAge
        case .rings:     return Copy.Common.shareChipToday
        case .mirror:    return Copy.Mirror.shareChip
        }
    }
}

/// Floors that decide whether a template is offered. Product thresholds, not
/// clinical ones.
enum ShareTemplateGates {
    /// A 3 day streak is not worth posting. Streaks travel at a threshold only.
    static let minMasterStreak = 7
    /// `VitalityScorer` holds vitality age at chronological age for the first
    /// week and ramps to full personalisation at 30 days, so a 1 year gap early
    /// on is model warm-up rather than a real win.
    static let minYearsYounger = 2
    /// The `.sleepDuration` series is stored in hours. A value outside this
    /// range means the upstream unit changed, so the card stays hidden rather
    /// than printing a nonsense number onto someone's photo.
    static let plausibleSleepHours: ClosedRange<Double> = 3...14
    /// HealthKit rounds sleep, so exact equality with the all-time high would
    /// almost never fire. Within a minute counts as tying the record.
    static let bestSleepToleranceHours: Double = 1.0 / 60.0
    /// Two mirror photos a few days apart show no visible change. Two weeks is
    /// the floor where a then-vs-now pair reads as progress.
    static let minMirrorDaysApart = 14
    /// `CorrelationAnalyzer` already calls 30+ aligned days "a reliable
    /// pattern" in the copy it writes for the detail view, so the share gate
    /// reuses that number rather than introducing a second, softer one. Below
    /// it the pattern is still building and does not belong on a card that
    /// leads with the sample size.
    static let minCorrelationDays = 30
    /// A badge earned months ago is a fact about the user, not a moment. Past
    /// this the achievement stays on the Achievements screen and off the tray.
    static let maxBadgeAgeDays = 30
}

/// Builds the tray, strongest win first, with the rings card last. Every win
/// gate is hard: a win that does not qualify is absent, never greyed out with a
/// bad number behind it.
enum ShareTemplateBuilder {
    static func build(
        vitalityAge: Int?,
        realAge: Int?,
        recovery: Int?,
        masterStreak: Int,
        actionResult: DailyActionResultStore.Result?,
        lastNightSleepSeconds: Double?,
        allTimeBestSleepHours: Double?,
        mirrorPair: (firstDay: Date, firstScore: Int?, latestDay: Date, latestScore: Int?)? = nil,
        correlation: HealthCorrelation? = nil,
        recentBadge: Achievement? = nil,
        today: Date = Date()
    ) -> [ShareTemplate] {
        var templates: [ShareTemplate] = []

        // Leads the tray. Every other card reports a result; this one reports
        // what produced it, over a stated number of days, which is the only
        // claim here that a single good morning could not have made.
        if let correlation, correlation.sampleCount >= ShareTemplateGates.minCorrelationDays {
            templates.append(ShareTemplate(
                kind: .receipt,
                chip: "\(correlation.sampleCount)",
                content: .headline(
                    accent: correlation.causeLabel,
                    plain: correlation.effectLabel,
                    sub: Copy.Common.shareReceiptSub(days: correlation.sampleCount)
                ),
                captionYears: nil
            ))
        }

        if let vitalityAge, let realAge {
            let years = realAge - vitalityAge
            if years >= ShareTemplateGates.minYearsYounger {
                templates.append(ShareTemplate(
                    kind: .younger,
                    chip: "\(years)",
                    content: .headline(
                        accent: Copy.Common.shareYoungerAccent(years: years),
                        plain: Copy.Common.shareYoungerPlain,
                        sub: Copy.Common.shareYoungerSub(realAge: realAge, vitalityAge: vitalityAge)
                    ),
                    captionYears: years
                ))
            }
        }

        if masterStreak >= ShareTemplateGates.minMasterStreak {
            templates.append(ShareTemplate(
                kind: .streak,
                chip: "\(masterStreak)",
                content: .headline(
                    accent: Copy.Common.shareStreakAccent(days: masterStreak),
                    plain: Copy.Common.shareStreakPlain,
                    sub: Copy.Common.shareStreakSub
                ),
                captionYears: nil
            ))
        }

        // Sits with the streak card because both are discipline proof rather
        // than a reading. Gated on recency, not just on being unlocked, so the
        // tray never offers a badge the user earned two months ago.
        if let recentBadge,
           let earnedOn = recentBadge.unlockedDate,
           recentBadge.isUnlocked,
           earnedOn.daysBetween(today) <= ShareTemplateGates.maxBadgeAgeDays {
            templates.append(ShareTemplate(
                kind: .badge,
                chip: earnedOn.formatted(.dateTime.day().month(.abbreviated)),
                content: .badge(
                    icon: recentBadge.icon,
                    title: recentBadge.title,
                    detail: recentBadge.description,
                    earnedOn: earnedOn
                ),
                captionYears: nil
            ))
        }

        if let actionResult, actionResult.direction == .up {
            templates.append(ShareTemplate(
                kind: .proof,
                chip: "+\(actionResult.delta)",
                content: .headline(
                    accent: Copy.Common.shareProofAccent(delta: actionResult.delta),
                    plain: Copy.Common.shareProofPlain,
                    sub: Copy.Common.shareProofSub(action: actionResult.record.actionTitle)
                ),
                captionYears: nil
            ))
        }

        if let lastNightSleepSeconds, let best = allTimeBestSleepHours {
            let hours = lastNightSleepSeconds / 3600
            if hours >= best - ShareTemplateGates.bestSleepToleranceHours,
               ShareTemplateGates.plausibleSleepHours.contains(hours),
               ShareTemplateGates.plausibleSleepHours.contains(best) {
                let text = clockText(hours: hours)
                templates.append(ShareTemplate(
                    kind: .bestSleep,
                    chip: text,
                    content: .headline(
                        accent: text,
                        plain: Copy.Common.shareBestSleepPlain,
                        sub: Copy.Common.shareBestSleepSub
                    ),
                    captionYears: nil
                ))
            }
        }

        if let pair = mirrorPair,
           pair.firstDay.daysBetween(pair.latestDay) >= ShareTemplateGates.minMirrorDaysApart {
            templates.append(ShareTemplate(
                kind: .mirror,
                chip: "\(pair.firstDay.daysBetween(pair.latestDay))",
                content: .mirrorPair(firstDay: pair.firstDay, firstScore: pair.firstScore,
                                     latestDay: pair.latestDay, latestScore: pair.latestScore),
                captionYears: nil
            ))
        }

        // Everyday cards, after the earned wins and before the rings card. They
        // are gated on the reading existing and on nothing else, so an ordinary
        // day still offers a real choice instead of a single option.
        if let recovery {
            templates.append(ShareTemplate(
                kind: .recovery,
                chip: "\(recovery)",
                content: .headline(
                    accent: Copy.Common.shareRecoveryAccent(score: recovery),
                    plain: Copy.Common.shareRecoveryPlain,
                    // No band word here on purpose: the recovery thresholds live
                    // in the dashboard layer, and copying them into Common would
                    // give the app two tables that can drift apart.
                    sub: Copy.Common.shareRecoverySubPlain
                ),
                captionYears: nil
            ))
        }

        if let lastNightSleepSeconds {
            let hours = lastNightSleepSeconds / 3600
            // Same plausibility guard as the best-sleep card: an out of range
            // value means the stored unit changed, and that must never be
            // printed onto someone's photo.
            if ShareTemplateGates.plausibleSleepHours.contains(hours) {
                let text = clockText(hours: hours)
                templates.append(ShareTemplate(
                    kind: .sleep,
                    chip: text,
                    content: .headline(
                        accent: text,
                        plain: Copy.Common.shareSleepPlain,
                        sub: Copy.Common.shareSleepSub
                    ),
                    captionYears: nil
                ))
            }
        }

        // Body age is an everyday card only while it is not older than the real
        // age. Recovery and sleep are neutral facts, but "my body is 6 years
        // older" is not something anyone posts, so that case stays out.
        if let vitalityAge, let realAge, vitalityAge <= realAge {
            templates.append(ShareTemplate(
                kind: .bodyAge,
                chip: "\(vitalityAge)",
                content: .headline(
                    accent: Copy.Common.shareAgeAccent(age: vitalityAge),
                    plain: Copy.Common.shareAgePlain,
                    sub: Copy.Common.shareAgeSub(realAge: realAge)
                ),
                captionYears: nil
            ))
        }

        // The original three-ring card, kept as a choice the user makes rather
        // than the default. It shows the day as it is, good or bad, so it goes
        // last and never sits in front of an earned win.
        let hasSleep = (lastNightSleepSeconds ?? 0) > 0
        if vitalityAge != nil || recovery != nil || hasSleep {
            let chip = recovery.map(String.init)
                ?? vitalityAge.map(String.init)
                ?? lastNightSleepSeconds.map { clockText(hours: $0 / 3600) }
                ?? ""
            templates.append(ShareTemplate(
                kind: .rings,
                chip: chip,
                content: .rings(vitalityAge: vitalityAge, realAge: realAge,
                                recovery: recovery, sleepSeconds: lastNightSleepSeconds),
                captionYears: nil
            ))
        }

        return templates
    }

    /// Moves the first of `kinds` that exists to the front of the tray, so a
    /// share started from a detail screen opens on the card that screen is
    /// about instead of on whatever Home would have led with.
    ///
    /// A kind that did not qualify today is simply absent, and the tray keeps
    /// its earned-wins-first order. Nothing is invented to fill the slot.
    static func leading(_ kinds: [ShareTemplate.Kind], in templates: [ShareTemplate]) -> [ShareTemplate] {
        guard let index = kinds.lazy.compactMap({ kind in
            templates.firstIndex { $0.kind == kind }
        }).first else { return templates }

        var ordered = templates
        ordered.insert(ordered.remove(at: index), at: 0)
        return ordered
    }

    /// "8:12" from 8.2 hours. Rounds once on the total minute count so 7.999
    /// does not render as 7:60.
    private static func clockText(hours: Double) -> String {
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }
}

// MARK: - Shared Canvas

/// The frame every 9:16 share card is drawn in: fixed canvas, brand wordmark
/// top-left, footer bottom, clipped and pinned to dark.
///
/// Cards pass their ground and their middle and nothing else. Four hand-copied
/// versions of this block is how the canvas size ended up written five times
/// and the photo scrim ended up with two sets of stops that disagreed.
struct ShareCardCanvas<Ground: View, Content: View>: View {
    @ViewBuilder var ground: () -> Ground
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            ground()

            VStack(spacing: 0) {
                HStack {
                    Text(Copy.Common.laso.uppercased())
                        .font(DS.Share.Typography.wordmark)
                        .tracking(DS.Share.Typography.wordmarkTracking)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
                .padding(.horizontal, DS.Share.marginH)
                .padding(.top, DS.Share.marginTop)

                content()

                Text(Copy.Common.shareCardFooter)
                    .font(DS.Share.Typography.footer)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, DS.Share.marginBottom)
            }
        }
        .frame(width: DS.Share.width, height: DS.Share.height)
        .clipShape(RoundedRectangle(cornerRadius: DS.Share.radius))
        // The ground is always dark artwork, so every theme-dynamic token inside
        // must resolve its dark variant even when the app is in light mode.
        .environment(\.colorScheme, .dark)
    }
}

/// Ground for a share card: the user's photo under the readability scrim, or
/// the score-graded gradient when there is no photo.
struct ShareCardGround: View {
    var photo: UIImage? = nil
    /// Grades the fallback gradient. Nil means the card carries no score, which
    /// is the earned-win case, and a win draws the optimal ground.
    var score: Int? = nil

    var body: some View {
        if let photo {
            ZStack {
                // The fill image must be framed and clipped HERE: unframed it
                // inflates the ZStack's layout bounds, which spreads the card's
                // own content past the visible canvas and cuts it off.
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: DS.Share.width, height: DS.Share.height)
                    .clipped()
                DS.Share.photoScrim
            }
        } else {
            DS.Share.gradient(for: score)
        }
    }
}

// MARK: - Rings Card (Whoop-style photo share)

/// A story-sized (9:16) card: the user's own photo (or a brand gradient when
/// they skip), with up to three stat rings across the lower third — Vitality
/// Age, Recovery, and last night's sleep. Rings with no data are hidden;
/// nothing is invented.
struct ShareableRingsCard: View {
    let vitalityAge: Int?
    let realAge: Int?
    let recovery: Int?
    let sleepSeconds: Double?
    let photo: UIImage?

    /// Mirrors the fixed goal in `RecoverySignalsSnapshot.sleepHoursGoal`.
    private static let sleepGoalHours: Double = 7.5

    /// Full ring at 10+ years younger, half at on-age, empty at 10+ years older.
    private var vitalityProgress: Double {
        guard let vitalityAge, let realAge else { return 0 }
        let clamped = max(-10, min(10, realAge - vitalityAge))
        return Double(clamped + 10) / 20.0
    }

    private var sleepText: String {
        guard let sleepSeconds, sleepSeconds > 0 else { return "" }
        // Round on the total minute count rather than truncating each part:
        // 8.2 hours is 29519.999… seconds in binary, which truncated to whole
        // minutes reads 8:11 here while the best-sleep card reads 8:12.
        let minutes = Int((sleepSeconds / 60).rounded())
        return "\(minutes / 60):\(String(format: "%02d", minutes % 60))"
    }

    var body: some View {
        ShareCardCanvas {
            ShareCardGround(photo: photo, score: recovery)
        } content: {
            Spacer()

            HStack(spacing: 0) {
                if let vitalityAge {
                    statRing(value: "\(vitalityAge)",
                             label: Copy.Common.shareRingVitalityAge,
                             progress: vitalityProgress,
                             tint: AppColour.scoreOptimal)
                }
                if let recovery {
                    statRing(value: "\(recovery)",
                             label: Copy.Common.shareRingRecovery,
                             progress: Double(recovery) / 100.0,
                             tint: DS.scoreColor(recovery))
                }
                if let sleepSeconds, sleepSeconds > 0 {
                    statRing(value: sleepText,
                             label: Copy.Common.shareRingSleep,
                             progress: min((sleepSeconds / 3600) / Self.sleepGoalHours, 1),
                             tint: .white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.space4)

            Spacer().frame(height: DS.Share.marginBottom)
        }
    }

    private func statRing(value: String, label: String, progress: Double, tint: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(DS.Share.Ring.trackOpacity), lineWidth: DS.Share.Ring.lineWidth)
                    .frame(width: DS.Share.Ring.diameter, height: DS.Share.Ring.diameter)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: DS.Share.Ring.lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: DS.Share.Ring.diameter, height: DS.Share.Ring.diameter)
                Text(value)
                    // "8:12" overruns the ring at full size, so anything wider
                    // than two characters steps down.
                    .font(value.count > 2 ? DS.Share.Typography.ringValueCompact : DS.Share.Typography.ringValue)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
            Text(label)
                .font(DS.Share.Typography.ringLabel)
                .tracking(DS.Share.Typography.labelTracking)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Template Card

/// Draws whichever template the user picked. `.headline` is the story-sized
/// (9:16) card carrying one earned number, legible to someone who has never
/// seen the app; `.rings` hands off to the original three-ring card.
struct ShareableTemplateCard: View {
    let template: ShareTemplate
    let photo: UIImage?

    var body: some View {
        switch template.content {
        case .rings(let vitalityAge, let realAge, let recovery, let sleepSeconds):
            ShareableRingsCard(vitalityAge: vitalityAge, realAge: realAge,
                               recovery: recovery, sleepSeconds: sleepSeconds, photo: photo)
        case .headline(let accent, let plain, let sub):
            headlineCard(accent: accent, plain: plain, sub: sub)
        case .mirrorPair(let firstDay, let firstScore, let latestDay, let latestScore):
            ShareableMirrorPairCard(firstDay: firstDay, firstScore: firstScore,
                                    latestDay: latestDay, latestScore: latestScore)
        case .badge(let icon, let title, let detail, let earnedOn):
            ShareableBadgeCard(icon: icon, title: title, detail: detail, earnedOn: earnedOn)
        }
    }

    private func headlineCard(accent: String, plain: String, sub: String) -> some View {
        ShareCardCanvas {
            ShareCardGround(photo: photo)
        } content: {
            Spacer()

            VStack(alignment: .leading, spacing: DS.space3) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(accent)
                        .foregroundStyle(AppColour.scoreOptimal)
                    Text(plain)
                        .foregroundStyle(.white)
                }
                .font(DS.Share.Typography.hero)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .shadow(color: .black.opacity(0.55), radius: 12, y: 2)

                Text(sub)
                    .font(DS.Share.Typography.sub)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.6), radius: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Share.marginH)

            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Badge Card (an earned achievement)

/// Story card for one already-earned achievement: the medal, the achievement's
/// own title and description, and the date it was earned.
///
/// The date is not decoration. An undated badge says what someone is, a dated
/// one says when they did it, and only the second reads as a moment worth
/// posting.
struct ShareableBadgeCard: View {
    let icon: String
    let title: String
    let detail: String
    let earnedOn: Date

    /// The medal rim. Runs through the same tokens the Achievements screen uses
    /// for its level ramp, so a badge is the same object in the app and on the
    /// card. Bronze sits at the sweep ends so the seam lands in shadow.
    private var rim: AngularGradient {
        AngularGradient(
            colors: [
                AppColour.achievementBronze,
                AppColour.achievementGold,
                AppColour.achievementPlatinum,
                AppColour.achievementGold,
                AppColour.achievementBronze
            ],
            center: .center
        )
    }

    var body: some View {
        ShareCardCanvas {
            ShareCardGround()
        } content: {
            Spacer()

            VStack(spacing: DS.space5) {
                ZStack {
                    Circle()
                        .fill(rim)
                        .frame(width: 156, height: 156)
                    Circle()
                        .fill(AppColour.shareScoreHighEnd)
                        .frame(width: 132, height: 132)
                    Image(systemName: icon)
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(AppColour.achievementGold)
                }
                .shadow(color: AppColour.achievementGold.opacity(0.35), radius: 26, y: 8)

                VStack(spacing: DS.space2) {
                    Text(title)
                        .font(DS.Share.Typography.heroCompact)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)

                    Text(detail)
                        .font(DS.Share.Typography.sub)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .multilineTextAlignment(.center)

                Text(Copy.Common.shareBadgeEarned(
                    date: earnedOn.formatted(.dateTime.day().month(.abbreviated).year())
                ))
                .font(DS.Share.Typography.label)
                .tracking(DS.Share.Typography.labelTracking)
                .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, DS.Share.marginH)

            Spacer()
        }
    }
}

// MARK: - Mirror Pair Card (then vs now)

/// Story-sized card with the user's first and latest Daily Mirror photos side
/// by side. Only offered from the template tray, so the photos appear in a
/// share only when the user deliberately picked this card and saw them.
struct ShareableMirrorPairCard: View {
    let firstDay: Date
    let firstScore: Int?
    let latestDay: Date
    let latestScore: Int?

    private var headline: String {
        if let firstScore, let latestScore, latestScore > firstScore {
            return Copy.Mirror.sharePointsUp(latestScore - firstScore)
        }
        return Copy.Mirror.shareDaysApart(firstDay.daysBetween(latestDay))
    }

    var body: some View {
        ShareCardCanvas {
            ShareCardGround()
        } content: {
            Spacer()

            HStack(spacing: DS.space3) {
                pairPhoto(day: firstDay, score: firstScore)
                pairPhoto(day: latestDay, score: latestScore)
            }
            .padding(.horizontal, DS.space5)

            Spacer().frame(height: 30)

            Text(headline)
                .font(DS.Share.Typography.heroCompact)
                .foregroundStyle(AppColour.scoreOptimal)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Spacer()
        }
    }

    @ViewBuilder
    private func pairPhoto(day: Date, score: Int?) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Deliberately the plain photo, not the day's template: this card
            // already prints its own date and score under each face, and a
            // second overlay on top would say everything twice.
            if let image = MirrorPhotoStore.shared.image(on: day) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 165, height: 260)
                    .clipped()
            } else {
                // A pair template whose photo was deleted between tray build
                // and render draws its slot empty rather than inventing one.
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 165, height: 260)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(day.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                if let score {
                    Text("\(score)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: .black.opacity(0.7), radius: 4)
            .padding(DS.space3)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
}

// MARK: - Camera capture

/// Minimal camera wrapper for the share card's "take a photo" option and the
/// Daily Mirror capture. iOS shows the camera permission prompt on first use;
/// a denial simply returns the user to the sheet with no photo.
///
/// `dismissesOnCapture` stays true for the share flow, where this view is its
/// own presentation. Daily Mirror embeds it inside a staged flow and passes
/// false, because `dismiss` there would tear down the whole flow instead of
/// moving to the confirm step.
struct CameraCaptureView: UIViewControllerRepresentable {
    var cameraDevice: UIImagePickerController.CameraDevice = .rear
    var dismissesOnCapture = true
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        if UIImagePickerController.isCameraDeviceAvailable(cameraDevice) {
            picker.cameraDevice = cameraDevice
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            if parent.dismissesOnCapture {
                parent.dismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Share flow (pick a win -> add photo -> share)

/// Sheet presented from the home Recovery card's share icon. Shows the wins the
/// user has actually earned, a live preview of the picked one, and the photo
/// attach step, then hands the rendered image to the share sheet through
/// `ShareButton`.
///
/// `templates` is built by `ShareTemplateBuilder` and can legitimately be empty.
/// Home hides the share affordance in that case, so the empty state here is the
/// backstop for a card that was earned when the screen loaded and expired
/// before the sheet opened.
struct ShareWinSheet: View {
    let templates: [ShareTemplate]

    @State private var selectedID: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var showCamera = false

    private var selected: ShareTemplate? {
        templates.first { $0.id == selectedID } ?? templates.first
    }

    /// Referral invite line attached as text next to the image. The card image
    /// itself stays clean; message apps show this under the photo.
    private var inviteCaption: String? {
        let referral = ReferralManager.shared
        guard referral.isEnabled, let code = referral.referralCode else { return nil }
        if let years = selected?.captionYears {
            return Copy.Referral.shareCaptionYounger(years: years, code: code)
        }
        return Copy.Referral.shareCaptionGeneric(code: code)
    }

    /// Title, tray, hint, photo row, Share button and their spacing need about
    /// this much room under the preview. The preview shrinks to fit rather than
    /// pushing the Share button below the fold on a small phone.
    private static let sheetChromeHeight: CGFloat = 300

    private func previewScale(forHeight height: CGFloat) -> CGFloat {
        min(0.55, max(height - Self.sheetChromeHeight, 200) / 693)
    }

    var body: some View {
        // Outside the ScrollView on purpose: inside, the proxy would report the
        // scroll content height rather than the sheet's.
        GeometryReader { proxy in
            let scale = previewScale(forHeight: proxy.size.height)

            ScrollView(.vertical) {
                VStack(spacing: DS.space4) {
                    Text(Copy.Common.shareSheetTitle)
                        .font(DS.Typography.title3)
                        .foregroundStyle(AppColour.textPrimary)
                        .padding(.top, DS.space5)

                    if let selected {
                        ShareableTemplateCard(template: selected, photo: photo)
                            .scaleEffect(scale)
                            .frame(width: 390 * scale, height: 693 * scale)

                        // A single earned win is not a choice, so the tray is
                        // only worth its vertical space when there are two.
                        if templates.count > 1 {
                            templateTray(selectedID: selected.id)
                            Text(Copy.Common.shareTrayHint)
                                .font(DS.Typography.footnote)
                                .foregroundStyle(AppColour.textSecondary)
                        }

                        photoControls

                        // Direct send first, activity sheet second. Private
                        // messaging carries the large majority of real sharing
                        // and converts several times better than a feed post,
                        // and health is the category where public posting drops
                        // off hardest, so the recipient path leads.
                        if SendToPersonButton.isAvailable {
                            SendToPersonButton(
                                cardType: .template(selected, photo: photo),
                                screen: .home,
                                captionText: inviteCaption
                            )
                        }

                        ShareButton(
                            cardType: .template(selected, photo: photo),
                            screen: .home,
                            title: SendToPersonButton.isAvailable
                                ? Copy.Common.shareMoreWays
                                : Copy.Common.shareCTA,
                            isPrimary: !SendToPersonButton.isAvailable,
                            captionText: inviteCaption
                        )
                    } else {
                        emptyState
                    }

                    Spacer(minLength: DS.space4)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            // Mint/load the invite code before the user hits Share so the
            // caption can carry it. No-op when cached or program disabled.
            await ReferralManager.shared.ensureReferralCode()
        }
    }

    private func templateTray(selectedID currentID: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.space3) {
                ForEach(templates) { template in
                    Button {
                        self.selectedID = template.id
                        AppAnalytics.shared.trackBlockTap(
                            title: "Share template",
                            type: .shareCard,
                            screen: .home,
                            metadata: ["template": template.kind.rawValue]
                        )
                    } label: {
                        VStack(spacing: DS.space1) {
                            Text(template.chip)
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Text(template.chipLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(AppColour.textPrimary)
                        .padding(.horizontal, DS.space1)
                        .frame(width: 68, height: 82)
                        .background(
                            AppColour.surfaceSubtle,
                            in: RoundedRectangle(cornerRadius: DS.Radius.md)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .strokeBorder(template.id == currentID ? AppColour.scoreOptimal : .clear,
                                              lineWidth: 2)
                        )
                    }
                    .accessibilityLabel(template.chipLabel)
                    .accessibilityValue(template.chip)
                    .accessibilityAddTraits(template.id == currentID ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, DS.screenPadding)
        }
    }

    private var photoControls: some View {
        HStack(spacing: DS.space5) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(photo == nil ? Copy.Common.shareAddPhoto : Copy.Common.shareChangePhoto,
                      systemImage: "photo")
                    .font(DS.Typography.bodySemibold)
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                let wasChange = photo != nil
                Task { @MainActor in
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photo = image
                        AppAnalytics.shared.trackSharePhotoAdded(source: "library", isChange: wasChange)
                    }
                }
            }

            // Camera capture, hidden where no camera exists (simulator).
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Take Photo",
                        type: .shareCard,
                        screen: .home,
                        metadata: ["source": "camera", "is_change": photo != nil]
                    )
                    showCamera = true
                } label: {
                    Label(Copy.Common.shareTakePhoto, systemImage: "camera")
                        .font(DS.Typography.bodySemibold)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                let wasChange = photo != nil
                photo = image
                AppAnalytics.shared.trackSharePhotoAdded(source: "camera", isChange: wasChange)
            }
            .ignoresSafeArea()
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.space3) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundStyle(AppColour.textTertiary)
            Text(Copy.Common.shareEmptyTitle)
                .font(DS.Typography.title3)
                .foregroundStyle(AppColour.textPrimary)
            Text(Copy.Common.shareEmptyBody)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space6)
        }
        .padding(.vertical, DS.space7)
    }
}

// MARK: - Score Card

/// A shareable card displaying the user's health score, weekly change, and streak
struct ShareableScoreCard: View {
    let score: Int
    let scoreChange: Int?
    let streakDays: Int

    private var scoreColor: Color {
        DS.scoreColor(score)
    }

    var body: some View {
        ZStack {
            DS.Share.gradient(for: score)

            VStack(spacing: 0) {
                // Top bar: App name
                HStack {
                    Text(Copy.Common.laso)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, DS.space6)
                .padding(.top, 28)

                Spacer()

                // Center: Score ring
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(scoreColor.opacity(0.08))
                        .frame(width: 200, height: 200)

                    // Background ring
                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 14)
                        .frame(width: 160, height: 160)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: Double(score) / 100.0)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 160, height: 160)

                    // Score number
                    VStack(spacing: 2) {
                        Text(Copy.Common.xText(score))
                            .font(DS.Typography.displayXL)
                            .foregroundStyle(.white)
                        Text(Copy.Common.healthScore)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer().frame(height: 24)

                // Badges row
                HStack(spacing: 12) {
                    if let change = scoreChange, change != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                            Text(Copy.Common.shareScoreChangeThisWeek(delta: change))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(change > 0 ? .green : .red)
                        .padding(.horizontal, DS.space3)
                        .padding(.vertical, 6)
                        .background((change > 0 ? Color.green : Color.red).opacity(0.15), in: Capsule())
                    }

                    if streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(Copy.Common.dayStreakText(streakDays))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, DS.space3)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                    }
                }

                Spacer()

                // Bottom tagline
                Text(Copy.Common.trackYourHealthWithLaso)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 390, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        // Statically dark artwork: pin the scheme so the score ring keeps its
        // dark variant for a light-mode user.
        .environment(\.colorScheme, .dark)
    }

    // Locale-aware. `.dateTime.day().month().year()` resolves the
    // ordering / separators / month-name length per `Locale.current` (e.g.
    // "Apr 25, 2026" en-US, "25 Apr 2026" en-GB, "25 avr. 2026" fr-FR).
    private var formattedDate: String {
        Date().formatted(.dateTime.day().month().year())
    }
}

// MARK: - Previews

#Preview("Template - Younger") {
    ShareableTemplateCard(
        template: ShareTemplateBuilder.build(
            vitalityAge: 31, realAge: 38, recovery: nil, masterStreak: 0,
            actionResult: nil, lastNightSleepSeconds: nil, allTimeBestSleepHours: nil
        )[0],
        photo: nil
    )
    .scaleEffect(0.55)
    .frame(width: 390 * 0.55, height: 693 * 0.55)
}

#Preview("Template - Streak") {
    ShareableTemplateCard(
        template: ShareTemplateBuilder.build(
            vitalityAge: nil, realAge: nil, recovery: nil, masterStreak: 23,
            actionResult: nil, lastNightSleepSeconds: nil, allTimeBestSleepHours: nil
        )[0],
        photo: nil
    )
    .scaleEffect(0.55)
    .frame(width: 390 * 0.55, height: 693 * 0.55)
}

#Preview("Score Card - High") {
    ShareableScoreCard(score: 85, scoreChange: 5, streakDays: 14)
        .padding()
        .background(.black)
}

#Preview("Score Card - Medium") {
    ShareableScoreCard(score: 62, scoreChange: -3, streakDays: 0)
        .padding()
        .background(.black)
}
