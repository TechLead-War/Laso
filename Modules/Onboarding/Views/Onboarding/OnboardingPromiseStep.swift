import SwiftUI

/// Screen 6: The 7 day promise landing.
/// Dated numeric promise derived from the user's actual calibration data, a compact Siri affordance,
/// and a footer disclaimer that replaces the standalone medical information screen.
struct OnboardingPromiseStep: View {
    let discovery: CalibrationDiscovery
    let onOpen: () -> Void

    @State private var showFullDisclaimer = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(DS.Typography.mediumIcon)
                .foregroundStyle(AppColour.info)
                .frame(width: 72, height: 72)
                .background(AppColour.info.opacity(DS.badgeBg), in: Circle())
                .padding(.bottom, DS.space5)

            Text(Copy.Onboarding.promiseTitle)
                .font(DS.Typography.title2)
                .padding(.bottom, DS.itemSpacing)

            Text(promiseCopy)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space7)

            siriTipCard
                .padding(.top, DS.space6)

            Spacer()

            disclaimerFooter
                .padding(.horizontal, DS.space6)
                .padding(.bottom, DS.space3)

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Open Laso",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "promise",
                        "metrics_discovered": discovery.metricsWithData,
                        "highlights_shown": discovery.highlights.count
                    ]
                )
                onOpen()
            } label: {
                Text(Copy.Onboarding.promiseOpen)
            }
            .buttonStyle(.dsPrimary)
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space8)
            .accessibilityIdentifier("onboarding.promiseOpen")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showFullDisclaimer) {
            MedicalDisclaimerView {
                showFullDisclaimer = false
            }
        }
    }

    private var promiseCopy: String {
        let count = max(discovery.metricsWithData, discovery.highlights.count)
        guard count > 0 else { return Copy.Onboarding.promiseFallback }
        return Copy.Onboarding.promiseBody(
            patternCount: count,
            span: discovery.dataSpanDescription
        )
    }

    private var siriTipCard: some View {
        HStack(spacing: DS.itemSpacing) {
            Image(systemName: "mic.fill")
                .font(DS.Typography.calloutSemibold)
                .foregroundStyle(AppColour.info)
                .frame(width: 32, height: 32)
                .background(AppColour.info.opacity(DS.badgeBg), in: Circle())

            VStack(alignment: .leading, spacing: DS.space1) {
                Text(Copy.Onboarding.worksWithSiri)
                    .font(DS.Typography.subheadlineSemibold)
                Text(Copy.Onboarding.siriTip)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.space3)
        .background(AppColour.info.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .padding(.horizontal, DS.space6)
    }

    private var disclaimerFooter: some View {
        VStack(spacing: DS.space1) {
            Text(Copy.Onboarding.promiseDisclaimerFooter)
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textTertiary)
                .multilineTextAlignment(.center)

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Full Disclaimer",
                    type: .onboardingContinueAnyway,
                    screen: .onboarding,
                    metadata: ["step_name": "promise"]
                )
                showFullDisclaimer = true
            } label: {
                Text(Copy.Onboarding.promiseDisclaimerLearnMore)
                    .font(DS.Typography.caption2Semibold)
                    .foregroundStyle(AppColour.info)
            }
            .accessibilityIdentifier("onboarding.promiseDisclaimerLearnMore")
        }
    }
}
