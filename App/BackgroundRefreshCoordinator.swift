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

    private static func gradeForScore(_ score: Int) -> String {
        switch score {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        default: return "D"
        }
    }

    func handle(_ task: BGAppRefreshTask) {
        schedule()

        let startTime = Date()
        task.expirationHandler = {}
        let delay = completionDelay

        Task { @MainActor in
            let liveViewModel = liveViewModelFactory()
            liveViewModel.fetchHomeData()

            try? await Task.sleep(for: .seconds(delay))

            let success = liveViewModel.recovery.readinessScore != nil
            let durationMs = Int(Date().timeIntervalSince(startTime) * 1000)

            if let score = liveViewModel.recovery.readinessScore {
                let snapshot = WidgetReadinessSnapshot(
                    score: score,
                    grade: Self.gradeForScore(score),
                    dayType: "",
                    updatedAt: Date()
                )
                WidgetDataStore.shared.saveReadiness(snapshot)
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

            task.setTaskCompleted(success: success)
            AppAnalytics.shared.trackBackgroundRefreshResult(
                success: success,
                durationMs: durationMs,
                samplesLoaded: success ? 1 : 0
            )
        }
    }
}
