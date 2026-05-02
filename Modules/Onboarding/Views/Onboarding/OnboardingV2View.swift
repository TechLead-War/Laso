import SwiftUI

/// New 16-screen onboarding flow router. Replaces the legacy `OnboardingView`
/// (TabView-based 7-step). Navigation is index-based with a forward-only fade
/// transition; back goes to previous screen.
///
/// Screen 9 in the design (custom HealthKit consent overlay) is intentionally
/// skipped — production uses the system HealthKit consent UI triggered from
/// screen 8's CTA. The flow goes 8 → (system sheet) → 10 directly.
struct OnboardingV2View: View {
    let healthKitManager: HealthKitManager
    let appStateStore: AppStateStore
    let subscriptionManager: SubscriptionManager
    /// Full first-launch HealthKit calibration. Runs in the background once
    /// HealthKit authorization is granted so the dashboard hydrates with real
    /// data the moment onboarding finishes — without it the dashboard's
    /// fallback `load()` races the sparse preview snapshot and metric keys
    /// silently drop, leaving Vitality/Strain/Stress empty on first launch.
    let runCalibration: () async -> String?
    let onComplete: () -> Void

    @State private var profile = OnboardingV2Profile()
    @State private var screen: Screen = .welcome
    @State private var isRequestingHealth = false
    @State private var calibrationStarted = false
    @State private var healthSnapshot = OnboardingHealthSnapshot()

    enum Screen: Hashable {
        case welcome        // 1
        case promise        // 2
        case about          // 3
        case goal           // 4
        case symptoms       // 5
        case activity       // 6
        case wearable       // 7
        case bridge         // 8
        case scan           // 10 (9 is the system HealthKit sheet)
        case heart          // 11
        case sleep          // 12
        case hrv            // 13
        case preview        // 14
        case signIn         // 15
        case paywall        // 16
        case done           // post
    }

    var body: some View {
        ZStack {
            content
                .id(screen)
                .transition(.opacity.combined(with: .offset(y: 6)))
        }
        .animation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.42), value: screen)
        .onAppear {
            Task { @MainActor in
                if subscriptionManager.products.isEmpty {
                    await subscriptionManager.loadProducts()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .welcome:
            OnbV2Screen1Welcome { advance(to: .promise) }
        case .promise:
            OnbV2Screen2Promise(onBack: { advance(to: .welcome) }) {
                advance(to: .about)
            }
        case .about:
            OnbV2Screen3About(profile: profile,
                              onBack: { advance(to: .promise) },
                              onContinue: { advance(to: .goal) })
        case .goal:
            OnbV2Screen4Goal(profile: profile,
                             onBack: { advance(to: .about) },
                             onContinue: { advance(to: .symptoms) })
        case .symptoms:
            OnbV2Screen5Symptoms(profile: profile,
                                 onBack: { advance(to: .goal) },
                                 onContinue: { advance(to: .activity) })
        case .activity:
            OnbV2Screen6Activity(profile: profile,
                                 onBack: { advance(to: .symptoms) },
                                 onContinue: { advance(to: .wearable) })
        case .wearable:
            OnbV2Screen7Wearable(profile: profile,
                                 onBack: { advance(to: .activity) },
                                 onContinue: { advance(to: .bridge) })
        case .bridge:
            OnbV2Screen8Bridge(goal: profile.primaryGoal,
                               onBack: { advance(to: .wearable) },
                               onCTA: requestHealthKitAndAdvance)
        case .scan:
            OnbV2Screen10Scan(snapshot: healthSnapshot) { advance(to: .heart) }
        case .heart:
            OnbV2Screen11Heart(snapshot: healthSnapshot,
                               onBack: { advance(to: .scan) },
                               onContinue: { advance(to: .sleep) })
        case .sleep:
            OnbV2Screen12Sleep(snapshot: healthSnapshot,
                               onBack: { advance(to: .heart) },
                               onContinue: { advance(to: .hrv) })
        case .hrv:
            OnbV2Screen13HRV(snapshot: healthSnapshot,
                             onBack: { advance(to: .sleep) },
                             onContinue: { advance(to: .preview) })
        case .preview:
            OnbV2Screen14Preview(onBack: { advance(to: .hrv) },
                                 onContinue: { advance(to: .signIn) })
        case .signIn:
            OnbV2Screen15SignIn(onBack: { advance(to: .preview) },
                                onSignedIn: handleSignedIn)
        case .paywall:
            // After sign-in, going back to the sign-in screen would re-prompt
            // an authenticated user, which is jarring. Skip back to preview.
            OnbV2Screen16Paywall(onBack: { advance(to: .preview) },
                                 onPurchased: { advance(to: .done) })
        case .done:
            OnbV2ScreenDone {
                persistOnboardingProfile()
                appStateStore.markOnboardingCompleted()
                onComplete()
            }
        }
    }

    private func advance(to next: Screen) {
        // Track backward navigation as a separate signal so funnel analysis can
        // distinguish completed steps from steps the user reconsidered. Screens
        // are ordered by `Self.screenOrdinal`; any move to a lower ordinal is "back".
        if Self.screenOrdinal(next) < Self.screenOrdinal(screen) {
            AppAnalytics.shared.trackOnboardingNavTapped(
                step: Self.screenOrdinal(screen),
                stepName: String(describing: screen),
                action: "back"
            )
        }
        screen = next
    }

    /// Step number used in analytics. Matches the user-visible 1-based step index.
    private static func screenOrdinal(_ screen: Screen) -> Int {
        switch screen {
        case .welcome:  return 1
        case .promise:  return 2
        case .about:    return 3
        case .goal:     return 4
        case .symptoms: return 5
        case .activity: return 6
        case .wearable: return 7
        case .bridge:   return 8
        case .scan:     return 10
        case .heart:    return 11
        case .sleep:    return 12
        case .hrv:      return 13
        case .preview:  return 14
        case .signIn:   return 15
        case .paywall:  return 16
        case .done:     return 17
        }
    }

    /// Persist V2 onboarding inputs to the same encrypted stores the legacy flow
    /// used (PersistenceManager + UserProfileStore). Health focuses drive the
    /// dashboard's goal-aware insight filtering (DashboardViewModel reads them
    /// in `updateCachedProperties`); without this save, V2 goals would be lost
    /// after onboarding.
    private func persistOnboardingProfile() {
        let focuses: Set<HealthFocus> = profile.goals.isEmpty
            ? Set(HealthFocus.allCases)
            : Set(profile.goals.map { $0.asHealthFocus })
        PersistenceManager().saveHealthFocuses(focuses)

        guard profile.age > 0,
              let dateOfBirth = Calendar.current.date(byAdding: .year, value: -profile.age, to: Date()) else {
            return
        }

        let storedName = UserProfileStore.shared.storedName() ?? ""
        let storedEmail = UserProfileStore.shared.storedEmail() ?? ""
        let userProfile = UserProfileStore.shared.makeProfile(
            name: storedName,
            email: storedEmail,
            gender: profile.sex?.asGender ?? .preferNotToSay,
            dateOfBirth: dateOfBirth,
            healthFocuses: focuses.map(\.rawValue)
        )
        UserProfileStore.shared.save(userProfile)
    }

    private func requestHealthKitAndAdvance() {
        guard !isRequestingHealth else { return }
        isRequestingHealth = true
        Task { @MainActor in
            await healthKitManager.requestAuthorization()
            isRequestingHealth = false
            advance(to: .scan)
            // Start loading real health data for screens 10–13. The scan screen
            // takes ~7s to animate, giving the queries time to finish before
            // screen 11 is reached. Screens render their own loading/empty
            // state if data isn't ready yet.
            Task { await healthSnapshot.load() }
            // Kick off the full dashboard calibration in parallel. The user
            // spends ~30s on screens 10–16 (scan → heart → sleep → hrv →
            // preview → sign-in → paywall), which is long enough for the 10y
            // HealthKit pull + analysis pipeline to finish. When onboarding
            // ends, ContentView's `pendingCalibrationHydration` check trips
            // and the dashboard renders fully populated instead of waiting on
            // a second sync that races a sparse preview snapshot.
            if !calibrationStarted {
                calibrationStarted = true
                Task.detached(priority: .userInitiated) {
                    _ = await runCalibration()
                }
            }
        }
    }

    private func handleSignedIn() {
        // If the user already has full access (free-year flag, restored
        // entitlement) skip the paywall — never charge an entitled user.
        if FeatureGate.hasFullAccess {
            advance(to: .done)
        } else {
            advance(to: .paywall)
        }
    }
}
