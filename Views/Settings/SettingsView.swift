import SwiftUI

/// Settings view for notification preferences, heart rate alerts, per-metric toggles, and export
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
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
                } header: {
                    Text("Metric Alerts")
                } footer: {
                    Text("Choose which metrics trigger warning-level notifications when they deviate from your baseline.")
                }

                // Export
                Section("Data Export") {
                    Button {
                        webExportViewModel.exportReport()
                        showExportSheet = true
                    } label: {
                        Label("Generate Web Report", systemImage: "globe")
                    }

                    if webExportViewModel.isExporting {
                        ProgressView("Generating report...")
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: preferences.dailySummaryEnabled) { _, _ in savePreferences() }
            .onChange(of: preferences.weeklySummaryEnabled) { _, _ in savePreferences() }
            .onChange(of: preferences.criticalAlertsEnabled) { _, _ in savePreferences() }
            .onChange(of: preferences.warningAlertsEnabled) { _, _ in savePreferences() }
            .onChange(of: preferences.maxNotificationsPerDay) { _, _ in savePreferences() }
            .onChange(of: preferences.heartRateSpikeAlertsEnabled) { _, _ in savePreferences() }
            .onChange(of: preferences.heartRateSpikeThreshold) { _, _ in savePreferences() }
            .onChange(of: preferences.heartRateDropThreshold) { _, _ in savePreferences() }
            .onChange(of: preferences.trendReversalAlertsEnabled) { _, _ in savePreferences() }
            .onChange(of: preferences.improvementAlertsEnabled) { _, _ in savePreferences() }
            .onChange(of: preferences.warningAlertMetrics) { _, _ in savePreferences() }
            .sheet(isPresented: $showExportSheet) {
                if let url = webExportViewModel.exportedURL {
                    ShareSheet(items: [url])
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
