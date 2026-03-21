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
