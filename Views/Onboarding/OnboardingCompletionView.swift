import SwiftUI

struct OnboardingCompletionView: View {
    let discovery: CalibrationDiscovery
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Success icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.green)
                .frame(width: 88, height: 88)
                .background(Color.green.opacity(0.12), in: Circle())
                .padding(.bottom, 24)

            // Title
            Text(Copy.Onboarding.yourHealthDecoded)
                .font(.title2.weight(.bold))
                .padding(.bottom, 4)

            // Data span subtitle
            if let span = discovery.dataSpanDescription {
                Text(Copy.Onboarding.dataSpanSubtitle(span))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Metric highlights
            if !discovery.highlights.isEmpty {
                VStack(spacing: 0) {
                    ForEach(discovery.highlights) { highlight in
                        HStack(spacing: 12) {
                            Image(systemName: highlight.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(highlight.color)
                                .frame(width: 32, height: 32)
                                .background(highlight.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(highlight.metricName): **\(highlight.stat)**")
                                    .font(.subheadline)
                                Text(highlight.detail)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .padding(.top, 20)
            } else {
                // No data fallback
                Text(Copy.Onboarding.noDataYetMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
            }

            // Siri tip
            siriTipCard
                .padding(.top, 16)

            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Start Your Journey",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "focus_calibration",
                        "calibration_state": "success",
                        "metrics_discovered": discovery.metricsWithData,
                        "highlights_shown": discovery.highlights.count
                    ]
                )
                onStart()
            } label: {
                Text(Copy.Onboarding.enterLaso)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .accessibilityIdentifier("onboarding.completionStart")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var siriTipCard: some View {
        VStack(spacing: 8) {
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
        }
        .padding(12)
        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }
}
