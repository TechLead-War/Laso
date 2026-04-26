import SwiftUI

/// Screen 1: Ambient pulse hero.
/// Single outcome line, slow heartbeat animation, one Begin button. No progress dots, no "Step 1".
struct OnboardingPulseStep: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale: CGFloat = 1.0
    @State private var haloOpacity: Double = 0.0
    @State private var headlineOpacity: Double = 0.0
    @State private var buttonOpacity: Double = 0.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            pulse
                .frame(width: 180, height: 180)
                .padding(.bottom, DS.space8)

            Text(Copy.Onboarding.pulseHeadline)
                .font(DS.Typography.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColour.textPrimary)
                .padding(.horizontal, DS.space7)
                .opacity(headlineOpacity)

            Spacer()
            Spacer()

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: "Begin",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: ["step_name": "pulse"]
                )
                onContinue()
            } label: {
                Text(Copy.Onboarding.pulseBegin)
            }
            .buttonStyle(.dsPrimary)
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space8)
            .opacity(buttonOpacity)
            .accessibilityIdentifier("onboarding.pulseBegin")
            .accessibilityHint("Starts the onboarding flow")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimation()
        }
    }

    private var pulse: some View {
        ZStack {
            Circle()
                .stroke(AppColour.primary.opacity(0.18), lineWidth: 1)
                .scaleEffect(pulseScale)
                .opacity(haloOpacity)

            Circle()
                .stroke(AppColour.primary.opacity(0.28), lineWidth: 1)
                .scaleEffect(pulseScale * 0.78)
                .opacity(haloOpacity * 0.8)

            Circle()
                .fill(AppColour.primary.opacity(0.10))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(DS.Typography.mediumIcon)
                        .foregroundStyle(AppColour.primary)
                        .accessibilityHidden(true)
                )
                .scaleEffect(1.0 + (pulseScale - 1.0) * 0.25)
        }
        .accessibilityHidden(true)
    }

    private func startAnimation() {
        withAnimation(.easeOut(duration: 0.8)) {
            headlineOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            buttonOpacity = 1.0
        }
        if reduceMotion {
            // 06-F12: honor Reduce Motion. Skip the infinite pulse loop and
            // settle on a static halo so VoiceOver users with motion sensitivity
            // do not see the looping scale animation.
            pulseScale = 1.0
            haloOpacity = 0.6
        } else {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulseScale = 1.35
                haloOpacity = 0.9
            }
        }
    }
}
