import Foundation

extension Copy {
    enum CycleTracking {

        // MARK: - Navigation

        static let title = "Cycle Tracking"

        // MARK: - Phase Names

        static let menstrualPhase = "Menstrual Phase"
        static let follicularPhase = "Follicular Phase"
        static let ovulatoryPhase = "Ovulatory Phase"
        static let lutealPhase = "Luteal Phase"

        // MARK: - Phase Descriptions

        static let menstrualDescription = "Your period is here. Hormone levels are at their lowest, so your energy and mood may dip."
        static let follicularDescription = "Your body is gearing up after your period. Energy and mood usually start to pick up."
        static let ovulatoryDescription = "This is your peak window. Energy, confidence, and strength are often at their highest."
        static let lutealDescription = "Your body is winding down toward the next cycle. You may notice changes in appetite, sleep, and mood."

        // MARK: - Energy Impact

        static let menstrualEnergy = "Energy tends to be lower. Light movement can help, but rest when your body asks for it."
        static let follicularEnergy = "Energy and endurance are rising. Great time for tough workouts and learning new things."
        static let ovulatoryEnergy = "Peak energy and strength. You may hit personal bests during this window."
        static let lutealEnergy = "Energy starts to wind down, especially toward the end. Shift to moderate, steady activities."

        // MARK: - Recovery Impact

        static let menstrualRecovery = "Recovery may be slower right now. Focus on sleep, water, and gentle movement like yoga or walking."
        static let follicularRecovery = "Recovery is usually fast right now. Your body handles training well and bounces back quickly."
        static let ovulatoryRecovery = "Recovery is good, but watch your intensity. Your body may hide tiredness during this peak."
        static let lutealRecovery = "Recovery slows down in this phase. Give yourself extra rest between hard sessions and focus on sleep."

        // MARK: - Sleep Impact

        static let menstrualSleep = "Sleep can be disrupted by cramps or discomfort. Give yourself extra time to rest."
        static let follicularSleep = "Sleep quality usually gets better. Your body supports deeper, more restful sleep right now."
        static let ovulatorySleep = "Sleep is usually good, though your body temperature may rise a little, making it harder to fall asleep."
        static let lutealSleep = "Your body temperature runs higher, which can make sleep harder. Keep the room cool and give yourself extra wind down time."

        // MARK: - Nutrition Tips

        static let menstrualNutrition = "Eat iron-rich foods like leafy greens, red meat, and lentils. Drink plenty of water."
        static let follicularNutrition = "Fuel your rising energy with whole grains, lean protein, and foods that are good for your gut."
        static let ovulatoryNutrition = "Go lighter with plenty of fiber and colorful vegetables. Broccoli and cauliflower are great right now."
        static let lutealNutrition = "Your body needs a bit more fuel. Add healthy fats and magnesium-rich foods. Dark chocolate and nuts can help with cravings."

        // MARK: - Exercise Recommendations

        static let menstrualExercise = "Gentle yoga, walking, light stretching, or swimming. Do what feels good and skip anything that does not."
        static let follicularExercise = "Great time for hard workouts, strength training, and learning new skills. Your body is ready to perform."
        static let ovulatoryExercise = "Your peak performance window. Go for heavy lifts, sprints, and competitive activities. Push for personal bests."
        static let lutealExercise = "Moderate cardio, Pilates, and lighter strength work. Ease off as your energy dips toward the end of this phase."

        // MARK: - Section Headers

        static let howThisPhaseAffectsYou = "How This Phase Affects You"
        static let energyAndPerformance = "Energy & Performance"
        static let recovery = "Recovery"
        static let sleep = "Sleep"
        static let nutritionTips = "Nutrition Tips"
        static let exerciseRecommendation = "Exercise Recommendation"
        static func recommendedFor(phase: String) -> String { "Recommended for \(phase)" }
        static let intensity = "Intensity:"

        // MARK: - History

        static let cycleHistory = "Cycle History"
        static let notEnoughCycleData = "Not enough cycle data yet"
        static func averageCycleLength(_ days: Int) -> String { "Average cycle length: \(days) days" }
        static func daysCount(_ days: Int) -> String { "\(days) days" }

        // MARK: - Next Period

        static let nextPeriodEstimate = "Next Period Estimate"
        static let estimatedStart = "Estimated Start"
        static let days = "days"
        static let daysToPeriod = "days to\nperiod"
        static func basedOnCycleLength(_ length: Int) -> String { "Based on your \(length)-day average cycle" }
        static func inAboutDays(_ days: Int) -> String { "In about \(days) days" }

        // MARK: - Cycle Wheel

        static func dayOfCycle(_ day: Int) -> String { "Day \(day)" }
        static func ofTotal(_ total: Int) -> String { "of \(total)" }
        static func dayOfPhase(_ day: Int, duration: Int) -> String { "Day \(day) of \(duration)" }
    }
}
