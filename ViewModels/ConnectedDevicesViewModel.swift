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

    var primaryDeviceInfo: ConnectedDeviceInfo? {
        activeDevices.first ?? connectedDevices.first
    }

    var primaryDevice: SupportedDevice? {
        primaryDeviceInfo?.device
    }

    var statusSymbolName: String {
        primaryDevice?.systemImageName ?? (healthKitManager.isAuthorized ? "heart.text.square.fill" : "heart.fill")
    }

    var metricCoverageText: String {
        "\(totalTrackedMetrics)/\(totalPossibleMetrics) metrics tracked"
    }

    var connectedCountText: String {
        let count = connectedDevices.count
        if count == 0 {
            return healthKitManager.isAuthorized ? "Health source ready" : "Connect a health source"
        }
        if count == 1 { return "1 source connected" }
        return "\(count) sources connected"
    }

    var statusHeadline: String {
        if let info = primaryDeviceInfo {
            return info.isActive ? "\(info.device.displayName) is active" : "\(info.device.displayName) is connected"
        }
        if isScanning {
            return "Checking connected sources"
        }
        return healthKitManager.isAuthorized ? "Apple Health is connected" : "Connect Apple Health"
    }

    var statusDetail: String {
        if let info = primaryDeviceInfo {
            return "\(info.metricCount) metrics are arriving through \(info.sourceName)."
        }
        if isScanning {
            return "Scanning Apple Health for devices and companion apps that are already syncing."
        }
        if healthKitManager.isAuthorized {
            return "We'll list each wearable, app, and accessory here as soon as it writes its first samples into Apple Health."
        }
        return "Enable Health access to start importing data from iPhone, Apple Watch, and partner apps."
    }

    var activitySummaryText: String {
        let activeCount = activeDevices.count
        if activeCount == 0 {
            return connectedDevices.isEmpty ? "Waiting for first sync" : "No recent syncs"
        }
        if activeCount == 1 { return "1 active source" }
        return "\(activeCount) active sources"
    }

    var primarySourceSummaryText: String {
        if let info = primaryDeviceInfo {
            return info.sourceName
        }
        return healthKitManager.isAuthorized ? "Apple Health" : "Not connected"
    }

    var lastSyncSummaryText: String {
        primaryDeviceInfo?.lastSyncText ?? "Pending first sync"
    }

    var availableSourcesTitle: String {
        connectedDevices.isEmpty ? "Available Sources" : "Compatible Sources"
    }

    var availableSourcesFooter: String {
        connectedDevices.isEmpty
            ? "Supported wearables, medical devices, and companion apps appear here after they write their first samples to Apple Health."
            : "Add more sources through their companion apps to expand the metrics Laso can import."
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
