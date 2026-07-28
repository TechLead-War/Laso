import BackgroundTasks
import Foundation
import WidgetKit

/// Encapsulates BGTask registration, scheduling, and execution.
final class BackgroundRefreshCoordinator {
    private let taskIdentifier: String
    private let earliestBeginInterval: TimeInterval
    private let completionDelay: TimeInterval
    private let liveViewModelFactory: @MainActor () -> LiveViewModel

    private var hasRegistered = false

    /// Tracks last successful foreground analysis completion for incremental skip logic.
    /// If the foreground pipeline completed recently, background task only refreshes
    /// readiness + widget snapshot without re-running the full ML pipeline.
    private static let incrementalSkipInterval: TimeInterval = 2 * 3600 // 2 hours

    init(
        taskIdentifier: String = AppConstants.BackgroundTask.readinessRefresh,
        earliestBeginInterval: TimeInterval = AppConstants.BackgroundTask.earliestBeginInterval,
        completionDelay: TimeInterval = AppConstants.BackgroundTask.completionDelay,
        liveViewModelFactory: @escaping @MainActor () -> LiveViewModel = {
            let healthKitManager = HealthKitManager()
            return LiveViewModel(
                healthKitManager: healthKitManager,
                readinessStore: ReadinessStore()
            )
        }
    ) {
        self.taskIdentifier = taskIdentifier
        self.earliestBeginInterval = earliestBeginInterval
        self.completionDelay = completionDelay
        self.liveViewModelFactory = liveViewModelFactory
    }

    func register() {
        guard !hasRegistered else { return }
        hasRegistered = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { [weak self] task in
            guard let self, let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            self.handle(refreshTask)
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliestBeginInterval)
        try? BGTaskScheduler.shared.submit(request)
    }


    func handle(_ task: BGAppRefreshTask) {
        if ThermalManager.shared.shouldThrottle {
            schedule() // re-schedule for later
            // Emitted before setTaskCompleted so the system keeps the process
            // alive long enough to send it. Without this a throttling device is
            // a silent gap, indistinguishable from a BGTask that never ran.
            Task { @MainActor in
                AppAnalytics.shared.trackBackgroundRefreshResult(
                    success: false,
                    reason: .thermalThrottle,
                    durationMs: 0,
                    samplesLoaded: 0
                )
                task.setTaskCompleted(success: false)
            }
            return
        }

        schedule()

        let startTime = Date()
        let delay = completionDelay

        let workTask = Task { @MainActor in
            // Re-check thermal state before doing work — device may have heated up
            // between the initial check and actual execution.
            guard !ThermalManager.shared.shouldThrottle else {
                AppAnalytics.shared.trackBackgroundRefreshResult(
                    success: false,
                    reason: .thermalThrottle,
                    durationMs: Int(Date().timeIntervalSince(startTime) * 1000),
                    samplesLoaded: 0
                )
                task.setTaskCompleted(success: false)
                return
            }

            let liveViewModel = liveViewModelFactory()

            // Incremental mode: if foreground ML pipeline ran recently, only fetch
            // lightweight readiness data instead of triggering full analysis.
            let lastMLRun = UserDefaults.standard.object(forKey: "lastMLPipelineCompletion") as? Date
            let isRecentForegroundRun = lastMLRun.map { Date().timeIntervalSince($0) < Self.incrementalSkipInterval } ?? false

            if isRecentForegroundRun {
                // Lightweight: just fetch readiness inputs (RHR, HRV, sleep)
                liveViewModel.fetchHomeDataTiered()
            } else {
                liveViewModel.fetchHomeData()
            }

            try? await Task.sleep(for: .seconds(delay))

            let success = liveViewModel.recovery.readinessScore != nil
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

            if let score = liveViewModel.recovery.readinessScore {
                // Background refresh updates score/grade only. The day-type comes
                // from the strain coach, which this lightweight LiveViewModel does
                // not run, so keep the last foreground-computed value. Empty when
                // there is none: the widget drops an empty day type rather than
                // showing a call the app never made.
                let snapshot = WidgetReadinessSnapshot(
                    score: score,
                    grade: HealthScore.gradeWithPlus(for: score),
                    dayType: WidgetDataStore.shared.loadReadiness()?.dayType ?? "",
                    updatedAt: Date()
                )
                if WidgetDataStore.shared.saveReadinessIfChanged(snapshot) {
                    WidgetDataStore.shared.markLastUpdate()
                    WidgetCenter.shared.reloadAllTimelines()
                    AppAnalytics.shared.trackWidgetSnapshotUpdated(
                        trigger: "background_refresh",
                        snapshotsWritten: 1,
                        hasReadiness: true,
                        hasSleep: false,
                        hasAction: false,
                        hasIntelligence: false,
                        hasRecoveryDebt: false
                    )
                }
            }

            await rearmNotifications(liveViewModel: liveViewModel)

            task.setTaskCompleted(success: success)
            AppAnalytics.shared.trackBackgroundRefreshResult(
                success: success,
                reason: success ? .ok : .noReadiness,
                durationMs: durationMs,
                samplesLoaded: loadedReadingCount(liveViewModel)
            )
        }

        task.expirationHandler = {
            workTask.cancel()
        }
    }

    /// How many readings this background pass actually pulled.
    ///
    /// `samples_loaded` used to be `success ? 1 : 0`, a second copy of `success`,
    /// so a pass that only re-read the cached morning lock looked exactly like
    /// one that pulled fresh data. The view model is built fresh for every pass,
    /// so every value present here was loaded by this pass. `fetchHomeData` does
    /// not run the HealthKit sync pipeline, so no true sample count exists in
    /// this path — this is a count of populated readings.
    @MainActor
    private func loadedReadingCount(_ liveViewModel: LiveViewModel) -> Int {
        let readings: [Bool] = [
            liveViewModel.vitals.currentHeartRate != nil,
            liveViewModel.vitals.currentBloodOxygen != nil,
            liveViewModel.vitals.currentRespiratoryRate != nil,
            liveViewModel.recovery.latestRestingHeartRate != nil,
            liveViewModel.recovery.latestHRV != nil,
            liveViewModel.activity.todaySteps > 0,
            liveViewModel.activity.todayActiveCalories > 0,
            liveViewModel.activity.todayExerciseMinutes > 0,
            liveViewModel.sleep.lastNightSleepDuration > 0
        ]
        return readings.filter { $0 }.count
    }

    /// Re-arm the post-onboarding notification tracks during a background refresh
    /// so they keep advancing for users who rarely foreground the app. Gated on
    /// live authorization so we never schedule for users who declined. Runs
    /// inside the BG MainActor block under the ~5s completion budget.
    @MainActor
    private func rearmNotifications(liveViewModel: LiveViewModel) async {
        guard await NotificationManager.shared.isCurrentlyAuthorized() else { return }

        let store = NotificationManager.shared.store

        ReengagementScheduler.reschedule()
        // `healthStore` flows through HealthKitManager (Core/Data) without naming
        // the HKHealthStore type here, keeping HealthKit isolated to Core.
        await EngagementSequenceScheduler.start(
            healthStore: liveViewModel.healthKitManager.healthStore,
            dataStore: store,
            userName: UserProfileStore.shared.storedName()
        )

        // Journey 4: fire the cliffhanger payoff once the stored inconclusive
        // prediction has matured against live data.
        AnswerReadyScheduler.checkAndFire(store: store)
        // Journey 5: denied-branch re-permission once the user has logged enough
        // check-ins, restating their own words.
        RepermissionScheduler.checkAndFire()

        // Wind-down needs a real target bedtime. Full housekeeping does not run
        // in BG, so derive one from the stored sleep history. A nil store here
        // means this is a scene-less background relaunch where the startup
        // coordinator never ran — NOT that the user lacks sleep data — so leave
        // any pending wind-down (scheduled by the last foreground pass) intact
        // instead of cancelling tonight's reminder.
        guard let store else { return }
        let need = SleepNeedCalculator().compute(
            from: store,
            currentStrain: 0,
            sleepDebt: 0,
            // Background pass has no circadian analyzer, so without the anchor
            // this falls back to averaging raw sample dates and the wind-down
            // reminder drifts away from the wake time the user chose.
            targetWakeTime: WakeUpTimeDetector.anchorDate(
                on: Date.cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            )
        )
        let defaults = UserDefaults.standard
        let lastHRV = defaults.integer(forKey: AppKeys.Notifications.lastHRVValue)
        WindDownScheduler.schedule(
            recommendedBedtime: need.recommendedBedtime,
            lastHRV: lastHRV > 0 ? lastHRV : nil,
            hrvIsLow: false,
            preferences: PersistenceManager().loadPreferences()
        )
    }
}
