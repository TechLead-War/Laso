import SwiftUI

/// Full-screen medical disclaimer shown once on first launch.
/// Required for App Store Review compliance (health app guidelines).
struct MedicalDisclaimerView: View {
    let onAcknowledge: () -> Void

    var body: some View {
        ZStack {
            AppColour.surfaceBase.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "cross.case")
                    .font(DS.Typography.heroIcon)
                    .foregroundStyle(AppColour.primary)

                Text(Copy.Disclaimer.title)
                    .font(.title2.bold())
                    .foregroundStyle(AppColour.textPrimary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    Text(Copy.Disclaimer.body)
                        .font(.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                        .multilineTextAlignment(.center)

                    Text(Copy.Disclaimer.secondaryBody)
                        .font(.subheadline)
                        .foregroundStyle(AppColour.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.space7)

                Spacer()

                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Medical Disclaimer Acknowledge",
                        type: .onboardingGetStarted,
                        screen: .onboarding
                    )
                    onAcknowledge()
                } label: {
                    Text(Copy.Disclaimer.acknowledge)
                        .font(.headline)
                        .foregroundStyle(AppColour.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.space4)
                        .background(AppColour.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityLabel(Copy.Disclaimer.acknowledge)
                .accessibilityHint(Copy.Common.acknowledgesTheMedicalDisclaimerAndContinuesHint)
                .padding(.horizontal, DS.space6)
                .padding(.bottom, 40)
            }
        }
        .accessibilityIdentifier("screen.medicalDisclaimer")
        .interactiveDismissDisabled()
    }
}
