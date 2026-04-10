import Foundation

extension Copy {
    enum Devices {

        // MARK: - Wear Prompts

        static func wearOvernight(deviceName: String, deviceType: DeviceType) -> String {
            switch deviceType {
            case .ring:
                return "Wear your \(deviceName) to bed to update your readiness score."
            case .sleepTracker:
                return "Sleep on your \(deviceName) to update your readiness score."
            case .watch, .other:
                return "Wear your \(deviceName) overnight to update your readiness score."
            }
        }

        static func wearToTrack(deviceName: String, deviceType: DeviceType) -> String {
            switch deviceType {
            case .ring:
                return "Put on your \(deviceName) to resume tracking."
            case .sleepTracker:
                return "Your \(deviceName) tracks data while you sleep."
            case .watch, .other:
                return "Put on your \(deviceName) to resume live tracking."
            }
        }

        static func staleVitals(wearToTrackMessage: String) -> String {
            "Your vitals are out of date. \(wearToTrackMessage)"
        }

        static func wearPromptTitle(deviceName: String, deviceType: DeviceType) -> String {
            switch deviceType {
            case .ring:
                return "Wear Your Ring"
            case .sleepTracker:
                return "Check Your \(deviceName)"
            case .watch, .other:
                return "Wear Your \(deviceName)"
            }
        }

        // MARK: - Pairing

        static func ensurePairedAppleWatch() -> String {
            "Make sure your Apple Watch is paired and worn. Heart rate and other vitals will appear here automatically."
        }

        static func ensurePairedRing(deviceName: String, companionApp: String) -> String {
            "Make sure your \(deviceName) is connected via \(companionApp). Vitals sync when your ring is nearby."
        }

        static func ensurePairedGeneric(deviceName: String, companionApp: String) -> String {
            "Make sure your \(deviceName) is syncing via \(companionApp). Vitals will appear here after the next sync."
        }

        // MARK: - Notifications

        static func notWornBody(deviceName: String, hours: Int, minutes: Int, wearToTrack: String) -> String {
            "Your \(deviceName) has not recorded data for \(hours)h \(max(0, minutes))m. \(wearToTrack)"
        }

        static func notWornBodyRecent(deviceName: String, wearToTrack: String) -> String {
            "Your \(deviceName) has not recorded data recently. \(wearToTrack)"
        }

        /// Device classification for string selection
        enum DeviceType {
            case ring
            case sleepTracker
            case watch
            case other
        }
    }
}
