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

    /// Short device name for inline text: "Apple Watch", "Oura Ring", "Garmin", etc.
    static var deviceName: String { primary.displayName }

    static var optionalDeviceName: String? { detectedWearable?.displayName }

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

    static var wearToTrackMessage: String {
        guard let detectedWearable else {
            return "Connect a wearable source to resume live tracking."
        }
        return Copy.Devices.wearToTrack(deviceName: detectedWearable.displayName, deviceType: deviceType)
    }

    static var wearPromptTitle: String {
        guard let detectedWearable else {
            return "Connect a Wearable"
        }
        return Copy.Devices.wearPromptTitle(deviceName: detectedWearable.displayName, deviceType: deviceType)
    }
}
