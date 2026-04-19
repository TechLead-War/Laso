import Foundation

extension Copy {
    enum Strain {

        // MARK: - Navigation

        static let title = "Strain"

        // MARK: - Hero

        static let of21 = "of 21"
        static let contextLow = "Very light day for your body."
        static let contextLight = "Easy effort. Room to do more."
        static let contextModerate = "Solid workload. Well-balanced."
        static let contextHigh = "Hard day. Recovery matters tonight."
        static let contextPeak = "Pushing your limits. Plan rest."
        static let contextAllOut = "Maximum effort. Prioritize recovery."

        // MARK: - Balance

        static let strainBalance = "Strain Balance"
        static let underTraining = "Under-Training"
        static let optimal = "Optimal"
        static let overreaching = "Peak"

        static let underTrainingDescription = "Your strain is below your target. Try adding more activity to stay on track."
        static let optimalDescription = "You are training in your ideal range for your current recovery. Nice work."
        static let overreachingDescription = "You are pushing harder than your body can recover from. Rest and go lighter."

        // MARK: - Coach

        static let strainCoach = "Strain Coach"
        static let targetStrain = "Target Strain"
        static let recommendedZone = "Recommended Zone"

        // MARK: - HR Zones

        static let heartRateZones = "Heart Rate Zones"
        static let activeRecovery = "Active Recovery"
        static let fatBurn = "Fat Burn"
        static let aerobic = "Aerobic"
        static let threshold = "Threshold"
        static let anaerobic = "Anaerobic"
        static func zoneDefault(_ zone: Int) -> String { "Zone \(zone)" }
        static func percentOfTotal(_ pct: Int) -> String { "\(pct)% of total time" }

        // MARK: - History

        static let sevenDayHistory = "7-Day History"
        static let sevenDayAverage = "7-Day Average:"

        // MARK: - Simplified Drivers

        static let todaySnapshot = "Today's Snapshot"
        static let inTarget = "In Target"
        static let belowTarget = "Below Target"
        static let aboveTarget = "Above Target"
        static func targetRange(_ low: String, _ high: String) -> String { "Aim for \(low) to \(high)" }
        static func currentStrainVsTarget(_ current: String) -> String { "You are at \(current) right now" }
        static let learnMore = "Learn More"
        static let learnMoreHint = "See your heart rate zones and detailed coaching."

        // MARK: - Disclaimer

        static let strainDisclaimer = "Strain is based on your heart rate during activity. It is not a medical measurement. Consider consulting a qualified professional before significantly changing your exercise routine."
    }
}
