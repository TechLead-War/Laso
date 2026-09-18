import SwiftUI

/// Score card: one readiness ring with a plain-word state, a one-line summary,
/// and the "Why" list of the real signals behind it. Deliberately simple — the
/// number never appears without a plain reason, and the missing-signals line is
/// the card's one honesty device.
struct RecoveryHeroCard: View {
    /// Nil when nothing has been scored yet. The card then says so instead of
    /// drawing a ring around a number the user never earned.
    let score: Int?
    /// Bold heading under the orb, e.g. "Higher than usual today."
    var summaryHead: String = ""
    /// Lighter sub line under the heading, e.g. "Good to push a little."
    var summarySub: String = ""
    /// The real reasons behind the score, ranked by the caller; the card shows
    /// at most the best three and the ring tap owns the rest.
    var whyReasons: [DashboardViewModel.RecoveryWhyReason] = []
    /// True when live readiness is absent and the ring carries the daily score
    /// instead. The label and narration must never say "Readiness" then — a
    /// relabeled fallback was the B3 contradiction.
    var isFallbackScore: Bool = false
    var isWearingWatch: Bool = true
    /// Scorer-fed signals with no reading today. Non-empty renders the one
    /// tappable coverage line at the card's foot.
    var missingSignals: [String] = []
    var onTap: (() -> Void)? = nil
    /// Opens the detail screen for one signal in the Why list.
    var onTapWhy: ((DashboardViewModel.RecoveryWhyReason.Kind) -> Void)? = nil
    /// Opens the Health-app instruction screen for the missing signals.
    var onFixCoverage: (() -> Void)? = nil
    /// Nil hides the share icon entirely — the caller passes nil when there is
    /// no earned win to share.
    var onShare: (() -> Void)? = nil

    /// The screen never shows more Why rows than a glance can hold; the rest
    /// live behind the ring tap.
    private static let maxWhyRows = 3

    private var visibleWhyReasons: [DashboardViewModel.RecoveryWhyReason] {
        Array(whyReasons.prefix(Self.maxWhyRows))
    }

    /// Ring label follows the score's real identity, so a daily-score fallback
    /// can never wear the Readiness name.
    private var ringLabel: String {
        isFallbackScore ? Copy.Common.healthScore : Copy.Home.scoreReadyLabel
    }

    /// No morning lock today and the watch is off — nothing legitimate to show.
    private var shouldShowWearWatch: Bool {
        !isWearingWatch && score == 0
    }

    var body: some View {
        Group {
            if let score {
                if shouldShowWearWatch {
                    Button { onTap?() } label: { wearWatchEmptyState }
                        .buttonStyle(.dsPress)
                } else {
                    cardContent(score: score)
                }
            } else {
                Button { onTap?() } label: { noScoreEmptyState }
                    .buttonStyle(.dsPress)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let onShare, !shouldShowWearWatch, let score, score > 0 {
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
            // Activation counts real readiness sightings only; a fallback daily
            // score is not the moment the milestone celebrates.
            guard isWearingWatch, !isFallbackScore, let score, score > 0 else { return }
            if UserDefaults.standard.bool(forKey: AppKeys.Engagement.firstRecoveryScoreSeen) {
                EngagementSequenceScheduler.markActivation(.secondRecoveryScore)
            } else {
                EngagementSequenceScheduler.markActivation(.firstRecoveryScore)
            }
        }
    }

    // MARK: - No Score Empty State

    /// Shown before anything has been scored. Says what is missing and what the
    /// user can do, and never puts a number where there is no measurement.
    private var noScoreEmptyState: some View {
        HStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(DS.Typography.title2)
                .foregroundStyle(AppColour.textTertiary)
                .frame(width: 56, height: 56)
                .background(AppColour.surfaceRaised, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(Copy.Home.scoreNoDataYet)
                    .font(DS.Typography.bodyMedium)
                    .foregroundStyle(AppColour.textPrimary)
                Text(Copy.Home.scoreNoDataYetDetail)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(DS.cardPadding + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.borderLow, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Copy.Home.scoreNoDataYet). \(Copy.Home.scoreNoDataYetDetail)")
        .accessibilityIdentifier("home.recoveryCard.noScore")
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

    /// The card is a stack of separate buttons, not one big button, because a
    /// Button nested inside another Button's label never receives the tap.
    private func cardContent(score: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ring on the left, the "Why" list on the right — compact side by
            // side. Ring is vertically centered against the taller Why column.
            HStack(alignment: .center, spacing: 16) {
                Button { onTap?() } label: { ringColumn(score: score) }
                    .buttonStyle(.dsPress)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(ringLabel) \(score)")
                    .accessibilityHint(Copy.Home.opensScoreBreakdownHint)

                if !visibleWhyReasons.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.Home.scoreWhyLabel)
                            .font(DS.Typography.captionSemibold)
                            .tracking(1.4)
                            .foregroundStyle(AppColour.textTertiary)
                            .padding(.bottom, 2)

                        ForEach(Array(visibleWhyReasons.enumerated()), id: \.element.id) { index, reason in
                            Button { onTapWhy?(reason.kind) } label: { whyRow(reason) }
                                .buttonStyle(.dsPress)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(reason.label), \(reason.value)")
                                .accessibilityHint(Copy.Home.viewDetailsHint(reason.kind.displayName))

                            if index < visibleWhyReasons.count - 1 {
                                Divider().overlay(AppColour.borderLow)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

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

            coverageRow
        }
        .padding(DS.cardPadding + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.borderLow, lineWidth: 1))
        .accessibilityIdentifier("home.recoveryCard")
    }

    private func ringColumn(score: Int) -> some View {
        let recoveryState = DashboardViewModel.RecoveryState(score: score)
        return ZStack {
            // Soft glow via a radial gradient (cheap) rather than a
            // Gaussian blur, which re-renders offscreen every frame and
            // makes scrolling lag. Same RecoveryState colour as the ring,
            // so a red morning can never glow green.
            Circle()
                .fill(RadialGradient(
                    colors: [recoveryState.color.opacity(0.28), .clear],
                    center: .center, startRadius: 6, endRadius: 66))
                .frame(width: 132, height: 132)
                .allowsHitTesting(false)
            HealthScoreRing(
                score: score,
                label: ringLabel,
                size: 104,
                lineWidth: 9,
                tint: recoveryState.color
            )
        }
        .frame(width: 132)
        .contentShape(Rectangle())
    }

    /// The card's one honesty device: names the scorer-fed signals with no
    /// reading and opens the screen that fixes them. Silent on a full read.
    @ViewBuilder
    private var coverageRow: some View {
        if !missingSignals.isEmpty {
            Button { onFixCoverage?() } label: {
                Text(Copy.Home.coverageInlineMissing(missingSignals.sentenceList))
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .accessibilityLabel(Copy.Home.coverageInlineMissing(missingSignals.sentenceList))
            .accessibilityIdentifier("home.recoveryCard.missingSignals")
        }
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
            .init(kind: .energy, label: "Energy is low", value: "Below usual", tone: .concern)
        ],
        missingSignals: ["Resting HR", "Stress"]
    )
    .padding(.vertical)
    .background(Color.black)
}
