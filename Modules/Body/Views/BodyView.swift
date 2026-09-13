import SwiftUI

/// The Body tab: heart rate right now, then every signal sorted into off your
/// usual and at your usual, with what Apple Health has not sent yet today.
struct BodyView: View {
    let viewModel: DashboardViewModel
    let liveViewModel: LiveViewModel
    @Binding var navigationPath: NavigationPath
    @Environment(\.scenePhase) private var scenePhase

    @State private var showProOverlay = false
    @State private var liveTracker = SectionTracker(section: .bodyLive, tab: .body)
    @State private var offTracker = SectionTracker(section: .bodyOffUsual, tab: .body)
    @State private var usualTracker = SectionTracker(section: .bodyAtUsual, tab: .body)

    /// The Live tab's paywall arguments, verbatim: `feature` keys the pro
    /// funnel events, so a new name here would split that funnel in two.
    private static let liveFeature = "Live Vitals"
    private static let liveIcon = "waveform.path.ecg"
    private static let liveDescription = "Monitor your heart rate, SpO2, activity rings, and readiness in real time."

    private var isLiveRowHidden: Bool { !UITestMode.isEnabled && RemoteConfigManager.shared.killLiveTab }
    private var isLiveRowLocked: Bool { (UITestMode.isEnabled && UITestMode.forceProLock) || !FeatureGate.canAccess(.liveTab) }
    private var streamsLive: Bool { !isLiveRowHidden && !isLiveRowLocked }

    var body: some View {
        let rows = BodyRowsBuilder.build(snapshot)
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                header

                if !isLiveRowHidden {
                    liveCard(rows.live)
                        .padding(.horizontal)
                        .onAppear { liveTracker.appeared() }
                        .onDisappear { liveTracker.disappeared() }
                }

                VStack(alignment: .leading, spacing: DS.space3) {
                    SectionHeaderView(icon: "arrow.up.arrow.down", title: Copy.Body.sectionOff)
                    if rows.off.isEmpty {
                        nothingOffRow
                    } else {
                        rowsCard(rows.off)
                    }
                }
                .onAppear { offTracker.appeared() }
                .onDisappear { offTracker.disappeared() }

                if !rows.usual.isEmpty {
                    VStack(alignment: .leading, spacing: DS.space3) {
                        SectionHeaderView(icon: "checkmark.circle", title: Copy.Body.sectionUsual)
                        rowsCard(rows.usual)
                    }
                    .onAppear { usualTracker.appeared() }
                    .onDisappear { usualTracker.disappeared() }
                }

                if !rows.notSynced.isEmpty {
                    notSyncedFooter(rows.notSynced)
                }

                Button(Copy.Body.healthStates) {
                    AppAnalytics.shared.trackBlockTap(title: "Health states", type: .bodyRow, screen: .body, metadata: ["row": "healthStates"])
                    navigationPath.append(Route.healthStateTimeline)
                }
                .buttonStyle(.dsTertiary)
                .padding(.horizontal)
                .accessibilityIdentifier("body.healthStates")
            }
            .padding(.bottom, DS.space5)
        }
        .contentMargins(.bottom, 72, for: .scrollContent)
        .accessibilityIdentifier("screen.body")
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showProOverlay) {
            ProFeatureOverlay(feature: Self.liveFeature, icon: Self.liveIcon, description: Self.liveDescription)
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.body, metadata: ["live_row": streamsLive])
            if streamsLive { liveViewModel.startStreaming() }
        }
        .onDisappear {
            if streamsLive { liveViewModel.stopStreaming() }
            AppAnalytics.shared.trackFeatureClose(.body)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard streamsLive else { return }
            if newPhase == .active {
                // Only restart after a true background return, not a brief
                // .inactive interruption (notification shade, Control Center).
                guard oldPhase == .background else { return }
                if liveViewModel.isStreaming {
                    liveViewModel.restartStreaming()
                } else {
                    liveViewModel.startStreaming()
                }
            } else if newPhase == .background, liveViewModel.isStreaming {
                liveViewModel.stopStreaming()
            }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.space1) {
            Text(Copy.Body.title)
                .font(DS.Typography.largeTitle)
            Text(Copy.Body.subtitle)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
        }
        .padding(.horizontal)
        .padding(.top, DS.space4)
    }

    @ViewBuilder
    private func liveCard(_ live: BodyRowsBuilder.LiveRow?) -> some View {
        let dotColor: Color = live.map { $0.isCalm ? AppColour.scoreGood : AppColour.scoreFair } ?? AppColour.stateDefault
        let card = HStack(spacing: DS.space3) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .background(Circle().fill(dotColor.opacity(DS.badgeBg)).frame(width: 18, height: 18))
            Text(live.map { Copy.Body.heartRateNow($0.bpm) } ?? Copy.Body.heartRateNowTitle)
                .font(DS.Typography.bodySemibold)
                .foregroundStyle(AppColour.textPrimary)
            if let live {
                Text(live.isCalm ? Copy.Body.calm : Copy.Body.elevated)
                    .font(DS.Typography.footnote)
                    .foregroundStyle(AppColour.textSecondary)
            }
            Spacer(minLength: DS.space2)
            if let live {
                Text(live.watchOn ? Copy.Body.watchOn : Copy.Body.watchOff)
                    .font(DS.Typography.caption)
                    .foregroundStyle(AppColour.textTertiary)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Body.heartRateNowTitle)

        if isLiveRowLocked {
            // Same treatment as a soft-locked Home card: blurred, one badge,
            // and any tap opens the Live tab's paywall overlay.
            card
                .blur(radius: 10)
                .allowsHitTesting(false)
                .overlay(
                    HStack(spacing: DS.space1) {
                        Image(systemName: "lock.fill")
                        Text(Copy.Home.softLockBadge)
                    }
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(AppColour.textSecondary)
                    .padding(.horizontal, DS.badgeH)
                    .padding(.vertical, DS.badgeV)
                    .background(Color.accentColor.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.Radius.full))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    AppAnalytics.shared.trackPremiumFeatureAttempted(feature: Self.liveFeature, screen: .body)
                    showProOverlay = true
                }
                .accessibilityIdentifier("body.liveRow.locked")
        } else {
            card
                .accessibilityIdentifier("body.liveRow")
        }
    }

    private func rowsCard(_ rows: [BodyRowsBuilder.Row]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                BodyRow(row: row) { open(row) }
                if row.id != rows.last?.id {
                    Divider().overlay(AppColour.borderLow)
                }
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
    }

    private var nothingOffRow: some View {
        HStack(spacing: DS.space2) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColour.scoreGood)
            Text(Copy.Body.nothingOff)
                .font(DS.Typography.bodyMedium)
                .foregroundStyle(AppColour.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(DS.cardPadding)
        .cardStyle()
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("body.nothingOff")
    }

    private func notSyncedFooter(_ names: [String]) -> some View {
        Button {
            openHealthAppForCoverage()
        } label: {
            (Text(Copy.Body.notSyncedPrefix + " " + names.joined(separator: Copy.Body.listSeparator))
                + Text(Copy.Body.notSyncedJoin)
                + Text(Copy.Body.openHealth).foregroundColor(AppColour.accent))
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .accessibilityIdentifier("body.notSynced")
    }

    // MARK: - Actions

    private func open(_ row: BodyRowsBuilder.Row) {
        AppAnalytics.shared.trackBlockTap(title: row.title, type: .bodyRow, screen: .body, metadata: ["row": row.id])
        if let route = row.route {
            navigationPath.append(route)
        } else if let metric = row.metric {
            navigationPath.append(metric)
        }
    }

    /// Opens the Health app so the user can fix a missing read permission.
    /// `x-apple-health://` is the public Health scheme; if the open fails the
    /// app settings screen is the fallback door. Never Laso's own settings.
    private func openHealthAppForCoverage() {
        AppAnalytics.shared.trackBlockTap(
            title: "Check Health settings",
            type: .errorRetry,
            screen: .body,
            metadata: ["source": "body_not_synced_line"]
        )
        guard let healthURL = URL(string: "x-apple-health://") else { return }
        UIApplication.shared.open(healthURL) { success in
            if !success, let settings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settings)
            }
        }
    }

    // MARK: - Inputs

    private var snapshot: BodyRowsBuilder.Snapshot {
        let series = viewModel.healthKitManager.timeSeries
        let baselines = viewModel.analysisEngine.baselines
        let recovery = liveViewModel.recovery
        let activity = liveViewModel.activity

        var latest: [HealthMetric: Double] = [:]
        for metric in [HealthMetric.sleepDuration, .heartRateVariability, .restingHeartRate, .vo2Max] {
            latest[metric] = series[metric]?.latestValue
        }
        // Overnight HRV and resting heart rate land on the live model before
        // the stored series is rebuilt, so they win when present.
        latest[.heartRateVariability] = recovery.latestHRV ?? latest[.heartRateVariability]
        latest[.restingHeartRate] = recovery.latestRestingHeartRate ?? latest[.restingHeartRate]
        // Zero before the first activity fetch is not a reading; zero after it is.
        if activity.hasAnyData {
            latest[.steps] = activity.todaySteps
            latest[.mindfulMinutes] = activity.todayMindfulMinutes
        }

        let hrr: (current: Double, baseline: UserBaseline)? = {
            guard let current = series[.heartRateRecovery]?.latestValue,
                  let baseline = baselines[.heartRateRecovery] else { return nil }
            return (current, baseline)
        }()

        let cycleTracker = viewModel.menstrualCycleTracker
        let cycle: (day: Int, phase: String)? = cycleTracker.isApplicable
            ? cycleTracker.currentCycle.map { ($0.dayInCycle, $0.currentPhase.displayName) }
            : nil

        return BodyRowsBuilder.Snapshot(
            now: Date(),
            baselines: baselines,
            latest: latest,
            sleepDebtHours: viewModel.sleepDebtTracker.currentDebt?.totalDebtHours,
            restDeficit: RecoveryAnalyzer.restDeficit(timeSeries: series, baselines: baselines),
            hrr: hrr,
            // Today's strain is still accumulating, so the six completed days
            // before it are the ones judged against the target.
            strainLast6: viewModel.strainScorer.weeklyStrainHistory.dropLast().suffix(6).map(\.strain),
            strainTarget: viewModel.strainCoach.currentTarget,
            stressLevel: recovery.stressLevel,
            vitalityAge: viewModel.vitalityScorer.vitalityAge,
            chronologicalAge: viewModel.vitalityScorer.chronologicalAge,
            cycle: cycle,
            heartRateNow: liveViewModel.vitals.currentHeartRate,
            isHeartRateCalm: liveViewModel.currentHeartRateZone == .rest,
            isWearingWatch: recovery.isWearingWatch,
            notSynced: notSyncedNames
        )
    }

    /// Sleep and resting heart rate get the friendlier names and the live
    /// model's own freshness checks; the rest come from today's coverage count.
    private var notSyncedNames: [String] {
        var names: [String] = []
        if !liveViewModel.sleep.hasSleepData {
            names.append(Copy.Body.lastNightSleep)
        }
        let rhrIsToday = liveViewModel.recovery.latestRestingHeartRateTimestamp.map(Date.cal.isDateInToday) ?? false
        if !rhrIsToday {
            names.append(Copy.Body.morningHeartRate)
        }
        // A zero-day window cuts off at the start of today, so a missing signal
        // here means no reading today rather than none in two weeks.
        names += viewModel.signalCoverage(window: 0)
            .filter { $0.isMissing && $0.metric != .sleepDuration && $0.metric != .restingHeartRate }
            .map(\.metric.displayName)
        return names
    }
}
