import SwiftUI

/// One time nudge to put the readiness complication on the watch face.
///
/// The complication never appears on its own, so without this most people who
/// install the watch app never see their score on the face. Shown only when there
/// is actually a watch to put it on, and it goes away for good once they add it or
/// dismiss it. The same steps stay on the Apple Watch device screen either way.
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
            VStack(alignment: .leading, spacing: DS.space3) {
                HStack(alignment: .top, spacing: DS.space3) {
                    Image(systemName: "applewatch.watchface")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.scoreGood)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: DS.space1) {
                        Text(Copy.Devices.WatchComplication.title)
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textPrimary)

                        Text(Copy.Devices.WatchComplication.subtitle)
                            .font(DS.Typography.footnote)
                            .foregroundStyle(AppColour.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

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

                WatchComplicationSteps()
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
