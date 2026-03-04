import SwiftUI
import SwiftData
import AppIntents

/// Settings view for notification preferences, heart rate alerts, per-metric toggles, and export
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppKeys.App.appTheme) private var appTheme: String = "system"
    @State private var preferences: NotificationPreferences
    @State private var showExportSheet = false
    @State private var showMetricAlertPicker = false

    @State private var devicesTracker = SectionTracker(section: .settingsDevices, tab: .settings)
    @State private var notificationsTracker = SectionTracker(section: .settingsNotifications, tab: .settings)
    @State private var alertsTracker = SectionTracker(section: .settingsAlerts, tab: .settings)
    @State private var metricAlertsTracker = SectionTracker(section: .settingsMetricAlerts, tab: .settings)
    @State private var exportTracker = SectionTracker(section: .settingsExport, tab: .settings)
    @State private var appearanceTracker = SectionTracker(section: .settingsAppearance, tab: .settings)
    @State private var dataStorageTracker = SectionTracker(section: .settingsDataStorage, tab: .settings)
    @State private var aboutTracker = SectionTracker(section: .settingsAbout, tab: .settings)

    private let persistence = PersistenceManager()
    let webExportViewModel: WebExportViewModel
    let deviceSourceManager: DeviceSourceManager
    let healthKitManager: HealthKitManager
    let healthDataStore: HealthDataStore

    init(webExportViewModel: WebExportViewModel, deviceSourceManager: DeviceSourceManager, healthKitManager: HealthKitManager, healthDataStore: HealthDataStore) {
        self.webExportViewModel = webExportViewModel
        self.deviceSourceManager = deviceSourceManager
        self.healthKitManager = healthKitManager
        self.healthDataStore = healthDataStore
        self._preferences = State(initialValue: PersistenceManager().loadPreferences())
    }

    var body: some View {
        NavigationStack {
            Form {
                // Connected Devices
                Section("Connected Devices") {
                    NavigationLink {
                        ConnectedDevicesView(
                            viewModel: ConnectedDevicesViewModel(
                                deviceSourceManager: deviceSourceManager,
                                healthKitManager: healthKitManager
                            )
                        )
                    } label: {
                        HStack {
                            Label {
                                Text("Manage Devices")
                            } icon: {
                                Image(systemName: "applewatch")
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            Text(deviceSourceManager.connectedDevices.isEmpty ? "Set up a device" : "\(deviceSourceManager.connectedDevices.count) connected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Manage Devices",
                            type: .manageDevices,
                            screen: .settings,
                            metadata: [
                                "destination": "connected_devices",
                                "connected_devices_count": deviceSourceManager.connectedDevices.count
                            ]
                        )
                        devicesTracker.tapped(target: "manage_devices")
                    })
                }
                .onAppear { devicesTracker.appeared() }
                .onDisappear { devicesTracker.disappeared() }

                // Notifications
                Section("Daily Summary") {
                    Toggle("Enable Daily Summary", isOn: $preferences.dailySummaryEnabled)
                        .onChange(of: preferences.dailySummaryEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "daily_summary_enabled", value: newValue)
                        }

                    if preferences.dailySummaryEnabled {
                        DatePicker(
                            "Summary Time",
                            selection: Binding(
                                get: {
                                    Calendar.current.date(from: preferences.dailySummaryTime) ?? Date()
                                },
                                set: { newDate in
                                    let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                    preferences.dailySummaryTime = components
                                    let hour = components.hour ?? 0
                                    let minute = components.minute ?? 0
                                    AppAnalytics.shared.trackSettingChanged(
                                        name: "daily_summary_time",
                                        value: String(format: "%02d:%02d", hour, minute)
                                    )
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
                .onAppear { notificationsTracker.appeared() }
                .onDisappear { notificationsTracker.disappeared() }

                Section("Weekly Summary") {
                    Toggle("Enable Weekly Report", isOn: $preferences.weeklySummaryEnabled)
                        .onChange(of: preferences.weeklySummaryEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "weekly_summary_enabled", value: newValue)
                        }
                }

                // Heart Rate Spike/Drop Alerts
                Section {
                    Toggle("Heart Rate Spike Alerts", isOn: $preferences.heartRateSpikeAlertsEnabled)
                        .onChange(of: preferences.heartRateSpikeAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "heart_rate_spike_alerts", value: newValue)
                        }

                    if preferences.heartRateSpikeAlertsEnabled {
                        HStack {
                            Text("High HR Threshold")
                            Spacer()
                            Text("\(Int(preferences.heartRateSpikeThreshold)) bpm")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: $preferences.heartRateSpikeThreshold,
                            in: 100...180,
                            step: 5
                        )
                        .onChange(of: preferences.heartRateSpikeThreshold) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "hr_spike_threshold", value: newValue)
                        }

                        HStack {
                            Text("Low HR Threshold")
                            Spacer()
                            Text("\(Int(preferences.heartRateDropThreshold)) bpm")
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: $preferences.heartRateDropThreshold,
                            in: 30...60,
                            step: 5
                        )
                        .onChange(of: preferences.heartRateDropThreshold) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "hr_drop_threshold", value: newValue)
                        }
                    }
                } header: {
                    Text("Heart Rate Alerts")
                } footer: {
                    Text("Get notified when your heart rate goes above or below your thresholds while not exercising.")
                }

                // Apple Watch Reminders
                Section {
                    Toggle("Watch Not Worn Reminder", isOn: $preferences.watchNotWornReminderEnabled)
                        .onChange(of: preferences.watchNotWornReminderEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "watch_not_worn_reminder", value: newValue)
                        }
                    if preferences.watchNotWornReminderEnabled {
                        Text("Get notified if your Apple Watch hasn't recorded data for over 1 hour.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Low Battery Reminder", isOn: $preferences.lowBatteryReminderEnabled)
                        .onChange(of: preferences.lowBatteryReminderEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "low_battery_reminder", value: newValue)
                        }
                    if preferences.lowBatteryReminderEnabled {
                        Text("Get a one-time alert when your watch battery drops below 10%.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Apple Watch", systemImage: "applewatch")
                } footer: {
                    Text("These reminders help you keep your watch on and charged so you never miss health data.")
                }

                // General Alerts
                Section("Alerts") {
                    Toggle("Critical Alerts", isOn: $preferences.criticalAlertsEnabled)
                        .onChange(of: preferences.criticalAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "critical_alerts", value: newValue)
                        }
                    Toggle("Warning Alerts", isOn: $preferences.warningAlertsEnabled)
                        .onChange(of: preferences.warningAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "warning_alerts", value: newValue)
                        }
                    Toggle("Trend Reversal Alerts", isOn: $preferences.trendReversalAlertsEnabled)
                        .onChange(of: preferences.trendReversalAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "trend_reversal_alerts", value: newValue)
                        }
                    Toggle("Improvement Celebrations", isOn: $preferences.improvementAlertsEnabled)
                        .onChange(of: preferences.improvementAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "improvement_alerts", value: newValue)
                        }

                    Stepper(
                        "Max \(preferences.maxNotificationsPerDay)/day",
                        value: $preferences.maxNotificationsPerDay,
                        in: 1...15
                    )
                    .onChange(of: preferences.maxNotificationsPerDay) { _, newValue in
                        AppAnalytics.shared.trackSettingChanged(name: "max_notifications_per_day", value: newValue)
                    }
                }
                .onAppear { alertsTracker.appeared() }
                .onDisappear { alertsTracker.disappeared() }

                // Per-Metric Alert Configuration
                Section {
                    NavigationLink {
                        MetricAlertPickerView(selectedMetrics: $preferences)
                    } label: {
                        HStack {
                            Text("Warning Alert Metrics")
                            Spacer()
                            Text("\(preferences.warningAlertMetrics.count) selected")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Warning Alert Metrics",
                            type: .metricAlertsPicker,
                            screen: .settings,
                            metadata: [
                                "destination": "metric_alert_picker",
                                "selected_metrics_count": preferences.warningAlertMetrics.count
                            ]
                        )
                        metricAlertsTracker.tapped(target: "warning_alert_metrics")
                    })
                } header: {
                    Text("Metric Alerts")
                } footer: {
                    Text("Choose which metrics trigger warning-level notifications when they deviate from your baseline.")
                }
                .onAppear { metricAlertsTracker.appeared() }
                .onDisappear { metricAlertsTracker.disappeared() }

                // Export
                Section("Data Export") {
                    if FeatureGate.canAccess(.exportReport) {
                        Button {
                            AppAnalytics.shared.trackBlockTap(
                                title: "Generate Web Report",
                                type: .exportReport,
                                screen: .settings,
                                metadata: [
                                    "destination": "web_report_share",
                                    "metrics_count": healthDataStore.metricsWithData
                                ]
                            )
                            exportTracker.tapped(target: "generate_web_report")
                            webExportViewModel.exportReport()
                            // Only show sheet after export completes with a valid URL
                            if webExportViewModel.exportedURL != nil {
                                showExportSheet = true
                            }
                        } label: {
                            Label("Generate Web Report", systemImage: "globe")
                        }

                        if webExportViewModel.isExporting {
                            ProgressView("Generating report...")
                        }
                        if let error = webExportViewModel.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        HStack {
                            Label("Generate Web Report", systemImage: "globe")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("PRO")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tint, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .onAppear { exportTracker.appeared() }
                .onDisappear { exportTracker.disappeared() }

                // Appearance
                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        Label("System", systemImage: "gearshape")
                            .tag("system")
                        Label("Light", systemImage: "sun.max.fill")
                            .tag("light")
                        Label("Dark", systemImage: "moon.fill")
                            .tag("dark")
                    }
                    .onChange(of: appTheme) { oldTheme, newTheme in
                        AppAnalytics.shared.trackThemeChanged(from: oldTheme, to: newTheme)
                    }
                }
                .onAppear { appearanceTracker.appeared() }
                .onDisappear { appearanceTracker.disappeared() }

                // Data Storage
                Section {
                    HStack {
                        Label("Stored Samples", systemImage: "internaldrive")
                        Spacer()
                        Text("\(healthDataStore.totalStoredSamples)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    HStack {
                        Label("Data History", systemImage: "calendar.badge.clock")
                        Spacer()
                        Text(healthDataStore.dataSpanDescription)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Metrics Tracked", systemImage: "chart.bar.xaxis")
                        Spacer()
                        Text("\(healthDataStore.metricsWithData)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } header: {
                    Text("On-Device Data")
                } footer: {
                    Text("All your health data is stored securely on this device. The longer you use the app, the better your insights become.")
                }
                .onAppear { dataStorageTracker.appeared() }
                .onDisappear { dataStorageTracker.disappeared() }

                // Siri & Shortcuts
                Section {
                    ShortcutsLink()
                    SiriTipView(intent: HealthScoreIntent())
                } header: {
                    Text("Siri & Shortcuts")
                } footer: {
                    Text("Say \"Hey Siri, what's my health score in Laso\" to check your score hands-free.")
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Data Privacy")
                        Spacer()
                        Text("Health Data On-Device")
                            .foregroundStyle(.secondary)
                    }
                }
                .onAppear { aboutTracker.appeared() }
                .onDisappear { aboutTracker.disappeared() }
            }
            .navigationTitle("Settings")
            .onAppear {
                AppAnalytics.shared.trackFeatureOpen(.settings)
                AppAnalytics.shared.trackActivationMilestone(.firstSettingsVisit)
            }
            .onDisappear { AppAnalytics.shared.trackFeatureClose(.settings) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Done",
                            type: .settingsDoneButton,
                            screen: .settings,
                            metadata: [
                                "destination": "dismiss_settings"
                            ]
                        )
                        dismiss()
                    }
                }
            }
            .onChange(of: preferences) { _, _ in
                savePreferences()
            }
            .sheet(isPresented: $showExportSheet, onDismiss: {
                webExportViewModel.cleanupExport()
            }) {
                if let url = webExportViewModel.exportedURL {
                    ShareSheet(items: [url])
                        .onAppear {
                            AppAnalytics.shared.trackShareSheetPresented(contentType: "web_report")
                        }
                }
            }
        }
    }

    private func savePreferences() {
        persistence.savePreferences(preferences)
    }
}

/// Per-metric alert toggle picker, grouped by category
struct MetricAlertPickerView: View {
    @Binding var selectedMetrics: NotificationPreferences

    var body: some View {
        List {
            ForEach(HealthCategory.allCases) { category in
                Section {
                    ForEach(category.metrics) { metric in
                        Toggle(isOn: Binding(
                            get: { selectedMetrics.warningAlertMetrics.contains(metric) },
                            set: { isOn in
                                if isOn {
                                    selectedMetrics.warningAlertMetrics.insert(metric)
                                } else {
                                    selectedMetrics.warningAlertMetrics.remove(metric)
                                }
                                AppAnalytics.shared.trackSettingChanged(
                                    name: "metric_alert_\(metric.rawValue)",
                                    value: isOn
                                )
                            }
                        )) {
                            HStack(spacing: 10) {
                                Image(systemName: metric.systemImageName)
                                    .font(.body)
                                    .foregroundStyle(category.color)
                                    .frame(width: 24)

                                Text(metric.displayName)
                                    .font(.subheadline)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: category.systemImageName)
                            .foregroundStyle(category.color)
                        Text(category.displayName)
                    }
                }
            }
        }
        .navigationTitle("Alert Metrics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.metricAlertPicker) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.metricAlertPicker) }
    }
}

/// UIKit share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let hkManager = HealthKitManager()
    let engine = AnalysisEngine()
    let container = try! ModelContainer(
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    SettingsView(
        webExportViewModel: WebExportViewModel(
            healthKitManager: hkManager,
            analysisEngine: engine
        ),
        deviceSourceManager: DeviceSourceManager(healthStore: hkManager.healthStore),
        healthKitManager: hkManager,
        healthDataStore: HealthDataStore(modelContainer: container)
    )
}
