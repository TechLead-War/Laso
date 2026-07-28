import Foundation

extension Copy {
    enum Settings {

        // MARK: - Navigation

        static var settings: String { RemoteConfigManager.shared.copyString("copy_settings_settings_settings", default: "Settings") }

        // MARK: - Section Headers

        static var dailySummary: String { RemoteConfigManager.shared.copyString("copy_settings_settings_daily_summary", default: "Daily Summary") }
        static var weeklySummary: String { RemoteConfigManager.shared.copyString("copy_settings_settings_weekly_summary", default: "Weekly Summary") }
        static var heartRateAlerts: String { RemoteConfigManager.shared.copyString("copy_settings_settings_heart_rate_alerts", default: "Heart Rate Alerts") }
        static var appleWatch: String { RemoteConfigManager.shared.copyString("copy_settings_settings_apple_watch", default: "Apple Watch") }
        static var onDeviceData: String { RemoteConfigManager.shared.copyString("copy_settings_settings_on_device_data", default: "On Device Data") }
        static var siriAndShortcuts: String { RemoteConfigManager.shared.copyString("copy_settings_settings_siri_and_shortcuts", default: "Siri & Shortcuts") }
        static var about: String { RemoteConfigManager.shared.copyString("copy_settings_settings_about", default: "About") }
        static var alertMetrics: String { RemoteConfigManager.shared.copyString("copy_settings_settings_alert_metrics", default: "Alert Metrics") }
        static var notifications: String { RemoteConfigManager.shared.copyString("copy_settings_settings_notifications", default: "Notifications") }

        // MARK: - Simplified Section Headers

        static var yourData: String { RemoteConfigManager.shared.copyString("copy_settings_settings_your_data", default: "Your Data") }
        static var support: String { RemoteConfigManager.shared.copyString("copy_settings_settings_support", default: "Support") }
        static var summaries: String { RemoteConfigManager.shared.copyString("copy_settings_settings_summaries", default: "Summaries") }
        static var healthAlerts: String { RemoteConfigManager.shared.copyString("copy_settings_settings_health_alerts", default: "Health Alerts") }
        static var customizeThresholds: String { RemoteConfigManager.shared.copyString("copy_settings_settings_customize_thresholds", default: "Customize Thresholds") }
        static var whichMetrics: String { RemoteConfigManager.shared.copyString("copy_settings_settings_which_metrics", default: "Choose Metrics") }
        static var notificationsHint: String { RemoteConfigManager.shared.copyString("copy_settings_settings_notifications_hint", default: "All alerts are optional. You choose what reaches you.") }
        static var dailySummaryDescription: String { RemoteConfigManager.shared.copyString("copy_settings_settings_daily_summary_description", default: "A short morning briefing with your score and key numbers.") }
        static var waitingForData: String { RemoteConfigManager.shared.copyString("copy_settings_settings_waiting_for_data", default: "Waiting for Health Data") }
        static var waitingForDataHint: String { RemoteConfigManager.shared.copyString("copy_settings_settings_waiting_for_data_hint", default: "Make sure your watch or health app is sharing with Apple Health.") }

        // MARK: - Siri Detail

        static var siriDetailDescription: String { RemoteConfigManager.shared.copyString("copy_settings_settings_siri_detail_description", default: "Add Laso shortcuts to Siri so you can check your health score, view your sleep summary, or open today's dashboard hands free.") }

        // MARK: - Danger Zone

        static var dangerZone: String { RemoteConfigManager.shared.copyString("copy_settings_settings_danger_zone", default: "Danger Zone") }

        // MARK: - Notifications Detail

        static var maxNotificationsLabel: String { RemoteConfigManager.shared.copyString("copy_settings_settings_max_notifications_label", default: "Maximum notifications per day") }

        // MARK: - Acknowledgements

        static func libraryLicense(name: String, license: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_settings_settings_library_license", default: "%@, %@"), name, license)
        }
        static var syncingData: String { RemoteConfigManager.shared.copyString("copy_settings_syncing_data", default: "Syncing Your Data") }
        static var refreshNow: String { RemoteConfigManager.shared.copyString("copy_settings_refresh_now", default: "Refresh Now") }

        // MARK: - Profile Header

        static var proMember: String { RemoteConfigManager.shared.copyString("copy_settings_pro_member", default: "Pro Member") }
        static var freePlan: String { RemoteConfigManager.shared.copyString("copy_settings_free_plan", default: "Free Plan") }

        static func freeUntil(_ date: Date) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_settings_free_until", default: "Free until %@"),
                   date.formatted(.dateTime.day().month(.abbreviated).year()))
        }
        static func renews(_ date: Date) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_settings_renews", default: "Renews %@"),
                   date.formatted(.dateTime.day().month(.abbreviated).year()))
        }

        // MARK: - Subscription Management

        static var manageSubscription: String { RemoteConfigManager.shared.copyString("copy_settings_manage_subscription", default: "Manage Subscription") }
        static var manageSubscriptionSubtitle: String { RemoteConfigManager.shared.copyString("copy_settings_manage_subscription_subtitle", default: "Pause or cancel anytime") }

        // MARK: - Device Management

        static var manageDevices: String { RemoteConfigManager.shared.copyString("copy_settings_manage_devices", default: "Manage Devices") }
        static var setUpADevice: String { RemoteConfigManager.shared.copyString("copy_settings_set_up_a_device", default: "Set up a device") }
        static func connectedCount(_ count: Int) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_settings_connected_count", default: "%d connected"), count)
        }

        // MARK: - Notifications

        static var summaryTime: String { RemoteConfigManager.shared.copyString("copy_settings_summary_time", default: "Summary Time") }

        // MARK: - Heart Rate

        static var heartRateSpikeAlerts: String { RemoteConfigManager.shared.copyString("copy_settings_heart_rate_spike_alerts", default: "Heart Rate Spike Alerts") }
        static var highHRThreshold: String { RemoteConfigManager.shared.copyString("copy_settings_high_hr_threshold", default: "High HR Threshold") }
        static var lowHRThreshold: String { RemoteConfigManager.shared.copyString("copy_settings_low_hr_threshold", default: "Low HR Threshold") }
        static func bpmValue(_ bpm: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_settings_bpm_value", default: "%d bpm"), bpm) }
        static var heartRateAlertsFooter: String { RemoteConfigManager.shared.copyString("copy_settings_heart_rate_alerts_footer", default: "Get notified when your heart rate goes too high or too low while you are not working out.") }

        // MARK: - Apple Watch Reminders

        static var watchNotWornReminder: String { RemoteConfigManager.shared.copyString("copy_settings_watch_not_worn_reminder", default: "Watch Not Worn Reminder") }
        static var watchNotWornDescription: String { RemoteConfigManager.shared.copyString("copy_settings_watch_not_worn_description", default: "Get notified if your Apple Watch has not recorded data for over an hour.") }
        static var watchRemindersFooter: String { RemoteConfigManager.shared.copyString("copy_settings_watch_reminders_footer", default: "These reminders help you keep your watch on and charged so you do not miss any health data.") }

        // MARK: - Alerts

        static var criticalAlerts: String { RemoteConfigManager.shared.copyString("copy_settings_critical_alerts", default: "Critical Alerts") }
        static var warningAlerts: String { RemoteConfigManager.shared.copyString("copy_settings_warning_alerts", default: "Warning Alerts") }
        static var trendReversalAlerts: String { RemoteConfigManager.shared.copyString("copy_settings_trend_reversal_alerts", default: "Trend Reversal Alerts") }
        static var improvementCelebrations: String { RemoteConfigManager.shared.copyString("copy_settings_improvement_celebrations", default: "Improvement Celebrations") }
        static func maxPerDay(_ count: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_settings_max_per_day", default: "Max %d/day"), count) }

        // MARK: - Metric Alerts

        static func selectedCount(_ count: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_settings_selected_count", default: "%d selected"), count) }

        // MARK: - Export

        static var generateWebReport: String { RemoteConfigManager.shared.copyString("copy_settings_generate_web_report", default: "Generate Web Report") }

        // MARK: - Data Storage

        static var dataStorageFooter: String { RemoteConfigManager.shared.copyString("copy_settings_data_storage_footer", default: "All your health data is stored safely on this phone. The longer you use the app, the better your insights get.") }
        static var samples: String { RemoteConfigManager.shared.copyString("copy_settings_samples", default: "Samples") }
        static var metrics: String { RemoteConfigManager.shared.copyString("copy_settings_metrics", default: "Metrics") }

        // MARK: - Siri

        static var siriFooter: String { RemoteConfigManager.shared.copyString("copy_settings_siri_footer", default: "Say \"Hey Siri, what's my health score in Laso\" to check your score hands free.") }

        // MARK: - About

        static var acknowledgements: String { RemoteConfigManager.shared.copyString("copy_settings_acknowledgements", default: "Acknowledgements") }
        static var acknowledgementsSubtitle: String { RemoteConfigManager.shared.copyString("copy_settings_acknowledgements_subtitle", default: "Open source libraries used in Laso") }
        static var acknowledgementsFooter: String { RemoteConfigManager.shared.copyString("copy_settings_acknowledgements_footer", default: "Laso is built with the help of these open source projects. Tap any item to view its source repository and license.") }
        static var viewSource: String { RemoteConfigManager.shared.copyString("copy_settings_view_source", default: "View Source") }

        // MARK: - Help & Support

        static var rateOnAppStore: String { RemoteConfigManager.shared.copyString("copy_settings_rate_on_app_store", default: "Rate on App Store") }
        static var rateOnAppStoreSubtitle: String { RemoteConfigManager.shared.copyString("copy_settings_rate_on_app_store_subtitle", default: "Enjoying Laso? A rating helps us a lot.") }
        static var reportABug: String { RemoteConfigManager.shared.copyString("copy_settings_report_a_bug", default: "Report a Bug") }
        static var reportABugSubtitle: String { RemoteConfigManager.shared.copyString("copy_settings_report_a_bug_subtitle", default: "Something not working? Tell us and we will fix it.") }
        static var contactUs: String { RemoteConfigManager.shared.copyString("copy_settings_contact_us", default: "Contact Us") }
        static var contactUsSubtitle: String { RemoteConfigManager.shared.copyString("copy_settings_contact_us_subtitle", default: "Questions, requests, or anything else.") }
        static var updateApp: String { RemoteConfigManager.shared.copyString("copy_settings_update_app", default: "Update App") }
        static var updateAvailableBadge: String { RemoteConfigManager.shared.copyString("copy_settings_update_available_badge", default: "New") }
        static func updateAvailableSubtitle(_ version: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_settings_update_available_subtitle", default: "Version %@ is available. Tap to update."), version)
        }
        static func appUpToDateSubtitle(_ version: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_settings_app_up_to_date_subtitle", default: "App is up to date · v%@"), version)
        }

        // MARK: - Loading

        static var loadingPrices: String { RemoteConfigManager.shared.copyString("copy_settings_loading_prices", default: "Loading prices...") }
        static var retryLoadingPlans: String { RemoteConfigManager.shared.copyString("copy_settings_retry_loading_plans", default: "Retry loading plans") }

        // MARK: - Device Status

        static var checkingSources: String { RemoteConfigManager.shared.copyString("copy_settings_checking_sources", default: "Checking sources") }
        static var healthAccessEnabled: String { RemoteConfigManager.shared.copyString("copy_settings_health_access_enabled", default: "Health access enabled") }

        // MARK: - Data Management

        static var deleteAllMyData: String { RemoteConfigManager.shared.copyString("copy_settings_delete_all_my_data", default: "Delete Account and All Data") }
        static var deleteAllDataQuestion: String { RemoteConfigManager.shared.copyString("copy_settings_delete_all_data_question", default: "Delete All Data?") }
        static var deleteEverything: String { RemoteConfigManager.shared.copyString("copy_settings_delete_everything", default: "Delete Everything") }
        /// Key bumped to v2 because the live Remote Config value still carries the
        /// old "the app will close" line, which the app never did.
        static var deleteDataWarning: String { RemoteConfigManager.shared.copyString("copy_settings_delete_data_warning_v2", default: "This will permanently erase all your data from this device, including your profile, preferences, saved health data, and your widgets. This cannot be undone.") }
        static var deleteDataFooter: String { RemoteConfigManager.shared.copyString("copy_settings_delete_data_footer", default: "Permanently removes all local data including your profile, preferences, saved health data, and encrypted storage. This cannot be undone.") }

        // MARK: - Lifted view literals
        static var setsTheDailyCapOnHealthHint: String { RemoteConfigManager.shared.copyString("copy_settings_sets_the_daily_cap_on_health_hint", default: "Sets the daily cap on health notifications") }
        static var adjustTheHeartRateThresholdForHint: String { RemoteConfigManager.shared.copyString("copy_settings_adjust_the_heart_rate_threshold_for_hint", default: "Adjust the heart rate threshold for alerts") }

        // MARK: - Appearance
        static var appearance: String { RemoteConfigManager.shared.copyString("copy_settings_appearance", default: "Appearance") }
        static var themeLight: String { RemoteConfigManager.shared.copyString("copy_settings_theme_light", default: "Light") }
        static var themeDark: String { RemoteConfigManager.shared.copyString("copy_settings_theme_dark", default: "Dark") }
        static var themeSystem: String { RemoteConfigManager.shared.copyString("copy_settings_theme_system", default: "System") }
        static var themeFooter: String { RemoteConfigManager.shared.copyString("copy_settings_theme_footer", default: "System follows your device setting, including its light and dark schedule.") }

        // MARK: - Lifted interpolated view literals
        static func xText(_ p0: String, _ p1: String) -> String { String(format: RemoteConfigManager.shared.copyString("copy_settings_x_text", default: "%@ %@"), p0, p1) }
        static func perDayValue(_ p0: Int) -> String { String(format: RemoteConfigManager.shared.copyString("copy_settings_per_day_value", default: "%d per day"), p0) }
    }
}
