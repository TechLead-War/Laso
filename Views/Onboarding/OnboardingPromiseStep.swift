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
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 72, height: 72)
                .background(Color.blue.opacity(0.12), in: Circle())
                .padding(.bottom, 20)

            Text(Copy.Onboarding.promiseTitle)
                .font(.title2.weight(.bold))
                .padding(.bottom, 10)

            Text(promiseCopy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            siriTipCard
                .padding(.top, 24)

            Spacer()

            disclaimerFooter
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

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
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
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
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(Copy.Onboarding.worksWithSiri)
                    .font(.subheadline.weight(.semibold))
                Text(Copy.Onboarding.siriTip)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    private var disclaimerFooter: some View {
        VStack(spacing: 4) {
            Text(Copy.Onboarding.promiseDisclaimerFooter)
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .accessibilityIdentifier("onboarding.promiseDisclaimerLearnMore")
        }
    }
}
