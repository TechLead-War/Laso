import SwiftUI

// MARK: - Monthly Review View

struct MonthlyReviewView: View {
    let monthDate: Date
    let averageScore: Int
    let categoryScores: [(HealthCategory, Int)]
    let dailyScores: [(Date, Int)]
    let records: [String]
    let behaviorCorrelations: [(behavior: String, effect: String, isPositive: Bool)]

    /// Optional previous-month metrics for month-over-month comparison.
    /// Each entry: (label, currentValue, previousValue, unit, higherIsBetter).
    var previousMonthMetrics: [(label: String, current: Double, previous: Double, unit: String, higherIsBetter: Bool)] = []

    /// Optional previous-month average score for delta display.
    var previousMonthScore: Int?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DS.sectionSpacing) {
                headerSection
                keyStatsGrid
                scoreTrendSection
                categoryPerformanceSection
                behaviorCorrelationsSection
                personalRecordsSection
                monthOverMonthSection
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(monthTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareButton(
                    cardType: .score(
                        score: averageScore,
                        scoreChange: scoreDelta,
                        streakDays: SessionTracker.shared.streakDays
                    ),
                    screen: .home
                )
            }
        }
    }

    // MARK: - Computed Helpers

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthDate)
    }

    private var scoreDelta: Int? {
        guard let prev = previousMonthScore else { return nil }
        return averageScore - prev
    }

    private var sortedCategoryScores: [(HealthCategory, Int)] {
        categoryScores.sorted { $0.1 < $1.1 }
    }

    private var bestDay: (Date, Int)? {
        dailyScores.max(by: { $0.1 < $1.1 })
    }

    private var worstDay: (Date, Int)? {
        dailyScores.min(by: { $0.1 < $1.1 })
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            HealthScoreRing(
                score: averageScore,
                label: "Monthly Avg",
                size: 140,
                lineWidth: 14
            )

            if let delta = scoreDelta {
                HStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                    Text(delta >= 0 ? "+\(delta) from last month" : "\(delta) from last month")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(delta >= 0 ? .green : .red)
            } else {
                Text("First month — no comparison yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(DS.recoveryGradient(averageScore))
        .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cardRadius)
                .strokeBorder(DS.scoreColor(averageScore).opacity(DS.strokeAlpha), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }

    // MARK: - Key Stats Grid (2x2)

    private var keyStatsGrid: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Label("Key Stats", systemImage: "chart.bar.fill")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.itemSpacing), GridItem(.flexible(), spacing: DS.itemSpacing)], spacing: DS.itemSpacing) {
                statCard(
                    title: "Avg Daily Strain",
                    value: formattedAverageStrain,
                    icon: "flame.fill",
                    color: .orange
                )

                statCard(
                    title: "Avg Sleep",
                    value: formattedAverageSleep,
                    icon: "bed.double.fill",
                    color: .indigo
                )

                statCard(
                    title: "Green Recovery Days",
                    value: "\(greenRecoveryDays)",
                    icon: "heart.circle.fill",
                    color: .green
                )

                statCard(
                    title: "Active Minutes",
                    value: formattedTotalActiveMinutes,
                    icon: "figure.run",
                    color: .blue
                )
            }
            .padding(.horizontal)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.cardPadding)
        .cardStyle(tint: color)
    }

    // Derived stat values from dailyScores
    private var formattedAverageStrain: String {
        guard !dailyScores.isEmpty else { return "--" }
        let avg = Double(dailyScores.map(\.1).reduce(0, +)) / Double(dailyScores.count)
        return String(format: "%.1f", avg / 10.0) // Normalize score to strain-like scale
    }

    private var formattedAverageSleep: String {
        // Derive approximate sleep hours from sleep category score
        if let sleepScore = categoryScores.first(where: { $0.0 == .sleep })?.1 {
            let hours = 5.0 + Double(sleepScore) / 100.0 * 4.0 // Map 0-100 -> 5-9h
            return String(format: "%.1fh", hours)
        }
        return "--"
    }

    private var greenRecoveryDays: Int {
        dailyScores.filter { $0.1 >= 75 }.count
    }

    private var formattedTotalActiveMinutes: String {
        // Derive from activity category score as approximation
        if let activityScore = categoryScores.first(where: { $0.0 == .activity })?.1 {
            let dailyMinutes = Double(activityScore) / 100.0 * 60.0 // Map to ~0-60 min/day
            let total = Int(dailyMinutes * Double(dailyScores.count))
            return NumberFormatter.localizedString(from: NSNumber(value: total), number: .decimal)
        }
        return "--"
    }

    // MARK: - Score Trend Section

    private var scoreTrendSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Label("30-Day Score Trend", systemImage: "chart.xyaxis.line")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // Sparkline chart
                scoreTrendChart
                    .frame(height: 120)
                    .padding(.horizontal, 8)

                Divider()
                    .padding(.horizontal)

                // Best and worst day callouts
                HStack(spacing: 0) {
                    if let best = bestDay {
                        dayCallout(
                            label: "Best Day",
                            date: best.0,
                            score: best.1,
                            color: .green,
                            icon: "arrow.up.circle.fill"
                        )
                    }

                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 1, height: DS.dividerHeight)

                    if let worst = worstDay {
                        dayCallout(
                            label: "Worst Day",
                            date: worst.0,
                            score: worst.1,
                            color: .red,
                            icon: "arrow.down.circle.fill"
                        )
                    }
                }
            }
            .padding(.vertical, DS.cardPadding)
            .cardStyle()
            .padding(.horizontal)
        }
    }

    private var scoreTrendChart: some View {
        GeometryReader { geo in
            let sorted = dailyScores.sorted(by: { $0.0 < $1.0 })
            let count = sorted.count
            if count > 1 {
                let maxScore = max(sorted.map(\.1).max() ?? 100, 100)
                let minScore = max(min(sorted.map(\.1).min() ?? 0, 0), 0)
                let range = Double(max(maxScore - minScore, 1))

                ZStack {
                    // Grid lines
                    ForEach([25, 50, 75], id: \.self) { threshold in
                        let y = geo.size.height * (1.0 - Double(threshold - minScore) / range)
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(.quaternary, style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    }

                    // Line path
                    Path { path in
                        for (i, entry) in sorted.enumerated() {
                            let x = geo.size.width * Double(i) / Double(count - 1)
                            let y = geo.size.height * (1.0 - Double(entry.1 - minScore) / range)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        DS.scoreColor(averageScore),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                    // Gradient fill
                    Path { path in
                        for (i, entry) in sorted.enumerated() {
                            let x = geo.size.width * Double(i) / Double(count - 1)
                            let y = geo.size.height * (1.0 - Double(entry.1 - minScore) / range)
                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [DS.scoreColor(averageScore).opacity(0.3), DS.scoreColor(averageScore).opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Best/worst day markers
                    if let best = bestDay, let bestIndex = sorted.firstIndex(where: { $0.0 == best.0 }) {
                        let x = geo.size.width * Double(bestIndex) / Double(count - 1)
                        let y = geo.size.height * (1.0 - Double(best.1 - minScore) / range)
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }

                    if let worst = worstDay, let worstIndex = sorted.firstIndex(where: { $0.0 == worst.0 }) {
                        let x = geo.size.width * Double(worstIndex) / Double(count - 1)
                        let y = geo.size.height * (1.0 - Double(worst.1 - minScore) / range)
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            } else {
                Text("Not enough data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func dayCallout(label: String, date: Date, score: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(color)
                    .textCase(.uppercase)
            }

            Text("\(score)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)

            Text(shortDateString(date))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Performance Section

    private var categoryPerformanceSection: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            Label("Category Performance", systemImage: "square.grid.2x2.fill")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 6) {
                ForEach(sortedCategoryScores, id: \.0) { category, score in
                    categoryRow(category: category, score: score)
                }
            }
            .padding(.vertical, DS.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            .padding(.horizontal)
        }
    }

    private func categoryRow(category: HealthCategory, score: Int) -> some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: category.systemImageName)
                .font(.body.weight(.semibold))
                .foregroundStyle(category.color)
                .frame(width: DS.iconSize, height: DS.iconSize)
                .background(category.color.opacity(DS.badgeBg), in: RoundedRectangle(cornerRadius: DS.iconRadius))

            // Name
            Text(category.displayName)
                .font(.subheadline.weight(.medium))

            Spacer()

            // Mini score ring
            HealthScoreRing(
                score: score,
                label: "",
                size: 36,
                lineWidth: 4
            )

            // Trend arrow vs previous month (if available)
            if let prevMetric = previousMonthMetrics.first(where: { $0.label == category.shortName }) {
                let delta = prevMetric.current - prevMetric.previous
                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(delta >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 6)
    }

    // MARK: - Behavior Correlations Section

    private var behaviorCorrelationsSection: some View {
        Group {
            if !behaviorCorrelations.isEmpty {
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    Label("Behavior Correlations", systemImage: "arrow.triangle.branch")
                        .font(.headline)
                        .padding(.horizontal)

                    let positive = behaviorCorrelations.filter(\.isPositive).prefix(3)
                    let negative = behaviorCorrelations.filter { !$0.isPositive }.prefix(3)

                    if !positive.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Helped Recovery")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.green)
                                .textCase(.uppercase)
                                .padding(.horizontal, DS.cardPadding)

                            ForEach(Array(positive.enumerated()), id: \.offset) { _, item in
                                behaviorRow(
                                    behavior: item.behavior,
                                    effect: item.effect,
                                    isPositive: true
                                )
                            }
                        }
                        .padding(.vertical, DS.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle(tint: .green)
                        .padding(.horizontal)
                    }

                    if !negative.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hurt Recovery")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                                .textCase(.uppercase)
                                .padding(.horizontal, DS.cardPadding)

                            ForEach(Array(negative.enumerated()), id: \.offset) { _, item in
                                behaviorRow(
                                    behavior: item.behavior,
                                    effect: item.effect,
                                    isPositive: false
                                )
                            }
                        }
                        .padding(.vertical, DS.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle(tint: .orange)
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    private func behaviorRow(behavior: String, effect: String, isPositive: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isPositive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.body)
                .foregroundStyle(isPositive ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(behavior)
                    .font(.subheadline.weight(.medium))
                Text(effect)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 2)
    }

    // MARK: - Personal Records Section

    private var personalRecordsSection: some View {
        Group {
            if !records.isEmpty {
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    Label("Personal Records", systemImage: "trophy.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                        .padding(.horizontal)

                    VStack(spacing: 6) {
                        ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                            HStack(spacing: 10) {
                                Image(systemName: "star.fill")
                                    .font(.body)
                                    .foregroundStyle(.yellow)

                                Text(record)
                                    .font(.subheadline.weight(.medium))

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, DS.cardPadding)
                        }
                    }
                    .padding(.vertical, DS.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(tint: .yellow)
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Month-over-Month Comparison

    private var monthOverMonthSection: some View {
        Group {
            if !previousMonthMetrics.isEmpty {
                VStack(alignment: .leading, spacing: DS.itemSpacing) {
                    Label("Month-over-Month", systemImage: "arrow.left.arrow.right")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 6) {
                        ForEach(Array(previousMonthMetrics.enumerated()), id: \.offset) { _, metric in
                            momRow(metric)
                        }
                    }
                    .padding(.vertical, DS.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: DS.cardRadius))
                    .padding(.horizontal)
                }
            }
        }
    }

    private func momRow(_ metric: (label: String, current: Double, previous: Double, unit: String, higherIsBetter: Bool)) -> some View {
        let delta = metric.previous != 0
            ? ((metric.current - metric.previous) / metric.previous) * 100.0
            : 0.0
        let isImprovement = metric.higherIsBetter ? delta >= 0 : delta <= 0
        let arrowColor: Color = isImprovement ? .green : .red
        let arrowIcon = delta >= 0 ? "arrow.up.right" : "arrow.down.right"

        return HStack(spacing: 10) {
            Text(metric.label)
                .font(.subheadline.weight(.medium))

            Spacer()

            Text(String(format: "%.1f%@", metric.current, metric.unit))
                .font(.subheadline.weight(.semibold).monospacedDigit())

            HStack(spacing: 3) {
                Image(systemName: arrowIcon)
                    .font(.caption2.weight(.bold))
                Text(String(format: "%.1f%%", abs(delta)))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(arrowColor)
            .padding(.horizontal, DS.badgeH)
            .padding(.vertical, DS.badgeV)
            .background(arrowColor.opacity(DS.badgeBg), in: Capsule())
        }
        .padding(.horizontal, DS.cardPadding)
        .padding(.vertical, 6)
    }

    // MARK: - Date Formatting

    private func shortDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let dailyScores: [(Date, Int)] = (0..<30).compactMap { offset in
        guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
        let score = Int.random(in: 40...95)
        return (date, score)
    }

    NavigationStack {
        MonthlyReviewView(
            monthDate: now,
            averageScore: 72,
            categoryScores: [
                (.heart, 78),
                (.sleep, 65),
                (.activity, 80),
                (.body, 70),
                (.respiratory, 85),
                (.mindfulness, 55),
                (.mobility, 60)
            ],
            dailyScores: dailyScores,
            records: [
                "Highest steps day: 18,432 on Feb 12",
                "Best sleep night: 8h 45m on Feb 20",
                "7-day meditation streak maintained"
            ],
            behaviorCorrelations: [
                (behavior: "Morning exercise", effect: "+12% recovery next day", isPositive: true),
                (behavior: "No screens before bed", effect: "+8% sleep quality", isPositive: true),
                (behavior: "Hydration > 2L", effect: "+5% overall score", isPositive: true),
                (behavior: "Late caffeine", effect: "-15% sleep quality", isPositive: false),
                (behavior: "Alcohol consumption", effect: "-22% recovery", isPositive: false),
                (behavior: "Skipping meals", effect: "-8% energy levels", isPositive: false)
            ],
            previousMonthMetrics: [
                (label: "Avg Score", current: 72, previous: 68, unit: "", higherIsBetter: true),
                (label: "Sleep", current: 7.2, previous: 6.8, unit: "h", higherIsBetter: true),
                (label: "Steps", current: 9500, previous: 8200, unit: "", higherIsBetter: true),
                (label: "Resting HR", current: 62, previous: 65, unit: " bpm", higherIsBetter: false)
            ],
            previousMonthScore: 68
        )
    }
}
