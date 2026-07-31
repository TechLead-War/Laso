import SwiftUI

/// One time nudge to put the readiness complication on the watch face.
///
/// The complication never appears on its own, so without this most people who
/// install the watch app never see their score on the face. Shown only when there
/// is actually a watch to put it on, and it goes away for good once they add it or
/// dismiss it. Collapsed to a single line; the full steps live on the Apple Watch
/// device screen (DeviceDetailView), which is where they always were.
struct WatchComplicationCard: View {

    let linkState: WatchLinkState

    @State private var isDismissed = UserDefaults.standard.bool(
        forKey: AppKeys.Watch.complicationPromptDismissed)
    @State private var hasTrackedImpression = false

    private var shouldShow: Bool {
        linkState.isPaired
            && linkState.isWatchAppInstalled
            && !linkState.isComplicationEnabled
            && !isDismissed
    }

    var body: some View {
        if shouldShow {
            HStack(spacing: DS.space3) {
                Image(systemName: "applewatch.watchface")
                    .font(DS.Typography.bodySemibold)
                    .foregroundStyle(AppColour.scoreGood)

                Text(Copy.Devices.WatchComplication.title)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.calloutSemibold)
                        .foregroundStyle(AppColour.textTertiary)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel(Copy.Devices.WatchComplication.dismissLabel)
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: AppColour.scoreGood)
            .padding(.horizontal, DS.screenPadding)
            .accessibilityIdentifier("home.watchComplicationCard")
            .onAppear {
                // LazyVStack re-fires onAppear on every scroll-back.
                guard !hasTrackedImpression else { return }
                hasTrackedImpression = true
                AppAnalytics.shared.trackBlockTap(
                    title: "Watch Complication Prompt Shown", type: .smartAction, screen: .home,
                    metadata: ["source": "watch_complication", "action": "shown"])
            }
        }
    }

    private func dismiss() {
        UserDefaults.standard.set(true, forKey: AppKeys.Watch.complicationPromptDismissed)
        AppAnalytics.shared.trackBlockTap(
            title: "Watch Complication Prompt Dismissed", type: .smartAction, screen: .home,
            metadata: ["source": "watch_complication", "action": "dismissed"])
        withAnimation { isDismissed = true }
    }
}
