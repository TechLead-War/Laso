import Foundation

/// Lightweight wrapper around Timer that eliminates the repeated start/stop/invalidate boilerplate.
final class RepeatTimer {
    private var timer: Timer?

    func start(interval: TimeInterval, tolerance: TimeInterval? = nil, action: @escaping () -> Void) {
        stop()
        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in action() }
        t.tolerance = tolerance ?? min(10, interval * 0.2)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stop() }
}
