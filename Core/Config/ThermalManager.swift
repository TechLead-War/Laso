import Foundation
import OSLog
import Observation

/// Monitors device thermal state and exposes throttling decisions.
/// Heavy work (ML, correlations, historical analysis) should check `shouldThrottle`
/// before starting, and abort/skip when the device is under thermal pressure.
@Observable
final class ThermalManager {

    static let shared = ThermalManager()

    private let logger = Logger(subsystem: "com.healthpulse", category: "Thermal")

    // MARK: - State

    /// The current thermal state reported by the OS.
    private(set) var currentState: ProcessInfo.ThermalState

    /// True when thermal state is `.serious` or `.critical`. defer non-essential heavy work.
    var shouldThrottle: Bool {
        currentState == .serious || currentState == .critical
    }

    /// True when thermal state is `.critical`. pause all heavy background work immediately.
    var shouldPauseHeavyWork: Bool {
        currentState == .critical
    }

    /// Prefer static or reduced visual effects when the device is already warming up.
    var shouldReduceVisualEffects: Bool {
        currentState == .fair || shouldThrottle
    }

    /// Longer analysis cooldowns under thermal pressure prevent repeated full refreshes
    /// from keeping the device pinned hot after the first expensive pass.
    var analysisRefreshInterval: TimeInterval {
        switch currentState {
        case .nominal:
            return 5 * 60
        case .fair:
            return 15 * 60
        case .serious, .critical:
            return 30 * 60
        @unknown default:
            return 15 * 60
        }
    }

    /// Foreground polling should stop once the device is already thermally constrained.
    var shouldRunForegroundRefreshTimers: Bool {
        !shouldThrottle
    }

    func homeRefreshInterval(for requestedInterval: TimeInterval) -> TimeInterval? {
        guard shouldRunForegroundRefreshTimers else { return nil }

        switch currentState {
        case .nominal:
            return max(requestedInterval, 60)
        case .fair:
            return max(requestedInterval, 3 * 60)
        case .serious, .critical:
            return nil
        @unknown default:
            return max(requestedInterval, 3 * 60)
        }
    }

    var liveReadinessRefreshInterval: TimeInterval? {
        guard shouldRunForegroundRefreshTimers else { return nil }

        switch currentState {
        case .nominal:
            return 30 * 60
        case .fair:
            return 60 * 60
        case .serious, .critical:
            return nil
        @unknown default:
            return 60 * 60
        }
    }

    var watchMonitorQueryInterval: TimeInterval {
        switch currentState {
        case .nominal:
            return 10 * 60
        case .fair:
            return 20 * 60
        case .serious:
            return 45 * 60
        case .critical:
            return 60 * 60
        @unknown default:
            return 20 * 60
        }
    }

    var watchNotificationRefreshInterval: TimeInterval {
        switch currentState {
        case .nominal:
            return 10 * 60
        case .fair:
            return 15 * 60
        case .serious:
            return 30 * 60
        case .critical:
            return 60 * 60
        @unknown default:
            return 15 * 60
        }
    }

    // MARK: - Graduated Compute Budget

    /// Fraction of full ML pipeline components that should run (0.0–1.0).
    /// Nominal: all components. Fair: skip exploratory. Serious: essentials only.
    var mlComponentBudget: Double {
        switch currentState {
        case .nominal:  return 1.0
        case .fair:     return 0.7   // skip interaction effects, temporal mining
        case .serious:  return 0.3   // only forecaster + scorer + anomaly
        case .critical: return 0.0
        @unknown default: return 0.7
        }
    }

    /// Whether a specific ML component tier should run at current thermal state.
    /// Tiers: 0 = essential (features, forecaster, scorer), 1 = important (correlations, classifier, anomaly),
    /// 2 = exploratory (interactions, temporal mining, change points, personal optimizer)
    func shouldRunComponent(tier: Int) -> Bool {
        switch currentState {
        case .nominal:
            return true
        case .fair:
            return tier <= 1
        case .serious:
            return tier == 0
        case .critical:
            return false
        @unknown default:
            return tier <= 1
        }
    }

    /// Maximum animation frame rate allowed at current thermal state.
    var maxFrameRate: Double {
        switch currentState {
        case .nominal:  return 30.0
        case .fair:     return 20.0
        case .serious:  return 8.0
        case .critical: return 0.0
        @unknown default: return 20.0
        }
    }

    // MARK: - Init

    private init() {
        self.currentState = ProcessInfo.processInfo.thermalState
        logger.info("Initial thermal state: \(Self.label(for: ProcessInfo.processInfo.thermalState))")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Notification Handler

    @objc private func thermalStateDidChange(_ notification: Notification) {
        let newState = ProcessInfo.processInfo.thermalState
        let oldLabel = Self.label(for: currentState)
        let newLabel = Self.label(for: newState)
        currentState = newState

        if newState == .critical {
            logger.warning("Thermal state CRITICAL (\(oldLabel) → \(newLabel)). pausing heavy work")
        } else if newState == .serious {
            logger.warning("Thermal state SERIOUS (\(oldLabel) → \(newLabel)). throttling heavy work")
        } else {
            logger.info("Thermal state changed: \(oldLabel) → \(newLabel)")
        }
    }

    // MARK: - Helpers

    private static func label(for state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
