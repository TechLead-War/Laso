import SwiftUI

/// Real-time health dashboard. live vitals, heart rate zones, activity rings, readiness
struct LiveView: View {
    let viewModel: LiveViewModel
    let mlOrchestrator: MLOrchestrator?
    let deviceSourceManager: DeviceSourceManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var pulseScale: CGFloat = 1.0
    @State private var previousZone: LiveViewModel.HeartRateZone?
    @State private var hasTrackedFirstData = false
    @State private var lastAnimationTime: Date = .distantPast
    @State private var maxScrollDepth: Int = 0

    // Section trackers
    @State private var headerTracker = SectionTracker(section: .liveHeader, tab: .live)
    @State private var heartRateTracker = SectionTracker(section: .liveHeartRate, tab: .live)
    @State private var vitalsTracker = SectionTracker(section: .liveVitals, tab: .live)
    @State private var activityTracker = SectionTracker(section: .liveActivity, tab: .live)
    @State private var quickStatsTracker = SectionTracker(section: .liveQuickStats, tab: .live)
    @State private var bpTempTracker = SectionTracker(section: .liveBloodPressureTemperature, tab: .live)
    @State private var workoutTracker = SectionTracker(section: .liveWorkout, tab: .live)

    private let liveMetrics: Set<HealthMetric> = [.heartRate, .bloodOxygen, .respiratoryRate]

    private var primaryLiveSource: ConnectedDeviceInfo? {
        deviceSourceManager.connectedDevices.first { info in
            info.device != .iPhone &&
            info.device != .generic &&
            !info.metricsProvided.isDisjoint(with: liveMetrics)
        }
    }

    private var primaryLiveDevice: SupportedDevice? {
        primaryLiveSource?.device
    }

    private var hasLiveSource: Bool {
        primaryLiveSource != nil
    }

    private var hasSupplementalSections: Bool {
        viewModel.activity.hasAnyData || viewModel.workout.lastWorkoutType != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                LiveHeaderSection(
                    isStreaming: viewModel.isStreaming,
                    hasFreshData: viewModel.vitals.hasFreshData,
                    isAging: viewModel.vitals.isAging,
                    isStale: viewModel.vitals.isStale,
                    primaryDevice: primaryLiveDevice,
                    headerTracker: headerTracker
                )

                if !viewModel.vitals.hasAnyData {
                    LiveWaitingForDataView(
                        isStreaming: viewModel.isStreaming,
                        primaryDevice: primaryLiveDevice,
                        hasLiveSource: hasLiveSource
                    )
                    if hasSupplementalSections {
                        LiveActivitySection(
                            activity: viewModel.activity,
                            activityTracker: activityTracker,
                            quickStatsTracker: quickStatsTracker,
                            maxScrollDepth: $maxScrollDepth
                        )
                        LiveWorkoutSection(
                            workout: viewModel.workout,
                            workoutTracker: workoutTracker,
                            maxScrollDepth: $maxScrollDepth
                        )
                    }
                    if hasSupplementalSections || viewModel.lastUpdate != nil {
                        LiveStatusFooter(lastUpdate: viewModel.lastUpdate)
                    }
                } else if viewModel.vitals.isStale && !viewModel.isStreaming {
                    LiveStaleVitalsPrompt(
                        vitals: viewModel.vitals,
                        primaryDevice: primaryLiveDevice
                    )
                    LiveActivitySection(
                        activity: viewModel.activity,
                        activityTracker: activityTracker,
                        quickStatsTracker: quickStatsTracker,
                        maxScrollDepth: $maxScrollDepth
                    )
                    LiveWorkoutSection(
                        workout: viewModel.workout,
                        workoutTracker: workoutTracker,
                        maxScrollDepth: $maxScrollDepth
                    )
                    LiveStatusFooter(lastUpdate: viewModel.lastUpdate)
                } else {
                    // Show full UI immediately. values fill in as they arrive.
                    // When streaming without vitals yet, show activity first + a loading indicator.
                    LiveHeartRateSection(
                        vitals: viewModel.vitals,
                        currentHeartRateZone: viewModel.currentHeartRateZone,
                        heartRateZonePercent: viewModel.heartRateZonePercent,
                        heartRateTracker: heartRateTracker,
                        maxScrollDepth: $maxScrollDepth,
                        pulseScale: $pulseScale,
                        lastAnimationTime: $lastAnimationTime
                    )
                    LiveVitalsSection(
                        vitals: viewModel.vitals,
                        vitalsTracker: vitalsTracker,
                        maxScrollDepth: $maxScrollDepth
                    )
                    LiveActivitySection(
                        activity: viewModel.activity,
                        activityTracker: activityTracker,
                        quickStatsTracker: quickStatsTracker,
                        maxScrollDepth: $maxScrollDepth
                    )
                    LiveBloodPressureTempSection(
                        vitals: viewModel.vitals,
                        bpTempTracker: bpTempTracker
                    )
                    LiveWorkoutSection(
                        workout: viewModel.workout,
                        workoutTracker: workoutTracker,
                        maxScrollDepth: $maxScrollDepth
                    )
                    LiveStatusFooter(lastUpdate: viewModel.lastUpdate)
                }
            }
            .padding(.bottom, DS.space5)
        }
        .contentMargins(.bottom, 72, for: .scrollContent)
        .accessibilityIdentifier("screen.live")
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.startStreaming()
            AppAnalytics.shared.trackFeatureOpen(.live, metadata: [
                "has_heart_rate": viewModel.vitals.currentHeartRate != nil,
                "is_streaming": viewModel.isStreaming
            ])
            AppAnalytics.shared.trackStreamingStarted()
            AppAnalytics.shared.trackActivationMilestone(.firstLiveSession)
            AppAnalytics.shared.trackCoreAction(.usedLiveTab, screen: .live)
            AppAnalytics.shared.trackLastMeaningfulAction(action: "used_live_tab", screen: .live)
        }
        .onDisappear {
            viewModel.stopStreaming()
            if maxScrollDepth > 0 {
                AppAnalytics.shared.trackScrollDepth(screen: .live, maxDepthPercent: maxScrollDepth)
            }
            AppAnalytics.shared.trackFeatureClose(.live)
            AppAnalytics.shared.trackStreamingStopped()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Only restart after a true background return. Avoid restarting on
                // brief .inactive interruptions (notification shade, Control Center).
                guard oldPhase == .background else { return }
                if viewModel.isStreaming {
                    viewModel.restartStreaming()
                } else {
                    viewModel.startStreaming()
                }
            } else if newPhase == .background {
                // Only stop streaming on full background. not on .inactive (which fires
                // for brief interruptions like notification banners or control center).
                if viewModel.isStreaming {
                    viewModel.stopStreaming()
                }
            }
        }
        .onChange(of: viewModel.vitals.hasAnyData) { _, hasData in
            if hasData && !hasTrackedFirstData {
                hasTrackedFirstData = true
                AppAnalytics.shared.trackLiveFirstDataReceived()
            }
        }
        .onChange(of: viewModel.currentHeartRateZone) { _, newZone in
            previousZone = newZone
        }
        .sensoryFeedback(.success, trigger: viewModel.vitals.hasAnyData)
    }
}

#Preview {
    LiveView(
        viewModel: LiveViewModel(healthKitManager: HealthKitManager()),
        mlOrchestrator: nil,
        deviceSourceManager: DeviceSourceManager(healthStore: .init())
    )
}
