import Foundation

extension Copy {
    enum Vitality {

        // MARK: - Navigation

        static let title = "Vitality Age"

        // MARK: - Hero

        static let vitalityAgeLabel = "VITALITY AGE"
        static func actualAge(_ age: Int) -> String { "Actual age \(age)" }
        static func ninetyDayPace(_ label: String) -> String { "90d \(label)" }
        static let buildingProfile = "Building your profile"
        static func yearsYounger(_ years: Int) -> String { "\(years) years younger" }
        static func yearsOlder(_ years: Int) -> String { "\(years) years older" }
        static let onTrack = "On track"

        // MARK: - Narratives

        static let buildingProfileNarrative = "We are building your profile. For now, your vitality age stays aligned with your chronological age."
        static func earlyYoungerNarrative(delta: Int) -> String {
            "Early estimate: your body currently appears about \(delta) years younger. Confidence improves as more data is collected."
        }
        static func earlyOlderNarrative(delta: Int) -> String {
            "Early estimate: your body currently appears about \(delta) years older. Confidence improves as more data is collected."
        }
        static let earlyAlignedNarrative = "Early estimate: your vitality age is currently aligned with your chronological age."
        static func personalYoungerNarrative(delta: Int) -> String {
            "Your body is performing about \(delta) years younger than your chronological age."
        }
        static func personalOlderNarrative(delta: Int) -> String {
            "Your trend suggests ~\(delta) years above your chronological age. The top improvement levers below can help close this gap."
        }
        static let personalAlignedNarrative = "Your vitality age is aligned with your chronological age. Maintaining your current routine can preserve this trend."

        // MARK: - Pace

        static let normalOrSlower = "Normal or slower"
        static let agingTooQuickly = "Accelerating"
        static let agingVeryFast = "Needs attention"

        // MARK: - Delta Labels

        static func metricYounger(_ years: Int) -> String { "\(years)y younger" }
        static func metricOlder(_ years: Int) -> String { "+\(years)y older" }

        // MARK: - Sections

        static let topImprovements = "Top Improvements"
        static let metricContributions = "Metric Contributions"
        static let howThisWorks = "How this works"
        static let methodology = "Vitality Age compares your key metrics against age-adjusted population norms and combines them into one performance age estimate. It is for wellness guidance only and is not a medical diagnosis."
        static func ageLabel(_ age: Int) -> String { "Age \(age)" }
        static func metricSubtitle(current: String, expected: String) -> String { "\(current) now, typical \(expected)" }

        // MARK: - Data Maturity

        static let buildingProfileDescription = "Your vitality age matches your real age while we learn your baseline. Keep wearing your device."
        static let earlyEstimateDescription = "Early estimate. Accuracy improves each day as we learn your patterns."
        static func dataProgress(days: Int, target: Int) -> String { "\(days) of \(target) days" }

        // MARK: - Trend

        static let ninetyDayTrend = "90-Day Trend"
        static let ninetyDayChange = "90d change"
        static let pace = "Pace"
        static let current = "Current"

        // MARK: - Improvement Suggestions

        static let improveVO2Max = "Add 2-3 sessions of vigorous cardio per week (running, cycling, swimming) to boost aerobic capacity."
        static let improveRHR = "Regular aerobic exercise and stress management can lower resting heart rate over time."
        static let improveHRV = "Prioritize sleep quality, practice deep breathing, and maintain consistent exercise to improve HRV."
        static let improveSleep = "Aim for 7-9 hours of sleep with a consistent schedule. Limit screens and caffeine before bed."
        static let improveWalkingSpeed = "Walking speed reflects overall fitness. Regular walking, strength training, and balance work can help."
        static let improveSteps = "Increase daily movement \u{2014} take walking meetings, use stairs, and add a daily walk to your routine."
        static let improveExercise = "Build up to 150+ minutes of moderate exercise per week through activities you enjoy."
        static let improveBodyComp = "Focus on sustainable nutrition and regular exercise. Small consistent changes have the biggest impact."
        static let improveDefault = "Track this metric consistently and look for patterns in your data."

        // MARK: - Pace Labels (VitalityScorer)

        static let paceImproving = "Improving"
        static let paceStable = "Stable"
        static let paceDeclining = "Declining"
    }
}
