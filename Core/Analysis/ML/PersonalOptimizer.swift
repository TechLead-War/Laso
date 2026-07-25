import Foundation

/// Discovers each user's personal optimal conditions. what combination of factors
/// creates peak performance, the ideal-day targets, and which metrics move the score most.
///
/// All thresholds and ranges are derived from the user's own data distribution,
/// not population averages. Requires at least 21 days of scored data.
final class PersonalOptimizer {
    static let minimumDays = 7

    // MARK: - Public Types

    struct OptimalProfile {
        let conditions: [OptimalCondition]
        let matchPercentage: Double
        let avgScoreWhenOptimal: Double
        let avgScoreWhenNot: Double

        struct OptimalCondition {
            let metric: HealthMetric
            let optimalRange: (lower: Double, upper: Double)
            let isCurrentlyMet: Bool
            let description: String
        }
    }

    struct IdealDay {
        let targets: [DayTarget]
        let predictedScore: Double
        let confidence: Double
        let description: String

        struct DayTarget {
            let metric: HealthMetric
            let targetValue: Double
            let description: String
        }
    }

    struct SensitivityResult {
        let metric: HealthMetric
        let slope: Double
        let rSquared: Double
        let description: String
    }

    // MARK: - Public State

    private(set) var optimalProfile: OptimalProfile?
    private(set) var idealDay: IdealDay?
    private(set) var sensitivities: [SensitivityResult] = []

    // MARK: - Internal Types

    private struct ScoredDay {
        let date: Date
        let score: Int
        let metricValues: [HealthMetric: Double]
    }

    private struct LinReg {
        let slope: Double
        let rSquared: Double
    }

    // MARK: - Main Entry Point

    func analyze(
        timeSeries: [HealthMetric: MetricTimeSeries],
        scoreHistory: [(date: Date, score: Int)],
        vectors: [DailyFeatureVector]
    ) {
        let cal = Date.cal
        var scoreByDate: [Date: Int] = [:]
        for e in scoreHistory { scoreByDate[cal.startOfDay(for: e.date)] = e.score }

        // Build scored days from feature vectors + raw time series values
        var scoredDays: [ScoredDay] = []
        for vector in vectors {
            let day = cal.startOfDay(for: vector.date)
            guard let score = scoreByDate[day] else { continue }
            var vals: [HealthMetric: Double] = [:]
            for (key, v) in vector.features where key.type == .raw && v != FeatureKey.missingSentinel {
                if let raw = rawValue(for: key.metric, on: day, in: timeSeries, cal: cal) {
                    vals[key.metric] = raw
                }
            }
            guard !vals.isEmpty else { continue }
            scoredDays.append(ScoredDay(date: day, score: score, metricValues: vals))
        }
        guard scoredDays.count >= Self.minimumDays else { return }

        let sorted = scoredDays.sorted { $0.date < $1.date }
        let byScore = scoredDays.sorted { $0.score > $1.score }
        let avail = metricsWithCoverage(days: sorted, minCount: sorted.count / 2)
        guard !avail.isEmpty else { return }
        let latest = latestValues(from: sorted)

        optimalProfile = discoverOptimalProfile(byScore: byScore, metrics: avail, latest: latest)
        idealDay = computeIdealDay(byScore: byScore, metrics: avail)
        sensitivities = computeSensitivities(days: sorted, metrics: avail)
    }

    // MARK: - Optimal Profile Discovery

    private func discoverOptimalProfile(
        byScore: [ScoredDay], metrics: [HealthMetric], latest: [HealthMetric: Double]
    ) -> OptimalProfile? {
        let topN = max(3, byScore.count / 10)
        let topDays = Array(byScore.prefix(topN))
        guard !topDays.isEmpty else { return nil }

        struct Hit { let metric: HealthMetric; let effect: Double; let lo: Double; let hi: Double }
        var hits: [Hit] = []

        for metric in metrics {
            let topVals = topDays.compactMap { $0.metricValues[metric] }
            let allVals = byScore.compactMap { $0.metricValues[metric] }
            guard topVals.count >= 3, allVals.count >= Self.minimumDays else { continue }
            let allStd = allVals.std; guard allStd > 0 else { continue }
            let effect = abs(topVals.avg - allVals.avg) / allStd
            guard mannWhitneyU(sample: topVals, pop: allVals) || effect > 0.3 else { continue }
            let s = topVals.sorted()
            hits.append(Hit(metric: metric, effect: effect, lo: pctl(s, 0.25), hi: pctl(s, 0.75)))
        }
        hits.sort { $0.effect > $1.effect }
        let top = Array(hits.prefix(8))
        guard !top.isEmpty else { return nil }

        let conditions = top.map { h -> OptimalProfile.OptimalCondition in
            let cur = latest[h.metric]
            let met = cur.map { $0 >= h.lo && $0 <= h.hi } ?? false
            let u = h.metric.unit.isEmpty ? "" : " \(h.metric.unit)"
            return .init(metric: h.metric, optimalRange: (h.lo, h.hi), isCurrentlyMet: met,
                         description: "\(h.metric.displayName) \(h.metric.formatValue(h.lo))-\(h.metric.formatValue(h.hi))\(u)")
        }

        // Count days matching top-3 conditions simultaneously
        let check = Array(conditions.prefix(3))
        var matchN = 0, optScores = [Int](), nonScores = [Int]()
        for day in byScore {
            let ok = check.allSatisfy { c in
                guard let v = day.metricValues[c.metric] else { return false }
                return v >= c.optimalRange.lower && v <= c.optimalRange.upper
            }
            if ok { matchN += 1; optScores.append(day.score) } else { nonScores.append(day.score) }
        }
        let matchPct = Double(matchN) / Double(byScore.count) * 100
        let avgOpt = optScores.isEmpty ? 0 : Double(optScores.reduce(0,+)) / Double(optScores.count)
        let avgNon = nonScores.isEmpty ? 0 : Double(nonScores.reduce(0,+)) / Double(nonScores.count)

        return OptimalProfile(conditions: conditions, matchPercentage: matchPct,
            avgScoreWhenOptimal: avgOpt, avgScoreWhenNot: avgNon)
    }

    // MARK: - Ideal Day Computation

    private func computeIdealDay(byScore: [ScoredDay], metrics: [HealthMetric]) -> IdealDay? {
        let topN = max(3, byScore.count / 10)
        let topDays = Array(byScore.prefix(topN))
        guard !topDays.isEmpty else { return nil }
        let avgTop = Double(topDays.reduce(0) { $0 + $1.score }) / Double(topDays.count)

        // Rank metrics by score sensitivity
        var sens: [HealthMetric: Double] = [:]
        for m in metrics {
            var xs = [Double](), ys = [Double]()
            for d in byScore { if let v = d.metricValues[m] { xs.append(v); ys.append(Double(d.score)) } }
            guard xs.count >= Self.minimumDays else { continue }
            let r = linReg(x: xs, y: ys); sens[m] = abs(r.slope) * r.rSquared
        }
        let ranked = metrics.filter { sens[$0] != nil }.sorted { (sens[$0] ?? 0) > (sens[$1] ?? 0) }

        var targets: [IdealDay.DayTarget] = []
        for m in ranked.prefix(8) {
            let vals = topDays.compactMap { $0.metricValues[m] }
            guard !vals.isEmpty else { continue }
            let med = pctl(vals.sorted(), 0.50)
            let u = m.unit.isEmpty ? "" : " \(m.unit)"
            targets.append(.init(metric: m, targetValue: med,
                                 description: "Aim for ~\(m.formatValue(med))\(u) \(m.displayName)"))
        }
        guard !targets.isEmpty else { return nil }

        let topStd = topDays.map { Double($0.score) }.std
        let conf = max(0.3, min(0.95, 1.0 - topStd / 30.0))
        let tStr = targets.prefix(3).map { "\($0.metric.formatValue($0.targetValue))\($0.metric.unit.isEmpty ? "" : " \($0.metric.unit)") \($0.metric.displayName)" }.joined(separator: ", ")

        return IdealDay(targets: targets, predictedScore: avgTop, confidence: conf,
            description: "Your ideal tomorrow: \(tStr) -> predicted score \(String(format: "%.0f", avgTop)) (\(String(format: "%.0f", conf * 100))% confidence)")
    }

    // MARK: - Sensitivity Analysis

    private func computeSensitivities(days: [ScoredDay], metrics: [HealthMetric]) -> [SensitivityResult] {
        var results = [SensitivityResult]()
        for m in metrics {
            var xs = [Double](), ys = [Double]()
            for d in days { if let v = d.metricValues[m] { xs.append(v); ys.append(Double(d.score)) } }
            guard xs.count >= Self.minimumDays else { continue }
            let r = linReg(x: xs, y: ys); guard r.rSquared > 0.02 else { continue }
            let deltaPerSD = abs(r.slope * xs.std)
            let dir = (r.slope > 0 && m.higherIsBetter) || (r.slope < 0 && !m.higherIsBetter) ? "increases" : "decreases"
            results.append(SensitivityResult(metric: m, slope: r.slope, rSquared: r.rSquared,
                description: "A 1 SD change in \(m.displayName) \(dir) your score by ~\(String(format: "%.1f", deltaPerSD)) points (R\u{00B2}=\(String(format: "%.2f", r.rSquared)))"))
        }
        results.sort { abs($0.slope) * $0.rSquared > abs($1.slope) * $1.rSquared }
        return Array(results.prefix(10))
    }

    // MARK: - Statistical Helpers

    private func linReg(x: [Double], y: [Double]) -> LinReg {
        let n = Double(x.count); guard n >= 3 else { return LinReg(slope: 0, rSquared: 0) }
        let xm = x.avg, ym = y.avg
        var sxy = 0.0, sxx = 0.0, sst = 0.0
        for i in 0..<x.count { let dx = x[i]-xm, dy = y[i]-ym; sxy += dx*dy; sxx += dx*dx; sst += dy*dy }
        guard sxx > 0, sst > 0 else { return LinReg(slope: 0, rSquared: 0) }
        let sl = sxy / sxx, ic = ym - sl * xm
        var ssr = 0.0; for i in 0..<x.count { let r = y[i] - (sl*x[i]+ic); ssr += r*r }
        return LinReg(slope: sl, rSquared: max(0, 1 - ssr/sst))
    }

    /// Mann-Whitney U test. Returns true if p < 0.05 (two-tailed, normal approximation).
    private func mannWhitneyU(sample: [Double], pop: [Double]) -> Bool {
        let n1 = sample.count, n2 = pop.count
        guard n1 >= 3, n2 >= 10 else { return false }
        struct RV { let v: Double; let isSample: Bool }
        var comb = sample.map { RV(v: $0, isSample: true) } + pop.map { RV(v: $0, isSample: false) }
        comb.sort { $0.v < $1.v }
        let total = comb.count
        var ranks = [Double](repeating: 0, count: total)
        var i = 0
        while i < total {
            var j = i; while j < total - 1 && comb[j+1].v == comb[i].v { j += 1 }
            let avg = Double(i + j) / 2.0 + 1.0
            for k in i...j { ranks[k] = avg }; i = j + 1
        }
        var r1 = 0.0; for idx in 0..<total where comb[idx].isSample { r1 += ranks[idx] }
        let u1 = r1 - Double(n1 * (n1+1)) / 2.0
        let u = Swift.min(u1, Double(n1*n2) - u1)
        let mu = Double(n1*n2) / 2.0
        let sigma = sqrt(Double(n1*n2) * Double(n1+n2+1) / 12.0)
        guard sigma > 0 else { return false }
        return abs((u - mu) / sigma) > 1.96
    }

    private func pctl(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let idx = p * Double(sorted.count - 1)
        let lo = Int(floor(idx)), hi = min(lo + 1, sorted.count - 1)
        return sorted[lo] * (1.0 - (idx - Double(lo))) + sorted[hi] * (idx - Double(lo))
    }

    // MARK: - Data Helpers

    private func rawValue(for metric: HealthMetric, on date: Date, in ts: [HealthMetric: MetricTimeSeries], cal: Calendar) -> Double? {
        guard let series = ts[metric] else { return nil }
        let target = cal.startOfDay(for: date)
        let samples = series.sortedSamples
        var lo = 0, hi = samples.count - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            let midDay = cal.startOfDay(for: samples[mid].date)
            if midDay == target { return samples[mid].value }
            else if midDay < target { lo = mid + 1 } else { hi = mid - 1 }
        }
        return nil
    }

    private func metricsWithCoverage(days: [ScoredDay], minCount: Int) -> [HealthMetric] {
        var counts: [HealthMetric: Int] = [:]
        for d in days { for m in d.metricValues.keys { counts[m, default: 0] += 1 } }
        return counts.filter { $0.value >= minCount }.map(\.key).sorted { $0.rawValue < $1.rawValue }
    }

    private func latestValues(from sorted: [ScoredDay]) -> [HealthMetric: Double] {
        guard let last = sorted.last else { return [:] }
        var vals = last.metricValues
        let lb = min(3, sorted.count)
        for i in stride(from: sorted.count - 2, through: max(0, sorted.count - lb), by: -1) {
            for (m, v) in sorted[i].metricValues where vals[m] == nil { vals[m] = v }
        }
        return vals
    }
}

// MARK: - Private Array Statistics

private extension Array where Element == Double {
    var avg: Double {
        guard !isEmpty else { return 0 }
        var t = 0.0; for v in self { t += v }; return t / Double(count)
    }
    var std: Double {
        guard count > 1 else { return 0 }
        let m = avg; var s = 0.0; for v in self { let d = v - m; s += d * d }
        return sqrt(s / Double(count))
    }
}
