import Foundation

extension Copy {
    enum Strain {

        // MARK: - Navigation

        static let title = "Strain"

        // MARK: - Hero

        static let of21 = "of 21"
        static let heroExplainer = "How much physical effort your body handled today"
        static let contextLow = "Light day for your body. Safe to add some activity if you feel up to it."
        static let contextLight = "Easy effort so far. You have room to push a bit more today."
        static let contextModerate = "Solid workload for your recovery. Keep this rhythm going."
        static let contextHigh = "Hard day on the body. Make sure to eat well, drink water, and get enough sleep tonight."
        static let contextPeak = "You pushed near your limit. Plan an easier day tomorrow."
        static let contextAllOut = "Maximum effort today. Real recovery is the priority now."

        // MARK: - Balance

        static let strainBalance = "Strain Balance"
        static let underTraining = "Under-Training"
        static let optimal = "Best"
        static let overreaching = "Peak"

        static let underTrainingDescription = "Your strain is below your target. Try adding more activity to stay on track."
        static let optimalDescription = "You are training in your best range for your current recovery. Nice work."
        static let overreachingDescription = "You are pushing harder than your body can recover from. Rest and go lighter."

        // MARK: - Coach Zone Display Names

        static let zoneRestoring = "Recovery Focus"
        static let zoneMaintaining = "Maintain Fitness"
        static let zoneBuilding = "Progressive Overload"
        static let zoneOverreaching = "Functional Overreach"

        // MARK: - Strain Balance Display Names (Coach)

        static let balanceUnderTraining = "Under-Training"
        static let balanceOptimal = "Optimal Load"
        static let balanceOverreaching = "Over-Reaching"

        // MARK: - Coach Guidance

        static let coachLimitedData = "Limited data \u{2014} this target is estimated. Keep logging for more accurate recommendations."
        static func coachRedRecovery(target: String) -> String {
            "Your body needs recovery. Focus on gentle movement like walking or stretching. Aim to keep strain under \(target)."
        }
        static func coachConsecutiveHigh(days: Int) -> String {
            "You've pushed hard \(days) days in a row. Take it easy today to avoid overtraining."
        }
        static let coachActiveRecovery = "Active recovery day. Light activity to promote blood flow without adding fatigue."
        static func coachMaintaining(remaining: String, target: String) -> String {
            "Moderate training day. You have \(remaining) strain remaining to hit your target of \(target)."
        }
        static let coachMaintainHit = "You've reached your maintenance target. Additional strain is fine but keep intensity controlled."
        static func coachBuilding(target: String) -> String {
            "Your body is ready for a challenge. Push toward a strain of \(target) with a hard workout."
        }
        static func coachBuildingHit(upper: String) -> String {
            "Great work \u{2014} you've hit your building target. You can keep going up to \(upper)."
        }
        static let coachOverreaching = "Functional overreach zone. Push to your limit today, then plan recovery tomorrow."

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

        // MARK: - Scale

        static let scaleSuffix = "/ 21"
        static let strainScaleLegend = "Strain Scale"
        static func targetZoneLabel(_ low: String, _ high: String) -> String {
            "Target zone: \(low) to \(high) / 21"
        }

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

        static let strainDisclaimer = "Strain is based on your heart rate during activity. It is not a medical measurement. Talk to a qualified professional before making big changes to your exercise routine."

        // MARK: - Today's Workout

        static let todaysWorkout = "Today's Workout"
        static let tapToViewWorkout = "Tap to view warm-up, blocks, and cooldown"
        static let cycleAdjustmentTitle = "Cycle Adjustment"
        static let cyclePhaseTitle = "Cycle Phase"
        static func cyclePhaseDetail(_ phase: String) -> String {
            "Current phase: \(phase). Training stays in line with your recovery for today."
        }
        static let warmUpTitle = "Warm-Up"
        static let cooldownTitle = "Cooldown"
        static func mainBlockTitle(_ index: Int) -> String { "Main Block \(index)" }
        static let done = "Done"
        static let recoveryLabel = "Recovery"
        static let durationLabel = "Duration"
        static let caloriesLabel = "Cal"
        static let redRecovery = "Red recovery"
        static let yellowRecovery = "Yellow recovery"
        static let greenRecovery = "Green recovery"
        static func workoutHeartRateTarget(label: String, minBPM: Int, maxBPM: Int) -> String {
            "Target: \(label) \u{2022} \(minBPM)-\(maxBPM) bpm"
        }
        static func minutesShort(_ minutes: Int) -> String { "\(minutes) min" }

        // MARK: - Strain Detail

        static func zoneShort(_ zone: Int) -> String { "Z\(zone)" }
        static let noWorkoutData = "No workout data yet"
        static let logWorkoutHint = "Log a workout in Apple Health or wear your watch during exercise. Your strain score will appear here once activity is recorded."

        // MARK: - Strain Levels

        static let strainLevelLow = "Low"
        static let strainLevelLight = "Light"
        static let strainLevelModerate = "Moderate"
        static let strainLevelHigh = "High"
        static let strainLevelPeak = "Peak"
        static let strainLevelAllOut = "All Out"
    }
}
