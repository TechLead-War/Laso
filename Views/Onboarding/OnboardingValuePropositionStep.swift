import SwiftUI

struct OnboardingValuePropositionStep: View {
    let onContinue: () -> Void

    private let bullets: [(icon: String, title: String)] = [
        ("person.fill", Copy.Onboarding.bulletPersonalized),
        ("shield.fill", Copy.Onboarding.bulletPrivate),
        ("chart.line.uptrend.xyaxis", Copy.Onboarding.bulletActionable)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(Copy.Labels.appName)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)

            Text(Copy.Onboarding.whatYouGet)
                .font(.title2.weight(.bold))
                .padding(.bottom, 24)

            VStack(spacing: 14) {
                ForEach(Array(bullets.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24, height: 24)
                            .background(Color.accentColor.opacity(0.12), in: Circle())

                        Text(item.title)
                            .font(.subheadline.weight(.medium))

                        Spacer()
                    }
                }
            }
            .padding(20)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()
            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Continue",
                    type: .onboardingCultureContinue,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "value_proposition"
                    ]
                )
                onContinue()
            } label: {
                Text(Copy.Buttons.continueButton)
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
