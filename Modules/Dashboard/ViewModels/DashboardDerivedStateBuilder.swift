import Foundation

struct DashboardDerivedStateBuilder {
    typealias ScoreHistoryEntry = (date: Date, score: Int)

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
