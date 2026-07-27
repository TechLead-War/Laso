import SwiftUI

/// New 13-step onboarding flow router. Replaces the legacy `OnboardingView`
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
    @State private var startTracked = false
    // Back-navigation from heart/preview re-lands on the scan, whose timer
    // re-runs routeAfterScan; these flags keep the day-1 segment, the scan's
    // forward funnel step, and the promise screen impression at one emission.
    @State private var scanRouted = false
    @State private var promiseTracked = false
    // Set by the done screen's CTA. `.done` is a live screen, so backgrounding
    // on it before the CTA is a real abandonment; only the CTA ends the funnel.
    @State private var completedTracked = false
    @State private var healthSnapshot = OnboardingHealthSnapshot()

    // The pre-registered claim, built from goal + symptom on the prediction
    // screen and persisted so the cliffhanger payoff can mature it later.
    @State private var prediction: PreRegisteredPrediction?
    // The instant verdict, computed in routeAfterScan on the rich branch. nil
    // on the sparse/denied branches (no instant answer).
    @State private var verdict: PredictionVerdict?
    // Nights of sleep still needed before the sparse branch can answer.
    @State private var cliffhangerNights = InsightConfig.GroupDifference.minSamples
    // Data-richness branch chosen in routeAfterScan. Drives the per-branch
    // screen order (`linearOrder`). nil while the user is still pre-scan,
    // where every branch shares the same screens.
    @State private var branch: DataRichnessSegment?
    // The single snapshot-load task, started during the scan animation and
    // awaited by routeAfterScan so segmentation runs on a fully loaded
    // snapshot without a second concurrent load.
    @State private var snapshotLoadTask: Task<Void, Never>?

    // Onboarding funnel timing: when the current step appeared and when
    // onboarding started. Feeds the onboarding_step_completed +
    // onboarding_completed funnel events.
    @State private var stepStartedAt = Date()
    @State private var onboardingStartedAt = Date()

    // Captures the screen a user quits on: the step funnel only logs screens
    // they navigate away from, so an app-kill mid-flow leaves no record without
    // watching scenePhase.
    @Environment(\.scenePhase) private var scenePhase

    /// Raw values intentionally match the case names so the Firebase Remote
    /// Config key `onboarding_skip_screens` (CSV) can reference them by name
    /// at runtime.
    enum Screen: String, Hashable, CaseIterable {
        case welcome
        case about
        case goal
        case symptoms
        case bridge
        case scan           // system HealthKit sheet fires before this
        // Mutually exclusive router targets, reached only from `scan` based on
        // the data-richness segment. Step numbers are branch-dependent — see
        // `linearOrder`: rich shows the reveal (.preview) right after the scan
        // and the verdict after hrv; sparse/denied show their router screen
        // after the scan and the reveal after hrv.
        case verdict        // rich
        case cliffhanger    // sparse
        case journalFirst   // denied
        case heart
        case sleep
        case hrv
        case preview        // Vitality Age reveal
        case signIn
        case referral       // friend's invite code (skipped when already redeemed)
        case paywall
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
                // Router targets imply a branch; without it the ordinal math
                // falls back to the pre-scan (rich) order and back-navigation
                // from the jumped-to screen misroutes.
                switch target {
                case .verdict:      branch = .rich
                case .cliffhanger:  branch = .sparse
                case .journalFirst: branch = .denied
                default: break
                }
                // The mid-flow screens are built from goal+symptom+scan state the
                // harness skips, so seed that state here too; without it they fall
                // through to .heart and cannot be captured from a single launch.
                if [.verdict, .cliffhanger].contains(target) {
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
                // The paywall's watch list is built from goals + symptoms; seed a
                // multi-item profile so the rows render. Mock scan data above keeps
                // it on the has-insights branch (the common case).
                if target == .paywall {
                    profile.goals = [.sleep, .energy, .stress]
                    profile.symptoms = [.tiredMorning, .restless]
                }
                // Goal override for per-goal screenshot capture (e.g. Screen 14
                // social proof line). Applied last so it wins over the seeds above.
                if let raw = UITestMode.onboardingGoal, let goal = OnbV2Goal(rawValue: raw) {
                    profile.goals = [goal]
                }
                screen = target
            }
#endif
            // Started must precede any step event so strict-order funnels hold,
            // including the kill-switch jump below.
            if !startTracked {
                startTracked = true
                AppAnalytics.shared.trackOnboardingStarted()
            }
            // Hotfix kill switch — when a middle screen crashes mid-flow, flip
            // ON in Firebase Remote Config to send new installs straight to the
            // paywall while a fix ships. Only honoured if we are still on the
            // welcome screen so a user mid-flow does not get teleported.
            if screen == .welcome, RemoteConfigManager.shared.onboardingForceSkipToPaywall {
                // record the welcome exit so the kill-switch jump still shows in the funnel
                AppAnalytics.shared.trackOnboardingStepCompleted(
                    stepKey: Screen.welcome.rawValue, stepIndex: funnelIndex(.welcome),
                    stepCount: stepCount, durationSec: 0, action: .completed)
                screen = .paywall
                // Without this the paywall's step duration includes welcome dwell.
                stepStartedAt = Date()
            }
            Task { @MainActor in
                if subscriptionManager.products.isEmpty {
                    await subscriptionManager.loadProducts()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Record the screen the user quit on. Only `.background` (true quit /
            // home / app-switcher dismiss) counts — `.inactive` is skipped because
            // it also fires for the system HealthKit and Apple Sign-In sheets,
            // which are not exits. Quitting on `.done` before its CTA leaves the
            // user un-completed and restarts onboarding next launch, so it is a
            // drop-off until `completedTracked` says otherwise.
            guard newPhase == .background, !completedTracked else { return }
            AppAnalytics.shared.trackOnboardingDropOff(
                lastStep: screen.rawValue,
                stepIndex: funnelIndex(screen),
                stepCount: stepCount,
                durationSec: max(0, Int(Date().timeIntervalSince(stepStartedAt)))
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .welcome:
            OnbV2Screen1Welcome { advance(to: .about) }
        case .about:
            OnbV2Screen3About(profile: profile,
                              onBack: { advance(to: .welcome) },
                              onContinue: {
                                  AppAnalytics.shared.trackOnboardingProfileSet(
                                      age: profile.age, sex: profile.sex?.rawValue ?? "unspecified")
                                  advance(to: .goal)
                              })
        case .goal:
            OnbV2Screen4Goal(profile: profile,
                             onBack: { advance(to: .about) },
                             onContinue: {
                                 AppAnalytics.shared.trackOnboardingGoalSelected(
                                     goals: profile.goals.map(\.rawValue), count: profile.goals.count)
                                 advance(to: .symptoms)
                             })
        case .symptoms:
            OnbV2Screen5Symptoms(profile: profile,
                                 onBack: { advance(to: .goal) },
                                 onContinue: {
                                     AppAnalytics.shared.trackOnboardingSymptomsSelected(
                                         symptoms: profile.symptoms.map(\.rawValue), count: profile.symptoms.count)
                                     // The claim is still built here (silently). The
                                     // dedicated claim screen is gone, but the
                                     // post-scan verdict / cliffhanger still pay it
                                     // off and the answer-ready push still arms.
                                     prediction = buildPrediction()
                                     advance(to: .bridge)
                                 })
        case .bridge:
            OnbV2Screen8Bridge(onBack: { advance(to: .symptoms) },
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
                                   onContinue: { advance(to: .signIn) })
            } else {
                Color.clear.onAppear { advance(to: .signIn) }
            }
        case .cliffhanger:
            OnbV2ScreenCliffhanger(nightsRemaining: cliffhangerNights,
                                   userPhrase: prediction?.userPhrase,
                                   onNotifyYes: { await requestNotificationPermission(source: "cliffhanger") },
                                   onContinue: { advance(to: .heart) })
                .onAppear { trackPromiseShownOnce(branch: "cliffhanger", nightsRemaining: cliffhangerNights) }
        case .journalFirst:
            OnbV2ScreenJournalFirst(onContinue: { advance(to: .heart) })
                .onAppear { trackPromiseShownOnce(branch: "journal_first") }
        case .heart:
            OnbV2Screen11Heart(snapshot: healthSnapshot,
                               onBack: { advance(to: branch == .rich ? .preview : .scan) },
                               onContinue: { advance(to: .sleep) })
        case .sleep:
            OnbV2Screen12Sleep(snapshot: healthSnapshot,
                               onBack: { advance(to: .heart) },
                               onContinue: { advance(to: .hrv) })
        case .hrv:
            OnbV2Screen13HRV(snapshot: healthSnapshot,
                             onBack: { advance(to: .sleep) },
                             onContinue: { advance(to: branch == .rich ? .verdict : .preview) })
        case .preview:
            OnbV2VitalityRevealScreen(profile: profile,
                                      snapshot: healthSnapshot,
                                      step: screenOrdinal(.preview),
                                      showsNotificationPrimer: branch == .rich,
                                      onBack: { advance(to: branch == .rich ? .scan : .hrv) },
                                      onContinue: {
                                          if branch == .rich {
                                              // The primer above the CTA set up this ask;
                                              // fire the system prompt before moving on.
                                              Task { @MainActor in
                                                  await requestNotificationPermission(source: "vitality_reveal")
                                                  advance(to: .heart)
                                              }
                                          } else {
                                              advance(to: .signIn)
                                          }
                                      })
        case .signIn:
            OnbV2Screen15SignIn(onBack: { advance(to: branch == .rich ? .verdict : .preview) },
                                onSignedIn: handleSignedIn)
        case .referral:
            ReferralCodeStep(onContinue: { advanceAfterReferral() },
                             onSkip: { advanceAfterReferral(action: .skipped) })
        case .paywall:
            // After sign-in, going back to the sign-in screen would re-prompt
            // an authenticated user, which is jarring. Skip back to the screen
            // before sign-in on the current branch.
            OnbV2Screen16Paywall(profile: profile,
                                 snapshot: healthSnapshot,
                                 verdict: verdict,
                                 onBack: { advance(to: branch == .rich ? .verdict : .preview) },
                                 onPurchased: { advance(to: .done) },
                                 onDeclined: {
                                     appStateStore.markPaywallDeclined()
                                     advance(to: .done)
                                 })
        case .done:
            OnbV2ScreenDone {
                completedTracked = true
                persistOnboardingProfile()
                // Mark complete BEFORE tracking so the onboarding_completed user
                // property is already true when the event fires (not contradictory).
                appStateStore.markOnboardingCompleted()
                // The done screen now shows the disclaimer line, so finishing
                // onboarding also acknowledges it — no separate disclaimer gate.
                appStateStore.markDisclaimerAcknowledged()
                AppAnalytics.shared.trackOnboardingCompleted(
                    focuses: profile.goals.map { $0.asHealthFocus.rawValue },
                    durationSec: max(0, Int(Date().timeIntervalSince(onboardingStartedAt)))
                )
                completeNotificationSetup()
                onComplete()
            }
        }
    }

    private func advance(to next: Screen, action: AppAnalytics.OnboardingStepAction = .completed, trackStep: Bool = true) {
        // Honour the Firebase Remote Config `onboarding_skip_screens` CSV by
        // walking forward through the current branch order until a non-skipped
        // screen. Walking `linearOrder` (not allCases) means a router screen
        // from another branch can never be selected as a skip target. Back
        // navigation is never skipped — we want the user to land where they
        // tapped, even if that screen happens to be in the skip set.
        var target = next
        let order = linearOrder
        let goingForward = screenOrdinal(next) > screenOrdinal(screen)
        if goingForward {
            let skipSet = RemoteConfigManager.shared.onboardingSkipScreens
            while skipSet.contains(target.rawValue) {
                // Skipping sign-in must not walk blindly onto the gated
                // referral/paywall screens: redeeming needs auth, and the
                // never-charge-an-entitled-user check lives in
                // advanceAfterReferral. Resolve the same gates here instead
                // of taking the next screen in order.
                if target == .signIn {
                    target = FeatureGate.hasFullAccess ? .done : .paywall
                    continue
                }
                guard let idx = order.firstIndex(of: target), idx + 1 < order.count else { break }
                target = order[idx + 1]
            }
        }

        // Screens are ordered by `screenOrdinal`. A move to a higher ordinal
        // means the current screen was completed (the forward funnel); a move to a
        // lower ordinal is the user reconsidering and going back. `trackStep`
        // is false only on the back-nav scan re-run, whose forward step already
        // fired on the first pass.
        let durationSec = max(0, Int(Date().timeIntervalSince(stepStartedAt)))
        if trackStep, screenOrdinal(target) > screenOrdinal(screen) {
            AppAnalytics.shared.trackOnboardingStepCompleted(
                stepKey: screen.rawValue,
                stepIndex: funnelIndex(screen),
                stepCount: stepCount,
                durationSec: durationSec,
                action: action
            )
        } else if trackStep, screenOrdinal(target) < screenOrdinal(screen) {
            AppAnalytics.shared.trackOnboardingStepCompleted(
                stepKey: screen.rawValue,
                stepIndex: funnelIndex(screen),
                stepCount: stepCount,
                durationSec: durationSec,
                action: .back
            )
        }
        screen = target
        stepStartedAt = Date()
    }

    /// Ordered screens for the current branch. All branches share screens 1-6;
    /// the rich branch shows the reveal right after the scan and holds the
    /// verdict until after hrv, while sparse/denied show their router screen
    /// after the scan and the reveal after hrv. `done` stays last as the
    /// post-flow state.
    private var linearOrder: [Screen] {
        switch branch {
        case .sparse:
            return [.welcome, .about, .goal, .symptoms, .bridge, .scan,
                    .cliffhanger, .heart, .sleep, .hrv, .preview, .signIn, .referral, .paywall, .done]
        case .denied:
            return [.welcome, .about, .goal, .symptoms, .bridge, .scan,
                    .journalFirst, .heart, .sleep, .hrv, .preview, .signIn, .referral, .paywall, .done]
        case .rich, nil:
            // nil = pre-scan, where only the shared screens 1-6 are reachable,
            // so defaulting to the rich order never misroutes.
            return [.welcome, .about, .goal, .symptoms, .bridge, .scan,
                    .preview, .heart, .sleep, .hrv, .verdict, .signIn, .referral, .paywall, .done]
        }
    }

    /// The screens this user will actually walk: the branch order minus the
    /// Remote Config skip list and the two gated screens. `linearOrder.count` is
    /// the same on every branch, so a denominator taken from it is a constant
    /// that ignores every live shortener and makes step_index/step_count
    /// meaningless for a shortened flow.
    private var liveOrder: [Screen] {
        let skipSet = RemoteConfigManager.shared.onboardingSkipScreens
        return linearOrder.filter { candidate in
            guard !skipSet.contains(candidate.rawValue) else { return false }
            switch candidate {
            case .referral:
                return ReferralManager.shared.isEnabled && ReferralManager.shared.redeemedCode == nil
            case .paywall:
                return !FeatureGate.hasFullAccess
            default:
                return true
            }
        }
    }

    /// Total user-facing steps in the live flow (excludes the post-flow `done`
    /// screen). Paired with `funnelIndex`, never with `screenOrdinal`.
    private var stepCount: Int { max(1, liveOrder.count - 1) }

    /// 1-based position in the live flow, used only for the funnel's
    /// `step_index`. A screen the user reached but that is not in `liveOrder`
    /// (a DEBUG jump, or a back tap onto a skip-listed screen) reports the slot
    /// it would have occupied, so the index stays monotonic.
    private func funnelIndex(_ target: Screen) -> Int {
        let cut = screenOrdinal(target)
        return liveOrder.filter { screenOrdinal($0) < cut }.count + 1
    }

    /// 1-based step number used for routing direction and the progress bar,
    /// derived from the current branch order. The two router screens absent from that
    /// order never render on it; they fall back to the post-scan slot (7) they
    /// would have occupied, keeping the funnel monotonic even for stale skip
    /// entries or DEBUG jumps.
    private func screenOrdinal(_ screen: Screen) -> Int {
        (linearOrder.firstIndex(of: screen) ?? 6) + 1
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

    /// Persist the answers persistOnboardingProfile drops (symptoms) plus the
    /// pre-registered prediction, so the symptoms screen's "we will watch for them" promise
    /// is true and the cliffhanger payoff can mature the claim later. Called
    /// once the prediction is built.
    private func persistCapturedAnswers() {
        OnboardingPredictionStore.saveAnswers(
            OnboardingPredictionStore.CapturedAnswers(
                symptomKeys: profile.symptoms.map(\.rawValue)
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

    /// The promise screens are recreated by the back-nav scan re-run, so their
    /// own .onAppear cannot dedupe; this flow-level guard fires exactly once.
    private func trackPromiseShownOnce(branch: String, nightsRemaining: Int? = nil) {
        guard !promiseTracked else { return }
        promiseTracked = true
        AppAnalytics.shared.trackPromiseShown(branch: branch, nightsRemaining: nightsRemaining)
    }

    /// The scan animation already runs about 7 seconds before this is awaited,
    /// so a snapshot that has not landed by now is not going to.
    private static let snapshotLoadDeadline: UInt64 = 8_000_000_000

    /// Lets exactly one of the two racers resume the continuation.
    private actor ResumeGate {
        private var claimed = false
        func claim() -> Bool {
            guard !claimed else { return false }
            claimed = true
            return true
        }
    }

    /// Returns when the task finishes or the deadline passes, whichever comes
    /// first. The task is left running: its results still land on the snapshot
    /// if they arrive later, they simply stop blocking the user.
    ///
    /// Deliberately not a task group. `await task.value` on a `Task<Void, Never>`
    /// ignores cancellation, so a group cannot leave until the hung task itself
    /// returns, which is the exact hang this is meant to escape.
    static func finish(_ task: Task<Void, Never>, within deadlineNs: UInt64) async {
        let gate = ResumeGate()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task {
                await task.value
                if await gate.claim() { continuation.resume() }
            }
            Task {
                try? await Task.sleep(nanoseconds: deadlineNs)
                if await gate.claim() { continuation.resume() }
            }
        }
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
        //
        // Never wait forever. `OnboardingHealthSnapshot.load()` fans out to
        // fourteen concurrent HealthKit queries and awaits every one, so a
        // single query that never calls back used to strand the user on the
        // scan screen with no way out. Whatever loaded by the deadline is what
        // segmentation sees; a thin snapshot routes to the sparse branch, which
        // is a real experience rather than a dead end.
        if let snapshotLoadTask {
            await Self.finish(snapshotLoadTask, within: Self.snapshotLoadDeadline)
        } else {
            await Self.finish(Task { await healthSnapshot.load() },
                              within: Self.snapshotLoadDeadline)
        }
        persistCapturedAnswers()

        let rerun = scanRouted
        scanRouted = true

        guard let prediction else {
            // No testable claim — treat as the journal-first experience.
            branch = .denied
            advance(to: .journalFirst, trackStep: !rerun)
            return
        }

        let history = healthSnapshot.verdictHistory
        let segment = PredictionVerdictEngine.segment(
            prediction: prediction,
            history: history,
            hasAnyHealthData: healthSnapshot.hasAnyHealthData
        )
        if !rerun {
            AppAnalytics.shared.trackDay1DataRichnessSegment(segment.rawValue)
        }

        // Set before advancing so the target's ordinal comes from the right
        // branch order.
        branch = segment
        switch segment {
        case .rich:
            // A rich segment can still land inconclusive; the prediction was
            // already persisted above so the answer-ready push can fire when it
            // confirms later. The verdict itself is paid off after the metric
            // reveals — rich goes to the Vitality Age reveal first.
            verdict = PredictionVerdictEngine.evaluate(prediction: prediction, history: history)
            advance(to: .preview, trackStep: !rerun)
        case .sparse:
            let result = PredictionVerdictEngine.evaluate(prediction: prediction, history: history)
            cliffhangerNights = result.nightsRemaining ?? InsightConfig.GroupDifference.minSamples
            advance(to: .cliffhanger, trackStep: !rerun)
        case .denied:
            advance(to: .journalFirst, trackStep: !rerun)
        }
    }

    /// Fires the system notification prompt from an in-flow primed ask — the
    /// cliffhanger opt-in on the sparse branch, the Vitality Age reveal CTA on
    /// the rich branch. On grant we arm the abandonment reminders here (rather
    /// than only at completion) so a user who opts in mid-flow but then drops
    /// out is still recovered.
    @MainActor
    private func requestNotificationPermission(source: String) async {
        // iOS only shows the prompt while the status is notDetermined; asking a
        // second time returns the cached answer with no alert. Both callers sit
        // on screens that back-navigation recreates, so calling through would
        // log a requested+result pair for a prompt nobody saw.
        let granted: Bool
        if await NotificationManager.shared.shouldRequestAuthorizationOnLaunch() {
            granted = await NotificationManager.shared.requestAuthorization(source: source)
        } else {
            granted = await NotificationManager.shared.isCurrentlyAuthorized()
        }
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

    /// Arm the post-onboarding notification tracks. The permission prompt
    /// itself fires mid-flow (reveal CTA on rich, cliffhanger opt-in on
    /// sparse), so this only reads the current status — never prompts.
    /// Onboarding is now complete, so the abandonment reminders are cancelled
    /// regardless of permission. The engagement drip and re-engagement track
    /// only arm when the user actually granted — scheduling them for a
    /// declined user is wasted work that iOS silently drops. The ContentView
    /// launch fallback still covers users who reach the dashboard without an
    /// in-flow ask (journal-first branch).
    private func completeNotificationSetup() {
        // Goal complete: the user finished onboarding, so no abandonment nudge
        // should ever fire. Cancel even when permission was declined.
        OnboardingAbandonmentScheduler.cancelAll()

        Task { @MainActor in
            let granted = await NotificationManager.shared.isCurrentlyAuthorized()
            guard granted else { return }
            await EngagementSequenceScheduler.start(
                healthStore: healthKitManager.healthStore,
                dataStore: NotificationManager.shared.store,
                userName: UserProfileStore.shared.storedName()
            )
            ReengagementScheduler.reschedule()

            // Trial reminders are armed at purchase, but a user who declined
            // (or never saw) the mid-flow permission ask hit the auth gate
            // there and the arming was silently dropped. Re-arm now that we
            // know permission exists, off the live entitlement end.
            // Idempotent: TrialScheduler uses fixed identifiers, so this
            // replaces rather than duplicates whatever purchase attempted.
            let trialEnd: Date?
            switch subscriptionManager.status {
            case .trial(let expiration): trialEnd = expiration
            case .subscribed(let expiration): trialEnd = expiration
            default: trialEnd = nil
            }
            if let trialEnd {
                TrialScheduler.scheduleTrialLifecycle(trialEnd: trialEnd)
            }
        }
    }

    private func handleSignedIn() {
        // Offer the friend's-invite-code step first (auth now exists, so the
        // redeem callable works). Skipped when the program is off, the user
        // already redeemed on a previous run, or the operator skip-listed the
        // screen — routing through advanceAfterReferral in every skip case so
        // the never-charge-an-entitled-user check cannot be walked past by
        // advance()'s skip-CSV forwarding.
        if ReferralManager.shared.isEnabled,
           ReferralManager.shared.redeemedCode == nil,
           !RemoteConfigManager.shared.onboardingSkipScreens.contains(Screen.referral.rawValue) {
            advance(to: .referral)
        } else {
            advanceAfterReferral()
        }
    }

    /// Post-sign-in routing shared by the referral step and its skip path.
    /// `action` labels how the referral step was left (completed vs skipped).
    private func advanceAfterReferral(action: AppAnalytics.OnboardingStepAction = .completed) {
        // If the user already has full access (free-year flag, restored
        // entitlement) skip the paywall — never charge an entitled user.
        if FeatureGate.hasFullAccess {
            advance(to: .done, action: action)
        } else {
            advance(to: .paywall, action: action)
        }
    }
}
