import Foundation

/// Device-aware messaging for UI strings that reference the user's wearable.
/// Returns generic copy when no wearable has been detected yet.
enum DeviceMessaging {

    /// The user's primary wearable device, resolved from the last scan.
    static var detectedWearable: SupportedDevice? {
        guard let raw = UserDefaults.standard.string(forKey: AppKeys.Data.primaryDevice),
              let device = SupportedDevice(rawValue: raw),
              device != .generic, device != .iPhone else {
            return nil
        }
        return device
    }

    static var primary: SupportedDevice {
        detectedWearable ?? .appleWatch
    }

    static var hasDetectedWearable: Bool {
        detectedWearable != nil
    }

    /// Short device name for inline text: "Apple Watch", "Oura Ring", "Garmin", etc.
    static var deviceName: String { primary.displayName }

    static var optionalDeviceName: String? { detectedWearable?.displayName }

    /// Icon name appropriate for the device (SF Symbols)
    static var deviceIcon: String { primary.systemImageName }

    // MARK: - Device Type Classification

    private static var deviceType: Copy.Devices.DeviceType {
        switch primary {
        case .ouraRing, .ultrahumanRing, .ringConn, .circularRing:
            return .ring
        case .eightSleep:
            return .sleepTracker
        case .appleWatch:
            return .watch
        default:
            return .other
        }
    }

    // MARK: - Contextual Messages

    static var wearOvernightMessage: String {
        guard let detectedWearable else {
            return "Overnight HRV and resting heart rate build faster when a wearable syncs into Apple Health regularly."
        }
        return Copy.Devices.wearOvernight(deviceName: detectedWearable.displayName, deviceType: deviceType)
    }

    static var wearToTrackMessage: String {
        guard let detectedWearable else {
            return "Connect a wearable source to resume live tracking."
        }
        return Copy.Devices.wearToTrack(deviceName: detectedWearable.displayName, deviceType: deviceType)
    }

    static var staleVitalsMessage: String {
        Copy.Devices.staleVitals(wearToTrackMessage: wearToTrackMessage)
    }

    static var wearPromptTitle: String {
        guard let detectedWearable else {
            return "Connect a Wearable"
        }
        return Copy.Devices.wearPromptTitle(deviceName: detectedWearable.displayName, deviceType: deviceType)
    }

    static var ensurePairedMessage: String {
        guard let detectedWearable else {
            return "Connect a compatible wearable or companion app to Apple Health. Vitals will appear here after the next sync."
        }
        let companion = detectedWearable.companionAppName
        switch detectedWearable {
        case .appleWatch:
            return Copy.Devices.ensurePairedAppleWatch()
        case .ouraRing, .ultrahumanRing, .ringConn, .circularRing:
            return Copy.Devices.ensurePairedRing(deviceName: detectedWearable.displayName, companionApp: companion)
        default:
            return Copy.Devices.ensurePairedGeneric(deviceName: detectedWearable.displayName, companionApp: companion)
        }
    }

    static func notWornNotificationBody(hours: Int? = nil, totalMinutes: Int? = nil) -> String {
        if let hours, hours > 0 {
            let minutes = (totalMinutes ?? 0) - (hours * 60)
            return Copy.Devices.notWornBody(deviceName: deviceName, hours: hours, minutes: minutes, wearToTrack: wearToTrackMessage)
        }
        return Copy.Devices.notWornBodyRecent(deviceName: deviceName, wearToTrack: wearToTrackMessage)
    }
}
