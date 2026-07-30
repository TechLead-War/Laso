import SwiftUI
import Charts

struct LiveHeartRateSection: View {
    let vitals: LiveViewModel.VitalsData
    let currentHeartRateZone: LiveViewModel.HeartRateZone
    let heartRateZonePercent: CGFloat
    var heartRateTracker: SectionTracker
    @Binding var maxScrollDepth: Int

    // Local to this card: a beat pulse held on LiveView re-ran the whole tab's
    // body twice per heartbeat.
    @State private var pulseScale: CGFloat = 1.0
    @State private var lastAnimationTime: Date = .distantPast

    private var isHeartRateStale: Bool {
        !vitals.isHeartRateFresh && vitals.heartRateTimestamp != nil
    }

    var body: some View {
        Button {
            AppAnalytics.shared.trackBlockTap(
                title: "Heart Rate Hero",
                type: .heartRateHeroCard,
                screen: .live,
                metadata: [
                    "metric_id": HealthMetric.heartRate.rawValue,
                    "heart_rate": Int(vitals.currentHeartRate ?? 0),
                    "zone": currentHeartRateZone.rawValue
                ]
            )
            heartRateTracker.tapped(target: "heart_rate_hero")
        } label: {
        VStack(spacing: 0) {
            // Top: pulsing heart + big number + zone
            HStack(alignment: .top, spacing: 16) {
                // Animated pulsing heart. stops pulsing when stale
                ZStack {
                    Circle()
                        .fill(AppColour.categoryHeart.opacity(isHeartRateStale ? 0.05 : 0.1))
                        .frame(width: 64, height: 64)
                        .scaleEffect(isHeartRateStale ? 1.0 : pulseScale)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(AppColour.categoryHeart.opacity(isHeartRateStale ? 0.4 : 1.0))
                        .scaleEffect(isHeartRateStale ? 1.0 : pulseScale)
                }
                .onChange(of: vitals.currentHeartRate) {
                    guard vitals.isHeartRateFresh else { return }
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
                        if let hr = vitals.currentHeartRate {
                            Text(String(format: "%.0f", hr))
                                .font(DS.Typography.displayXL)
                                .foregroundStyle(AppColour.textPrimary.opacity(isHeartRateStale ? 0.4 : 1.0))
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.3), value: hr)
                                .postHogMask()

                            Text(Copy.Live.bpm)
                                .font(DS.Typography.title3)
                                .foregroundStyle(AppColour.textSecondary.opacity(isHeartRateStale ? 0.5 : 1.0))
                        } else {
                            Text(Copy.Live.syncing)
                                .font(DS.Typography.title2)
                                .foregroundStyle(AppColour.textTertiary)
                        }
                    }

                    // Stale: show prominent "Last Reading X ago" instead of zone
                    if isHeartRateStale {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Copy.Live.lastReading)
                                .font(DS.Typography.captionSemibold)
                                .foregroundStyle(AppColour.textOnAccent)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(AppColour.surfaceMuted, in: Capsule())

                            if let ts = vitals.heartRateTimestamp {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(DS.Typography.caption2)
                                    Text(ts, style: .relative)
                                        .font(DS.Typography.captionMedium)
                                    Text(Copy.Live.ago)
                                        .font(DS.Typography.captionMedium)
                                }
                                .foregroundStyle(AppColour.textSecondary)
                            }
                        }
                    } else {
                        // Zone badge. only shown when data is fresh
                        HStack(spacing: 6) {
                            Text(currentHeartRateZone.rawValue)
                                .font(DS.Typography.captionSemibold)
                                .foregroundStyle(AppColour.textOnAccent)
                                .padding(.horizontal, DS.badgeH)
                                .padding(.vertical, DS.badgeV)
                                .background(currentHeartRateZone.color, in: Capsule())

                            if let ts = vitals.heartRateTimestamp {
                                Text(ts, style: .relative)
                                    .font(DS.Typography.caption2)
                                    .foregroundStyle(AppColour.textTertiary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(DS.cardPadding)

            // Zone bar. gradient from blue to red
            zoneProgressBar
                .padding(.horizontal)

            // Session stats: Min / Avg / Max (30 min)
            if vitals.heartRateMin30 != nil {
                HStack(spacing: 0) {
                    sessionStatCell(label: "Min", value: vitals.heartRateMin30, unit: "bpm", color: AppColour.info)
                    Divider().frame(height: DS.dividerHeight)
                    sessionStatCell(label: "Avg", value: vitals.heartRateAvg30, unit: "bpm", color: AppColour.textPrimary)
                    Divider().frame(height: DS.dividerHeight)
                    sessionStatCell(label: "Max", value: vitals.heartRateMax30, unit: "bpm", color: AppColour.danger)
                }
                .padding(.vertical, DS.space2)
            }

            // Today's range
            if let minHR = vitals.todayHeartRateMin, let maxHR = vitals.todayHeartRateMax {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(DS.Typography.caption2)
                    Text(Copy.Live.todayBpmText(Int(minHR), Int(maxHR)))
                        .font(DS.Typography.caption2)
                        .postHogMask()
                }
                .foregroundStyle(AppColour.textTertiary)
                .padding(.bottom, DS.space2)
            }

            // Mini chart. last 30 minutes
            if vitals.recentHeartRates.count > 1 {
                heartRateMiniChart
                    .padding(.horizontal)
                    .padding(.bottom, DS.space3)
            }
        }
        .cardStyle(tint: AppColour.categoryHeart)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(heartRateAccessibilityLabel)
        .sensoryFeedback(.warning, trigger: vitals.heartRateStatus == .elevated)
        .onAppear { heartRateTracker.appeared(); maxScrollDepth = max(maxScrollDepth, 20) }
        .onDisappear { heartRateTracker.disappeared() }
        } // end label
        .buttonStyle(.dsPress)
        .padding(.horizontal)
    }

    private var heartRateAccessibilityLabel: String {
        let hr = vitals.currentHeartRate.map { "\(Int($0)) beats per minute" } ?? "no data"
        let zone = currentHeartRateZone.rawValue
        let stats = [
            vitals.heartRateMin30.map { "minimum \(Int($0))" },
            vitals.heartRateAvg30.map { "average \(Int($0))" },
            vitals.heartRateMax30.map { "maximum \(Int($0))" }
        ].compactMap { $0 }.joined(separator: ", ")
        return "Heart rate \(hr), zone \(zone)\(stats.isEmpty ? "" : ", last 30 minutes \(stats)")"
    }

    private var zoneProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(AppColour.trackNeutral)

                // Active fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppColour.info, currentHeartRateZone.color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * heartRateZonePercent)

                // Indicator dot
                Circle()
                    .fill(AppColour.markerOnSurface)
                    .frame(width: 10, height: 10)
                    .shadow(color: AppColour.shadowAmbient, radius: 3)
                    .offset(x: max(0, geo.size.width * heartRateZonePercent - 5))
            }
        }
        .frame(height: 8)
    }

    private func sessionStatCell(label: String, value: Double?, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            if let value {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(String(format: "%.0f", value))
                        .font(DS.Typography.subheadlineSemibold.monospacedDigit())
                        .foregroundStyle(color)
                        .postHogMask()
                    Text(unit)
                        .font(DS.Typography.caption2)
                        .foregroundStyle(AppColour.textTertiary)
                }
            } else {
                Text(Copy.Live.x)
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(AppColour.textQuaternary)
            }
            Text(label)
                .font(DS.Typography.caption2)
                .foregroundStyle(AppColour.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var heartRateMiniChart: some View {
        Chart {
            ForEach(vitals.recentHeartRates, id: \.date) { entry in
                LineMark(
                    x: .value("Time", entry.date),
                    y: .value("BPM", entry.value)
                )
                .foregroundStyle(AppColour.categoryHeart)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
                // Per-point VoiceOver readout. Note the parent
                // hero button uses children:.ignore so these are exposed only
                // when the chart is read directly (e.g., via Accessibility
                // Inspector or future flat-mode VoiceOver navigation).
                .accessibilityLabel(Text(entry.date.formatted(date: .omitted, time: .shortened)))
                .accessibilityValue(Text(Copy.Live.beatsPerMinuteText(Int(entry.value))))

                AreaMark(
                    x: .value("Time", entry.date),
                    y: .value("BPM", entry.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColour.categoryHeart.opacity(0.3), AppColour.chartAreaFill],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                .accessibilityHidden(true)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
                            .font(DS.Typography.caption2)
                            .foregroundStyle(AppColour.textTertiary)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(AppColour.chartGridline)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(Copy.Live.xText(Int(v)))
                            .font(DS.Typography.caption2)
                            .foregroundStyle(AppColour.textTertiary)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(AppColour.chartGridline)
            }
        }
        .frame(height: 90)
        .padding(.top, DS.space1)
    }
}
