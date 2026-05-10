import Foundation

struct DashboardDerivedStateBuilder {
    struct TrendSnapshot {
        let metric: HealthMetric
        let direction: TrendDirection
        let weekOverWeekChange: Double
    }

    typealias ScoreHistoryEntry = (date: Date, score: Int)

    func scoreChangeFromLastWeek(
        currentScore: Int,
        history: [ScoreHistoryEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard history.count >= 2 else { return nil }

        // Anchor the cutoff at start-of-today so the "old" snapshot picked is
        // stable across refreshes within the same calendar day.
        let today = calendar.startOfDay(for: now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        guard let oldScore = history
            .filter({ $0.date <= weekAgo })
            .last?.score else { return nil }

        let delta = currentScore - oldScore
        return delta == 0 ? nil : delta
    }

    func scoreChangeFromYesterday(
        currentScore: Int,
        history: [ScoreHistoryEntry],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard history.count >= 2 else { return nil }

        let yesterday = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -1, to: now) ?? now
        )
        let today = calendar.startOfDay(for: now)
        guard let yesterdayScore = history
            .filter({ $0.date >= yesterday && $0.date < today })
            .last?.score else { return nil }

        let delta = currentScore - yesterdayScore
        return delta == 0 ? nil : delta
    }

    func trendsSummary(
        trends: [TrendSnapshot],
        focusCategories: Set<HealthCategory>,
        limit: Int = 5
    ) -> DashboardViewModel.TrendsSummary {
        var improving = 0
        var stable = 0
        var declining = 0
        var movers: [DashboardViewModel.MetricMover] = []

        for trend in trends {
            switch trend.direction {
            case .improving: improving += 1
            case .stable: stable += 1
            case .declining: declining += 1
            }

            if abs(trend.weekOverWeekChange) > 3 {
                movers.append(
                    DashboardViewModel.MetricMover(
                        metric: trend.metric,
                        changePercent: trend.weekOverWeekChange,
                        improving: trend.direction == .improving
                    )
                )
            }
        }

        movers.sort { a, b in
            if !focusCategories.isEmpty {
                let aFocused = focusCategories.contains(a.metric.category)
                let bFocused = focusCategories.contains(b.metric.category)
                if aFocused != bFocused { return aFocused }
            }
            return abs(a.changePercent) > abs(b.changePercent)
        }

        return DashboardViewModel.TrendsSummary(
            improving: improving,
            stable: stable,
            declining: declining,
            topMovers: Array(movers.prefix(limit))
        )
    }

    func topCorrelations(
        from correlations: [HealthCorrelation],
        focusCategories: Set<HealthCategory>,
        limit: Int = 5
    ) -> [HealthCorrelation] {
        if focusCategories.isEmpty {
            return Array(correlations.prefix(limit))
        }

        let sorted = correlations.sorted { a, b in
            let aRelevant = focusCategories.contains(a.metricA.category) || focusCategories.contains(a.metricB.category)
            let bRelevant = focusCategories.contains(b.metricA.category) || focusCategories.contains(b.metricB.category)
            if aRelevant != bRelevant { return aRelevant }
            return abs(a.correlation) > abs(b.correlation)
        }

        return Array(sorted.prefix(limit))
    }
}
