import SwiftUI
import SwiftData
import AppIntents
#if canImport(FirebaseAuth)
import FirebaseCore
import FirebaseAuth
#endif

/// Main Settings screen. Uses a native grouped Form with 5 calm sections so the
/// surface stays scannable. Advanced alert tuning lives one tap deeper inside
/// NotificationsSettingsView.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    // Loaded in `.task`, not in `init`: this view sits in a ViewBuilder that runs
    // on every navigation event, so an initial value meant a disk read, an AES-GCM
    // open and a JSON decode per pass.
    @State private var preferences: NotificationPreferences = .default
    @State private var showExportSheet = false
    @State private var showDeleteDataAlert = false
    @State private var isDeleting = false

    @State private var saveDebounceTask: DispatchWorkItem?

    @State private var devicesTracker = SectionTracker(section: .settingsDevices, tab: .settings)
    @State private var exportTracker = SectionTracker(section: .settingsExport, tab: .settings)
    @State private var dataStorageTracker = SectionTracker(section: .settingsDataStorage, tab: .settings)
    @State private var aboutTracker = SectionTracker(section: .settingsAbout, tab: .settings)

    @State private var activeFeedbackEntry: FeedbackSheet.EntryPoint?
    @State private var rateHapticTrigger = false

    // Injected rather than built here: this view sits in a ViewBuilder that
    // re-evaluates on every tab switch and navigation push, so each construction
    // was a fresh migration pass, a KVS sync and ~13 keychain round trips.
    let persistence: PersistenceManager
    let webExportViewModel: WebExportViewModel
    let deviceSourceManager: DeviceSourceManager
    let healthKitManager: HealthKitManager
    let healthDataStore: HealthDataStore

    init(
        persistence: PersistenceManager,
        webExportViewModel: WebExportViewModel,
        deviceSourceManager: DeviceSourceManager,
        healthKitManager: HealthKitManager,
        healthDataStore: HealthDataStore
    ) {
        self.persistence = persistence
        self.webExportViewModel = webExportViewModel
        self.deviceSourceManager = deviceSourceManager
        self.healthKitManager = healthKitManager
        self.healthDataStore = healthDataStore
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

    /// Caption shown under the Pro badge so the user knows till when access lasts.
    /// Real subscribers see "Renews DD MMM YYYY"; free-year users see
    /// "Free until DD MMM YYYY" when an end date is configured in Remote Config.
    private var subscriptionDateText: String? {
        if let expiration = FeatureGate.subscriptionExpirationDate {
            return Copy.Settings.renews(expiration)
        }
        if FeatureGate.freeYearActive, let endDate = FeatureGate.freeYearEndDate {
            return Copy.Settings.freeUntil(endDate)
        }
        return nil
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Body

    /// Identifies the deep-linkable Settings sub-screens. Used by UI-test launch
    /// flag (`--ui-test-settings-route=`) to push directly into a sub-page.
    enum SettingsRoute: String, Hashable {
        case notifications
        case devices
        case siri
    }

    @State private var deepLinkPath: [SettingsRoute] = []
    private var themeManager: ThemeManager { ThemeManager.shared }

    var body: some View {
        NavigationStack(path: $deepLinkPath) {
            Form {
                profileSection
                appearanceSection
                referralSection
                subscriptionSection
                dataSection
                notificationsSection
                supportSection
                aboutSection
                dangerZoneSection
                disclaimerSection
            }
            .background(AppColour.surfaceBase.ignoresSafeArea())
            .accessibilityIdentifier("screen.settings")
            .navigationTitle(Copy.Settings.settings)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .notifications:
                    NotificationsSettingsView(
                        preferences: $preferences,
                        hasAppleWatchSource: hasAppleWatchSource
                    )
                case .devices:
                    ConnectedDevicesView(
                        viewModel: ConnectedDevicesViewModel(
                            deviceSourceManager: deviceSourceManager,
                            healthKitManager: healthKitManager
                        )
                    )
                case .siri:
                    siriDetailView
                }
            }
            .onAppear {
                AppAnalytics.shared.trackFeatureOpen(.settings)
                AppAnalytics.shared.trackActivationMilestone(.firstSettingsVisit)
                // UI-test deep-link: push the requested sub-page on first appear.
                if UITestMode.isEnabled,
                   let raw = UITestMode.settingsInitialRoute,
                   let route = SettingsRoute(rawValue: raw),
                   deepLinkPath.isEmpty {
                    deepLinkPath = [route]
                }
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(Copy.Labels.appName)
                        .font(DS.Typography.title3)
                    Text(Copy.Settings.xText(Copy.Labels.version, appVersion))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    subscriptionBadge
                    if let dateText = subscriptionDateText {
                        Text(dateText)
                            .font(DS.Typography.caption2)
                            .foregroundStyle(.secondary)
                            // Match the capsule's internal horizontal padding so
                            // the date text's right edge aligns with the "Pro
                            // Member" label's right edge (not the capsule's
                            // outer edge). Without this, the caption visually
                            // sits flush-right while the badge text appears
                            // inset, creating the misalignment in screenshots.
                            .padding(.trailing, DS.space3)
                            .accessibilityIdentifier("settings.subscription.dateCaption")
                    }
                }
            }
            .padding(.vertical, 6)
            .listRowBackground(AppColour.surfaceRaised)
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

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section {
            Picker(Copy.Settings.appearance, selection: Binding(
                get: { themeManager.preference },
                set: {
                    AppAnalytics.shared.trackSettingChanged(name: "appearance", value: $0.rawValue)
                    themeManager.set($0)
                }
            )) {
                ForEach(ThemePreference.allCases) { option in
                    Label(option.title, systemImage: option.symbol).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.appearance")
        } header: {
            Text(Copy.Settings.appearance)
        } footer: {
            Text(Copy.Settings.themeFooter)
        }
    }

    // MARK: - Referral Section

    @ViewBuilder
    private var referralSection: some View {
        if ReferralManager.shared.isEnabled {
            Section {
                NavigationLink {
                    InviteFriendsView()
                } label: {
                    settingsRow(
                        icon: "gift.fill",
                        iconColor: AppColour.primary,
                        title: Copy.Referral.inviteRowTitle,
                        subtitle: Copy.Referral.inviteRowSubtitle
                    )
                }
                .accessibilityIdentifier("settings.row.inviteFriends")
            }
        }
    }

    // MARK: - Subscription Section

    @ViewBuilder
    private var subscriptionSection: some View {
        if FeatureGate.hasFullAccess, let manageURL = URL(string: AppSecrets.URLs.manageSubscriptions) {
            Section {
                Link(destination: manageURL) {
                    settingsRow(
                        icon: "creditcard.fill",
                        iconColor: AppColour.warning,
                        title: Copy.Settings.manageSubscription,
                        subtitle: Copy.Settings.manageSubscriptionSubtitle,
                        trailing: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.row.subscription.top")
                .simultaneousGesture(TapGesture().onEnded {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Manage Subscription",
                        type: .appStoreLink,
                        screen: .settings,
                        metadata: ["destination": "app_store_subscriptions"]
                    )
                })
            }
        }
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
            } label: {
                settingsRow(
                    icon: "heart.text.square.fill",
                    iconColor: AppColour.primary,
                    title: Copy.Settings.manageDevices,
                    subtitle: devicesStatusText
                )
            }
            .accessibilityIdentifier("settings.row.connectedDevices")
            // Bound to the tap, not the destination's onAppear: ConnectedDevicesView
            // pushes its own detail screens, so popping back re-ran onAppear and
            // counted a navigation the user never made from Settings.
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
            iconBadge(icon: "internaldrive.fill", color: AppColour.success)
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
                    iconBadge(icon: "square.and.arrow.up.fill", color: AppColour.categorySleep)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Settings.generateWebReport)
                            .font(DS.Typography.subheadlineMedium)
                            .foregroundStyle(.primary)
                        if let error = webExportViewModel.error {
                            Text(error)
                                .font(DS.Typography.caption)
                                .foregroundStyle(AppColour.danger)
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
                iconBadge(icon: "square.and.arrow.up.fill", color: AppColour.surfaceMuted)
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
            .foregroundStyle(AppColour.textOnAccent)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(
                LinearGradient(colors: [AppColour.primary, AppColour.categoryStress], startPoint: .leading, endPoint: .trailing),
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
                    iconColor: AppColour.warning,
                    title: Copy.Settings.notifications,
                    subtitle: notificationsSummary
                )
            }
            .accessibilityIdentifier("settings.row.notifications")
            // Bound to the tap, not the destination's onAppear: NotificationsSettingsView
            // pushes the metric alert picker, so popping back re-ran onAppear and
            // counted a navigation the user never made from Settings.
            .simultaneousGesture(TapGesture().onEnded {
                AppAnalytics.shared.trackBlockTap(
                    title: "Notifications",
                    type: .settingsNotifications,
                    screen: .settings,
                    metadata: [
                        "destination": "notifications_settings",
                        "active_summary": notificationsSummary
                    ]
                )
            })
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

    /// Signed-in user's display name or email (post Sign In with Apple).
    /// Returns nil for anonymous Firebase Auth users.
    private var signedInIdentity: String? {
        #if canImport(FirebaseAuth)
        // `Auth.auth()` traps when Firebase was never configured, which is the
        // case on any launch that skips `configureOnLaunch`, including screenshot
        // runs. Reading the app handle first turns a crash into no row.
        guard FirebaseApp.app() != nil,
              let user = Auth.auth().currentUser, !user.isAnonymous else { return nil }
        return user.displayName?.isEmpty == false ? user.displayName : user.email
        #else
        return nil
        #endif
    }

    private var aboutSection: some View {
        Section {
            if let identity = signedInIdentity {
                settingsRow(
                    icon: "person.crop.circle.fill",
                    iconColor: AppColour.primary,
                    title: "Signed in as",
                    subtitle: identity,
                    trailing: nil
                )
                .accessibilityIdentifier("settings.row.signedInAs")
            }
            siriRow
            if let privacyURL = URL(string: AppSecrets.URLs.privacyPolicy) {
                Link(destination: privacyURL) {
                    settingsRow(
                        icon: "hand.raised.fill",
                        iconColor: AppColour.primary,
                        title: Copy.Privacy.privacyPolicy,
                        subtitle: nil,
                        trailing: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    AppAnalytics.shared.trackPrivacyPageViewed(source: "settings")
                })
            }
            if let termsURL = URL(string: AppSecrets.URLs.termsOfUse) {
                Link(destination: termsURL) {
                    settingsRow(
                        icon: "doc.text.fill",
                        iconColor: AppColour.categorySleep,
                        title: Copy.Privacy.termsOfUse,
                        subtitle: nil,
                        trailing: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Terms of Use",
                        type: .settingsTermsLink,
                        screen: .settings,
                        metadata: ["destination": "terms_of_use_web"]
                    )
                })
            }
            NavigationLink {
                AcknowledgementsView()
            } label: {
                settingsRow(
                    icon: "doc.badge.gearshape.fill",
                    iconColor: AppColour.surfaceMuted,
                    title: Copy.Settings.acknowledgements,
                    subtitle: Copy.Settings.acknowledgementsSubtitle
                )
            }
            .accessibilityIdentifier("settings.row.acknowledgements")
            .simultaneousGesture(TapGesture().onEnded {
                AppAnalytics.shared.trackBlockTap(
                    title: "Acknowledgements",
                    type: .settingsAcknowledgements,
                    screen: .settings,
                    metadata: ["destination": "acknowledgements"]
                )
            })
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
                iconColor: AppColour.categoryStress,
                title: Copy.Settings.siriAndShortcuts,
                subtitle: nil
            )
        }
        .simultaneousGesture(TapGesture().onEnded {
            AppAnalytics.shared.trackBlockTap(
                title: "Siri and Shortcuts",
                type: .settingsSiri,
                screen: .settings,
                metadata: ["destination": "siri_detail"]
            )
        })
    }

    private var siriDetailView: some View {
        Form {
            Section {
                Text(Copy.Settings.siriDetailDescription)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
                    .listRowBackground(Color.clear)
            }
            Section {
                ShortcutsLink()
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Open Shortcuts App",
                            type: .siriShortcutsLink,
                            screen: .settings,
                            metadata: ["destination": "shortcuts_app"]
                        )
                    })
                SiriTipView(intent: HealthScoreIntent())
                    .simultaneousGesture(TapGesture().onEnded {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Siri Tip",
                            type: .siriTip,
                            screen: .settings,
                            metadata: ["intent": "health_score"]
                        )
                    })
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
        let updateAvailable = checker.isUpdateAvailable
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: Copy.Settings.updateApp,
                type: .updateApp,
                screen: .settings,
                metadata: [
                    "destination": "app_store_product_page",
                    "latest_version": checker.latestVersion ?? "unknown",
                    "update_available": updateAvailable
                ]
            )
            _ = checker.openAppStoreForUpdate(using: { openURL($0) })
        } label: {
            HStack(spacing: 12) {
                iconBadge(icon: "arrow.down.circle.fill", color: AppColour.success)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(Copy.Settings.updateApp)
                            .font(DS.Typography.subheadlineMedium)
                            .foregroundStyle(.primary)
                        if updateAvailable {
                            Text(Copy.Settings.updateAvailableBadge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColour.textOnAccent)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(AppColour.success, in: Capsule())
                        }
                    }
                    if updateAvailable, let latest = checker.latestVersion {
                        Text(Copy.Settings.updateAvailableSubtitle(latest))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text(Copy.Settings.appUpToDateSubtitle(checker.currentAppVersion))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
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
                rateHapticTrigger.toggle()
                AppStoreReviewManager.shared.requestReviewFromUser(trigger: "settings_help")
            } label: {
                settingsRow(
                    icon: "star.fill",
                    iconColor: AppColour.warning,
                    title: Copy.Settings.rateOnAppStore,
                    subtitle: Copy.Settings.rateOnAppStoreSubtitle,
                    trailing: "arrow.up.right"
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: rateHapticTrigger)
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
                    iconColor: AppColour.danger,
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
                    iconColor: AppColour.primary,
                    title: Copy.Settings.contactUs,
                    subtitle: Copy.Settings.contactUsSubtitle
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.row.contactUs")
        } header: {
            Text(Copy.Settings.support)
        }
    }

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive) {
                AppAnalytics.shared.trackBlockTap(
                    title: Copy.Settings.deleteAllMyData,
                    type: .settingsDeleteData,
                    screen: .settings,
                    metadata: [
                        "destination": "delete_data_confirm_alert",
                        "stored_samples": healthDataStore.totalStoredSamples
                    ]
                )
                showDeleteDataAlert = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "trash.fill", color: AppColour.danger)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Settings.deleteAllMyData)
                            .font(DS.Typography.subheadlineMedium)
                            .foregroundStyle(AppColour.danger)
                        Text(Copy.Settings.deleteDataFooter)
                            .font(DS.Typography.caption)
                            .foregroundStyle(AppColour.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
            .accessibilityIdentifier("settings.deleteAllDataButton")
        } header: {
            Text(Copy.Settings.dangerZone)
                .font(DS.Typography.captionSemibold)
                .foregroundStyle(AppColour.danger)
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
            .foregroundStyle(AppColour.textOnAccent)
            .frame(width: 34, height: 34)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }

    // MARK: - Actions

    private func performDataDeletion() {
        // Must be first: AnalyticsBackend.provider.reset() below drops the identity,
        // so anything emitted after it lands on a fresh anonymous id.
        AppAnalytics.shared.trackAccountDataDeleted(storedSamples: healthDataStore.totalStoredSamples)

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

        // The App Group sits outside the app's own defaults domain, so the wipe
        // above misses it and the widget keeps rendering the deleted data.
        WidgetDataStore.shared.clearAll()

        // Sign out of Firebase + reset analytics identity. Server-side Firestore
        // wipe (user_profiles/{uid}, subscriptions/{uid}) needs a Cloud Function
        // (TODO follow-up: deleteAccountData callable). For now, the local
        // wipe + sign-out sends the user back to onboarding cleanly.
        #if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
        #endif
        AnalyticsBackend.provider.reset()

        // App-root observer (LasoApp) listens for this notification and routes
        // back to onboarding by clearing onboardingCompleted state.
        NotificationCenter.default.post(name: Notification.Name("LasoDidWipeAccount"), object: nil)

        isDeleting = false
        dismiss()
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
        persistence: PersistenceManager(),
        webExportViewModel: WebExportViewModel(
            healthKitManager: hkManager,
            analysisEngine: engine
        ),
        deviceSourceManager: DeviceSourceManager(healthStore: hkManager.healthStore),
        healthKitManager: hkManager,
        healthDataStore: HealthDataStore(modelContainer: container)
    )
}
