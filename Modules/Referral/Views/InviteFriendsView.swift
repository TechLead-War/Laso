import SwiftUI

/// Invite-friends screen, reached from Settings. Shows the user's referral
/// code (minted server-side on first open), the reward deal, the running
/// count of joined friends, and a share CTA carrying the invite message.
struct InviteFriendsView: View {

    @State private var copied = false
    /// Set after the first load attempt fails, so the initial render shows a
    /// spinner rather than flashing the error state before .task has run.
    @State private var codeLoadFailed = false

    private var referral: ReferralManager { .shared }

    /// "15 August 2026"-style label for the free-year banner. nil hides the
    /// urgency line (free year off, end date unset, or date already passed).
    private var freeUntilLabel: String? {
        guard FeatureGate.freeYearActive,
              let end = FeatureGate.freeYearEndDate,
              end > Date() else { return nil }
        return end.formatted(.dateTime.day().month(.wide).year())
    }

    private var shareMessage: String? {
        guard let code = referral.referralCode else { return nil }
        return Copy.Referral.shareCaptionGeneric(code: code)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.itemSpacing) {
                banner
                codeCard
                rewardRow
                progressLine
            }
            .padding(.horizontal, DS.screenPadding)
            .padding(.top, DS.space4)
        }
        .background(AppColour.surfaceBase)
        .navigationTitle(Copy.Referral.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { shareCTA }
        .task {
            codeLoadFailed = await referral.ensureReferralCode() == nil
            await referral.syncWithFirestore()
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.inviteFriends)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.inviteFriends)
        }
    }

    // MARK: - Banner

    private var banner: some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            Text(freeUntilLabel.map { Copy.Referral.bannerTitle(freeUntil: $0) } ?? Copy.Referral.bannerTitleFallback)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(AppColour.textPrimary)
            Text(Copy.Referral.bannerSubtitle)
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .background(AppColour.primarySoft, in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: DS.cardRadius).strokeBorder(AppColour.primary.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Code Card

    private var codeCard: some View {
        Button {
            guard let code = referral.referralCode else { return }
            UIPasteboard.general.string = code
            copied = true
            AppAnalytics.shared.trackBlockTap(
                title: "Copy invite code",
                type: .shareCard,
                screen: .inviteFriends,
                metadata: [:]
            )
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            VStack(spacing: DS.space2) {
                Text(Copy.Referral.yourCodeLabel)
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(AppColour.textTertiary)
                    .kerning(1.2)

                if let code = referral.referralCode {
                    Text(code)
                        .font(DS.Typography.title2.monospaced())
                        .foregroundStyle(AppColour.textPrimary)
                        .postHogMask()
                    Text(copied ? Copy.Referral.copied : Copy.Referral.tapToCopy)
                        .font(DS.Typography.caption)
                        .foregroundStyle(copied ? AppColour.success : AppColour.primary)
                } else if codeLoadFailed {
                    Text(Copy.Referral.codeLoadError)
                        .font(DS.Typography.caption)
                        .foregroundStyle(AppColour.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    ProgressView()
                        .padding(.vertical, DS.space2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DS.cardPadding)
            .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cardRadius)
                    .strokeBorder(AppColour.borderMedium, style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
        .buttonStyle(.dsPress)
        .disabled(referral.referralCode == nil)
        .sensoryFeedback(.success, trigger: copied) { _, new in new }
        .accessibilityIdentifier("invite.codeCard")
    }

    // MARK: - Reward + Progress

    private var rewardRow: some View {
        HStack(alignment: .top, spacing: DS.space3) {
            Text(verbatim: "+1")
                .font(DS.Typography.footnoteMedium)
                .foregroundStyle(AppColour.success)
                .frame(width: 30, height: 30)
                .background(AppColour.success.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.sm))

            Text(Copy.Referral.rewardLine)
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.cardRadius))
    }

    private var progressLine: some View {
        Text(referral.successfulReferrals > 0
             ? Copy.Referral.friendsJoined(referral.successfulReferrals)
             : Copy.Referral.noFriendsYet)
            .font(DS.Typography.footnoteMedium)
            .foregroundStyle(referral.successfulReferrals > 0 ? AppColour.success : AppColour.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, DS.space2)
    }

    // MARK: - Share CTA

    @ViewBuilder
    private var shareCTA: some View {
        if let shareMessage {
            // UIActivityViewController instead of ShareLink: ShareLink has no
            // completion hook, so share_completed could never fire here.
            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Share invite",
                    type: .shareCard,
                    screen: .inviteFriends,
                    metadata: ["source": "invite_screen"]
                )
                ShareButton.presentShareSheet(items: [shareMessage], contentType: "referral_invite")
            } label: {
                Label(Copy.Referral.shareInviteCTA, systemImage: "square.and.arrow.up")
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppColour.info, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, DS.screenPadding)
            }
            .padding(.bottom, DS.space2)
            .background(AppColour.surfaceBase.opacity(0.94))
            .accessibilityIdentifier("invite.shareCTA")
        }
    }
}

#Preview {
    NavigationStack {
        InviteFriendsView()
    }
    .preferredColorScheme(.dark)
}
