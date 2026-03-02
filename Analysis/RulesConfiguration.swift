import Foundation

/// Domain knowledge: thresholds, normal ranges, and recommendation templates
struct RulesConfiguration {

    /// Normal population ranges for each metric
    struct NormalRange {
        let low: Double
        let high: Double

        func contains(_ value: Double) -> Bool {
            value >= low && value <= high
        }
    }

    static func normalRange(for metric: HealthMetric) -> NormalRange {
        switch metric {
        case .heartRate: return NormalRange(low: 60, high: 100)
        case .restingHeartRate: return NormalRange(low: 40, high: 80)
        case .heartRateVariability: return NormalRange(low: 20, high: 100)
        case .vo2Max: return NormalRange(low: 25, high: 60)
        case .walkingHeartRateAverage: return NormalRange(low: 80, high: 120)
        case .heartRateRecovery: return NormalRange(low: 12, high: 50)
        case .bloodOxygen: return NormalRange(low: 95, high: 100)
        case .atrialFibrillationBurden: return NormalRange(low: 0, high: 1)
        case .peripheralPerfusionIndex: return NormalRange(low: 0.5, high: 5)
        case .sleepDuration: return NormalRange(low: 6, high: 9)
        case .sleepREM: return NormalRange(low: 0.8, high: 2.5)
        case .sleepDeep: return NormalRange(low: 0.8, high: 2.0)
        case .sleepCore: return NormalRange(low: 2.0, high: 5.0)
        case .sleepAwake: return NormalRange(low: 0, high: 1.0)
        case .steps: return NormalRange(low: 5000, high: 15000)
        case .activeCalories: return NormalRange(low: 200, high: 800)
        case .basalCalories: return NormalRange(low: 1200, high: 2200)
        case .exerciseMinutes: return NormalRange(low: 20, high: 90)
        case .standHours: return NormalRange(low: 6, high: 14)
        case .distanceWalkingRunning: return NormalRange(low: 3, high: 12)
        case .flightsClimbed: return NormalRange(low: 2, high: 20)
        case .distanceCycling: return NormalRange(low: 0, high: 50)
        case .distanceSwimming: return NormalRange(low: 0, high: 5)
        case .swimmingStrokeCount: return NormalRange(low: 0, high: 3000)
        case .appleMoveTime: return NormalRange(low: 10, high: 120)
        case .walkingSpeed: return NormalRange(low: 3.5, high: 6.5)
        case .walkingStepLength: return NormalRange(low: 55, high: 85)
        case .walkingAsymmetry: return NormalRange(low: 0, high: 15)
        case .walkingDoubleSupportPercentage: return NormalRange(low: 20, high: 40)
        case .stairAscentSpeed: return NormalRange(low: 0.5, high: 2.0)
        case .stairDescentSpeed: return NormalRange(low: 0.5, high: 2.0)
        case .sixMinuteWalkTestDistance: return NormalRange(low: 400, high: 700)
        case .weight: return NormalRange(low: 45, high: 130)
        case .bmi: return NormalRange(low: 18.5, high: 25)
        case .bodyFatPercentage: return NormalRange(low: 8, high: 30)
        case .bloodPressureSystolic: return NormalRange(low: 90, high: 130)
        case .bloodPressureDiastolic: return NormalRange(low: 60, high: 85)
        case .respiratoryRate: return NormalRange(low: 12, high: 20)
        case .bodyTemperature: return NormalRange(low: 36.1, high: 37.2)
        case .appleSleepingWristTemperature: return NormalRange(low: -1.0, high: 1.0)
        case .leanBodyMass: return NormalRange(low: 35, high: 90)
        case .waistCircumference: return NormalRange(low: 60, high: 102)
        case .peakExpiratoryFlowRate: return NormalRange(low: 300, high: 700)
        case .forcedVitalCapacity: return NormalRange(low: 2.5, high: 6.0)
        case .mindfulMinutes: return NormalRange(low: 5, high: 60)
        case .timeInDaylight: return NormalRange(low: 15, high: 180)
        case .electrodermalActivity: return NormalRange(low: 0.01, high: 20)
        case .waterIntake: return NormalRange(low: 1.5, high: 4.0)  // liters per day
        case .bloodGlucose: return NormalRange(low: 70, high: 140)
        case .workoutCount: return NormalRange(low: 0, high: 3)
        case .workoutDuration: return NormalRange(low: 0, high: 120)
        }
    }

    /// Warning threshold: deviation from baseline (proportion)
    static var warningDeviationThreshold: Double { RemoteConfigManager.shared.analysisWarningDeviation }

    /// Critical threshold: deviation from baseline (proportion)
    static var criticalDeviationThreshold: Double { RemoteConfigManager.shared.analysisCriticalDeviation }

    /// Trend significance: minimum absolute slope to be considered non-stable
    static var trendSlopeThreshold: Double { RemoteConfigManager.shared.analysisTrendSlopeThreshold }

    /// Score deductions
    static let anomalyWarningDeduction: Int = -20
    static let anomalyCriticalDeduction: Int = -40
    static let decliningTrendDeduction: Int = -10
    static let strongDecliningTrendDeduction: Int = -20
    static let outsideNormalRangeDeduction: Int = -15
    static let improvingTrendBonus: Int = 5

    /// Recommendation templates — base version (no context)
    static func recommendation(for metric: HealthMetric, severity: Severity, trend: TrendDirection) -> String {
        recommendation(for: metric, severity: severity, trend: trend, currentValue: nil, deviationPercent: nil, context: nil)
    }

    /// Enhanced recommendation with actual values
    static func recommendation(for metric: HealthMetric, severity: Severity, trend: TrendDirection, currentValue: Double?, deviationPercent: Double?) -> String {
        recommendation(for: metric, severity: severity, trend: trend, currentValue: currentValue, deviationPercent: deviationPercent, context: nil)
    }

    // MARK: - Context-Aware Helpers

    /// "At this rate, you'll reach warning level in ~8 days."
    static func projectionSentence(context: InsightContext?, trend: TrendDirection) -> String {
        guard trend == .declining, let days = context?.projectedDaysToThreshold, days > 0, days <= 21 else { return "" }
        return " At this rate, you'll reach warning level in ~\(days) days."
    }

    /// "This appears connected to your sleep duration dropping 18%."
    static func rootCauseSentence(context: InsightContext?) -> String {
        guard let ctx = context, let rootMetric = ctx.rootCauseMetric, let rootDev = ctx.rootCauseDeviation else { return "" }
        return " This appears connected to your \(rootMetric.displayName.lowercased()) shifting \(String(format: "%.0f", abs(rootDev)))%."
    }

    /// "This puts you in the bottom 12% of your history. This is 15% below your typical February."
    static func historicalPositionSentence(context: InsightContext?) -> String {
        guard let ctx = context else { return "" }
        var parts: [String] = []
        if let pct = ctx.allTimePercentile, pct <= 20 || pct >= 80 {
            let label = pct >= 80 ? "top \(Int(100 - pct))%" : "bottom \(Int(pct))%"
            parts.append("in the \(label) of your history")
        }
        if let seasonal = ctx.seasonalDeviation, abs(seasonal) >= 5 {
            let monthName = Calendar.current.monthSymbols[Calendar.current.component(.month, from: Date()) - 1]
            parts.append("\(String(format: "%.0f", abs(seasonal)))% \(seasonal > 0 ? "above" : "below") your typical \(monthName)")
        }
        if let yoy = ctx.yearOverYearChange, abs(yoy) > 2 {
            parts.append("\(String(format: "%.0f", abs(yoy)))% \(yoy > 0 ? "better" : "worse") than this time last year")
        }
        guard !parts.isEmpty else { return "" }
        return " Historically: " + parts.joined(separator: "; ") + "."
    }

    /// "Your data shows that improving sleep by 1hr typically raises your HRV by ~12ms."
    static func correlationActionSentence(context: InsightContext?, metric: HealthMetric) -> String {
        guard let ctx = context, let top = ctx.correlatedFactors.first else { return "" }
        return " Your data shows that improving \(top.metric.displayName.lowercased()) raises your \(metric.displayName.lowercased()) by ~\(String(format: "%.0f", top.effectPercent))%."
    }

    // MARK: - Context-Aware Recommendation

    /// Full context-aware recommendation — uses context data when available, falls back to templates
    static func recommendation(for metric: HealthMetric, severity: Severity, trend: TrendDirection, currentValue: Double?, deviationPercent: Double?, context: InsightContext?) -> String {
        let devStr = deviationPercent.map { String(format: "%.0f", abs($0)) + "% " } ?? ""
        let valStr = currentValue.map { metric.formatValue($0) + " " + metric.unit + " \u{2014} " } ?? ""

        // Build context suffix that applies to any metric
        let projection = projectionSentence(context: context, trend: trend)
        let rootCause = rootCauseSentence(context: context)
        let historical = historicalPositionSentence(context: context)
        let correlationAction = correlationActionSentence(context: context, metric: metric)

        // Use the strongest correlated factor for the recommendation action when available
        let topLever: String? = context?.correlatedFactors.first.map { factor in
            "Your #1 lever: improve \(factor.metric.displayName.lowercased()) (\(String(format: "%.0f", factor.effectPercent))% impact on \(metric.displayName.lowercased()))."
        }

        switch metric {
        case .heartRate, .restingHeartRate:
            if severity >= .warning {
                let base = "\(valStr)Your resting HR is \(devStr)above baseline."
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + " Reduce caffeine after 2 PM, add 10 min of deep breathing before bed, and prioritize 7+ hrs sleep." + projection + historical
            }
            return trend == .improving
                ? "\(valStr)Resting HR is trending down \u{2014} your recent habits are working." + historical
                : "\(valStr)Add 20 min of moderate cardio 3x per week to lower your resting HR." + correlationAction + historical

        case .heartRateVariability:
            if trend == .declining {
                let base = "\(valStr)HRV is down \(devStr)from baseline."
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + " Prioritize 7+ hours of sleep tonight and try a 10-min meditation session." + projection + historical
            }
            return "\(valStr)HRV is holding steady." + correlationAction + historical

        case .vo2Max:
            if trend == .improving {
                return "\(valStr)VO2 Max is up \(devStr)\u{2014} your cardiovascular fitness is improving. Continue your current training intensity." + historical
            }
            return "\(valStr)Add 20 min of zone 2 cardio (brisk walking, easy jogging) 3-4 times this week to boost VO2 Max." + projection + historical

        case .bloodOxygen:
            if severity >= .warning {
                return "\(valStr)Blood oxygen is below 95%. Practice 4-7-8 breathing exercises and ensure good ventilation. Seek medical attention if this persists." + rootCause + projection
            }
            return "\(valStr)Blood oxygen is within normal range." + historical

        case .atrialFibrillationBurden:
            if severity >= .warning {
                return "\(valStr)Elevated AFib burden detected. Consult your cardiologist promptly. Avoid excessive alcohol and caffeine." + projection
            }
            return "\(valStr)AFib burden is within normal range." + historical

        case .peripheralPerfusionIndex:
            if severity >= .warning {
                return "\(valStr)Perfusion index is outside normal range. Consult your physician if you notice cold extremities or numbness." + rootCause
            }
            return "\(valStr)Peripheral perfusion is within normal range."

        case .sleepDuration:
            if severity >= .warning || trend == .declining {
                let base = "\(valStr)Sleep duration is down \(devStr)from baseline."
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + " Set your bedtime 30 min earlier tonight. Avoid screens 1 hour before bed and keep your bedroom at 65-68\u{00B0}F." + projection + historical
            }
            return "\(valStr)Sleep duration is solid." + correlationAction + historical

        case .sleepREM, .sleepDeep:
            let stageName = metric == .sleepDeep ? "deep" : "REM"
            let base = "\(valStr)\(stageName.capitalized) sleep is \(devStr)\(trend == .declining ? "below" : "above") baseline."
            if let lever = topLever {
                return base + rootCause + " " + lever + projection + historical
            }
            return base + rootCause + " Avoid alcohol before bed, keep bedtimes consistent, and exercise earlier in the day." + projection + historical

        case .sleepCore:
            return "\(valStr)Core sleep forms the bulk of your rest. Maintain consistent sleep and wake times." + historical

        case .sleepAwake:
            if severity >= .warning {
                return "\(valStr)Excessive wake time during sleep (\(devStr)above normal). Cut caffeine after 2 PM and add a relaxation routine before bed." + rootCause + projection
            }
            return "\(valStr)Nighttime awake periods are within normal range." + historical

        case .steps:
            if trend == .declining {
                let base = "\(valStr)Steps are down \(devStr)from baseline."
                if let lever = topLever {
                    return base + rootCause + " " + lever + projection + historical
                }
                return base + rootCause + " Add a 10-minute walk after each meal to get back to baseline." + projection + historical
            }
            return trend == .improving
                ? "\(valStr)Step count is up \(devStr)\u{2014} aim for 10,000+ daily for optimal health." + historical
                : "\(valStr)Add a post-dinner walk or walking meeting to boost daily steps." + correlationAction + historical

        case .activeCalories:
            if trend == .declining {
                return "\(valStr)Active calorie burn is down \(devStr)from baseline. Add a 20-minute workout or brisk walk to your routine." + rootCause + projection + historical
            }
            return "\(valStr)Active calorie burn is strong." + correlationAction + historical

        case .exerciseMinutes:
            if trend == .declining {
                return "\(valStr)Exercise time is dropping \(devStr). Schedule workouts as calendar events to maintain consistency." + rootCause + projection + historical
            }
            return "\(valStr)Exercise routine is solid. Aim for 150+ minutes per week." + historical

        case .distanceCycling:
            return trend == .declining
                ? "\(valStr)Cycling distance is down \(devStr). Schedule regular rides or commute by bike 2x per week." + projection + historical
                : "\(valStr)Cycling activity is consistent." + historical

        case .distanceSwimming, .swimmingStrokeCount:
            return trend == .declining
                ? "\(valStr)Swimming activity is dropping. Aim for 2-3 swim sessions per week for cardiovascular benefit." + projection
                : "\(valStr)Swimming routine is consistent." + historical

        case .appleMoveTime:
            return trend == .declining
                ? "\(valStr)Move time is down \(devStr). Set hourly reminders to stand and move for a few minutes." + projection
                : "\(valStr)Daily movement time is healthy." + historical

        case .weight, .bmi, .bodyFatPercentage:
            if trend == .declining && !metric.higherIsBetter {
                return "\(valStr)Trending up \(devStr). Focus on consistent nutrition and 150+ min of weekly exercise." + rootCause + projection + historical
            }
            return "\(valStr)Body composition is stable. Focus on consistent nutrition and exercise rather than daily fluctuations." + historical

        case .leanBodyMass:
            return trend == .declining
                ? "\(valStr)Lean body mass is down \(devStr). Increase protein intake to 1.6g/kg and add 2-3 resistance training sessions per week." + projection + historical
                : "\(valStr)Lean body mass is stable." + historical

        case .waistCircumference:
            if severity >= .warning {
                return "\(valStr)Waist circumference is \(devStr)above recommended levels. Focus on whole foods, 30 min daily cardio, and core exercises." + projection + historical
            }
            return "\(valStr)Waist circumference is within a healthy range." + historical

        case .appleSleepingWristTemperature:
            if severity >= .warning {
                return "\(valStr)Wrist temperature deviation detected. This often indicates illness onset or hormonal changes. Rest, hydrate, and track how you feel tomorrow." + rootCause
            }
            return "\(valStr)Sleeping wrist temperature is within normal variation."

        case .bloodPressureSystolic, .bloodPressureDiastolic:
            if severity >= .warning {
                return "\(valStr)Blood pressure is \(devStr)above target. Reduce sodium to <2300mg/day, exercise 30 min daily, and consult your physician." + rootCause + projection
            }
            return "\(valStr)Blood pressure is within healthy range." + historical

        case .respiratoryRate:
            if severity >= .warning {
                return "\(valStr)Respiratory rate is elevated \(devStr)above normal. Practice 4-7-8 breathing exercises 3x daily." + rootCause + projection
            }
            return "\(valStr)Respiratory rate is normal." + historical

        case .peakExpiratoryFlowRate:
            if severity >= .warning {
                return "\(valStr)Peak flow rate is below normal. If you have asthma, review your action plan. Consult a pulmonologist if this continues." + projection
            }
            return "\(valStr)Peak expiratory flow rate is within normal range."

        case .forcedVitalCapacity:
            if severity >= .warning {
                return "\(valStr)Forced vital capacity is reduced \(devStr). Practice breathing exercises and consult your physician for a pulmonary assessment." + projection
            }
            return "\(valStr)Lung capacity is within normal range."

        case .bodyTemperature:
            if severity >= .warning {
                return "\(valStr)Body temperature is \(devStr)outside normal range. Rest, hydrate, and check again in 4 hours. Seek medical attention if fever persists above 38.3\u{00B0}C." + rootCause
            }
            return "\(valStr)Body temperature is within normal range."

        case .mindfulMinutes:
            if trend == .declining {
                return "\(valStr)Mindfulness time dropped \(devStr). Start with just 5 min of guided breathing tomorrow morning." + correlationAction + projection
            }
            return "\(valStr)Mindfulness practice is consistent. Even 10 min daily reduces stress and improves HRV." + correlationAction + historical

        case .timeInDaylight:
            if trend == .declining {
                return "\(valStr)Daylight exposure is down \(devStr). Get 20+ min of outdoor light before noon \u{2014} this directly impacts your sleep quality and circadian rhythm." + correlationAction + projection
            }
            return "\(valStr)Good daylight exposure. Natural light supports circadian rhythm and vitamin D production." + historical

        case .electrodermalActivity:
            if severity >= .warning {
                return "\(valStr)EDA is elevated \(devStr)\u{2014} increased stress arousal detected. Try 5 min of box breathing (4-4-4-4 pattern) right now." + rootCause
            }
            return "\(valStr)Electrodermal activity is within normal range."

        case .walkingSpeed:
            return trend == .declining
                ? "\(valStr)Walking speed is down \(devStr). Add 10-min brisk walking intervals to your daily walks." + projection + historical
                : "\(valStr)Walking speed is healthy." + historical

        case .walkingStepLength:
            return trend == .declining
                ? "\(valStr)Step length is shortening \(devStr). Add 5 min of hip flexor stretches and leg swings daily." + projection + historical
                : "\(valStr)Step length is within normal range." + historical

        case .walkingAsymmetry:
            if severity >= .warning {
                return "\(valStr)Walking asymmetry is elevated \(devStr). Consult a physical therapist to address gait imbalance before it compounds." + projection
            }
            return "\(valStr)Walking symmetry is good." + historical

        case .walkingDoubleSupportPercentage:
            if severity >= .warning {
                return "\(valStr)Double support time is elevated \(devStr)\u{2014} reduced balance confidence. Add single-leg stands and tandem walking exercises." + projection
            }
            return "\(valStr)Double support percentage is within normal range."

        case .stairAscentSpeed, .stairDescentSpeed:
            return trend == .declining
                ? "\(valStr)Stair speed is down \(devStr). Add leg strengthening (squats, lunges) and use stairs instead of elevators 2x daily." + projection + historical
                : "\(valStr)Stair navigation speed is healthy." + historical

        case .sixMinuteWalkTestDistance:
            return trend == .declining
                ? "\(valStr)Six-minute walk distance is down \(devStr). Regular 30-min walks and cardio exercise can help maintain endurance." + projection + historical
                : "\(valStr)Six-minute walk distance is within healthy range." + historical

        default:
            if trend == .declining {
                return "\(valStr)\(metric.displayName) is declining \(devStr)from baseline. Review your recent habits for changes." + rootCause + projection + historical
            }
            return "\(valStr)\(metric.displayName) is within normal parameters." + historical
        }
    }
}
