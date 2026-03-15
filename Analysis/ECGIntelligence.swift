import Foundation

/// Longitudinal ECG analysis: AFib recurrence tracking, waveform evolution,
/// QTc prolongation observations, and autonomic balance trends.
///
/// **Important:** This analysis is for informational and educational purposes only.
/// It does not provide medical diagnosis. ECG data from consumer devices has limitations
/// and should not replace clinical-grade ECG interpretation by a qualified healthcare provider.
struct ECGIntelligence {

    // MARK: - Types

    enum AFibFrequency: String {
        case none = "None"
        case rare = "Rare"           // < 1/month
        case occasional = "Occasional" // 1-4/month
        case frequent = "Frequent"     // 1+/week
        case persistent = "Persistent" // daily
    }

    struct ECGTrend {
        let metric: String
        let slope: Double         // Change per month
        let currentValue: Double
        let isWorrisome: Bool
        let description: String
    }

    struct ECGAnalysisResult {
        let afibEpisodeCount: Int
        let afibFrequency: AFibFrequency
        let afibBurdenTrend: ECGTrend?
        let qrsWidthTrend: ECGTrend?
        let qtcTrend: ECGTrend?
        let hrvTrend: ECGTrend?
        let autonomicBalanceTrend: ECGTrend?
        let insights: [Insight]
    }

    // MARK: - Analysis

    /// Analyze stored ECG features for longitudinal trends and patterns.
    /// - Parameters:
    ///   - features: Chronological ECG feature snapshots.
    ///   - biologicalSex: User's biological sex for sex-adjusted thresholds (QTc).
    ///     Pass `nil` to fall back to the more conservative male threshold (450 ms).
    static func analyze(features: [StoredECGFeatures], biologicalSex: Gender? = nil) -> ECGAnalysisResult? {
        guard features.count >= 2 else { return nil }

        // Sort by date (newest first is how they come from store, reverse for chronological)
        let sorted = features.sorted { $0.ecgDate < $1.ecgDate }
        let totalDays = Calendar.current.dateComponents([.day], from: sorted.first!.ecgDate, to: sorted.last!.ecgDate).day ?? 1

        // AFib analysis
        let afibEpisodes = sorted.filter { $0.isAFib }
        let afibCount = afibEpisodes.count
        let afibFrequency = classifyAFibFrequency(episodeCount: afibCount, totalDays: max(1, totalDays))
        let afibTrend = analyzeAFibBurdenTrend(sorted: sorted)

        // Sex-adjusted QTc threshold: ≤450 ms for males, ≤470 ms for females (AHA/ACC guidelines)
        let qtcThreshold: Double = biologicalSex == .female ? 470.0 : 450.0

        // Waveform trends
        let qrsWidthTrend = analyzeTrend(
            values: sorted.compactMap { feat -> (Date, Double)? in
                guard let qrs = feat.qrsWidth else { return nil }
                return (feat.ecgDate, qrs)
            },
            metricName: "QRS Width",
            unit: "ms",
            worrisomeThreshold: 120.0, // Wide QRS > 120ms
            worrisomeDirection: .above
        )

        let qtcTrend = analyzeTrend(
            values: sorted.compactMap { feat -> (Date, Double)? in
                guard let qtc = feat.qtcInterval else { return nil }
                return (feat.ecgDate, qtc)
            },
            metricName: "QTc Interval",
            unit: "ms",
            worrisomeThreshold: qtcThreshold,
            worrisomeDirection: .above
        )

        // HRV trend (SDNN from ECG)
        let hrvTrend = analyzeTrend(
            values: sorted.map { ($0.ecgDate, $0.rrSDNN) },
            metricName: "ECG-derived HRV (SDNN)",
            unit: "ms",
            worrisomeThreshold: 50.0, // Low SDNN < 50ms
            worrisomeDirection: .below
        )

        // Autonomic balance (LF/HF ratio)
        let autonomicTrend = analyzeTrend(
            values: sorted.compactMap { feat -> (Date, Double)? in
                guard let ratio = feat.lfHfRatio else { return nil }
                return (feat.ecgDate, ratio)
            },
            metricName: "Autonomic Balance (LF/HF)",
            unit: "",
            worrisomeThreshold: 3.0, // High sympathetic dominance
            worrisomeDirection: .above
        )

        let insights = generateInsights(
            afibCount: afibCount,
            afibFrequency: afibFrequency,
            afibTrend: afibTrend,
            qrsWidthTrend: qrsWidthTrend,
            qtcTrend: qtcTrend,
            qtcThreshold: qtcThreshold,
            hrvTrend: hrvTrend,
            autonomicTrend: autonomicTrend,
            totalECGs: sorted.count
        )

        return ECGAnalysisResult(
            afibEpisodeCount: afibCount,
            afibFrequency: afibFrequency,
            afibBurdenTrend: afibTrend,
            qrsWidthTrend: qrsWidthTrend,
            qtcTrend: qtcTrend,
            hrvTrend: hrvTrend,
            autonomicBalanceTrend: autonomicTrend,
            insights: insights
        )
    }

    // MARK: - AFib Classification

    private static func classifyAFibFrequency(episodeCount: Int, totalDays: Int) -> AFibFrequency {
        guard episodeCount > 0 else { return .none }
        let monthlyRate = Double(episodeCount) / (Double(totalDays) / 30.0)
        switch monthlyRate {
        case 0..<1: return .rare
        case 1..<4: return .occasional
        case 4..<30: return .frequent
        default: return .persistent
        }
    }

    private static func analyzeAFibBurdenTrend(sorted: [StoredECGFeatures]) -> ECGTrend? {
        let afibRecordings = sorted.filter { $0.isAFib }
        guard afibRecordings.count >= 2 else { return nil }

        // Compute monthly AFib rate (rolling 30-day windows)
        let calendar = Calendar.current
        guard let firstDate = sorted.first?.ecgDate,
              let lastDate = sorted.last?.ecgDate else { return nil }
        let totalDays = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
        guard totalDays >= 30 else { return nil }

        // Compare first half vs second half AFib rate
        let midDate = calendar.date(byAdding: .day, value: totalDays / 2, to: firstDate) ?? firstDate
        let firstHalfCount = Double(afibRecordings.filter { $0.ecgDate < midDate }.count)
        let secondHalfCount = Double(afibRecordings.filter { $0.ecgDate >= midDate }.count)
        let halfDays = Double(totalDays) / 2.0

        let firstRate = firstHalfCount / (halfDays / 30.0)
        let secondRate = secondHalfCount / (halfDays / 30.0)
        let rateChange = secondRate - firstRate

        let isWorrisome = secondRate > firstRate && secondRate >= 2
        let description = rateChange > 0
            ? "AFib episodes increasing: \(String(format: "%.1f", firstRate))/mo → \(String(format: "%.1f", secondRate))/mo"
            : "AFib episode rate stable or decreasing"

        return ECGTrend(
            metric: "AFib Burden",
            slope: rateChange,
            currentValue: secondRate,
            isWorrisome: isWorrisome,
            description: description
        )
    }

    // MARK: - General Trend Analysis

    private enum WorrisomeDirection { case above, below }

    private static func analyzeTrend(
        values: [(Date, Double)],
        metricName: String,
        unit: String,
        worrisomeThreshold: Double,
        worrisomeDirection: WorrisomeDirection
    ) -> ECGTrend? {
        guard values.count >= 3 else { return nil }

        // Linear regression: slope per month
        let firstDate = values.first!.0
        let xValues = values.map { Double(Calendar.current.dateComponents([.day], from: firstDate, to: $0.0).day ?? 0) }
        let yValues = values.map { $0.1 }

        let n = Double(values.count)
        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xValues.reduce(0) { $0 + $1 * $1 }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return nil }

        let slopePerDay = (n * sumXY - sumX * sumY) / denominator
        let slopePerMonth = slopePerDay * 30.0

        let currentValue = yValues.last!
        let isWorrisome: Bool
        switch worrisomeDirection {
        case .above:
            isWorrisome = currentValue > worrisomeThreshold || (slopePerMonth > 0 && currentValue > worrisomeThreshold * 0.9)
        case .below:
            isWorrisome = currentValue < worrisomeThreshold || (slopePerMonth < 0 && currentValue < worrisomeThreshold * 1.1)
        }

        let trendWord = slopePerMonth > 0.5 ? "increasing" : slopePerMonth < -0.5 ? "decreasing" : "stable"
        let description = "\(metricName) is \(trendWord) at \(String(format: "%.1f", abs(slopePerMonth)))\(unit)/month (current: \(String(format: "%.0f", currentValue))\(unit))"

        return ECGTrend(
            metric: metricName,
            slope: slopePerMonth,
            currentValue: currentValue,
            isWorrisome: isWorrisome,
            description: description
        )
    }

    // MARK: - Insight Generation

    private static let medicalDisclaimer = " This is informational only and not a medical diagnosis. Consult your healthcare provider for clinical interpretation of ECG data."

    private static func generateInsights(
        afibCount: Int,
        afibFrequency: AFibFrequency,
        afibTrend: ECGTrend?,
        qrsWidthTrend: ECGTrend?,
        qtcTrend: ECGTrend?,
        qtcThreshold: Double,
        hrvTrend: ECGTrend?,
        autonomicTrend: ECGTrend?,
        totalECGs: Int
    ) -> [Insight] {
        var insights: [Insight] = []

        // AFib recurrence insight
        if afibCount > 0 {
            let severity: Severity = afibFrequency == .persistent || afibFrequency == .frequent ? .critical :
                                     afibFrequency == .occasional ? .warning : .info

            var summary = "Detected \(afibCount) AFib episode\(afibCount == 1 ? "" : "s") across \(totalECGs) ECG recordings."
            summary += " Frequency classification: \(afibFrequency.rawValue)."
            if let trend = afibTrend {
                summary += " " + trend.description
            }

            insights.append(Insight(
                metric: .heartRate,
                title: "AFib Pattern: \(afibFrequency.rawValue)",
                summary: summary,
                recommendation: "Track your AFib episodes and share this data with your healthcare provider." + medicalDisclaimer,
                severity: severity,
                trend: afibTrend?.slope ?? 0 > 0 ? .declining : .stable,
                currentValue: Double(afibCount),
                baselineValue: 0,
                deviationPercent: 0,
                category: .ecgIntelligence,
                context: InsightContext(
                    confidenceLevel: min(1.0, Double(totalECGs) / 20.0),
                    dataPointCount: totalECGs
                )
            ))
        }

        // QTc prolongation warning
        if let qtc = qtcTrend, qtc.isWorrisome {
            insights.append(Insight(
                metric: .heartRate,
                title: "QTc Prolongation Trend",
                summary: qtc.description + ". QTc values above \(Int(qtcThreshold))ms may warrant further review by a healthcare provider.",
                recommendation: "Changes in QTc can have many causes. Share this trend data with your healthcare provider for proper evaluation." + medicalDisclaimer,
                severity: qtc.currentValue > 500 ? .critical : .warning,
                trend: qtc.slope > 0 ? .declining : .stable,
                currentValue: qtc.currentValue,
                baselineValue: 440,
                deviationPercent: (qtc.currentValue - 440) / 440 * 100,
                category: .ecgIntelligence,
                context: InsightContext(
                    confidenceLevel: min(1.0, Double(totalECGs) / 10.0),
                    dataPointCount: totalECGs
                )
            ))
        }

        // QRS widening
        if let qrs = qrsWidthTrend, qrs.isWorrisome {
            insights.append(Insight(
                metric: .heartRate,
                title: "QRS Width Trend",
                summary: qrs.description + ". QRS values above 120ms may warrant further review.",
                recommendation: "Share this QRS trend data with your healthcare provider for evaluation." + medicalDisclaimer,
                severity: .warning,
                trend: qrs.slope > 0 ? .declining : .stable,
                currentValue: qrs.currentValue,
                baselineValue: 100,
                deviationPercent: (qrs.currentValue - 100) / 100 * 100,
                category: .ecgIntelligence,
                context: InsightContext(
                    confidenceLevel: min(1.0, Double(totalECGs) / 10.0),
                    dataPointCount: totalECGs
                )
            ))
        }

        // ECG-derived HRV trend
        if let hrv = hrvTrend, hrv.isWorrisome {
            insights.append(Insight(
                metric: .heartRateVariability,
                title: "ECG-Derived HRV Declining",
                summary: hrv.description + ". Low SDNN (<50ms) from ECG recordings may reflect reduced autonomic variability.",
                recommendation: "Prioritize rest, stress management, and regular exercise to support autonomic health." + medicalDisclaimer,
                severity: hrv.currentValue < 30 ? .warning : .info,
                trend: .declining,
                currentValue: hrv.currentValue,
                baselineValue: 50,
                deviationPercent: (50 - hrv.currentValue) / 50 * 100,
                category: .ecgIntelligence,
                context: InsightContext(
                    confidenceLevel: min(1.0, Double(totalECGs) / 10.0),
                    dataPointCount: totalECGs
                )
            ))
        }

        // Autonomic balance shift
        if let autonomic = autonomicTrend, autonomic.isWorrisome {
            insights.append(Insight(
                metric: .heartRateVariability,
                title: "Autonomic Balance Shift",
                summary: autonomic.description + ". Elevated LF/HF ratio indicates sympathetic dominance (stress response).",
                recommendation: "Practice vagal tone exercises: deep breathing, cold water face immersion, or meditation to restore parasympathetic balance." + medicalDisclaimer,
                severity: .info,
                trend: autonomic.slope > 0 ? .declining : .stable,
                currentValue: autonomic.currentValue,
                baselineValue: 1.5,
                deviationPercent: (autonomic.currentValue - 1.5) / 1.5 * 100,
                category: .ecgIntelligence,
                context: InsightContext(
                    confidenceLevel: min(1.0, Double(totalECGs) / 10.0),
                    dataPointCount: totalECGs
                )
            ))
        }

        return insights
    }
}
