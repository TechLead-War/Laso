import Foundation

/// Generates insights from historical health score trajectory.
/// Uses stored daily analysis snapshots to detect long-term score trends.
struct ScoreTrajectoryAnalyzer {

    /// Generate insights from score history with optional category breakdown
    static func generateInsights(scoreHistory: [(date: Date, score: Int)], categoryScores: [HealthScore] = []) -> [Insight] {
        guard scoreHistory.count >= 7 else { return [] }
        var insights: [Insight] = []

        // 1. Overall trajectory over last 30 days
        if let trajectory = analyzeTrajectory(scoreHistory: scoreHistory, days: 30, categoryScores: categoryScores) {
            insights.append(trajectory)
        }

        // 2. Score momentum: is improvement accelerating or decelerating?
        if let momentum = analyzeMomentum(scoreHistory: scoreHistory) {
            insights.append(momentum)
        }

        // 3. Sustained high/low periods
        if let sustained = analyzeSustainedPeriod(scoreHistory: scoreHistory) {
            insights.append(sustained)
        }

        return insights
    }

    // MARK: - Trajectory (30-day score direction)

    private static func analyzeTrajectory(scoreHistory: [(date: Date, score: Int)], days: Int, categoryScores: [HealthScore] = []) -> Insight? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recent = scoreHistory.filter { $0.date >= cutoff }
        guard recent.count >= 5 else { return nil }

        // Compare first half vs second half (use dropFirst/dropLast to avoid skipping middle element)
        let mid = recent.count / 2
        let firstHalf = Array(recent.prefix(mid))
        let secondHalf = Array(recent.dropFirst(mid))

        let firstAvg = Double(firstHalf.map(\.score).reduce(0, +)) / Double(firstHalf.count)
        let secondAvg = Double(secondHalf.map(\.score).reduce(0, +)) / Double(secondHalf.count)

        guard firstAvg > 0 else { return nil }
        let changePercent = ((secondAvg - firstAvg) / firstAvg) * 100

        // Only report significant changes (>3%)
        guard abs(changePercent) > 3 else { return nil }

        let improving = changePercent > 0
        let absChange = String(format: "%.0f", abs(changePercent))
        let currentScore = Int(secondAvg.rounded())

        // Build category driver text for declining scores
        let categoryDriverText: String
        if !improving && !categoryScores.isEmpty {
            let sorted = categoryScores
                .filter { $0.score < 70 }
                .sorted { $0.score < $1.score }
                .prefix(3)
            if !sorted.isEmpty {
                let driverList = sorted.compactMap { score -> String? in
                    guard let cat = score.category else { return nil }
                    return "\(cat.displayName) (\(score.score)/100)"
                }.joined(separator: ", ")
                categoryDriverText = " Pulled down by: \(driverList)."
            } else {
                categoryDriverText = ""
            }
        } else {
            categoryDriverText = ""
        }

        return Insight(
            metric: .restingHeartRate, // Representative metric for overall health
            title: improving ? "Health Score Trending Up" : "Health Score Declining",
            summary: "Your overall health score has \(improving ? "improved" : "declined") \(absChange)% over the last \(days) days. Current average: \(currentScore).\(categoryDriverText)",
            recommendation: improving
                ? "Your consistent efforts are paying off \u{2014} score up \(absChange)%. Keep maintaining your current habits."
                : "Focus on the weakest categories above. Improving just 1 area by 10 points will noticeably raise your overall score.",
            severity: improving ? .info : .warning,
            trend: improving ? .improving : .declining,
            currentValue: secondAvg,
            baselineValue: firstAvg,
            deviationPercent: changePercent,
            category: .scoreTrajectory
        )
    }

    // MARK: - Momentum (acceleration of change)

    private static func analyzeMomentum(scoreHistory: [(date: Date, score: Int)]) -> Insight? {
        // Need at least 3 weeks of data for acceleration
        guard scoreHistory.count >= 21 else { return nil }

        let recent = Array(scoreHistory.suffix(21))

        // Split into 3 weeks
        let week1 = Array(recent.prefix(7))
        let week2 = Array(recent.dropFirst(7).prefix(7))
        let week3 = Array(recent.suffix(7))

        let avg1 = Double(week1.map(\.score).reduce(0, +)) / 7.0
        let avg2 = Double(week2.map(\.score).reduce(0, +)) / 7.0
        let avg3 = Double(week3.map(\.score).reduce(0, +)) / 7.0

        let change1to2 = avg2 - avg1
        let change2to3 = avg3 - avg2
        let acceleration = change2to3 - change1to2

        // Only report if acceleration is significant (>2 points)
        guard abs(acceleration) > 2 else { return nil }

        let accelerating = acceleration > 0
        let isImproving = change2to3 > 0

        // Interesting case: improvements are accelerating or declines are accelerating
        if accelerating && isImproving {
            return Insight(
                metric: .restingHeartRate,
                title: "Improvement Accelerating",
                summary: "Your health gains are picking up speed. This week's improvement was stronger than last week's.",
                recommendation: "Your trajectory is excellent. Whatever you changed recently is working — keep it up.",
                severity: .info,
                trend: .improving,
                currentValue: avg3,
                baselineValue: avg1,
                deviationPercent: ((avg3 - avg1) / max(avg1, 1)) * 100,
                category: .scoreTrajectory
            )
        } else if !accelerating && !isImproving {
            return Insight(
                metric: .restingHeartRate,
                title: "Decline Accelerating",
                summary: "Your health score is dropping faster this week than last. Multiple areas may need attention.",
                recommendation: "Check your sleep, activity, and stress levels. A decline acceleration often signals compounding issues.",
                severity: .warning,
                trend: .declining,
                currentValue: avg3,
                baselineValue: avg1,
                deviationPercent: ((avg3 - avg1) / max(avg1, 1)) * 100,
                category: .scoreTrajectory
            )
        }

        return nil
    }

    // MARK: - Sustained Periods

    private static func analyzeSustainedPeriod(scoreHistory: [(date: Date, score: Int)]) -> Insight? {
        guard scoreHistory.count >= 7 else { return nil }

        let recent = Array(scoreHistory.suffix(14))

        // Check for sustained high (>85) or low (<60) scores
        let highDays = recent.filter { $0.score >= 85 }.count
        let lowDays = recent.filter { $0.score < 60 }.count

        if highDays >= 10 {
            let avg = Double(recent.map(\.score).reduce(0, +)) / Double(recent.count)
            return Insight(
                metric: .restingHeartRate,
                title: "Consistently Strong Health",
                summary: "Your health score has been 85+ for \(highDays) of the last \(recent.count) days. This is excellent.",
                recommendation: "You've built strong habits. Consider setting new goals or focusing on your weakest category for further gains.",
                severity: .info,
                trend: .improving,
                currentValue: avg,
                baselineValue: 85,
                deviationPercent: ((avg - 85) / 85) * 100,
                category: .scoreTrajectory
            )
        }

        if lowDays >= 7 {
            let avg = Double(recent.map(\.score).reduce(0, +)) / Double(recent.count)
            return Insight(
                metric: .restingHeartRate,
                title: "Extended Low Score Period",
                summary: "Your health score has been below 60 for \(lowDays) of the last \(recent.count) days.",
                recommendation: "A sustained low score usually signals a specific area needs intervention. Check your top declining metrics and pick one to improve this week.",
                severity: .warning,
                trend: .declining,
                currentValue: avg,
                baselineValue: 60,
                deviationPercent: ((avg - 60) / 60) * 100,
                category: .scoreTrajectory
            )
        }

        return nil
    }
}
