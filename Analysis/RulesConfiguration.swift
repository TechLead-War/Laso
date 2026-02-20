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
        case .workoutCount: return NormalRange(low: 0, high: 3)
        case .workoutDuration: return NormalRange(low: 0, high: 120)
        }
    }

    /// Warning threshold: deviation from baseline (proportion)
    static let warningDeviationThreshold: Double = 0.10 // 10%

    /// Critical threshold: deviation from baseline (proportion)
    static let criticalDeviationThreshold: Double = 0.20 // 20%

    /// Trend significance: minimum absolute slope to be considered non-stable
    static let trendSlopeThreshold: Double = 0.02

    /// Score deductions
    static let anomalyWarningDeduction: Int = -20
    static let anomalyCriticalDeduction: Int = -40
    static let decliningTrendDeduction: Int = -10
    static let strongDecliningTrendDeduction: Int = -20
    static let outsideNormalRangeDeduction: Int = -15
    static let improvingTrendBonus: Int = 5

    /// Recommendation templates
    static func recommendation(for metric: HealthMetric, severity: Severity, trend: TrendDirection) -> String {
        switch metric {
        case .heartRate, .restingHeartRate:
            if severity >= .warning {
                return "Monitor your heart rate closely. Reduce caffeine, manage stress, and ensure adequate sleep. Consult a physician if elevated HR persists."
            }
            return trend == .improving
                ? "Your heart rate trend is positive. Continue current lifestyle habits."
                : "Your resting heart rate is stable. Maintain regular cardiovascular exercise."

        case .heartRateVariability:
            if trend == .declining {
                return "Declining HRV suggests increased stress or insufficient recovery. Try meditation, prioritize sleep, and consider reducing exercise intensity for a few days."
            }
            return "Your HRV is healthy. Continue balancing exercise with recovery."

        case .vo2Max:
            if trend == .improving {
                return "Your cardiovascular fitness is improving. Keep up the aerobic exercise! Consider adding zone 2 training for sustained improvement."
            }
            return "Add 20 minutes of zone 2 cardio (brisk walking, easy jogging) 3-4 times this week to boost VO2 max."

        case .bloodOxygen:
            if severity >= .warning {
                return "Low blood oxygen detected. Ensure good ventilation, practice deep breathing exercises. Seek medical attention if readings remain below 95%."
            }
            return "Blood oxygen levels are normal."

        case .atrialFibrillationBurden:
            if severity >= .warning {
                return "Elevated AFib burden detected. Consult your cardiologist promptly. Avoid excessive alcohol and caffeine."
            }
            return "AFib burden is within normal range. Continue regular monitoring."

        case .peripheralPerfusionIndex:
            if severity >= .warning {
                return "Perfusion index is outside normal range. Monitor circulation and consult your physician if you notice cold extremities."
            }
            return "Peripheral perfusion is within normal range."

        case .sleepDuration:
            if severity >= .warning || trend == .declining {
                return "Set a consistent bedtime 30 minutes earlier. Avoid screens 1 hour before bed. Keep your bedroom cool and dark."
            }
            return "Your sleep duration is adequate. Maintain your current sleep schedule."

        case .sleepREM, .sleepDeep:
            return "Improve deep/REM sleep by avoiding alcohol before bed, maintaining consistent sleep times, and exercising earlier in the day."

        case .sleepCore:
            return "Core sleep forms the majority of your sleep. Maintain consistent sleep and wake times."

        case .sleepAwake:
            if severity >= .warning {
                return "Excessive wake time during sleep. Avoid caffeine after 2 PM, reduce evening screen time, and try relaxation techniques before bed."
            }
            return "Your nighttime awake periods are within normal range."

        case .steps:
            if trend == .declining {
                return "Your step count is declining. Try a 10-minute walk after each meal to boost daily movement."
            }
            return trend == .improving
                ? "Great step count improvement! Aim for 10,000+ daily for optimal health."
                : "Maintain your walking habits. Consider a walking meeting or post-dinner stroll."

        case .activeCalories:
            return trend == .declining
                ? "Active calorie burn is decreasing. Add a 20-minute workout or brisk walk to your routine."
                : "Your activity level is good. Keep up the current routine."

        case .exerciseMinutes:
            return trend == .declining
                ? "Exercise time is dropping. Schedule workouts as calendar events to maintain consistency."
                : "Your exercise routine looks solid. Aim for 150+ minutes per week."

        case .distanceCycling:
            return trend == .declining
                ? "Cycling distance is decreasing. Try scheduling regular rides or commuting by bike."
                : "Your cycling activity is on track. Keep pedaling!"

        case .distanceSwimming, .swimmingStrokeCount:
            return trend == .declining
                ? "Swimming activity is dropping. Aim for 2-3 swim sessions per week for cardiovascular benefit."
                : "Your swimming routine is consistent. Great for full-body fitness."

        case .appleMoveTime:
            return trend == .declining
                ? "Move time is decreasing. Set hourly reminders to stand and move for a few minutes."
                : "Your daily movement time is healthy. Keep staying active throughout the day."

        case .weight, .bmi, .bodyFatPercentage:
            return "Weight changes are gradual. Focus on consistent nutrition and exercise rather than daily fluctuations."

        case .leanBodyMass:
            return trend == .declining
                ? "Lean body mass is decreasing. Ensure adequate protein intake and include resistance training."
                : "Your lean body mass is stable. Maintain your strength training routine."

        case .waistCircumference:
            if severity >= .warning {
                return "Waist circumference is above recommended levels. Focus on whole foods, regular cardio, and core exercises."
            }
            return "Waist circumference is within a healthy range."

        case .appleSleepingWristTemperature:
            if severity >= .warning {
                return "Wrist temperature deviation detected during sleep. This may indicate illness onset or hormonal changes. Monitor how you feel."
            }
            return "Sleeping wrist temperature is within normal variation."

        case .bloodPressureSystolic, .bloodPressureDiastolic:
            if severity >= .warning {
                return "Blood pressure is outside normal range. Reduce sodium intake, exercise regularly, and consult your physician."
            }
            return "Blood pressure is within healthy range."

        case .respiratoryRate:
            if severity >= .warning {
                return "Respiratory rate is elevated. Practice deep breathing exercises and monitor for respiratory symptoms."
            }
            return "Respiratory rate is normal."

        case .peakExpiratoryFlowRate:
            if severity >= .warning {
                return "Peak flow rate is below normal. If you have asthma, review your action plan. Consider consulting a pulmonologist."
            }
            return "Peak expiratory flow rate is within normal range."

        case .forcedVitalCapacity:
            if severity >= .warning {
                return "Forced vital capacity is reduced. Practice breathing exercises and consult your physician for a pulmonary assessment."
            }
            return "Lung capacity is within normal range."

        case .bodyTemperature:
            if severity >= .warning {
                return "Body temperature deviation detected. Monitor for other symptoms and rest if feeling unwell."
            }
            return "Body temperature is within normal range."

        case .mindfulMinutes:
            return trend == .declining
                ? "Mindfulness time is decreasing. Try a 5-minute guided meditation to restart the habit."
                : "Good mindfulness practice. Even 10 minutes daily reduces stress and improves focus."

        case .timeInDaylight:
            return trend == .declining
                ? "Time in daylight is dropping. Aim for 20-30 minutes of outdoor light daily, especially in the morning."
                : "Good daylight exposure. Natural light supports circadian rhythm and vitamin D production."

        case .electrodermalActivity:
            if severity >= .warning {
                return "Elevated electrodermal activity suggests increased stress arousal. Try deep breathing or a brief mindfulness session."
            }
            return "Electrodermal activity is within normal range."

        case .walkingSpeed:
            return trend == .declining
                ? "Walking speed is decreasing. Incorporate brisk walking intervals to maintain gait velocity."
                : "Walking speed is healthy. Maintaining pace supports cardiovascular fitness."

        case .walkingStepLength:
            return trend == .declining
                ? "Step length is shortening. Stretching and hip mobility exercises can help maintain stride."
                : "Step length is within normal range."

        case .walkingAsymmetry:
            if severity >= .warning {
                return "Walking asymmetry is elevated. Consider consulting a physical therapist to address gait imbalance."
            }
            return "Walking symmetry is good."

        case .walkingDoubleSupportPercentage:
            if severity >= .warning {
                return "Double support time is elevated, suggesting reduced balance confidence. Balance exercises and strength training may help."
            }
            return "Double support percentage is within normal range."

        case .stairAscentSpeed, .stairDescentSpeed:
            return trend == .declining
                ? "Stair speed is declining. Leg strengthening exercises and regular stair use can help maintain mobility."
                : "Stair navigation speed is healthy."

        case .sixMinuteWalkTestDistance:
            return trend == .declining
                ? "Six-minute walk distance is decreasing. Regular walking and cardio exercise can help maintain endurance."
                : "Six-minute walk distance is within healthy range."

        default:
            return trend == .declining
                ? "This metric is showing a declining trend. Review your recent habits for changes."
                : "This metric is within normal parameters."
        }
    }
}
