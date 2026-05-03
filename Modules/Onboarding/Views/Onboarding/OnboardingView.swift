import SwiftUI
import HealthKit

/// Root onboarding coordinator. Seven screen flow: pulse, profile, connect, priority, mirror,
/// promise (Apple Sign In gate), trial (StoreKit autopay setup with the 7-day introductory
/// free trial). Notifications, cycle opt in, and the standalone medical disclaimer are deferred
/// to contextual surfaces. Disclaimer is acknowledged when the trial purchase succeeds.
struct OnboardingView: View {
    enum OnboardingStep: String, Hashable {
        case pulse
        case profile
        case connect
        case priority
        case mirror
        case promise
        case trial
    }

    @State private var currentStep: OnboardingStep = .pulse
    @State private var selectedFocuses: Set<HealthFocus> = []
    @State private var onboardingStartDate = Date()
    @State private var stepStartDate = Date()

    @State private var profileGender: Gender?
    @State private var profileAge: Int?
    @State private var discovery: CalibrationDiscovery = CalibrationDiscovery()

    let healthKitManager: HealthKitManager
    let appStateStore: AppStateStore
    let subscriptionManager: SubscriptionManager
    let runCalibration: () async -> String?
    let onComplete: () -> Void

    /// Onboarding steps. Kept stable (always 7 entries) so the TabView selection
    /// binding can never point at a missing tag. Skipping the paywall when the
    /// user already has full access is handled by the promise step's branching
    /// closure and PaywallView's own self-advance on appear, not by mutating
    /// this list mid-flow (which would cause a blank-tab render glitch).
    private var flowSteps: [OnboardingStep] {
        [.pulse, .profile, .connect, .priority, .mirror, .promise, .trial]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentStep) {
                OnboardingPulseStep {
                    advance(to: .profile)
                }
                .tag(OnboardingStep.pulse)

                ProfileCaptureView { _, _, gender, age in
                    profileGender = gender
                    profileAge = age
                    advance(to: .connect)
                }
                .tag(OnboardingStep.profile)

                OnboardingConnectHealthStep(healthKitManager: healthKitManager, age: profileAge) {
                    advance(to: .priority)
                }
                .tag(OnboardingStep.connect)

                OnboardingFocusSelectionStep(selectedFocuses: $selectedFocuses) {
                    advance(to: .mirror)
                }
                .tag(OnboardingStep.priority)

                OnboardingMirrorMomentStep(
                    isActive: currentStep == .mirror,
                    selectedFocuses: selectedFocuses,
                    healthKitManager: healthKitManager,
                    runCalibration: runCalibration
                ) { result in
                    discovery = result
                    advance(to: .promise)
                }
                .tag(OnboardingStep.mirror)

                OnboardingPromiseStep(discovery: discovery) {
                    // Skip the paywall step entirely when full access is
                    // already granted (e.g. free-year RC bypass or restored
                    // entitlement) so the user never sees an autopay prompt
                    // they don't need.
                    if FeatureGate.hasFullAccess {
                        finishOnboarding()
                    } else {
                        advance(to: .trial)
                    }
                }
                .tag(OnboardingStep.promise)

                PaywallView(
                    subscriptionManager: subscriptionManager,
                    source: "onboarding"
                ) {
                    finishOnboarding()
                }
                .tag(OnboardingStep.trial)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(true)

            if currentStep != .pulse, let currentProgressIndex = flowSteps.firstIndex(of: currentStep) {
                HStack(spacing: DS.space2) {
                    ForEach(0..<flowSteps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentProgressIndex ? AppColour.primary : AppColour.borderLow)
                            .frame(
                                width: index == currentProgressIndex ? DS.space2 : 6,
                                height: index == currentProgressIndex ? DS.space2 : 6
                            )
                            .animation(DS.Motion.transition, value: currentStep)
                    }
                }
                .padding(.bottom, DS.space4)
            }
        }
        .accessibilityIdentifier("screen.onboarding")
        .background(AppColour.surfaceBase)
        .interactiveDismissDisabled()
        .sensoryFeedback(.selection, trigger: currentStep)
        .onAppear {
            onboardingStartDate = Date()
            stepStartDate = Date()
            AppAnalytics.shared.trackFeatureOpen(.onboarding)
            // UI-test deep-link: jump to the requested onboarding step on first
            // appear so each step can be screenshotted in a single launch.
            if UITestMode.isEnabled,
               let raw = UITestMode.onboardingStartStep,
               let step = OnboardingStep(rawValue: raw) {
                currentStep = step
            }
        }
        .onChange(of: currentStep) { oldStep, newStep in
            guard oldStep != newStep else { return }
            let stepDuration = Int(Date().timeIntervalSince(stepStartDate))
            AppAnalytics.shared.trackOnboardingStepCompleted(
                step: stepIndex(for: oldStep),
                stepName: oldStep.rawValue,
                durationSec: stepDuration
            )
            stepStartDate = Date()
        }
        .onDisappear {
            if !appStateStore.onboardingCompleted {
                let totalDuration = Int(Date().timeIntervalSince(onboardingStartDate))
                AppAnalytics.shared.trackOnboardingDropOff(
                    lastStep: stepIndex(for: currentStep),
                    lastStepName: currentStep.rawValue,
                    durationSec: totalDuration
                )
            }
        }
    }

    private func advance(to step: OnboardingStep) {
        withAnimation(.smooth(duration: 0.4)) { currentStep = step }
    }

    private func finishOnboarding() {
        let focuses = selectedFocuses.isEmpty ? Set(HealthFocus.allCases) : selectedFocuses
        PersistenceManager().saveHealthFocuses(focuses)
        saveUserProfile(focuses: focuses)

        appStateStore.markDisclaimerAcknowledged()

        let totalDuration = Int(Date().timeIntervalSince(onboardingStartDate))
        AppAnalytics.shared.trackOnboardingCompleted(
            focuses: focuses.map(\.rawValue),
            durationSec: totalDuration,
            stepsCompleted: flowSteps.count
        )
        AppAnalytics.shared.trackFeatureClose(.onboarding)

        onComplete()
    }

    private func saveUserProfile(focuses: Set<HealthFocus>) {
        // Profile screen validates 13..120 and gates onComplete behind a non-nil age,
        // so a missing profileAge here means the profile step was bypassed (e.g.
        // UI test deep-link). In that case we save no profile rather than fabricate
        // a fake DOB -- a fake age would silently corrupt Vitality Age and any other
        // age-norm calculation downstream.
        guard let age = profileAge,
              let dateOfBirth = Date.cal.date(byAdding: .year, value: -age, to: Date()) else {
            return
        }

        let profile = UserProfileStore.shared.makeProfile(
            name: "",
            email: "",
            gender: profileGender ?? .preferNotToSay,
            dateOfBirth: dateOfBirth,
            healthFocuses: focuses.map(\.rawValue)
        )
        UserProfileStore.shared.save(profile)
    }

    private func stepIndex(for step: OnboardingStep) -> Int {
        flowSteps.firstIndex(of: step) ?? 0
    }
}
