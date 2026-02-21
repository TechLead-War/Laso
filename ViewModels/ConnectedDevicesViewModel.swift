import Foundation
import Observation

/// ViewModel for the Connected Devices management screen
@Observable
final class ConnectedDevicesViewModel {
    let deviceSourceManager: DeviceSourceManager
    let healthKitManager: HealthKitManager

    var hasScanned = false

    var connectedDevices: [ConnectedDeviceInfo] {
        deviceSourceManager.connectedDevices
    }

    var activeDevices: [ConnectedDeviceInfo] {
        deviceSourceManager.activeDevices
    }

    var inactiveDevices: [ConnectedDeviceInfo] {
        deviceSourceManager.inactiveDevices
    }

    var unconnectedDevices: [SupportedDevice] {
        deviceSourceManager.unconnectedDevices
    }

    var isScanning: Bool {
        deviceSourceManager.isScanning
    }

    var totalTrackedMetrics: Int {
        deviceSourceManager.totalTrackedMetrics
    }

    var totalPossibleMetrics: Int {
        HealthMetric.allCases.count
    }

    var metricCoverageText: String {
        "\(totalTrackedMetrics)/\(totalPossibleMetrics) metrics tracked"
    }

    var connectedCountText: String {
        let count = connectedDevices.count
        if count == 0 { return "No devices connected" }
        if count == 1 { return "1 device connected" }
        return "\(count) devices connected"
    }

    init(deviceSourceManager: DeviceSourceManager, healthKitManager: HealthKitManager) {
        self.deviceSourceManager = deviceSourceManager
        self.healthKitManager = healthKitManager
    }

    func scan() async {
        await deviceSourceManager.scanSources()
        hasScanned = true
    }
}
