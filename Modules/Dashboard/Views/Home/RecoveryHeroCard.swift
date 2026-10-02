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

    @State private var showReasons = false

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
                        .frame(minWidth: 44, minHeight: 44)
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

    private func cardContent(score: Int) -> some View {
        VStack(spacing: DS.space3) {
            Button { onTap?() } label: {
                HealthScoreGauge(
                    score: score,
                    label: ringLabel,
                    tint: isFallbackScore
                        ? HealthScoreGauge.bandColor(score)
                        : DashboardViewModel.RecoveryState(score: score).color
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint(Copy.Home.opensScoreBreakdownHint)

            if !summaryHead.isEmpty || !summarySub.isEmpty {
                VStack(spacing: DS.space1) {
                    Text(summaryHead)
                        .font(.headline)
                        .foregroundStyle(AppColour.textPrimary)
                    Text(summarySub)
                        .font(.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !missingSignals.isEmpty {
                Button { onFixCoverage?() } label: {
                    HStack(spacing: DS.space2) {
                        Image(systemName: "clock")
                        Text(Copy.Home.coverageInlineMissing(missingSignals.sentenceList))
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                    }
                    .font(.footnote)
                    .foregroundStyle(AppColour.textSecondary)
                    .padding(.horizontal, DS.space3)
                    .padding(.vertical, DS.space2)
                    .frame(minHeight: 44)
                    .background(AppColour.surfaceSubtle, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.recoveryCard.missingSignals")
            }

            if !visibleWhyReasons.isEmpty {
                DisclosureGroup(isExpanded: $showReasons) {
                    VStack(spacing: 0) {
                        ForEach(visibleWhyReasons) { reason in
                            Button { onTapWhy?(reason.kind) } label: {
                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: DS.space2) {
                                        reasonLabel(reason)
                                        Spacer(minLength: 8)
                                        Text(reason.value).foregroundStyle(AppColour.textSecondary)
                                    }
                                    VStack(alignment: .leading, spacing: DS.space1) {
                                        reasonLabel(reason)
                                        Text(reason.value).foregroundStyle(AppColour.textSecondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(.subheadline)
                                .padding(.vertical, DS.space2)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityHint(Copy.Home.viewDetailsHint(reason.kind.displayName))
                        }
                    }
                } label: {
                    Text("Behind your score")
                        .font(.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                        .frame(minHeight: 44)
                }
                .tint(AppColour.textSecondary)
            }
        }
        .padding(.bottom, DS.space2)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("home.recoveryCard")
    }

    private func reasonLabel(_ reason: DashboardViewModel.RecoveryWhyReason) -> some View {
        HStack(spacing: DS.space2) {
            Circle().fill(dotColor(reason.tone)).frame(width: 6, height: 6)
            Text(reason.label)
                .foregroundStyle(AppColour.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
