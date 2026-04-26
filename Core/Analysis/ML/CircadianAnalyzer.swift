import Foundation
import Accelerate

/// Circadian rhythm analyzer using cosinor analysis to discover personal chronotype
/// and recommend optimal timing for workouts, sleep, and focused work.
final class CircadianAnalyzer {

    // MARK: - Types

    enum Chronotype: String, Codable {
        case earlyBird = "Early Bird"
        case intermediate = "Intermediate"
        case nightOwl = "Night Owl"
    }

    enum ActivityType: String, Codable {
        case workout = "Workout"
        case sleep = "Sleep"
        case focusedWork = "Focused Work"
        case recovery = "Recovery"
    }

    struct TimingRecommendation {
        let activity: ActivityType
        let optimalWindowStart: Int  // Hour (0-23)
        let optimalWindowEnd: Int    // Hour (0-23)
        let confidence: Double
        let reasoning: String

        var optimalWindowDescription: String {
            let startStr = String(format: "%d:%02d", optimalWindowStart, 0)
            let endStr = String(format: "%d:%02d", optimalWindowEnd, 0)
            return "\(startStr) – \(endStr)"
        }
    }

    struct CircadianProfile: Codable {
        let chronotype: Chronotype
        let activityAcrophaseHour: Double     // Peak activity hour
        let hrvAcrophaseHour: Double?         // Peak HRV hour
        let hrNadirHour: Double               // Lowest heart rate hour
        let temperatureNadirHour: Double?     // Lowest temperature hour
        let confidence: Double                // Overall confidence (0-1)
        let analyzedAt: Date
    }

    struct CosinorResult {
        let mesor: Double      // Rhythm-adjusted mean (M)
        let amplitude: Double  // Half the peak-to-trough range (A)
        let acrophase: Double  // Time of peak in hours (φ)
        let rSquared: Double   // Goodness of fit
    }

    // MARK: - Configuration

    static let minimumDays = 7
    static let metricsToAnalyze: [HealthMetric] = [
        .heartRate, .restingHeartRate, .heartRateVariability,
        .steps, .activeCalories
    ]
    /// Optional metrics (temperature sensors not available on all devices)
    static let optionalMetrics: [HealthMetric] = [
        .bodyTemperature, .appleSleepingWristTemperature
    ]

    // MARK: - State

    private(set) var profile: CircadianProfile?
    private(set) var recommendations: [TimingRecommendation] = []
    private(set) var cosinorResults: [HealthMetric: CosinorResult] = [:]
    private var lastAnalysisDate: Date?

    var isReady: Bool { profile != nil }

    /// Run weekly, not daily
    var needsAnalysis: Bool {
        guard let last = lastAnalysisDate else { return true }
        return Date().timeIntervalSince(last) > 7 * 24 * 3600
    }

    // MARK: - Analysis

    /// Run circadian analysis on hourly-binned data.
    /// - Parameter hourlyData: For each metric, an array of 24 arrays (one per hour), each containing
    ///   daily values for that hour slot across all available days.
    func analyze(hourlyData: [HealthMetric: [[Double]]]) {
        guard !hourlyData.isEmpty else { return }

        var results: [HealthMetric: CosinorResult] = [:]

        for (metric, hourBins) in hourlyData {
            guard hourBins.count == 24 else { continue }

            // Build hourly averages
            var hourlyAverages: [(hour: Double, value: Double)] = []
            for hour in 0..<24 {
                let values = hourBins[hour]
                guard !values.isEmpty else { continue }
                let avg = values.reduce(0, +) / Double(values.count)
                hourlyAverages.append((hour: Double(hour), value: avg))
            }

            guard hourlyAverages.count >= 12 else { continue }  // Need at least half the day

            let result = fitCosinor(data: hourlyAverages)
            guard result.rSquared >= 0.1 else { continue }  // Skip very noisy fits
            results[metric] = result
        }

        cosinorResults = results
        guard !results.isEmpty else { return }

        // Derive chronotype from activity metrics
        let activityAcrophase = deriveActivityAcrophase(results: results)
        let hrvAcrophase = results[.heartRateVariability]?.acrophase
        let hrNadir = deriveHRNadir(results: results)
        let tempNadir = deriveTempNadir(results: results)

        // Confidence = average R² across all fitted metrics
        let avgR2 = results.values.map(\.rSquared).reduce(0, +) / Double(results.count)
        let confidence = min(1.0, avgR2 * 1.5)  // Scale up slightly since R² for circadian is often modest

        let chronotype = classifyChronotype(activityAcrophaseHour: activityAcrophase)

        profile = CircadianProfile(
            chronotype: chronotype,
            activityAcrophaseHour: activityAcrophase,
            hrvAcrophaseHour: hrvAcrophase,
            hrNadirHour: hrNadir,
            temperatureNadirHour: tempNadir,
            confidence: confidence,
            analyzedAt: Date()
        )

        recommendations = generateRecommendations(
            chronotype: chronotype,
            activityAcrophase: activityAcrophase,
            hrvAcrophase: hrvAcrophase,
            hrNadir: hrNadir,
            tempNadir: tempNadir,
            confidence: confidence
        )

        lastAnalysisDate = Date()
    }

    // MARK: - Cosinor Fitting

    /// Fit cosinor model: y(t) = M + A*cos(2πt/24 - φ)
    /// Linearized: y = M + β*cos(ωt) + γ*sin(ωt)
    /// where amplitude = √(β² + γ²), acrophase = atan2(γ, β)
    private func fitCosinor(data: [(hour: Double, value: Double)]) -> CosinorResult {
        let n = data.count
        let omega = 2.0 * .pi / 24.0

        // Build design matrix [1, cos(ωt), sin(ωt)] and response vector
        var sumY = 0.0
        var sumCos = 0.0
        var sumSin = 0.0
        var sumCos2 = 0.0
        var sumSin2 = 0.0
        var sumCosSin = 0.0
        var sumYCos = 0.0
        var sumYSin = 0.0

        for point in data {
            let t = point.hour
            let y = point.value
            let c = cos(omega * t)
            let s = sin(omega * t)

            sumY += y
            sumCos += c
            sumSin += s
            sumCos2 += c * c
            sumSin2 += s * s
            sumCosSin += c * s
            sumYCos += y * c
            sumYSin += y * s
        }

        let nD = Double(n)

        // Solve 3x3 normal equations: X'X * [M, β, γ]' = X'Y
        // Using Cramer's rule for the 3x3 system
        let a11 = nD, a12 = sumCos, a13 = sumSin
        let a21 = sumCos, a22 = sumCos2, a23 = sumCosSin
        let a31 = sumSin, a32 = sumCosSin, a33 = sumSin2

        let b1 = sumY, b2 = sumYCos, b3 = sumYSin

        let det = a11 * (a22 * a33 - a23 * a32)
              - a12 * (a21 * a33 - a23 * a31)
              + a13 * (a21 * a32 - a22 * a31)

        guard abs(det) > 1e-6 else {
            return CosinorResult(mesor: sumY / nD, amplitude: 0, acrophase: 0, rSquared: 0)
        }

        let detM = b1 * (a22 * a33 - a23 * a32)
              - a12 * (b2 * a33 - a23 * b3)
              + a13 * (b2 * a32 - a22 * b3)

        let detBeta = a11 * (b2 * a33 - a23 * b3)
              - b1 * (a21 * a33 - a23 * a31)
              + a13 * (a21 * b3 - b2 * a31)

        let detGamma = a11 * (a22 * b3 - b2 * a32)
              - a12 * (a21 * b3 - b2 * a31)
              + b1 * (a21 * a32 - a22 * a31)

        let mesor = detM / det
        let beta = detBeta / det
        let gamma = detGamma / det

        guard mesor.isFinite, beta.isFinite, gamma.isFinite else {
            return CosinorResult(mesor: sumY / nD, amplitude: 0, acrophase: 0, rSquared: 0)
        }

        let amplitude = sqrt(beta * beta + gamma * gamma)

        // Acrophase in hours: atan2(γ, β) / ω
        var acrophaseRad = atan2(gamma, beta)
        if acrophaseRad < 0 { acrophaseRad += 2.0 * .pi }
        let acrophaseHour = acrophaseRad / omega

        // Compute R²
        let meanY = sumY / nD
        var ssTotal = 0.0
        var ssResidual = 0.0
        for point in data {
            let predicted = mesor + beta * cos(omega * point.hour) + gamma * sin(omega * point.hour)
            ssTotal += (point.value - meanY) * (point.value - meanY)
            ssResidual += (point.value - predicted) * (point.value - predicted)
        }

        let rSquared = ssTotal > 0 ? 1.0 - (ssResidual / ssTotal) : 0
        return CosinorResult(mesor: mesor, amplitude: amplitude, acrophase: acrophaseHour, rSquared: max(0, rSquared))
    }

    // MARK: - Derivations

    private func deriveActivityAcrophase(results: [HealthMetric: CosinorResult]) -> Double {
        // Prefer steps, then activeCalories for activity peak
        if let steps = results[.steps], steps.rSquared >= 0.15 {
            return steps.acrophase
        }
        if let cal = results[.activeCalories], cal.rSquared >= 0.15 {
            return cal.acrophase
        }
        // Fallback: HR peak (activity drives HR up)
        if let hr = results[.heartRate] {
            return hr.acrophase
        }
        // Last resort: derive from steps activity, since active periods drive
        // HR up. This is a real-data proxy rather than a fabricated default.
        if let steps = results[.steps] {
            return steps.acrophase
        }
        return 14.0
    }

    private func deriveHRNadir(results: [HealthMetric: CosinorResult]) -> Double {
        // HR nadir = acrophase + 12 hours (opposite of peak)
        if let rhr = results[.restingHeartRate] {
            return normalizeHour(rhr.acrophase + 12.0)
        }
        if let hr = results[.heartRate] {
            return normalizeHour(hr.acrophase + 12.0)
        }
        // Last resort: opposite of activity peak. Real signal beats a fake 3 AM.
        if let steps = results[.steps] {
            return normalizeHour(steps.acrophase + 12.0)
        }
        return 3.0
    }

    private func deriveTempNadir(results: [HealthMetric: CosinorResult]) -> Double? {
        if let temp = results[.appleSleepingWristTemperature] {
            return normalizeHour(temp.acrophase + 12.0)  // Nadir is opposite of peak
        }
        if let temp = results[.bodyTemperature] {
            return normalizeHour(temp.acrophase + 12.0)
        }
        return nil
    }

    private func classifyChronotype(activityAcrophaseHour: Double) -> Chronotype {
        // Early bird: activity peaks before 1 PM
        // Night owl: activity peaks after 4 PM
        if activityAcrophaseHour < 13.0 {
            return .earlyBird
        } else if activityAcrophaseHour > 16.0 {
            return .nightOwl
        } else {
            return .intermediate
        }
    }

    private func normalizeHour(_ hour: Double) -> Double {
        var h = hour.truncatingRemainder(dividingBy: 24.0)
        if h < 0 { h += 24.0 }
        return h
    }

    // MARK: - Recommendations

    private func generateRecommendations(
        chronotype: Chronotype,
        activityAcrophase: Double,
        hrvAcrophase: Double?,
        hrNadir: Double,
        tempNadir: Double?,
        confidence: Double
    ) -> [TimingRecommendation] {
        var recs: [TimingRecommendation] = []

        // Workout: near activity acrophase (±1.5h), when body is most primed
        let workoutStart = Int(normalizeHour(activityAcrophase - 1.5))
        let workoutEnd = Int(normalizeHour(activityAcrophase + 1.5))
        recs.append(TimingRecommendation(
            activity: .workout,
            optimalWindowStart: workoutStart,
            optimalWindowEnd: workoutEnd,
            confidence: confidence,
            reasoning: "Your body's activity rhythm peaks around \(Int(activityAcrophase)):00, making this the ideal window for exercise performance."
        ))

        // Focused work: HRV acrophase ±1.5h (high HRV = parasympathetic tone = calm focus)
        if let hrvPeak = hrvAcrophase {
            let focusStart = Int(normalizeHour(hrvPeak - 1.5))
            let focusEnd = Int(normalizeHour(hrvPeak + 1.5))
            recs.append(TimingRecommendation(
                activity: .focusedWork,
                optimalWindowStart: focusStart,
                optimalWindowEnd: focusEnd,
                confidence: confidence * 0.9,
                reasoning: "Your HRV peaks around \(Int(hrvPeak)):00, indicating optimal autonomic balance for cognitive tasks."
            ))
        } else {
            // Fallback: morning for early birds, late morning for others
            let focusHour = chronotype == .earlyBird ? 9 : chronotype == .nightOwl ? 11 : 10
            recs.append(TimingRecommendation(
                activity: .focusedWork,
                optimalWindowStart: focusHour - 1,
                optimalWindowEnd: focusHour + 2,
                confidence: confidence * 0.5,
                reasoning: "Based on your \(chronotype.rawValue) chronotype, late morning is typically best for focused work."
            ))
        }

        // Sleep: natural sleep window = HR nadir - 4h to HR nadir + 4h
        let sleepStart = Int(normalizeHour(hrNadir - 4.0))
        let sleepEnd = Int(normalizeHour(hrNadir + 4.0))
        recs.append(TimingRecommendation(
            activity: .sleep,
            optimalWindowStart: sleepStart,
            optimalWindowEnd: sleepEnd,
            confidence: confidence,
            reasoning: "Your heart rate reaches its lowest point around \(Int(hrNadir)):00. Sleeping through this window aligns with your natural circadian dip."
        ))

        // Recovery: 2h after temperature nadir (if available), or early morning
        if let tNadir = tempNadir {
            let recoveryStart = Int(normalizeHour(tNadir + 1.0))
            let recoveryEnd = Int(normalizeHour(tNadir + 3.0))
            recs.append(TimingRecommendation(
                activity: .recovery,
                optimalWindowStart: recoveryStart,
                optimalWindowEnd: recoveryEnd,
                confidence: confidence * 0.8,
                reasoning: "Your body temperature begins rising around \(recoveryStart):00, a natural wake-up signal. Light activity here supports circadian alignment."
            ))
        } else {
            let recoveryStart = Int(normalizeHour(hrNadir + 2.0))
            let recoveryEnd = Int(normalizeHour(hrNadir + 4.0))
            recs.append(TimingRecommendation(
                activity: .recovery,
                optimalWindowStart: recoveryStart,
                optimalWindowEnd: recoveryEnd,
                confidence: confidence * 0.6,
                reasoning: "Light morning activity after your deepest rest period supports circadian rhythm alignment."
            ))
        }

        return recs
    }

    // MARK: - Insight Generation

    func generateInsights() -> [Insight] {
        guard let profile else { return [] }

        var insights: [Insight] = []

        // Chronotype insight
        insights.append(Insight(
            metric: .heartRate,
            title: "Your Chronotype: \(profile.chronotype.rawValue)",
            summary: "Based on \(cosinorResults.count) physiological rhythms, you're a \(profile.chronotype.rawValue). " +
                     "Your activity peaks around \(String(format: "%.0f", profile.activityAcrophaseHour)):00 " +
                     "and your heart rate dips lowest around \(String(format: "%.0f", profile.hrNadirHour)):00.",
            recommendation: chronotypeRecommendation(profile.chronotype),
            severity: .info,
            trend: .stable,
            currentValue: profile.activityAcrophaseHour,
            baselineValue: 14.0,
            deviationPercent: 0,
            category: .circadian,
            context: InsightContext(
                confidenceLevel: profile.confidence,
                dataPointCount: cosinorResults.count * 14
            )
        ))

        // Timing recommendations as insights
        for rec in recommendations.prefix(3) {
            insights.append(Insight(
                metric: .heartRate,
                title: "Best Time to \(rec.activity.rawValue): \(rec.optimalWindowDescription)",
                summary: rec.reasoning,
                recommendation: "Schedule your \(rec.activity.rawValue.lowercased()) between \(rec.optimalWindowDescription) for optimal results.",
                severity: .info,
                trend: .stable,
                currentValue: Double(rec.optimalWindowStart),
                baselineValue: 0,
                deviationPercent: 0,
                category: .circadian,
                context: InsightContext(
                    confidenceLevel: rec.confidence,
                    dataPointCount: cosinorResults.count * 14
                )
            ))
        }

        return insights
    }

    private func chronotypeRecommendation(_ type: Chronotype) -> String {
        switch type {
        case .earlyBird:
            return "Leverage your morning energy by scheduling important tasks and workouts in the AM. Avoid late-night commitments when your performance naturally dips."
        case .intermediate:
            return "Your rhythm is flexible. Schedule demanding tasks in the late morning and workouts in the early afternoon for best results."
        case .nightOwl:
            return "Your energy peaks later in the day. If possible, shift important meetings and workouts to the afternoon. Protect your sleep by maintaining a consistent late schedule."
        }
    }

    // MARK: - Persistence

    struct Parameters: Codable {
        let profile: CircadianProfile?
        let lastAnalysisDate: Date?
    }

    func getParameters() -> MLModelState? {
        let params = Parameters(
            profile: profile,
            lastAnalysisDate: lastAnalysisDate
        )
        return MLModelState.create(
            componentName: "CircadianAnalyzer",
            version: 1,
            parameters: params,
            dataPointsUsed: cosinorResults.count * 14
        )
    }

    func restoreParameters(from state: MLModelState) {
        guard let params = state.decodeParameters(Parameters.self) else { return }
        profile = params.profile
        lastAnalysisDate = params.lastAnalysisDate
    }
}
