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

    // MARK: - Contextual Messages

    /// "Wear your [device] overnight to update your readiness score."
    static var wearOvernightMessage: String {
        switch primary {
        case .ouraRing, .ultrahumanRing, .ringConn, .circularRing:
            return "Wear your \(deviceName) to bed to update your readiness score."
        case .eightSleep:
            return "Sleep on your \(deviceName) to update your readiness score."
        default:
            return "Wear your \(deviceName) overnight to update your readiness score."
        }
    }

    /// "Wear your [device] to keep tracking" — for stale data prompts
    static var wearToTrackMessage: String {
        switch primary {
        case .ouraRing, .ultrahumanRing, .ringConn, .circularRing:
            return "Put on your \(deviceName) to resume tracking."
        case .eightSleep:
            return "Your \(deviceName) tracks data while you sleep."
        default:
            return "Put on your \(deviceName) to resume live tracking."
        }
    }

    /// "Your vitals are out of date. Put on your [device] to resume live tracking."
    static var staleVitalsMessage: String {
        "Your vitals are out of date. \(wearToTrackMessage)"
    }

    /// Title for stale/wear prompts: "Wear Your [device short]"
    static var wearPromptTitle: String {
        switch primary {
        case .ouraRing, .ultrahumanRing, .ringConn, .circularRing:
            return "Wear Your Ring"
        case .eightSleep:
            return "Check Your Eight Sleep"
        default:
            return "Wear Your \(deviceName)"
        }
    }

    /// "Make sure your [device] is paired and worn."
    static var ensurePairedMessage: String {
        let companion = primary.companionAppName
        switch primary {
        case .appleWatch:
            return "Make sure your Apple Watch is paired and worn. Heart rate and other vitals will appear here automatically."
        case .ouraRing, .ultrahumanRing, .ringConn, .circularRing:
            return "Make sure your \(deviceName) is connected via \(companion). Vitals sync when your ring is nearby."
        default:
            return "Make sure your \(deviceName) is syncing via \(companion). Vitals will appear here after the next sync."
        }
    }

    /// Notification body when device hasn't recorded data
    static func notWornNotificationBody(hours: Int? = nil) -> String {
        if let hours, hours > 0 {
            let minutes = 0
            return "Your \(deviceName) hasn't recorded data for \(hours)h \(minutes)m. \(wearToTrackMessage)"
        }
        return "Your \(deviceName) hasn't recorded data recently. \(wearToTrackMessage)"
    }
}
