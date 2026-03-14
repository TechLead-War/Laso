import SwiftUI

// MARK: - Data Models

/// Level badge information passed from the gamification layer.
struct ProfileLevelBadge {
    let name: String
    let color: Color
}

/// 30-day performance summary data.
struct ThirtyDaySummary {
    let averageScore: Int
    let averageStrain: Double
    let averageSleep: Double          // hours
    let greenRecoveryDays: Int
    let yellowRecoveryDays: Int
    let redRecoveryDays: Int
    let totalActiveMinutes: Int

    var totalDays: Int {
        greenRecoveryDays + yellowRecoveryDays + redRecoveryDays
    }
}

/// Lifetime cumulative statistics.
struct AllTimeStats {
    let totalDaysTracked: Int
    let totalActivitiesLogged: Int
    let totalDistanceKm: Double
    let totalCaloriesBurned: Int
    let totalSleepHours: Double
    let bestSingleDayScore: Int
}

/// A single personal record entry.
struct PersonalRecord: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let date: Date
    let icon: String
    let tint: Color
}

/// A breakdown of a single workout/activity type.
struct ActivityTypeBreakdown: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let count: Int
    let averageStrain: Double
    let tint: Color
}

/// All data needed by PerformanceProfileView, passed as simple types.
struct PerformanceProfileData {
    let userName: String?
    let levelBadge: ProfileLevelBadge?
    let memberSince: Date?
    let vitalityAge: Int?
    let vitalityDelta: Int?               // negative = younger
    let thirtyDay: ThirtyDaySummary?
    let allTime: AllTimeStats?
    let personalRecords: [PersonalRecord]
    let activityBreakdown: [ActivityTypeBreakdown]
}

// MARK: - View

/// WHOOP-inspired performance profile showing a comprehensive summary of
/// the user's health journey: 30-day performance, all-time stats, personal
/// records, and activity breakdown.
struct PerformanceProfileView: View {
    let data: PerformanceProfileData

    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                headerSection
                    .padding(.horizontal)

                if let summary = data.thirtyDay {
                    thirtyDaySection(summary)
                        .padding(.horizontal)
                }

                if let allTime = data.allTime {
                    allTimeSection(allTime)
                        .padding(.horizontal)
                }

                if !data.personalRecords.isEmpty {
                    personalRecordsSection
                        .padding(.horizontal)
                }

                if !data.activityBreakdown.isEmpty {
                    activityBreakdownSection
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Performance Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareProfile()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Share profile")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ProfileShareSheet(items: [image])
            }
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.performanceProfile)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.performanceProfile)
        }
    }

    // MARK: - 1. Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            // Avatar placeholder
            Circle()
                .fill(.quaternary)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }

            // Name
            Text(data.userName ?? "Your Profile")
                .font(.title2.weight(.bold))

            // Level badge
            if let badge = data.levelBadge {
                Text(badge.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(badge.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(badge.color.opacity(DS.badgeBg), in: Capsule())
            }

            // Member since
            if let since = data.memberSince {
                Text("Member since \(formattedMemberDate(since))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Vitality age
            if let vAge = data.vitalityAge {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.caption.weight(.semibold))
                        Text("Vitality Age: \(vAge)")
                            .font(.subheadline.weight(.semibold))
                    }

                    if let delta = data.vitalityDelta, delta != 0 {
                        vitalityDeltaBadge(delta)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.cardPadding + 4)
        .cardStyle()
    }

    @ViewBuilder
    private func vitalityDeltaBadge(_ delta: Int) -> some View {
        let isYounger = delta < 0
        let text = isYounger
            ? "\(abs(delta)) year\(abs(delta) == 1 ? "" : "s") younger"
            : "\(delta) year\(delta == 1 ? "" : "s") older"
        let color: Color = isYounger ? .green : .red

        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(color.opacity(DS.badgeBg), in: Capsule())
    }

    // MARK: - 2. 30-Day Performance Summary

    private func thirtyDaySection(_ summary: ThirtyDaySummary) -> some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader("30-Day Performance", icon: "calendar", tint: .blue)

            // Score ring + grid
            HStack(spacing: 16) {
                // Score ring
                HealthScoreRing(
                    score: summary.averageScore,
                    label: "30d Avg",
                    size: 100,
                    lineWidth: 10
                )

                // 2x2 stats grid
                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        miniStat(
                            value: String(format: "%.1f", summary.averageStrain),
                            label: "Avg Strain",
                            icon: "flame.fill",
                            tint: .orange
                        )
                        Divider().frame(height: DS.dividerHeight)
                        miniStat(
                            value: String(format: "%.1f", summary.averageSleep) + "h",
                            label: "Avg Sleep",
                            icon: "bed.double.fill",
                            tint: .indigo
                        )
                    }
                    Divider()
                    HStack(spacing: 0) {
                        miniStat(
                            value: "\(summary.greenRecoveryDays)",
                            label: "Green Days",
                            icon: "checkmark.circle.fill",
                            tint: .green
                        )
                        Divider().frame(height: DS.dividerHeight)
                        miniStat(
                            value: formatMinutes(summary.totalActiveMinutes),
                            label: "Active",
                            icon: "figure.run",
                            tint: .cyan
                        )
                    }
                }
            }

            // Recovery distribution donut
            if summary.totalDays > 0 {
                recoveryDistribution(summary)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func miniStat(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func recoveryDistribution(_ summary: ThirtyDaySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recovery Distribution")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                // Donut chart
                ZStack {
                    donutSlice(
                        startAngle: 0,
                        endAngle: greenEndAngle(summary),
                        color: .green
                    )
                    donutSlice(
                        startAngle: greenEndAngle(summary),
                        endAngle: yellowEndAngle(summary),
                        color: .yellow
                    )
                    donutSlice(
                        startAngle: yellowEndAngle(summary),
                        endAngle: 360,
                        color: .red
                    )

                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 40, height: 40)
                }
                .frame(width: 64, height: 64)

                // Legend
                VStack(alignment: .leading, spacing: 6) {
                    recoveryLegendRow(
                        color: .green,
                        label: "Green",
                        count: summary.greenRecoveryDays,
                        total: summary.totalDays
                    )
                    recoveryLegendRow(
                        color: .yellow,
                        label: "Yellow",
                        count: summary.yellowRecoveryDays,
                        total: summary.totalDays
                    )
                    recoveryLegendRow(
                        color: .red,
                        label: "Red",
                        count: summary.redRecoveryDays,
                        total: summary.totalDays
                    )
                }

                Spacer()
            }
        }
        .padding(.top, 4)
    }

    private func greenEndAngle(_ s: ThirtyDaySummary) -> Double {
        guard s.totalDays > 0 else { return 0 }
        return Double(s.greenRecoveryDays) / Double(s.totalDays) * 360
    }

    private func yellowEndAngle(_ s: ThirtyDaySummary) -> Double {
        guard s.totalDays > 0 else { return 0 }
        return Double(s.greenRecoveryDays + s.yellowRecoveryDays) / Double(s.totalDays) * 360
    }

    private func donutSlice(startAngle: Double, endAngle: Double, color: Color) -> some View {
        Circle()
            .trim(
                from: startAngle / 360,
                to: endAngle / 360
            )
            .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .butt))
            .rotationEffect(.degrees(-90))
    }

    private func recoveryLegendRow(color: Color, label: String, count: Int, total: Int) -> some View {
        let pct = total > 0 ? Int(round(Double(count) / Double(total) * 100)) : 0
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2.weight(.medium))
                .frame(width: 44, alignment: .leading)
            Text("\(count) days")
                .font(.caption2.weight(.semibold).monospacedDigit())
            Text("(\(pct)%)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 3. All-Time Stats

    private func allTimeSection(_ stats: AllTimeStats) -> some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader("All-Time Stats", icon: "trophy.fill", tint: .yellow)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                allTimeStat(
                    value: formatLargeNumber(stats.totalDaysTracked),
                    label: "Days Tracked",
                    icon: "calendar.badge.checkmark",
                    tint: .blue
                )
                allTimeStat(
                    value: formatLargeNumber(stats.totalActivitiesLogged),
                    label: "Activities",
                    icon: "figure.mixed.cardio",
                    tint: .green
                )
                allTimeStat(
                    value: formatDistance(stats.totalDistanceKm),
                    label: "Distance",
                    icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                    tint: .orange
                )
                allTimeStat(
                    value: formatLargeNumber(stats.totalCaloriesBurned),
                    label: "Calories",
                    icon: "flame.fill",
                    tint: .red
                )
                allTimeStat(
                    value: formatLargeNumber(Int(stats.totalSleepHours)),
                    label: "Sleep Hours",
                    icon: "bed.double.fill",
                    tint: .indigo
                )
                allTimeStat(
                    value: "\(stats.bestSingleDayScore)",
                    label: "Best Score",
                    icon: "star.fill",
                    tint: .yellow
                )
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func allTimeStat(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 8))

            Text(value)
                .font(.headline.weight(.bold).monospacedDigit())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 4. Personal Records

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader("Personal Records", icon: "medal.fill", tint: .purple)

            ForEach(data.personalRecords) { record in
                personalRecordRow(record)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func personalRecordRow(_ record: PersonalRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: record.icon)
                .font(.body)
                .foregroundStyle(record.tint)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(record.tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.subheadline.weight(.semibold))

                Text(formattedRecordDate(record.date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(record.value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 5. Activity Breakdown

    private var activityBreakdownSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader("Activity Breakdown", icon: "chart.bar.fill", tint: .cyan)

            ForEach(data.activityBreakdown) { activity in
                activityRow(activity)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    private func activityRow(_ activity: ActivityTypeBreakdown) -> some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.body)
                .foregroundStyle(activity.tint)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(activity.tint.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(activity.count) session\(activity.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", activity.averageStrain))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                Text("avg strain")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    // MARK: - Share

    private func shareProfile() {
        let renderer = ImageRenderer(content: shareableProfileCard)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return }
        shareImage = image
        showShareSheet = true
    }

    private var shareableProfileCard: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Laso")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(formattedShareDate)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Name + level
            VStack(spacing: 6) {
                Text(data.userName ?? "My Profile")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                if let badge = data.levelBadge {
                    Text(badge.name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(badge.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(badge.color.opacity(0.2), in: Capsule())
                }
            }

            // Score ring
            if let summary = data.thirtyDay {
                ZStack {
                    Circle()
                        .stroke(DS.scoreColor(summary.averageScore).opacity(0.2), lineWidth: 10)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: Double(summary.averageScore) / 100.0)
                        .stroke(
                            DS.scoreColor(summary.averageScore),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 100)

                    VStack(spacing: 1) {
                        Text("\(summary.averageScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("30d Avg")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            // Stats row
            if let allTime = data.allTime {
                HStack(spacing: 0) {
                    shareStatPill("\(allTime.totalDaysTracked)", "Days")
                    shareStatPill(formatDistance(allTime.totalDistanceKm), "km")
                    shareStatPill(formatLargeNumber(allTime.totalCaloriesBurned), "Cal")
                }
            }

            Spacer()

            Text("Track your health with Laso")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(24)
        .frame(width: 390, height: 520)
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.12, blue: 0.2), Color(red: 0.05, green: 0.06, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func shareStatPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatters

    private func formattedMemberDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func formattedRecordDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private var formattedShareDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date())
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hrs = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h"
        }
        return "\(minutes)m"
    }

    private func formatLargeNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        }
        if number >= 10_000 {
            return "\(number / 1000)k"
        }
        if number >= 1_000 {
            return String(format: "%.1fk", Double(number) / 1000)
        }
        return "\(number)"
    }

    private func formatDistance(_ km: Double) -> String {
        if km >= 1000 {
            return String(format: "%.0fk", km / 1000)
        }
        if km >= 100 {
            return String(format: "%.0f", km)
        }
        return String(format: "%.1f", km)
    }
}

// MARK: - Share Sheet (UIKit bridge)

private struct ProfileShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#Preview("Full Profile") {
    NavigationStack {
        PerformanceProfileView(data: PerformanceProfileData(
            userName: "Alex",
            levelBadge: ProfileLevelBadge(name: "Gold", color: .yellow),
            memberSince: Calendar.current.date(byAdding: .month, value: -8, to: Date()),
            vitalityAge: 29,
            vitalityDelta: -3,
            thirtyDay: ThirtyDaySummary(
                averageScore: 74,
                averageStrain: 12.4,
                averageSleep: 7.2,
                greenRecoveryDays: 14,
                yellowRecoveryDays: 10,
                redRecoveryDays: 6,
                totalActiveMinutes: 1845
            ),
            allTime: AllTimeStats(
                totalDaysTracked: 243,
                totalActivitiesLogged: 186,
                totalDistanceKm: 412.8,
                totalCaloriesBurned: 198400,
                totalSleepHours: 1720,
                bestSingleDayScore: 96
            ),
            personalRecords: [
                PersonalRecord(
                    title: "Highest Daily Steps",
                    value: "24,312",
                    date: Calendar.current.date(byAdding: .day, value: -45, to: Date())!,
                    icon: "figure.walk",
                    tint: .green
                ),
                PersonalRecord(
                    title: "Longest Sleep",
                    value: "9h 42m",
                    date: Calendar.current.date(byAdding: .day, value: -12, to: Date())!,
                    icon: "bed.double.fill",
                    tint: .indigo
                ),
                PersonalRecord(
                    title: "Best HRV",
                    value: "98 ms",
                    date: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
                    icon: "waveform.path.ecg",
                    tint: .red
                ),
                PersonalRecord(
                    title: "Most Active Day",
                    value: "1,842 cal",
                    date: Calendar.current.date(byAdding: .day, value: -60, to: Date())!,
                    icon: "flame.fill",
                    tint: .orange
                ),
            ],
            activityBreakdown: [
                ActivityTypeBreakdown(name: "Walking", icon: "figure.walk", count: 84, averageStrain: 6.2, tint: .green),
                ActivityTypeBreakdown(name: "Running", icon: "figure.run", count: 42, averageStrain: 14.8, tint: .orange),
                ActivityTypeBreakdown(name: "Cycling", icon: "figure.outdoor.cycle", count: 28, averageStrain: 12.1, tint: .cyan),
                ActivityTypeBreakdown(name: "Strength", icon: "dumbbell.fill", count: 32, averageStrain: 10.5, tint: .purple),
            ]
        ))
    }
}

#Preview("Minimal Profile") {
    NavigationStack {
        PerformanceProfileView(data: PerformanceProfileData(
            userName: nil,
            levelBadge: nil,
            memberSince: nil,
            vitalityAge: nil,
            vitalityDelta: nil,
            thirtyDay: nil,
            allTime: nil,
            personalRecords: [],
            activityBreakdown: []
        ))
    }
}
