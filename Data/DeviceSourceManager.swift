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
        guard !isScanning else { return }
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

        // Track detected devices
        for device in connectedDevices {
            AppAnalytics.shared.trackDeviceDetected(
                deviceType: device.device.rawValue,
                metricsCount: device.metricCount,
                isActive: device.isActive
            )
        }
        let activeCount = connectedDevices.filter(\.isActive).count
        let primary = connectedDevices.first?.device.rawValue ?? "none"
        let hasWatch = connectedDevices.contains { $0.device == .appleWatch && $0.isActive }
        UserDefaults.standard.set(primary, forKey: AppKeys.Data.primaryDevice)
        AppAnalytics.shared.updateDeviceProperties(activeCount: activeCount, primaryDevice: primary)
        AppAnalytics.shared.updateHealthSourceProperties(
            hasAppleWatch: hasWatch,
            sourceCount: activeCount,
            primarySource: primary,
            daysSinceFirstSync: SessionTracker.shared.daysSinceInstall
        )
    }

    /// Query sources for a given sample type and return (source, metric, lastSampleDate) tuples
    private func querySources(for sampleType: HKSampleType, metric: HealthMetric) async -> [(HKSource, HealthMetric, Date?)] {
        let healthStore = self.healthStore
        return await withCheckedContinuation { continuation in
            let query = HKSourceQuery(sampleType: sampleType, samplePredicate: nil) { _, sourcesOrNil, error in
                guard let sources = sourcesOrNil, error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                Task { [healthStore, sampleType, metric] in
                    guard !Task.isCancelled else {
                        continuation.resume(returning: [])
                        return
                    }
                    var results: [(HKSource, HealthMetric, Date?)] = []
                    results.reserveCapacity(sources.count)
                    for source in sources {
                        let lastDate = await Self.latestSampleDate(
                            in: healthStore,
                            for: sampleType,
                            source: source
                        )
                        results.append((source, metric, lastDate))
                    }
                    continuation.resume(returning: results)
                }
            }
            healthStore.execute(query)
        }
    }

    /// Fetch the most recent sample date for a specific source + type.
    private static func latestSampleDate(in healthStore: HKHealthStore, for sampleType: HKSampleType, source: HKSource) async -> Date? {
        await withCheckedContinuation { continuation in
            let sourcePredicate = HKQuery.predicateForObjects(from: [source])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: sourcePredicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: samples?.first?.endDate)
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

    /// The primary wearable device (most active, most metrics)
    var primaryDevice: SupportedDevice {
        connectedDevices.first?.device ?? .appleWatch
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
