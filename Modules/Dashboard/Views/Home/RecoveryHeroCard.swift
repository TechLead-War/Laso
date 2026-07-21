import SwiftUI

/// Score card: one readiness ring with a plain-word state, a one-line summary,
/// and the "Why" list of the real signals behind it. Deliberately simple — the
/// number never appears without a plain reason.
struct RecoveryHeroCard: View {
    let score: Int
    /// Plain-English line under the score, e.g. "Lower than usual today."
    var summaryLine: String = ""
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

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ring + one-line summary
            HStack(spacing: 18) {
                HealthScoreRing(
                    score: score,
                    label: Copy.Home.scoreReadyLabel,
                    size: 96,
                    lineWidth: 8,
                    tint: hasLiveReadiness ? recoveryState.color : nil
                )

                Text(summaryLine)
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.trailing, 34) // clear the share button

            // Why list
            if !whyReasons.isEmpty {
                Divider()
                    .overlay(AppColour.borderLow)
                    .padding(.vertical, 16)

                Text(Copy.Home.scoreWhyLabel)
                    .font(DS.Typography.captionSemibold)
                    .tracking(1.4)
                    .foregroundStyle(AppColour.textTertiary)

                ForEach(whyReasons) { reason in
                    HStack(spacing: 11) {
                        Circle()
                            .fill(reason.tone == .good ? AppColour.success : AppColour.warning)
                            .frame(width: 7, height: 7)
                        Text(reason.label)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(AppColour.textPrimary)
                        Spacer(minLength: 8)
                        Text(reason.value)
                            .font(DS.Typography.footnote)
                            .foregroundStyle(AppColour.textSecondary)
                            .postHogMask()
                    }
                    .padding(.top, 12)
                }
            }
        }
        .padding(DS.cardPadding + 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColour.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.borderLow, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Copy.Home.scoreReadyLabel) \(score). \(summaryLine). " + whyReasons.map { "\($0.label), \($0.value)" }.joined(separator: ". "))
        .accessibilityHint(Copy.Home.opensScoreBreakdownHint)
        .accessibilityIdentifier("home.recoveryCard")
    }
}

#Preview {
    RecoveryHeroCard(
        score: 68,
        summaryLine: "Lower than usual today. Worth an easy day.",
        whyReasons: [
            .init(label: "Sleep was short", value: "5h 40m", tone: .concern),
            .init(label: "Heart is calm", value: "Good", tone: .good),
            .init(label: "Energy is low", value: "Below usual", tone: .concern)
        ]
    )
    .padding(.vertical)
    .background(Color.black)
}
