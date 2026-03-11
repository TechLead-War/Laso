import SwiftUI
import Charts

// MARK: - Strain Balance

enum StrainBalance: String {
    case under = "Under-Training"
    case optimal = "Optimal"
    case overreaching = "Overreaching"

    var color: Color {
        switch self {
        case .under: return .blue
        case .optimal: return .green
        case .overreaching: return .red
        }
    }

    var icon: String {
        switch self {
        case .under: return "arrow.down.circle.fill"
        case .optimal: return "checkmark.circle.fill"
        case .overreaching: return "exclamationmark.triangle.fill"
        }
    }

    var description: String {
        switch self {
        case .under: return "Your strain is below your target range. Consider increasing activity to maintain fitness."
        case .optimal: return "You're training within your ideal strain range for your current recovery."
        case .overreaching: return "Your strain exceeds your recovery capacity. Prioritize rest and lighter sessions."
        }
    }
}

// MARK: - Daily Strain Point

struct DailyStrainPoint: Identifiable {
    let id = UUID()
    let date: Date
    let strain: Double
    let level: StrainLevel
}

// MARK: - Strain Detail View

/// Full detail view for strain analysis, showing today's strain ring, HR zone breakdown,
/// strain coach guidance, 7-day history, and strain balance indicator.
struct StrainDetailView: View {
    let strainValue: Double
    let strainLevel: StrainLevel
    let zoneMinutes: [Int: Double]
    let targetStrainRange: ClosedRange<Double>
    let trainingZone: String
    let guidanceText: String
    let weekHistory: [DailyStrainPoint]
    let strainBalance: StrainBalance

    /// Max strain on the 0-21 scale
    private let maxStrain: Double = 21.0

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        min(strainValue / maxStrain, 1.0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                // 1. Hero section
                heroSection

                // 2. Strain balance indicator
                balanceSection

                // 3. Strain Coach
                coachSection

                // 4. HR Zone breakdown
                zoneBreakdownSection

                // 5. 7-day history
                if !weekHistory.isEmpty {
                    historySection
                }

                // 6. Disclaimer
                disclaimerNote
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Strain")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.strainDetail)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.strainDetail)
        }
    }

    // MARK: - 1. Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Large strain ring
            ZStack {
                Circle()
                    .stroke(strainLevel.color.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(strainLevel.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: animatedProgress)

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", strainValue))
                        .font(.system(size: 40, weight: .bold, design: .rounded))

                    Text("of 21")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear { animatedProgress = progress }
            .onChange(of: strainValue) { animatedProgress = progress }

            // Strain level badge
            Text(strainLevel.rawValue)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(strainLevel.color, in: Capsule())

            // Scale reference
            HStack(spacing: 0) {
                ForEach(StrainLevel.allCases, id: \.rawValue) { level in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level.color)
                            .frame(height: 4)

                        Text(level.rawValue)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(strainGradient, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(strainLevel.color.opacity(DS.strokeAlpha * 2), lineWidth: 1)
        )
        .shadow(color: strainLevel.color.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal)
    }

    private var strainGradient: LinearGradient {
        LinearGradient(
            colors: [strainLevel.color.opacity(0.28), strainLevel.color.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - 2. Strain Balance

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "scale.3d", title: "Strain Balance")

            HStack(spacing: 12) {
                Image(systemName: strainBalance.icon)
                    .font(.title2)
                    .foregroundStyle(strainBalance.color)
                    .frame(width: 44, height: 44)
                    .background(strainBalance.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(strainBalance.rawValue)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(strainBalance.color)

                    Text(strainBalance.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle(tint: strainBalance.color)
            .padding(.horizontal)
        }
    }

    // MARK: - 3. Strain Coach

    private var coachSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "figure.run", title: "Strain Coach")

            VStack(spacing: 12) {
                // Target strain range
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(.tint, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Strain")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 4) {
                            Text(String(format: "%.1f", targetStrainRange.lowerBound))
                                .font(.title3.weight(.bold).monospacedDigit())
                            Text("-")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", targetStrainRange.upperBound))
                                .font(.title3.weight(.bold).monospacedDigit())
                        }
                    }

                    Spacer()

                    // Whether current is within target
                    if targetStrainRange.contains(strainValue) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: strainValue < targetStrainRange.lowerBound ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }
                }

                Divider()

                // Training zone
                HStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(.pink, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended Zone")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(trainingZone)
                            .font(.subheadline.weight(.semibold))
                    }

                    Spacer()
                }

                Divider()

                // Guidance text
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "text.bubble.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(.indigo, in: Circle())

                    Text(guidanceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    // MARK: - 4. HR Zone Breakdown

    private var zoneBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "heart.text.square.fill", title: "Heart Rate Zones")

            VStack(spacing: 0) {
                ForEach(1...5, id: \.self) { zone in
                    zoneRow(zone: zone)

                    if zone < 5 {
                        Divider()
                            .padding(.leading, DS.cardPadding + 40 + 10)
                    }
                }
            }
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private func zoneRow(zone: Int) -> some View {
        let minutes = zoneMinutes[zone] ?? 0
        let totalMinutes = max((1...5).compactMap({ zoneMinutes[$0] }).reduce(0, +), 1)
        let fraction = minutes / totalMinutes

        return HStack(spacing: 10) {
            // Zone label circle
            Text("Z\(zone)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(zoneColor(zone), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(zoneName(zone))
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text(formatMinutes(minutes))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(zoneColor(zone))
                }

                // Bar visualization
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(zoneColor(zone).opacity(0.15))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(zoneColor(zone))
                            .frame(width: max(geo.size.width * CGFloat(fraction), 4), height: 6)
                    }
                }
                .frame(height: 6)

                Text("\(Int(fraction * 100))% of total time")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 11)
    }

    // MARK: - 5. 7-Day History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "calendar", title: "7-Day History")

            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(weekHistory) { point in
                        BarMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Strain", point.strain)
                        )
                        .foregroundStyle(point.level.color.gradient)
                        .cornerRadius(4)
                    }

                    // Target range band
                    RuleMark(y: .value("Target Low", targetStrainRange.lowerBound))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

                    RuleMark(y: .value("Target High", targetStrainRange.upperBound))
                        .foregroundStyle(.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartYScale(domain: 0...21)
                .chartYAxis {
                    AxisMarks(values: [0, 7, 14, 21]) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        AxisGridLine()
                    }
                }
                .frame(height: 180)

                // Chart legend
                HStack(spacing: 16) {
                    ForEach([StrainLevel.low, .moderate, .high, .overreaching], id: \.rawValue) { level in
                        HStack(spacing: 4) {
                            Circle().fill(level.color).frame(width: 6, height: 6)
                            Text(level.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Average
                let avgStrain = weekHistory.map(\.strain).reduce(0, +) / max(Double(weekHistory.count), 1)
                HStack(spacing: 6) {
                    Text("7-Day Average:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", avgStrain))
                        .font(.caption.weight(.bold).monospacedDigit())
                    Text(StrainLevel(strain: avgStrain).rawValue)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(StrainLevel(strain: avgStrain).color)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(StrainLevel(strain: avgStrain).color.opacity(DS.badgeBg), in: Capsule())
                }
            }
            .padding(DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    // MARK: - 6. Disclaimer

    private var disclaimerNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text("Strain is calculated from cardiovascular load using heart rate data. It is not a medical measurement. Consult your doctor before making changes to your exercise routine.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal)
    }

    private func zoneColor(_ zone: Int) -> Color {
        switch zone {
        case 1: return .blue
        case 2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }

    private func zoneName(_ zone: Int) -> String {
        switch zone {
        case 1: return "Active Recovery"
        case 2: return "Fat Burn"
        case 3: return "Aerobic"
        case 4: return "Threshold"
        case 5: return "Anaerobic"
        default: return "Zone \(zone)"
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        if h > 0 {
            return "\(h)h \(String(format: "%02d", m))m"
        }
        return "\(m)m"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StrainDetailView(
            strainValue: 14.2,
            strainLevel: .high,
            zoneMinutes: [1: 45, 2: 30, 3: 22, 4: 15, 5: 8],
            targetStrainRange: 10.0...16.0,
            trainingZone: "Zone 2-3 (Aerobic Base)",
            guidanceText: "Your recovery supports moderate-to-high strain today. Focus on sustained aerobic work in Zone 2-3 for optimal cardiovascular benefit without overreaching.",
            weekHistory: [
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -6, to: .now)!, strain: 8.5, level: .moderate),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -5, to: .now)!, strain: 12.3, level: .moderate),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -4, to: .now)!, strain: 15.8, level: .high),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -3, to: .now)!, strain: 5.2, level: .low),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!, strain: 11.0, level: .moderate),
                DailyStrainPoint(date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!, strain: 18.9, level: .overreaching),
                DailyStrainPoint(date: .now, strain: 14.2, level: .high)
            ],
            strainBalance: .optimal
        )
    }
}
