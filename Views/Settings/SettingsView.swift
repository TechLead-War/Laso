import SwiftUI
import SwiftData
import AppIntents

/// Settings view for notification preferences, heart rate alerts, per-metric toggles, and export
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preferences: NotificationPreferences
    @State private var showExportSheet = false
    @State private var showMetricAlertPicker = false
    @State private var showDeleteDataAlert = false
    @State private var isDeleting = false

    @State private var saveDebounceTask: DispatchWorkItem?

    @State private var devicesTracker = SectionTracker(section: .settingsDevices, tab: .settings)
    @State private var notificationsTracker = SectionTracker(section: .settingsNotifications, tab: .settings)
    @State private var alertsTracker = SectionTracker(section: .settingsAlerts, tab: .settings)
    @State private var metricAlertsTracker = SectionTracker(section: .settingsMetricAlerts, tab: .settings)
    @State private var exportTracker = SectionTracker(section: .settingsExport, tab: .settings)
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

    private var devicesStatusText: String {
        let count = deviceSourceManager.connectedDevices.count
        if count > 0 {
            return Copy.Settings.connectedCount(count)
        }
        if deviceSourceManager.isScanning {
            return "Checking sources"
        }
        if healthKitManager.isAuthorized {
            return "Health access enabled"
        }
        return Copy.Settings.setUpADevice
    }

    private var devicesStatusIcon: String {
        deviceSourceManager.connectedDevices.first?.device.systemImageName ?? "heart.text.square.fill"
    }

    private var hasAppleWatchSource: Bool {
        deviceSourceManager.connectedDevices.contains { $0.device == .appleWatch }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Connected Devices
                Section(Copy.Settings.connectedDevices) {
                    NavigationLink {
                        ConnectedDevicesView(
                            viewModel: ConnectedDevicesViewModel(
                                deviceSourceManager: deviceSourceManager,
                                healthKitManager: healthKitManager
                            )
                        )
                        .onAppear {
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
                        }
                    } label: {
                        HStack {
                            Label {
                                Text(Copy.Settings.manageDevices)
                            } icon: {
                                Image(systemName: devicesStatusIcon)
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            Text(devicesStatusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                }
                .onAppear { devicesTracker.appeared() }
                .onDisappear { devicesTracker.disappeared() }

                // Notifications
                Section(Copy.Settings.dailySummary) {
                    Toggle(Copy.Settings.enableDailySummary, isOn: $preferences.dailySummaryEnabled)
                        .onChange(of: preferences.dailySummaryEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "daily_summary_enabled", value: newValue)
                        }

                    if preferences.dailySummaryEnabled {
                        DatePicker(
                            Copy.Settings.summaryTime,
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

                Section(Copy.Settings.weeklySummary) {
                    Toggle(Copy.Settings.enableWeeklyReport, isOn: $preferences.weeklySummaryEnabled)
                        .onChange(of: preferences.weeklySummaryEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "weekly_summary_enabled", value: newValue)
                        }
                }

                // Heart Rate Spike/Drop Alerts
                Section {
                    Toggle(Copy.Settings.heartRateSpikeAlerts, isOn: $preferences.heartRateSpikeAlertsEnabled)
                        .onChange(of: preferences.heartRateSpikeAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "heart_rate_spike_alerts", value: newValue)
                        }

                    if preferences.heartRateSpikeAlertsEnabled {
                        HStack {
                            Text(Copy.Settings.highHRThreshold)
                            Spacer()
                            Text(Copy.Settings.bpmValue(Int(preferences.heartRateSpikeThreshold)))
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
                            Text(Copy.Settings.lowHRThreshold)
                            Spacer()
                            Text(Copy.Settings.bpmValue(Int(preferences.heartRateDropThreshold)))
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
                    Text(Copy.Settings.heartRateAlerts)
                } footer: {
                    Text(Copy.Settings.heartRateAlertsFooter)
                }

                // Apple Watch Reminders
                if hasAppleWatchSource {
                    Section {
                        Toggle(Copy.Settings.watchNotWornReminder, isOn: $preferences.watchNotWornReminderEnabled)
                            .onChange(of: preferences.watchNotWornReminderEnabled) { _, newValue in
                                AppAnalytics.shared.trackSettingChanged(name: "watch_not_worn_reminder", value: newValue)
                            }
                        if preferences.watchNotWornReminderEnabled {
                            Text(Copy.Settings.watchNotWornDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Toggle(Copy.Settings.lowBatteryReminder, isOn: $preferences.lowBatteryReminderEnabled)
                            .onChange(of: preferences.lowBatteryReminderEnabled) { _, newValue in
                                AppAnalytics.shared.trackSettingChanged(name: "low_battery_reminder", value: newValue)
                            }
                        if preferences.lowBatteryReminderEnabled {
                            Text(Copy.Settings.lowBatteryDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Label(Copy.Settings.appleWatch, systemImage: "applewatch")
                    } footer: {
                        Text(Copy.Settings.watchRemindersFooter)
                    }
                }

                // General Alerts
                Section(Copy.Settings.alerts) {
                    Toggle(Copy.Settings.criticalAlerts, isOn: $preferences.criticalAlertsEnabled)
                        .onChange(of: preferences.criticalAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "critical_alerts", value: newValue)
                        }
                    Toggle(Copy.Settings.warningAlerts, isOn: $preferences.warningAlertsEnabled)
                        .onChange(of: preferences.warningAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "warning_alerts", value: newValue)
                        }
                    Toggle(Copy.Settings.trendReversalAlerts, isOn: $preferences.trendReversalAlertsEnabled)
                        .onChange(of: preferences.trendReversalAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "trend_reversal_alerts", value: newValue)
                        }
                    Toggle(Copy.Settings.improvementCelebrations, isOn: $preferences.improvementAlertsEnabled)
                        .onChange(of: preferences.improvementAlertsEnabled) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "improvement_alerts", value: newValue)
                        }

                    Stepper(
                        Copy.Settings.maxPerDay(preferences.maxNotificationsPerDay),
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
                            .onAppear {
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
                            }
                    } label: {
                        HStack {
                            Text(Copy.Settings.warningAlertMetrics)
                            Spacer()
                            Text(Copy.Settings.selectedCount(preferences.warningAlertMetrics.count))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                } header: {
                    Text(Copy.Settings.metricAlerts)
                } footer: {
                    Text(Copy.Settings.metricAlertsFooter)
                }
                .onAppear { metricAlertsTracker.appeared() }
                .onDisappear { metricAlertsTracker.disappeared() }

                // Export
                Section(Copy.Settings.dataExport) {
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
                            Label(Copy.Settings.generateWebReport, systemImage: "globe")
                        }

                        if webExportViewModel.isExporting {
                            ProgressView(Copy.Settings.generatingReport)
                        }
                        if let error = webExportViewModel.error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        HStack {
                            Label(Copy.Settings.generateWebReport, systemImage: "globe")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Copy.Labels.pro)
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

                // Data Storage
                Section {
                    HStack {
                        Label(Copy.Settings.storedSamples, systemImage: "internaldrive")
                        Spacer()
                        Text("\(healthDataStore.totalStoredSamples)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    HStack {
                        Label(Copy.Settings.dataHistory, systemImage: "calendar.badge.clock")
                        Spacer()
                        Text(healthDataStore.dataSpanDescription)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label(Copy.Settings.metricsTracked, systemImage: "chart.bar.xaxis")
                        Spacer()
                        Text("\(healthDataStore.metricsWithData)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } header: {
                    Text(Copy.Settings.onDeviceData)
                } footer: {
                    Text(Copy.Settings.dataStorageFooter)
                }
                .onAppear { dataStorageTracker.appeared() }
                .onDisappear { dataStorageTracker.disappeared() }

                // Siri & Shortcuts
                Section {
                    ShortcutsLink()
                    SiriTipView(intent: HealthScoreIntent())
                } header: {
                    Text(Copy.Settings.siriAndShortcuts)
                } footer: {
                    Text(Copy.Settings.siriFooter)
                }

                // About
                Section(Copy.Settings.about) {
                    HStack {
                        Text(Copy.Labels.version)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(Copy.Settings.dataPrivacy)
                        Spacer()
                        Text(Copy.Privacy.healthDataOnDevice)
                            .foregroundStyle(.secondary)
                    }

                    if let privacyURL = URL(string: AppSecrets.URLs.privacyPolicy) {
                        Link(destination: privacyURL) {
                            HStack {
                                Label(Copy.Privacy.privacyPolicy, systemImage: "hand.raised.fill")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let termsURL = URL(string: AppSecrets.URLs.termsOfUse) {
                        Link(destination: termsURL) {
                            HStack {
                                Label(Copy.Privacy.termsOfUse, systemImage: "doc.text.fill")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onAppear { aboutTracker.appeared() }
                .onDisappear { aboutTracker.disappeared() }

                // Delete All Data
                Section {
                    Button(role: .destructive) {
                        showDeleteDataAlert = true
                    } label: {
                        HStack {
                            Label("Delete All My Data", systemImage: "trash")
                            Spacer()
                        }
                    }
                    .disabled(isDeleting)
                    .accessibilityIdentifier("settings.deleteAllDataButton")
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Permanently removes all local data including your profile, preferences, health cache, and encrypted storage. This cannot be undone.")
                }
                .alert("Delete All Data?", isPresented: $showDeleteDataAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete Everything", role: .destructive) {
                        performDataDeletion()
                    }
                } message: {
                    Text("This will permanently erase all of your data from this device, including your profile, preferences, and cached health data. This action is irreversible. The app will close so changes take full effect.")
                }

                // Medical Disclaimer
                Section {
                    Text(Copy.medicalDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("screen.settings")
            .navigationTitle(Copy.Settings.settings)
            .onAppear {
                AppAnalytics.shared.trackFeatureOpen(.settings)
                AppAnalytics.shared.trackActivationMilestone(.firstSettingsVisit)
            }
            .task {
                guard healthKitManager.isAuthorized,
                      deviceSourceManager.connectedDevices.isEmpty,
                      !deviceSourceManager.isScanning else { return }
                await deviceSourceManager.scanSources()
            }
            .onDisappear { AppAnalytics.shared.trackFeatureClose(.settings) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.Buttons.done) {
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
                    .accessibilityIdentifier("settings.doneButton")
                }
            }
            .onChange(of: preferences) { _, _ in
                debouncedSave()
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

    private func performDataDeletion() {
        isDeleting = true

        // 1. Clear all encrypted profile keys individually
        let encryptedStore = EncryptedStore.shared
        encryptedStore.remove(forKey: AppKeys.Profile.name)
        encryptedStore.remove(forKey: AppKeys.Profile.email)
        encryptedStore.remove(forKey: AppKeys.Profile.dateOfBirth)
        encryptedStore.remove(forKey: "healthpulse.userProfile")

        // 2. Wipe the entire UserDefaults persistent domain for this app
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        UserDefaults.standard.synchronize()

        // 3. Post notification for any listeners, then terminate so the
        //    in-memory AppStateStore resets on next launch and onboarding shows.
        NotificationCenter.default.post(name: .init("HealthPulseDidDeleteAllData"), object: nil)

        // Brief delay so the alert can dismiss before the process exits
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            exit(0)
        }
    }

    private func debouncedSave() {
        saveDebounceTask?.cancel()
        let task = DispatchWorkItem { [preferences] in
            persistence.savePreferences(preferences)
        }
        saveDebounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
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
        .navigationTitle(Copy.Settings.alertMetrics)
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
        for: StoredDailySample.self, StoredSyncMetadata.self, StoredAnalysisSnapshot.self, StoredDailyStrain.self,
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
