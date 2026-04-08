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
        static let onDeviceData = "On-Device Data"
        static let siriAndShortcuts = "Siri & Shortcuts"
        static let about = "About"
        static let alertMetrics = "Alert Metrics"

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
        static let heartRateAlertsFooter = "Get notified when your heart rate goes above or below your thresholds while not exercising."

        // MARK: - Apple Watch Reminders

        static let watchNotWornReminder = "Watch Not Worn Reminder"
        static let watchNotWornDescription = "Get notified if your Apple Watch hasn't recorded data for over an hour."
        static let lowBatteryReminder = "Low Battery Reminder"
        static let lowBatteryDescription = "Get a one-time alert when your watch battery drops below 10%."
        static let watchRemindersFooter = "These reminders help you keep your watch on and charged so you never miss health data."

        // MARK: - Alerts

        static let criticalAlerts = "Critical Alerts"
        static let warningAlerts = "Warning Alerts"
        static let trendReversalAlerts = "Trend Reversal Alerts"
        static let improvementCelebrations = "Improvement Celebrations"
        static func maxPerDay(_ count: Int) -> String { "Max \(count)/day" }

        // MARK: - Metric Alerts

        static let warningAlertMetrics = "Warning Alert Metrics"
        static func selectedCount(_ count: Int) -> String { "\(count) selected" }
        static let metricAlertsFooter = "Choose which metrics trigger warning-level notifications when they deviate from your baseline."

        // MARK: - Export

        static let generateWebReport = "Generate Web Report"
        static let generatingReport = "Generating report..."

        // MARK: - Data Storage

        static let storedSamples = "Stored Samples"
        static let dataHistory = "Data History"
        static let metricsTracked = "Metrics Tracked"
        static let dataStorageFooter = "All your health data is stored securely on this device. The longer you use the app, the better your insights become."

        // MARK: - Siri

        static let siriFooter = "Say \"Hey Siri, what's my health score in Laso\" to check your score hands-free."

        // MARK: - About

        static let dataPrivacy = "Data Privacy"

        // MARK: - Loading

        static let loadingPrices = "Loading prices..."
        static let retryLoadingPlans = "Retry loading plans"
    }
}
