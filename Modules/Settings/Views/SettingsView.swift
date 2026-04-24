import SwiftUI
import SwiftData
import AppIntents

/// Main Settings screen. Uses a native grouped Form with 5 calm sections so the
/// surface stays scannable. Advanced alert tuning lives one tap deeper inside
/// NotificationsSettingsView.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var preferences: NotificationPreferences
    @State private var showExportSheet = false
    @State private var showDeleteDataAlert = false
    @State private var isDeleting = false

    @State private var saveDebounceTask: DispatchWorkItem?

    @State private var devicesTracker = SectionTracker(section: .settingsDevices, tab: .settings)
    @State private var exportTracker = SectionTracker(section: .settingsExport, tab: .settings)
    @State private var dataStorageTracker = SectionTracker(section: .settingsDataStorage, tab: .settings)
    @State private var aboutTracker = SectionTracker(section: .settingsAbout, tab: .settings)

    @State private var activeFeedbackEntry: FeedbackSheet.EntryPoint?

    private let persistence = PersistenceManager()
    let webExportViewModel: WebExportViewModel
    let deviceSourceManager: DeviceSourceManager
    let healthKitManager: HealthKitManager
    let healthDataStore: HealthDataStore

    init(
        webExportViewModel: WebExportViewModel,
        deviceSourceManager: DeviceSourceManager,
        healthKitManager: HealthKitManager,
        healthDataStore: HealthDataStore
    ) {
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

    private var hasAppleWatchSource: Bool {
        deviceSourceManager.connectedDevices.contains { $0.device == .appleWatch }
    }

    private var subscriptionBadgeText: String {
        FeatureGate.hasFullAccess ? Copy.Settings.proMember : Copy.Settings.freePlan
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                dataSection
                notificationsSection
                aboutSection
                supportSection
                disclaimerSection
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
            .task {
                await AppStoreVersionChecker.shared.check()
            }
            .onDisappear { AppAnalytics.shared.trackFeatureClose(.settings) }

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
            .sheet(item: $activeFeedbackEntry) { entry in
                FeedbackSheet(entryPoint: entry)
            }
            .alert(Copy.Settings.deleteAllDataQuestion, isPresented: $showDeleteDataAlert) {
                Button(Copy.Buttons.cancel, role: .cancel) { }
                Button(Copy.Settings.deleteEverything, role: .destructive) {
                    performDataDeletion()
                }
            } message: {
                Text(Copy.Settings.deleteDataWarning)
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            HStack(spacing: 14) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Labels.appName)
                        .font(.title3.weight(.bold))
                    Text("\(Copy.Labels.version) \(appVersion)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                subscriptionBadge
            }
            .padding(.vertical, 6)
            .listRowBackground(Color(.secondarySystemGroupedBackground))
        }
    }

    private var subscriptionBadge: some View {
        HStack(spacing: 5) {
            if FeatureGate.hasFullAccess {
                Image(systemName: "crown.fill")
                    .font(.footnote.weight(.bold))
            }
            Text(subscriptionBadgeText)
                .font(.footnote.weight(.bold))
        }
        .foregroundStyle(FeatureGate.hasFullAccess ? AppColour.premiumBadgeText : .secondary)
        .padding(.horizontal, DS.space3)
        .padding(.vertical, 6)
        .background(
            FeatureGate.hasFullAccess
                ? AnyShapeStyle(LinearGradient(
                    colors: [
                        AppColour.premiumGradientTop,
                        AppColour.premiumGradientBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  ))
                : AnyShapeStyle(.fill.tertiary),
            in: Capsule()
        )
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section {
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
                settingsRow(
                    icon: "heart.text.square.fill",
                    iconColor: .blue,
                    title: Copy.Settings.manageDevices,
                    subtitle: devicesStatusText
                )
            }
            .accessibilityIdentifier("settings.row.connectedDevices")

            storageRow
                .onAppear { dataStorageTracker.appeared() }
                .onDisappear { dataStorageTracker.disappeared() }

            exportRow
                .onAppear { exportTracker.appeared() }
                .onDisappear { exportTracker.disappeared() }
        } header: {
            Text(Copy.Settings.yourData)
        } footer: {
            Text(Copy.Settings.dataStorageFooter)
        }
    }

    private var storageRow: some View {
        HStack(spacing: 12) {
            iconBadge(icon: "internaldrive.fill", color: .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(Copy.Settings.onDeviceData)
                    .font(DS.Typography.subheadlineMedium)
                Text(storageSummary)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var storageSummary: String {
        "\(healthDataStore.totalStoredSamples) \(Copy.Settings.samples.lowercased()) · \(healthDataStore.dataSpanDescription) · \(healthDataStore.metricsWithData) \(Copy.Settings.metrics.lowercased())"
    }

    @ViewBuilder
    private var exportRow: some View {
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
                    iconBadge(icon: "square.and.arrow.up.fill", color: .indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Settings.generateWebReport)
                            .font(DS.Typography.subheadlineMedium)
                            .foregroundStyle(.primary)
                        if let error = webExportViewModel.error {
                            Text(error)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                    if webExportViewModel.isExporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up.right")
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.row.dataExport")
        } else {
            HStack(spacing: 12) {
                iconBadge(icon: "square.and.arrow.up.fill", color: .gray)
                Text(Copy.Settings.generateWebReport)
                    .font(DS.Typography.subheadlineMedium)
                    .foregroundStyle(.secondary)
                Spacer()
                proBadge
            }
        }
    }

    private var proBadge: some View {
        Text(Copy.Labels.pro)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(
                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            NavigationLink {
                NotificationsSettingsView(
                    preferences: $preferences,
                    hasAppleWatchSource: hasAppleWatchSource
                )
            } label: {
                settingsRow(
                    icon: "bell.badge.fill",
                    iconColor: .orange,
                    title: Copy.Settings.notifications,
                    subtitle: notificationsSummary
                )
            }
            .accessibilityIdentifier("settings.row.notifications")
        } footer: {
            Text(Copy.Settings.notificationsHint)
        }
    }

    private var notificationsSummary: String {
        var active: [String] = []
        if preferences.dailySummaryEnabled { active.append(Copy.Settings.dailySummary) }
        if preferences.weeklySummaryEnabled { active.append(Copy.Settings.weeklySummary) }
        if preferences.criticalAlertsEnabled { active.append(Copy.Settings.criticalAlerts) }
        if preferences.heartRateSpikeAlertsEnabled { active.append(Copy.Settings.heartRateAlerts) }
        if active.isEmpty { return "Off" }
        if active.count <= 2 { return active.joined(separator: ", ") }
        return "\(active.count) active"
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            siriRow
            if let privacyURL = URL(string: AppSecrets.URLs.privacyPolicy) {
                Link(destination: privacyURL) {
                    settingsRow(
                        icon: "hand.raised.fill",
                        iconColor: .blue,
                        title: Copy.Privacy.privacyPolicy,
                        subtitle: nil,
                        trailing: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)
            }
            if let termsURL = URL(string: AppSecrets.URLs.termsOfUse) {
                Link(destination: termsURL) {
                    settingsRow(
                        icon: "doc.text.fill",
                        iconColor: .indigo,
                        title: Copy.Privacy.termsOfUse,
                        subtitle: nil,
                        trailing: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)
            }
            if FeatureGate.hasFullAccess, let manageURL = URL(string: AppSecrets.URLs.manageSubscriptions) {
                Link(destination: manageURL) {
                    settingsRow(
                        icon: "creditcard.fill",
                        iconColor: .orange,
                        title: Copy.Settings.manageSubscription,
                        subtitle: nil,
                        trailing: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.row.subscription")
            }
        } header: {
            Text(Copy.Settings.about)
        }
        .onAppear { aboutTracker.appeared() }
        .onDisappear { aboutTracker.disappeared() }
    }

    private var siriRow: some View {
        NavigationLink {
            siriDetailView
        } label: {
            settingsRow(
                icon: "mic.fill",
                iconColor: .purple,
                title: Copy.Settings.siriAndShortcuts,
                subtitle: nil
            )
        }
    }

    private var siriDetailView: some View {
        Form {
            Section {
                ShortcutsLink()
                SiriTipView(intent: HealthScoreIntent())
            } footer: {
                Text(Copy.Settings.siriFooter)
            }
        }
        .navigationTitle(Copy.Settings.siriAndShortcuts)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Support Section

    @ViewBuilder
    private var updateAppRow: some View {
        let checker = AppStoreVersionChecker.shared
        if checker.isUpdateAvailable, let latest = checker.latestVersion {
            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: Copy.Settings.updateApp,
                    type: .updateApp,
                    screen: .settings,
                    metadata: [
                        "destination": "app_store_product_page",
                        "latest_version": latest
                    ]
                )
                _ = checker.openAppStoreForUpdate(using: { openURL($0) })
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "arrow.down.circle.fill", color: .green)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(Copy.Settings.updateApp)
                                .font(DS.Typography.subheadlineMedium)
                                .foregroundStyle(.primary)
                            Text(Copy.Settings.updateAvailableBadge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(Color.green, in: Capsule())
                        }
                        Text(Copy.Settings.updateAvailableSubtitle(latest))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.row.updateApp")
        }
    }

    private var supportSection: some View {
        Section {
            updateAppRow

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: Copy.Settings.rateOnAppStore,
                    type: .rateAppStore,
                    screen: .settings,
                    metadata: ["destination": "app_store_review"]
                )
                AppStoreReviewManager.shared.requestReviewFromUser(trigger: "settings_help")
            } label: {
                settingsRow(
                    icon: "star.fill",
                    iconColor: .yellow,
                    title: Copy.Settings.rateOnAppStore,
                    subtitle: Copy.Settings.rateOnAppStoreSubtitle,
                    trailing: "arrow.up.right"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.row.rateOnAppStore")

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: Copy.Settings.reportABug,
                    type: .reportBug,
                    screen: .settings,
                    metadata: ["destination": "feedback_sheet_bug"]
                )
                activeFeedbackEntry = .bug
            } label: {
                settingsRow(
                    icon: "ladybug.fill",
                    iconColor: .red,
                    title: Copy.Settings.reportABug,
                    subtitle: Copy.Settings.reportABugSubtitle
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.row.reportBug")

            Button {
                AppAnalytics.shared.trackBlockTap(
                    title: Copy.Settings.contactUs,
                    type: .contactSupport,
                    screen: .settings,
                    metadata: ["destination": "feedback_sheet_support"]
                )
                activeFeedbackEntry = .support
            } label: {
                settingsRow(
                    icon: "questionmark.bubble.fill",
                    iconColor: .blue,
                    title: Copy.Settings.contactUs,
                    subtitle: Copy.Settings.contactUsSubtitle
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.row.contactUs")

            Button(role: .destructive) {
                showDeleteDataAlert = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "trash.fill", color: .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Settings.deleteAllMyData)
                            .font(DS.Typography.subheadlineMedium)
                            .foregroundStyle(.red)
                        Text(Copy.Settings.deleteDataFooter)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .accessibilityIdentifier("settings.deleteAllDataButton")
        } header: {
            Text(Copy.Settings.support)
        }
    }

    // MARK: - Disclaimer

    private var disclaimerSection: some View {
        Section {
            EmptyView()
        } footer: {
            Text(Copy.medicalDisclaimer)
                .font(DS.Typography.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Shared Row Builders

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String?,
        trailing: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon: icon, color: iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.subheadlineMedium)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let trailing {
                Image(systemName: trailing)
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func iconBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))
    }

    // MARK: - Actions

    private func performDataDeletion() {
        isDeleting = true

        let encryptedStore = EncryptedStore.shared
        encryptedStore.remove(forKey: AppKeys.Profile.name)
        encryptedStore.remove(forKey: AppKeys.Profile.email)
        encryptedStore.remove(forKey: AppKeys.Profile.dateOfBirth)
        encryptedStore.remove(forKey: "healthpulse.userProfile")

        healthDataStore.deleteAllData()

        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        UserDefaults.standard.synchronize()

        NotificationCenter.default.post(name: .init("HealthPulseDidDeleteAllData"), object: nil)

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
                                    .font(DS.Typography.body)
                                    .foregroundStyle(category.color)
                                    .frame(width: 24)
                                Text(metric.displayName)
                                    .font(DS.Typography.subheadline)
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
