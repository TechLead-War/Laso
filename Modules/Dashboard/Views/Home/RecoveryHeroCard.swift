import SwiftUI

/// Score card: one readiness ring with a plain-word state, a one-line summary,
/// and the "Why" list of the real signals behind it. Deliberately simple — the
/// number never appears without a plain reason.
struct RecoveryHeroCard: View {
    let score: Int
    /// Bold heading under the orb, e.g. "Higher than usual today."
    var summaryHead: String = ""
    /// Lighter sub line under the heading, e.g. "Good to push a little."
    var summarySub: String = ""
    /// The real reasons behind the score (sleep, heart, energy).
    var whyReasons: [DashboardViewModel.RecoveryWhyReason] = []
    var hasLiveReadiness: Bool = true
    /// Points gained or lost since yesterday. Nil when yesterday has no score,
    /// which renders nothing rather than a misleading zero.
    var scoreChange: Int? = nil
    var isWearingWatch: Bool = true
    /// Score points the model held back because signals were missing. When it is
    /// meaningful the card shows a range rather than a single number, so a thin
    /// day cannot read as confidently as a complete one. Nil or zero shows the
    /// plain score.
    var scoreUncertainty: Int? = nil
    var onTap: (() -> Void)? = nil
    /// Opens the detail screen for one signal in the Why list.
    var onTapWhy: ((DashboardViewModel.RecoveryWhyReason.Kind) -> Void)? = nil
    var onShare: (() -> Void)? = nil

    private var recoveryState: DashboardViewModel.RecoveryState {
        DashboardViewModel.RecoveryState(score: score)
    }

    /// No morning lock today and the watch is off — nothing legitimate to show.
    private var shouldShowWearWatch: Bool {
        !isWearingWatch && score == 0
    }

    var body: some View {
        Group {
            if shouldShowWearWatch {
                Button { onTap?() } label: { wearWatchEmptyState }
                    .buttonStyle(.dsPress)
            } else {
                cardContent
            }
        }
        .overlay(alignment: .topTrailing) {
            if let onShare, !shouldShowWearWatch, score > 0 {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(DS.Typography.footnoteMedium)
                        .foregroundStyle(AppColour.textSecondary)
                        .padding(10)
                }
                .accessibilityLabel(Copy.Common.shareHealthCard)
                .accessibilityIdentifier("home.recoveryCard.share")
                .padding(.top, 6)
                .padding(.trailing, 6)
            }
        }
        .padding(.horizontal, DS.screenPadding)
        .onAppear {
            guard isWearingWatch, hasLiveReadiness, score > 0 else { return }
            if UserDefaults.standard.bool(forKey: AppKeys.Engagement.firstRecoveryScoreSeen) {
                EngagementSequenceScheduler.markActivation(.secondRecoveryScore)
            } else {
                EngagementSequenceScheduler.markActivation(.firstRecoveryScore)
            }
        }
    }

    // MARK: - Wear Watch Empty State

    private var wearWatchEmptyState: some View {
        HStack(spacing: 16) {
            Image(systemName: "applewatch")
                .font(DS.Typography.title2)
                .foregroundStyle(AppColour.textTertiary)
                .frame(width: 56, height: 56)
                .background(AppColour.surfaceRaised, in: Circle())

            Text(Copy.Home.wearAppleWatchForRecovery)
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(DS.cardPadding + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.borderLow, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Home.wearAppleWatchForRecovery)
        .accessibilityIdentifier("home.recoveryCard.wearWatch")
    }

    // MARK: - Card Content

    private var ringTint: Color {
        hasLiveReadiness ? recoveryState.color : AppColour.scoreGood
    }

    /// The card is a stack of separate buttons, not one big button, because a
    /// Button nested inside another Button's label never receives the tap.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ring on the left, the "Why" list on the right — compact side by
            // side. Ring is vertically centered against the taller Why column.
            HStack(alignment: .center, spacing: 16) {
                Button { onTap?() } label: { ringColumn }
                    .buttonStyle(.dsPress)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(Copy.Home.scoreReadyLabel) \(score)" + (scoreChange.map { ". \(changeChipText($0))" } ?? ""))
                    .accessibilityHint(Copy.Home.opensScoreBreakdownHint)

                if !whyReasons.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.Home.scoreWhyLabel)
                            .font(DS.Typography.captionSemibold)
                            .tracking(1.4)
                            .foregroundStyle(AppColour.textTertiary)
                            .padding(.bottom, 2)

                        ForEach(Array(whyReasons.enumerated()), id: \.element.id) { index, reason in
                            Button { onTapWhy?(reason.kind) } label: { whyRow(reason) }
                                .buttonStyle(.dsPress)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(reason.label), \(reason.value)")
                                .accessibilityHint(Copy.Home.viewDetailsHint(reason.kind.displayName))

                            if index < whyReasons.count - 1 {
                                Divider().overlay(AppColour.borderLow)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            missingSignalsRow

            // Plain-word takeaway kept as a footer so it is never dropped.
            if !summaryHead.isEmpty || !summarySub.isEmpty {
                Divider()
                    .overlay(AppColour.borderLow)
                    .padding(.vertical, 14)

                Button { onTap?() } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summaryHead)
                            .font(DS.Typography.headline)
                            .foregroundStyle(AppColour.textPrimary)
                        Text(summarySub)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(AppColour.textSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(summaryHead) \(summarySub)")
                .accessibilityHint(Copy.Home.opensScoreBreakdownHint)
            }
        }
        .padding(DS.cardPadding + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.borderLow, lineWidth: 1))
        .accessibilityIdentifier("home.recoveryCard")
    }

    private var ringColumn: some View {
        VStack(spacing: 8) {
            ZStack {
                // Soft glow via a radial gradient (cheap) rather than a
                // Gaussian blur, which re-renders offscreen every frame and
                // makes scrolling lag.
                Circle()
                    .fill(RadialGradient(
                        colors: [ringTint.opacity(0.28), .clear],
                        center: .center, startRadius: 6, endRadius: 66))
                    .frame(width: 132, height: 132)
                    .allowsHitTesting(false)
                HealthScoreRing(
                    score: score,
                    label: Copy.Home.scoreReadyLabel,
                    size: 104,
                    lineWidth: 9,
                    tint: hasLiveReadiness ? recoveryState.color : nil
                )
            }

            scoreRangeRow
            changeChip
            confidenceRow
        }
        .frame(width: 132)
        .contentShape(Rectangle())
    }

    /// The band the reading actually sits in on a thin day. Hidden once the
    /// model had enough signals to hold the number still, so a complete day
    /// stays clean.
    @ViewBuilder
    private var scoreRangeRow: some View {
        if let scoreUncertainty, scoreUncertainty >= Self.minimumUncertaintyToShowRange {
            Text(Copy.Home.scoreRange(max(0, score - scoreUncertainty),
                                      min(100, score + scoreUncertainty)))
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("home.recoveryCard.scoreRange")
        }
    }

    /// Below this the band is narrower than the rounding on the score itself, so
    /// printing it would suggest more precision than it removes.
    private static let minimumUncertaintyToShowRange = 3

    private var signalsWithData: Int {
        whyReasons.filter { $0.tone != .noData }.count
    }

    /// How much of the score is real readings today. Counted off the rows the
    /// card is already showing, so the number can never drift from the list.
    ///
    /// The bar carries the weight the sentence alone could not: a score built on
    /// one signal used to render exactly as confidently as one built on five.
    @ViewBuilder
    private var confidenceRow: some View {
        if !whyReasons.isEmpty {
            let fraction = Double(signalsWithData) / Double(whyReasons.count)
            VStack(spacing: 5) {
                Text(Copy.Home.scoreConfidence(signalsWithData, whyReasons.count))
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColour.trackNeutral)
                        Capsule()
                            .fill(certaintyTint(fraction))
                            .frame(width: max(4, geo.size.width * fraction))
                    }
                }
                .frame(height: 4)
                .accessibilityHidden(true)   // the sentence above already says it
            }
        }
    }

    private func certaintyTint(_ fraction: Double) -> Color {
        if fraction >= 0.8 { return AppColour.success }
        if fraction >= 0.4 { return AppColour.warning }
        return AppColour.danger
    }

    /// Names the signals with no reading and the one thing that fixes them.
    /// Silent when every signal reported, so a full read carries no clutter.
    @ViewBuilder
    private var missingSignalsRow: some View {
        let missing = whyReasons.filter { $0.tone == .noData }.map(\.kind.displayName)
        if !missing.isEmpty {
            Text(Copy.Home.scoreMissingSignals(missing.sentenceList))
                .font(DS.Typography.caption)
                .foregroundStyle(AppColour.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .accessibilityIdentifier("home.recoveryCard.missingSignals")
        }
    }

    /// Yesterday comparison. Up, down and flat each read differently; a missing
    /// yesterday shows nothing at all.
    @ViewBuilder
    private var changeChip: some View {
        if let scoreChange {
            let tint: Color = scoreChange == 0
                ? AppColour.textSecondary
                : (scoreChange > 0 ? AppColour.success : AppColour.danger)

            HStack(spacing: 3) {
                if scoreChange != 0 {
                    Image(systemName: scoreChange > 0 ? "arrow.up" : "arrow.down")
                        .font(DS.Typography.caption2)
                }
                Text(changeChipText(scoreChange))
                    .font(DS.Typography.captionSemibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(tint.opacity(DS.badgeBg), in: Capsule())
        }
    }

    private func changeChipText(_ change: Int) -> String {
        if change > 0 { return Copy.Home.scoreChangeUp(change) }
        if change < 0 { return Copy.Home.scoreChangeDown(abs(change)) }
        return Copy.Home.scoreChangeSame
    }

    // MARK: - Why Row

    /// One plain line: a colored dot, the interpretation, and the value. The
    /// label auto-shrinks a touch rather than wrapping, so long reasons like
    /// "Resting heart rate is up" stay on one line in the narrow right column.
    /// A signal with no reading stays in place, greyed, so the list never looks
    /// like it is holding something back.
    private func whyRow(_ reason: DashboardViewModel.RecoveryWhyReason) -> some View {
        let missing = reason.tone == .noData
        return HStack(spacing: 9) {
            Circle()
                .fill(dotColor(reason.tone))
                .frame(width: 7, height: 7)
            // The signal name has to survive intact; the reading beside it can
            // shrink, because a clipped label leaves the row meaningless.
            Text(reason.label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(missing ? AppColour.textTertiary : AppColour.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
            Spacer(minLength: 6)
            Text(reason.value)
                .font(DS.Typography.footnote)
                .foregroundStyle(missing ? AppColour.textTertiary : AppColour.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .postHogMask()
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func dotColor(_ tone: DashboardViewModel.RecoveryWhyReason.Tone) -> Color {
        switch tone {
        case .good:            return AppColour.success
        case .okay, .concern:  return AppColour.warning
        case .noData:          return AppColour.textTertiary
        }
    }
}

#Preview {
    RecoveryHeroCard(
        score: 77,
        summaryHead: "Higher than usual today.",
        summarySub: "Good to push a little.",
        whyReasons: [
            .init(kind: .sleep, label: "Sleep was short", value: "5h 40m", tone: .concern),
            .init(kind: .heart, label: "Heart is calm", value: "Good", tone: .good),
            .init(kind: .energy, label: "Energy is low", value: "Below usual", tone: .concern),
            .noData(kind: .restingHR),
            .noData(kind: .stress)
        ],
        scoreChange: 4
    )
    .padding(.vertical)
    .background(Color.black)
}
