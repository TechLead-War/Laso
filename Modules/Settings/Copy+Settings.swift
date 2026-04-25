import Foundation

extension Copy {
    enum Settings {

        // MARK: - Navigation

        static let settings = "Settings"

        // MARK: - Section Headers

        static let connectedDevices = "Connected Devices"
        static let dailySummary = "Daily Summary"
        static let weeklySummary = "Weekly Summary"
        static let heartRateAlerts = "Heart Rate Alerts"
        static let appleWatch = "Apple Watch"
        static let alerts = "Alerts"
        static let metricAlerts = "Metric Alerts"
        static let dataExport = "Data Export"
        static let onDeviceData = "On Device Data"
        static let siriAndShortcuts = "Siri & Shortcuts"
        static let about = "About"
        static let alertMetrics = "Alert Metrics"
        static let notifications = "Notifications"

        // MARK: - Simplified Section Headers

        static let yourData = "Your Data"
        static let support = "Support"
        static let summaries = "Summaries"
        static let healthAlerts = "Health Alerts"
        static let customizeThresholds = "Customize Thresholds"
        static let whichMetrics = "Choose Metrics"
        static let notificationsHint = "All alerts are optional. You choose what reaches you."
        static let dailySummaryDescription = "A short morning briefing with your score and key numbers."
        static let weeklySummaryDescription = "A weekly recap delivered every Monday morning."
        static let connectDataSource = "Connect a Data Source"
        static let connectDataSourceHint = "Laso reads from Apple Health. Connect a watch or other app to start."
        static let waitingForData = "Waiting for Health Data"
        static let waitingForDataHint = "Make sure your watch or health app is sharing with Apple Health."
        static let syncingData = "Syncing Your Data"
        static let refreshNow = "Refresh Now"

        // MARK: - Profile Header

        static let proMember = "Pro Member"
        static let freePlan = "Free Plan"
        static let trialActive = "Trial Active"

        // MARK: - Subscription Management

        static let manageSubscription = "Manage Subscription"

        // MARK: - Section Icons & Labels

        static let devices = "Devices"
        static let aboutAndLegal = "About & Legal"

        // MARK: - Device Management

        static let manageDevices = "Manage Devices"
        static let setUpADevice = "Set up a device"
        static func connectedCount(_ count: Int) -> String {
            "\(count) connected"
        }

        // MARK: - Notifications

        static let enableDailySummary = "Enable Daily Summary"
        static let summaryTime = "Summary Time"
        static let enableWeeklyReport = "Enable Weekly Report"

        // MARK: - Heart Rate

        static let heartRateSpikeAlerts = "Heart Rate Spike Alerts"
        static let highHRThreshold = "High HR Threshold"
        static let lowHRThreshold = "Low HR Threshold"
        static func bpmValue(_ bpm: Int) -> String { "\(bpm) bpm" }
        static let heartRateAlertsFooter = "Get notified when your heart rate goes too high or too low while you are not working out."

        // MARK: - Apple Watch Reminders

        static let watchNotWornReminder = "Watch Not Worn Reminder"
        static let watchNotWornDescription = "Get notified if your Apple Watch has not recorded data for over an hour."
        static let lowBatteryReminder = "Low Battery Reminder"
        static let lowBatteryDescription = "Get a one-time alert when your watch battery drops below 10%."
        static let watchRemindersFooter = "These reminders help you keep your watch on and charged so you do not miss any health data."

        // MARK: - Alerts

        static let criticalAlerts = "Critical Alerts"
        static let warningAlerts = "Warning Alerts"
        static let trendReversalAlerts = "Trend Reversal Alerts"
        static let improvementCelebrations = "Improvement Celebrations"
        static func maxPerDay(_ count: Int) -> String { "Max \(count)/day" }

        // MARK: - Metric Alerts

        static let warningAlertMetrics = "Warning Alert Metrics"
        static func selectedCount(_ count: Int) -> String { "\(count) selected" }
        static let metricAlertsFooter = "Choose which health numbers send you a warning when they change from your usual."

        // MARK: - Export

        static let generateWebReport = "Generate Web Report"
        static let generatingReport = "Generating report..."
        static let exportHealthReport = "Export Health Report"

        // MARK: - Data Storage

        static let storedSamples = "Stored Samples"
        static let dataHistory = "Data History"
        static let metricsTracked = "Metrics Tracked"
        static let dataStorageFooter = "All your health data is stored safely on this phone. The longer you use the app, the better your insights get."
        static let samples = "Samples"
        static let history = "History"
        static let metrics = "Metrics"

        // MARK: - Siri

        static let siriFooter = "Say \"Hey Siri, what's my health score in Laso\" to check your score hands free."

        // MARK: - About

        static let dataPrivacy = "Data Privacy"
        static let acknowledgements = "Acknowledgements"
        static let acknowledgementsSubtitle = "Open source libraries used in Laso"
        static let acknowledgementsFooter = "Laso is built with the help of these open source projects. Tap any item to view its source repository and license."
        static let viewSource = "View Source"

        // MARK: - Help & Support

        static let helpAndSupport = "Help & Support"
        static let rateOnAppStore = "Rate on App Store"
        static let rateOnAppStoreSubtitle = "Enjoying Laso? A rating helps us a lot."
        static let reportABug = "Report a Bug"
        static let reportABugSubtitle = "Something not working? Tell us and we will fix it."
        static let contactUs = "Contact Us"
        static let contactUsSubtitle = "Questions, requests, or anything else."
        static let updateApp = "Update App"
        static let updateAvailableBadge = "New"
        static func updateAvailableSubtitle(_ version: String) -> String {
            "Version \(version) is available. Tap to update."
        }
        static func appUpToDateSubtitle(_ version: String) -> String {
            "App is up to date · v\(version)"
        }

        // MARK: - Loading

        static let loadingPrices = "Loading prices..."
        static let retryLoadingPlans = "Retry loading plans"

        // MARK: - Device Status

        static let checkingSources = "Checking sources"
        static let healthAccessEnabled = "Health access enabled"

        // MARK: - Data Management

        static let dataManagement = "Data Management"
        static let deleteAllMyData = "Delete All My Data"
        static let deleteAllDataQuestion = "Delete All Data?"
        static let deleteEverything = "Delete Everything"
        static let deleteDataWarning = "This will permanently erase all your data from this device, including your profile, preferences, and saved health data. This cannot be undone. The app will close so changes take full effect."
        static let deleteDataFooter = "Permanently removes all local data including your profile, preferences, saved health data, and encrypted storage. This cannot be undone."
    }
}
