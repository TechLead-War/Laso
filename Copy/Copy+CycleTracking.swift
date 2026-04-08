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

        static let menstrualDescription = "Your body is shedding the uterine lining. Hormone levels are at their lowest, which can affect energy and mood."
        static let follicularDescription = "Estrogen rises steadily as follicles develop. Energy and mood typically improve as your body prepares for ovulation."
        static let ovulatoryDescription = "An egg is released from the ovary. Estrogen peaks and testosterone briefly surges, often boosting energy and confidence."
        static let lutealDescription = "Progesterone rises to prepare the uterine lining. You may notice changes in appetite, sleep, and mood as the cycle nears its end."

        // MARK: - Energy Impact

        static let menstrualEnergy = "Energy tends to be lower. Light movement can help ease discomfort, but listen to your body and rest when needed."
        static let follicularEnergy = "Rising estrogen boosts energy and endurance. A great time for challenging workouts and learning new skills."
        static let ovulatoryEnergy = "Peak energy and strength. You may hit personal records during this window as hormones support performance."
        static let lutealEnergy = "Energy gradually declines, especially in the late luteal phase. Shift toward moderate, steady-state activities."

        // MARK: - Recovery Impact

        static let menstrualRecovery = "Recovery may be slower due to inflammation. Prioritize sleep, hydration, and gentle movement like yoga or walking."
        static let follicularRecovery = "Recovery is typically efficient. Your body responds well to training stimulus and adapts quickly."
        static let ovulatoryRecovery = "Good recovery capacity, but monitor intensity. The hormonal peak can mask fatigue signals."
        static let lutealRecovery = "Recovery slows as progesterone rises. Allow extra rest between intense sessions and focus on sleep quality."

        // MARK: - Sleep Impact

        static let menstrualSleep = "Sleep can be disrupted by cramps or discomfort. Melatonin production may be affected by low hormone levels."
        static let follicularSleep = "Sleep quality generally improves. Rising estrogen supports deeper, more restorative sleep cycles."
        static let ovulatorySleep = "Sleep is typically good, though some may experience a slight rise in body temperature affecting sleep onset."
        static let lutealSleep = "Progesterone raises core body temperature, which can reduce sleep quality. Keep the room cool and allow extra wind-down time."

        // MARK: - Nutrition Tips

        static let menstrualNutrition = "Focus on iron-rich foods (leafy greens, red meat, lentils) and anti-inflammatory choices. Stay well hydrated."
        static let follicularNutrition = "Support rising energy with complex carbs and lean protein. Fermented foods can support gut health during this phase."
        static let ovulatoryNutrition = "Lighter meals with plenty of fiber and antioxidants. Cruciferous vegetables help metabolize the estrogen peak."
        static let lutealNutrition = "Increased caloric needs. Add healthy fats and magnesium-rich foods. Dark chocolate and nuts can help with cravings."

        // MARK: - Exercise Recommendations

        static let menstrualExercise = "Gentle yoga, walking, light stretching, or swimming. Reduce intensity and focus on movement that feels good."
        static let follicularExercise = "High-intensity training, strength work, HIIT, and skill-based activities. Your body is primed for performance gains."
        static let ovulatoryExercise = "Peak performance window. Heavy lifts, sprint intervals, competitive sports. Push toward personal records."
        static let lutealExercise = "Moderate cardio, Pilates, strength maintenance. Taper intensity in the late luteal phase as energy declines."

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
