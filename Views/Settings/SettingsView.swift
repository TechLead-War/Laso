import SwiftUI

/// Settings view for notification preferences, heart rate alerts, per-metric toggles, and export
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("healthpulse.appTheme") private var appTheme: String = "system"
    @State private var preferences: NotificationPreferences
    @State private var showExportSheet = false
    @State private var showMetricAlertPicker = false

    private let persistence = PersistenceManager()
    let webExportViewModel: WebExportViewModel
    let deviceSourceManager: DeviceSourceManager
    let healthKitManager: HealthKitManager

    init(webExportViewModel: WebExportViewModel, deviceSourceManager: DeviceSourceManager, healthKitManager: HealthKitManager) {
        self.webExportViewModel = webExportViewModel
        self.deviceSourceManager = deviceSourceManager
        self.healthKitManager = healthKitManager
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
                        AppAnalytics.shared.trackBlockTap(title: "Manage Devices", type: .manageDevices, screen: .settings)
                    })
                }

                // Notifications
                Section("Daily Summary") {
                    Toggle("Enable Daily Summary", isOn: $preferences.dailySummaryEnabled)

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

                Section("Weekly Summary") {
                    Toggle("Enable Weekly Report", isOn: $preferences.weeklySummaryEnabled)
                }

                // Heart Rate Spike/Drop Alerts
                Section {
                    Toggle("Heart Rate Spike Alerts", isOn: $preferences.heartRateSpikeAlertsEnabled)

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
                    }
                } header: {
                    Text("Heart Rate Alerts")
                } footer: {
                    Text("Get notified when your heart rate goes above or below your thresholds while not exercising.")
                }

                // General Alerts
                Section("Alerts") {
                    Toggle("Critical Alerts", isOn: $preferences.criticalAlertsEnabled)
                    Toggle("Warning Alerts", isOn: $preferences.warningAlertsEnabled)
                    Toggle("Trend Reversal Alerts", isOn: $preferences.trendReversalAlertsEnabled)
                    Toggle("Improvement Celebrations", isOn: $preferences.improvementAlertsEnabled)

                    Stepper(
                        "Max \(preferences.maxNotificationsPerDay)/day",
                        value: $preferences.maxNotificationsPerDay,
                        in: 1...15
                    )
                }

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
                        AppAnalytics.shared.trackBlockTap(title: "Warning Alert Metrics", type: .metricAlertsPicker, screen: .settings)
                    })
                } header: {
                    Text("Metric Alerts")
                } footer: {
                    Text("Choose which metrics trigger warning-level notifications when they deviate from your baseline.")
                }

                // Export
                Section("Data Export") {
                    Button {
                        AppAnalytics.shared.trackBlockTap(title: "Generate Web Report", type: .exportReport, screen: .settings)
                        webExportViewModel.exportReport()
                        showExportSheet = true
                    } label: {
                        Label("Generate Web Report", systemImage: "globe")
                    }

                    if webExportViewModel.isExporting {
                        ProgressView("Generating report...")
                    }
                }

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
                        Text("100% On-Device")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { AppAnalytics.shared.trackFeatureOpen(.settings) }
            .onDisappear { AppAnalytics.shared.trackFeatureClose(.settings) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        AppAnalytics.shared.trackBlockTap(title: "Done", type: .settingsDoneButton, screen: .settings)
                        dismiss()
                    }
                }
            }
            .onChange(of: preferences.dailySummaryEnabled) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "daily_summary_enabled", value: newValue)
            }
            .onChange(of: preferences.weeklySummaryEnabled) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "weekly_summary_enabled", value: newValue)
            }
            .onChange(of: preferences.criticalAlertsEnabled) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "critical_alerts_enabled", value: newValue)
            }
            .onChange(of: preferences.warningAlertsEnabled) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "warning_alerts_enabled", value: newValue)
            }
            .onChange(of: preferences.maxNotificationsPerDay) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "max_notifications_per_day", value: newValue)
            }
            .onChange(of: preferences.heartRateSpikeAlertsEnabled) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "heart_rate_spike_alerts_enabled", value: newValue)
            }
            .onChange(of: preferences.heartRateSpikeThreshold) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "heart_rate_spike_threshold_bpm", value: newValue)
            }
            .onChange(of: preferences.heartRateDropThreshold) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "heart_rate_drop_threshold_bpm", value: newValue)
            }
            .onChange(of: preferences.trendReversalAlertsEnabled) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "trend_reversal_alerts_enabled", value: newValue)
            }
            .onChange(of: preferences.improvementAlertsEnabled) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "improvement_alerts_enabled", value: newValue)
            }
            .onChange(of: preferences.warningAlertMetrics) { _, newValue in
                savePreferences()
                AppAnalytics.shared.trackSettingChanged(name: "warning_alert_metrics_count", value: newValue.count)
            }
            .sheet(isPresented: $showExportSheet) {
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
    SettingsView(
        webExportViewModel: WebExportViewModel(
            healthKitManager: hkManager,
            analysisEngine: engine
        ),
        deviceSourceManager: DeviceSourceManager(healthStore: hkManager.healthStore),
        healthKitManager: hkManager
    )
}
