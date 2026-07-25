import Foundation

/// Detects statistically significant changepoints (regime shifts) in health metric time series.
/// Uses CUSUM detection with Welch's t-test validation and co-occurrence analysis to find
/// when a user's baselines fundamentally shifted. gradual changes invisible day-to-day.
final class ChangePointDetector {

    static let minimumDays = 14

    // MARK: - Configuration

    private static let minSegmentDays = 7
    private static let maxRecursionDepth = 4
    private static let coOccurrenceWindowDays = 14
    private static let minEffectSize = 0.5      // Cohen's d threshold
    private static let primaryAlpha = 0.01       // Welch's t-test significance
    private static let coOccurrenceAlpha = 0.05  // Relaxed threshold for related shifts
    private static let mergeWindowDays = 7       // Merge changepoints within this window

    // MARK: - Output Types

    struct ChangePoint {
        let metric: HealthMetric
        let date: Date
        let beforeMean: Double
        let afterMean: Double
        let magnitude: Double           // Cohen's d
        let direction: ChangeDirection
        let confidence: Double          // 0-1
        let daysSinceChange: Int
        let description: String
        let coOccurringChanges: [CoOccurrence]

        enum ChangeDirection: String { case increase, decrease }

        struct CoOccurrence {
            let metric: HealthMetric
            let direction: ChangeDirection
            let magnitude: Double
        }
    }

    // MARK: - Internal Types

    private struct Candidate {
        let date: Date
        let beforeMean: Double, afterMean: Double
        let cohenD: Double
        let pValue: Double
    }

    // MARK: - Public API

    private(set) var changePoints: [ChangePoint] = []
    var isReady: Bool { !changePoints.isEmpty }

    /// Hash of input data from last run. Skip recomputation if unchanged.
    private var lastInputHash: Int = 0

    // MARK: - Detection Entry Point

    /// Detect changepoints across all metrics with sufficient data.
    func detect(timeSeries: [HealthMetric: MetricTimeSeries], baselines: [HealthMetric: UserBaseline]) {
        // Skip if input data hasn't changed since last run
        let inputHash = computeInputHash(timeSeries: timeSeries)
        if inputHash == lastInputHash && isReady { return }
        lastInputHash = inputHash

        changePoints = []
        let calendar = Date.cal

        // Phase 1: CUSUM detection + validation per metric
        var allCandidates: [HealthMetric: [Candidate]] = [:]
        for (metric, series) in timeSeries {
            let samples = series.sortedSamples
            guard samples.count >= Self.minimumDays else { continue }

            var candidates: [Candidate] = []
            detectCUSUM(values: samples.map(\.value), dates: samples.map(\.date),
                        depth: 0, candidates: &candidates)

            let validated = candidates.filter { $0.pValue < Self.primaryAlpha && $0.cohenD >= Self.minEffectSize }
            let merged = mergeNearbyCandidates(validated, calendar: calendar)
            if !merged.isEmpty { allCandidates[metric] = merged }
        }

        // Phase 2: Co-occurrence, attribution, and description generation
        let today = Date()
        var confirmed: [ChangePoint] = []
        for (metric, candidates) in allCandidates {
            for candidate in candidates {
                let coOccurrences = findCoOccurrences(primaryMetric: metric, primaryDate: candidate.date,
                                                      allCandidates: allCandidates, calendar: calendar)
                let attribution = findAttribution(primaryMetric: metric, primaryDate: candidate.date,
                                                   allCandidates: allCandidates, calendar: calendar)
                let direction: ChangePoint.ChangeDirection = candidate.afterMean > candidate.beforeMean ? .increase : .decrease
                let daysSince = calendar.dateComponents([.day], from: candidate.date, to: today).day ?? 0
                let confidence = computeConfidence(pValue: candidate.pValue, cohenD: candidate.cohenD)
                let description = generateDescription(metric: metric, candidate: candidate, direction: direction,
                                                       daysSince: daysSince, coOccurrences: coOccurrences,
                                                       attribution: attribution)

                confirmed.append(ChangePoint(
                    metric: metric, date: candidate.date,
                    beforeMean: candidate.beforeMean, afterMean: candidate.afterMean,
                    magnitude: candidate.cohenD, direction: direction,
                    confidence: confidence, daysSinceChange: daysSince,
                    description: description, coOccurringChanges: coOccurrences
                ))
            }
        }

        changePoints = confirmed.sorted {
            $0.daysSinceChange != $1.daysSinceChange
                ? $0.daysSinceChange < $1.daysSinceChange
                : $0.magnitude > $1.magnitude
        }
    }

    // MARK: - CUSUM Changepoint Detection

    /// Recursive CUSUM: splits the series at the point where cumulative sum exceeds threshold,
    /// then recurses on each sub-segment to find multiple changepoints.
    private func detectCUSUM(
        values: [Double], dates: [Date],
        depth: Int, candidates: inout [Candidate]
    ) {
        let n = values.count
        guard n >= Self.minimumDays, depth < Self.maxRecursionDepth else { return }

        let mu = values.mean
        let sigma = values.standardDeviation
        guard sigma > 0 else { return }

        let k = 0.5 * sigma  // slack
        let h = 4.0 * sigma  // threshold

        var sHigh = 0.0, sLow = 0.0
        var bestIdx = -1, bestVal = 0.0

        for i in 0..<n {
            sHigh = Swift.max(0, sHigh + (values[i] - mu - k))
            sLow = Swift.max(0, sLow - (values[i] - mu) - k)
            let peak = Swift.max(sHigh, sLow)
            if peak > h && peak > bestVal && i >= Self.minSegmentDays && (n - i - 1) >= Self.minSegmentDays {
                bestVal = peak
                bestIdx = i
            }
        }
        guard bestIdx > 0 else { return }

        // Validate with Welch's t-test
        let before = Array(values[0..<bestIdx])
        let after = Array(values[bestIdx..<n])
        let bMean = before.mean, aMean = after.mean
        let bStd = before.standardDeviation, aStd = after.standardDeviation
        let welch = welchTTest(mean1: bMean, std1: bStd, n1: before.count,
                               mean2: aMean, std2: aStd, n2: after.count)
        let pooled = pooledStd(std1: bStd, n1: before.count, std2: aStd, n2: after.count)
        let d = pooled > 0 ? abs(aMean - bMean) / pooled : 0

        candidates.append(Candidate(
            date: dates[bestIdx],
            beforeMean: bMean, afterMean: aMean,
            cohenD: d, pValue: welch.p
        ))

        // Recurse on each sub-segment
        if bestIdx >= Self.minimumDays {
            detectCUSUM(values: Array(values[0..<bestIdx]),
                        dates: Array(dates[0..<bestIdx]),
                        depth: depth + 1, candidates: &candidates)
        }
        if (n - bestIdx) >= Self.minimumDays {
            detectCUSUM(values: Array(values[bestIdx..<n]),
                        dates: Array(dates[bestIdx..<n]),
                        depth: depth + 1, candidates: &candidates)
        }
    }

    // MARK: - Two-Sample Validation (Welch's t-test)

    private func welchTTest(
        mean1: Double, std1: Double, n1: Int,
        mean2: Double, std2: Double, n2: Int
    ) -> (t: Double, p: Double) {
        let n1d = Double(n1), n2d = Double(n2)
        let v1 = std1 * std1, v2 = std2 * std2
        let se = ((v1 / n1d) + (v2 / n2d)).squareRoot()
        guard se > 0 else { return (0, 1.0) }

        let t = abs((mean1 - mean2) / se)

        // Welch-Satterthwaite degrees of freedom
        let num = (v1 / n1d + v2 / n2d) * (v1 / n1d + v2 / n2d)
        let den = (v1 * v1) / (n1d * n1d * (n1d - 1)) + (v2 * v2) / (n2d * n2d * (n2d - 1))
        guard den > 0 else { return (t, 1.0) }

        return (t, tDistPValue(t: t, df: num / den))
    }

    /// Two-tailed p-value via I_{df/(df+t^2)}(df/2, 1/2) using regularized incomplete beta
    private func tDistPValue(t: Double, df: Double) -> Double {
        guard df > 0, t.isFinite else { return 1.0 }
        return Swift.min(1, Swift.max(0, regIncBeta(x: df / (df + t * t), a: df / 2, b: 0.5)))
    }

    /// Regularized incomplete beta I_x(a,b) via Lentz's continued fraction
    private func regIncBeta(x: Double, a: Double, b: Double) -> Double {
        guard x > 0 else { return 0 }
        guard x < 1 else { return 1 }
        if x > (a + 1) / (a + b + 2) {
            return 1 - regIncBeta(x: 1 - x, a: b, b: a)
        }

        let lnB = lgamma(a) + lgamma(b) - lgamma(a + b)
        let front = exp(log(x) * a + log(1 - x) * b - lnB) / a
        let eps = 1e-10

        var c = 1.0
        var d = 1.0 / Swift.max(abs(1.0 - (a + b) * x / (a + 1)), eps)
        var result = d

        for m in 1...200 {
            let md = Double(m)
            // Even step
            var num = md * (b - md) * x / ((a + 2 * md - 1) * (a + 2 * md))
            d = 1 / Swift.max(abs(1 + num * d), eps)
            c = Swift.max(abs(1 + num / c), eps)
            result *= d * c
            // Odd step
            num = -(a + md) * (a + b + md) * x / ((a + 2 * md) * (a + 2 * md + 1))
            d = 1 / Swift.max(abs(1 + num * d), eps)
            c = Swift.max(abs(1 + num / c), eps)
            let delta = d * c
            result *= delta
            if abs(delta - 1) < eps { break }
        }

        return Swift.min(1, Swift.max(0, front * result))
    }

    private func pooledStd(std1: Double, n1: Int, std2: Double, n2: Int) -> Double {
        let n1d = Double(n1), n2d = Double(n2)
        guard n1d + n2d - 2 > 0 else { return 0 }
        return (((n1d - 1) * std1 * std1 + (n2d - 1) * std2 * std2) / (n1d + n2d - 2)).squareRoot()
    }

    // MARK: - Changepoint Merging

    /// Merge candidates within `mergeWindowDays`, keeping the one with largest effect size.
    private func mergeNearbyCandidates(_ candidates: [Candidate], calendar: Calendar) -> [Candidate] {
        guard candidates.count > 1 else { return candidates }
        let sorted = candidates.sorted { $0.date < $1.date }
        var merged: [Candidate] = []
        var i = 0
        while i < sorted.count {
            var best = sorted[i]
            var j = i + 1
            while j < sorted.count {
                let gap = abs(calendar.dateComponents([.day], from: best.date, to: sorted[j].date).day ?? 0)
                guard gap <= Self.mergeWindowDays else { break }
                if sorted[j].cohenD > best.cohenD { best = sorted[j] }
                j += 1
            }
            merged.append(best)
            i = j
        }
        return merged
    }

    // MARK: - Co-occurrence Detection

    /// Find other metrics that changed within +/-coOccurrenceWindowDays of a primary changepoint.
    private func findCoOccurrences(
        primaryMetric: HealthMetric, primaryDate: Date,
        allCandidates: [HealthMetric: [Candidate]], calendar: Calendar
    ) -> [ChangePoint.CoOccurrence] {
        var result: [ChangePoint.CoOccurrence] = []
        for (metric, candidates) in allCandidates where metric != primaryMetric {
            for c in candidates {
                let lag = calendar.dateComponents([.day], from: primaryDate, to: c.date).day ?? 0
                guard abs(lag) <= Self.coOccurrenceWindowDays, c.pValue < Self.coOccurrenceAlpha else { continue }
                result.append(ChangePoint.CoOccurrence(
                    metric: metric,
                    direction: c.afterMean > c.beforeMean ? .increase : .decrease,
                    magnitude: c.cohenD
                ))
            }
        }
        return result.sorted { $0.magnitude > $1.magnitude }
    }

    // MARK: - Impact Attribution

    /// Find a potential causal metric that changed 1-14 days BEFORE the primary change.
    private func findAttribution(
        primaryMetric: HealthMetric, primaryDate: Date,
        allCandidates: [HealthMetric: [Candidate]], calendar: Calendar
    ) -> (metric: HealthMetric, lagDays: Int, direction: ChangePoint.ChangeDirection)? {
        var best: (metric: HealthMetric, lag: Int, dir: ChangePoint.ChangeDirection, mag: Double)?
        for (metric, candidates) in allCandidates where metric != primaryMetric {
            for c in candidates {
                let lag = calendar.dateComponents([.day], from: c.date, to: primaryDate).day ?? 0
                guard lag >= 1, lag <= Self.coOccurrenceWindowDays, c.pValue < Self.coOccurrenceAlpha else { continue }
                let dir: ChangePoint.ChangeDirection = c.afterMean > c.beforeMean ? .increase : .decrease
                if best.map({ c.cohenD > $0.mag }) ?? true {
                    best = (metric, lag, dir, c.cohenD)
                }
            }
        }
        guard let b = best else { return nil }
        return (b.metric, b.lag, b.dir)
    }

    // MARK: - Confidence Computation

    /// Geometric mean of p-value significance and effect size, mapped to 0-1.
    private func computeConfidence(pValue: Double, cohenD: Double) -> Double {
        let pComp = Swift.min(1, -log10(Swift.max(pValue, 1e-10)) / 4.0)
        let dComp = Swift.min(1, cohenD / 1.5)
        return (pComp * dComp).squareRoot()
    }

    // MARK: - Natural Language Generation

    private func generateDescription(
        metric: HealthMetric, candidate: Candidate,
        direction: ChangePoint.ChangeDirection, daysSince: Int,
        coOccurrences: [ChangePoint.CoOccurrence],
        attribution: (metric: HealthMetric, lagDays: Int, direction: ChangePoint.ChangeDirection)?
    ) -> String {
        var parts: [String] = []
        let unit = metric.unit
        let u = unit.isEmpty ? "" : " \(unit)"
        let dir = direction == .increase ? "up" : "down"
        let delta = metric.formatValue(abs(candidate.afterMean - candidate.beforeMean))

        parts.append(
            "Your \(metric.displayName) shifted \(dir) by \(delta)\(u) around \(fmtDate(candidate.date)) " +
            "(from \(metric.formatValue(candidate.beforeMean)) to \(metric.formatValue(candidate.afterMean))\(u))."
        )

        // Duration context
        if daysSince <= 7 {
            parts.append("This happened in the past week.")
        } else if daysSince <= 30 {
            parts.append("You've been in this new pattern for \(daysSince) days.")
        } else {
            parts.append("This shift has been sustained for \(daysSince / 7) weeks.")
        }

        // Attribution (potential cause)
        if let attr = attribution {
            let verb = attr.direction == .increase ? "increased" : "decreased"
            parts.append("This may be related to your \(attr.metric.displayName), which \(verb) " +
                          "\(attr.lagDays) day\(attr.lagDays == 1 ? "" : "s") earlier.")
        }

        // Co-occurring changes (top 2)
        let topCo = coOccurrences.prefix(2)
        if !topCo.isEmpty {
            let descs = topCo.map { "\($0.metric.displayName) also \($0.direction == .increase ? "increased" : "decreased")" }
            parts.append("Around the same time, your \(descs.joined(separator: " and ")).")
        }

        // Actionability
        parts.append(actionAdvice(metric: metric, direction: direction, cohenD: candidate.cohenD))
        return parts.joined(separator: " ")
    }

    private func actionAdvice(metric: HealthMetric, direction: ChangePoint.ChangeDirection, cohenD: Double) -> String {
        let positive = (direction == .increase && metric.higherIsBetter)
                    || (direction == .decrease && !metric.higherIsBetter)
        if positive {
            return cohenD >= 1.0
                ? "This is a significant positive shift. whatever you changed is working well."
                : "Positive trend. keep up what you're doing."
        }
        if cohenD >= 1.5 { return "This is a large shift worth discussing with your doctor if it persists." }
        if cohenD >= 1.0 { return "This is a notable change. worth monitoring closely over the next few weeks." }
        return "Worth keeping an eye on to see if this trend continues."
    }

    /// Cached short-date formatter. avoids per-call allocation
    /// when describing change points across many metrics.
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()

    private func fmtDate(_ date: Date) -> String {
        Self.shortDateFormatter.string(from: date)
    }

    /// Lightweight hash of input data to skip recomputation when unchanged.
    private func computeInputHash(timeSeries: [HealthMetric: MetricTimeSeries]) -> Int {
        var hasher = Hasher()
        for (metric, series) in timeSeries.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            hasher.combine(metric.rawValue)
            hasher.combine(series.samples.count)
            if let last = series.samples.last {
                hasher.combine(last.value)
                hasher.combine(last.date.timeIntervalSinceReferenceDate)
            }
        }
        return hasher.finalize()
    }
}
