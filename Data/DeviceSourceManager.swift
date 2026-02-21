import Foundation
import HealthKit
import Observation

/// Detects which devices/apps are writing health data to HealthKit via HKSourceQuery
@Observable
final class DeviceSourceManager {
    let healthStore: HKHealthStore

    var connectedDevices: [ConnectedDeviceInfo] = []
    var isScanning = false

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    /// Scan all HealthKit sample types for contributing sources
    func scanSources() async {
        isScanning = true
        defer { isScanning = false }

        var sourceMap: [String: (source: HKSource, metrics: Set<HealthMetric>, lastDate: Date?)] = [:]

        await withTaskGroup(of: [(HKSource, HealthMetric, Date?)].self) { group in
            for metric in HealthMetric.allCases {
                let config = HealthKitMetricRegistry.config(for: metric)
                guard let sampleType = config.sampleType else { continue }

                group.addTask { [self] in
                    await self.querySources(for: sampleType, metric: metric)
                }
            }

            for await results in group {
                for (source, metric, lastDate) in results {
                    let key = source.bundleIdentifier
                    var entry = sourceMap[key] ?? (source: source, metrics: [], lastDate: nil)
                    entry.metrics.insert(metric)
                    if let lastDate, entry.lastDate == nil || lastDate > entry.lastDate! {
                        entry.lastDate = lastDate
                    }
                    sourceMap[key] = entry
                }
            }
        }

        // Convert to ConnectedDeviceInfo, deduplicating by SupportedDevice
        var deviceMap: [SupportedDevice: ConnectedDeviceInfo] = [:]

        for (bundleId, entry) in sourceMap {
            let device = identifyDevice(bundleId: bundleId)
            if var existing = deviceMap[device] {
                existing.metricsProvided.formUnion(entry.metrics)
                if let newDate = entry.lastDate,
                   existing.lastDataDate == nil || newDate > existing.lastDataDate! {
                    existing.lastDataDate = newDate
                }
                deviceMap[device] = existing
            } else {
                deviceMap[device] = ConnectedDeviceInfo(
                    device: device,
                    sourceName: entry.source.name,
                    sourceBundleId: bundleId,
                    metricsProvided: entry.metrics,
                    lastDataDate: entry.lastDate
                )
            }
        }

        connectedDevices = Array(deviceMap.values).sorted { a, b in
            if a.isActive != b.isActive { return a.isActive }
            return a.metricCount > b.metricCount
        }
    }

    /// Query sources for a given sample type and return (source, metric, lastSampleDate) tuples
    private func querySources(for sampleType: HKSampleType, metric: HealthMetric) async -> [(HKSource, HealthMetric, Date?)] {
        await withCheckedContinuation { continuation in
            let query = HKSourceQuery(sampleType: sampleType, samplePredicate: nil) { _, sourcesOrNil, error in
                guard let sources = sourcesOrNil, error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                let results = sources.map { source in
                    (source, metric, nil as Date?)
                }
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
    }

    /// Match a bundle identifier to a known device
    private func identifyDevice(bundleId: String) -> SupportedDevice {
        for device in SupportedDevice.allCases where device != .generic {
            for prefix in device.companionAppBundlePrefixes {
                if bundleId.hasPrefix(prefix) {
                    return device
                }
            }
        }
        return .generic
    }

    /// Devices that are not yet detected as connected
    var unconnectedDevices: [SupportedDevice] {
        let connectedTypes = Set(connectedDevices.map(\.device))
        return SupportedDevice.discoverableDevices.filter { !connectedTypes.contains($0) }
    }

    /// Active devices (data within last 7 days)
    var activeDevices: [ConnectedDeviceInfo] {
        connectedDevices.filter(\.isActive)
    }

    /// Inactive devices (detected but stale data)
    var inactiveDevices: [ConnectedDeviceInfo] {
        connectedDevices.filter { !$0.isActive }
    }

    /// Total unique metrics being tracked across all devices
    var totalTrackedMetrics: Int {
        var allMetrics = Set<HealthMetric>()
        for device in connectedDevices {
            allMetrics.formUnion(device.metricsProvided)
        }
        return allMetrics.count
    }

    /// Find which device provides data for a given metric
    func sourceDevice(for metric: HealthMetric) -> ConnectedDeviceInfo? {
        connectedDevices.first { $0.metricsProvided.contains(metric) }
    }
}
