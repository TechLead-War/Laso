import AuthenticationServices
import SwiftUI

/// Screen 6: The 7 day promise landing.
/// Apple Sign In is mandatory here. Successful sign-in advances the user to the
/// trial setup step. There is no skip path -- onboarding cannot proceed without
/// a Firebase identity attached, so the subscription entitlement is portable
/// across devices.
struct OnboardingPromiseStep: View {
    let discovery: CalibrationDiscovery
    let onAuthenticated: () -> Void

    @State private var showFullDisclaimer = false
    @State private var isSigningInWithApple = false
    @State private var appleSignInError: String?

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

            VStack(spacing: DS.space2) {
                if let appleSignInError {
                    Text(appleSignInError)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(AppColour.danger)
                        .multilineTextAlignment(.center)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { _ in
                    handleAppleSignIn()
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .disabled(isSigningInWithApple)
                .opacity(isSigningInWithApple ? 0.5 : 1)
                .accessibilityIdentifier("onboarding.signInWithApple")

                Text(Copy.Onboarding.promiseSignInHelper)
                    .font(DS.Typography.caption2)
                    .foregroundStyle(AppColour.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showFullDisclaimer) {
            MedicalDisclaimerView {
                showFullDisclaimer = false
            }
        }
    }

    private func handleAppleSignIn() {
        guard !isSigningInWithApple else { return }
        isSigningInWithApple = true
        appleSignInError = nil

        Task {
            do {
                let result = try await AppleAuthService.shared.signIn()
                AppAnalytics.shared.trackBlockTap(
                    title: "Sign in with Apple",
                    type: .onboardingGetStarted,
                    screen: .onboarding,
                    metadata: [
                        "step_name": "promise",
                        "is_new_user": result.isNewUser,
                        "has_email": result.email != nil
                    ]
                )
                _ = await NotificationManager.shared.requestAuthorization(source: "onboarding")
                await MainActor.run {
                    isSigningInWithApple = false
                    onAuthenticated()
                }
            } catch AppleAuthService.AppleAuthError.userCancelled {
                await MainActor.run {
                    isSigningInWithApple = false
                    appleSignInError = nil
                }
            } catch {
                await MainActor.run {
                    isSigningInWithApple = false
                    appleSignInError = "Couldn't sign in with Apple. Please try again."
                }
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
