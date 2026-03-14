import BackgroundTasks
import Foundation

/// Encapsulates BGTask registration, scheduling, and execution.
final class BackgroundRefreshCoordinator {
    private let taskIdentifier: String
    private let earliestBeginInterval: TimeInterval
    private let completionDelay: TimeInterval
    private let liveViewModelFactory: () -> LiveViewModel

    private var hasRegistered = false

    init(
        taskIdentifier: String = AppConstants.BackgroundTask.readinessRefresh,
        earliestBeginInterval: TimeInterval = AppConstants.BackgroundTask.earliestBeginInterval,
        completionDelay: TimeInterval = AppConstants.BackgroundTask.completionDelay,
        liveViewModelFactory: @escaping () -> LiveViewModel = {
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
        schedule()

        let liveViewModel = liveViewModelFactory()
        task.expirationHandler = {}

        liveViewModel.fetchHomeData()

        DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay) {
            task.setTaskCompleted(success: liveViewModel.recovery.readinessScore != nil)
        }
    }
}
