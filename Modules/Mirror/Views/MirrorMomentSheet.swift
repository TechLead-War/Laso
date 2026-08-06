import SwiftUI

/// The Mirror Moment: a compact, dismissible sheet over Home, shown at most
/// once per day after the readiness score has rendered. First ever showing
/// asks for a one tap commitment; every day after it leads with streak state
/// and teases yesterday's locked photo. Capture opens the existing
/// MirrorCaptureSheet, whose 7 day replay is the reveal.
struct MirrorMomentSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let manager = MirrorMomentManager.shared
    private let store = MirrorPhotoStore.shared

    @State private var showCapture = false
    /// Set the moment any button decides the outcome, so onDisappear can count
    /// a swipe-down as a dismissal without double-counting button exits.
    @State private var outcomeRecorded = false
    /// One-shot guard: the fullScreenCover removes this sheet from the
    /// hierarchy, so onAppear/onDisappear fire around every capture attempt,
    /// not just at real presentation and dismissal.
    @State private var openTracked = false
    /// Snapshotted once: tapping the commit button flips the manager's
    /// first-run flag mid-presentation, and the copy and detent must not
    /// swap underneath the capture transition.
    @State private var isFirstRun = MirrorMomentManager.shared.needsFirstRun

    var body: some View {
        ScrollView {
            sheetContent
        }
        .background(AppColour.surfaceRaised)
        .presentationDetents([.height(isFirstRun ? 400 : 380)])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Straight to the capture confirm step: screenshots of the overlay
            // picker need no tap the simulator's missing camera would block.
            if UITestMode.isEnabled, UITestMode.mirrorConfirmFilter != nil {
                showCapture = true
            }
            guard !openTracked else { return }
            openTracked = true
            // The day is stamped here, on confirmed presentation, never at
            // the call site: a failed presentation attempt (another sheet
            // already up) must not burn the one impression the day gets.
            manager.markShown()
            AppAnalytics.shared.trackFeatureOpen(.mirrorMoment)
        }
        .onDisappear {
            // The capture cover also removes this view; that is not an exit.
            guard !showCapture else { return }
            AppAnalytics.shared.trackFeatureClose(.mirrorMoment)
            // A swipe-down is a "not today" said with a gesture.
            if !outcomeRecorded {
                manager.recordDismissal()
            }
        }
        .fullScreenCover(isPresented: $showCapture, onDismiss: {
            if store.hasPhoto(on: .now) {
                // Captured: the reveal (7 day replay) already played inside
                // the capture flow, so the moment sheet just leaves quietly.
                dismiss()
            } else {
                // Camera abandoned: the outcome is undecided again, so a
                // later swipe-down must still count as a dismissal.
                outcomeRecorded = false
            }
        }) {
            MirrorCaptureSheet()
        }
    }

    private var sheetContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isFirstRun ? Copy.Mirror.momentEyebrow : manager.eyebrow())
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(AppColour.primary)
                .textCase(.uppercase)
                .kerning(1.1)
                .padding(.top, DS.space5)

            Text(isFirstRun ? Copy.Mirror.momentCommitTitle : manager.dailyTitle())
                .font(DS.Typography.title3)
                .foregroundStyle(AppColour.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.space2)

            if !isFirstRun, let brokenLine = manager.brokenStreakLine() {
                Text(brokenLine)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
                    .padding(.top, DS.space1)
            }

            teaseRow
                .padding(.top, DS.space4)

            Button {
                outcomeRecorded = true
                if isFirstRun {
                    manager.recordCommit()
                    AppAnalytics.shared.trackBlockTap(
                        title: "Mirror commit",
                        type: .mirrorMomentCommit,
                        screen: .mirrorMoment
                    )
                } else {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Mirror moment capture",
                        type: .mirrorMomentCapture,
                        screen: .mirrorMoment,
                        metadata: ["streak": store.currentStreak]
                    )
                }
                showCapture = true
            } label: {
                Text(isFirstRun ? Copy.Mirror.momentCommitCTA : Copy.Mirror.momentCaptureCTA)
                    .font(DS.Typography.headline)
                    .foregroundStyle(AppColour.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.space4)
                    .background(AppColour.primary, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            }
            .buttonStyle(.dsPress)
            .padding(.top, DS.space5)

            Button {
                outcomeRecorded = true
                manager.recordDismissal()
                AppAnalytics.shared.trackBlockTap(
                    title: "Mirror moment declined",
                    type: isFirstRun ? .mirrorMomentLater : .mirrorMomentNotToday,
                    screen: .mirrorMoment
                )
                dismiss()
            } label: {
                Text(isFirstRun ? Copy.Mirror.momentCommitLater : Copy.Mirror.momentNotToday)
                    .font(DS.Typography.subheadlineMedium)
                    .foregroundStyle(AppColour.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.space3)
            }

            if isFirstRun {
                Text(Copy.Mirror.momentPrivacyLine)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, DS.space6)
        .padding(.bottom, DS.space4)
    }

    /// Yesterday's photo, blurred and locked, as the honest hook: today's
    /// capture is the key. Before there is a yesterday, the replay countdown
    /// carries the tease instead.
    private var teaseRow: some View {
        HStack(spacing: DS.space3) {
            if let frame = MirrorPhotoFrame.forStoredDay(Date().daysAgo(1), thumbnail: true) {
                frame
                    .frame(width: DS.iconSize, height: DS.iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: DS.iconRadius))
                    .blur(radius: 5)
                    .clipShape(RoundedRectangle(cornerRadius: DS.iconRadius))
                    .overlay {
                        Image(systemName: "lock.fill")
                            .font(DS.Typography.footnoteMedium)
                            .foregroundStyle(.white)
                    }
                Text(Copy.Mirror.momentTeaseLocked)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Image(systemName: "camera.fill")
                    .font(DS.Typography.mediumIcon)
                    .foregroundStyle(AppColour.primary)
                    .frame(width: DS.iconSize, height: DS.iconSize)
                Text(isFirstRun
                     ? Copy.Mirror.momentCommitLine
                     : Copy.Mirror.momentTeaseProgress(max(1, 7 - store.photoCount)))
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.space3)
        .background(AppColour.surfaceBase, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
}
