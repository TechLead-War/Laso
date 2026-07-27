import SwiftUI

/// Dedicated notifications sub-page. Groups every alert toggle behind one Settings row
/// so the main Settings screen stays calm and scannable.
struct NotificationsSettingsView: View {
    @Binding var preferences: NotificationPreferences
    let hasAppleWatchSource: Bool

    @State private var showThresholds = false
    @State private var tracker = SectionTracker(section: .settingsNotifications, tab: .settings)
    @State private var alertsTracker = SectionTracker(section: .settingsAlerts, tab: .settings)
    @State private var metricAlertsTracker = SectionTracker(section: .settingsMetricAlerts, tab: .settings)


    var body: some View {
        Form {
            summariesSection
            healthAlertsSection
            heartRateSection
            if hasAppleWatchSource {
                watchSection
            }
        }
        .navigationTitle(Copy.Settings.notifications)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.notificationsSettings)
            tracker.appeared()
            alertsTracker.appeared()
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.notificationsSettings)
            tracker.disappeared()
            alertsTracker.disappeared()
        }
    }

    // MARK: - Summaries

    private var summariesSection: some View {
        Section {
            Toggle(Copy.Settings.dailySummary, isOn: $preferences.dailySummaryEnabled)
                .onChange(of: preferences.dailySummaryEnabled) { _, newValue in
                    AppAnalytics.shared.trackSettingChanged(name: "daily_summary_enabled", value: newValue)
                }

            if preferences.dailySummaryEnabled {
                DatePicker(
                    Copy.Settings.summaryTime,
                    selection: Binding(
                        get: { Date.cal.date(from: preferences.dailySummaryTime) ?? Date() },
                        set: { newDate in
                            let components = Date.cal.dateComponents([.hour, .minute], from: newDate)
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

            Toggle(Copy.Settings.weeklySummary, isOn: $preferences.weeklySummaryEnabled)
                .onChange(of: preferences.weeklySummaryEnabled) { _, newValue in
                    AppAnalytics.shared.trackSettingChanged(name: "weekly_summary_enabled", value: newValue)
                }
        } header: {
            Text(Copy.Settings.summaries)
        } footer: {
            Text(Copy.Settings.dailySummaryDescription)
        }
    }

    // MARK: - Health Alerts

    private var healthAlertsSection: some View {
        Section {
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
            .accessibilityLabel(Copy.Settings.maxNotificationsLabel)
            .accessibilityValue(Copy.Settings.perDayValue(preferences.maxNotificationsPerDay))
            .accessibilityHint(Copy.Settings.setsTheDailyCapOnHealthHint)
            .onChange(of: preferences.maxNotificationsPerDay) { _, newValue in
                AppAnalytics.shared.trackSettingChanged(name: "max_notifications_per_day", value: newValue)
            }

            NavigationLink {
                MetricAlertPickerView(selectedMetrics: $preferences)
            } label: {
                HStack {
                    Text(Copy.Settings.whichMetrics)
                    Spacer()
                    Text(Copy.Settings.selectedCount(preferences.warningAlertMetrics.count))
                        .foregroundStyle(.secondary)
                }
            }
            // Bound to the tap, not the destination's onAppear, so returning to the
            // picker does not count as a fresh tap from this screen.
            .simultaneousGesture(TapGesture().onEnded {
                AppAnalytics.shared.trackBlockTap(
                    title: "Warning Alert Metrics",
                    type: .metricAlertsPicker,
                    screen: .notificationsSettings,
                    metadata: [
                        "destination": "metric_alert_picker",
                        "selected_metrics_count": preferences.warningAlertMetrics.count
                    ]
                )
                metricAlertsTracker.tapped(target: "warning_alert_metrics")
            })
        } header: {
            Text(Copy.Settings.healthAlerts)
        } footer: {
            Text(Copy.Settings.notificationsHint)
        }
    }

    // MARK: - Heart Rate

    private var heartRateSection: some View {
        Section {
            Toggle(Copy.Settings.heartRateSpikeAlerts, isOn: $preferences.heartRateSpikeAlertsEnabled)
                .onChange(of: preferences.heartRateSpikeAlertsEnabled) { _, newValue in
                    AppAnalytics.shared.trackSettingChanged(name: "heart_rate_spike_alerts", value: newValue)
                }

            if preferences.heartRateSpikeAlertsEnabled {
                DisclosureGroup(Copy.Settings.customizeThresholds, isExpanded: $showThresholds) {
                    VStack(alignment: .leading, spacing: 14) {
                        thresholdSlider(
                            label: Copy.Settings.highHRThreshold,
                            value: $preferences.heartRateSpikeThreshold,
                            range: 100...180,
                            color: .red,
                            analyticsName: "hr_spike_threshold"
                        )
                        thresholdSlider(
                            label: Copy.Settings.lowHRThreshold,
                            value: $preferences.heartRateDropThreshold,
                            range: 30...60,
                            color: .blue,
                            analyticsName: "hr_drop_threshold"
                        )
                    }
                    .padding(.top, 6)
                }
            }
        } header: {
            Text(Copy.Settings.heartRateAlerts)
        } footer: {
            Text(Copy.Settings.heartRateAlertsFooter)
        }
    }

    private func thresholdSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        color: Color,
        analyticsName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(Copy.Settings.bpmValue(Int(value.wrappedValue)))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(color)
            }
            Slider(value: value, in: range, step: 5)
                .tint(color)
                .accessibilityLabel(label)
                .accessibilityValue(Copy.Settings.bpmValue(Int(value.wrappedValue)))
                .accessibilityHint(Copy.Settings.adjustTheHeartRateThresholdForHint)
                .onChange(of: value.wrappedValue) { _, newValue in
                    AppAnalytics.shared.trackSettingChanged(name: analyticsName, value: newValue)
                }
        }
    }

    // MARK: - Apple Watch

    private var watchSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Toggle(Copy.Settings.watchNotWornReminder, isOn: $preferences.watchNotWornReminderEnabled)
                    .onChange(of: preferences.watchNotWornReminderEnabled) { _, newValue in
                        AppAnalytics.shared.trackSettingChanged(name: "watch_not_worn_reminder", value: newValue)
                    }
                if preferences.watchNotWornReminderEnabled {
                    Text(Copy.Settings.watchNotWornDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        } header: {
            Text(Copy.Settings.appleWatch)
        } footer: {
            Text(Copy.Settings.watchRemindersFooter)
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView(
            preferences: .constant(.default),
            hasAppleWatchSource: true
        )
    }
}
