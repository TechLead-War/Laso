import Foundation
import SwiftUI

/// A health pattern assessment combining multiple metric signals to identify potential trends
struct HealthRisk: Identifiable {
    let id = UUID()
    let riskType: HealthRiskType
    let level: Int // 0-100 (0 = no risk, 100 = maximum risk)
    let factors: [RiskFactor]
    let focusAreas: [FocusArea]
    let generatedAt: Date

    var riskGrade: RiskGrade {
        switch level {
        case 0..<15: return .low
        case 15..<35: return .moderate
        case 35..<55: return .elevated
        case 55..<75: return .high
        default: return .veryHigh
        }
    }

    /// Only factors that have data (not unmeasured)
    var measuredFactors: [RiskFactor] {
        factors.filter { $0.status != .unmeasured }
    }

    /// Factors that need attention (borderline or worse)
    var concerningFactors: [RiskFactor] {
        factors.filter { $0.status == .concerning || $0.status == .critical }
    }

    init(riskType: HealthRiskType, level: Int, factors: [RiskFactor], focusAreas: [FocusArea], generatedAt: Date = Date()) {
        self.riskType = riskType
        self.level = max(0, min(100, level))
        self.factors = factors
        self.focusAreas = focusAreas
        self.generatedAt = generatedAt
    }
}

// MARK: - Risk Grade

enum RiskGrade: String {
    case low, moderate, elevated, high, veryHigh

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .elevated: return "Elevated"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }

    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .elevated: return .orange
        case .high: return .red
        case .veryHigh: return .red
        }
    }

    var icon: String {
        switch self {
        case .low: return "checkmark.shield.fill"
        case .moderate: return "shield.fill"
        case .elevated: return "exclamationmark.shield.fill"
        case .high: return "exclamationmark.triangle.fill"
        case .veryHigh: return "xmark.shield.fill"
        }
    }
}

// MARK: - Risk Types

/// Types of health pattern profiles assessed by the engine
enum HealthRiskType: String, CaseIterable, Identifiable, Hashable {
    var id: String { rawValue }

    case cardiac
    case sleepDeficit
    case overtraining
    case respiratory
    case metabolic
    case stress
    case mobilityDecline

    var displayName: String {
        switch self {
        case .cardiac: return "Heart Health Pattern"
        case .sleepDeficit: return "Sleep Pattern"
        case .overtraining: return "Training Load Pattern"
        case .respiratory: return "Respiratory Pattern"
        case .metabolic: return "Metabolic Pattern"
        case .stress: return "Stress & Recovery"
        case .mobilityDecline: return "Mobility Trend"
        }
    }

    var systemImageName: String {
        switch self {
        case .cardiac: return "heart.circle.fill"
        case .sleepDeficit: return "moon.zzz.fill"
        case .overtraining: return "flame.circle.fill"
        case .respiratory: return "lungs.fill"
        case .metabolic: return "scalemass.fill"
        case .stress: return "brain.head.profile"
        case .mobilityDecline: return "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .cardiac: return .red
        case .sleepDeficit: return .indigo
        case .overtraining: return .orange
        case .respiratory: return .teal
        case .metabolic: return .yellow
        case .stress: return .purple
        case .mobilityDecline: return .cyan
        }
    }

    var description: String {
        switch self {
        case .cardiac: return "Looks at heart health signals including heart rate, HRV, blood pressure, and recovery patterns."
        case .sleepDeficit: return "Tracks sleep quality and quantity patterns that affect recovery and how you feel."
        case .overtraining: return "Watches for signs of high training load without enough recovery."
        case .respiratory: return "Tracks lung function and blood oxygen patterns over time."
        case .metabolic: return "Tracks body composition and activity patterns related to your metabolism."
        case .stress: return "Combines nervous system signals to understand your stress and recovery balance."
        case .mobilityDecline: return "Looks at gait and movement patterns to spot mobility changes over time."
        }
    }

    /// Metrics that contribute to this risk assessment
    var relevantMetrics: [HealthMetric] {
        switch self {
        case .cardiac:
            return [.restingHeartRate, .heartRateVariability, .bloodPressureSystolic, .bloodPressureDiastolic, .heartRateRecovery, .atrialFibrillationBurden]
        case .sleepDeficit:
            return [.sleepDuration, .sleepDeep, .sleepREM, .sleepAwake, .sleepCore]
        case .overtraining:
            return [.heartRateVariability, .restingHeartRate, .exerciseMinutes, .heartRateRecovery, .activeCalories]
        case .respiratory:
            return [.bloodOxygen, .respiratoryRate, .vo2Max, .peakExpiratoryFlowRate, .forcedVitalCapacity]
        case .metabolic:
            return [.weight, .bmi, .bodyFatPercentage, .waistCircumference, .steps, .activeCalories]
        case .stress:
            return [.heartRateVariability, .restingHeartRate, .sleepDuration, .mindfulMinutes, .electrodermalActivity, .respiratoryRate]
        case .mobilityDecline:
            return [.walkingSpeed, .walkingStepLength, .walkingAsymmetry, .walkingDoubleSupportPercentage, .sixMinuteWalkTestDistance, .stairAscentSpeed]
        }
    }
}

// MARK: - Risk Factor

/// A single metric's contribution to a risk assessment
struct RiskFactor: Identifiable {
    let id = UUID()
    let metric: HealthMetric
    let contribution: Int // 0-100 how much this metric contributes to risk
    let status: RiskFactorStatus
    let currentValue: Double
    let optimalRange: String
    let explanation: String
}

enum RiskFactorStatus: String {
    case optimal
    case borderline
    case concerning
    case critical
    case unmeasured

    var displayName: String {
        switch self {
        case .optimal: return "Optimal"
        case .borderline: return "Borderline"
        case .concerning: return "Concerning"
        case .critical: return "Critical"
        case .unmeasured: return "Not Measured"
        }
    }

    var color: Color {
        switch self {
        case .optimal: return .green
        case .borderline: return .yellow
        case .concerning: return .orange
        case .critical: return .red
        case .unmeasured: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .optimal: return "checkmark.circle.fill"
        case .borderline: return "minus.circle.fill"
        case .concerning: return "exclamationmark.circle.fill"
        case .critical: return "xmark.circle.fill"
        case .unmeasured: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Focus Area

/// A specific, actionable recommendation to reduce risk. ranked by impact
struct FocusArea: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let impact: FocusImpact
    let metric: HealthMetric
    let targetDescription: String
}

enum FocusImpact: String {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high: return "High Impact"
        case .medium: return "Medium Impact"
        case .low: return "Low Impact"
        }
    }

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }

    var icon: String {
        switch self {
        case .high: return "arrow.up.circle.fill"
        case .medium: return "arrow.right.circle.fill"
        case .low: return "arrow.down.circle.fill"
        }
    }
}
