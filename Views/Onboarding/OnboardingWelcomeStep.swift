import SwiftUI

struct OnboardingWelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Step 1")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            Image("LaunchIcon")
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.bottom, 24)

            Text(Copy.Labels.appName)
                .font(.system(size: 32, weight: .bold))
                .padding(.bottom, 8)

            Text(Copy.Onboarding.tagline)
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()
            Spacer()

            Button {
                onContinue()
            } label: {
                Text(Copy.Buttons.getStarted)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(.headline)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
