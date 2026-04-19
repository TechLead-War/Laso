import Foundation
import HealthKit
import Observation

/// Codable wrapper for caching ConnectedDeviceInfo to UserDefaults
private struct CachedDeviceEntry: Codable {
    let deviceRawValue: String
    let sourceName: String
    let sourceBundleId: String
    let metricRawValues: [String]
    let lastDataDate: Date?
    let deviceModelName: String?

    init(from info: ConnectedDeviceInfo) {
        self.deviceRawValue = info.device.rawValue
        self.sourceName = info.sourceName
        self.sourceBundleId = info.sourceBundleId
        self.metricRawValues = info.metricsProvided.map(\.rawValue)
        self.lastDataDate = info.lastDataDate
        self.deviceModelName = info.deviceModelName
    }

    func toConnectedDeviceInfo() -> ConnectedDeviceInfo? {
        guard let device = SupportedDevice(rawValue: deviceRawValue) else { return nil }
        let metrics = Set(metricRawValues.compactMap { HealthMetric(rawValue: $0) })
        return ConnectedDeviceInfo(
            device: device,
            sourceName: sourceName,
            sourceBundleId: sourceBundleId,
            metricsProvided: metrics,
            lastDataDate: lastDataDate,
            deviceModelName: deviceModelName
        )
    }
}

/// Detects which devices/apps are writing health data to HealthKit via HKSourceQuery
@Observable
final class DeviceSourceManager {
    private struct ScanTarget {
        let sampleType: HKSampleType
        let metrics: Set<HealthMetric>
    }

    let healthStore: HKHealthStore

    var connectedDevices: [ConnectedDeviceInfo] = []
    var isScanning = false

    private var hasScanned = false
    private var lastScanDate: Date?
    private static let scanTTL: TimeInterval = 24 * 3600
    /// Bump this to invalidate stale device caches on app update
    private static let cacheVersion = 3

    /// Build source queries from the HealthKit registry instead of a hand-maintained
    /// shortlist so newly supported device categories can surface without code changes.
    /// Nutrition and mindfulness are excluded to avoid turning general logging apps
    /// into "devices" on this screen.
    private static var sourceDiscoveryTargets: [ScanTarget] {
        var groupedMetrics: [String: (sampleType: HKSampleType, metrics: Set<HealthMetric>)] = [:]

        for metric in HealthMetric.allCases
        where metric.category != .nutrition && metric.category != .mindfulness {
            let config = HealthKitMetricRegistry.config(for: metric)
            guard let sampleType = config.sampleType else { continue }

            let key = sampleType.identifier
            var entry = groupedMetrics[key] ?? (sampleType: sampleType, metrics: [])
            entry.metrics.insert(metric)
            groupedMetrics[key] = entry
        }

        return groupedMetrics.keys.sorted().compactMap { key in
            guard let entry = groupedMetrics[key] else { return nil }
            return ScanTarget(sampleType: entry.sampleType, metrics: entry.metrics)
        }
    }

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
        loadCachedDevices()
    }

    /// Scan representative HealthKit sample types for contributing sources.
    /// Results are cached to UserDefaults with a 24-hour TTL.
    func scanSources() async {
        // Early return if scanned recently (within TTL)
        if hasScanned, let lastScan = lastScanDate,
           Date().timeIntervalSince(lastScan) < Self.scanTTL {
            return
        }

        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        // Snapshot previously active devices for disconnect detection
        let previouslyActive = Set(connectedDevices.filter(\.isActive).map(Self.activityKey(for:)))

        var sourceMap: [String: (source: HKSource, metrics: Set<HealthMetric>, lastDate: Date?, deviceName: String?)] = [:]

        await withTaskGroup(of: [(HKSource, Set<HealthMetric>, Date?, String?)].self) { group in
            for target in Self.sourceDiscoveryTargets {
                group.addTask { [self] in
                    await self.querySources(for: target.sampleType, metrics: target.metrics)
                }
            }

            for await results in group {
                for (source, metrics, lastDate, deviceName) in results {
                    let key = source.bundleIdentifier
                    var entry = sourceMap[key] ?? (source: source, metrics: [], lastDate: nil, deviceName: nil)
                    entry.metrics.formUnion(metrics)
                    if let lastDate, entry.lastDate == nil || lastDate > entry.lastDate! {
                        entry.lastDate = lastDate
                    }
                    if entry.deviceName == nil, let deviceName {
                        entry.deviceName = deviceName
                    }
                    sourceMap[key] = entry
                }
            }
        }

        // Convert to ConnectedDeviceInfo, keeping known brands grouped while
        // allowing unknown Apple Health sources to appear independently.
        var deviceMap: [String: ConnectedDeviceInfo] = [:]

        for (bundleId, entry) in sourceMap {
            let device = identifyDevice(bundleId: bundleId, metricsProvided: entry.metrics)
            let key = Self.groupingKey(bundleId: bundleId, device: device)
            if var existing = deviceMap[key] {
                existing.metricsProvided.formUnion(entry.metrics)
                if let newDate = entry.lastDate,
                   existing.lastDataDate == nil || newDate > existing.lastDataDate! {
                    existing.lastDataDate = newDate
                }
                if existing.deviceModelName == nil, let name = entry.deviceName {
                    existing.deviceModelName = name
                }
                deviceMap[key] = existing
            } else {
                deviceMap[key] = ConnectedDeviceInfo(
                    device: device,
                    sourceName: entry.source.name,
                    sourceBundleId: bundleId,
                    metricsProvided: entry.metrics,
                    lastDataDate: entry.lastDate,
                    deviceModelName: entry.deviceName
                )
            }
        }

        connectedDevices = Array(deviceMap.values).sorted { a, b in
            if a.isActive != b.isActive { return a.isActive }
            return a.metricCount > b.metricCount
        }

        // Mark scan as complete and cache results
        hasScanned = true
        lastScanDate = Date()
        cacheDevicesToDefaults()

        // Track detected devices
        let activeCount = connectedDevices.filter(\.isActive).count
        let primary = connectedDevices.first?.device.rawValue ?? "none"
        let hasWatch = connectedDevices.contains { $0.device == .appleWatch && $0.isActive }
        let watchModel = connectedDevices.first(where: { $0.device == .appleWatch })?.deviceModelName
        let primaryWearableModel = connectedDevices.first(where: { $0.device != .iPhone })?.deviceModelName
        UserDefaults.standard.set(primary, forKey: AppKeys.Data.primaryDevice)
        let devices = connectedDevices
        await MainActor.run {
            for device in devices {
                AppAnalytics.shared.trackDeviceDetected(
                    deviceType: device.device.rawValue,
                    metricsCount: device.metricCount,
                    isActive: device.isActive,
                    modelName: device.deviceModelName
                )
                if device.isActive {
                    AppAnalytics.shared.trackSourceConnected(
                        sourceType: device.device.rawValue,
                        metricsAvailable: device.metricCount
                    )
                }
            }
            AppAnalytics.shared.updateDeviceProperties(activeCount: activeCount, primaryDevice: primary)
            AppAnalytics.shared.updateHealthSourceProperties(
                hasAppleWatch: hasWatch,
                sourceCount: activeCount,
                primarySource: primary,
                daysSinceFirstSync: SessionTracker.shared.daysSinceInstall,
                watchModel: watchModel,
                wearableModel: primaryWearableModel
            )

            // Detect devices that were active but are now inactive
            let currentlyActive = Set(devices.filter(\.isActive).map(Self.activityKey(for:)))
            let disconnected = previouslyActive.subtracting(currentlyActive)
            for activityKey in disconnected {
                let info = devices.first { Self.activityKey(for: $0) == activityKey }
                let daysSince: Int
                if let lastDate = info?.lastDataDate {
                    daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                } else {
                    daysSince = 0
                }
                AppAnalytics.shared.trackDeviceDisconnected(
                    deviceType: info?.device.rawValue ?? SupportedDevice.generic.rawValue,
                    daysSinceLastData: daysSince,
                    modelName: info?.deviceModelName
                )
            }
        }
    }

    /// Query sources for a given sample type and return (source, metrics, lastSampleDate, deviceName) tuples
    private func querySources(for sampleType: HKSampleType, metrics: Set<HealthMetric>) async -> [(HKSource, Set<HealthMetric>, Date?, String?)] {
        let healthStore = self.healthStore
        return await withCheckedContinuation { continuation in
            let query = HKSourceQuery(sampleType: sampleType, samplePredicate: nil) { _, sourcesOrNil, error in
                guard let sources = sourcesOrNil, error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                Task { [healthStore, sampleType, metrics] in
                    guard !Task.isCancelled else {
                        continuation.resume(returning: [])
                        return
                    }
                    var results: [(HKSource, Set<HealthMetric>, Date?, String?)] = []
                    results.reserveCapacity(sources.count)
                    for source in sources {
                        let info = await Self.latestSampleInfo(
                            in: healthStore,
                            for: sampleType,
                            source: source
                        )
                        results.append((source, metrics, info.date, info.deviceName))
                    }
                    continuation.resume(returning: results)
                }
            }
            healthStore.execute(query)
        }
    }

    /// Fetch the most recent sample date and HKDevice for a specific source + type.
    private static func latestSampleInfo(in healthStore: HKHealthStore, for sampleType: HKSampleType, source: HKSource) async -> (date: Date?, deviceName: String?) {
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
                    continuation.resume(returning: (nil, nil))
                    return
                }
                let sample = samples?.first
                let deviceName = sample?.device?.name ?? sample?.device?.model
                continuation.resume(returning: (sample?.endDate, deviceName))
            }
            healthStore.execute(query)
        }
    }

    /// Match a bundle identifier to a known device.
    /// For Apple Health sources, uses discovered metrics to distinguish iPhone from Apple Watch.
    private func identifyDevice(bundleId: String, metricsProvided: Set<HealthMetric> = []) -> SupportedDevice {
        // Apple ecosystem: disambiguate iPhone vs Watch using metrics
        let isAppleSource = bundleId.hasPrefix("com.apple.health")
            || bundleId.hasPrefix("com.apple.Health")
            || bundleId.hasPrefix("com.apple.watch")
        if isAppleSource {
            // Metrics that require a wearable sensor. iPhone alone cannot produce these
            let watchOnlyMetrics: Set<HealthMetric> = [.heartRate, .bloodOxygen, .sleepDuration]
            if bundleId.hasPrefix("com.apple.watch") || !metricsProvided.isDisjoint(with: watchOnlyMetrics) {
                return .appleWatch
            }
            return .iPhone
        }

        for device in SupportedDevice.allCases where device != .generic && device != .appleWatch && device != .iPhone {
            for prefix in device.companionAppBundlePrefixes {
                if bundleId.hasPrefix(prefix) {
                    return device
                }
            }
        }
        return .generic
    }

    private static func groupingKey(bundleId: String, device: SupportedDevice) -> String {
        device == .generic ? "generic:\(bundleId)" : device.rawValue
    }

    private static func activityKey(for info: ConnectedDeviceInfo) -> String {
        groupingKey(bundleId: info.sourceBundleId, device: info.device)
    }

    // MARK: - UserDefaults Cache

    /// Save current connectedDevices to UserDefaults as JSON
    private func cacheDevicesToDefaults() {
        let entries = connectedDevices.map { CachedDeviceEntry(from: $0) }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: AppKeys.Data.cachedDeviceSources)
        }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppKeys.Data.deviceSourceScanDate)
        UserDefaults.standard.set(Self.cacheVersion, forKey: "deviceSourceCacheVersion")
    }

    /// Load cached devices from UserDefaults (called on init for instant availability)
    private func loadCachedDevices() {
        // Invalidate stale cache when version changes (e.g. device detection logic updated)
        let storedVersion = UserDefaults.standard.integer(forKey: "deviceSourceCacheVersion")
        if storedVersion != Self.cacheVersion {
            UserDefaults.standard.removeObject(forKey: AppKeys.Data.cachedDeviceSources)
            UserDefaults.standard.removeObject(forKey: AppKeys.Data.deviceSourceScanDate)
            return
        }

        // Restore last scan date
        let storedTimestamp = UserDefaults.standard.double(forKey: AppKeys.Data.deviceSourceScanDate)
        if storedTimestamp > 0 {
            lastScanDate = Date(timeIntervalSince1970: storedTimestamp)
        }

        // Restore cached devices
        guard let data = UserDefaults.standard.data(forKey: AppKeys.Data.cachedDeviceSources),
              let entries = try? JSONDecoder().decode([CachedDeviceEntry].self, from: data) else {
            return
        }

        let restored = entries.compactMap { $0.toConnectedDeviceInfo() }
        if !restored.isEmpty {
            connectedDevices = restored
            hasScanned = true
        }
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

    /// True when an Apple Watch has delivered HealthKit data within the last 7 days.
    /// Used by analytics to segment retention cohorts by Watch-pair status — the
    /// single most predictive dimension for health-app engagement per Oura/WHOOP.
    var isAppleWatchPaired: Bool {
        connectedDevices.contains { $0.device == .appleWatch && $0.isActive }
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
