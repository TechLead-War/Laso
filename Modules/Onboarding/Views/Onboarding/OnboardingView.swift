import SwiftUI
import HealthKit

/// Root onboarding coordinator. Six screen flow: pulse, profile, connect, priority, mirror, promise.
/// Notifications, cycle opt in, and the standalone medical disclaimer are deferred to contextual
/// surfaces. Disclaimer is acknowledged via the footer on the Promise screen when the user taps
/// Open Laso.
struct OnboardingView: View {
    enum OnboardingStep: String, Hashable {
        case pulse
        case profile
        case connect
        case priority
        case mirror
        case promise
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
    let runCalibration: () async -> String?
    let onComplete: () -> Void

    private var flowSteps: [OnboardingStep] {
        [.pulse, .profile, .connect, .priority, .mirror, .promise]
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
                    finishOnboarding()
                }
                .tag(OnboardingStep.promise)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(true)

            if currentStep != .pulse, let currentProgressIndex = flowSteps.firstIndex(of: currentStep) {
                HStack(spacing: 6) {
                    ForEach(0..<flowSteps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentProgressIndex ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(
                                width: index == currentProgressIndex ? 8 : 6,
                                height: index == currentProgressIndex ? 8 : 6
                            )
                            .animation(.spring(response: 0.4), value: currentStep)
                    }
                }
                .padding(.bottom, DS.space4)
            }
        }
        .accessibilityIdentifier("screen.onboarding")
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled()
        .sensoryFeedback(.selection, trigger: currentStep)
        .onAppear {
            onboardingStartDate = Date()
            stepStartDate = Date()
            AppAnalytics.shared.trackFeatureOpen(.onboarding)
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
        let finalGender = profileGender ?? .preferNotToSay

        let dateOfBirth: Date
        if let age = profileAge {
            dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: Date()) ?? Date()
        } else {
            dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        }

        let profile = UserProfileStore.shared.makeProfile(
            name: "",
            email: "",
            gender: finalGender,
            dateOfBirth: dateOfBirth,
            healthFocuses: focuses.map(\.rawValue)
        )
        UserProfileStore.shared.save(profile)
    }

    private func stepIndex(for step: OnboardingStep) -> Int {
        flowSteps.firstIndex(of: step) ?? 0
    }
}
