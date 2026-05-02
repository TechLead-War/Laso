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

        static let buildingProfileNarrative = "We are building your profile. For now, your vitality age matches your real age."
        static func earlyYoungerNarrative(delta: Int) -> String {
            "Early estimate: your body looks about \(delta) years younger. This gets more accurate with more data."
        }
        static func earlyOlderNarrative(delta: Int) -> String {
            "Early estimate: your body looks about \(delta) years older. This gets more accurate with more data."
        }
        static let earlyAlignedNarrative = "Early estimate: your vitality age matches your real age."
        static func personalYoungerNarrative(delta: Int) -> String {
            "Your body is performing about \(delta) years younger than your actual age."
        }
        static func personalOlderNarrative(delta: Int) -> String {
            "Your numbers suggest about \(delta) years above your actual age. The tips below can help close the gap."
        }
        static let personalAlignedNarrative = "Your vitality age matches your real age. Keep doing what you are doing to stay on track."

        // MARK: - Pace

        static let normalOrSlower = "Normal or slower"
        static let agingTooQuickly = "Accelerating"
        static let agingVeryFast = "Could use some care"

        // MARK: - Delta Labels

        static func metricYounger(_ years: Int) -> String { "\(years)y younger" }
        static func metricOlder(_ years: Int) -> String { "+\(years)y older" }

        // MARK: - Sections

        static let topImprovements = "Top Improvements"
        static let metricContributions = "Metric Contributions"
        static let howThisWorks = "How this works"
        static let methodology = "Vitality Age compares your health numbers to what is typical for your age and turns that into one number. This is for wellness and information only."
        static func ageLabel(_ age: Int) -> String { "Age \(age)" }
        static func metricSubtitle(current: String, expected: String) -> String { "\(current) now, typical \(expected)" }

        // MARK: - Data Maturity

        static let buildingProfileDescription = "Your vitality age matches your real age while we learn what is normal for you. Keep wearing your device."
        static let earlyEstimateDescription = "Early estimate. Gets more accurate each day as we learn your patterns."
        static let profileProgressTitle = "Profile progress"
        static func dataProgress(days: Int, target: Int) -> String { "\(days) of \(target) days" }

        // MARK: - Trend

        static let ninetyDayTrend = "90-Day Trend"
        static let ninetyDayChange = "90d change"
        static let pace = "Pace"
        static let current = "Current"

        // MARK: - Improvement Suggestions

        static let improveVO2Max = "Try running, cycling, or swimming 2 to 3 times a week to build your cardio fitness."
        static let improveRHR = "Regular exercise and less stress can bring your resting heart rate down over time."
        static let improveHRV = "Better sleep, deep breathing, and regular exercise all help improve HRV."
        static let improveSleep = "Aim for 7 to 9 hours of sleep on a regular schedule. Cut screens and caffeine before bed."
        static let improveWalkingSpeed = "Walking speed shows your overall fitness. Regular walks, strength work, and balance exercises can help."
        static let improveSteps = "Move more during the day. Take walking meetings, use stairs, and add a daily walk."
        static let improveExercise = "Work up to 150 or more minutes of exercise per week doing things you enjoy."
        static let improveBodyComp = "Focus on eating well and staying active. Small steady changes make the biggest difference over time."
        static let improveDefault = "Keep tracking this and look for patterns in your data."

        // MARK: - Pace Labels (VitalityScorer)

        static let paceImproving = "Improving"
        static let paceStable = "Stable"
        static let paceDeclining = "Declining"

        // MARK: - Chart Accessibility (VitalityTrendSection)

        static func chartPointAccessibilityValue(age: Int) -> String {
            "Vitality age \(age) years"
        }
        static func chartAccessibilityLabel(dayCount: Int) -> String {
            "Vitality age trend over last \(dayCount) days"
        }
    }
}
