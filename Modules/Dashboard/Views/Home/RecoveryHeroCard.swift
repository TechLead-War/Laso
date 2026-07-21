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
    var lastRefresh: Date? = nil
    var isWearingWatch: Bool = true
    var onTap: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil

    @State private var appeared = false

    private var recoveryState: DashboardViewModel.RecoveryState {
        DashboardViewModel.RecoveryState(score: score)
    }

    /// No morning lock today and the watch is off — nothing legitimate to show.
    private var shouldShowWearWatch: Bool {
        !isWearingWatch && score == 0
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            Group {
                if shouldShowWearWatch {
                    wearWatchEmptyState
                } else {
                    cardContent
                }
            }
        }
        .buttonStyle(.dsPress)
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
            appeared = true
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
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.textTertiary.opacity(0.18), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Home.wearAppleWatchForRecovery)
        .accessibilityIdentifier("home.recoveryCard.wearWatch")
    }

    // MARK: - Card Content

    private var ringTint: Color {
        hasLiveReadiness ? recoveryState.color : AppColour.scoreGood
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Centered hero orb with a soft glow, heading and sub line below.
            VStack(spacing: 12) {
                ZStack {
                    // Soft glow via a radial gradient (cheap) rather than a
                    // Gaussian blur, which re-renders offscreen every frame and
                    // makes scrolling lag.
                    Circle()
                        .fill(RadialGradient(
                            colors: [ringTint.opacity(0.28), .clear],
                            center: .center, startRadius: 8, endRadius: 92))
                        .frame(width: 184, height: 184)
                        .allowsHitTesting(false)
                    HealthScoreRing(
                        score: score,
                        label: Copy.Home.scoreReadyLabel,
                        size: 150,
                        lineWidth: 10,
                        tint: hasLiveReadiness ? recoveryState.color : nil
                    )
                }

                VStack(spacing: 3) {
                    Text(summaryHead)
                        .font(DS.Typography.title3)
                        .foregroundStyle(AppColour.textPrimary)
                    Text(summarySub)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            // Why list
            if !whyReasons.isEmpty {
                Divider()
                    .overlay(AppColour.borderLow)
                    .padding(.vertical, 16)

                Text(Copy.Home.scoreWhyLabel)
                    .font(DS.Typography.captionSemibold)
                    .tracking(1.4)
                    .foregroundStyle(AppColour.textTertiary)
                    .padding(.bottom, 2)

                ForEach(Array(whyReasons.enumerated()), id: \.element.id) { index, reason in
                    whyRow(reason)
                    if index < whyReasons.count - 1 {
                        Divider().overlay(AppColour.borderLow.opacity(0.6))
                    }
                }
            }
        }
        .padding(DS.cardPadding + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.borderLow, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Copy.Home.scoreReadyLabel) \(score). \(summaryHead) \(summarySub). " + whyReasons.map { "\($0.label), \($0.value)" }.joined(separator: ". "))
        .accessibilityHint(Copy.Home.opensScoreBreakdownHint)
        .accessibilityIdentifier("home.recoveryCard")
    }

    // MARK: - Why Row

    /// One plain line: a colored dot, the interpretation, and the value.
    private func whyRow(_ reason: DashboardViewModel.RecoveryWhyReason) -> some View {
        HStack(spacing: 11) {
            Circle()
                .fill(dotColor(reason.tone))
                .frame(width: 8, height: 8)
            Text(reason.label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textPrimary)
            Spacer(minLength: 8)
            Text(reason.value)
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)
                .postHogMask()
        }
        .padding(.vertical, 12)
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
        ]
    )
    .padding(.vertical)
    .background(Color.black)
}
