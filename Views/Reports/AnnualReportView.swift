import SwiftUI
import Charts

// MARK: - Data Models

/// Summary statistics for an entire year of health tracking
struct AnnualStats {
    let totalActiveDays: Int
    let totalExerciseHours: Double
    let totalDistanceKm: Double
    let averageDailySteps: Int
    let averageSleepHours: Double
    let sleepOver7HoursPercent: Double
}

/// A single category's annual performance summary
struct AnnualCategoryScore: Identifiable {
    var id: String { category.rawValue }
    let category: HealthCategory
    let averageScore: Int
    let trend: TrendDirection
}

/// A notable health discovery made during the year
struct AnnualDiscovery: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let category: HealthCategory
    let month: Int
}

/// A personal record or milestone achieved during the year
struct AnnualRecord: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
}

// MARK: - Annual Report View

/// Full-screen annual performance assessment presenting a comprehensive year-in-review
/// of the user's health data, scores, discoveries, and milestones.
struct AnnualReportView: View {
    let year: Int
    let monthlyScores: [(month: Int, score: Int)]
    let annualStats: AnnualStats
    let categoryScores: [AnnualCategoryScore]
    let discoveries: [AnnualDiscovery]
    let records: [AnnualRecord]

    /// Overall annual score — average of all monthly scores
    var overallScore: Int {
        guard !monthlyScores.isEmpty else { return 0 }
        return monthlyScores.map(\.score).reduce(0, +) / monthlyScores.count
    }

    /// Optional vitality age at start and end of year
    var vitalityAgeStart: Int?
    var vitalityAgeEnd: Int?

    /// Best streak (consecutive active days) achieved during the year
    var streakRecord: Int = 0

    /// Previous year's average score for year-over-year comparison (nil if < 2 years of data)
    var previousYearScore: Int?

    /// Suggested focus areas for next year based on weakest categories
    var focusAreas: [String] = []

    /// Total insights generated and data points analyzed during the year
    var totalInsightsGenerated: Int = 0
    var totalDataPointsAnalyzed: Int = 0

    @State private var isShareSheetPresented = false
    @State private var shareImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                heroSection
                annualStatsSection
                scoreJourneySection
                categorySummarySection
                topDiscoveriesSection
                milestonesSection
                lookingAheadSection
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("\(String(year)) Year in Review")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    renderAndShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Share annual report")
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let image = shareImage {
                ShareSheetRepresentable(items: [image])
            }
        }
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.annualReport)
        }
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.annualReport)
        }
    }

    // MARK: - 1. Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Year label
            Text("\(String(year)) Year in Review")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)

            // Large score ring
            HealthScoreRing(
                score: overallScore,
                label: "Annual Score",
                size: 160,
                lineWidth: 14
            )

            // Vitality age comparison
            if let start = vitalityAgeStart, let end = vitalityAgeEnd {
                vitalityAgeRow(start: start, end: end)
            }

            // Streak record
            if streakRecord > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                    Text("\(streakRecord)-day streak record")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func vitalityAgeRow(start: Int, end: Int) -> some View {
        let delta = start - end
        let improved = delta > 0

        return HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("Jan")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(start)")
                    .font(.title3.weight(.bold).monospacedDigit())
            }

            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)

            VStack(spacing: 2) {
                Text("Dec")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("\(end)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(improved ? .green : (delta < 0 ? .red : .primary))
            }

            Spacer()

            if delta != 0 {
                Text(improved ? "\(delta)y younger" : "\(abs(delta))y older")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(improved ? .green : .red)
                    .padding(.horizontal, DS.badgeH + 4)
                    .padding(.vertical, DS.badgeV + 2)
                    .background((improved ? Color.green : Color.red).opacity(DS.badgeBg), in: Capsule())
            }
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 2. Annual Stats

    private var annualStatsSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(title: "Annual Stats", icon: "chart.bar.fill", color: .blue)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                annualStatCell(
                    value: "\(annualStats.totalActiveDays)",
                    label: "Active Days",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                annualStatCell(
                    value: formatHours(annualStats.totalExerciseHours),
                    label: "Exercise Hours",
                    icon: "flame.fill",
                    color: .orange
                )
                annualStatCell(
                    value: formatDistance(annualStats.totalDistanceKm),
                    label: "Distance (km)",
                    icon: "figure.walk",
                    color: .cyan
                )
                annualStatCell(
                    value: formatSteps(annualStats.averageDailySteps),
                    label: "Avg Steps/Day",
                    icon: "shoe.fill",
                    color: .purple
                )
                annualStatCell(
                    value: String(format: "%.1fh", annualStats.averageSleepHours),
                    label: "Avg Sleep",
                    icon: "bed.double.fill",
                    color: .indigo
                )
                annualStatCell(
                    value: "\(Int(annualStats.sleepOver7HoursPercent))%",
                    label: "7+ Hour Nights",
                    icon: "moon.stars.fill",
                    color: .blue
                )
            }
            .padding(DS.cardPadding)
            .cardStyle()
        }
    }

    private func annualStatCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 8))

            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 3. Score Journey

    private var scoreJourneySection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(title: "Score Journey", icon: "chart.xyaxis.line", color: .green)

            // Monthly score chart
            if !monthlyScores.isEmpty {
                monthlyScoreChart
                    .padding(DS.cardPadding)
                    .cardStyle()
            }

            // Best / worst month + YoY
            HStack(spacing: DS.itemSpacing) {
                if let best = bestMonth {
                    monthHighlightCard(
                        label: "Best Month",
                        month: best.month,
                        score: best.score,
                        color: .green,
                        icon: "arrow.up.circle.fill"
                    )
                }

                if let worst = worstMonth {
                    monthHighlightCard(
                        label: "Worst Month",
                        month: worst.month,
                        score: worst.score,
                        color: .red,
                        icon: "arrow.down.circle.fill"
                    )
                }
            }

            // Year-over-year trend
            if let prevScore = previousYearScore {
                yearOverYearCard(currentScore: overallScore, previousScore: prevScore)
            }
        }
    }

    private var monthlyScoreChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Averages")
                .font(.subheadline.weight(.semibold))

            Chart {
                ForEach(monthlyScores, id: \.month) { entry in
                    LineMark(
                        x: .value("Month", monthAbbreviation(entry.month)),
                        y: .value("Score", entry.score)
                    )
                    .foregroundStyle(DS.scoreColor(overallScore).gradient)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Month", monthAbbreviation(entry.month)),
                        y: .value("Score", entry.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DS.scoreColor(overallScore).opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Month", monthAbbreviation(entry.month)),
                        y: .value("Score", entry.score)
                    )
                    .foregroundStyle(DS.scoreColor(entry.score))
                    .symbolSize(isExtremMonth(entry.month) ? 60 : 30)
                    .annotation(position: .top, spacing: 4) {
                        if isExtremMonth(entry.month) {
                            Text("\(entry.score)")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(DS.scoreColor(entry.score))
                        }
                    }
                }
            }
            .chartYScale(domain: chartYDomain)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
        }
    }

    private func monthHighlightCard(label: String, month: Int, score: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(monthName(month))
                .font(.subheadline.weight(.semibold))

            Text("\(score)")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(DS.scoreColor(score))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle(tint: color)
    }

    private func yearOverYearCard(currentScore: Int, previousScore: Int) -> some View {
        let delta = currentScore - previousScore
        let improved = delta > 0

        return HStack(spacing: 12) {
            Image(systemName: improved ? "arrow.up.forward.circle.fill" : "arrow.down.forward.circle.fill")
                .font(.title3)
                .foregroundStyle(improved ? .green : .red)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background((improved ? Color.green : Color.red).opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 2) {
                Text("Year over Year")
                    .font(.subheadline.weight(.semibold))
                Text("\(year - 1) avg: \(previousScore) \u{2192} \(year) avg: \(currentScore)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(improved ? "+" : "")\(delta)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(improved ? .green : .red)
                .padding(.horizontal, DS.badgeH + 4)
                .padding(.vertical, DS.badgeV + 2)
                .background((improved ? Color.green : Color.red).opacity(DS.badgeBg), in: Capsule())
        }
        .padding(DS.cardPadding)
        .cardStyle()
    }

    // MARK: - 4. Category Summary

    private var categorySummarySection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(title: "Category Summary", icon: "square.grid.2x2.fill", color: .purple)

            VStack(spacing: 0) {
                let sorted = categoryScores.sorted { $0.averageScore < $1.averageScore }
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                    categoryRow(item, isMostImproved: mostImprovedCategory?.category == item.category)

                    if index < sorted.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
            .cardStyle()

            // Most improved highlight
            if let improved = mostImprovedCategory {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(Color.yellow.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Most Improved")
                            .font(.subheadline.weight(.semibold))
                        Text("\(improved.category.displayName) showed the most improvement this year")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HealthScoreRing(
                        score: improved.averageScore,
                        label: "",
                        size: 36,
                        lineWidth: 4
                    )
                }
                .padding(DS.cardPadding)
                .cardStyle(tint: .yellow)
            }
        }
    }

    private func categoryRow(_ item: AnnualCategoryScore, isMostImproved: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.category.systemImageName)
                .font(.title3)
                .foregroundStyle(item.category.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.category.displayName)
                        .font(.body.weight(.medium))

                    if isMostImproved {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                TrendBadge(direction: item.trend)
            }

            Spacer()

            HealthScoreRing(
                score: item.averageScore,
                label: "",
                size: 36,
                lineWidth: 4
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 5. Top Discoveries

    private var topDiscoveriesSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(title: "Top Discoveries", icon: "lightbulb.fill", color: .yellow)

            ForEach(Array(discoveries.prefix(5))) { discovery in
                discoveryCard(discovery)
            }
        }
    }

    private func discoveryCard(_ discovery: AnnualDiscovery) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: discovery.category.systemImageName)
                .font(.caption)
                .foregroundStyle(discovery.category.color)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(discovery.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(discovery.title)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text(monthAbbreviation(discovery.month))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.badgeH)
                        .padding(.vertical, DS.badgeV)
                        .background(Color.secondary.opacity(0.1), in: Capsule())
                }

                Text(discovery.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(DS.cardPadding)
        .cardStyle(tint: discovery.category.color)
    }

    // MARK: - 6. Milestones & Records

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(title: "Milestones & Records", icon: "trophy.fill", color: .orange)

            // Records list
            ForEach(records) { record in
                HStack(spacing: 12) {
                    Image(systemName: record.icon)
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: DS.iconSize, height: DS.iconSize)
                        .background(Color.orange.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title)
                            .font(.subheadline.weight(.semibold))
                        Text(record.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(DS.cardPadding)
                .cardStyle()
            }

            // Summary stats row
            HStack(spacing: 0) {
                milestoneStat(value: "\(streakRecord)", label: "Best Streak", icon: "flame.fill")
                Divider().frame(height: DS.dividerHeight)
                milestoneStat(value: formatCount(totalInsightsGenerated), label: "Insights", icon: "lightbulb.fill")
                Divider().frame(height: DS.dividerHeight)
                milestoneStat(value: formatCount(totalDataPointsAnalyzed), label: "Data Points", icon: "chart.dots.scatter")
            }
            .padding(.vertical, 12)
            .cardStyle()
        }
    }

    private func milestoneStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.orange)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 7. Looking Ahead

    private var lookingAheadSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            sectionHeader(title: "Looking Ahead to \(String(year + 1))", icon: "sparkles", color: .cyan)

            // Opportunity areas from weakest categories
            let weakest = categoryScores.sorted { $0.averageScore < $1.averageScore }.prefix(3)

            if !weakest.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Biggest Opportunities")
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(weakest)) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.category.systemImageName)
                                .font(.caption)
                                .foregroundStyle(item.category.color)
                                .frame(width: 28, height: 28)
                                .background(item.category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category.displayName)
                                    .font(.subheadline.weight(.medium))
                                Text("Average score: \(item.averageScore) \u{2014} \(opportunityMessage(for: item.averageScore))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(item.averageScore)")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(DS.scoreColor(item.averageScore))
                        }
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle(tint: .cyan)
            }

            // Suggested focus areas
            if !focusAreas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Focus Areas")
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(focusAreas.enumerated()), id: \.offset) { index, area in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(.cyan, in: Circle())

                            Text(area)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(DS.cardPadding)
                .cardStyle()
            }

            // Closing motivational line
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.red)

                Text("Here's to a healthier \(String(year + 1))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }

    // MARK: - Sharing

    private func renderAndShare() {
        let reportCard = ShareableAnnualReportCard(
            year: year,
            overallScore: overallScore,
            totalActiveDays: annualStats.totalActiveDays,
            totalExerciseHours: annualStats.totalExerciseHours,
            averageSleepHours: annualStats.averageSleepHours,
            streakRecord: streakRecord
        )
        let renderer = ImageRenderer(content: reportCard)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return }
        shareImage = image
        isShareSheetPresented = true
    }

    // MARK: - Computed Helpers

    private var bestMonth: (month: Int, score: Int)? {
        monthlyScores.max(by: { $0.score < $1.score })
    }

    private var worstMonth: (month: Int, score: Int)? {
        monthlyScores.min(by: { $0.score < $1.score })
    }

    private var mostImprovedCategory: AnnualCategoryScore? {
        categoryScores.first(where: { $0.trend == .improving })
    }

    private func isExtremMonth(_ month: Int) -> Bool {
        month == bestMonth?.month || month == worstMonth?.month
    }

    private var chartYDomain: ClosedRange<Int> {
        let scores = monthlyScores.map(\.score)
        let minScore = max(0, (scores.min() ?? 0) - 10)
        let maxScore = min(100, (scores.max() ?? 100) + 10)
        return minScore...maxScore
    }

    // MARK: - Formatters

    private func monthAbbreviation(_ month: Int) -> String {
        let formatter = DateFormatter()
        guard month >= 1, month <= 12 else { return "" }
        return formatter.shortMonthSymbols[month - 1]
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        guard month >= 1, month <= 12 else { return "" }
        return formatter.monthSymbols[month - 1]
    }

    private func formatHours(_ hours: Double) -> String {
        if hours >= 1000 { return "\(Int(hours / 100) * 100)" }
        if hours >= 100 { return "\(Int(hours))" }
        return String(format: "%.0f", hours)
    }

    private func formatDistance(_ km: Double) -> String {
        if km >= 10_000 { return String(format: "%.0fk", km / 1000) }
        if km >= 1_000 { return String(format: "%.1fk", km / 1000) }
        return String(format: "%.0f", km)
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 10_000 { return String(format: "%.0fk", Double(steps) / 1000) }
        if steps >= 1_000 { return String(format: "%.1fk", Double(steps) / 1000) }
        return "\(steps)"
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 10_000 { return String(format: "%.0fk", Double(count) / 1000) }
        if count >= 1_000 { return String(format: "%.1fk", Double(count) / 1000) }
        return "\(count)"
    }

    private func opportunityMessage(for score: Int) -> String {
        switch score {
        case 80...100: return "keep up the great work"
        case 60..<80: return "small improvements can make a big difference"
        case 40..<60: return "significant room for growth"
        default: return "a priority area for next year"
        }
    }
}

// MARK: - UIKit Share Sheet

/// Wraps UIActivityViewController for SwiftUI presentation via .sheet
private struct ShareSheetRepresentable: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Shareable Card for Social Sharing

/// A compact, visually rich card rendered for image-based sharing of the annual report.
private struct ShareableAnnualReportCard: View {
    let year: Int
    let overallScore: Int
    let totalActiveDays: Int
    let totalExerciseHours: Double
    let averageSleepHours: Double
    let streakRecord: Int

    private var scoreColor: Color {
        DS.scoreColor(overallScore)
    }

    private var gradientColors: [Color] {
        switch overallScore {
        case 80...100: return [Color(red: 0.1, green: 0.2, blue: 0.15), Color(red: 0.05, green: 0.12, blue: 0.08)]
        case 60..<80: return [Color(red: 0.2, green: 0.18, blue: 0.08), Color(red: 0.12, green: 0.1, blue: 0.04)]
        case 40..<60: return [Color(red: 0.22, green: 0.14, blue: 0.06), Color(red: 0.14, green: 0.08, blue: 0.03)]
        default: return [Color(red: 0.22, green: 0.08, blue: 0.08), Color(red: 0.14, green: 0.04, blue: 0.04)]
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Text("Laso")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(String(year)) Year in Review")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)

                Spacer()

                // Score ring
                ZStack {
                    Circle()
                        .fill(scoreColor.opacity(0.08))
                        .frame(width: 180, height: 180)

                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 12)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: Double(overallScore) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 140, height: 140)

                    VStack(spacing: 2) {
                        Text("\(overallScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Annual Score")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer().frame(height: 24)

                // Stats row
                HStack(spacing: 16) {
                    shareStatBadge(icon: "checkmark.circle.fill", value: "\(totalActiveDays)", label: "Active Days")
                    shareStatBadge(icon: "flame.fill", value: String(format: "%.0f", totalExerciseHours), label: "Exercise Hrs")
                    shareStatBadge(icon: "bed.double.fill", value: String(format: "%.1f", averageSleepHours), label: "Avg Sleep")
                }

                if streakRecord > 0 {
                    Spacer().frame(height: 16)

                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(streakRecord)-day streak record")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                }

                Spacer()

                Text("Track your health with Laso")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 390, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func shareStatBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AnnualReportView(
            year: 2025,
            monthlyScores: [
                (month: 1, score: 68),
                (month: 2, score: 71),
                (month: 3, score: 65),
                (month: 4, score: 74),
                (month: 5, score: 78),
                (month: 6, score: 72),
                (month: 7, score: 80),
                (month: 8, score: 82),
                (month: 9, score: 77),
                (month: 10, score: 85),
                (month: 11, score: 79),
                (month: 12, score: 83)
            ],
            annualStats: AnnualStats(
                totalActiveDays: 287,
                totalExerciseHours: 342,
                totalDistanceKm: 1845,
                averageDailySteps: 8742,
                averageSleepHours: 7.2,
                sleepOver7HoursPercent: 68
            ),
            categoryScores: [
                AnnualCategoryScore(category: .heart, averageScore: 82, trend: .improving),
                AnnualCategoryScore(category: .sleep, averageScore: 71, trend: .stable),
                AnnualCategoryScore(category: .activity, averageScore: 78, trend: .improving),
                AnnualCategoryScore(category: .body, averageScore: 65, trend: .declining),
                AnnualCategoryScore(category: .respiratory, averageScore: 88, trend: .stable),
                AnnualCategoryScore(category: .mindfulness, averageScore: 55, trend: .improving),
                AnnualCategoryScore(category: .mobility, averageScore: 73, trend: .stable)
            ],
            discoveries: [
                AnnualDiscovery(
                    title: "Sleep-HRV Connection",
                    detail: "Your HRV improves by 12% on nights you sleep before 11pm",
                    category: .sleep,
                    month: 3
                ),
                AnnualDiscovery(
                    title: "Weekend Activity Gap",
                    detail: "Saturday step count averages 40% lower than weekday average",
                    category: .activity,
                    month: 5
                ),
                AnnualDiscovery(
                    title: "Resting HR Improvement",
                    detail: "Resting heart rate dropped 4 bpm since consistent cardio started in June",
                    category: .heart,
                    month: 8
                ),
                AnnualDiscovery(
                    title: "Stress Recovery Pattern",
                    detail: "Mindfulness sessions reduce next-day resting HR by an average of 3 bpm",
                    category: .mindfulness,
                    month: 10
                ),
                AnnualDiscovery(
                    title: "Seasonal Sleep Shift",
                    detail: "Average sleep duration increases by 35 min during winter months",
                    category: .sleep,
                    month: 11
                )
            ],
            records: [
                AnnualRecord(title: "Highest Score", detail: "Reached 92 on October 14", icon: "star.fill"),
                AnnualRecord(title: "Most Steps in a Day", detail: "24,381 steps on July 8", icon: "shoe.fill"),
                AnnualRecord(title: "Best Sleep Week", detail: "8.1 hrs average, week of Nov 3", icon: "moon.stars.fill"),
                AnnualRecord(title: "Longest Streak", detail: "47 consecutive active days", icon: "flame.fill")
            ],
            vitalityAgeStart: 34,
            vitalityAgeEnd: 31,
            streakRecord: 47,
            previousYearScore: 69,
            focusAreas: [
                "Improve mindfulness consistency with daily 5-minute sessions",
                "Address weekend activity gaps with scheduled Saturday movement",
                "Focus on body composition through strength training 3x/week"
            ],
            totalInsightsGenerated: 847,
            totalDataPointsAnalyzed: 142_350
        )
    }
}
