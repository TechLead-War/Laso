import SwiftUI

/// Full-screen medical disclaimer shown once on first launch.
/// Required for App Store Review compliance (health app guidelines).
struct MedicalDisclaimerView: View {
    let onAcknowledge: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "cross.case")
                    .font(DS.Typography.heroIcon)
                    .foregroundStyle(.blue)

                Text(Copy.Disclaimer.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    Text(Copy.Disclaimer.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text(Copy.Disclaimer.secondaryBody)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.space7)

                Spacer()

                Button {
                    onAcknowledge()
                } label: {
                    Text(Copy.Disclaimer.acknowledge)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.space4)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityLabel(Copy.Disclaimer.acknowledge)
                .accessibilityHint("Acknowledges the medical disclaimer and continues into the app")
                .padding(.horizontal, DS.space6)
                .padding(.bottom, 40)
            }
        }
        .accessibilityIdentifier("screen.medicalDisclaimer")
        .interactiveDismissDisabled()
    }
}
