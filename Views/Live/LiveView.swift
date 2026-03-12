import SwiftUI
import Charts

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
                headerSection

                if !viewModel.vitals.hasAnyData && !viewModel.activity.hasAnyData && viewModel.lastUpdate == nil && !viewModel.isStreaming {
                    // No data at all and not streaming — full empty state
                    waitingForDataView
                } else if viewModel.vitals.isStale && !viewModel.isStreaming {
                    // Stale vitals with no active stream — show wear-your-watch prompt
                    staleVitalsPrompt
                    activityRingsSection
                    lastWorkoutCard
                    statusFooter
                } else {
                    // Show full UI immediately — values fill in as they arrive.
                    // When streaming without vitals yet, show activity first + a loading indicator.
                    heartRateHeroCard
                    vitalSignsRow
                    activityRingsSection
                    bloodPressureAndTempRow
                    lastWorkoutCard
                    statusFooter
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

    // MARK: - Stale Vitals Prompt

    private var staleVitalsPrompt: some View {
        VStack(spacing: 16) {
            // Wear your watch CTA
            VStack(spacing: 12) {
                Image(systemName: DeviceMessaging.deviceIcon)
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)

                Text(DeviceMessaging.wearPromptTitle)
                    .font(.title3.weight(.semibold))

                Text(DeviceMessaging.staleVitalsMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.orange.opacity(0.15), lineWidth: 0.5)
            )
            .padding(.horizontal)

            // Last known readings — compact muted row
            if viewModel.vitals.hasAnyData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Last Known Readings")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        if let hr = viewModel.vitals.currentHeartRate {
                            staleReadingPill(
                                icon: "heart.fill",
                                color: .red,
                                value: "\(Int(hr))",
                                unit: "bpm",
                                timestamp: viewModel.vitals.heartRateTimestamp
                            )
                        }
                        if let spo2 = viewModel.vitals.currentBloodOxygen {
                            staleReadingPill(
                                icon: "drop.fill",
                                color: .blue,
                                value: "\(Int(spo2))",
                                unit: "%",
                                timestamp: viewModel.vitals.bloodOxygenTimestamp
                            )
                        }
                        if let rr = viewModel.vitals.currentRespiratoryRate {
                            staleReadingPill(
                                icon: "wind",
                                color: .teal,
                                value: "\(Int(rr))",
                                unit: "br/m",
                                timestamp: viewModel.vitals.respiratoryRateTimestamp
                            )
                        }
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
            }
        }
    }

    private func staleReadingPill(icon: String, color: Color, value: String, unit: String, timestamp: Date?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.6))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if let ts = timestamp {
                Text(ts, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Waiting for Data (Empty State)

    private var waitingForDataView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: DeviceMessaging.deviceIcon)
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, isActive: viewModel.isStreaming)

            VStack(spacing: 8) {
                Text("Waiting for Live Data")
                    .font(.title3.weight(.semibold))

                Text(DeviceMessaging.ensurePairedMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Tips
            VStack(alignment: .leading, spacing: 12) {
                tipRow(icon: DeviceMessaging.deviceIcon, text: "Wear your \(DeviceMessaging.deviceName) snugly")
                tipRow(icon: "bluetooth", text: "Keep Bluetooth enabled on iPhone")
                tipRow(icon: "heart.fill", text: "Open a workout or check your heart rate on the Watch")
                tipRow(icon: "arrow.clockwise", text: "Recent data may take a moment to sync")
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Waiting for live data from \(DeviceMessaging.deviceName). Make sure your device is paired and worn.")
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live")
                    .font(.largeTitle.bold())

                HStack(spacing: 6) {
                    Circle()
                        .fill(viewModel.vitals.hasFreshData ? .green : (viewModel.vitals.isAging ? .yellow : (viewModel.vitals.isStale ? .orange : .gray)))
                        .frame(width: 8, height: 8)
                        .shadow(color: viewModel.vitals.hasFreshData ? .green.opacity(0.6) : .clear, radius: 4)

                    Text(liveStatusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if viewModel.isStreaming && !viewModel.vitals.hasFreshData {
                ProgressView()
                    .controlSize(.small)
                    .tint(.secondary)
            } else {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, isActive: viewModel.vitals.hasFreshData)
            }
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .onAppear { headerTracker.appeared() }
        .onDisappear { headerTracker.disappeared() }
    }


    private var liveStatusLabel: String {
        if viewModel.vitals.hasFreshData {
            return "Streaming"
        } else if viewModel.vitals.isAging {
            return "Updating..."
        } else if viewModel.isStreaming {
            return "Refreshing..."
        } else if viewModel.vitals.isStale {
            return "Wear your watch"
        } else {
            return "Connecting..."
        }
    }

    // MARK: - Heart Rate Hero

    private var isHeartRateStale: Bool {
        !viewModel.vitals.isHeartRateFresh && viewModel.vitals.heartRateTimestamp != nil
    }

    private var heartRateHeroCard: some View {
        VStack(spacing: 0) {
            // Top: pulsing heart + big number + zone
            HStack(alignment: .top, spacing: 16) {
                // Animated pulsing heart — stops pulsing when stale
                ZStack {
                    Circle()
                        .fill(.red.opacity(isHeartRateStale ? 0.05 : 0.1))
                        .frame(width: 64, height: 64)
                        .scaleEffect(isHeartRateStale ? 1.0 : pulseScale)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.red.opacity(isHeartRateStale ? 0.4 : 1.0))
                        .scaleEffect(isHeartRateStale ? 1.0 : pulseScale)
                }
                .onChange(of: viewModel.vitals.currentHeartRate) {
                    guard viewModel.vitals.isHeartRateFresh else { return }
                    guard Date.now.timeIntervalSince(lastAnimationTime) >= 1.0 else { return }
                    lastAnimationTime = .now
                    withAnimation(.easeInOut(duration: 0.15)) {
                        pulseScale = 1.15
                    }
                    withAnimation(.easeInOut(duration: 0.3).delay(0.15)) {
                        pulseScale = 1.0
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    // BPM
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if let hr = viewModel.vitals.currentHeartRate {
                            Text(String(format: "%.0f", hr))
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(isHeartRateStale ? 0.4 : 1.0))
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.3), value: hr)

                            Text("bpm")
                                .font(.title3)
                                .foregroundStyle(.secondary.opacity(isHeartRateStale ? 0.5 : 1.0))
                        } else {
                            Text("Syncing")
                                .font(.title2.weight(.medium))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Stale: show prominent "Last Reading X ago" instead of zone
                    if isHeartRateStale {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last Reading")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(.gray, in: Capsule())

                            if let ts = viewModel.vitals.heartRateTimestamp {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text(ts, style: .relative)
                                        .font(.caption.weight(.medium))
                                    Text("ago")
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        // Zone badge — only shown when data is fresh
                        HStack(spacing: 6) {
                            Text(viewModel.currentHeartRateZone.rawValue)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(viewModel.currentHeartRateZone.color, in: Capsule())

                            if let ts = viewModel.vitals.heartRateTimestamp {
                                Text(ts, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(DS.cardPadding)

            // Zone bar — gradient from blue to red
            zoneProgressBar
                .padding(.horizontal)

            // Session stats: Min / Avg / Max (30 min)
            if viewModel.vitals.heartRateMin30 != nil {
                HStack(spacing: 0) {
                    sessionStatCell(label: "Min", value: viewModel.vitals.heartRateMin30, unit: "bpm", color: .blue)
                    Divider().frame(height: DS.dividerHeight)
                    sessionStatCell(label: "Avg", value: viewModel.vitals.heartRateAvg30, unit: "bpm", color: .primary)
                    Divider().frame(height: DS.dividerHeight)
                    sessionStatCell(label: "Max", value: viewModel.vitals.heartRateMax30, unit: "bpm", color: .red)
                }
                .padding(.vertical, 10)
            }

            // Today's range
            if let minHR = viewModel.vitals.todayHeartRateMin, let maxHR = viewModel.vitals.todayHeartRateMax {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("Today: \(Int(minHR))–\(Int(maxHR)) bpm")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
            }

            // Mini chart — last 30 minutes
            if viewModel.vitals.recentHeartRates.count > 1 {
                heartRateMiniChart
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
        }
        .cardStyle(tint: .red)
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heartRateAccessibilityLabel)
        .sensoryFeedback(.warning, trigger: viewModel.vitals.heartRateStatus == .elevated)
        .onAppear { heartRateTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 20) }
        .onDisappear { heartRateTracker.disappeared() }
        .onTapGesture {
            AppAnalytics.shared.trackBlockTap(
                title: "Heart Rate Hero",
                type: .heartRateHeroCard,
                screen: .live,
                metadata: [
                    "metric_id": HealthMetric.heartRate.rawValue,
                    "heart_rate": Int(viewModel.vitals.currentHeartRate ?? 0),
                    "zone": viewModel.currentHeartRateZone.rawValue
                ]
            )
            heartRateTracker.tapped(target: "heart_rate_hero")
        }
    }

    private var heartRateAccessibilityLabel: String {
        let hr = viewModel.vitals.currentHeartRate.map { "\(Int($0)) beats per minute" } ?? "no data"
        let zone = viewModel.currentHeartRateZone.rawValue
        let stats = [
            viewModel.vitals.heartRateMin30.map { "minimum \(Int($0))" },
            viewModel.vitals.heartRateAvg30.map { "average \(Int($0))" },
            viewModel.vitals.heartRateMax30.map { "maximum \(Int($0))" }
        ].compactMap { $0 }.joined(separator: ", ")
        return "Heart rate \(hr), zone \(zone)\(stats.isEmpty ? "" : ", last 30 minutes \(stats)")"
    }

    private var zoneProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background gradient bar
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(0.2)

                // Active fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, viewModel.currentHeartRateZone.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * viewModel.heartRateZonePercent)

                // Indicator dot
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .shadow(color: viewModel.currentHeartRateZone.color.opacity(0.5), radius: 3)
                    .offset(x: max(0, geo.size.width * viewModel.heartRateZonePercent - 5))
            }
        }
        .frame(height: 8)
    }

    private func sessionStatCell(label: String, value: Double?, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(String(format: "%.0f", value))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("···")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.quaternary)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var heartRateMiniChart: some View {
        Chart {
            ForEach(viewModel.vitals.recentHeartRates, id: \.date) { entry in
                LineMark(
                    x: .value("Time", entry.date),
                    y: .value("BPM", entry.value)
                )
                .foregroundStyle(.red.opacity(0.7))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Time", entry.date),
                    y: .value("BPM", entry.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red.opacity(0.15), .red.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 10)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.hour().minute())
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .frame(height: 80)
    }

    // MARK: - Vital Signs Row

    private var vitalSignsRow: some View {
        HStack(spacing: 12) {
            vitalCard(
                icon: "drop.fill",
                iconColor: .blue,
                label: "SpO2",
                value: viewModel.vitals.currentBloodOxygen.map { String(format: "%.0f", $0) },
                unit: "%",
                timestamp: viewModel.vitals.bloodOxygenTimestamp,
                status: viewModel.vitals.bloodOxygenStatus,
                isFresh: viewModel.vitals.isBloodOxygenFresh
            )

            vitalCard(
                icon: "wind",
                iconColor: .teal,
                label: "Resp Rate",
                value: viewModel.vitals.currentRespiratoryRate.map { String(format: "%.0f", $0) },
                unit: "br/min",
                timestamp: viewModel.vitals.respiratoryRateTimestamp,
                status: viewModel.vitals.respiratoryRateStatus,
                isFresh: viewModel.vitals.isRespiratoryRateFresh,
                isUnavailable: viewModel.vitals.respiratoryRateUnavailable,
                unavailableHint: "Measured during sleep"
            )
        }
        .padding(.horizontal)
        .onAppear { vitalsTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 45) }
        .onDisappear { vitalsTracker.disappeared() }
    }

    private func vitalCard(
        icon: String,
        iconColor: Color,
        label: String,
        value: String?,
        unit: String,
        timestamp: Date?,
        status: LiveViewModel.VitalStatus,
        isFresh: Bool = true,
        isUnavailable: Bool = false,
        unavailableHint: String? = nil
    ) -> some View {
        let isStale = !isFresh && timestamp != nil
        let blockType: BlockType? = {
            switch label {
            case "SpO2": return .vitalCardSpo2
            case "Resp Rate": return .vitalCardRespRate
            default: return nil
            }
        }()

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iconColor.opacity(isStale ? 0.5 : 1.0))

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if isUnavailable && value == nil {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No data")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tertiary)
                    if let hint = unavailableHint {
                        Text(hint)
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                }
            } else if let value {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary.opacity(isStale ? 0.4 : 1.0))
                        .contentTransition(.numericText())

                    Text(unit)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary.opacity(isStale ? 0.5 : 1.0))
                }
            } else {
                Text("Syncing")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
            }

            if isStale {
                // Prominent stale timestamp
                if let ts = timestamp {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(ts, style: .relative)
                            .font(.caption2.weight(.medium))
                        Text("ago")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    if status != .unknown {
                        Circle()
                            .fill(status.color)
                            .frame(width: 6, height: 6)
                        Text(status.label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(status.color)
                    }

                    Spacer()

                    if let ts = timestamp {
                        Text(ts, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
        .padding(DS.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value ?? "no data") \(unit), \(status.label)")
        .onTapGesture {
            guard let blockType else { return }
            let metricId: String = label == "SpO2" ? HealthMetric.bloodOxygen.rawValue : HealthMetric.respiratoryRate.rawValue
            AppAnalytics.shared.trackBlockTap(
                title: label,
                type: blockType,
                screen: .live,
                metadata: [
                    "metric_id": metricId,
                    "status": status.label,
                    "is_stale": isStale ? 1 : 0
                ]
            )
            vitalsTracker.tapped(target: label.lowercased().replacingOccurrences(of: " ", with: "_"))
        }
    }

    // MARK: - Activity Rings

    private var isActivityAllZeros: Bool {
        viewModel.activity.todayActiveCalories == 0 && viewModel.activity.todayExerciseMinutes == 0 && viewModel.activity.todayStandHours == 0
    }

    private var activityRingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Rings")
                .font(.headline)
                .padding(.horizontal)

            if isActivityAllZeros && Calendar.current.component(.hour, from: Date()) < 10 {
                HStack(spacing: 12) {
                    Image(systemName: "figure.stand")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No activity yet")
                            .font(.subheadline.weight(.medium))
                        Text("Your rings will fill as you move throughout the day.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
            } else {

            HStack(spacing: 16) {
                // Triple ring
                ZStack {
                    // Stand (outer) — cyan
                    ringArc(progress: viewModel.activity.standProgress, color: .cyan, size: 90, lineWidth: 8)
                    // Exercise (middle) — green
                    ringArc(progress: viewModel.activity.exerciseProgress, color: .green, size: 70, lineWidth: 8)
                    // Move (inner) — pink
                    ringArc(progress: viewModel.activity.moveProgress, color: .pink, size: 50, lineWidth: 8)
                }
                .frame(width: 100, height: 100)

                // Labels
                VStack(alignment: .leading, spacing: 10) {
                    ringLabel(
                        color: .pink,
                        label: "Move",
                        value: "\(Int(viewModel.activity.todayActiveCalories))/\(Int(viewModel.activity.moveGoal)) kcal",
                        progress: viewModel.activity.moveProgress
                    )
                    ringLabel(
                        color: .green,
                        label: "Exercise",
                        value: "\(Int(viewModel.activity.todayExerciseMinutes))/\(Int(viewModel.activity.exerciseGoal)) min",
                        progress: viewModel.activity.exerciseProgress
                    )
                    ringLabel(
                        color: .cyan,
                        label: "Stand",
                        value: "\(Int(viewModel.activity.todayStandHours))/\(Int(viewModel.activity.standGoal)) hrs",
                        progress: viewModel.activity.standProgress
                    )
                }

                Spacer()
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Activity rings. Move: \(Int(viewModel.activity.todayActiveCalories)) of \(Int(viewModel.activity.moveGoal)) calories, \(Int(viewModel.activity.moveProgress * 100)) percent. Exercise: \(Int(viewModel.activity.todayExerciseMinutes)) of \(Int(viewModel.activity.exerciseGoal)) minutes, \(Int(viewModel.activity.exerciseProgress * 100)) percent. Stand: \(Int(viewModel.activity.todayStandHours)) of \(Int(viewModel.activity.standGoal)) hours, \(Int(viewModel.activity.standProgress * 100)) percent.")
            .onTapGesture {
                AppAnalytics.shared.trackBlockTap(
                    title: "Activity Rings",
                    type: .activityRingsSection,
                    screen: .live,
                    metadata: [
                        "metric_id": "activity_rings",
                        "move_progress": Int(viewModel.activity.moveProgress * 100),
                        "exercise_progress": Int(viewModel.activity.exerciseProgress * 100),
                        "stand_progress": Int(viewModel.activity.standProgress * 100)
                    ]
                )
                activityTracker.tapped(target: "activity_rings")
            }

            // Quick stats row
            HStack(spacing: 12) {
                quickStatPill(
                    icon: "figure.walk",
                    value: formatLargeNumber(viewModel.activity.todaySteps),
                    label: "Steps",
                    color: .green,
                    blockType: .quickStatSteps
                )
                quickStatPill(
                    icon: "location.fill",
                    value: String(format: "%.1f km", viewModel.activity.todayDistance),
                    label: "Distance",
                    color: .blue,
                    blockType: .quickStatDistance
                )
                quickStatPill(
                    icon: "figure.stairs",
                    value: "\(Int(viewModel.activity.todayFlightsClimbed))",
                    label: "Flights",
                    color: .purple,
                    blockType: .quickStatFlights
                )
            }
            .padding(.horizontal)
            .onAppear { quickStatsTracker.appeared() }
            .onDisappear { quickStatsTracker.disappeared() }

            } // end else (has activity)
        }
        .onAppear { activityTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 65) }
        .onDisappear { activityTracker.disappeared() }
    }

    private func ringArc(progress: Double, color: Color, size: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
        }
    }

    private func ringLabel(color: Color, label: String, value: String, progress: Double) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)

            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)

            Spacer()

            Text("\(Int(progress * 100))%")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private func quickStatPill(icon: String, value: String, label: String, color: Color, blockType: BlockType) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(DS.tintBg), in: RoundedRectangle(cornerRadius: DS.cardRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .onTapGesture {
            let metricId: String = switch blockType {
            case .quickStatSteps: HealthMetric.steps.rawValue
            case .quickStatDistance: HealthMetric.distanceWalkingRunning.rawValue
            case .quickStatFlights: HealthMetric.flightsClimbed.rawValue
            default: "unknown"
            }
            AppAnalytics.shared.trackBlockTap(
                title: label,
                type: blockType,
                screen: .live,
                metadata: [
                    "metric_id": metricId,
                    "value": value
                ]
            )
            quickStatsTracker.tapped(target: label.lowercased())
        }
    }

    // MARK: - Blood Pressure & Temperature

    @ViewBuilder
    private var bloodPressureAndTempRow: some View {
        let hasBP = viewModel.vitals.latestSystolic != nil
        let hasTemp = viewModel.vitals.latestBodyTemp != nil

        if hasBP || hasTemp {
            HStack(spacing: 12) {
                if let sys = viewModel.vitals.latestSystolic, let dia = viewModel.vitals.latestDiastolic {
                    // Blood Pressure card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.purple)
                            Text("Blood Pressure")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(sys))/\(Int(dia))")
                                .font(.title2.weight(.bold).monospacedDigit())
                            Text("mmHg")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 4) {
                            Circle()
                                .fill(viewModel.vitals.bloodPressureStatus.color)
                                .frame(width: 6, height: 6)
                            Text(viewModel.vitals.bloodPressureStatus.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(viewModel.vitals.bloodPressureStatus.color)
                        }
                    }
                    .padding(DS.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .onTapGesture {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Blood Pressure",
                            type: .bloodPressureCard,
                            screen: .live,
                            metadata: [
                                "metric_id": "blood_pressure",
                                "systolic": Int(sys),
                                "diastolic": Int(dia)
                            ]
                        )
                        bpTempTracker.tapped(target: "blood_pressure")
                    }
                }

                if let temp = viewModel.vitals.latestBodyTemp {
                    // Temperature card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "thermometer.medium")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                            Text("Temperature")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", temp))
                                .font(.title2.weight(.bold).monospacedDigit())
                            Text("°C")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        if let ts = viewModel.vitals.bodyTempTimestamp {
                            Text(ts, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(DS.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .onTapGesture {
                        AppAnalytics.shared.trackBlockTap(
                            title: "Temperature",
                            type: .temperatureCard,
                            screen: .live,
                            metadata: [
                                "metric_id": HealthMetric.bodyTemperature.rawValue,
                                "value_c": temp
                            ]
                        )
                        bpTempTracker.tapped(target: "temperature")
                    }
                }
            }
            .padding(.horizontal)
            .onAppear { bpTempTracker.appeared() }
            .onDisappear { bpTempTracker.disappeared() }
        }
    }

    // MARK: - Last Workout

    @ViewBuilder
    private var lastWorkoutCard: some View {
        if let type = viewModel.workout.lastWorkoutType {
            VStack(alignment: .leading, spacing: 12) {
                Text("Last Workout")
                    .font(.headline)
                    .padding(.horizontal)

                HStack(spacing: 14) {
                    // Workout icon
                    Image(systemName: "figure.run")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.green)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(.green.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(type)
                            .font(.subheadline.weight(.semibold))

                        HStack(spacing: 12) {
                            if let dur = viewModel.workout.lastWorkoutDuration {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text("\(Int(dur)) min")
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.secondary)
                            }

                            if let cal = viewModel.workout.lastWorkoutCalories {
                                HStack(spacing: 3) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                    Text("\(Int(cal)) kcal")
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    if let ts = viewModel.workout.lastWorkoutTimestamp {
                        Text(ts, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle()
                .padding(.horizontal)
                .onTapGesture {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Last Workout",
                        type: .lastWorkoutCard,
                        screen: .live,
                        metadata: [
                            "workout_type": type,
                            "duration_min": Int(viewModel.workout.lastWorkoutDuration ?? 0),
                            "calories": Int(viewModel.workout.lastWorkoutCalories ?? 0)
                        ]
                    )
                    workoutTracker.tapped(target: "last_workout")
                }
            }
            .onAppear { workoutTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 90) }
            .onDisappear { workoutTracker.disappeared() }
        }
    }

    // MARK: - Status Footer

    private var statusFooter: some View {
        Group {
            if let lastUpdate = viewModel.lastUpdate {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.caption2)
                    Text("Last signal \(lastUpdate, style: .relative) ago")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Helpers

    private func formatLargeNumber(_ value: Double) -> String {
        if value >= 10000 {
            return String(format: "%.0fk", value / 1000)
        } else if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

#Preview {
    LiveView(viewModel: LiveViewModel(healthKitManager: HealthKitManager()), mlOrchestrator: nil)
}
