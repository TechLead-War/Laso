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

    // The pre-registered claim, built from goal + symptom on the prediction
    // screen and persisted so the cliffhanger payoff can mature it later.
    @State private var prediction: PreRegisteredPrediction?
    // The instant verdict, computed in routeAfterScan on the rich branch. nil
    // on the sparse/denied branches (no instant answer).
    @State private var verdict: PredictionVerdict?
    // Nights of sleep still needed before the sparse branch can answer.
    @State private var cliffhangerNights = InsightConfig.GroupDifference.minSamples
    // The single snapshot-load task, started during the scan animation and
    // awaited by routeAfterScan so segmentation runs on a fully loaded
    // snapshot without a second concurrent load.
    @State private var snapshotLoadTask: Task<Void, Never>?

    // Onboarding funnel timing: when the current step appeared and when
    // onboarding started. Feeds the onboarding_step_completed +
    // onboarding_completed funnel events.
    @State private var stepStartedAt = Date()
    @State private var onboardingStartedAt = Date()

    /// Raw values intentionally match the case names so the Firebase Remote
    /// Config key `onboarding_skip_screens` (CSV) can reference them by name
    /// at runtime.
    enum Screen: String, Hashable, CaseIterable {
        case welcome        // 1
        case promise        // 2
        case about          // 3
        case goal           // 4
        case symptoms       // 5
        case prediction     // 6  (pre-registered claim, built from goal+symptom)
        case activity       // 7
        case wearable       // 8
        case bridge         // 9
        case scan           // 10 (system HealthKit sheet fires before this)
        // Mutually exclusive router targets, reached only from `scan` based on
        // the data-richness segment. They share ordinal 11 (the linear slot
        // they replace).
        case verdict        // 11 rich
        case cliffhanger    // 11 sparse
        case journalFirst   // 11 denied
        case heart          // 12
        case sleep          // 13
        case hrv            // 14
        case preview        // 15
        case signIn         // 16
        case paywall        // 17
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
#if DEBUG
            // Screenshot harness: jump straight to a requested screen and seed
            // realistic health data so the data-driven screens (scan/heart/
            // sleep/hrv) render fully instead of their empty state.
            if let raw = UITestMode.onboardingV2StartScreen, let target = Screen(rawValue: raw) {
                healthSnapshot.applyUITestMockData()
                // The mid-flow screens are built from goal+symptom+scan state the
                // harness skips, so seed that state here too; without it they fall
                // through to .heart and cannot be captured from a single launch.
                if [.prediction, .verdict, .cliffhanger].contains(target) {
                    profile.goals = [.sleep]
                    profile.symptoms = [.tiredMorning]
                    prediction = buildPrediction()
                    if target == .verdict, let prediction {
                        verdict = PredictionVerdictEngine.evaluate(
                            prediction: prediction,
                            history: healthSnapshot.verdictHistory
                        )
                    }
                }
                screen = target
            }
#endif
            // Hotfix kill switch — when a middle screen crashes mid-flow, flip
            // ON in Firebase Remote Config to send new installs straight to the
            // paywall while a fix ships. Only honoured if we are still on the
            // welcome screen so a user mid-flow does not get teleported.
            if screen == .welcome, RemoteConfigManager.shared.onboardingForceSkipToPaywall {
                screen = .paywall
            }
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
                                 onContinue: {
                                     prediction = buildPrediction()
                                     advance(to: .prediction)
                                 })
        case .prediction:
            // Without a buildable claim (no mapped goal/symptom) the verdict
            // branch is meaningless, so skip straight to the activity question.
            if let prediction {
                OnbV2ScreenPrediction(prediction: prediction,
                                      onBack: { advance(to: .symptoms) },
                                      onCTA: { advance(to: .activity) })
            } else {
                Color.clear.onAppear { advance(to: .activity) }
            }
        case .activity:
            OnbV2Screen6Activity(profile: profile,
                                 onBack: { advance(to: .prediction) },
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
            OnbV2Screen10Scan(snapshot: healthSnapshot) {
                Task { await routeAfterScan() }
            }
        case .verdict:
            if let prediction, let verdict {
                // The proof chart reads per-weekday means (Mon..Sun) the snapshot
                // already computed for the HRV screen — no second HealthKit query.
                // weekday highlights the confirmed driver day; nil on
                // refuted/inconclusive, where the chart is hidden anyway.
                OnbV2ScreenVerdict(prediction: prediction,
                                   verdict: verdict,
                                   weekdayMeans: healthSnapshot.hrvWeekdayMeans,
                                   onContinue: { advance(to: .heart) })
            } else {
                Color.clear.onAppear { advance(to: .heart) }
            }
        case .cliffhanger:
            OnbV2ScreenCliffhanger(nightsRemaining: cliffhangerNights,
                                   onNotifyYes: { await requestNotificationPermission() },
                                   onContinue: { advance(to: .heart) })
        case .journalFirst:
            OnbV2ScreenJournalFirst(onContinue: { advance(to: .heart) })
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
            OnbV2Screen14Preview(profile: profile,
                                 snapshot: healthSnapshot,
                                 onBack: { advance(to: .hrv) },
                                 onContinue: { advance(to: .signIn) })
        case .signIn:
            OnbV2Screen15SignIn(onBack: { advance(to: .preview) },
                                onSignedIn: handleSignedIn)
        case .paywall:
            // After sign-in, going back to the sign-in screen would re-prompt
            // an authenticated user, which is jarring. Skip back to preview.
            OnbV2Screen16Paywall(profile: profile,
                                 snapshot: healthSnapshot,
                                 verdict: verdict,
                                 onBack: { advance(to: .preview) },
                                 onPurchased: { advance(to: .done) })
        case .done:
            OnbV2ScreenDone {
                persistOnboardingProfile()
                // Mark complete BEFORE tracking so the onboarding_completed user
                // property is already true when the event fires (not contradictory).
                appStateStore.markOnboardingCompleted()
                AppAnalytics.shared.trackOnboardingCompleted(
                    focuses: profile.goals.map { $0.asHealthFocus.rawValue },
                    durationSec: max(0, Int(Date().timeIntervalSince(onboardingStartedAt)))
                )
                completeNotificationSetup()
                onComplete()
            }
        }
    }

    private func advance(to next: Screen) {
        // Honour the Firebase Remote Config `onboarding_skip_screens` CSV by
        // walking forward through the ordinal order until a non-skipped screen.
        // Back navigation is never skipped — we want the user to land where
        // they tapped, even if that screen happens to be in the skip set.
        var target = next
        let goingForward = Self.screenOrdinal(next) > Self.screenOrdinal(screen)
        if goingForward {
            let skipSet = RemoteConfigManager.shared.onboardingSkipScreens
            while skipSet.contains(target.rawValue) {
                let currentOrdinal = Self.screenOrdinal(target)
                let later = Screen.allCases
                    .filter { Self.screenOrdinal($0) > currentOrdinal }
                    .min(by: { Self.screenOrdinal($0) < Self.screenOrdinal($1) })
                guard let after = later, after != target else { break }
                target = after
            }
        }

        // Screens are ordered by `Self.screenOrdinal`. A move to a higher ordinal
        // means the current screen was completed (the forward funnel); a move to a
        // lower ordinal is the user reconsidering and going back.
        let durationSec = max(0, Int(Date().timeIntervalSince(stepStartedAt)))
        if Self.screenOrdinal(target) > Self.screenOrdinal(screen) {
            AppAnalytics.shared.trackOnboardingStepCompleted(
                stepKey: screen.rawValue,
                stepIndex: Self.screenOrdinal(screen),
                stepCount: Self.stepCount,
                durationSec: durationSec,
                action: .completed
            )
        } else if Self.screenOrdinal(target) < Self.screenOrdinal(screen) {
            AppAnalytics.shared.trackOnboardingStepCompleted(
                stepKey: screen.rawValue,
                stepIndex: Self.screenOrdinal(screen),
                stepCount: Self.stepCount,
                durationSec: durationSec,
                action: .back
            )
        }
        screen = target
        stepStartedAt = Date()
    }

    /// Total user-facing steps in this onboarding version (excludes the
    /// post-flow `done` screen and the two router alternates that share a slot
    /// with `.verdict`, so a user only ever traverses this many distinct
    /// ordinals). Counting distinct ordinals keeps the funnel denominator equal
    /// to the visible progress total.
    private static let stepCount = Set(
        Screen.allCases.filter { $0 != .done }.map(screenOrdinal)
    ).count

    /// Step number used in analytics. Matches the user-visible 1-based step
    /// index. The three router screens share ordinal 11 (the linear slot they
    /// replace), so the forward/back funnel comparison stays monotonic across
    /// whichever branch the user lands on.
    private static func screenOrdinal(_ screen: Screen) -> Int {
        switch screen {
        case .welcome:      return 1
        case .promise:      return 2
        case .about:        return 3
        case .goal:         return 4
        case .symptoms:     return 5
        case .prediction:   return 6
        case .activity:     return 7
        case .wearable:     return 8
        case .bridge:       return 9
        case .scan:         return 10
        case .verdict, .cliffhanger, .journalFirst: return 11
        case .heart:        return 12
        case .sleep:        return 13
        case .hrv:          return 14
        case .preview:      return 15
        case .signIn:       return 16
        case .paywall:      return 17
        case .done:         return 18
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
              let dateOfBirth = Date.cal.date(byAdding: .year, value: -profile.age, to: Date()) else {
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

    /// Persist the answers persistOnboardingProfile drops (symptoms, activity,
    /// wearable) plus the pre-registered prediction, so screen 5's "we will
    /// watch for them" promise is true and the cliffhanger payoff can mature
    /// the claim later. Called once the prediction is built.
    private func persistCapturedAnswers() {
        OnboardingPredictionStore.saveAnswers(
            OnboardingPredictionStore.CapturedAnswers(
                symptomKeys: profile.symptoms.map(\.rawValue),
                activityKey: profile.activity?.rawValue,
                wearableKey: profile.wearable?.rawValue
            )
        )
        if let prediction {
            OnboardingPredictionStore.savePrediction(prediction)
        }
    }

    /// Builds the claim from the user's first goal + chosen symptom, using their
    /// own words for `userPhrase`. Returns nil when neither maps to a metric.
    private func buildPrediction() -> PreRegisteredPrediction? {
        // First symptom that maps to a metric drives the claim; .none is never
        // a real symptom so it is excluded.
        let symptom = profile.symptoms.first { $0 != .none }
        let goal = profile.primaryGoal
        return PredictionBuilder.makePrediction(
            symptomKey: symptom?.rawValue,
            symptomPhrase: symptom.map { Copy.OnboardingV2.symptomCopy[$0]?.label ?? $0.rawValue },
            goalKey: goal?.rawValue,
            goalPhrase: goal.map { Copy.OnboardingV2.goalCopy[$0]?.title ?? $0.rawValue }
        )
    }

    /// Runs after the scan animation. Awaits the snapshot, segments on data
    /// richness, and routes to the matching branch screen. Computes the
    /// instant verdict only on the rich branch. MainActor because it mutates
    /// @State and reads the @MainActor snapshot.
    @MainActor
    private func routeAfterScan() async {
        // Await the load started during the scan animation (see
        // requestHealthKitAndAdvance). If the user deep-linked straight to scan
        // (no load task), load now as a fallback so segmentation has data.
        if let snapshotLoadTask {
            await snapshotLoadTask.value
        } else {
            await healthSnapshot.load()
        }
        persistCapturedAnswers()

        guard let prediction else {
            // No testable claim — treat as the journal-first experience.
            advance(to: .journalFirst)
            return
        }

        let history = healthSnapshot.verdictHistory
        let segment = PredictionVerdictEngine.segment(
            prediction: prediction,
            history: history,
            hasAnyHealthData: healthSnapshot.hasAnyHealthData
        )
        AnalyticsBackend.provider.capture(
            event: "day1_data_richness_segment",
            properties: ["segment": segment.rawValue]
        )

        switch segment {
        case .rich:
            // A rich segment can still land inconclusive; the prediction was
            // already persisted above so the answer-ready push can fire when it
            // confirms later.
            verdict = PredictionVerdictEngine.evaluate(prediction: prediction, history: history)
            advance(to: .verdict)
        case .sparse:
            let result = PredictionVerdictEngine.evaluate(prediction: prediction, history: history)
            cliffhangerNights = result.nightsRemaining ?? InsightConfig.GroupDifference.minSamples
            advance(to: .cliffhanger)
        case .denied:
            advance(to: .journalFirst)
        }
    }

    /// Fires the system notification prompt from the cliffhanger opt-in. Kept
    /// separate so the prompt only appears after the user taps yes. On grant we
    /// arm the abandonment reminders here (rather than only at completion) so a
    /// user who opts in on the cliffhanger but then drops out is still recovered.
    @MainActor
    private func requestNotificationPermission() async {
        let granted = await NotificationManager.shared.requestAuthorization(source: "cliffhanger")
        if granted {
            OnboardingAbandonmentScheduler.schedule()
        }
    }

    private func requestHealthKitAndAdvance() {
        guard !isRequestingHealth else { return }
        isRequestingHealth = true
        Task { @MainActor in
            await healthKitManager.requestAuthorization()
            isRequestingHealth = false
            advance(to: .scan)
            // Load the snapshot during the ~7s scan animation so its queries
            // overlap the animation. routeAfterScan awaits this exact task, so
            // segmentation never runs on a half-loaded snapshot and no second
            // concurrent load races the same @MainActor state.
            snapshotLoadTask = Task { await healthSnapshot.load() }
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

    /// Prompt for notification permission (mirrors the HealthKit ask) and arm
    /// the post-onboarding notification tracks. Onboarding is now complete, so
    /// the abandonment reminders are cancelled regardless of permission. The
    /// engagement drip and re-engagement track only arm when the user actually
    /// granted — scheduling them for a declined user is wasted work that iOS
    /// silently drops. The ContentView launch fallback still covers users who
    /// reach the dashboard without passing through here.
    private func completeNotificationSetup() {
        // Goal complete: the user finished onboarding, so no abandonment nudge
        // should ever fire. Cancel even when permission was declined.
        OnboardingAbandonmentScheduler.cancelAll()

        Task { @MainActor in
            let granted = await NotificationManager.shared.requestAuthorization(source: "onboarding")
            guard granted else { return }
            await EngagementSequenceScheduler.start(
                healthStore: healthKitManager.healthStore,
                dataStore: NotificationManager.shared.store,
                userName: UserProfileStore.shared.storedName()
            )
            ReengagementScheduler.reschedule()
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
