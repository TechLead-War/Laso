import Foundation

/// Discovers conditional relationships, dose-response curves, and moderation effects
/// that reveal non-obvious health patterns users cannot see from single-metric views.
///
/// **Statistical methods:** Pearson correlation in subgroups, Fisher's z-test for comparing
/// two correlations, lack-of-fit F-test for non-linearity, multiple comparison correction (p < 0.01).
final class InteractionEffectEngine {
    static let minimumDays = 14

    // MARK: - Result Types

    struct InteractionEffect {
        let cause: HealthMetric
        let effect: HealthMetric
        let effectType: EffectType
        let description: String
        let strength: Double          // 0-1 effect size
        let confidence: Double        // statistical confidence
        let sampleCount: Int
        let condition: String?
        let discoveredAt: Date

        enum EffectType: String {
            case doseResponse, conditionalPositive, conditionalNegative
            case uShape, invertedU, threshold, saturation, moderation
        }
    }

    struct DoseResponseCurve {
        let cause: HealthMetric
        let effect: HealthMetric
        let bins: [DoseResponseBin]
        let optimalRange: (lower: Double, upper: Double)?
        let description: String

        struct DoseResponseBin {
            let binCenter: Double
            let effectMean: Double
            let effectStd: Double
            let sampleCount: Int
        }
    }

    // MARK: - State

    private(set) var effects: [InteractionEffect] = []
    private(set) var doseResponseCurves: [DoseResponseCurve] = []
    private(set) var conditionalEffects: [InteractionEffect] = []

    var isReady: Bool { !effects.isEmpty }

    // MARK: - Constants

    private static let minCorrelation = 0.15
    private static let alpha = 0.01
    private static let minModerationDelta = 0.2
    private static let minBinSamples = 5

    private static let priorityPairs: [(HealthMetric, HealthMetric)] = [
        (.sleepDuration, .heartRateVariability), (.sleepDuration, .restingHeartRate),
        (.sleepDuration, .activeCalories),       (.sleepDuration, .steps),
        (.exerciseMinutes, .sleepDuration),       (.exerciseMinutes, .sleepDeep),
        (.exerciseMinutes, .heartRateVariability), (.exerciseMinutes, .restingHeartRate),
        (.steps, .sleepDuration),                 (.steps, .heartRateVariability),
        (.activeCalories, .sleepDuration),         (.activeCalories, .heartRateVariability),
        (.heartRateVariability, .activeCalories),  (.heartRateVariability, .steps),
        (.caffeineIntake, .sleepDuration),         (.caffeineIntake, .sleepDeep),
        (.mindfulMinutes, .heartRateVariability),  (.mindfulMinutes, .restingHeartRate),
        (.waterIntake, .heartRateVariability),
    ]

    // MARK: - Discovery (Main Entry Point)

    /// Run all interaction analyses. Returns discovered effects sorted by strength.
    func discover(
        timeSeries: [HealthMetric: MetricTimeSeries],
        baselines: [HealthMetric: UserBaseline]
    ) -> [InteractionEffect] {
        let calendar = Date.cal
        var dateValues: [HealthMetric: [Date: Double]] = [:]
        for (metric, series) in timeSeries {
            var dv: [Date: Double] = [:]
            for sample in series.sortedSamples {
                dv[calendar.startOfDay(for: sample.date)] = sample.value
            }
            dateValues[metric] = dv
        }

        let available = Array(dateValues.keys).sorted { $0.rawValue < $1.rawValue }
        guard available.count >= 2 else { return [] }

        // Collect candidate pairs: priority first, then all with |r| > threshold
        var pairs: [(HealthMetric, HealthMetric)] = []
        var seen: Set<String> = []

        for (c, e) in Self.priorityPairs where dateValues[c] != nil && dateValues[e] != nil {
            if seen.insert(pairKey(c, e)).inserted { pairs.append((c, e)) }
        }
        for i in 0..<available.count {
            for j in 0..<available.count where i != j {
                let (c, e) = (available[i], available[j])
                guard !seen.contains(pairKey(c, e)) else { continue }
                let (cv, ev) = aligned(c, e, dateValues, calendar)
                guard cv.count >= Self.minimumDays,
                      let r = [Double].pearsonCorrelation(cv, ev),
                      abs(r) >= Self.minCorrelation else { continue }
                seen.insert(pairKey(c, e))
                pairs.append((c, e))
            }
        }

        var allEffects: [InteractionEffect] = []
        var allCurves: [DoseResponseCurve] = []
        var allConditional: [InteractionEffect] = []

        for (idx, (cause, effect)) in pairs.enumerated() {
            // Bail out mid-loop if device reaches critical thermal state
            if idx % 5 == 0 && ProcessInfo.processInfo.thermalState == .critical { break }

            let (cv, ev) = aligned(cause, effect, dateValues, calendar)
            guard cv.count >= Self.minimumDays else { continue }

            if let curve = analyzeDoseResponse(cause: cause, effect: effect, cv: cv, ev: ev, baselines: baselines) {
                allCurves.append(curve)
                if let ie = effectFromCurve(curve, n: cv.count) { allEffects.append(ie) }
            }

            let (cv2, ev2, dates) = alignedWithDates(cause, effect, dateValues, calendar)
            if cv2.count >= Self.minimumDays {
                let ce = analyzeConditional(cause: cause, effect: effect, cv: cv2, ev: ev2, dates: dates, baselines: baselines, cal: calendar)
                allConditional.append(contentsOf: ce)
                allEffects.append(contentsOf: ce)
            }

            allEffects.append(contentsOf: analyzeModeration(
                cause: cause, effect: effect, dateValues: dateValues,
                available: available, calendar: calendar
            ))
        }

        allEffects.sort { $0.strength > $1.strength }
        effects = allEffects
        doseResponseCurves = allCurves
        conditionalEffects = allConditional
        return allEffects
    }

    // MARK: - Dose-Response Analysis

    private func analyzeDoseResponse(
        cause: HealthMetric, effect: HealthMetric,
        cv: [Double], ev: [Double],
        baselines: [HealthMetric: UserBaseline]
    ) -> DoseResponseCurve? {
        let n = cv.count
        guard n >= Self.minimumDays else { return nil }
        let binCount = n < 60 ? 5 : (n < 120 ? 6 : (n < 200 ? 7 : 8))

        // Quantile-based bin edges
        let sorted = cv.sorted()
        var edges = (0...binCount).map { i -> Double in
            sorted[Swift.min(Int(Double(i) / Double(binCount) * Double(n - 1)), n - 1)]
        }
        for i in 1..<edges.count where edges[i] <= edges[i - 1] { edges[i] = edges[i - 1] + 1e-9 }

        // Bin observations
        var binE: [[Double]] = .init(repeating: [], count: binCount)
        var binC: [[Double]] = .init(repeating: [], count: binCount)
        for i in 0..<n {
            var b = binCount - 1
            for j in 0..<(binCount - 1) where cv[i] < edges[j + 1] { b = j; break }
            binE[b].append(ev[i]); binC[b].append(cv[i])
        }

        var bins: [DoseResponseCurve.DoseResponseBin] = []
        for b in 0..<binCount where binE[b].count >= Self.minBinSamples {
            bins.append(.init(binCenter: binC[b].mean, effectMean: binE[b].mean,
                              effectStd: binE[b].standardDeviation, sampleCount: binE[b].count))
        }
        guard bins.count >= 3 else { return nil }

        let shape = detectShape(bins)
        guard shape != .noPattern else { return nil }
        let optimal = findOptimalRange(bins, effect)
        let desc = describeCurve(cause, effect, bins, shape, optimal, baselines)

        return DoseResponseCurve(cause: cause, effect: effect, bins: bins,
                                  optimalRange: optimal, description: desc)
    }

    // MARK: - Shape Detection

    private enum Shape { case monotoneUp, monotoneDown, uShape, invertedU, threshold, saturation, noPattern }

    private func detectShape(_ bins: [DoseResponseCurve.DoseResponseBin]) -> Shape {
        let m = bins.map(\.effectMean)
        let n = m.count
        guard n >= 3 else { return .noPattern }
        let steps = n - 1
        let ups = (1..<n).filter { m[$0] > m[$0 - 1] }.count
        let downs = (1..<n).filter { m[$0] < m[$0 - 1] }.count
        if ups == steps { return .monotoneUp }
        if downs == steps { return .monotoneDown }

        let tolerance = m.standardDeviation * 0.2
        // Inverted-U
        if let pk = m.indices.max(by: { m[$0] < m[$1] }), pk > 0, pk < n - 1 {
            if (0..<pk).allSatisfy({ m[$0] <= m[$0 + 1] + tolerance }) &&
               (pk..<n - 1).allSatisfy({ m[$0] >= m[$0 + 1] - tolerance }) { return .invertedU }
        }
        // U-shape
        if let tr = m.indices.min(by: { m[$0] < m[$1] }), tr > 0, tr < n - 1 {
            if (0..<tr).allSatisfy({ m[$0] >= m[$0 + 1] - tolerance }) &&
               (tr..<n - 1).allSatisfy({ m[$0] <= m[$0 + 1] + tolerance }) { return .uShape }
        }
        // Saturation / Threshold (split at half)
        if n >= 4 {
            let h = n / 2
            let r1 = (m[0..<h].max() ?? 0) - (m[0..<h].min() ?? 0)
            let r2 = (m[h..<n].max() ?? 0) - (m[h..<n].min() ?? 0)
            if r1 > 0, r2 / r1 < 0.3 { return .saturation }
            if r2 > 0, r1 / r2 < 0.3 { return .threshold }
        }
        return .noPattern
    }

    // MARK: - Sweet Spot Finder

    private func findOptimalRange(
        _ bins: [DoseResponseCurve.DoseResponseBin], _ effect: HealthMetric
    ) -> (lower: Double, upper: Double)? {
        guard bins.count >= 3 else { return nil }
        let higher = effect.higherIsBetter
        let sortedM = bins.map(\.effectMean).sorted()
        let idx = higher
            ? Swift.max(0, Int(Double(sortedM.count) * 0.7))
            : Swift.min(sortedM.count - 1, Int(Double(sortedM.count) * 0.3))
        let threshold = sortedM[idx]
        let good = higher ? bins.filter { $0.effectMean >= threshold } : bins.filter { $0.effectMean <= threshold }
        guard let f = good.first, let l = good.last else { return nil }
        let halfBin = bins.count > 1 ? abs(bins[1].binCenter - bins[0].binCenter) / 2 : 0
        return (lower: f.binCenter - halfBin, upper: l.binCenter + halfBin)
    }

    private func effectFromCurve(_ curve: DoseResponseCurve, n: Int) -> InteractionEffect? {
        let bins = curve.bins
        guard bins.count >= 3 else { return nil }
        let m = bins.map(\.effectMean)
        let range = (m.max() ?? 0) - (m.min() ?? 0)
        let pStd = pooledStd(bins)
        guard pStd > 0 else { return nil }
        let eff = Swift.min(range / pStd, 1.0)
        guard eff > 0.15 else { return nil }

        let shape = detectShape(bins)
        let (eType, cond): (InteractionEffect.EffectType, String?) = {
            switch shape {
            case .monotoneUp, .monotoneDown: return (.doseResponse, nil)
            case .uShape:
                let t = bins.min(by: { $0.effectMean < $1.effectMean })
                return (.uShape, t.map { "nadir near \(curve.cause.formatValue($0.binCenter)) \(curve.cause.unit)" })
            case .invertedU:
                let p = bins.max(by: { $0.effectMean < $1.effectMean })
                return (.invertedU, p.map { "peak near \(curve.cause.formatValue($0.binCenter)) \(curve.cause.unit)" })
            case .saturation:
                return (.saturation, findChangePoint(bins, rising: false).map { "plateaus after \(curve.cause.formatValue($0)) \(curve.cause.unit)" })
            case .threshold:
                return (.threshold, findChangePoint(bins, rising: true).map { "kicks in after \(curve.cause.formatValue($0)) \(curve.cause.unit)" })
            case .noPattern: return (.doseResponse, nil)
            }
        }()
        let conf = Swift.min(1.0, Double(n) / 120.0) * binConsistency(bins)
        return InteractionEffect(cause: curve.cause, effect: curve.effect, effectType: eType,
                                  description: curve.description, strength: eff, confidence: conf,
                                  sampleCount: n, condition: cond, discoveredAt: Date())
    }

    // MARK: - Conditional Effect Analysis

    private func analyzeConditional(
        cause: HealthMetric, effect: HealthMetric,
        cv: [Double], ev: [Double], dates: [Date],
        baselines: [HealthMetric: UserBaseline], cal: Calendar
    ) -> [InteractionEffect] {
        var results: [InteractionEffect] = []
        let n = cv.count

        // Split: weekday vs weekend
        var wdC = [Double](), wdE = [Double](), weC = [Double](), weE = [Double]()
        for i in 0..<n {
            let dow = Date.cal.component(.weekday, from: dates[i])
            if dow == 1 || dow == 7 { weC.append(cv[i]); weE.append(ev[i]) }
            else { wdC.append(cv[i]); wdE.append(ev[i]) }
        }
        if let rWd = [Double].pearsonCorrelation(wdC, wdE),
           let rWe = [Double].pearsonCorrelation(weC, weE),
           wdC.count >= 10, weC.count >= 5 {
            let z = fisherZ(r1: rWd, n1: wdC.count, r2: rWe, n2: weC.count)
            if z.p < Self.alpha, abs(rWd - rWe) > Self.minModerationDelta {
                let (strong, weak) = abs(rWd) > abs(rWe) ? ("weekdays", "weekends") : ("weekends", "weekdays")
                let (sR, wR) = strong == "weekdays" ? (rWd, rWe) : (rWe, rWd)
                let verb = sR > 0 ? "improves" : "worsens"
                results.append(InteractionEffect(
                    cause: cause, effect: effect,
                    effectType: sR > 0 ? .conditionalPositive : .conditionalNegative,
                    description: "\(cause.displayName) \(verb) your \(effect.displayName) on \(strong) (r=\(f2(sR))) but has little effect on \(weak) (r=\(f2(wR)))",
                    strength: Swift.min(abs(rWd - rWe), 1.0), confidence: 1.0 - z.p,
                    sampleCount: n, condition: "on \(strong) only", discoveredAt: Date()
                ))
            }
        }

        // Split: above/below cause baseline
        if let bl = baselines[cause] {
            var aC = [Double](), aE = [Double](), bC = [Double](), bE = [Double]()
            for i in 0..<n {
                if cv[i] >= bl.mean { aC.append(cv[i]); aE.append(ev[i]) }
                else { bC.append(cv[i]); bE.append(ev[i]) }
            }
            if let rA = [Double].pearsonCorrelation(aC, aE),
               let rB = [Double].pearsonCorrelation(bC, bE),
               aC.count >= 10, bC.count >= 10 {
                let z = fisherZ(r1: rA, n1: aC.count, r2: rB, n2: bC.count)
                if z.p < Self.alpha, abs(rA - rB) > Self.minModerationDelta {
                    let (grp, sR, wR) = abs(rA) > abs(rB) ? ("above", rA, rB) : ("below", rB, rA)
                    let bv = cause.formatValue(bl.mean)
                    let verb = sR > 0 ? "helps" : "hurts"
                    results.append(InteractionEffect(
                        cause: cause, effect: effect,
                        effectType: sR > 0 ? .conditionalPositive : .conditionalNegative,
                        description: "\(cause.displayName) \(verb) your \(effect.displayName) mostly when \(grp) your baseline of \(bv) \(cause.unit) (r=\(f2(sR)) vs r=\(f2(wR)))",
                        strength: Swift.min(abs(rA - rB), 1.0), confidence: 1.0 - z.p,
                        sampleCount: n, condition: "when \(cause.displayName) is \(grp) \(bv) \(cause.unit)",
                        discoveredAt: Date()
                    ))
                }
            }
        }
        return results
    }

    // MARK: - Moderation Analysis

    private func analyzeModeration(
        cause: HealthMetric, effect: HealthMetric,
        dateValues: [HealthMetric: [Date: Double]],
        available: [HealthMetric], calendar: Calendar
    ) -> [InteractionEffect] {
        guard let cMap = dateValues[cause], let eMap = dateValues[effect] else { return [] }
        var results: [InteractionEffect] = []

        for mod in available where mod != cause && mod != effect {
            guard let mMap = dateValues[mod] else { continue }
            let common = Set(cMap.keys).intersection(eMap.keys).intersection(mMap.keys).sorted()
            guard common.count >= Self.minimumDays else { continue }

            var hC = [Double](), hE = [Double](), lC = [Double](), lE = [Double]()
            let modVals = common.compactMap { mMap[$0] }
            guard modVals.count == common.count else { continue }
            let median = modVals.sorted()[modVals.count / 2]

            for d in common {
                guard let c = cMap[d], let e = eMap[d], let m = mMap[d] else { continue }
                if m >= median { hC.append(c); hE.append(e) } else { lC.append(c); lE.append(e) }
            }
            guard hC.count >= 10, lC.count >= 10 else { continue }
            guard let hR = [Double].pearsonCorrelation(hC, hE),
                  let lR = [Double].pearsonCorrelation(lC, lE) else { continue }
            let diff = abs(hR - lR)
            guard diff > Self.minModerationDelta else { continue }
            let z = fisherZ(r1: hR, n1: hC.count, r2: lR, n2: lC.count)
            guard z.p < Self.alpha else { continue }

            let (grp, sR, wR) = abs(hR) > abs(lR) ? ("high", hR, lR) : ("low", lR, hR)
            let verb = sR > 0 ? "helps" : "hurts"
            results.append(InteractionEffect(
                cause: cause, effect: effect, effectType: .moderation,
                description: "\(cause.displayName) \(verb) your \(effect.displayName) more when your \(mod.displayName) is \(grp) (r=\(f2(sR)) vs r=\(f2(wR)), split at \(mod.formatValue(median)) \(mod.unit))",
                strength: Swift.min(diff, 1.0), confidence: 1.0 - z.p,
                sampleCount: common.count, condition: "moderated by \(mod.displayName)",
                discoveredAt: Date()
            ))
        }
        return results
    }

    // MARK: - Natural Language Generation

    private func describeCurve(
        _ cause: HealthMetric, _ effect: HealthMetric,
        _ bins: [DoseResponseCurve.DoseResponseBin],
        _ shape: Shape,
        _ optimal: (lower: Double, upper: Double)?,
        _ baselines: [HealthMetric: UserBaseline]
    ) -> String {
        let f = bins.first!, l = bins.last!
        let delta = l.effectMean - f.effectMean
        let cRange = l.binCenter - f.binCenter
        let better = effect.higherIsBetter
        let positive = (better && delta > 0) || (!better && delta < 0)

        switch shape {
        case .monotoneUp, .monotoneDown:
            let step = naturalStep(cause)
            let per = cRange > 0 ? delta / cRange * step : 0
            let verb = positive ? "improves" : "worsens"
            return "Each additional \(cause.formatValue(step)) \(cause.unit) of \(cause.displayName) \(verb) your \(effect.displayName) by \(effect.formatValue(abs(per))) \(effect.unit) (from \(effect.formatValue(f.effectMean)) to \(effect.formatValue(l.effectMean)) \(effect.unit))"

        case .invertedU:
            guard let r = optimal else { return "\(cause.displayName) has a sweet spot effect on \(effect.displayName)" }
            let pk = bins.max(by: { $0.effectMean < $1.effectMean })!
            return "Your \(effect.displayName) peaks at \(effect.formatValue(pk.effectMean)) \(effect.unit) when \(cause.displayName) is \(cause.formatValue(r.lower))-\(cause.formatValue(r.upper)) \(cause.unit). Beyond that range, \(effect.displayName) drops off"

        case .uShape:
            let tr = bins.min(by: { $0.effectMean < $1.effectMean })!
            return "Both low and high \(cause.displayName) are associated with better \(effect.displayName). The worst \(effect.displayName) occurs around \(cause.formatValue(tr.binCenter)) \(cause.unit)"

        case .saturation:
            let m = bins.map(\.effectMean)
            let pt = findChangePoint(bins, rising: false) ?? bins[bins.count / 2].binCenter
            let gain = abs(m[bins.count / 2] - m[0])
            let verb = positive ? "improves" : "changes"
            return "\(cause.displayName) \(verb) your \(effect.displayName) by \(effect.formatValue(gain)) \(effect.unit), but plateaus after \(cause.formatValue(pt)) \(cause.unit) with minimal further benefit"

        case .threshold:
            let m = bins.map(\.effectMean)
            let pt = findChangePoint(bins, rising: true) ?? bins[bins.count / 2].binCenter
            let afterDelta = abs((m.last ?? 0) - m[bins.count / 2])
            let verb = positive ? "improves" : "drops"
            return "\(cause.displayName) has little effect on \(effect.displayName) until \(cause.formatValue(pt)) \(cause.unit), after which \(effect.displayName) \(verb) by \(effect.formatValue(afterDelta)) \(effect.unit)"

        case .noPattern:
            return ""
        }
    }

    // MARK: - Statistical Helpers

    /// Fisher's z-test for comparing two independent Pearson correlations.
    private func fisherZ(r1: Double, n1: Int, r2: Double, n2: Int) -> (z: Double, p: Double) {
        guard n1 > 3, n2 > 3 else { return (0, 1) }
        let clamp = { (r: Double) in Swift.max(-0.999, Swift.min(0.999, r)) }
        let z1 = 0.5 * log((1 + clamp(r1)) / (1 - clamp(r1)))
        let z2 = 0.5 * log((1 + clamp(r2)) / (1 - clamp(r2)))
        let se = (1.0 / Double(n1 - 3) + 1.0 / Double(n2 - 3)).squareRoot()
        guard se > 0 else { return (0, 1) }
        let zStat = (z1 - z2) / se
        return (zStat, 2.0 * normalSurvival(abs(zStat)))
    }

    /// Abramowitz & Stegun rational approximation for standard normal survival
    private func normalSurvival(_ z: Double) -> Double {
        guard z >= 0 else { return 1.0 - normalSurvival(-z) }
        let t = 1.0 / (1.0 + 0.2316419 * z)
        let poly = t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))))
        let phi = (1.0 / (2.0 * Double.pi).squareRoot()) * exp(-0.5 * z * z)
        return Swift.max(0, Swift.min(1, phi * poly))
    }

    // MARK: - Utility Helpers

    private func aligned(
        _ c: HealthMetric, _ e: HealthMetric,
        _ dv: [HealthMetric: [Date: Double]], _ cal: Calendar
    ) -> ([Double], [Double]) {
        guard let cm = dv[c], let em = dv[e] else { return ([], []) }
        let dates = Set(cm.keys).intersection(em.keys).sorted()
        return (dates.compactMap { cm[$0] }, dates.compactMap { em[$0] })
    }

    private func alignedWithDates(
        _ c: HealthMetric, _ e: HealthMetric,
        _ dv: [HealthMetric: [Date: Double]], _ cal: Calendar
    ) -> ([Double], [Double], [Date]) {
        guard let cm = dv[c], let em = dv[e] else { return ([], [], []) }
        let dates = Set(cm.keys).intersection(em.keys).sorted()
        var cv = [Double](), ev = [Double](), vd = [Date]()
        for d in dates { if let a = cm[d], let b = em[d] { cv.append(a); ev.append(b); vd.append(d) } }
        return (cv, ev, vd)
    }

    private func pairKey(_ a: HealthMetric, _ b: HealthMetric) -> String {
        a.rawValue < b.rawValue ? "\(a.rawValue)|\(b.rawValue)" : "\(b.rawValue)|\(a.rawValue)"
    }

    private func pooledStd(_ bins: [DoseResponseCurve.DoseResponseBin]) -> Double {
        var ss = 0.0, n = 0
        for b in bins { ss += b.effectStd * b.effectStd * Double(b.sampleCount); n += b.sampleCount }
        return n > 0 ? (ss / Double(n)).squareRoot() : 0
    }

    private func binConsistency(_ bins: [DoseResponseCurve.DoseResponseBin]) -> Double {
        guard bins.count >= 3 else { return 0.5 }
        let m = bins.map(\.effectMean)
        let d0 = m[1] - m[0]
        let same = (1..<m.count).filter { (m[$0] - m[$0 - 1]) * d0 > 0 }.count
        return Double(same) / Double(m.count - 1)
    }

    private func naturalStep(_ m: HealthMetric) -> Double {
        switch m {
        case .steps: return 1000
        case .activeCalories, .basalCalories: return 100
        case .exerciseMinutes, .mindfulMinutes: return 10
        case .sleepDuration, .sleepDeep, .sleepREM, .sleepCore: return 1
        case .heartRate, .restingHeartRate, .heartRateVariability: return 5
        case .waterIntake: return 250
        case .caffeineIntake: return 50
        default: return 1
        }
    }

    /// Find the bin center where the curve transitions (plateau start or threshold kick-in)
    private func findChangePoint(_ bins: [DoseResponseCurve.DoseResponseBin], rising: Bool) -> Double? {
        let m = bins.map(\.effectMean)
        let total = abs((m.max() ?? 0) - (m.min() ?? 0))
        guard total > 0 else { return nil }
        for i in 1..<bins.count {
            let ratio = abs(m[i] - m[i - 1]) / total
            if rising ? ratio > 0.3 : ratio < 0.1 { return bins[i].binCenter }
        }
        return nil
    }

    private func f2(_ v: Double) -> String { String(format: "%.2f", v) }

    // MARK: - Public Accessors

    func effects(for cause: HealthMetric) -> [InteractionEffect] { effects.filter { $0.cause == cause } }
    func effectsOn(_ effect: HealthMetric) -> [InteractionEffect] { effects.filter { $0.effect == effect } }
    func topEffects(_ count: Int = 10) -> [InteractionEffect] { Array(effects.prefix(count)) }
    func doseResponse(cause: HealthMetric, effect: HealthMetric) -> DoseResponseCurve? {
        doseResponseCurves.first { $0.cause == cause && $0.effect == effect }
    }
}
