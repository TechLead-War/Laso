import SwiftUI
import HealthKit

// MARK: - OnboardingView

struct OnboardingView: View {
    enum OnboardingStep: String, Hashable {
        case welcome
        case valueProposition = "value_proposition"
        case profileCapture = "profile_capture"
        case connectHealth = "connect_health"
        case cycleOptIn = "cycle_opt_in"
        case focusCalibration = "focus_calibration"
    }

    @State private var currentStep: OnboardingStep = .welcome
    @State private var selectedFocuses: Set<HealthFocus> = []
    @State private var onboardingStartDate = Date()
    @State private var stepStartDate = Date()

    // Profile capture state
    @State private var profileName: String?
    @State private var profileEmail: String?
    @State private var profileGender: Gender?
    @State private var profileAge: Int?

    let healthKitManager: HealthKitManager
    let appStateStore: AppStateStore
    let runCalibration: () async -> String?
    let onComplete: () -> Void

    private var includesCycleStep: Bool {
        profileGender == .female
    }

    private var flowSteps: [OnboardingStep] {
        var steps: [OnboardingStep] = [
            .welcome,
            .valueProposition,
            .profileCapture,
            .connectHealth
        ]
        if includesCycleStep {
            steps.append(.cycleOptIn)
        }
        steps.append(.focusCalibration)
        return steps
    }

    private var progressSteps: [OnboardingStep] {
        flowSteps
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentStep) {
                // Page 0: Welcome
                OnboardingWelcomeStep {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Get Started",
                        type: .onboardingGetStarted,
                        screen: .onboarding,
                        metadata: ["step_name": "welcome"]
                    )
                    withAnimation(.smooth(duration: 0.4)) { currentStep = .valueProposition }
                }
                .tag(OnboardingStep.welcome)

                // Page 1: Value proposition
                OnboardingValuePropositionStep {
                    withAnimation(.smooth(duration: 0.4)) { currentStep = .profileCapture }
                }
                .tag(OnboardingStep.valueProposition)

                // Page 2: Profile capture
                ProfileCaptureView { name, email, gender, age in
                    profileName = name
                    profileEmail = email
                    profileGender = gender
                    profileAge = age
                    if gender != .female {
                        persistCyclePreference(false, trackAnalytics: false)
                    }
                    withAnimation(.smooth(duration: 0.4)) { currentStep = .connectHealth }
                }
                .tag(OnboardingStep.profileCapture)

                // Page 3: Connect Apple Health
                OnboardingConnectHealthStep(healthKitManager: healthKitManager) {
                    withAnimation(.smooth(duration: 0.4)) {
                        currentStep = includesCycleStep ? .cycleOptIn : .focusCalibration
                    }
                }
                .tag(OnboardingStep.connectHealth)

                if includesCycleStep {
                    // Page 4: Female-only cycle tracking opt-in
                    OnboardingCycleOptInStep(
                        onEnable: {
                            persistCyclePreference(true, trackAnalytics: true)
                            withAnimation(.smooth(duration: 0.4)) { currentStep = .focusCalibration }
                        },
                        onSkip: {
                            persistCyclePreference(false, trackAnalytics: true)
                            withAnimation(.smooth(duration: 0.4)) { currentStep = .focusCalibration }
                        }
                    )
                    .tag(OnboardingStep.cycleOptIn)
                }

                // Page 5 (or 4): Focus + Calibration
                OnboardingFocusCalibrationStep(
                    isActive: currentStep == .focusCalibration,
                    selectedFocuses: $selectedFocuses,
                    healthKitManager: healthKitManager,
                    runCalibration: runCalibration,
                    onComplete: finishOnboarding
                )
                .tag(OnboardingStep.focusCalibration)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scrollDisabled(true)

            // Progress dots (visible on non-welcome steps)
            if let currentProgressIndex = progressSteps.firstIndex(of: currentStep) {
                HStack(spacing: 6) {
                    ForEach(0..<progressSteps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentProgressIndex ? Color.accentColor : Color.secondary.opacity(0.2))
                            .frame(
                                width: index == currentProgressIndex ? 8 : 6,
                                height: index == currentProgressIndex ? 8 : 6
                            )
                            .animation(.spring(response: 0.4), value: currentStep)
                    }
                }
                .padding(.bottom, 16)
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
            // Track step completion for the step we just left
            let stepDuration = Int(Date().timeIntervalSince(stepStartDate))
            AppAnalytics.shared.trackOnboardingStepCompleted(
                step: stepIndex(for: oldStep),
                stepName: oldStep.rawValue,
                durationSec: stepDuration
            )
            stepStartDate = Date()
        }
        .onDisappear {
            // If onboarding disappears without completion, track drop-off
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

    private func finishOnboarding() {
        let focuses = selectedFocuses.isEmpty ? Set(HealthFocus.allCases) : selectedFocuses
        PersistenceManager().saveHealthFocuses(focuses)

        // Save user profile to local + Firestore
        saveUserProfile(focuses: focuses)

        // Notification permission is requested from the main app after the
        // dashboard loads — asking here interrupts the onboarding→app transition.

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

        // Convert age to approximate date of birth
        let dateOfBirth: Date
        if let age = profileAge {
            dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: Date()) ?? Date()
        } else {
            dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
        }

        let profile = UserProfileStore.shared.makeProfile(
            name: profileName ?? "",
            email: profileEmail ?? "",
            gender: finalGender,
            dateOfBirth: dateOfBirth,
            healthFocuses: focuses.map(\.rawValue)
        )
        UserProfileStore.shared.save(profile)

        // Persist individual fields for quick access
        if let name = profileName {
            UserDefaults.standard.set(name, forKey: AppKeys.Profile.name)
        }
        if let email = profileEmail {
            UserDefaults.standard.set(email, forKey: AppKeys.Profile.email)
        }
        UserDefaults.standard.set(finalGender.rawValue, forKey: AppKeys.Profile.gender)
        if let age = profileAge {
            UserDefaults.standard.set(age, forKey: AppKeys.Profile.dateOfBirth)
        }
        UserDefaults.standard.set(true, forKey: AppKeys.Profile.profileCompleted)
    }

    private func stepIndex(for step: OnboardingStep) -> Int {
        flowSteps.firstIndex(of: step) ?? 0
    }

    private func persistCyclePreference(_ enabled: Bool, trackAnalytics: Bool) {
        UserDefaults.standard.set(enabled, forKey: AppKeys.Cycle.trackingEnabled)
        if trackAnalytics {
            AppAnalytics.shared.trackSettingChanged(name: "cycle_tracking_enabled", value: enabled)
        }
    }
}
