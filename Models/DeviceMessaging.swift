import Foundation

/// Device-aware messaging for UI strings that reference the user's wearable.
/// Falls back to "Apple Watch" when no device has been detected yet.
enum DeviceMessaging {

    /// The user's primary wearable device, resolved from the last scan.
    static var primary: SupportedDevice {
        guard let raw = UserDefaults.standard.string(forKey: AppKeys.Data.primaryDevice),
              let device = SupportedDevice(rawValue: raw),
              device != .generic, device != .iPhone else {
            return .appleWatch
        }
        return device
    }

    /// Short device name for inline text: "Apple Watch", "Oura Ring", "Garmin", etc.
    static var deviceName: String { primary.displayName }

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
        Copy.Devices.wearOvernight(deviceName: deviceName, deviceType: deviceType)
    }

    static var wearToTrackMessage: String {
        Copy.Devices.wearToTrack(deviceName: deviceName, deviceType: deviceType)
    }

    static var staleVitalsMessage: String {
        Copy.Devices.staleVitals(wearToTrackMessage: wearToTrackMessage)
    }

    static var wearPromptTitle: String {
        Copy.Devices.wearPromptTitle(deviceName: deviceName, deviceType: deviceType)
    }

    static var ensurePairedMessage: String {
        let companion = primary.companionAppName
        switch primary {
        case .appleWatch:
            return Copy.Devices.ensurePairedAppleWatch()
        case .ouraRing, .ultrahumanRing, .ringConn, .circularRing:
            return Copy.Devices.ensurePairedRing(deviceName: deviceName, companionApp: companion)
        default:
            return Copy.Devices.ensurePairedGeneric(deviceName: deviceName, companionApp: companion)
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
