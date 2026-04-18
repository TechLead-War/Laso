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

    // Disclosure group expansion state
    @State private var dailySummaryExpanded = true
    @State private var weeklyReportExpanded = false
    @State private var alertsExpanded = false
    @State private var watchExpanded = false

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
            return Copy.Settings.checkingSources
        }
        if healthKitManager.isAuthorized {
            return Copy.Settings.healthAccessEnabled
        }
        return Copy.Settings.setUpADevice
    }

    private var devicesStatusIcon: String {
        deviceSourceManager.connectedDevices.first?.device.systemImageName ?? "heart.text.square.fill"
    }

    private var hasAppleWatchSource: Bool {
        deviceSourceManager.connectedDevices.contains { $0.device == .appleWatch }
    }

    private var subscriptionBadgeText: String {
        if FeatureGate.hasFullAccess {
            return Copy.Settings.proMember
        }
        return Copy.Settings.freePlan
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.sectionSpacing) {

                    // MARK: - Profile Header Card
                    profileHeaderCard

                    // MARK: - Devices
                    devicesCard
                        .onAppear { devicesTracker.appeared() }
                        .onDisappear { devicesTracker.disappeared() }

                    // MARK: - Notifications
                    notificationsCard
                        .onAppear { notificationsTracker.appeared() }
                        .onDisappear { notificationsTracker.disappeared() }

                    // MARK: - Heart Rate Alerts
                    heartRateAlertsCard
                        .onAppear { alertsTracker.appeared() }
                        .onDisappear { alertsTracker.disappeared() }

                    // MARK: - Per-Metric Alerts
                    metricAlertsCard
                        .onAppear { metricAlertsTracker.appeared() }
                        .onDisappear { metricAlertsTracker.disappeared() }

                    // MARK: - Data & Storage
                    dataStorageCard
                        .onAppear { dataStorageTracker.appeared() }
                        .onDisappear { dataStorageTracker.disappeared() }

                    // MARK: - Export
                    exportCard
                        .onAppear { exportTracker.appeared() }
                        .onDisappear { exportTracker.disappeared() }

                    // MARK: - Siri & Shortcuts
                    siriCard

                    // MARK: - About & Legal
                    aboutCard
                        .onAppear { aboutTracker.appeared() }
                        .onDisappear { aboutTracker.disappeared() }

                    // MARK: - Delete Data
                    deleteDataCard

                    // MARK: - Medical Disclaimer
                    Text(Copy.medicalDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.cardPadding)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .accessibilityIdentifier("screen.settings")
            .navigationTitle(Copy.Settings.settings)
            .navigationBarTitleDisplayMode(.large)
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
                    .fontWeight(.semibold)
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

    // MARK: - Profile Header Card

    private var profileHeaderCard: some View {
        VStack(spacing: 12) {
            // App icon and branding
            HStack(spacing: 14) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Labels.appName)
                        .font(.title2.weight(.bold))

                    Text("\(Copy.Labels.version) \(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Subscription status badge
                HStack(spacing: 5) {
                    if FeatureGate.hasFullAccess {
                        Image(systemName: "crown.fill")
                            .font(.footnote.weight(.bold))
                    }
                    Text(subscriptionBadgeText)
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(FeatureGate.hasFullAccess ? Color(red: 0.35, green: 0.22, blue: 0.02) : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    FeatureGate.hasFullAccess
                        ? AnyShapeStyle(LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.85, blue: 0.45),
                                Color(red: 0.96, green: 0.64, blue: 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ))
                        : AnyShapeStyle(.fill.tertiary),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            FeatureGate.hasFullAccess
                                ? Color.white.opacity(0.35)
                                : .clear,
                            lineWidth: 0.5
                        )
                )
                .shadow(color: FeatureGate.hasFullAccess ? Color(red: 0.95, green: 0.6, blue: 0.1).opacity(0.35) : .clear, radius: 6, y: 2)
            }
        }
        .padding(DS.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.06),
                            Color.purple.opacity(0.03),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .cardStyle()
    }

    // MARK: - Devices Card

    private var devicesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSectionHeader(title: Copy.Settings.devices, icon: "antenna.radiowaves.left.and.right", color: .blue)

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
                HStack(spacing: 12) {
                    settingsIconBadge(icon: devicesStatusIcon, color: .blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Settings.manageDevices)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(devicesStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(DS.cardPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.row.connectedDevices")
        }
        .cardStyle()
    }

    // MARK: - Notifications Card

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSectionHeader(title: Copy.Settings.notifications, icon: "bell.badge.fill", color: .orange)

            VStack(spacing: 0) {
                // Daily Summary
                DisclosureGroup(isExpanded: $dailySummaryExpanded) {
                    VStack(spacing: 10) {
                        Toggle(isOn: $preferences.dailySummaryEnabled) {
                            Text(Copy.Settings.enableDailySummary)
                                .font(.subheadline)
                        }
                        .tint(.blue)
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
                            .font(.subheadline)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                } label: {
                    Text(Copy.Settings.dailySummary)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, DS.cardPadding)
                .padding(.vertical, 10)

                Divider().padding(.leading, DS.cardPadding)

                // Weekly Report
                DisclosureGroup(isExpanded: $weeklyReportExpanded) {
                    Toggle(isOn: $preferences.weeklySummaryEnabled) {
                        Text(Copy.Settings.enableWeeklyReport)
                            .font(.subheadline)
                    }
                    .tint(.blue)
                    .onChange(of: preferences.weeklySummaryEnabled) { _, newValue in
                        AppAnalytics.shared.trackSettingChanged(name: "weekly_summary_enabled", value: newValue)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                } label: {
                    Text(Copy.Settings.weeklySummary)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, DS.cardPadding)
                .padding(.vertical, 10)

                Divider().padding(.leading, DS.cardPadding)

                // Alerts
                DisclosureGroup(isExpanded: $alertsExpanded) {
                    VStack(spacing: 8) {
                        settingsToggleRow(
                            title: Copy.Settings.criticalAlerts,
                            isOn: $preferences.criticalAlertsEnabled,
                            analyticsName: "critical_alerts"
                        )
                        settingsToggleRow(
                            title: Copy.Settings.warningAlerts,
                            isOn: $preferences.warningAlertsEnabled,
                            analyticsName: "warning_alerts"
                        )
                        settingsToggleRow(
                            title: Copy.Settings.trendReversalAlerts,
                            isOn: $preferences.trendReversalAlertsEnabled,
                            analyticsName: "trend_reversal_alerts"
                        )
                        settingsToggleRow(
                            title: Copy.Settings.improvementCelebrations,
                            isOn: $preferences.improvementAlertsEnabled,
                            analyticsName: "improvement_alerts"
                        )

                        Divider()

                        Stepper(
                            Copy.Settings.maxPerDay(preferences.maxNotificationsPerDay),
                            value: $preferences.maxNotificationsPerDay,
                            in: 1...15
                        )
                        .font(.subheadline)
                        .onChange(of: preferences.maxNotificationsPerDay) { _, newValue in
                            AppAnalytics.shared.trackSettingChanged(name: "max_notifications_per_day", value: newValue)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                } label: {
                    Text(Copy.Settings.alerts)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, DS.cardPadding)
                .padding(.vertical, 10)

                // Apple Watch Reminders (conditional)
                if hasAppleWatchSource {
                    Divider().padding(.leading, DS.cardPadding)

                    DisclosureGroup(isExpanded: $watchExpanded) {
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: $preferences.watchNotWornReminderEnabled) {
                                    Text(Copy.Settings.watchNotWornReminder)
                                        .font(.subheadline)
                                }
                                .tint(.blue)
                                .onChange(of: preferences.watchNotWornReminderEnabled) { _, newValue in
                                    AppAnalytics.shared.trackSettingChanged(name: "watch_not_worn_reminder", value: newValue)
                                }
                                if preferences.watchNotWornReminderEnabled {
                                    Text(Copy.Settings.watchNotWornDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: $preferences.lowBatteryReminderEnabled) {
                                    Text(Copy.Settings.lowBatteryReminder)
                                        .font(.subheadline)
                                }
                                .tint(.blue)
                                .onChange(of: preferences.lowBatteryReminderEnabled) { _, newValue in
                                    AppAnalytics.shared.trackSettingChanged(name: "low_battery_reminder", value: newValue)
                                }
                                if preferences.lowBatteryReminderEnabled {
                                    Text(Copy.Settings.lowBatteryDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(Copy.Settings.watchRemindersFooter)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 2)
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "applewatch")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(Copy.Settings.appleWatch)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .padding(.horizontal, DS.cardPadding)
                    .padding(.vertical, 10)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Heart Rate Alerts Card

    private var heartRateAlertsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSectionHeader(title: Copy.Settings.heartRateAlerts, icon: "heart.fill", color: .red)

            VStack(spacing: 12) {
                Toggle(isOn: $preferences.heartRateSpikeAlertsEnabled) {
                    HStack(spacing: 10) {
                        settingsIconBadge(icon: "waveform.path.ecg", color: .red)
                        Text(Copy.Settings.heartRateSpikeAlerts)
                            .font(.subheadline.weight(.medium))
                    }
                }
                .tint(.red)
                .onChange(of: preferences.heartRateSpikeAlertsEnabled) { _, newValue in
                    AppAnalytics.shared.trackSettingChanged(name: "heart_rate_spike_alerts", value: newValue)
                }

                if preferences.heartRateSpikeAlertsEnabled {
                    VStack(spacing: 14) {
                        Divider()

                        VStack(spacing: 6) {
                            HStack {
                                Text(Copy.Settings.highHRThreshold)
                                    .font(.subheadline)
                                Spacer()
                                Text(Copy.Settings.bpmValue(Int(preferences.heartRateSpikeThreshold)))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.red)
                            }
                            Slider(
                                value: $preferences.heartRateSpikeThreshold,
                                in: 100...180,
                                step: 5
                            )
                            .tint(.red)
                            .onChange(of: preferences.heartRateSpikeThreshold) { _, newValue in
                                AppAnalytics.shared.trackSettingChanged(name: "hr_spike_threshold", value: newValue)
                            }
                        }

                        VStack(spacing: 6) {
                            HStack {
                                Text(Copy.Settings.lowHRThreshold)
                                    .font(.subheadline)
                                Spacer()
                                Text(Copy.Settings.bpmValue(Int(preferences.heartRateDropThreshold)))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.blue)
                            }
                            Slider(
                                value: $preferences.heartRateDropThreshold,
                                in: 30...60,
                                step: 5
                            )
                            .tint(.blue)
                            .onChange(of: preferences.heartRateDropThreshold) { _, newValue in
                                AppAnalytics.shared.trackSettingChanged(name: "hr_drop_threshold", value: newValue)
                            }
                        }
                    }
                }

                Text(Copy.Settings.heartRateAlertsFooter)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
        }
        .cardStyle()
    }

    // MARK: - Metric Alerts Card

    private var metricAlertsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSectionHeader(title: Copy.Settings.metricAlerts, icon: "chart.bar.xaxis", color: .purple)

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
                HStack(spacing: 12) {
                    settingsIconBadge(icon: "exclamationmark.triangle.fill", color: .purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Settings.warningAlertMetrics)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(Copy.Settings.metricAlertsFooter)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Text(Copy.Settings.selectedCount(preferences.warningAlertMetrics.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(DS.cardPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.row.metricAlerts")
        }
        .cardStyle()
    }

    // MARK: - Data & Storage Card

    private var dataStorageCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSectionHeader(title: Copy.Settings.onDeviceData, icon: "internaldrive.fill", color: .green)

            VStack(spacing: 12) {
                // Stats row
                HStack(spacing: 0) {
                    dataStatItem(
                        value: "\(healthDataStore.totalStoredSamples)",
                        label: Copy.Settings.samples,
                        icon: "number",
                        color: .green
                    )

                    Divider()
                        .frame(height: DS.dividerHeight)

                    dataStatItem(
                        value: healthDataStore.dataSpanDescription,
                        label: Copy.Settings.history,
                        icon: "calendar",
                        color: .blue
                    )

                    Divider()
                        .frame(height: DS.dividerHeight)

                    dataStatItem(
                        value: "\(healthDataStore.metricsWithData)",
                        label: Copy.Settings.metrics,
                        icon: "chart.bar",
                        color: .purple
                    )
                }

                Text(Copy.Settings.dataStorageFooter)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
        }
        .cardStyle()
    }

    // MARK: - Export Card

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSectionHeader(title: Copy.Settings.dataExport, icon: "square.and.arrow.up.fill", color: .indigo)

            VStack(spacing: 8) {
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
                        if webExportViewModel.exportedURL != nil {
                            showExportSheet = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            settingsIconBadge(icon: "globe", color: .indigo)

                            Text(Copy.Settings.generateWebReport)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            if webExportViewModel.isExporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(DS.cardPadding)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.row.dataExport")

                    if let error = webExportViewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, DS.cardPadding)
                            .padding(.bottom, 8)
                    }
                } else {
                    HStack(spacing: 12) {
                        settingsIconBadge(icon: "globe", color: .gray)

                        Text(Copy.Settings.generateWebReport)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(Copy.Labels.pro)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.badgeH)
                            .padding(.vertical, DS.badgeV)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                    }
                    .padding(DS.cardPadding)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Siri Card

    private var siriCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSectionHeader(title: Copy.Settings.siriAndShortcuts, icon: "mic.fill", color: .purple)

            VStack(spacing: 10) {
                ShortcutsLink()
                SiriTipView(intent: HealthScoreIntent())

                Text(Copy.Settings.siriFooter)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.cardPadding)
        }
        .cardStyle()
    }

    // MARK: - About & Legal Card

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsSectionHeader(title: Copy.Settings.aboutAndLegal, icon: "info.circle.fill", color: .gray)

            VStack(spacing: 0) {
                // Data privacy row
                HStack(spacing: 12) {
                    settingsIconBadge(icon: "lock.shield.fill", color: .green)

                    Text(Copy.Settings.dataPrivacy)
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text(Copy.Privacy.healthDataOnDevice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(DS.cardPadding)

                Divider().padding(.leading, DS.cardPadding + DS.iconSize + 12)

                // Privacy Policy
                if let privacyURL = URL(string: AppSecrets.URLs.privacyPolicy) {
                    Link(destination: privacyURL) {
                        HStack(spacing: 12) {
                            settingsIconBadge(icon: "hand.raised.fill", color: .blue)

                            Text(Copy.Privacy.privacyPolicy)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(DS.cardPadding)
                        .contentShape(Rectangle())
                    }

                    Divider().padding(.leading, DS.cardPadding + DS.iconSize + 12)
                }

                // Terms of Use
                if let termsURL = URL(string: AppSecrets.URLs.termsOfUse) {
                    Link(destination: termsURL) {
                        HStack(spacing: 12) {
                            settingsIconBadge(icon: "doc.text.fill", color: .indigo)

                            Text(Copy.Privacy.termsOfUse)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(DS.cardPadding)
                        .contentShape(Rectangle())
                    }
                }

                // Manage Subscription (visible to subscribed users)
                if FeatureGate.hasFullAccess, let manageURL = URL(string: AppSecrets.URLs.manageSubscriptions) {
                    Divider().padding(.leading, DS.cardPadding + DS.iconSize + 12)

                    Link(destination: manageURL) {
                        HStack(spacing: 12) {
                            settingsIconBadge(icon: "creditcard.fill", color: .orange)

                            Text(Copy.Settings.manageSubscription)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(DS.cardPadding)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("settings.row.subscription")
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Delete Data Card

    private var deleteDataCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(role: .destructive) {
                showDeleteDataAlert = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "trash.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Settings.deleteAllMyData)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                        Text(Copy.Settings.deleteDataFooter)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(DS.cardPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .accessibilityIdentifier("settings.deleteAllDataButton")
        }
        .cardStyle(tint: .red)
        .alert(Copy.Settings.deleteAllDataQuestion, isPresented: $showDeleteDataAlert) {
            Button(Copy.Buttons.cancel, role: .cancel) { }
            Button(Copy.Settings.deleteEverything, role: .destructive) {
                performDataDeletion()
            }
        } message: {
            Text(Copy.Settings.deleteDataWarning)
        }
    }

    // MARK: - Shared Components

    private func settingsSectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.top, DS.cardPadding)
        .padding(.bottom, 4)
    }

    private func settingsIconBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.subheadline)
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))
    }

    private func settingsToggleRow(title: String, isOn: Binding<Bool>, analyticsName: String) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.subheadline)
        }
        .tint(.blue)
        .onChange(of: isOn.wrappedValue) { _, newValue in
            AppAnalytics.shared.trackSettingChanged(name: analyticsName, value: newValue)
        }
    }

    private func dataStatItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func performDataDeletion() {
        isDeleting = true

        // 1. Clear all encrypted profile keys individually
        let encryptedStore = EncryptedStore.shared
        encryptedStore.remove(forKey: AppKeys.Profile.name)
        encryptedStore.remove(forKey: AppKeys.Profile.email)
        encryptedStore.remove(forKey: AppKeys.Profile.dateOfBirth)
        encryptedStore.remove(forKey: "healthpulse.userProfile")

        // 2. Delete all SwiftData records (health samples, analysis snapshots,
        //    journal entries, ML model state, etc.)
        healthDataStore.deleteAllData()

        // 3. Wipe the entire UserDefaults persistent domain for this app
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        UserDefaults.standard.synchronize()

        // 4. Post notification for any listeners, then terminate so the
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
