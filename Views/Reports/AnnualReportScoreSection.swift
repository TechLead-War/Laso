import SwiftUI
import Charts

struct AnnualReportScoreSection: View {
    let year: Int
    let monthlyScores: [(month: Int, score: Int)]
    let overallScore: Int
    let previousYearScore: Int?

    private var bestMonth: (month: Int, score: Int)? {
        monthlyScores.max(by: { $0.score < $1.score })
    }

    private var worstMonth: (month: Int, score: Int)? {
        monthlyScores.min(by: { $0.score < $1.score })
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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.itemSpacing) {
            AnnualReportHelpers.sectionHeader(title: Copy.Reports.scoreJourney, icon: "chart.xyaxis.line", color: .green)

            if !monthlyScores.isEmpty {
                monthlyScoreChart
                    .padding(DS.cardPadding)
                    .cardStyle()
            }

            HStack(spacing: DS.itemSpacing) {
                if let best = bestMonth {
                    monthHighlightCard(
                        label: Copy.Reports.bestMonth,
                        month: best.month,
                        score: best.score,
                        color: .green,
                        icon: "arrow.up.circle.fill"
                    )
                }

                if let worst = worstMonth {
                    monthHighlightCard(
                        label: Copy.Reports.worstMonth,
                        month: worst.month,
                        score: worst.score,
                        color: .red,
                        icon: "arrow.down.circle.fill"
                    )
                }
            }

            if let prevScore = previousYearScore {
                yearOverYearCard(currentScore: overallScore, previousScore: prevScore)
            }
        }
    }

    private var monthlyScoreChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Copy.Reports.monthlyAverages)
                .font(.subheadline.weight(.semibold))

            Chart {
                ForEach(monthlyScores, id: \.month) { entry in
                    LineMark(
                        x: .value("Month", AnnualReportHelpers.monthAbbreviation(entry.month)),
                        y: .value("Score", entry.score)
                    )
                    .foregroundStyle(DS.scoreColor(overallScore).gradient)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Month", AnnualReportHelpers.monthAbbreviation(entry.month)),
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
                        x: .value("Month", AnnualReportHelpers.monthAbbreviation(entry.month)),
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

            Text(AnnualReportHelpers.monthName(month))
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
                Text(Copy.Reports.yearOverYear)
                    .font(.subheadline.weight(.semibold))
                Text(Copy.Reports.yearOverYearDetail(prevYear: year - 1, prevScore: previousScore, curYear: year, curScore: currentScore))
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
}
