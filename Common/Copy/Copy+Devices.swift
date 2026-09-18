import Foundation

extension Copy {
    enum Devices {

        // MARK: - Wear Prompts

        static func wearToTrack(deviceName: String, deviceType: DeviceType) -> String {
            let template: String
            switch deviceType {
            case .ring:
                template = RemoteConfigManager.shared.copyString("copy_devices_wear_to_track_ring", default: "Put on your %@ to resume tracking.")
            case .sleepTracker:
                template = RemoteConfigManager.shared.copyString("copy_devices_wear_to_track_sleep_tracker", default: "Your %@ tracks data while you sleep.")
            case .watch, .other:
                template = RemoteConfigManager.shared.copyString("copy_devices_wear_to_track_watch", default: "Put on your %@ to resume live tracking.")
            }
            return String(format: template, deviceName)
        }

        static func wearPromptTitle(deviceName: String, deviceType: DeviceType) -> String {
            switch deviceType {
            case .ring:
                return RemoteConfigManager.shared.copyString("copy_devices_wear_prompt_title_ring", default: "Wear Your Ring")
            case .sleepTracker:
                return String(format: RemoteConfigManager.shared.copyString("copy_devices_wear_prompt_title_sleep_tracker", default: "Check Your %@"), deviceName)
            case .watch, .other:
                return String(format: RemoteConfigManager.shared.copyString("copy_devices_wear_prompt_title_watch", default: "Wear Your %@"), deviceName)
            }
        }

        /// Device classification for string selection
        enum DeviceType {
            case ring
            case sleepTracker
            case watch
            case other
        }

        // MARK: - Lifted view literals
        static var setupGuide: String { RemoteConfigManager.shared.copyString("copy_devices_setup_guide", default: "Setup Guide") }
        static var metrics: String { RemoteConfigManager.shared.copyString("copy_devices_metrics", default: "Metrics") }
        static var sourceApp: String { RemoteConfigManager.shared.copyString("copy_devices_source_app", default: "Source App") }
        static var lastSync: String { RemoteConfigManager.shared.copyString("copy_devices_last_sync", default: "Last Sync") }
        static var syncPath: String { RemoteConfigManager.shared.copyString("copy_devices_sync_path", default: "Sync Path") }
        static var importedMetrics: String { RemoteConfigManager.shared.copyString("copy_devices_imported_metrics", default: "Imported Metrics") }
        static var dataSource: String { RemoteConfigManager.shared.copyString("copy_devices_data_source", default: "Data Source") }
        static var howThisSourceConnects: String { RemoteConfigManager.shared.copyString("copy_devices_how_this_source_connects", default: "How This Source Connects") }
        static var whatLasoConfirmsAfterSync: String { RemoteConfigManager.shared.copyString("copy_devices_what_laso_confirms_after_sync", default: "What Laso Confirms After Sync") }
        static var openAppStoreLabel: String { RemoteConfigManager.shared.copyString("copy_devices_open_app_store_label", default: "Open App Store") }
        static var scanningForDevicesLabel: String { RemoteConfigManager.shared.copyString("copy_devices_scanning_for_devices_label", default: "Scanning for devices") }
        static var connectedButInactive: String { RemoteConfigManager.shared.copyString("copy_devices_connected_but_inactive", default: "Connected But Inactive") }
        static var theseSourcesWereDetectedBeforeBut: String { RemoteConfigManager.shared.copyString("copy_devices_these_sources_were_detected_before_but", default: "These sources were detected before, but they haven't written data to Apple Health in the last 7 days.") }
        static var connectedDevicesNavTitle: String { RemoteConfigManager.shared.copyString("copy_devices_connected_devices_nav_title", default: "Connected Devices") }
        static var detected: String { RemoteConfigManager.shared.copyString("copy_devices_detected", default: "Detected") }

        // MARK: - Lifted interpolated view literals
        static func xText(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_devices_x_text", default: "%d"), p0) }
        static func appText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_devices_app_text", default: "App: %@"), p0) }
        static func bundleText(_ p0: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_devices_bundle_text", default: "Bundle: %@"), p0) }
        static func metricsAndLastSyncText(_ p0: Int, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_devices_metrics_last_sync_text", default: "%d metrics · Last sync %@"), p0, p1) }

        // MARK: - Watch Complication

        /// Steps for putting the readiness complication on the watch face. Shown on
        /// Home once, and kept permanently on the Apple Watch device screen.
        enum WatchComplication {
            static var title: String { RemoteConfigManager.shared.copyString("copy_devices_watch_complication_title", default: "Put your score on your watch face") }
            static var subtitle: String { RemoteConfigManager.shared.copyString("copy_devices_watch_complication_subtitle", default: "See your readiness by raising your wrist, without opening the app.") }
            static var stepOne: String { RemoteConfigManager.shared.copyString("copy_devices_watch_complication_step_one", default: "Press and hold your watch face") }
            static var stepTwo: String { RemoteConfigManager.shared.copyString("copy_devices_watch_complication_step_two", default: "Tap Edit, then swipe to Complications") }
            static var stepThree: String { RemoteConfigManager.shared.copyString("copy_devices_watch_complication_step_three", default: "Tap a slot and choose Laso") }
            static var dismissLabel: String { RemoteConfigManager.shared.copyString("copy_devices_watch_complication_dismiss_label", default: "Hide this tip") }
            static var added: String { RemoteConfigManager.shared.copyString("copy_devices_watch_complication_added", default: "Laso is on your watch face.") }
        }

    }
}
