import Foundation

/// Generates a self-contained HTML report with charts and insights
struct HTMLReportGenerator {

    static func generate(
        overallScore: HealthScore,
        categoryScores: [HealthScore],
        insights: [Insight],
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> String {
        var body = ""

        // Overall Score
        body += generateScoreSection(score: overallScore)

        // Category Cards
        body += "<div class=\"categories\">"
        for catScore in categoryScores {
            body += generateCategoryCard(score: catScore)
        }
        body += "</div>"

        // Insights
        if !insights.isEmpty {
            body += "<div class=\"card\"><h2>Insights & Recommendations</h2>"
            for insight in insights {
                body += generateInsightCard(insight: insight)
            }
            body += "</div>"
        }

        // Metric Charts
        body += "<div class=\"card\"><h2>Metric Details (30-Day View)</h2>"
        var chartIndex = 0
        for category in HealthCategory.allCases {
            body += "<h3>\(category.displayName)</h3>"
            for metric in category.metrics {
                guard let series = timeSeries[metric],
                      !series.samples.isEmpty else { continue }
                body += generateChartSection(
                    metric: metric,
                    series: series,
                    baseline: baselines[metric],
                    chartId: "chart\(chartIndex)"
                )
                chartIndex += 1
            }
        }
        body += "</div>"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let dateString = dateFormatter.string(from: Date())

        return ReportTemplate.html(
            title: "HealthPulse Report",
            date: dateString,
            body: body
        )
    }

    private static func generateScoreSection(score: HealthScore) -> String {
        let color = scoreColor(score.score)
        let circumference = 2.0 * Double.pi * 65
        let offset = circumference * (1.0 - Double(score.score) / 100.0)

        return """
        <div class="card" style="text-align: center;">
            <div class="score-ring">
                <svg viewBox="0 0 160 160">
                    <circle cx="80" cy="80" r="65" fill="none" stroke="#e0e0e0" stroke-width="12"/>
                    <circle cx="80" cy="80" r="65" fill="none" stroke="\(color)" stroke-width="12"
                        stroke-dasharray="\(String(format: "%.1f", circumference))"
                        stroke-dashoffset="\(String(format: "%.1f", offset))"
                        stroke-linecap="round"/>
                </svg>
                <div class="score-text" style="color: \(color)">\(score.score)</div>
            </div>
            <p style="font-size: 14px; color: #666;">Overall Health Score &middot; Grade: \(score.grade)</p>
        </div>
        """
    }

    private static func generateCategoryCard(score: HealthScore) -> String {
        let name = score.category?.displayName ?? "Unknown"
        let color = scoreColor(score.score)

        var breakdownHTML = ""
        for component in score.breakdown.prefix(5) {
            let sign = component.points >= 0 ? "+" : ""
            let pointColor = component.points >= 0 ? "#34c759" : "#ff3b30"
            breakdownHTML += """
            <div style="display: flex; justify-content: space-between; font-size: 13px; padding: 4px 0;">
                <span>\(component.reason)</span>
                <span style="color: \(pointColor); font-weight: 600;">\(sign)\(component.points)</span>
            </div>
            """
        }

        return """
        <div class="category-card">
            <div class="category-header">
                <h3>\(name)</h3>
                <span class="category-score" style="color: \(color)">\(score.score)</span>
            </div>
            \(breakdownHTML)
        </div>
        """
    }

    private static func generateInsightCard(insight: Insight) -> String {
        """
        <div class="insight-card \(insight.severity.rawValue)">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                <span class="insight-title">\(insight.title)</span>
                <div>
                    <span class="badge \(insight.severity.rawValue)">\(insight.severity.displayName)</span>
                    <span class="badge \(insight.trend.rawValue)">\(insight.trend.displayName)</span>
                </div>
            </div>
            <div class="insight-summary">\(insight.summary)</div>
            <div class="insight-recommendation">\(insight.recommendation)</div>
        </div>
        """
    }

    private static func generateChartSection(
        metric: HealthMetric,
        series: MetricTimeSeries,
        baseline: UserBaseline?,
        chartId: String
    ) -> String {
        let samples = series.samples(lastDays: 30)
        guard !samples.isEmpty else { return "" }

        let labels = samples.map { "'\($0.date.shortDateString)'" }.joined(separator: ",")
        let values = samples.map { String(format: "%.2f", $0.value) }.joined(separator: ",")
        let color = categoryColor(for: metric.category)

        let stats = samples.map(\.value)
        let mean = stats.mean
        let stdDev = stats.standardDeviation

        return """
        <div style="margin-bottom: 24px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3>\(metric.displayName)</h3>
                <span style="font-size: 13px; color: #666;">\(metric.unit)</span>
            </div>
            <div class="chart-container">
                <canvas id="\(chartId)" width="800" height="250"></canvas>
            </div>
            <div class="stats-grid">
                <div class="stat-item">
                    <div class="stat-value">\(String(format: "%.1f", stats.last ?? 0))</div>
                    <div class="stat-label">Current</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">\(String(format: "%.1f", mean))</div>
                    <div class="stat-label">Average</div>
                </div>
                <div class="stat-item">
                    <div class="stat-value">\(String(format: "%.1f", stdDev))</div>
                    <div class="stat-label">Std Dev</div>
                </div>
            </div>
            <script>
            new Chart(document.getElementById('\(chartId)'), {
                type: 'line',
                data: {
                    labels: [\(labels)],
                    datasets: [{
                        data: [\(values)],
                        borderColor: '\(color)',
                        backgroundColor: '\(color)22',
                    }]
                }
            });
            </script>
        </div>
        """
    }

    private static func scoreColor(_ score: Int) -> String {
        switch score {
        case 80...100: return "#34c759"
        case 60..<80: return "#ffcc00"
        case 40..<60: return "#ff9500"
        default: return "#ff3b30"
        }
    }

    private static func categoryColor(for category: HealthCategory) -> String {
        switch category {
        case .heart: return "#ff3b30"
        case .sleep: return "#5856d6"
        case .activity: return "#34c759"
        case .body: return "#ff9500"
        case .respiratory: return "#30b0c7"
        case .mindfulness: return "#32ade6"
        case .mobility: return "#af52de"
        }
    }
}
