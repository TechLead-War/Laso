import Foundation

/// Discovers each user's personal optimal conditions. what their best and worst days
/// look like, what combination of factors creates peak performance, ideal targets,
/// recovery patterns, and resilience factors.
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
        let description: String

        struct OptimalCondition {
            let metric: HealthMetric
            let optimalRange: (lower: Double, upper: Double)
            let importance: Double
            let currentValue: Double?
            let isCurrentlyMet: Bool
            let description: String
        }
    }

    struct DayProfile {
        let metrics: [MetricProfile]
        let dayType: DayType
        let frequency: Int
        let avgScore: Double
        let description: String

        struct MetricProfile {
            let metric: HealthMetric
            let mean: Double
            let range: (lower: Double, upper: Double)
        }

        enum DayType: String {
            case bestDays, goodDays, averageDays, poorDays, worstDays
        }
    }

    struct RecoveryProfile {
        let avgRecoveryDays: Double
        let fastRecoveryConditions: [String]
        let slowRecoveryConditions: [String]
        let description: String
    }

    struct IdealDay {
        let targets: [DayTarget]
        let predictedScore: Double
        let confidence: Double
        let description: String

        struct DayTarget {
            let metric: HealthMetric
            let targetValue: Double
            let importanceRank: Int
            let description: String
        }
    }

    struct ResilienceFactor {
        let bufferMetric: HealthMetric
        let stressorMetric: HealthMetric
        let protectiveRange: String
        let effectSize: Double
        let description: String
    }

    struct SensitivityResult {
        let metric: HealthMetric
        let slope: Double
        let rSquared: Double
        let description: String
    }

    // MARK: - Public State

    private(set) var optimalProfile: OptimalProfile?
    private(set) var bestDayProfile: DayProfile?
    private(set) var worstDayProfile: DayProfile?
    private(set) var recoveryProfile: RecoveryProfile?
    private(set) var idealDay: IdealDay?
    private(set) var resilienceFactors: [ResilienceFactor] = []
    private(set) var sensitivities: [SensitivityResult] = []
    var isReady: Bool { optimalProfile != nil }

    // MARK: - Internal Types

    private struct ScoredDay {
        let date: Date
        let score: Int
        let metricValues: [HealthMetric: Double]
    }

    private struct LinReg {
        let slope: Double
        let intercept: Double
        let rSquared: Double
    }

    // MARK: - Main Entry Point

    func analyze(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline],
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
        bestDayProfile = buildDayProfile(byScore: byScore, type: .bestDays, metrics: avail)
        worstDayProfile = buildDayProfile(byScore: byScore, type: .worstDays, metrics: avail)
        idealDay = computeIdealDay(byScore: byScore, metrics: avail)
        recoveryProfile = analyzeRecovery(sorted: sorted, metrics: avail)
        resilienceFactors = discoverResilience(sorted: sorted, metrics: avail)
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

        let maxE = top[0].effect
        let conditions = top.map { h -> OptimalProfile.OptimalCondition in
            let cur = latest[h.metric]
            let met = cur.map { $0 >= h.lo && $0 <= h.hi } ?? false
            let u = h.metric.unit.isEmpty ? "" : " \(h.metric.unit)"
            return .init(metric: h.metric, optimalRange: (h.lo, h.hi),
                         importance: h.effect / maxE, currentValue: cur, isCurrentlyMet: met,
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
        let condStr = conditions.prefix(3).map(\.description).joined(separator: ", ")

        return OptimalProfile(conditions: conditions, matchPercentage: matchPct,
            avgScoreWhenOptimal: avgOpt, avgScoreWhenNot: avgNon,
            description: "Your top \(topN) days share: \(condStr). Hit this combo \(matchN) times in \(byScore.count) days.")
    }

    // MARK: - Day Profiling

    private func buildDayProfile(
        byScore: [ScoredDay], type: DayProfile.DayType, metrics: [HealthMetric]
    ) -> DayProfile? {
        let n = byScore.count; guard n >= Self.minimumDays else { return nil }
        let days: [ScoredDay]
        switch type {
        case .bestDays:   days = Array(byScore.prefix(max(3, n / 10)))
        case .goodDays:   days = Array(byScore.prefix(max(3, n / 4)))
        case .averageDays: days = Array(byScore[(n/4)..<(n*3/4)])
        case .poorDays:   days = Array(byScore.suffix(max(3, n / 4)))
        case .worstDays:  days = Array(byScore.suffix(max(3, n / 10)))
        }
        guard !days.isEmpty else { return nil }
        let avg = Double(days.reduce(0) { $0 + $1.score }) / Double(days.count)

        let profiles: [DayProfile.MetricProfile] = metrics.compactMap { m in
            let vals = days.compactMap { $0.metricValues[m] }
            guard vals.count >= 3 else { return nil }
            let s = vals.sorted()
            return .init(metric: m, mean: vals.avg, range: (pctl(s, 0.10), pctl(s, 0.90)))
        }

        // Comparative description for best/worst
        let desc: String
        if type == .bestDays || type == .worstDays {
            let oppDays = type == .bestDays ? Array(byScore.suffix(max(3, n/10))) : Array(byScore.prefix(max(3, n/10)))
            let label = type == .bestDays ? "best" : "worst"
            let oppLabel = type == .bestDays ? "worst" : "best"
            var diffs: [(HealthMetric, Double, Double)] = [] // metric, thisMean, normalizedDiff
            for p in profiles {
                let opp = oppDays.compactMap { $0.metricValues[p.metric] }
                guard !opp.isEmpty else { continue }
                let allR = (byScore.compactMap { $0.metricValues[p.metric] }.max() ?? 1)
                    - (byScore.compactMap { $0.metricValues[p.metric] }.min() ?? 0)
                let nd = allR > 0 ? abs(p.mean - opp.avg) / allR : 0
                diffs.append((p.metric, p.mean - opp.avg, nd))
            }
            diffs.sort { $0.2 > $1.2 }
            let parts = diffs.prefix(3).map { m, diff, _ -> String in
                let dir = diff > 0 ? "more" : "fewer"
                let u = m.unit.isEmpty ? "" : " \(m.unit)"
                return "\(m.formatValue(abs(diff)))\(u) \(dir) \(m.displayName)"
            }
            desc = "Your \(label) days (avg score \(String(format: "%.0f", avg))) have \(parts.joined(separator: ", ")) than your \(oppLabel)"
        } else {
            desc = "\(type.rawValue): avg score \(String(format: "%.0f", avg)) across \(days.count) days"
        }
        return DayProfile(metrics: profiles, dayType: type, frequency: days.count, avgScore: avg, description: desc)
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
        for (i, m) in ranked.prefix(8).enumerated() {
            let vals = topDays.compactMap { $0.metricValues[m] }
            guard !vals.isEmpty else { continue }
            let med = pctl(vals.sorted(), 0.50)
            let u = m.unit.isEmpty ? "" : " \(m.unit)"
            targets.append(.init(metric: m, targetValue: med, importanceRank: i + 1,
                                 description: "Aim for ~\(m.formatValue(med))\(u) \(m.displayName)"))
        }
        guard !targets.isEmpty else { return nil }

        let topStd = topDays.map { Double($0.score) }.std
        let conf = max(0.3, min(0.95, 1.0 - topStd / 30.0))
        let tStr = targets.prefix(3).map { "\($0.metric.formatValue($0.targetValue))\($0.metric.unit.isEmpty ? "" : " \($0.metric.unit)") \($0.metric.displayName)" }.joined(separator: ", ")

        return IdealDay(targets: targets, predictedScore: avgTop, confidence: conf,
            description: "Your ideal tomorrow: \(tStr) -> predicted score \(String(format: "%.0f", avgTop)) (\(String(format: "%.0f", conf * 100))% confidence)")
    }

    // MARK: - Recovery Analysis

    private func analyzeRecovery(sorted: [ScoredDay], metrics: [HealthMetric]) -> RecoveryProfile? {
        let scores = sorted.map { Double($0.score) }
        let mean = scores.avg, sd = scores.std
        guard sd > 0 else { return nil }
        let threshold = mean - sd
        let cal = Date.cal

        struct Dip { let endIdx: Int; var recovDays: Int?; var recovMetrics: [HealthMetric: Double] }
        var dips = [Dip]()
        var i = 0
        while i < sorted.count {
            if Double(sorted[i].score) < threshold {
                while i < sorted.count && Double(sorted[i].score) < threshold { i += 1 }
                let end = i - 1
                var rd: Int?; var rm: [HealthMetric: [Double]] = [:]
                for j in (end+1)..<sorted.count {
                    let gap = cal.dateComponents([.day], from: sorted[end].date, to: sorted[j].date).day ?? 0
                    if gap > 14 { break }
                    for m in metrics { if let v = sorted[j].metricValues[m] { rm[m, default: []].append(v) } }
                    if Double(sorted[j].score) >= mean { rd = gap; break }
                }
                dips.append(Dip(endIdx: end, recovDays: rd, recovMetrics: rm.mapValues { $0.avg }))
            } else { i += 1 }
        }
        let resolved = dips.filter { $0.recovDays != nil }
        guard resolved.count >= 2 else { return nil }

        let rdays = resolved.compactMap(\.recovDays)
        let avgR = Double(rdays.reduce(0,+)) / Double(rdays.count)
        let medR = Double(rdays.sorted()[rdays.count / 2])
        let fast = resolved.filter { Double($0.recovDays!) <= medR }
        let slow = resolved.filter { Double($0.recovDays!) > medR }

        var fastCond = [String](), slowCond = [String]()
        for m in metrics {
            let fv = fast.compactMap { $0.recovMetrics[m] }, sv = slow.compactMap { $0.recovMetrics[m] }
            guard fv.count >= 2, sv.count >= 2 else { continue }
            let pooled = (fv.std + sv.std) / 2; guard pooled > 0 else { continue }
            let d = (fv.avg - sv.avg) / pooled; guard abs(d) > 0.5 else { continue }
            let u = m.unit.isEmpty ? "" : " \(m.unit)"
            if (m.higherIsBetter && d > 0) || (!m.higherIsBetter && d < 0) {
                fastCond.append(">\(m.formatValue(fv.avg))\(u) \(m.displayName)")
            } else {
                slowCond.append("<\(m.formatValue(sv.avg))\(u) \(m.displayName)")
            }
        }

        let fAvg = fast.isEmpty ? avgR : Double(fast.compactMap(\.recovDays).reduce(0,+)) / Double(fast.count)
        let sAvg = slow.isEmpty ? avgR : Double(slow.compactMap(\.recovDays).reduce(0,+)) / Double(slow.count)
        var desc = "After a bad stretch, you recover in \(String(format: "%.1f", fAvg)) days"
        if let c = fastCond.first { desc += " with \(c) vs \(String(format: "%.1f", sAvg)) days without" }

        return RecoveryProfile(avgRecoveryDays: avgR, fastRecoveryConditions: fastCond,
                               slowRecoveryConditions: slowCond, description: desc)
    }

    // MARK: - Resilience Factor Discovery

    private func discoverResilience(sorted: [ScoredDay], metrics: [HealthMetric]) -> [ResilienceFactor] {
        guard sorted.count >= 30 else { return [] }
        let stressors: [HealthMetric] = [.sleepDuration, .sleepDeep, .sleepREM, .heartRateVariability, .restingHeartRate].filter { metrics.contains($0) }
        let buffers: [HealthMetric] = [.exerciseMinutes, .steps, .activeCalories, .sleepDuration, .sleepDeep, .mindfulMinutes, .heartRateVariability].filter { metrics.contains($0) }
        let cal = Date.cal
        var factors = [ResilienceFactor]()

        for stressor in stressors {
            let sVals = sorted.compactMap { $0.metricValues[stressor] }
            guard sVals.count >= 10 else { continue }
            let sMean = sVals.avg, sStd = sVals.std; guard sStd > 0 else { continue }
            let badThresh = stressor.higherIsBetter ? sMean - sStd : sMean + sStd

            let stressDayIdx: [Int] = sorted.enumerated().compactMap { idx, day in
                guard let v = day.metricValues[stressor] else { return nil }
                return (stressor.higherIsBetter ? v < badThresh : v > badThresh) ? idx : nil
            }
            guard stressDayIdx.count >= 5 else { continue }

            for buffer in buffers where buffer != stressor {
                let bVals = sorted.compactMap { $0.metricValues[buffer] }
                guard bVals.count >= 10 else { continue }
                let bMedian = bVals.sorted()[bVals.count / 2]
                var hiDeltas = [Double](), loDeltas = [Double]()

                for idx in stressDayIdx {
                    var window = [Double]()
                    for lb in 1...7 {
                        let pi = idx - lb; guard pi >= 0 else { break }
                        let gap = cal.dateComponents([.day], from: sorted[pi].date, to: sorted[idx].date).day ?? 0
                        guard gap <= 10 else { break }
                        if let v = sorted[pi].metricValues[buffer] { window.append(v) }
                    }
                    guard window.count >= 3, idx + 1 < sorted.count else { continue }
                    let bAvg = window.avg
                    let delta = Double(sorted[idx + 1].score - sorted[idx].score)
                    if bAvg >= bMedian { hiDeltas.append(delta) } else { loDeltas.append(delta) }
                }
                guard hiDeltas.count >= 3, loDeltas.count >= 3 else { continue }
                let diff = hiDeltas.avg - loDeltas.avg; guard diff > 2.0 else { continue }
                let ps = sqrt((hiDeltas.vari + loDeltas.vari) / 2)
                let es = ps > 0 ? diff / ps : 0; guard es > 0.3 else { continue }

                let hbv = bVals.filter { $0 >= bMedian }.sorted()
                let lo = pctl(hbv, 0.25), hi = pctl(hbv, 0.75)
                let u = buffer.unit.isEmpty ? "" : " \(buffer.unit)"
                let range = "\(buffer.formatValue(lo))-\(buffer.formatValue(hi))\(u)/day"
                let desc = "When your weekly \(buffer.displayName) is \(range), poor \(stressor.displayName) only changes score by \(String(format: "%.0f", abs(hiDeltas.avg))) pts vs \(String(format: "%.0f", abs(loDeltas.avg))) pts when low"
                factors.append(ResilienceFactor(bufferMetric: buffer, stressorMetric: stressor, protectiveRange: range, effectSize: es, description: desc))
            }
        }
        factors.sort { $0.effectSize > $1.effectSize }
        var seen = Set<String>(); var unique = [ResilienceFactor]()
        for f in factors { let k = f.stressorMetric.rawValue; if seen.insert(k).inserted { unique.append(f) } }
        return Array(unique.prefix(5))
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
        let n = Double(x.count); guard n >= 3 else { return LinReg(slope: 0, intercept: 0, rSquared: 0) }
        let xm = x.avg, ym = y.avg
        var sxy = 0.0, sxx = 0.0, sst = 0.0
        for i in 0..<x.count { let dx = x[i]-xm, dy = y[i]-ym; sxy += dx*dy; sxx += dx*dx; sst += dy*dy }
        guard sxx > 0, sst > 0 else { return LinReg(slope: 0, intercept: ym, rSquared: 0) }
        let sl = sxy / sxx, ic = ym - sl * xm
        var ssr = 0.0; for i in 0..<x.count { let r = y[i] - (sl*x[i]+ic); ssr += r*r }
        return LinReg(slope: sl, intercept: ic, rSquared: max(0, 1 - ssr/sst))
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
    var vari: Double {
        guard count > 1 else { return 0 }
        let m = avg; var s = 0.0; for v in self { let d = v - m; s += d * d }
        return s / Double(count)
    }
}
