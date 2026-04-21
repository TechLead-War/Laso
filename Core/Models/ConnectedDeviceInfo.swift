import Foundation

/// Runtime model for a device detected via HKSourceQuery
struct ConnectedDeviceInfo: Identifiable {
    let id = UUID()
    let device: SupportedDevice
    let sourceName: String
    let sourceBundleId: String
    var metricsProvided: Set<HealthMetric>
    var lastDataDate: Date?
    /// Specific device model name from HKDevice (e.g. "Apple Watch Series 10", "Garmin Fenix 8")
    var deviceModelName: String?

    /// Device is considered active if it contributed data within the last 7 days
    var isActive: Bool {
        guard let lastDate = lastDataDate else { return false }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 999 <= 7
    }

    var metricCount: Int {
        metricsProvided.count
    }

    /// Prefer the concrete model or source name for dynamically discovered sources.
    var presentationName: String {
        if device != .generic {
            return device.displayName
        }

        if let deviceModelName {
            let trimmed = deviceModelName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let source = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty {
            return source
        }

        return device.displayName
    }

    var sourceDisplayName: String {
        let source = sourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty {
            return source
        }
        return device == .generic ? "Apple Health Source" : device.companionAppName
    }

    var lastSyncText: String {
        guard let lastDate = lastDataDate else { return "No data" }
        let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }
}
