import SwiftUI

/// Real-time health dashboard — live vitals, heart rate zones, activity rings, readiness
struct LiveView: View {
    let viewModel: LiveViewModel
    let mlOrchestrator: MLOrchestrator?
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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LiveHeaderSection(
                    isStreaming: viewModel.isStreaming,
                    hasFreshData: viewModel.vitals.hasFreshData,
                    isAging: viewModel.vitals.isAging,
                    isStale: viewModel.vitals.isStale,
                    hasAnyVitalData: viewModel.vitals.hasAnyData,
                    currentHeartRate: viewModel.vitals.currentHeartRate,
                    headerTracker: headerTracker
                )

                if !viewModel.vitals.hasAnyData && !viewModel.activity.hasAnyData && viewModel.lastUpdate == nil && !viewModel.isStreaming {
                    // No data at all and not streaming — full empty state
                    LiveWaitingForDataView(isStreaming: viewModel.isStreaming)
                } else if viewModel.vitals.isStale && !viewModel.isStreaming {
                    // Stale vitals with no active stream — show wear-your-watch prompt
                    LiveStaleVitalsPrompt(vitals: viewModel.vitals)
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
                    // Show full UI immediately — values fill in as they arrive.
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
            .padding(.bottom, 20)
        }
        .accessibilityIdentifier("screen.live")
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Warm restart: keep existing data visible while new queries spin up.
                // This avoids the blank-flash that full stop→start causes.
                if viewModel.isStreaming {
                    viewModel.restartStreaming()
                } else {
                    viewModel.startStreaming()
                }
            } else if newPhase == .background {
                // Only stop streaming on full background — not on .inactive (which fires
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
    LiveView(viewModel: LiveViewModel(healthKitManager: HealthKitManager()), mlOrchestrator: nil)
}
